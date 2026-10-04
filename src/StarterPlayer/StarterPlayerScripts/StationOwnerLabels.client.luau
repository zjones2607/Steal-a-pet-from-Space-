-- StationOwnerLabels: highlights your own station's name sign (made by StationClaims) in gold,
-- so it stands out from the other players' stations.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
local GOLD, WHITE = Color3.fromRGB(255, 215, 80), Color3.new(1, 1, 1)
local SUBTITLE = Color3.fromRGB(160, 215, 255)

local function refresh(plot)
	local sign = plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerBillboard")
	if not gui then return end
	local mine = plot:GetAttribute("OwnerUserId") == player.UserId
	gui.OwnerName.TextColor3 = mine and GOLD or WHITE
	gui.Subtitle.Text = mine and "Your Station" or (plot:GetAttribute("StationName") or plot.Name)
	gui.Subtitle.TextColor3 = mine and GOLD or SUBTITLE
end

local function watch(plot)
	if not plot.Name:match("^StationPlot%d+$") then return end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() task.defer(refresh, plot) end)
	plot.ChildAdded:Connect(function(child) if child.Name == "OwnerSign" then task.defer(refresh, plot) end end)
	refresh(plot)
end

for _, plot in ipairs(station:GetChildren()) do watch(plot) end
station.ChildAdded:Connect(watch)
