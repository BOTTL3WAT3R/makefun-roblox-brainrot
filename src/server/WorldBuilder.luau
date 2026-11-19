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
WorldBuilder.TsunamiFoam = nil :: Model?
WorldBuilder.EggPrompt = nil :: ProximityPrompt?
WorldBuilder.GachaPrompt = nil :: ProximityPrompt?
WorldBuilder.FusePrompt = nil :: ProximityPrompt?
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
		Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic)
	makeSign(baseFolder, "LockSign", lockButton, "LOCK BASE\n" .. tostring(GameConfig.LockDurationSeconds) .. "s", Color3.fromRGB(255, 90, 110), Vector3.new(0, 5, 0))

	local lasers = {}
	for side = 1, 4 do
		local angle = (side - 1) * math.pi / 2
		local offset = Vector3.new(math.sin(angle) * 22, 3, math.cos(angle) * 22)
		local laser = makePart(baseFolder, "LaserWall" .. tostring(side), Vector3.new(44, 5, 0.6), origin + offset,
			Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic)
		laser.Orientation = Vector3.new(0, math.deg(angle), 0)
		laser.Transparency = 1
		laser.CanCollide = false
		table.insert(lasers, laser)
	end

	-- MINI CANDY HOUSE at the plot's back edge (the side away from the belt):
	-- pure dressing in the base's own candy colour, so every plot reads as a
	-- little sweet home like the concept art. The back strip is dead ground
	-- -- the pads end 11 studs from centre, the lock button sits at the
	-- front corner, the spawn lands mid-plot -- so a 10x8 house centred 17
	-- studs behind centre (spanning 13..21) clears all of them, and its
	-- front face looks down the pad rows toward the belt.
	local houseCentre = origin + Vector3.new(0, 0, -facing * 17)
	local roofColor = BASE_SLOT_COLORS[(index % #BASE_SLOT_COLORS) + 1]
	makePart(baseFolder, "HouseWalls", Vector3.new(10, 6, 8), houseCentre + Vector3.new(0, 4, 0), slotColor, Enum.Material.SmoothPlastic)
	-- A gable roof from two wedges back to back: a stock wedge stands its
	-- tall face at its +Z end, so the north wedge as-is has its tall face
	-- toward the centre, and the south wedge turned 180 degrees about Y
	-- mirrors it -- the two slopes meet at a ridge along X.
	local roofSouth = Instance.new("WedgePart")
	roofSouth.Name = "HouseRoofS"
	roofSouth.Size = Vector3.new(11, 3, 4.6)
	roofSouth.CFrame = CFrame.new(houseCentre + Vector3.new(0, 8.5, 2)) * CFrame.Angles(0, math.pi, 0)
	roofSouth.Color = roofColor
	roofSouth.Material = Enum.Material.SmoothPlastic
	roofSouth.Anchored = true
	roofSouth.TopSurface = Enum.SurfaceType.Smooth
	roofSouth.BottomSurface = Enum.SurfaceType.Smooth
	roofSouth.Parent = baseFolder
	local roofNorth = Instance.new("WedgePart")
	roofNorth.Name = "HouseRoofN"
	roofNorth.Size = Vector3.new(11, 3, 4.6)
	roofNorth.CFrame = CFrame.new(houseCentre + Vector3.new(0, 8.5, -2))
	roofNorth.Color = roofColor
	roofNorth.Material = Enum.Material.SmoothPlastic
	roofNorth.Anchored = true
	roofNorth.TopSurface = Enum.SurfaceType.Smooth
	roofNorth.BottomSurface = Enum.SurfaceType.Smooth
	roofNorth.Parent = baseFolder
	-- The door slab on the front face (the side toward the belt), and a
	-- little chimney poking out of the roof's east slope.
	makePart(baseFolder, "HouseDoor", Vector3.new(2.2, 3.6, 0.3), houseCentre + Vector3.new(0, 2.8, facing * 4.1),
		Color3.fromRGB(94, 58, 32), Enum.Material.SmoothPlastic)
	makePart(baseFolder, "HouseChimney", Vector3.new(1.2, 2.6, 1.2), houseCentre + Vector3.new(3.2, 10.6, 0),
		Color3.fromRGB(150, 95, 55), Enum.Material.SmoothPlastic)

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
		laser.Transparency = if visible then 0.5 else 1
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

-- Every chair in the game carries an E prompt that sits the player by
-- script (PlaygroundService handles Triggered): touch-sitting is flaky on
-- the rides, whose decks and swings pivot every frame, so sitting down is
-- deliberate instead -- walk up, press E, sit; press E again to stand.
local function addSitPrompt(seat: BasePart, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
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
	local seatPart = add("Seat", "Seat", Vector3.new(5.5, 0.7, 1.9), Vector3.new(0, 1.9, 0), dark, Enum.Material.SmoothPlastic)
	addSitPrompt(seatPart, "Bench")
	add("Part", "Backrest", Vector3.new(5.5, 2.4, 0.45), Vector3.new(0, 3.6, 1.1), dark, Enum.Material.SmoothPlastic)
	add("Part", "Trim", Vector3.new(5.5, 0.3, 0.3), Vector3.new(0, 1.45, -1), Color3.fromRGB(255, 130, 190), Enum.Material.Neon)
	for _, x in ipairs({ -2.3, 2.3 }) do
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, 0.55), dark, nil)
		add("Part", "Leg", Vector3.new(0.55, 1.6, 0.55), Vector3.new(x, 0.8, -0.55), dark, nil)
	end
	return bench, seatPart
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

	-- Every Seat built below (swings, merry-go-round, arena benches) is
	-- collected here and exported in WorldBuilder.Playground, so
	-- PlaygroundService can wire all their SitPrompts to one handler.
	local playgroundSeats: { Seat } = {}

	-- The safety mat: one soft pastel-pink slab so the whole zone reads as one place.
	makePart(folder, "SafetyMat", Vector3.new(190, 0.35, 16), Vector3.new(0, 0.18, -119), Color3.fromRGB(255, 190, 220), Enum.Material.SmoothPlastic)
	local matEdge = makePart(folder, "MatEdge", Vector3.new(190, 0.25, 0.9), Vector3.new(0, 0.45, -111.4), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	matEdge.CanCollide = false

	-- A white picket fence along both long edges of the mat, like the
	-- concept art's fenced playground: two rails with a slat every ~4
	-- studs. The north edge runs full length; the south edge leaves the
	-- centre open under the zone sign (the way in) and a second gap where
	-- the original bounce pad's disc crosses the fence line at x 45.
	local white = Color3.fromRGB(255, 255, 255)
	local function buildFenceRun(xStart: number, xEnd: number, z: number)
		local length = xEnd - xStart
		local midX = (xStart + xEnd) / 2
		for _, railY in ipairs({ 1.05, 2.15 }) do
			makePart(folder, "FenceRail", Vector3.new(length, 0.28, 0.12), Vector3.new(midX, railY, z), white, Enum.Material.SmoothPlastic)
		end
		local slatCount = math.floor(length / 4)
		for slatIndex = 0, slatCount do
			local slat = makePart(folder, "FenceSlat", Vector3.new(0.35, 2.6, 0.15), Vector3.new(xStart + slatIndex * 4, 1.6, z), white, Enum.Material.SmoothPlastic)
			slat.CanCollide = false
		end
	end
	buildFenceRun(-95, 95, -127.4)
	buildFenceRun(-95, -14, -110.6)
	buildFenceRun(14, 36.5, -110.6)
	buildFenceRun(53.5, 95, -110.6)

	-- SANDBOX in the one clear pocket of the mat -- between the swings
	-- (x -31..-19) and the seesaw (x 17..33), against the north fence: a
	-- sand square in a low wooden rim, with a little pink bucket.
	makePart(folder, "SandboxSand", Vector3.new(10, 0.5, 10), Vector3.new(0, 0.55, -121), Color3.fromRGB(240, 215, 160), Enum.Material.Sand)
	makePart(folder, "SandboxRimN", Vector3.new(10.6, 0.9, 0.5), Vector3.new(0, 0.8, -126.3), dark, Enum.Material.SmoothPlastic)
	makePart(folder, "SandboxRimS", Vector3.new(10.6, 0.9, 0.5), Vector3.new(0, 0.8, -115.7), dark, Enum.Material.SmoothPlastic)
	makePart(folder, "SandboxRimE", Vector3.new(0.5, 0.9, 10.6), Vector3.new(5.3, 0.8, -121), dark, Enum.Material.SmoothPlastic)
	makePart(folder, "SandboxRimW", Vector3.new(0.5, 0.9, 10.6), Vector3.new(-5.3, 0.8, -121), dark, Enum.Material.SmoothPlastic)
	local bucket = makePart(folder, "SandboxBucket", Vector3.new(1.2, 1.1, 1.2), Vector3.new(2.2, 1.3, -120), Color3.fromRGB(255, 130, 190), Enum.Material.SmoothPlastic)
	bucket.Shape = Enum.PartType.Cylinder
	bucket.Orientation = Vector3.new(0, 0, 90)
	bucket.CanCollide = false

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
	-- A stock WedgePart stands its tall face at the +Z end; the slide needs
	-- the tall face NORTH, butted against the platform (whose top is y 9 at
	-- z -116.25), with the slope falling away south to the landing. Turned
	-- 180 degrees about Y, the wedge's 9-over-13.5 slope (~34 degrees)
	-- runs exactly parallel to the lavender chute rails below.
	chute.CFrame = CFrame.new(Vector3.new(-70, 4.5, -109.5)) * CFrame.Angles(0, math.pi, 0)
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
		addSitPrompt(seat, "Swing")
		table.insert(playgroundSeats, seat)
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
		addSitPrompt(seat, "Merry-Go-Round")
		table.insert(playgroundSeats, seat)
		local seatPost = makePart(merry, "SeatPost" .. tostring(seatIndex), Vector3.new(0.5, 1, 0.5), seatPosition, dark, Enum.Material.Metal)
		seatPost.CFrame = seatFrame * CFrame.new(0, -0.75, 0)
		local seatBack = makePart(merry, "SeatBack" .. tostring(seatIndex), Vector3.new(2.4, 1.8, 0.4), seatPosition, merrySeatColors[seatIndex], Enum.Material.SmoothPlastic)
		seatBack.CFrame = seatFrame * CFrame.new(0, 1.05, 1.1)
	end

	-- BOUNCE PADS: the original on the playground's south edge at (45, -112)
	-- -- the strip between the mat and the north bases is open grass, so it
	-- sits clear of every plot -- plus four more planted in the island's open
	-- lanes, each checked against the belt (z -31..-9), the base plots
	-- (z 60..104 and -104..-60), the machines and the roads:
	--   * (38, 40): the grass south-east of the Candy Arena rim, between the
	--     Fuse Machine's pad (ends z 36.5) and the south road (starts z 44);
	--   * (0, 88): the corridor between the two middle south bases (their
	--     plots start at |x| 10) at the foot of the chocolate hill (z 104),
	--     so a good bounce starts the climb to the safe top;
	--   * (-88, 8) and its east mirror (88, 8): the open lanes beside the
	--     Egg Machine and Rebirth Shrine approaches.
	-- PlaygroundService launches whoever steps on any of them.
	local function makeBouncePad(name: string, position: Vector3, postPosition: Vector3): Part
		local pad = makePart(folder, name, Vector3.new(0.8, 10, 10), position, Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder
		pad.Orientation = Vector3.new(0, 0, 90)
		local post = makePart(folder, name .. "Post", Vector3.new(0.7, 7, 0.7), postPosition, Color3.fromRGB(255, 80, 180), Enum.Material.Neon)
		makeSign(folder, name .. "Sign", post, "BOUNCE!", Color3.fromRGB(255, 150, 220), Vector3.new(0, 5, 0))
		return pad
	end
	local bouncePads = {
		makeBouncePad("BouncePad", Vector3.new(45, 0.4, -112), Vector3.new(51.5, 3.5, -106.5)),
		makeBouncePad("BouncePadArena", Vector3.new(38, 0.4, 40), Vector3.new(44.5, 3.5, 45.5)),
		makeBouncePad("BouncePadHill", Vector3.new(0, 0.4, 88), Vector3.new(6.5, 3.5, 93.5)),
		makeBouncePad("BouncePadWest", Vector3.new(-88, 0.4, 8), Vector3.new(-81.5, 3.5, 13.5)),
		makeBouncePad("BouncePadEast", Vector3.new(88, 0.4, 8), Vector3.new(94.5, 3.5, 13.5)),
	}

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
	local _, benchSeatNW = buildBench(folder, "BenchNW", Vector3.new(-14, 0, -2), arenaCentre)
	local _, benchSeatNE = buildBench(folder, "BenchNE", Vector3.new(14, 0, -2), arenaCentre)
	local _, benchSeatW = buildBench(folder, "BenchW", Vector3.new(-31, 0, 28), arenaCentre)
	local _, benchSeatS = buildBench(folder, "BenchS", Vector3.new(0, 0, 62), arenaCentre)
	for _, benchSeat in ipairs({ benchSeatNW, benchSeatNE, benchSeatW, benchSeatS }) do
		table.insert(playgroundSeats, benchSeat)
	end

	WorldBuilder.PlaygroundFolder = folder
	WorldBuilder.Playground = {
		Swings = swings,
		Seesaw = seesaw,
		SeesawPivot = Vector3.new(25, 2.45, -116),
		MerryGoRound = merry,
		MerryPivot = Vector3.new(75, 0, -116),
		BouncePads = bouncePads,
		TrashPrompt = prompt,
		Seats = playgroundSeats,
	}
end

-- CANDY DECOR: pure dressing built from primitives -- lollipop trees scattered
-- on the open lanes and rim, candy-cane poles along the belt ends and paths,
-- gumdrops sprinkled on the cream rim, sprinkles scattered over the two
-- frosting paths, marshmallow piles on the rim lanes and gift boxes near
-- the bases. Everything is anchored; only the lollipop trunks collide.
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
		-- Six more on the open lanes the palm trees used to stand in (the
		-- mockup island grows lollipops, not palms): the lane between belt
		-- and north road, the two arena-side lanes, and the south-west rim.
		Vector3.new(-48, 0, -38), Vector3.new(48, 0, -38), Vector3.new(0, 0, -38),
		Vector3.new(-60, 0, 20), Vector3.new(60, 0, 20), Vector3.new(-88, 0, 120),
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
		Vector3.new(100, 0, 133), Vector3.new(-100, 0, 133), Vector3.new(100, 0, -133),
		Vector3.new(-100, 0, -133), Vector3.new(133, 0, 20), Vector3.new(-133, 0, 20),
		Vector3.new(133, 0, -20), Vector3.new(-133, 0, -20),
	}
	for index, spot in ipairs(gumdropSpots) do
		local drop = makePart(folder, "Gumdrop" .. tostring(index), Vector3.new(1.8, 1.3, 1.8), spot + Vector3.new(0, 0.35, 0), candyColors[((index - 1) % #candyColors) + 1], Enum.Material.SmoothPlastic)
		drop.Shape = Enum.PartType.Ball
		drop.CanCollide = false
	end

	-- Sprinkles: tiny flat candy sticks scattered over the two frosting paths
	-- (deterministic pseudo-random spots, kept off the belt and the plots).
	for index = 1, 40 do
		local onNorth = index <= 20
		local laneIndex = if onNorth then index else index - 20
		local x = -114 + (laneIndex - 1) * 12 + ((laneIndex * 37) % 7) - 3
		local z = (if onNorth then -52 else 52) + ((laneIndex * 29) % 9) - 4
		local sprinkle = makePart(folder, "Sprinkle" .. tostring(index), Vector3.new(1.5, 0.14, 0.5), Vector3.new(x, 0.55, z), candyColors[((index - 1) % #candyColors) + 1], Enum.Material.SmoothPlastic)
		sprinkle.Orientation = Vector3.new(0, (index * 47) % 180, 0)
		sprinkle.CanCollide = false
	end

	-- Marshmallow piles: clusters of squashed white spheres heaped on the
	-- rim lanes beside the belt ends and behind the corner bases, snapped
	-- to the ground height at each spot.
	local marshmallowSpots = {
		Vector3.new(-124, 0, 100), Vector3.new(124, 0, 100), Vector3.new(-124, 0, -100),
		Vector3.new(124, 0, -100), Vector3.new(-124, 0, 0), Vector3.new(124, 0, 0),
	}
	for pileIndex, spot in ipairs(marshmallowSpots) do
		local groundY = groundHeightAt(spot.X, spot.Z)
		for puffIndex = 1, 4 do
			local angle = (puffIndex - 1) * (math.pi / 2) + pileIndex
			local offset = if puffIndex == 1 then Vector3.new(0, 0, 0) else Vector3.new(math.cos(angle) * 1.9, 0, math.sin(angle) * 1.9)
			local puffSize = 2.7 - puffIndex * 0.25
			local puff = makePart(folder, "Marshmallow" .. tostring(pileIndex) .. "_" .. tostring(puffIndex),
				Vector3.new(puffSize, puffSize * 0.62, puffSize),
				spot + offset + Vector3.new(0, groundY + 0.55, 0), Color3.fromRGB(255, 252, 248), Enum.Material.SmoothPlastic)
			puff.Shape = Enum.PartType.Ball
			puff.CanCollide = false
		end
	end

	-- Gift boxes: little candy cubes with a pale ribbon cross on top,
	-- left on the open lanes near the bases and the arena.
	local giftSpots = {
		Vector3.new(56, 0, -38), Vector3.new(-56, 0, -38), Vector3.new(32, 0, 57),
		Vector3.new(-32, 0, 57), Vector3.new(118, 0, -56), Vector3.new(-118, 0, 56),
	}
	for giftIndex, spot in ipairs(giftSpots) do
		local giftColor = candyColors[((giftIndex - 1) % #candyColors) + 1]
		local groundY = groundHeightAt(spot.X, spot.Z)
		makePart(folder, "GiftBox" .. tostring(giftIndex), Vector3.new(2.2, 2.2, 2.2), spot + Vector3.new(0, groundY + 1.1, 0), giftColor, Enum.Material.SmoothPlastic)
		local ribbonA = makePart(folder, "GiftRibbon" .. tostring(giftIndex) .. "A", Vector3.new(2.3, 0.25, 0.5), spot + Vector3.new(0, groundY + 2.3, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		ribbonA.CanCollide = false
		local ribbonB = makePart(folder, "GiftRibbon" .. tostring(giftIndex) .. "B", Vector3.new(0.5, 0.25, 2.3), spot + Vector3.new(0, groundY + 2.3, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		ribbonB.CanCollide = false
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
	-- The candy-cane ring around the rim: 18 red/white arc segments hugging
	-- the glow base's edge (radius 26.3, between the disc's 26 and the
	-- glow's 27), laid almost flat -- a half-stud lip over the disc, so
	-- players step in and out freely and the golden-brainrot stage inside
	-- is untouched. Each segment's local X points radially outward, so its
	-- long Z side runs along the ring.
	for segmentIndex = 0, 17 do
		local angle = segmentIndex * (math.pi * 2 / 18)
		local segmentColor = if segmentIndex % 2 == 0 then Color3.fromRGB(255, 70, 80) else Color3.fromRGB(255, 255, 255)
		local segment = makePart(worldFolder, "ArenaCaneSegment" .. tostring(segmentIndex + 1), Vector3.new(2.4, 0.9, 9.6),
			Vector3.new(math.cos(angle) * 26.3, 0.95, 28 + math.sin(angle) * 26.3), segmentColor, Enum.Material.SmoothPlastic)
		segment.CFrame = CFrame.new(segment.Position) * CFrame.Angles(0, -angle, 0)
	end
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
	-- The machine's own E prompt: the FUSE panel is not the only door in.
	-- FuseService turns this into an automatic fuse attempt with feedback.
	local fusePrompt = Instance.new("ProximityPrompt")
	fusePrompt.Name = "FusePrompt"
	fusePrompt.ActionText = "Fuse"
	fusePrompt.ObjectText = "Fuse Machine"
	fusePrompt.KeyboardKeyCode = Enum.KeyCode.E
	fusePrompt.HoldDuration = 0
	fusePrompt.MaxActivationDistance = 12
	fusePrompt.RequiresLineOfSight = false
	fusePrompt.Parent = cauldron
	WorldBuilder.FusePrompt = fusePrompt
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
	local gachaPrompt = Instance.new("ProximityPrompt")
	gachaPrompt.Name = "GachaPrompt"
	gachaPrompt.ActionText = "Spin " .. GameConfig.FormatCash(GameConfig.GachaPrice)
	gachaPrompt.ObjectText = "Gacha Capsule"
	gachaPrompt.KeyboardKeyCode = Enum.KeyCode.E
	gachaPrompt.HoldDuration = 0
	gachaPrompt.MaxActivationDistance = 12
	gachaPrompt.RequiresLineOfSight = false
	gachaPrompt.Parent = gachaBase
	WorldBuilder.GachaPrompt = gachaPrompt
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
	-- Belt rollers: yellow wheels studding the belt's two long faces, like
	-- the concept art's conveyor. They sit in the visible band of the face
	-- (y 0.8..1.9, below the belt top the walkers walk on), axis pointing
	-- outward. The south face skips any roller that would bite into a
	-- conveyor slot pad on the apron in front of it.
	for rollerIndex = 0, 21 do
		local rollerX = -84 + rollerIndex * 8
		local northRoller = makePart(worldFolder, "BeltRollerN" .. tostring(rollerIndex + 1), Vector3.new(0.7, 1.1, 1.1),
			Vector3.new(rollerX, 1.35, -25.3), Color3.fromRGB(255, 205, 60), Enum.Material.SmoothPlastic)
		northRoller.Shape = Enum.PartType.Cylinder
		northRoller.Orientation = Vector3.new(0, 90, 0)
		northRoller.CanCollide = false
		local nearPad = false
		for slotIndex = 1, GameConfig.ConveyorMaxOnBelt do
			if math.abs(rollerX - (-72 + (slotIndex - 1) * 24)) < 5.2 then
				nearPad = true
				break
			end
		end
		if not nearPad then
			local southRoller = makePart(worldFolder, "BeltRollerS" .. tostring(rollerIndex + 1), Vector3.new(0.7, 1.1, 1.1),
				Vector3.new(rollerX, 1.35, -14.7), Color3.fromRGB(255, 205, 60), Enum.Material.SmoothPlastic)
			southRoller.Shape = Enum.PartType.Cylinder
			southRoller.Orientation = Vector3.new(0, 90, 0)
			southRoller.CanCollide = false
		end
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
	local eggPrompt = Instance.new("ProximityPrompt")
	eggPrompt.Name = "HatchPrompt"
	eggPrompt.ActionText = "Hatch " .. GameConfig.FormatCash(GameConfig.EggPrice)
	eggPrompt.ObjectText = "Egg Machine"
	eggPrompt.KeyboardKeyCode = Enum.KeyCode.E
	eggPrompt.HoldDuration = 0
	eggPrompt.MaxActivationDistance = 12
	eggPrompt.RequiresLineOfSight = false
	eggPrompt.Parent = eggBase
	WorldBuilder.EggPrompt = eggPrompt
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
	-- Hill dressing: flattened blobs of darker melted chocolate draped over
	-- the cap's edges, and chocolate chunks scattered on the cap and fallen
	-- at the front foot -- the concept art's churning chocolate hilltop.
	-- The cap's centre (where wave refugees stand, under the sign) is kept
	-- clear; every blob hugs an edge and every chunk sits off-centre.
	local capTopY = WorldBuilder.HighGroundTopY + 0.9
	local blobSpots = {
		Vector3.new(-20, capTopY, 105.5), Vector3.new(13, capTopY, 105),
		Vector3.new(-9, capTopY, 122.5), Vector3.new(21, capTopY, 121.5),
		Vector3.new(27.5, capTopY, 113), Vector3.new(-27.5, capTopY, 116),
	}
	for blobIndex, spot in ipairs(blobSpots) do
		local blob = makePart(worldFolder, "ChocolateBlob" .. tostring(blobIndex), Vector3.new(11, 2, 8), spot, Color3.fromRGB(74, 44, 24), Enum.Material.SmoothPlastic)
		blob.Shape = Enum.PartType.Ball
		blob.Orientation = Vector3.new(0, (blobIndex * 53) % 180, 0)
		blob.CanCollide = false
	end
	local chunkSpots = {
		{ Position = Vector3.new(-24, capTopY + 0.8, 120), Size = 2.6 },
		{ Position = Vector3.new(17, capTopY + 0.7, 108), Size = 2.2 },
		{ Position = Vector3.new(24, capTopY + 0.9, 118), Size = 3 },
		{ Position = Vector3.new(-16, capTopY + 0.6, 107), Size = 2 },
		{ Position = Vector3.new(5, capTopY + 0.6, 120.5), Size = 2.2 },
		{ Position = Vector3.new(-7, 1, 99.5), Size = 2.8 },
		{ Position = Vector3.new(6, 0.9, 101), Size = 2.4 },
		{ Position = Vector3.new(2, 1.1, 97), Size = 2 },
		{ Position = Vector3.new(31.5, 0.9, 108), Size = 2.6 },
		{ Position = Vector3.new(-31.5, 1, 120), Size = 2.4 },
	}
	for chunkIndex, chunk in ipairs(chunkSpots) do
		local piece = makePart(worldFolder, "ChocolateChunk" .. tostring(chunkIndex), Vector3.new(chunk.Size, chunk.Size, chunk.Size), chunk.Position,
			Color3.fromRGB(90, 54, 28), Enum.Material.SmoothPlastic)
		piece.Orientation = Vector3.new((chunkIndex * 31) % 40 - 20, (chunkIndex * 47) % 180, (chunkIndex * 17) % 30 - 15)
	end
	makeSign(worldFolder, "ShelterSign", hill, "HIGH HILL\nSAFE FROM THE BIG WAVE", Color3.fromRGB(255, 240, 200), Vector3.new(0, 16, 0))
	makePart(worldFolder, "HillBeacon", Vector3.new(0.8, 11, 0.8), Vector3.new(34, 5.5, 114), Color3.fromRGB(255, 130, 190), Enum.Material.Neon)

	-- No palm trees: the concept island grows lollipops instead. The lanes
	-- the palms used to stand in are covered by the extra lollipop trees
	-- and marshmallow piles in buildCandyDecor below.

	-- The Candy Playground fills the dead north strip behind the north bases,
	-- and its benches ring the arena (built inside buildPlayground).
	buildPlayground(worldFolder)

	-- Candy dressing over the whole island: lollipop trees, candy-cane poles,
	-- gumdrops on the rim and sprinkles on the paths.
	buildCandyDecor(worldFolder)

	-- The Big Wave wall itself: a huge sheet of strawberry-pink soda, mostly
	-- see-through (Transparency 0.78) so standing in its path tints the world
	-- pink instead of blanking the screen, crowned with a foam crest -- a
	-- white slab with a row of foam bubbles along its top edge -- so it reads
	-- as a cresting wave. TsunamiService tweens the wall part and the foam
	-- MODEL (by CFrame) smoothly across the island together.
	local wall = makePart(worldFolder, "TsunamiWall", Vector3.new(280, 30, 6), Vector3.new(-165, 12, 0), Color3.fromRGB(255, 110, 160), Enum.Material.SmoothPlastic)
	wall.Transparency = 0.78
	wall.CanCollide = false
	WorldBuilder.TsunamiWall = wall
	local foam = Instance.new("Model")
	foam.Name = "TsunamiFoam"
	foam.Parent = worldFolder
	local foamRoot = Instance.new("Part")
	foamRoot.Name = "FoamRoot"
	foamRoot.Size = Vector3.new(1, 1, 1)
	foamRoot.Position = Vector3.new(-165, 28.5, 0)
	foamRoot.Transparency = 1
	foamRoot.Anchored = true
	foamRoot.CanCollide = false
	foamRoot.Parent = foam
	foam.PrimaryPart = foamRoot
	local foamSlab = makePart(foam, "FoamSlab", Vector3.new(280, 2.2, 6.8), Vector3.new(-165, 28.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	foamSlab.Transparency = 0.1
	foamSlab.CanCollide = false
	for bubbleIndex = 1, 18 do
		local bubbleSize = if bubbleIndex % 2 == 0 then 4.1 else 3.2
		local bubble = makePart(foam, "FoamBubble" .. tostring(bubbleIndex), Vector3.new(bubbleSize, bubbleSize, bubbleSize),
			Vector3.new(-165 - 133 + (bubbleIndex - 1) * (266 / 17), 30.3, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
		bubble.Shape = Enum.PartType.Ball
		bubble.Transparency = 0.1
		bubble.CanCollide = false
	end
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
