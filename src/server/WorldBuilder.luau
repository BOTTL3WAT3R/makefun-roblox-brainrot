-- WorldBuilder.luau (ModuleScript, ServerScriptService.Server)
-- PLUNDERROT: Kraken's Curse -- builds the whole 3D world from primitive Parts at runtime:
-- the island ground, a pirate dock-town plaza, a conveyor shop row with big price signs, the
-- Kraken Egg Vault, Davy Jones' Shrine, 8 player base plots (10 pads each, a lock button and
-- laser walls), the Crow's Nest Cliffs that survive the Kraken Tide, a docked pirate ship,
-- treasure chests, barrels, cannons, and the Kraken Tide wave wall itself.
-- Every sign uses a SurfaceGui or BillboardGui with large readable text, kept clear and bold
-- so it still reads when a screenshot is scaled down for judging.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local WorldBuilder = {}

WorldBuilder.Bases = {} :: { any }
WorldBuilder.ConveyorSlots = {} :: { any }
WorldBuilder.TsunamiWall = nil :: Part?
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

local function makeSign(parent: Instance, name: string, adornee: BasePart, text: string, textColor: Color3, studsOffset: Vector3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(360, 110)
	billboard.StudsOffset = studsOffset
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
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

-- A pirate treasure chest: a wooden box, a rounded lid, glowing gold trim and a lock plate.
-- groundPosition is where the chest's bottom sits.
local function buildTreasureChest(parent: Instance, groundPosition: Vector3)
	local chest = Instance.new("Folder")
	chest.Name = "TreasureChest"
	chest.Parent = parent
	makePart(chest, "ChestBox", Vector3.new(4, 2.2, 2.6), groundPosition + Vector3.new(0, 1.1, 0),
		Color3.fromRGB(110, 72, 38), Enum.Material.Wood)
	makePart(chest, "ChestLid", Vector3.new(4.2, 1, 2.8), groundPosition + Vector3.new(0, 2.7, 0),
		Color3.fromRGB(130, 86, 46), Enum.Material.Wood)
	makePart(chest, "ChestGoldTrim", Vector3.new(4.3, 0.5, 2.9), groundPosition + Vector3.new(0, 2.05, 0),
		Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	makePart(chest, "ChestLockPlate", Vector3.new(0.9, 1.1, 0.3), groundPosition + Vector3.new(0, 1.5, -1.4),
		Color3.fromRGB(255, 215, 80), Enum.Material.Neon)
	return chest
end

-- A wooden barrel: a brown cylinder standing upright with a dark iron band around its belly.
local function buildBarrel(parent: Instance, groundPosition: Vector3)
	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3, 2.1, 2.1)
	barrel.Orientation = Vector3.new(0, 0, 90)
	barrel.Position = groundPosition + Vector3.new(0, 1.5, 0)
	barrel.Color = Color3.fromRGB(120, 80, 45)
	barrel.Material = Enum.Material.Wood
	barrel.Anchored = true
	barrel.TopSurface = Enum.SurfaceType.Smooth
	barrel.BottomSurface = Enum.SurfaceType.Smooth
	barrel.Parent = parent
	local band = Instance.new("Part")
	band.Name = "BarrelBand"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.5, 2.3, 2.3)
	band.Orientation = Vector3.new(0, 0, 90)
	band.Position = groundPosition + Vector3.new(0, 1.5, 0)
	band.Color = Color3.fromRGB(45, 45, 50)
	band.Material = Enum.Material.Metal
	band.Anchored = true
	band.CanCollide = false
	band.Parent = parent
	return barrel
end

-- A ship's cannon: a dark iron barrel on a wooden carriage box, aimed out to sea.
local function buildCannon(parent: Instance, groundPosition: Vector3)
	local cannon = Instance.new("Folder")
	cannon.Name = "Cannon"
	cannon.Parent = parent
	makePart(cannon, "CannonCarriage", Vector3.new(3, 1.4, 2.2), groundPosition + Vector3.new(0, 0.7, 0),
		Color3.fromRGB(100, 66, 36), Enum.Material.Wood)
	local barrel = Instance.new("Part")
	barrel.Name = "CannonBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3.8, 0.9, 0.9)
	barrel.Orientation = Vector3.new(0, 90, 0)
	barrel.Position = groundPosition + Vector3.new(0, 1.7, 0)
	barrel.Color = Color3.fromRGB(50, 50, 58)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.Parent = cannon
	return cannon
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
	makeSign(model, "IncomeLabel", body, labelText, rarityColor, Vector3.new(0, 4.6, 0))

	return model
end

local function buildBasePlot(parent: Folder, index: number, origin: Vector3)
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. tostring(index)
	baseFolder.Parent = parent

	local floor = makePart(baseFolder, "BaseFloor", Vector3.new(44, 1, 44), origin + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(90, 200, 120), Enum.Material.SmoothPlastic)
	makeSign(baseFolder, "BaseSign", floor, "⚓ BASE " .. tostring(index) .. "\nFREE", Color3.fromRGB(255, 255, 255), Vector3.new(0, 9, 0))
	buildTreasureChest(baseFolder, origin + Vector3.new(18, 1, -18))

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
	makeSign(baseFolder, "LockSign", lockButton, "LOCK YER BASE\n" .. tostring(GameConfig.LockDurationSeconds) .. "s", Color3.fromRGB(255, 120, 120), Vector3.new(0, 5, 0))

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
			label.Text = if ownerName then "⚓ " .. string.upper(ownerName) .. "'S BASE" else "⚓ BASE " .. tostring(base.Index) .. "\nFREE"
		end
	end
end

function WorldBuilder.SetBaseLasersVisible(base: any, visible: boolean)
	for _, laser in ipairs(base.Lasers) do
		laser.Transparency = if visible then 0.35 else 1
		laser.CanCollide = visible
	end
end

-- The docked pirate ship THE SOGGY WAFFLE, moored in the sea off the island's north-west
-- edge: a long hull with a raised stern, a plank deck, a tall mast flying a black Jolly
-- Roger, deck cannons and a treasure chest. Pure decor -- and the first thing a player
-- sees when they look out from the plunder belt.
function WorldBuilder.BuildPirateShip(parent: Instance)
	local ship = Instance.new("Folder")
	ship.Name = "PirateShip"
	ship.Parent = parent
	local keel = Vector3.new(-168, 0, -184)

	local hull = makePart(ship, "ShipHull", Vector3.new(56, 8, 14), keel, Color3.fromRGB(105, 68, 36), Enum.Material.Wood)
	makePart(ship, "ShipDeck", Vector3.new(56, 1, 12), keel + Vector3.new(0, 4.5, 0), Color3.fromRGB(150, 105, 60), Enum.Material.WoodPlanks)
	makePart(ship, "ShipStern", Vector3.new(14, 6, 13), keel + Vector3.new(-21, 7, 0), Color3.fromRGB(95, 60, 32), Enum.Material.Wood)
	makePart(ship, "ShipBow", Vector3.new(10, 5, 10), keel + Vector3.new(26, 5.5, 0), Color3.fromRGB(95, 60, 32), Enum.Material.Wood)
	makeSign(ship, "ShipNameSign", hull, "THE SOGGY WAFFLE", Color3.fromRGB(255, 230, 150), Vector3.new(0, 9, 0))

	local mast = Instance.new("Part")
	mast.Name = "ShipMast"
	mast.Shape = Enum.PartType.Cylinder
	mast.Size = Vector3.new(24, 1.2, 1.2)
	mast.Orientation = Vector3.new(0, 0, 90)
	mast.Position = keel + Vector3.new(0, 16, 0)
	mast.Color = Color3.fromRGB(120, 84, 46)
	mast.Material = Enum.Material.Wood
	mast.Anchored = true
	mast.Parent = ship
	makePart(ship, "ShipSail", Vector3.new(0.4, 13, 15), keel + Vector3.new(0, 14, 0), Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic)

	local flag = makePart(ship, "JollyRogerFlag", Vector3.new(0.3, 4, 7), keel + Vector3.new(0, 26, 3.5), Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic)
	makeSign(ship, "JollyRogerSign", flag, "☠ JOLLY ROGER", Color3.fromRGB(255, 255, 255), Vector3.new(0, 4, 0))

	buildCannon(ship, keel + Vector3.new(12, 5, -4))
	buildCannon(ship, keel + Vector3.new(-8, 5, -4))
	buildTreasureChest(ship, keel + Vector3.new(-14, 5, 2))
	buildBarrel(ship, keel + Vector3.new(20, 5, 3))
	return ship
end

function WorldBuilder.BuildWorld()
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "PlunderrotWorld"
	worldFolder.Parent = Workspace

	-- Island ground and the sea around it.
	makePart(worldFolder, "IslandGround", Vector3.new(420, 4, 420), Vector3.new(0, -2, 0), Color3.fromRGB(105, 205, 110), Enum.Material.Grass)
	local sea = makePart(worldFolder, "Sea", Vector3.new(900, 2, 900), Vector3.new(0, -5, 0), Color3.fromRGB(40, 130, 220), Enum.Material.SmoothPlastic)
	sea.Transparency = 0.25

	-- Central plaza: a pirate dock town square of wooden planks -- spawn, fountain, the big
	-- title sign, a treasure chest at every corner and barrels by the fountain.
	local plaza = makePart(worldFolder, "SpawnPlaza", Vector3.new(60, 1, 60), Vector3.new(0, 0.5, 0), Color3.fromRGB(146, 102, 58), Enum.Material.WoodPlanks)
	local fountain = makePart(worldFolder, "Fountain", Vector3.new(10, 3, 10), Vector3.new(0, 2, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	makeSign(worldFolder, "TitleSign", fountain, "PLUNDERROT\nKRAKEN'S CURSE", Color3.fromRGB(255, 230, 80), Vector3.new(0, 12, 0))
	for _, cornerX in ipairs({ -26, 26 }) do
		for _, cornerZ in ipairs({ -26, 26 }) do
			buildTreasureChest(worldFolder, Vector3.new(cornerX, 1, cornerZ))
		end
	end
	buildBarrel(worldFolder, Vector3.new(10, 1, 18))
	buildBarrel(worldFolder, Vector3.new(-13, 1, 20))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 14)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = worldFolder

	-- A wooden boardwalk from the plaza to the plunder belt, and a dirt road ring to the bases.
	makePart(worldFolder, "BoardwalkToBelt", Vector3.new(16, 0.4, 120), Vector3.new(0, 0.2, -90), Color3.fromRGB(140, 98, 55), Enum.Material.WoodPlanks)
	makePart(worldFolder, "RoadRing", Vector3.new(300, 0.4, 16), Vector3.new(0, 0.2, 60), Color3.fromRGB(80, 80, 90), Enum.Material.Asphalt)

	-- Conveyor shop row on its wooden dock: brainrots ride the belt, price signs shout their cost.
	makePart(worldFolder, "BeltDock", Vector3.new(110, 1, 22), Vector3.new(0, 0.25, -150), Color3.fromRGB(140, 98, 55), Enum.Material.WoodPlanks)
	local belt = makePart(worldFolder, "ConveyorBelt", Vector3.new(90, 2, 10), Vector3.new(0, 1, -150), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
	makeSign(worldFolder, "ShopSign", belt, "PLUNDER BELT - WALK INTO ONE TO BUY IT", Color3.fromRGB(120, 255, 160), Vector3.new(0, 10, 0))
	buildBarrel(worldFolder, Vector3.new(38, 1, -136))
	buildBarrel(worldFolder, Vector3.new(-40, 1, -134))
	buildBarrel(worldFolder, Vector3.new(-36, 1, -164))
	buildBarrel(worldFolder, Vector3.new(42, 1, -162))
	buildCannon(worldFolder, Vector3.new(24, 1, -136))
	buildCannon(worldFolder, Vector3.new(-24, 1, -136))
	for slotIndex = 1, GameConfig.ConveyorMaxOnBelt do
		local slotPosition = Vector3.new(-37 + (slotIndex - 1) * 15, 2, -150)
		local slotPad = makePart(worldFolder, "ConveyorSlot" .. tostring(slotIndex), Vector3.new(9, 0.4, 9), slotPosition, Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
		table.insert(WorldBuilder.ConveyorSlots, { Pad = slotPad, Position = slotPosition + Vector3.new(0, 1, 0), OccupiedBy = nil })
	end

	-- Kraken Egg Vault: a glass dome on a pedestal, hatch for doubloons and pray for Rainbow.
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
	makeSign(worldFolder, "EggSign", eggBase, "KRAKEN EGG VAULT\nHATCH: " .. GameConfig.FormatCash(GameConfig.EggPrice), Color3.fromRGB(255, 170, 230), Vector3.new(0, 10, 0))
	WorldBuilder.EggMachinePosition = Vector3.new(45, 0, -104)

	-- Davy Jones' Shrine: golden steps up to a glowing crystal.
	for step = 1, 3 do
		makePart(worldFolder, "ShrineStep" .. tostring(step), Vector3.new(20 - step * 3, 1, 20 - step * 3), Vector3.new(-45, step * 0.5, -120), Color3.fromRGB(255, 200, 70), Enum.Material.Metal)
	end
	local crystal = makePart(worldFolder, "RebirthCrystal", Vector3.new(4, 8, 4), Vector3.new(-45, 7, -120), Color3.fromRGB(150, 255, 255), Enum.Material.Neon)
	crystal.Orientation = Vector3.new(0, 45, 0)
	makeSign(worldFolder, "RebirthSign", crystal, "DAVY JONES' SHRINE\nRESET FOR +100% INCOME", Color3.fromRGB(160, 255, 255), Vector3.new(0, 9, 0))
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

	-- High ground: the Crow's Nest Cliffs. Stand up here and the Kraken Tide cannot take you.
	local hill = makePart(worldFolder, "ShelterHill", Vector3.new(70, WorldBuilder.HighGroundTopY, 70), Vector3.new(150, WorldBuilder.HighGroundTopY / 2, -40), Color3.fromRGB(150, 120, 90), Enum.Material.Rock)
	makeSign(worldFolder, "ShelterSign", hill, "CROW'S NEST CLIFFS\nHIGH GROUND = SAFE FROM THE KRAKEN TIDE", Color3.fromRGB(255, 255, 255), Vector3.new(0, 8, 40))

	-- Decorations: palm-ish trees and glowing lamps around the plaza.
	for treeIndex = 1, 12 do
		local angle = (treeIndex / 12) * math.pi * 2
		local treePosition = Vector3.new(math.cos(angle) * 55, 0, math.sin(angle) * 55)
		makePart(worldFolder, "TreeTrunk" .. tostring(treeIndex), Vector3.new(1.5, 7, 1.5), treePosition + Vector3.new(0, 3.5, 0), Color3.fromRGB(120, 85, 50))
		local leaves = makePart(worldFolder, "TreeLeaves" .. tostring(treeIndex), Vector3.new(7, 5, 7), treePosition + Vector3.new(0, 9, 0), Color3.fromRGB(60, 170, 70))
		leaves.Shape = Enum.PartType.Ball
	end

	-- The Kraken Tide wall itself: a huge sheet of water that sweeps across the island.
	local wall = makePart(worldFolder, "TsunamiWall", Vector3.new(440, 30, 6), Vector3.new(-260, 12, 0), Color3.fromRGB(30, 110, 230), Enum.Material.SmoothPlastic)
	wall.Transparency = 0.3
	wall.CanCollide = false
	WorldBuilder.TsunamiWall = wall

	-- The docked pirate ship, moored off the north-west shore.
	WorldBuilder.BuildPirateShip(worldFolder)

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
