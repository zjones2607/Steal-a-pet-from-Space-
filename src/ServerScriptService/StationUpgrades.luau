-- StationUpgrades: show/hide a station's upgrade deck rings.
-- Usage (server):  require(game.ServerScriptService.StationUpgrades).SetTier(plotModel, 2)
-- Tiers: 0 = core (4 pets), 1 = 10 pets, 2 = 18 pets, 3 = 26 pets.
-- Each pet bed has an Attachment named "PetSlot" (Pod has attribute SlotIndex) for placing pets.
local ServerStorage = game:GetService("ServerStorage")
local CAP = {[0]=4, [1]=10, [2]=18, [3]=26}
local M = {}
local function store(plot)
	local root = ServerStorage:FindFirstChild("StationTierCache")
	if not root then root = Instance.new("Folder"); root.Name = "StationTierCache"; root.Parent = ServerStorage end
	local f = root:FindFirstChild(plot.Name)
	if not f then f = Instance.new("Folder"); f.Name = plot.Name; f.Parent = root end
	return f
end
function M.SetTier(plot, tier)
	tier = math.clamp(math.floor(tier), 0, 3)
	local s = store(plot)
	for t = 1, 3 do
		local deck = plot:FindFirstChild("Tier"..t) or s:FindFirstChild("Tier"..t)
		local outline = plot:FindFirstChild("LockedOutline"..t) or s:FindFirstChild("LockedOutline"..t)
		if deck then deck.Parent = (t <= tier) and plot or s end
		if outline then outline.Parent = (t <= tier) and s or plot end
	end
	plot:SetAttribute("UnlockedTier", tier)
	plot:SetAttribute("Capacity", CAP[tier])
	return CAP[tier]
end
function M.GetPlots()
	local map = workspace:FindFirstChild("JetpackPetRescueMap")
	local st = map and map:FindFirstChild("SpaceStation")
	local plots = {}
	if st then for i = 1, 8 do local p = st:FindFirstChild("StationPlot"..i); if p then table.insert(plots, p) end end end
	return plots
end
M.Capacity = CAP
return M
