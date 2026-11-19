-- WorldBuilder.luau (ModuleScript, ServerScriptService.Server)
-- Brainrot Island -- builds the whole 3D world from primitive Parts at runtime, kept
-- deliberately simple and readable like the big tycoon games: one flat toybox island,
-- one strong colour per zone (orange belt, pink egg, gold shrine, green hill), big
-- short signs, and nothing else competing for the eye. All the motion lives on the
-- brainrots themselves (see AnimationService).
-- Every sign uses a BillboardGui with large readable text, and MaxDistance is kept
-- short so signs never pile up across the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local WorldBuilder = {}

WorldBuilder.Bases = {} :: { any }
WorldBuilder.ConveyorSlots = {} :: { any }
WorldBuilder.TsunamiWall = nil :: Part?
WorldBuilder.TsunamiFoam = nil :: Part?
WorldBuilder.HighGroundTopY = 26

local BASE_SPACING = 95
local PADS_PER_BASE = GameConfig.MaxPlacedPerBase

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if material then
		part.Material = material
	end
	part.Parent = parent
	return part
end

local function makeSign(parent: Instance, name: string, adornee: BasePart, text: string, textColor: Color3, studsOffset: Vector3, maxDistance: number?)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(360, 110)
	billboard.StudsOffset = studsOffset
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = maxDistance or 100
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard
	billboard.Parent = parent
	return billboard
end

local function makeFaceSign(part: Part, text: string, textColor: Color3)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "FaceSign"
	surface.Face = Enum.NormalId.Front
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "FaceSignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = surface
	return surface
end

-- Builds one brainrot character model from its catalog recipe: body, head, eyes and one
-- accessory, plus a floating label with its name, rarity and income per second.
function WorldBuilder.BuildBrainrotModel(character: any, mutationName: string): Model
	local model = Instance.new("Model")
	model.Name = character.Id

	local bodyColor = Color3.fromRGB(character.BodyColor[1], character.BodyColor[2], character.BodyColor[3])
	local headColor = Color3.fromRGB(character.HeadColor[1], character.HeadColor[2], character.HeadColor[3])
	local accessoryColor = Color3.fromRGB(character.AccessoryColor[1], character.AccessoryColor[2], character.AccessoryColor[3])
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		if mutation.Name == mutationName and mutation.Tint then
			bodyColor = mutation.Tint
			headColor = mutation.Tint
		end
	end

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3, 2.4)
	body.Position = Vector3.new(0, 1.5, 0)
	body.Color = bodyColor
	body.Anchored = false
	body.CanCollide = false
	if character.BodyShape == "Ball" then
		body.Shape = Enum.PartType.Ball
	elseif character.BodyShape == "Cylinder" then
		body.Shape = Enum.PartType.Cylinder
		body.Orientation = Vector3.new(0, 0, 90)
	end
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1.8, 2)
	head.Position = Vector3.new(0, 3.9, 0)
	head.Color = headColor
	head.CanCollide = false
	head.Parent = model

	local eyeColor = Color3.fromRGB(15, 15, 20)
	for _, x in ipairs({ -0.5, 0.5 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.35, 0.35, 0.35)
		eye.Position = Vector3.new(x, 4.1, -1.05)
		eye.Color = eyeColor
		eye.CanCollide = false
		eye.Parent = model
	end

	local accessory = Instance.new("Part")
	accessory.Name = "Accessory"
	accessory.CanCollide = false
	if character.Accessory == "Cap" then
		accessory.Size = Vector3.new(2.3, 0.4, 2.3)
		accessory.Position = Vector3.new(0, 4.95, 0)
		accessory.Color = accessoryColor
	elseif character.Accessory == "Horns" then
		accessory.Size = Vector3.new(2.6, 1, 0.5)
		accessory.Position = Vector3.new(0, 5, 0)
		accessory.Color = accessoryColor
	elseif character.Accessory == "Crown" then
		accessory.Size = Vector3.new(1.8, 0.9, 1.8)
		accessory.Position = Vector3.new(0, 5.2, 0)
		accessory.Color = accessoryColor
		accessory.Material = Enum.Material.Neon
	elseif character.Accessory == "Antenna" then
		accessory.Size = Vector3.new(0.25, 1.4, 0.25)
		accessory.Position = Vector3.new(0, 5.4, 0)
		accessory.Color = accessoryColor
		accessory.Material = Enum.Material.Neon
	elseif character.Accessory == "Mohawk" then
		accessory.Size = Vector3.new(0.5, 1, 2.2)
		accessory.Position = Vector3.new(0, 5.1, 0)
		accessory.Color = accessoryColor
	elseif character.Accessory == "Halo" then
		accessory.Shape = Enum.PartType.Cylinder
		accessory.Size = Vector3.new(0.25, 2.2, 2.2)
		accessory.Position = Vector3.new(0, 5.5, 0)
		accessory.Color = accessoryColor
		accessory.Material = Enum.Material.Neon
	else
		accessory.Size = Vector3.new(0.1, 0.1, 0.1)
		accessory.Position = Vector3.new(0, 5, 0)
		accessory.Transparency = 1
	end
	accessory.Parent = model

	-- Weld the pieces together so the model moves as one character.
	for _, piece in ipairs(model:GetChildren()) do
		if piece:IsA("BasePart") and piece ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = piece
			weld.Parent = body
		end
	end
	model.PrimaryPart = body

	local income = BrainrotCatalog.GetIncomePerSecond(character, mutationName)
	local mutationText = if mutationName == "Normal" then "" else " " .. string.upper(mutationName)
	local labelText = string.format("%s%s\n%s - $%d/s", character.Name, mutationText, character.Rarity, income)
	local rarityColor = BrainrotCatalog.RarityColors[character.Rarity] or Color3.fromRGB(255, 255, 255)
	makeSign(model, "IncomeLabel", body, labelText, rarityColor, Vector3.new(0, 4.6, 0), 90)

	return model
end

local function buildBasePlot(parent: Folder, index: number, origin: Vector3)
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. tostring(index)
	baseFolder.Parent = parent

	local floor = makePart(baseFolder, "BaseFloor", Vector3.new(44, 1, 44), origin + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(90, 200, 120), Enum.Material.SmoothPlastic)
	makeSign(baseFolder, "BaseSign", floor, "BASE " .. tostring(index) .. "\nFREE", Color3.fromRGB(255, 255, 255), Vector3.new(0, 9, 0))

	local pads = {}
	for padIndex = 1, PADS_PER_BASE do
		local column = (padIndex - 1) % 5
		local row = math.floor((padIndex - 1) / 5)
		local padPosition = origin + Vector3.new(-16 + column * 8, 1.2, -8 + row * 14)
		local pad = makePart(baseFolder, "Pad" .. tostring(padIndex), Vector3.new(6, 0.4, 6), padPosition,
			Color3.fromRGB(70, 70, 90), Enum.Material.Neon)
		table.insert(pads, pad)
	end

	local lockButton = makePart(baseFolder, "LockButton", Vector3.new(5, 1, 5), origin + Vector3.new(18, 1.5, 18),
		Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
	makeSign(baseFolder, "LockSign", lockButton, "LOCK BASE\n" .. tostring(GameConfig.LockDurationSeconds) .. "s", Color3.fromRGB(255, 120, 120), Vector3.new(0, 5, 0))

	local lasers = {}
	for side = 1, 4 do
		local angle = (side - 1) * math.pi / 2
		local offset = Vector3.new(math.sin(angle) * 22, 3, math.cos(angle) * 22)
		local laser = makePart(baseFolder, "LaserWall" .. tostring(side), Vector3.new(44, 5, 0.6), origin + offset,
			Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		laser.Orientation = Vector3.new(0, math.deg(angle), 0)
		laser.Transparency = 1
		laser.CanCollide = false
		table.insert(lasers, laser)
	end

	local record = { Index = index, Folder = baseFolder, Floor = floor, Pads = pads, LockButton = lockButton, Lasers = lasers, Origin = origin, Owner = nil :: Player? }
	table.insert(WorldBuilder.Bases, record)
	return record
end

function WorldBuilder.SetBaseOwnerSign(base: any, ownerName: string?)
	local sign = base.Folder:FindFirstChild("BaseSign")
	if sign then
		local label = sign:FindFirstChild("SignText")
		if label then
			label.Text = if ownerName then string.upper(ownerName) .. "'S BASE" else "BASE " .. tostring(base.Index) .. "\nFREE"
		end
	end
end

function WorldBuilder.SetBaseLasersVisible(base: any, visible: boolean)
	for _, laser in ipairs(base.Lasers) do
		laser.Transparency = if visible then 0.35 else 1
		laser.CanCollide = visible
	end
end

function WorldBuilder.BuildWorld()
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "BrainrotIslandWorld"
	worldFolder.Parent = Workspace

	-- Island: a grass top on a slightly wider sand rim, floating in a calm sea.
	-- The sand rim's top sits just below the grass top, so the island edge reads
	-- as a beach from any camera angle.
	makePart(worldFolder, "IslandSandRim", Vector3.new(436, 4, 436), Vector3.new(0, -2.25, 0), Color3.fromRGB(240, 220, 160), Enum.Material.Sand)
	makePart(worldFolder, "IslandGround", Vector3.new(420, 4, 420), Vector3.new(0, -2, 0), Color3.fromRGB(105, 205, 110), Enum.Material.Grass)
	local sea = makePart(worldFolder, "Sea", Vector3.new(900, 2, 900), Vector3.new(0, -5, 0), Color3.fromRGB(40, 130, 220), Enum.Material.SmoothPlastic)
	sea.Transparency = 0.25

	-- Central plaza: clean pale paving, the fountain and one big title sign.
	local plaza = makePart(worldFolder, "SpawnPlaza", Vector3.new(60, 1, 60), Vector3.new(0, 0.5, 0), Color3.fromRGB(232, 228, 220), Enum.Material.Concrete)
	local fountain = makePart(worldFolder, "Fountain", Vector3.new(10, 3, 10), Vector3.new(0, 2, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	makeSign(worldFolder, "TitleSign", fountain, "BRAINROT ISLAND", Color3.fromRGB(255, 230, 80), Vector3.new(0, 12, 0))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 14)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = worldFolder

	-- One pale path from the plaza to the belt, one road ring to the bases.
	makePart(worldFolder, "PathToBelt", Vector3.new(16, 0.4, 120), Vector3.new(0, 0.2, -90), Color3.fromRGB(226, 222, 214), Enum.Material.Concrete)
	makePart(worldFolder, "RoadRing", Vector3.new(300, 0.4, 16), Vector3.new(0, 0.2, 60), Color3.fromRGB(80, 80, 90), Enum.Material.Asphalt)

	-- ORANGE ZONE: the shop belt. Brainrots ride it, big sign, chase-light pads.
	makePart(worldFolder, "BeltPlatform", Vector3.new(110, 1, 22), Vector3.new(0, 0.25, -150), Color3.fromRGB(255, 150, 60), Enum.Material.SmoothPlastic)
	local belt = makePart(worldFolder, "ConveyorBelt", Vector3.new(90, 2, 10), Vector3.new(0, 1, -150), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
	makeSign(worldFolder, "ShopSign", belt, "SHOP BELT - WALK IN TO BUY", Color3.fromRGB(120, 255, 160), Vector3.new(0, 10, 0))
	for slotIndex = 1, GameConfig.ConveyorMaxOnBelt do
		local slotPosition = Vector3.new(-37 + (slotIndex - 1) * 15, 2, -150)
		local slotPad = makePart(worldFolder, "ConveyorSlot" .. tostring(slotIndex), Vector3.new(9, 0.4, 9), slotPosition, Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		table.insert(WorldBuilder.ConveyorSlots, { Pad = slotPad, Position = slotPosition + Vector3.new(0, 1, 0), OccupiedBy = nil })
	end

	-- PINK ZONE: the egg machine, a glass dome on a pink pedestal.
	local eggBase = makePart(worldFolder, "EggMachineBase", Vector3.new(12, 4, 12), Vector3.new(45, 2, -120), Color3.fromRGB(255, 120, 200), Enum.Material.Neon)
	local eggDome = Instance.new("Part")
	eggDome.Name = "EggDome"
	eggDome.Shape = Enum.PartType.Ball
	eggDome.Size = Vector3.new(8, 8, 8)
	eggDome.Position = Vector3.new(45, 8, -120)
	eggDome.Color = Color3.fromRGB(255, 240, 250)
	eggDome.Transparency = 0.3
	eggDome.Anchored = true
	eggDome.CanCollide = false
	eggDome.Parent = worldFolder
	makeSign(worldFolder, "EggSign", eggBase, "EGG MACHINE\nHATCH: " .. GameConfig.FormatCash(GameConfig.EggPrice), Color3.fromRGB(255, 170, 230), Vector3.new(0, 10, 0))
	WorldBuilder.EggMachinePosition = Vector3.new(45, 0, -104)

	-- GOLD ZONE: the rebirth shrine, golden steps up to a glowing crystal.
	for step = 1, 3 do
		makePart(worldFolder, "ShrineStep" .. tostring(step), Vector3.new(20 - step * 3, 1, 20 - step * 3), Vector3.new(-45, step * 0.5, -120), Color3.fromRGB(255, 200, 70), Enum.Material.Metal)
	end
	local crystal = makePart(worldFolder, "RebirthCrystal", Vector3.new(4, 8, 4), Vector3.new(-45, 7, -120), Color3.fromRGB(150, 255, 255), Enum.Material.Neon)
	crystal.Orientation = Vector3.new(0, 45, 0)
	makeSign(worldFolder, "RebirthSign", crystal, "REBIRTH SHRINE\nRESET FOR +100% INCOME", Color3.fromRGB(160, 255, 255), Vector3.new(0, 9, 0))
	WorldBuilder.RebirthShrinePosition = Vector3.new(-45, 0, -104)

	-- Eight base plots in two rows.
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = worldFolder
	for index = 1, GameConfig.BaseCount do
		local column = (index - 1) % 4
		local row = math.floor((index - 1) / 4)
		local origin = Vector3.new(-142 + column * BASE_SPACING, 0, 110 + row * BASE_SPACING)
		buildBasePlot(basesFolder, index, origin)
	end

	-- GREEN ZONE: the high hill. Stand up here and the Big Wave cannot take you.
	local hill = makePart(worldFolder, "ShelterHill", Vector3.new(70, WorldBuilder.HighGroundTopY, 70), Vector3.new(150, WorldBuilder.HighGroundTopY / 2, -40), Color3.fromRGB(105, 205, 110), Enum.Material.Grass)
	makeSign(worldFolder, "ShelterSign", hill, "HIGH HILL\nSAFE FROM THE BIG WAVE", Color3.fromRGB(255, 255, 255), Vector3.new(0, 8, 40))

	-- A ring of simple round trees around the plaza, nothing more.
	for treeIndex = 1, 12 do
		local angle = (treeIndex / 12) * math.pi * 2
		local treePosition = Vector3.new(math.cos(angle) * 55, 0, math.sin(angle) * 55)
		makePart(worldFolder, "TreeTrunk" .. tostring(treeIndex), Vector3.new(1.5, 7, 1.5), treePosition + Vector3.new(0, 3.5, 0), Color3.fromRGB(120, 85, 50))
		local leaves = makePart(worldFolder, "TreeLeaves" .. tostring(treeIndex), Vector3.new(7, 5, 7), treePosition + Vector3.new(0, 9, 0), Color3.fromRGB(60, 170, 70))
		leaves.Shape = Enum.PartType.Ball
	end

	-- The Big Wave wall itself: a huge sheet of water with a white foam crest,
	-- tweened smoothly across the island by TsunamiService.
	local wall = makePart(worldFolder, "TsunamiWall", Vector3.new(440, 30, 6), Vector3.new(-260, 12, 0), Color3.fromRGB(30, 110, 230), Enum.Material.SmoothPlastic)
	wall.Transparency = 0.3
	wall.CanCollide = false
	WorldBuilder.TsunamiWall = wall
	local foam = makePart(worldFolder, "TsunamiFoam", Vector3.new(440, 3, 6.6), Vector3.new(-260, 28.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	foam.Transparency = 0.15
	foam.CanCollide = false
	WorldBuilder.TsunamiFoam = foam

	return worldFolder
end

function WorldBuilder.GetFreeBase(): any?
	for _, base in ipairs(WorldBuilder.Bases) do
		if base.Owner == nil then
			return base
		end
	end
	return nil
end

function WorldBuilder.GetBaseByIndex(index: number): any?
	for _, base in ipairs(WorldBuilder.Bases) do
		if base.Index == index then
			return base
		end
	end
	return nil
end

return WorldBuilder
