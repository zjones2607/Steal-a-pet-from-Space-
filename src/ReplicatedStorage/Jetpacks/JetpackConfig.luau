-- JetpackConfig: every jetpack tier, shared by the server (Jetpacks), the flight code
-- (JetpackFlight) and the GUI (SpaceGUI > Jetpacks page).
-- Better jetpacks fly higher, faster and steer better, and each costs more Coins (Price) than the
-- last. Coins are picked up on the planets (ServerScriptService.CoinPickups). Each tier can climb to
-- just above one planet (its Planet), so every new jetpack opens up the next planet and its more
-- valuable coins.
local Config = {}

-- How far above its planet's surface each jetpack can climb. The server works the actual heights out
-- from where the planets are when it starts (ServerScriptService.Jetpacks stores them as
-- "Ceiling_<Id>" attributes on this module), so the map can be moved without breaking flying.
Config.CeilingMargin = 150

Config.CurrencyAttribute = "Coins"       -- player attribute holding their coins (saved by PlayerSaving)
Config.OwnedFolder = "OwnedJetpacks"     -- player folder with a BoolValue per bought tier Id (saved by PlayerSaving)
Config.EquippedAttribute = "Jetpack"     -- player attribute holding the equipped tier Id (saved by PlayerSaving)
Config.LaunchKey = Enum.KeyCode.F
Config.LaunchGamepadButton = Enum.KeyCode.ButtonX
-- Jetpacks only launch from inside a part with this tag: each base's launch site has one
-- (ServerStorage.RideARocketLaunchSiteBuilder builds them)
Config.LaunchZoneTag = "LaunchZone"
-- The base button teleports players to their own base's launch pad
Config.TeleportKey = Enum.KeyCode.T
Config.TeleportGamepadButton = Enum.KeyCode.ButtonL2
Config.TeleportCooldown = 3

-- Planet: the planet it can reach (part of the planet model's name)   Speed: climb speed (studs/s)
-- AirSpeed: steering speed (kept for the shop's stats)   FlySpeed: free-flight speed after the launch
-- Cooldown: seconds after landing before it can launch again
-- Colors: Body = frame, Tank = fuel tanks, Glow = neon trim, Flame = exhaust
Config.Tiers = {
	{Id = "starter", Name = "Starter Jet", Rarity = "Common", Planet = "Moon", Price = 0,
		Speed = 140, AirSpeed = 40, FlySpeed = 80, Cooldown = 3,
		Colors = {Body = Color3.fromRGB(200, 210, 230), Tank = Color3.fromRGB(70, 140, 255),
			Glow = Color3.fromRGB(90, 220, 255), Flame = Color3.fromRGB(255, 170, 60)}},
	{Id = "frost", Name = "Frost Booster", Rarity = "Uncommon", Planet = "Mars", Price = 250,
		Speed = 210, AirSpeed = 48, FlySpeed = 100, Cooldown = 2.5,
		Colors = {Body = Color3.fromRGB(225, 240, 255), Tank = Color3.fromRGB(120, 220, 255),
			Glow = Color3.fromRGB(180, 250, 255), Flame = Color3.fromRGB(120, 210, 255)}},
	{Id = "magma", Name = "Magma Thruster", Rarity = "Rare", Planet = "Mercury", Price = 1500,
		Speed = 290, AirSpeed = 56, FlySpeed = 125, Cooldown = 2,
		Colors = {Body = Color3.fromRGB(70, 56, 70), Tank = Color3.fromRGB(255, 110, 40),
			Glow = Color3.fromRGB(255, 200, 60), Flame = Color3.fromRGB(255, 90, 30)}},
	{Id = "crystal", Name = "Crystal Wing", Rarity = "Epic", Planet = "Venus", Price = 7500,
		Speed = 370, AirSpeed = 64, FlySpeed = 150, Cooldown = 1.5,
		Colors = {Body = Color3.fromRGB(90, 60, 170), Tank = Color3.fromRGB(190, 110, 255),
			Glow = Color3.fromRGB(255, 120, 230), Flame = Color3.fromRGB(230, 120, 255)}},
	{Id = "cosmic", Name = "Cosmic Nova", Rarity = "Legendary", Planet = "Jupiter", Price = 30000,
		Speed = 450, AirSpeed = 75, FlySpeed = 180, Cooldown = 1,
		Colors = {Body = Color3.fromRGB(40, 30, 90), Tank = Color3.fromRGB(255, 210, 70),
			Glow = Color3.fromRGB(255, 90, 230), Flame = Color3.fromRGB(255, 240, 140)}},
}

Config.ById = {}
for index, tier in ipairs(Config.Tiers) do
	tier.Index = index
	Config.ById[tier.Id] = tier
end

-- Free tiers are always owned; the rest once bought
function Config.Owns(tier, player)
	if tier.Price <= 0 then return true end
	local owned = player:FindFirstChild(Config.OwnedFolder)
	return owned ~= nil and owned:FindFirstChild(tier.Id) ~= nil
end

function Config.Coins(player)
	return player:GetAttribute(Config.CurrencyAttribute) or 0
end

-- The planet's name to show players ("the Moon", "Mars")
function Config.PlanetLabel(tier)
	return tier.Planet == "Moon" and "the Moon" or tier.Planet
end

-- The highest Y this tier can climb to, or nil if the server couldn't find its planet
function Config.Ceiling(tier)
	return script:GetAttribute("Ceiling_" .. tier.Id)
end

-- The tier the player is flying with: their saved choice, or the Starter Jet if that
-- choice is missing or not owned.
function Config.Equipped(player)
	local tier = Config.ById[player:GetAttribute(Config.EquippedAttribute)]
	if not tier or not Config.Owns(tier, player) then tier = Config.Tiers[1] end
	return tier
end

-- Highest value of a stat across all tiers (the GUI's stat bars are drawn relative to it).
function Config.Max(stat)
	local best = 0
	for _, tier in ipairs(Config.Tiers) do best = math.max(best, tier[stat]) end
	return best
end

return Config
