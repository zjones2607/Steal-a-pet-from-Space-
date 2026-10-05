-- PlayerSaving: loads each player's progress when they join and saves it when they leave,
-- every couple of minutes, and when the server shuts down. Works across all servers.
-- To save something new, add its player attribute or folder name to the lists below.
-- Other scripts should wait for the player's "DataLoaded" attribute before changing saved things.
-- ServerStorage.SavePlayerNow (a BindableFunction) saves one player straight away and returns
-- whether it worked; Robux purchases use it so a bought item is saved before it counts as delivered.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local SAVED_ATTRIBUTES = {"EggsCollected", "Coins", "Jetpack", "CoinBoostEndsAt", "LuckBoostEndsAt", "PenLevel"}
local SAVED_FOLDERS = {"EggInventory", "EggDiscoveries", "OwnedJetpacks", "SpaceGUIData", "PurchaseHistory", "IncubatingEggs"}
local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_EVERY = 120
local LOCK_WAITS = 6          -- times to wait 5s for another server to finish saving before taking over

local VALUE_CLASSES = {IntValue=true, NumberValue=true, BoolValue=true, StringValue=true}
local isStudio = RunService:IsStudio()
local store
pcall(function() store = DataStoreService:GetDataStore(STORE_NAME) end)
local sessions = {}           -- [player] = {loaded, saving, left}

local function key(player) return "Player_" .. player.UserId end
local function retry(fn)
	local err, attempts = nil, isStudio and 1 or 4  -- Studio fails fast when API access is off
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then return true, result end
		err = result
		if attempt < attempts then task.wait(attempt * 1.5) end
	end
	return false, err
end

-- Folders of values <-> plain tables the DataStore can hold
local function attributes(inst)
	local out
	for name, v in pairs(inst:GetAttributes()) do
		local t = type(v)
		if t == "number" or t == "string" or t == "boolean" then out = out or {}; out[name] = v end
	end
	return out
end
local function encode(inst)
	local node = {n=inst.Name, c=inst.ClassName, a=attributes(inst)}
	if VALUE_CLASSES[inst.ClassName] then node.v = inst.Value end
	local kids = {}
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("Folder") or VALUE_CLASSES[child.ClassName] then table.insert(kids, encode(child)) end
	end
	if #kids > 0 then node.k = kids end
	return node
end
local function decode(node, parent)
	if node.c ~= "Folder" and not VALUE_CLASSES[node.c] then return end
	local inst = Instance.new(node.c)
	inst.Name = node.n
	if node.v ~= nil then inst.Value = node.v end
	for name, v in pairs(node.a or {}) do inst:SetAttribute(name, v) end
	for _, kid in ipairs(node.k or {}) do decode(kid, inst) end
	inst.Parent = parent
end

local function snapshot(player)
	local data = {Attributes = {}, Folders = {}}
	for _, name in ipairs(SAVED_ATTRIBUTES) do data.Attributes[name] = player:GetAttribute(name) end
	for _, name in ipairs(SAVED_FOLDERS) do
		local folder = player:FindFirstChild(name)
		if folder then data.Folders[name] = encode(folder).k or {} end
	end
	return data
end
local function apply(player, data)
	for _, name in ipairs(SAVED_ATTRIBUTES) do
		local v = data.Attributes and data.Attributes[name]
		if v ~= nil then player:SetAttribute(name, v) end
	end
	for _, name in ipairs(SAVED_FOLDERS) do
		local saved = data.Folders and data.Folders[name]
		if saved then
			local folder = player:FindFirstChild(name)
			if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = player end
			folder:ClearAllChildren()
			for _, node in ipairs(saved) do decode(node, folder) end
		end
	end
end

-- Loading takes a session lock so two servers never save over each other when a player hops.
-- Only the session holding the lock may save; once it lets go (or loses it) its saves are refused.
local function load(player, session)
	for attempt = 1, LOCK_WAITS + 1 do
		local blocked, data = false, nil
		local ok, err = retry(function()
			return store:UpdateAsync(key(player), function(old)
				old = old or {}
				blocked = old.Lock ~= nil and attempt <= LOCK_WAITS -- still held by another session
				if blocked then return nil end
				old.Lock = {Id = session, JobId = game.JobId, Time = os.time()}
				data = old
				return old
			end)
		end)
		if not ok then return false, err end
		if not blocked then return true, data end
		task.wait(5)
	end
end

local function save(player, leaving)
	local s = sessions[player]
	if not s or not s.loaded then return end
	while s.saving do task.wait(0.1) end
	s.saving = true
	local data = snapshot(player)
	local ok, err = retry(function()
		return store:UpdateAsync(key(player), function(old)
			old = old or {}
			if not old.Lock or old.Lock.Id ~= s.id then return nil end -- this session no longer owns the save
			old.Attributes, old.Folders, old.Version = data.Attributes, data.Folders, 1
			old.Lock = not leaving and {Id = s.id, JobId = game.JobId, Time = os.time()} or nil
			return old
		end)
	end)
	s.saving = false
	if not ok then warn(("PlayerSaving: couldn't save %s: %s"):format(player.Name, tostring(err))) end
	return ok
end

local function release(player, session)
	retry(function()
		return store:UpdateAsync(key(player), function(old)
			if not old or not old.Lock or old.Lock.Id ~= session then return nil end
			old.Lock = nil
			return old
		end)
	end)
end

local function onPlayerAdded(player)
	local s = {id = ("%s/%d/%f"):format(game.JobId, player.UserId, os.clock()), loaded = false, saving = false, left = false}
	sessions[player] = s
	local ok, data
	if store then ok, data = load(player, s.id) end
	if s.left then
		if ok then release(player, s.id) end
		return
	end
	if ok then
		apply(player, data)
		s.loaded = true
	elseif isStudio then
		warn("PlayerSaving: saving is off in Studio. Turn on Game Settings > Security > Enable Studio Access to API Services.")
	else
		player:Kick("Couldn't load your save data. Please rejoin in a moment.")
		return
	end
	player:SetAttribute("DataLoaded", true)
end

local saveNow = Instance.new("BindableFunction")
saveNow.Name = "SavePlayerNow"
saveNow.OnInvoke = function(player)
	local s = sessions[player]
	if not s then return false end
	if not s.loaded then return isStudio end -- Studio without API access has nowhere to save, so let tests through
	return save(player, false) == true
end
saveNow.Parent = ServerStorage

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	if not s then return end
	s.left = true
	save(player, true)
	sessions[player] = nil
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(sessions) do
		pending += 1
		task.spawn(function() save(player, true); pending -= 1 end)
	end
	while pending > 0 do task.wait(0.1) end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for player, s in pairs(sessions) do
			if s.loaded then task.spawn(save, player, false) end
		end
	end
end)
