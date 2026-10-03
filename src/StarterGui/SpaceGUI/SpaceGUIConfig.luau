-- All IDs stay at 0 until you add your own Roblox IDs.
-- (The GUI no longer uses any image, so SpaceGUI > ArtworkImageId can be deleted.)
local Config = {}

Config.OpenShopOnJoin = false
Config.CreditsStatNames = {"Credits", "Coins", "Money", "Cash"}
Config.SpeedStatNames = {"Speed", "Fuel", "Power"}
Config.DataFolderName = "SpaceGUIData"
Config.ActionRemoteName = "SpaceGUIAction"

-- Leave false until your SERVER grants and saves each purchased reward.
-- Filling in product IDs alone does not create a reward system.
Config.PurchasesEnabled = false

-- ===== NEW in the polish pass (all optional) =====

-- Unix time (seconds, e.g. os.time() + 14*86400) when the featured egg ends.
-- nil = no countdown on the banner (it says "Find your next space pet").
Config.FeaturedEndsAt = nil

-- Name of a PLAYER ATTRIBUTE your server sets to a unix time (seconds) for the
-- next event / meteor. Drives the moon timer bottom-right. Not set = hidden.
Config.NextEventAttribute = "NextEventAt"

-- Studio only: show demo timers (10d 14h... / in 1m 33s) so you can preview
-- the look. Ignored in live servers.
Config.PreviewTimers = true

-- The gift buttons call sendAction("GiftItem", item.Key). Leave false until
-- your server handles that action; until then they show "coming soon".
Config.GiftsEnabled = false

-- Studio only: press this key to preview the hatch reveal with a random pet.
-- Set to nil to disable. In a live game your SERVER triggers it instead:
--   remote:FireClient(player, "Hatched", "astro_dog")   (remote = Config.ActionRemoteName)
Config.PreviewHatchKey = Enum.KeyCode.H

-- Gamepad button that opens/closes the shop (keyboard uses B).
Config.GamepadShopButton = Enum.KeyCode.ButtonY

-- Optional UI sounds. Put your own rbxassetid numbers here (0 = silent).
Config.Sounds = {Click = 0, Open = 0, Close = 0}

-- Keys are used by your server and must stay unique.
Config.EggPacks = {
    {Key="Egg50", Name="50 Eggs", ProductId=0, Kind="Product", Random=true},
    {Key="Egg10", Name="10 Eggs", ProductId=0, Kind="Product", Random=true},
    {Key="Egg3", Name="3 Eggs", ProductId=0, Kind="Product", Random=true},
    {Key="Egg1", Name="1 Egg", ProductId=0, Kind="Product", Random=true},
}
-- Descriptions support RichText, so the "x2" can be highlighted green like the artwork.
Config.Passes = {
    {Key="Growth2x", Name="x2 Growth", Description='Eggs Grow <font color="#48E878">x2</font> faster!', ProductId=0, Kind="Pass", Icon="Clock"},
    {Key="Credits2x", Name="x2 Credits", Description='Get <font color="#48E878">x2</font> Credits!', ProductId=0, Kind="Pass", Icon="Coins"},
}
Config.SpeedPacks = {
    {Key="Speed150K", Name="+150K Speed", ProductId=0, Kind="Product", Icon="Rocket"},
    {Key="Speed1M", Name="+1M Speed", ProductId=0, Kind="Product", Icon="Rocket"},
    {Key="Speed10M", Name="+10M Speed", ProductId=0, Kind="Product", Icon="Rocket"},
    {Key="Speed50M", Name="+50M Speed", ProductId=0, Kind="Product", Icon="Rocket"},
    {Key="Speed500M", Name="+500M Speed", ProductId=0, Kind="Product", Icon="Rocket"},
    {Key="Speed1B", Name="+1B Speed", ProductId=0, Kind="Product", Icon="Rocket"},
}
Config.CreditPacks = {
    {Key="Credits24K", Name="24K Credits", ProductId=0, Kind="Product", Icon="Coins"},
    {Key="Credits200K", Name="200K Credits", ProductId=0, Kind="Product", Icon="Coins"},
    {Key="Credits800K", Name="800K Credits", ProductId=0, Kind="Product", Icon="Coins"},
}

-- These are the DISPLAY odds shown in the GUI, not a server hatch system.
-- Match these values to your server's real odds before selling eggs.
-- Each pet Id must match a model in SpaceModels (unknown ids get a generic blob).
Config.Pets = {
    {Id="astro_dog", Name="Astro Dog", Odds=39, Rarity="Common"},
    {Id="moon_cat", Name="Moon Cat", Odds=24, Rarity="Common"},
    {Id="alien_bunny", Name="Alien Bunny", Odds=18, Rarity="Uncommon"},
    {Id="comet_fox", Name="Comet Fox", Odds=11, Rarity="Rare"},
    {Id="robot_bear", Name="Robot Bear", Odds=6.5, Rarity="Epic"},
    {Id="star_dragon", Name="Star Dragon", Odds=0.5, Rarity="Legendary"},
    {Id="cosmic_golem", Name="Cosmic Golem", Odds=1, Rarity="Mythic"},
}

return Config
