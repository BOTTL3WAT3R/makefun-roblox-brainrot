-- PlayerData.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- all per-player state lives in this one module:
-- cash, placed brainrots, the brainrot being carried, rebirths and the income multiplier,
-- and the linear mission chain (buy, hatch, lock, fuse, steal, rebirth) that teaches
-- the whole loop one rewarded step at a time.
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
	MissionIndex: number,
	MissionProgress: number,
	BoostEndsAt: { [string]: number },
	WaveShield: boolean,
}

-- The mission chain, in order. Services report finished actions by Key through
-- ReportMissionAction; only the CURRENT mission's key counts, so the chain
-- teaches one mechanic at a time. Rewards land as cash the moment a mission ends.
local MISSIONS = {
	{ Key = "Buy", Label = "Buy a brainrot from the belt", Target = 1, Reward = 100 },
	{ Key = "Hatch", Label = "Hatch an egg at the Egg Machine", Target = 1, Reward = 250 },
	{ Key = "Lock", Label = "Lock your base", Target = 1, Reward = 500 },
	{ Key = "Fuse", Label = "Fuse 3 brainrots into 1", Target = 1, Reward = 1000 },
	{ Key = "Steal", Label = "Steal a brainrot from another base", Target = 1, Reward = 2500 },
	{ Key = "Rebirth", Label = "Rebirth at the Shrine", Target = 1, Reward = 5000 },
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
		MissionIndex = 1,
		MissionProgress = 0,
		BoostEndsAt = { Speed = 0, Income = 0, Luck = 0 },
		WaveShield = false,
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

-- Boosts (see GameConfig.Boosts): timed boosts store an os.clock() expiry in
-- BoostEndsAt keyed by boost Id; the Wave Shield is a one-time held flag the
-- TsunamiService consumes when it saves its owner.
function PlayerData.HasBoost(state: PlayerState, boostId: string): boolean
	return os.clock() < (state.BoostEndsAt[boostId] or 0)
end

function PlayerData.GetBoostSecondsLeft(state: PlayerState, boostId: string): number
	return math.max(0, math.ceil((state.BoostEndsAt[boostId] or 0) - os.clock()))
end

-- The Income X2 boost as a multiplier, kept apart from the rebirth multiplier
-- so the stacking order in EconomyService reads base x rebirth x boost.
function PlayerData.GetIncomeBoostMultiplier(state: PlayerState): number
	return if PlayerData.HasBoost(state, "Income") then 2 else 1
end

-- The speed a player should walk at when nothing else (carrying, dashing)
-- overrides it: Speed Surge raises the base from 16 to 24 while it lasts.
function PlayerData.GetBaseWalkSpeed(state: PlayerState): number
	return if PlayerData.HasBoost(state, "Speed") then GameConfig.SpeedBoostWalkSpeed else GameConfig.NormalWalkSpeed
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

-- Reports one finished gameplay action ("Buy", "Hatch", "Lock", "Fuse", "Steal",
-- "Rebirth") against the mission chain. Counts only when it matches the current
-- mission; on completion the reward is added as cash and the chain advances.
-- Returns (completed, reward) so the calling service can toast the player.
function PlayerData.ReportMissionAction(state: PlayerState, actionKey: string): (boolean, number)
	local mission = MISSIONS[state.MissionIndex]
	if not mission or mission.Key ~= actionKey then
		return false, 0
	end
	state.MissionProgress += 1
	if state.MissionProgress >= mission.Target then
		local reward = mission.Reward
		state.MissionIndex += 1
		state.MissionProgress = 0
		state.Cash += reward
		PlayerData.FireStateChanged(state)
		return true, reward
	end
	PlayerData.FireStateChanged(state)
	return false, 0
end

-- The mission line for the HUD: either the current mission with its progress
-- and reward, or the victory line once the whole chain is done.
function PlayerData.GetMissionSnapshot(state: PlayerState): { Text: string, Done: boolean }
	local mission = MISSIONS[state.MissionIndex]
	if not mission then
		return { Text = "ALL MISSIONS COMPLETE - you rule Candy Island!", Done = true }
	end
	local text = string.format(
		"MISSION %d/%d: %s (%d/%d)  REWARD %s",
		state.MissionIndex,
		#MISSIONS,
		mission.Label,
		state.MissionProgress,
		mission.Target,
		GameConfig.FormatCash(mission.Reward)
	)
	return { Text = text, Done = false }
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
