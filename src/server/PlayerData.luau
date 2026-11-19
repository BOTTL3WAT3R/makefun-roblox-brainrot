-- PlayerData.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- all per-player state lives in this one module:
-- cash, placed brainrots, the brainrot being carried, rebirths and the income multiplier,
-- the twelve-quest chain (three active at a time, each paying cash the moment it
-- completes) and the owned-ever collection set behind the Index and its income
-- milestones.
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
	QuestProgress: { [number]: number },
	QuestCompleted: { [number]: boolean },
	OwnedEver: { [string]: boolean },
	BoostEndsAt: { [string]: number },
	WaveShield: boolean,
}

-- The quest chain, in order. The first three UNFINISHED quests are active at
-- once; services report finished actions by Key through ReportQuestAction and
-- only active quests gain progress, so nothing is ever earned retroactively.
-- The two Earn quests are fed by the income tick (amount = cash just earned);
-- every other key counts single actions. Rewards land as cash the moment a
-- quest completes, and completing one immediately activates the next in line.
local QUESTS = {
	{ Key = "Buy", Label = "Buy 3 brainrots from the belt", Target = 3, Reward = 300 },
	{ Key = "Hatch", Label = "Hatch 2 eggs", Target = 2, Reward = 500 },
	{ Key = "Lock", Label = "Lock your base", Target = 1, Reward = 400 },
	{ Key = "Earn", Label = "Earn $5,000 total", Target = 5000, Reward = 750 },
	{ Key = "Fuse", Label = "Fuse 3 brainrots into 1", Target = 1, Reward = 1000 },
	{ Key = "Steal", Label = "Steal a brainrot", Target = 1, Reward = 1500 },
	{ Key = "Survive", Label = "Survive 2 Big Waves", Target = 2, Reward = 1200 },
	{ Key = "Buy", Label = "Buy 10 brainrots from the belt", Target = 10, Reward = 2000 },
	{ Key = "Gacha", Label = "Spin the Gacha 2 times", Target = 2, Reward = 2500 },
	{ Key = "Earn", Label = "Earn $100,000 total", Target = 100000, Reward = 5000 },
	{ Key = "Rebirth", Label = "Rebirth at the Shrine", Target = 1, Reward = 7500 },
	{ Key = "Steal", Label = "Steal 3 brainrots", Target = 3, Reward = 10000 },
}
local ACTIVE_QUEST_COUNT = 3

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
		QuestProgress = {},
		QuestCompleted = {},
		OwnedEver = {},
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

-- The indexes of the currently active quests: the first ACTIVE_QUEST_COUNT
-- unfinished ones, in chain order. Completing a quest slides the window, so
-- the next quest in line activates the moment the previous one pays out.
local function activeQuestIndexes(state: PlayerState): { number }
	local indexes = {}
	for index in ipairs(QUESTS) do
		if not state.QuestCompleted[index] then
			table.insert(indexes, index)
			if #indexes >= ACTIVE_QUEST_COUNT then
				break
			end
		end
	end
	return indexes
end

-- Reports one finished gameplay action against the quest chain. Keys:
-- "Buy", "Hatch", "Lock", "Fuse", "Steal", "Rebirth", "Gacha", "Survive" count
-- single actions (amount defaults to 1); "Earn" is fed by the income tick with
-- amount = the cash that tick just paid. Only ACTIVE quests matching the key
-- gain progress -- the active set is snapshotted first, so a quest activated
-- BY this very action never counts it retroactively. On completion the reward
-- is added as cash at once. Returns the completions ({ Label, Reward }) so the
-- calling service can toast each one.
function PlayerData.ReportQuestAction(state: PlayerState, actionKey: string, amount: number?): { { Label: string, Reward: number } }
	local completions: { { Label: string, Reward: number } } = {}
	local step = amount or 1
	if step <= 0 then
		return completions
	end
	local changed = false
	for _, index in ipairs(activeQuestIndexes(state)) do
		local quest = QUESTS[index]
		if quest.Key == actionKey then
			local progress = math.min((state.QuestProgress[index] or 0) + step, quest.Target)
			if progress ~= (state.QuestProgress[index] or 0) then
				state.QuestProgress[index] = progress
				changed = true
			end
			if progress >= quest.Target then
				state.QuestCompleted[index] = true
				state.Cash += quest.Reward
				changed = true
				table.insert(completions, { Label = quest.Label, Reward = quest.Reward })
			end
		end
	end
	if changed then
		PlayerData.FireStateChanged(state)
	end
	return completions
end

-- The quest block for the HUD snapshot: how many are done, and one row per
-- active quest (description, progress, target, formatted reward).
function PlayerData.GetQuestSnapshot(state: PlayerState)
	local done = 0
	for index in ipairs(QUESTS) do
		if state.QuestCompleted[index] then
			done += 1
		end
	end
	local active = {}
	for _, index in ipairs(activeQuestIndexes(state)) do
		local quest = QUESTS[index]
		table.insert(active, {
			Label = quest.Label,
			Progress = math.min(state.QuestProgress[index] or 0, quest.Target),
			Target = quest.Target,
			RewardText = GameConfig.FormatCash(quest.Reward),
		})
	end
	return { Done = done, Total = #QUESTS, AllDone = done >= #QUESTS, Active = active }
end

-- The collection: every character the player has owned at least once (bought,
-- hatched, spun, fused, grabbed or banked from a steal) is marked the moment
-- it lands on a pad, and the mark is permanent -- selling or losing the
-- brainrot never un-finds it. Milestones over the found count pay a permanent
-- income bonus, multiplicative with the rebirth multiplier.
function PlayerData.MarkOwned(state: PlayerState, characterId: string)
	state.OwnedEver[characterId] = true
end

function PlayerData.GetFoundCount(state: PlayerState): number
	local count = 0
	for _ in pairs(state.OwnedEver) do
		count += 1
	end
	return count
end

function PlayerData.GetMilestonesReached(state: PlayerState): number
	local found = PlayerData.GetFoundCount(state)
	local reached = 0
	for _, milestone in ipairs(GameConfig.CollectionMilestones) do
		if found >= milestone then
			reached += 1
		end
	end
	return reached
end

function PlayerData.GetCollectionMultiplier(state: PlayerState): number
	return 1 + PlayerData.GetMilestonesReached(state) * GameConfig.CollectionBonusPerMilestone
end

function PlayerData.GetCollectionBonusPercent(state: PlayerState): number
	return PlayerData.GetMilestonesReached(state) * math.floor(GameConfig.CollectionBonusPerMilestone * 100)
end

-- How many more finds until the next milestone pays out, or nil at the cap.
function PlayerData.GetNextMilestoneIn(state: PlayerState): number?
	local found = PlayerData.GetFoundCount(state)
	for _, milestone in ipairs(GameConfig.CollectionMilestones) do
		if found < milestone then
			return milestone - found
		end
	end
	return nil
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
