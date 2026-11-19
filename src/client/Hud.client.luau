-- Hud.client.luau (LocalScript, StarterPlayerScripts.Client)
-- Brainrot Island -- the heads-up display over the 3D world: cash, income per second,
-- rebirth multiplier and lock state in a panel at the TOP CENTRE (Roblox's own menu
-- buttons cover the top-left corner, so nothing important lives there), a big Big Wave
-- countdown banner under it, a toast line for game news, and the DASH and LOCK buttons.
-- Two small animations keep it alive: the cash label pops whenever the number changes,
-- and the wave banner pulses red while a Big Wave is about to hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

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

-- Toasts: steals, hatches, sales and warnings land here, centre screen.
local toastLabel = makeLabel("ToastLabel", UDim2.new(0.5, 0, 0.32, 0), UDim2.fromOffset(760, 64), 28, Color3.fromRGB(255, 255, 255))
toastLabel.BackgroundTransparency = 1
toastLabel.Text = "Buy them. Guard them. Outrun the Big Wave."
task.delay(8, function()
	if toastLabel.Text == "Buy them. Guard them. Outrun the Big Wave." then
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
	if lastCashValue ~= nil and snapshot.Cash ~= lastCashValue then
		popCashLabel()
	end
	lastCashValue = snapshot.Cash
	cashLabel.Text = "CASH: " .. snapshot.CashText
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
