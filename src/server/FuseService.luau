-- FuseService.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- the Fuse Machine by the plaza: hand over 3 placed brainrots of
-- the SAME rarity and they are consumed into 1 random brainrot of the NEXT
-- rarity tier, with a mutation roll kinder than the egg's (55% Normal, 25% Gold,
-- 13% Diamond, 7% Rainbow -- or 40/32/18/10 under a Lucky Charm boost). Fusing is free; Transcendent, the top
-- of the ladder, has no tier above it and cannot be fused. Every check happens here on the server -- the client's
-- FUSE panel only ever sends 3 uids through the FuseBrainrots remote (created
-- and wired to PerformFuse in Main.server) and hopes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local EconomyService = require(ServerModules:WaitForChild("EconomyService"))
local AnimationService = require(ServerModules:WaitForChild("AnimationService"))

local FuseService = {}

local rng = Random.new()
local remotes: { [string]: RemoteEvent } = {}

function FuseService.BindRemotes(remoteFolder: Folder)
	for _, child in ipairs(remoteFolder:GetChildren()) do
		if child:IsA("RemoteEvent") then
			remotes[child.Name] = child
		end
	end
end

local function notifyPlayer(player: Player, message: string)
	local remote = remotes.Notify
	if remote then
		remote:FireClient(player, message)
	end
end

-- Mission reporting is always pcall-wrapped: the mission chain is a bonus
-- layer and can never be allowed to break the mechanic that feeds it.
local function reportMission(state: any, actionKey: string)
	pcall(function()
		local completed, reward = PlayerData.ReportMissionAction(state, actionKey)
		if completed then
			notifyPlayer(state.Player, "MISSION COMPLETE! +" .. GameConfig.FormatCash(reward))
		end
	end)
end

-- Mutation roll for a fuse result, weighted from GameConfig (55/25/13/7
-- normally). A player under the Lucky Charm boost rolls the kinder table
-- (40/32/18/10) instead -- the charm is personal and never touches the belt.
local MUTATION_ORDER = { "Normal", "Gold", "Diamond", "Rainbow" }

local function rollFuseMutation(lucky: boolean): string
	local weights = if lucky then GameConfig.LuckyFuseMutationWeights else GameConfig.FuseMutationWeights
	local totalWeight = 0
	for _, name in ipairs(MUTATION_ORDER) do
		totalWeight += weights[name]
	end
	local roll = rng:NextInteger(1, totalWeight)
	local running = 0
	for _, name in ipairs(MUTATION_ORDER) do
		running += weights[name]
		if roll <= running then
			return name
		end
	end
	return "Normal"
end

local function nextRarity(rarity: string): string?
	for index, entry in ipairs(BrainrotCatalog.RarityOrder) do
		if entry == rarity then
			return BrainrotCatalog.RarityOrder[index + 1]
		end
	end
	return nil
end

function FuseService.PerformFuse(state: any, uids: any): boolean
	if typeof(uids) ~= "table" or #uids ~= 3 then
		notifyPlayer(state.Player, "Fuse needs exactly 3 brainrots.")
		return false
	end
	-- Validate everything before consuming anything: 3 distinct uids, all placed
	-- and owned by this player, all one shared rarity below the top tier.
	local seen: { [number]: boolean } = {}
	local chosen: { any } = {}
	local sharedRarity: string? = nil
	for _, uid in ipairs(uids) do
		if typeof(uid) ~= "number" or seen[uid] then
			notifyPlayer(state.Player, "Fuse needs 3 different brainrots.")
			return false
		end
		seen[uid] = true
		local placed = PlayerData.FindPlacedByUid(state, uid)
		if not placed then
			notifyPlayer(state.Player, "One of those brainrots is no longer at your base.")
			return false
		end
		local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
		if not character then
			return false
		end
		if sharedRarity == nil then
			sharedRarity = character.Rarity
		elseif character.Rarity ~= sharedRarity then
			notifyPlayer(state.Player, "Fuse needs 3 brainrots of the SAME rarity.")
			return false
		end
		table.insert(chosen, placed)
	end
	local resultRarity = sharedRarity and nextRarity(sharedRarity)
	if not resultRarity then
		local topRarity = BrainrotCatalog.RarityOrder[#BrainrotCatalog.RarityOrder]
		notifyPlayer(state.Player, topRarity .. " is the top -- there is nothing to fuse into.")
		return false
	end
	-- Consume the three through the same removal path selling uses.
	for _, placed in ipairs(chosen) do
		local removed = PlayerData.RemovePlaced(state, placed.Uid)
		if removed and removed.Model then
			pcall(function()
				AnimationService.Unregister(removed.Model)
			end)
			removed.Model:Destroy()
		end
	end
	local pool = BrainrotCatalog.GetCharactersOfRarity(resultRarity)
	local resultCharacter = pool[rng:NextInteger(1, #pool)]
	local mutationName = rollFuseMutation(PlayerData.HasBoost(state, "Luck"))
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, resultCharacter.Id, mutationName)
	if placedOk then
		local mutationText = if mutationName == "Normal" then "" else ", " .. mutationName
		notifyPlayer(state.Player, string.format("FUSED! Your 3 %s brainrots became %s (%s%s)!", sharedRarity, resultCharacter.Name, resultRarity, mutationText))
		reportMission(state, "Fuse")
	end
	return placedOk
end

-- The Fuse Machine's own E prompt: the panel lets the player hand-pick 3
-- uids, but the machine itself just has to DO something. Pressing E runs an
-- automatic attempt through the very same PerformFuse: the lowest rarity
-- tier the player holds 3+ placed of (and that still has a tier above it)
-- is fused first, so commons burn before rares. Every other outcome speaks:
-- nothing placed, or no rarity with a full set of 3.
function FuseService.WatchFusePrompt()
	local prompt = WorldBuilder.FusePrompt
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		local state = PlayerData.GetState(player)
		if not state then
			return
		end
		if #state.Placed == 0 then
			notifyPlayer(player, "You have no brainrots to fuse - buy some from the belt first!")
			return
		end
		local uidsByRarity: { [string]: { number } } = {}
		for _, placed in ipairs(state.Placed) do
			local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
			if character then
				local uids = uidsByRarity[character.Rarity]
				if not uids then
					uids = {}
					uidsByRarity[character.Rarity] = uids
				end
				table.insert(uids, placed.Uid)
			end
		end
		for index, rarity in ipairs(BrainrotCatalog.RarityOrder) do
			local uids = uidsByRarity[rarity]
			if uids and #uids >= 3 and BrainrotCatalog.RarityOrder[index + 1] then
				FuseService.PerformFuse(state, { uids[1], uids[2], uids[3] })
				return
			end
		end
		notifyPlayer(player, "The Fuse Machine needs 3 placed brainrots of the SAME rarity.")
	end)
end

return FuseService
