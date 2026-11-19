-- Hud.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Brainrot Tycoon: Tsunami Dash -- the heads-up display over the 3D world: cash, income
-- per second, rebirth multiplier and lock state in a panel at the TOP CENTRE (Roblox's own
-- menu buttons cover the top-left corner, so nothing important lives there), a big tsunami
-- countdown banner under it, a toast line for game news, and the DASH and LOCK buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
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
local cashLabel = makeLabel("CashLabel", UDim2.new(0.5, -190, 0, 12), UDim2.fromOffset(250, 52), 30, Color3.fromRGB(140, 255, 150))
cashLabel.Text = "$100"
local incomeLabel = makeLabel("IncomeLabel", UDim2.new(0.5, 75, 0, 12), UDim2.fromOffset(250, 52), 24, Color3.fromRGB(255, 230, 120))
incomeLabel.Text = "+$0/s"
local rebirthLabel = makeLabel("RebirthLabel", UDim2.new(0.5, 320, 0, 12), UDim2.fromOffset(210, 52), 24, Color3.fromRGB(160, 255, 255))
rebirthLabel.Text = "x1 income"

-- The tsunami banner: calm it counts down quietly, warning it shouts.
local waveBanner = makeLabel("WaveBanner", UDim2.new(0.5, 0, 0, 76), UDim2.fromOffset(620, 58), 32, Color3.fromRGB(140, 210, 255))
waveBanner.Text = "Next tsunami: --"

-- Toasts: steals, hatches, sales and warnings land here, centre screen.
local toastLabel = makeLabel("ToastLabel", UDim2.new(0.5, 0, 0.32, 0), UDim2.fromOffset(760, 64), 28, Color3.fromRGB(255, 255, 255))
toastLabel.BackgroundTransparency = 1
toastLabel.Text = "Buy a brainrot from the belt. Guard it. Outrun the wave."
task.delay(8, function()
	if toastLabel.Text == "Buy a brainrot from the belt. Guard it. Outrun the wave." then
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
ContextActionService:BindAction("BrainrotDash", function(_actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		remotes:WaitForChild("RequestDash"):FireServer()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift)

local latestSnapshot: any = nil

remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot: any)
	latestSnapshot = snapshot
	cashLabel.Text = snapshot.CashText
	incomeLabel.Text = "+$" .. tostring(snapshot.IncomePerSecond) .. "/s"
	rebirthLabel.Text = "x" .. tostring(snapshot.Multiplier) .. " income"
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
		waveBanner.Text = "TSUNAMI!!! RUN TO YOUR BASE OR HIGH GROUND!"
		waveBanner.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif phase == "Warning" then
		waveBanner.Text = "TSUNAMI IN " .. tostring(secondsLeft) .. "s - GET HOME!"
		waveBanner.TextColor3 = Color3.fromRGB(255, 140, 60)
	else
		waveBanner.Text = "Next tsunami: " .. tostring(secondsLeft) .. "s"
		waveBanner.TextColor3 = Color3.fromRGB(140, 210, 255)
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
