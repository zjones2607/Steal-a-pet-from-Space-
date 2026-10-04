-- AdminPanelClient: the admin panel window. AdminPanel (server) only copies this into admins'
-- PlayerGui, and checks every request again itself. Open with the ADMIN button or Right Shift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = script.Parent
local remote = ReplicatedStorage:WaitForChild("AdminRemote")

local C = {
	bg = Color3.fromRGB(20, 29, 51), panel = Color3.fromRGB(30, 42, 72), item = Color3.fromRGB(40, 55, 95),
	accent = Color3.fromRGB(80, 217, 236), gold = Color3.fromRGB(255, 215, 80), red = Color3.fromRGB(235, 80, 90),
	text = Color3.fromRGB(230, 251, 255), dim = Color3.fromRGB(150, 170, 200),
}
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function round(inst, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, inst) end
local function button(text, parent, color, size)
	local b = new("TextButton", {Text = text, Size = size or UDim2.new(0, 120, 0, 30), BackgroundColor3 = color or C.item,
		TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true}, parent)
	round(b, 6)
	return b
end
local function row(parent, height)
	local f = new("Frame", {Size = UDim2.new(1, 0, 0, height or 30), BackgroundTransparency = 1}, parent)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, f)
	return f
end
local function label(text, parent, color)
	return new("TextLabel", {Text = text, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, TextColor3 = color or C.dim,
		Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, parent)
end
local function textbox(placeholder, parent, width)
	local t = new("TextBox", {PlaceholderText = placeholder, Text = "", Size = UDim2.new(0, width or 250, 0, 30), BackgroundColor3 = C.item,
		TextColor3 = C.text, PlaceholderColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 14, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left}, parent)
	round(t, 6); new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, t)
	return t
end

-- Window
local toggle = button("ADMIN", gui, C.red, UDim2.new(0, 80, 0, 32))
toggle.AnchorPoint = Vector2.new(0.5, 0); toggle.Position = UDim2.new(0.5, 0, 0, 8)
local window = new("Frame", {Size = UDim2.new(0, 460, 0, 400), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg, Visible = false, Active = true}, gui)
round(window, 12)
new("UIStroke", {Color = C.accent, Thickness = 2}, window)
new("UISizeConstraint", {MaxSize = Vector2.new(460, 400)}, window)
new("TextLabel", {Text = "Admin Panel", Size = UDim2.new(1, -50, 0, 40), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1,
	TextColor3 = C.gold, Font = Enum.Font.GothamBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left}, window)
local close = button("X", window, C.red, UDim2.new(0, 30, 0, 30))
close.Position = UDim2.new(1, -38, 0, 6)
local status = new("TextLabel", {Text = "", Size = UDim2.new(1, -28, 0, 22), Position = UDim2.new(0, 14, 1, -28), BackgroundTransparency = 1,
	TextColor3 = C.accent, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, window)
local tabsBar = new("Frame", {Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 42), BackgroundTransparency = 1}, window)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, tabsBar)
local body = new("Frame", {Size = UDim2.new(1, -28, 1, -112), Position = UDim2.new(0, 14, 0, 80), BackgroundTransparency = 1}, window)

local function call(action, ...)
	status.Text = "..."; status.TextColor3 = C.dim
	local ok, success, result = pcall(remote.InvokeServer, remote, action, ...)
	if not ok then success, result = false, "Couldn't reach the server" end
	if type(result) == "string" then
		status.Text = result; status.TextColor3 = success and C.accent or C.red
	else
		status.Text = ""
	end
	return success, result
end

local pages, tabButtons = {}, {}
local function showPage(name)
	for n, page in pairs(pages) do page.Visible = n == name end
	for n, b in pairs(tabButtons) do b.BackgroundColor3 = n == name and C.accent or C.item; b.TextColor3 = n == name and C.bg or C.text end
end
local function page(name)
	local p = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, body)
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, p)
	pages[name] = p
	local b = button(name, tabsBar, C.item, UDim2.new(0, 100, 1, 0))
	tabButtons[name] = b
	b.MouseButton1Click:Connect(function() showPage(name) end)
	return p
end

-- Players tab: pick a player, then act on them
local playersPage = page("Players")
local list = new("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = C.panel, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, playersPage)
round(list, 8)
new("UIListLayout", {Padding = UDim.new(0, 4)}, list)
new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10)}, list)
local selectedLabel = label("Select a player", playersPage, C.text)
local selectedId
local actionRow = row(playersPage)
local tierRow = row(playersPage)
local kickRow = row(playersPage)
local function needTarget(fn) return function() if selectedId then fn(selectedId) else status.Text = "Select a player first"; status.TextColor3 = C.red end end end
button("Teleport to", actionRow, nil, UDim2.new(0, 100, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("TeleportTo", id) end))
button("Bring", actionRow, nil, UDim2.new(0, 80, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("Bring", id) end))
button("Respawn", actionRow, nil, UDim2.new(0, 90, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("Respawn", id) end))
button("Reset eggs", actionRow, nil, UDim2.new(0, 100, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("ResetEggs", id) end))
new("TextLabel", {Text = "Station tier:", Size = UDim2.new(0, 90, 1, 0), BackgroundTransparency = 1, TextColor3 = C.dim,
	Font = Enum.Font.GothamBold, TextSize = 13}, tierRow)
for tier = 0, 3 do
	button(tostring(tier), tierRow, nil, UDim2.new(0, 44, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("SetTier", id, tier) end))
end
local reason = textbox("Kick reason (optional)", kickRow, 300)
button("Kick", kickRow, C.red, UDim2.new(0, 80, 1, 0)).MouseButton1Click:Connect(needTarget(function(id) call("Kick", id, reason.Text) end))

local function refreshPlayers()
	local ok, players = pcall(remote.InvokeServer, remote, "GetPlayers")
	if not ok or type(players) ~= "table" then return end
	for _, child in ipairs(list:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	local stillHere = false
	for _, p in ipairs(players) do
		local text = ("%s  (@%s)   %s   eggs: %d%s"):format(p.DisplayName, p.Name, p.Station and p.Station:gsub("StationPlot", "Station ") or "no station", p.Eggs, p.Admin and "   [admin]" or "")
		local b = button(text, list, p.UserId == selectedId and C.accent or C.item, UDim2.new(1, 0, 0, 26))
		b.TextXAlignment = Enum.TextXAlignment.Left; b.TextSize = 13
		if p.UserId == selectedId then b.TextColor3 = C.bg; stillHere = true end
		new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, b)
		b.MouseButton1Click:Connect(function()
			selectedId = p.UserId
			selectedLabel.Text = "Selected: " .. p.DisplayName .. " (@" .. p.Name .. ")"
			refreshPlayers()
		end)
	end
	if selectedId and not stillHere then selectedId = nil; selectedLabel.Text = "Select a player" end
end

-- Me tab
local mePage = page("Me")
label("Walk speed", mePage)
local speedRow = row(mePage)
for _, speed in ipairs({16, 32, 64, 100}) do
	button(tostring(speed), speedRow, nil, UDim2.new(0, 70, 1, 0)).MouseButton1Click:Connect(function() call("SetSpeed", speed) end)
end
label("Go to", mePage)
local goRow = row(mePage)
button("Plaza", goRow).MouseButton1Click:Connect(function() call("GoTo", "Plaza") end)
button("My station", goRow).MouseButton1Click:Connect(function() call("GoTo", "MyStation") end)

-- Server tab
local serverPage = page("Server")
label("Announcement to everyone in this server", serverPage)
local message = textbox("Type a message...", serverPage, 432)
local sendRow = row(serverPage)
button("Send", sendRow, C.accent).MouseButton1Click:Connect(function()
	local ok = call("Announce", message.Text)
	if ok then message.Text = "" end
end)

-- Open / close
local function setOpen(open)
	window.Visible = open
	player:SetAttribute("AdminPanelOpen", open) -- lets JetpackHUD hide its buttons
	if open then refreshPlayers() end
end
toggle.MouseButton1Click:Connect(function() setOpen(not window.Visible) end)
close.MouseButton1Click:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightShift then setOpen(not window.Visible) end
end)
showPage("Players")
task.spawn(function()
	while gui.Parent do
		if window.Visible and pages.Players.Visible then refreshPlayers() end
		task.wait(3)
	end
end)
