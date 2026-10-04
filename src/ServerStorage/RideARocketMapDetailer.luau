-- RideARocketMapDetailer: dresses the map up as the real solar system without changing its layout.
-- The station's planet becomes Earth (grass, trees, ponds on top; oceans, continents and clouds
-- underneath) and the five floating planets become the Moon, Mars, Mercury, Venus and Jupiter, in that
-- order: renamed, retextured and recoloured, with decorations that don't belong (trees on the Moon,
-- volcanoes on Mercury...) swapped for ones that do, in the same spots. Run from the command bar in
-- Edit mode:
--   require(game.ServerStorage.RideARocketMapDetailer).Apply()
--   require(game.ServerStorage.RideARocketMapDetailer).Revert()   -- puts everything back
-- Added parts go in folders named "Detail"; swapped-out decorations are kept in
-- ServerStorage.RemovedMapBackups.Decor_BeforeRealPlanets; changed parts remember their old name,
-- material, colour, transparency or text in "Original..." attributes. The layout is random but seeded,
-- so Apply gives the same result each time. If you re-run RideARocketBaseBuilder or
-- RideARocketMapBuilder, run Apply again afterwards.
local ServerStorage = game:GetService("ServerStorage")

local M = {}
local DETAIL = "Detail"
local BACKUP = "Decor_BeforeRealPlanets"
local Mat = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis (X) to point up

-- Station materials by part name. Anything not listed keeps its look (eggs, pets, crops, lights, signs...).
local BY_NAME = {
	Station_Pad = Mat.DiamondPlate, Deck_Tier1 = Mat.DiamondPlate, Deck_Tier2 = Mat.DiamondPlate, Deck_Tier3 = Mat.DiamondPlate,
	Walkway = Mat.DiamondPlate, WalkwayEdge = Mat.Metal, EntryPath = Mat.DiamondPlate,
	Plaza = Mat.Pavement, PlazaCenter = Mat.DiamondPlate, PlazaCenterRing = Mat.Metal, PlazaRim = Mat.Metal,
	RocketPedestal = Mat.Metal, Rocket_Body = Mat.Metal, Rocket_Nose = Mat.Metal, Rocket_Fins = Mat.Metal,
	Rocket_Nozzle = Mat.CorrodedMetal, Rocket_WindowRing = Mat.Metal,
	Border_Wall = Mat.Metal, Border_Frame = Mat.Metal, Border_Pillar = Mat.Metal, Border_Plinth = Mat.Concrete,
	Border_Glass = Mat.Glass, Post = Mat.Metal, Rail = Mat.Metal,
	Pod_Base = Mat.Metal, Pod_Arch = Mat.Metal, Pod_Cushion = Mat.Fabric,
	Crate_Body = Mat.Metal, Crate_Straps = Mat.Fabric, Tank_Body = Mat.Metal, Tank_Saddle = Mat.Metal,
	Mast_Tower = Mat.Metal, Flood_Pole = Mat.Metal,
	Deck = Mat.Metal, Bollard = Mat.Metal, Brace = Mat.Metal, Diagonal = Mat.Metal, TopDeck = Mat.DiamondPlate,
	Ring = Mat.Metal, ServiceArm = Mat.Metal, Antenna = Mat.Metal,
	Rock_Boulder = Mat.Rock, FloatingAsteroid = Mat.Basalt, Volcano_Cone = Mat.Basalt,
	Tree_Trunk = Mat.Wood, Pine_Trunk = Mat.Wood, Tree_Canopy = Mat.LeafyGrass, Bush = Mat.LeafyGrass,
}

-- The floating planets, by the number their model name starts with. swap: decorations that don't
-- belong, and what goes in their place ("crater", "rock", "volcano" or "swirl").
local PLANETS = {
	{name = "Moon", sign = "THE MOON", seed = 11,
		surface = {Mat.Slate, rgb(176, 176, 170)}, rock = {Mat.Slate, rgb(150, 150, 146)},
		swap = {PuffyTree = "crater", Bush = "crater", Mushroom = "crater"}, boulders = {Mat.Slate, rgb(140, 140, 135)},
		craters = 18, craterRim = rgb(160, 160, 154), craterFloor = rgb(122, 122, 118),
		pebbles = 45, pebble = {Mat.Basalt, rgb(132, 132, 128)}, outcrops = 40, debris = 10},
	{name = "Mars", sign = "MARS", seed = 22,
		surface = {Mat.Sand, rgb(196, 98, 58)}, rock = {Mat.Rock, rgb(150, 70, 45)},
		swap = {Pine = "rock", Crystal_Cluster = "rock"}, boulders = {Mat.Rock, rgb(160, 78, 50)},
		craters = 8, craterRim = rgb(176, 88, 54), craterFloor = rgb(150, 72, 45), mesas = 6, polarCap = true,
		pebbles = 45, pebble = {Mat.Rock, rgb(150, 75, 48)}, outcrops = 40, debris = 10},
	{name = "Mercury", sign = "MERCURY", seed = 33,
		surface = {Mat.Slate, rgb(168, 146, 124)}, rock = {Mat.Rock, rgb(128, 108, 92)},
		swap = {Volcano = "crater", Crystal_Cluster = "crater"}, boulders = {Mat.Rock, rgb(132, 114, 98)},
		craters = 30, craterSize = {4, 11}, craterRim = rgb(150, 130, 110), craterFloor = rgb(112, 96, 82),
		pebbles = 40, pebble = {Mat.Rock, rgb(120, 104, 90)}, outcrops = 44, debris = 10},
	{name = "Venus", sign = "VENUS", seed = 44,
		surface = {Mat.Rock, rgb(212, 160, 88)}, rock = {Mat.Basalt, rgb(150, 98, 58)},
		swap = {Mushroom = "volcano", Crystal_Cluster = "volcano"}, boulders = {Mat.Basalt, rgb(140, 92, 55)},
		craters = 4, craterRim = rgb(190, 140, 80), craterFloor = rgb(160, 110, 60), haze = 18,
		pebbles = 35, pebble = {Mat.Basalt, rgb(120, 80, 50)}, outcrops = 36, debris = 8},
	{name = "Jupiter", sign = "JUPITER", seed = 55,
		surface = {Mat.SmoothPlastic, rgb(236, 222, 196)}, rock = {Mat.SmoothPlastic, rgb(232, 214, 184)},
		swap = {Mushroom = "swirl", Crystal_Cluster = "swirl", Rock_Boulder = "swirl"},
		ring = rgb(205, 190, 165), bands = true, outcrops = 0, debris = 0},
}
-- Jupiter's cloud belts: pale zones and darker belts
local BANDS = {rgb(240, 230, 210), rgb(219, 188, 148), rgb(236, 220, 192), rgb(196, 142, 98), rgb(230, 208, 172), rgb(178, 116, 80)}

-- Kit meshes used for the detail: size fractions (same format as RideARocketBaseBuilder)
local KIT = {
	Rock_Boulder = Vector3.new(2.3841, 1.5531, 1.9709),
	Crystal_Cluster = Vector3.new(2.0593, 4.1, 1.8054),
	Crater_Rim = Vector3.new(2.1, 0.12, 2.1),
	Crater_Floor = Vector3.new(1.4, 0.008, 1.4),
	Volcano_Cone = Vector3.new(4.8, 2.2, 4.8),
	Volcano_Lava = Vector3.new(1.5, 0.15, 1.5),
}

-- Saves a property's value once, so Revert can put it back
local function remember(inst, prop)
	local key = "Original" .. prop
	if inst:GetAttribute(key) == nil then
		local value = inst[prop]
		inst:SetAttribute(key, typeof(value) == "EnumItem" and value.Name or value)
	end
end
local function style(part, material, color, transparency)
	if material and part.Material ~= material then remember(part, "Material"); part.Material = material end
	if color and part.Color ~= color then remember(part, "Color"); part.Color = color end
	if transparency and part.Transparency ~= transparency then remember(part, "Transparency"); part.Transparency = transparency end
end

local function detailFolder(parent)
	local old = parent:FindFirstChild(DETAIL)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = DETAIL
	f.Parent = parent
	return f
end

-- Where swapped-out decorations from `source` are kept (with a link back for Revert)
local function backupStore(key, source)
	local root = ServerStorage:FindFirstChild("RemovedMapBackups") or Instance.new("Folder")
	root.Name = "RemovedMapBackups"
	root.Parent = ServerStorage
	local store = root:FindFirstChild(BACKUP) or Instance.new("Folder")
	store.Name = BACKUP
	store.Parent = root
	local f = store:FindFirstChild(key)
	if not f then
		f = Instance.new("Folder")
		f.Name = key
		f.Parent = store
		local link = Instance.new("ObjectValue")
		link.Name = "Source"
		link.Value = source
		link.Parent = f
	end
	return f
end

-- A map-kit mesh; size is a scale (multiplies the kit proportions) or an exact Vector3
local function kitPiece(parent, name, size, cf, color, material, collide)
	local p = ServerStorage:WaitForChild("RideARocket_MapKit")[name]:Clone()
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	p.Size = typeof(size) == "Vector3" and size or KIT[name] * size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.CastShadow = collide
	pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Hull end)
	p.Parent = parent
	return p
end
-- A plain, non-colliding part (bands, spots, flowers...)
local function flat(parent, name, size, cf, color, material, shape, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function randomTilt(rng, amount)
	return CFrame.Angles(rng:NextNumber(-amount, amount), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-amount, amount))
end
-- A frame sitting on a surface point, with its Y axis along the surface normal
local function onSurface(hit)
	return CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function rayDown(within, x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {within}
	return workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -300, 0), params)
end

-- A random spot on top of `ground` where nothing else stands, away from everything in `avoid`.
-- footprint: also check the ground is open that far around (for trees, ponds...)
local function groundSpot(rng, ground, within, avoid, clearance, footprint)
	local top = ground.Position.Y + ground.Size.Y / 2
	local radius = math.min(ground.Size.X, ground.Size.Z) / 2 * 0.88
	for _ = 1, 20 do
		local a, d = rng:NextNumber(0, math.pi * 2), radius * math.sqrt(rng:NextNumber())
		local x, z = ground.Position.X + math.cos(a) * d, ground.Position.Z + math.sin(a) * d
		local hit = rayDown(within, x, z, top + 80)
		local ok = hit ~= nil and hit.Instance == ground and hit.Normal.Y > 0.75
		if ok then
			for _, p in ipairs(avoid) do
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude < clearance then ok = false break end
			end
		end
		if ok and footprint then
			for _, o in ipairs({{footprint, 0}, {-footprint, 0}, {0, footprint}, {0, -footprint}}) do
				local h = rayDown(within, x + o[1], z + o[2], top + 80)
				if not h or h.Instance ~= ground then ok = false break end
			end
		end
		if ok then return hit end
	end
end

-- The ground height under a point on a planet's top
local function groundAt(planet, surface, pos)
	local top = surface.Position.Y + surface.Size.Y / 2
	local hit = rayDown(planet, pos.X, pos.Z, top + 60)
	return hit and hit.Instance == surface and hit.Position or Vector3.new(pos.X, top, pos.Z)
end

-- Eggs, rescue pets, resting spots and signs: new decorations keep away from them
local function landmarks(planet)
	local points = {}
	for _, d in ipairs(planet:GetDescendants()) do
		if d:IsA("BasePart") and (d:GetAttribute("EggId") or d.Name == "PetRestingSpot" or d.Name == "PlanetNameSign") then
			table.insert(points, d.Position)
		elseif d:IsA("Model") and d.Name:match("^RescueDisplayPet") then
			table.insert(points, d:GetPivot().Position)
		end
	end
	return points
end

-- A point on a planet rock's outside surface. around (0..1) spreads points evenly around it;
-- yMin..yMax picks how far down the sides (-1 = straight underneath).
local function rockSpot(rng, rock, around, yMin, yMax)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {rock}
	local center = rock.Position
	local reach = rock.Size.Magnitude
	for _ = 1, 10 do
		local y = rng:NextNumber(yMin or -0.95, yMax or 0.2)
		local r = math.sqrt(1 - y * y)
		local theta = around and (around * math.pi * 2 + rng:NextNumber(-0.15, 0.15)) or rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r)
		local hit = workspace:Raycast(center + dir * reach, -dir * reach, params)
		if hit then return hit, dir end
	end
end

local function crater(folder, pos, s, yaw, rim, floor, rimMat, floorMat, floorTransparency)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	kitPiece(folder, "Crater_Rim", s, cf * CFrame.new(0, KIT.Crater_Rim.Y * s / 2 - 0.05, 0), rim, rimMat, false)
	local f = kitPiece(folder, "Crater_Floor", s, cf * CFrame.new(0, 0.04, 0), floor, floorMat, false)
	f.Transparency = floorTransparency or 0
end

local function volcano(folder, pos, s, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	kitPiece(folder, "Volcano_Cone", s, cf * CFrame.new(0, KIT.Volcano_Cone.Y * s / 2, 0), rgb(110, 70, 50), Mat.Basalt, true)
	kitPiece(folder, "Volcano_Lava", s, cf * CFrame.new(0, 2.15 * s, 0), rgb(255, 140, 40), Mat.Neon, false)
end

-- Puts a copy of a decoration (model or mesh) on the ground at pos
local function placeCopy(folder, template, pos, scale, yaw)
	local copy = template:Clone()
	if copy:IsA("Model") then copy:ScaleTo(copy:GetScale() * scale) else copy.Size = copy.Size * scale end
	copy:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
	local cf, size
	if copy:IsA("Model") then cf, size = copy:GetBoundingBox() else cf, size = copy.CFrame, copy.Size end
	copy:PivotTo(copy:GetPivot() + Vector3.new(0, pos.Y - (cf.Position.Y - size.Y / 2) - 0.3, 0))
	copy.Parent = folder
	return copy
end

local function dressPlanet(planet, number, theme)
	local surface, rock = planet:FindFirstChild("PlanetSurface"), planet:FindFirstChild("PlanetRock")
	if not surface or not rock then return end
	local rng = Random.new(theme.seed)
	remember(planet, "Name")
	planet.Name = ("%02d • %s"):format(number, theme.name)
	local sign = planet:FindFirstChild("PlanetNameSign")
	local text = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if text then remember(text, "Text"); text.Text = theme.sign end
	style(surface, theme.surface[1], theme.surface[2])
	style(rock, theme.rock[1], theme.rock[2])
	local folder = detailFolder(planet)
	local top = surface.Position.Y + surface.Size.Y / 2
	local center = surface.Position

	-- Swap decorations that don't belong for ones that do, in the same spots
	local avoid = landmarks(planet)
	local decor = planet:FindFirstChild("Decor")
	if decor then
		local store = backupStore(planet:GetAttribute("OriginalName") .. " Decor", decor)
		for _, item in ipairs(decor:GetChildren()) do
			if theme.swap[item.Name] then
				item.Parent = store
			elseif item.Name == "Rock_Boulder" and theme.boulders then
				style(item, theme.boulders[1], theme.boulders[2])
			elseif item.Name == "PlanetRing_Band" and theme.ring then
				style(item, Mat.SmoothPlastic, theme.ring, 0.45)
			end
		end
		for _, item in ipairs(store:GetChildren()) do
			local kind = item.Name ~= "Source" and theme.swap[item.Name]
			if kind then
				local size = item:IsA("Model") and item:GetExtentsSize() or item.Size
				local pos = groundAt(planet, surface, item:GetPivot().Position)
				local yaw = rng:NextNumber(0, math.pi * 2)
				table.insert(avoid, pos)
				if kind == "crater" then
					crater(folder, pos, math.clamp(size.X / 6, 3, 7), yaw, theme.craterRim, theme.craterFloor, theme.surface[1], theme.surface[1])
				elseif kind == "rock" then
					local s = math.clamp(size.X / 5, 2, 5)
					kitPiece(folder, "Rock_Boulder", s, CFrame.new(pos + Vector3.new(0, s * 0.4, 0)) * randomTilt(rng, 0.5),
						theme.boulders[2]:Lerp(rgb(0, 0, 0), rng:NextNumber(0, 0.2)), theme.boulders[1], true)
				elseif kind == "volcano" then
					volcano(folder, pos, rng:NextNumber(2.6, 4.2), yaw)
				elseif kind == "swirl" then
					flat(folder, "Swirl", Vector3.new(0.14, rng:NextNumber(16, 28), rng:NextNumber(8, 14)),
						CFrame.new(pos.X, top + 0.16, pos.Z) * CFrame.Angles(0, yaw, 0) * UPRIGHT, rgb(246, 240, 226), Mat.Sand, Enum.PartType.Cylinder)
				end
			end
		end
	end

	-- Craters scattered over the ground
	for _ = 1, theme.craters or 0 do
		local hit = groundSpot(rng, surface, planet, avoid, 16)
		if hit then
			local sizes = theme.craterSize or {2.5, 8}
			crater(folder, hit.Position, rng:NextNumber(sizes[1], sizes[2]), rng:NextNumber(0, math.pi * 2), theme.craterRim, theme.craterFloor,
				theme.surface[1], theme.surface[1])
			table.insert(avoid, hit.Position)
		end
	end
	-- Mars: flat-topped rocky mesas, and a white polar ice cap underneath
	for _ = 1, theme.mesas or 0 do
		local hit = groundSpot(rng, surface, planet, avoid, 28)
		if hit then
			local w = rng:NextNumber(18, 34)
			kitPiece(folder, "Rock_Boulder", Vector3.new(w, rng:NextNumber(5, 9), w * rng:NextNumber(0.6, 0.9)),
				CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rgb(176, 84, 52), Mat.Rock, true).Name = "Mesa"
			table.insert(avoid, hit.Position)
		end
	end
	if theme.polarCap then
		for _ = 1, 7 do
			local hit = rockSpot(rng, rock, nil, -1, -0.86)
			if hit then
				local s = rng:NextNumber(30, 55)
				kitPiece(folder, "Rock_Boulder", s, CFrame.new(hit.Position - hit.Normal * s * 0.35) * randomTilt(rng, math.pi),
					rgb(238, 240, 246), Mat.Snow, true)
			end
		end
	end
	-- Jupiter: a gas giant. The rock is wrapped in a globe of stacked cloud layers in alternating belt
	-- colours with the Great Red Spot on its side, and the walkable top is striped with the same belts.
	if theme.bands then
		local shellTop, shellBottom = top - 4, rock.Position.Y - rock.Size.Y / 2 - 10
		local height = shellTop - shellBottom
		local rMax, rTop = math.max(rock.Size.X, rock.Size.Z) / 2 + 14, surface.Size.X / 2 + 4
		local function radiusAt(t) -- t: 0 at the bottom, 1 at the top; round underneath, full width up high
			if t < 0.55 then return rMax * math.sqrt(math.max(0.03, 1 - ((0.55 - t) / 0.55) ^ 2)) end
			if t < 0.93 then return rMax end
			return rMax + (rTop - rMax) * (t - 0.93) / 0.07
		end
		local layers = 18
		for k = 0, layers - 1 do
			local t = (k + 0.5) / layers
			local r = radiusAt(t)
			local layer = flat(folder, "CloudLayer", Vector3.new(height / layers + 0.2, r * 2, r * 2),
				CFrame.new(center.X, shellBottom + t * height, center.Z) * UPRIGHT, BANDS[k % #BANDS + 1], Mat.SmoothPlastic, Enum.PartType.Cylinder)
			layer.CanCollide = true
			layer.CanQuery = true
			layer.CastShadow = true
		end
		local t = 0.42
		local dir = Vector3.new(1, 0, 1).Unit
		local pos = Vector3.new(center.X, shellBottom + t * height, center.Z) + dir * (radiusAt(t) - 2)
		local facing = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis pointing outwards
		flat(folder, "GreatRedSpot", Vector3.new(6, 64, 116), facing, rgb(196, 86, 58), Mat.SmoothPlastic, Enum.PartType.Cylinder)
		flat(folder, "GreatRedSpotEye", Vector3.new(6.4, 40, 74), facing, rgb(220, 120, 84), Mat.SmoothPlastic, Enum.PartType.Cylinder)

		-- Belts across the top, in thin strips so they follow the round edge of its flat part
		local only = RaycastParams.new()
		only.FilterType = Enum.RaycastFilterType.Include
		only.FilterDescendantsInstances = {surface}
		local R = surface.Size.X / 2
		for _, way in ipairs({Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis}) do
			local flatTo = 0
			for dist = 0, surface.Size.X / 2, 2 do
				local p = center + way * dist
				local hit = workspace:Raycast(Vector3.new(p.X, top + 20, p.Z), Vector3.new(0, -40, 0), only)
				if not hit or hit.Position.Y < top - 0.5 then break end
				flatTo = dist
			end
			R = math.min(R, flatTo - 1)
		end
		local d, i = -R, 0
		while d < R do
			i += 1
			local stop = math.min(d + rng:NextNumber(26, 56), R)
			while d < stop do
				local d2 = math.min(d + 4, stop)
				local outer = math.max(math.abs(d), math.abs(d2))
				if outer < R then
					flat(folder, "CloudBand", Vector3.new(2 * math.sqrt(R * R - outer * outer), 0.12, d2 - d),
						CFrame.new(center.X, top + 0.06, center.Z + (d + d2) / 2), BANDS[(i - 1) % #BANDS + 1], Mat.SmoothPlastic)
				end
				d = d2
			end
		end
	end
	-- Venus: thick yellow clouds wrapped around the planet
	for _ = 1, theme.haze or 0 do
		local hit, dir = rockSpot(rng, rock, nil, -0.7, 0.15)
		if hit then
			local cloud = kitPiece(folder, "Rock_Boulder", Vector3.new(rng:NextNumber(60, 120), rng:NextNumber(18, 30), rng:NextNumber(40, 80)),
				onSurface(hit) * CFrame.new(0, rng:NextNumber(14, 34), 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rgb(240, 218, 150), Mat.SmoothPlastic, false)
			cloud.Name = "Cloud"
			cloud.Transparency = 0.4
		end
	end

	-- Rock outcrops half-buried in the sides and underside (on Jupiter, coloured in belts by height)
	local bottom = rock.Position.Y - rock.Size.Y / 2
	for i = 1, theme.outcrops do
		local hit = rockSpot(rng, rock, i / theme.outcrops)
		if hit then
			local s = theme.bands and rng:NextNumber(30, 60) or rng:NextNumber(24, 56)
			local color
			if theme.bands then
				color = BANDS[math.floor((hit.Position.Y - bottom) / 45) % #BANDS + 1]
			else
				local shade = rng:NextNumber(-0.3, 0.15)
				color = shade < 0 and rock.Color:Lerp(rgb(0, 0, 0), -shade) or rock.Color:Lerp(rgb(255, 255, 255), shade)
			end
			kitPiece(folder, "Rock_Boulder", s, CFrame.new(hit.Position - hit.Normal * s * 0.4) * randomTilt(rng, math.pi), color, theme.rock[1], true)
		end
	end
	-- Pebbles and small rocks on top, clear of eggs, pets and signs
	for _ = 1, theme.pebbles or 0 do
		local hit = groundSpot(rng, surface, planet, avoid, 10)
		if hit then
			local s = rng:NextNumber(0.8, 3)
			kitPiece(folder, "Rock_Boulder", s, CFrame.new(hit.Position + Vector3.new(0, s * 0.35, 0)) * randomTilt(rng, 0.4),
				theme.pebble[2]:Lerp(rgb(255, 255, 255), rng:NextNumber(0, 0.15)), theme.pebble[1], s > 2)
		end
	end
	-- Debris drifting under the planet (no collision, so it never blocks a flight)
	for _ = 1, theme.debris or 0 do
		local hit, dir = rockSpot(rng, rock)
		if hit and dir.Y < 0 then
			local s = rng:NextNumber(3, 10)
			kitPiece(folder, "Rock_Boulder", s, CFrame.new(hit.Position + dir * rng:NextNumber(40, 120)) * randomTilt(rng, math.pi),
				rock.Color:Lerp(rgb(0, 0, 0), 0.2), theme.rock[1], false)
		end
	end
end

-- The first template found for a decoration, in the map or in the backups
local function findTemplate(name)
	local roots = {workspace:FindFirstChild("JetpackPetRescueMap"), ServerStorage:FindFirstChild("RemovedMapBackups")}
	for _, root in ipairs(roots) do
		for _, d in ipairs(root and root:GetDescendants() or {}) do
			if d.Name == name and (d:IsA("Model") or d:IsA("MeshPart")) and not d:FindFirstAncestor(DETAIL) then return d end
		end
	end
end

local FLOWERS = {rgb(255, 120, 180), rgb(255, 220, 70), rgb(250, 250, 250), rgb(190, 120, 255), rgb(235, 70, 70)}

local function dressEarth(station, templates)
	local home = station:FindFirstChild("SharedPlanet")
	local ground, globe = home and home:FindFirstChild("HomeSurface"), home and home:FindFirstChild("HomeRock")
	if not ground or not globe then return end
	style(ground, Mat.Grass, rgb(88, 160, 72))
	style(globe, Mat.Glacier, rgb(32, 92, 172))
	local rng = Random.new(77)
	local folder = detailFolder(home)

	-- Underneath, Earth from space: continents, polar ice and clouds over a blue ocean
	for i = 1, 34 do
		local hit = rockSpot(rng, globe, i / 34, -0.85, 0.1)
		if hit then
			local s = rng:NextNumber(130, 280)
			local land = rng:NextNumber() < 0.72 and rgb(80, 160, 66):Lerp(rgb(56, 124, 52), rng:NextNumber()) or rgb(196, 172, 112)
			kitPiece(folder, "Rock_Boulder", Vector3.new(s, 22, s * rng:NextNumber(0.5, 0.9)),
				onSurface(hit) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(0, -3, 0), land, Mat.Grass, true).Name = "Continent"
		end
	end
	for _ = 1, 4 do
		local hit = rockSpot(rng, globe, nil, -1, -0.9)
		if hit then
			local s = rng:NextNumber(120, 200)
			kitPiece(folder, "Rock_Boulder", Vector3.new(s, 24, s * 0.8), onSurface(hit) * CFrame.new(0, -3, 0), rgb(240, 244, 250), Mat.Snow, true).Name = "IceCap"
		end
	end
	for _ = 1, 22 do
		local hit = rockSpot(rng, globe, nil, -0.9, 0.1)
		if hit then
			local cloud = kitPiece(folder, "Rock_Boulder", Vector3.new(rng:NextNumber(80, 180), 8, rng:NextNumber(40, 90)),
				onSurface(hit) * CFrame.new(0, rng:NextNumber(18, 40), 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rgb(250, 250, 255), Mat.SmoothPlastic, false)
			cloud.Name = "Cloud"
			cloud.Transparency = 0.25
		end
	end

	-- On top: the old moon decorations become Earth ones (crystals -> bushes, craters -> ponds)
	local decor = station:FindFirstChild("BaseDecor")
	local avoid = {}
	if decor then
		local store = backupStore("Station BaseDecor", decor)
		for _, item in ipairs(decor:GetChildren()) do
			if item.Name == "Crystal_Cluster" then item.Parent = store
			elseif item.Name == "Crater_Floor" then style(item, Mat.Glass, rgb(45, 125, 200), 0.1)
			elseif item.Name == "Crater_Rim" then style(item, Mat.Ground, rgb(112, 96, 68))
			elseif item.Name == "Rock_Boulder" then style(item, Mat.Rock, rgb(128, 122, 112)) end
			if item.Parent == decor then table.insert(avoid, item:GetPivot().Position) end
		end
		for _, item in ipairs(store:GetChildren()) do
			if item.Name == "Crystal_Cluster" and templates.Bush then
				local pos = item.Position - Vector3.new(0, item.Size.Y / 2, 0)
				placeCopy(folder, templates.Bush, pos, rng:NextNumber(0.6, 0.85), rng:NextNumber(0, math.pi * 2))
				table.insert(avoid, pos)
			end
		end
	end
	-- Ponds, trees, bushes, flowers, grass patches and rocks on the open ground
	for _ = 1, 8 do
		local hit = groundSpot(rng, ground, station, avoid, 30, 12)
		if hit then
			crater(folder, hit.Position, rng:NextNumber(6, 10), rng:NextNumber(0, math.pi * 2), rgb(112, 96, 68), rgb(45, 125, 200), Mat.Ground, Mat.Glass, 0.1)
			table.insert(avoid, hit.Position)
		end
	end
	for i = 1, 46 do
		local template = (i % 3 == 0) and templates.Pine or templates.PuffyTree
		local hit = template and groundSpot(rng, ground, station, avoid, 18, 9)
		if hit then
			local tree = placeCopy(folder, template, hit.Position, rng:NextNumber(0.75, 1.2), rng:NextNumber(0, math.pi * 2))
			for _, p in ipairs(tree:GetDescendants()) do
				if p.Name == "Pine_Leaves" then p.Color = rgb(58, 118, 66); p.Material = Mat.LeafyGrass end
			end
			table.insert(avoid, hit.Position)
		end
	end
	for _ = 1, 30 do
		local hit = templates.Bush and groundSpot(rng, ground, station, avoid, 10, 5)
		if hit then
			placeCopy(folder, templates.Bush, hit.Position, rng:NextNumber(0.45, 0.8), rng:NextNumber(0, math.pi * 2))
			table.insert(avoid, hit.Position)
		end
	end
	for _ = 1, 20 do
		local hit = groundSpot(rng, ground, station, avoid, 8)
		if hit then
			local color = FLOWERS[rng:NextInteger(1, #FLOWERS)]
			for _ = 1, 7 do
				local p = hit.Position + Vector3.new(rng:NextNumber(-4, 4), 0.5, rng:NextNumber(-4, 4))
				flat(folder, "Flower", Vector3.new(0.9, 0.9, 0.9), CFrame.new(p), color, Mat.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end
	for _ = 1, 24 do
		local hit = groundSpot(rng, ground, station, {}, 0)
		if hit then
			local patch = kitPiece(folder, "Rock_Boulder", Vector3.new(rng:NextNumber(22, 48), 0.3, rng:NextNumber(18, 40)),
				CFrame.new(hit.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rgb(76, 146, 62):Lerp(rgb(110, 176, 84), rng:NextNumber()), Mat.Grass, false)
			patch.Name = "GrassPatch"
		end
	end
	for _ = 1, 10 do
		local hit = groundSpot(rng, ground, station, avoid, 12)
		if hit then
			for _ = 1, rng:NextInteger(3, 4) do
				local s = rng:NextNumber(1.2, 3.4)
				local offset = Vector3.new(rng:NextNumber(-5, 5), s * 0.3, rng:NextNumber(-5, 5))
				kitPiece(folder, "Rock_Boulder", s, CFrame.new(hit.Position + offset) * randomTilt(rng, 0.5),
					rgb(118, 112, 102):Lerp(rgb(150, 144, 134), rng:NextNumber()), Mat.Rock, s > 1.6)
			end
			table.insert(avoid, hit.Position)
		end
	end
end

-- Plaza: a glowing ring and a guide line out towards each walkway. Walkways: panel seams.
local function dressPlazaAndWalkways(station)
	local hub, walkways = station:FindFirstChild("SpawnHub"), station:FindFirstChild("Walkways")
	local plaza = hub and hub:FindFirstChild("Plaza", true)
	if not plaza or not walkways then return end
	local center = plaza.Position
	local top = center.Y + plaza.Size.X / 2 -- the plaza is a cylinder standing on end
	local radius = plaza.Size.Y / 2
	local glow = rgb(70, 160, 255)
	local folder = detailFolder(hub)
	flat(folder, "PlazaRingGlow", Vector3.new(0.06, radius * 1.24, radius * 1.24), CFrame.new(center.X, top + 0.03, center.Z) * UPRIGHT,
		glow, Mat.Neon, Enum.PartType.Cylinder)
	flat(folder, "PlazaRingInner", Vector3.new(0.06, radius * 1.24 - 1.4, radius * 1.24 - 1.4), CFrame.new(center.X, top + 0.05, center.Z) * UPRIGHT,
		plaza.Color, plaza.Material, Enum.PartType.Cylinder)
	local seams = detailFolder(walkways)
	for _, w in ipairs(walkways:GetChildren()) do
		if w:IsA("BasePart") and w.Name == "Walkway" then
			local out = Vector3.new(w.Position.X - center.X, 0, w.Position.Z - center.Z).Unit
			local from, to = 21, radius - 4
			local mid = center + out * (from + to) / 2
			flat(folder, "GuideLine", Vector3.new(0.9, 0.1, to - from),
				CFrame.lookAt(Vector3.new(mid.X, top + 0.16, mid.Z), Vector3.new(mid.X, top + 0.16, mid.Z) + out), glow, Mat.Neon)
			local length, width = w.Size.Z, w.Size.X
			local wTop = w.Position.Y + w.Size.Y / 2
			local count = math.floor(length / 10.5)
			for i = 1, count - 1 do
				local pos = w.CFrame * Vector3.new(0, 0, -length / 2 + i * length / count)
				flat(seams, "Seam", Vector3.new(width - 0.4, 0.05, 0.3),
					CFrame.lookAt(Vector3.new(pos.X, wTop + 0.025, pos.Z), Vector3.new(pos.X, wTop + 0.025, pos.Z) + out),
					w.Color:Lerp(rgb(0, 0, 0), 0.35), Mat.Metal)
			end
		end
	end
end

function M.Apply()
	local map = workspace:WaitForChild("JetpackPetRescueMap")
	local templates = {PuffyTree = findTemplate("PuffyTree"), Pine = findTemplate("Pine"), Bush = findTemplate("Bush")}
	local changed = 0
	for _, d in ipairs(map:GetDescendants()) do
		local material = d:IsA("BasePart") and d.Transparency < 1 and BY_NAME[d.Name]
		if material and not d:FindFirstAncestor(DETAIL) then
			style(d, material)
			changed += 1
		end
	end
	local renamed = {}
	for _, planet in ipairs(map:GetChildren()) do
		local number = tonumber(planet.Name:match("^(%d+)"))
		if planet:IsA("Model") and number and PLANETS[number] then
			dressPlanet(planet, number, PLANETS[number])
			table.insert(renamed, planet.Name)
		end
	end
	local station = map:FindFirstChild("SpaceStation")
	if station then
		dressEarth(station, templates)
		dressPlazaAndWalkways(station)
	end
	local added = 0
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d:FindFirstAncestor(DETAIL) then added += 1 end
	end
	table.sort(renamed)
	return ("retextured %d parts, added %d detail parts; planets: %s"):format(changed, added, table.concat(renamed, ", "))
end

function M.Revert()
	local map = workspace:WaitForChild("JetpackPetRescueMap")
	local root = ServerStorage:FindFirstChild("RemovedMapBackups")
	local store = root and root:FindFirstChild(BACKUP)
	if store then
		for _, f in ipairs(store:GetChildren()) do
			local source = f:FindFirstChild("Source")
			if source and source.Value then
				for _, item in ipairs(f:GetChildren()) do
					if item ~= source then item.Parent = source.Value end
				end
			end
		end
		store:Destroy()
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("Folder") and d.Name == DETAIL then d:Destroy() end
	end
	for _, d in ipairs(map:GetDescendants()) do
		for _, prop in ipairs({"Material", "Color", "Transparency", "Text", "Name"}) do
			local value = d:GetAttribute("Original" .. prop)
			if value ~= nil then
				d[prop] = prop == "Material" and Enum.Material[value] or value
				d:SetAttribute("Original" .. prop, nil)
			end
		end
	end
end

return M
