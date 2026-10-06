-- JetpackAnimations: makes jetpack flying look alive, for every flying player, on every device.
-- No animation files are needed: the arms, legs, body and head of R15 and R6 characters are posed by code
-- each frame (the Transform of each Motor6D, or of each AnimationConstraint on Roblox's newer R15
-- avatars, set after Roblox's own animations), and every joint follows its
-- target on a spring, so the poses flow into each other instead of snapping.
--   Launch    a quick crouch, then a straight-as-an-arrow push upward, arms pinned down, chin up
--   Flying    the limbs react to which way the player is moving, relative to their body:
--               forward: legs trail behind, arms sweep back (superhero dive)
--               backward: legs and arms swing forward to brake
--               sideways: legs swing out the other way, arms balance
--               up: legs hang straight, arms push down;  down: knees tuck, arms rise
--             hovering: legs dangle and paddle gently, arms float out
--   Landing   near the ground on the way down: legs reach for it and arms spread to balance;
--             on touchdown, a soft knee-bend and a puff of dust
-- Everyone sees each other's poses: the server sets the character attribute "JetpackFlying" (from
-- JetpackFlight's JetpackThrust messages). The local player's own flight is read straight from
-- JetpackFlight, so their animation starts with no delay.
-- Speed: white speed lines stream in and out around the edges of the screen when you fly fast (and
-- burst on launch). R6 characters have no elbows, knees or waist, so they get the rest of each pose.
-- Footstep sounds are muted while flying (Roblox's character sounds don't know about jetpacks).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local folder = ReplicatedStorage:WaitForChild("Jetpacks")
local Config = require(folder:WaitForChild("JetpackConfig"))
local Flight = require(folder:WaitForChild("JetpackFlight"))
local player = Players.LocalPlayer

local SPRING = 10            -- how quickly joints follow their pose (higher = snappier)
local LAUNCH_CROUCH = 0.22   -- seconds of crouch at the start of a launch
local LAUNCH_PUSH = 0.9      -- seconds of the straight push pose after it
local LAND_REACH = 16        -- studs above the ground where the legs start reaching for it
local TOUCHDOWN = 0.4        -- seconds of knee-bend after landing
local STREAK_SPEED = 0.55    -- share of top speed where the speed lines start
local MAX_LINES = 26

-- R6 joints live in the Torso and are turned 90 degrees, so each one needs its own conversion from
-- (x = swing forward, z = swing out to the right) into its own axes
local R6_JOINTS = {
	["Left Shoulder"] = {name = "LeftShoulder", convert = function(x, z) return CFrame.Angles(z, 0, -x) end},
	["Right Shoulder"] = {name = "RightShoulder", convert = function(x, z) return CFrame.Angles(-z, 0, x) end},
	["Left Hip"] = {name = "LeftHip", convert = function(x, z) return CFrame.Angles(z, 0, -x) end},
	["Right Hip"] = {name = "RightHip", convert = function(x, z) return CFrame.Angles(-z, 0, x) end},
	["Neck"] = {name = "Neck", convert = function(x) return CFrame.Angles(-x, 0, 0) end},
}
local function r15Convert(x, z) return CFrame.Angles(x, 0, z) end
local R15_JOINTS = {
	Waist = "UpperTorso", Neck = "Head",
	LeftShoulder = "LeftUpperArm", RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm", RightElbow = "RightLowerArm",
	LeftHip = "LeftUpperLeg", RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg", RightKnee = "RightLowerLeg",
}

local function new(class, parent, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(x) return math.clamp(x, 0, 1) end

----------------------------------------------------------------------------
-- Effects in the world: dust rings
----------------------------------------------------------------------------
local effects = new("Folder", workspace, {Name = "JetpackEffects"})
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- A ring of smoke/dust spreading out flat on the ground
local function dustRing(position, color, size)
	local ring = new("Part", effects, {Name = "Dust", Shape = Enum.PartType.Cylinder, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic,
		Color = color, Transparency = 0.35, Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)})
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, {Size = Vector3.new(0.15, size, size), Transparency = 1}):Play()
	task.delay(0.65, function() ring:Destroy() end)
end

----------------------------------------------------------------------------
-- Each character that flies gets a record: its joints, springs and streaks
----------------------------------------------------------------------------
local riders = {} -- [character] = rider

-- A joint that can be posed: the classic Motor6D, or the AnimationConstraint that Roblox's newer
-- R15 avatars use instead (both have a Transform). Looked up by name in its usual part first, then
-- anywhere in the character.
local function findJoint(character, partName, jointName)
	local part = partName and character:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	if not joint or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		joint = nil
		for _, d in ipairs(character:GetDescendants()) do
			if d.Name == jointName and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then joint = d break end
		end
	end
	return joint
end

local function riderFor(character)
	local rider = riders[character]
	if rider then return rider end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root then return nil end
	rider = {character = character, humanoid = humanoid, root = root, joints = {}, angles = {}, targets = {},
		flying = false, since = 0, landedAt = nil, convert = {}, muted = {}}
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		for joint, partName in pairs(R15_JOINTS) do
			local motor = findJoint(character, partName, joint)
			if motor then
				rider.joints[joint] = motor
				rider.convert[joint] = r15Convert
				rider.angles[joint] = {x = 0, z = 0}
			end
		end
	else
		for motorName, j in pairs(R6_JOINTS) do
			local motor = findJoint(character, "Torso", motorName)
			if motor then
				rider.joints[j.name] = motor
				rider.convert[j.name] = j.convert
				rider.angles[j.name] = {x = 0, z = 0}
			end
		end
	end
	if next(rider.joints) == nil then
		warn(("JetpackAnimations: found no arm/leg joints to animate on %s (rig %s)"):format(character.Name,
			tostring(humanoid.RigType)))
	end
	riders[character] = rider
	return rider
end

-- Roblox plays footstep (and climbing/swimming) sounds from the root part; silence them in the air
local QUIET = {"Running", "Climbing", "Swimming"}
local function muteSounds(rider, on)
	if on then
		for _, name in ipairs(QUIET) do
			local sound = rider.root:FindFirstChild(name)
			if sound and sound:IsA("Sound") then
				if rider.muted[sound] == nil then rider.muted[sound] = sound.Volume end
				if sound.Volume ~= 0 then sound.Volume = 0 end
			end
		end
	else
		for sound, volume in pairs(rider.muted) do
			if sound.Parent then sound.Volume = volume end
		end
		table.clear(rider.muted)
	end
end

----------------------------------------------------------------------------
-- The pose: target angles (radians) for each joint. x swings a limb forward (+) / back (-) and
-- bends elbows forward (+) and knees back (-); z swings a limb out to the side (left -, right +).
----------------------------------------------------------------------------
local function poseFor(rider, info, t)
	local P = {}
	local function set(joint, x, z) P[joint] = {x = x, z = z or 0} end
	-- Hover: dangling legs that paddle a little, arms floating out
	local paddle = math.sin(t * 2.4) * 0.12
	set("LeftHip", 0.12 + paddle, -0.06); set("RightHip", 0.12 - paddle, 0.06)
	set("LeftKnee", -0.35 - paddle * 0.5); set("RightKnee", -0.35 + paddle * 0.5)
	set("LeftShoulder", 0.1, -0.35 - math.sin(t * 1.7) * 0.05); set("RightShoulder", 0.1, 0.35 + math.sin(t * 1.7) * 0.05)
	set("LeftElbow", 0.35); set("RightElbow", 0.35)
	set("Waist", 0); set("Neck", 0)

	local fwd, side, up = info.forward, info.side, info.up
	local function add(joint, x, z)
		local p = P[joint]
		p.x += x; p.z += (z or 0)
	end
	-- Forward: superhero dive.  Backward: brake.
	if fwd > 0 then
		add("LeftHip", -0.55 * fwd); add("RightHip", -0.55 * fwd)
		add("LeftKnee", 0.15 * fwd); add("RightKnee", 0.15 * fwd)
		add("LeftShoulder", -0.75 * fwd, 0.15 * fwd); add("RightShoulder", -0.75 * fwd, -0.15 * fwd)
		add("LeftElbow", -0.25 * fwd); add("RightElbow", -0.25 * fwd)
		add("Neck", 0.4 * fwd); add("Waist", 0.1 * fwd)
	else
		local b = -fwd
		add("LeftHip", 0.55 * b); add("RightHip", 0.45 * b)
		add("LeftKnee", -0.35 * b); add("RightKnee", -0.45 * b)
		add("LeftShoulder", 0.75 * b, -0.2 * b); add("RightShoulder", 0.75 * b, 0.2 * b)
		add("Waist", -0.12 * b)
	end
	-- Sideways: legs swing out the other way, the leading arm reaches out
	add("LeftHip", 0, -0.35 * side); add("RightHip", 0, -0.35 * side)
	add("LeftShoulder", 0, -0.45 * math.max(-side, 0)); add("RightShoulder", 0, 0.45 * math.max(side, 0))
	add("Waist", 0, -0.08 * side)
	-- Up: legs straight, arms push down.  Down: knees tuck, arms rise.
	if up > 0 then
		add("LeftKnee", 0.25 * up); add("RightKnee", 0.25 * up)
		add("LeftShoulder", -0.25 * up, 0.25 * up); add("RightShoulder", -0.25 * up, -0.25 * up)
		add("Neck", 0.3 * up)
	else
		local d = -up
		add("LeftHip", 0.55 * d); add("RightHip", 0.55 * d)
		add("LeftKnee", -0.85 * d); add("RightKnee", -0.85 * d)
		add("LeftShoulder", 0.25 * d, -0.55 * d); add("RightShoulder", 0.25 * d, 0.55 * d)
		add("Neck", -0.15 * d)
	end
	-- Out of fuel: a bit of flailing
	if info.empty then
		local flail = math.sin(t * 9) * 0.35
		add("LeftShoulder", flail, -0.3); add("RightShoulder", -flail, 0.3)
		add("LeftHip", -flail * 0.4); add("RightHip", flail * 0.4)
	end

	-- Launch: crouch, then stretch out straight like a rocket
	local launch = info.launchTime
	if launch then
		local crouch = launch < LAUNCH_CROUCH and math.sin(launch / LAUNCH_CROUCH * math.pi / 2) or 0
		local push = launch >= LAUNCH_CROUCH and (1 - clamp01((launch - LAUNCH_CROUCH) / LAUNCH_PUSH)) or 0
		push = push * push * (3 - 2 * push) -- eases out of the rocket pose into the climbing one
		local w = math.max(crouch, push)
		local function blend(joint, x, z)
			local p = P[joint]
			p.x = lerp(p.x, x, w); p.z = lerp(p.z, z or 0, w)
		end
		if crouch > 0 then
			blend("LeftHip", 0.9, -0.1); blend("RightHip", 0.9, 0.1)
			blend("LeftKnee", -1.4); blend("RightKnee", -1.4)
			blend("LeftShoulder", -0.5, -0.3); blend("RightShoulder", -0.5, 0.3)
			blend("Waist", -0.25); blend("Neck", 0.1)
		else
			blend("LeftHip", -0.05, 0.03); blend("RightHip", -0.05, -0.03)
			blend("LeftKnee", -0.05); blend("RightKnee", -0.05)
			blend("LeftShoulder", -0.15, -0.1); blend("RightShoulder", -0.15, 0.1)
			blend("LeftElbow", 0.05); blend("RightElbow", 0.05)
			blend("Waist", 0.08); blend("Neck", 0.45)
		end
	end
	-- About to land: legs reach for the ground, arms spread for balance
	local reach = info.landing
	if reach > 0 then
		local function blend(joint, x, z)
			local p = P[joint]
			p.x = lerp(p.x, x, reach); p.z = lerp(p.z, z or 0, reach)
		end
		blend("LeftHip", 0.25, -0.12); blend("RightHip", 0.25, 0.12)
		blend("LeftKnee", -0.45); blend("RightKnee", -0.45)
		blend("LeftShoulder", 0.3, -0.85); blend("RightShoulder", 0.3, 0.85)
		blend("LeftElbow", 0.2); blend("RightElbow", 0.2)
		blend("Neck", -0.2); blend("Waist", -0.05)
	end
	return P
end

-- After touchdown: a soft knee-bend that springs back up
local function touchdownPose(k)
	local bend = math.sin(k * math.pi) -- 0 -> 1 -> 0
	return {
		LeftHip = {x = 0.7 * bend, z = -0.08}, RightHip = {x = 0.7 * bend, z = 0.08},
		LeftKnee = {x = -1.2 * bend, z = 0}, RightKnee = {x = -1.2 * bend, z = 0},
		LeftShoulder = {x = 0.2 * bend, z = -0.6 * bend}, RightShoulder = {x = 0.2 * bend, z = 0.6 * bend},
		LeftElbow = {x = 0.3 * bend, z = 0}, RightElbow = {x = 0.3 * bend, z = 0},
		Waist = {x = -0.25 * bend, z = 0}, Neck = {x = 0.1 * bend, z = 0},
	}
end

----------------------------------------------------------------------------
-- Speed lines (this player only): thin white streaks around the screen edges
----------------------------------------------------------------------------
local lineGui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "JetpackSpeedLines", IgnoreGuiInset = true,
	ResetOnSpawn = false, DisplayOrder = 5})
local lineRoot = new("Frame", lineGui, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)})
local lines = {}
for i = 1, MAX_LINES do
	local f = new("Frame", lineRoot, {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, BackgroundTransparency = 1, Visible = false})
	new("UICorner", f, {CornerRadius = UDim.new(1, 0)})
	new("UIGradient", f, {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0), NumberSequenceKeypoint.new(1, 0.6)})})
	lines[i] = {frame = f, life = 0, age = 1, angle = 0, from = 0, to = 0, length = 0, width = 2}
end
local lineIntensity, spawnDebt = 0, 0
local function spawnLine(line, size)
	local diag = math.sqrt(size.X * size.X + size.Y * size.Y) / 2
	line.angle = math.random() * math.pi * 2
	line.from = diag * (0.5 + math.random() * 0.25)
	line.to = line.from + diag * (0.15 + math.random() * 0.2) * (math.random() < 0.5 and -1 or 1) -- in or out
	line.length = diag * (0.12 + math.random() * 0.18)
	line.width = 1.5 + math.random() * 2
	line.life = 0.22 + math.random() * 0.2
	line.age = 0
	line.frame.Visible = true
	line.frame.Rotation = math.deg(line.angle)
end
local function updateLines(dt)
	local size = lineRoot.AbsoluteSize
	if size.X < 10 then return end
	spawnDebt += dt * lineIntensity * 70
	for _, line in ipairs(lines) do
		if line.age >= line.life then
			if spawnDebt >= 1 then
				spawnDebt -= 1
				spawnLine(line, size)
			elseif line.frame.Visible then
				line.frame.Visible = false
			end
		end
		if line.age < line.life then
			line.age += dt
			local k = clamp01(line.age / line.life)
			local r = lerp(line.from, line.to, k)
			local cx, cy = size.X / 2 + math.cos(line.angle) * r, size.Y / 2 + math.sin(line.angle) * r
			line.frame.Position = UDim2.fromOffset(cx, cy)
			line.frame.Size = UDim2.fromOffset(line.length * (0.6 + 0.4 * math.sin(k * math.pi)), line.width)
			line.frame.BackgroundTransparency = 1 - math.sin(k * math.pi) * (0.25 + 0.55 * lineIntensity)
		end
	end
	spawnDebt = math.min(spawnDebt, MAX_LINES)
end

----------------------------------------------------------------------------
-- Every frame
----------------------------------------------------------------------------
local clock = 0
local function speedRefFor(character)
	local owner = Players:GetPlayerFromCharacter(character)
	local tier = owner and Config.ById[owner:GetAttribute(Config.EquippedAttribute)] or Config.Tiers[1]
	return tier.FlySpeed or 80, tier.Speed or 140
end

-- PreSimulation runs after Roblox's own animations each frame, so the pose set here is what shows
RunService.PreSimulation:Connect(function(dt)
	dt = math.min(dt, 0.1)
	clock += dt
	local alpha = 1 - math.exp(-SPRING * dt)
	local mine = player.Character
	local myInfo = Flight.Info()
	local myIntensity = 0

	-- Who is flying: everyone the server marked, plus ourselves straight away
	local active = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if character and (character:GetAttribute("JetpackFlying") or (character == mine and myInfo)) then
			active[character] = true
		end
	end
	if mine and not myInfo then active[mine] = nil end -- our own landing counts the moment it happens

	for character in pairs(active) do riderFor(character) end
	for character, rider in pairs(riders) do
		local flying = active[character] == true and character.Parent ~= nil and rider.humanoid.Health > 0
		if flying and not rider.flying then
			rider.flying, rider.since, rider.landedAt = true, clock, nil
			dustRing(rider.root.Position - Vector3.new(0, rider.humanoid.HipHeight + rider.root.Size.Y / 2, 0),
				Color3.fromRGB(235, 235, 245), 18)
		elseif not flying and rider.flying then
			rider.flying = false
			muteSounds(rider, false)
			if character.Parent and rider.humanoid.Health > 0 then
				rider.landedAt = clock
				dustRing(rider.root.Position - Vector3.new(0, rider.humanoid.HipHeight + rider.root.Size.Y / 2, 0),
					Color3.fromRGB(205, 190, 160), 12)
			end
		end

		local pose
		if rider.flying then
			local root = rider.root
			local flySpeed, launchSpeed = speedRefFor(character)
			local info = {empty = false}
			local launchTime
			if character == mine and myInfo then
				flySpeed, launchSpeed = myInfo.flySpeed, myInfo.launchSpeed
				info.empty = myInfo.empty
				if myInfo.state == "Thrust" then launchTime = myInfo.elapsed end
			elseif clock - rider.since < LAUNCH_CROUCH + LAUNCH_PUSH then
				launchTime = clock - rider.since
			end
			info.launchTime = launchTime
			local v = root.AssemblyLinearVelocity
			local lv = root.CFrame:VectorToObjectSpace(v) / flySpeed
			info.forward = math.clamp(-lv.Z, -1, 1)
			info.side = math.clamp(lv.X, -1, 1)
			info.up = math.clamp(v.Y / flySpeed, -1, 1)
			-- Near the ground on the way down: get ready to land
			info.landing = 0
			if v.Y < 2 and not launchTime then
				rayParams.FilterDescendantsInstances = {character, effects}
				local legs = rider.humanoid.HipHeight + root.Size.Y / 2
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -(legs + LAND_REACH), 0), rayParams)
				if hit then info.landing = clamp01(1 - (root.Position.Y - legs - hit.Position.Y) / LAND_REACH) end
			end
			pose = poseFor(rider, info, clock + (rider.since % 7))
			muteSounds(rider, true)
			local speed = v.Magnitude
			if character == mine then
				local ref = launchTime and launchSpeed or flySpeed
				myIntensity = clamp01((speed / ref - STREAK_SPEED) / (1 - STREAK_SPEED))
				if launchTime and launchTime > LAUNCH_CROUCH then myIntensity = math.max(myIntensity, 0.6) end
			end
		elseif rider.landedAt and clock - rider.landedAt < TOUCHDOWN then
			pose = touchdownPose((clock - rider.landedAt) / TOUCHDOWN)
		end

		if pose then
			for joint, motor in pairs(rider.joints) do
				local target = pose[joint] or {x = 0, z = 0}
				local a = rider.angles[joint]
				a.x += (target.x - a.x) * alpha
				a.z += (target.z - a.z) * alpha
				if motor.Parent then motor.Transform = rider.convert[joint](a.x, a.z) end
			end
		else
			-- Done: let the normal animations take over, and forget this rider until it flies again
			for _, a in pairs(rider.angles) do a.x, a.z = 0, 0 end
			riders[character] = nil
		end
	end

	lineIntensity += (myIntensity - lineIntensity) * (1 - math.exp(-6 * dt))
	updateLines(dt)
end)

Players.PlayerRemoving:Connect(function(leaving)
	local character = leaving.Character
	if character and riders[character] then muteSounds(riders[character], false); riders[character] = nil end
end)
