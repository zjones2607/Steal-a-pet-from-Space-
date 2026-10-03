-- Every station starts at the core tier; locked rings show as glowing outlines.
local Upgrades = require(script.Parent:WaitForChild("StationUpgrades"))
workspace:WaitForChild("JetpackPetRescueMap"):WaitForChild("SpaceStation")
for _, plot in ipairs(Upgrades.GetPlots()) do
	if plot:FindFirstChild("Tier1") or plot:FindFirstChild("LockedOutline1") then
		Upgrades.SetTier(plot, 0)
	end
end
