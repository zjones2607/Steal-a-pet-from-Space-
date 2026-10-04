-- RideARocketLaunchSiteBuilder: swaps the satellite on every base (StationPlotN.Core.SS_*) for a
-- jetpack launch site of about the same size. Run from the command bar in Edit mode:
--   require(game.ServerStorage.RideARocketLaunchSiteBuilder).Apply()
-- The satellite parts are moved (not deleted) to ServerStorage.RemovedMapBackups.Satellites_BeforeLaunchSites.
-- If you re-run RideARocketBaseBuilder, run this again afterwards.
--
-- Running it again rebuilds every launch site from scratch (the satellites stay in the backup), so
-- design changes here only need another Apply(). Metal finishes from RideARocketMapDetailer carry over
-- to the rebuilt parts (new kinds of part keep the look they're built with).
--
-- Each site has an invisible part named "LaunchZone" tagged "LaunchZone". Jetpacks can only launch
-- while the player stands inside one (a cylinder: diameter = Size.X, height = Size.Y), and the base
-- teleport drops players at its "SpawnPoint" attachment. The site keeps clear of the four pet pods.
-- The "LAUNCH PAD" sign on the gantry is styled like the menus: a pill-shaped board with a glowing rim
-- and marquee bulbs, and a painted face (SurfaceGui) with a rocket, the title in gold and up-chevrons.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local M = {}
M.ZoneTag = "LaunchZone"

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local SP, NEON, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.DiamondPlate
-- Same palette as RideARocketBaseBuilder, plus the orange of the LAUNCH button and, for the sign, the
-- menus' (SpaceGUI) ink outline, cyan rim and gold text
local C = {
	white = rgb(240, 243, 248), light = rgb(200, 206, 216), metal = rgb(165, 172, 186), grey = rgb(140, 147, 162),
	dark = rgb(75, 80, 95), navy = rgb(28, 38, 74), navy2 = rgb(40, 55, 100), blue = rgb(70, 160, 255),
	glow = rgb(160, 215, 255), orange = rgb(255, 115, 20), red = rgb(255, 60, 60),
	ink = rgb(3, 8, 30), cyan = rgb(8, 197, 248), board = rgb(14, 32, 92), gold = rgb(255, 218, 52), goldDeep = rgb(240, 150, 20),
}
-- Kit pieces used here: size and offset as fractions of the scale (same table format as the base builder)
local B = {
	Tank_Body = {1.4, 0.64, 0.6303, 0, 0.46, 0}, Tank_Bands = {0.8, 0.66, 0.65, 0, 0.46, 0},
	Tank_Saddle = {0.84, 0.24, 0.54, 0, 0.12, 0}, PlanetRing_Band = {1, 1, 1, 0, 0, 0},
}

local PLATFORM_D = 15   -- launch pad diameter (the LaunchZone matches it)
local ZONE_H = 12       -- how far above the pad still counts as standing on it
local TOWER_Z = 12.3    -- gantry centre, behind the pad (far enough back that the sign stays outside the LaunchZone)
local TOWER_W = 7
local TOWER_H = 30
local ARM_Z = 3         -- the service arms reach out over the back of the pad to here
local SIGN_W = 15       -- "LAUNCH PAD" sign on the gantry's front pillars, centred SIGN_Y above the pad:
local SIGN_H = 4.4      --   the title is above the head of anyone standing on the pad, the sign hides the
local SIGN_Y = 7.5      --   brace behind it at height 9, and it stays well below the service arms (12)
local SIGN_PPS = 50     -- resolution of the sign's painted face (SurfaceGui pixels per stud)
local RING_D = 47       -- big ring, about the satellite's width
local RING_Y = 14
local HALO_D = 17
local HALO_Y = 26

local function part(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = opts.mat or SP
	p.Shape = opts.shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = opts.shadow == true
	p.Transparency = opts.transparency or 0
	p.CanTouch = false
	if opts.decor then p.CanCollide = false; p.CanQuery = false end
	p.Parent = parent
	return p
end
-- Upright cylinder centred on cf
local function cyl(parent, name, diameter, height, cf, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, opts)
end
-- A map-kit mesh, placed the same way RideARocketBaseBuilder does
local function kitPiece(parent, name, scale, cf, color, opts)
	opts = opts or {}
	local kit = ServerStorage:WaitForChild("RideARocket_MapKit")
	local b = B[name]
	local p = kit[name]:Clone()
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	p.Name = opts.name or name
	p.Size = opts.size or Vector3.new(b[1], b[2], b[3]) * scale
	p.CFrame = cf * CFrame.new(b[4] * scale, b[5] * scale, b[6] * scale) * CFrame.Angles(0, math.pi, 0)
	p.Anchored = true
	p.Color = color
	p.Material = opts.mat or SP
	p.Transparency = opts.transparency or 0
	p.CastShadow = opts.shadow == true
	p.CanTouch = false
	if opts.decor then p.CanCollide = false; p.CanQuery = false end
	pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
	p.Parent = parent
	return p
end
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
-- A flat pill (a box with round ends) w wide and h tall, its face towards -Z, centred on cf
local function pill(parent, name, w, h, depth, cf, color, opts)
	local mid = part(parent, name, Vector3.new(w - h, h, depth), cf, color, opts)
	local capOpts = table.clone(opts)
	capOpts.shape = Enum.PartType.Cylinder
	for _, side in ipairs({-1, 1}) do
		part(parent, name, Vector3.new(depth, h, h), cf * CFrame.new(side * (w - h) / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			color, capOpts)
	end
	return mid
end

-- GUI pieces for the sign's painted face, in the same style as SpaceGUI and SpaceIcons
local function ui(class, parent, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return ui("UICorner", o, {CornerRadius = UDim.new(r or 0.5, 0)}) end
local function vgrad(o, top, bottom) return ui("UIGradient", o, {Color = ColorSequence.new(top, bottom), Rotation = 90}) end
local function ink(o, px) return ui("UIStroke", o, {Color = C.ink, Thickness = px, LineJoinMode = Enum.LineJoinMode.Round}) end
-- A square box `size` studs wide, centred x, y studs from the top-left of `parent`, to draw an icon in
local function iconBox(parent, x, y, size, z, rot)
	return ui("Frame", parent, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x * SIGN_PPS, y * SIGN_PPS),
		Size = UDim2.fromOffset(size * SIGN_PPS, size * SIGN_PPS), BackgroundTransparency = 1, Rotation = rot or 0, ZIndex = z})
end
-- One rounded shape in an icon box: centre and size as fractions of the box. c2 = bottom colour of a
-- top-to-bottom gradient. o.ink = outline in pixels, o.rot = rotation, o.r = corner radius, o.z = layer.
local function shape(box, cx, cy, w, h, c1, c2, o)
	o = o or {}
	local f = ui("Frame", box, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromScale(w, h),
		BackgroundColor3 = c2 and Color3.new(1, 1, 1) or c1, BackgroundTransparency = o.t or 0, BorderSizePixel = 0,
		Rotation = o.rot or 0, ZIndex = o.z or 1})
	corner(f, o.r)
	if c2 then vgrad(f, c1, c2) end
	if o.ink then ink(f, o.ink) end
	return f
end
-- The menus' cartoon rocket (same shapes as SpaceIcons' Rocket): white body, red nose and fins, blue window, orange flame
local function drawRocket(parent, x, y, size, z)
	local box = iconBox(parent, x, y, size, z, 40)
	local px = size * SIGN_PPS * 0.05
	shape(box, 0.5, 0.9, 0.2, 0.3, rgb(255, 235, 100), rgb(255, 110, 30), {z = 1})
	shape(box, 0.5, 0.85, 0.1, 0.16, rgb(255, 255, 225), nil, {z = 2})
	shape(box, 0.3, 0.68, 0.2, 0.3, rgb(255, 100, 100), rgb(190, 30, 50), {rot = 18, r = 0.35, ink = px, z = 3})
	shape(box, 0.7, 0.68, 0.2, 0.3, rgb(255, 100, 100), rgb(190, 30, 50), {rot = -18, r = 0.35, ink = px, z = 3})
	shape(box, 0.5, 0.5, 0.34, 0.66, rgb(255, 255, 255), rgb(185, 200, 232), {ink = px, z = 4})
	shape(box, 0.5, 0.2, 0.28, 0.26, rgb(255, 110, 110), rgb(200, 30, 55), {ink = px, z = 5})
	shape(box, 0.5, 0.46, 0.18, 0.18, rgb(130, 240, 255), rgb(20, 130, 230), {ink = px, z = 6})
	shape(box, 0.47, 0.42, 0.05, 0.05, rgb(255, 255, 255), nil, {t = 0.2, z = 7})
end
-- Three stacked up-chevrons, gold at the top fading to orange. Each is two rounded bars meeting at the
-- top; the dark outline is a slightly bigger layer underneath, so the bars join without a seam.
local function drawChevrons(parent, x, y, size, z)
	local box = iconBox(parent, x, y, size, z)
	local arm, thick, edge, gap = 0.4, 0.11, 0.04, 0.26 -- fractions of the box
	local colors = {{rgb(255, 248, 170), C.gold}, {rgb(255, 196, 60), rgb(250, 140, 25)}, {rgb(255, 150, 40), rgb(235, 90, 15)}}
	local reach = (arm - thick) * math.sqrt(0.5) -- how far each bar's far end sits from the tip, across and down
	local first = 0.5 - (2 * gap + reach) / 2
	for k = 1, 3 do
		local tipY = first + (k - 1) * gap
		for _, side in ipairs({-1, 1}) do
			local cx, cy = 0.5 + side * reach / 2, tipY + reach / 2
			shape(box, cx, cy, arm + 2 * edge, thick + 2 * edge, C.ink, nil, {rot = side * 45, z = 1})
			shape(box, cx, cy, arm, thick, colors[k][1], colors[k][2], {rot = side * 45, z = 2})
		end
	end
end
-- A small eight-point star like the menus' Star icon: two rounded squares over a dark outline layer
local function drawStar(parent, x, y, size, z)
	local box = iconBox(parent, x, y, size, z)
	for _, rot in ipairs({0, 45}) do shape(box, 0.5, 0.5, 0.72, 0.72, C.ink, nil, {rot = rot, r = 0.16, z = 1}) end
	for _, rot in ipairs({0, 45}) do shape(box, 0.5, 0.5, 0.56, 0.56, rgb(255, 240, 130), C.gold, {rot = rot, r = 0.14, z = 2}) end
end

-- The "LAUNCH PAD" sign: a pill-shaped board (dark outline, glowing cyan rim, navy border lined with
-- gold/orange marquee bulbs) with a painted face: a navy-to-blue panel with a rocket, the title in gold
-- with a thick dark outline, a subtitle and up-chevrons. cf = centre of the board's back, -Z facing the
-- pad. Everything is decoration: nothing to bump into, and the camera doesn't snag on it.
local function buildSign(parent, cf)
	local sign = model("LaunchPadSign", parent)
	local function layer(z) return cf * CFrame.new(0, 0, -z) end -- z studs out from the board's back
	local w, h = SIGN_W, SIGN_H
	pill(sign, "SignBacking", w, h, 0.3, layer(0.15), C.ink, {decor = true, shadow = true})
	pill(sign, "SignRim", w - 0.24, h - 0.24, 0.1, layer(0.31), C.cyan, {decor = true, mat = NEON})
	pill(sign, "SignBorder", w - 0.56, h - 0.56, 0.1, layer(0.37), C.board, {decor = true})

	-- Marquee bulbs round the border, starting at the top middle. An even count, so the colours
	-- alternate all the way round and the two halves mirror each other.
	local half, r = (w - h) / 2, (h - 0.56) / 2 - 0.22
	local arc = math.pi * r
	local total = 4 * half + 2 * arc
	local count = 34
	for k = 0, count - 1 do
		local s, x, y = k * total / count, 0, 0
		if s < half then
			x, y = s, r
		elseif s < half + arc then
			local a = (s - half) / r
			x, y = half + r * math.sin(a), r * math.cos(a)
		elseif s < 3 * half + arc then
			x, y = half - (s - half - arc), -r
		elseif s < 3 * half + 2 * arc then
			local a = (s - 3 * half - arc) / r
			x, y = -half - r * math.sin(a), -r * math.cos(a)
		else
			x, y = s - total, r
		end
		part(sign, "MarqueeBulb", Vector3.new(0.28, 0.28, 0.28), layer(0.42) * CFrame.new(x, y, 0), k % 2 == 0 and C.gold or C.orange,
			{mat = NEON, decor = true, shape = Enum.PartType.Ball})
	end

	-- The painted face, on an invisible part just in front of the border, inside the bulbs
	local fw, fh = w - 1.44, h - 1.44
	local face = part(sign, "SignFace", Vector3.new(fw, fh, 0.05), layer(0.445), C.board, {decor = true, transparency = 1})
	local gui = ui("SurfaceGui", face, {Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = SIGN_PPS, LightInfluence = 0, MaxDistance = 300, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	local pw, ph = fw - 0.2, fh - 0.2 -- panel size in studs (a margin for its outline)
	local panel = ui("Frame", gui, {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(pw * SIGN_PPS, ph * SIGN_PPS), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0})
	corner(panel)
	vgrad(panel, rgb(24, 58, 150), rgb(6, 16, 52))
	ink(panel, 4)
	local shine = ui("Frame", panel, {Name = "Shine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.94, 0.46), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1})
	corner(shine)
	ui("UIGradient", shine, {Rotation = 90, Transparency = NumberSequence.new(0.8, 1)})

	drawRocket(panel, 1.65, ph / 2, 2.4, 3)
	drawChevrons(panel, pw - 1.7, ph / 2, 2.4, 3)
	local function text(name, str, y, width, height, color, z)
		return ui("TextLabel", panel, {Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y * SIGN_PPS),
			Size = UDim2.fromOffset(width * SIGN_PPS, height * SIGN_PPS), BackgroundTransparency = 1, Text = str,
			Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = color, ZIndex = z})
	end
	-- Title: gold, thick dark outline, and a dark copy just below it for a chunky drop shadow
	ink(text("TitleShadow", "LAUNCH PAD", 1.12 + 0.08, 7.4, 1.5, C.ink, 4), 5)
	local title = text("Title", "LAUNCH PAD", 1.12, 7.4, 1.5, Color3.new(1, 1, 1), 5)
	ui("UIGradient", title, {Rotation = 90, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 248, 170)),
		ColorSequenceKeypoint.new(0.5, C.gold), ColorSequenceKeypoint.new(1, C.goldDeep)})})
	ink(title, 5)
	ink(text("Subtitle", "STEP ON TO FLY!", 2.2, 5.4, 0.48, rgb(185, 235, 255), 5), 3)
	drawStar(panel, pw / 2 - 2.5, 2.2, 0.5, 5)
	drawStar(panel, pw / 2 + 2.5, 2.2, 0.5, 5)
	return sign
end

-- Builds one launch site. cf = centre of the pad's top surface, with -Z (LookVector) facing the plaza.
function M.Build(cf)
	local function at(x, y, z) return cf * CFrame.new(x, y, z) end
	local site = Instance.new("Model")
	site.Name = "LaunchSite"

	-- Launch pad: metal rim, navy deck with a glowing edge and an orange target in the middle
	local pad = model("LaunchPad", site)
	cyl(pad, "Rim", PLATFORM_D + 1.2, 0.8, at(0, 0.4, 0), C.metal, {mat = METAL, shadow = true})
	local deck = cyl(pad, "Deck", PLATFORM_D, 1, at(0, 0.5, 0), C.navy2, {shadow = true})
	cyl(pad, "EdgeGlow", PLATFORM_D - 1.6, 0.06, at(0, 1.03, 0), C.blue, {mat = NEON, decor = true})
	cyl(pad, "Inner", PLATFORM_D - 2.8, 0.08, at(0, 1.04, 0), C.navy, {decor = true})
	cyl(pad, "TargetRing", 7, 0.1, at(0, 1.05, 0), C.orange, {mat = NEON, decor = true})
	cyl(pad, "TargetGap", 6, 0.12, at(0, 1.06, 0), C.navy, {decor = true})
	cyl(pad, "TargetDot", 2.4, 0.14, at(0, 1.07, 0), C.orange, {mat = NEON, decor = true})
	pad.PrimaryPart = deck
	-- Chevrons on the walkway pointing players to the pad
	for i, z in ipairs({-12, -16.5}) do
		for _, side in ipairs({-1, 1}) do
			part(pad, "Chevron", Vector3.new(4.2, 0.1, 0.8), at(1.45 * side, 0.06, z) * CFrame.Angles(0, math.rad(40 * side), 0),
				C.orange, {mat = NEON, decor = true, transparency = i == 1 and 0 or 0.35})
		end
	end
	-- Low bollards around the pad
	for _, xz in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		local x, z = xz[1] * 6.6, xz[2] * 6.6
		cyl(pad, "Bollard", 0.9, 1.6, at(x, 0.8, z), C.light, {shadow = true})
		cyl(pad, "BollardLight", 0.95, 0.4, at(x, 1.8, z), C.orange, {mat = NEON, decor = true})
	end

	-- Where launching is allowed, and where the base teleport drops you
	local zone = part(site, "LaunchZone", Vector3.new(PLATFORM_D, ZONE_H, PLATFORM_D), at(0, 1 + ZONE_H / 2, 0), C.orange,
		{decor = true, transparency = 1})
	CollectionService:AddTag(zone, M.ZoneTag)
	local spawnPoint = Instance.new("Attachment")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.Position = Vector3.new(0, -ZONE_H / 2, 0) -- on the pad's surface, facing the plaza
	spawnPoint.Parent = zone

	-- Gantry: a lattice tower behind the pad with two service arms and a beacon on top
	local tower = model("Gantry", site)
	local h, w, tz = TOWER_H, TOWER_W, TOWER_Z
	local front, back = tz - w / 2, tz + w / 2
	for _, x in ipairs({-w / 2, w / 2}) do
		for _, z in ipairs({front, back}) do
			part(tower, "Pillar", Vector3.new(1, h, 1), at(x, h / 2, z), C.light, {mat = METAL, shadow = true})
		end
	end
	for y = 3, h - 3, 6 do
		for _, z in ipairs({front, back}) do
			part(tower, "Brace", Vector3.new(w + 1, 0.6, 0.6), at(0, y, z), C.light, {shadow = true})
		end
		for _, x in ipairs({-w / 2, w / 2}) do
			part(tower, "Brace", Vector3.new(0.6, 0.6, w + 1), at(x, y, tz), C.light, {shadow = true})
		end
	end
	local diag = math.sqrt(w * w + 36)
	local tilt = math.atan2(6, w)
	for bay = 0, 3 do
		local y = 6 + bay * 6
		local s = (bay % 2 == 0) and 1 or -1
		part(tower, "Diagonal", Vector3.new(diag, 0.35, 0.35), at(0, y, back) * CFrame.Angles(0, 0, tilt * s), C.grey)
		for _, x in ipairs({-w / 2, w / 2}) do
			part(tower, "Diagonal", Vector3.new(0.35, 0.35, diag), at(x, y, tz) * CFrame.Angles(tilt * s, 0, 0), C.grey)
		end
	end
	part(tower, "TopDeck", Vector3.new(w + 1.6, 0.6, w + 1.6), at(0, h + 0.3, tz), C.navy, {shadow = true})
	for _, x in ipairs({-1, 1}) do
		for _, z in ipairs({front - 0.5, back + 0.5}) do
			part(tower, "WarningLight", Vector3.new(0.5, 0.5, 0.5), at(x * (w / 2 + 0.5), h + 0.85, z), C.red, {mat = NEON, decor = true})
		end
	end
	cyl(tower, "Antenna", 0.3, 5, at(0, h + 3.1, tz), C.metal, {decor = true})
	part(tower, "Beacon", Vector3.new(1.2, 1.2, 1.2), at(0, h + 6, tz), C.red, {mat = NEON, decor = true, shape = Enum.PartType.Ball})
	local reach = front - ARM_Z
	for _, y in ipairs({12, 20}) do
		part(tower, "ServiceArm", Vector3.new(0.9, 0.9, reach), at(0, y, front - reach / 2), C.white, {decor = true, shadow = true})
		part(tower, "ArmClamp", Vector3.new(2.6, 1.6, 0.5), at(0, y, ARM_Z), C.navy, {decor = true})
		part(tower, "ArmLight", Vector3.new(2.2, 0.25, 0.55), at(0, y + 0.4, ARM_Z), C.glow, {mat = NEON, decor = true})
	end
	-- "LAUNCH PAD" sign on the front of the front pillars, facing the pad, below the service arms
	buildSign(site, at(0, SIGN_Y, front - 0.5))

	-- Big launch ring overhead on three struts (the front stays open for the walkway), and a glowing halo
	-- above the pad that players fly up through
	local ring = model("LaunchRing", site)
	kitPiece(ring, "PlanetRing_Band", 1, at(0, RING_Y, 0), C.white, {name = "Ring", size = Vector3.new(RING_D, 0.9, RING_D), decor = true, shadow = true})
	kitPiece(ring, "PlanetRing_Band", 1, at(0, RING_Y + 0.5, 0), C.glow, {name = "RingGlow", size = Vector3.new(RING_D - 1.2, 0.2, RING_D - 1.2), mat = NEON, decor = true})
	local r = RING_D / 2 - 0.3
	for _, xz in ipairs({{-r, 0}, {r, 0}, {0, r}}) do
		part(ring, "Strut", Vector3.new(1.2, RING_Y, 1.2), at(xz[1], RING_Y / 2, xz[2]), C.metal, {mat = METAL, shadow = true})
	end
	kitPiece(site, "PlanetRing_Band", 1, at(0, HALO_Y, 0), C.glow, {name = "Halo", size = Vector3.new(HALO_D, 0.4, HALO_D), mat = NEON, decor = true, transparency = 0.1})

	-- Fuel tanks on either side, piped to the pad
	local tanks = model("FuelTanks", site)
	for _, side in ipairs({-1, 1}) do
		local tcf = at(15.5 * side, 0, 0)
		kitPiece(tanks, "Tank_Saddle", 9, tcf * CFrame.new(-3.2, 0, 0), C.dark, {shadow = true})
		kitPiece(tanks, "Tank_Saddle", 9, tcf * CFrame.new(3.2, 0, 0), C.dark, {shadow = true})
		kitPiece(tanks, "Tank_Body", 9, tcf, C.white, {shadow = true})
		kitPiece(tanks, "Tank_Bands", 9, tcf, C.orange, {decor = true})
		part(tanks, "FuelPipe", Vector3.new(2.2, 0.6, 0.6), at(8.6 * side, 0.9, 0), C.metal, {mat = METAL})
	end

	site.PrimaryPart = deck
	site.WorldPivot = cf
	return site
end

-- The frame a plot's launch site is built in: the top of its Station_Pad, facing the plaza
local function siteFrame(core, plaza)
	local pad = core:FindFirstChild("Station_Pad")
	local c = pad.CFrame.Position
	local top = Vector3.new(c.X, c.Y + pad.Size.Y / 2, c.Z)
	return CFrame.lookAt(top, top + Vector3.new(plaza.X - c.X, 0, plaza.Z - c.Z).Unit)
end

-- RideARocketMapDetailer gives some parts (by name) a metal finish and keeps the old material in an
-- "OriginalMaterial" attribute. A rebuilt site copies those finishes from the old one, attribute and all,
-- so the detailer's Revert() still works on it.
local function detailerLooks(site)
	local looks = {}
	for _, d in ipairs(site:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("OriginalMaterial") ~= nil then looks[d.Name] = d.Material end
	end
	return looks
end
local function keepLooks(site, looks)
	for _, d in ipairs(site:GetDescendants()) do
		local material = d:IsA("BasePart") and looks[d.Name]
		if material and d.Material ~= material then
			d:SetAttribute("OriginalMaterial", d.Material.Name)
			d.Material = material
		end
	end
end

-- Replaces the satellite on every base. Safe to run again: old launch sites are rebuilt.
function M.Apply()
	local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
	local backups = ServerStorage:FindFirstChild("RemovedMapBackups") or Instance.new("Folder")
	backups.Name = "RemovedMapBackups"
	backups.Parent = ServerStorage
	local store = backups:FindFirstChild("Satellites_BeforeLaunchSites") or Instance.new("Folder")
	store.Name = "Satellites_BeforeLaunchSites"
	store.Parent = backups
	local built = 0
	for i = 1, 8 do
		local plot = station:FindFirstChild("StationPlot" .. i)
		local core = plot and plot:FindFirstChild("Core")
		if core and core:FindFirstChild("Station_Pad") then
			local saved = store:FindFirstChild(plot.Name) or Instance.new("Folder")
			saved.Name = plot.Name
			saved.Parent = store
			for _, c in ipairs(core:GetChildren()) do
				if c.Name:match("^SS_") then c.Parent = saved end
			end
			local old = core:FindFirstChild("LaunchSite")
			local looks = old and detailerLooks(old) or {}
			if old then old:Destroy() end
			local site = M.Build(siteFrame(core, station.SpawnHub.PlazaRim.CFrame.Position))
			keepLooks(site, looks)
			site.Parent = core
			built += 1
		end
	end
	return built
end

-- Puts the satellites back and removes the launch sites.
function M.Revert()
	local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
	local store = ServerStorage:FindFirstChild("RemovedMapBackups")
	store = store and store:FindFirstChild("Satellites_BeforeLaunchSites")
	for i = 1, 8 do
		local plot = station:FindFirstChild("StationPlot" .. i)
		local core = plot and plot:FindFirstChild("Core")
		local saved = store and store:FindFirstChild("StationPlot" .. i)
		if core then
			local site = core:FindFirstChild("LaunchSite")
			if site then site:Destroy() end
			if saved then for _, c in ipairs(saved:GetChildren()) do c.Parent = core end end
		end
	end
end

return M
