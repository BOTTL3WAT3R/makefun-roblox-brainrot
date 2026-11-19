-- Main.server.luau (Script, ServerScriptService.Server)
-- Neon Shores -- the server bootstrap. It sets the golden-hour lighting, builds the
-- world, creates the RemoteEvents the client talks through, hands each player a base
-- plot, keeps leaderstats in step with PlayerData, and starts every service loop:
-- income, conveyor, the Neon Arena golden-brainrot event, stealing, the Big Wave
-- cycle, the Rebirth Shrine watch and the AnimationService dressing (egg pulse and
-- belt chase lights). Snapshots carry the player's current mission line for the HUD.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = ServerScriptService:WaitForChild("Server")
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local EconomyService = require(ServerModules:WaitForChild("EconomyService"))
local StealService = require(ServerModules:WaitForChild("StealService"))
local FuseService = require(ServerModules:WaitForChild("FuseService"))
local TsunamiService = require(ServerModules:WaitForChild("TsunamiService"))
local RebirthService = require(ServerModules:WaitForChild("RebirthService"))
local AnimationService = require(ServerModules:WaitForChild("AnimationService"))
local PlaygroundService = require(ServerModules:WaitForChild("PlaygroundService"))

-- 0. Golden hour: the sun sits low, the air is peachy, and only the neon is bright
-- enough to bloom. This is the single biggest screenshot win in the game.
local function setupGoldenHourLighting()
	Lighting.ClockTime = 16.9
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(161, 117, 97)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 129, 106)
	Lighting.FogColor = Color3.fromRGB(252, 183, 140)
	Lighting.FogStart = 150
	Lighting.FogEnd = 900
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NeonBloom"
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "DuskSunRays"
	sunRays.Intensity = 0.08
	sunRays.Spread = 0.8
	sunRays.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "DuskAtmosphere"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 199, 158)
	atmosphere.Decay = Color3.fromRGB(209, 140, 102)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting
end
setupGoldenHourLighting()

-- 1. The world exists before anyone joins.
local worldFolder = WorldBuilder.BuildWorld()

-- 2. Remotes: one folder, named events, created here so client and server agree.
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
remoteFolder.Parent = ReplicatedStorage

local remoteNames = {
	"BuyBoost", "HatchEgg", "RollGacha", "SellBrainrot", "ToggleLock", "RequestRebirth",
	"RequestDash", "StateUpdate", "Notify", "WaveUpdate", "FuseBrainrots",
}
local remotes: { [string]: RemoteEvent } = {}
for _, remoteName in ipairs(remoteNames) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = remoteFolder
	remotes[remoteName] = remote
end

EconomyService.BindRemotes(remoteFolder)
StealService.BindRemotes(remoteFolder)
FuseService.BindRemotes(remoteFolder)
TsunamiService.BindRemotes(remoteFolder, Instance.new("BindableEvent"))
RebirthService.BindRemotes(remoteFolder)
PlaygroundService.BindRemotes(remoteFolder)

-- 3. State sync: whenever PlayerData changes, push a plain snapshot to that player and
-- refresh their leaderstats, so the HUD never guesses.
local stateChanged = Instance.new("BindableEvent")
stateChanged.Name = "PlayerStateChanged"
stateChanged.Parent = ServerScriptService
PlayerData.BindStateChangedEvent(stateChanged)

local function buildStateSnapshot(state: any)
	local placedSummary = {}
	for _, placed in ipairs(state.Placed) do
		local character = BrainrotCatalog.GetCharacterById(placed.CharacterId)
		if character then
			table.insert(placedSummary, {
				Uid = placed.Uid,
				CharacterId = placed.CharacterId,
				Name = character.Name,
				Rarity = character.Rarity,
				Mutation = placed.Mutation,
				IncomePerSecond = BrainrotCatalog.GetIncomePerSecond(character, placed.Mutation),
			})
		end
	end
	return {
		Cash = state.Cash,
		CashText = GameConfig.FormatCash(state.Cash),
		IncomePerSecond = EconomyService.GetPlacedIncomePerSecond(state),
		Rebirths = state.Rebirths,
		Multiplier = PlayerData.GetIncomeMultiplier(state),
		NextRebirthCost = RebirthService.GetNextRebirthCost(state),
		BaseIndex = state.BaseIndex,
		LockSecondsLeft = math.max(0, math.ceil(state.LockEndsAt - os.clock())),
		IsLocked = PlayerData.IsBaseLocked(state),
		Carrying = state.Carried ~= nil,
		CarriedId = if state.Carried then state.Carried.CharacterId else nil,
		Mission = PlayerData.GetMissionSnapshot(state),
		Boosts = {
			SpeedLeft = PlayerData.GetBoostSecondsLeft(state, "Speed"),
			IncomeLeft = PlayerData.GetBoostSecondsLeft(state, "Income"),
			LuckLeft = PlayerData.GetBoostSecondsLeft(state, "Luck"),
			WaveShield = state.WaveShield,
		},
		Placed = placedSummary,
	}
end

local function pushStateToPlayer(player: Player)
	local state = PlayerData.GetState(player)
	if not state then
		return
	end
	remotes.StateUpdate:FireClient(player, buildStateSnapshot(state))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cashValue = leaderstats:FindFirstChild("Cash")
		if cashValue then
			cashValue.Value = state.Cash
		end
		local rebirthValue = leaderstats:FindFirstChild("Rebirths")
		if rebirthValue then
			rebirthValue.Value = state.Rebirths
		end
	end
end

stateChanged.Event:Connect(function(player: Player)
	pushStateToPlayer(player)
end)

-- Boost bookkeeping for the 1-second housekeeping loop in section 6: the
-- last-seen active flags per player, so expiries are caught the second a
-- boost runs out and the player gets a fresh snapshot (and their WalkSpeed
-- restored) instead of drifting on stale numbers.
local boostWasActive: { [number]: { [string]: boolean } } = {}

-- 4. Players: state, a base plot, leaderstats, and a welcome snapshot.
local function onPlayerAdded(player: Player)
	local state = PlayerData.CreateStateForPlayer(player)
	local base = WorldBuilder.GetFreeBase()
	if base then
		base.Owner = player
		state.BaseIndex = base.Index
		WorldBuilder.SetBaseOwnerSign(base, player.DisplayName)
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = state.Cash
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = 0
	rebirthValue.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Respawn keeps a live Speed Surge: base speed comes from PlayerData.
			humanoid.WalkSpeed = PlayerData.GetBaseWalkSpeed(state)
		end
		if base then
			task.wait(0.2)
			-- Land between the base and the belt: the base's Facing points from
			-- its plot toward the conveyor, whichever side of the island it is on.
			root.CFrame = CFrame.new(base.Origin + Vector3.new(0, 4, 20 * (base.Facing or 1)))
		end
		pushStateToPlayer(player)
	end)

	remotes.Notify:FireClient(player, "Welcome to Neon Shores! Buy a brainrot from the belt, guard it at your base, and outrun the Big Wave!")
	pushStateToPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	boostWasActive[player.UserId] = nil
	for _, base in ipairs(WorldBuilder.Bases) do
		if base.Owner == player then
			base.Owner = nil
			WorldBuilder.SetBaseOwnerSign(base, nil)
			WorldBuilder.SetBaseLasersVisible(base, false)
		end
	end
	local state = PlayerData.GetState(player)
	if state then
		for _, placed in ipairs(state.Placed) do
			if placed.Model then
				placed.Model:Destroy()
			end
		end
		if state.Carried and state.Carried.Model then
			state.Carried.Model:Destroy()
		end
	end
end)

-- 5. Client requests, each validated on the server before any money moves.
-- There is deliberately NO remote that buys a brainrot directly: the only
-- way to buy one is walking into it on the belt (EconomyService's server-side
-- touch handler). This endpoint buys BOOSTS, validated in EconomyService.
remotes.BuyBoost.OnServerEvent:Connect(function(player: Player, boostId: any)
	if typeof(boostId) ~= "string" then
		return
	end
	local state = PlayerData.GetState(player)
	if state then
		EconomyService.BuyBoost(state, boostId)
	end
end)

remotes.HatchEgg.OnServerEvent:Connect(function(player: Player)
	local state = PlayerData.GetState(player)
	if not state then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and WorldBuilder.EggMachinePosition and (root.Position - WorldBuilder.EggMachinePosition).Magnitude > 26 then
		remotes.Notify:FireClient(player, "Walk to the Egg Machine by the shop belt to hatch!")
		return
	end
	EconomyService.HatchEgg(state)
end)

remotes.RollGacha.OnServerEvent:Connect(function(player: Player)
	local state = PlayerData.GetState(player)
	if not state then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and WorldBuilder.GachaMachinePosition and (root.Position - WorldBuilder.GachaMachinePosition).Magnitude > 26 then
		remotes.Notify:FireClient(player, "Walk to the Gacha Capsule west of the arena to spin!")
		return
	end
	EconomyService.RollGacha(state)
end)

remotes.SellBrainrot.OnServerEvent:Connect(function(player: Player, uid: any)
	if typeof(uid) ~= "number" then
		return
	end
	local state = PlayerData.GetState(player)
	if state then
		EconomyService.SellPlacedBrainrot(state, uid)
	end
end)

remotes.ToggleLock.OnServerEvent:Connect(function(player: Player)
	local state = PlayerData.GetState(player)
	if state then
		StealService.TryToggleBaseLock(state)
	end
end)

remotes.RequestRebirth.OnServerEvent:Connect(function(player: Player)
	local state = PlayerData.GetState(player)
	if state then
		RebirthService.PerformRebirth(state)
	end
end)

remotes.RequestDash.OnServerEvent:Connect(function(player: Player)
	StealService.TryDash(player)
end)

remotes.FuseBrainrots.OnServerEvent:Connect(function(player: Player, uids: any)
	if typeof(uids) ~= "table" then
		return
	end
	local state = PlayerData.GetState(player)
	if state then
		FuseService.PerformFuse(state, uids)
	end
end)

-- 6. Start every loop.
StealService.WatchBases()
StealService.StartStealWatchLoop()
StealService.StartLockSignLoop()
EconomyService.StartIncomeTickLoop()
EconomyService.StartConveyorLoop()
EconomyService.StartArenaEventLoop()
TsunamiService.StartWaveCycleLoop()
RebirthService.WatchShrineProximity()
PlaygroundService.Start()

-- Boost housekeeping: once a second, catch boost transitions per player. A
-- Speed Surge switching off restores the player's WalkSpeed (unless they are
-- mid-carry, where the carry speed rules), and any boost starting or ending
-- pushes a fresh snapshot so the BOOST panel timers never lie.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = PlayerData.GetState(player)
			if state then
				local nowActive = {
					Speed = PlayerData.HasBoost(state, "Speed"),
					Income = PlayerData.HasBoost(state, "Income"),
					Luck = PlayerData.HasBoost(state, "Luck"),
					WaveShield = state.WaveShield,
				}
				local was = boostWasActive[player.UserId] or { Speed = false, Income = false, Luck = false, WaveShield = false }
				local changed = false
				for key, active in pairs(nowActive) do
					if was[key] ~= active then
						changed = true
					end
				end
				if nowActive.Speed ~= was.Speed and not state.Carried then
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = PlayerData.GetBaseWalkSpeed(state)
					end
				end
				boostWasActive[player.UserId] = nowActive
				if changed then
					pushStateToPlayer(player)
				end
			end
		end
	end
end)

-- 7. Animation dressing that belongs to the world itself: the egg dome breathes
-- and the belt pads chase a highlight around the shop row.
pcall(function()
	AnimationService.StartEggPulse(worldFolder:FindFirstChild("EggDome"))
end)
pcall(function()
	AnimationService.StartBeltLights(WorldBuilder.ConveyorSlots)
end)

print(GameConfig.GameTitle .. " server started: world built, remotes live, Big Wave scheduled.")
