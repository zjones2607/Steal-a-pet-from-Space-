-- Announcements: shows admin announcements (sent from the admin panel) as a banner for everyone.
-- The banner only exists on screen while an announcement is showing: it slides down from above the
-- top of the screen, stays for SHOW_FOR seconds, slides back up and is then hidden completely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local SHOW_FOR = 6
local SHOWN = UDim2.new(0.5, 0, 0, 56)
-- Far enough up to be fully off-screen even with Roblox's top bar inset (the GUI sits below it).
local HIDDEN = UDim2.new(0.5, 0, 0, -220)

local gui = Instance.new("ScreenGui")
gui.Name = "Announcements"; gui.ResetOnSpawn = false; gui.DisplayOrder = 90
gui.Parent = player:WaitForChild("PlayerGui")
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0); banner.Position = HIDDEN; banner.Visible = false
banner.Size = UDim2.new(0.6, 0, 0, 84); banner.BackgroundColor3 = Color3.fromRGB(20, 29, 51); banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", banner); stroke.Color = Color3.fromRGB(255, 215, 80); stroke.Thickness = 2
local limit = Instance.new("UISizeConstraint", banner); limit.MaxSize = Vector2.new(640, 84)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 26); title.Position = UDim2.new(0, 12, 0, 6); title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack; title.TextSize = 16; title.TextColor3 = Color3.fromRGB(255, 215, 80)
title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = banner
local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -24, 1, -36); body.Position = UDim2.new(0, 12, 0, 30); body.BackgroundTransparency = 1
body.Font = Enum.Font.GothamBold; body.TextSize = 18; body.TextWrapped = true; body.TextColor3 = Color3.fromRGB(230, 251, 255)
body.TextXAlignment = Enum.TextXAlignment.Left; body.TextYAlignment = Enum.TextYAlignment.Top; body.Parent = banner

local shown = 0   -- counts announcements, so an older one's timer never hides a newer one
local tween
local function slide(position, info)
	if tween then tween:Cancel() end
	tween = TweenService:Create(banner, info, {Position = position})
	tween:Play()
	return tween
end
ReplicatedStorage:WaitForChild("AdminAnnouncement").OnClientEvent:Connect(function(text, from)
	shown += 1
	local mine = shown
	title.Text = "📢 Announcement from " .. tostring(from)
	body.Text = tostring(text)
	if not banner.Visible then banner.Position = HIDDEN end -- otherwise it's already showing, or sliding out
	banner.Visible = true
	slide(SHOWN, TweenInfo.new(0.35, Enum.EasingStyle.Back))
	task.delay(SHOW_FOR, function()
		if shown ~= mine then return end
		slide(HIDDEN, TweenInfo.new(0.3)).Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and shown == mine then banner.Visible = false end
		end)
	end)
end)
