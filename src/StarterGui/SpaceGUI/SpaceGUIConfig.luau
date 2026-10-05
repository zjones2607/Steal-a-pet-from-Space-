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

-- Eggs you collect (or buy) go straight into the pen behind your station and hatch on their own
-- after this many seconds. The x2 Growth pass halves it. Give one kind its own time with
-- EggHatchSecondsByKind, e.g. {["Galaxy Egg"] = 120}. PenEggSlots eggs fit in a pen at once;
-- the rest wait on the Eggs page and move in as soon as there's room.
Config.EggHatchSeconds = 60
Config.EggHatchSecondsByKind = {}
Config.PenEggSlots = 12

-- Pet pen upgrades, bought on the Pets page. The pen holds BaseCapacity pets, and each level adds
-- PerLevel more, up to MaxLevel. Only the pets in the pen roam it and earn coins (the best earners
-- among your equipped pets get the spots). Upgrading from level L costs PenUpgradeCost(L) coins.
Config.PenUpgrade = {BaseCapacity = 10, PerLevel = 1, MaxLevel = 20, BaseCost = 1000, CostGrowth = 1.35}
function Config.PenCapacity(level)
    local u = Config.PenUpgrade
    return u.BaseCapacity + u.PerLevel * math.clamp(level or 0, 0, u.MaxLevel)
end
function Config.PenUpgradeCost(level)
    local u = Config.PenUpgrade
    if (level or 0) >= u.MaxLevel then return nil end
    local cost = u.BaseCost * u.CostGrowth ^ (level or 0)
    local step = cost >= 100000 and 5000 or cost >= 10000 and 500 or 50 -- round to a tidy price
    return math.floor(cost / step + 0.5) * step
end

-- Gamepad button that opens/closes the shop (keyboard uses B).
Config.GamepadShopButton = Enum.KeyCode.ButtonY

-- Optional UI sounds. Put your own rbxassetid numbers here (0 = silent).
Config.Sounds = {Click = 0, Open = 0, Close = 0}

-- Keys are used by your server and must stay unique.
-- How big hatched pets come out. Chance is out of the total; Min..Max is the size (1 = normal).
-- The biggest ones get a Label shown next to their weight.
Config.PetSizes = {
    {Chance = 70, Min = 0.7, Max = 1.3},
    {Chance = 22, Min = 1.3, Max = 2},
    {Chance = 7, Min = 2, Max = 3, Label = "BIG"},
    {Chance = 1, Min = 3, Max = 5, Label = "HUGE"},
}
-- Coins a second one pet of this size earns (before x2 boosts), and how heavy it is in kg
function Config.PetIncome(pet, size)
    return math.max(1, math.floor((pet.Income or 0) * (size or 1) + 0.5))
end
function Config.PetKg(pet, size)
    return math.floor((pet.BaseKg or 5) * (size or 1) * 10 + 0.5) / 10
end
function Config.PetSizeLabel(size)
    local label
    for _, band in ipairs(Config.PetSizes) do
        if (size or 1) >= band.Min and band.Label then label = band.Label end
    end
    return label
end

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

-- The server (PetsAndShop) hatches eggs with these Odds, so the odds the GUI shows are the real ones.
-- BaseKg = how heavy a normal-sized one is. Every hatched pet gets its own size (see PetSizes):
-- its weight is BaseKg x size, and it earns Income x size (rounded, at least 1).
-- Income = coins per second that ONE copy of the pet earns while it's equipped. Equipped pets roam
-- the pen behind your station (StarterPlayerScripts.PetPens), and every copy there earns its Income
-- (doubled by the x2 Coins boost, and again by the x2 Credits pass). Keep Income a whole number.
-- Each pet Id must match a model in SpaceModels (unknown ids get a generic blob).
Config.Pets = {
    {Id="astro_dog", Name="Astro Dog", Odds=39, Rarity="Common", Income=1, BaseKg=8},
    {Id="moon_cat", Name="Moon Cat", Odds=24, Rarity="Common", Income=2, BaseKg=4},
    {Id="alien_bunny", Name="Alien Bunny", Odds=18, Rarity="Uncommon", Income=5, BaseKg=3},
    {Id="comet_fox", Name="Comet Fox", Odds=11, Rarity="Rare", Income=12, BaseKg=6},
    {Id="robot_bear", Name="Robot Bear", Odds=6.5, Rarity="Epic", Income=30, BaseKg=40},
    {Id="star_dragon", Name="Star Dragon", Odds=0.5, Rarity="Legendary", Income=200, BaseKg=250},
    {Id="cosmic_golem", Name="Cosmic Golem", Odds=1, Rarity="Mythic", Income=75, BaseKg=120},
}

return Config
