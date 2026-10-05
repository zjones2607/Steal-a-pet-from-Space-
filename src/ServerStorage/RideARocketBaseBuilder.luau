-- RideARocketBaseBuilder v2: player-scaled space base (grey/white/navy/blue palette)
local B = {
 Planet_Rock={19.8921,17.8873,19.9464,-0.1335,-2.4436,0.1227}, Planet_Topsoil={16.1,2.4925,16.1,0,5.9538,0},
 Crystal_Cluster={2.0593,4.1,1.8054,0.0631,2.05,0.1691}, Rock_Boulder={2.3841,1.5531,1.9709,-0.043,-0.0143,-0.0482},
 Station_Pad={9,0.4,9,0,0.2,0}, Station_PadGlow={9.12,0.1,9.12,0,0.17,0},
 Deck_Tier1={4.2163,0.4,4.1,6.0919,0.2,-2.05}, Deck_Tier2={3.8986,0.4,5.5,9.0507,0.2,-2.75}, Deck_Tier3={4.0737,0.4,6.8,11.5631,0.2,-3.4},
 DeckRail_Tier1={1.2025,0.12,4.1,7.5987,0.46,-2.05}, DeckRail_Tier2={1.5776,0.12,5.5,10.2112,0.46,-2.75}, DeckRail_Tier3={1.926,0.12,6.8,12.637,0.46,-3.4},
 Pod_Base={1.4,0.2,1.4,0,0.1,0}, Pod_Cushion={1.2,0.18,1.2,0,0.29,0}, Pod_Arch={1.32,0.66,0.1039,0,0.53,0},
 Rocket_Body={2,4.2,2,0,2.7,0}, Rocket_Nose={1.6,1.7,1.6,0,5.65,0}, Rocket_Nozzle={1.5,0.45,1.5,0,0.375,0},
 Rocket_Fins={2.4779,2.2,2.8613,0.361,1.1,0}, Rocket_WindowRing={0.84,0.84,0.12,0,3.4,1.05}, Rocket_Window={0.66,0.66,0.05,0,3.4,0.985},
 Rocket_Flame={1.1,1.55,1.1,0,-0.625,0},
 SS_Hub={2.8,4.7,2.8,0,2.75,0}, SS_Bands={2.47,3.36,2.47,0,2.78,0}, SS_Windows={2.4585,2.49,2.48,0,2.975,0},
 SS_Ring={8.12,0.92,8.12,0,2.4,0}, SS_RingWindows={8.1195,0.2,8.1195,0,2.4,0}, SS_RingStripe={7.675,0.0636,7.675,0,2.8432,0},
 SS_Spokes={4.7518,0.32,4.7518,0,2.4,0}, SS_Truss={9.2,0.3,0.3,0,4.6,0}, SS_SolarPanels={8.8,2.6,0.05,0,4.6,0},
 SS_PanelFrames={8.85,3.0,0.09,0,4.6,0}, SS_Dish={1.4,0.9674,1.1294,0,5.5337,-0.1491}, SS_Airlock={1.4,1.4,1.1,0,1.05,-1.65},
 SS_Hatch={0.96,0.96,0.06,0,1.05,-2.23}, SS_HatchRim={1.12,1.12,0.09,0,1.05,-2.235}, SS_Fins={4.4,1.4,2.29,0,1.1,1.055},
 SS_LightsRed={1.5783,1.64,0.28,-3.794,5.28,0}, SS_LightsGreen={1.5783,1.64,0.28,3.794,5.28,0}, SS_TopLight={0.2092,0.22,0.22,0,5.12,0},
 Border_Wall={2.34,0.56,0.13,0,0.52,0}, Border_Frame={2.4,1.415,0.18,0,0.9075,0}, Border_Plinth={2.4,0.2,0.24,0,0.1,0},
 Border_Light={2.4,0.07,0.12,0,0.875,0.02}, Border_Glass={2.4,0.62,0.025,0,1.22,-0.005}, Border_Pillar={0.42,1.72,0.42,0,0.86,0},
 Border_PillarLight={0.22,0.17,0.2092,0,1.805,0}, Flood_Pole={0.32,1.3494,0.2946,0,0.6747,-0.0173}, Flood_Lamp={0.27,0.1085,0.0625,0,1.2283,-0.148},
 Crater_Rim={2.1,0.12,2.1,0,0.06,0}, Crater_Floor={1.4,0.008,1.4,0,0.004,0}, Crate_Body={0.5,0.5,0.5,0,0.25,0},
 Crate_Straps={0.52,0.52,0.52,0,0.25,0}, Tank_Body={1.4,0.64,0.6303,0,0.46,0}, Tank_Bands={0.8,0.66,0.65,0,0.46,0},
 Tank_Saddle={0.84,0.24,0.54,0,0.12,0}, Mast_Tower={0.52,2.4,0.4,0,1.2,0}, Mast_Light={0.1141,0.12,0.12,0,2.44,0},
}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SP, NEON = Enum.Material.SmoothPlastic, Enum.Material.Neon
local C = {
 white=rgb(240,243,248), light=rgb(200,206,216), light2=rgb(182,189,202), metal=rgb(165,172,186), grey=rgb(140,147,162),
 dark=rgb(75,80,95), black=rgb(32,34,42), navy=rgb(28,38,74), navy2=rgb(40,55,100), panel=rgb(30,65,160), blue=rgb(70,160,255),
 glow=rgb(160,215,255), glass=rgb(170,200,235), regolith=rgb(112,117,132), rock=rgb(58,62,78), boulder=rgb(92,97,112), ice=rgb(150,210,255),
}
local Y0 = 8; local TOP = Y0 + 1
local K = 0.6; local SST = 10*K
local R_PLOT = 272
local PLOT_R = 136*K
local HUB_R = 50
local WALL_N = 101; local WALL_L = 24
local WALL_R = (WALL_L/2) / math.sin(math.pi/WALL_N)
local GROUND_F = 53.4
local NAMES = {"Alpha","Bravo","Charlie","Delta","Echo","Foxtrot","Golf","Hotel"}
local TIER_CAP = {[0]=4,[1]=10,[2]=18,[3]=26}

local M = {}
M.Layout = {Y0=Y0, TOP=TOP, R_PLOT=R_PLOT, PLOT_R=PLOT_R, HUB_R=HUB_R, WALL_R=WALL_R}
local kit
local function place(name, parent, cf, s, color, opts)
	opts = opts or {}
	local srcPart = kit[name]; assert(srcPart, "Kit piece missing: "..name)
	local b = B[name]
	local p = srcPart:Clone()
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	p.Name = opts.name or name
	p.Size = Vector3.new(b[1], b[2], b[3]) * s
	p.CFrame = cf * CFrame.new(b[4]*s, b[5]*s, b[6]*s) * CFrame.Angles(0, math.pi, 0)
	p.Anchored = true; p.Color = color; p.Material = opts.mat or SP
	p.Transparency = opts.transparency or 0; p.CastShadow = opts.shadow == true
	if opts.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	else p.CanCollide = true; p.CanTouch = false end
	pcall(function() p.CollisionFidelity = opts.fidelity or Enum.CollisionFidelity.Box end)
	pcall(function() p.RenderFidelity = Enum.RenderFidelity.Automatic end)
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
local function disc(name, parent, diameter, height, topY, color, opts)
	opts = opts or {}; opts.shape = Enum.PartType.Cylinder
	return block(name, parent, Vector3.new(height, diameter, diameter), CFrame.new(0, topY - height/2, 0) * CFrame.Angles(0,0,math.rad(90)), color, opts)
end
local function model(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
local function yaw(rng) return CFrame.Angles(0, rng:NextNumber()*math.pi*2, 0) end
local function billboard(parent, text, size, maxDist)
	local g = Instance.new("BillboardGui"); g.Size = size; g.MaxDistance = maxDist; g.LightInfluence = 0; g.Parent = parent
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1,1); t.BackgroundTransparency = 1; t.Text = text
	t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = Color3.new(1,1,1); t.Parent = g
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Color = C.navy; st.Parent = t
	return g
end
local function flood(parent, cf)
	local m = model("Floodlight", parent)
	place("Flood_Pole", m, cf, 10, C.dark, {})
	place("Flood_Lamp", m, cf, 10, Color3.fromRGB(235,245,255), {decor=true, mat=NEON})
end
local function coreStation(core, cf)
	local S = SST
	place("SS_Hub", core, cf, S, C.white, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("SS_Bands", core, cf, S, C.navy, {decor=true})
	place("SS_Windows", core, cf, S, C.glow, {decor=true, mat=NEON})
	place("SS_Ring", core, cf, S, C.white, {decor=true, shadow=true})
	place("SS_RingWindows", core, cf, S, C.glow, {decor=true, mat=NEON})
	place("SS_RingStripe", core, cf * CFrame.new(0, 0.2, 0), S*1.012, C.navy, {decor=true})
	place("SS_Spokes", core, cf, S, C.grey, {decor=true})
	place("SS_Truss", core, cf, S, C.dark, {decor=true})
	place("SS_SolarPanels", core, cf, S, C.panel, {decor=true, shadow=true})
	place("SS_PanelFrames", core, cf, S, rgb(195,200,210), {decor=true})
	place("SS_Dish", core, cf, S, C.white, {decor=true, shadow=true})
	place("SS_Airlock", core, cf, S, C.white, {shadow=true})
	place("SS_Hatch", core, cf, S, C.navy, {decor=true})
	place("SS_HatchRim", core, cf, S, C.metal, {decor=true})
	place("SS_Fins", core, cf, S, C.navy, {decor=true, shadow=true})
	place("SS_LightsRed", core, cf, S, rgb(255,60,60), {decor=true, mat=NEON})
	place("SS_LightsGreen", core, cf, S, rgb(70,255,120), {decor=true, mat=NEON})
	place("SS_TopLight", core, cf, S, C.glow, {decor=true, mat=NEON})
end
local function buildPlot(parent, i, store)
	local phi = math.rad((i-1)*45)
	local pos = Vector3.new(R_PLOT*math.sin(phi), TOP-0.4*SST, R_PLOT*math.cos(phi))
	local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local plot = model("StationPlot"..i, parent)
	plot:SetAttribute("StationName", "Station "..NAMES[i]); plot:SetAttribute("UnlockedTier", 0)
	plot:SetAttribute("Capacity", TIER_CAP[0]); plot:SetAttribute("TierCapacities", "4,10,18,26")
	local core = model("Core", plot)
	place("Station_Pad", core, cf, SST, C.metal, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Station_PadGlow", core, cf * CFrame.new(0, -0.05, 0), SST*1.015, C.blue, {decor=true, mat=NEON})
	coreStation(core, cf)
	local slot = 0
	local function pods(container, n, r, offsetDeg)
		for k = 0, n-1 do
			local a = math.rad(offsetDeg + k*360/n)
			local pcf = cf * CFrame.new(r*math.sin(a), 0.4*SST, r*math.cos(a)) * CFrame.Angles(0, a, 0)
			local pod = model("PetPod", container)
			local base = place("Pod_Base", pod, pcf, SST, C.navy2, {})
			place("Pod_Cushion", pod, pcf * CFrame.new(0, 0.15, 0), SST, C.light, {decor=true})
			place("Pod_Arch", pod, pcf, SST, rgb(195,200,210), {decor=true})
			slot += 1
			local att = Instance.new("Attachment"); att.Name = "PetSlot"; att.Position = Vector3.new(0, 0.12*SST, 0); att.Parent = base
			pod:SetAttribute("SlotIndex", slot)
		end
	end
	pods(core, 4, 30*K, 45)
	local inner, outer = 44*K, 140*K
	block("EntryPath", plot, Vector3.new(10, 1, outer-inner), cf * CFrame.new(0, 0.4*SST - 0.15 - 0.5, -(inner+outer)/2), C.metal, {})
	local pstore = Instance.new("Folder"); pstore.Name = plot.Name; pstore.Parent = store
	local podPlan = {{6,64*K,30},{8,96*K,22.5},{8,123*K,22.5}}
	for t = 1, 3 do
		local tier = model("Tier"..t, plot); tier:SetAttribute("Tier", t); tier:SetAttribute("Capacity", TIER_CAP[t])
		local outline = model("LockedOutline"..t, pstore)
		for k = 0, 11 do
			local scf = cf * CFrame.Angles(0, math.rad(30*k), 0)
			place("Deck_Tier"..t, tier, scf, SST, t % 2 == 1 and C.light or C.light2, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
			place("DeckRail_Tier"..t, tier, scf, SST, C.blue, {decor=true, mat=NEON})
			place("DeckRail_Tier"..t, outline, scf * CFrame.new(0, -0.6, 0), SST, C.blue, {decor=true, mat=NEON, transparency=0.5, name="LockedRail"})
		end
		pods(tier, podPlan[t][1], podPlan[t][2], podPlan[t][3])
		local rMid = ({64, 96, 123})[t]*K
	end
	local region = block("PlotRegion", plot, Vector3.new(PLOT_R*2+2, 40, PLOT_R*2+2), cf * CFrame.new(0, 20, 0), C.white, {decor=true, transparency=1})
	plot.PrimaryPart = region
end
local function scatter(rng, n, rMin, rMax, gap, avoid, pts)
	local out, tries = {}, 0
	while #out < n and tries < n*150 do
		tries += 1
		local a = rng:NextNumber()*math.pi*2
		local r = math.sqrt(rng:NextNumber()*(rMax^2 - rMin^2) + rMin^2)
		local v = Vector2.new(math.cos(a)*r, math.sin(a)*r)
		local ok = not avoid(v)
		if ok then for _, q in ipairs(pts) do if (q - v).Magnitude < gap then ok = false break end end end
		if ok then table.insert(pts, v); table.insert(out, v) end
	end
	return out
end

function M.RebuildBase(kitFolder, opts)
	opts = opts or {}
	kit = {}
	for _, d in ipairs(kitFolder:GetDescendants()) do if d:IsA("BasePart") and B[d.Name] then kit[d.Name] = d end end
	for name in pairs(B) do assert(kit[name], "Kit piece missing: "..name) end
	local map = workspace:FindFirstChild("JetpackPetRescueMap")
	local oldStation = map:FindFirstChild("SpaceStation"); if oldStation then oldStation:Destroy() end
	local SS = game:GetService("ServerStorage")
	local oldCache = SS:FindFirstChild("StationTierCache"); if oldCache then oldCache:Destroy() end
	local store = Instance.new("Folder"); store.Name = "StationTierCache"; store.Parent = SS
	local rng = Random.new(opts.seed or 777)
	local station = model("SpaceStation", map)

	local home = model("SharedPlanet", station)
	local origin = CFrame.new(0, Y0 - 7.2*GROUND_F, 0)
	place("Planet_Rock", home, origin, GROUND_F, C.rock, {fidelity=Enum.CollisionFidelity.Hull, shadow=true, name="HomeRock"})
	place("Planet_Topsoil", home, origin, GROUND_F, C.regolith, {fidelity=Enum.CollisionFidelity.Hull, name="HomeSurface"})

	local hub = model("SpawnHub", station)
	disc("PlazaRim", hub, HUB_R*2+6, 2, TOP, C.white, {})
	disc("PlazaGlow", hub, HUB_R*2+2, 2, TOP+0.2, C.blue, {mat=NEON})
	disc("Plaza", hub, HUB_R*2-2, 2, TOP+0.4, C.navy, {})
	disc("PlazaCenterRing", hub, 38, 2, TOP+0.6, C.light, {})
	disc("PlazaCenter", hub, 35, 2, TOP+0.8, C.metal, {})
	block("RocketPedestal", hub, Vector3.new(2.5, 17, 17), CFrame.new(0, TOP+1.25, 0) * CFrame.Angles(0,0,math.rad(90)), C.dark, {shape=Enum.PartType.Cylinder, shadow=true})
	local rocket = model("HeroRocket", hub)
	local rcf = CFrame.new(0, TOP + 2.5 + 7, 0)
	place("Rocket_Body", rocket, rcf, 5, C.white, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Rocket_Nose", rocket, rcf, 5, C.navy, {fidelity=Enum.CollisionFidelity.Hull, shadow=true})
	place("Rocket_Nozzle", rocket, rcf, 5, C.navy, {decor=true})
	place("Rocket_Fins", rocket, rcf, 5, C.navy, {shadow=true})
	place("Rocket_WindowRing", rocket, rcf, 5, C.metal, {decor=true})
	place("Rocket_Window", rocket, rcf, 5, C.glow, {decor=true, mat=NEON})
	place("Rocket_Flame", rocket, rcf, 5, rgb(110,185,255), {decor=true, mat=NEON})
	for k = 0, 7 do
		local a = math.rad(k*45 + 22.5)
		local p = Vector3.new(math.sin(a)*(HUB_R-4), TOP+0.06, math.cos(a)*(HUB_R-4))
		flood(hub, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)))
	end

	local paths = model("Walkways", station)
	for i = 1, 8 do
		local phi = math.rad((i-1)*45)
		local dir = Vector3.new(math.sin(phi), 0, math.cos(phi))
		local r0, r1 = HUB_R + 3, R_PLOT - PLOT_R - 2
		local mid = dir * ((r0+r1)/2) + Vector3.new(0, Y0, 0)
		local pcf = CFrame.lookAt(mid, mid + dir)
		local len = r1 - r0
		block("Walkway", paths, Vector3.new(10, 2, len), pcf, C.metal, {})
		for side = -1, 1, 2 do
			block("WalkwayEdge", paths, Vector3.new(1.2, 2.5, len), pcf * CFrame.new(side*5.6, 0.25, 0), C.navy, {decor=true})
			block("WalkwayLight", paths, Vector3.new(0.4, 0.3, len), pcf * CFrame.new(side*3.6, 1.15, 0), C.blue, {decor=true, mat=NEON})
			local p = (pcf * CFrame.new(side*9, -1, side*len*0.18)).Position
			flood(paths, CFrame.lookAt(p, p - pcf.RightVector*side))
		end
	end

	for i = 1, 8 do buildPlot(station, i, store) end

	local border = model("PerimeterWall", station)
	local apothem = WALL_R * math.cos(math.pi/WALL_N)
	for k = 0, WALL_N-1 do
		local a = (k+0.5) * 2*math.pi/WALL_N
		local out = Vector3.new(math.sin(a), 0, math.cos(a))
		local p = out*apothem + Vector3.new(0, Y0, 0)
		local cf = CFrame.lookAt(p, p + out)
		local seg = model("WallSegment", border)
		place("Border_Plinth", seg, cf, 10, C.navy, {})
		place("Border_Frame", seg, cf, 10, C.dark, {shadow=true})
		place("Border_Wall", seg, cf, 10, C.white, {shadow=true})
		place("Border_Light", seg, cf, 10, C.blue, {decor=true, mat=NEON})
		place("Border_Glass", seg, cf, 10, C.glass, {decor=true, transparency=0.55})
		local pa = k * 2*math.pi/WALL_N
		local pp = Vector3.new(math.sin(pa)*WALL_R, Y0, math.cos(pa)*WALL_R)
		local pcf = CFrame.lookAt(pp, pp + Vector3.new(math.sin(pa), 0, math.cos(pa)))
		place("Border_Pillar", seg, pcf, 10, C.grey, {shadow=true})
		place("Border_PillarLight", seg, pcf, 10, C.blue, {decor=true, mat=NEON})
	end

	local deco = model("BaseDecor", station)
	local function avoid(v)
		local r = v.Magnitude
		if r < HUB_R + 14 or r > WALL_R - 14 then return true end
		for i = 1, 8 do
			local phi = math.rad((i-1)*45)
			local d = Vector2.new(math.sin(phi), math.cos(phi))
			if (v - d*R_PLOT).Magnitude < PLOT_R + 12 then return true end
			local along = v:Dot(d); local perp = math.abs(v.X*d.Y - v.Y*d.X)
			if along > 0 and along < R_PLOT and perp < 15 then return true end
		end
		return false
	end
	local used = {}
	local function at(v) return CFrame.new(v.X, Y0, v.Y) end
	for _, v in ipairs(scatter(rng, 14, 0, WALL_R, 30, avoid, used)) do
		local s = 10*rng:NextNumber(0.8, 1.5); local cf = at(v) * yaw(rng)
		place("Crater_Rim", deco, cf, s, rgb(128,133,148), {decor=true})
		place("Crater_Floor", deco, cf * CFrame.new(0, 0.25, 0), s, rgb(88,93,108), {decor=true})
	end
	for _, v in ipairs(scatter(rng, 10, 0, WALL_R, 30, avoid, used)) do
		local base = at(v) * yaw(rng)
		local cl = model("CargoStack", deco)
		local spots = {CFrame.new(0,0,0), CFrame.new(5.6,0,0.4), CFrame.new(0.3,0,5.7), CFrame.new(2.8,5,2.6)}
		for j = 1, rng:NextInteger(2, 4) do
			local c = base * spots[j] * CFrame.Angles(0, rng:NextNumber(-0.25,0.25), 0)
			place("Crate_Body", cl, c, 10, (j % 2 == 0) and C.light or C.white, {shadow=true})
			place("Crate_Straps", cl, c, 10, C.navy, {decor=true})
		end
		if rng:NextNumber() < 0.6 then
			local fp = (base * CFrame.new(-7, 0, -4)).Position
			local tp = (base * CFrame.new(3, 0, 3)).Position
			flood(cl, CFrame.lookAt(fp, Vector3.new(tp.X, fp.Y, tp.Z)))
		end
	end
	for _, v in ipairs(scatter(rng, 6, 0, WALL_R, 34, avoid, used)) do
		local cf = at(v) * yaw(rng); local tk = model("FuelTank", deco)
		place("Tank_Body", tk, cf, 10, C.white, {shadow=true})
		place("Tank_Bands", tk, cf, 10, C.panel, {decor=true})
		place("Tank_Saddle", tk, cf, 10, C.dark, {decor=true})
	end
	for _, v in ipairs(scatter(rng, 4, 150, WALL_R, 60, avoid, used)) do
		local cf = at(v) * yaw(rng); local mst = model("CommMast", deco)
		place("Mast_Tower", mst, cf, 10, rgb(185,190,200), {shadow=true})
		place("Mast_Light", mst, cf, 10, rgb(255,50,50), {decor=true, mat=NEON, name="BlinkLight"})
	end
	for _, v in ipairs(scatter(rng, 20, 0, WALL_R, 18, avoid, used)) do
		place("Rock_Boulder", deco, at(v) * yaw(rng) * CFrame.new(0, 0.6, 0), rng:NextNumber(2, 4), C.boulder, {})
	end
	for _, v in ipairs(scatter(rng, 10, 0, WALL_R, 22, avoid, used)) do
		place("Crystal_Cluster", deco, at(v) * yaw(rng), rng:NextNumber(1.5, 2.4), C.ice, {decor=true, mat = rng:NextNumber() < 0.5 and NEON or SP})
	end
	local outside = model("OutsideRocks", station)
	for k = 0, 55 do
		local a = k/56*math.pi*2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(WALL_R + 14, WALL_R + 38)
		place("Rock_Boulder", outside, CFrame.new(math.sin(a)*r, Y0 + 1, math.cos(a)*r) * yaw(rng), rng:NextNumber(4, 9), C.boulder:Lerp(C.rock, rng:NextNumber()), {decor=true})
	end
	return station
end

function M.TonePlanets(amount)
	local map = workspace.JetpackPetRescueMap
	for _, pl in ipairs(map:GetChildren()) do
		if pl.Name:match("Planet$") then
			for _, d in ipairs(pl:GetDescendants()) do
				local skip = d:FindFirstAncestor("DiscoverableEggs")
				local mdl = d:FindFirstAncestorWhichIsA("Model")
				if mdl and mdl.Name:match("^RescueDisplayPet") then skip = true end
				if d:IsA("BasePart") and not skip then
					local h, s, v = d.Color:ToHSV()
					d.Color = Color3.fromHSV(h, s*(1-amount), v)
				end
			end
		end
	end
end
return M
