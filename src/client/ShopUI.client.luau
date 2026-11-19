-- ShopUI.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Neon Shores -- the panels over the 3D world: a SHOP panel listing
-- the whole cast by rarity with prices and income (buying sends the brainrot straight to a
-- free pad at your base), a MY BASE panel listing what you own with a SELL button each, an
-- INDEX panel grid of the whole 36-character cast that lights up in rarity colours for the
-- ones you own, a FUSE panel that trades 3 same-rarity brainrots up a tier, and the EGG
-- and REBIRTH buttons. The SHOP and MY BASE panels open from the right-hand side,
-- away from the top-left corner where Roblox draws its own menu; the INDEX and FUSE
-- panels are centred modals, so they never sit under the right-hand button column.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "NeonPanels"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makePanel(name: string, title: string): ScrollingFrame
	local panel = Instance.new("ScrollingFrame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -14, 0, 90)
	panel.Size = UDim2.fromOffset(380, 460)
	panel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.ScrollBarThickness = 8
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.fromOffset(0, 0)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	local heading = Instance.new("TextLabel")
	heading.Name = "PanelTitle"
	heading.Size = UDim2.new(1, 0, 0, 44)
	heading.BackgroundTransparency = 1
	heading.Text = title
	heading.TextColor3 = Color3.fromRGB(255, 255, 255)
	heading.TextSize = 26
	heading.Font = Enum.Font.FredokaOne
	heading.Parent = panel
	panel.Parent = gui
	return panel
end

local function makeRow(panel: ScrollingFrame, text: string, buttonText: string, buttonColor: Color3, onClick: () -> ())
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
	row.Parent = panel
	return row
end

-- Shop panel: the full cast, cheapest first (the catalog is already in price order).
local shopPanel = makePanel("ShopPanel", "SHOP")
for _, character in ipairs(BrainrotCatalog.Characters) do
	local rowText = string.format("%s [%s]\n$%d/s - %s", character.Name, character.Rarity, character.IncomePerSecond, character.Tagline)
	makeRow(shopPanel, rowText, GameConfig.FormatCash(character.Price), Color3.fromRGB(60, 170, 80), function()
		remotes:WaitForChild("BuyBrainrot"):FireServer(character.Id)
	end)
end

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
		local row = makeRow(basePanel, "No brainrots yet. Buy one from the belt or the shop!", "SHOP", Color3.fromRGB(60, 170, 80), function()
			shopPanel.Visible = true
			basePanel.Visible = false
		end)
		table.insert(dynamicRows, row)
	end
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildBasePanel)

-- Index panel: a grid of the whole cast. Owned brainrots glow in their rarity
-- colour; the rest sit greyed out. Ownership comes from the same state snapshot
-- as MY BASE (placed CharacterIds plus the carried one), so no extra remote.
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
indexTitle.Text = "BRAINROT INDEX  0/" .. tostring(#BrainrotCatalog.Characters)
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
indexScroll.Name = "IndexGrid"
indexScroll.Position = UDim2.fromOffset(6, 48)
indexScroll.Size = UDim2.new(1, -12, 1, -54)
indexScroll.BackgroundTransparency = 1
indexScroll.BorderSizePixel = 0
indexScroll.ScrollBarThickness = 8
indexScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
indexScroll.CanvasSize = UDim2.fromOffset(0, 0)
indexScroll.Parent = indexPanel
local indexLayout = Instance.new("UIGridLayout")
indexLayout.CellSize = UDim2.fromOffset(118, 86)
indexLayout.CellPadding = UDim2.fromOffset(6, 6)
indexLayout.SortOrder = Enum.SortOrder.LayoutOrder
indexLayout.Parent = indexScroll

local indexCells: { [string]: Frame } = {}
local indexCellLabels: { [string]: TextLabel } = {}
for cellIndex, character in ipairs(BrainrotCatalog.Characters) do
	local cell = Instance.new("Frame")
	cell.Name = "IndexCell_" .. character.Id
	cell.LayoutOrder = cellIndex
	cell.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
	local cellLabel = Instance.new("TextLabel")
	cellLabel.Size = UDim2.new(1, -8, 1, -8)
	cellLabel.Position = UDim2.fromOffset(4, 4)
	cellLabel.BackgroundTransparency = 1
	cellLabel.Text = string.format("%s\n%s\n$%d/s", character.Name, character.Rarity, character.IncomePerSecond)
	cellLabel.TextColor3 = Color3.fromRGB(120, 120, 135)
	cellLabel.TextSize = 14
	cellLabel.Font = Enum.Font.FredokaOne
	cellLabel.TextWrapped = true
	cellLabel.Parent = cell
	cell.Parent = indexScroll
	indexCells[character.Id] = cell
	indexCellLabels[character.Id] = cellLabel
end

local function rebuildIndexPanel(snapshot: any)
	local owned: { [string]: boolean } = {}
	for _, placed in ipairs(snapshot.Placed) do
		if placed.CharacterId then
			owned[placed.CharacterId] = true
		end
	end
	if snapshot.CarriedId then
		owned[snapshot.CarriedId] = true
	end
	local ownedCount = 0
	for _, character in ipairs(BrainrotCatalog.Characters) do
		local cell = indexCells[character.Id]
		local cellLabel = indexCellLabels[character.Id]
		if cell and cellLabel then
			if owned[character.Id] then
				ownedCount += 1
				cell.BackgroundColor3 = BrainrotCatalog.RarityColors[character.Rarity] or Color3.fromRGB(42, 42, 56)
				cellLabel.TextColor3 = Color3.fromRGB(20, 20, 28)
			else
				cell.BackgroundColor3 = Color3.fromRGB(42, 42, 56)
				cellLabel.TextColor3 = Color3.fromRGB(120, 120, 135)
			end
		end
	end
	indexTitle.Text = "BRAINROT INDEX  " .. tostring(ownedCount) .. "/" .. tostring(#BrainrotCatalog.Characters)
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
	elseif sharedRarity == "Brainrot God" then
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

-- Side buttons: SHOP, MY BASE, EGG and REBIRTH, stacked down the right edge.
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

makeSideButton("ShopButton", 90, "SHOP", Color3.fromRGB(60, 170, 80), function()
	shopPanel.Visible = not shopPanel.Visible
	basePanel.Visible = false
	indexPanel.Visible = false
	fusePanel.Visible = false
end)

makeSideButton("BaseButton", 152, "MY BASE", Color3.fromRGB(80, 120, 220), function()
	basePanel.Visible = not basePanel.Visible
	shopPanel.Visible = false
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
	shopPanel.Visible = false
	basePanel.Visible = false
	fusePanel.Visible = false
end)

makeSideButton("FuseButton", 400, "FUSE", Color3.fromRGB(170, 70, 230), function()
	fusePanel.Visible = not fusePanel.Visible
	shopPanel.Visible = false
	basePanel.Visible = false
	indexPanel.Visible = false
end)

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	rebirthButton.Text = "REBIRTH " .. GameConfig.FormatCash(snapshot.NextRebirthCost)
end)
