-- SpaceIcons (ModuleScript) - every icon in the GUI, drawn from Frames only
-- (UICorner + UIGradient + UIStroke). No images, no asset IDs.
-- Put it inside the SpaceGUI ScreenGui next to SpaceGUIController.
--
--   Icons.new(name, parent, size) -> Frame (square, size x size pixels)
--   names: Cart Book Star Rocket Coins Egg Helmet Potion Clock Moon Robux Gift Plus Check Jetpack Pen

local Icons = {}
local INK = Color3.fromRGB(3, 8, 30)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local WHITE = rgb(255, 255, 255)

local builders = {}

-- 8-point star: two rounded squares, dark outline layer underneath the fill layer.
local function star8(S, pxs, cx, cy, w, c1, c2, p)
    local o = w + pxs * 2.8
    S(cx, cy, o, o, INK, nil, {r = 0.16, ink = false, p = p})
    S(cx, cy, o, o, INK, nil, {r = 0.16, ink = false, rot = 45, p = p})
    S(cx, cy, w, w, c1, c2, {r = 0.14, ink = false, p = p})
    S(cx, cy, w, w, c1, c2, {r = 0.14, ink = false, rot = 45, p = p})
end
-- 4-point sparkle: two thin pills.
local function spark4(S, cx, cy, s, color, p)
    S(cx, cy, s, s * 0.22, color, nil, {ink = false, p = p})
    S(cx, cy, s * 0.22, s, color, nil, {ink = false, p = p})
end

builders.Cart = function(S)
    S(0.24, 0.27, 0.32, 0.085, WHITE, rgb(210, 220, 250), {rot = 32})
    S(0.6, 0.47, 0.62, 0.36, rgb(255, 125, 235), rgb(204, 50, 226), {rot = -5, r = 0.16})
    for _, x in ipairs({0.46, 0.62, 0.78}) do
        S(x, 0.47, 0.045, 0.25, rgb(140, 20, 165), nil, {rot = -5, ink = false, t = 0.4})
    end
    S(0.58, 0.72, 0.56, 0.07, WHITE, rgb(210, 220, 250), {})
    S(0.4, 0.87, 0.15, 0.15, WHITE, rgb(190, 200, 235), {})
    S(0.76, 0.87, 0.15, 0.15, WHITE, rgb(190, 200, 235), {})
end

builders.Book = function(S, _, pxs)
    S(0.56, 0.54, 0.62, 0.8, rgb(252, 246, 226), rgb(225, 215, 190), {r = 0.1})
    S(0.5, 0.5, 0.64, 0.82, rgb(70, 160, 255), rgb(20, 70, 200), {r = 0.1})
    S(0.24, 0.5, 0.1, 0.82, rgb(15, 50, 150), nil, {r = 0.3, ink = false, t = 0.15})
    star8(S, pxs, 0.56, 0.48, 0.24, rgb(255, 240, 130), rgb(255, 180, 40))
    spark4(S, 0.72, 0.72, 0.16, rgb(200, 235, 255))
end

builders.Star = function(S, _, pxs)
    star8(S, pxs, 0.5, 0.5, 0.5, rgb(255, 238, 120), rgb(255, 170, 30))
    S(0.5, 0.5, 0.26, 0.26, rgb(255, 252, 210), nil, {ink = false, t = 0.2, z = 2})
    S(0.5, 0.5, 0.98, 0.38, nil, nil, {fill = false, sc = rgb(190, 130, 255), sw = 1.6, rot = -25, z = 3})
end

builders.Rocket = function(S)
    local h = S(0.5, 0.5, 1, 1, nil, nil, {fill = false, ink = false, rot = 40})
    S(0.5, 0.9, 0.2, 0.3, rgb(255, 235, 100), rgb(255, 110, 30), {p = h, ink = false})
    S(0.5, 0.85, 0.1, 0.16, rgb(255, 255, 225), nil, {p = h, ink = false})
    S(0.3, 0.68, 0.2, 0.3, rgb(255, 100, 100), rgb(190, 30, 50), {p = h, rot = 18, r = 0.35})
    S(0.7, 0.68, 0.2, 0.3, rgb(255, 100, 100), rgb(190, 30, 50), {p = h, rot = -18, r = 0.35})
    S(0.5, 0.5, 0.34, 0.66, WHITE, rgb(185, 200, 232), {p = h})
    S(0.5, 0.2, 0.28, 0.26, rgb(255, 110, 110), rgb(200, 30, 55), {p = h})
    S(0.5, 0.46, 0.18, 0.18, rgb(130, 240, 255), rgb(20, 130, 230), {p = h})
    S(0.47, 0.42, 0.05, 0.05, WHITE, nil, {p = h, ink = false, t = 0.2})
end

builders.Coins = function(S, _, pxs)
    local function coin(cx, cy, d)
        S(cx, cy, d, d, rgb(255, 236, 100), rgb(238, 150, 20), {})
        S(cx, cy, d * 0.7, d * 0.7, rgb(255, 210, 55), rgb(255, 240, 120),
            {sc = rgb(190, 110, 10), sw = 0.7})
        star8(S, pxs * 0.6, cx, cy, d * 0.3, rgb(255, 250, 200), rgb(255, 200, 60))
    end
    coin(0.7, 0.66, 0.44)
    coin(0.3, 0.68, 0.46)
    coin(0.5, 0.38, 0.6)
end

builders.Egg = function(S)
    S(0.5, 0.54, 0.62, 0.8, rgb(170, 100, 255), rgb(38, 30, 140), {})
    S(0.4, 0.34, 0.14, 0.22, WHITE, nil, {rot = 18, ink = false, t = 0.55})
    S(0.6, 0.58, 0.08, 0.08, rgb(255, 225, 100), nil, {ink = false})
    S(0.42, 0.68, 0.06, 0.06, rgb(255, 140, 220), nil, {ink = false})
    S(0.62, 0.4, 0.05, 0.05, rgb(120, 235, 255), nil, {ink = false})
    S(0.5, 0.56, 0.62, 0.07, rgb(255, 215, 90), nil, {ink = false, t = 0.1, r = 0.4})
end

builders.Helmet = function(S)
    S(0.5, 0.5, 0.9, 0.9, WHITE, rgb(175, 190, 225), {})
    S(0.5, 0.5, 0.66, 0.56, rgb(30, 60, 160), rgb(8, 18, 80), {r = 0.42, sc = rgb(120, 170, 255), sw = 0.6})
    S(0.5, 0.56, 0.18, 0.14, rgb(235, 248, 255), nil, {ink = false})
    for _, p in ipairs({{0.36, 0.44}, {0.46, 0.38}, {0.56, 0.38}, {0.65, 0.44}}) do
        S(p[1], p[2], 0.08, 0.1, rgb(235, 248, 255), nil, {ink = false})
    end
    S(0.34, 0.32, 0.16, 0.06, WHITE, nil, {rot = -30, ink = false, t = 0.4})
end

builders.Potion = function(S)
    S(0.5, 0.14, 0.26, 0.11, rgb(190, 120, 60), rgb(130, 70, 30), {r = 0.3})
    S(0.5, 0.3, 0.2, 0.3, rgb(215, 240, 255), rgb(160, 205, 245), {r = 0.2})
    S(0.5, 0.65, 0.66, 0.62, rgb(215, 240, 255), rgb(160, 205, 245), {})
    S(0.5, 0.7, 0.5, 0.44, rgb(60, 225, 255), rgb(10, 120, 235), {ink = false})
    S(0.4, 0.62, 0.07, 0.07, WHITE, nil, {ink = false, t = 0.2})
    S(0.6, 0.72, 0.05, 0.05, WHITE, nil, {ink = false, t = 0.3})
    S(0.35, 0.5, 0.08, 0.18, WHITE, nil, {rot = 20, ink = false, t = 0.45})
end

-- Two blue fuel tanks on a white backplate, with red caps, a glowing core and exhaust flames.
builders.Jetpack = function(S)
    for _, x in ipairs({0.31, 0.69}) do
        S(x, 0.9, 0.15, 0.2, rgb(255, 235, 100), rgb(255, 110, 30), {ink = false, rot = 180})
        S(x, 0.87, 0.07, 0.11, rgb(255, 255, 225), nil, {ink = false})
        S(x, 0.77, 0.17, 0.09, rgb(120, 130, 160), rgb(60, 66, 92), {r = 0.25})
    end
    S(0.5, 0.46, 0.3, 0.64, WHITE, rgb(185, 200, 232), {r = 0.22})
    for _, x in ipairs({0.31, 0.69}) do
        S(x, 0.47, 0.25, 0.58, rgb(110, 185, 255), rgb(25, 85, 215), {r = 0.45})
        S(x, 0.19, 0.19, 0.09, rgb(255, 110, 110), rgb(200, 30, 55), {r = 0.4})
        S(x - 0.05, 0.44, 0.05, 0.28, WHITE, nil, {ink = false, t = 0.5})
    end
    S(0.5, 0.36, 0.14, 0.14, rgb(130, 240, 255), rgb(20, 130, 230), {})
    S(0.5, 0.6, 0.2, 0.07, rgb(255, 215, 90), rgb(230, 140, 20), {r = 0.3})
end

-- The pet pen: a wooden fence on a patch of grass, with a big paw print in front
builders.Pen = function(S)
    local wood1, wood2 = rgb(240, 185, 110), rgb(175, 105, 45)
    S(0.5, 0.82, 0.96, 0.3, rgb(130, 235, 110), rgb(45, 160, 75), {})
    for _, x in ipairs({0.13, 0.37, 0.63, 0.87}) do
        S(x, 0.5, 0.13, 0.62, wood1, wood2, {r = 0.35})
    end
    S(0.5, 0.36, 0.9, 0.1, wood1, wood2, {r = 0.3})
    S(0.5, 0.6, 0.9, 0.1, wood1, wood2, {r = 0.3})
    -- paw print
    S(0.5, 0.71, 0.34, 0.27, WHITE, rgb(215, 222, 245), {})
    for _, toe in ipairs({{0.31, 0.53}, {0.42, 0.44}, {0.58, 0.44}, {0.69, 0.53}}) do
        S(toe[1], toe[2], 0.12, 0.14, WHITE, rgb(215, 222, 245), {})
    end
end

builders.Clock = function(S)
    S(0.5, 0.1, 0.16, 0.13, rgb(255, 215, 80), rgb(230, 140, 20), {r = 0.3})
    S(0.5, 0.56, 0.7, 0.7, WHITE, rgb(190, 205, 240), {})
    S(0.5, 0.56, 0.56, 0.56, rgb(245, 250, 255), rgb(210, 225, 250), {ink = false})
    S(0.5, 0.47, 0.055, 0.24, rgb(40, 50, 120), nil, {ink = false})
    S(0.58, 0.58, 0.2, 0.055, rgb(40, 50, 120), nil, {ink = false, rot = 20})
    S(0.5, 0.56, 0.09, 0.09, rgb(255, 140, 60), nil, {})
    S(0.5, 0.56, 0.98, 0.4, nil, nil, {fill = false, sc = rgb(60, 200, 255), sw = 1.7, rot = -25, z = 3})
end

builders.Moon = function(S)
    S(0.5, 0.5, 0.9, 0.9, rgb(240, 242, 252), rgb(150, 156, 195), {})
    S(0.36, 0.36, 0.2, 0.2, rgb(120, 126, 168), nil, {ink = false, t = 0.15})
    S(0.66, 0.5, 0.26, 0.26, rgb(120, 126, 168), nil, {ink = false, t = 0.15})
    S(0.42, 0.7, 0.16, 0.16, rgb(120, 126, 168), nil, {ink = false, t = 0.15})
    S(0.68, 0.74, 0.09, 0.09, rgb(120, 126, 168), nil, {ink = false, t = 0.15})
end

builders.Robux = function(S)
    S(0.5, 0.5, 0.86, 0.86, WHITE, rgb(215, 224, 240), {r = 0.22})
    S(0.5, 0.5, 0.86, 0.86, WHITE, rgb(215, 224, 240), {r = 0.22, rot = 30})
    S(0.5, 0.5, 0.5, 0.5, rgb(225, 232, 246), nil, {sc = INK, sw = 1})
    S(0.5, 0.5, 0.22, 0.22, INK, nil, {ink = false})
end

builders.Gift = function(S)
    S(0.5, 0.66, 0.66, 0.46, WHITE, rgb(215, 222, 245), {r = 0.1})
    S(0.5, 0.42, 0.76, 0.22, WHITE, rgb(225, 230, 250), {r = 0.14})
    S(0.5, 0.6, 0.14, 0.62, rgb(255, 225, 70), rgb(240, 150, 20), {r = 0.1})
    S(0.4, 0.22, 0.24, 0.15, rgb(255, 225, 70), rgb(240, 150, 20), {rot = -28})
    S(0.6, 0.22, 0.24, 0.15, rgb(255, 225, 70), rgb(240, 150, 20), {rot = 28})
    S(0.5, 0.28, 0.13, 0.13, rgb(255, 200, 50), nil, {})
end

builders.Plus = function(S)
    S(0.5, 0.5, 0.7, 0.2, INK, nil, {r = 0.4, ink = false})
    S(0.5, 0.5, 0.2, 0.7, INK, nil, {r = 0.4, ink = false})
end

builders.Check = function(S)
    S(0.36, 0.6, 0.22, 0.52, rgb(80, 235, 130), rgb(30, 180, 90), {rot = -40, r = 0.4})
    S(0.6, 0.5, 0.22, 0.8, rgb(80, 235, 130), rgb(30, 180, 90), {rot = 40, r = 0.4})
end

function Icons.new(name, parent, size)
    local build = builders[name] or builders.Star
    local box = Instance.new("Frame")
    box.Name = name .. "Icon"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Size = UDim2.fromOffset(size, size)
    local px = math.max(1.5, size * 0.05)
    local pxs = px / size

    -- S(cx, cy, w, h, color1, color2, opts): one shape, all sizes as 0..1 fractions.
    local function S(cx, cy, w, h, c1, c2, o)
        o = o or {}
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(cx, cy)
        f.Size = UDim2.fromScale(w, h)
        f.BorderSizePixel = 0
        f.Rotation = o.rot or 0
        f.ZIndex = o.z or 1
        if o.fill == false then
            f.BackgroundTransparency = 1
        else
            f.BackgroundTransparency = o.t or 0
            f.BackgroundColor3 = c2 and WHITE or c1
        end
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(o.r or 0.5, 0)
        corner.Parent = f
        if c2 and o.fill ~= false then
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new(c1, c2)
            g.Rotation = o.grot or 90
            g.Parent = f
        end
        local strokeColor = o.sc or (o.ink ~= false and INK or nil)
        if strokeColor then
            local s = Instance.new("UIStroke")
            s.Color = strokeColor
            s.Thickness = (o.sw or 1) * px
            s.LineJoinMode = Enum.LineJoinMode.Round
            s.Parent = f
        end
        f.Parent = o.p or box
        return f
    end

    build(S, box, pxs)
    box.Parent = parent
    return box
end

return Icons
