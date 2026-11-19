-- RebirthService.luau (ModuleScript, ServerScriptService.Server)
-- Brainrot Tycoon: Tsunami Dash -- the long ladder: pay a mountain of cash, lose every
-- placed brainrot and your carried catch, and come back with a permanent income
-- multiplier. Each rebirth also raises the shrine's price for the next one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))

local RebirthService = {}

local remotes: { [string]: RemoteEvent } = {}

function RebirthService.BindRemotes(remoteFolder: Folder)
	for _, child in ipairs(remoteFolder:GetChildren()) do
		if child:IsA("RemoteEvent") then
			remotes[child.Name] = child
		end
	end
end

local function notifyPlayer(player: Player, message: string)
	local remote = remotes.Notify
	if remote then
		remote:FireClient(player, message)
	end
end

function RebirthService.GetNextRebirthCost(state: any): number
	return GameConfig.GetRebirthCost(state.Rebirths)
end

function RebirthService.CanAffordRebirth(state: any): boolean
	return state.Cash >= RebirthService.GetNextRebirthCost(state)
end

local function destroyPlacedModels(state: any)
	for _, placed in ipairs(state.Placed) do
		if placed.Model then
			placed.Model:Destroy()
		end
	end
	if state.Carried and state.Carried.Model then
		state.Carried.Model:Destroy()
	end
end

function RebirthService.PerformRebirth(state: any): boolean
	local cost = RebirthService.GetNextRebirthCost(state)
	if not PlayerData.TrySpendCash(state, cost) then
		notifyPlayer(state.Player, "Rebirth needs " .. GameConfig.FormatCash(cost) .. ". Keep grinding!")
		return false
	end
	destroyPlacedModels(state)
	PlayerData.WipeForRebirth(state)
	local newMultiplier = PlayerData.GetIncomeMultiplier(state)
	notifyPlayer(state.Player, string.format("REBIRTH! Your income is now x%d forever. Rebuild bigger!", newMultiplier))
	return true
end

-- Stepping up to the shrine crystal offers the rebirth; the client button confirms it.
function RebirthService.WatchShrineProximity()
	local shrinePosition = Vector3.new(-45, 0, -104)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, state in ipairs(PlayerData.GetAllStates()) do
				local character = state.Player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - shrinePosition).Magnitude < 14 then
					local remote = remotes.Notify
					if remote then
						local cost = RebirthService.GetNextRebirthCost(state)
						remote:FireClient(state.Player, "Rebirth Shrine: reset everything for +100% income. Cost: " .. GameConfig.FormatCash(cost) .. " - use the REBIRTH button!")
					end
				end
			end
		end
	end)
end

return RebirthService
