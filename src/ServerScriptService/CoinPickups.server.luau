-- CoinPickups: scatters coins over each planet's surface. Touching one adds its value to the
-- player's "Coins" attribute (saved by PlayerSaving, spent on jetpacks), and it reappears somewhere
-- else on the planet a little later. Coins on higher planets are worth more, so each new jetpack pays
-- for the next one faster. StarterPlayerScripts.CoinEffects spins the coins and shows "+value" pop-ups.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COINS_PER_PLANET = 18
local RESPAWN = 15                     -- seconds before a collected coin reappears elsewhere
local VALUES = {5, 15, 40, 100, 250}   -- what one coin is worth on planets 01 to 05
local TAG = "Coin"
local CURRENCY = "Coins"

local map = workspace:WaitForChild("JetpackPetRescueMap")
local collectedRemote = Instance.new("RemoteEvent")
collectedRemote.Name = "CoinCollected"
collectedRemote.Parent = ReplicatedStorage
local rng = Random.new()

-- A random open spot on the planet's ground: not on top of eggs, rocks or other decorations
local function findSpot(planet, surface)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {planet}
	local top = surface.Position.Y + surface.Size.Y / 2
	local radius = math.min(surface.Size.X, surface.Size.Z) / 2 * 0.8
	for _ = 1, 12 do
		local angle, dist = rng:NextNumber(0, math.pi * 2), radius * math.sqrt(rng:NextNumber())
		local from = Vector3.new(surface.Position.X + math.cos(angle) * dist, top + 60, surface.Position.Z + math.sin(angle) * dist)
		local hit = workspace:Raycast(from, Vector3.new(0, -200, 0), params)
		if hit and hit.Instance == surface and hit.Normal.Y > 0.8 then return hit.Position + Vector3.new(0, 2.5, 0) end
	end
end

local function makeCoin(folder, value)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder -- stands on its edge like a wheel
	coin.Size = Vector3.new(0.6, 3, 3)
	coin.Color = Color3.fromRGB(255, 190, 30)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin:SetAttribute("Value", value)
	CollectionService:AddTag(coin, TAG)
	coin.Parent = folder
	return coin
end

-- The player whose character a touching part belongs to (skipping models like the worn jetpack)
local function toucher(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then return player, model end
		model = model:FindFirstAncestorOfClass("Model")
	end
end

local function show(coin, planet, surface)
	local spot = findSpot(planet, surface)
	if not spot then return false end
	coin.CFrame = CFrame.new(spot)
	coin.Transparency = 0
	coin.CanTouch = true
	return true
end

local function setUpPlanet(planet, value)
	local surface = planet:FindFirstChild("PlanetSurface")
	if not surface then return end
	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = planet
	for _ = 1, COINS_PER_PLANET do
		local coin = makeCoin(folder, value)
		local taken = not show(coin, planet, surface)
		coin.Touched:Connect(function(hit)
			if taken then return end
			local player, character = toucher(hit)
			if not player or not player:GetAttribute("DataLoaded") then return end -- wait until their save has loaded
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or (root.Position - coin.Position).Magnitude > 15 then return end
			taken = true
			coin.Transparency = 1
			coin.CanTouch = false
			player:SetAttribute(CURRENCY, (player:GetAttribute(CURRENCY) or 0) + value)
			collectedRemote:FireClient(player, coin.Position, value)
			task.delay(RESPAWN, function()
				while not show(coin, planet, surface) do task.wait(2) end
				taken = false
			end)
		end)
	end
end

-- Planets are named "01 • Moon" ... "05 • Jupiter": the number picks the coin value
for _, planet in ipairs(map:GetChildren()) do
	local index = tonumber(planet.Name:match("^(%d+)"))
	if planet:IsA("Model") and index and VALUES[index] then setUpPlanet(planet, VALUES[index]) end
end
