-- AnimationService.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- the animation layer. The world itself stays deliberately simple;
-- all the motion lives on the collectibles, like the big tycoon games do it:
--   * every placed brainrot gently bobs, and the top rarities (Mythic and above)
--     also slowly spin, driven by ONE Heartbeat loop for the whole game;
--   * belt brainrots WALK the conveyor (RegisterWalker): they stride along +X with
--     a quick bob and a side-to-side sway, faces turned to the travel direction,
--     and hand themselves back through OnArrive at the end of the belt;
--   * Legendary-and-up brainrots and every mutated brainrot wear a sparkle emitter,
--     tinted by mutation (Gold, Diamond, Rainbow) or warm white-gold for rarity alone;
--   * the egg dome breathes with a looping scale pulse;
--   * the conveyor pads chase a bright highlight along the belt's front edge.
-- Everything here is cheap, nil-safe and pcall-friendly: a missed registration can
-- never break a mechanic, and a model that leaves the world removes itself.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))

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

type WalkerEntry = {
	Model: Model,
	Primary: BasePart,
	X: number,
	Y: number,
	Z: number,
	Speed: number,
	EndX: number,
	Phase: number,
	OnArrive: ((Model) -> ())?,
}

local walkers: { [Model]: WalkerEntry } = {}
local elapsed = 0
local loopStarted = false

local SPARKLE_TEXTURE = "rbxassetid://6490895960"
local SPIN_RADIANS_PER_SECOND = 0.6
local BOB_AMPLITUDE = 0.18
local BOB_SPEED = 2.2
local WALK_BOB_AMPLITUDE = 0.12
local WALK_BOB_SPEED = 10
local WALK_SWAY_AMPLITUDE = 0.06
local WALK_SWAY_SPEED = 5
-- Brainrot models face -Z out of the builder; this turn points them down +X.
local WALK_FACING = CFrame.Angles(0, math.rad(-90), 0)

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
	elseif rarity == "Cosmic" or rarity == "Transcendent" or rarity == "Celestial" or rarity == "Secret" then
		-- The four tiers above Brainrot God sparkle in their own ladder colours:
		-- galaxy violet for Cosmic, radiant white-gold for Transcendent, icy
		-- cyan-white for Celestial, hot magenta-pink for Secret.
		return ColorSequence.new(BrainrotCatalog.RarityColors[rarity] or Color3.fromRGB(255, 230, 160))
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
		-- Walkers stride along +X; arrivals are collected and fired after the
		-- loop so OnArrive can safely destroy its own model mid-frame.
		local arrived: { WalkerEntry } = {}
		for model, walker in pairs(walkers) do
			if model.Parent == nil or walker.Primary.Parent == nil then
				walkers[model] = nil
			else
				walker.X += walker.Speed * deltaTime
				local bob = math.sin(elapsed * WALK_BOB_SPEED + walker.Phase) * WALK_BOB_AMPLITUDE
				local sway = math.sin(elapsed * WALK_SWAY_SPEED + walker.Phase) * WALK_SWAY_AMPLITUDE
				local ok = pcall(function()
					model:PivotTo(CFrame.new(walker.X, walker.Y + bob, walker.Z) * WALK_FACING * CFrame.Angles(0, 0, sway))
				end)
				if not ok then
					walkers[model] = nil
				elseif walker.X >= walker.EndX then
					walkers[model] = nil
					table.insert(arrived, walker)
				end
			end
		end
		for _, walker in ipairs(arrived) do
			if walker.OnArrive then
				local onArrive = walker.OnArrive
				task.spawn(function()
					pcall(onArrive, walker.Model)
				end)
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

-- Register a brainrot as a belt walker: the Heartbeat loop strides it along +X
-- from wherever it currently stands until its pivot passes opts.EndX, then calls
-- opts.OnArrive(model) exactly once. opts: { Speed, EndX, OnArrive, Rarity, Mutation }
function AnimationService.RegisterWalker(model: Model?, opts: { [string]: any }?)
	if not model or not model:IsA("Model") then
		return
	end
	local primary = model.PrimaryPart or model:FindFirstChild("Body")
	if not primary or not primary:IsA("BasePart") then
		return
	end
	local options = opts or {}
	local pivot = model:GetPivot()
	walkers[model] = {
		Model = model,
		Primary = primary,
		X = pivot.Position.X,
		Y = pivot.Position.Y,
		Z = pivot.Position.Z,
		Speed = options.Speed or 6,
		EndX = options.EndX or pivot.Position.X + 100,
		Phase = math.random() * math.pi * 2,
		OnArrive = options.OnArrive,
	}
	attachSparkles(primary, options.Rarity, options.Mutation)
	startLoopIfNeeded()
end

-- Removes a model from BOTH registries (placed bobbers and belt walkers), so any
-- removal path -- sell, steal, buy, despawn -- only ever calls this one function.
function AnimationService.Unregister(model: Model?)
	if model then
		entries[model] = nil
		walkers[model] = nil
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

-- Conveyor chase lights: the pads wear a pastel candy palette (pink, mint, baby
-- blue, lavender, peach) and one pad flashes white at a time, cycling fast
-- (0.15s per step) along the belt's front edge, echoing the walkers above it.
local BELT_COLORS = {
	Color3.fromRGB(255, 170, 205),
	Color3.fromRGB(170, 240, 195),
	Color3.fromRGB(170, 215, 255),
	Color3.fromRGB(215, 185, 255),
	Color3.fromRGB(255, 205, 165),
}
local BELT_BRIGHT = Color3.fromRGB(255, 255, 255)

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
					pad.Color = if index == highlight then BELT_BRIGHT else BELT_COLORS[((index - 1) % #BELT_COLORS) + 1]
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
