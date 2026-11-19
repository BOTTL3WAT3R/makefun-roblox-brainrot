-- WorldBuilder.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- builds the whole 3D world from primitive Parts at runtime: a compact
-- tropical island at golden hour (see the Lighting setup in Main.server) laid out like
-- the big steal-a-brainrot games: ONE long conveyor spine through the middle with the
-- eight player bases flanking it on both sides, the glowing Neon Arena (spawn) just
-- south of the belt, the Egg Machine and Rebirth Shrine capping the belt's two ends,
-- and dark slate ground so every neon sign, pad and laser glows. Neon zone colours
-- throughout (orange belt, pink egg, gold shrine, purple fuse, green hill), palm trees
-- with glowfruit, and one vivid neon colour per player base. Big short signs, and all
-- the motion lives on the brainrots themselves (see AnimationService).
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

-- One vivid neon colour per base slot: pads and floor trim wear it, so every base
-- reads as its own glowing territory in a screenshot.
local BASE_SLOT_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 230, 80),
	Color3.fromRGB(110, 255, 120),
	Color3.fromRGB(60, 220, 255),
	Color3.fromRGB(110, 140, 255),
	Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 110, 200),
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
	-- A smaller, higher label than the world signs: two clean lines (name, then
	-- rarity and income) that stay readable without piling onto the next brainrot.
	local incomeLabel = makeSign(model, "IncomeLabel", body, labelText, rarityColor, Vector3.new(0, 5.2, 0), 90)
	incomeLabel.Size = UDim2.fromOffset(300, 92)

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
		Color3.fromRGB(52, 54, 68), Enum.Material.SmoothPlastic)
	-- Neon trim ring around the floor, in the base's slot colour.
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

-- One palm tree: a slightly tilted cylinder trunk, six flat leaves fanned from the
-- top, and (on some palms) a glowing neon "glowfruit" sphere hanging by the crown.
local function buildPalm(parent: Folder, name: string, position: Vector3, withGlowfruit: boolean, glowColor: Color3)
	local trunk = Instance.new("Part")
	trunk.Name = name .. "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(1.3, 10, 1.3)
	trunk.Color = Color3.fromRGB(130, 92, 55)
	trunk.Anchored = true
	trunk.TopSurface = Enum.SurfaceType.Smooth
	trunk.BottomSurface = Enum.SurfaceType.Smooth
	trunk.CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(7))
	trunk.Parent = parent
	local crownTop = position + Vector3.new(1.25, 10, 0)
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
	local dark = Color3.fromRGB(46, 48, 62)
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
	add("Part", "Trim", Vector3.new(5.5, 0.3, 0.3), Vector3.new(0, 1.45, -1), Color3.fromRGB(40, 230, 255), Enum.Material.Neon)
	for _, x in ipairs({ -2.3, 2.3 }) do
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, 0.55), dark, nil)
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, -0.55), dark, nil)
	end
	return bench
end

-- THE NEON PLAYGROUND: a pure fun layer on the empty north strip behind the
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

	local dark = Color3.fromRGB(46, 48, 62)
	local neonCyan = Color3.fromRGB(40, 230, 255)
	local orange = Color3.fromRGB(255, 140, 40)

	-- The safety mat: one soft teal slab so the whole zone reads as one place.
	makePart(folder, "SafetyMat", Vector3.new(190, 0.35, 16), Vector3.new(0, 0.18, -119), Color3.fromRGB(35, 175, 165), Enum.Material.SmoothPlastic)
	local matEdge = makePart(folder, "MatEdge", Vector3.new(190, 0.25, 0.9), Vector3.new(0, 0.45, -111.4), neonCyan, Enum.Material.Neon)
	matEdge.CanCollide = false

	-- The zone sign, on the grass lane south of the mat, facing the bases.
	makePart(folder, "PlaygroundPostW", Vector3.new(0.8, 9, 0.8), Vector3.new(-8, 4.5, -109), neonCyan, Enum.Material.Neon)
	makePart(folder, "PlaygroundPostE", Vector3.new(0.8, 9, 0.8), Vector3.new(8, 4.5, -109), neonCyan, Enum.Material.Neon)
	local signBoard = makePart(folder, "PlaygroundSignBoard", Vector3.new(19, 4, 0.6), Vector3.new(0, 8.5, -109), dark, Enum.Material.SmoothPlastic)
	makeSign(folder, "PlaygroundSign", signBoard, "NEON PLAYGROUND", Color3.fromRGB(120, 255, 235), Vector3.new(0, 5, 0))

	-- SLIDE at (-70, -116): blocky steps climb the north side to a railed
	-- platform 9 studs up; the wedge chute falls away southward at ~35
	-- degrees with zero friction, so players genuinely slide to the landing.
	local slide = Instance.new("Folder")
	slide.Name = "Slide"
	slide.Parent = folder
	makePart(slide, "SlidePlatform", Vector3.new(6.5, 1, 6.5), Vector3.new(-70, 8.5, -119.5), neonCyan, Enum.Material.SmoothPlastic)
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
	chute.Color = orange
	chute.Material = Enum.Material.SmoothPlastic
	chute.Anchored = true
	chute.TopSurface = Enum.SurfaceType.Smooth
	chute.BottomSurface = Enum.SurfaceType.Smooth
	chute.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 0, 0)
	chute.Parent = slide
	for _, dx in ipairs({ -2.45, 2.45 }) do
		local rail = makePart(slide, "ChuteRail", Vector3.new(0.45, 0.6, 14.2), Vector3.new(-70 + dx, 5.6, -109.5), neonCyan, Enum.Material.SmoothPlastic)
		rail.CFrame = CFrame.new(-70 + dx, 5.6, -109.5) * CFrame.Angles(math.rad(34), 0, 0)
	end
	makePart(slide, "SlideLanding", Vector3.new(6, 0.4, 4.5), Vector3.new(-70, 0.2, -100.3), orange, Enum.Material.SmoothPlastic)

	-- SWINGS at (-25, -118): an A-frame with a neon top bar and two real Seat
	-- swings. Each swing is a Model whose PrimaryPart sits ON the bar, so
	-- PlaygroundService can rock the whole model around the bar axis.
	local swingsFolder = Instance.new("Folder")
	swingsFolder.Name = "Swings"
	swingsFolder.Parent = folder
	makePart(swingsFolder, "SwingBar", Vector3.new(19, 0.8, 0.8), Vector3.new(-25, 10.2, -118), neonCyan, Enum.Material.Neon)
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

	-- MERRY-GO-ROUND at (75, -116): a slate deck on a pink neon rim, centre
	-- pole and four handle posts; PlaygroundService spins the model and
	-- riders standing on the deck are carried around with it.
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
	local merryRim = makePart(merry, "Rim", Vector3.new(0.7, 19.4, 19.4), Vector3.new(75, 0.55, -116), Color3.fromRGB(255, 110, 200), Enum.Material.Neon)
	merryRim.Shape = Enum.PartType.Cylinder
	merryRim.Orientation = Vector3.new(0, 0, 90)
	local merryDeck = makePart(merry, "Deck", Vector3.new(1.2, 18, 18), Vector3.new(75, 1, -116), dark, Enum.Material.SmoothPlastic)
	merryDeck.Shape = Enum.PartType.Cylinder
	merryDeck.Orientation = Vector3.new(0, 0, 90)
	local merryPole = makePart(merry, "CentrePole", Vector3.new(5, 1.1, 1.1), Vector3.new(75, 3.4, -116), neonCyan, Enum.Material.Neon)
	merryPole.Shape = Enum.PartType.Cylinder
	merryPole.Orientation = Vector3.new(0, 0, 90)
	for postIndex = 1, 4 do
		local angle = math.rad(45 + (postIndex - 1) * 90)
		local post = makePart(merry, "HandlePost" .. tostring(postIndex), Vector3.new(3, 0.4, 0.4),
			Vector3.new(75 + math.cos(angle) * 6.2, 3.1, -116 + math.sin(angle) * 6.2), dark, Enum.Material.Metal)
		post.Shape = Enum.PartType.Cylinder
		post.Orientation = Vector3.new(0, 0, 90)
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
	-- grey-green bin with a dark lid and a neon band, and a ProximityPrompt
	-- that PlaygroundService turns into a once-a-minute cash rummage.
	local trashBody = makePart(folder, "TrashCan", Vector3.new(3.4, 3.2, 3.2), Vector3.new(44, 1.7, 22), Color3.fromRGB(105, 125, 105), Enum.Material.Metal)
	trashBody.Shape = Enum.PartType.Cylinder
	trashBody.Orientation = Vector3.new(0, 0, 90)
	local trashLid = makePart(folder, "TrashLid", Vector3.new(0.5, 3.7, 3.7), Vector3.new(44, 3.55, 22), dark, Enum.Material.Metal)
	trashLid.Shape = Enum.PartType.Cylinder
	trashLid.Orientation = Vector3.new(0, 0, 90)
	local trashBand = makePart(folder, "TrashBand", Vector3.new(0.45, 3.35, 3.35), Vector3.new(44, 2.5, 22), Color3.fromRGB(110, 255, 120), Enum.Material.Neon)
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

	-- BENCHES around the Neon Arena, each with a real Seat, facing the ring:
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

function WorldBuilder.BuildWorld()
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "NeonShoresWorld"
	worldFolder.Parent = Workspace

	-- Island: a warm grass top on a slightly wider sand rim, floating in a deep
	-- teal sea. The sand rim's top sits just below the grass top, so the island
	-- edge reads as a beach from any camera angle.
	makePart(worldFolder, "IslandSandRim", Vector3.new(276, 4, 276), Vector3.new(0, -2.25, 0), Color3.fromRGB(245, 205, 140), Enum.Material.Sand)
	makePart(worldFolder, "IslandGround", Vector3.new(260, 4, 260), Vector3.new(0, -2, 0), Color3.fromRGB(92, 192, 82), Enum.Material.Grass)
	local sea = makePart(worldFolder, "Sea", Vector3.new(900, 2, 900), Vector3.new(0, -5, 0), Color3.fromRGB(16, 95, 125), Enum.Material.SmoothPlastic)
	sea.Transparency = 0.25

	-- THE NEON ARENA: the spawn plaza, a glowing ring just south of the belt.
	-- A dark slate disc (built from flat cylinders) floats on a wider cyan neon
	-- disc so the rim glows, with a pink neon inlay ring around the spawn point.
	-- Every few minutes a golden brainrot appears here (EconomyService's arena
	-- event), so the ring is kept empty on purpose -- it is a stage, not a plaza.
	local neonCyan = Color3.fromRGB(40, 230, 255)
	local arenaGlow = makePart(worldFolder, "ArenaGlowBase", Vector3.new(0.5, 54, 54), Vector3.new(0, 0.25, 28), neonCyan, Enum.Material.Neon)
	arenaGlow.Shape = Enum.PartType.Cylinder
	arenaGlow.Orientation = Vector3.new(0, 0, 90)
	local arenaDisc = makePart(worldFolder, "ArenaDisc", Vector3.new(0.6, 52, 52), Vector3.new(0, 0.55, 28), Color3.fromRGB(46, 48, 62), Enum.Material.Concrete)
	arenaDisc.Shape = Enum.PartType.Cylinder
	arenaDisc.Orientation = Vector3.new(0, 0, 90)
	local arenaRing = makePart(worldFolder, "ArenaInnerRing", Vector3.new(0.25, 34, 34), Vector3.new(0, 0.92, 28), Color3.fromRGB(255, 110, 200), Enum.Material.Neon)
	arenaRing.Shape = Enum.PartType.Cylinder
	arenaRing.Orientation = Vector3.new(0, 0, 90)
	arenaRing.CanCollide = false
	local arenaCore = makePart(worldFolder, "ArenaCore", Vector3.new(0.3, 26, 26), Vector3.new(0, 1, 28), Color3.fromRGB(52, 54, 68), Enum.Material.Concrete)
	arenaCore.Shape = Enum.PartType.Cylinder
	arenaCore.Orientation = Vector3.new(0, 0, 90)
	WorldBuilder.ArenaPosition = Vector3.new(0, 0, 28)
	-- The title sign stands on two posts over the arena's north side, facing the belt.
	makePart(worldFolder, "TitlePostW", Vector3.new(0.8, 12, 0.8), Vector3.new(-13, 6, 6), Color3.fromRGB(255, 240, 90), Enum.Material.Neon)
	makePart(worldFolder, "TitlePostE", Vector3.new(0.8, 12, 0.8), Vector3.new(13, 6, 6), Color3.fromRGB(255, 240, 90), Enum.Material.Neon)
	local titleBoard = makePart(worldFolder, "TitleBoard", Vector3.new(30, 5, 0.6), Vector3.new(0, 10.5, 6), Color3.fromRGB(30, 30, 44), Enum.Material.SmoothPlastic)
	makeSign(worldFolder, "TitleSign", titleBoard, "NEON SHORES", Color3.fromRGB(255, 240, 90), Vector3.new(0, 5, 0))
	local arenaPost = makePart(worldFolder, "ArenaSignPost", Vector3.new(0.8, 8, 0.8), Vector3.new(0, 4, 53), Color3.fromRGB(255, 110, 200), Enum.Material.Neon)
	makeSign(worldFolder, "ArenaSign", arenaPost, "NEON ARENA\nGOLDEN BRAINROTS APPEAR HERE!", Color3.fromRGB(255, 190, 90), Vector3.new(0, 6, 0))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 28)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = worldFolder

	-- PURPLE ZONE: the Fuse Machine, a dark cauldron of glowing purple brew at
	-- the arena's east edge. Feed it 3 brainrots of one rarity (from the
	-- FUSE panel) and it bubbles up 1 of the next rarity.
	makePart(worldFolder, "FusePad", Vector3.new(13, 0.4, 13), Vector3.new(34, 0.2, 30), Color3.fromRGB(46, 48, 62), Enum.Material.Concrete)
	local cauldron = makePart(worldFolder, "FuseCauldron", Vector3.new(5, 7, 7), Vector3.new(34, 2.5, 30), Color3.fromRGB(38, 36, 50), Enum.Material.Metal)
	cauldron.Shape = Enum.PartType.Cylinder
	cauldron.Orientation = Vector3.new(0, 0, 90)
	local brew = makePart(worldFolder, "FuseBrew", Vector3.new(0.5, 6, 6), Vector3.new(34, 5.1, 30), Color3.fromRGB(190, 90, 255), Enum.Material.Neon)
	brew.Shape = Enum.PartType.Cylinder
	brew.Orientation = Vector3.new(0, 0, 90)
	brew.CanCollide = false
	makeSign(worldFolder, "FuseSign", cauldron, "FUSE MACHINE\n3 SAME RARITY = 1 RARITY UP", Color3.fromRGB(215, 150, 255), Vector3.new(0, 9, 0))
	makePart(worldFolder, "FusePostW", Vector3.new(0.8, 9, 0.8), Vector3.new(28, 4.5, 30), Color3.fromRGB(190, 90, 255), Enum.Material.Neon)
	makePart(worldFolder, "FusePostE", Vector3.new(0.8, 9, 0.8), Vector3.new(40, 4.5, 30), Color3.fromRGB(190, 90, 255), Enum.Material.Neon)
	WorldBuilder.FuseMachinePosition = Vector3.new(34, 0, 30)

	-- A short paved connector from the arena's north edge to the belt platform,
	-- edged with cyan neon strips, and two straight roads running between the
	-- belt and each row of bases.
	makePart(worldFolder, "ArenaToBelt", Vector3.new(16, 0.4, 14), Vector3.new(0, 0.2, -3), Color3.fromRGB(52, 54, 68), Enum.Material.Concrete)
	makePart(worldFolder, "PathEdgeE", Vector3.new(1.2, 0.25, 14), Vector3.new(7.4, 0.45, -3), neonCyan, Enum.Material.Neon)
	makePart(worldFolder, "PathEdgeW", Vector3.new(1.2, 0.25, 14), Vector3.new(-7.4, 0.45, -3), neonCyan, Enum.Material.Neon)
	makePart(worldFolder, "RoadNorth", Vector3.new(252, 0.4, 16), Vector3.new(0, 0.2, -52), Color3.fromRGB(60, 62, 76), Enum.Material.Asphalt)
	makePart(worldFolder, "RoadSouth", Vector3.new(252, 0.4, 16), Vector3.new(0, 0.2, 52), Color3.fromRGB(60, 62, 76), Enum.Material.Asphalt)

	-- ORANGE ZONE: the conveyor spine. One long belt runs east-west through the
	-- middle of the island and the bases flank it on both sides. Brainrots walk
	-- its full length (EconomyService strides them from x -80 to x 80), big sign
	-- over the middle, a chase-light pad row along the belt's front edge, and a
	-- neon orange beacon post marking the zone.
	makePart(worldFolder, "BeltPlatform", Vector3.new(192, 1, 22), Vector3.new(0, 0.25, -20), Color3.fromRGB(255, 150, 60), Enum.Material.SmoothPlastic)
	local belt = makePart(worldFolder, "ConveyorBelt", Vector3.new(184, 2, 10), Vector3.new(0, 1, -20), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
	makeSign(worldFolder, "ShopSign", belt, "SHOP BELT - WALK IN TO BUY", Color3.fromRGB(255, 165, 50), Vector3.new(0, 10, 0))
	makePart(worldFolder, "BeltBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(100, 5.5, -32), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
	for slotIndex = 1, GameConfig.ConveyorMaxOnBelt do
		local slotPosition = Vector3.new(-72 + (slotIndex - 1) * 24, 0.95, -11.5)
		local slotPad = makePart(worldFolder, "ConveyorSlot" .. tostring(slotIndex), Vector3.new(9, 0.4, 9), slotPosition, Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
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
	makePart(worldFolder, "EggBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(-122, 5.5, -20), Color3.fromRGB(255, 120, 220), Enum.Material.Neon)
	WorldBuilder.EggMachinePosition = Vector3.new(-108, 0, -4)

	-- GOLD ZONE: the rebirth shrine caps the belt's EAST end, golden steps up
	-- to a glowing crystal.
	for step = 1, 3 do
		makePart(worldFolder, "ShrineStep" .. tostring(step), Vector3.new(20 - step * 3, 1, 20 - step * 3), Vector3.new(108, step * 0.5, -20), Color3.fromRGB(255, 200, 70), Enum.Material.Metal)
	end
	local crystal = makePart(worldFolder, "RebirthCrystal", Vector3.new(4, 8, 4), Vector3.new(108, 7, -20), Color3.fromRGB(150, 255, 255), Enum.Material.Neon)
	crystal.Orientation = Vector3.new(0, 45, 0)
	makeSign(worldFolder, "RebirthSign", crystal, "REBIRTH SHRINE\nRESET FOR +100% INCOME", Color3.fromRGB(255, 215, 80), Vector3.new(0, 9, 0))
	makePart(worldFolder, "ShrineBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(122, 5.5, -20), Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
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

	-- GREEN ZONE: the high hill, a grass ridge along the south beach between
	-- the south bases and the sea. Stand up here and the Big Wave cannot take you.
	local hill = makePart(worldFolder, "ShelterHill", Vector3.new(56, WorldBuilder.HighGroundTopY, 20), Vector3.new(0, WorldBuilder.HighGroundTopY / 2, 114), Color3.fromRGB(92, 192, 82), Enum.Material.Grass)
	makeSign(worldFolder, "ShelterSign", hill, "HIGH HILL\nSAFE FROM THE BIG WAVE", Color3.fromRGB(120, 255, 140), Vector3.new(0, 16, 0))
	makePart(worldFolder, "HillBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(34, 5.5, 114), Color3.fromRGB(110, 255, 120), Enum.Material.Neon)

	-- Palm trees in neat clusters: the beach rim, the arena sides and the gaps
	-- between belt and bases -- never under a base plot, the belt or the arena.
	-- Every other palm carries a neon glowfruit.
	local palmSpots = {
		{ Position = Vector3.new(-120, 0, -40), Glow = true, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(120, 0, -44), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-120, 0, 40), Glow = true, Color = Color3.fromRGB(60, 225, 255) },
		{ Position = Vector3.new(124, 0, 36), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-48, 0, -38), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(48, 0, -38), Glow = true, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(-60, 0, 20), Glow = true, Color = Color3.fromRGB(255, 220, 80) },
		{ Position = Vector3.new(60, 0, 20), Glow = false, Color = Color3.fromRGB(60, 225, 255) },
		{ Position = Vector3.new(0, 0, -38), Glow = true, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(-88, 0, 120), Glow = false, Color = Color3.fromRGB(255, 120, 220) },
		{ Position = Vector3.new(88, 0, 120), Glow = true, Color = Color3.fromRGB(60, 225, 255) },
		{ Position = Vector3.new(-124, 0, 20), Glow = false, Color = Color3.fromRGB(255, 220, 80) },
	}
	for palmIndex, spot in ipairs(palmSpots) do
		buildPalm(worldFolder, "Palm" .. tostring(palmIndex), spot.Position, spot.Glow, spot.Color)
	end

	-- The Neon Playground fills the dead north strip behind the north bases,
	-- and its benches ring the arena (built inside buildPlayground).
	buildPlayground(worldFolder)

	-- The Big Wave wall itself: a huge sheet of water with a white foam crest,
	-- tweened smoothly across the island by TsunamiService.
	local wall = makePart(worldFolder, "TsunamiWall", Vector3.new(280, 30, 6), Vector3.new(-165, 12, 0), Color3.fromRGB(30, 110, 230), Enum.Material.SmoothPlastic)
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
