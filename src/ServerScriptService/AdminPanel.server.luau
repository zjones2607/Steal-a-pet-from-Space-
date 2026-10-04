-- AdminPanel: an admin panel that only the game's owner and developers can open.
-- Admins are: the game's owner (or rank GROUP_ADMIN_RANK+ if a group owns the game), anyone in
-- ADMIN_USERNAMES, and any real account while testing in Studio. Only admins are sent the panel,
-- and the server re-checks admin status on every request, so other players can't use it even by
-- firing the remote themselves.
local ADMIN_USERNAMES = {
	-- "SomeDeveloper",   -- Roblox usernames of developers, in quotes, one per line
}
local GROUP_ADMIN_RANK = 254

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Upgrades = require(script.Parent:WaitForChild("StationUpgrades"))
local station = workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")

local SPEEDS = {[16]=true, [32]=true, [64]=true, [100]=true}
local MAX_MESSAGE = 200

local admins = {}             -- [player] = true, decided once when they join
local adminIds = {}           -- usernames from ADMIN_USERNAMES resolved to user IDs
local adminNames = {}
for _, name in ipairs(ADMIN_USERNAMES) do adminNames[name:lower()] = true end
task.spawn(function()
	for _, name in ipairs(ADMIN_USERNAMES) do
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
		if ok and id then adminIds[id] = true end
	end
end)

local function checkAdmin(player)
	if adminIds[player.UserId] or adminNames[player.Name:lower()] then return true end
	if RunService:IsStudio() and player.UserId > 0 then return true end
	if game.CreatorType == Enum.CreatorType.User then return player.UserId == game.CreatorId end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= GROUP_ADMIN_RANK
end

local remote = Instance.new("RemoteFunction")
remote.Name = "AdminRemote"
remote.Parent = ReplicatedStorage
local announce = ReplicatedStorage:FindFirstChild("AdminAnnouncement") or Instance.new("RemoteEvent")
announce.Name = "AdminAnnouncement"
announce.Parent = ReplicatedStorage

local function log(admin, text) print(("[Admin] %s: %s"):format(admin.Name, text)) end
local function root(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
local function plotOf(player)
	for i = 1, 8 do
		local plot = station:FindFirstChild("StationPlot" .. i)
		if plot and plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
	end
end
local function filter(text, fromUserId, forUserId)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, fromUserId)
		if forUserId then return filtered:GetNonChatStringForUserAsync(forUserId) end
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end
local function target(id)
	local player = type(id) == "number" and Players:GetPlayerByUserId(id)
	return player or nil
end

-- Each action gets the admin and the client's arguments, and returns ok, message.
-- Arguments come from the client, so check every one.
local actions = {}
function actions.GetPlayers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, {UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName,
			Station = p:GetAttribute("Station"), Eggs = p:GetAttribute("EggsCollected") or 0, Admin = admins[p] == true})
	end
	return true, list
end
function actions.TeleportTo(admin, id)
	local t = target(id); local from, to = root(admin), t and root(t)
	if not from or not to then return false, "Player not found" end
	admin.Character:PivotTo(to.CFrame * CFrame.new(0, 0, 4))
	log(admin, "teleported to " .. t.Name); return true, "Teleported to " .. t.Name
end
function actions.Bring(admin, id)
	local t = target(id); local from, to = root(admin), t and root(t)
	if not from or not to then return false, "Player not found" end
	t.Character:PivotTo(from.CFrame * CFrame.new(0, 0, -4))
	log(admin, "brought " .. t.Name); return true, "Brought " .. t.Name
end
function actions.Respawn(admin, id)
	local t = target(id)
	if not t then return false, "Player not found" end
	t:LoadCharacter()
	log(admin, "respawned " .. t.Name); return true, "Respawned " .. t.Name
end
function actions.Kick(admin, id, reason)
	local t = target(id)
	if not t then return false, "Player not found" end
	if admins[t] then return false, "Admins can't be kicked" end
	local message = "Kicked by an admin."
	if type(reason) == "string" and reason ~= "" then
		local clean = filter(reason:sub(1, MAX_MESSAGE), admin.UserId, t.UserId)
		if clean then message = message .. " Reason: " .. clean end
	end
	log(admin, "kicked " .. t.Name)
	t:Kick(message); return true, "Kicked " .. t.Name
end
function actions.SetTier(admin, id, tier)
	local t = target(id)
	if not t then return false, "Player not found" end
	if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 0 or tier > 3 then return false, "Tier must be 0-3" end
	local plot = plotOf(t)
	if not plot then return false, t.Name .. " has no station" end
	Upgrades.SetTier(plot, tier)
	log(admin, ("set %s's station to tier %d"):format(t.Name, tier)); return true, ("%s's station is now tier %d"):format(t.Name, tier)
end
function actions.ResetEggs(admin, id)
	local t = target(id)
	if not t then return false, "Player not found" end
	if not t:GetAttribute("DataLoaded") then return false, t.Name .. "'s data hasn't loaded yet" end
	for _, name in ipairs({"EggInventory", "EggDiscoveries"}) do
		local folder = t:FindFirstChild(name)
		if folder then folder:ClearAllChildren() end
	end
	t:SetAttribute("EggsCollected", 0)
	log(admin, "reset eggs for " .. t.Name); return true, "Reset " .. t.Name .. "'s eggs (eggs reappear for them after rejoining)"
end
function actions.SetSpeed(admin, speed)
	if not SPEEDS[speed] then return false, "Not an allowed speed" end
	local humanoid = admin.Character and admin.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "No character" end
	humanoid.WalkSpeed = speed
	return true, "Speed set to " .. speed
end
function actions.GoTo(admin, where)
	if where == "MyStation" then
		if not plotOf(admin) then return false, "You don't have a station" end
		admin:LoadCharacter() -- StationClaims spawns them on their station
		return true, "Sent to your station"
	elseif where == "Plaza" then
		local spawn = workspace:FindFirstChild("SpawnLocation")
		if not spawn or not root(admin) then return false, "Can't find the plaza" end
		admin.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		return true, "Sent to the plaza"
	end
	return false, "Unknown place"
end
function actions.Announce(admin, text)
	if type(text) ~= "string" or text:gsub("%s", "") == "" then return false, "Type a message first" end
	local clean = filter(text:sub(1, MAX_MESSAGE), admin.UserId)
	if not clean then return false, "Message couldn't be checked by Roblox's filter, try again" end
	announce:FireAllClients(clean, admin.Name)
	log(admin, "announced: " .. clean); return true, "Announcement sent"
end

remote.OnServerInvoke = function(player, action, ...)
	if not admins[player] then
		warn(("[Admin] %s tried to use the admin panel without permission (%s)"):format(player.Name, tostring(action)))
		return false, "Not allowed"
	end
	local handler = type(action) == "string" and actions[action]
	if not handler then return false, "Unknown action" end
	local ok, success, result = pcall(handler, player, ...)
	if not ok then warn("[Admin] " .. tostring(success)); return false, "Something went wrong" end
	return success, result
end

local client = ServerStorage:WaitForChild("AdminPanelClient")
local function onPlayerAdded(player)
	if not checkAdmin(player) then return end
	admins[player] = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"; gui.ResetOnSpawn = false; gui.DisplayOrder = 100
	client:Clone().Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end
Players.PlayerRemoving:Connect(function(player) admins[player] = nil end)
