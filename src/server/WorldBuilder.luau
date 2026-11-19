-- WorldBuilder.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- builds the whole 3D world from primitive Parts at runtime: a compact
-- candy island at bright midday (see the Lighting setup in Main.server) laid out like
-- the big steal-a-brainrot games: ONE long conveyor spine through the middle with the
-- eight player bases flanking it on both sides, the Candy Arena (spawn) just
-- south of the belt, the Egg Machine and Rebirth Shrine capping the belt's two ends,
-- the Fuse Machine and the premium Gacha Capsule flanking the arena east and west,
-- all on pastel pink frosting ground with a chocolate shelter hill. Candy zone colours
-- throughout (chocolate belt, pink egg, caramel shrine, lavender fuse), lollipop trees,
-- candy-cane poles, gumdrops and sprinkles, and one pastel candy colour per player
-- base. Big short signs, and all the motion lives on the brainrots (see AnimationService).
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
WorldBuilder.Playground = nil :: any
WorldBuilder.TsunamiWall = nil :: Part?
WorldBuilder.TsunamiFoam = nil :: Part?
WorldBuilder.HighGroundTopY = 26

local BASE_SPACING = 64
local PADS_PER_BASE = GameConfig.MaxPlacedPerBase

-- One pastel candy colour per base slot: pads and floor trim wear it, so every
-- base reads as its own sweet territory in a screenshot.
local BASE_SLOT_COLORS = {
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(255, 190, 130),
	Color3.fromRGB(255, 235, 130),
	Color3.fromRGB(150, 240, 180),
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(195, 160, 255),
	Color3.fromRGB(235, 160, 255),
	Color3.fromRGB(255, 130, 160),
}

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
-- labelOptions is for belt walkers only: BuyPrice merges a green BUY line into the
-- SAME billboard (a second stacked billboard per walker piled up unreadably), and
-- LabelHeight staggers neighbouring walkers' labels into two bands. Placed
-- brainrots pass nil and keep the plain two-line label.
function WorldBuilder.BuildBrainrotModel(character: any, mutationName: string, labelOptions: { BuyPrice: number?, LabelHeight: number? }?): Model
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
	local rarityColor = BrainrotCatalog.RarityColors[character.Rarity] or Color3.fromRGB(255, 255, 255)
	local buyPrice = labelOptions and labelOptions.BuyPrice
	if buyPrice then
		-- Walker label: three lines in ONE billboard -- name, rarity/income, and the
		-- buy price in bright green via RichText (the rest keeps the rarity colour).
		local labelText = string.format(
			"%s%s\n%s - $%d/s\n<font color=\"rgb(120, 255, 140)\">BUY %s</font>",
			character.Name, mutationText, character.Rarity, income, GameConfig.FormatCash(buyPrice)
		)
		local walkerLabel = makeSign(model, "IncomeLabel", body, labelText, rarityColor,
			Vector3.new(0, (labelOptions and labelOptions.LabelHeight) or 5.2, 0), 60)
		walkerLabel.Size = UDim2.fromOffset(280, 120)
		local walkerText = walkerLabel:FindFirstChild("SignText")
		if walkerText then
			walkerText.RichText = true
		end
	else
		-- Placed label: two clean lines (name, then rarity and income) that stay
		-- readable without piling onto the next brainrot.
		local labelText = string.format("%s%s\n%s - $%d/s", character.Name, mutationText, character.Rarity, income)
		local incomeLabel = makeSign(model, "IncomeLabel", body, labelText, rarityColor, Vector3.new(0, 5.2, 0), 90)
		incomeLabel.Size = UDim2.fromOffset(300, 92)
	end

	return model
end

-- facing is +1 when the base's front (pad rows, lock button) looks toward +Z and
-- -1 when it looks toward -Z: the north row faces the belt to its south, the south
-- row faces the belt to its north, so every front door opens onto the conveyor.
local function buildBasePlot(parent: Folder, index: number, origin: Vector3, facing: number)
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. tostring(index)
	baseFolder.Parent = parent

	local slotColor = BASE_SLOT_COLORS[((index - 1) % #BASE_SLOT_COLORS) + 1]
	local floor = makePart(baseFolder, "BaseFloor", Vector3.new(44, 1, 44), origin + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(255, 244, 230), Enum.Material.SmoothPlastic)
	-- Candy trim ring around the floor, in the base's slot colour.
	makePart(baseFolder, "TrimN", Vector3.new(44, 0.3, 1.2), origin + Vector3.new(0, 1.05, -21.4), slotColor, Enum.Material.Neon)
	makePart(baseFolder, "TrimS", Vector3.new(44, 0.3, 1.2), origin + Vector3.new(0, 1.05, 21.4), slotColor, Enum.Material.Neon)
	makePart(baseFolder, "TrimE", Vector3.new(1.2, 0.3, 44), origin + Vector3.new(21.4, 1.05, 0), slotColor, Enum.Material.Neon)
	makePart(baseFolder, "TrimW", Vector3.new(1.2, 0.3, 44), origin + Vector3.new(-21.4, 1.05, 0), slotColor, Enum.Material.Neon)
	makeSign(baseFolder, "BaseSign", floor, "BASE " .. tostring(index) .. "\nFREE", Color3.fromRGB(255, 255, 255), Vector3.new(0, 9, 0))

	local pads = {}
	for padIndex = 1, PADS_PER_BASE do
		local column = (padIndex - 1) % 5
		local row = math.floor((padIndex - 1) / 5)
		local padPosition = origin + Vector3.new(-16 + column * 8, 1.2, facing * (-8 + row * 14))
		local pad = makePart(baseFolder, "Pad" .. tostring(padIndex), Vector3.new(6, 0.4, 6), padPosition,
			slotColor, Enum.Material.Neon)
		table.insert(pads, pad)
	end

	local lockButton = makePart(baseFolder, "LockButton", Vector3.new(5, 1, 5), origin + Vector3.new(18, 1.5, facing * 18),
		Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
	makeSign(baseFolder, "LockSign", lockButton, "LOCK BASE\n" .. tostring(GameConfig.LockDurationSeconds) .. "s", Color3.fromRGB(255, 90, 110), Vector3.new(0, 5, 0))

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

	local record = { Index = index, Folder = baseFolder, Floor = floor, Pads = pads, LockButton = lockButton, Lasers = lasers, Origin = origin, Facing = facing, Owner = nil :: Player? }
	table.insert(WorldBuilder.Bases, record)
	return record
end

-- The base billboard: owner's name on top (or "BASE n / FREE" while unowned),
-- and while the base is locked a second line counts the lock down, so a lock
-- is visible from across the island and not just on the owner's HUD.
function WorldBuilder.RefreshBaseSign(base: any, lockSecondsLeft: number?)
	local sign = base.Folder:FindFirstChild("BaseSign")
	if not sign then
		return
	end
	local label = sign:FindFirstChild("SignText")
	if not label then
		return
	end
	local ownerName = base.OwnerName
	local topLine = if ownerName then string.upper(ownerName) .. "'S BASE" else "BASE " .. tostring(base.Index)
	if lockSecondsLeft then
		label.Text = topLine .. "\nLOCKED " .. tostring(lockSecondsLeft) .. "s"
	elseif ownerName then
		label.Text = topLine
	else
		label.Text = topLine .. "\nFREE"
	end
end

function WorldBuilder.SetBaseOwnerSign(base: any, ownerName: string?)
	base.OwnerName = ownerName
	WorldBuilder.RefreshBaseSign(base, nil)
end

function WorldBuilder.SetBaseLasersVisible(base: any, visible: boolean)
	for _, laser in ipairs(base.Lasers) do
		laser.Transparency = if visible then 0.35 else 1
		laser.CanCollide = visible
	end
end

-- The walkable ground height at a spot, derived from the geometry BuildWorld
-- itself creates: the shelter hill's cap is the highest surface, then the
-- island top (y 0), then the sand rim whose top sits just below it. Decor
-- placed anywhere on the island snaps its base to this instead of assuming
-- flat y 0 ground.
local function groundHeightAt(x: number, z: number): number
	if math.abs(x) <= 28.3 and z >= 103.7 and z <= 124.3 then
		return WorldBuilder.HighGroundTopY + 0.9
	end
	if math.abs(x) <= 130 and math.abs(z) <= 130 then
		return 0
	end
	if math.abs(x) <= 138 and math.abs(z) <= 138 then
		return -0.25
	end
	return 0
end

-- One palm tree: a slightly tilted cylinder trunk, six flat leaves fanned from the
-- top, and (on some palms) a glowing candy "glowfruit" sphere hanging by the crown.
-- The trunk's base is snapped to the ground height at its spot, and the cylinder
-- is built the way every other cylinder in this file is: its length runs along
-- its X axis (Size 10 long, 1.3 thick), stood upright with an 83-degree Z
-- rotation -- a 7-degree lean -- and centred halfway up the lean, so its foot
-- lands exactly on the ground point and its top meets the crown.
local function buildPalm(parent: Folder, name: string, position: Vector3, withGlowfruit: boolean, glowColor: Color3)
	local base = Vector3.new(position.X, groundHeightAt(position.X, position.Z), position.Z)
	local trunk = Instance.new("Part")
	trunk.Name = name .. "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(10, 1.3, 1.3)
	trunk.Color = Color3.fromRGB(130, 92, 55)
	trunk.Anchored = true
	trunk.TopSurface = Enum.SurfaceType.Smooth
	trunk.BottomSurface = Enum.SurfaceType.Smooth
	trunk.CFrame = CFrame.new(base + Vector3.new(0.61, 4.96, 0)) * CFrame.Angles(0, 0, math.rad(83))
	trunk.Parent = parent
	local crownTop = base + Vector3.new(1.22, 9.93, 0)
	for leafIndex = 1, 6 do
		local leaf = Instance.new("Part")
		leaf.Name = name .. "Leaf" .. tostring(leafIndex)
		leaf.Size = Vector3.new(7, 0.3, 1.8)
		leaf.Color = Color3.fromRGB(52, 165, 70)
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.TopSurface = Enum.SurfaceType.Smooth
		leaf.BottomSurface = Enum.SurfaceType.Smooth
		leaf.CFrame = CFrame.new(crownTop)
			* CFrame.Angles(0, math.rad((leafIndex - 1) * 60), 0)
			* CFrame.Angles(0, 0, math.rad(-26))
			* CFrame.new(3.1, 0, 0)
		leaf.Parent = parent
	end
	if withGlowfruit then
		local fruit = Instance.new("Part")
		fruit.Name = name .. "Glowfruit"
		fruit.Shape = Enum.PartType.Ball
		fruit.Size = Vector3.new(1.5, 1.5, 1.5)
		fruit.Color = glowColor
		fruit.Material = Enum.Material.Neon
		fruit.Anchored = true
		fruit.CanCollide = false
		fruit.Position = crownTop + Vector3.new(0.9, -1, 0.4)
		fruit.Parent = parent
	end
end

-- A bench with a real Seat, built as a small model turned to face a target
-- point: whoever sits down looks at whatever the bench faces (the arena ring).
local function buildBench(parent: Folder, name: string, position: Vector3, faceTarget: Vector3)
	local bench = Instance.new("Model")
	bench.Name = name
	bench.Parent = parent
	local frame = CFrame.lookAt(
		Vector3.new(position.X, 0, position.Z),
		Vector3.new(faceTarget.X, 0, faceTarget.Z)
	)
	local dark = Color3.fromRGB(94, 58, 32)
	local function add(className: string, partName: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
		local part: any = Instance.new(className)
		part.Name = partName
		part.Size = size
		part.Color = color
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if material then
			part.Material = material
		end
		part.CFrame = frame * CFrame.new(offset)
		part.Parent = bench
		return part
	end
	-- CFrame.lookAt aims local -Z at the target, so the sitter's back is +Z.
	add("Seat", "Seat", Vector3.new(5.5, 0.7, 1.9), Vector3.new(0, 1.9, 0), dark, Enum.Material.SmoothPlastic)
	add("Part", "Backrest", Vector3.new(5.5, 2.4, 0.45), Vector3.new(0, 3.6, 1.1), dark, Enum.Material.SmoothPlastic)
	add("Part", "Trim", Vector3.new(5.5, 0.3, 0.3), Vector3.new(0, 1.45, -1), Color3.fromRGB(255, 130, 190), Enum.Material.Neon)
	for _, x in ipairs({ -2.3, 2.3 }) do
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, 0.55), dark, nil)
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, -0.55), dark, nil)
	end
	return bench
end

-- THE CANDY PLAYGROUND: a pure fun layer on the empty north strip behind the
-- north base row (the plots end at z=-104, the island edge is z=-130, so the
-- strip z=-111..-127 fits a safety mat with room to spare). Real usable kit --
-- a slide you actually slide down, swings that swing with you on them, a
-- seesaw that tips toward whoever stands on it, a merry-go-round that carries
-- its riders, a bounce pad -- plus a rummageable trash can by the Fuse Machine
-- and benches facing the arena. PlaygroundService drives all the motion.
local function buildPlayground(worldFolder: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Playground"
	folder.Parent = worldFolder

	local dark = Color3.fromRGB(94, 58, 32)
	local lavender = Color3.fromRGB(190, 160, 255)
	local orange = Color3.fromRGB(255, 185, 120)

	-- The safety mat: one soft pastel-pink slab so the whole zone reads as one place.
	makePart(folder, "SafetyMat", Vector3.new(190, 0.35, 16), Vector3.new(0, 0.18, -119), Color3.fromRGB(255, 190, 220), Enum.Material.SmoothPlastic)
	local matEdge = makePart(folder, "MatEdge", Vector3.new(190, 0.25, 0.9), Vector3.new(0, 0.45, -111.4), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	matEdge.CanCollide = false

	-- The zone sign, on the grass lane south of the mat, facing the bases.
	makePart(folder, "PlaygroundPostW", Vector3.new(0.8, 9, 0.8), Vector3.new(-8, 4.5, -109), lavender, Enum.Material.Neon)
	makePart(folder, "PlaygroundPostE", Vector3.new(0.8, 9, 0.8), Vector3.new(8, 4.5, -109), lavender, Enum.Material.Neon)
	local signBoard = makePart(folder, "PlaygroundSignBoard", Vector3.new(19, 4, 0.6), Vector3.new(0, 8.5, -109), dark, Enum.Material.SmoothPlastic)
	makeSign(folder, "PlaygroundSign", signBoard, "CANDY PLAYGROUND", Color3.fromRGB(255, 170, 220), Vector3.new(0, 5, 0))

	-- SLIDE at (-70, -116): blocky steps climb the north side to a railed
	-- platform 9 studs up; the wedge chute falls away southward at ~35
	-- degrees with zero friction, so players genuinely slide to the landing.
	local slide = Instance.new("Folder")
	slide.Name = "Slide"
	slide.Parent = folder
	makePart(slide, "SlidePlatform", Vector3.new(6.5, 1, 6.5), Vector3.new(-70, 8.5, -119.5), Color3.fromRGB(150, 240, 200), Enum.Material.SmoothPlastic)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		for _, dz in ipairs({ -2.6, 2.6 }) do
			makePart(slide, "SlideLeg", Vector3.new(0.7, 8, 0.7), Vector3.new(-70 + dx, 4, -119.5 + dz), dark, Enum.Material.SmoothPlastic)
		end
	end
	makePart(slide, "SlideRailBack", Vector3.new(6.5, 1.6, 0.4), Vector3.new(-70, 10, -122.6), orange, Enum.Material.SmoothPlastic)
	makePart(slide, "SlideRailW", Vector3.new(0.4, 1.6, 6.5), Vector3.new(-73.05, 10, -119.5), orange, Enum.Material.SmoothPlastic)
	makePart(slide, "SlideRailE", Vector3.new(0.4, 1.6, 6.5), Vector3.new(-66.95, 10, -119.5), orange, Enum.Material.SmoothPlastic)
	for step = 1, 6 do
		makePart(slide, "SlideStep" .. tostring(step), Vector3.new(4.5, 1.1, 1.15),
			Vector3.new(-70, step * 1.5 - 0.55, -128.3 + (step - 1) * 1.05), orange, Enum.Material.SmoothPlastic)
	end
	local chute = Instance.new("WedgePart")
	chute.Name = "SlideChute"
	chute.Size = Vector3.new(5, 9, 13.5)
	chute.Position = Vector3.new(-70, 4.5, -109.5)
	chute.Color = Color3.fromRGB(255, 130, 180)
	chute.Material = Enum.Material.SmoothPlastic
	chute.Anchored = true
	chute.TopSurface = Enum.SurfaceType.Smooth
	chute.BottomSurface = Enum.SurfaceType.Smooth
	chute.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 0, 0)
	chute.Parent = slide
	for _, dx in ipairs({ -2.45, 2.45 }) do
		local rail = makePart(slide, "ChuteRail", Vector3.new(0.45, 0.6, 14.2), Vector3.new(-70 + dx, 5.6, -109.5), lavender, Enum.Material.SmoothPlastic)
		rail.CFrame = CFrame.new(-70 + dx, 5.6, -109.5) * CFrame.Angles(math.rad(34), 0, 0)
	end
	makePart(slide, "SlideLanding", Vector3.new(6, 0.4, 4.5), Vector3.new(-70, 0.2, -100.3), orange, Enum.Material.SmoothPlastic)

	-- SWINGS at (-25, -118): an A-frame with a lavender top bar and two real Seat
	-- swings. Each swing is a Model whose PrimaryPart sits ON the bar, so
	-- PlaygroundService can rock the whole model around the bar axis.
	local swingsFolder = Instance.new("Folder")
	swingsFolder.Name = "Swings"
	swingsFolder.Parent = folder
	makePart(swingsFolder, "SwingBar", Vector3.new(19, 0.8, 0.8), Vector3.new(-25, 10.2, -118), lavender, Enum.Material.Neon)
	for _, endX in ipairs({ -33.5, -16.5 }) do
		for _, side in ipairs({ -1, 1 }) do
			local leg = makePart(swingsFolder, "SwingLeg", Vector3.new(0.7, 11.5, 0.7), Vector3.new(endX, 5.1, -118 + side * 2.5), dark, Enum.Material.SmoothPlastic)
			leg.CFrame = CFrame.new(endX, 5.1, -118 + side * 2.5) * CFrame.Angles(math.rad(-24 * side), 0, 0)
		end
	end
	local swings = {}
	for i, swingX in ipairs({ -29.5, -20.5 }) do
		local model = Instance.new("Model")
		model.Name = "Swing" .. tostring(i)
		model.Parent = swingsFolder
		local pivot = Instance.new("Part")
		pivot.Name = "Pivot"
		pivot.Size = Vector3.new(0.5, 0.5, 0.5)
		pivot.Position = Vector3.new(swingX, 10.2, -118)
		pivot.Transparency = 1
		pivot.CanCollide = false
		pivot.Anchored = true
		pivot.Parent = model
		model.PrimaryPart = pivot
		for _, dx in ipairs({ -1.2, 1.2 }) do
			local chain = makePart(model, "Chain", Vector3.new(0.18, 7.2, 0.18), Vector3.new(swingX + dx, 6.6, -118), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
			chain.CanCollide = false
		end
		local seat = Instance.new("Seat")
		seat.Name = "SwingSeat"
		seat.Size = Vector3.new(3.4, 0.5, 1.7)
		seat.Position = Vector3.new(swingX, 2.75, -118)
		seat.Color = orange
		seat.Material = Enum.Material.SmoothPlastic
		seat.Anchored = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.Parent = model
		table.insert(swings, { Model = model, Pivot = Vector3.new(swingX, 10.2, -118), Phase = (i - 1) * 1.7 })
	end

	-- SEESAW at (25, -116): a log fulcrum and a 16-stud plank model pivoting
	-- on it; PlaygroundService tips it toward whichever end is stood on.
	local fulcrum = makePart(folder, "SeesawFulcrum", Vector3.new(3, 2.2, 2.2), Vector3.new(25, 1.1, -116), dark, Enum.Material.SmoothPlastic)
	fulcrum.Shape = Enum.PartType.Cylinder
	fulcrum.Orientation = Vector3.new(0, 90, 0)
	local seesaw = Instance.new("Model")
	seesaw.Name = "Seesaw"
	seesaw.Parent = folder
	local seesawPivot = Instance.new("Part")
	seesawPivot.Name = "Pivot"
	seesawPivot.Size = Vector3.new(0.5, 0.5, 0.5)
	seesawPivot.Position = Vector3.new(25, 2.45, -116)
	seesawPivot.Transparency = 1
	seesawPivot.CanCollide = false
	seesawPivot.Anchored = true
	seesawPivot.Parent = seesaw
	seesaw.PrimaryPart = seesawPivot
	makePart(seesaw, "Plank", Vector3.new(16, 0.5, 2.2), Vector3.new(25, 2.45, -116), Color3.fromRGB(255, 220, 80), Enum.Material.SmoothPlastic)
	for _, dx in ipairs({ -6.6, 6.6 }) do
		makePart(seesaw, "PlankPad", Vector3.new(2.8, 0.35, 2.4), Vector3.new(25 + dx, 2.85, -116), Color3.fromRGB(255, 110, 200), Enum.Material.Neon)
	end
	for _, dx in ipairs({ -5.2, 5.2 }) do
		makePart(seesaw, "HandlePost", Vector3.new(0.25, 1.1, 0.25), Vector3.new(25 + dx, 3.2, -116), dark, Enum.Material.Metal)
		makePart(seesaw, "HandleGrip", Vector3.new(0.25, 0.25, 1.6), Vector3.new(25 + dx, 3.8, -116), dark, Enum.Material.Metal)
	end

	-- MERRY-GO-ROUND at (75, -116): a candy-pink deck on a cream candy rim,
	-- centre pole, four candy-stripe handle posts and four real seats with
	-- backrests, so it reads as a ride and not a plain slab. PlaygroundService
	-- spins the model, carries standing riders around with it, and seated
	-- riders ride along on their seats' welds.
	local merry = Instance.new("Model")
	merry.Name = "MerryGoRound"
	merry.Parent = folder
	local merryPivot = Instance.new("Part")
	merryPivot.Name = "Pivot"
	merryPivot.Size = Vector3.new(1, 1, 1)
	merryPivot.Position = Vector3.new(75, 0, -116)
	merryPivot.Transparency = 1
	merryPivot.CanCollide = false
	merryPivot.Anchored = true
	merryPivot.Parent = merry
	merry.PrimaryPart = merryPivot
	local merryRim = makePart(merry, "Rim", Vector3.new(0.7, 19.4, 19.4), Vector3.new(75, 0.55, -116), Color3.fromRGB(255, 244, 230), Enum.Material.Neon)
	merryRim.Shape = Enum.PartType.Cylinder
	merryRim.Orientation = Vector3.new(0, 0, 90)
	local merryDeck = makePart(merry, "Deck", Vector3.new(1.2, 18, 18), Vector3.new(75, 1, -116), Color3.fromRGB(255, 130, 200), Enum.Material.SmoothPlastic)
	merryDeck.Shape = Enum.PartType.Cylinder
	merryDeck.Orientation = Vector3.new(0, 0, 90)
	local merryPole = makePart(merry, "CentrePole", Vector3.new(5, 1.1, 1.1), Vector3.new(75, 3.4, -116), lavender, Enum.Material.Neon)
	merryPole.Shape = Enum.PartType.Cylinder
	merryPole.Orientation = Vector3.new(0, 0, 90)
	for postIndex = 1, 4 do
		local angle = math.rad(45 + (postIndex - 1) * 90)
		local postX = 75 + math.cos(angle) * 6.2
		local postZ = -116 + math.sin(angle) * 6.2
		local postLower = makePart(merry, "HandlePost" .. tostring(postIndex), Vector3.new(1.5, 0.4, 0.4),
			Vector3.new(postX, 2.35, postZ), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		postLower.Shape = Enum.PartType.Cylinder
		postLower.Orientation = Vector3.new(0, 0, 90)
		local postUpper = makePart(merry, "HandlePostTop" .. tostring(postIndex), Vector3.new(1.5, 0.4, 0.4),
			Vector3.new(postX, 3.85, postZ), Color3.fromRGB(255, 80, 110), Enum.Material.SmoothPlastic)
		postUpper.Shape = Enum.PartType.Cylinder
		postUpper.Orientation = Vector3.new(0, 0, 90)
	end
	-- Four seats inside the handle posts, facing outward over the deck edge,
	-- one candy colour each: a Seat box on a short post, with a backrest on
	-- the centre side. Sitting players face out and hold the striped pole
	-- in front of them, just like a real carousel.
	local merrySeatColors = {
		Color3.fromRGB(255, 130, 200),
		Color3.fromRGB(150, 240, 200),
		Color3.fromRGB(255, 235, 130),
		Color3.fromRGB(195, 160, 255),
	}
	for seatIndex = 1, 4 do
		local angle = math.rad(45 + (seatIndex - 1) * 90)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local seatPosition = Vector3.new(75, 2.85, -116) + radial * 5.2
		local seatFrame = CFrame.lookAt(seatPosition, seatPosition + radial)
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. tostring(seatIndex)
		seat.Size = Vector3.new(2.4, 0.5, 2.1)
		seat.Color = merrySeatColors[seatIndex]
		seat.Material = Enum.Material.SmoothPlastic
		seat.Anchored = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.CFrame = seatFrame
		seat.Parent = merry
		local seatPost = makePart(merry, "SeatPost" .. tostring(seatIndex), Vector3.new(0.5, 1, 0.5), seatPosition, dark, Enum.Material.Metal)
		seatPost.CFrame = seatFrame * CFrame.new(0, -0.75, 0)
		local seatBack = makePart(merry, "SeatBack" .. tostring(seatIndex), Vector3.new(2.4, 1.8, 0.4), seatPosition, merrySeatColors[seatIndex], Enum.Material.SmoothPlastic)
		seatBack.CFrame = seatFrame * CFrame.new(0, 1.05, 1.1)
	end

	-- BOUNCE PAD on the playground's south edge at (45, -112) -- the strip
	-- between the mat and the north bases is open grass, so it sits clear of
	-- every plot. PlaygroundService launches whoever steps on it.
	local bounce = makePart(folder, "BouncePad", Vector3.new(0.8, 10, 10), Vector3.new(45, 0.4, -112), Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
	bounce.Shape = Enum.PartType.Cylinder
	bounce.Orientation = Vector3.new(0, 0, 90)
	local bouncePost = makePart(folder, "BouncePost", Vector3.new(0.7, 7, 0.7), Vector3.new(51.5, 3.5, -106.5), Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
	makeSign(folder, "BounceSign", bouncePost, "BOUNCE!", Color3.fromRGB(255, 150, 220), Vector3.new(0, 5, 0))

	-- TRASH CAN by the Fuse Machine, on the path every player walks: a
	-- mint bin with a chocolate lid and a pink band, and a ProximityPrompt
	-- that PlaygroundService turns into a once-a-minute cash rummage.
	local trashBody = makePart(folder, "TrashCan", Vector3.new(3.4, 3.2, 3.2), Vector3.new(44, 1.7, 22), Color3.fromRGB(140, 200, 160), Enum.Material.Metal)
	trashBody.Shape = Enum.PartType.Cylinder
	trashBody.Orientation = Vector3.new(0, 0, 90)
	local trashLid = makePart(folder, "TrashLid", Vector3.new(0.5, 3.7, 3.7), Vector3.new(44, 3.55, 22), dark, Enum.Material.Metal)
	trashLid.Shape = Enum.PartType.Cylinder
	trashLid.Orientation = Vector3.new(0, 0, 90)
	local trashBand = makePart(folder, "TrashBand", Vector3.new(0.45, 3.35, 3.35), Vector3.new(44, 2.5, 22), Color3.fromRGB(255, 150, 200), Enum.Material.Neon)
	trashBand.Shape = Enum.PartType.Cylinder
	trashBand.Orientation = Vector3.new(0, 0, 90)
	trashBand.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RummagePrompt"
	prompt.ActionText = "Rummage"
	prompt.ObjectText = "Trash Can"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = trashBody

	-- BENCHES around the Candy Arena, each with a real Seat, facing the ring:
	-- two flanking the arena-to-belt path, one west, one south past the road.
	local arenaCentre = Vector3.new(0, 0, 28)
	buildBench(folder, "BenchNW", Vector3.new(-14, 0, -2), arenaCentre)
	buildBench(folder, "BenchNE", Vector3.new(14, 0, -2), arenaCentre)
	buildBench(folder, "BenchW", Vector3.new(-31, 0, 28), arenaCentre)
	buildBench(folder, "BenchS", Vector3.new(0, 0, 62), arenaCentre)

	WorldBuilder.PlaygroundFolder = folder
	WorldBuilder.Playground = {
		Swings = swings,
		Seesaw = seesaw,
		SeesawPivot = Vector3.new(25, 2.45, -116),
		MerryGoRound = merry,
		MerryPivot = Vector3.new(75, 0, -116),
		BouncePad = bounce,
		TrashPrompt = prompt,
	}
end

-- CANDY DECOR: pure dressing built from primitives -- lollipop trees scattered
-- on the open lanes and rim, candy-cane poles along the belt ends and paths,
-- gumdrops sprinkled on the cream rim, and sprinkles scattered over the two
-- frosting paths. Everything is anchored; only the lollipop trunks collide.
local function buildCandyDecor(worldFolder: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "CandyDecor"
	folder.Parent = worldFolder

	local candyColors = {
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(190, 130, 255),
		Color3.fromRGB(130, 240, 180),
		Color3.fromRGB(255, 180, 130),
		Color3.fromRGB(255, 240, 150),
	}

	-- Lollipop trees: a thin white trunk, a big vertical candy disc and a
	-- smaller white centre disc -- a swirl lollipop from any angle. Each disc
	-- faces a different direction so some always face the camera.
	local lollipopSpots = {
		Vector3.new(-124, 0, -8), Vector3.new(124, 0, 8), Vector3.new(-124, 0, 64),
		Vector3.new(124, 0, -64), Vector3.new(-70, 0, -44), Vector3.new(70, 0, 44),
		Vector3.new(-40, 0, 118), Vector3.new(40, 0, 118), Vector3.new(-110, 0, -118),
		Vector3.new(110, 0, -118),
	}
	for index, spot in ipairs(lollipopSpots) do
		local color = candyColors[((index - 1) % #candyColors) + 1]
		local trunk = makePart(folder, "LollipopTrunk" .. tostring(index), Vector3.new(7, 0.9, 0.9), spot + Vector3.new(0, 3.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Orientation = Vector3.new(0, 0, 90)
		local facing = (index - 1) * 36
		local disc = makePart(folder, "LollipopDisc" .. tostring(index), Vector3.new(0.7, 5.2, 5.2), spot + Vector3.new(0, 7.8, 0), color, Enum.Material.SmoothPlastic)
		disc.Shape = Enum.PartType.Cylinder
		disc.Orientation = Vector3.new(0, facing, 0)
		disc.CanCollide = false
		local centre = makePart(folder, "LollipopCentre" .. tostring(index), Vector3.new(0.85, 2.2, 2.2), spot + Vector3.new(0, 7.8, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		centre.Shape = Enum.PartType.Cylinder
		centre.Orientation = Vector3.new(0, facing, 0)
		centre.CanCollide = false
	end

	-- Candy-cane poles: a red/white alternating stack of six short cylinders,
	-- standing at the belt's two ends and along both frosting paths.
	local caneSpots = {
		Vector3.new(-100, 0, -36), Vector3.new(100, 0, -36), Vector3.new(-100, 0, -4),
		Vector3.new(100, 0, -4), Vector3.new(-64, 0, 44), Vector3.new(64, 0, 44),
		Vector3.new(-64, 0, -44), Vector3.new(64, 0, -44),
	}
	for index, spot in ipairs(caneSpots) do
		for segment = 1, 6 do
			local color = if segment % 2 == 1 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 80, 80)
			local piece = makePart(folder, "CandyCane" .. tostring(index) .. "_" .. tostring(segment), Vector3.new(1, 1.1, 1.1), spot + Vector3.new(0, segment - 0.5, 0), color, Enum.Material.SmoothPlastic)
			piece.Shape = Enum.PartType.Cylinder
			piece.Orientation = Vector3.new(0, 0, 90)
			piece.CanCollide = false
		end
	end

	-- Gumdrops: small squashed pastel spheres dotted along the cream rim.
	local gumdropSpots = {
		Vector3.new(133, 0, -60), Vector3.new(-133, 0, -60), Vector3.new(133, 0, 60),
		Vector3.new(-133, 0, 60), Vector3.new(60, 0, 133), Vector3.new(-60, 0, 133),
		Vector3.new(60, 0, -133), Vector3.new(-60, 0, -133), Vector3.new(133, 0, 120),
		Vector3.new(-133, 0, -120), Vector3.new(20, 0, 133), Vector3.new(-20, 0, -133),
		Vector3.new(133, 0, -120), Vector3.new(-133, 0, 120),
	}
	for index, spot in ipairs(gumdropSpots) do
		local drop = makePart(folder, "Gumdrop" .. tostring(index), Vector3.new(1.8, 1.3, 1.8), spot + Vector3.new(0, 0.35, 0), candyColors[((index - 1) % #candyColors) + 1], Enum.Material.SmoothPlastic)
		drop.Shape = Enum.PartType.Ball
		drop.CanCollide = false
	end

	-- Sprinkles: tiny flat candy sticks scattered over the two frosting paths
	-- (deterministic pseudo-random spots, kept off the belt and the plots).
	for index = 1, 24 do
		local onNorth = index <= 12
		local laneIndex = if onNorth then index else index - 12
		local x = -115 + (laneIndex - 1) * 21 + ((laneIndex * 37) % 9) - 4
		local z = (if onNorth then -52 else 52) + ((laneIndex * 29) % 9) - 4
		local sprinkle = makePart(folder, "Sprinkle" .. tostring(index), Vector3.new(1.5, 0.14, 0.5), Vector3.new(x, 0.55, z), candyColors[((index - 1) % #candyColors) + 1], Enum.Material.SmoothPlastic)
		sprinkle.Orientation = Vector3.new(0, (index * 47) % 180, 0)
		sprinkle.CanCollide = false
	end
end

function WorldBuilder.BuildWorld()
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "CandyIslandWorld"
	worldFolder.Parent = Workspace

	-- Island: a pastel pink frosting top on a slightly wider cream rim, floating in a bright
	-- teal sea. The sand rim's top sits just below the grass top, so the island
	-- edge reads as a beach from any camera angle.
	makePart(worldFolder, "IslandSandRim", Vector3.new(276, 4, 276), Vector3.new(0, -2.25, 0), Color3.fromRGB(255, 240, 214), Enum.Material.Sand)
	makePart(worldFolder, "IslandGround", Vector3.new(260, 4, 260), Vector3.new(0, -2, 0), Color3.fromRGB(255, 183, 213), Enum.Material.SmoothPlastic)
	local sea = makePart(worldFolder, "Sea", Vector3.new(900, 2, 900), Vector3.new(0, -5, 0), Color3.fromRGB(30, 145, 205), Enum.Material.SmoothPlastic)
	sea.Transparency = 0.25

	-- THE CANDY ARENA: the spawn plaza, a candy ring just south of the belt.
	-- A cream-white disc (built from flat cylinders) floats on a wider hot-pink
	-- disc so the rim pops, with a white inlay ring and a hot-pink core around
	-- the spawn point.
	-- Every few minutes a golden brainrot appears here (EconomyService's arena
	-- event), so the ring is kept empty on purpose -- it is a stage, not a plaza.
	local arenaGlow = makePart(worldFolder, "ArenaGlowBase", Vector3.new(0.5, 54, 54), Vector3.new(0, 0.25, 28), Color3.fromRGB(255, 90, 170), Enum.Material.Neon)
	arenaGlow.Shape = Enum.PartType.Cylinder
	arenaGlow.Orientation = Vector3.new(0, 0, 90)
	local arenaDisc = makePart(worldFolder, "ArenaDisc", Vector3.new(0.6, 52, 52), Vector3.new(0, 0.55, 28), Color3.fromRGB(255, 250, 244), Enum.Material.SmoothPlastic)
	arenaDisc.Shape = Enum.PartType.Cylinder
	arenaDisc.Orientation = Vector3.new(0, 0, 90)
	local arenaRing = makePart(worldFolder, "ArenaInnerRing", Vector3.new(0.25, 34, 34), Vector3.new(0, 0.92, 28), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	arenaRing.Shape = Enum.PartType.Cylinder
	arenaRing.Orientation = Vector3.new(0, 0, 90)
	arenaRing.CanCollide = false
	local arenaCore = makePart(worldFolder, "ArenaCore", Vector3.new(0.3, 26, 26), Vector3.new(0, 1, 28), Color3.fromRGB(255, 130, 195), Enum.Material.SmoothPlastic)
	arenaCore.Shape = Enum.PartType.Cylinder
	arenaCore.Orientation = Vector3.new(0, 0, 90)
	WorldBuilder.ArenaPosition = Vector3.new(0, 0, 28)
	-- The title sign stands on two posts over the arena's north side, facing the belt.
	makePart(worldFolder, "TitlePostW", Vector3.new(0.8, 12, 0.8), Vector3.new(-13, 6, 6), Color3.fromRGB(255, 90, 170), Enum.Material.Neon)
	makePart(worldFolder, "TitlePostE", Vector3.new(0.8, 12, 0.8), Vector3.new(13, 6, 6), Color3.fromRGB(255, 90, 170), Enum.Material.Neon)
	local titleBoard = makePart(worldFolder, "TitleBoard", Vector3.new(30, 5, 0.6), Vector3.new(0, 10.5, 6), Color3.fromRGB(120, 60, 90), Enum.Material.SmoothPlastic)
	makeSign(worldFolder, "TitleSign", titleBoard, "CANDY ISLAND", Color3.fromRGB(255, 240, 90), Vector3.new(0, 5, 0))
	local arenaPost = makePart(worldFolder, "ArenaSignPost", Vector3.new(0.8, 8, 0.8), Vector3.new(0, 4, 53), Color3.fromRGB(255, 110, 200), Enum.Material.Neon)
	makeSign(worldFolder, "ArenaSign", arenaPost, "CANDY ARENA\nGOLDEN BRAINROTS APPEAR HERE!", Color3.fromRGB(255, 190, 90), Vector3.new(0, 6, 0))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 28)
	spawn.Color = Color3.fromRGB(255, 150, 200)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = worldFolder

	-- PURPLE ZONE: the Fuse Machine, a dark cauldron of glowing purple brew at
	-- the arena's east edge. Feed it 3 brainrots of one rarity (from the
	-- FUSE panel) and it bubbles up 1 of the next rarity.
	makePart(worldFolder, "FusePad", Vector3.new(13, 0.4, 13), Vector3.new(34, 0.2, 30), Color3.fromRGB(255, 244, 230), Enum.Material.SmoothPlastic)
	local cauldron = makePart(worldFolder, "FuseCauldron", Vector3.new(5, 7, 7), Vector3.new(34, 2.5, 30), Color3.fromRGB(120, 90, 180), Enum.Material.Metal)
	cauldron.Shape = Enum.PartType.Cylinder
	cauldron.Orientation = Vector3.new(0, 0, 90)
	local brew = makePart(worldFolder, "FuseBrew", Vector3.new(0.5, 6, 6), Vector3.new(34, 5.1, 30), Color3.fromRGB(200, 130, 255), Enum.Material.Neon)
	brew.Shape = Enum.PartType.Cylinder
	brew.Orientation = Vector3.new(0, 0, 90)
	brew.CanCollide = false
	makeSign(worldFolder, "FuseSign", cauldron, "FUSE MACHINE\n3 SAME RARITY = 1 RARITY UP", Color3.fromRGB(215, 150, 255), Vector3.new(0, 9, 0))
	makePart(worldFolder, "FusePostW", Vector3.new(0.8, 9, 0.8), Vector3.new(28, 4.5, 30), Color3.fromRGB(180, 140, 255), Enum.Material.Neon)
	makePart(worldFolder, "FusePostE", Vector3.new(0.8, 9, 0.8), Vector3.new(40, 4.5, 30), Color3.fromRGB(180, 140, 255), Enum.Material.Neon)
	WorldBuilder.FuseMachinePosition = Vector3.new(34, 0, 30)

	-- MAGENTA ZONE: the Gacha Capsule, mirror of the Fuse Machine at the
	-- arena's WEST edge -- nudged further west (x -44, not -34) because the
	-- arena's west bench and the r27 glow ring crowd the mirrored spot. A
	-- glass dome full of bright mini capsules on a chunky base, with a crank
	-- and a prize slot on its front. One spin costs real money and never,
	-- ever lands a Common (EconomyService.RollGacha).
	makePart(worldFolder, "GachaPad", Vector3.new(13, 0.4, 13), Vector3.new(-44, 0.2, 30), Color3.fromRGB(255, 244, 230), Enum.Material.SmoothPlastic)
	local gachaBase = makePart(worldFolder, "GachaBase", Vector3.new(9, 4.5, 9), Vector3.new(-44, 2.25, 30), Color3.fromRGB(255, 140, 200), Enum.Material.SmoothPlastic)
	makePart(worldFolder, "GachaTrim", Vector3.new(9.6, 0.5, 9.6), Vector3.new(-44, 4.4, 30), Color3.fromRGB(255, 110, 220), Enum.Material.Neon)
	local gachaDome = Instance.new("Part")
	gachaDome.Name = "GachaDome"
	gachaDome.Shape = Enum.PartType.Ball
	gachaDome.Size = Vector3.new(8.5, 8.5, 8.5)
	gachaDome.Position = Vector3.new(-44, 7.6, 30)
	gachaDome.Color = Color3.fromRGB(255, 240, 250)
	gachaDome.Transparency = 0.3
	gachaDome.Anchored = true
	gachaDome.CanCollide = false
	gachaDome.Parent = worldFolder
	-- The prize stock: ten mini capsules in toy colours, floating in the dome.
	local capsuleColors = {
		Color3.fromRGB(255, 170, 210), Color3.fromRGB(170, 225, 255), Color3.fromRGB(255, 240, 170),
		Color3.fromRGB(180, 245, 195), Color3.fromRGB(255, 205, 170), Color3.fromRGB(215, 185, 255),
		Color3.fromRGB(255, 170, 170), Color3.fromRGB(210, 250, 170), Color3.fromRGB(170, 210, 255),
		Color3.fromRGB(255, 170, 220),
	}
	local capsuleOffsets = {
		Vector3.new(2.3, 5.4, 0), Vector3.new(1.15, 5.4, 1.99), Vector3.new(-1.15, 5.4, 1.99),
		Vector3.new(-2.3, 5.4, 0), Vector3.new(-1.15, 5.4, -1.99), Vector3.new(1.15, 5.4, -1.99),
		Vector3.new(1.2, 6.9, 0), Vector3.new(-0.6, 6.9, 1.04), Vector3.new(-0.6, 6.9, -1.04),
		Vector3.new(0, 8.2, 0),
	}
	for capsuleIndex, offset in ipairs(capsuleOffsets) do
		local capsule = makePart(worldFolder, "GachaCapsule" .. tostring(capsuleIndex), Vector3.new(1.7, 1.7, 1.7), Vector3.new(-44 + offset.X, offset.Y, 30 + offset.Z), capsuleColors[capsuleIndex], Enum.Material.SmoothPlastic)
		capsule.Shape = Enum.PartType.Ball
		capsule.CanCollide = false
	end
	-- The crank on the front face, and the prize slot under it.
	local crank = makePart(worldFolder, "GachaCrank", Vector3.new(1.8, 1.2, 1.2), Vector3.new(-41.8, 2.6, 34.9), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	crank.Shape = Enum.PartType.Cylinder
	crank.Orientation = Vector3.new(0, 90, 0)
	local crankHandle = makePart(worldFolder, "GachaCrankHandle", Vector3.new(1.1, 1.1, 1.1), Vector3.new(-41.2, 1.7, 35.3), Color3.fromRGB(255, 110, 220), Enum.Material.Neon)
	crankHandle.Shape = Enum.PartType.Ball
	makePart(worldFolder, "GachaPrizeSlot", Vector3.new(3.6, 1.7, 0.5), Vector3.new(-44, 1.15, 34.6), Color3.fromRGB(16, 16, 22), Enum.Material.SmoothPlastic)
	makeSign(worldFolder, "GachaSign", gachaBase, "GACHA CAPSULE\n" .. GameConfig.FormatCash(GameConfig.GachaPrice) .. " PER SPIN - NO COMMONS!", Color3.fromRGB(255, 110, 220), Vector3.new(0, 10, 0))
	makePart(worldFolder, "GachaPostW", Vector3.new(0.8, 9, 0.8), Vector3.new(-50, 4.5, 30), Color3.fromRGB(255, 110, 220), Enum.Material.Neon)
	makePart(worldFolder, "GachaPostE", Vector3.new(0.8, 9, 0.8), Vector3.new(-38, 4.5, 30), Color3.fromRGB(255, 110, 220), Enum.Material.Neon)
	WorldBuilder.GachaMachinePosition = Vector3.new(-44, 0, 30)

	-- A short frosting connector from the arena's north edge to the belt platform,
	-- edged with white candy strips, and two straight frosting paths running
	-- between the belt and each row of bases.
	makePart(worldFolder, "ArenaToBelt", Vector3.new(16, 0.4, 14), Vector3.new(0, 0.2, -3), Color3.fromRGB(255, 228, 238), Enum.Material.SmoothPlastic)
	makePart(worldFolder, "PathEdgeE", Vector3.new(1.2, 0.25, 14), Vector3.new(7.4, 0.45, -3), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	makePart(worldFolder, "PathEdgeW", Vector3.new(1.2, 0.25, 14), Vector3.new(-7.4, 0.45, -3), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	makePart(worldFolder, "RoadNorth", Vector3.new(252, 0.4, 16), Vector3.new(0, 0.2, -52), Color3.fromRGB(255, 232, 240), Enum.Material.SmoothPlastic)
	makePart(worldFolder, "RoadSouth", Vector3.new(252, 0.4, 16), Vector3.new(0, 0.2, 52), Color3.fromRGB(255, 232, 240), Enum.Material.SmoothPlastic)

	-- CHOCOLATE ZONE: the conveyor spine. One long belt runs east-west through
	-- the middle of the island and the bases flank it on both sides. Brainrots
	-- walk its full length (EconomyService strides them from x -80 to x 80), big
	-- sign over the middle, a chase-light pad row along the belt's front edge,
	-- and a candy-red beacon post marking the zone. The belt stays dark
	-- chocolate so the walkers and their labels keep their contrast.
	makePart(worldFolder, "BeltPlatform", Vector3.new(192, 1, 22), Vector3.new(0, 0.25, -20), Color3.fromRGB(120, 72, 38), Enum.Material.SmoothPlastic)
	local belt = makePart(worldFolder, "ConveyorBelt", Vector3.new(184, 2, 10), Vector3.new(0, 1, -20), Color3.fromRGB(74, 44, 24), Enum.Material.SmoothPlastic)
	makeSign(worldFolder, "ShopSign", belt, "SHOP BELT - WALK IN TO BUY", Color3.fromRGB(255, 240, 170), Vector3.new(0, 10, 0))
	makePart(worldFolder, "BeltBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(100, 5.5, -32), Color3.fromRGB(255, 90, 100), Enum.Material.Neon)
	for slotIndex = 1, GameConfig.ConveyorMaxOnBelt do
		local slotPosition = Vector3.new(-72 + (slotIndex - 1) * 24, 0.95, -11.5)
		local slotPad = makePart(worldFolder, "ConveyorSlot" .. tostring(slotIndex), Vector3.new(9, 0.4, 9), slotPosition, Color3.fromRGB(255, 170, 205), Enum.Material.Neon)
		table.insert(WorldBuilder.ConveyorSlots, { Pad = slotPad, Position = slotPosition + Vector3.new(0, 1, 0) })
	end

	-- PINK ZONE: the egg machine caps the belt's WEST end, a glass dome on a
	-- pink pedestal. The approach point sits south of it, on the belt line.
	local eggBase = makePart(worldFolder, "EggMachineBase", Vector3.new(12, 4, 12), Vector3.new(-108, 2, -20), Color3.fromRGB(255, 120, 200), Enum.Material.Neon)
	local eggDome = Instance.new("Part")
	eggDome.Name = "EggDome"
	eggDome.Shape = Enum.PartType.Ball
	eggDome.Size = Vector3.new(8, 8, 8)
	eggDome.Position = Vector3.new(-108, 8, -20)
	eggDome.Color = Color3.fromRGB(255, 240, 250)
	eggDome.Transparency = 0.3
	eggDome.Anchored = true
	eggDome.CanCollide = false
	eggDome.Parent = worldFolder
	makeSign(worldFolder, "EggSign", eggBase, "EGG MACHINE\nHATCH: " .. GameConfig.FormatCash(GameConfig.EggPrice), Color3.fromRGB(255, 120, 230), Vector3.new(0, 10, 0))
	makePart(worldFolder, "EggBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(-122, 5.5, -20), Color3.fromRGB(120, 255, 190), Enum.Material.Neon)
	WorldBuilder.EggMachinePosition = Vector3.new(-108, 0, -4)

	-- CARAMEL ZONE: the rebirth shrine caps the belt's EAST end, caramel steps
	-- up to a glowing cream crystal.
	for step = 1, 3 do
		makePart(worldFolder, "ShrineStep" .. tostring(step), Vector3.new(20 - step * 3, 1, 20 - step * 3), Vector3.new(108, step * 0.5, -20), Color3.fromRGB(235, 180, 95), Enum.Material.Metal)
	end
	local crystal = makePart(worldFolder, "RebirthCrystal", Vector3.new(4, 8, 4), Vector3.new(108, 7, -20), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	crystal.Orientation = Vector3.new(0, 45, 0)
	makeSign(worldFolder, "RebirthSign", crystal, "REBIRTH SHRINE\nRESET FOR +100% INCOME", Color3.fromRGB(255, 215, 80), Vector3.new(0, 9, 0))
	makePart(worldFolder, "ShrineBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(122, 5.5, -20), Color3.fromRGB(240, 190, 90), Enum.Material.Neon)
	WorldBuilder.RebirthShrinePosition = Vector3.new(108, 0, -4)

	-- Eight base plots FLANK the belt: four on the north side facing south
	-- toward it, four on the south side facing north toward it.
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = worldFolder
	for index = 1, GameConfig.BaseCount do
		local column = (index - 1) % 4
		local row = math.floor((index - 1) / 4)
		local origin = Vector3.new(-96 + column * BASE_SPACING, 0, if row == 0 then -82 else 82)
		local facing = if row == 0 then 1 else -1
		buildBasePlot(basesFolder, index, origin, facing)
	end

	-- CHOCOLATE ZONE: the high hill, a chocolate ridge along the south beach
	-- between the south bases and the sea, with a lighter melted-chocolate cap.
	-- Stand up here and the Big Wave cannot take you.
	local hill = makePart(worldFolder, "ShelterHill", Vector3.new(56, WorldBuilder.HighGroundTopY, 20), Vector3.new(0, WorldBuilder.HighGroundTopY / 2, 114), Color3.fromRGB(111, 66, 35), Enum.Material.SmoothPlastic)
	makePart(worldFolder, "HillCap", Vector3.new(56.6, 1.2, 20.6), Vector3.new(0, WorldBuilder.HighGroundTopY + 0.3, 114), Color3.fromRGB(150, 95, 55), Enum.Material.SmoothPlastic)
	makeSign(worldFolder, "ShelterSign", hill, "HIGH HILL\nSAFE FROM THE BIG WAVE", Color3.fromRGB(255, 240, 200), Vector3.new(0, 16, 0))
	makePart(worldFolder, "HillBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(34, 5.5, 114), Color3.fromRGB(255, 130, 190), Enum.Material.Neon)

	-- Palm trees in neat clusters: the beach rim, the arena sides and the gaps
	-- between belt and bases -- never under a base plot, the belt or the arena.
	-- Every other palm carries a candy glowfruit.
	local palmSpots = {
		{ Position = Vector3.new(-120, 0, -40), Glow = true, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(120, 0, -44), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-120, 0, 40), Glow = true, Color = Color3.fromRGB(170, 140, 255) },
		{ Position = Vector3.new(124, 0, 36), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-48, 0, -38), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(48, 0, -38), Glow = true, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-60, 0, 20), Glow = true, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(60, 0, 20), Glow = false, Color = Color3.fromRGB(170, 140, 255) },
		{ Position = Vector3.new(0, 0, -38), Glow = true, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(-88, 0, 120), Glow = false, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(88, 0, 120), Glow = true, Color = Color3.fromRGB(170, 140, 255) },
		{ Position = Vector3.new(-124, 0, 20), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
	}
	for palmIndex, spot in ipairs(palmSpots) do
		buildPalm(worldFolder, "Palm" .. tostring(palmIndex), spot.Position, spot.Glow, spot.Color)
	end

	-- The Candy Playground fills the dead north strip behind the north bases,
	-- and its benches ring the arena (built inside buildPlayground).
	buildPlayground(worldFolder)

	-- Candy dressing over the whole island: lollipop trees, candy-cane poles,
	-- gumdrops on the rim and sprinkles on the paths.
	buildCandyDecor(worldFolder)

	-- The Big Wave wall itself: a huge sheet of strawberry-pink soda with a
	-- white foam crest, tweened smoothly across the island by TsunamiService.
	local wall = makePart(worldFolder, "TsunamiWall", Vector3.new(280, 30, 6), Vector3.new(-165, 12, 0), Color3.fromRGB(255, 110, 160), Enum.Material.SmoothPlastic)
	wall.Transparency = 0.3
	wall.CanCollide = false
	WorldBuilder.TsunamiWall = wall
	local foam = makePart(worldFolder, "TsunamiFoam", Vector3.new(280, 3, 6.6), Vector3.new(-165, 28.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
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
