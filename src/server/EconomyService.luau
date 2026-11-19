-- EconomyService.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- the cash engine: the per-second income tick for every
-- placed brainrot, buying from the walking shop belt, hatching eggs with a mutation
-- roll, spinning the premium gacha capsule by the arena, placing a fresh brainrot
-- on a free base pad, selling one back, and the Candy
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

-- The top of the ladder earns the slow spin: Mythic and everything above it
-- (Brainrot God, Cosmic, Transcendent). Decided by ladder position, not by
-- name, so new tiers join automatically.
local function shouldSpin(rarity: string): boolean
	local rarityIndex = table.find(BrainrotCatalog.RarityOrder, rarity)
	local mythicIndex = table.find(BrainrotCatalog.RarityOrder, "Mythic")
	return rarityIndex ~= nil and mythicIndex ~= nil and rarityIndex >= mythicIndex
end

function EconomyService.GetPlacedIncomePerSecond(state: any): number
	local total = 0
	for _, placed in ipairs(state.Placed) do
		local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
		if character then
			total += BrainrotCatalog.GetIncomePerSecond(character, placed.Mutation)
		end
	end
	-- Stacking order: base income x rebirth multiplier x Income X2 boost.
	return math.floor(total * PlayerData.GetIncomeMultiplier(state) * PlayerData.GetIncomeBoostMultiplier(state))
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
			Spin = shouldSpin(character.Rarity),
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
	-- The Lucky Charm boost tilts this player's own hatch: kinder mutation
	-- weights and a rarity roll shifted one notch up the ladder. Belt spawns
	-- are shared and never see these weights.
	local character, mutation
	if PlayerData.HasBoost(state, "Luck") then
		character, mutation = BrainrotCatalog.RollHatch(rng, GameConfig.LuckyHatchRarityWeights, GameConfig.LuckyHatchMutationWeights)
	else
		character, mutation = BrainrotCatalog.RollHatch(rng)
	end
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, character.Id, mutation.Name)
	if placedOk then
		notifyPlayer(state.Player, string.format("The egg hatched %s (%s, %s)!", character.Name, character.Rarity, mutation.Name))
		reportMission(state, "Hatch")
	end
	return placedOk
end

-- GACHA CAPSULE: the premium spin west of the arena. Same shape as HatchEgg
-- (free pad first, cash second, place the winner) but the rarity table in
-- GameConfig starts at Rare and climbs to Transcendent -- no Commons, ever.
-- A spin is NOT a hatch and NOT a buy, so it reports no mission action. The
-- mutation roll is the standard one, bent by the Lucky Charm exactly like
-- the egg's. Pull Brainrot God or better and the whole island hears about it.
local function rollGachaRarity(): string
	local totalWeight = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		totalWeight += GameConfig.GachaRarityWeights[rarity] or 0
	end
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		local weight = GameConfig.GachaRarityWeights[rarity] or 0
		running += weight
		if weight > 0 and roll <= running then
			return rarity
		end
	end
	return "Rare"
end

function EconomyService.RollGacha(state: any): boolean
	if not PlayerData.HasFreePad(state) then
		notifyPlayer(state.Player, "Your base is full! Make room before spinning the capsule.")
		return false
	end
	if not PlayerData.TrySpendCash(state, GameConfig.GachaPrice) then
		notifyPlayer(state.Player, "The Gacha Capsule needs " .. GameConfig.FormatCash(GameConfig.GachaPrice) .. " per spin.")
		return false
	end
	local rarity = rollGachaRarity()
	local pool = BrainrotCatalog.GetCharactersOfRarity(rarity)
	local character = pool[rng:NextInteger(1, #pool)]
	local mutation
	if PlayerData.HasBoost(state, "Luck") then
		mutation = BrainrotCatalog.RollMutation(rng, GameConfig.LuckyHatchMutationWeights)
	else
		mutation = BrainrotCatalog.RollMutation(rng)
	end
	local placedOk = EconomyService.PlaceBrainrotOnPad(state, character.Id, mutation.Name)
	if placedOk then
		local mutationText = if mutation.Name == "Normal" then "" else ", " .. mutation.Name
		notifyPlayer(state.Player, string.format("GACHA: %s [%s]%s!", character.Name, character.Rarity, mutationText))
		-- Jackpot theatre: Brainrot God and above gets announced to everyone else.
		local rarityIndex = table.find(BrainrotCatalog.RarityOrder, character.Rarity)
		local godIndex = table.find(BrainrotCatalog.RarityOrder, "Brainrot God")
		if rarityIndex and godIndex and rarityIndex >= godIndex then
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= state.Player then
					notifyPlayer(otherPlayer, string.format("%s pulled a %s %s from the GACHA CAPSULE!", state.Player.DisplayName, character.Rarity, character.Name))
				end
			end
		end
	end
	return placedOk
end

-- Boosts: the cash sink that replaced the shop panel. Fully server-validated
-- against GameConfig.Boosts: unknown ids are ignored, timed boosts REFRESH
-- their duration on re-buy, and the one-time Wave Shield refuses a second
-- purchase while one is already held.
local function applyBaseWalkSpeed(state: any)
	if state.Carried then
		return
	end
	local character = state.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerData.GetBaseWalkSpeed(state)
	end
end

function EconomyService.BuyBoost(state: any, boostId: string): boolean
	local boost = GameConfig.GetBoostById(boostId)
	if not boost then
		return false
	end
	if boost.OneTime then
		if state.WaveShield then
			notifyPlayer(state.Player, "You already have a Wave Shield — it will save you from the next Big Wave.")
			return false
		end
		if not PlayerData.TrySpendCash(state, boost.Price) then
			notifyPlayer(state.Player, "Not enough cash for " .. boost.Name .. " (" .. GameConfig.FormatCash(boost.Price) .. ")")
			return false
		end
		state.WaveShield = true
		PlayerData.FireStateChanged(state)
		notifyPlayer(state.Player, "WAVE SHIELD ready! The next Big Wave cannot wash you.")
		return true
	end
	if not PlayerData.TrySpendCash(state, boost.Price) then
		notifyPlayer(state.Player, "Not enough cash for " .. boost.Name .. " (" .. GameConfig.FormatCash(boost.Price) .. ")")
		return false
	end
	state.BoostEndsAt[boost.Id] = os.clock() + boost.DurationSeconds
	if boost.Id == "Speed" then
		applyBaseWalkSpeed(state)
	end
	PlayerData.FireStateChanged(state)
	notifyPlayer(state.Player, string.format("%s active for %ds!", boost.Name, boost.DurationSeconds))
	return true
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

-- Walkers alternate between two label heights (5.2 / 6.6 studs) so a full belt
-- reads as two tidy bands of labels instead of one stacked pile.
local beltSpawnCount = 0

local function spawnConveyorBrainrot()
	if beltWalkerCount >= GameConfig.ConveyorMaxOnBelt then
		return
	end
	local character = BrainrotCatalog.Characters[rng:NextInteger(1, #BrainrotCatalog.Characters)]
	beltSpawnCount += 1
	local labelHeight = if beltSpawnCount % 2 == 0 then 5.2 else 6.6
	local model = WorldBuilder.BuildBrainrotModel(character, "Normal", { BuyPrice = character.Price, LabelHeight = labelHeight })
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

-- CANDY ARENA EVENT: every 150 seconds (while anyone is playing) a GOLDEN
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
			Spin = shouldSpin(character.Rarity),
		})
	end)
	notifyAllPlayers("A GOLDEN " .. character.Name .. " appeared in the CANDY ARENA! First to grab it keeps it!")

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
