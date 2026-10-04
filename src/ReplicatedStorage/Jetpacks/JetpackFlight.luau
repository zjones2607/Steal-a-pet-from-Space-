-- JetpackFlight (client only): flies the local player with their equipped jetpack. SpaceGUI's LAUNCH
-- button and launch keys (JetpackConfig.LaunchKey / LaunchGamepadButton) call Flight.Launch().
-- Launching only works while standing on a launch pad (inside a part tagged JetpackConfig.LaunchZoneTag).
-- A launch climbs straight up at the tier's Speed until it reaches the tier's Ceiling (or runs out of
-- fuel) while the player steers sideways at the tier's AirSpeed. Once the boost runs out, full gravity
-- takes over and the player drops fast (up to MAX_FALL_SPEED) until they land. The cooldown starts
-- when the thrust ends.
--   Flight.Launch()      -> ok, reason ("flying" | "cooldown" | "nopad" | "ceiling" | "nocharacter")
--   Flight.OnLaunchPad() -> true while the player stands on a launch pad
--   Flight.Cancel()      -> ends the current flight straight away (e.g. before teleporting)
--   Flight.Status()      -> state ("Ready" | "Thrust" | "Falling"), cooldown seconds left, cooldown length
--   Flight.Changed       -> fires with the new state whenever it changes
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local folder = script.Parent
local Config = require(folder:WaitForChild("JetpackConfig"))
local Models = require(folder:WaitForChild("JetpackModels"))
local player = Players.LocalPlayer

local EXTRA_FUEL = 6      -- seconds of thrust beyond a straight climb, so players can steer around planets
local FOV_BOOST = 10      -- camera widens by this much while thrusting
local SPOOL_UP = 0.35     -- seconds to reach full climb speed
-- Fastest fall once the boost runs out. Uncapped, a drop from the top planet would hit ~1300 studs/s,
-- fast enough to punch through thin floors or outrun streaming.
local MAX_FALL_SPEED = 300

local Flight = {}
local changed = Instance.new("BindableEvent")
Flight.Changed = changed.Event

local state = "Ready"
local cooldownEnds, cooldownLength = 0, 0
local flight -- the current flight, nil when on the ground

local function setState(s)
	state = s
	changed:Fire(s)
end

local function tweenFov(fov, seconds)
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {FieldOfView = fov}):Play()
	end
end

local function showFlames(f, on)
	local pack = f.character:FindFirstChild("Jetpack")
	if pack then Models.SetThrust(pack, on) end -- right away for this player; the server shows everyone else
	local remote = folder:FindFirstChild("JetpackThrust")
	if remote then remote:FireServer(on) end
end

local function stopThrust(f)
	if not f.thrust then return end
	f.thrust:Destroy()
	f.thrust = nil
	showFlames(f, false)
	tweenFov(f.fov, 0.6)
	cooldownLength = f.tier.Cooldown
	cooldownEnds = os.clock() + cooldownLength
end

-- Landed, died or respawned
local function finish(f)
	if flight ~= f then return end
	flight = nil
	f.conn:Disconnect()
	stopThrust(f)
	-- Only undo our own speed change, in case something else set a new WalkSpeed mid-flight
	if f.humanoid.WalkSpeed == f.airSpeed then f.humanoid.WalkSpeed = f.walkSpeed end
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
	if flight then finish(flight) end
end

function Flight.Launch()
	if state == "Thrust" then return false, "flying" end
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

	local f = {tier = tier, character = character, humanoid = humanoid, root = root, started = os.clock()}
	local previous = flight
	if previous then -- launching again mid-fall: keep the speed and FOV from before the first launch
		previous.conn:Disconnect()
		f.walkSpeed, f.fov = previous.walkSpeed, previous.fov
	else
		f.walkSpeed = humanoid.WalkSpeed
		f.fov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
	end
	flight = f
	f.airSpeed = math.max(f.walkSpeed, tier.AirSpeed)
	humanoid.WalkSpeed = f.airSpeed
	f.ceiling = ceiling
	f.fuel = (ceiling - root.Position.Y) / tier.Speed + EXTRA_FUEL

	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChild("JetpackAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "JetpackAttachment"
		attachment.Parent = root
	end
	local thrust = Instance.new("LinearVelocity")
	thrust.Name = "JetpackThrust"
	thrust.Attachment0 = attachment
	thrust.RelativeTo = Enum.ActuatorRelativeTo.World
	thrust.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	thrust.LineDirection = Vector3.yAxis -- only pushes up, so the player can still steer sideways
	thrust.MaxForce = root.AssemblyMass * workspace.Gravity * 20
	thrust.LineVelocity = tier.Speed * 0.3
	thrust.Parent = root
	f.thrust = thrust
	if humanoid.FloorMaterial ~= Enum.Material.Air then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end

	showFlames(f, true)
	tweenFov(f.fov + FOV_BOOST, 0.5)
	setState("Thrust")
	f.conn = RunService.Heartbeat:Connect(function()
		if flight ~= f then return end
		if not root.Parent or humanoid.Health <= 0 or player.Character ~= character then finish(f) return end
		if f.thrust then
			local t = os.clock() - f.started
			local remaining = f.ceiling - root.Position.Y
			local speed = tier.Speed * math.min(1, 0.3 + 0.7 * t / SPOOL_UP)
			f.thrust.LineVelocity = math.min(speed, math.max(remaining * 3, 15)) -- ease off near the ceiling
			if remaining <= 3 or t >= f.fuel then
				stopThrust(f)
				f.fallStart = os.clock()
				setState("Falling")
			end
		else
			local v = root.AssemblyLinearVelocity
			if v.Y < -MAX_FALL_SPEED then root.AssemblyLinearVelocity = Vector3.new(v.X, -MAX_FALL_SPEED, v.Z) end
			if os.clock() - f.fallStart > 0.3 and humanoid.FloorMaterial ~= Enum.Material.Air then finish(f) end
		end
	end)
	return true
end

return Flight
