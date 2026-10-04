-- JetpackModels: builds every jetpack tier from Parts (no meshes or images). Used by the server
-- (the jetpack strapped to each player's back) and the GUI (3D previews on the Jetpacks page).
--   Models.Build(tierId, {Flames = true})  -> anchored Model centred on the origin, tanks facing +Z
--   Models.Wear(tierId, torso)              -> Model welded to the back of the torso (not parented yet)
--   Models.SetThrust(model, on)             -> shows / hides the exhaust flames, particles and light
-- Higher tiers get more detail: fins (2+), antenna lights (3+), wings (4+), a second wing pair and a star (5).
local Config = require(script.Parent:WaitForChild("JetpackConfig"))

local Models = {}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local NOZZLE = Color3.fromRGB(70, 75, 95)
local FLAME_TRANSPARENCY = {Flame = 0.15, FlameCore = 0.05}

local function build(tier, opts)
	opts = opts or {}
	local s = opts.Scale or 1
	local c = tier.Colors
	local model = Instance.new("Model")
	model.Name = "Jetpack"
	model:SetAttribute("Tier", tier.Id)

	-- shape: "block", "ball" (ellipsoid) or "cyl" (upright cylinder, size = diameter, length)
	local function part(name, shape, sx, sy, sz, x, y, z, color, material, rotZ, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = material or Enum.Material.SmoothPlastic
		p.Color = color
		p.Transparency = transparency or 0
		local cf = CFrame.new(x * s, y * s, z * s) * CFrame.Angles(0, 0, math.rad(rotZ or 0))
		if shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(sy, sx, sx) * s
			cf = cf * CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is X; stand it up
		else
			p.Size = Vector3.new(sx, sy, sz) * s
			if shape == "ball" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
		p.CFrame = cf
		p.Parent = model
		return p
	end

	local i = tier.Index
	local metal = Enum.Material.Metal
	local neon = Enum.Material.Neon
	local back = part("Backplate", "block", 1.9, 2.2, 0.3, 0, 0, 0.1, c.Body)
	part("Spine", "block", 0.6, 1.8, 0.3, 0, 0, 0.35, c.Body:Lerp(BLACK, 0.25), metal)
	part("Core", "ball", 0.42, 0.42, 0.42, 0, 0.55, 0.62, c.Glow, neon)
	for _, side in ipairs({-1, 1}) do
		local x = 0.52 * side
		part("Tank", "cyl", 0.85, 2.0, 0, x, 0.05, 0.62, c.Tank)
		part("TankTop", "ball", 0.85, 0.55, 0.85, x, 1.05, 0.62, c.Tank:Lerp(WHITE, 0.25))
		part("TankBottom", "ball", 0.85, 0.45, 0.85, x, -0.95, 0.62, c.Tank:Lerp(BLACK, 0.2))
		part("Band", "cyl", 0.9, 0.14, 0, x, 0.45, 0.62, c.Glow, neon)
		local nozzle = part("Nozzle", "cyl", 0.55, 0.4, 0, x, -1.3, 0.62, NOZZLE, metal)
		part("NozzleGlow", "cyl", 0.38, 0.06, 0, x, -1.5, 0.62, c.Flame, neon)
		local visible = opts.Flames == true
		part("Flame", "ball", 0.5, 1.3, 0.5, x, -2.1, 0.62, c.Flame, neon, 0, visible and FLAME_TRANSPARENCY.Flame or 1)
		part("FlameCore", "ball", 0.28, 0.8, 0.28, x, -1.85, 0.62, c.Flame:Lerp(WHITE, 0.6), neon, 0,
			visible and FLAME_TRANSPARENCY.FlameCore or 1)
		if opts.Effects then
			local at = Instance.new("Attachment")
			at.Name = "ExhaustPoint"
			at.Parent = nozzle
			-- Upright (not turned with the cylinder) so the particles shoot straight down out of the nozzle
			at.WorldCFrame = CFrame.new(nozzle.Position - Vector3.new(0, 0.25 * s, 0))
			local e = Instance.new("ParticleEmitter")
			e.Name = "Exhaust"
			e.Texture = "rbxasset://textures/particles/fire_main.dds"
			e.Color = ColorSequence.new(c.Flame:Lerp(WHITE, 0.45), c.Flame)
			e.LightEmission = 1
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9 * s), NumberSequenceKeypoint.new(1, 0)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
			e.Lifetime = NumberRange.new(0.25, 0.45)
			e.Rate = 60 + i * 10
			e.Speed = NumberRange.new(18, 26)
			e.SpreadAngle = Vector2.new(8, 8)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Enabled = false
			e.Parent = at
		end
		if i >= 2 then -- fins + a second band
			part("Fin", "block", 0.12, 0.8, 0.55, 0.98 * side, -0.75, 0.62, c.Glow, nil, -15 * side)
			part("Band", "cyl", 0.9, 0.1, 0, x, -0.4, 0.62, c.Glow, neon)
		end
		if i >= 3 then -- antenna lights on the tank tops
			part("Antenna", "cyl", 0.12, 0.45, 0, x, 1.45, 0.62, NOZZLE, metal)
			part("AntennaLight", "ball", 0.22, 0.22, 0.22, x, 1.7, 0.62, c.Glow, neon)
		end
		if i >= 4 then -- wings that tilt upwards
			part("Wing", "block", 1.5, 0.6, 0.14, 1.6 * side, 0.8, 0.45, c.Tank, nil, 25 * side)
			part("WingTip", "block", 0.3, 0.66, 0.18, 2.27 * side, 1.12, 0.45, c.Glow, neon, 25 * side)
		end
		if i >= 5 then -- a smaller second pair of wings below
			part("Wing", "block", 1.0, 0.45, 0.12, 1.35 * side, -0.35, 0.45, c.Tank, nil, -20 * side)
			part("WingTip", "block", 0.24, 0.5, 0.16, 1.83 * side, -0.53, 0.45, c.Glow, neon, -20 * side)
		end
	end
	if i >= 5 then -- glowing 8-point star on the spine
		part("Star", "block", 0.5, 0.5, 0.12, 0, -0.35, 0.68, c.Glow, neon)
		part("Star", "block", 0.5, 0.5, 0.12, 0, -0.35, 0.68, c.Tank, neon, 45)
	end
	if opts.Effects then
		local light = Instance.new("PointLight")
		light.Name = "ExhaustLight"
		light.Color = c.Flame
		light.Range = 8
		light.Brightness = 1.2
		light.Enabled = false
		light.Parent = back
	end
	model.PrimaryPart = back
	return model
end

local function tierOf(id)
	return Config.ById[id] or Config.Tiers[1]
end

function Models.Build(id, opts)
	local model = build(tierOf(id), opts)
	local cf = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	model:PivotTo(CFrame.new())
	return model
end

function Models.Wear(id, torso)
	local s = math.clamp(torso.Size.X / 2, 0.4, 3) * 0.9
	local model = build(tierOf(id), {Scale = s, Effects = true})
	local back = model.PrimaryPart
	-- The model's origin sits on the torso's back (+Z); the backplate is 0.1 behind the origin.
	local weld = Instance.new("Weld")
	weld.Name = "JetpackWeld"
	weld.Part0 = torso
	weld.Part1 = back
	weld.C0 = CFrame.new(0, 0.05 * s, torso.Size.Z / 2 + 0.05 * s)
	weld.C1 = CFrame.new(0, 0, -0.1 * s)
	-- Move every part into place first: WeldConstraints keep the offsets the parts have when the
	-- model enters the workspace
	model:PivotTo(torso.CFrame * weld.C0 * weld.C1:Inverse())
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			if p ~= back then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = back
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	weld.Parent = back
	return model
end

function Models.SetThrust(model, on)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and FLAME_TRANSPARENCY[d.Name] then
			d.Transparency = on and FLAME_TRANSPARENCY[d.Name] or 1
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

return Models
