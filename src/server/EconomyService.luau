-- EconomyService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the cash engine: the per-second income tick for every
-- placed brainrot, buying from the shop belt, hatching eggs with a mutation roll,
-- placing a fresh brainrot on a free base pad, and selling one back. Every model it
-- spawns is handed to AnimationService so it bobs (and spins / sparkles when rare).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local AnimationService = require(ServerModules:WaitForChild("AnimationService"))

local EconomyService = {}

local rng = Random.new()
local remotes: { [string]: RemoteEvent } = {}
local conveyorCharacters: { [number]: { Character: any, Model: Model } } = {}

function EconomyService.BindRemotes(remoteFolder: Folder)
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

function EconomyService.GetPlacedIncomePerSecond(state: any): number
	local total = 0
	for _, placed in ipairs(state.Placed) do
		local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
		if character then
			total += BrainrotCatalog.GetIncomePerSecond(character, placed.Mutation)
		end
	end
	return math.floor(total * PlayerData.GetIncomeMultiplier(state))
end

-- Places a brainrot on the owner's next free pad and stands its model on that pad.
function EconomyService.PlaceBrainrotOnPad(state: any, characterId: string, mutationName: string): boolean
	if not PlayerData.HasFreePad(state) then
		return false
	end
	local base = WorldBuilder.GetBaseByIndex(state.BaseIndex)
	if not base then
		return false
	end
	local usedPads: { [number]: boolean } = {}
	for _, placed in ipairs(state.Placed) do
		usedPads[placed.PadIndex] = true
	end
	local padIndex = 1
	while usedPads[padIndex] do
		padIndex += 1
	end
	local character = BrainrotCatalog.GetCharacterById(characterId)
	if not character then
		return false
	end
	local model = WorldBuilder.BuildBrainrotModel(character, mutationName)
	local pad = base.Pads[padIndex]
	model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 0.4, 0)))
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	model:SetAttribute("OwnerUserId", state.Player.UserId)
	model:SetAttribute("BrainrotUid", 0)
	model.Parent = Workspace
	pcall(function()
		AnimationService.Register(model, {
			Rarity = character.Rarity,
			Mutation = mutationName,
			Spin = character.Rarity == "Mythic" or character.Rarity == "Brainrot God",
		})
	end)

	local placed = {
		Uid = PlayerData.AllocateUid(state),
		CharacterId = characterId,
		Mutation = mutationName,
		PadIndex = padIndex,
		Model = model,
	}
	model:SetAttribute("BrainrotUid", placed.Uid)
	PlayerData.AddPlaced(state, placed)
	return true
end

function EconomyService.BuyCharacter(state: any, characterId: string): boolean
	local character = BrainrotCatalog.GetCharacterById(characterId)
	if not character then
		return false
	end
	if not PlayerData.HasFreePad(state) then
		notifyPlayer(state.Player, "Your base is full! Sell a brainrot or use the Rebirth Shrine.")
		return false
	end
	if not PlayerData.TrySpendCash(state, character.Price) then
		notifyPlayer(state.Player, "Not enough cash for " .. character.Name .. " (" .. GameConfig.FormatCash(character.Price) .. ")")
		return false
	end
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, characterId, "Normal")
	if placedOk then
		notifyPlayer(state.Player, "Bought " .. character.Name .. "! It now earns for you at your base.")
	end
	return placedOk
end

function EconomyService.HatchEgg(state: any): boolean
	if not PlayerData.HasFreePad(state) then
		notifyPlayer(state.Player, "Your base is full! Make room before hatching.")
		return false
	end
	if not PlayerData.TrySpendCash(state, GameConfig.EggPrice) then
		notifyPlayer(state.Player, "The Egg Machine needs " .. GameConfig.FormatCash(GameConfig.EggPrice) .. ".")
		return false
	end
	local character, mutation = BrainrotCatalog.RollHatch(rng)
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, character.Id, mutation.Name)
	if placedOk then
		notifyPlayer(state.Player, string.format("The egg hatched %s (%s, %s)!", character.Name, character.Rarity, mutation.Name))
	end
	return placedOk
end

function EconomyService.SellPlacedBrainrot(state: any, uid: number): boolean
	local placed = PlayerData.FindPlacedByUid(state, uid)
	if not placed then
		return false
	end
	local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
	if not character then
		return false
	end
	local removed = PlayerData.RemovePlaced(state, uid)
	if removed and removed.Model then
		pcall(function()
			AnimationService.Unregister(removed.Model)
		end)
		removed.Model:Destroy()
	end
	local refund = math.floor(character.Price * GameConfig.SellRefundFraction)
	PlayerData.AddCash(state, refund)
	notifyPlayer(state.Player, "Sold " .. character.Name .. " for " .. GameConfig.FormatCash(refund))
	return true
end

-- Conveyor belt: keep fresh brainrots rolling past the shop row; walking into one buys it.
local function spawnConveyorBrainrot()
	for slotIndex, slot in ipairs(WorldBuilder.ConveyorSlots) do
		if conveyorCharacters[slotIndex] == nil then
			local character = BrainrotCatalog.Characters[rng:NextInteger(1, #BrainrotCatalog.Characters)]
			local model = WorldBuilder.BuildBrainrotModel(character, "Normal")
			model:PivotTo(CFrame.new(slot.Position))
			for _, piece in ipairs(model:GetDescendants()) do
				if piece:IsA("BasePart") then
					piece.Anchored = true
				end
			end
			local priceSign = model:FindFirstChild("IncomeLabel", true)
			model.Parent = Workspace
			pcall(function()
				AnimationService.Register(model, {
					Rarity = character.Rarity,
					Mutation = "Normal",
					Spin = character.Rarity == "Mythic" or character.Rarity == "Brainrot God",
				})
			end)
			conveyorCharacters[slotIndex] = { Character = character, Model = model }
			task.delay(GameConfig.ConveyorLifetimeSeconds, function()
				local current = conveyorCharacters[slotIndex]
				if current and current.Model == model then
					conveyorCharacters[slotIndex] = nil
					pcall(function()
						AnimationService.Unregister(model)
					end)
					model:Destroy()
				end
			end)
			-- Touching the belt brainrot buys it, if the walker can pay and has a free pad.
			local body = model:FindFirstChild("Body")
			if body then
				body.Touched:Connect(function(hit)
					local characterModel = hit.Parent
					local humanoid = characterModel and characterModel:FindFirstChildOfClass("Humanoid")
					if not humanoid then
						return
					end
					local player = Players:GetPlayerFromCharacter(characterModel)
					if not player then
						return
					end
					local state = PlayerData.GetState(player)
					if not state then
						return
					end
					if EconomyService.BuyCharacter(state, character.Id) then
						conveyorCharacters[slotIndex] = nil
						pcall(function()
							AnimationService.Unregister(model)
						end)
						model:Destroy()
					end
				end)
			end
			return
		end
	end
end

function EconomyService.StartConveyorLoop()
	task.spawn(function()
		while true do
			spawnConveyorBrainrot()
			task.wait(GameConfig.ConveyorSpawnSeconds)
		end
	end)
end

function EconomyService.StartIncomeTickLoop()
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			for _, state in ipairs(PlayerData.GetAllStates()) do
				local income = EconomyService.GetPlacedIncomePerSecond(state)
				if income > 0 then
					PlayerData.AddCash(state, income)
				end
			end
		end
	end)
end

return EconomyService
