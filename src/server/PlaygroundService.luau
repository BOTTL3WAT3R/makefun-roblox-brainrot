-- PlaygroundService.luau (ModuleScript, ServerScriptService.Server)
-- Neon Shores -- the runtime behaviour for the Neon Playground (built by
-- WorldBuilder.buildPlayground): one Heartbeat loop rocks the swings, spins
-- the merry-go-round and tips the seesaw toward whoever stands on it, plus
-- the two touch/prompt interactions -- the bounce pad launch and the trash
-- can rummage by the Fuse Machine. Pure fun layer: the only money it touches
-- is the trash can's small once-a-minute find, paid through PlayerData.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerModules = ServerScriptService:WaitForChild("Server")
local PlayerData = require(ServerModules:WaitForChild("PlayerData"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))

local PlaygroundService = {}

local rng = Random.new()
local remotes: { [string]: RemoteEvent } = {}

function PlaygroundService.BindRemotes(remoteFolder: Folder)
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

-- Trash rummage: one find per player per minute, $25-$150 of other people's
-- junk, announced with a rotating joke. On cooldown the bin only has peels.
local TRASH_COOLDOWN_SECONDS = 60
local TRASH_MESSAGES = {
	"You found $%d in the trash!",
	"Someone threw away a fortune cookie: 'Fuse more.' (+$%d)",
	"Jackpot! A soggy $%d bill!",
	"A generous seagull dropped $%d into the bin. You take it. Obviously.",
	"Buried under banana peels: $%d in loose change!",
	"An unopened wallet! With exactly $%d inside. You keep it. Obviously.",
}
local trashReadyAt: { [number]: number } = {}

local function onTrashRummaged(player: Player)
	local state = PlayerData.GetState(player)
	if not state then
		return
	end
	local now = os.clock()
	if now < (trashReadyAt[player.UserId] or 0) then
		notifyPlayer(player, "Nothing but banana peels. Try again later.")
		return
	end
	trashReadyAt[player.UserId] = now + TRASH_COOLDOWN_SECONDS
	local reward = rng:NextInteger(25, 150)
	PlayerData.AddCash(state, reward)
	local template = TRASH_MESSAGES[rng:NextInteger(1, #TRASH_MESSAGES)]
	notifyPlayer(player, string.format(template, reward))
end

-- Seesaw: which end (if any) is being stood on. A player counts when their
-- root is over the plank's footprint (within 3 studs sideways, just above
-- the plank) and clearly on one half. Both ends stood on = level.
local function computeSeesawTarget(playground: any): number
	local pivot = playground.SeesawPivot
	local westStood, eastStood = false, false
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local rel = root.Position - pivot
			if math.abs(rel.Z) < 3 and rel.Y > 0 and rel.Y < 4.5 then
				if rel.X < -1.5 then
					westStood = true
				elseif rel.X > 1.5 then
					eastStood = true
				end
			end
		end
	end
	if westStood == eastStood then
		return 0
	end
	-- Rotating about Z by a positive angle lifts the +X (east) end and drops
	-- the west end, and vice versa: tip DOWN toward the stood-on side.
	return if westStood then math.rad(14) else -math.rad(14)
end

function PlaygroundService.Start()
	local playground = WorldBuilder.Playground
	if not playground then
		return
	end

	-- Bounce pad: stepping on the neon disc launches you skyward. Debounced
	-- per character so standing on it doesn't machine-gun the velocity.
	local lastBounceAt: { [Model]: number } = {}
	playground.BouncePad.Touched:Connect(function(hit: BasePart)
		if hit.Name ~= "HumanoidRootPart" then
			return
		end
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		if now - (lastBounceAt[character] or 0) < 0.6 then
			return
		end
		lastBounceAt[character] = now
		local velocity = hit.AssemblyLinearVelocity
		hit.AssemblyLinearVelocity = Vector3.new(velocity.X, 60, velocity.Z)
	end)

	-- Trash can: the prompt lives on the bin in Workspace; Triggered is
	-- server-side by design, no remote needed.
	playground.TrashPrompt.Triggered:Connect(onTrashRummaged)

	-- The motion loop: swings rock on offset sine phases around their bar
	-- pivots, the merry-go-round turns at a steady half-radian per second,
	-- and the seesaw eases toward the tilt its riders ask for (checked on a
	-- 0.1s throttle, eased every frame so it never snaps).
	local seesawAngle = 0
	local seesawTarget = 0
	local merryAngle = 0
	local checkAccumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = os.clock()
		for _, swing in ipairs(playground.Swings) do
			local angle = math.rad(18) * math.sin(now * 1.5 + swing.Phase)
			swing.Model:PivotTo(CFrame.new(swing.Pivot) * CFrame.Angles(angle, 0, 0))
		end
		merryAngle += 0.5 * deltaTime
		playground.MerryGoRound:PivotTo(CFrame.new(playground.MerryPivot) * CFrame.Angles(0, merryAngle, 0))
		checkAccumulator += deltaTime
		if checkAccumulator >= 0.1 then
			checkAccumulator = 0
			seesawTarget = computeSeesawTarget(playground)
		end
		seesawAngle += (seesawTarget - seesawAngle) * math.min(1, deltaTime * 6)
		playground.Seesaw:PivotTo(CFrame.new(playground.SeesawPivot) * CFrame.Angles(0, 0, seesawAngle))
	end)
end

return PlaygroundService
