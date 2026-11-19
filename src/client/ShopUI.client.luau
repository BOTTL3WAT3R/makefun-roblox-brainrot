-- ShopUI.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Candy Island -- the panels over the 3D world: a BOOST panel selling four
-- cash-bought powers (speed, wave shield, income x2, luck -- there is no shop
-- list any more: the walking belt is the only way to buy a brainrot), a MY BASE
-- panel listing what you own with a SELL button each, an INDEX book of the
-- whole 48-character cast -- real 3D models in viewport tiles, silhouettes
-- for the ones still missing, and collection milestones in the footer -- a
-- FUSE panel that trades 3 same-rarity brainrots up a tier, and the EGG,
-- REBIRTH and GACHA buttons (the gacha fires its premium spin straight from
-- the button -- the capsule machine and the toast are its interface).
-- All four panels (BOOST, MY BASE, INDEX and FUSE) are
-- centred modals, so they never sit under the right-hand button column or the
-- top-left corner where Roblox draws its own menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "CandyPanels"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makePanel(name: string, title: string): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.fromOffset(560, 460)
	panel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 90, 220)
	stroke.Thickness = 2
	stroke.Parent = panel
	local heading = Instance.new("TextLabel")
	heading.Name = "PanelTitle"
	heading.Size = UDim2.new(1, 0, 0, 44)
	heading.BackgroundTransparency = 1
	heading.Text = title
	heading.TextColor3 = Color3.fromRGB(255, 255, 255)
	heading.TextSize = 26
	heading.Font = Enum.Font.FredokaOne
	heading.Parent = panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PanelScroll"
	scroll.Position = UDim2.fromOffset(6, 48)
	scroll.Size = UDim2.new(1, -12, 1, -54)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroll
	scroll.Parent = panel
	local close = Instance.new("TextButton")
	close.Name = "PanelClose"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.TextSize = 20
	close.Font = Enum.Font.FredokaOne
	close.Text = "X"
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	close.Parent = panel
	panel.Parent = gui
	return panel
end

local function makeRow(panel: Frame, text: string, buttonText: string, buttonColor: Color3, onClick: () -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(38, 38, 54)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -118, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 17
	label.Font = Enum.Font.FredokaOne
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.fromOffset(104, 40)
	button.BackgroundColor3 = buttonColor
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.Font = Enum.Font.FredokaOne
	button.Text = buttonText
	button.Activated:Connect(onClick)
	button.Parent = row
	local scroll = panel:FindFirstChild("PanelScroll")
	row.Parent = scroll or panel
	return row
end

-- Boost panel: one row per boost in GameConfig.Boosts (the same table the
-- server validates against). The price button doubles as the status readout:
-- it shows the live countdown while a timed boost runs, or HELD while a Wave
-- Shield is waiting, and refreshes from every state snapshot.
local boostPanel = makePanel("BoostPanel", "BOOSTS")
local boostButtons: { [string]: TextButton } = {}
local BOOST_BUTTON_COLOR = Color3.fromRGB(230, 150, 40)
local BOOST_ACTIVE_COLOR = Color3.fromRGB(70, 70, 85)
for _, boost in ipairs(GameConfig.Boosts) do
	local durationText = if boost.OneTime then "one save" else tostring(boost.DurationSeconds) .. "s"
	local rowText = string.format("%s (%s)\n%s", boost.Name, durationText, boost.Description)
	local row = makeRow(boostPanel, rowText, GameConfig.FormatCash(boost.Price), BOOST_BUTTON_COLOR, function()
		remotes:WaitForChild("BuyBoost"):FireServer(boost.Id)
	end)
	local button = row:FindFirstChildOfClass("TextButton")
	if button then
		boostButtons[boost.Id] = button
	end
end

local function rebuildBoostPanel(snapshot: any)
	if not snapshot.Boosts then
		return
	end
	for _, boost in ipairs(GameConfig.Boosts) do
		local button = boostButtons[boost.Id]
		if button then
			if boost.OneTime then
				if snapshot.Boosts.WaveShield then
					button.Text = "HELD"
					button.BackgroundColor3 = BOOST_ACTIVE_COLOR
				else
					button.Text = GameConfig.FormatCash(boost.Price)
					button.BackgroundColor3 = BOOST_BUTTON_COLOR
				end
			else
				local secondsLeft = snapshot.Boosts[boost.Id .. "Left"] or 0
				if secondsLeft > 0 then
					button.Text = "ACTIVE " .. tostring(secondsLeft) .. "s"
					button.BackgroundColor3 = BOOST_ACTIVE_COLOR
				else
					button.Text = GameConfig.FormatCash(boost.Price)
					button.BackgroundColor3 = BOOST_BUTTON_COLOR
				end
			end
		end
	end
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildBoostPanel)

-- Base panel: rebuilt from every state snapshot, one SELL row per placed brainrot.
local basePanel = makePanel("BasePanel", "MY BASE")
local dynamicRows: { Frame } = {}

local function rebuildBasePanel(snapshot: any)
	for _, row in ipairs(dynamicRows) do
		row:Destroy()
	end
	dynamicRows = {}
	for _, placed in ipairs(snapshot.Placed) do
		local mutationText = if placed.Mutation == "Normal" then "" else " " .. placed.Mutation
		local rowText = string.format("%s%s [%s]\n+$%d/s", placed.Name, mutationText, placed.Rarity, placed.IncomePerSecond)
		local row = makeRow(basePanel, rowText, "SELL", Color3.fromRGB(200, 120, 40), function()
			remotes:WaitForChild("SellBrainrot"):FireServer(placed.Uid)
		end)
		table.insert(dynamicRows, row)
	end
	if #snapshot.Placed == 0 then
		local row = makeRow(basePanel, "No brainrots yet. Walk the belt and grab one!", "BOOST", Color3.fromRGB(230, 150, 40), function()
			boostPanel.Visible = true
			basePanel.Visible = false
		end)
		table.insert(dynamicRows, row)
	end
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildBasePanel)

-- Index panel: a collection BOOK of the whole cast, grouped under rarity
-- headers. Every tile shows the character's actual 3D model in a viewport --
-- the server builds one clean specimen per character into
-- ReplicatedStorage/IndexSpecimens at startup and the tiles clone from there.
-- Found characters pose in full colour with their name and income; the rest
-- are dark silhouettes named "???". The footer tracks the collection
-- milestones: every 12 finds pays a permanent +10% income, server-side.
local indexPanel = Instance.new("Frame")
indexPanel.Name = "IndexPanel"
indexPanel.AnchorPoint = Vector2.new(0.5, 0.5)
indexPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
indexPanel.Size = UDim2.fromOffset(560, 460)
indexPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
indexPanel.BackgroundTransparency = 0.1
indexPanel.Visible = false
indexPanel.Parent = gui

local indexStroke = Instance.new("UIStroke")
indexStroke.Color = Color3.fromRGB(150, 90, 220)
indexStroke.Thickness = 2
indexStroke.Parent = indexPanel

local indexTitle = Instance.new("TextLabel")
indexTitle.Name = "IndexTitle"
indexTitle.Size = UDim2.new(1, 0, 0, 44)
indexTitle.BackgroundTransparency = 1
indexTitle.Text = "BRAINROT INDEX — 0/" .. tostring(#BrainrotCatalog.Characters) .. " FOUND"
indexTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
indexTitle.TextSize = 26
indexTitle.Font = Enum.Font.FredokaOne
indexTitle.Parent = indexPanel

local indexClose = Instance.new("TextButton")
indexClose.Name = "IndexClose"
indexClose.AnchorPoint = Vector2.new(1, 0)
indexClose.Position = UDim2.new(1, -8, 0, 8)
indexClose.Size = UDim2.fromOffset(36, 36)
indexClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
indexClose.TextColor3 = Color3.fromRGB(255, 255, 255)
indexClose.TextSize = 20
indexClose.Font = Enum.Font.FredokaOne
indexClose.Text = "X"
indexClose.Activated:Connect(function()
	indexPanel.Visible = false
end)
indexClose.Parent = indexPanel

local indexScroll = Instance.new("ScrollingFrame")
indexScroll.Name = "IndexBook"
indexScroll.Position = UDim2.fromOffset(6, 48)
indexScroll.Size = UDim2.new(1, -12, 1, -118)
indexScroll.BackgroundTransparency = 1
indexScroll.BorderSizePixel = 0
indexScroll.ScrollBarThickness = 8
indexScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
indexScroll.CanvasSize = UDim2.fromOffset(0, 0)
indexScroll.Parent = indexPanel
local indexBookLayout = Instance.new("UIListLayout")
indexBookLayout.Padding = UDim.new(0, 8)
indexBookLayout.SortOrder = Enum.SortOrder.LayoutOrder
indexBookLayout.Parent = indexScroll

-- Footer: the collection bonus as it stands, the four milestone markers
-- (lit once reached) and how many more finds the next +10% needs.
local indexFooter = Instance.new("Frame")
indexFooter.Name = "IndexFooter"
indexFooter.AnchorPoint = Vector2.new(0, 1)
indexFooter.Position = UDim2.new(0, 6, 1, -6)
indexFooter.Size = UDim2.new(1, -12, 0, 58)
indexFooter.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
indexFooter.BackgroundTransparency = 0.3
indexFooter.Parent = indexPanel
local collectionBonusLabel = Instance.new("TextLabel")
collectionBonusLabel.Name = "CollectionBonus"
collectionBonusLabel.Position = UDim2.fromOffset(10, 4)
collectionBonusLabel.Size = UDim2.new(1, -20, 0, 24)
collectionBonusLabel.BackgroundTransparency = 1
collectionBonusLabel.Text = "COLLECTION BONUS: +0% income"
collectionBonusLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
collectionBonusLabel.TextSize = 17
collectionBonusLabel.Font = Enum.Font.FredokaOne
collectionBonusLabel.TextXAlignment = Enum.TextXAlignment.Left
collectionBonusLabel.Parent = indexFooter
local milestoneLabel = Instance.new("TextLabel")
milestoneLabel.Name = "Milestones"
milestoneLabel.Position = UDim2.fromOffset(10, 30)
milestoneLabel.Size = UDim2.new(1, -20, 0, 22)
milestoneLabel.BackgroundTransparency = 1
milestoneLabel.Text = ""
milestoneLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
milestoneLabel.TextSize = 14
milestoneLabel.Font = Enum.Font.FredokaOne
milestoneLabel.TextXAlignment = Enum.TextXAlignment.Left
milestoneLabel.Parent = indexFooter

-- Tiles: one per character, grouped under a header per rarity. The viewport
-- model is (re)filled only when the tile's found state flips or the
-- specimens first arrive, so the per-second snapshots stay cheap.
local tileRecords: { [string]: any } = {}

local function makeTile(sectionGrid: Frame, layoutOrder: number, character: any)
	local tile = Instance.new("Frame")
	tile.Name = "IndexTile_" .. character.Id
	tile.LayoutOrder = layoutOrder
	tile.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ModelView"
	viewport.Position = UDim2.fromOffset(4, 4)
	viewport.Size = UDim2.fromOffset(110, 82)
	viewport.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(190, 190, 205)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.Parent = tile
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CharName"
	nameLabel.Position = UDim2.fromOffset(4, 88)
	nameLabel.Size = UDim2.fromOffset(110, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "???"
	nameLabel.TextColor3 = Color3.fromRGB(120, 120, 135)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextWrapped = true
	nameLabel.Parent = tile
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "CharIncome"
	incomeLabel.Position = UDim2.fromOffset(4, 114)
	incomeLabel.Size = UDim2.fromOffset(110, 16)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = ""
	incomeLabel.TextColor3 = Color3.fromRGB(140, 255, 150)
	incomeLabel.TextSize = 13
	incomeLabel.Font = Enum.Font.FredokaOne
	incomeLabel.Parent = tile
	tile.Parent = sectionGrid
	tileRecords[character.Id] = {
		Character = character,
		Frame = tile,
		Viewport = viewport,
		NameLabel = nameLabel,
		IncomeLabel = incomeLabel,
		Found = nil,
	}
end

for sectionIndex, rarity in ipairs(BrainrotCatalog.RarityOrder) do
	local section = Instance.new("Frame")
	section.Name = "IndexSection_" .. rarity
	section.LayoutOrder = sectionIndex
	section.Size = UDim2.new(1, -4, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 4)
	sectionLayout.Parent = section
	local header = Instance.new("TextLabel")
	header.Name = "RarityHeader"
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundTransparency = 1
	header.Text = "◆ " .. string.upper(rarity)
	header.TextColor3 = BrainrotCatalog.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
	header.TextSize = 18
	header.Font = Enum.Font.FredokaOne
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = section
	local grid = Instance.new("Frame")
	grid.Name = "TileGrid"
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(118, 134)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	grid.Parent = section
	section.Parent = indexScroll
	for tileIndex, character in ipairs(BrainrotCatalog.GetCharactersOfRarity(rarity)) do
		makeTile(grid, tileIndex, character)
	end
end

local specimensFolder: Folder? = nil
local specimensReady = false

-- Poses a tile's specimen clone in its viewport: the real model for a found
-- character, the same model repainted dark grey (45,45,60) with no name for
-- a missing one. The clone is centred on its bounding box and the camera
-- sits at a fixed three-quarter angle -- no spin, one static pose per tile.
local function fillTileViewport(record: any)
	local viewport = record.Viewport
	for _, child in ipairs(viewport:GetChildren()) do
		child:Destroy()
	end
	local specimen = specimensFolder and specimensFolder:FindFirstChild(record.Character.Id)
	if not specimen then
		return
	end
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	local clone = specimen:Clone()
	if not record.Found then
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(45, 45, 60)
				descendant.Material = Enum.Material.SmoothPlastic
			elseif descendant:IsA("BillboardGui") then
				descendant:Destroy()
			end
		end
	end
	clone.Parent = worldModel
	local boxCFrame, boxSize = clone:GetBoundingBox()
	clone:PivotTo(CFrame.new(-boxCFrame.Position) * clone:GetPivot())
	local camera = Instance.new("Camera")
	camera.FieldOfView = 45
	local reach = math.max(boxSize.X, boxSize.Y, boxSize.Z)
	camera.CFrame = CFrame.lookAt(Vector3.new(reach * 0.55, reach * 0.3, reach * 1.05), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Specimens are built by the server during startup; wait for the folder and
-- every character, then pose any tile whose found state is already known.
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("IndexSpecimens")
	specimensFolder = folder
	for _, character in ipairs(BrainrotCatalog.Characters) do
		folder:WaitForChild(character.Id)
	end
	specimensReady = true
	for _, record in pairs(tileRecords) do
		if record.Found ~= nil then
			fillTileViewport(record)
		end
	end
end)

local function rebuildIndexPanel(snapshot: any)
	if not snapshot then
		return
	end
	local foundSet: { [string]: boolean } = {}
	for _, characterId in ipairs(snapshot.FoundIds or {}) do
		foundSet[characterId] = true
	end
	local foundCount = snapshot.FoundCount or 0
	indexTitle.Text = "BRAINROT INDEX — " .. tostring(foundCount) .. "/" .. tostring(#BrainrotCatalog.Characters) .. " FOUND"
	for _, character in ipairs(BrainrotCatalog.Characters) do
		local record = tileRecords[character.Id]
		if record then
			local found = foundSet[character.Id] == true
			if record.Found ~= found then
				record.Found = found
				if found then
					local rarityColor = BrainrotCatalog.RarityColors[character.Rarity] or Color3.fromRGB(42, 42, 56)
					record.Frame.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(22, 22, 34), 0.5)
					record.NameLabel.Text = character.Name
					record.NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					record.IncomeLabel.Text = "$" .. tostring(character.IncomePerSecond) .. "/s"
				else
					record.Frame.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
					record.NameLabel.Text = "???"
					record.NameLabel.TextColor3 = Color3.fromRGB(120, 120, 135)
					record.IncomeLabel.Text = ""
				end
				if specimensReady then
					fillTileViewport(record)
				end
			end
		end
	end
	collectionBonusLabel.Text = "COLLECTION BONUS: +" .. tostring(snapshot.CollectionBonusPercent or 0) .. "% income"
	local markerParts = {}
	for _, milestone in ipairs(GameConfig.CollectionMilestones) do
		table.insert(markerParts, (if foundCount >= milestone then "★ " else "☆ ") .. tostring(milestone))
	end
	local nextText = if snapshot.NextMilestoneIn
		then "next: " .. tostring(snapshot.NextMilestoneIn) .. " more for +10%"
		else "MAX BONUS!"
	milestoneLabel.Text = table.concat(markerParts, "   ") .. "   ·   " .. nextText
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildIndexPanel)

-- Fuse panel: pick 3 placed brainrots of the same rarity and trade them up
-- into 1 of the next rarity. The grid mirrors the latest state snapshot; the
-- server re-validates everything, so this panel is only ever a picker.
local fusePanel = Instance.new("Frame")
fusePanel.Name = "FusePanel"
fusePanel.AnchorPoint = Vector2.new(0.5, 0.5)
fusePanel.Position = UDim2.new(0.5, 0, 0.5, 0)
fusePanel.Size = UDim2.fromOffset(560, 460)
fusePanel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
fusePanel.BackgroundTransparency = 0.1
fusePanel.Visible = false
fusePanel.Parent = gui

local fuseStroke = Instance.new("UIStroke")
fuseStroke.Color = Color3.fromRGB(150, 90, 220)
fuseStroke.Thickness = 2
fuseStroke.Parent = fusePanel

local fuseTitle = Instance.new("TextLabel")
fuseTitle.Name = "FuseTitle"
fuseTitle.Size = UDim2.new(1, 0, 0, 44)
fuseTitle.BackgroundTransparency = 1
fuseTitle.Text = "FUSE MACHINE"
fuseTitle.TextColor3 = Color3.fromRGB(215, 150, 255)
fuseTitle.TextSize = 26
fuseTitle.Font = Enum.Font.FredokaOne
fuseTitle.Parent = fusePanel

local fuseClose = Instance.new("TextButton")
fuseClose.Name = "FuseClose"
fuseClose.AnchorPoint = Vector2.new(1, 0)
fuseClose.Position = UDim2.new(1, -8, 0, 8)
fuseClose.Size = UDim2.fromOffset(36, 36)
fuseClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
fuseClose.TextColor3 = Color3.fromRGB(255, 255, 255)
fuseClose.TextSize = 20
fuseClose.Font = Enum.Font.FredokaOne
fuseClose.Text = "X"
fuseClose.Activated:Connect(function()
	fusePanel.Visible = false
end)
fuseClose.Parent = fusePanel

local fuseHint = Instance.new("TextLabel")
fuseHint.Name = "FuseHint"
fuseHint.Position = UDim2.fromOffset(10, 44)
fuseHint.Size = UDim2.new(1, -20, 0, 38)
fuseHint.BackgroundTransparency = 1
fuseHint.Text = "Pick 3 brainrots of the same rarity to get 1 of the next rarity"
fuseHint.TextColor3 = Color3.fromRGB(200, 200, 215)
fuseHint.TextSize = 15
fuseHint.Font = Enum.Font.FredokaOne
fuseHint.TextWrapped = true
fuseHint.Parent = fusePanel

local fuseScroll = Instance.new("ScrollingFrame")
fuseScroll.Name = "FuseGrid"
fuseScroll.Position = UDim2.fromOffset(6, 86)
fuseScroll.Size = UDim2.new(1, -12, 1, -142)
fuseScroll.BackgroundTransparency = 1
fuseScroll.BorderSizePixel = 0
fuseScroll.ScrollBarThickness = 8
fuseScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
fuseScroll.CanvasSize = UDim2.fromOffset(0, 0)
fuseScroll.Parent = fusePanel
local fuseLayout = Instance.new("UIGridLayout")
fuseLayout.CellSize = UDim2.fromOffset(118, 86)
fuseLayout.CellPadding = UDim2.fromOffset(6, 6)
fuseLayout.SortOrder = Enum.SortOrder.LayoutOrder
fuseLayout.Parent = fuseScroll

local fuseAction = Instance.new("TextButton")
fuseAction.Name = "FuseAction"
fuseAction.AnchorPoint = Vector2.new(0, 1)
fuseAction.Position = UDim2.new(0, 6, 1, -6)
fuseAction.Size = UDim2.new(1, -12, 0, 44)
fuseAction.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
fuseAction.TextColor3 = Color3.fromRGB(255, 255, 255)
fuseAction.TextSize = 19
fuseAction.Font = Enum.Font.FredokaOne
fuseAction.Text = "FUSE (0/3)"
fuseAction.Active = false
fuseAction.AutoButtonColor = false
fuseAction.Parent = fusePanel

local fuseSelection: { [number]: boolean } = {}
local fusePlaced: { any } = {}
local fuseCells: { TextButton } = {}

local function selectedFuseUids(): { number }
	local uids = {}
	for uid in pairs(fuseSelection) do
		table.insert(uids, uid)
	end
	return uids
end

local function refreshFuseAction()
	local uids = selectedFuseUids()
	local sharedRarity: string? = nil
	local mixed = false
	for _, placed in ipairs(fusePlaced) do
		if fuseSelection[placed.Uid] then
			if sharedRarity == nil then
				sharedRarity = placed.Rarity
			elseif placed.Rarity ~= sharedRarity then
				mixed = true
			end
		end
	end
	if #uids < 3 then
		fuseAction.Text = "FUSE (" .. tostring(#uids) .. "/3)"
		fuseAction.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
		fuseAction.Active = false
	elseif mixed then
		fuseAction.Text = "NEED 3 OF SAME RARITY"
		fuseAction.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
		fuseAction.Active = false
	elseif sharedRarity == BrainrotCatalog.RarityOrder[#BrainrotCatalog.RarityOrder] then
		fuseAction.Text = "MAX RARITY - CANNOT FUSE"
		fuseAction.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
		fuseAction.Active = false
	else
		fuseAction.Text = "FUSE (3/3)"
		fuseAction.BackgroundColor3 = Color3.fromRGB(150, 90, 220)
		fuseAction.Active = true
	end
end

local function refreshFuseCells()
	for _, cell in ipairs(fuseCells) do
		local uid = cell:GetAttribute("Uid")
		local rarity = cell:GetAttribute("Rarity")
		local label = cell:FindFirstChildOfClass("TextLabel")
		if uid and fuseSelection[uid] then
			cell.BackgroundColor3 = BrainrotCatalog.RarityColors[rarity] or Color3.fromRGB(150, 90, 220)
			if label then
				label.TextColor3 = Color3.fromRGB(20, 20, 28)
			end
		else
			cell.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
			if label then
				label.TextColor3 = Color3.fromRGB(200, 200, 215)
			end
		end
	end
	refreshFuseAction()
end

local function rebuildFusePanel(snapshot: any)
	fusePlaced = snapshot.Placed
	local stillPlaced: { [number]: boolean } = {}
	for _, placed in ipairs(snapshot.Placed) do
		stillPlaced[placed.Uid] = true
	end
	for uid in pairs(fuseSelection) do
		if not stillPlaced[uid] then
			fuseSelection[uid] = nil
		end
	end
	for _, cell in ipairs(fuseCells) do
		cell:Destroy()
	end
	fuseCells = {}
	for cellIndex, placed in ipairs(snapshot.Placed) do
		local cell = Instance.new("TextButton")
		cell.Name = "FuseCell_" .. tostring(placed.Uid)
		cell.LayoutOrder = cellIndex
		cell.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
		cell.Text = ""
		cell.AutoButtonColor = false
		cell:SetAttribute("Uid", placed.Uid)
		cell:SetAttribute("Rarity", placed.Rarity)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 1, -8)
		label.Position = UDim2.fromOffset(4, 4)
		label.BackgroundTransparency = 1
		local mutationText = if placed.Mutation == "Normal" then "" else " " .. placed.Mutation
		label.Text = string.format("%s%s\n%s\n$%d/s", placed.Name, mutationText, placed.Rarity, placed.IncomePerSecond)
		label.TextColor3 = Color3.fromRGB(200, 200, 215)
		label.TextSize = 14
		label.Font = Enum.Font.FredokaOne
		label.TextWrapped = true
		label.Parent = cell
		cell.Activated:Connect(function()
			if fuseSelection[placed.Uid] then
				fuseSelection[placed.Uid] = nil
			elseif #selectedFuseUids() < 3 then
				fuseSelection[placed.Uid] = true
			end
			refreshFuseCells()
		end)
		cell.Parent = fuseScroll
		table.insert(fuseCells, cell)
	end
	refreshFuseCells()
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildFusePanel)

fuseAction.Activated:Connect(function()
	local uids = selectedFuseUids()
	if #uids ~= 3 then
		return
	end
	fuseSelection = {}
	remotes:WaitForChild("FuseBrainrots"):FireServer(uids)
	fusePanel.Visible = false
	refreshFuseCells()
end)

-- Side buttons: BOOST, MY BASE, EGG, REBIRTH, INDEX, FUSE and GACHA,
-- stacked down the right edge.
local function makeSideButton(name: string, yOffset: number, text: string, color: Color3, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -14, 0, yOffset)
	button.Size = UDim2.fromOffset(195, 54)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 19
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.Activated:Connect(onClick)
	button.Parent = gui
	return button
end

makeSideButton("BoostButton", 90, "BOOST", Color3.fromRGB(230, 150, 40), function()
	boostPanel.Visible = not boostPanel.Visible
	basePanel.Visible = false
	indexPanel.Visible = false
	fusePanel.Visible = false
end)

makeSideButton("BaseButton", 152, "MY BASE", Color3.fromRGB(80, 120, 220), function()
	basePanel.Visible = not basePanel.Visible
	boostPanel.Visible = false
	indexPanel.Visible = false
	fusePanel.Visible = false
end)

makeSideButton("EggButton", 214, "EGG " .. GameConfig.FormatCash(GameConfig.EggPrice), Color3.fromRGB(230, 90, 180), function()
	remotes:WaitForChild("HatchEgg"):FireServer()
end)

local rebirthButton = makeSideButton("RebirthButton", 276, "REBIRTH", Color3.fromRGB(60, 200, 210), function()
	remotes:WaitForChild("RequestRebirth"):FireServer()
end)

makeSideButton("IndexButton", 338, "INDEX", Color3.fromRGB(150, 90, 220), function()
	indexPanel.Visible = not indexPanel.Visible
	boostPanel.Visible = false
	basePanel.Visible = false
	fusePanel.Visible = false
end)

makeSideButton("FuseButton", 400, "FUSE", Color3.fromRGB(170, 70, 230), function()
	fusePanel.Visible = not fusePanel.Visible
	boostPanel.Visible = false
	basePanel.Visible = false
	indexPanel.Visible = false
end)

-- The gacha button has no panel: like EGG it fires its remote directly, and
-- the capsule machine plus the result toast are the whole interface.
makeSideButton("GachaButton", 462, "GACHA " .. GameConfig.FormatCash(GameConfig.GachaPrice), Color3.fromRGB(255, 70, 190), function()
	remotes:WaitForChild("RollGacha"):FireServer()
end)

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	rebirthButton.Text = "REBIRTH " .. GameConfig.FormatCash(snapshot.NextRebirthCost)
end)
