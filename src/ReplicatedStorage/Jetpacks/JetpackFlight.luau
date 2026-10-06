-- JetpackFlight (client only): flies the local player with their equipped jetpack. JetpackHUD's LAUNCH
-- button and launch keys (JetpackConfig.LaunchKey / LaunchGamepadButton) call Flight.Launch().
-- Launching only works while standing on a launch pad (inside a part tagged JetpackConfig.LaunchZoneTag).
-- 1. Boost: the launch carries the player halfway up to the tier's Ceiling, easing in and out.
-- 2. Flying: then they fly themselves, in any direction, at the tier's FlySpeed:
--      W/A/S/D (or the thumbstick) fly where the camera looks: look up and press W to climb
--      Space (or the jump button / gamepad A) goes straight up, Left Ctrl or Q (gamepad B) straight down
--      with nothing pressed the jetpack hovers in place
--    Speed changes blend smoothly, and the body leans into the way it's flying and banks into turns.
--    Nobody can fly above their tier's Ceiling.
-- 3. Landing: touching the ground (any planet, any floor) ends the flight; the cooldown starts then.
--   Flight.Launch()      -> ok, reason ("flying" | "cooldown" | "nopad" | "ceiling" | "nocharacter")
--   Flight.OnLaunchPad() -> true while the player stands on a launch pad
--   Flight.Cancel()      -> ends the current flight straight away (e.g. before teleporting)
--   Flight.Status()      -> state ("Ready" | "Thrust" | "Flying"), cooldown seconds left, cooldown length
--   Flight.Changed       -> fires with the new state whenever it changes
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local folder = script.Parent
local Config = require(folder:WaitForChild("JetpackConfig"))
local Models = require(folder:WaitForChild("JetpackModels"))
local player = Players.LocalPlayer

local BOOST_FRACTION = 0.5   -- the launch carries you this much of the way up to the ceiling
local SPOOL_UP = 0.45        -- seconds the launch takes to reach full speed
local RESPONSE = 3.2         -- how quickly flying speed follows the controls (higher = snappier)
local TURN_RESPONSE = 9      -- how quickly the body turns, leans and banks
local MAX_LEAN = math.rad(32) -- forward lean at full speed
local MAX_BANK = math.rad(24) -- sideways tilt when strafing at full speed
local HOVER_BOB = 0.9        -- studs/s of gentle up-and-down while hovering
local LAND_AFTER = 0.5       -- seconds of free flight before touching the ground counts as landing
local FOV_BOOST = 14         -- camera widens by up to this much at full speed
local LEVEL_TILT = math.rad(20) -- camera tilts smaller than this fly level
local UP_KEYS = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA}
local DOWN_KEYS = {Enum.KeyCode.LeftControl, Enum.KeyCode.Q, Enum.KeyCode.ButtonB}

local Flight = {}
local changed = Instance.new("BindableEvent")
Flight.Changed = changed.Event

local state = "Ready"
local cooldownEnds, cooldownLength = 0, 0
local flight -- the current flight, nil when on the ground
local jumpHeldUntil = 0 -- the mobile jump button only sends JumpRequest, so it counts as "up" briefly

local controls
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and module then controls = module:GetControls() end
end)
UserInputService.JumpRequest:Connect(function()
	if flight then jumpHeldUntil = os.clock() + 0.2 end
end)

local function setState(s)
	state = s
	changed:Fire(s)
end

local function anyDown(keys)
	if UserInputService:GetFocusedTextBox() then return false end
	for _, key in ipairs(keys) do
		if UserInputService:IsKeyDown(key) then return true end
	end
	for _, pad in ipairs({Enum.UserInputType.Gamepad1}) do
		for _, key in ipairs(keys) do
			if key.Name:find("Button") and UserInputService:IsGamepadButtonDown(pad, key) then return true end
		end
	end
	return false
end

-- The stick / WASD as a 3D direction from the camera, plus up and down
local function wantedDirection(f)
	local camera = workspace.CurrentCamera
	local move = controls and controls:GetMoveVector() or Vector3.zero
	if not controls then -- fall back on the humanoid's own idea of where we're walking
		local md = f.humanoid.MoveDirection
		if camera and md.Magnitude > 0 then
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0 then
				local right = camera.CFrame.RightVector
				move = Vector3.new(md:Dot(right), 0, -md:Dot(flatLook.Unit))
			end
		end
	end
	local dir = Vector3.zero
	if camera and move.Magnitude > 0.01 then
		-- Forward follows the camera's tilt, but small tilts count as level: the usual over-the-shoulder
		-- view looks a little down, and W shouldn't make you sink
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local pitch = math.asin(math.clamp(look.Y, -1, 1))
		local excess = math.max(0, math.abs(pitch) - LEVEL_TILT) / (math.pi / 2 - LEVEL_TILT) * (math.pi / 2)
		local tilt = math.sign(pitch) * excess
		local forward = flat * math.cos(tilt) + Vector3.yAxis * math.sin(tilt)
		dir = camera.CFrame.RightVector * move.X + forward * -move.Z
	end
	local vertical = 0
	if anyDown(UP_KEYS) or os.clock() < jumpHeldUntil then vertical += 1 end
	if anyDown(DOWN_KEYS) then vertical -= 1 end
	dir += Vector3.yAxis * vertical
	if dir.Magnitude > 1 then dir = dir.Unit end
	return dir
end

local function showFlames(f, on)
	local pack = f.character:FindFirstChild("Jetpack")
	if pack then Models.SetThrust(pack, on) end -- right away for this player; the server shows everyone else
	local remote = folder:FindFirstChild("JetpackThrust")
	if remote then remote:FireServer(on) end
end

-- Landed, died, respawned or cancelled
local function finish(f, landed)
	if flight ~= f then return end
	flight = nil
	f.conn:Disconnect()
	for _, obj in ipairs(f.objects) do obj:Destroy() end
	showFlames(f, false)
	local humanoid, root = f.humanoid, f.root
	if humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = f.autoRotate
		if landed then
			-- keep a little of the glide so the touchdown doesn't feel like a wall
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X * 0.35, math.min(v.Y, 0) * 0.2, v.Z * 0.35)
			humanoid:ChangeState(Enum.HumanoidStateType.Landed)
		else
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
	local camera = workspace.CurrentCamera
	if camera then f.restoreFov(camera) end
	cooldownLength = f.tier.Cooldown
	cooldownEnds = os.clock() + cooldownLength
	setState("Ready")
end

function Flight.Tier()
	return Config.Equipped(player)
end

function Flight.Status()
	return state, math.max(0, cooldownEnds - os.clock()), cooldownLength
end

-- A launch zone is a cylinder: diameter = the part's Size.X, height = its Size.Y
function Flight.OnLaunchPad()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, zone in ipairs(CollectionService:GetTagged(Config.LaunchZoneTag)) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			local p = zone.CFrame:PointToObjectSpace(root.Position)
			local r = zone.Size.X / 2
			if p.X * p.X + p.Z * p.Z <= r * r and math.abs(p.Y) <= zone.Size.Y / 2 then return true end
		end
	end
	return false
end

function Flight.Cancel()
	if flight then finish(flight, false) end
end

-- The ground under the player, within `reach` studs of their feet (ignoring themselves)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(f, reach)
	rayParams.FilterDescendantsInstances = {f.character}
	local legs = f.humanoid.HipHeight + f.root.Size.Y / 2
	local hit = workspace:Raycast(f.root.Position, Vector3.new(0, -(legs + reach), 0), rayParams)
	return hit ~= nil and hit.Instance.CanCollide
end

function Flight.Launch()
	if flight then return false, "flying" end
	if os.clock() < cooldownEnds then return false, "cooldown" end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then return false, "nocharacter" end
	if not Flight.OnLaunchPad() then return false, "nopad" end
	local tier = Config.Equipped(player)
	-- (The fallback only matters if the server couldn't find the planets)
	local ceiling = Config.Ceiling(tier) or root.Position.Y + 900 * tier.Index
	if root.Position.Y >= ceiling - 10 then return false, "ceiling" end
	if humanoid.Sit then humanoid.Sit = false end

	local camera = workspace.CurrentCamera
	local baseFov = camera and camera.FieldOfView or 70
	local f = {tier = tier, character = character, humanoid = humanoid, root = root, elapsed = 0,
		ceiling = ceiling, objects = {}, autoRotate = humanoid.AutoRotate,
		flySpeed = tier.FlySpeed or tier.AirSpeed * 2}
	f.boostTo = root.Position.Y + (ceiling - root.Position.Y) * BOOST_FRACTION
	f.restoreFov = function(cam)
		TweenService:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {FieldOfView = baseFov}):Play()
	end
	flight = f

	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChild("JetpackAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "JetpackAttachment"
		attachment.Parent = root
	end
	local mass = root.AssemblyMass
	local move = Instance.new("LinearVelocity")
	move.Name = "JetpackMove"
	move.Attachment0 = attachment
	move.RelativeTo = Enum.ActuatorRelativeTo.World
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	move.MaxForce = mass * workspace.Gravity * 40
	move.VectorVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	move.Parent = root
	local turn = Instance.new("AlignOrientation")
	turn.Name = "JetpackTurn"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.MaxTorque = mass * 4000
	turn.Responsiveness = TURN_RESPONSE * 4
	turn.CFrame = root.CFrame.Rotation
	turn.Parent = root
	f.objects = {move, turn}
	f.velocity = move.VectorVelocity

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true -- the jetpack moves the body now, not the legs
	showFlames(f, true)
	setState("Thrust")

	-- Facing: where the camera looks, flattened, so the player flies "into the screen"
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	f.conn = RunService.Heartbeat:Connect(function(dt)
		if flight ~= f then return end
		if not root.Parent or humanoid.Health <= 0 or player.Character ~= character then finish(f, false) return end
		dt = math.min(dt, 0.1)
		f.elapsed += dt
		local now = f.elapsed -- flight time, counted in frames so it's the same at any frame rate
		local y = root.Position.Y
		local cam = workspace.CurrentCamera
		local steer = wantedDirection(f)
		local target
		if state == "Thrust" then
			-- Ease in to full climb speed, then ease off as the halfway point gets close
			local t = now
			local spool = math.clamp(t / SPOOL_UP, 0, 1)
			spool = spool * spool * (3 - 2 * spool)
			local remaining = f.boostTo - y
			local climb = math.min(tier.Speed * spool, math.max(remaining * 2.2, f.flySpeed * 0.35))
			local side = Vector3.new(steer.X, 0, steer.Z) * f.flySpeed * 0.6 -- a little steering on the way up
			target = Vector3.new(side.X, climb, side.Z)
			if remaining <= 4 then
				f.flyingSince = now
				setState("Flying")
			end
			f.velocity = target -- the launch follows its own smooth curve
		else
			if steer.Magnitude > 0.01 then
				target = steer * f.flySpeed
			else
				target = Vector3.new(0, math.sin(now * 2.2) * HOVER_BOB, 0) -- hover in place
			end
			-- Never above the tier's ceiling: slow the climb near it, push back down above it
			local headroom = f.ceiling - y
			if headroom < 25 and target.Y > 0 then target = Vector3.new(target.X, target.Y * math.max(headroom, 0) / 25, target.Z) end
			if headroom < 0 then target = Vector3.new(target.X, math.max(headroom * 2, -f.flySpeed), target.Z) end
			local alpha = 1 - math.exp(-RESPONSE * dt)
			f.velocity = f.velocity:Lerp(target, alpha)
			-- Landing: the ground is right under our feet (or will be by the next frame) and we're not climbing
			if now - f.flyingSince > LAND_AFTER and f.velocity.Y < 1 then
				local reach = 0.8 + math.max(0, -f.velocity.Y) * dt * 2
				if groundBelow(f, reach) then finish(f, true) return end
			end
		end
		move.VectorVelocity = f.velocity

		-- Body: face the camera's direction, lean into forward speed, bank into sideways speed
		if cam then
			local look = cam.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.05 then facing = facing:Lerp(flatLook.Unit, 1 - math.exp(-TURN_RESPONSE * dt)) end
		end
		if facing.Magnitude > 0.01 then
			local face = CFrame.lookAt(Vector3.zero, facing.Unit)
			local local_ = face:VectorToObjectSpace(f.velocity)
			local forward = math.clamp(-local_.Z / f.flySpeed, -1, 1)
			local sideways = math.clamp(local_.X / f.flySpeed, -1, 1)
			turn.CFrame = face * CFrame.Angles(-forward * MAX_LEAN, 0, -sideways * MAX_BANK)
		end
		-- Camera opens up with speed
		if cam then
			local wantFov = baseFov + FOV_BOOST * math.clamp(f.velocity.Magnitude / math.max(f.flySpeed, tier.Speed * 0.5), 0, 1)
			cam.FieldOfView += (wantFov - cam.FieldOfView) * (1 - math.exp(-4 * dt))
		end
	end)
	return true
end

return Flight
