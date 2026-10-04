-- SpaceGUIController (LocalScript) - v3 "all vector, 3D models, every device"
-- Client interface only. It reads stats and asks the SERVER for actions through
-- Config.ActionRemoteName. It never grants items, money or purchases by itself.
--
-- Inside the SpaceGUI ScreenGui you need:
--   SpaceGUIController (this LocalScript), SpaceGUIConfig, SpaceIcons, SpaceModels
-- (ArtworkImageId is no longer used - everything is drawn with frames, gradients,
--  strokes and 3D parts.)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local gui = script.Parent
local Config = require(gui:WaitForChild("SpaceGUIConfig"))
local Icons = require(gui:WaitForChild("SpaceIcons"))
local Models = require(gui:WaitForChild("SpaceModels"))
-- Jetpacks (ReplicatedStorage.Jetpacks): tiers and prices, the 3D models and the flying itself.
-- ServerScriptService.Jetpacks adds the BuyJetpack / EquipJetpack / TeleportToLaunchSite remotes.
local jetpackFolder = ReplicatedStorage:WaitForChild("Jetpacks")
local JetpackConfig = require(jetpackFolder:WaitForChild("JetpackConfig"))
local JetpackModels = require(jetpackFolder:WaitForChild("JetpackModels"))
local Flight = require(jetpackFolder:WaitForChild("JetpackFlight"))

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local old = gui:FindFirstChild("Runtime")
if old then old:Destroy() end
local installNote = gui:FindFirstChild("SetupNote")
if installNote then installNote:Destroy() end

----------------------------------------------------------------------------
-- STYLE TOKENS
----------------------------------------------------------------------------
local C = {
    Ink = Color3.fromRGB(3, 8, 30),
    Navy = Color3.fromRGB(9, 23, 68),
    Deep = Color3.fromRGB(5, 15, 48),
    Panel = Color3.fromRGB(17, 36, 96),
    Violet = Color3.fromRGB(78, 34, 170),
    Purple = Color3.fromRGB(132, 56, 240),
    Blue = Color3.fromRGB(28, 122, 235),
    Magenta = Color3.fromRGB(226, 46, 240),
    Cyan = Color3.fromRGB(8, 197, 248),
    Gold = Color3.fromRGB(255, 218, 52),
    GoldDeep = Color3.fromRGB(240, 150, 20),
    White = Color3.fromRGB(250, 252, 255),
    Muted = Color3.fromRGB(170, 192, 232),
    Red = Color3.fromRGB(232, 40, 52),
    Green = Color3.fromRGB(72, 232, 120),
}
local RarityColor = {
    Common = Color3.fromRGB(110, 150, 230), Uncommon = Color3.fromRGB(80, 230, 130),
    Rare = Color3.fromRGB(255, 150, 60), Epic = Color3.fromRGB(190, 110, 255),
    Legendary = C.Gold, Mythic = C.Magenta,
}
local CENTER = Enum.TextXAlignment.Center
local RIGHT = Enum.TextXAlignment.Right
local PET_RATIO = 0.85 -- pet card art height / width
local TAB_W = 118

----------------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------------
local function new(class, parent, properties)
    local obj = Instance.new(class)
    for key, value in pairs(properties or {}) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function tween(obj, seconds, props, style, direction)
    local t = TweenService:Create(obj,
        TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end
-- Endless page animations are tracked so they are cancelled when the page is rebuilt.
local pageLoops = {}
local function loop(obj, seconds, props, persistent)
    local t = TweenService:Create(obj,
        TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
    t:Play()
    if not persistent then table.insert(pageLoops, t) end
    return t
end
local function spin(obj, seconds, persistent)
    local t = TweenService:Create(obj,
        TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false),
        {Rotation = obj.Rotation + 360})
    t:Play()
    if not persistent then table.insert(pageLoops, t) end
    return t
end
local function playSound(name)
    local id = Config.Sounds and Config.Sounds[name]
    if type(id) ~= "number" or id <= 0 then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = 0.5
    s.Parent = SoundService
    s:Play()
    task.delay(4, function() s:Destroy() end)
end
local function corner(obj, radius)
    return new("UICorner", obj, {CornerRadius = UDim.new(0, radius or 12)})
end
local function stroke(obj, color, thickness, transparency)
    return new("UIStroke", obj, {Color = color or C.Ink, Thickness = thickness or 2,
        Transparency = transparency or 0, LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end
local function vgrad(obj, top, bottom)
    return new("UIGradient", obj, {Color = ColorSequence.new(top, bottom), Rotation = 90})
end
local function frame(parent, name, x, y, w, h, color)
    return new("Frame", parent, {Name = name, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or C.Panel,
        BackgroundTransparency = color and 0 or 1, BorderSizePixel = 0})
end
local function label(parent, name, text, x, y, w, h, size, color, align)
    local textSize = size or 26
    local l = new("TextLabel", parent, {Name = name, Text = text, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.FredokaOne, TextSize = textSize, TextColor3 = color or C.White,
        TextWrapped = true, TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center})
    new("UIStroke", l, {Color = C.Ink, Thickness = math.clamp(textSize / 11, 1.5, 4),
        LineJoinMode = Enum.LineJoinMode.Round})
    return l
end
local function goldText(l)
    l.TextColor3 = C.White
    vgrad(l, Color3.fromRGB(255, 248, 170), C.GoldDeep)
end
local function panel(parent, name, x, y, w, h, top, bottom, rim, radius)
    local r = radius or 14
    local f = new("Frame", parent, {Name = name, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.White, BorderSizePixel = 0})
    corner(f, r)
    vgrad(f, top or C.Panel, bottom or C.Navy)
    stroke(f, C.Ink, 3)
    if rim then
        local inner = new("Frame", f, {Name = "Rim", BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)})
        corner(inner, math.max(r - 3, 2))
        stroke(inner, rim, 2, 0.2)
    end
    return f
end
local function icon(name, parent, x, y, size)
    local ic = Icons.new(name, parent, size)
    ic.Position = UDim2.fromOffset(x, y)
    return ic
end
local function sparkle(parent, x, y, size, color)
    local s = frame(parent, "Sparkle", x, y, size, size)
    local function bar(w, h)
        local b = new("Frame", s, {BackgroundColor3 = color or C.White, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(w, 0, h, 0)})
        b.Size = w == 1 and UDim2.new(1, 0, 0, math.max(2, size * 0.16)) or UDim2.new(0, math.max(2, size * 0.16), 1, 0)
        corner(b, 3)
        return b
    end
    return s, bar(1, 0), bar(0, 1)
end
local function twinkle(parent, x, y, size, persistent, sink)
    local s, b1, b2 = sparkle(parent, x, y, size, C.White)
    local tweens = {
        loop(s, 1.4 + (x % 5) * 0.2, {Rotation = 90}, persistent),
        loop(b1, 0.8 + (y % 4) * 0.25, {BackgroundTransparency = 0.85}, persistent),
        loop(b2, 0.8 + (y % 4) * 0.25, {BackgroundTransparency = 0.85}, persistent),
    }
    if sink then
        for _, t in ipairs(tweens) do table.insert(sink, t) end
    end
    return s
end
local function formatNumber(value)
    local n = tonumber(value) or 0
    local suffixes = {{1e15, "Q"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}
    for _, item in ipairs(suffixes) do
        if math.abs(n) >= item[1] then
            return (string.format("%.1f", n / item[1]):gsub("%.0$", "")) .. item[2]
        end
    end
    return tostring(math.floor(n))
end
local function fmtDuration(seconds)
    local sec = math.max(0, math.floor(seconds))
    local d = math.floor(sec / 86400)
    local hh = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if d > 0 then return string.format("%dd %dh %dm %ds", d, hh, m, s) end
    if hh > 0 then return string.format("%dh %dm %ds", hh, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

----------------------------------------------------------------------------
-- STATE, DEVICE + INPUT MODE
----------------------------------------------------------------------------
local narrow, tabsSide = false, true
local bodyWidth = 908
local windowOpen = false
local currentPage = "Shop"
local currentTab = "Featured"
local builtWidth
local Lm = {titleH = 76, tabRowH = 84, hint = 0, W = 940, H = 700, extra = TAB_W + 14, scale = 1, hs = 1, LW = 1500, LH = 850}
local openPage, closeWindow, layoutWindow, render, selectTab, resize, updateTimers, updateHints
local teleportToBase, launchJetpack
local bannerTimer -- TextLabel on the featured banner (if built)
local featuredEnd -- unix seconds, set in the timers section

-- "Keyboard" (PC/Mac), "Touch" (phone/tablet) or "Gamepad" (console/controller).
local inputMode = "Keyboard"
if GuiService:IsTenFootInterface() then inputMode = "Gamepad"
elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then inputMode = "Touch" end

-- Shared rounded white outline used as the gamepad selection cursor.
local selectionCursor = Instance.new("Frame")
selectionCursor.BackgroundTransparency = 1
selectionCursor.BorderSizePixel = 0
selectionCursor.Position = UDim2.fromOffset(-6, -6)
selectionCursor.Size = UDim2.new(1, 12, 1, 12)
new("UICorner", selectionCursor, {CornerRadius = UDim.new(0, 16)})
new("UIStroke", selectionCursor, {Color = Color3.new(1, 1, 1), Thickness = 4})

-- Layers: root measures the real screen. stage is scaled so that everything
-- inside is laid out in "logical" units that stay readable on every device.
local root = new("Frame", gui, {Name = "Runtime", BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1)})
local stage = new("Frame", root, {Name = "Stage", BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.fromOffset(1500, 850)})
local stageScale = new("UIScale", stage, {Scale = 1})
local scrim = new("TextButton", stage, {Name = "Scrim", Text = "", AutoButtonColor = false,
    BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1), ZIndex = 1, Visible = false, Selectable = false})
local hud = new("Frame", stage, {Name = "HUD", BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1), ZIndex = 2})

local function computeMetrics()
    local vx, vy = root.AbsoluteSize.X, root.AbsoluteSize.Y
    local sc = math.min(vx / 1500, vy / 850)
    if GuiService:IsTenFootInterface() then sc = sc * 1.2 end
    sc = math.clamp(math.max(sc, UserInputService.TouchEnabled and 0.75 or 0.55), 0.5, 2.4)
    local LW, LH = vx / sc, vy / sc
    local m = {scale = sc, LW = LW, LH = LH}
    m.hint = (inputMode ~= "Touch") and 34 or 0
    m.tabsSide = LW >= 1240 and LH >= 560
    m.extra = m.tabsSide and (TAB_W + 14) or 0
    if m.tabsSide then m.W = math.floor(math.min(940, LW - 24 - m.extra))
    else m.W = math.floor(math.min(760, LW - 16)) end
    m.H = math.floor(math.clamp(LH - 24 - m.hint, 340, 720))
    local short = LH < 520
    m.titleH = short and 58 or 76
    m.tabRowH = short and 62 or 84
    m.bodyWidth = m.W - 52
    m.narrow = m.bodyWidth < 640
    m.hs = LW < 760 and 0.8 or 1
    m.hudFits = LW >= (m.W + m.extra) + 2 * (14 + 190 * m.hs)
    return m
end

----------------------------------------------------------------------------
-- 3D BUTTON: dark lip, glossy face, hover grow, press squish, gamepad cursor
-- Returns: hitbox(TextButton), face(Frame), label(TextLabel), depth(number)
----------------------------------------------------------------------------
local function button(parent, name, text, x, y, w, h, color, action, opts)
    opts = opts or {}
    color = color or C.Purple
    local radius = opts.radius or 11
    local depth = opts.depth or math.max(4, math.floor(h * 0.1))
    local faceH = h - depth
    local b = new("TextButton", parent, {Name = name, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x + w / 2, y + h / 2), Size = UDim2.fromOffset(w, h),
        SelectionImageObject = selectionCursor})
    local scale = new("UIScale", b, {Scale = 1})
    local lip = new("Frame", b, {Name = "Lip", BackgroundColor3 = color:Lerp(C.Ink, 0.55),
        BorderSizePixel = 0, Position = UDim2.fromOffset(0, depth), Size = UDim2.new(1, 0, 0, faceH)})
    corner(lip, radius)
    stroke(lip, C.Ink, 3)
    local face = new("Frame", b, {Name = "Face", BackgroundColor3 = C.White, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, faceH)})
    corner(face, radius)
    vgrad(face, color:Lerp(C.White, opts.flat and 0.1 or 0.3), color)
    stroke(face, C.Ink, 3)
    if opts.rim then
        local inner = new("Frame", face, {Name = "Rim", BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)})
        corner(inner, math.max(radius - 3, 2))
        stroke(inner, opts.rim, 2, 0.1)
    end
    -- Gloss: strong on bright buttons, barely there on dark ones (it read as a grey band).
    local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    local gloss = new("Frame", face, {Name = "Gloss", BackgroundColor3 = C.White,
        BackgroundTransparency = lum < 0.25 and 0.95 or 0.8,
        BorderSizePixel = 0, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0.36, 0)})
    corner(gloss, 8)
    local glow = new("Frame", face, {Name = "Hover", BackgroundColor3 = C.White, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2})
    corner(glow, radius)
    local lbl = new("TextLabel", face, {Name = "Label", Text = text, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, ZIndex = 3,
        TextSize = opts.textSize or math.clamp(math.floor(h * 0.5), 16, 36),
        TextColor3 = opts.textColor or C.White, TextWrapped = true})
    new("UIStroke", lbl, {Color = C.Ink, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round})

    local hovering, pressed = false, false
    local function refresh()
        local target = 1
        if pressed then target = 0.95 elseif hovering then target = opts.hoverScale or 1.06 end
        tween(scale, 0.12, {Scale = target}, Enum.EasingStyle.Back)
        tween(glow, 0.12, {BackgroundTransparency = hovering and 0.86 or 1})
        tween(face, 0.06, {Position = UDim2.fromOffset(0, pressed and depth - 2 or 0)})
    end
    b.MouseEnter:Connect(function() hovering = true refresh() end)
    b.MouseLeave:Connect(function() hovering = false pressed = false refresh() end)
    b.MouseButton1Down:Connect(function() pressed = true refresh() end)
    b.MouseButton1Up:Connect(function() pressed = false refresh() end)
    b.SelectionGained:Connect(function() hovering = true refresh() end)
    b.SelectionLost:Connect(function() hovering = false pressed = false refresh() end)
    if action then
        b.Activated:Connect(function()
            playSound("Click")
            action()
        end)
    end
    return b, face, lbl, depth
end

-- Round gamepad / key badge: (A) (B) [LB] [B]
local function keycap(parent, text, color, kind, order)
    local w = kind == "wide" and 44 or 28
    local f = new("Frame", parent, {Name = "Cap", BackgroundColor3 = C.White, BorderSizePixel = 0,
        Size = UDim2.fromOffset(w, 28), LayoutOrder = order or 0})
    corner(f, kind == "pad" and 14 or 8)
    vgrad(f, color:Lerp(C.White, 0.3), color)
    stroke(f, C.Ink, 2.5)
    label(f, "T", text, 0, 0, w, 28, kind == "wide" and 15 or 17, C.White, CENTER)
    return f
end

----------------------------------------------------------------------------
-- TOAST + TOOLTIP
----------------------------------------------------------------------------
local notice = panel(stage, "Notice", 0, 0, 580, 60, C.Panel, C.Deep, C.Cyan, 14)
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.Position = UDim2.new(0.5, 0, 1, 90)
notice.ZIndex = 50
notice.Visible = false
local noticeText = label(notice, "Text", "", 12, 0, 556, 60, 22, C.White, CENTER)
noticeText.Size = UDim2.new(1, -24, 1, 0)
local noticeCount = 0
local function toast(message)
    noticeCount = noticeCount + 1
    local current = noticeCount
    noticeText.Text = message
    notice.Visible = true
    notice.Position = UDim2.new(0.5, 0, 1, 90)
    tween(notice, 0.35, {Position = UDim2.new(0.5, 0, 1, -130)}, Enum.EasingStyle.Back)
    task.delay(3.5, function()
        if current == noticeCount and notice.Parent then
            tween(notice, 0.25, {Position = UDim2.new(0.5, 0, 1, 90)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.27, function()
                if current == noticeCount then notice.Visible = false end
            end)
        end
    end)
end

local tipBox = panel(stage, "Tooltip", 0, 0, 120, 38, C.Panel, C.Deep, C.Cyan, 10)
tipBox.AnchorPoint = Vector2.new(1, 0.5)
tipBox.Visible = false
tipBox.ZIndex = 60
local tipScale = new("UIScale", tipBox, {Scale = 1})
local tipText = label(tipBox, "Text", "", 0, 0, 120, 38, 20, C.White, CENTER)
tipText.Size = UDim2.fromScale(1, 1)
local tipOwner
local function attachTip(target, text)
    local function show()
        tipOwner = target
        tipText.Text = text
        tipBox.Size = UDim2.fromOffset(28 + #text * 11, 38)
        local k = stageScale.Scale
        local ap, as, origin = target.AbsolutePosition, target.AbsoluteSize, stage.AbsolutePosition
        tipBox.Position = UDim2.fromOffset((ap.X - origin.X) / k - 10, (ap.Y - origin.Y + as.Y / 2) / k)
        tipBox.Visible = true
        tipScale.Scale = 0.7
        tween(tipScale, 0.15, {Scale = 1}, Enum.EasingStyle.Back)
    end
    local function hide() if tipOwner == target then tipBox.Visible = false end end
    target.MouseEnter:Connect(show)
    target.MouseLeave:Connect(hide)
    target.SelectionGained:Connect(show)
    target.SelectionLost:Connect(hide)
end


----------------------------------------------------------------------------
-- SERVER ACTIONS + PURCHASES (same rules as before: UI only, server decides)
----------------------------------------------------------------------------
local function sendAction(action, value)
    local remote = ReplicatedStorage:FindFirstChild(Config.ActionRemoteName)
    if not remote or not remote:IsA("RemoteEvent") then
        toast("This feature is coming soon.")
        if RunService:IsStudio() then
            warn("SpaceGUI: connect server action " .. action .. " in " .. Config.ActionRemoteName)
        end
        return false
    end
    remote:FireServer(action, value)
    return true
end

local randomPurchasesAllowed = false
if Config.PurchasesEnabled then
    task.spawn(function()
        local ok, policy = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
        randomPurchasesAllowed = ok and policy.ArePaidRandomItemsRestricted == false
    end)
end
local productCache = {}
local purchaseButtons = {}
local purchaseBusy = false
local function purchase(item)
    if purchaseBusy then return end
    if not Config.PurchasesEnabled or not item.ProductId or item.ProductId <= 0 then
        toast("This item is not on sale yet.")
        return
    end
    if item.Random and not randomPurchasesAllowed then
        toast("This purchase is not available right now.")
        return
    end
    local info = productCache[item.Key]
    if not info or not info.IsForSale or type(info.PriceInRobux) ~= "number" then
        toast("This item is not available right now.")
        return
    end
    if info.Owned then toast("You already own this pass.") return end
    purchaseBusy = true
    local ok = pcall(function()
        if item.Kind == "Pass" then MarketplaceService:PromptGamePassPurchase(player, item.ProductId)
        else MarketplaceService:PromptProductPurchase(player, item.ProductId) end
    end)
    if not ok then toast("Could not open the purchase. Please try again.") end
    task.delay(1, function() purchaseBusy = false end)
end


-- Cyan price plate: Robux icon + amount, or plain status text ("Coming soon").
local function buyButton(parent, item, x, y, w, h)
    local b, face, lbl = button(parent, item.Key, "Coming soon", x, y, w, h, C.Cyan,
        function() purchase(item) end, {flat = true, textSize = 22})
    local row = new("Frame", face, {Name = "PriceRow", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 3, Visible = false})
    new("UIListLayout", row, {FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
    local chip = Icons.new("Robux", row, math.floor(h * 0.58))
    chip.LayoutOrder = 1
    local amount = new("TextLabel", row, {Name = "Amount", LayoutOrder = 2, BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "",
        Font = Enum.Font.FredokaOne, TextSize = math.clamp(math.floor(h * 0.55), 18, 36), TextColor3 = C.White})
    new("UIStroke", amount, {Color = C.Ink, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round})
    local entry = {Button = b, Item = item, Row = row, Amount = amount, Label = lbl}
    table.insert(purchaseButtons, entry)
    return b, entry
end
local function showPriceText(entry, text)
    entry.Row.Visible = false
    entry.Label.Text = text
end
local function showPriceAmount(entry, amount)
    entry.Row.Visible = true
    entry.Label.Text = ""
    entry.Amount.Text = tostring(amount)
end
-- Magenta gift button next to every price plate.
local function giftButton(parent, item, x, y, size)
    local b, face, _, depth = button(parent, "Gift_" .. item.Key, "", x, y, size, size, C.Magenta, function()
        if Config.GiftsEnabled then sendAction("GiftItem", item.Key)
        else toast("Gifting is coming soon.") end
    end, {radius = 10, hoverScale = 1.1})
    local g = math.floor(size * 0.62)
    icon("Gift", face, (size - g) / 2, (size - depth - g) / 2, g)
    return b
end


local function refreshPrices()
    for _, entry in ipairs(purchaseButtons) do
        local item, b = entry.Item, entry.Button
        if b.Parent then
            if Config.PurchasesEnabled and item.ProductId > 0 then
                showPriceText(entry, "Loading...")
                task.spawn(function()
                    local info = productCache[item.Key]
                    if not info then
                        local ok, result = pcall(function()
                            return MarketplaceService:GetProductInfoAsync(item.ProductId,
                                item.Kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
                        end)
                        if ok then info = result productCache[item.Key] = result end
                        if info and item.Kind == "Pass" then
                            local ownOK, owned = pcall(function()
                                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.ProductId)
                            end)
                            info.Owned = ownOK and owned or false
                        end
                    end
                    if b.Parent then
                        if info and info.Owned then showPriceText(entry, "Owned")
                        elseif info and info.IsForSale and type(info.PriceInRobux) == "number" then
                            showPriceAmount(entry, info.PriceInRobux)
                        else showPriceText(entry, "Unavailable") end
                    end
                end)
            else showPriceText(entry, "Coming soon") end
        end
    end
end


----------------------------------------------------------------------------
-- HUD: left menu, right menu, stats, moon timer   (all vector + 3D, no images)
----------------------------------------------------------------------------
local left = frame(hud, "LeftMenu", 14, 0, 190, 340)
left.AnchorPoint = Vector2.new(0, 0.5)
left.Position = UDim2.new(0, 14, 0.47, 0)
local leftScale = new("UIScale", left, {Scale = 1})
local right = frame(hud, "RightMenu", 0, 0, 94, 290)
right.AnchorPoint = Vector2.new(1, 0.5)
right.Position = UDim2.new(1, -14, 0.47, 0)
local rightScale = new("UIScale", right, {Scale = 1})
local stats = frame(hud, "Stats", 14, 0, 262, 146)
stats.AnchorPoint = Vector2.new(0, 1)
stats.Position = UDim2.new(0, 14, 1, -18)
local statScale = new("UIScale", stats, {Scale = 1})

local function menuButton(name, text, iconName, y, color, targetPage)
    local b, face, lbl = button(left, name, text, 0, y, 184, 84, color,
        function() openPage(targetPage, targetPage == "Shop" and "Featured" or nil) end,
        {rim = C.Cyan, textSize = 36, radius = 14})
    icon(iconName, face, 8, 6, 64)
    lbl.Position = UDim2.fromOffset(72, 0)
    lbl.Size = UDim2.new(1, -76, 1, 0)
    return b, lbl
end
local shopBtn = menuButton("Shop", "Shop", "Cart", 0, C.Purple, "Shop")
local _, jetpackMenuLabel = menuButton("Jetpacks", "Jetpacks", "Rocket", 96, Color3.fromRGB(240, 110, 40), "Jetpacks")
jetpackMenuLabel.TextScaled = true -- "Jetpacks" is too long for the shared 36px size
new("UITextSizeConstraint", jetpackMenuLabel, {MaxTextSize = 36})
menuButton("Index", "Index", "Book", 192, Color3.fromRGB(24, 128, 226), "Index")
local shopKeyCap = keycap(shopBtn, "B", Color3.fromRGB(70, 80, 120), "key", 0)
shopKeyCap.AnchorPoint = Vector2.new(1, 0)
shopKeyCap.Position = UDim2.new(1, 6, 0, -8)
shopKeyCap.ZIndex = 6

-- Slow Mode: toggle switch with a sliding knob.
local slowBtn = new("TextButton", left, {Name = "SlowMode", Text = "", AutoButtonColor = false,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 292), Size = UDim2.fromOffset(184, 46),
    SelectionImageObject = selectionCursor})
local track = panel(slowBtn, "Track", 3, 4, 88, 38, C.Deep, C.Navy, C.Cyan, 12)
local knob = panel(track, "Knob", 4, 4, 38, 30, Color3.fromRGB(120, 235, 255), C.Cyan, nil, 9)
local knobTint = new("Frame", knob, {Name = "OnTint", BackgroundColor3 = C.Green, BackgroundTransparency = 1,
    BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)})
corner(knobTint, 9)
local slowText = label(slowBtn, "Text", "Slow Mode", 98, 4, 88, 38, 19, C.White)
slowText.TextWrapped = false
local function applySlow(on)
    tween(knob, 0.22, {Position = UDim2.fromOffset(on and 46 or 4, 4)}, Enum.EasingStyle.Back)
    tween(knobTint, 0.22, {BackgroundTransparency = on and 0.05 or 1})
end
slowBtn.Activated:Connect(function()
    playSound("Click")
    sendAction("SetSlowMode", not player:GetAttribute("SpaceSlowMode"))
end)
applySlow(player:GetAttribute("SpaceSlowMode") == true)
player:GetAttributeChangedSignal("SpaceSlowMode"):Connect(function()
    applySlow(player:GetAttribute("SpaceSlowMode") == true)
end)

-- Right column: Eggs (live 3D egg), Pets (helmet), Boosts (potion). Tooltips on hover/select.
local function rightButton(index, name)
    local b, face = button(right, name, "", 4, (index - 1) * 102, 86, 86, C.Navy,
        function() openPage(name) end, {rim = C.Cyan, radius = 14, hoverScale = 1.08})
    attachTip(b, name)
    return face
end
Models.EggView(rightButton(1, "Eggs"), 1, {Position = UDim2.fromOffset(11, 3), Size = UDim2.fromOffset(64, 68)})
icon("Helmet", rightButton(2, "Pets"), 12, 8, 62)
icon("Potion", rightButton(3, "Boosts"), 12, 8, 62)

-- Stat pills: the whole pill opens the matching shop tab.
local function statRow(name, iconName, y, color, tabName)
    local _, face, lbl = button(stats, name, "", 0, y, 254, 66, C.Deep,
        function() openPage("Shop", tabName) end, {rim = C.Cyan, radius = 16, hoverScale = 1.03, depth = 6})
    lbl.Visible = false
    icon(iconName, face, 8, 3, 54)
    local plus = panel(face, "Plus", 44, 30, 26, 26, C.Gold, C.GoldDeep, nil, 7)
    icon("Plus", plus, 3, 3, 20)
    return label(face, "Value", "0", 76, 0, 172, 60, 36, color)
end
local speedLabel = statRow("Speed", "Rocket", 0, C.Gold, "Speed")
local creditLabel = statRow("Credits", "Coins", 76, C.Green, "Credits")

-- Moon countdown (bottom right). Only visible when a timer exists.
local moonPill = panel(hud, "MoonTimer", 0, 0, 220, 58, C.Deep, C.Navy, C.Cyan, 18)
moonPill.AnchorPoint = Vector2.new(1, 1)
moonPill.Position = UDim2.new(1, -14, 1, -18)
moonPill.Visible = false
local moonScale = new("UIScale", moonPill, {Scale = 1})
icon("Moon", moonPill, 8, 7, 44)
local moonText = label(moonPill, "Text", "", 60, 0, 154, 58, 26, C.White)

-- Jetpack bar (bottom middle): Base teleports to your own launch pad, LAUNCH flies (JetpackFlight).
-- Launching only works on a launch pad; the LAUNCH button glows while you stand on one.
local LAUNCH_COLOR = Color3.fromRGB(255, 120, 40)
local launchBar = frame(hud, "JetpackBar", 0, 0, 326, 96)
launchBar.AnchorPoint = Vector2.new(0.5, 1)
launchBar.Position = UDim2.new(0.5, 0, 1, -18)
local launchScale = new("UIScale", launchBar, {Scale = 1})
local launchGlow = new("Frame", launchBar, {Name = "PadGlow", BackgroundColor3 = C.Gold, BorderSizePixel = 0,
    Position = UDim2.fromOffset(94, -6), Size = UDim2.fromOffset(238, 104), Visible = false})
corner(launchGlow, 20)
loop(launchGlow, 0.7, {BackgroundTransparency = 0.75}, true)
local launchBtn, _, launchLabel
local baseBtn, baseFace = button(launchBar, "Base", "", 0, 4, 86, 86, C.Navy,
    function() teleportToBase() end, {rim = C.Cyan, radius = 14, hoverScale = 1.08})
icon("Rocket", baseFace, 12, 2, 62)
attachTip(baseBtn, "Go to your launch pad")
launchBtn, _, launchLabel = button(launchBar, "Launch", "LAUNCH", 100, 0, 226, 92, LAUNCH_COLOR,
    function() launchJetpack() end, {rim = C.Gold, radius = 16, textSize = 40, hoverScale = 1.05})
local launchCap = keycap(launchBtn, "F", Color3.fromRGB(70, 80, 120), "key", 0)
launchCap.AnchorPoint = Vector2.new(1, 0)
launchCap.Position = UDim2.new(1, 6, 0, -8)
launchCap.ZIndex = 6
local baseCap = keycap(baseBtn, "T", Color3.fromRGB(70, 80, 120), "key", 0)
baseCap.AnchorPoint = Vector2.new(1, 0)
baseCap.Position = UDim2.new(1, 6, 0, -8)
baseCap.ZIndex = 6

----------------------------------------------------------------------------
-- WINDOW SHELL
----------------------------------------------------------------------------
-- fit: scales the window if the screen is tiny. group: pop-in/out animation.
local fit = frame(stage, "WindowFit", 0, 0, 1092, 700)
fit.AnchorPoint = Vector2.new(0.5, 0.5)
fit.Position = UDim2.fromScale(0.5, 0.5)
fit.Visible = false
fit.ZIndex = 5
local fitScale = new("UIScale", fit, {Scale = 1})
local group = new("Frame", fit, {Name = "Group", BackgroundTransparency = 1, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1)})
local pop = new("UIScale", group, {Scale = 1})

local windowRim = new("Frame", group, {Name = "OuterRim", BackgroundColor3 = C.Ink, BorderSizePixel = 0,
    Position = UDim2.fromOffset(-8, -8), Size = UDim2.fromOffset(976, 716)})
corner(windowRim, 30)
local window = new("Frame", group, {Name = "Window", BackgroundColor3 = C.White, BorderSizePixel = 0,
    Size = UDim2.fromOffset(960, 700), Active = true})
corner(window, 24)
vgrad(window, Color3.fromRGB(14, 32, 92), C.Deep)
local windowStroke = stroke(window, C.Cyan, 5)
new("UIGradient", windowStroke, {Color = ColorSequence.new(Color3.fromRGB(90, 235, 255),
    Color3.fromRGB(40, 110, 255)), Rotation = 90})

local contentBack = new("Frame", window, {Name = "ContentBack", BackgroundColor3 = C.Deep,
    BackgroundTransparency = 0.15, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 92),
    Size = UDim2.fromOffset(940, 598)})
corner(contentBack, 16)
stroke(contentBack, C.Violet, 2, 0.3)

local titlebar = new("Frame", window, {Name = "TitleBar", BackgroundColor3 = C.White, BorderSizePixel = 0,
    Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(944, 76), ClipsDescendants = true})
corner(titlebar, 16)
vgrad(titlebar, Color3.fromRGB(100, 46, 224), Color3.fromRGB(40, 40, 170))
stroke(titlebar, C.Ink, 3)

-- Space header drawn with circles: big blue planet, ringed planet, moon, comet, stars.
local function orb(parent, x, y, d, top, bottom, transparency)
    local p = new("Frame", parent, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, y),
        Size = UDim2.fromOffset(d, d), BackgroundColor3 = C.White, BorderSizePixel = 0,
        BackgroundTransparency = transparency or 0})
    corner(p, d)
    vgrad(p, top, bottom)
    return p
end
local farHolder = new("Frame", titlebar, {Name = "Far", BackgroundTransparency = 1, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 470, 1, 0)})
orb(farHolder, 430, 26, 210, Color3.fromRGB(120, 210, 255), Color3.fromRGB(24, 70, 190))
orb(farHolder, 452, 40, 210, Color3.fromRGB(8, 24, 110), Color3.fromRGB(8, 24, 110), 0.5)
orb(farHolder, 150, -2, 40, Color3.fromRGB(220, 150, 255), Color3.fromRGB(105, 55, 205))
local ring = new("Frame", farHolder, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 150, 0.5, -2),
    Size = UDim2.fromOffset(104, 26), Rotation = -18, BackgroundTransparency = 1, BorderSizePixel = 0})
corner(ring, 30)
stroke(ring, Color3.fromRGB(240, 215, 255), 3, 0.1)
orb(farHolder, 240, -16, 20, Color3.fromRGB(190, 225, 255), Color3.fromRGB(90, 140, 230))
local streak = new("Frame", farHolder, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 60, 0.5, -10),
    Size = UDim2.fromOffset(120, 5), Rotation = 24, BackgroundColor3 = C.White, BorderSizePixel = 0})
corner(streak, 3)
new("UIGradient", streak, {Transparency = NumberSequence.new(1, 0)})
twinkle(farHolder, 24, 12, 14, true)
twinkle(farHolder, 300, 44, 11, true)
twinkle(farHolder, 350, 10, 16, true)

local title = label(titlebar, "Title", "Shop", 22, 0, 380, 76, 50, C.White)
title.ZIndex = 3
local close = button(titlebar, "Close", "X", 880, 9, 54, 54, C.Red, function() closeWindow() end,
    {textSize = 34, radius = 12, hoverScale = 1.1})
close.ZIndex = 4
close.MouseEnter:Connect(function() tween(close, 0.25, {Rotation = 90}, Enum.EasingStyle.Back) end)
close.MouseLeave:Connect(function() tween(close, 0.25, {Rotation = 0}, Enum.EasingStyle.Back) end)

-- Shop tabs: icon column beside the window (wide screens) or a row under the title.
local tabOrder = {"Featured", "Speed", "Credits"}
local tabIcons = {Featured = "Star", Speed = "Rocket", Credits = "Coins"}
local tabHolder = frame(group, "ShopTabs", 0, 0, TAB_W, 364)
local tabPlate = panel(tabHolder, "Selected", 0, 0, TAB_W, 116, C.Violet, C.Deep, C.Cyan, 18)
tabPlate.BackgroundTransparency = 0.2
local tabSlots = {}
for _, name in ipairs(tabOrder) do
    local btn = new("TextButton", tabHolder, {Name = name, Text = "", AutoButtonColor = false,
        BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(TAB_W, 116), ZIndex = 2, SelectionImageObject = selectionCursor})
    local hoverScale = new("UIScale", btn, {Scale = 1})
    local ic = Icons.new(tabIcons[name], btn, 64)
    ic.AnchorPoint = Vector2.new(0.5, 0.5)
    local iconScale = new("UIScale", ic, {Scale = 1})
    local text = label(btn, "Label", name, 0, 0, TAB_W, 30, 26, C.Gold, CENTER)
    local function grow(on) tween(hoverScale, 0.12, {Scale = on and 1.08 or 1}, Enum.EasingStyle.Back) end
    btn.MouseEnter:Connect(function() grow(true) end)
    btn.MouseLeave:Connect(function() grow(false) end)
    btn.SelectionGained:Connect(function() grow(true) end)
    btn.SelectionLost:Connect(function() grow(false) end)
    btn.Activated:Connect(function()
        if currentTab == name then return end
        playSound("Click")
        currentTab = name
        selectTab(name, false)
        render()
    end)
    tabSlots[name] = {Btn = btn, Icon = ic, IconScale = iconScale, Label = text, Pos = Vector2.new(0, 0)}
end
selectTab = function(name, instant)
    local chosen = tabSlots[name]
    if not chosen then return end
    local target = UDim2.fromOffset(chosen.Pos.X, chosen.Pos.Y)
    if instant then tabPlate.Position = target
    else tween(tabPlate, 0.32, {Position = target}, Enum.EasingStyle.Back) end
    for tabName, slot in pairs(tabSlots) do
        local on = tabName == name
        tween(slot.IconScale, 0.25, {Scale = on and 1.18 or 1}, Enum.EasingStyle.Back)
        slot.Label.TextColor3 = on and C.Gold or Color3.fromRGB(205, 214, 240)
        if on and not instant then
            slot.Icon.Rotation = -14
            tween(slot.Icon, 0.4, {Rotation = 0}, Enum.EasingStyle.Back)
        end
    end
end

local pages = new("ScrollingFrame", window, {Name = "Content", Position = UDim2.fromOffset(16, 100),
    Size = UDim2.fromOffset(928, 580), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 8, ScrollBarImageColor3 = C.Cyan, CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y})
new("UIListLayout", pages, {Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder})
new("UIPadding", pages, {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 24)})

-- Input hints along the bottom of the window (hidden on touch devices).
local hintBar = new("Frame", window, {Name = "Hints", BackgroundTransparency = 1, BorderSizePixel = 0,
    Position = UDim2.fromOffset(16, 660), Size = UDim2.fromOffset(928, 30)})
new("UIListLayout", hintBar, {FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder})
local function hintItem(order, caps, text)
    local item = new("Frame", hintBar, {BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order})
    new("UIListLayout", item, {FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
    for i, cap in ipairs(caps) do keycap(item, cap[1], cap[2], cap[3], i) end
    local l = label(item, "Text", text, 0, 0, 10, 28, 19, C.Muted)
    l.LayoutOrder = #caps + 1
    l.AutomaticSize = Enum.AutomaticSize.X
    l.Size = UDim2.fromOffset(0, 28)
    l.TextWrapped = false
end
updateHints = function()
    for _, child in ipairs(hintBar:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    hintBar.Visible = Lm.hint > 0
    shopKeyCap.Visible = inputMode ~= "Touch"
    local key = shopKeyCap:FindFirstChild("T")
    if key then key.Text = inputMode == "Gamepad" and "Y" or "B" end
    local gray = Color3.fromRGB(70, 80, 120)
    if inputMode == "Gamepad" then
        hintItem(1, {{"A", Color3.fromRGB(70, 190, 90), "pad"}}, "Select")
        hintItem(2, {{"B", Color3.fromRGB(225, 70, 70), "pad"}}, "Close")
        if currentPage == "Shop" then hintItem(3, {{"LB", gray, "wide"}, {"RB", gray, "wide"}}, "Tabs") end
    elseif inputMode == "Keyboard" then
        hintItem(1, {{"B", gray, "key"}}, "Open / close")
    end
    launchCap.Visible = inputMode ~= "Touch"
    baseCap.Visible = inputMode ~= "Touch"
    launchCap.T.Text = inputMode == "Gamepad" and "X" or "F"
    baseCap.T.Text = inputMode == "Gamepad" and "LT" or "T"
end


----------------------------------------------------------------------------
-- PAGE BUILDERS  (3D pets + eggs in ViewportFrames, vector icons everywhere)
----------------------------------------------------------------------------
local petById = {}
for _, p in ipairs(Config.Pets) do petById[p.Id] = p end

local function clearContent()
    for _, t in ipairs(pageLoops) do t:Cancel() end
    pageLoops = {}
    for _, child in ipairs(pages:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    pages.CanvasPosition = Vector2.new(0, 0)
    purchaseButtons = {}
    bannerTimer = nil
end
local function section(text, order)
    local l = label(pages, "Section", "-- " .. text .. " --", 0, 0, bodyWidth, 44, 32, C.Gold, CENTER)
    goldText(l)
    l.LayoutOrder = order
    return l
end
local function dataFolder(category)
    local data = player:FindFirstChild(Config.DataFolderName)
    return data and data:FindFirstChild(category)
end
local function ownedPet(id)
    local pets = dataFolder("Pets")
    if pets then
        for _, v in ipairs(pets:GetChildren()) do
            if v:IsA("StringValue") and v.Value == id then return true end
        end
    end
    return false
end

-- Hover / select / tap makes a 3D model come alive.
local function attachSpin(hit, vp, ctl)
    hit.MouseEnter:Connect(function() ctl.Spin(true, "sway") end)
    hit.MouseLeave:Connect(function() ctl.Spin(false) end)
    hit.SelectionGained:Connect(function() ctl.Spin(true, "sway") end)
    hit.SelectionLost:Connect(function() ctl.Spin(false) end)
    hit.Activated:Connect(function()
        ctl.Spin(true, "spin")
        task.delay(2.4, function() if vp.Parent then ctl.Spin(false) end end)
    end)
end
local function hitbox(parent)
    return new("TextButton", parent, {Name = "Hit", Text = "", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 10, AutoButtonColor = false, SelectionImageObject = selectionCursor})
end
-- Soft colored disc behind a 3D model.
local function aura(parent, cx, cy, d, color, transparency)
    local a = new("Frame", parent, {Name = "Aura", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(d, d), BackgroundColor3 = color,
        BackgroundTransparency = transparency, BorderSizePixel = 0})
    corner(a, d)
    return a
end

-- Pet card on the Galaxy Egg banner: 3D pet on top, odds underneath.
local function bannerPetCard(parent, p, x, y, w, h)
    local col = RarityColor[p.Rarity] or C.Cyan
    local special = p.Rarity == "Legendary" or p.Rarity == "Mythic"
    local card = panel(parent, p.Id, x, y, w, h, Color3.fromRGB(36, 46, 124), C.Deep,
        special and col or C.Violet, 12)
    local artH = h - 36
    local disc = aura(card, w / 2, 6 + artH / 2, math.min(w - 12, artH) * 0.95, col, special and 0.7 or 0.86)
    if special then
        loop(disc, 1.1, {BackgroundTransparency = 0.5})
        local rimStroke = card.Rim:FindFirstChildOfClass("UIStroke")
        rimStroke.Thickness = 3
        rimStroke.Transparency = 0
        local sweep = new("UIGradient", rimStroke, {Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, col), ColorSequenceKeypoint.new(0.5, C.White),
            ColorSequenceKeypoint.new(1, col)})})
        spin(sweep, 2.6)
    end
    local vp, ctl = Models.PetView(card, p.Id, {Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(w - 12, artH), Aspect = (w - 12) / artH})
    local odds = label(card, "Odds", tostring(p.Odds) .. "%", 0, artH + 6, w, 28, 24, C.Gold, CENTER)
    local hit = hitbox(card)
    attachSpin(hit, vp, ctl)
    hit.MouseEnter:Connect(function()
        odds.Text = p.Name
        odds.TextSize = 16
        odds.TextColor3 = C.White
        tween(card, 0.15, {Position = UDim2.fromOffset(x, y - 5)}, Enum.EasingStyle.Back)
    end)
    hit.MouseLeave:Connect(function()
        odds.Text = tostring(p.Odds) .. "%"
        odds.TextSize = 24
        odds.TextColor3 = C.Gold
        tween(card, 0.15, {Position = UDim2.fromOffset(x, y)}, Enum.EasingStyle.Quad)
    end)
    return card
end

local function eggCountFor(item)
    return tonumber(tostring(item.Name):match("%d+")) or 1
end

local function makeFeatured()
    section("FEATURED", 1)
    local columns = bodyWidth >= 640 and 7 or 4
    local gap = 8
    local cardW = math.floor((bodyWidth - 32 - (columns - 1) * gap) / columns)
    local cardH = math.floor((cardW - 12) * PET_RATIO) + 36
    local rows = math.ceil(#Config.Pets / columns)
    local packColumns = narrow and 2 or 4
    local packRows = math.ceil(#Config.EggPacks / packColumns)
    local headerH = narrow and 104 or 116
    local height = headerH + rows * (cardH + gap) + 6 + packRows * 138 + 8

    local banner = panel(pages, "GalaxyEgg", 0, 0, bodyWidth, height,
        Color3.fromRGB(78, 34, 168), Color3.fromRGB(22, 22, 90), C.Purple, 18)
    banner.LayoutOrder = 2
    banner.ClipsDescendants = true

    -- Nebula glow + twinkling stars.
    local blob = aura(banner, bodyWidth * 0.78, 30, 320, C.Magenta, 0.86)
    loop(blob, 3.5, {BackgroundTransparency = 0.94})
    local blob2 = aura(banner, bodyWidth * 0.12, height - 40, 280, C.Cyan, 0.9)
    loop(blob2, 4.5, {BackgroundTransparency = 0.95})
    local rng = Random.new(11)
    for _ = 1, 16 do
        local sz = rng:NextInteger(2, 4)
        local star = new("Frame", banner, {Name = "Star", BackgroundColor3 = C.White, BorderSizePixel = 0,
            BackgroundTransparency = rng:NextNumber(0.1, 0.5),
            Position = UDim2.fromOffset(rng:NextInteger(10, bodyWidth - 10), rng:NextInteger(6, headerH - 8)),
            Size = UDim2.fromOffset(sz, sz)})
        corner(star, 2)
        loop(star, rng:NextNumber(0.8, 2), {BackgroundTransparency = 0.95})
    end
    twinkle(banner, bodyWidth - 300, 20, 14)
    twinkle(banner, 460, 58, 10)

    -- Hero: the Galaxy Egg model floats and sways next to the title.
    local eggW = narrow and 80 or 100
    local eggH = headerH - 8
    aura(banner, 6 + eggW / 2, 4 + eggH / 2, eggW * 0.95, C.Magenta, 0.78)
    local _, heroCtl = Models.EggView(banner, 1, {Position = UDim2.fromOffset(6, 4),
        Size = UDim2.fromOffset(eggW, eggH), Aspect = eggW / eggH, Yaw = 0.35, Bob = 0.03})
    heroCtl.Spin(true, "sway")

    -- "New!" tag sits in front of the title (like the artwork) so it never covers the egg.
    local textX = eggW + 14
    local tagW = narrow and 70 or 92
    local tagH = narrow and 32 or 40
    local tag = new("Frame", banner, {Name = "NewTag", BackgroundColor3 = C.White, BorderSizePixel = 0,
        Position = UDim2.fromOffset(textX, narrow and 10 or 16), Size = UDim2.fromOffset(tagW, tagH),
        Rotation = -4, ZIndex = 3})
    corner(tag, 9)
    vgrad(tag, Color3.fromRGB(255, 90, 90), Color3.fromRGB(190, 20, 34))
    stroke(tag, C.Ink, 3)
    label(tag, "Text", "New!", 0, 0, tagW, tagH, narrow and 20 or 25, C.White, CENTER)
    loop(tag, 1.1, {Rotation = 2})

    local headX = textX + tagW + 10
    local heading = label(banner, "Heading", "GALAXY EGG", headX, 4, bodyWidth - headX - (narrow and 8 or 290),
        narrow and 48 or 64, narrow and 32 or 52, C.White)
    goldText(heading)
    label(banner, "Subtitle", featuredEnd and "Limited Time!" or "Find your next space pet",
        textX + 2, narrow and 50 or 66, 300, 30, narrow and 20 or 24, C.White)
    if narrow then
        bannerTimer = label(banner, "Timer", "", textX + 2, 76, bodyWidth - textX - 10, 24, 20, C.Muted)
    else
        bannerTimer = label(banner, "Timer", "", bodyWidth - 282, 16, 268, 32, 27, C.White, RIGHT)
    end

    -- Pet cards.
    local rowW = columns * cardW + (columns - 1) * gap
    local startX = math.floor((bodyWidth - rowW) / 2)
    for i, p in ipairs(Config.Pets) do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        bannerPetCard(banner, p, startX + col * (cardW + gap), headerH + row * (cardH + gap), cardW, cardH)
    end

    -- Egg packs: 3D egg pile + gift + price plate.
    local packY = headerH + rows * (cardH + gap) + 6
    local cellW = math.floor((bodyWidth - 32 - (packColumns - 1) * 12) / packColumns)
    for i, item in ipairs(Config.EggPacks) do
        local cx = 16 + ((i - 1) % packColumns) * (cellW + 12)
        local cy = packY + math.floor((i - 1) / packColumns) * 138
        local pileView, pileCtl = Models.EggView(banner, eggCountFor(item),
            {Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(64, 64)})
        local pileHit = hitbox(banner)
        pileHit.Position = UDim2.fromOffset(cx, cy)
        pileHit.Size = UDim2.fromOffset(64, 64)
        attachSpin(pileHit, pileView, pileCtl)
        label(banner, "Quantity", item.Name, cx + 70, cy + 8, cellW - 70, 48, narrow and 22 or 26, C.White)
        giftButton(banner, item, cx, cy + 70, 54)
        buyButton(banner, item, cx + 60, cy + 70, cellW - 60, 58)
    end

    -- Shimmer sweep across the banner every few seconds.
    local shimmer = new("Frame", banner, {Name = "Shimmer", BackgroundColor3 = C.White, BorderSizePixel = 0,
        Rotation = 18, Position = UDim2.new(0, -200, -0.5, 0), Size = UDim2.new(0, 90, 2, 0), ZIndex = 8})
    new("UIGradient", shimmer, {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1)})})
    task.spawn(function()
        task.wait(1.2)
        while shimmer.Parent do
            shimmer.Position = UDim2.new(0, -200, -0.5, 0)
            tween(shimmer, 1.3, {Position = UDim2.new(0, bodyWidth + 120, -0.5, 0)},
                Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
            task.wait(5)
        end
    end)

    -- Passes.
    section("PASSES", 3)
    local passCols = narrow and 1 or 2
    local passH = 204
    local passW = math.floor((bodyWidth - (passCols - 1) * 14) / passCols)
    local passRows = math.ceil(#Config.Passes / passCols)
    local passRow = frame(pages, "Passes", 0, 0, bodyWidth, passRows * (passH + 14) - 14)
    passRow.LayoutOrder = 4
    for i, item in ipairs(Config.Passes) do
        local warm = i ~= 1
        local x = ((i - 1) % passCols) * (passW + 14)
        local y = math.floor((i - 1) / passCols) * (passH + 14)
        local card = panel(passRow, item.Key, x, y, passW, passH,
            warm and Color3.fromRGB(156, 108, 24) or Color3.fromRGB(58, 50, 196),
            warm and Color3.fromRGB(46, 34, 84) or Color3.fromRGB(16, 22, 88),
            warm and C.Gold or C.Purple, 16)
        local ic = icon(item.Icon or "Star", card, 12, 16, 116)
        loop(ic, 1.3 + i * 0.2, {Position = UDim2.fromOffset(12, 9)})
        label(card, "Name", item.Name, 138, 14, passW - 152, 46, 34, C.White)
        local desc = label(card, "Description", item.Description or "", 138, 62, passW - 152, 62, 23, C.White)
        desc.RichText = true
        desc.TextYAlignment = Enum.TextYAlignment.Top
        giftButton(card, item, 12, passH - 70, 54)
        buyButton(card, item, 72, passH - 70, passW - 84, 58)
    end
    if updateTimers then updateTimers() end
end

local function makePacks(items, heading, accent)
    section(heading:upper(), 1)
    local columns = narrow and 2 or 3
    local gap = 14
    local w = math.floor((bodyWidth - gap * (columns - 1)) / columns)
    local rows = math.ceil(#items / columns)
    local container = frame(pages, "Packs", 0, 0, bodyWidth, rows * 256)
    container.LayoutOrder = 2
    for i, item in ipairs(items) do
        local x = ((i - 1) % columns) * (w + gap)
        local y = math.floor((i - 1) / columns) * 256
        local card = panel(container, item.Key, x, y, w, 240, Color3.fromRGB(38, 52, 138), C.Deep, accent, 16)
        aura(card, w / 2, 66, 120, accent, 0.9)
        local ic = icon(item.Icon or "Star", card, w / 2 - 51, 16, 102)
        loop(ic, 1.1 + (i % 3) * 0.2, {Position = UDim2.fromOffset(w / 2 - 51, 8)})
        label(card, "Name", item.Name, 8, 124, w - 16, 44, 30, C.White, CENTER)
        giftButton(card, item, 12, 176, 54)
        buyButton(card, item, 72, 176, w - 84, 58)
    end
end

local function makeIndex()
    section("SPACE PET INDEX", 1)
    local columns = bodyWidth >= 780 and 4 or (bodyWidth >= 520 and 3 or 2)
    local gap = 14
    local w = math.floor((bodyWidth - (columns - 1) * gap) / columns)
    local artH = math.floor((w - 12) * PET_RATIO)
    local tileH = artH + 74
    local rows = math.ceil(#Config.Pets / columns)
    local box = frame(pages, "PetGrid", 0, 0, bodyWidth, rows * (tileH + gap))
    box.LayoutOrder = 2
    for i, p in ipairs(Config.Pets) do
        local owned = ownedPet(p.Id)
        local col = RarityColor[p.Rarity] or C.Cyan
        local x = ((i - 1) % columns) * (w + gap)
        local y = math.floor((i - 1) / columns) * (tileH + gap)
        local tile = panel(box, p.Id, x, y, w, tileH, Color3.fromRGB(34, 46, 126), C.Deep,
            owned and col or C.Violet, 14)
        aura(tile, w / 2, 6 + artH / 2, math.min(w - 12, artH) * 0.95, col, owned and 0.72 or 0.9)
        local vp, ctl = Models.PetView(tile, p.Id, {Position = UDim2.fromOffset(6, 6),
            Size = UDim2.fromOffset(w - 12, artH), Aspect = (w - 12) / artH,
            Tint = owned and Color3.new(1, 1, 1) or Color3.fromRGB(38, 46, 92)})
        if not owned then
            label(tile, "Locked", "?", 6, 6, w - 12, artH, math.floor(artH * 0.45), C.White, CENTER)
        end
        label(tile, "Name", p.Name, 4, artH + 10, w - 8, 28, narrow and 19 or 22, C.White, CENTER)
        label(tile, "Detail", owned and "Collected" or p.Rarity, 4, artH + 40, w - 8, 26,
            narrow and 17 or 20, owned and C.Green or col, CENTER)
        attachSpin(hitbox(tile), vp, ctl)
    end
end

local function emptyState(kind, heading, description)
    local box = panel(pages, "EmptyState", 0, 0, bodyWidth, 380, Color3.fromRGB(34, 46, 126), C.Deep, C.Purple, 18)
    box.LayoutOrder = 2
    aura(box, bodyWidth / 2, 96, 190, C.Purple, 0.82)
    if kind == "Eggs" then
        local _, ctl = Models.EggView(box, 1, {Position = UDim2.fromOffset(bodyWidth / 2 - 70, 20),
            Size = UDim2.fromOffset(140, 150), Aspect = 140 / 150, Bob = 0.03})
        ctl.Spin(true, "sway")
    else
        local ic = icon(kind == "Pets" and "Helmet" or "Potion", box, bodyWidth / 2 - 62, 34, 124)
        loop(ic, 1.3, {Position = UDim2.fromOffset(bodyWidth / 2 - 62, 20)})
    end
    label(box, "Heading", heading, 24, 186, bodyWidth - 48, 56, 38, C.White, CENTER)
    label(box, "Description", description, 34, 250, bodyWidth - 68, 80, 25, C.Muted, CENTER)
    twinkle(box, 60, 40, 16)
    twinkle(box, bodyWidth - 80, 70, 12)
    twinkle(box, 120, 300, 10)
    twinkle(box, bodyWidth - 140, 320, 14)
end

local function makeInventory(category)
    section(category:upper(), 1)
    local folder = dataFolder(category)
    local entries = {}
    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            if v:IsA("StringValue") then table.insert(entries, v) end
        end
    end
    table.sort(entries, function(a, b) return a.Name < b.Name end)
    if #entries == 0 then
        local descriptions = {Pets = "Your collected pets will appear here.",
            Eggs = "Your eggs will appear here.", Boosts = "Your saved boosts will appear here."}
        emptyState(category, "No " .. category:lower() .. " yet", descriptions[category])
        return
    end
    if category == "Pets" then
        local wrap = frame(pages, "EquipBestWrap", 0, 0, bodyWidth, 62)
        wrap.LayoutOrder = 2
        button(wrap, "EquipBest", "Equip Best", 0, 0, bodyWidth, 58, C.Purple,
            function() sendAction("EquipBest") end, {rim = C.Cyan, textSize = 28})
    end
    for i, entry in ipairs(entries) do
        local p = petById[entry.Value]
        local name = (p and p.Name) or entry:GetAttribute("DisplayName") or entry.Value
        local rarityCol = (p and RarityColor[p.Rarity]) or C.Cyan
        local f = panel(pages, entry.Name, 0, 0, bodyWidth, 120, Color3.fromRGB(34, 46, 126), C.Deep, rarityCol, 14)
        f.LayoutOrder = i + 2
        aura(f, 60, 60, 96, rarityCol, 0.8)
        if category == "Pets" then
            local vp, ctl = Models.PetView(f, entry.Value, {Position = UDim2.fromOffset(8, 8),
                Size = UDim2.fromOffset(104, 104)})
            local hit = hitbox(f)
            hit.Size = UDim2.new(0, 120, 1, 0)
            attachSpin(hit, vp, ctl)
        elseif category == "Eggs" then
            Models.EggView(f, 1, {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(96, 108), Aspect = 96 / 108})
        else
            icon("Potion", f, 16, 14, 92)
        end
        local nameW = bodyWidth - (narrow and 300 or 320)
        label(f, "Name", name, 132, 12, nameW, 50, narrow and 26 or 30, C.White)
        local detail = category == "Pets" and ("Power: " .. tostring(entry:GetAttribute("Power") or 0))
            or ("Count: " .. tostring(entry:GetAttribute("Count") or 1))
        label(f, "Details", detail, 132, 64, nameW, 36, 23, C.Muted)
        local action = category == "Pets" and "TogglePet" or category == "Eggs" and "HatchEgg" or "UseBoost"
        local text = category == "Pets" and (entry:GetAttribute("Equipped") and "Unequip" or "Equip")
            or category == "Eggs" and "Hatch" or "Use"
        button(f, "Action", text, bodyWidth - 172, 30, 156, 60, C.Purple,
            function() sendAction(action, entry.Name) end, {rim = C.Cyan, textSize = 26})
    end
end

-- Jetpacks page: every tier with a 3D preview, what it reaches, its stats and Buy / Equip.
-- Buying and equipping go through the server (ServerScriptService.Jetpacks), which checks the coins.
local jetpackBusy = false
local function jetpackRequest(remoteName, tier)
    if jetpackBusy then return end
    local remote = jetpackFolder:FindFirstChild(remoteName)
    if not remote then toast("Jetpacks are still loading, try again in a moment.") return end
    jetpackBusy = true
    local ok, success, message = pcall(remote.InvokeServer, remote, tier.Id)
    jetpackBusy = false
    if not ok then toast("Something went wrong, try again.") return end
    if message then toast(message) end
    if success then playSound("Open") end
end

local function statBar(parent, name, text, x, y, w, fill, color)
    label(parent, name, text, x, y, w, 24, 18, C.Muted)
    local track = panel(parent, name .. "Bar", x, y + 26, w, 16, C.Deep, C.Ink, nil, 8)
    local bar = new("Frame", track, {Name = "Fill", BackgroundColor3 = C.White, BorderSizePixel = 0,
        Size = UDim2.new(math.clamp(fill, 0.06, 1), 0, 1, 0)})
    corner(bar, 8)
    vgrad(bar, color:Lerp(C.White, 0.35), color)
end

local function makeJetpacks()
    section("JETPACKS", 1)
    local coins = JetpackConfig.Coins(player)
    local equipped = JetpackConfig.Equipped(player)
    local intro = panel(pages, "Intro", 0, 0, bodyWidth, 76, Color3.fromRGB(34, 46, 126), C.Deep, C.Cyan, 14)
    intro.LayoutOrder = 2
    icon("Coins", intro, 12, 10, 56)
    local coinText = label(intro, "Coins", formatNumber(coins), 76, 0, 150, 76, 34, C.Gold)
    coinText.TextWrapped = false
    label(intro, "Hint", "Better jetpacks fly higher. Stand on your launch pad and press LAUNCH!",
        236, 6, bodyWidth - 250, 64, narrow and 18 or 21, C.Muted)

    local maxSpeed, maxAir = JetpackConfig.Max("Speed"), JetpackConfig.Max("AirSpeed")
    local fastestCooldown = math.huge
    for _, tier in ipairs(JetpackConfig.Tiers) do fastestCooldown = math.min(fastestCooldown, tier.Cooldown) end
    local rowH = narrow and 172 or 156
    local btnW = narrow and 150 or 176
    for i, tier in ipairs(JetpackConfig.Tiers) do
        local col = RarityColor[tier.Rarity] or C.Cyan
        local owns = JetpackConfig.Owns(tier, player)
        local isEquipped = tier == equipped
        local f = panel(pages, tier.Id, 0, 0, bodyWidth, rowH, Color3.fromRGB(34, 46, 126), C.Deep,
            isEquipped and C.Green or col, 14)
        f.LayoutOrder = i + 2
        local art = rowH - 16
        aura(f, 8 + art / 2, rowH / 2, art * 0.95, tier.Colors.Glow, 0.78)
        local vp, ctl = Models.View(f, JetpackModels.Build(tier.Id, {Flames = true}), {
            Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(art, art), Yaw = -0.5, Margin = 1.15})
        local hit = hitbox(f)
        hit.Size = UDim2.new(0, art + 16, 1, 0)
        attachSpin(hit, vp, ctl)

        local tx = art + 22
        local textW = bodyWidth - tx - btnW - 22
        local nameLabel = label(f, "Name", tier.Name, tx, 8, textW, 38, narrow and 26 or 30, C.White)
        nameLabel.TextWrapped = false
        nameLabel.TextScaled = true
        new("UITextSizeConstraint", nameLabel, {MaxTextSize = narrow and 26 or 30})
        label(f, "Reach", tier.Rarity .. " - reaches " .. JetpackConfig.PlanetLabel(tier), tx, 44, textW, 28,
            narrow and 17 or 20, col)
        local statW = math.floor((textW - 20) / 3)
        local sy = narrow and 86 or 80
        statBar(f, "Climb", "Climb " .. tier.Speed, tx, sy, statW, tier.Speed / maxSpeed, C.Gold)
        statBar(f, "Steer", "Steer " .. tier.AirSpeed, tx + statW + 10, sy, statW, tier.AirSpeed / maxAir, C.Cyan)
        statBar(f, "Recharge", "Recharge " .. tier.Cooldown .. "s", tx + 2 * (statW + 10), sy, statW,
            fastestCooldown / tier.Cooldown, C.Green)

        local bx, by, bh = bodyWidth - btnW - 14, (rowH - 66) / 2, 66
        if isEquipped then
            button(f, "Equipped", "Equipped", bx, by, btnW, bh, C.Green, nil, {rim = C.White, textSize = 26})
        elseif owns then
            button(f, "Equip", "Equip", bx, by, btnW, bh, C.Purple,
                function() jetpackRequest("EquipJetpack", tier) end, {rim = C.Cyan, textSize = 28})
        else
            local canAfford = coins >= tier.Price
            local _, face, lbl = button(f, "Buy", formatNumber(tier.Price), bx, by, btnW, bh,
                canAfford and C.GoldDeep or Color3.fromRGB(70, 80, 120),
                function() jetpackRequest("BuyJetpack", tier) end, {rim = C.Gold, textSize = 28})
            icon("Coins", face, 8, 8, 44)
            lbl.Position = UDim2.fromOffset(50, 0)
            lbl.Size = UDim2.new(1, -56, 1, 0)
        end
    end
end

----------------------------------------------------------------------------
-- HATCH REVEAL: egg shakes, flashes, then the pet bursts out with light rays.
-- Trigger from your server: remote:FireClient(player, "Hatched", petId)
----------------------------------------------------------------------------
local hatchBusy = false
local function showHatch(petId)
    local p = petById[petId]
    if not p or hatchBusy then return end
    hatchBusy = true
    local col = RarityColor[p.Rarity] or C.Cyan
    local overlay = new("TextButton", stage, {Name = "Hatch", Text = "", AutoButtonColor = false,
        BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ZIndex = 40, SelectionImageObject = selectionCursor})
    tween(overlay, 0.3, {BackgroundTransparency = 0.2})
    local loops, ready, done = {}, false, false
    overlay.Activated:Connect(function() if ready then done = true end end)
    task.spawn(function()
        local holder = new("Frame", overlay, {BackgroundTransparency = 1, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -10),
            Size = UDim2.fromOffset(300, 340)})
        local _, eggCtl = Models.EggView(holder, 1, {Aspect = 300 / 340, Yaw = 0.3})
        eggCtl.Spin(true, "sway")
        for i = 1, 8 do
            tween(holder, 0.07, {Rotation = (i % 2 == 0 and 1 or -1) * (3 + i * 1.5)}, Enum.EasingStyle.Sine)
            task.wait(0.1)
        end
        local flash = new("Frame", overlay, {BackgroundColor3 = C.White, BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5})
        tween(flash, 0.12, {BackgroundTransparency = 0})
        task.wait(0.14)
        holder:Destroy()

        -- light rays + glow + sparkles
        local rays = new("Frame", overlay, {BackgroundTransparency = 1, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.44, 0), Size = UDim2.fromOffset(700, 700)})
        -- 5 full-length beams through the center = 10 rays. Each beam rotates around its
        -- own middle (the pet) and fades out toward both tips.
        for i = 0, 4 do
            local ray = new("Frame", rays, {BackgroundColor3 = col, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(40, 700), Rotation = i * 36})
            new("UIGradient", ray, {Rotation = 90, Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35),
                NumberSequenceKeypoint.new(1, 1)})})
        end
        table.insert(loops, spin(rays, 16, true))
        local glowDisc = aura(overlay, 0, 0, 380, col, 0.75)
        glowDisc.Position = UDim2.new(0.5, 0, 0.44, 0)
        table.insert(loops, loop(glowDisc, 1.0, {BackgroundTransparency = 0.55}, true))
        for i = 1, 9 do
            twinkle(overlay, math.random(60, 1400), math.random(40, 780), math.random(10, 20), true, loops)
        end

        local petHolder = new("Frame", overlay, {BackgroundTransparency = 1, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.44, 0), Size = UDim2.fromOffset(340, 340)})
        local petScale = new("UIScale", petHolder, {Scale = 0.15})
        local _, petCtl = Models.PetView(petHolder, petId, {Aspect = 1, Bob = 0.03})
        petCtl.Spin(true, "sway")
        tween(petScale, 0.55, {Scale = 1}, Enum.EasingStyle.Back)
        tween(flash, 0.6, {BackgroundTransparency = 1})

        local nameLabel = label(overlay, "Name", p.Name, 0, 0, 700, 64, 58, C.White, CENTER)
        nameLabel.AnchorPoint = Vector2.new(0.5, 0)
        nameLabel.Position = UDim2.new(0.5, 0, 0.44, 190)
        local rarity = label(overlay, "Rarity", p.Rarity:upper() .. "  -  " .. tostring(p.Odds) .. "%", 0, 0, 700, 40, 30, col, CENTER)
        rarity.AnchorPoint = Vector2.new(0.5, 0)
        rarity.Position = UDim2.new(0.5, 0, 0.44, 254)
        local prompt = label(overlay, "Prompt", inputMode == "Gamepad" and "Press A to continue"
            or (inputMode == "Touch" and "Tap to continue" or "Click to continue"), 0, 0, 700, 34, 22, C.Muted, CENTER)
        prompt.AnchorPoint = Vector2.new(0.5, 0)
        prompt.Position = UDim2.new(0.5, 0, 0.44, 306)
        table.insert(loops, loop(prompt, 0.8, {TextTransparency = 0.6}, true))
        task.wait(0.6)
        ready = true
        if inputMode == "Gamepad" then GuiService.SelectedObject = overlay end
        while overlay.Parent and not done do task.wait(0.1) end

        for _, t in ipairs(loops) do t:Cancel() end
        tween(overlay, 0.25, {BackgroundTransparency = 1})
        if GuiService.SelectedObject == overlay then GuiService.SelectedObject = nil end
        task.wait(0.05)
        overlay:Destroy()
        hatchBusy = false
    end)
end


----------------------------------------------------------------------------
-- LAYOUT + RENDER
----------------------------------------------------------------------------
layoutWindow = function()
    local W, H = Lm.W, Lm.H
    local showTabs = currentPage == "Shop"
    local titleH = Lm.titleH
    local barW = W - 16
    fit.Size = UDim2.fromOffset(W + Lm.extra, H)
    -- Without the tab column the window recenters itself.
    tween(group, 0.25, {Position = UDim2.new(0.5, (showTabs or not Lm.tabsSide) and 0 or Lm.extra / 2, 0.5, 0)})
    windowRim.Size = UDim2.fromOffset(W + 16, H + 16)
    window.Size = UDim2.fromOffset(W, H)
    titlebar.Size = UDim2.fromOffset(barW, titleH)
    title.Size = UDim2.fromOffset(380, titleH)
    close.Position = UDim2.fromOffset(barW - 8 - 27, titleH / 2)
    farHolder.Visible = barW >= 600

    -- shop tabs
    tabHolder.Visible = showTabs
    local gap = 8
    local slotW, slotH, iconSz, labelSize
    if Lm.tabsSide then slotW, slotH, iconSz, labelSize = TAB_W, 116, 76, 26
    else
        slotW = math.floor((W - 32 - gap * 2) / 3)
        slotH = Lm.tabRowH
        iconSz = slotH >= 80 and 50 or 34
        labelSize = 20
    end
    for i, name in ipairs(tabOrder) do
        local slot = tabSlots[name]
        local x = Lm.tabsSide and 0 or (i - 1) * (slotW + gap)
        local y = Lm.tabsSide and (i - 1) * (slotH + gap) or 0
        slot.Pos = Vector2.new(x, y)
        slot.Btn.Size = UDim2.fromOffset(slotW, slotH)
        slot.Btn.Position = UDim2.fromOffset(x + slotW / 2, y + slotH / 2)
        slot.Icon.Size = UDim2.fromOffset(iconSz, iconSz)
        slot.Icon.Position = UDim2.fromOffset(slotW / 2, 4 + iconSz / 2 + (Lm.tabsSide and 4 or 0))
        slot.Label.Size = UDim2.fromOffset(slotW, labelSize + 6)
        slot.Label.Position = UDim2.fromOffset(0, slotH - labelSize - (Lm.tabsSide and 14 or 8))
        slot.Label.TextSize = labelSize
    end
    tabPlate.Size = UDim2.fromOffset(slotW, slotH)
    local tabsY = 8 + titleH + 8
    if Lm.tabsSide then
        tabHolder.Size = UDim2.fromOffset(TAB_W, slotH * 3 + gap * 2)
        tabHolder.Position = UDim2.fromOffset(W + 14, tabsY + 4)
    else
        tabHolder.Size = UDim2.fromOffset(W - 32, slotH)
        tabHolder.Position = UDim2.fromOffset(16, tabsY)
    end
    selectTab(currentTab, true)

    -- content area
    local py = (showTabs and not Lm.tabsSide) and (tabsY + slotH + 8) or (8 + titleH + 14)
    pages.Position = UDim2.fromOffset(16, py)
    pages.Size = UDim2.fromOffset(bodyWidth + 20, H - py - 16 - Lm.hint)
    contentBack.Position = UDim2.fromOffset(10, py - 8)
    contentBack.Size = UDim2.fromOffset(W - 20, H - py - 2 - Lm.hint)
    hintBar.Position = UDim2.fromOffset(16, H - Lm.hint + 2)
    hintBar.Size = UDim2.fromOffset(W - 32, 28)
end

render = function()
    clearContent()
    layoutWindow()
    builtWidth = bodyWidth
    title.Text = currentPage
    title.TextSize = 58
    tween(title, 0.3, {TextSize = 50}, Enum.EasingStyle.Back)
    if currentPage == "Shop" then
        if currentTab == "Featured" then makeFeatured()
        elseif currentTab == "Speed" then makePacks(Config.SpeedPacks, "Speed", C.Cyan)
        else makePacks(Config.CreditPacks, "Credits", C.Gold) end
    elseif currentPage == "Index" then makeIndex()
    elseif currentPage == "Jetpacks" then makeJetpacks()
    else makeInventory(currentPage) end
    refreshPrices()
    if updateTimers then updateTimers() end
    -- Content rises into place.
    local base = pages.Position
    pages.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + 18)
    tween(pages, 0.32, {Position = base}, Enum.EasingStyle.Quart)
end

----------------------------------------------------------------------------
-- RESPONSIVE: phone / tablet / console / PC / Mac
----------------------------------------------------------------------------
resize = function()
    if root.AbsoluteSize.X < 1 or root.AbsoluteSize.Y < 1 then return end
    local m = computeMetrics()
    local layoutChanged = m.narrow ~= narrow or m.tabsSide ~= tabsSide
    Lm, narrow, tabsSide, bodyWidth = m, m.narrow, m.tabsSide, m.bodyWidth
    stage.Size = UDim2.fromOffset(m.LW, m.LH)
    stageScale.Scale = m.scale
    leftScale.Scale = m.hs
    rightScale.Scale = m.hs
    statScale.Scale = m.hs
    moonScale.Scale = m.hs
    launchScale.Scale = m.hs
    notice.Size = UDim2.fromOffset(math.min(580, m.LW - 28), 60)
    noticeText.TextSize = m.LW < 700 and 18 or 22
    updateHints()
    layoutWindow()
    fitScale.Scale = math.max(0.3, math.min(1, (m.LW - 8) / (m.W + m.extra), (m.LH - 8) / m.H))
    if windowOpen then hud.Visible = m.hudFits end
    if windowOpen and (layoutChanged or math.abs(m.bodyWidth - (builtWidth or 0)) > 6) then render() end
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resize() end)

----------------------------------------------------------------------------
-- OPEN / CLOSE  (spring pop, dimmed background, gamepad focus)
----------------------------------------------------------------------------
local closeToken = 0
openPage = function(page, tab)
    currentPage = page
    if tab then currentTab = tab end
    closeToken = closeToken + 1
    local wasOpen = windowOpen
    windowOpen = true
    fit.Visible = true
    scrim.Visible = true
    resize()
    if not wasOpen then
        pop.Scale = 0.8
        tween(pop, 0.38, {Scale = 1}, Enum.EasingStyle.Back)
        tween(scrim, 0.25, {BackgroundTransparency = 0.5})
        playSound("Open")
    end
    render()
    selectTab(currentTab, not wasOpen)
    if inputMode == "Gamepad" then
        task.defer(function()
            if not windowOpen then return end
            GuiService.SelectedObject = (currentPage == "Shop") and tabSlots[currentTab].Btn or close
        end)
    end
end
closeWindow = function()
    if not windowOpen then return end
    windowOpen = false
    closeToken = closeToken + 1
    local token = closeToken
    tween(pop, 0.16, {Scale = 0.85}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tween(scrim, 0.16, {BackgroundTransparency = 1})
    hud.Visible = true
    playSound("Close")
    if inputMode == "Gamepad" then GuiService.SelectedObject = nil end
    task.delay(0.18, function()
        if token == closeToken and not windowOpen then
            fit.Visible = false
            scrim.Visible = false
            clearContent() -- also stops this page's looping animations
        end
    end)
end
-- Clicking outside the window no longer closes it; players must press the X.
-- The scrim stays Active so outside clicks are swallowed instead of passing through to the game.

----------------------------------------------------------------------------
-- INPUT: keyboard (B), gamepad (Y open, B close, LB/RB tabs), touch
----------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    local code = input.KeyCode
    if code == Enum.KeyCode.ButtonB then
        if windowOpen then closeWindow() end
        return
    end
    if code == Enum.KeyCode.ButtonL1 or code == Enum.KeyCode.ButtonR1 then
        if windowOpen and currentPage == "Shop" then
            local dir = code == Enum.KeyCode.ButtonR1 and 1 or -1
            local index = table.find(tabOrder, currentTab) or 1
            currentTab = tabOrder[((index - 1 + dir) % #tabOrder) + 1]
            selectTab(currentTab, false)
            render()
        end
        return
    end
    if processed or UserInputService:GetFocusedTextBox() then return end
    if code == Enum.KeyCode.B or (Config.GamepadShopButton and code == Config.GamepadShopButton) then
        if windowOpen then closeWindow() else openPage("Shop", "Featured") end
    end
end)
UserInputService.LastInputTypeChanged:Connect(function(t)
    local mode
    if t == Enum.UserInputType.Touch then mode = "Touch"
    elseif t.Name:find("Gamepad") then mode = "Gamepad"
    elseif t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseMovement
        or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseWheel then mode = "Keyboard" end
    if mode and mode ~= inputMode then
        inputMode = mode
        if mode ~= "Gamepad" then GuiService.SelectedObject = nil end
        resize()
    end
end)

resize()

----------------------------------------------------------------------------
-- TIMERS (banner countdown + moon countdown)
-- Real times come from Config.FeaturedEndsAt (unix seconds) and a player
-- attribute (Config.NextEventAttribute, unix seconds). In Studio only,
-- Config.PreviewTimers = true shows demo values like the artwork.
----------------------------------------------------------------------------
local previewTimers = RunService:IsStudio() and Config.PreviewTimers == true
featuredEnd = Config.FeaturedEndsAt
if not featuredEnd and previewTimers then
    featuredEnd = os.time() + 10 * 86400 + 14 * 3600 + 51 * 60 + 44
end
local previewMoonEnd
updateTimers = function()
    local now = os.time()
    if bannerTimer and bannerTimer.Parent then
        if featuredEnd then
            local remaining = featuredEnd - now
            bannerTimer.Visible = true
            bannerTimer.Text = remaining > 0 and fmtDuration(remaining) or "Ended"
        else
            bannerTimer.Visible = false
        end
    end
    local target
    local attr = player:GetAttribute(Config.NextEventAttribute or "NextEventAt")
    if type(attr) == "number" then target = attr end
    if target == nil and previewTimers then
        if not previewMoonEnd or previewMoonEnd <= now then previewMoonEnd = now + 93 end
        target = previewMoonEnd
    end
    if target then
        moonPill.Visible = true
        local remaining = target - now
        moonText.Text = remaining > 0 and ("in " .. fmtDuration(remaining)) or "now!"
    else
        moonPill.Visible = false
    end
end
task.spawn(function()
    while gui.Parent do
        updateTimers()
        task.wait(0.25)
    end
end)

----------------------------------------------------------------------------
-- STATS (numbers pop when they change)
----------------------------------------------------------------------------
local function readStat(names)
    local leaderstats = player:FindFirstChild("leaderstats")
    for _, name in ipairs(names) do
        local stat = leaderstats and leaderstats:FindFirstChild(name)
        if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then return stat.Value end
        local attr = player:GetAttribute(name)
        if type(attr) == "number" then return attr end
    end
    return 0
end
local seenStat = {}
local function setStat(lbl, value)
    local text = formatNumber(value)
    local seen = seenStat[lbl]
    seenStat[lbl] = true
    if lbl.Text == text then return end
    lbl.Text = text
    if seen then
        lbl.TextSize = 44
        tween(lbl, 0.3, {TextSize = 36}, Enum.EasingStyle.Back)
    end
end
task.spawn(function()
    while gui.Parent do
        setStat(speedLabel, readStat(Config.SpeedStatNames))
        setStat(creditLabel, readStat(Config.CreditsStatNames))
        task.wait(0.4)
    end
end)

----------------------------------------------------------------------------
-- DATA (server-owned display folder) + PASS PURCHASE FEEDBACK
----------------------------------------------------------------------------
local dataConnections = {}
local refreshQueued = false
local function scheduleInventoryRefresh()
    if refreshQueued then return end
    refreshQueued = true
    task.defer(function()
        refreshQueued = false
        if windowOpen and currentPage ~= "Shop" then render() end
    end)
end
local function watchEntry(entry)
    if entry:IsA("StringValue") then
        table.insert(dataConnections, entry.Changed:Connect(scheduleInventoryRefresh))
        table.insert(dataConnections, entry.AttributeChanged:Connect(scheduleInventoryRefresh))
    end
end
local function bindData()
    for _, conn in ipairs(dataConnections) do conn:Disconnect() end
    dataConnections = {}
    local data = player:FindFirstChild(Config.DataFolderName)
    if not data then return end
    for _, entry in ipairs(data:GetDescendants()) do watchEntry(entry) end
    table.insert(dataConnections, data.DescendantAdded:Connect(function(entry)
        watchEntry(entry) scheduleInventoryRefresh()
    end))
    table.insert(dataConnections, data.DescendantRemoving:Connect(scheduleInventoryRefresh))
    scheduleInventoryRefresh()
end
player.ChildAdded:Connect(function(child)
    if child.Name == Config.DataFolderName then bindData() end
end)
player.ChildRemoved:Connect(function(child)
    if child.Name == Config.DataFolderName then bindData() scheduleInventoryRefresh() end
end)
bindData()
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id, bought)
    if who ~= player or not bought then return end
    -- Update UI only. The server must verify and apply the pass benefit.
    for _, item in ipairs(Config.Passes) do
        if item.ProductId == id then
            local info = productCache[item.Key]
            if info then info.Owned = true end
        end
    end
    refreshPrices()
end)

----------------------------------------------------------------------------
-- INTRO: HUD slides in once when the game loads
----------------------------------------------------------------------------
local function slideIn(obj, fromPos, delay)
    local target = obj.Position
    obj.Position = fromPos
    task.delay(delay, function()
        if obj.Parent then tween(obj, 0.6, {Position = target}, Enum.EasingStyle.Back) end
    end)
end
slideIn(left, UDim2.new(0, -260, 0.47, 0), 0.1)
slideIn(right, UDim2.new(1, 200, 0.47, 0), 0.2)
slideIn(stats, UDim2.new(0, 14, 1, 240), 0.3)
slideIn(launchBar, UDim2.new(0.5, 0, 1, 240), 0.4)

if Config.OpenShopOnJoin then openPage("Shop", "Featured") end

----------------------------------------------------------------------------
-- JETPACKS: LAUNCH + Base buttons, launch keys, and keeping the Jetpacks page up to date
----------------------------------------------------------------------------
local launchMessages = {
    nopad = "Stand on your launch pad to launch! Press the rocket button to go there.",
    ceiling = "You're as high as this jetpack can go. Buy a better one to reach the next planet!",
    nocharacter = "You can't launch right now.",
}
launchJetpack = function()
    local ok, reason = Flight.Launch()
    if ok then playSound("Open") return end
    if launchMessages[reason] then toast(launchMessages[reason]) end
end

local teleportBusy = false
teleportToBase = function()
    if teleportBusy then return end
    local remote = jetpackFolder:FindFirstChild("TeleportToLaunchSite")
    if not remote then toast("Jetpacks are still loading, try again in a moment.") return end
    teleportBusy = true
    Flight.Cancel()
    local ok, success, message = pcall(remote.InvokeServer, remote)
    teleportBusy = false
    if not ok then toast("Something went wrong, try again.")
    elseif not success and message then toast(message) end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    local code = input.KeyCode
    if code == JetpackConfig.LaunchKey or code == JetpackConfig.LaunchGamepadButton then
        launchJetpack()
    elseif code == JetpackConfig.TeleportKey or code == JetpackConfig.TeleportGamepadButton then
        teleportToBase()
    end
end)

-- The LAUNCH button shows the cooldown and "FLYING", and glows while you're on a launch pad.
task.spawn(function()
    while gui.Parent do
        local state, cooldown = Flight.Status()
        local text
        if state == "Thrust" then text = "FLYING"
        elseif cooldown > 0 then text = string.format("%.1fs", cooldown)
        else text = "LAUNCH" end
        if launchLabel.Text ~= text then launchLabel.Text = text end
        launchGlow.Visible = state ~= "Thrust" and cooldown <= 0 and Flight.OnLaunchPad()
        task.wait(0.1)
    end
end)

-- Rebuild the Jetpacks page when coins, the equipped jetpack or the owned jetpacks change.
local jetpackRefreshQueued = false
local function refreshJetpacks()
    if jetpackRefreshQueued then return end
    jetpackRefreshQueued = true
    task.delay(0.2, function()
        jetpackRefreshQueued = false
        if windowOpen and currentPage == "Jetpacks" then
            local scroll = pages.CanvasPosition
            render()
            pages.CanvasPosition = scroll
        end
    end)
end
player:GetAttributeChangedSignal(JetpackConfig.CurrencyAttribute):Connect(refreshJetpacks)
player:GetAttributeChangedSignal(JetpackConfig.EquippedAttribute):Connect(refreshJetpacks)
local function watchOwned(folder)
    folder.ChildAdded:Connect(refreshJetpacks)
    folder.ChildRemoved:Connect(refreshJetpacks)
    refreshJetpacks()
end
local owned = player:FindFirstChild(JetpackConfig.OwnedFolder)
if owned then watchOwned(owned) end
player.ChildAdded:Connect(function(child)
    if child.Name == JetpackConfig.OwnedFolder then watchOwned(child) end
end)


----------------------------------------------------------------------------
-- HATCH HOOKUP: your server fires ("Hatched", petId); Studio preview key too.
----------------------------------------------------------------------------
task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild(Config.ActionRemoteName, 30)
    if remote and remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(function(action, value)
            if action == "Hatched" then showHatch(value) end
        end)
    end
end)
if RunService:IsStudio() and Config.PreviewHatchKey then
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or input.KeyCode ~= Config.PreviewHatchKey then return end
        local pet = Config.Pets[math.random(1, #Config.Pets)]
        if pet then showHatch(pet.Id) end
    end)
end
