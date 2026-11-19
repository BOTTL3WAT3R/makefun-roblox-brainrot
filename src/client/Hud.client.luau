-- Hud.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Candy Island -- the heads-up display over the 3D world: cash, income per second,
-- rebirth multiplier and lock state in a panel at the TOP CENTRE (Roblox's own menu
-- buttons cover the top-left corner itself), a big Big Wave
-- countdown banner under it, a quest panel in the top-left under the menu corner, a toast line for
-- game news, a static rarity-ladder legend in the bottom-left, and the DASH and
-- LOCK buttons. Two small animations keep it alive: the cash label pops whenever
-- the number changes, and the wave banner pulses red while a Big Wave is about to hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- The E prompt on a placed brainrot is created server-side as "Steal" for
-- everyone, but on YOUR OWN brainrot the same key picks it up instead. The
-- label is per-viewer, so it is fixed up here at show time: the model's
-- OwnerUserId attribute (stamped when it was placed) decides which word this
-- player sees. The server branches on the presser either way -- this is
-- cosmetics only, never trust.
-- The chair prompt is likewise created server-side with one word ("Sit")
-- for everyone, but once YOU are in the chair the same key is the way
-- out, so for the seated viewer it reads "Stand Up". The check runs when
-- the prompt is shown AND whenever the local humanoid's SeatPart changes:
-- sitting down does not hide and re-show the prompt, so without the
-- second pass the label would sit stale on "Sit" for the whole ride.
local shownSitPrompts: { [ProximityPrompt]: boolean } = {}

local function refreshSitPromptLabel(prompt: ProximityPrompt)
	local seat = prompt.Parent
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		seat
		and seat:IsA("Seat")
		and humanoid
		and (seat.Occupant == humanoid or humanoid.SeatPart == seat)
	then
		prompt.ActionText = "Stand Up"
	else
		prompt.ActionText = "Sit"
	end
end

local function refreshShownSitPromptLabels()
	for prompt in pairs(shownSitPrompts) do
		refreshSitPromptLabel(prompt)
	end
end

local function watchCharacterForSitLabels(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refreshShownSitPromptLabels)
	end
end

if player.Character then
	watchCharacterForSitLabels(player.Character)
end
player.CharacterAdded:Connect(watchCharacterForSitLabels)

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "StealPrompt" then
		local model = prompt:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("OwnerUserId") == player.UserId then
			prompt.ActionText = "Pick Up"
		else
			prompt.ActionText = "Steal"
		end
	elseif prompt.Name == "SitPrompt" then
		shownSitPrompts[prompt] = true
		refreshSitPromptLabel(prompt)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "SitPrompt" then
		shownSitPrompts[prompt] = nil
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CandyHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name: string, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = Enum.Font.FredokaOne
	label.Text = ""
	label.Parent = gui
	return label
end

-- Stats bar across the top centre of the screen.
local cashLabel = makeLabel("CashLabel", UDim2.new(0.5, -235, 0, 12), UDim2.fromOffset(310, 52), 28, Color3.fromRGB(140, 255, 150))
cashLabel.Text = "CASH: $100"
local cashScale = Instance.new("UIScale")
cashScale.Parent = cashLabel
local incomeLabel = makeLabel("IncomeLabel", UDim2.new(0.5, 75, 0, 12), UDim2.fromOffset(250, 52), 24, Color3.fromRGB(255, 230, 120))
incomeLabel.Text = "+$0/s"
local rebirthLabel = makeLabel("RebirthLabel", UDim2.new(0.5, 320, 0, 12), UDim2.fromOffset(210, 52), 24, Color3.fromRGB(160, 255, 255))
rebirthLabel.Text = "x1 income"

-- Cash pop: every time the displayed cash changes, the label swells and settles.
-- Throttled to one pop per 0.25s so a fast income tick cannot strobe the screen.
local lastCashValue: number? = nil
local lastPopAt = 0
local function popCashLabel()
	local now = os.clock()
	if now - lastPopAt < 0.25 then
		return
	end
	lastPopAt = now
	cashScale.Scale = 1.18
	TweenService:Create(cashScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- The Big Wave banner: calm it counts down quietly, warning it shouts and pulses red.
local waveBanner = makeLabel("WaveBanner", UDim2.new(0.5, 0, 0, 76), UDim2.fromOffset(680, 58), 32, Color3.fromRGB(140, 210, 255))
waveBanner.Text = "Next Big Wave: --"
local BANNER_CALM_COLOR = Color3.fromRGB(18, 18, 28)
local bannerPulse: Tween? = nil
local function setBannerPulse(on: boolean)
	if on and not bannerPulse then
		bannerPulse = TweenService:Create(
			waveBanner,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundColor3 = Color3.fromRGB(200, 40, 40) }
		)
		bannerPulse:Play()
	elseif not on and bannerPulse then
		bannerPulse:Cancel()
		bannerPulse = nil
		waveBanner.BackgroundColor3 = BANNER_CALM_COLOR
	end
end

-- The quest panel: top-left, tucked under Roblox's own menu corner. A header
-- with the done count, then one row per ACTIVE quest (three at a time):
-- description on the left, progress and cash reward on the right. Rows are
-- built once and re-texted from every snapshot, so the per-second income
-- snapshots never churn the layout.
local questPanel = Instance.new("Frame")
questPanel.Name = "QuestPanel"
questPanel.Position = UDim2.fromOffset(12, 84)
questPanel.Size = UDim2.fromOffset(304, 196)
questPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
questPanel.BackgroundTransparency = 0.25
questPanel.Parent = gui

local questHeader = Instance.new("TextLabel")
questHeader.Name = "QuestHeader"
questHeader.Position = UDim2.fromOffset(10, 4)
questHeader.Size = UDim2.new(1, -20, 0, 24)
questHeader.BackgroundTransparency = 1
questHeader.Text = "QUESTS — 0/12 done"
questHeader.TextColor3 = Color3.fromRGB(255, 215, 110)
questHeader.TextSize = 17
questHeader.Font = Enum.Font.FredokaOne
questHeader.TextXAlignment = Enum.TextXAlignment.Left
questHeader.Parent = questPanel

local questRows: { { Frame: Frame, Desc: TextLabel, Meta: TextLabel } } = {}
for rowIndex = 1, 3 do
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = "QuestRow" .. tostring(rowIndex)
	rowFrame.Position = UDim2.fromOffset(8, 32 + (rowIndex - 1) * 54)
	rowFrame.Size = UDim2.new(1, -16, 0, 50)
	rowFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 54)
	rowFrame.BackgroundTransparency = 0.35
	rowFrame.Parent = questPanel
	local desc = Instance.new("TextLabel")
	desc.Name = "Desc"
	desc.Position = UDim2.fromOffset(8, 2)
	desc.Size = UDim2.new(1, -104, 1, -4)
	desc.BackgroundTransparency = 1
	desc.Text = ""
	desc.TextColor3 = Color3.fromRGB(255, 255, 255)
	desc.TextSize = 15
	desc.Font = Enum.Font.FredokaOne
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Center
	desc.Parent = rowFrame
	local meta = Instance.new("TextLabel")
	meta.Name = "Meta"
	meta.AnchorPoint = Vector2.new(1, 0)
	meta.Position = UDim2.new(1, -8, 0, 2)
	meta.Size = UDim2.fromOffset(88, 46)
	meta.BackgroundTransparency = 1
	meta.Text = ""
	meta.TextColor3 = Color3.fromRGB(255, 215, 110)
	meta.TextSize = 15
	meta.Font = Enum.Font.FredokaOne
	meta.TextXAlignment = Enum.TextXAlignment.Right
	meta.TextYAlignment = Enum.TextYAlignment.Center
	meta.Parent = rowFrame
	table.insert(questRows, { Frame = rowFrame, Desc = desc, Meta = meta })
end

local function rebuildQuestPanel(quests: any)
	if not quests then
		return
	end
	questHeader.Text = string.format("QUESTS — %d/%d done", quests.Done, quests.Total)
	if quests.AllDone then
		questRows[1].Frame.Visible = true
		questRows[1].Desc.Text = "ALL QUESTS DONE!"
		questRows[1].Meta.Text = ""
		questRows[2].Frame.Visible = false
		questRows[3].Frame.Visible = false
		return
	end
	for rowIndex, row in ipairs(questRows) do
		local quest = quests.Active[rowIndex]
		if quest then
			row.Frame.Visible = true
			row.Desc.Text = quest.Label
			row.Meta.Text = string.format("%d/%d\n%s", quest.Progress, quest.Target, quest.RewardText)
		else
			row.Frame.Visible = false
		end
	end
end

-- The rarity ladder legend: static reference furniture in the bottom-left --
-- the ten rarities in their catalogue colours, and what each mutation pays.
local legend = Instance.new("Frame")
legend.Name = "RarityLadder"
legend.AnchorPoint = Vector2.new(0, 1)
legend.Position = UDim2.new(0, 12, 1, -12)
legend.Size = UDim2.fromOffset(264, 216)
legend.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
legend.BackgroundTransparency = 0.25
legend.Parent = gui
local legendTitle = Instance.new("TextLabel")
legendTitle.Name = "LegendTitle"
legendTitle.Position = UDim2.fromOffset(10, 4)
legendTitle.Size = UDim2.new(1, -20, 0, 20)
legendTitle.BackgroundTransparency = 1
legendTitle.Text = "RARITY LADDER"
legendTitle.TextColor3 = Color3.fromRGB(255, 215, 110)
legendTitle.TextSize = 16
legendTitle.Font = Enum.Font.FredokaOne
legendTitle.TextXAlignment = Enum.TextXAlignment.Left
legendTitle.Parent = legend
for index, rarity in ipairs(BrainrotCatalog.RarityOrder) do
	local row = Instance.new("TextLabel")
	row.Name = "Rarity" .. tostring(index)
	row.Position = UDim2.fromOffset(10, 24 + (index - 1) * 15)
	row.Size = UDim2.new(1, -20, 0, 15)
	row.BackgroundTransparency = 1
	row.Text = rarity
	row.TextColor3 = BrainrotCatalog.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
	row.TextSize = 14
	row.Font = Enum.Font.FredokaOne
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = legend
end
local mutationParts = {}
for _, mutation in ipairs(BrainrotCatalog.Mutations) do
	if mutation.Name ~= "Normal" then
		table.insert(mutationParts, mutation.Name .. " x" .. tostring(mutation.IncomeMultiplier))
	end
end
local mutationLine = Instance.new("TextLabel")
mutationLine.Name = "MutationLine"
mutationLine.Position = UDim2.fromOffset(10, 186)
mutationLine.Size = UDim2.new(1, -20, 0, 20)
mutationLine.BackgroundTransparency = 1
mutationLine.Text = "MUTATIONS: " .. table.concat(mutationParts, "  ")
mutationLine.TextColor3 = Color3.fromRGB(220, 220, 235)
mutationLine.TextSize = 13
mutationLine.Font = Enum.Font.FredokaOne
mutationLine.TextXAlignment = Enum.TextXAlignment.Left
mutationLine.Parent = legend

-- Toasts: steals, hatches, sales and warnings land here, centre screen.
local toastLabel = makeLabel("ToastLabel", UDim2.new(0.5, 0, 0.32, 0), UDim2.fromOffset(760, 64), 28, Color3.fromRGB(255, 255, 255))
toastLabel.BackgroundTransparency = 1
toastLabel.Text = "Buy the glow. Guard the glow. Outrun the Big Wave."
task.delay(8, function()
	if toastLabel.Text == "Buy the glow. Guard the glow. Outrun the Big Wave." then
		toastLabel.Text = ""
	end
end)

local function makeButton(name: string, position: UDim2, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(210, 64)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 26
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.Parent = gui
	return button
end

local dashButton = makeButton("DashButton", UDim2.new(0.5, -120, 1, -18), "DASH (Shift)", Color3.fromRGB(255, 140, 40))
local lockButton = makeButton("LockButton", UDim2.new(0.5, 120, 1, -18), "LOCK BASE", Color3.fromRGB(220, 60, 60))

dashButton.Activated:Connect(function()
	remotes:WaitForChild("RequestDash"):FireServer()
end)

lockButton.Activated:Connect(function()
	remotes:WaitForChild("ToggleLock"):FireServer()
end)

-- Roblox's default camera scripts swallow some keys, so the dash is bound through
-- ContextActionService, which hears LeftShift even while the camera is listening.
ContextActionService:BindAction("CandyDash", function(_actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		remotes:WaitForChild("RequestDash"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift)

local latestSnapshot: any = nil

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	latestSnapshot = snapshot
	if lastCashValue ~= nil and snapshot.Cash ~= lastCashValue then
		popCashLabel()
	end
	lastCashValue = snapshot.Cash
	cashLabel.Text = "CASH: " .. snapshot.CashText
	incomeLabel.Text = "+$" .. tostring(snapshot.IncomePerSecond) .. "/s"
	rebirthLabel.Text = "x" .. tostring(snapshot.Multiplier) .. " income"
	rebuildQuestPanel(snapshot.Quests)
	if snapshot.IsLocked then
		lockButton.Text = "LOCKED " .. tostring(snapshot.LockSecondsLeft) .. "s"
	else
		lockButton.Text = "LOCK BASE"
	end
	if snapshot.Carrying then
		toastLabel.Text = "YOU ARE CARRYING A STOLEN BRAINROT - DASH HOME!"
	end
end)

remotes:WaitForChild("WaveUpdate").OnClientEvent:Connect(function(phase: string, secondsLeft: number)
	if phase == "Sweeping" then
		waveBanner.Text = "BIG WAVE!!! RUN TO YOUR BASE OR HIGH GROUND!"
		waveBanner.TextColor3 = Color3.fromRGB(255, 80, 80)
		setBannerPulse(true)
	elseif phase == "Warning" then
		waveBanner.Text = "BIG WAVE IN " .. tostring(secondsLeft) .. "s - RUN TO YOUR BASE!"
		waveBanner.TextColor3 = Color3.fromRGB(255, 140, 60)
		setBannerPulse(secondsLeft <= 10)
	else
		waveBanner.Text = "Next Big Wave: " .. tostring(secondsLeft) .. "s"
		waveBanner.TextColor3 = Color3.fromRGB(140, 210, 255)
		setBannerPulse(false)
	end
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(message: string)
	toastLabel.Text = message
	task.delay(6, function()
		if toastLabel.Text == message then
			toastLabel.Text = ""
		end
	end)
end)
