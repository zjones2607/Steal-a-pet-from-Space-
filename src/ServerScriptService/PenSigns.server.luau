-- PenSigns: the "PET PEN  3 / 10 PETS" sign at the front of every station's pet pen. It shows how
-- many pets are in the owner's pen and how many fit (the PenPetCount / PenCapacity attributes that
-- PetsAndShop keeps up to date). Free stations show an empty pen of the starting size.
-- The pen used to have a sign and an "Upgrade Pen" prompt made in Studio, outside this project.
-- Pens are now upgraded only from SpaceGUI's Pets page, so any "Upgrade Pen" prompt is removed, and
-- an old "PET PEN" sign is taken over (its text is replaced by this script's) instead of adding a
-- second one. A pen without a sign gets a new one built above the fence opening.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Config = require(StarterGui:WaitForChild("SpaceGUI"):WaitForChild("SpaceGUIConfig"))
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")

local GUI_NAME = "PenSignGui"
local SIGN_SIZE = Vector3.new(24, 7, 0.6)
local SIGN_HEIGHT = 9            -- studs from the pen floor to the middle of the sign
local NAVY = Color3.fromRGB(10, 20, 120)
local TRIM = Color3.fromRGB(90, 240, 255)
local INK = Color3.fromRGB(3, 8, 30)
local WHITE = Color3.fromRGB(250, 252, 255)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 240, 150), Color3.fromRGB(225, 165, 40)

local function new(class, parent, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

----------------------------------------------------------------------------
-- THE OLD STUDIO-MADE UPGRADE PROMPT: pens are upgraded on the Pets page now
----------------------------------------------------------------------------
local function isUpgradePrompt(obj)
	if not obj:IsA("ProximityPrompt") then return false end
	if obj.Name == "PenUpgradePrompt" then return true end -- what the Studio-made ones are called
	local text = (obj.ActionText .. " " .. obj.ObjectText):lower()
	return text:find("upgrade pen", 1, true) ~= nil or text:find("upgrade pet pen", 1, true) ~= nil
end
local function removeUpgradePrompt(obj)
	if isUpgradePrompt(obj) then obj:Destroy() end
end

----------------------------------------------------------------------------
-- SIGNS
----------------------------------------------------------------------------
-- Fills a SurfaceGui (old or new) with this script's two lines. Returns the count label.
local function fillGui(gui)
	gui:ClearAllChildren()
	gui.Name = GUI_NAME
	local function line(name, text, y, h, top, bottom)
		local l = new("TextLabel", gui, {Name = name, Text = text, Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, h), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
			TextScaled = true, TextColor3 = WHITE})
		new("UIStroke", l, {Color = INK, Thickness = 6, LineJoinMode = Enum.LineJoinMode.Round})
		new("UIGradient", l, {Color = ColorSequence.new(top, bottom), Rotation = 90})
		return l
	end
	line("Title", "PET PEN", 0.1, 0.4, GOLD_TOP, GOLD_BOTTOM)
	return line("Count", "", 0.52, 0.38, WHITE, Color3.fromRGB(215, 225, 240))
end

-- A new sign above the fence at the front of the pen (the side facing the station)
local function buildSign(plot, floor)
	local pad = plot:FindFirstChild("Core") and plot.Core:FindFirstChild("Station_Pad")
	local size = floor.Size
	local front = 1
	if pad and pad:IsA("BasePart") then
		front = floor.CFrame:PointToObjectSpace(pad.CFrame.Position).Z > 0 and 1 or -1
	end
	local pos = floor.CFrame * Vector3.new(0, size.Y / 2 + SIGN_HEIGHT, front * (size.Z / 2 + 1))
	local outward = (floor.CFrame:VectorToWorldSpace(Vector3.new(0, 0, front)) * Vector3.new(1, 0, 1)).Unit
	local cf = CFrame.lookAt(pos, pos + outward)
	local model = new("Model", plot, {Name = "PenSign"})
	local function part(name, partSize, offset, color, material)
		return new("Part", model, {Name = name, Size = partSize, CFrame = cf * offset, Color = color,
			Material = material or Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false,
			CanQuery = false, CanTouch = false, CastShadow = false})
	end
	local board = part("Board", SIGN_SIZE, CFrame.new(), NAVY)
	for _, y in ipairs({1, -1}) do
		part("Trim", Vector3.new(SIGN_SIZE.X + 0.6, 0.45, SIGN_SIZE.Z + 0.3),
			CFrame.new(0, y * (SIGN_SIZE.Y / 2 + 0.1), 0), TRIM, Enum.Material.Neon)
	end
	local postHeight = SIGN_HEIGHT - SIGN_SIZE.Y / 2
	for _, x in ipairs({-1, 1}) do
		part("Post", Vector3.new(0.6, postHeight, 0.6),
			CFrame.new(x * (SIGN_SIZE.X / 2 - 1), -SIGN_SIZE.Y / 2 - postHeight / 2, 0), Color3.fromRGB(75, 80, 95), Enum.Material.Metal)
	end
	local gui = new("SurfaceGui", board, {Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40, LightInfluence = 0})
	return fillGui(gui)
end

-- An old "PET PEN" sign for this pen, if the place has one: a SurfaceGui with "PET PEN" in it,
-- on the plot or on a part near the pen's floor
local function findOldSign(plot, floor)
	local function isPenSign(gui)
		if not gui:IsA("SurfaceGui") and not gui:IsA("BillboardGui") then return false end
		if gui.Name == GUI_NAME then return true end
		for _, d in ipairs(gui:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:upper():find("PET PEN", 1, true) then return true end
		end
		return false
	end
	for _, d in ipairs(plot:GetDescendants()) do
		if isPenSign(d) then return d end
	end
	local best, bestDistance = nil, 70
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) and not d:IsDescendantOf(station) and isPenSign(d) then
			local part = d.Adornee or d.Parent
			if part and part:IsA("BasePart") then
				local distance = (part.CFrame.Position - floor.CFrame.Position).Magnitude
				if distance < bestDistance then best, bestDistance = d, distance end
			end
		end
	end
	return best
end

local signs = {} -- [plot] = count label

local function countText(plot)
	local id = plot:GetAttribute("OwnerUserId")
	local owner = type(id) == "number" and Players:GetPlayerByUserId(id)
	local count = owner and owner:GetAttribute("PenPetCount") or 0
	local capacity = owner and owner:GetAttribute("PenCapacity") or Config.PenCapacity(0)
	return ("%d / %d PETS"):format(count, capacity)
end

local function updatePlot(plot)
	local penModel = plot:FindFirstChild("PetPen")
	local floor = penModel and penModel:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then return end
	local label = signs[plot]
	if not label or not label.Parent or not label:IsDescendantOf(workspace) then
		local old = findOldSign(plot, floor)
		label = old and fillGui(old) or buildSign(plot, floor)
		signs[plot] = label
	end
	local text = countText(plot)
	if label.Text ~= text then label.Text = text end
end

for _, d in ipairs(workspace:GetDescendants()) do removeUpgradePrompt(d) end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		removeUpgradePrompt(d)
		task.defer(function() if d.Parent then removeUpgradePrompt(d) end end) -- in case its text is set just after
	end
end)

-- Once a second is plenty for a sign, and it also puts the right text back if anything else changes it
while true do
	for _, plot in ipairs(station:GetChildren()) do
		if plot.Name:match("^StationPlot%d+$") then
			local ok, err = pcall(updatePlot, plot)
			if not ok then warn("PenSigns: " .. tostring(err)) end
		end
	end
	task.wait(1)
end
