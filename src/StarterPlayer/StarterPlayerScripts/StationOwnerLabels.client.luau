-- StationOwnerLabels: shows your own username sign (made by StationClaims) in gold,
-- so it stands out from the other players' stations.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
local GOLD, WHITE = Color3.fromRGB(255, 215, 80), Color3.new(1, 1, 1)

local function refresh(plot)
	local sign = plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerBillboard")
	if not gui then return end
	local mine = plot:GetAttribute("OwnerUserId") == player.UserId
	gui.OwnerName.TextColor3 = mine and GOLD or WHITE
end

local function watch(plot)
	if not plot.Name:match("^StationPlot%d+$") then return end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() task.defer(refresh, plot) end)
	plot.ChildAdded:Connect(function(child) if child.Name == "OwnerSign" then task.defer(refresh, plot) end end)
	refresh(plot)
end

for _, plot in ipairs(station:GetChildren()) do watch(plot) end
station.ChildAdded:Connect(watch)
