-- JetpackHUD: the on-screen jetpack controls. A row at the bottom of the screen has:
--   JETPACKS  opens the shop to buy and equip jetpacks (BuyJetpack / EquipJetpack remotes)
--   LAUNCH    flies with the equipped jetpack (JetpackFlight); works on a launch pad. Key: F / gamepad X
--   MY PAD    teleports to the launch pad on your station (TeleportToLaunchSite). Key: T / gamepad L2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild("Jetpacks")
local Config = require(folder:WaitForChild("JetpackConfig"))
local Flight = require(folder:WaitForChild("JetpackFlight"))
local buyRemote = folder:WaitForChild("BuyJetpack")
local equipRemote = folder:WaitForChild("EquipJetpack")
local teleportRemote = folder:WaitForChild("TeleportToLaunchSite")

local C = {
	bg = Color3.fromRGB(20, 29, 51), panel = Color3.fromRGB(30, 42, 72), item = Color3.fromRGB(40, 55, 95),
	accent = Color3.fromRGB(80, 217, 236), orange = Color3.fromRGB(255, 140, 40), green = Color3.fromRGB(72, 232, 120),
	gold = Color3.fromRGB(255, 215, 80), grey = Color3.fromRGB(90, 100, 125), text = Color3.fromRGB(230, 251, 255),
	dim = Color3.fromRGB(150, 170, 200), red = Color3.fromRGB(235, 80, 90),
}
local RARITY = {Common = Color3.fromRGB(200, 210, 230), Uncommon = Color3.fromRGB(110, 230, 140),
	Rare = Color3.fromRGB(90, 170, 255), Epic = Color3.fromRGB(200, 120, 255), Legendary = Color3.fromRGB(255, 200, 60)}

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

-- Bottom row: JETPACKS | LAUNCH | MY PAD
local bar = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 430, 0, 68),
	BackgroundTransparency = 1}, gui)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10)}, bar)
local shopButton = button("JETPACKS", UDim2.new(0, 120, 0, 52), C.item, bar)
stroke(shopButton, C.accent)
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

-- Shop window
local shop = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 470),
	BackgroundColor3 = C.bg, Visible = false, Active = true}, gui)
corner(shop, 16); stroke(shop, C.accent)
new("UISizeConstraint", {MaxSize = Vector2.new(620, 470)}, shop)
new("TextLabel", {Text = "JETPACKS", Position = UDim2.new(0, 18, 0, 10), Size = UDim2.new(0.5, 0, 0, 36), BackgroundTransparency = 1,
	TextColor3 = C.gold, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, shop)
local coinsLabel = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 14), Size = UDim2.new(0.4, 0, 0, 28),
	BackgroundTransparency = 1, TextColor3 = C.gold, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right}, shop)
local closeButton = button("X", UDim2.new(0, 36, 0, 36), C.red, shop)
closeButton.AnchorPoint = Vector2.new(1, 0); closeButton.Position = UDim2.new(1, -12, 0, 10)
local list = new("ScrollingFrame", {Position = UDim2.new(0, 14, 0, 58), Size = UDim2.new(1, -28, 1, -72), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, shop)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
new("UIPadding", {PaddingRight = UDim.new(0, 8)}, list)

local rows = {}
local busy = false
for _, tier in ipairs(Config.Tiers) do
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = C.panel, LayoutOrder = tier.Index}, list)
	corner(row, 12)
	local rowStroke = stroke(row, RARITY[tier.Rarity] or C.dim, 2)
	local swatch = new("Frame", {Position = UDim2.new(0, 10, 0.5, -26), Size = UDim2.new(0, 52, 0, 52), BackgroundColor3 = tier.Colors.Body}, row)
	corner(swatch, 10)
	new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.75),
		BackgroundColor3 = tier.Colors.Tank}, swatch)
	stroke(swatch, tier.Colors.Glow, 3)
	new("TextLabel", {Text = tier.Name, Position = UDim2.new(0, 74, 0, 8), Size = UDim2.new(1, -220, 0, 24), BackgroundTransparency = 1,
		TextColor3 = C.text, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, row)
	new("TextLabel", {Text = ("%s  •  reaches %s  •  speed %d"):format(tier.Rarity, Config.PlanetLabel(tier), tier.Speed),
		Position = UDim2.new(0, 74, 0, 36), Size = UDim2.new(1, -220, 0, 20), BackgroundTransparency = 1,
		TextColor3 = RARITY[tier.Rarity] or C.dim, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left}, row)
	local action = button("", UDim2.new(0, 130, 0, 44), C.item, row)
	action.AnchorPoint = Vector2.new(1, 0.5); action.Position = UDim2.new(1, -12, 0.5, 0)
	action.MouseButton1Click:Connect(function()
		if busy then return end
		local owned = Config.Owns(tier, player)
		if owned and Config.Equipped(player) == tier then return end
		busy = true
		local remote = owned and equipRemote or buyRemote
		local ok, success, message = pcall(remote.InvokeServer, remote, tier.Id)
		busy = false
		if not ok then say("Couldn't reach the server.", C.red)
		else say(message or (success and "Done!" or "That didn't work."), success and C.green or C.gold) end
	end)
	rows[tier.Id] = {action = action, stroke = rowStroke}
end

local function refresh()
	local coins = Config.Coins(player)
	coinsLabel.Text = ("%d coins"):format(coins)
	local equipped = Config.Equipped(player)
	for _, tier in ipairs(Config.Tiers) do
		local r = rows[tier.Id]
		if equipped == tier then
			r.action.Text = "EQUIPPED"; r.action.BackgroundColor3 = C.green; r.stroke.Thickness = 3
		elseif Config.Owns(tier, player) then
			r.action.Text = "EQUIP"; r.action.BackgroundColor3 = C.accent; r.stroke.Thickness = 2
		else
			r.action.Text = ("BUY  %d"):format(tier.Price)
			r.action.BackgroundColor3 = coins >= tier.Price and C.orange or C.grey; r.stroke.Thickness = 2
		end
	end
end
player:GetAttributeChangedSignal(Config.CurrencyAttribute):Connect(refresh)
player:GetAttributeChangedSignal(Config.EquippedAttribute):Connect(refresh)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
local function watchOwned(owned)
	if owned.Name ~= Config.OwnedFolder then return end
	owned.ChildAdded:Connect(refresh); owned.ChildRemoved:Connect(refresh)
	refresh()
end
player.ChildAdded:Connect(watchOwned)
local owned = player:FindFirstChild(Config.OwnedFolder)
if owned then watchOwned(owned) end
refresh()

local function setShop(open)
	shop.Visible = open
	if open then refresh() end
end
shopButton.MouseButton1Click:Connect(function() setShop(not shop.Visible) end)
closeButton.MouseButton1Click:Connect(function() setShop(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Config.LaunchKey or input.KeyCode == Config.LaunchGamepadButton then launch()
	elseif input.KeyCode == Config.TeleportKey or input.KeyCode == Config.TeleportGamepadButton then goToPad() end
end)
