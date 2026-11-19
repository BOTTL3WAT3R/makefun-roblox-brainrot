-- AnimationService.luau (ModuleScript, ServerScriptService.Server)
-- Brainrot Island -- the animation layer. The world itself stays deliberately simple;
-- all the motion lives on the collectibles, like the big tycoon games do it:
--   * every placed or belt brainrot gently bobs, and Mythic / Brainrot God rarities
--     also slowly spin, driven by ONE Heartbeat loop for the whole game;
--   * Legendary-and-up brainrots and every mutated brainrot wear a sparkle emitter,
--     tinted by mutation (Gold, Diamond, Rainbow) or warm white-gold for rarity alone;
--   * the egg dome breathes with a looping scale pulse;
--   * the conveyor slot pads chase a bright highlight around the belt, faking motion.
-- Everything here is cheap, nil-safe and pcall-friendly: a missed registration can
-- never break a mechanic, and a model that leaves the world removes itself.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AnimationService = {}

type AnimEntry = {
	Model: Model,
	Primary: BasePart,
	Home: CFrame,
	Phase: number,
	Spin: boolean,
	SpinAngle: number,
}

local entries: { [Model]: AnimEntry } = {}
local elapsed = 0
local loopStarted = false

local SPARKLE_TEXTURE = "rbxassetid://6490895960"
local SPIN_RADIANS_PER_SECOND = 0.6
local BOB_AMPLITUDE = 0.18
local BOB_SPEED = 2.2

local function sparkleColorFor(rarity: string?, mutationName: string?): ColorSequence?
	if mutationName == "Gold" then
		return ColorSequence.new(Color3.fromRGB(255, 200, 60))
	elseif mutationName == "Diamond" then
		return ColorSequence.new(Color3.fromRGB(120, 220, 255))
	elseif mutationName == "Rainbow" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
		})
	elseif rarity == "Legendary" or rarity == "Mythic" or rarity == "Brainrot God" then
		return ColorSequence.new(Color3.fromRGB(255, 230, 160))
	end
	return nil
end

local function attachSparkles(primary: BasePart, rarity: string?, mutationName: string?)
	local color = sparkleColorFor(rarity, mutationName)
	if not color then
		return
	end
	if primary:FindFirstChild("BrainrotSparkles") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BrainrotSparkles"
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = color
	emitter.Rate = 12
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0.7
	emitter.Parent = primary
end

local function startLoopIfNeeded()
	if loopStarted then
		return
	end
	loopStarted = true
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		for model, entry in pairs(entries) do
			if model.Parent == nil or entry.Primary.Parent == nil then
				entries[model] = nil
			else
				if entry.Spin then
					entry.SpinAngle += deltaTime * SPIN_RADIANS_PER_SECOND
				end
				local bob = math.sin(elapsed * BOB_SPEED + entry.Phase) * BOB_AMPLITUDE
				local ok = pcall(function()
					model:PivotTo(entry.Home * CFrame.new(0, bob, 0) * CFrame.Angles(0, entry.SpinAngle, 0))
				end)
				if not ok then
					entries[model] = nil
				end
			end
		end
	end)
end

-- Register a brainrot model for bobbing (and spinning / sparkles when it earns them).
-- opts: { Rarity: string?, Mutation: string?, Spin: boolean? }
function AnimationService.Register(model: Model?, opts: { [string]: any }?)
	if not model or not model:IsA("Model") then
		return
	end
	local primary = model.PrimaryPart or model:FindFirstChild("Body")
	if not primary or not primary:IsA("BasePart") then
		return
	end
	local options = opts or {}
	entries[model] = {
		Model = model,
		Primary = primary,
		Home = model:GetPivot(),
		Phase = math.random() * math.pi * 2,
		Spin = options.Spin == true,
		SpinAngle = 0,
	}
	attachSparkles(primary, options.Rarity, options.Mutation)
	startLoopIfNeeded()
end

function AnimationService.Unregister(model: Model?)
	if model then
		entries[model] = nil
	end
end

-- The egg dome breathes: a soft looping scale pulse, 8 studs out to 8.7 and back.
function AnimationService.StartEggPulse(domePart: BasePart?)
	if not domePart then
		return
	end
	local tween = TweenService:Create(
		domePart,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = Vector3.new(8.7, 8.7, 8.7) }
	)
	tween:Play()
end

-- Conveyor chase lights: one slot pad glows bright at a time, cycling fast enough
-- (0.15s per step) that the belt reads as moving even though the brainrots stand still.
local BELT_DIM = Color3.fromRGB(255, 140, 40)
local BELT_BRIGHT = Color3.fromRGB(255, 244, 190)

function AnimationService.StartBeltLights(slots: { any }?)
	if not slots or #slots == 0 then
		return
	end
	task.spawn(function()
		local highlight = 1
		while true do
			for index, slot in ipairs(slots) do
				local pad = slot and slot.Pad
				if pad and pad.Parent then
					pad.Color = if index == highlight then BELT_BRIGHT else BELT_DIM
				end
			end
			highlight += 1
			if highlight > #slots then
				highlight = 1
			end
			task.wait(0.15)
		end
	end)
end

return AnimationService
