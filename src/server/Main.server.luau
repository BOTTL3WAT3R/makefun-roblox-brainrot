-- Main.server.luau (Script, ServerScriptService.Server)
-- Brainrot Tycoon: Tsunami Dash -- the server bootstrap. It builds the world, creates the
-- RemoteEvents the client talks through, hands each player a base plot, keeps leaderstats
-- in step with PlayerData, and starts every service loop: income, conveyor, stealing,
-- the tsunami cycle and the rebirth shrine.

local Players = game:GetService("Players")
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
local TsunamiService = require(ServerModules:WaitForChild("TsunamiService"))
local RebirthService = require(ServerModules:WaitForChild("RebirthService"))

-- 1. The world exists before anyone joins.
WorldBuilder.BuildWorld()

-- 2. Remotes: one folder, named events, created here so client and server agree.
local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "Remotes"
remoteFolder.Parent = ReplicatedStorage

local remoteNames = {
	"BuyBrainrot", "HatchEgg", "SellBrainrot", "ToggleLock", "RequestRebirth",
	"RequestDash", "StateUpdate", "Notify", "WaveUpdate",
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
TsunamiService.BindRemotes(remoteFolder, Instance.new("BindableEvent"))
RebirthService.BindRemotes(remoteFolder)

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
			humanoid.WalkSpeed = GameConfig.NormalWalkSpeed
		end
		if base then
			task.wait(0.2)
			root.CFrame = CFrame.new(base.Origin + Vector3.new(0, 4, 20))
		end
		pushStateToPlayer(player)
	end)

	remotes.Notify:FireClient(player, "Welcome to Brainrot Tycoon: Tsunami Dash! Buy a brainrot from the belt, guard it, and outrun the wave!")
	pushStateToPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
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
remotes.BuyBrainrot.OnServerEvent:Connect(function(player: Player, characterId: any)
	if typeof(characterId) ~= "string" then
		return
	end
	local state = PlayerData.GetState(player)
	if state then
		EconomyService.BuyCharacter(state, characterId)
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
		remotes.Notify:FireClient(player, "Walk to the Egg Machine by the shop row to hatch!")
		return
	end
	EconomyService.HatchEgg(state)
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

-- 6. Start every loop.
StealService.WatchBases()
StealService.StartStealWatchLoop()
EconomyService.StartIncomeTickLoop()
EconomyService.StartConveyorLoop()
TsunamiService.StartWaveCycleLoop()
RebirthService.WatchShrineProximity()

print(GameConfig.GameTitle .. " server started: world built, remotes live, tsunami scheduled.")
