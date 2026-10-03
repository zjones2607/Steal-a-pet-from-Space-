-- RideARocketMapBuilder: assembles the new cartoon map from the Blender kit (RideARocket_MapKit.fbx)
local B = {
 SS_Hub={2.8,4.7,2.8,0,2.75,0}, SS_Bands={2.47,3.36,2.47,0,2.78,0}, SS_Windows={2.4585,2.49,2.48,0,2.975,0},
 SS_Ring={8.12,0.92,8.12,0,2.4,0}, SS_RingWindows={8.1195,0.2,8.1195,0,2.4,0}, SS_RingStripe={7.675,0.0636,7.675,0,2.8432,0},
 SS_Spokes={4.7518,0.32,4.7518,0,2.4,0}, SS_Truss={9.2,0.3,0.3,0,4.6,0}, SS_SolarPanels={8.8,2.6,0.05,0,4.6,0},
 SS_PanelFrames={8.85,3.0,0.09,0,4.6,0}, SS_Dish={1.4,0.9674,1.1294,0,5.5337,-0.1491}, SS_Airlock={1.4,1.4,1.1,0,1.05,-1.65},
 SS_Hatch={0.96,0.96,0.06,0,1.05,-2.23}, SS_HatchRim={1.12,1.12,0.09,0,1.05,-2.235}, SS_Fins={4.4,1.4,2.29,0,1.1,1.055},
 SS_LightsRed={1.5783,1.64,0.28,-3.794,5.28,0}, SS_LightsGreen={1.5783,1.64,0.28,3.794,5.28,0}, SS_TopLight={0.2092,0.22,0.22,0,5.12,0},
 Planet_Rock={19.8921,17.8873,19.9464,-0.1335,-2.4436,0.1227}, Planet_Topsoil={16.1,2.4925,16.1,0,5.9538,0},
 PlanetRing_Band={32,0.4,32,0,0,0}, Tree_Trunk={0.9,3.2,0.9,0,1.6,0}, Tree_Canopy={4.335,3.45,3.6,0.0262,4.175,0.1},
 Pine_Trunk={0.5196,1.2,0.6,0,0.6,0}, Pine_Leaves={3.2,3.6,3.2,0,3.0,0}, Crystal_Cluster={2.0593,4.1,1.8054,0.0631,2.05,0.1691},
 Rock_Boulder={2.3841,1.5531,1.9709,-0.043,-0.0143,-0.0482}, Shroom_Stem={0.856,2.4,0.9,0,1.2,0}, Shroom_Cap={3.0434,1.12,3.2,0,2.96,0},
 Shroom_Spots={3.2678,0.7412,3.0903,-0.0194,3.1676,-0.013}, Volcano_Cone={4.8,2.2,4.8,0,1.1,0}, Volcano_Lava={1.5,0.15,1.5,0,2.15,0},
 Lamp_Pole={0.9511,3.3,1.0,0,1.65,0}, Lamp_Orb={0.9511,1.0,1.0,0,3.6,0},
 Station_Pad={9,0.4,9,0,0.2,0}, Station_PadGlow={9.12,0.1,9.12,0,0.17,0}, Station_Dome={3.2,1.5,3.2,0,1.15,0},
 Station_Trim={3.52,0.32,3.52,0,0.5,0}, Station_Antenna={0.32,1.1,0.32,0,2.45,0}, Station_Beacon={0.4185,0.44,0.44,0,3.15,0},
 Station_DoorArch={1.44,0.72,0.2078,0,0.76,-1.52},
 Deck_Tier1={4.2163,0.4,4.1,6.0919,0.2,-2.05}, Deck_Tier2={3.8986,0.4,5.5,9.0507,0.2,-2.75}, Deck_Tier3={4.0737,0.4,6.8,11.5631,0.2,-3.4},
 DeckRail_Tier1={1.2025,0.12,4.1,7.5987,0.46,-2.05}, DeckRail_Tier2={1.5776,0.12,5.5,10.2112,0.46,-2.75}, DeckRail_Tier3={1.926,0.12,6.8,12.637,0.46,-3.4},
 Pod_Base={1.4,0.2,1.4,0,0.1,0}, Pod_Cushion={1.2,0.18,1.2,0,0.29,0}, Pod_Arch={1.32,0.66,0.1039,0,0.53,0},
 Rocket_Body={2,4.2,2,0,2.7,0}, Rocket_Nose={1.6,1.7,1.6,0,5.65,0}, Rocket_Nozzle={1.5,0.45,1.5,0,0.375,0},
 Rocket_Fins={2.4779,2.2,2.8613,0.361,1.1,0}, Rocket_WindowRing={0.84,0.84,0.12,0,3.4,1.05}, Rocket_Window={0.66,0.66,0.05,0,3.4,0.985},
 Rocket_Flame={1.1,1.55,1.1,0,-0.625,0},
}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SP, NEON, GLASS = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass
local Y0 = 8                 -- home world ground height
local TOP = Y0 + 1           -- walk surface of plaza / paths / decks
local R_PLOT = 470           -- radius of the station ring (was ~380)
local PLOTS = {
 {"Ruby",rgb(255,70,95)},{"Amber",rgb(255,170,40)},{"Lime",rgb(125,220,60)},{"Teal",rgb(40,210,190)},
 {"Sky",rgb(70,170,255)},{"Indigo",rgb(115,100,255)},{"Violet",rgb(190,90,255)},{"Bubblegum",rgb(255,110,200)},
}
local TIER_CAP = {[0]=4,[1]=10,[2]=18,[3]=26}
local THEMES = {
 ["01 • Verdant Planet"]={rock=rgb(150,100,75),soil=rgb(95,215,85),accent=rgb(255,220,90),props={"tree","tree","bush","boulder","tree","shroom","bush"},leaf={rgb(90,220,90),rgb(150,235,80),rgb(60,195,120)},cap={rgb(255,90,90),rgb(255,160,60)},crystal={rgb(255,230,120)}},
 ["02 • Frost Planet"]={rock=rgb(120,150,215),soil=rgb(240,248,255),accent=rgb(120,220,255),props={"pine","pine","crystal","boulder","pine","pine"},leaf={rgb(70,175,165),rgb(95,200,190),rgb(230,245,255)},crystal={rgb(140,230,255),rgb(190,245,255)},cap={rgb(120,200,255)}},
 ["03 • Molten Planet"]={rock=rgb(85,55,70),soil=rgb(235,100,45),accent=rgb(255,190,40),props={"volcano","boulder","volcano","crystal","boulder"},crystal={rgb(255,150,40),rgb(255,90,60)},leaf={rgb(255,120,40)},cap={rgb(255,120,40)}},
 ["04 • Crystal Planet"]={rock=rgb(100,65,170),soil=rgb(225,160,255),accent=rgb(255,120,220),props={"crystal","crystal","crystal","boulder","shroom"},crystal={rgb(255,90,220),rgb(110,230,255),rgb(190,120,255)},cap={rgb(110,230,255)},leaf={rgb(255,150,230)}},
 ["05 • Cosmic Planet"]={rock=rgb(45,45,120),soil=rgb(70,225,200),accent=rgb(255,230,90),props={"shroom","crystal","shroom","boulder","shroom"},crystal={rgb(255,240,120),rgb(120,255,220)},cap={rgb(255,80,170),rgb(140,90,255),rgb(80,200,255)},leaf={rgb(140,90,255)},ring=true},
}
local HOME = {rock=rgb(120,95,190),soil=rgb(185,165,255),leaf={rgb(255,140,200),rgb(120,230,120),rgb(255,205,90),rgb(110,210,255)},crystal={rgb(110,230,255),rgb(255,120,220),rgb(255,230,110)},cap={rgb(255,90,150),rgb(255,170,60)}}

local M = {}
local kit
local function place(name, parent, cf, s, color, opts)
	opts = opts or {}
	local srcPart = kit[name]; assert(srcPart, "Kit piece missing: "..name)
	local b = B[name]
	local p = srcPart:Clone()
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	p.Name = opts.name or name
	p.Size = Vector3.new(b[1], b[2], b[3]) * s
	p.CFrame = cf * CFrame.new(b[4]*s, b[5]*s, b[6]*s) * CFrame.Angles(0, math.pi, 0) -- importer turns meshes 180deg
	p.Anchored = true
	p.Color = color
	p.Material = opts.mat or SP
	p.Transparency = opts.transparency or 0
	p.CastShadow = opts.shadow == true
	if opts.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	else p.CanCollide = opts.collide ~= false; p.CanTouch = false end
	if p:IsA("MeshPart") then
		pcall(function() p.CollisionFidelity = opts.fidelity or Enum.CollisionFidelity.Box end)
		pcall(function() p.RenderFidelity = Enum.RenderFidelity.Automatic end)
		pcall(function() p.DoubleSided = false end)
	end
	p.Parent = parent
	return p
end
local function block(name, parent, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true; p.Color = color
	p.Material = opts.mat or SP; p.Shape = opts.shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = opts.shadow == true; p.Transparency = opts.transparency or 0
	if opts.decor then p.CanCollide=false; p.CanTouch=false; p.CanQuery=false else p.CanTouch=false end
	p.Parent = parent; return p
end
local function model(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local function pick(rng, t) return t[rng:NextInteger(1, #t)] end
local function yaw(rng) return CFrame.Angles(0, rng:NextNumber()*math.pi*2, 0) end
local function billboard(parent, text, color, size, maxDist, offsetY)
	local g = Instance.new("BillboardGui"); g.Size = size; g.MaxDistance = maxDist; g.StudsOffset = Vector3.new(0, offsetY or 0, 0)
	g.LightInfluence = 0; g.Parent = parent
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1,1); t.BackgroundTransparency = 1; t.Text = text
	t.TextScaled = true; t.Font = Enum.Font.FredokaOne; t.TextColor3 = Color3.new(1,1,1); t.Parent = g
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = color; st.Parent = t
	return g
end

-- props: base CFrame sits on the ground
local function prop(kind, parent, cf, s, th, rng)
	cf = cf * yaw(rng)
	if kind == "tree" then
		local m = model("PuffyTree", parent)
		place("Tree_Trunk", m, cf, s, rgb(150,95,60), {shadow=true})
		place("Tree_Canopy", m, cf, s, pick(rng, th.leaf), {decor=true, shadow=true})
	elseif kind == "bush" then
		place("Tree_Canopy", parent, cf * CFrame.new(0, -2.6*s, 0), s*0.6, pick(rng, th.leaf), {decor=true, name="Bush"})
	elseif kind == "pine" then
		local m = model("Pine", parent)
		place("Pine_Trunk", m, cf, s, rgb(130,85,60))
		place("Pine_Leaves", m, cf, s, pick(rng, th.leaf), {decor=true, shadow=true})
	elseif kind == "crystal" then
		local c = pick(rng, th.crystal)
		place("Crystal_Cluster", parent, cf * CFrame.Angles(rng:NextNumber(-0.2,0.2),0,rng:NextNumber(-0.2,0.2)), s, c, {decor=true, mat = rng:NextNumber() < 0.35 and NEON or SP})
	elseif kind == "boulder" then
		place("Rock_Boulder", parent, cf * CFrame.new(0, 0.25*s, 0), s, th.rock:Lerp(Color3.new(1,1,1), 0.18), {fidelity=Enum.CollisionFidelity.Box})
	elseif kind == "shroom" then
		local m = model("Mushroom", parent)
		place("Shroom_Stem", m, cf, s, rgb(255,245,225), {decor=true})
		place("Shroom_Cap", m, cf, s, pick(rng, th.cap), {decor=true, shadow=true})
		place("Shroom_Spots", m, cf, s, Color3.new(1,1,1), {decor=true})
	elseif kind == "volcano" then
		local m = model("Volcano", parent)
		place("Volcano_Cone", m, cf, s, th.rock:Lerp(Color3.new(0,0,0), 0.2), {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
		place("Volcano_Lava", m, cf, s, rgb(255,120,20), {decor=true, mat=NEON})
	end
end
local function lamp(parent, cf, s, orbColor)
	local m = model("Lamp", parent)
	place("Lamp_Pole", m, cf, s, rgb(255,200,70), {decor=true})
	place("Lamp_Orb", m, cf, s, orbColor, {decor=true, mat=NEON})
end
local function scatter(rng, n, rMin, rMax, gap, avoid)
	local pts, tries = {}, 0
	while #pts < n and tries < n*80 do
		tries += 1
		local a = rng:NextNumber()*math.pi*2
		local r = math.sqrt(rng:NextNumber()*(rMax^2 - rMin^2) + rMin^2)
		local v = Vector2.new(math.cos(a)*r, math.sin(a)*r)
		local ok = not (avoid and avoid(v))
		if ok then for _, q in ipairs(pts) do if (q - v).Magnitude < gap then ok = false break end end end
		if ok then table.insert(pts, v) end
	end
	return pts
end

local function buildPlanetBody(parent, center2, topY, f, th, name)
	local origin = CFrame.new(center2.X, topY - 7.2*f, center2.Y)
	place("Planet_Rock", parent, origin, f, th.rock, {fidelity=Enum.CollisionFidelity.Hull, shadow=true, name=name.."Rock"})
	place("Planet_Topsoil", parent, origin, f, th.soil, {fidelity=Enum.CollisionFidelity.Hull, name=name.."Surface"})
	return origin
end

local DECK_A, DECK_B = rgb(205,212,228), rgb(182,192,214)
local function buildCoreStation(core, cf, color)
	local S, W, G, GOLD, LIT = 10, rgb(245,247,255), rgb(160,168,190), rgb(255,205,60), rgb(255,225,120)
	place("SS_Hub", core, cf, S, W, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("SS_Bands", core, cf, S, color, {decor=true})
	place("SS_Windows", core, cf, S, LIT, {decor=true, mat=NEON})
	place("SS_Ring", core, cf, S, W, {decor=true, shadow=true})
	place("SS_RingWindows", core, cf, S, LIT, {decor=true, mat=NEON})
	place("SS_RingStripe", core, cf, S, color, {decor=true})
	place("SS_Spokes", core, cf, S, G, {decor=true})
	place("SS_Truss", core, cf, S, G, {decor=true})
	place("SS_SolarPanels", core, cf, S, rgb(45,85,220), {decor=true, shadow=true})
	place("SS_PanelFrames", core, cf, S, GOLD, {decor=true})
	place("SS_Dish", core, cf, S, W, {decor=true, shadow=true})
	place("SS_Airlock", core, cf, S, W, {fidelity=Enum.CollisionFidelity.Box, shadow=true})
	place("SS_Hatch", core, cf, S, color, {decor=true})
	place("SS_HatchRim", core, cf, S, GOLD, {decor=true})
	place("SS_Fins", core, cf, S, color, {decor=true, shadow=true})
	place("SS_LightsRed", core, cf, S, rgb(255,50,50), {decor=true, mat=NEON})
	place("SS_LightsGreen", core, cf, S, rgb(60,255,110), {decor=true, mat=NEON})
	place("SS_TopLight", core, cf, S, LIT, {decor=true, mat=NEON})
end
local function plotCF(i)
	local phi = math.rad((i-1)*45)
	local pos = Vector3.new(R_PLOT*math.sin(phi), TOP-4, R_PLOT*math.cos(phi))
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end
local function buildPlot(parent, i)
	local info = PLOTS[i]; local color = info[2]
	local phi = math.rad((i-1)*45)
	local pos = Vector3.new(R_PLOT*math.sin(phi), TOP-4, R_PLOT*math.cos(phi))
	local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local plot = model("StationPlot"..i, parent)
	plot:SetAttribute("StationName", info[1].." Station"); plot:SetAttribute("UnlockedTier", 0)
	plot:SetAttribute("Capacity", TIER_CAP[0]); plot:SetAttribute("TierCapacities", "4,10,18,26")
	local S = 10
	local core = model("Core", plot)
	place("Station_Pad", core, cf, S, rgb(245,247,255), {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Station_PadGlow", core, cf, S, color, {decor=true, mat=NEON})
	buildCoreStation(core, cf, color)
	local slot = 0
	local function pods(container, n, r, offsetDeg)
		for k = 0, n-1 do
			local a = math.rad(offsetDeg + k*360/n)
			local pcf = cf * CFrame.new(r*math.sin(a), 4, r*math.cos(a)) * CFrame.Angles(0, a, 0)
			local pod = model("PetPod", container)
			local base = place("Pod_Base", pod, pcf, S, color, {})
			place("Pod_Cushion", pod, pcf, S, color:Lerp(Color3.new(1,1,1), 0.6), {decor=true})
			place("Pod_Arch", pod, pcf, S, rgb(255,205,60), {decor=true})
			slot += 1
			local att = Instance.new("Attachment"); att.Name = "PetSlot"; att.Position = Vector3.new(0, 1.2, 0); att.Parent = base
			pod:SetAttribute("SlotIndex", slot)
		end
	end
	pods(core, 4, 30, 45)
	-- entry path inside plot (hidden under decks once unlocked)
	local inner, outer = 44, 140
	block("EntryPath", plot, Vector3.new(16, 2, outer-inner), cf * CFrame.new(0, TOP-0.2-1-(TOP-4), -(inner+outer)/2) , rgb(255,236,170), {})
	local store = game:GetService("ServerStorage"):FindFirstChild("StationTierCache") or Instance.new("Folder")
	store.Name = "StationTierCache"; store.Parent = game:GetService("ServerStorage")
	local pstore = store:FindFirstChild(plot.Name); if pstore then pstore:Destroy() end
	pstore = Instance.new("Folder"); pstore.Name = plot.Name; pstore.Parent = store
	local podPlan = {{6,64,30},{8,96,22.5},{8,123,22.5}}
	for t = 1, 3 do
		local tier = model("Tier"..t, plot); tier:SetAttribute("Tier", t); tier:SetAttribute("Capacity", TIER_CAP[t])
		local outline = model("LockedOutline"..t, pstore)
		for k = 0, 11 do
			local scf = cf * CFrame.Angles(0, math.rad(30*k), 0)
			place("Deck_Tier"..t, tier, scf, S, t % 2 == 1 and DECK_A or DECK_B, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
			place("DeckRail_Tier"..t, tier, scf, S, color, {decor=true, mat=NEON})
			place("DeckRail_Tier"..t, outline, scf * CFrame.new(0, -1.0, 0), S, color, {decor=true, mat=NEON, transparency=0.45, name="LockedRail"})
		end
		pods(tier, podPlan[t][1], podPlan[t][2], podPlan[t][3])
		local rMid = ({64, 96, 123})[t]
		local hint = block("UpgradeHint", outline, Vector3.new(1,1,1), cf * CFrame.new(rMid*math.sin(math.rad(150)), 10, rMid*math.cos(math.rad(150))), color, {decor=true, transparency=1})
		billboard(hint, "🔒 Upgrade: +"..(TIER_CAP[t]-TIER_CAP[t-1]).." pets", color, UDim2.fromOffset(170, 34), 160, 3)
	end
	local tag = block("NameTag", plot, Vector3.new(1,1,1), cf * CFrame.new(0, 72, 0), color, {decor=true, transparency=1})
	billboard(tag, info[1].." Station", color, UDim2.fromOffset(220, 50), 320, 0)
	local region = block("PlotRegion", plot, Vector3.new(272, 60, 272), cf * CFrame.new(0, 30, 0), color, {decor=true, transparency=1})
	plot.PrimaryPart = region
	return plot
end

function M.Build(kitFolder, opts)
	opts = opts or {}
	kit = {}
	for _, d in ipairs(kitFolder:GetDescendants()) do if d:IsA("BasePart") and B[d.Name] then kit[d.Name] = d end end
	local old = workspace:FindFirstChild("JetpackPetRescueMap")
	local rng = Random.new(opts.seed or 4242)
	local map = model(opts.name or "JetpackPetRescueMap_New", workspace)
	local station = model("SpaceStation", map)

	-- HOME WORLD ------------------------------------------------------
	local home = model("SharedPlanet", station)
	buildPlanetBody(home, Vector2.new(0,0), Y0, 79.5, HOME, "Home")
	-- SPAWN HUB --------------------------------------------------------
	local hub = model("SpawnHub", station)
	block("PlazaRim", hub, Vector3.new(2, 194, 194), CFrame.new(0, Y0, 0) * CFrame.Angles(0,0,math.rad(90)), rgb(255,205,70), {shape=Enum.PartType.Cylinder})
	block("Plaza", hub, Vector3.new(2, 178, 178), CFrame.new(0, Y0+0.05, 0) * CFrame.Angles(0,0,math.rad(90)), rgb(250,247,240), {shape=Enum.PartType.Cylinder})
	block("PlazaStar", hub, Vector3.new(2, 60, 60), CFrame.new(0, Y0+0.1, 0) * CFrame.Angles(0,0,math.rad(90)), rgb(185,165,255), {shape=Enum.PartType.Cylinder})
	block("RocketPedestal", hub, Vector3.new(5, 34, 34), CFrame.new(0, TOP+2.5, 0) * CFrame.Angles(0,0,math.rad(90)), rgb(110,100,255), {shape=Enum.PartType.Cylinder, shadow=true})
	local rocket = model("HeroRocket", hub)
	local rcf = CFrame.new(0, TOP+5+14, 0)
	place("Rocket_Body", rocket, rcf, 10, rgb(250,250,255), {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Rocket_Nose", rocket, rcf, 10, rgb(255,70,95), {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Rocket_Nozzle", rocket, rcf, 10, rgb(200,205,230), {decor=true})
	place("Rocket_Fins", rocket, rcf, 10, rgb(255,70,95), {fidelity=Enum.CollisionFidelity.Box, shadow=true})
	place("Rocket_WindowRing", rocket, rcf, 10, rgb(255,205,60), {decor=true})
	place("Rocket_Window", rocket, rcf, 10, rgb(120,220,255), {decor=true, mat=NEON})
	place("Rocket_Flame", rocket, rcf, 10, rgb(255,170,30), {decor=true, mat=NEON})
	for k = 0, 11 do
		local a = math.rad(k*30 + 15)
		lamp(hub, CFrame.new(math.sin(a)*90, TOP, math.cos(a)*90), 6, PLOTS[(k % 8)+1][2])
	end
	-- PATHS ------------------------------------------------------------
	local paths = model("Walkways", station)
	for i = 1, 8 do
		local phi = math.rad((i-1)*45)
		local dir = Vector3.new(math.sin(phi), 0, math.cos(phi))
		local r0, r1 = 95, R_PLOT - 140
		local mid = dir * ((r0+r1)/2) + Vector3.new(0, Y0, 0)
		local pcf = CFrame.lookAt(mid, mid + dir)
		block("Walkway", paths, Vector3.new(16, 2, r1-r0), pcf, rgb(255,236,170), {})
		for side = -1, 1, 2 do
			block("WalkwayGlow", paths, Vector3.new(1.2, 2.1, r1-r0), pcf * CFrame.new(side*8.4, 0.05, 0), PLOTS[i][2], {decor=true, mat=NEON})
		end
		for k = 1, 4 do
			local side = (k % 2 == 0) and 1 or -1
			lamp(paths, pcf * CFrame.new(side*13, 0, (r1-r0)/2 - k*(r1-r0)/5), 5, PLOTS[i][2])
		end
	end
	-- PLOTS ------------------------------------------------------------
	for i = 1, 8 do buildPlot(station, i) end
	-- HOME DECOR -------------------------------------------------------
	local deco = model("HomeDecor", station)
	local function avoidHome(v)
		local r = v.Magnitude
		if r < 120 then return true end
		for i = 1, 8 do
			local phi = math.rad((i-1)*45)
			local c = Vector2.new(R_PLOT*math.sin(phi), R_PLOT*math.cos(phi))
			if (v - c).Magnitude < 160 then return true end
			local d = Vector2.new(math.sin(phi), math.cos(phi))
			local along = v:Dot(d); local perp = math.abs(v.X*d.Y - v.Y*d.X)
			if along > 0 and along < R_PLOT and perp < 26 then return true end
		end
		return false
	end
	local kinds = {"tree","tree","tree","crystal","crystal","boulder","boulder","shroom","bush","bush"}
	for _, v in ipairs(scatter(rng, 85, 120, 600, 38, avoidHome)) do
		prop(pick(rng, kinds), deco, CFrame.new(v.X, Y0, v.Y), rng:NextNumber(5, 9), HOME, rng)
	end
	for k = 0, 47 do
		local a = k/48*math.pi*2 + rng:NextNumber(-0.04, 0.04)
		local r = 628
		place("Rock_Boulder", deco, CFrame.new(math.sin(a)*r, Y0 + 4, math.cos(a)*r) * yaw(rng), rng:NextNumber(14, 22), HOME.rock:Lerp(Color3.new(1,1,1), 0.15), {fidelity=Enum.CollisionFidelity.Hull, name="RimRock"})
	end
	-- PLANETS ----------------------------------------------------------
	if old then
		for _, oldPlanet in ipairs(old:GetChildren()) do
			local th = THEMES[oldPlanet.Name]
			if th then
				local surf = oldPlanet:FindFirstChild("ExplorationSurface")
				local topY = surf.Position.Y + surf.Size.X/2
				local c2 = Vector2.new(surf.Position.X, surf.Position.Z)
				local planet = model(oldPlanet.Name, map)
				local origin = buildPlanetBody(planet, c2, topY, 33, th, "Planet")
				-- carry gameplay over (eggs keep their prompts + attributes)
				local avoid = {}
				for _, ch in ipairs(oldPlanet:GetChildren()) do
					local keep = ch.Name == "DiscoverableEggs" or ch.Name == "PlanetNameSign" or ch.Name == "PetRestingSpot" or ch.Name:match("^RescueDisplayPet")
					if keep then
						local item = opts.moveGameplay and ch or ch:Clone()
						item.Parent = planet
						for _, d in ipairs(item:IsA("BasePart") and {item} or item:GetDescendants()) do
							if d:IsA("BasePart") then table.insert(avoid, Vector2.new(d.Position.X, d.Position.Z) - c2) end
						end
						if ch.Name == "PlanetNameSign" then item.Material = SP; item.Color = th.rock:Lerp(Color3.new(0,0,0),0.25) end
						if ch.Name == "PetRestingSpot" then item.Material = SP; item.Color = th.accent end
					end
				end
				local decor = model("Decor", planet)
				local function avoidP(v) for _, q in ipairs(avoid) do if (q - v).Magnitude < 20 then return true end end return false end
				for _, v in ipairs(scatter(rng, 34, 20, 238, 24, avoidP)) do
					prop(pick(rng, th.props), decor, CFrame.new(c2.X + v.X, topY, c2.Y + v.Y), rng:NextNumber(4, 7.5), th, rng)
				end
				if th.ring then
					place("PlanetRing_Band", decor, CFrame.new(c2.X, topY - 318, c2.Y) * CFrame.Angles(math.rad(14), 0, math.rad(8)), 26, rgb(255,215,90), {decor=true, transparency=0.15})
				end
			end
		end
		-- asteroids replace the old floating rocks one-for-one
		local sky = model("SpaceScenery", map)
		local oldSky = old:FindFirstChild("SpaceScenery")
		if oldSky then
			local pal = {rgb(150,120,220), rgb(120,140,230), rgb(200,130,210), rgb(110,100,180)}
			for _, a in ipairs(oldSky:GetChildren()) do
				if a:IsA("BasePart") then
					local s = math.max(a.Size.X, a.Size.Y, a.Size.Z) / 2.38
					place("Rock_Boulder", sky, CFrame.new(a.Position) * CFrame.Angles(rng:NextNumber(0,6), rng:NextNumber(0,6), 0), s, pick(rng, pal), {fidelity=Enum.CollisionFidelity.Box, name="FloatingAsteroid"})
				end
			end
		end
	end
	return map
end
function M.RestyleStations(kitFolder)
	kit = {}
	for _, d in ipairs(kitFolder:GetDescendants()) do if d:IsA("BasePart") and B[d.Name] then kit[d.Name] = d end end
	local st = workspace.JetpackPetRescueMap.SpaceStation
	local cache = game:GetService("ServerStorage"):FindFirstChild("StationTierCache")
	local OLD = {Station_Dome=true, Station_Trim=true, Station_DoorArch=true, Station_Antenna=true, Station_Beacon=true}
	for i = 1, 8 do
		local plot = st:FindFirstChild("StationPlot"..i)
		local core = plot and plot:FindFirstChild("Core")
		if core then
			for _, c in ipairs(core:GetChildren()) do if OLD[c.Name] or c.Name:match("^SS_") then c:Destroy() end end
			buildCoreStation(core, plotCF(i), PLOTS[i][2])
			local tag = plot:FindFirstChild("NameTag"); if tag then tag.CFrame = plotCF(i) * CFrame.new(0, 72, 0) end
			local holders = {plot, cache and cache:FindFirstChild(plot.Name)}
			for _, h in ipairs(holders) do
				for _, d in ipairs(h:GetDescendants()) do
					if d.Name:match("^Deck_Tier%d") then d.Color = (tonumber(d.Name:sub(-1)) % 2 == 1) and DECK_A or DECK_B end
				end
			end
		end
	end
end
return M
