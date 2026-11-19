-- PlayerData.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- all per-player state lives in this one module:
-- cash, placed brainrots, the brainrot being carried, rebirths and the income multiplier.
-- Every other service reads and writes state through here, never in its own tables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PlayerData = {}

export type PlacedBrainrot = {
	Uid: number,
	CharacterId: string,
	Mutation: string,
	PadIndex: number,
	Model: Model?,
}

export type PlayerState = {
	Player: Player,
	Cash: number,
	Rebirths: number,
	Placed: { PlacedBrainrot },
	Carried: PlacedBrainrot?,
	BaseIndex: number?,
	LockEndsAt: number,
	LockReadyAt: number,
	NextUid: number,
}

local statesByUserId: { [number]: PlayerState } = {}
local stateChangedEvent: BindableEvent? = nil

function PlayerData.BindStateChangedEvent(event: BindableEvent)
	stateChangedEvent = event
end

function PlayerData.FireStateChanged(state: PlayerState)
	if stateChangedEvent then
		stateChangedEvent:Fire(state.Player)
	end
end

function PlayerData.CreateStateForPlayer(player: Player): PlayerState
	local state: PlayerState = {
		Player = player,
		Cash = GameConfig.StartingCash,
		Rebirths = 0,
		Placed = {},
		Carried = nil,
		BaseIndex = nil,
		LockEndsAt = 0,
		LockReadyAt = 0,
		NextUid = 1,
	}
	statesByUserId[player.UserId] = state
	return state
end

function PlayerData.GetState(player: Player): PlayerState?
	return statesByUserId[player.UserId]
end

function PlayerData.RemoveStateForPlayer(player: Player)
	statesByUserId[player.UserId] = nil
end

function PlayerData.GetAllStates(): { PlayerState }
	local all = {}
	for _, state in pairs(statesByUserId) do
		table.insert(all, state)
	end
	return all
end

function PlayerData.GetIncomeMultiplier(state: PlayerState): number
	return GameConfig.GetIncomeMultiplier(state.Rebirths)
end

function PlayerData.AddCash(state: PlayerState, amount: number)
	state.Cash = math.max(0, math.floor(state.Cash + amount))
	PlayerData.FireStateChanged(state)
end

function PlayerData.TrySpendCash(state: PlayerState, amount: number): boolean
	if state.Cash < amount then
		return false
	end
	state.Cash -= amount
	PlayerData.FireStateChanged(state)
	return true
end

function PlayerData.GetPlacedCount(state: PlayerState): number
	return #state.Placed
end

function PlayerData.HasFreePad(state: PlayerState): boolean
	return #state.Placed < GameConfig.MaxPlacedPerBase
end

function PlayerData.AllocateUid(state: PlayerState): number
	local uid = state.NextUid
	state.NextUid += 1
	return uid
end

function PlayerData.FindPlacedByUid(state: PlayerState, uid: number): PlacedBrainrot?
	for _, placed in ipairs(state.Placed) do
		if placed.Uid == uid then
			return placed
		end
	end
	return nil
end

function PlayerData.RemovePlaced(state: PlayerState, uid: number): PlacedBrainrot?
	for index, placed in ipairs(state.Placed) do
		if placed.Uid == uid then
			table.remove(state.Placed, index)
			PlayerData.FireStateChanged(state)
			return placed
		end
	end
	return nil
end

function PlayerData.AddPlaced(state: PlayerState, placed: PlacedBrainrot)
	table.insert(state.Placed, placed)
	PlayerData.FireStateChanged(state)
end

function PlayerData.IsBaseLocked(state: PlayerState): boolean
	return os.clock() < state.LockEndsAt
end

function PlayerData.WipeForRebirth(state: PlayerState)
	state.Placed = {}
	state.Carried = nil
	state.Cash = GameConfig.StartingCash
	state.Rebirths += 1
	PlayerData.FireStateChanged(state)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.RemoveStateForPlayer(player)
end)

return PlayerData
