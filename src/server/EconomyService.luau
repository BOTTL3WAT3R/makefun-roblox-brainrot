-- EconomyService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the cash engine: the per-second income tick for every
-- placed brainrot, buying from the walking shop belt, hatching eggs with a mutation
-- roll, placing a fresh brainrot on a free base pad, selling one back, and the Neon
-- Arena event that drops a golden brainrot on the spawn ring every few minutes.
-- Every model it spawns is handed to AnimationService so it bobs (and spins /
-- sparkles when rare).

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

local function notifyAllPlayers(message: string)
	for _, player in ipairs(Players:GetPlayers()) do
		notifyPlayer(player, message)
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
		reportMission(state, "Buy")
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
		reportMission(state, "Hatch")
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

-- Conveyor belt: brainrots WALK the belt from the west end to the east end,
-- like the big steal-a-brainrot games. Walking into one mid-stride buys it;
-- reaching the far end unclaimed despawns it. Travel time is the lifetime.
local BELT_Z = -20
local BELT_Y = 2
local BELT_START_X = -80
local BELT_END_X = 80
local BELT_WALK_SPEED = 6

local beltWalkers: { [Model]: { Character: any, Model: Model } } = {}
local beltWalkerCount = 0

local function removeBeltWalker(model: Model)
	if beltWalkers[model] then
		beltWalkers[model] = nil
		beltWalkerCount -= 1
	end
end

-- A small bright price tag under the walker's name label: the reference games
-- shout the buy price, so a passing brainrot can be judged at a glance. It is a
-- child of the model, so it walks, bobs and despawns with it for free.
local function attachPriceTag(model: Model, character: any)
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "PriceTag"
	tag.Adornee = body
	tag.Size = UDim2.fromOffset(220, 54)
	tag.StudsOffset = Vector3.new(0, 3.1, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Name = "PriceText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(10, 40, 16)
	label.Text = "BUY " .. GameConfig.FormatCash(character.Price)
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = tag
	tag.Parent = model
end

local function spawnConveyorBrainrot()
	if beltWalkerCount >= GameConfig.ConveyorMaxOnBelt then
		return
	end
	local character = BrainrotCatalog.Characters[rng:NextInteger(1, #BrainrotCatalog.Characters)]
	local model = WorldBuilder.BuildBrainrotModel(character, "Normal")
	attachPriceTag(model, character)
	model:PivotTo(CFrame.new(Vector3.new(BELT_START_X, BELT_Y, BELT_Z)) * CFrame.Angles(0, math.rad(-90), 0))
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	model.Parent = Workspace
	beltWalkers[model] = { Character = character, Model = model }
	beltWalkerCount += 1
	pcall(function()
		AnimationService.RegisterWalker(model, {
			Speed = BELT_WALK_SPEED,
			EndX = BELT_END_X,
			Rarity = character.Rarity,
			Mutation = "Normal",
			OnArrive = function(arrivedModel: Model)
				removeBeltWalker(arrivedModel)
				arrivedModel:Destroy()
			end,
		})
	end)
	-- Touching the walking brainrot buys it, if the player can pay and has a free pad.
	local body = model:FindFirstChild("Body")
	if body then
		body.Touched:Connect(function(hit)
			if not beltWalkers[model] then
				return
			end
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
				removeBeltWalker(model)
				pcall(function()
					AnimationService.Unregister(model)
				end)
				model:Destroy()
			end
		end)
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

-- NEON ARENA EVENT: every 150 seconds (while anyone is playing) a GOLDEN
-- brainrot -- a random Epic-or-higher character wearing the Gold mutation --
-- appears on the arena ring under a beam of golden light. It is touch-driven
-- like belt buying: the first player to grab it keeps it on a free base pad.
-- Unclaimed, it fades after 30 seconds. No remotes, all server-side.
local ARENA_EVENT_PERIOD_SECONDS = 150
local ARENA_CLAIM_WINDOW_SECONDS = 30

local arenaEventActive = false

local function spawnArenaBrainrot()
	if arenaEventActive then
		return
	end
	local pool = {}
	for _, character in ipairs(BrainrotCatalog.Characters) do
		local rarityIndex = table.find(BrainrotCatalog.RarityOrder, character.Rarity)
		local epicIndex = table.find(BrainrotCatalog.RarityOrder, "Epic")
		if rarityIndex and epicIndex and rarityIndex >= epicIndex then
			table.insert(pool, character)
		end
	end
	if #pool == 0 then
		return
	end
	local character = pool[rng:NextInteger(1, #pool)]
	local arenaPosition = WorldBuilder.ArenaPosition or Vector3.new(0, 0, 28)

	local model = WorldBuilder.BuildBrainrotModel(character, "Gold")
	model:PivotTo(CFrame.new(arenaPosition + Vector3.new(0, 1.2, 0)))
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	model.Parent = Workspace

	-- The beacon: a translucent gold beam into the sky with a PointLight at its
	-- heart, visible from every base on the island.
	local beam = Instance.new("Part")
	beam.Name = "ArenaBeacon"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 3.5, 3.5)
	beam.Orientation = Vector3.new(0, 0, 90)
	beam.Position = arenaPosition + Vector3.new(0, 30, 0)
	beam.Color = Color3.fromRGB(255, 205, 60)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 60)
	light.Range = 26
	light.Brightness = 3
	light.Parent = beam

	arenaEventActive = true
	pcall(function()
		AnimationService.Register(model, {
			Rarity = character.Rarity,
			Mutation = "Gold",
			Spin = character.Rarity == "Mythic" or character.Rarity == "Brainrot God",
		})
	end)
	notifyAllPlayers("A GOLDEN " .. character.Name .. " appeared in the NEON ARENA! First to grab it keeps it!")

	local claimed = false
	local function cleanup()
		pcall(function()
			AnimationService.Unregister(model)
		end)
		if model.Parent then
			model:Destroy()
		end
		if beam.Parent then
			beam:Destroy()
		end
		arenaEventActive = false
	end

	local body = model:FindFirstChild("Body")
	if body then
		body.Touched:Connect(function(hit)
			if claimed or not arenaEventActive then
				return
			end
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
			if not PlayerData.HasFreePad(state) then
				notifyPlayer(player, "Your base is full! The golden brainrot stays in the arena.")
				return
			end
			claimed = true
			local placedOk = EconomyService.PlaceBrainrotOnPad(state, character.Id, "Gold")
			cleanup()
			if placedOk then
				notifyPlayer(player, "You grabbed the GOLDEN " .. character.Name .. "! It shines at your base.")
			end
		end)
	end

	task.delay(ARENA_CLAIM_WINDOW_SECONDS, function()
		if arenaEventActive and not claimed then
			cleanup()
		end
	end)
end

function EconomyService.StartArenaEventLoop()
	task.spawn(function()
		while true do
			task.wait(ARENA_EVENT_PERIOD_SECONDS)
			if #Players:GetPlayers() > 0 then
				pcall(spawnArenaBrainrot)
			end
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
