-- FuseService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the Fuse Machine by the plaza: hand over 3 placed brainrots of
-- the SAME rarity and they are consumed into 1 random brainrot of the NEXT
-- rarity tier, with a mutation roll kinder than the egg's (55% Normal, 25% Gold,
-- 13% Diamond, 7% Rainbow). Fusing is free; Brainrot God has no tier above it
-- and cannot be fused. Every check happens here on the server -- the client's
-- FUSE panel only ever sends 3 uids through the FuseBrainrots remote (created
-- and wired to PerformFuse in Main.server) and hopes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
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

local function rollFuseMutation(): string
	local roll = rng:NextInteger(1, 100)
	if roll <= 55 then
		return "Normal"
	elseif roll <= 80 then
		return "Gold"
	elseif roll <= 93 then
		return "Diamond"
	end
	return "Rainbow"
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
	-- and owned by this player, all one shared rarity below Brainrot God.
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
		notifyPlayer(state.Player, "Brainrot God is the top -- there is nothing to fuse into.")
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
	local mutationName = rollFuseMutation()
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, resultCharacter.Id, mutationName)
	if placedOk then
		local mutationText = if mutationName == "Normal" then "" else ", " .. mutationName
		notifyPlayer(state.Player, string.format("FUSED! Your 3 %s brainrots became %s (%s%s)!", sharedRarity, resultCharacter.Name, resultRarity, mutationText))
	end
	return placedOk
end

return FuseService
