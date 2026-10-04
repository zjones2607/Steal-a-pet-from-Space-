-- PetsAndShop: the server side of SpaceGUI's Eggs, Pets, Boosts and Shop pages. It creates the
-- SpaceGUIAction remote and each player's SpaceGUIData folder (Eggs, Pets, Boosts) that SpaceGUI
-- shows, and handles every button SpaceGUI sends. Nothing the GUI asks for is trusted: each request
-- is checked against what the player really has.
--   Eggs: the eggs found on the planets (EggInventory, filled by PlanetEggCollection). Hatching one
--     picks a pet with the odds in SpaceGUIConfig.Pets, so the odds the shop shows are the real ones.
--   Pets: one entry per kind of pet. Hatching one you already have adds to its Count, and its Power
--     grows with it. Up to MAX_EQUIPPED pets can be equipped: they follow you around
--     (StarterPlayerScripts.PetFollowers) and multiply the coins you pick up by 1 + their Power/100.
--   Boosts: a hatch sometimes drops one. Using it starts a timer, saved as a unix time in
--     <Boost>EndsAt, so it keeps running while the player is offline.
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

local MAX_EQUIPPED = 3
local HATCH_COOLDOWN = 2          -- seconds between hatches, so the reveal can play
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
local PASS_KEYS = {Credits2x = true}

local remote = Instance.new("RemoteEvent")
remote.Name = Config.ActionRemoteName
remote.Parent = ReplicatedStorage

local rng = Random.new()
local ready = {}       -- [player] = true once their save has loaded and their folders are set up
local lastAction = {}  -- [player] = os.clock() of their last request
local lastHatch = {}

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
local function boostActive(player, key)
	local endsAt = player:GetAttribute(BOOSTS[key].Attribute)
	return type(endsAt) == "number" and endsAt > os.time()
end

-- Works out everything that depends on equipped pets, boosts and passes:
--   EquippedPets  ids of the equipped pets, comma separated (PetFollowers shows them)
--   PetPower      their total Power
--   CoinMultiplier  what CoinPickups multiplies each coin by
local function refresh(player)
	if not ready[player] then return end
	local ids, power = {}, 0
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry:IsA("StringValue") and entry:GetAttribute("Equipped") then
			table.insert(ids, entry.Value)
			power += entry:GetAttribute("Power") or 0
		end
	end
	table.sort(ids)
	for _, key in ipairs(BOOST_KEYS) do
		local attribute = BOOSTS[key].Attribute
		if player:GetAttribute(attribute) ~= nil and not boostActive(player, key) then
			player:SetAttribute(attribute, nil)
			notice(player, BOOSTS[key].Name:gsub(" %(.*%)", "") .. " has run out.")
		end
	end
	local multiplier = 1 + power / 100
	if boostActive(player, "CoinBoost") then multiplier *= 2 end
	if player:GetAttribute("Pass_Credits2x") then multiplier *= 2 end
	multiplier = math.floor(multiplier * 100 + 0.5) / 100
	local list = table.concat(ids, ",")
	if player:GetAttribute("EquippedPets") ~= list then player:SetAttribute("EquippedPets", list) end
	if player:GetAttribute("PetPower") ~= power then player:SetAttribute("PetPower", power) end
	if player:GetAttribute("CoinMultiplier") ~= multiplier then player:SetAttribute("CoinMultiplier", multiplier) end
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
	for _, entry in ipairs(shown:GetChildren()) do
		if not keep[entry.Name] then entry:Destroy() end
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
			if player.Parent then syncEggs(player) end
		end)
	end
	local function hook(count)
		if count:IsA("IntValue") then count.Changed:Connect(schedule) end
		schedule()
	end
	for _, count in ipairs(inventory:GetChildren()) do hook(count) end
	inventory.ChildAdded:Connect(hook)
	inventory.ChildRemoved:Connect(schedule)
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

local function addPet(player, pet)
	local pets = dataFolder(player, "Pets")
	local entry = pets:FindFirstChild(pet.Id)
	if not entry then
		entry = Instance.new("StringValue")
		entry.Name = pet.Id
		entry.Value = pet.Id
		entry:SetAttribute("DisplayName", pet.Name)
		entry:SetAttribute("Equipped", equippedCount(player) < MAX_EQUIPPED) -- new kinds go straight on if there's room
	end
	local count = (entry:GetAttribute("Count") or 0) + 1
	entry:SetAttribute("Count", count)
	entry:SetAttribute("Power", powerOf(pet.Id) * count)
	entry.Parent = pets
	refresh(player)
	return count
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

----------------------------------------------------------------------------
-- BUTTONS IN SPACEGUI   (sendAction(action, value) on the client)
----------------------------------------------------------------------------
local actions = {}

function actions.HatchEgg(player, kind)
	if type(kind) ~= "string" then return end
	local count = folder(player, "EggInventory"):FindFirstChild(kind)
	if not count or not count:IsA("IntValue") or count.Value < 1 then
		return notice(player, "You don't have that egg any more.")
	end
	local now = os.clock()
	if lastHatch[player] and now - lastHatch[player] < HATCH_COOLDOWN then return end
	if #Config.Pets == 0 then return end
	lastHatch[player] = now
	local pet = rollPet(player)
	count.Value -= 1
	if count.Value <= 0 then count:Destroy() end
	local owned = addPet(player, pet)
	remote:FireClient(player, "Hatched", pet.Id)
	local message = owned > 1 and ("Another %s! It now has %d Power."):format(pet.Name, powerOf(pet.Id) * owned) or nil
	if rng:NextNumber() < BOOST_DROP_CHANCE then
		local key = BOOST_KEYS[rng:NextInteger(1, #BOOST_KEYS)]
		addBoost(player, key)
		message = (message and message .. " " or "") .. ("You also found a %s boost!"):format(BOOSTS[key].Name)
	end
	if message then task.delay(3, function() if player.Parent then notice(player, message) end end) end
end

function actions.TogglePet(player, id)
	local entry = type(id) == "string" and dataFolder(player, "Pets"):FindFirstChild(id)
	if not entry then return end
	local name = entry:GetAttribute("DisplayName") or id
	if entry:GetAttribute("Equipped") then
		entry:SetAttribute("Equipped", false)
		refresh(player)
		return notice(player, ("Unequipped %s."):format(name))
	end
	if equippedCount(player) >= MAX_EQUIPPED then
		return notice(player, ("You can equip %d pets. Unequip one first."):format(MAX_EQUIPPED))
	end
	entry:SetAttribute("Equipped", true)
	refresh(player)
	notice(player, ("Equipped %s! Coins x%s"):format(name, tostring(player:GetAttribute("CoinMultiplier"))))
end

function actions.EquipBest(player)
	local entries = {}
	for _, entry in ipairs(dataFolder(player, "Pets"):GetChildren()) do
		if entry:IsA("StringValue") then table.insert(entries, entry) end
	end
	table.sort(entries, function(a, b) return (a:GetAttribute("Power") or 0) > (b:GetAttribute("Power") or 0) end)
	for i, entry in ipairs(entries) do entry:SetAttribute("Equipped", i <= MAX_EQUIPPED) end
	refresh(player)
	notice(player, ("Equipped your best pets! Coins x%s"):format(tostring(player:GetAttribute("CoinMultiplier"))))
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
		notice(player, ("Thanks! %d %s%s added to your eggs."):format(reward.Eggs, SHOP_EGG, reward.Eggs == 1 and "" or "s"))
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
	ready[player] = true
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
	lastHatch[player] = nil
end)

-- Boosts run out on their own
task.spawn(function()
	while true do
		task.wait(1)
		for player in pairs(ready) do refresh(player) end
	end
end)
