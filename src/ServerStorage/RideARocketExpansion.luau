-- RideARocketExpansion: edits to the base built by RideARocketBaseBuilder.
-- Grows the spawn plaza, pushes the perimeter wall out, and adds a fenced pet pen behind every station:
-- a Model "PetPen" in each StationPlot with a grass "Floor" part (its CFrame is the pen's frame, its top
-- is the ground the pets walk on) and an opening in the fence facing the station. The station owner's
-- equipped pets roam inside it (StarterPlayerScripts.PetPens builds them on every device).
-- Run from Studio's command bar (edit mode, not Play):
--   require(game.ServerStorage.RideARocketExpansion).Apply()
-- Every step is safe to repeat, so running a newer version over an older one updates it in place
-- (v2 rebuilt the farms 15% bigger; v3 rebuilt them without the FARM gate sign; v4 turns the farms into
-- pet pens: the crops are gone and the soil is a grass floor). Positions are measured from wherever the
-- base really is (found from the spawn plaza), so it still works after the whole station has been moved.
-- Decorations from RideARocketMapDetailer that stand inside a pen are moved (not deleted) to
-- ServerStorage.RemovedMapBackups.Decor_InPetPens. If you re-run the detailer, run
-- Apply({force = true}) afterwards to clear its new ones out of the pens.
-- Rocks, trees and other decorations standing on a walkway are slid sideways off it. That step also
-- runs on its own, without touching anything else:
--   require(game.ServerStorage.RideARocketExpansion).ClearPaths()
local VERSION = 4
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local SP, NEON, GRASS = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Grass
local C = {
 white=rgb(240,243,248), light=rgb(200,206,216), blue=rgb(70,160,255),
 pen=rgb(128,196,94), -- a little lighter than the detailer's Earth grass (88,160,72), so the pens stand out
}
-- Layout of the existing base (matches RideARocketBaseBuilder). These are measured from the base's
-- own origin, so the base can have been moved anywhere: Apply finds it from the spawn plaza (O below).
local Y0 = 8
local R_PLOT = 272
local PLOT_R = 81.6
-- New layout
local HUB_R = 80             -- spawn plaza radius (was 50)
local PEN_W = 110            -- pen width along the wall
local PEN_GAP = 4            -- space between a station's outer edge and its pen
local WALL_GAP = 8           -- space between a pen and the wall
local WALL_APOTHEM = 410     -- wall distance from the base centre (was ~385.5); sits at the green edge of the planet
local GROUND_EDGE = 429      -- radius where the planet's top ends
local GATE = 7               -- half the width of the opening in the fence facing the station
local BACKUP = "Decor_InPetPens"

local M = {}
-- Where the base actually is: the point the base builder called (0, 0, 0). The plaza rim is built centred
-- at (0, Y0, 0), so this is its centre minus Y0. Set by Apply before anything else runs.
local O = Vector3.new(0, 0, 0)
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
-- Is pos (seen from above) inside a pen box, or within margin studs of it?
local function inBox(pos, box, margin)
	local l = box.cf:PointToObjectSpace(Vector3.new(pos.X, box.cf.Position.Y, pos.Z))
	return math.abs(l.X) < box.w/2 + margin and math.abs(l.Z) < box.d/2 + margin
end

local function growHub(station, hubR)
	local hub = station.SpawnHub
	local oldR = (hub.PlazaRim.Size.Y - 6) / 2
	local d = hubR - oldR
	for _, name in ipairs({"PlazaRim", "PlazaGlow", "Plaza"}) do
		local p = hub[name]; p.Size = p.Size + Vector3.new(0, 2*d, 2*d)
	end
	for _, f in ipairs(hub:GetChildren()) do
		if f.Name == "Floodlight" then shift(f, flat(anchorPos(f) - O).Unit * d) end
	end
	-- Walkways now start at the bigger plaza's edge: shorten each piece from the hub end
	for _, w in ipairs(station.Walkways:GetChildren()) do
		if w:IsA("BasePart") then
			local dir = flat(w.CFrame.LookVector).Unit
			w.Size = w.Size - Vector3.new(0, 0, d)
			w.CFrame = w.CFrame + dir * (d/2)
		elseif w.Name == "Floodlight" then
			local pos = flat(anchorPos(w) - O)
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
		spawn.CFrame = CFrame.new(O.X, O.Y + Y0 + 2.3, O.Z + hubR*0.55) -- on the plaza, wherever the base is
	end
	return oldR
end

local function pushWall(station, apothem)
	local wall = station.PerimeterWall
	local oldApothem = flat(wall:FindFirstChildWhichIsA("Model").Border_Plinth.CFrame.Position - O).Magnitude
	local k = apothem / oldApothem
	for _, p in ipairs(parts(wall)) do
		local pos = p.CFrame.Position
		p.CFrame = CFrame.new(O.X + (pos.X - O.X)*k, pos.Y, O.Z + (pos.Z - O.Z)*k) * (p.CFrame - pos)
		if p.Name ~= "Border_Pillar" and p.Name ~= "Border_PillarLight" then
			p.Size = Vector3.new(p.Size.X*k, p.Size.Y, p.Size.Z)
		end
	end
	-- Outside rocks: squeeze their band into the strip between the wall and the planet's edge
	local rocks, minR, maxR = {}, math.huge, 0
	for _, rock in ipairs(station.OutsideRocks:GetChildren()) do
		if rock:IsA("BasePart") then
			local r = flat(rock.CFrame.Position - O).Magnitude
			table.insert(rocks, rock); minR = math.min(minR, r); maxR = math.max(maxR, r)
		end
	end
	local lo = apothem + 5
	local hi = math.max(lo, math.min(apothem + 17, GROUND_EDGE))
	for _, rock in ipairs(rocks) do
		local pos = flat(rock.CFrame.Position - O)
		local t = maxR > minR and (pos.Magnitude - minR) / (maxR - minR) or 0.5
		rock.CFrame = rock.CFrame + pos.Unit * (lo + t*(hi - lo) - pos.Magnitude)
	end
end

local function buildPen(plot, i, inner, outer)
	local dir = plotDir(i)
	local depth = outer - inner
	local center = O + dir * ((inner + outer)/2) + Vector3.new(0, Y0, 0)
	local fcf = CFrame.lookAt(center, center + dir) -- -Z points out to the wall, +Z back to the station
	local pen = model("PetPen", plot)
	pen:SetAttribute("Station", plot:GetAttribute("StationName"))
	local floor = block("Floor", pen, Vector3.new(PEN_W, 0.8, depth), fcf * CFrame.new(0, 0.4, 0), C.pen, {mat=GRASS})
	pen.PrimaryPart = floor
	-- Fence on all four sides, with an opening facing the station
	local fence = model("Fence", pen)
	local hw, hd = PEN_W/2, depth/2
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
	rail(corners[3], Vector3.new(GATE, 0, hd)); rail(Vector3.new(-GATE, 0, hd), corners[4])
	return pen, fcf
end

-- RideARocketMapDetailer gives the fence posts and rails a metal finish and keeps the old material in an
-- "OriginalMaterial" attribute. A rebuilt pen copies those finishes from the old farm or pen, attribute
-- and all, so the detailer's Revert() still works on it.
local function detailerLooks(old, looks)
	for _, p in ipairs(parts(old)) do
		if p:GetAttribute("OriginalMaterial") ~= nil then looks[p.Name] = p.Material end
	end
end
local function keepLooks(pen, looks)
	for _, p in ipairs(parts(pen)) do
		local material = looks[p.Name]
		if material and p.Material ~= material then
			p:SetAttribute("OriginalMaterial", p.Material.Name)
			p.Material = material
		end
	end
end

-- Remove scattered decor that would sit inside the new plaza or a pen
local function clearDecor(station, hubR, penBoxes)
	for _, d in ipairs(station.BaseDecor:GetChildren()) do
		local pos = anchorPos(d)
		if not pos then continue end
		local remove = flat(pos - O).Magnitude < hubR + 14
		for _, box in ipairs(penBoxes) do
			if inBox(pos, box, 8) then remove = true end
		end
		if remove then d:Destroy() end
	end
end

-- RideARocketMapDetailer's trees, bushes, ponds, rocks and flowers (its "Detail" folders) that stand
-- inside a pen would poke through the floor, and the pets would walk through them. Move them (not
-- delete) to ServerStorage.RemovedMapBackups.Decor_InPetPens. Only things on the planet's top count:
-- the continents and clouds under Earth are hundreds of studs lower.
local function centre(inst)
	local ps = parts(inst)
	if #ps == 0 then return nil end
	local sum = Vector3.new(0, 0, 0)
	for _, p in ipairs(ps) do sum = sum + p.CFrame.Position end
	return sum / #ps
end
local function moveDetailOutOfPens(station, penBoxes)
	local store, moved = nil, 0
	for _, folder in ipairs(station:GetDescendants()) do
		if folder:IsA("Folder") and folder.Name == "Detail" then
			for _, item in ipairs(folder:GetChildren()) do
				local pos = centre(item)
				if not pos or pos.Y < O.Y + Y0 - 4 or pos.Y > O.Y + Y0 + 60 then continue end
				for _, box in ipairs(penBoxes) do
					if inBox(pos, box, 1.5) then
						if not store then
							local ServerStorage = game:GetService("ServerStorage")
							local root = ServerStorage:FindFirstChild("RemovedMapBackups") or Instance.new("Folder")
							root.Name = "RemovedMapBackups"
							root.Parent = ServerStorage
							store = root:FindFirstChild(BACKUP) or Instance.new("Folder")
							store.Name = BACKUP
							store.Parent = root
						end
						item.Parent = store
						moved += 1
						break
					end
				end
			end
		end
	end
	return moved
end

-- Decorations standing on a walkway (or a station's entry path) are slid sideways just off it.
-- Only loose decor counts: the base's scattered decor and the detailer's "Detail" items on the planet
-- top, never the walkways' own trim, the plaza, the stations or the pens.
local PATH_MARGIN = 1.5      -- studs kept clear beside a path
local MAX_DECOR_RADIUS = 25  -- bigger things than this aren't loose decor
local function footprint(item)
	local c = centre(item)
	if not c then return nil end
	local r = 0
	for _, p in ipairs(parts(item)) do
		r = math.max(r, flat(p.CFrame.Position - c).Magnitude + math.max(p.Size.X, p.Size.Z) / 2)
	end
	return c, r
end
local function clearPaths(station)
	local paths = {}
	for _, p in ipairs(station.Walkways:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Walkway" then table.insert(paths, p) end
	end
	for _, d in ipairs(station:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "EntryPath" then table.insert(paths, d) end
	end
	local skip = {station.Walkways, station.SpawnHub}
	local function loose(item)
		for _, s in ipairs(skip) do if item:IsDescendantOf(s) then return false end end
		local plot = item:FindFirstAncestorWhichIsA("Model")
		while plot and plot ~= station do
			if plot.Name:match("^StationPlot%d+$") then return false end
			plot = plot.Parent
		end
		return true
	end
	local items = {}
	for _, d in ipairs(station.BaseDecor:GetChildren()) do table.insert(items, d) end
	for _, folder in ipairs(station:GetDescendants()) do
		if folder:IsA("Folder") and folder.Name == "Detail" and loose(folder) then
			for _, d in ipairs(folder:GetChildren()) do table.insert(items, d) end
		end
	end
	local moved = 0
	for _, item in ipairs(items) do
		local c, r = footprint(item)
		if not c or r > MAX_DECOR_RADIUS or c.Y < O.Y + Y0 - 4 or c.Y > O.Y + Y0 + 60 then continue end
		local shifted = false
		for _ = 1, 4 do -- moving off one path could put it on another (where paths meet)
			local hit = false
			for _, path in ipairs(paths) do
				local l = path.CFrame:PointToObjectSpace(Vector3.new(c.X, path.CFrame.Position.Y, c.Z))
				local clear = path.Size.X / 2 + r + PATH_MARGIN
				if math.abs(l.X) < clear and math.abs(l.Z) < path.Size.Z / 2 + r then
					local side = l.X >= 0 and 1 or -1
					local offset = flat(path.CFrame.RightVector).Unit * side * (clear - math.abs(l.X))
					shift(item, offset)
					c = c + offset
					hit, shifted = true, true
				end
			end
			if not hit then break end
		end
		if shifted then moved += 1 end
	end
	return moved
end
function M.ClearPaths()
	local station = workspace.JetpackPetRescueMap.SpaceStation
	O = station.SpawnHub.PlazaRim.CFrame.Position - Vector3.new(0, Y0, 0)
	local recording
	pcall(function() recording = game:GetService("ChangeHistoryService"):TryBeginRecording("Clear walkways") end)
	local moved = clearPaths(station)
	if recording then
		pcall(function() game:GetService("ChangeHistoryService"):FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
	end
	print(("RideARocketExpansion: moved %d decorations off the walkways"):format(moved))
	return moved
end

function M.Apply(opts)
	opts = opts or {}
	local station = workspace.JetpackPetRescueMap.SpaceStation
	if (station:GetAttribute("ExpansionVersion") or 0) >= VERSION and not opts.force then
		warn("RideARocketExpansion: already applied to this place"); return
	end
	O = station.SpawnHub.PlazaRim.CFrame.Position - Vector3.new(0, Y0, 0)
	local hubR = opts.hubRadius or HUB_R
	local apothem = opts.wallApothem or WALL_APOTHEM
	-- The wall goes at a fixed distance. (Probing the planet's collision shape for its edge proved
	-- unreliable: its hull doesn't follow the visible ground near the rim.) Pass {wallApothem = n} to move it.
	local recording
	pcall(function() recording = game:GetService("ChangeHistoryService"):TryBeginRecording("Expand space base") end)

	growHub(station, hubR)
	pushWall(station, apothem)
	local inner, outer = R_PLOT + PLOT_R + PEN_GAP, apothem - WALL_GAP
	local boxes = {}
	for i = 1, 8 do
		local plot = station:FindFirstChild("StationPlot"..i)
		if plot then
			-- The old farm (v1-v3) or pen (v4) goes; the new pen keeps its fence's detailer finish
			local looks = {}
			for _, old in ipairs(plot:GetChildren()) do
				if old.Name == "Farm" or old.Name == "PetPen" then detailerLooks(old, looks); old:Destroy() end
			end
			local pen, fcf = buildPen(plot, i, inner, outer)
			keepLooks(pen, looks)
			table.insert(boxes, {cf=fcf, w=PEN_W, d=outer - inner})
		end
	end
	clearDecor(station, hubR, boxes)
	local moved = moveDetailOutOfPens(station, boxes)
	local offPaths = clearPaths(station)
	station:SetAttribute("ExpansionVersion", VERSION)

	if recording then
		pcall(function() game:GetService("ChangeHistoryService"):FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
	end
	print(("RideARocketExpansion: base at (%.0f, %.0f, %.0f), plaza radius %d, wall at %d, %d pet pens (%d studs deep), %d decorations moved out of the pens, %d off the walkways")
		:format(O.X, O.Y, O.Z, hubR, apothem, #boxes, outer - inner, moved, offPaths))
end
return M
