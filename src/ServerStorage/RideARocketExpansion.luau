-- RideARocketExpansion: edits to the base built by RideARocketBaseBuilder.
-- Grows the spawn plaza, pushes the perimeter wall out, and adds a farm behind every station.
-- Run from Studio's command bar (edit mode, not Play):
--   require(game.ServerStorage.RideARocketExpansion).Apply()
-- Every step is safe to repeat, so running a newer version over an older one updates it in place
-- (v2 rebuilds the farms 15% bigger and moves the wall to fit them).
local VERSION = 2
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SP, NEON, GROUND = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Ground
local C = {
 white=rgb(240,243,248), light=rgb(200,206,216), navy=rgb(28,38,74), blue=rgb(70,160,255),
 soil=rgb(112,80,58), furrow=rgb(86,60,44), stem=rgb(80,200,95), leaf=rgb(60,175,85),
}
local BERRY = {rgb(255,120,220), rgb(110,230,255), rgb(255,230,110)}
-- Layout of the existing base (matches RideARocketBaseBuilder)
local Y0 = 8
local R_PLOT = 272
local PLOT_R = 81.6
-- New layout
local HUB_R = 80             -- spawn plaza radius (was 50)
local FARM_W = 110          -- farm width along the wall
local FARM_DEPTH = 51        -- farm depth from station to wall
local FARM_GAP = 4           -- space between a station's outer edge and its farm
local WALL_GAP = 8           -- space between a farm and the wall
local WALL_APOTHEM = R_PLOT + PLOT_R + FARM_GAP + FARM_DEPTH + WALL_GAP -- ~417 (was ~385.5); lowered if the ground runs out
local GROUND_EDGE = 429      -- radius where the planet's top ends
local ROW_SPACING, CROP_SPACING = 5.5, 8

local M = {}
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
local function parts(inst)
	local out = {}
	if inst:IsA("BasePart") then table.insert(out, inst) end
	for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then table.insert(out, d) end end
	return out
end
local function shift(inst, offset) for _, p in ipairs(parts(inst)) do p.CFrame = p.CFrame + offset end end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function anchorPos(inst) local ps = parts(inst); return ps[1] and ps[1].CFrame.Position end
local function plotDir(i) local phi = math.rad((i-1)*45); return Vector3.new(math.sin(phi), 0, math.cos(phi)) end

-- Studio only: is there flat ground all the way round at radius r?
local function groundAt(surface, r)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {surface}
	for k = 0, 23 do
		local a = k * math.pi / 12
		local hit = workspace:Raycast(Vector3.new(math.sin(a)*r, Y0 + 30, math.cos(a)*r), Vector3.new(0, -80, 0), params)
		if not hit or math.abs(hit.Position.Y - Y0) > 1.5 then return false end
	end
	return true
end

local function growHub(station, hubR)
	local hub = station.SpawnHub
	local oldR = (hub.PlazaRim.Size.Y - 6) / 2
	local d = hubR - oldR
	for _, name in ipairs({"PlazaRim", "PlazaGlow", "Plaza"}) do
		local p = hub[name]; p.Size = p.Size + Vector3.new(0, 2*d, 2*d)
	end
	for _, f in ipairs(hub:GetChildren()) do
		if f.Name == "Floodlight" then shift(f, flat(anchorPos(f)).Unit * d) end
	end
	-- Walkways now start at the bigger plaza's edge: shorten each piece from the hub end
	for _, w in ipairs(station.Walkways:GetChildren()) do
		if w:IsA("BasePart") then
			local dir = flat(w.CFrame.LookVector).Unit
			w.Size = w.Size - Vector3.new(0, 0, d)
			w.CFrame = w.CFrame + dir * (d/2)
		elseif w.Name == "Floodlight" then
			local pos = flat(anchorPos(w))
			local best, dir = -2, nil
			for i = 1, 8 do local v = plotDir(i); local dot = v:Dot(pos.Unit); if dot > best then best, dir = dot, v end end
			local oldMid = (oldR + 3 + R_PLOT - PLOT_R - 2) / 2
			local side = (pos:Dot(dir) > oldMid) and 1 or -1
			shift(w, dir * (d/2 - side*0.18*d))
		end
	end
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn then
		spawn.Size = Vector3.new(32, spawn.Size.Y, 32)
		spawn.CFrame = CFrame.new(0, spawn.CFrame.Y, hubR*0.55)
	end
	return oldR
end

local function pushWall(station, apothem)
	local wall = station.PerimeterWall
	local oldApothem = flat(wall:FindFirstChildWhichIsA("Model").Border_Plinth.CFrame.Position).Magnitude
	local k = apothem / oldApothem
	for _, p in ipairs(parts(wall)) do
		local pos = p.CFrame.Position
		p.CFrame = CFrame.new(pos.X*k, pos.Y, pos.Z*k) * (p.CFrame - pos)
		if p.Name ~= "Border_Pillar" and p.Name ~= "Border_PillarLight" then
			p.Size = Vector3.new(p.Size.X*k, p.Size.Y, p.Size.Z)
		end
	end
	-- Outside rocks: squeeze their band into the strip between the wall and the planet's edge
	local rocks, minR, maxR = {}, math.huge, 0
	for _, rock in ipairs(station.OutsideRocks:GetChildren()) do
		if rock:IsA("BasePart") then
			local r = flat(rock.CFrame.Position).Magnitude
			table.insert(rocks, rock); minR = math.min(minR, r); maxR = math.max(maxR, r)
		end
	end
	local lo = apothem + 5
	local hi = math.max(lo, math.min(apothem + 17, GROUND_EDGE))
	for _, rock in ipairs(rocks) do
		local pos = flat(rock.CFrame.Position)
		local t = maxR > minR and (pos.Magnitude - minR) / (maxR - minR) or 0.5
		rock.CFrame = rock.CFrame + pos.Unit * (lo + t*(hi - lo) - pos.Magnitude)
	end
end

local function buildFarm(plot, i, inner, outer)
	local dir = plotDir(i)
	local depth = outer - inner
	local center = dir * ((inner + outer)/2) + Vector3.new(0, Y0, 0)
	local fcf = CFrame.lookAt(center, center + dir) -- -Z points out to the wall, +Z back to the station
	local farm = model("Farm", plot)
	farm:SetAttribute("Station", plot:GetAttribute("StationName"))
	block("Soil", farm, Vector3.new(FARM_W, 0.8, depth), fcf * CFrame.new(0, 0.4, 0), C.soil, {mat=GROUND})
	local crops = model("Crops", farm)
	local rows = math.floor((depth - 6) / ROW_SPACING)
	local perRow = math.floor((FARM_W - 8) / CROP_SPACING) + 1
	local slot = 0
	for r = 0, rows - 1 do
		local z = -((rows - 1) * ROW_SPACING)/2 + r * ROW_SPACING
		block("Furrow", farm, Vector3.new(FARM_W - 6, 0.5, 2.6), fcf * CFrame.new(0, 1.05, z), C.furrow, {mat=GROUND})
		for c = 0, perRow - 1 do
			local x = -((perRow - 1) * CROP_SPACING)/2 + c * CROP_SPACING
			local base = fcf * CFrame.new(x, 1.3, z)
			local crop = model("Crop", crops)
			slot += 1; crop:SetAttribute("CropSlot", slot)
			block("Stem", crop, Vector3.new(0.35, 2.2, 0.35), base * CFrame.new(0, 1.1, 0), C.stem, {decor=true})
			block("Leaf", crop, Vector3.new(1.8, 0.15, 0.6), base * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(35 + 40*(c % 3)), math.rad(12)), C.leaf, {decor=true})
			block("Berry", crop, Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 2.5, 0), BERRY[r % #BERRY + 1], {decor=true, mat=NEON, shape=Enum.PartType.Ball})
		end
	end
	-- Fence on all four sides, with a gate facing the station
	local fence = model("Fence", farm)
	local hw, hd, gate = FARM_W/2, depth/2, 7
	local function rail(a, b)
		local mid, len = (a + b)/2, (b - a).Magnitude
		local cf = fcf * CFrame.lookAt(mid, b)
		block("Rail", fence, Vector3.new(0.4, 0.4, len), cf * CFrame.new(0, 1.4, 0), C.white, {})
		block("Rail", fence, Vector3.new(0.4, 0.4, len), cf * CFrame.new(0, 2.6, 0), C.white, {})
		block("RailLight", fence, Vector3.new(0.25, 0.15, len), cf * CFrame.new(0, 2.85, 0), C.blue, {decor=true, mat=NEON})
		local n = math.max(1, math.floor(len / 8 + 0.5))
		for k = 0, n do
			block("Post", fence, Vector3.new(0.8, 3.2, 0.8), fcf * CFrame.new(a:Lerp(b, k/n)) * CFrame.new(0, 1.6, 0), C.light, {})
		end
	end
	local corners = {Vector3.new(-hw, 0, -hd), Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd)}
	rail(corners[1], corners[2]); rail(corners[2], corners[3]); rail(corners[4], corners[1])
	rail(corners[3], Vector3.new(gate, 0, hd)); rail(Vector3.new(-gate, 0, hd), corners[4])
	-- Sign over the gate
	for side = -1, 1, 2 do
		block("GatePost", fence, Vector3.new(1, 7, 1), fcf * CFrame.new(side*gate, 3.5, hd), C.navy, {})
	end
	local sign = block("GateSign", fence, Vector3.new(gate*2 + 1, 1.6, 0.4), fcf * CFrame.new(0, 7.2, hd), C.navy, {})
	block("GateSignGlow", fence, Vector3.new(gate*2 + 1.2, 0.2, 0.5), fcf * CFrame.new(0, 6.3, hd), C.blue, {decor=true, mat=NEON})
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Back; gui.LightInfluence = 0; gui.Parent = sign
	local label = Instance.new("TextLabel"); label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
	label.Text = "FARM"; label.TextScaled = true; label.Font = Enum.Font.GothamBlack; label.TextColor3 = C.white; label.Parent = gui
	return farm, fcf
end

-- Remove scattered decor that would sit inside the new plaza or a farm
local function clearDecor(station, hubR, farmBoxes)
	for _, d in ipairs(station.BaseDecor:GetChildren()) do
		local pos = anchorPos(d)
		if not pos then continue end
		local remove = flat(pos).Magnitude < hubR + 14
		for _, box in ipairs(farmBoxes) do
			local l = box.cf:PointToObjectSpace(Vector3.new(pos.X, box.cf.Position.Y, pos.Z))
			if math.abs(l.X) < box.w/2 + 8 and math.abs(l.Z) < box.d/2 + 8 then remove = true end
		end
		if remove then d:Destroy() end
	end
end

function M.Apply(opts)
	opts = opts or {}
	local station = workspace.JetpackPetRescueMap.SpaceStation
	if (station:GetAttribute("ExpansionVersion") or 0) >= VERSION and not opts.force then
		warn("RideARocketExpansion: already applied to this place"); return
	end
	local hubR = opts.hubRadius or HUB_R
	local apothem = opts.wallApothem or WALL_APOTHEM
	-- Pull the wall in if the planet's flat top ends before the target. Skipped when the probe
	-- can't even see the ground inside the current wall (e.g. the surface isn't queryable).
	local target = apothem
	pcall(function()
		local surface = station.SharedPlanet.HomeSurface
		if not groundAt(surface, 380) then return end
		while apothem > 392 and not groundAt(surface, apothem + 4) do apothem -= 2 end
	end)
	if apothem < target then warn(("RideARocketExpansion: flat ground ends early, wall placed at %d"):format(apothem)) end
	local recording
	pcall(function() recording = game:GetService("ChangeHistoryService"):TryBeginRecording("Expand space base") end)

	growHub(station, hubR)
	pushWall(station, apothem)
	local inner, outer = R_PLOT + PLOT_R + FARM_GAP, apothem - WALL_GAP
	local boxes = {}
	for i = 1, 8 do
		local plot = station:FindFirstChild("StationPlot"..i)
		if plot then
			local old = plot:FindFirstChild("Farm")
			if old then old:Destroy() end
			local _, fcf = buildFarm(plot, i, inner, outer)
			table.insert(boxes, {cf=fcf, w=FARM_W, d=outer - inner})
		end
	end
	clearDecor(station, hubR, boxes)
	station:SetAttribute("ExpansionVersion", VERSION)

	if recording then
		pcall(function() game:GetService("ChangeHistoryService"):FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
	end
	print(("RideARocketExpansion: plaza radius %d, wall at %d, %d farms (%d studs deep)"):format(hubR, apothem, #boxes, outer - inner))
end
return M
