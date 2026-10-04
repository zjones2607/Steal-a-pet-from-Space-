-- CoinEffects: spins the coins on the planets (ServerScriptService.CoinPickups) and pops up a
-- gold "+value" where you grab one. Purely visual; the server hands out the coins.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TAG = "Coin"
local SPIN_SPEED = 2.5    -- radians per second
local SPIN_RANGE = 400    -- only spin coins this close to the camera

local coins = {}
local function add(coin) if coin:IsA("BasePart") then coins[coin] = true end end
for _, coin in ipairs(CollectionService:GetTagged(TAG)) do add(coin) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(coin) coins[coin] = nil end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	local turn = CFrame.Angles(0, os.clock() * SPIN_SPEED, 0)
	for coin in pairs(coins) do
		if coin.Transparency < 1 and (coin.Position - eye).Magnitude < SPIN_RANGE then
			coin.CFrame = CFrame.new(coin.Position) * turn
		end
	end
end)

ReplicatedStorage:WaitForChild("CoinCollected").OnClientEvent:Connect(function(position, value)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "+" .. tostring(value)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 34
	text.TextColor3 = Color3.fromRGB(255, 218, 52)
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(3, 8, 30)
	stroke.Thickness = 3
	stroke.Parent = text
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, {StudsOffsetWorldSpace = Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(text, info, {TextTransparency = 1}):Play()
	TweenService:Create(stroke, info, {Transparency = 1}):Play()
	task.delay(1, function() anchor:Destroy() end)
end)
