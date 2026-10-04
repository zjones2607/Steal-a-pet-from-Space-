-- PetPens: shows the equipped pets of every claimed station roaming around the pen behind it.
-- The server (PetsAndShop) lists each player's equipped pets, with how many copies of each, in their
-- "PenPets" attribute ("astro_dog:3,comet_fox:1"), and the map (RideARocketExpansion) gives every
-- StationPlot a "PetPen" model whose flat "Floor" part is the ground inside the fence. This script
-- builds the same 3D models SpaceGUI uses (SpaceGUI.SpaceModels) on this device, one per copy, and
-- walks them around the floor, so the server never sends positions. A label above each pet shows its
-- name in its rarity colour and the coins it earns every second.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PET_SIZE = 3.5            -- studs: the longest side of each pet
local MAX_PETS = 30             -- per pen; when there are more, the best earners are the ones shown
local EDGE_MARGIN = 4           -- studs kept clear along the floor's edges, so pets stay inside the fence
local WANDER = 24               -- studs: how far one walk can take a pet
local MIN_WALK = 5              -- studs: shorter walks than this are avoided
local SPACING = 4               -- studs: pets try not to stop closer than this to each other
local WALK_SPEED = {4, 6}       -- studs per second, picked per pet
local IDLE_TIME = {1, 4}        -- seconds a pet stands still between walks
local HOP_HEIGHT = 0.45         -- studs
local HOP_LENGTH = 1.8          -- studs walked per hop
local TURN_RATE = 9             -- higher = pets turn to face where they're going faster
local ANIMATE_DISTANCE = 300    -- pens further than this from the camera are left alone
-- The label above each pet, in studs, so it shrinks with distance like the pets do
local LABEL_DISTANCE = 100      -- labels further away than this are hidden
local LABEL_W = 7
local NAME_H = 0.95
local INCOME_H = 0.8
local LABEL_H = NAME_H + INCOME_H
local LABEL_GAP = 0.35          -- between the top of the pet and its label
local CHAR_W = 0.54             -- width of one FredokaOne character, as a fraction of its height
local COIN = 0.8                -- coin size, as a fraction of the income line's height

local INK = Color3.fromRGB(3, 8, 30)
local WHITE = Color3.fromRGB(250, 252, 255)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 248, 170), Color3.fromRGB(240, 150, 20)
local COIN_FACE, COIN_CENTER = Color3.fromRGB(255, 218, 52), Color3.fromRGB(240, 165, 25)
-- Same colours as SpaceGUI's pet cards
local RarityColor = {
	Common = Color3.fromRGB(110, 150, 230), Uncommon = Color3.fromRGB(80, 230, 130),
	Rare = Color3.fromRGB(255, 150, 60), Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 218, 52), Mythic = Color3.fromRGB(226, 46, 240),
}

local player = Players.LocalPlayer
local spaceGui = player:WaitForChild("PlayerGui"):WaitForChild("SpaceGUI")
local Models = require(spaceGui:WaitForChild("SpaceModels"))
local Config = require(spaceGui:WaitForChild("SpaceGUIConfig"))
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")

local petInfo = {}
for _, p in ipairs(Config.Pets or {}) do petInfo[p.Id] = p end
local function incomeOf(id)
	local info = petInfo[id]
	return info and type(info.Income) == "number" and info.Income or 0
end

local holder = Instance.new("Folder")
holder.Name = "PetPens"
holder.Parent = workspace

----------------------------------------------------------------------------
-- WHICH PETS GO IN A PEN
----------------------------------------------------------------------------
-- "astro_dog:3,comet_fox:1" -> {{Id = "astro_dog", Count = 3}, {Id = "comet_fox", Count = 1}}
local function parsePenPets(text)
	local list, byId = {}, {}
	if type(text) ~= "string" then return list end
	for id, count in text:gmatch("([%w_]+):(%d+)") do
		count = tonumber(count) or 0
		if count > 0 then
			if byId[id] then
				byId[id].Count += count
			else
				byId[id] = {Id = id, Count = count}
				table.insert(list, byId[id])
			end
		end
	end
	return list
end

-- Every copy as its own pet, best earners first, at most `cap` of them: {{Id =, Key = "astro_dog#2"}, ...}.
-- The Key stays the same while the copy is still there, so a pet keeps walking when another one is added.
local function penLayout(list, cap)
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		local incomeA, incomeB = incomeOf(a.Id), incomeOf(b.Id)
		if incomeA ~= incomeB then return incomeA > incomeB end
		return a.Id < b.Id
	end)
	local pets = {}
	for _, entry in ipairs(sorted) do
		for k = 1, entry.Count do
			if #pets >= cap then return pets end
			table.insert(pets, {Id = entry.Id, Key = entry.Id .. "#" .. k})
		end
	end
	return pets
end

-- 9 -> "9", 2.5 -> "2.5", 12345 -> "12.3K"
local function short(n)
	if n >= 1e6 then return (("%.1f"):format(n / 1e6):gsub("%.0$", "")) .. "M" end
	if n >= 1e4 then return (("%.1f"):format(n / 1e3):gsub("%.0$", "")) .. "K" end
	if n == math.floor(n) then return tostring(math.floor(n)) end
	return (("%.1f"):format(n):gsub("%.0$", ""))
end

-- Same seed on every device, so a pet starts in the same spot for everyone
local function seedFor(plotIndex, key)
	local h = plotIndex * 7919
	for i = 1, #key do h = (h * 31 + key:byte(i)) % 2147483647 end
	return h
end

----------------------------------------------------------------------------
-- ROAMING (all in the floor's own space: X along the fence, Z from the wall to the station)
----------------------------------------------------------------------------
-- Pets stay within +-hx, +-hz of the floor's center
local function roamBounds(size)
	return math.max(0, size.X / 2 - EDGE_MARGIN), math.max(0, size.Z / 2 - EDGE_MARGIN)
end

-- The angle from a to b, between -pi and pi
local function angleDiff(a, b)
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

-- The models face +Z, so turning one by math.atan2(dx, dz) makes it face along (dx, dz): the same
-- facing as CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi, 0).
local function yawToward(dx, dz)
	return math.atan2(dx, dz)
end

-- A random spot for the pet to stand on: anywhere in the pen when it arrives, or within WANDER of
-- where it is for a walk. Spots near where the other pets are standing or heading are avoided.
local function pickSpot(pet, others, hx, hz, wander)
	local rng = pet.rng
	local x0, x1, z0, z1 = -hx, hx, -hz, hz
	if wander then
		x0, x1 = math.max(-hx, pet.x - WANDER), math.min(hx, pet.x + WANDER)
		z0, z1 = math.max(-hz, pet.z - WANDER), math.min(hz, pet.z + WANDER)
		if x0 > x1 then x0, x1 = -hx, hx end -- the pet is outside the bounds (the floor shrank)
		if z0 > z1 then z0, z1 = -hz, hz end
	end
	local bestX, bestZ, bestScore = 0, 0, -1
	for _ = 1, 6 do
		local x, z = rng:NextNumber(x0, x1), rng:NextNumber(z0, z1)
		local nearest = SPACING * SPACING
		for _, other in ipairs(others) do
			if other ~= pet and other.tx then
				local dx, dz = x - other.tx, z - other.tz
				nearest = math.min(nearest, dx * dx + dz * dz)
			end
		end
		local score = nearest
		if wander and (x - pet.x) ^ 2 + (z - pet.z) ^ 2 < MIN_WALK * MIN_WALK then score *= 0.01 end
		if score >= SPACING * SPACING then return x, z end
		if score > bestScore then bestX, bestZ, bestScore = x, z, score end
	end
	return bestX, bestZ
end

-- Moves one pet along for dt seconds. Returns true if it moved (so it has to be drawn again).
local function stepPet(pet, dt, others, hx, hz)
	local rng = pet.rng
	if pet.walking then
		local dx, dz = pet.tx - pet.x, pet.tz - pet.z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist > 0.05 then pet.faceYaw = yawToward(dx, dz) end
		local diff = angleDiff(pet.faceYaw, pet.yaw)
		pet.yaw += diff * math.min(1, dt * TURN_RATE)
		-- Facing away, it turns on the spot first, then sets off
		local step = pet.speed * math.clamp(math.cos(diff), 0, 1) * dt
		if step >= dist then
			step = dist
			pet.x, pet.z = pet.tx, pet.tz
			pet.walking = false
			pet.yaw = angleDiff(pet.yaw, 0) -- back between -pi and pi, so it never winds up
			pet.timer = rng:NextNumber(IDLE_TIME[1], IDLE_TIME[2])
			-- Sometimes it has a look around while it waits
			if rng:NextNumber() < 0.5 then pet.faceYaw = pet.yaw + rng:NextNumber(-1, 1) end
		else
			pet.x += dx / dist * step
			pet.z += dz / dist * step
		end
		pet.phase += step / HOP_LENGTH * math.pi
		return true
	end
	local moved = false
	if pet.phase ~= 0 then -- finish the hop it was in the middle of
		local nextPhase = pet.phase + pet.speed * dt / HOP_LENGTH * math.pi
		pet.phase = math.floor(nextPhase / math.pi) > math.floor(pet.phase / math.pi) and 0 or nextPhase
		moved = true
	end
	local diff = angleDiff(pet.faceYaw, pet.yaw)
	if math.abs(diff) > 0.002 then
		pet.yaw += diff * math.min(1, dt * TURN_RATE)
		moved = true
	end
	pet.timer -= dt
	if pet.timer <= 0 and pet.phase == 0 then
		pet.tx, pet.tz = pickSpot(pet, others, hx, hz, true)
		pet.walking = true
	end
	return moved
end

-- Where the pet and its label go, in the world
local function petFrame(floorCF, top, pet)
	local hop = HOP_HEIGHT * math.abs(math.sin(pet.phase))
	return floorCF * CFrame.new(pet.x, top + pet.half + hop, pet.z) * CFrame.Angles(0, pet.yaw, 0)
end
local function labelFrame(floorCF, top, pet)
	return floorCF * CFrame.new(pet.x, top + pet.half * 2 + LABEL_GAP + LABEL_H / 2, pet.z)
end

----------------------------------------------------------------------------
-- PET MODELS AND LABELS
----------------------------------------------------------------------------
local function new(class, parent, properties)
	local obj = Instance.new(class)
	for key, value in pairs(properties or {}) do obj[key] = value end
	obj.Parent = parent
	return obj
end
local function gradient(obj, top, bottom)
	return new("UIGradient", obj, {Color = ColorSequence.new(top, bottom), Rotation = 90})
end
local function text(parent, name, size, position, xAlign)
	local l = new("TextLabel", parent, {Name = name, Size = size, Position = position or UDim2.new(),
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.FredokaOne, TextScaled = true,
		TextColor3 = WHITE, TextXAlignment = xAlign or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, Text = ""})
	return l, new("UIStroke", l, {Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round})
end

local function makeLabel(pet, anchor, info)
	local gui = new("BillboardGui", anchor, {Name = "PetLabel", Size = UDim2.fromScale(LABEL_W, LABEL_H),
		LightInfluence = 0, MaxDistance = LABEL_DISTANCE, AlwaysOnTop = false})
	local name, nameStroke = text(gui, "PetName", UDim2.fromScale(1, NAME_H / LABEL_H))
	name.Text = info and info.Name or pet.id:gsub("_", " "):gsub("^%l", string.upper)
	local color = info and RarityColor[info.Rarity] or RarityColor.Common
	gradient(name, color:Lerp(WHITE, 0.3), color)

	-- "+N/s" with a coin in front of it, centred under the name
	local row = new("Frame", gui, {Name = "Income", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromScale(0, NAME_H / LABEL_H), Size = UDim2.fromScale(1, INCOME_H / LABEL_H)})
	new("UIListLayout", row, {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.15 * INCOME_H / LABEL_W, 0)})
	local coin = new("Frame", row, {Name = "Coin", LayoutOrder = 1, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		Size = UDim2.fromScale(COIN * INCOME_H / LABEL_W, COIN)})
	new("UICorner", coin, {CornerRadius = UDim.new(0.5, 0)})
	gradient(coin, Color3.fromRGB(255, 240, 140), COIN_FACE)
	local coinStroke = new("UIStroke", coin, {Color = INK, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	local center = new("Frame", coin, {Name = "Center", BackgroundColor3 = COIN_CENTER, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5)})
	new("UICorner", center, {CornerRadius = UDim.new(0.5, 0)})
	local amount, amountStroke = text(row, "Amount", UDim2.fromScale(0.3, 1), nil, Enum.TextXAlignment.Left)
	amount.LayoutOrder = 2
	gradient(amount, GOLD_TOP, GOLD_BOTTOM)

	pet.amount = amount
	pet.strokes = {nameStroke, amountStroke, coinStroke}
end

-- Shows what one copy earns, with the owner's boosts
local function setIncome(pet, multiplier)
	local label = "+" .. short(incomeOf(pet.id) * multiplier) .. "/s"
	if pet.amount.Text == label then return end
	pet.amount.Text = label
	-- TextScaled can't size the label to fit its text, so it's sized from the number of characters
	local width = math.min(1 - COIN * INCOME_H / LABEL_W, #label * CHAR_W * INCOME_H / LABEL_W)
	pet.amount.Size = UDim2.fromScale(width, 1)
end

-- The outlines are in pixels, so they're thinned out as a label gets smaller with distance
local function setOutline(pet, pixelsPerStud)
	local thickness = math.clamp(math.floor(NAME_H * pixelsPerStud * 0.11 * 4 + 0.5) / 4, 1, 3.5)
	if pet.outline == thickness then return end
	pet.outline = thickness
	pet.strokes[1].Thickness = thickness
	pet.strokes[2].Thickness = math.max(1, thickness * 0.9)
	pet.strokes[3].Thickness = math.max(1, thickness * 0.7)
end

local function buildPet(pen, id, key, floorCF, top, hx, hz)
	local ok, model = pcall(Models.Pet, id)
	if not ok or not model then return nil end
	local size = model:GetExtentsSize()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then model:ScaleTo(PET_SIZE / longest) end
	local box
	box, size = model:GetBoundingBox()
	local center = CFrame.new(box.Position)
	local pet = {key = key, id = id, model = model, parts = {}, offsets = {}, half = size.Y / 2}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			table.insert(pet.parts, part)
			table.insert(pet.offsets, center:ToObjectSpace(part.CFrame))
		end
	end
	-- An invisible part the label floats on, so it stays level while the pet hops
	pet.anchor = new("Part", model, {Name = "LabelAnchor", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
	makeLabel(pet, pet.anchor, petInfo[id])

	local rng = Random.new(seedFor(pen.index, key))
	pet.rng = rng
	pet.speed = rng:NextNumber(WALK_SPEED[1], WALK_SPEED[2])
	pet.x, pet.z = 0, 0
	pet.x, pet.z = pickSpot(pet, pen.pets, hx, hz, false)
	pet.tx, pet.tz = pet.x, pet.z
	pet.yaw = rng:NextNumber(-math.pi, math.pi)
	pet.faceYaw = pet.yaw
	pet.phase = 0
	pet.walking = false
	pet.timer = rng:NextNumber(0, IDLE_TIME[2])

	-- In place before it's shown, so it never flashes up somewhere else
	local cf = petFrame(floorCF, top, pet)
	for i, part in ipairs(pet.parts) do part.CFrame = cf * pet.offsets[i] end
	local labelCF = labelFrame(floorCF, top, pet)
	pet.anchor.CFrame = labelCF
	pet.labelPos = labelCF.Position
	model.Name = id
	model.Parent = pen.folder
	return pet
end

----------------------------------------------------------------------------
-- PENS
----------------------------------------------------------------------------
local pens = {} -- [plot] = {plot, index, owner, floor, folder, pets = {pet}, byKey = {[key] = pet}}

local function clearPets(pen)
	for _, pet in ipairs(pen.pets) do pet.model:Destroy() end
	table.clear(pen.pets)
	table.clear(pen.byKey)
end

local function currentFloor(plot)
	local penModel = plot:FindFirstChild("PetPen")
	local floor = penModel and penModel:FindFirstChild("Floor")
	return floor and floor:IsA("BasePart") and floor or nil
end

local function multiplierOf(owner)
	local m = owner and owner:GetAttribute("IncomeMultiplier")
	return type(m) == "number" and m or 1
end

local function updateIncome(pen)
	local multiplier = multiplierOf(pen.owner)
	for _, pet in ipairs(pen.pets) do setIncome(pet, multiplier) end
end

-- Makes the pen's pets match its owner's PenPets: copies that are gone are removed, new ones added,
-- and the ones still there carry on where they are.
local function sync(pen)
	local floor = currentFloor(pen.plot)
	if floor ~= pen.floor then
		clearPets(pen)
		pen.floor = floor
	end
	if not floor or not pen.owner or not pen.owner.Parent then
		clearPets(pen)
		return
	end
	local wanted = penLayout(parsePenPets(pen.owner:GetAttribute("PenPets")), MAX_PETS)
	local keep = {}
	for _, w in ipairs(wanted) do keep[w.Key] = true end
	for i = #pen.pets, 1, -1 do
		local pet = pen.pets[i]
		if not keep[pet.key] then
			pet.model:Destroy()
			table.remove(pen.pets, i)
			pen.byKey[pet.key] = nil
		end
	end
	local floorCF, size = floor.CFrame, floor.Size
	local hx, hz = roamBounds(size)
	for _, w in ipairs(wanted) do
		if not pen.byKey[w.Key] then
			local pet = buildPet(pen, w.Id, w.Key, floorCF, size.Y / 2, hx, hz)
			if pet then
				table.insert(pen.pets, pet)
				pen.byKey[w.Key] = pet
			end
		end
	end
	updateIncome(pen)
end

local function setOwner(pen)
	for _, conn in ipairs(pen.ownerConns) do conn:Disconnect() end
	table.clear(pen.ownerConns)
	local id = pen.plot:GetAttribute("OwnerUserId")
	local owner = type(id) == "number" and Players:GetPlayerByUserId(id) or nil
	if owner ~= pen.owner then clearPets(pen) end
	pen.owner = owner
	if owner then
		table.insert(pen.ownerConns, owner:GetAttributeChangedSignal("PenPets"):Connect(function() sync(pen) end))
		table.insert(pen.ownerConns, owner:GetAttributeChangedSignal("IncomeMultiplier"):Connect(function() updateIncome(pen) end))
	end
	sync(pen)
end

-- The PetPen model appears when the owner runs the map command (or streams in): watch it for its Floor
local function watchPenModel(pen, penModel)
	if pen.penModel == penModel then return end
	for _, conn in ipairs(pen.penConns) do conn:Disconnect() end
	table.clear(pen.penConns)
	pen.penModel = penModel
	local function changed(child) if child.Name == "Floor" then sync(pen) end end
	table.insert(pen.penConns, penModel.ChildAdded:Connect(changed))
	table.insert(pen.penConns, penModel.ChildRemoved:Connect(changed))
	sync(pen)
end

local function watchPlot(plot)
	if not plot.Name:match("^StationPlot%d+$") or pens[plot] then return end
	local folder = Instance.new("Folder")
	folder.Name = plot.Name
	folder.Parent = holder
	local pen = {plot = plot, index = tonumber(plot.Name:match("%d+")), folder = folder, pets = {}, byKey = {},
		ownerConns = {}, penConns = {}}
	pens[plot] = pen
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() setOwner(pen) end)
	plot.ChildAdded:Connect(function(child)
		if child.Name == "PetPen" and child:IsA("Model") then watchPenModel(pen, child) end
	end)
	plot.ChildRemoved:Connect(function(child) if child == pen.penModel then sync(pen) end end)
	local penModel = plot:FindFirstChild("PetPen")
	if penModel then watchPenModel(pen, penModel) end
	setOwner(pen)
end

for _, plot in ipairs(station:GetChildren()) do watchPlot(plot) end
station.ChildAdded:Connect(watchPlot)

Players.PlayerAdded:Connect(function(newPlayer)
	for _, pen in pairs(pens) do
		if pen.plot:GetAttribute("OwnerUserId") == newPlayer.UserId and pen.owner ~= newPlayer then setOwner(pen) end
	end
end)
Players.PlayerRemoving:Connect(function(leaving)
	for _, pen in pairs(pens) do
		if pen.owner == leaving then
			for _, conn in ipairs(pen.ownerConns) do conn:Disconnect() end
			table.clear(pen.ownerConns)
			pen.owner = nil
			clearPets(pen)
		end
	end
end)

----------------------------------------------------------------------------
-- EVERY FRAME: walk the pets in the pens near the camera, and move them all in one go
----------------------------------------------------------------------------
local moveParts, moveFrames = {}, {}
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local camPos = camera.CFrame.Position
	-- Pixels per stud at 1 stud away; divided by the distance, it's how big a label is on screen
	local pixelsAtOne = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2))
	table.clear(moveParts)
	table.clear(moveFrames)
	local n = 0
	for _, pen in pairs(pens) do
		local floor = pen.floor
		if not floor or #pen.pets == 0 then continue end
		local floorCF = floor.CFrame
		if (floorCF.Position - camPos).Magnitude > ANIMATE_DISTANCE then continue end
		local size = floor.Size
		local top = size.Y / 2
		local hx, hz = roamBounds(size)
		for _, pet in ipairs(pen.pets) do
			if stepPet(pet, dt, pen.pets, hx, hz) then
				local cf = petFrame(floorCF, top, pet)
				for i, part in ipairs(pet.parts) do
					n += 1
					moveParts[n] = part
					moveFrames[n] = cf * pet.offsets[i]
				end
				local labelCF = labelFrame(floorCF, top, pet)
				pet.labelPos = labelCF.Position
				n += 1
				moveParts[n] = pet.anchor
				moveFrames[n] = labelCF
			end
			local distance = (pet.labelPos - camPos).Magnitude
			if distance < LABEL_DISTANCE then setOutline(pet, pixelsAtOne / math.max(distance, 1)) end
		end
	end
	if n > 0 then workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged) end
end)
