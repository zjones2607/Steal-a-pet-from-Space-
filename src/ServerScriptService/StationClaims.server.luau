-- StationClaims: gives every player their own station when they join, spawns them on it
-- (also after dying), and shows the owner's username above their station for everyone.
-- Unclaimed stations show no sign.
-- The owner is stored on the plot as OwnerUserId / OwnerName attributes, and the player gets
-- a "Station" attribute with the plot's name. Stations free up when their owner leaves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
local Upgrades = require(script.Parent:WaitForChild("StationUpgrades"))
local NAVY = Color3.fromRGB(28, 38, 74)
local SPAWN_DISTANCE = 20     -- studs from the station's centre towards the plaza, in front of the hatch
local SIGN_HEIGHT = 40        -- studs above the pad

local claims = {}             -- [plot] = player

local function plotByIndex(i) return station:FindFirstChild("StationPlot" .. i) end
local function pad(plot) return plot.Core.Station_Pad end

local function makeSign(plot)
	local top = pad(plot).CFrame.Position + Vector3.new(0, SIGN_HEIGHT, 0)
	local anchor = Instance.new("Part")
	anchor.Name = "OwnerSign"; anchor.Size = Vector3.new(1, 1, 1); anchor.CFrame = CFrame.new(top)
	anchor.Anchored = true; anchor.Transparency = 1; anchor.CanCollide = false; anchor.CanTouch = false; anchor.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerBillboard"; gui.Size = UDim2.fromScale(48, 8); gui.MaxDistance = 900
	gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = anchor
	local function label(name, text, y, h, color)
		local t = Instance.new("TextLabel")
		t.Name = name; t.Text = text; t.Position = UDim2.fromScale(0, y); t.Size = UDim2.fromScale(1, h)
		t.BackgroundTransparency = 1; t.TextScaled = true; t.Font = Enum.Font.GothamBlack; t.TextColor3 = color
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = NAVY; stroke.Parent = t
		t.Parent = gui
		return t
	end
	label("OwnerName", "", 0, 1, Color3.new(1, 1, 1))
	anchor.Parent = plot
	return anchor
end

local function updateSign(plot)
	local sign = plot:FindFirstChild("OwnerSign") or makeSign(plot)
	local owner = claims[plot]
	local gui = sign.OwnerBillboard
	gui.OwnerName.Text = owner and owner.Name or ""
	gui.Enabled = owner ~= nil
	-- The colour is left alone after creation: StationOwnerLabels restyles it per player
end

-- Standing on the pad in front of the airlock, facing the station
local function spawnCFrame(plot)
	local p = pad(plot)
	local centre = p.CFrame.Position
	local plaza = station.SpawnHub.PlazaRim.CFrame.Position -- the base may not sit at the world's centre
	local toPlaza = Vector3.new(plaza.X - centre.X, 0, plaza.Z - centre.Z).Unit
	local floorY = centre.Y + p.Size.Y/2
	local pos = Vector3.new(centre.X, floorY + 3, centre.Z) + toPlaza * SPAWN_DISTANCE
	return CFrame.lookAt(pos, Vector3.new(centre.X, pos.Y, centre.Z))
end

local function claim(player)
	for i = 1, 8 do
		local plot = plotByIndex(i)
		if plot and not claims[plot] then
			claims[plot] = player
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.Name)
			player:SetAttribute("Station", plot.Name)
			updateSign(plot)
			return plot
		end
	end
	warn(("StationClaims: no free station for %s"):format(player.Name))
end

local function release(player)
	for plot, owner in pairs(claims) do
		if owner == player then
			claims[plot] = nil
			plot:SetAttribute("OwnerUserId", nil)
			plot:SetAttribute("OwnerName", nil)
			Upgrades.SetTier(plot, 0)
			updateSign(plot)
		end
	end
end

local function plotOf(player)
	for plot, owner in pairs(claims) do if owner == player then return plot end end
end

local function onCharacter(player, character)
	local plot = plotOf(player)
	if not plot then return end -- no free station: they stay at the plaza spawn
	character:WaitForChild("HumanoidRootPart", 10)
	if not character.Parent then character.AncestryChanged:Wait() end
	RunService.Heartbeat:Wait() -- let Roblox finish placing the character first
	character:PivotTo(spawnCFrame(plot))
end

local function onPlayerAdded(player)
	claim(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end

for i = 1, 8 do local plot = plotByIndex(i); if plot then updateSign(plot) end end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
Players.PlayerRemoving:Connect(release)
