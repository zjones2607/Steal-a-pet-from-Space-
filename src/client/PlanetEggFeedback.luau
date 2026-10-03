local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local map=workspace:WaitForChild("JetpackPetRescueMap")
local discoveries=player:WaitForChild("EggDiscoveries")
local gui=Instance.new("ScreenGui")
gui.Name="PlanetEggFeedback";gui.ResetOnSpawn=false;gui.DisplayOrder=45;gui.Parent=player:WaitForChild("PlayerGui")
local toast=Instance.new("TextLabel")
toast.Name="PickupMessage";toast.AnchorPoint=Vector2.new(.5,.5);toast.Position=UDim2.fromScale(.5,.85)
toast.Size=UDim2.new(.65,0,0,62);toast.BackgroundColor3=Color3.fromRGB(20,29,51);toast.BackgroundTransparency=.1
toast.TextColor3=Color3.fromRGB(230,251,255);toast.Font=Enum.Font.GothamBold;toast.TextSize=21;toast.TextWrapped=true
toast.Visible=false;toast.Parent=gui
local sizeLimit=Instance.new("UISizeConstraint");sizeLimit.MaxSize=Vector2.new(520,62);sizeLimit.Parent=toast
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,14);corner.Parent=toast
local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(80,217,236);stroke.Thickness=2;stroke.Parent=toast
local eggs={}
local function fade(egg)
 egg.LocalTransparencyModifier=.8
 for _,v in ipairs(egg:GetDescendants()) do
  if v:IsA("BasePart") then v.LocalTransparencyModifier=.8 end
  if v:IsA("ProximityPrompt") then v.Enabled=false end
 end
end
local function register(item)
 if item:IsA("BasePart") and item:GetAttribute("EggId") then
  local id=item:GetAttribute("EggId");eggs[id]=item
  if discoveries:FindFirstChild(id) then fade(item) end
 elseif item:IsA("ProximityPrompt") then
  local id=item.Parent:GetAttribute("EggId")
  if id and discoveries:FindFirstChild(id) then item.Enabled=false end
 end
end
for _,v in ipairs(map:GetDescendants()) do register(v) end
map.DescendantAdded:Connect(register)
discoveries.ChildAdded:Connect(function(marker) local egg=eggs[marker.Name];if egg then fade(egg) end end)
local version=0
ReplicatedStorage:WaitForChild("PlanetEggPickupFeedback").OnClientEvent:Connect(function(kind,total)
 version+=1;local current=version
 toast.Text=kind.." collected!  •  "..total.." eggs found";toast.Visible=true
 task.delay(3.5,function() if version==current then toast.Visible=false end end)
end)
