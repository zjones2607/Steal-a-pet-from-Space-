-- Jetpacks: straps each player's equipped jetpack to their back, sells jetpacks for Coins and lets
-- players equip the ones they own (tiers and prices are in ReplicatedStorage.Jetpacks.JetpackConfig),
-- shows the exhaust flames to everyone while its owner is flying, and teleports players to the
-- launch pad on their own base (the base button in SpaceGUI).
-- PlayerSaving saves the equipped tier ("Jetpack" attribute), the "Coins" attribute and the
-- "OwnedJetpacks" folder (a BoolValue per bought tier).
-- The flying itself happens on the player's own device (JetpackFlight), because Roblox gives each
-- player control of their own character's physics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Jetpacks")
local Config = require(folder:WaitForChild("JetpackConfig"))
local Models = require(folder:WaitForChild("JetpackModels"))

local equipRemote = Instance.new("RemoteFunction")
equipRemote.Name = "EquipJetpack"
equipRemote.Parent = folder
local buyRemote = Instance.new("RemoteFunction")
buyRemote.Name = "BuyJetpack"
buyRemote.Parent = folder
local thrustRemote = Instance.new("RemoteEvent")
thrustRemote.Name = "JetpackThrust"
thrustRemote.Parent = folder
local teleportRemote = Instance.new("RemoteFunction")
teleportRemote.Name = "TeleportToLaunchSite"
teleportRemote.Parent = folder

local map = workspace:WaitForChild("JetpackPetRescueMap")
local station = map:WaitForChild("SpaceStation")
local lastTeleport = {} -- [player] = os.clock() of their last teleport

-- Each jetpack's fuel is sized from where the planets really are: store each planet's landing top
-- (and the height just above it) on JetpackConfig so every player's device can read them.
local configModule = folder:WaitForChild("JetpackConfig")
for _, tier in ipairs(Config.Tiers) do
	local found = false
	for _, planet in ipairs(map:GetChildren()) do
		local surface = planet:FindFirstChild("PlanetSurface")
		if surface and planet.Name:find(tier.Planet, 1, true) then
			local top = surface.Position + Vector3.new(0, surface.Size.Y / 2, 0)
			configModule:SetAttribute("Ceiling_" .. tier.Id, math.floor(top.Y + Config.CeilingMargin))
			configModule:SetAttribute("PlanetTop_" .. tier.Id, top) -- JetpackFlight sizes each fuel tank from these
			found = true
		end
	end
	if not found then warn(("Jetpacks: couldn't find the %s for the %s"):format(tier.Planet, tier.Name)) end
end

local function torsoOf(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

-- Puts the equipped jetpack on the character, replacing the old one if the tier changed.
local function attach(player, force)
	local character = player.Character
	local torso = character and torsoOf(character)
	if not torso then return end
	local tier = Config.Equipped(player)
	local old = character:FindFirstChild("Jetpack")
	if old and old:GetAttribute("Tier") == tier.Id and not force then return end
	if old then old:Destroy() end
	Models.Wear(tier.Id, torso).Parent = character
end

local function onCharacter(player, character)
	if not character:WaitForChild("HumanoidRootPart", 10) then return end
	local deadline = os.clock() + 10
	while not torsoOf(character) and os.clock() < deadline and character.Parent do task.wait(0.1) end
	attach(player)
end

local function ownedFolder(player)
	local owned = player:FindFirstChild(Config.OwnedFolder)
	if not owned then
		owned = Instance.new("Folder")
		owned.Name = Config.OwnedFolder
		owned.Parent = player
	end
	return owned
end

local function onPlayerAdded(player)
	ownedFolder(player)
	player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	-- Body scaling is applied with the avatar's appearance, so refit the jetpack to the final torso size
	player.CharacterAppearanceLoaded:Connect(function() attach(player, true) end)
	player:GetAttributeChangedSignal(Config.EquippedAttribute):Connect(function() attach(player) end)
	-- The save restores the equipped attribute before the owned folder, so check again once it's all in
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function() attach(player) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end

equipRemote.OnServerInvoke = function(player, id)
	local tier = type(id) == "string" and Config.ById[id]
	if not tier then return false, "That jetpack doesn't exist." end
	if not player:GetAttribute("DataLoaded") then return false, "Your data is still loading, try again in a moment." end
	if not Config.Owns(tier, player) then return false, ("Buy the %s first."):format(tier.Name) end
	player:SetAttribute(Config.EquippedAttribute, tier.Id)
	attach(player)
	return true, ("Equipped the %s!"):format(tier.Name)
end

-- Buying takes the coins, adds the tier to OwnedJetpacks and equips it straight away. Nothing
-- here yields, so two quick requests can't both spend the same coins.
buyRemote.OnServerInvoke = function(player, id)
	local tier = type(id) == "string" and Config.ById[id]
	if not tier then return false, "That jetpack doesn't exist." end
	if not player:GetAttribute("DataLoaded") then return false, "Your data is still loading, try again in a moment." end
	if Config.Owns(tier, player) then return false, ("You already own the %s."):format(tier.Name) end
	local coins = Config.Coins(player)
	if coins < tier.Price then
		return false, ("You need %d more coins for the %s."):format(tier.Price - coins, tier.Name)
	end
	player:SetAttribute(Config.CurrencyAttribute, coins - tier.Price)
	local bought = Instance.new("BoolValue")
	bought.Name = tier.Id
	bought.Value = true
	bought.Parent = ownedFolder(player)
	player:SetAttribute(Config.EquippedAttribute, tier.Id)
	attach(player)
	return true, ("Bought the %s!"):format(tier.Name)
end

-- The LaunchZone on the base this player owns (StationClaims hands out the bases)
local function launchZoneOf(player)
	for _, plot in ipairs(station:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local site = plot:FindFirstChild("LaunchSite", true)
			return site and site:FindFirstChild("LaunchZone")
		end
	end
end

teleportRemote.OnServerInvoke = function(player)
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < Config.TeleportCooldown then
		return false, "Teleport is recharging, try again in a moment."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then return false, "You can't teleport right now." end
	local zone = launchZoneOf(player)
	local spot = zone and zone:FindFirstChild("SpawnPoint")
	if not spot then return false, "You don't have a base yet." end
	lastTeleport[player] = now
	local target = spot.WorldCFrame
	-- Let their device load the base first so they don't land on ground that isn't there yet
	pcall(player.RequestStreamAroundAsync, player, target.Position, 3)
	if not root.Parent then return false, "You can't teleport right now." end
	character:PivotTo(target + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.5, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- (on, flying): flames on/off, and whether the player is in the air on their jetpack at all. The
-- character's "JetpackFlying" attribute lets every device animate the flyer (JetpackAnimations).
thrustRemote.OnServerEvent:Connect(function(player, on, flying)
	local character = player.Character
	if character and type(flying) == "boolean" and character:GetAttribute("JetpackFlying") ~= flying then
		character:SetAttribute("JetpackFlying", flying)
	end
	local pack = character and character:FindFirstChild("Jetpack")
	if not pack or pack:GetAttribute("Thrusting") == (on == true) then return end
	pack:SetAttribute("Thrusting", on == true)
	Models.SetThrust(pack, on == true)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
Players.PlayerRemoving:Connect(function(player) lastTeleport[player] = nil end)
