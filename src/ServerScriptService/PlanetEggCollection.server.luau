local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local map=workspace:WaitForChild("JetpackPetRescueMap")
local feedback=ReplicatedStorage:WaitForChild("PlanetEggPickupFeedback")
local function inventory(player)
 local bag=player:FindFirstChild("EggInventory")
 if not bag then bag=Instance.new("Folder");bag.Name="EggInventory";bag.Parent=player end
 local discovered=player:FindFirstChild("EggDiscoveries")
 if not discovered then discovered=Instance.new("Folder");discovered.Name="EggDiscoveries";discovered.Parent=player end
 if player:GetAttribute("EggsCollected")==nil then player:SetAttribute("EggsCollected",0) end
 return bag,discovered
end
Players.PlayerAdded:Connect(inventory)
for _,player in ipairs(Players:GetPlayers()) do inventory(player) end
local hooked={}
local function hook(prompt)
 if not prompt:IsA("ProximityPrompt") or prompt.Name~="CollectEgg" or hooked[prompt] then return end
 local egg=prompt.Parent
 if not egg:IsA("BasePart") or not egg:GetAttribute("EggId") then return end
 hooked[prompt]=true
 prompt.Triggered:Connect(function(player)
  if not egg:IsDescendantOf(map) then return end
  if not player:GetAttribute("DataLoaded") then return end -- wait until PlayerSaving has loaded their eggs
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  if not root or not humanoid or humanoid.Health<=0 then return end
  if (root.Position-egg.Position).Magnitude>prompt.MaxActivationDistance+2 then return end
  local bag,discovered=inventory(player)
  local eggId=egg:GetAttribute("EggId")
  local kind=egg:GetAttribute("EggType")
  if discovered:FindFirstChild(eggId) then return end
  local marker=Instance.new("BoolValue");marker.Name=eggId;marker.Value=true;marker.Parent=discovered
  local count=bag:FindFirstChild(kind)
  if not count then count=Instance.new("IntValue");count.Name=kind;count.Parent=bag end
  count.Value+=1
  local total=(player:GetAttribute("EggsCollected") or 0)+1
  player:SetAttribute("EggsCollected",total)
  feedback:FireClient(player,kind,total)
 end)
end
for _,item in ipairs(map:GetDescendants()) do hook(item) end
map.DescendantAdded:Connect(hook)
