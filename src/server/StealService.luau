-- StealService.luau (ModuleScript, ServerScriptService.Server)
-- Brainrot Tycoon: Tsunami Dash -- the tension engine: walk into another player's unlocked
-- brainrot to rip it off its pad and carry it on your back, slowed down, while its owner
-- chases you. Reach your own base to keep it. A locked base raises laser walls and cannot
-- be robbed until the lock timer runs out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local EconomyService = require(ServerModules:WaitForChild("EconomyService"))

local StealService = {}

local remotes: { [string]: RemoteEvent } = {}
local lastStealTouchByUserId: { [number]: number } = {}

function StealService.BindRemotes(remoteFolder: Folder)
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

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Straps a stolen brainrot model onto the thief's back so everyone can see the crime.
function StealService.AttachCarriedModelToBack(thief: Player, model: Model)
	local character = thief.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart"))
	if not torso then
		return
	end
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = false
			piece.CanCollide = false
		end
	end
	model:PivotTo(torso.CFrame * CFrame.new(0, 1.5, 1.8))
	local body = model.PrimaryPart
	if body and torso:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = torso
		weld.Part1 = body
		weld.Parent = body
	end
end

function StealService.BeginCarry(thiefState: any, victimState: any, placed: any): boolean
	if thiefState.Carried then
		return false
	end
	local removed = PlayerData.RemovePlaced(victimState, placed.Uid)
	if not removed then
		return false
	end
	thiefState.Carried = removed
	PlayerData.FireStateChanged(thiefState)
	setWalkSpeed(thiefState.Player, GameConfig.CarriedWalkSpeed)
	if removed.Model then
		StealService.AttachCarriedModelToBack(thiefState.Player, removed.Model)
	end
	local character = BrainrotCatalog.GetCharacterById(removed.CharacterId)
	local name = if character then character.Name else "a brainrot"
	notifyPlayer(thiefState.Player, "You stole " .. name .. "! DASH back to your base to keep it!")
	notifyPlayer(victimState.Player, name .. " was STOLEN from your base! Chase the thief!")
	return true
end

-- Dropping the catch: the tsunami, a tackle or leaving all wash the carried brainrot away.
function StealService.DropCarriedBrainrot(thiefState: any, reason: string)
	local carried = thiefState.Carried
	if not carried then
		return
	end
	thiefState.Carried = nil
	if carried.Model then
		carried.Model:Destroy()
	end
	setWalkSpeed(thiefState.Player, GameConfig.NormalWalkSpeed)
	PlayerData.FireStateChanged(thiefState)
	notifyPlayer(thiefState.Player, reason)
end

-- The dash home ends here: stepping onto your own base floor banks the stolen brainrot.
function StealService.TryBankCarriedBrainrot(thiefState: any): boolean
	local carried = thiefState.Carried
	if not carried then
		return false
	end
	if not PlayerData.HasFreePad(thiefState) then
		notifyPlayer(thiefState.Player, "Your base is full! The stolen brainrot slips away!")
		StealService.DropCarriedBrainrot(thiefState, "Dropped: your base had no free pad.")
		return false
	end
	thiefState.Carried = nil
	if carried.Model then
		carried.Model:Destroy()
	end
	setWalkSpeed(thiefState.Player, GameConfig.NormalWalkSpeed)
	local placedOk = EconomyService.PlaceBrainrotOnPad(thiefState, carried.CharacterId, carried.Mutation)
	if placedOk then
		local character = BrainrotCatalog.GetCharacterById(carried.CharacterId)
		local name = if character then character.Name else "Brainrot"
		notifyPlayer(thiefState.Player, "Banked! " .. name .. " now earns at YOUR base.")
	end
	return placedOk
end

function StealService.TryToggleBaseLock(state: any): boolean
	local now = os.clock()
	if PlayerData.IsBaseLocked(state) then
		notifyPlayer(state.Player, "Your base is already locked.")
		return false
	end
	if now < state.LockReadyAt then
		notifyPlayer(state.Player, "Lock is recharging...")
		return false
	end
	state.LockEndsAt = now + GameConfig.LockDurationSeconds
	state.LockReadyAt = state.LockEndsAt + GameConfig.LockCooldownSeconds
	local base = WorldBuilder.GetBaseByIndex(state.BaseIndex)
	if base then
		WorldBuilder.SetBaseLasersVisible(base, true)
		task.delay(GameConfig.LockDurationSeconds, function()
			WorldBuilder.SetBaseLasersVisible(base, false)
			notifyPlayer(state.Player, "Your base lock expired. Your brainrots can be stolen!")
		end)
	end
	PlayerData.FireStateChanged(state)
	notifyPlayer(state.Player, "Base LOCKED for " .. tostring(GameConfig.LockDurationSeconds) .. " seconds!")
	return true
end

-- Watches every base: lock buttons, banking a stolen brainrot, and the steal touch itself.
function StealService.WatchBases()
	for _, base in ipairs(WorldBuilder.Bases) do
		base.LockButton.Touched:Connect(function(hit)
			local characterModel = hit.Parent
			local player = characterModel and Players:GetPlayerFromCharacter(characterModel)
			if not player then
				return
			end
			local state = PlayerData.GetState(player)
			if state and state.BaseIndex == base.Index then
				StealService.TryToggleBaseLock(state)
			end
		end)

		base.Floor.Touched:Connect(function(hit)
			local characterModel = hit.Parent
			local player = characterModel and Players:GetPlayerFromCharacter(characterModel)
			if not player then
				return
			end
			local state = PlayerData.GetState(player)
			if state and state.BaseIndex == base.Index and state.Carried then
				StealService.TryBankCarriedBrainrot(state)
			end
		end)
	end
end

-- Stealing starts with a touch: any placed brainrot model listens for a thief's arrival.
function StealService.WatchPlacedModelForSteal(model: Model, ownerState: any)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	body.Touched:Connect(function(hit)
		local characterModel = hit.Parent
		local thief = characterModel and Players:GetPlayerFromCharacter(characterModel)
		if not thief or thief == ownerState.Player then
			return
		end
		local now = os.clock()
		if lastStealTouchByUserId[thief.UserId] and now - lastStealTouchByUserId[thief.UserId] < GameConfig.StealTouchCooldownSeconds then
			return
		end
		lastStealTouchByUserId[thief.UserId] = now
		if PlayerData.IsBaseLocked(ownerState) then
			notifyPlayer(thief, "That base is LOCKED! The lasers zap your fingers.")
			return
		end
		local thiefState = PlayerData.GetState(thief)
		if not thiefState or thiefState.Carried then
			return
		end
		local uid = model:GetAttribute("BrainrotUid")
		local placed = uid and PlayerData.FindPlacedByUid(ownerState, uid)
		if placed then
			StealService.BeginCarry(thiefState, ownerState, placed)
		end
	end)
end

-- Placed models appear over time (buys, hatches, banks), so a slow scan keeps every one
-- of them steal-watched exactly once, whoever placed it.
function StealService.StartStealWatchLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, state in ipairs(PlayerData.GetAllStates()) do
				for _, placed in ipairs(state.Placed) do
					if placed.Model and not placed.Model:GetAttribute("StealWatched") then
						placed.Model:SetAttribute("StealWatched", true)
						StealService.WatchPlacedModelForSteal(placed.Model, state)
					end
				end
			end
		end
	end)
end

-- A short speed burst for the dash home (or the chase), on a cooldown.
local dashReadyAtByUserId: { [number]: number } = {}

function StealService.TryDash(player: Player): boolean
	local now = os.clock()
	if dashReadyAtByUserId[player.UserId] and now < dashReadyAtByUserId[player.UserId] then
		return false
	end
	dashReadyAtByUserId[player.UserId] = now + GameConfig.DashCooldownSeconds + GameConfig.DashDurationSeconds
	local state = PlayerData.GetState(player)
	local baseSpeed = if state and state.Carried then GameConfig.CarriedWalkSpeed else GameConfig.NormalWalkSpeed
	setWalkSpeed(player, GameConfig.DashWalkSpeed)
	task.delay(GameConfig.DashDurationSeconds, function()
		local currentState = PlayerData.GetState(player)
		local restoreSpeed = if currentState and currentState.Carried then GameConfig.CarriedWalkSpeed else baseSpeed
		setWalkSpeed(player, restoreSpeed)
	end)
	return true
end

return StealService
