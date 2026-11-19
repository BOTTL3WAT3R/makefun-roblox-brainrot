-- TsunamiService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the Big Wave. Every cycle: calm, a loud warning with a countdown,
-- then a wall of water tweens smoothly across the island. Anyone caught low and outside
-- a base loses the brainrot they are carrying and is washed back to spawn. Bases and
-- the high hill are safe ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Safe means: inside your own base plot, or standing on the high hill.
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
		StealService.DropCarriedBrainrot(state, "The BIG WAVE took the brainrot you were carrying!")
	end
	TsunamiService.WashPlayerBackToSpawn(player)
end

local function runSweep()
	TsunamiService.Phase = "Sweeping"
	broadcastWaveState()
	notifyAll("BIG WAVE! RUN TO YOUR BASE OR HIGH GROUND!")
	local wall = WorldBuilder.TsunamiWall
	local foam = WorldBuilder.TsunamiFoam
	local startX = -260
	local endX = 260
	local distance = endX - startX
	local duration = distance / GameConfig.TsunamiWallSpeed
	-- The wall glides on a linear TweenService tween instead of stepping, and the
	-- white foam crest rides the same tween along its top edge.
	if wall then
		TweenService:Create(wall, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = Vector3.new(endX, 12, 0) }):Play()
	end
	if foam then
		TweenService:Create(foam, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = Vector3.new(endX, 28.5, 0) }):Play()
	end
	local elapsed = 0
	local step = 0.1
	while elapsed < duration do
		task.wait(step)
		elapsed += step
		local x = if wall then wall.Position.X else startX + distance * (elapsed / duration)
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
	if foam then
		foam.Position = Vector3.new(startX, 28.5, 0)
	end
	notifyAll("The Big Wave passed. The belt is restocked — happy collecting!")
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
			notifyAll("The BIG WAVE is coming! Get to your base or the high hill!")
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
