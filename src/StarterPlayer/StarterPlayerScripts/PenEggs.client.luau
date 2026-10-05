-- PenEggs: shows the eggs hatching in every claimed station's pen, sitting in nests along the back
-- fence. The server (PetsAndShop) keeps each player's eggs in their "IncubatingEggs" folder: one
-- StringValue per egg called Egg1..EggN after its spot, its kind in Value, and the unix time it
-- hatches in its HatchAt attribute (Seconds = how long it takes). This script builds the egg models
-- (SpaceGUI.SpaceModels) on this device, with a countdown above each one, and wobbles them harder and
-- harder as they get ready. When an egg hatches it bursts with a puff of light.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EGG_HEIGHT = 3            -- studs
local PER_ROW = 6               -- eggs side by side along the back fence
local SPACING_X = 7             -- studs between eggs in a row
local ROW_DEPTH = 7             -- studs between rows
local BACK_MARGIN = 6           -- studs from the back fence to the first row
local NEST_HEIGHT = 0.5
local ANIMATE_DISTANCE = 200    -- eggs further than this from the camera don't wobble
local LABEL_DISTANCE = 90       -- countdowns further than this are hidden
local CHECK_EVERY = 0.25        -- seconds between looking for eggs that came or went

local INK = Color3.fromRGB(3, 8, 30)
local WHITE = Color3.fromRGB(250, 252, 255)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 248, 170), Color3.fromRGB(240, 150, 20)
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(150, 255, 170), Color3.fromRGB(60, 200, 110)
local NEST = Color3.fromRGB(214, 170, 92)
local NEST_RIM = Color3.fromRGB(176, 128, 60)
local POP = Color3.fromRGB(255, 240, 170)

local player = Players.LocalPlayer
local spaceGui = player:WaitForChild("PlayerGui"):WaitForChild("SpaceGUI")
local Models = require(spaceGui:WaitForChild("SpaceModels"))
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")

local holder = Instance.new("Folder")
holder.Name = "PenEggs"
holder.Parent = workspace

local function new(class, parent, properties)
	local obj = Instance.new(class)
	for key, value in pairs(properties or {}) do obj[key] = value end
	obj.Parent = parent
	return obj
end
local function gradient(obj, top, bottom)
	return new("UIGradient", obj, {Color = ColorSequence.new(top, bottom), Rotation = 90})
end
local function decor(parent, name, shape, size, cf, color, material)
	return new("Part", parent, {Name = name, Shape = shape, Size = size, CFrame = cf, Color = color,
		Material = material or Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false,
		CanQuery = false, CanTouch = false, CastShadow = false, TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth})
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	local m, s = math.floor(seconds / 60), seconds % 60
	if m >= 60 then return ("%d:%02d:%02d"):format(math.floor(m / 60), m % 60, s) end
	return ("%d:%02d"):format(m, s)
end

-- The egg's spot in its pen, in the floor's own space: rows along the fence furthest from the station
local function spotFor(slot, floor, plot)
	local size = floor.Size
	local pad = plot:FindFirstChild("Core") and plot.Core:FindFirstChild("Station_Pad")
	local back = -1
	if pad and pad:IsA("BasePart") then
		local towardStation = floor.CFrame:PointToObjectSpace(pad.CFrame.Position).Z
		back = towardStation > 0 and -1 or 1
	end
	local i = slot - 1
	local row, col = math.floor(i / PER_ROW), i % PER_ROW
	local x = (col - (PER_ROW - 1) / 2) * SPACING_X
	local z = back * math.max(0, size.Z / 2 - BACK_MARGIN - row * ROW_DEPTH)
	x = math.clamp(x, -size.X / 2 + 3, size.X / 2 - 3)
	return floor.CFrame * CFrame.new(x, size.Y / 2, z) * CFrame.Angles(0, slot * 1.7, 0)
end

-- One egg in its nest, with its countdown. Returns the egg's record.
local function buildEgg(folder, eggValue, ground)
	local model = Models.Egg(1)
	local extents = model:GetExtentsSize()
	if extents.Y > 0 then model:ScaleTo(EGG_HEIGHT / extents.Y) end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local nest = new("Model", folder, {Name = eggValue.Name})
	local up = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis (X) to point up
	decor(nest, "Nest", Enum.PartType.Cylinder, Vector3.new(NEST_HEIGHT, 4.2, 4.2),
		ground * CFrame.new(0, NEST_HEIGHT / 2, 0) * up, NEST, Enum.Material.Fabric)
	decor(nest, "NestRim", Enum.PartType.Cylinder, Vector3.new(NEST_HEIGHT + 0.3, 4.6, 4.6),
		ground * CFrame.new(0, (NEST_HEIGHT + 0.3) / 2 - 0.05, 0) * up, NEST_RIM, Enum.Material.Fabric).Transparency = 0.15
	local base = ground * CFrame.new(0, NEST_HEIGHT + EGG_HEIGHT / 2 - 0.25, 0)
	model:PivotTo(base)
	model.Name = "Egg"
	model.Parent = nest

	-- The countdown floats on its own invisible part, so it stays still while the egg wobbles
	local anchor = decor(nest, "LabelAnchor", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2),
		base * CFrame.new(0, EGG_HEIGHT / 2 + 1.6, 0), WHITE)
	anchor.Transparency = 1
	local gui = new("BillboardGui", anchor, {Name = "Countdown", Size = UDim2.fromScale(5, 1.9),
		LightInfluence = 0, MaxDistance = LABEL_DISTANCE})
	local name = new("TextLabel", gui, {Name = "Kind", Size = UDim2.fromScale(1, 0.42), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = WHITE, Text = eggValue.Value})
	new("UIStroke", name, {Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round})
	local timer = new("TextLabel", gui, {Name = "Timer", Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.38), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		TextScaled = true, TextColor3 = WHITE, Text = ""})
	new("UIStroke", timer, {Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round})
	gradient(timer, GOLD_TOP, GOLD_BOTTOM)
	local track = new("Frame", gui, {Name = "Progress", AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromScale(0.62, 0.14),
		BackgroundColor3 = INK, BorderSizePixel = 0})
	new("UICorner", track, {CornerRadius = UDim.new(0.5, 0)})
	local fill = new("Frame", track, {Name = "Fill", Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE, BorderSizePixel = 0})
	new("UICorner", fill, {CornerRadius = UDim.new(0.5, 0)})
	gradient(fill, GREEN_TOP, GREEN_BOTTOM)

	return {value = eggValue, nest = nest, model = model, base = base, timer = timer, fill = fill,
		hatchAt = eggValue:GetAttribute("HatchAt") or 0, seconds = eggValue:GetAttribute("Seconds") or 60,
		seed = (#eggValue.Name * 37 + (eggValue:GetAttribute("HatchAt") or 0)) % 100 / 10, shown = ""}
end

-- A puff of light where an egg was
local function pop(cf)
	local ball = decor(holder, "HatchPop", Enum.PartType.Ball, Vector3.new(2, 2, 2), cf, POP, Enum.Material.Neon)
	ball.Transparency = 0.2
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ball, info, {Size = Vector3.new(8, 8, 8), Transparency = 1}):Play()
	task.delay(0.5, function() ball:Destroy() end)
end

local function removeEgg(egg, burst)
	if burst then pop(egg.base) end
	egg.nest:Destroy()
end

----------------------------------------------------------------------------
-- PENS: [plotName] = {folder, eggs = {[eggName] = egg}, floor, owner}
----------------------------------------------------------------------------
local pens = {}

local function clearPen(pen, burst)
	for key, egg in pairs(pen.eggs) do
		removeEgg(egg, burst)
		pen.eggs[key] = nil
	end
end

local function syncPen(plot)
	local pen = pens[plot.Name]
	if not pen then
		pen = {folder = new("Folder", holder, {Name = plot.Name}), eggs = {}}
		pens[plot.Name] = pen
	end
	local id = plot:GetAttribute("OwnerUserId")
	local owner = type(id) == "number" and Players:GetPlayerByUserId(id) or nil
	local penModel = plot:FindFirstChild("PetPen")
	local floor = penModel and penModel:FindFirstChild("Floor")
	if floor and not floor:IsA("BasePart") then floor = nil end
	if owner ~= pen.owner or floor ~= pen.floor or (floor and floor.CFrame ~= pen.floorCF) then
		clearPen(pen, false) -- new owner, or the pen was rebuilt: start again
		pen.owner, pen.floor, pen.floorCF = owner, floor, floor and floor.CFrame
	end
	local incubator = owner and owner:FindFirstChild("IncubatingEggs")
	if not floor or not incubator then
		clearPen(pen, false)
		return
	end
	local present = {}
	for _, value in ipairs(incubator:GetChildren()) do
		local slot = value:IsA("StringValue") and tonumber(value.Name:match("^Egg(%d+)$"))
		if slot then
			local key = value.Name .. "|" .. value.Value .. "|" .. tostring(value:GetAttribute("HatchAt"))
			present[key] = true
			if not pen.eggs[key] then
				pen.eggs[key] = buildEgg(pen.folder, value, spotFor(slot, floor, plot))
			end
		end
	end
	for key, egg in pairs(pen.eggs) do
		if not present[key] then
			-- An egg that's gone close to its time hatched, so it bursts; otherwise it just goes
			local hatched = egg.hatchAt - workspace:GetServerTimeNow() < 3 or not egg.value.Parent
			removeEgg(egg, hatched)
			pen.eggs[key] = nil
		end
	end
end

task.spawn(function()
	while true do
		local seen = {}
		for _, plot in ipairs(station:GetChildren()) do
			if plot.Name:match("^StationPlot%d+$") then
				seen[plot.Name] = true
				local ok, err = pcall(syncPen, plot)
				if not ok then warn("PenEggs: " .. tostring(err)) end
			end
		end
		for name, pen in pairs(pens) do
			if not seen[name] then
				clearPen(pen, false)
				pen.folder:Destroy()
				pens[name] = nil
			end
		end
		task.wait(CHECK_EVERY)
	end
end)

----------------------------------------------------------------------------
-- EVERY FRAME: countdowns, and eggs wobble more and more as they get close to hatching
----------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	for _, pen in pairs(pens) do
		for _, egg in pairs(pen.eggs) do
			local left = egg.hatchAt - now
			local text = left > 0 and clock(left) or "Hatching!"
			if text ~= egg.shown then
				egg.shown = text
				egg.timer.Text = text
				egg.fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(egg.seconds, 1), 0, 1), 1)
			end
			if camPos and (egg.base.Position - camPos).Magnitude < ANIMATE_DISTANCE then
				local progress = math.clamp(1 - left / math.max(egg.seconds, 1), 0, 1)
				-- A gentle rock that grows; in the last 5 seconds it shakes fast
				local amount = math.rad(2 + 10 * progress * progress)
				local speed = 2 + 4 * progress
				if left < 5 then amount, speed = math.rad(14), 14 end
				local angle = math.sin((t + egg.seed) * speed) * amount
				local bottom = CFrame.new(0, -EGG_HEIGHT / 2, 0)
				egg.model:PivotTo(egg.base * bottom * CFrame.Angles(angle * 0.4, 0, angle) * bottom:Inverse())
			end
		end
	end
end)
