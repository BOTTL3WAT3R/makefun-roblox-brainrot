-- ShopUI.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Neon Shores -- the panels over the 3D world: a SHOP panel listing
-- the whole cast by rarity with prices and income (buying sends the brainrot straight to a
-- free pad at your base), a MY BASE panel listing what you own with a SELL button each, an
-- INDEX panel grid of the whole 36-character cast that lights up in rarity colours for the
-- ones you own, and the EGG and REBIRTH buttons. Panels open from the right-hand side,
-- away from the top-left corner where Roblox draws its own menu.

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
indexPanel.AnchorPoint = Vector2.new(1, 0)
indexPanel.Position = UDim2.new(1, -14, 0, 90)
indexPanel.Size = UDim2.fromOffset(380, 460)
indexPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
indexPanel.BackgroundTransparency = 0.1
indexPanel.Visible = false
indexPanel.Parent = gui

local indexTitle = Instance.new("TextLabel")
indexTitle.Name = "IndexTitle"
indexTitle.Size = UDim2.new(1, 0, 0, 44)
indexTitle.BackgroundTransparency = 1
indexTitle.Text = "INDEX  0/" .. tostring(#BrainrotCatalog.Characters)
indexTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
indexTitle.TextSize = 26
indexTitle.Font = Enum.Font.FredokaOne
indexTitle.Parent = indexPanel

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
	indexTitle.Text = "INDEX  " .. tostring(ownedCount) .. "/" .. tostring(#BrainrotCatalog.Characters)
end

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(rebuildIndexPanel)

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
end)

makeSideButton("BaseButton", 152, "MY BASE", Color3.fromRGB(80, 120, 220), function()
	basePanel.Visible = not basePanel.Visible
	shopPanel.Visible = false
	indexPanel.Visible = false
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
end)

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	rebirthButton.Text = "REBIRTH " .. GameConfig.FormatCash(snapshot.NextRebirthCost)
end)
