-- PetsAndShop: the server side of SpaceGUI's Eggs, Pets, Boosts and Shop pages. It creates the
-- SpaceGUIAction remote and each player's SpaceGUIData folder (Eggs, Pets, Boosts) that SpaceGUI
-- shows, and handles every button SpaceGUI sends. Nothing the GUI asks for is trusted: each request
-- is checked against what the player really has.
--   Eggs: the eggs found on the planets (EggInventory, filled by PlanetEggCollection) or bought go
--     straight into the pen behind your station (IncubatingEggs: one StringValue per egg, its kind in
--     Value, with HatchAt = the unix time it hatches and Seconds = how long it takes). Each one hatches
--     on its own when its time is up, even while you're offline. Only SpaceGUIConfig.PenEggSlots fit at
--     once; the rest wait in EggInventory. Hatching picks a pet with the odds in SpaceGUIConfig.Pets,
--     so the odds the shop shows are the real ones. StarterPlayerScripts.PenEggs shows the eggs.
--     ServerStorage.InstantHatch (a BindableFunction, used by the admin panel) hatches a player's
--     pen eggs straight away.
--   Pets: one entry per pet (a StringValue called Pet1, Pet2... with the kind's id in Value). Every
--     hatched pet gets its own size (SpaceGUIConfig.PetSizes): Size, and Kg = BaseKg x Size, are
--     attributes on its entry, and it earns Config.PetIncome(kind, Size) coins a second while it's in
--     the pen. Old saves (one entry per kind with a Count) are split into single pets of size 1.
--   Pen: holds Config.PenCapacity(PenLevel) pets (10 to start, +1 per upgrade bought on the Pets
--     page with UpgradePen). Any mix of pets can be equipped, up to that many, and every equipped
--     pet roams the pen behind your station (StarterPlayerScripts.PetPens builds them from PenPets)
--     and earns. The 3 strongest equipped pets also multiply the coins you pick up by
--     1 + their Power/100. PenPetCount / PenCapacity feed the pen's sign (PenSigns) and SpaceGUI.
--   Boosts: a hatch sometimes drops one. Using it starts a timer, saved as a unix time in
--     <Boost>EndsAt, so it keeps running while the player is offline. x2 Coins doubles both pet
--     income and picked-up coins, and so does the x2 Credits pass.
--   Robux: the products and passes are the ones in SpaceGUIConfig. Fill in their ProductId and turn
--     on PurchasesEnabled there. Each purchase is noted in PurchaseHistory and saved before Roblox is
--     told it was delivered, so nobody pays without getting it, or gets it twice.
-- PlayerSaving saves SpaceGUIData, PurchaseHistory and the boost timers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(StarterGui:WaitForChild("SpaceGUI"):WaitForChild("SpaceGUIConfig"))
local saveNow = ServerStorage:WaitForChild("SavePlayerNow")

local MAX_MIGRATED = 1000        -- copies of one kind an old save is split into, at most
local POWER_PETS = 3              -- how many of the strongest equipped pets boost coin pickups
local ACTION_COOLDOWN = 0.2       -- seconds between any two requests from one player
local BOOST_DROP_CHANCE = 0.15    -- chance that a hatch also gives a random boost
local SHOP_EGG = "Galaxy Egg"     -- the egg that Robux egg packs give
local SLOW_WALKSPEED, NORMAL_WALKSPEED = 8, 16
local HISTORY_KEEP = 100          -- purchases remembered per player (Roblox retries recent ones)

-- How strong each pet is. A pet that isn't listed gets DEFAULT_POWER.
local PET_POWER = {astro_dog = 5, moon_cat = 6, alien_bunny = 10, comet_fox = 20, robot_bear = 40,
	cosmic_golem = 80, star_dragon = 150}
local DEFAULT_POWER = 5
-- During a Lucky Hatch these rarities are twice as likely
local LUCKY_RARITIES = {Rare = true, Epic = true, Legendary = true, Mythic = true}
local BOOSTS = {
	CoinBoost = {Name = "x2 Coins (5 min)", Seconds = 300, Attribute = "CoinBoostEndsAt"},
	LuckBoost = {Name = "Lucky Hatch (5 min)", Seconds = 300, Attribute = "LuckBoostEndsAt"},
}
local BOOST_KEYS = {"CoinBoost", "LuckBoost"}
-- What each Robux product in SpaceGUIConfig gives. Products not listed here can't be sold yet.
local PRODUCT_REWARDS = {
	Egg1 = {Eggs = 1}, Egg3 = {Eggs = 3}, Egg10 = {Eggs = 10}, Egg50 = {Eggs = 50},
	Credits24K = {Coins = 24000}, Credits200K = {Coins = 200000}, Credits800K = {Coins = 800000},
}
-- Game passes this script knows. Owning one sets the player attribute "Pass_<Key>".
local PASS_KEYS = {Credits2x = true, Growth2x = true}
local INCUBATOR = "IncubatingEggs"
local PEN_EGGS = Config.PenEggSlots or 12

local remote = Instance.new("RemoteEvent")
remote.Name = Config.ActionRemoteName
remote.Parent = ReplicatedStorage

local rng = Random.new()
local ready = {}       -- [player] = true once their save has loaded and their folders are set up
local lastAction = {}  -- [player] = os.clock() of their last request

local function notice(player, text) remote:FireClient(player, "Notice", text) end

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local function dataFolder(player, category) return folder(folder(player, Config.DataFolderName), category) end

local function petInfo(id)
	for _, p in ipairs(Config.Pets) do
		if p.Id == id then return p end
	end
end
local function powerOf(id) return PET_POWER[id] or DEFAULT_POWER end
-- Coins a second one pet earns before boosts: its kind's Income times its size
local function petIncome(entry)
	local info = petInfo(entry.Value)
	return info and Config.PetIncome(info, entry:GetAttribute("Size") or 1) or 0
end
local RARITY_RANK = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6}
-- Best pets first: most coins a second, then rarest, then heaviest
local function betterPet(a, b)
	local incomeA, incomeB = petIncome(a), petIncome(b)
	if incomeA ~= incomeB then return incomeA > incomeB end
	local infoA, infoB = petInfo(a.Value), petInfo(b.Value)
	local rankA, rankB = infoA and RARITY_RANK[infoA.Rarity] or 0, infoB and RARITY_RANK[infoB.Rarity] or 0
	if rankA ~= rankB then return rankA > rankB end
	local kgA, kgB = a:GetAttribute("Kg") or 0, b:GetAttribute("Kg") or 0
	if kgA ~= kgB then return kgA > kgB end
	return a.Name < b.Name
end
local function penCapacity(player) return Config.PenCapacity(player:GetAttribute("PenLevel") or 0) end
local function boostActive(player, key)
	local endsAt = player:GetAttribute(BOOSTS[key].Attribute)
	return type(endsAt) == "number" and endsAt > os.time()
end
local function setAttribute(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
-- "1 coin/s", "24 coins/s"
local function perSecond(coins) return ("%s coin%s/s"):format(tostring(coins), coins == 1 and "" or "s") end

-- Works out everything that depends on equipped pets, boosts and passes:
--   EquippedPets      ids of the kinds in the pen, comma separated
--   PenPets           every pet in the pen, best first, as "Pet12:astro_dog:1.25:3" (entry name, kind,
--                     size, coins a second before boosts), comma separated. PetPens builds these.
--   PetPower          the total Power of the POWER_PETS strongest pets in the pen
--   CoinMultiplier    what CoinPickups multiplies each coin by
--   IncomeMultiplier  what pet income is multiplied by: x2 for the x2 Coins boost, x2 for the x2 Credits pass
--   PetIncome         coins per second the pen earns, which the loop at the bottom pays out
--   PenCapacity       how many pets fit in the pen, from the PenLevel upgrades
--   PenPetCount       how many pets are in it
local function refresh(player)
	if not ready[player] then return end
	local equipped = {}
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry:IsA("StringValue") and entry:GetAttribute("Equipped") then table.insert(equipped, entry) end
	end
	table.sort(equipped, betterPet)
	local capacity = penCapacity(player)
	local pen, kinds, seen, powers, income = {}, {}, {}, {}, 0
	for i, entry in ipairs(equipped) do
		if i > capacity then break end -- only happens if something equipped too many
		local earns = petIncome(entry)
		income += earns
		table.insert(pen, ("%s:%s:%.2f:%d"):format(entry.Name, entry.Value, entry:GetAttribute("Size") or 1, earns))
		table.insert(powers, entry:GetAttribute("Power") or powerOf(entry.Value))
		if not seen[entry.Value] then seen[entry.Value] = true; table.insert(kinds, entry.Value) end
	end
	table.sort(kinds)
	table.sort(powers, function(a, b) return a > b end)
	local power = 0
	for i = 1, math.min(POWER_PETS, #powers) do power += powers[i] end
	for _, key in ipairs(BOOST_KEYS) do
		local attribute = BOOSTS[key].Attribute
		if player:GetAttribute(attribute) ~= nil and not boostActive(player, key) then
			player:SetAttribute(attribute, nil)
			notice(player, BOOSTS[key].Name:gsub(" %(.*%)", "") .. " has run out.")
		end
	end
	local boost = 1
	if boostActive(player, "CoinBoost") then boost *= 2 end
	if player:GetAttribute("Pass_Credits2x") then boost *= 2 end
	local multiplier = math.floor((1 + power / 100) * boost * 100 + 0.5) / 100
	setAttribute(player, "EquippedPets", table.concat(kinds, ","))
	setAttribute(player, "PenPets", table.concat(pen, ","))
	setAttribute(player, "PetPower", power)
	setAttribute(player, "CoinMultiplier", multiplier)
	setAttribute(player, "IncomeMultiplier", boost)
	setAttribute(player, "PetIncome", math.floor(income * boost + 0.5))
	setAttribute(player, "PenCapacity", capacity)
	setAttribute(player, "PenPetCount", #pen)
end

-- Coins a second one pet earns in the pen right now, boosts included
local function entryIncome(player, entry)
	return math.floor(petIncome(entry) * (player:GetAttribute("IncomeMultiplier") or 1) + 0.5)
end

local function equippedCount(player)
	local n = 0
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry:GetAttribute("Equipped") then n += 1 end
	end
	return n
end

-- SpaceGUI's Eggs page shows SpaceGUIData.Eggs: one entry per kind of egg in EggInventory, with its Count.
local function syncEggs(player)
	local inventory = folder(player, "EggInventory")
	local shown = dataFolder(player, "Eggs")
	local keep = {}
	for _, count in ipairs(inventory:GetChildren()) do
		if count:IsA("IntValue") and count.Value > 0 then
			keep[count.Name] = true
			local entry = shown:FindFirstChild(count.Name)
			if not entry then
				entry = Instance.new("StringValue")
				entry.Name = count.Name
				entry.Value = count.Name
				entry.Parent = shown
			end
			if entry:GetAttribute("Count") ~= count.Value then entry:SetAttribute("Count", count.Value) end
		end
	end
	-- The eggs hatching in the pen, as "Pen_Egg3" entries with their timer
	for _, egg in ipairs(folder(player, INCUBATOR):GetChildren()) do
		if egg:IsA("StringValue") then
			local name = "Pen_" .. egg.Name
			keep[name] = true
			local entry = shown:FindFirstChild(name)
			if not entry then
				entry = Instance.new("StringValue")
				entry.Name = name
				entry:SetAttribute("InPen", true)
				entry.Parent = shown
			end
			if entry.Value ~= egg.Value then entry.Value = egg.Value end
			for _, key in ipairs({"HatchAt", "Seconds"}) do
				if entry:GetAttribute(key) ~= egg:GetAttribute(key) then entry:SetAttribute(key, egg:GetAttribute(key)) end
			end
		end
	end
	for _, entry in ipairs(shown:GetChildren()) do
		if not keep[entry.Name] then entry:Destroy() end
	end
end

local function hatchSeconds(player, kind)
	local byKind = Config.EggHatchSecondsByKind
	local seconds = tonumber(byKind and byKind[kind]) or tonumber(Config.EggHatchSeconds) or 60
	if player:GetAttribute("Pass_Growth2x") then seconds /= 2 end
	return math.max(1, math.floor(seconds + 0.5))
end

-- Moves waiting eggs into the pen until it's full. Eggs are called Egg1..EggN after the pen spot
-- they sit in, so an egg keeps its spot until it hatches.
local function fillPen(player)
	local incubator = folder(player, INCUBATOR)
	local inventory = folder(player, "EggInventory")
	local used, n = {}, 0
	for _, egg in ipairs(incubator:GetChildren()) do used[egg.Name] = true; n += 1 end
	local slot = 1
	while n < PEN_EGGS do
		local waiting = {}
		for _, count in ipairs(inventory:GetChildren()) do
			if count:IsA("IntValue") and count.Value > 0 then table.insert(waiting, count) end
		end
		if #waiting == 0 then break end
		table.sort(waiting, function(a, b) return a.Name < b.Name end)
		local count, kind = waiting[1], waiting[1].Name
		count.Value -= 1
		if count.Value <= 0 then count:Destroy() end
		while used["Egg" .. slot] do slot += 1 end
		local seconds = hatchSeconds(player, kind)
		local egg = Instance.new("StringValue")
		egg.Name = "Egg" .. slot
		egg.Value = kind
		egg:SetAttribute("HatchAt", os.time() + seconds)
		egg:SetAttribute("Seconds", seconds)
		egg.Parent = incubator
		used[egg.Name] = true
		n += 1
	end
end
local function watchEggs(player)
	local inventory = folder(player, "EggInventory")
	local queued = false
	local function schedule()
		if queued then return end
		queued = true
		task.defer(function()
			queued = false
			if player.Parent then fillPen(player); syncEggs(player) end
		end)
	end
	local function hook(count)
		if count:IsA("IntValue") then count.Changed:Connect(schedule) end
		schedule()
	end
	for _, count in ipairs(inventory:GetChildren()) do hook(count) end
	inventory.ChildAdded:Connect(hook)
	inventory.ChildRemoved:Connect(schedule)
	local incubator = folder(player, INCUBATOR)
	incubator.ChildAdded:Connect(schedule)
	incubator.ChildRemoved:Connect(schedule)
	fillPen(player)
	syncEggs(player)
end

local function addEggs(player, kind, amount)
	local inventory = folder(player, "EggInventory")
	local count = inventory:FindFirstChild(kind)
	if not count then
		count = Instance.new("IntValue")
		count.Name = kind
		count.Parent = inventory
	end
	count.Value += amount
end

-- A random size for a new pet, from SpaceGUIConfig.PetSizes
local function rollSize()
	local total = 0
	for _, band in ipairs(Config.PetSizes) do total += band.Chance end
	local pick = rng:NextNumber() * total
	for _, band in ipairs(Config.PetSizes) do
		pick -= band.Chance
		if pick < 0 then return math.floor((band.Min + rng:NextNumber() * (band.Max - band.Min)) * 100 + 0.5) / 100 end
	end
	return 1
end

local function newPet(player, pet, size)
	local pets = dataFolder(player, "Pets")
	local id = pets:GetAttribute("NextId") or 1
	pets:SetAttribute("NextId", id + 1)
	local entry = Instance.new("StringValue")
	entry.Name = "Pet" .. id
	entry.Value = pet.Id
	entry:SetAttribute("DisplayName", pet.Name)
	entry:SetAttribute("Size", size)
	entry:SetAttribute("Kg", Config.PetKg(pet, size))
	entry:SetAttribute("Power", powerOf(pet.Id))
	entry:SetAttribute("Equipped", false)
	entry.Parent = pets
	return entry
end

-- Adds `amount` new pets of one kind, each with its own size. They go straight into the pen while
-- there's room. Returns the last one.
local function addPet(player, pet, amount, size)
	local room = penCapacity(player) - equippedCount(player)
	local entry
	for _ = 1, amount or 1 do
		entry = newPet(player, pet, size or rollSize())
		if room > 0 then
			entry:SetAttribute("Equipped", true)
			room -= 1
		end
	end
	refresh(player)
	return entry
end

-- Fills the pen with the best pets
local function equipBest(player)
	local entries = {}
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry:IsA("StringValue") then table.insert(entries, entry) end
	end
	table.sort(entries, betterPet)
	local capacity = penCapacity(player)
	for i, entry in ipairs(entries) do
		local on = i <= capacity
		if entry:GetAttribute("Equipped") ~= on then entry:SetAttribute("Equipped", on) end
	end
	refresh(player)
end

-- Old saves kept one entry per kind with a Count: split them into single pets of normal size
local function migratePets(player)
	local pets = dataFolder(player, "Pets")
	local highest = 0
	for _, entry in ipairs(pets:GetChildren()) do
		highest = math.max(highest, tonumber(entry.Name:match("^Pet(%d+)$")) or 0)
	end
	if (pets:GetAttribute("NextId") or 1) <= highest then pets:SetAttribute("NextId", highest + 1) end
	local changed = false
	for _, entry in ipairs(pets:GetChildren()) do
		if entry:IsA("StringValue") and entry:GetAttribute("Size") == nil then
			local info = petInfo(entry.Value)
			local count = math.clamp(math.floor(entry:GetAttribute("Count") or 1), 0, MAX_MIGRATED)
			entry:Destroy()
			if info then
				for _ = 1, count do newPet(player, info, 1) end
			end
			changed = true
		end
	end
	if changed then equipBest(player) end
end

local function addBoost(player, key)
	local entry = dataFolder(player, "Boosts"):FindFirstChild(key)
	if not entry then
		entry = Instance.new("StringValue")
		entry.Name = key
		entry.Value = key
		entry:SetAttribute("DisplayName", BOOSTS[key].Name)
		entry.Parent = dataFolder(player, "Boosts")
	end
	entry:SetAttribute("Count", (entry:GetAttribute("Count") or 0) + 1)
end

local function rollPet(player)
	local lucky = boostActive(player, "LuckBoost")
	local weights, total = {}, 0
	for i, p in ipairs(Config.Pets) do
		local w = math.max(tonumber(p.Odds) or 0, 0)
		if lucky and LUCKY_RARITIES[p.Rarity] then w *= 2 end
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	for i, p in ipairs(Config.Pets) do
		pick -= weights[i]
		if pick < 0 then return p end
	end
	return Config.Pets[#Config.Pets]
end

local function applySlowMode(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if player:GetAttribute("SpaceSlowMode") then
		if humanoid.WalkSpeed == NORMAL_WALKSPEED then humanoid.WalkSpeed = SLOW_WALKSPEED end
	elseif humanoid.WalkSpeed == SLOW_WALKSPEED then
		humanoid.WalkSpeed = NORMAL_WALKSPEED -- leave other speeds (like the admin panel's) alone
	end
end

-- Hatches one egg: picks the pet and its size, adds it, and shows the player the reveal
local function hatchPet(player, kind)
	if #Config.Pets == 0 then return end
	local pet = rollPet(player)
	local firstOfKind = true
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry.Value == pet.Id then firstOfKind = false break end
	end
	local entry = addPet(player, pet)
	local earns = entryIncome(player, entry)
	remote:FireClient(player, "Hatched", pet.Id, {Kg = entry:GetAttribute("Kg"), Size = entry:GetAttribute("Size"),
		Income = earns, New = firstOfKind})
	local message = ("You hatched a %s kg %s from your %s!"):format(tostring(entry:GetAttribute("Kg")), pet.Name, kind)
	if entry:GetAttribute("Equipped") then
		message ..= (" It's in your pen: +%s."):format(perSecond(earns))
	else
		message ..= " Your pen is full: upgrade it or press Equip Best."
	end
	if rng:NextNumber() < BOOST_DROP_CHANCE then
		local key = BOOST_KEYS[rng:NextInteger(1, #BOOST_KEYS)]
		addBoost(player, key)
		message ..= (" You also found a %s boost!"):format(BOOSTS[key].Name)
	end
	task.delay(3, function() if player.Parent then notice(player, message) end end)
end

-- Hatches the pen eggs whose time is up (or all of them with `now`), soonest first, then refills
-- the pen from the waiting eggs. Returns how many hatched.
local function hatchReady(player, now)
	local due = {}
	for _, egg in ipairs(folder(player, INCUBATOR):GetChildren()) do
		local hatchAt = egg:GetAttribute("HatchAt")
		if now or type(hatchAt) ~= "number" or hatchAt <= os.time() then table.insert(due, egg) end
	end
	if #due == 0 then return 0 end
	table.sort(due, function(a, b) return (a:GetAttribute("HatchAt") or 0) < (b:GetAttribute("HatchAt") or 0) end)
	for _, egg in ipairs(due) do
		local kind = egg.Value
		egg:Destroy()
		hatchPet(player, kind)
	end
	fillPen(player)
	syncEggs(player)
	return #due
end

local instantHatch = Instance.new("BindableFunction")
instantHatch.Name = "InstantHatch"
instantHatch.OnInvoke = function(player)
	if not ready[player] then return 0 end
	return hatchReady(player, true)
end
instantHatch.Parent = ServerStorage

-- The admin panel's "Give pet": adds `count` pets of one kind, each with a random size like a hatch
local givePet = Instance.new("BindableFunction")
givePet.Name = "GivePet"
givePet.OnInvoke = function(player, id, count)
	local pet = petInfo(id)
	if not ready[player] or not pet or type(count) ~= "number" or count < 1 then return false end
	addPet(player, pet, math.floor(count))
	return true
end
givePet.Parent = ServerStorage

----------------------------------------------------------------------------
-- BUTTONS IN SPACEGUI   (sendAction(action, value) on the client)
----------------------------------------------------------------------------
local actions = {}

-- Old saves and the Eggs page may still ask to hatch a waiting egg: it goes into the pen instead
function actions.HatchEgg(player)
	fillPen(player)
	if #folder(player, INCUBATOR):GetChildren() >= PEN_EGGS then
		notice(player, ("Your pen is full: %d eggs are hatching. The next one moves in when one hatches."):format(PEN_EGGS))
	end
end

function actions.TogglePet(player, id)
	local entry = type(id) == "string" and dataFolder(player, "Pets"):FindFirstChild(id)
	if not entry or not entry:IsA("StringValue") then return end
	local name = entry:GetAttribute("DisplayName") or entry.Value
	if entry:GetAttribute("Equipped") then
		entry:SetAttribute("Equipped", false)
		refresh(player)
		return notice(player, ("Took %s out of your pen. Your pen now makes %s."):format(name,
			perSecond(player:GetAttribute("PetIncome") or 0)))
	end
	local capacity = penCapacity(player)
	if equippedCount(player) >= capacity then
		return notice(player, ("Your pen is full (%d/%d). Unequip a pet or upgrade your pen."):format(capacity, capacity))
	end
	entry:SetAttribute("Equipped", true)
	refresh(player)
	notice(player, ("%s is in your pen! +%s"):format(name, perSecond(entryIncome(player, entry))))
end

-- Fills the pen with the pets that earn the most
function actions.EquipBest(player)
	equipBest(player)
	notice(player, ("Equipped your best pets! +%s, coin pickups x%s"):format(perSecond(player:GetAttribute("PetIncome") or 0),
		tostring(player:GetAttribute("CoinMultiplier"))))
end

function actions.UseBoost(player, key)
	local boost = type(key) == "string" and BOOSTS[key]
	local entry = boost and dataFolder(player, "Boosts"):FindFirstChild(key)
	local count = entry and entry:GetAttribute("Count") or 0
	if count < 1 then return notice(player, "You don't have that boost any more.") end
	if count <= 1 then entry:Destroy() else entry:SetAttribute("Count", count - 1) end
	-- Using one while it's already running adds to the time left
	local now = os.time()
	local endsAt = player:GetAttribute(boost.Attribute)
	player:SetAttribute(boost.Attribute, math.max(type(endsAt) == "number" and endsAt or 0, now) + boost.Seconds)
	refresh(player)
	local left = math.ceil((player:GetAttribute(boost.Attribute) - now) / 60)
	notice(player, ("%s is on! %d min left."):format(boost.Name:gsub(" %(.*%)", ""), left))
end

-- Pen upgrades: +Config.PenUpgrade.PerLevel spots for PenUpgradeCost(level) coins
function actions.UpgradePen(player)
	local level = player:GetAttribute("PenLevel") or 0
	local cost = Config.PenUpgradeCost(level)
	if not cost then return notice(player, "Your pet pen is already as big as it gets!") end
	local coins = player:GetAttribute("Coins") or 0
	if coins < cost then
		return notice(player, ("You need %d more coins to upgrade your pen."):format(cost - coins))
	end
	player:SetAttribute("Coins", coins - cost)
	player:SetAttribute("PenLevel", level + 1)
	refresh(player)
	notice(player, ("Pen upgraded to level %d! It now holds %d pets."):format(level + 1, Config.PenCapacity(level + 1)))
end

function actions.SetSlowMode(player, on)
	if type(on) ~= "boolean" then return end
	player:SetAttribute("SpaceSlowMode", on)
	applySlowMode(player)
end

function actions.GiftItem(player)
	notice(player, "Gifting is coming soon.")
end

remote.OnServerEvent:Connect(function(player, action, value)
	local handler = type(action) == "string" and actions[action]
	if not handler then return end
	if value ~= nil and type(value) ~= "string" and type(value) ~= "boolean" then return end
	if type(value) == "string" and #value > 60 then return end
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < ACTION_COOLDOWN then return end
	lastAction[player] = now
	if not ready[player] then return notice(player, "Your data is still loading, try again in a moment.") end
	handler(player, value)
end)

----------------------------------------------------------------------------
-- ROBUX
----------------------------------------------------------------------------
local productsById, passesById = {}, {}
for _, list in ipairs({Config.EggPacks or {}, Config.SpeedPacks or {}, Config.CreditPacks or {}}) do
	for _, item in ipairs(list) do
		if (item.ProductId or 0) > 0 then
			if PRODUCT_REWARDS[item.Key] then productsById[item.ProductId] = item
			else warn(("PetsAndShop: %s has a ProductId, but nothing gives it out yet, so it can't be bought."):format(item.Key)) end
		end
	end
end
for _, item in ipairs(Config.Passes or {}) do
	if (item.ProductId or 0) > 0 then
		if PASS_KEYS[item.Key] then passesById[item.ProductId] = item
		else warn(("PetsAndShop: the %s pass has a ProductId, but nothing gives its reward yet."):format(item.Key)) end
	end
end

local function grant(player, item)
	local reward = PRODUCT_REWARDS[item.Key]
	if reward.Eggs then
		addEggs(player, SHOP_EGG, reward.Eggs)
		notice(player, ("Thanks! %d %s%s are on their way to your pen."):format(reward.Eggs, SHOP_EGG, reward.Eggs == 1 and "" or "s"))
	end
	if reward.Coins then
		player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + reward.Coins)
		notice(player, ("Thanks! %d coins added."):format(reward.Coins))
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local item = productsById[receipt.ProductId]
	if not player or not ready[player] or not item then
		if player and not item then warn(("PetsAndShop: no reward for product %d"):format(receipt.ProductId)) end
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again later, e.g. next time they join
	end
	local history = folder(player, "PurchaseHistory")
	if not history:FindFirstChild(receipt.PurchaseId) then
		grant(player, item)
		local mark = Instance.new("StringValue")
		mark.Name = receipt.PurchaseId
		mark.Value = item.Key
		mark:SetAttribute("Time", os.time())
		mark.Parent = history
		local marks = history:GetChildren()
		if #marks > HISTORY_KEEP then
			table.sort(marks, function(a, b) return (a:GetAttribute("Time") or 0) < (b:GetAttribute("Time") or 0) end)
			for i = 1, #marks - HISTORY_KEEP do marks[i]:Destroy() end
		end
	end
	-- Only tell Roblox it's delivered once it's saved. If the save fails Roblox asks again, and the
	-- PurchaseHistory note stops it being given twice.
	if saveNow:Invoke(player) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function givePass(player, item)
	if player:GetAttribute("Pass_" .. item.Key) then return end
	player:SetAttribute("Pass_" .. item.Key, true)
	refresh(player)
end
local function checkPasses(player)
	for id, item in pairs(passesById) do
		task.spawn(function()
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns and player.Parent then givePass(player, item) end
		end)
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	local item = passesById[id]
	if bought and item then
		givePass(player, item)
		notice(player, ("Thanks! You now have %s."):format(item.Name))
	end
end)

----------------------------------------------------------------------------
-- PLAYERS
----------------------------------------------------------------------------
local function setUp(player)
	if ready[player] or not player.Parent then return end
	for _, category in ipairs({"Eggs", "Pets", "Boosts"}) do dataFolder(player, category) end
	folder(player, "PurchaseHistory")
	folder(player, INCUBATOR)
	ready[player] = true
	migratePets(player)
	watchEggs(player)
	refresh(player)
	checkPasses(player)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applySlowMode(player)
	end)
	-- PlayerSaving replaces the saved folders while loading, so wait until it's done
	if player:GetAttribute("DataLoaded") then
		setUp(player)
	else
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function() setUp(player) end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end
Players.PlayerRemoving:Connect(function(player)
	ready[player] = nil
	lastAction[player] = nil
end)

-- Every second: eggs whose time is up hatch, boosts run out on their own, then the pets in each pen
-- pay their owner. refresh runs first so a boost that just ran out stops doubling the pay straight away.
task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(ready) do
			local ok, err = pcall(hatchReady, player)
			if not ok then warn("PetsAndShop: hatching failed for " .. player.Name .. ": " .. tostring(err)) end
			refresh(player)
			local income = player:GetAttribute("PetIncome")
			if type(income) == "number" and income > 0 then
				player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + income)
			end
		end
	end
end)
