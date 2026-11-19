-- PlaygroundService.luau (ModuleScript, ServerScriptService.Server)
-- Candy Island -- the runtime behaviour for the Candy Playground (built by
-- WorldBuilder.buildPlayground): one Heartbeat loop rocks the swings, spins
-- the merry-go-round and tips the seesaw toward whoever stands on it, plus
-- the touch/prompt interactions -- the bounce pad launch, the trash can
-- rummage by the Fuse Machine, and the E-prompt sitting on every chair.
-- Pure fun layer: the only money it touches
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

	-- Bounce pads: a region check in the motion loop below, NOT a Touched
	-- event. The old Touched handler only accepted hits from a part named
	-- HumanoidRootPart, but a character standing or landing on the pad only
	-- ever touches it with its feet and legs -- the root part hovers about
	-- three studs above whatever the character stands on and never
	-- intersects the thin disc, so the launch was effectively dead code.
	-- The region check watches the root's position instead: over a disc
	-- (which fills its whole radius, so "within radius and airborne" always
	-- means above the pad) and at standing height above its top face. Every
	-- pad WorldBuilder planted (the playground original plus the arena, hill
	-- and machine-lane pads) is checked against every player; the per-player
	-- ready time is a plain timestamp shared across pads, so the debounce
	-- always expires on its own and can never strand a player unbounced.
	local bouncePads: { { Centre: Vector3, Radius: number, TopY: number } } = {}
	for _, pad in ipairs(playground.BouncePads or {}) do
		table.insert(bouncePads, {
			Centre = pad.Position,
			Radius = pad.Size.Y / 2,
			TopY = pad.Position.Y + pad.Size.X / 2,
		})
	end
	local bounceReadyAt: { [number]: number } = {}

	local function checkBouncePads(now: number)
		for _, player in ipairs(Players:GetPlayers()) do
			if now < (bounceReadyAt[player.UserId] or 0) then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				for _, pad in ipairs(bouncePads) do
					local relY = root.Position.Y - pad.TopY
					local dx = root.Position.X - pad.Centre.X
					local dz = root.Position.Z - pad.Centre.Z
					if relY > 2.4 and relY < 5 and dx * dx + dz * dz <= pad.Radius * pad.Radius then
						bounceReadyAt[player.UserId] = now + 0.5
						local velocity = root.AssemblyLinearVelocity
						root.AssemblyLinearVelocity = Vector3.new(velocity.X, 65, velocity.Z)
						break
					end
				end
			end
		end
	end

	-- Merry-go-round riders: the deck is anchored, so PivotTo gives it no
	-- surface velocity and friction alone leaves standing riders behind
	-- while the deck turns under them. Rotate every standing rider's root
	-- around the centre axis by the same delta angle instead (position and
	-- facing, Y preserved by the vertical axis). The moment a rider steps
	-- off the deck's radius or height band they are simply not rotated and
	-- walk away freely. Seated riders are skipped on purpose: their seat's
	-- weld already carries them with the pivoting model.
	local merryDeck = playground.MerryGoRound:FindFirstChild("Deck")
	local merryCentre = playground.MerryPivot
	local merryDeckTopY = if merryDeck then merryDeck.Position.Y + merryDeck.Size.X / 2 else 1.6
	local merryRadius = if merryDeck then merryDeck.Size.Y / 2 + 0.2 else 9.2

	local function carryMerryRiders(deltaAngle: number)
		local orbit = CFrame.new(merryCentre) * CFrame.Angles(0, deltaAngle, 0) * CFrame.new(-merryCentre)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not humanoid.Sit then
				local relY = root.Position.Y - merryDeckTopY
				local dx = root.Position.X - merryCentre.X
				local dz = root.Position.Z - merryCentre.Z
				if relY > 1.2 and relY < 4.4 and dx * dx + dz * dz <= merryRadius * merryRadius then
					root.CFrame = orbit * root.CFrame
				end
			end
		end
	end

	-- Trash can: the prompt lives on the bin in Workspace; Triggered is
	-- server-side by design, no remote needed.
	playground.TrashPrompt.Triggered:Connect(onTrashRummaged)

	-- Seat prompts: every chair (merry-go-round seats, swing seats, arena
	-- benches) carries a SitPrompt, because touch-sitting on the rides is
	-- flaky -- the deck and swings pivot every frame, so a walking touch
	-- rarely registers as a clean sit. The prompt sits the player by script
	-- instead: seat:Sit welds them exactly like a touch-sit would, so the
	-- merry-go-round's carry loop (which skips Humanoid.Sit riders) and the
	-- swings' rocking both carry a prompted sitter on the weld unchanged.
	-- Pressing E again while seated stands back up -- but clearing Sit
	-- alone does NOT work: a Seat auto-sits any character still touching
	-- its cushion, so the old "Sit = false + hop" dropped the player
	-- straight back onto the same chair and the engine welded them again
	-- in the same breath (E looked completely dead in playtests). Standing
	-- therefore DISMOUNTS: break the weld, switch the seat's touch-sit off
	-- for a moment (Seat.Disabled blocks the engine's auto-sit only --
	-- scripted Sit() still works, so an eager re-press of E is fine), and
	-- place the root a clear step in front of the chair using the seat's
	-- CURRENT world CFrame, which is right even on the turning
	-- merry-go-round and the rocking swings.
	local function standFromSeat(player: Player, seat: any, humanoid: Humanoid)
		humanoid.Sit = false
		seat.Disabled = true
		task.delay(1.5, function()
			seat.Disabled = false
		end)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local seatCFrame = seat.CFrame
			local landing = seatCFrame.Position + seatCFrame.LookVector * 3.5
			local target = Vector3.new(landing.X, seatCFrame.Position.Y + 3.2, landing.Z)
			root.CFrame = CFrame.lookAt(target, target + seatCFrame.LookVector)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	for _, seat in ipairs(playground.Seats or {}) do
		local sitPrompt = seat:FindFirstChild("SitPrompt")
		if sitPrompt and sitPrompt:IsA("ProximityPrompt") then
			sitPrompt.Triggered:Connect(function(player: Player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end
				-- "Seated in THIS seat" is tested both ways -- the seat's
				-- Occupant and the humanoid's own SeatPart. Either one
				-- naming this seat is enough: on the pivoting rides the
				-- pair can disagree for a frame, and a missed test is a
				-- dead E press.
				local occupant = seat.Occupant
				if occupant == humanoid or humanoid.SeatPart == seat then
					standFromSeat(player, seat, humanoid)
				elseif occupant == nil then
					if humanoid.SeatPart == nil then
						seat:Sit(humanoid)
					else
						notifyPlayer(player, "You are already sitting!")
					end
				else
					notifyPlayer(player, "Someone is sitting there!")
				end
			end)
		end
	end

	-- The motion loop: swings rock on offset sine phases around their bar
	-- pivots, the merry-go-round turns at a steady half-radian per second
	-- (carrying its standing riders with it), the bounce pad region check
	-- runs, and the seesaw eases toward the tilt its riders ask for
	-- (checked on a 0.1s throttle, eased every frame so it never snaps).
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
		local merryDelta = 0.5 * deltaTime
		merryAngle += merryDelta
		playground.MerryGoRound:PivotTo(CFrame.new(playground.MerryPivot) * CFrame.Angles(0, merryAngle, 0))
		carryMerryRiders(merryDelta)
		checkBouncePads(now)
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
