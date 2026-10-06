-- JetpackHUD: the jetpack flight controls, drawn in the same cartoon style as SpaceGUI
-- (glossy 3D buttons, dark outlines, FredokaOne text). Buying and equipping jetpacks is
-- the Jetpacks page in SpaceGUI.
--   LAUNCH  slides up from the bottom of the screen while you stand on a launch pad and drops
--           away when you step off. Flies with the equipped jetpack (JetpackFlight). Key: F / X
--   MY PAD  shows while you're off the pad and teleports you to your station's launch pad
--           (TeleportToLaunchSite). Key: T / L2, which works even while the buttons are hidden.
--   While flying, a hint at the top of the screen shows the flight controls.
-- Both buttons slide away while a menu is open: SpaceGUI and the admin panel set the local
-- player attributes listed in MENU_ATTRIBUTES while their windows are showing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild("Jetpacks")
local Config = require(folder:WaitForChild("JetpackConfig"))
local Flight = require(folder:WaitForChild("JetpackFlight"))
local teleportRemote = folder:WaitForChild("TeleportToLaunchSite")
local playerGui = player:WaitForChild("PlayerGui")
local spaceGui = playerGui:WaitForChild("SpaceGUI", 10)
local iconModule = spaceGui and spaceGui:WaitForChild("SpaceIcons", 10)
local Icons = iconModule and require(iconModule)

-- Same colours as SpaceGUI
local C = {
	Ink = Color3.fromRGB(3, 8, 30), Navy = Color3.fromRGB(9, 23, 68), Deep = Color3.fromRGB(5, 15, 48),
	Panel = Color3.fromRGB(17, 36, 96), Cyan = Color3.fromRGB(8, 197, 248), Blue = Color3.fromRGB(28, 122, 235),
	Gold = Color3.fromRGB(255, 218, 52), GoldDeep = Color3.fromRGB(240, 150, 20), White = Color3.fromRGB(250, 252, 255),
	Orange = Color3.fromRGB(255, 120, 30), OrangeTop = Color3.fromRGB(255, 205, 70),
	Grey = Color3.fromRGB(95, 104, 135), GreyTop = Color3.fromRGB(160, 170, 195), Green = Color3.fromRGB(72, 232, 120),
}
local SHOWN_Y, HIDDEN_Y = -26, 260
local MENU_ATTRIBUTES = {"SpaceGUIOpen", "AdminPanelOpen"}

-- Default GUI borders are square (UICorner doesn't round them), so every object starts without one
local function new(class, parent, props)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
	for k, v in pairs(props or {}) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function tween(obj, seconds, props, style, direction, repeats, reverses)
	local t = TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out, repeats or 0, reverses or false), props)
	t:Play()
	return t
end
local function corner(obj, r) return new("UICorner", obj, {CornerRadius = UDim.new(0, r)}) end
-- Outline around a Frame's (rounded) edge
local function stroke(obj, color, thickness, transparency)
	return new("UIStroke", obj, {Color = color, Thickness = thickness, Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function gradient(obj, top, bottom)
	return new("UIGradient", obj, {Color = ColorSequence.new(top, bottom), Rotation = 90})
end
-- Outlined cartoon text. The outline goes round the letters (Contextual), not round the label's
-- box: a Border stroke here drew a square black frame around every label, i.e. around the buttons.
local function text(parent, value, size, props)
	local l = new("TextLabel", parent, {Text = value, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		TextSize = size, TextColor3 = C.White, TextWrapped = false, ZIndex = 5})
	for k, v in pairs(props or {}) do l[k] = v end
	new("UIStroke", l, {Color = C.Ink, Thickness = math.clamp(size / 11, 1.5, 4),
		LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
	return l
end

-- Key hint sitting on the button's top-right corner, centred on the corner so it sticks out the
-- same amount above and to the right
local keyboard = UserInputService.KeyboardEnabled and not GuiService:IsTenFootInterface()
local KEY_SIZE, KEY_INSET = 34, 8
local function keycap(parent, label)
	local cap = new("Frame", parent, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -KEY_INSET, 0, KEY_INSET),
		Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE), BackgroundColor3 = C.White, ZIndex = 6})
	corner(cap, 9); gradient(cap, Color3.fromRGB(235, 240, 255), Color3.fromRGB(170, 185, 220)); stroke(cap, C.Ink, 3)
	text(cap, label, 20, {Size = UDim2.fromScale(1, 1), TextColor3 = C.Navy, ZIndex = 7})
	return cap
end

-- Glossy 3D button like SpaceGUI's: dark lip underneath, gradient face, rim, gloss and a shine sweep.
-- The face and the lip are the same size with the same RADIUS and OUTLINE, and the lip is just
-- the face moved down, so the dark outline hugs the rounded button and the lip only shows as a
-- darker edge along the bottom. depth leaves a clear band of lip below the face's outline.
local RADIUS, OUTLINE = 22, 4
local LIP_DARKEN = 0.45
local function cartoonButton(parent, w, h, top, bottom)
	local depth = math.max(OUTLINE + 6, math.floor(h * 0.11))
	local holder = new("TextButton", parent, {Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(w, h)})
	local scale = new("UIScale", holder, {Scale = 1})
	local lip = new("Frame", holder, {BackgroundColor3 = bottom:Lerp(C.Ink, LIP_DARKEN), Position = UDim2.fromOffset(0, depth),
		Size = UDim2.new(1, 0, 1, -depth)})
	corner(lip, RADIUS); stroke(lip, C.Ink, OUTLINE)
	local face = new("Frame", holder, {BackgroundColor3 = C.White, Size = UDim2.new(1, 0, 1, -depth)})
	corner(face, RADIUS)
	local faceGradient = gradient(face, top, bottom)
	stroke(face, C.Ink, OUTLINE)
	local rim = new("Frame", face, {BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8)})
	corner(rim, RADIUS - 4); stroke(rim, C.White, 2.5, 0.35)
	local gloss = new("Frame", face, {BackgroundColor3 = C.White, BackgroundTransparency = 0.72,
		Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0.36, 0), ZIndex = 2})
	corner(gloss, 12)
	local shine = new("Frame", face, {BackgroundColor3 = C.White, Size = UDim2.fromScale(1, 1), ZIndex = 3})
	corner(shine, RADIUS)
	local shineGradient = new("UIGradient", shine, {Rotation = 25, Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1)})})
	-- Press squish
	holder.MouseButton1Down:Connect(function() tween(face, 0.06, {Position = UDim2.fromOffset(0, depth - 2)}) end)
	local function release() tween(face, 0.1, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back) end
	holder.MouseButton1Up:Connect(release)
	holder.MouseLeave:Connect(release)
	return {holder = holder, face = face, lip = lip, gradient = faceGradient, scale = scale, shine = shineGradient}
end

local gui = new("ScreenGui", playerGui, {Name = "JetpackHUD", ResetOnSpawn = false, DisplayOrder = 30,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
-- Everything is laid out for a 1500x850 screen and scaled to fit, like SpaceGUI
local stage = new("Frame", gui, {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(600, 400)})
local stageScale = new("UIScale", stage, {Scale = 1})
local function fit()
	local size = gui.AbsoluteSize
	local s = math.min(size.X / 1500, size.Y / 850)
	stageScale.Scale = math.clamp(math.max(s, UserInputService.TouchEnabled and 0.75 or 0.55), 0.5, 2.4)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- Speech-bubble toast above the buttons
local toast = new("Frame", stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170),
	Size = UDim2.fromOffset(560, 54), BackgroundColor3 = C.White, Visible = false})
corner(toast, 16); gradient(toast, C.Panel, C.Deep); stroke(toast, C.Ink, 3)
local toastRim = new("Frame", toast, {BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)})
corner(toastRim, 13); stroke(toastRim, C.Cyan, 2, 0.2)
local toastText = text(toast, "", 21, {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), TextWrapped = true})
local toastScale = new("UIScale", toast, {Scale = 1})
local toastId = 0
local function say(message)
	toastId += 1
	local mine = toastId
	toastText.Text = message
	toast.Visible = true
	toastScale.Scale = 0.6
	tween(toastScale, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
	task.delay(3, function() if toastId == mine then toast.Visible = false end end)
end

-- LAUNCH: big orange button with a wiggling rocket
local launchSlot = new("Frame", stage, {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, HIDDEN_Y), Size = UDim2.fromOffset(320, 116), Visible = false})
local launch = cartoonButton(launchSlot, 320, 116, C.OrangeTop, C.Orange)
local rocket
if Icons then
	rocket = Icons.new("Rocket", launch.face, 78)
	rocket.AnchorPoint = Vector2.new(0.5, 0.5)
	rocket.Position = UDim2.fromOffset(58, 50)
	rocket.ZIndex = 4
	for _, d in ipairs(rocket:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 3 end end
end
local launchText = text(launch.face, "LAUNCH!", 50, {Position = UDim2.fromOffset(Icons and 100 or 0, 0),
	Size = UDim2.new(1, Icons and -112 or 0, 1, 0)})
local launchSub = text(launch.face, "", 18, {Position = UDim2.new(0, Icons and 100 or 0, 1, -30),
	Size = UDim2.new(1, Icons and -112 or 0, 0, 22), Visible = false})
if keyboard then keycap(launch.holder, "F") end

-- MY PAD: smaller blue button, shown while you're off the pad
local padSlot = new("Frame", stage, {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, SHOWN_Y), Size = UDim2.fromOffset(210, 75)})
local pad = cartoonButton(padSlot, 210, 75, Color3.fromRGB(110, 190, 255), C.Blue)
text(pad.face, "MY PAD", 30, {Size = UDim2.fromScale(1, 1)})
if keyboard then keycap(pad.holder, "T") end

-- Animations: a shine sweeps across LAUNCH, the button breathes and the rocket wiggles
task.spawn(function()
	while gui.Parent do
		if launchSlot.Visible then
			launch.shine.Offset = Vector2.new(-1, 0)
			tween(launch.shine, 0.9, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Sine)
		end
		task.wait(2.2)
	end
end)
local breathe, wiggle
local function startIdle()
	if breathe then breathe:Cancel() end
	launch.scale.Scale = 1
	breathe = tween(launch.scale, 0.7, {Scale = 1.06}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	if rocket and not wiggle then
		rocket.Rotation = -10
		wiggle = tween(rocket, 0.35, {Rotation = 10}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
end
local function stopIdle()
	if breathe then breathe:Cancel(); breathe = nil end
	launch.scale.Scale = 1
end

local slideToken = 0
local function slide(slot, show)
	slideToken += 1
	local mine = slideToken
	if show then
		slot.Visible = true
		slot.Position = UDim2.new(0.5, 0, 1, HIDDEN_Y)
		tween(slot, 0.5, {Position = UDim2.new(0.5, 0, 1, SHOWN_Y)}, Enum.EasingStyle.Back)
	else
		tween(slot, 0.28, {Position = UDim2.new(0.5, 0, 1, HIDDEN_Y)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.3, function() if slideToken == mine then slot.Visible = false end end)
	end
end
-- Slide the pad button separately so the two animations don't cancel each other's hide
local padToken = 0
local function slidePad(show)
	padToken += 1
	local mine = padToken
	if show then
		padSlot.Visible = true
		tween(padSlot, 0.45, {Position = UDim2.new(0.5, 0, 1, SHOWN_Y)}, Enum.EasingStyle.Back)
	else
		tween(padSlot, 0.25, {Position = UDim2.new(0.5, 0, 1, HIDDEN_Y)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.27, function() if padToken == mine then padSlot.Visible = false end end)
	end
end

local function menuOpen()
	for _, name in ipairs(MENU_ATTRIBUTES) do
		if player:GetAttribute(name) then return true end
	end
	return false
end

-- Whether LAUNCH has its ready (orange) look; set by setLook below
local ready = nil
local REASONS = {
	nopad = "Stand on your launch pad to launch! Press MY PAD to go there.",
	cooldown = "Your jetpack is recharging...",
	ceiling = "You're as high as this jetpack can go. Get a better one in Jetpacks!",
	nocharacter = "You can't launch right now.",
	flying = "You're already flying!",
}
local function doLaunch()
	local ok, reason = Flight.Launch()
	if ok then
		stopIdle()
		launch.scale.Scale = 1.18
		tween(launch.scale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
		task.delay(0.32, function() if ready then startIdle() end end)
	else
		say(REASONS[reason] or "You can't launch right now.")
	end
end
local teleporting = false
local function goToPad()
	if teleporting then return end
	teleporting = true
	Flight.Cancel()
	local ok, success, message = pcall(teleportRemote.InvokeServer, teleportRemote)
	if not ok then say("Couldn't reach the server, try again.")
	elseif not success then say(message or "You can't teleport right now.") end
	teleporting = false
end
launch.holder.Activated:Connect(doLaunch)
pad.holder.Activated:Connect(goToPad)

-- Flight controls hint, shown while flying
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local hint = text(gui, touch and "Stick: fly where you look   -   Jump: up   -   Touch the ground to land"
	or "WASD: fly where you look   -   Space: up   -   Ctrl / Q: down   -   Touch the ground to land",
	20, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(700, 30),
		TextTransparency = 1, TextScaled = false})
local hintStroke = hint:FindFirstChildOfClass("UIStroke")
hintStroke.Transparency = 1
local hintShown = false
local function showHint(on)
	if on == hintShown then return end
	hintShown = on
	tween(hint, 0.4, {TextTransparency = on and 0 or 1})
	tween(hintStroke, 0.4, {Transparency = on and 0 or 1})
end

-- Watch the pad and the jetpack's state
local onPad = false
local showLaunch, showPad = false, true
local function setLook(isReady, cooldown)
	if isReady ~= ready then
		ready = isReady
		launch.gradient.Color = isReady and ColorSequence.new(C.OrangeTop, C.Orange) or ColorSequence.new(C.GreyTop, C.Grey)
		launch.lip.BackgroundColor3 = (isReady and C.Orange or C.Grey):Lerp(C.Ink, LIP_DARKEN)
		launchText.TextSize = isReady and 50 or 34
		launchText.Position = UDim2.fromOffset(Icons and 100 or 0, isReady and 0 or -10)
		launchSub.Visible = not isReady
		if isReady then
			startIdle()
		else
			stopIdle()
		end
	end
	if not isReady then launchSub.Text = ("%.1fs"):format(cooldown) end
end
task.spawn(function()
	while gui.Parent do
		local state, cooldown = Flight.Status()
		onPad = Flight.OnLaunchPad()
		local hidden = menuOpen()
		local wantLaunch, wantPad = onPad and not hidden, not onPad and not hidden
		if wantLaunch ~= showLaunch then showLaunch = wantLaunch; slide(launchSlot, wantLaunch) end
		if wantPad ~= showPad then showPad = wantPad; slidePad(wantPad) end
		showHint((state == "Thrust" or state == "Flying") and not hidden)
		if state == "Thrust" or state == "Flying" then
			launchText.Text = "FLYING!"; setLook(true, 0)
		elseif cooldown > 0 then
			launchText.Text = "RECHARGING"; setLook(false, cooldown)
		else
			launchText.Text = "LAUNCH!"; setLook(true, 0)
		end
		task.wait(0.1)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Config.LaunchKey or input.KeyCode == Config.LaunchGamepadButton then
		if showLaunch then doLaunch() end
	elseif input.KeyCode == Config.TeleportKey or input.KeyCode == Config.TeleportGamepadButton then goToPad() end
end)
