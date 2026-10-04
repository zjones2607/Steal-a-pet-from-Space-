-- JetpackHUD: the on-screen jetpack flight controls. (Buying and equipping jetpacks is the
-- Jetpacks page in SpaceGUI.) A row at the bottom of the screen has:
--   LAUNCH    flies with the equipped jetpack (JetpackFlight); works on a launch pad. Key: F / gamepad X
--   MY PAD    teleports to the launch pad on your station (TeleportToLaunchSite). Key: T / gamepad L2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild("Jetpacks")
local Config = require(folder:WaitForChild("JetpackConfig"))
local Flight = require(folder:WaitForChild("JetpackFlight"))
local teleportRemote = folder:WaitForChild("TeleportToLaunchSite")

local C = {
	bg = Color3.fromRGB(20, 29, 51), panel = Color3.fromRGB(30, 42, 72), item = Color3.fromRGB(40, 55, 95),
	accent = Color3.fromRGB(80, 217, 236), orange = Color3.fromRGB(255, 140, 40), green = Color3.fromRGB(72, 232, 120),
	gold = Color3.fromRGB(255, 215, 80), grey = Color3.fromRGB(90, 100, 125), text = Color3.fromRGB(230, 251, 255),
	dim = Color3.fromRGB(150, 170, 200), red = Color3.fromRGB(235, 80, 90),
}
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function corner(inst, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, inst) end
local function stroke(inst, color, thickness) return new("UIStroke", {Color = color, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst) end
local function button(text, size, color, parent)
	local b = new("TextButton", {Text = text, Size = size, BackgroundColor3 = color, TextColor3 = C.text,
		Font = Enum.Font.GothamBlack, TextScaled = true, AutoButtonColor = true}, parent)
	corner(b, 12)
	new("UITextSizeConstraint", {MaxTextSize = 22}, b)
	new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, b)
	return b
end

local gui = new("ScreenGui", {Name = "JetpackHUD", ResetOnSpawn = false, DisplayOrder = 30, IgnoreGuiInset = false}, player:WaitForChild("PlayerGui"))

-- Toast message above the buttons
local toast = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.new(0, 420, 0, 34),
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextScaled = true, Visible = false}, gui)
corner(toast, 10)
new("UITextSizeConstraint", {MaxTextSize = 18}, toast)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, toast)
local toastId = 0
local function say(text, color)
	toastId += 1
	local mine = toastId
	toast.Text = text; toast.TextColor3 = color or C.text; toast.Visible = true
	task.delay(3, function() if toastId == mine then toast.Visible = false end end)
end

-- Bottom row: LAUNCH | MY PAD
local bar = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 300, 0, 68),
	BackgroundTransparency = 1}, gui)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10)}, bar)
local launchButton = button("LAUNCH", UDim2.new(0, 170, 0, 68), C.orange, bar)
local launchStroke = stroke(launchButton, Color3.new(1, 1, 1), 3)
local padButton = button("MY PAD", UDim2.new(0, 120, 0, 52), C.item, bar)
stroke(padButton, C.accent)

local REASONS = {
	nopad = "Stand on a launch pad to launch. Press MY PAD (T) to go to yours.",
	cooldown = "Your jetpack is recharging...",
	ceiling = "You're already as high as this jetpack can go. Buy a better one!",
	nocharacter = "You can't launch right now.",
	flying = "You're already flying!",
}
local function launch()
	local ok, reason = Flight.Launch()
	if not ok then say(REASONS[reason] or "You can't launch right now.", C.gold) end
end
local teleporting = false
local function goToPad()
	if teleporting then return end
	teleporting = true
	Flight.Cancel()
	local ok, success, message = pcall(teleportRemote.InvokeServer, teleportRemote)
	if not ok then say("Couldn't reach the server.", C.red)
	elseif not success then say(message or "You can't teleport right now.", C.gold) end
	teleporting = false
end
launchButton.MouseButton1Click:Connect(launch)
padButton.MouseButton1Click:Connect(goToPad)

-- LAUNCH shows whether you can fly right now
task.spawn(function()
	while gui.Parent do
		local state, cooldown = Flight.Status()
		local onPad = Flight.OnLaunchPad()
		if state == "Thrust" then
			launchButton.Text = "FLYING!"; launchButton.BackgroundColor3 = C.green
		elseif state == "Falling" then
			launchButton.Text = onPad and "LAUNCH" or "FALLING"; launchButton.BackgroundColor3 = onPad and C.orange or C.grey
		elseif cooldown > 0 then
			launchButton.Text = ("RECHARGING %.1f"):format(cooldown); launchButton.BackgroundColor3 = C.grey
		else
			launchButton.Text = "LAUNCH"; launchButton.BackgroundColor3 = onPad and C.orange or C.grey
		end
		launchStroke.Transparency = (onPad and state ~= "Thrust" and cooldown <= 0) and 0 or 0.7
		task.wait(0.15)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Config.LaunchKey or input.KeyCode == Config.LaunchGamepadButton then launch()
	elseif input.KeyCode == Config.TeleportKey or input.KeyCode == Config.TeleportGamepadButton then goToPad() end
end)
