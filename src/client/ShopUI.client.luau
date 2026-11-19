-- ShopUI.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Brainrot Island -- the panels over the 3D world: a SHOP panel listing
-- the whole cast by rarity with prices and income (buying sends the brainrot straight to a
-- free pad at your base), a MY BASE panel listing what you own with a SELL button each, and
-- the EGG and REBIRTH buttons. Panels open from the right-hand side, away from
-- the top-left corner where Roblox draws its own menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotPanels"
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
end)

makeSideButton("BaseButton", 152, "MY BASE", Color3.fromRGB(80, 120, 220), function()
	basePanel.Visible = not basePanel.Visible
	shopPanel.Visible = false
end)

makeSideButton("EggButton", 214, "EGG " .. GameConfig.FormatCash(GameConfig.EggPrice), Color3.fromRGB(230, 90, 180), function()
	remotes:WaitForChild("HatchEgg"):FireServer()
end)

local rebirthButton = makeSideButton("RebirthButton", 276, "REBIRTH", Color3.fromRGB(60, 200, 210), function()
	remotes:WaitForChild("RequestRebirth"):FireServer()
end)

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	rebirthButton.Text = "REBIRTH " .. GameConfig.FormatCash(snapshot.NextRebirthCost)
end)
