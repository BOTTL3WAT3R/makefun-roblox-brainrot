-- StealService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the tension engine: press E on another player's unlocked
-- brainrot (a ProximityPrompt rides on every placed model, like the big games)
-- to rip it off its pad and carry it hoisted above your head, slowed down, while
-- its owner chases you. Reach your own base to keep it. A locked base raises
-- laser walls and cannot be robbed until the lock timer runs out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotCatalog = require(Shared:WaitForChild("BrainrotCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ServerModules = script.Parent
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local EconomyService = require(ServerModules:WaitForChild("EconomyService"))
local AnimationService = require(ServerModules:WaitForChild("AnimationService"))

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

-- Mission reporting is always pcall-wrapped: the mission chain is a bonus
-- layer and can never be allowed to break the mechanic that feeds it.
local function reportMission(state: any, actionKey: string)
	pcall(function()
		local completed, reward = PlayerData.ReportMissionAction(state, actionKey)
		if completed then
			notifyPlayer(state.Player, "MISSION COMPLETE! +" .. GameConfig.FormatCash(reward))
		end
	end)
end

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Hoists a stolen brainrot ABOVE the thief's head, both-arms-up style like the
-- big steal games: a Heartbeat follow loop pivots the model to a point 3.2
-- studs over the HumanoidRootPart every frame, upright and facing the way the
-- thief faces, with a gentle bob and a slight forward tilt + sway while moving.
-- The loop owns the model's pivot until the carry ends (bank, drop, wave), and
-- it disconnects itself if the carried record or the model ever disappears.
local carryFollowByUserId: { [number]: RBXScriptConnection } = {}

local function stopCarryFollow(player: Player)
	local connection = carryFollowByUserId[player.UserId]
	if connection then
		connection:Disconnect()
		carryFollowByUserId[player.UserId] = nil
	end
end

function StealService.AttachCarriedModelOverhead(thief: Player, thiefState: any, model: Model)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
		end
	end
	stopCarryFollow(thief)
	local startedAt = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local carried = thiefState.Carried
		if not carried or carried.Model ~= model or not model.Parent then
			connection:Disconnect()
			if carryFollowByUserId[thief.UserId] == connection then
				carryFollowByUserId[thief.UserId] = nil
			end
			return
		end
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
		local t = os.clock() - startedAt
		local bob = math.sin(t * 7) * 0.15
		local tilt = if moving then math.rad(7) else 0
		local sway = if moving then math.sin(t * 7) * math.rad(3) else 0
		local facing = root.CFrame - root.CFrame.Position
		model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 3.2 + bob, 0)) * facing * CFrame.Angles(tilt, 0, sway))
	end)
	carryFollowByUserId[thief.UserId] = connection
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
		-- Stop the bob loop first: from here the overhead carry follow owns the pivot.
		pcall(function()
			AnimationService.Unregister(removed.Model)
		end)
		-- A carried brainrot cannot be re-stolen mid-run: kill its Steal prompt.
		local carriedBody = removed.Model:FindFirstChild("Body")
		local stealPrompt = carriedBody and carriedBody:FindFirstChild("StealPrompt")
		if stealPrompt then
			stealPrompt.Enabled = false
		end
		StealService.AttachCarriedModelOverhead(thiefState.Player, thiefState, removed.Model)
	end
	local character = BrainrotCatalog.GetCharacterById(removed.CharacterId)
	local name = if character then character.Name else "a brainrot"
	notifyPlayer(thiefState.Player, "You stole " .. name .. "! DASH back to your base to keep it!")
	notifyPlayer(victimState.Player, name .. " was STOLEN from your base! Chase the thief!")
	return true
end

-- Dropping the catch: the Big Wave, a tackle or leaving all wash the carried brainrot away.
function StealService.DropCarriedBrainrot(thiefState: any, reason: string)
	local carried = thiefState.Carried
	if not carried then
		return
	end
	thiefState.Carried = nil
	stopCarryFollow(thiefState.Player)
	if carried.Model then
		carried.Model:Destroy()
	end
	setWalkSpeed(thiefState.Player, PlayerData.GetBaseWalkSpeed(thiefState))
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
	stopCarryFollow(thiefState.Player)
	if carried.Model then
		carried.Model:Destroy()
	end
	setWalkSpeed(thiefState.Player, PlayerData.GetBaseWalkSpeed(thiefState))
	local placedOk = EconomyService.PlaceBrainrotOnPad(thiefState, carried.CharacterId, carried.Mutation)
	if placedOk then
		local character = BrainrotCatalog.GetCharacterById(carried.CharacterId)
		local name = if character then character.Name else "Brainrot"
		notifyPlayer(thiefState.Player, "Banked! " .. name .. " now earns at YOUR base.")
		reportMission(thiefState, "Steal")
	end
	return placedOk
end

function StealService.TryToggleBaseLock(state: any): boolean
	if not state.BaseIndex then
		notifyPlayer(state.Player, "You have no base yet - a base is assigned to you when you join.")
		return false
	end
	local now = os.clock()
	if PlayerData.IsBaseLocked(state) then
		notifyPlayer(state.Player, "Your base is already locked (" .. tostring(math.ceil(state.LockEndsAt - now)) .. "s left)")
		return false
	end
	if now < state.LockReadyAt then
		notifyPlayer(state.Player, "Lock is recharging... (" .. tostring(math.ceil(state.LockReadyAt - now)) .. "s left)")
		return false
	end
	state.LockEndsAt = now + GameConfig.LockDurationSeconds
	state.LockReadyAt = state.LockEndsAt + GameConfig.LockCooldownSeconds
	local base = WorldBuilder.GetBaseByIndex(state.BaseIndex)
	if base then
		WorldBuilder.SetBaseLasersVisible(base, true)
		WorldBuilder.RefreshBaseSign(base, GameConfig.LockDurationSeconds)
		task.delay(GameConfig.LockDurationSeconds, function()
			WorldBuilder.SetBaseLasersVisible(base, false)
			notifyPlayer(state.Player, "Your base lock expired. Your brainrots can be stolen!")
		end)
	end
	PlayerData.FireStateChanged(state)
	notifyPlayer(state.Player, "Base LOCKED for " .. tostring(GameConfig.LockDurationSeconds) .. " seconds!")
	reportMission(state, "Lock")
	return true
end

-- Once a second, every owned base's sign and laser walls are synced to its
-- owner's lock state: the sign counts "LOCKED <n>s" down in the world (both
-- lock paths -- the in-world pad and the HUD button -- land here, since both
-- write the same state), and the moment the timer dies the sign reverts to
-- the owner's name and the lasers drop, whichever path raised them.
function StealService.StartLockSignLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, state in ipairs(PlayerData.GetAllStates()) do
				if state.BaseIndex then
					local base = WorldBuilder.GetBaseByIndex(state.BaseIndex)
					if base then
						if PlayerData.IsBaseLocked(state) then
							WorldBuilder.SetBaseLasersVisible(base, true)
							WorldBuilder.RefreshBaseSign(base, math.max(0, math.ceil(state.LockEndsAt - os.clock())))
						else
							WorldBuilder.SetBaseLasersVisible(base, false)
							WorldBuilder.RefreshBaseSign(base, nil)
						end
					end
				end
			end
		end
	end)
end

-- Watches every base: lock buttons, banking a stolen brainrot, and the steal touch itself.
-- The lock pad speaks up about EVERY outcome: before this, stepping on another
-- player's pad failed in total silence, which read exactly like a broken button.
local lastLockPadTouchByUserId: { [number]: number } = {}

function StealService.WatchBases()
	for _, base in ipairs(WorldBuilder.Bases) do
		base.LockButton.Touched:Connect(function(hit)
			local characterModel = hit.Parent
			local player = characterModel and Players:GetPlayerFromCharacter(characterModel)
			if not player and characterModel and characterModel.Parent then
				-- The touching part can be an accessory handle: climb one more level.
				player = Players:GetPlayerFromCharacter(characterModel.Parent)
			end
			if not player then
				return
			end
			local now = os.clock()
			if lastLockPadTouchByUserId[player.UserId] and now - lastLockPadTouchByUserId[player.UserId] < 1 then
				return
			end
			lastLockPadTouchByUserId[player.UserId] = now
			local state = PlayerData.GetState(player)
			if not state then
				return
			end
			if state.BaseIndex ~= base.Index then
				if state.BaseIndex then
					notifyPlayer(player, "This is not your base - yours is BASE " .. tostring(state.BaseIndex))
				else
					notifyPlayer(player, "This is not your base - you have no base of your own yet.")
				end
				return
			end
			StealService.TryToggleBaseLock(state)
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

-- The E prompt on a placed brainrot: the primary steal path, mirroring the big
-- games. Every refusal says WHY (your own, locked, hands full) instead of the
-- touch path's silence; a 1-second per-thief debounce keeps a refused prompt
-- from spamming toasts while the player stands next to it.
local lastStealPromptByUserId: { [number]: number } = {}

function StealService.TryStealViaPrompt(thief: Player, ownerState: any, model: Model): boolean
	if thief == ownerState.Player then
		notifyPlayer(thief, "That's your own brainrot!")
		return false
	end
	local now = os.clock()
	if lastStealPromptByUserId[thief.UserId] and now - lastStealPromptByUserId[thief.UserId] < 1 then
		return false
	end
	lastStealPromptByUserId[thief.UserId] = now
	if PlayerData.IsBaseLocked(ownerState) then
		notifyPlayer(thief, "That base is LOCKED! The lasers zap your fingers.")
		return false
	end
	local thiefState = PlayerData.GetState(thief)
	if not thiefState then
		return false
	end
	if thiefState.Carried then
		notifyPlayer(thief, "You are already carrying a brainrot! Bank it at your base first.")
		return false
	end
	local uid = model:GetAttribute("BrainrotUid")
	local placed = uid and PlayerData.FindPlacedByUid(ownerState, uid)
	if not placed then
		return false
	end
	return StealService.BeginCarry(thiefState, ownerState, placed)
end

-- Stealing starts with a touch: any placed brainrot model listens for a thief's arrival.
function StealService.WatchPlacedModelForSteal(model: Model, ownerState: any)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	-- The "E" button that floats on the brainrot itself: the character's name
	-- over the word Steal, exactly the reference layout. It is disabled the
	-- moment the brainrot is carried off (BeginCarry), and a banked brainrot
	-- is a fresh model that earns a fresh prompt from this same watcher.
	if not body:FindFirstChild("StealPrompt") then
		local uid = model:GetAttribute("BrainrotUid")
		local placed = uid and PlayerData.FindPlacedByUid(ownerState, uid)
		local character = placed and BrainrotCatalog.GetCharacterById(placed.CharacterId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "Steal"
		prompt.ObjectText = if character then character.Name else "Brainrot"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(thief: Player)
			StealService.TryStealViaPrompt(thief, ownerState, model)
		end)
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
	local baseSpeed = if state and state.Carried then GameConfig.CarriedWalkSpeed else if state then PlayerData.GetBaseWalkSpeed(state) else GameConfig.NormalWalkSpeed
	setWalkSpeed(player, GameConfig.DashWalkSpeed)
	task.delay(GameConfig.DashDurationSeconds, function()
		local currentState = PlayerData.GetState(player)
		local restoreSpeed = if currentState and currentState.Carried then GameConfig.CarriedWalkSpeed else if currentState then PlayerData.GetBaseWalkSpeed(currentState) else baseSpeed
		setWalkSpeed(player, restoreSpeed)
	end)
	return true
end

return StealService
