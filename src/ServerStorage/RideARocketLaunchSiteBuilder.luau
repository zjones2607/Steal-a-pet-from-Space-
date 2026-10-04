-- RideARocketLaunchSiteBuilder: swaps the satellite on every base (StationPlotN.Core.SS_*) for a
-- jetpack launch site of about the same size. Run once from the command bar in Edit mode:
--   require(game.ServerStorage.RideARocketLaunchSiteBuilder).Apply()
-- The satellite parts are moved (not deleted) to ServerStorage.RemovedMapBackups.Satellites_BeforeLaunchSites.
-- If you re-run RideARocketBaseBuilder, run this again afterwards.
--
-- Each site has an invisible part named "LaunchZone" tagged "LaunchZone". Jetpacks can only launch
-- while the player stands inside one (a cylinder: diameter = Size.X, height = Size.Y), and the base
-- teleport drops players at its "SpawnPoint" attachment. The site keeps clear of the four pet pods.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local M = {}
M.ZoneTag = "LaunchZone"

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local SP, NEON, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.DiamondPlate
-- Same palette as RideARocketBaseBuilder, plus the orange of the LAUNCH button
local C = {
	white = rgb(240, 243, 248), light = rgb(200, 206, 216), metal = rgb(165, 172, 186), grey = rgb(140, 147, 162),
	dark = rgb(75, 80, 95), navy = rgb(28, 38, 74), navy2 = rgb(40, 55, 100), blue = rgb(70, 160, 255),
	glow = rgb(160, 215, 255), orange = rgb(255, 115, 20), red = rgb(255, 60, 60),
}
-- Kit pieces used here: size and offset as fractions of the scale (same table format as the base builder)
local B = {
	Tank_Body = {1.4, 0.64, 0.6303, 0, 0.46, 0}, Tank_Bands = {0.8, 0.66, 0.65, 0, 0.46, 0},
	Tank_Saddle = {0.84, 0.24, 0.54, 0, 0.12, 0}, PlanetRing_Band = {1, 1, 1, 0, 0, 0},
}

local PLATFORM_D = 15   -- launch pad diameter (the LaunchZone matches it)
local ZONE_H = 12       -- how far above the pad still counts as standing on it
local TOWER_Z = 11.5    -- gantry centre, behind the pad
local TOWER_W = 7
local TOWER_H = 30
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
	for _, y in ipairs({12, 20}) do
		part(tower, "ServiceArm", Vector3.new(0.9, 0.9, 5), at(0, y, front - 2.5), C.white, {decor = true, shadow = true})
		part(tower, "ArmClamp", Vector3.new(2.6, 1.6, 0.5), at(0, y, front - 5), C.navy, {decor = true})
		part(tower, "ArmLight", Vector3.new(2.2, 0.25, 0.55), at(0, y + 0.4, front - 5), C.glow, {mat = NEON, decor = true})
	end
	-- "LAUNCH PAD" sign on the gantry, facing the pad
	local sign = part(tower, "Sign", Vector3.new(6.4, 1.8, 0.3), at(0, 6, front - 0.55), C.navy, {})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "LAUNCH PAD"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rgb(255, 218, 52)
	text.Parent = gui
	local pad2 = Instance.new("UIPadding")
	pad2.PaddingTop = UDim.new(0.12, 0); pad2.PaddingBottom = UDim.new(0.12, 0)
	pad2.Parent = text

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
local function siteFrame(core)
	local pad = core:FindFirstChild("Station_Pad")
	local c = pad.Position
	local top = Vector3.new(c.X, c.Y + pad.Size.Y / 2, c.Z)
	return CFrame.lookAt(top, top + Vector3.new(-c.X, 0, -c.Z).Unit)
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
			if old then old:Destroy() end
			M.Build(siteFrame(core)).Parent = core
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
