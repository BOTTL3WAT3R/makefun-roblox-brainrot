-- TsunamiService.luau (ModuleScript, ServerScriptService.Server)
-- PLUNDERROT: Kraken's Curse -- the Kraken Tide that gives the curse its name. Every cycle:
-- calm, a loud warning with a countdown, then a wall of water sweeps the island. Anyone
-- caught low and outside a base loses the brainrot they are carrying and is washed back
-- to spawn. Bases and the Crow's Nest Cliffs are safe ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local StealService = require(ServerModules:WaitForChild("StealService"))

local TsunamiService = {}

TsunamiService.Phase = "Calm" -- Calm, Warning, Sweeping
TsunamiService.SecondsUntilWave = GameConfig.TsunamiPeriodSeconds

local remotes: { [string]: RemoteEvent } = {}
local waveStateChanged: BindableEvent? = nil

function TsunamiService.BindRemotes(remoteFolder: Folder, stateEvent: BindableEvent)
	for _, child in ipairs(remoteFolder:GetChildren()) do
		if child:IsA("RemoteEvent") then
			remotes[child.Name] = child
		end
	end
	waveStateChanged = stateEvent
end

local function broadcastWaveState()
	local remote = remotes.WaveUpdate
	if remote then
		remote:FireAllClients(TsunamiService.Phase, math.ceil(TsunamiService.SecondsUntilWave))
	end
end

local function notifyAll(message: string)
	local remote = remotes.Notify
	if remote then
		remote:FireAllClients(message)
	end
end

-- Safe means: inside your own base plot, or standing on the shelter hill's high ground.
function TsunamiService.IsPlayerSafeFromWave(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end
	if root.Position.Y > 12 then
		return true
	end
	local state = PlayerData.GetState(player)
	if state and state.BaseIndex then
		local base = WorldBuilder.GetBaseByIndex(state.BaseIndex)
		if base then
			local offset = root.Position - base.Origin
			if math.abs(offset.X) <= 23 and math.abs(offset.Z) <= 23 then
				return true
			end
		end
	end
	return false
end

function TsunamiService.WashPlayerBackToSpawn(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(Vector3.new(0, 6, 14))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function TsunamiService.ApplyWaveHitToPlayer(player: Player)
	local state = PlayerData.GetState(player)
	if state and state.Carried then
		StealService.DropCarriedBrainrot(state, "The KRAKEN TIDE took the brainrot you were carrying!")
	end
	TsunamiService.WashPlayerBackToSpawn(player)
end

local function runSweep()
	TsunamiService.Phase = "Sweeping"
	broadcastWaveState()
	notifyAll("KRAKEN TIDE! DASH TO YER BASE OR HIGH GROUND!")
	local wall = WorldBuilder.TsunamiWall
	local startX = -260
	local endX = 260
	local distance = endX - startX
	local duration = distance / GameConfig.TsunamiWallSpeed
	local elapsed = 0
	local step = 0.1
	while elapsed < duration do
		task.wait(step)
		elapsed += step
		local x = startX + distance * (elapsed / duration)
		if wall then
			wall.Position = Vector3.new(x, 12, 0)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and math.abs(root.Position.X - x) < 5 and root.Position.Z > -230 and root.Position.Z < 230 then
				if not TsunamiService.IsPlayerSafeFromWave(player) then
					TsunamiService.ApplyWaveHitToPlayer(player)
				end
			end
		end
	end
	if wall then
		wall.Position = Vector3.new(startX, 12, 0)
	end
	notifyAll("The Kraken Tide passed. The belt is restocked and the plundering resumes!")
end

function TsunamiService.StartWaveCycleLoop()
	task.spawn(function()
		while true do
			TsunamiService.Phase = "Calm"
			TsunamiService.SecondsUntilWave = GameConfig.TsunamiPeriodSeconds - GameConfig.TsunamiWarningSeconds
			while TsunamiService.SecondsUntilWave > 0 do
				task.wait(1)
				TsunamiService.SecondsUntilWave -= 1
				broadcastWaveState()
			end
			TsunamiService.Phase = "Warning"
			TsunamiService.SecondsUntilWave = GameConfig.TsunamiWarningSeconds
			notifyAll("The KRAKEN TIDE is coming! Get to yer base or the Crow's Nest Cliffs!")
			while TsunamiService.SecondsUntilWave > 0 do
				task.wait(1)
				TsunamiService.SecondsUntilWave -= 1
				broadcastWaveState()
			end
			runSweep()
		end
	end)
end

return TsunamiService
