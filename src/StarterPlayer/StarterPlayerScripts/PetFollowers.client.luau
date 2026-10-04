-- PetFollowers: shows every player's equipped pets floating behind them. The server
-- (PetsAndShop) lists each player's equipped pets in their "EquippedPets" attribute, and this script
-- builds the same 3D models SpaceGUI uses (SpaceGUI.SpaceModels) on this device and moves them every
-- frame, so they follow smoothly without the server sending positions.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PET_SIZE = 3.2                 -- studs: the longest side of each pet
local FOLLOW_SPEED = 8               -- higher = pets catch up faster
-- Where each pet floats, relative to its owner (+X right, +Z behind)
local SLOTS = {Vector3.new(-3.5, 0, 4.5), Vector3.new(3.5, 0, 4.5), Vector3.new(0, 0.6, 6.5)}

local player = Players.LocalPlayer
local Models = require(player:WaitForChild("PlayerGui"):WaitForChild("SpaceGUI"):WaitForChild("SpaceModels"))

local holder = Instance.new("Folder")
holder.Name = "PetFollowers"
holder.Parent = workspace

local shown = {} -- [owner] = {list = "a,b", pets = {{model, cf}}}

local function clear(owner)
	local s = shown[owner]
	if not s then return end
	for _, pet in ipairs(s.pets) do pet.model:Destroy() end
	shown[owner] = nil
end

local function build(owner)
	local list = owner:GetAttribute("EquippedPets")
	if type(list) ~= "string" then list = "" end
	if shown[owner] and shown[owner].list == list then return end
	clear(owner)
	local s = {list = list, pets = {}}
	for id in list:gmatch("[^,]+") do
		if #s.pets >= #SLOTS then break end
		local ok, model = pcall(Models.Pet, id)
		if ok and model then
			local size = model:GetExtentsSize()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0 then model:ScaleTo(PET_SIZE / longest) end
			model.Name = owner.Name .. "_" .. id
			model.Parent = holder
			table.insert(s.pets, {model = model})
		end
	end
	shown[owner] = s
end

local function watch(owner)
	owner:GetAttributeChangedSignal("EquippedPets"):Connect(function() build(owner) end)
	build(owner)
end
for _, owner in ipairs(Players:GetPlayers()) do task.spawn(watch, owner) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local blend = math.min(1, dt * FOLLOW_SPEED)
	for owner, s in pairs(shown) do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		for i, pet in ipairs(s.pets) do
			if root and humanoid and humanoid.Health > 0 then
				local slot = SLOTS[i]
				local base = root.CFrame * CFrame.new(slot.X, -humanoid.HipHeight * 0.5 + slot.Y, slot.Z)
				local bob = math.sin(t * 2.5 + i * 1.7) * 0.35
				-- The models face +Z, so turn them round to look the way their owner is facing
				local target = CFrame.new(base.Position + Vector3.new(0, bob, 0))
					* root.CFrame.Rotation * CFrame.Angles(0, math.pi, 0)
				pet.cf = pet.cf and pet.cf:Lerp(target, blend) or target
				pet.model:PivotTo(pet.cf)
			elseif pet.cf then
				pet.cf = nil
				pet.model:PivotTo(CFrame.new(0, -1000, 0)) -- out of sight while they respawn
			end
		end
	end
end)
