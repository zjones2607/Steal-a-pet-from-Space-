-- SpaceModels (ModuleScript) - custom 3D eggs and pets, built entirely from Parts.
-- Put it inside the SpaceGUI ScreenGui next to SpaceGUIController.
-- No meshes or images are used: spheres are Parts with a SpecialMesh(Sphere),
-- so every model works offline and can be re-used in your world/hatching code.
--
--   Models.Pet(id)                  -> Model (faces +Z, centered on the origin)
--   Models.Egg(count)               -> Model (1 egg, or a small pile of eggs)
--   Models.View(parent, model, {Size=,Position=,Aspect=,Yaw=,Tint=,ZIndex=})
--                                   -> ViewportFrame, controller{Spin(on, mode), Destroy()}
--
-- Row format for the pet data below:
--   {kind, x,y,z, sizeX,sizeY,sizeZ, r,g,b, material, [rotX,rotY,rotZ], [transparency]}
--   kind: "b" ball/ellipsoid, "k" block, "c" upright cylinder (size = dia, length, dia)
--   a trailing "m" on the kind (e.g. "bm") also adds the mirrored copy at -x.
--   material: S smooth, N neon, G glass, L slate, M metal

local RunService = game:GetService("RunService")

local Models = {}
local v3 = Vector3.new
local ZERO = v3(0, 0, 0)
local MAT = {
    S = Enum.Material.SmoothPlastic, N = Enum.Material.Neon, G = Enum.Material.Glass,
    L = Enum.Material.Slate, M = Enum.Material.Metal,
}

----------------------------------------------------------------------------
-- PART FACTORY
----------------------------------------------------------------------------
local function makePart(kind, pos, size, color, mat, rot, tr)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = MAT[mat] or Enum.Material.SmoothPlastic
    p.Color = color
    p.Transparency = tr or 0
    local cf = CFrame.new(pos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
    if kind == "c" then
        p.Shape = Enum.PartType.Cylinder
        p.Size = v3(math.max(size.Y, 0.05), math.max(size.X, 0.05), math.max(size.X, 0.05))
        cf = cf * CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis is X; stand it up
    else
        p.Size = v3(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
        if kind == "b" then
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.Sphere
            mesh.Parent = p
        end
    end
    p.CFrame = cf
    return p
end

local function addRows(model, rows)
    for _, r in ipairs(rows) do
        local kind = r[1]
        local mirror = kind:sub(-1) == "m"
        if mirror then kind = kind:sub(1, -2) end
        local pos = v3(r[2], r[3], r[4])
        local size = v3(r[5], r[6], r[7])
        local color = Color3.fromRGB(r[8], r[9], r[10])
        local rot = v3(r[12] or 0, r[13] or 0, r[14] or 0)
        makePart(kind, pos, size, color, r[11], rot, r[15]).Parent = model
        if mirror then
            makePart(kind, v3(-pos.X, pos.Y, pos.Z), size, color, r[11], v3(rot.X, -rot.Y, -rot.Z), r[15]).Parent = model
        end
    end
end

-- Re-centers the model so its bounding box center sits on the origin.
local function finish(model)
    local cf = model:GetBoundingBox()
    model.WorldPivot = CFrame.new(cf.Position)
    model:PivotTo(CFrame.new())
    return model
end

----------------------------------------------------------------------------
-- PET DATA  (chunky, cute, front = +Z)
----------------------------------------------------------------------------
local PETS = {}

PETS.astro_dog = {
    {"b", 0,-1.05,0, 2.0,1.7,1.6, 245,247,255, "S"},                     -- suit body
    {"b", 0,-0.95,0.72, 0.8,0.5,0.25, 60,200,255, "N"},                  -- chest light
    {"bm", 0.5,-1.95,0.15, 0.8,0.75,1.0, 235,238,250, "S"},              -- legs
    {"bm", 0.5,-2.25,0.4, 0.85,0.4,1.1, 90,110,170, "S"},                -- boots
    {"bm", 1.25,-0.9,0.1, 0.7,1.3,0.7, 245,247,255, "S", 0,0,12},        -- arms
    {"bm", 1.32,-1.5,0.15, 0.6,0.55,0.6, 90,110,170, "S"},               -- gloves
    {"k", 0,-0.9,-1.05, 1.3,1.5,0.6, 120,135,175, "M"},                  -- backpack
    {"b", 0.35,-0.6,-1.38, 0.25,0.25,0.1, 60,255,200, "N"},              -- pack light
    {"c", 0,-0.12,0, 2.7,0.35,2.7, 200,210,235, "M"},                    -- collar ring
    {"b", 0,0.85,0, 2.5,2.2,2.3, 214,150,84, "S"},                       -- head
    {"b", 0,0.6,0.8, 1.6,1.5,1.0, 255,244,230, "S"},                     -- face blaze
    {"b", 0,0.4,1.05, 1.1,0.85,0.8, 255,246,236, "S"},                   -- muzzle
    {"b", 0,0.62,1.42, 0.42,0.3,0.28, 30,25,35, "S"},                    -- nose
    {"b", 0,0.08,1.28, 0.3,0.2,0.25, 255,120,140, "S"},                  -- tongue
    {"bm", 0.62,1.05,1.0, 0.34,0.48,0.25, 25,20,35, "S"},                -- eyes
    {"bm", 0.56,1.2,1.13, 0.13,0.15,0.1, 255,255,255, "S"},              -- eye shine
    {"bm", 0.95,1.95,0.05, 0.85,1.1,0.5, 214,150,84, "S", 0,0,-18},      -- ears
    {"bm", 0.95,1.9,0.26, 0.45,0.7,0.25, 255,190,190, "S", 0,0,-18},
    {"b", 0,0.85,0.05, 3.5,3.3,3.3, 160,215,255, "G", 0,0,0, 0.7},      -- glass helmet
}

PETS.moon_cat = {
    {"b", 0,-1.0,0, 1.9,1.7,1.6, 150,165,205, "S"},
    {"b", 0,-1.05,0.55, 1.2,1.2,0.8, 235,238,250, "S"},
    {"bm", 0.5,-1.85,0.35, 0.75,0.6,0.95, 235,238,250, "S"},
    {"bm", 1.1,-0.95,0.2, 0.6,1.1,0.6, 150,165,205, "S", 0,0,10},
    {"bm", 1.15,-1.5,0.3, 0.55,0.45,0.55, 235,238,250, "S"},
    {"b", 0,0.7,0, 2.8,2.3,2.4, 150,165,205, "S"},                       -- head
    {"bm", 0.95,2.0,0, 0.95,1.3,0.5, 150,165,205, "S", 0,0,-20},         -- ears
    {"bm", 0.95,1.95,0.2, 0.5,0.8,0.25, 255,170,200, "S", 0,0,-20},
    {"bm", 0.68,0.85,1.0, 0.62,0.75,0.35, 30,30,80, "S"},                -- eyes
    {"bm", 0.68,0.85,1.13, 0.42,0.55,0.2, 130,220,255, "N"},
    {"bm", 0.58,1.02,1.28, 0.16,0.2,0.1, 255,255,255, "S"},
    {"b", 0,0.4,1.16, 0.25,0.18,0.18, 255,150,180, "S"},                 -- nose
    {"bm", 0.12,0.2,1.14, 0.2,0.1,0.1, 90,80,120, "S"},                  -- smile
    {"bm", 1.05,0.35,1.0, 0.9,0.05,0.05, 235,240,255, "S", 0,10,-6},     -- whiskers
    {"bm", 1.05,0.22,1.0, 0.9,0.05,0.05, 235,240,255, "S", 0,10,8},
    {"b", 0,1.5,0.92, 0.8,0.8,0.22, 255,245,180, "N"},                   -- crescent
    {"b", 0.17,1.55,1.02, 0.7,0.7,0.24, 150,165,205, "S"},
    {"b", 1.0,-1.45,-0.9, 0.6,0.55,0.6, 150,165,205, "S"},               -- tail
    {"b", 1.5,-1.2,-0.8, 0.55,0.5,0.55, 150,165,205, "S"},
    {"b", 1.85,-0.8,-0.7, 0.5,0.5,0.5, 150,165,205, "S"},
    {"b", 1.9,-0.4,-0.65, 0.45,0.5,0.45, 235,238,250, "S"},
}

PETS.alien_bunny = {
    {"b", 0,-1.0,0, 1.8,1.7,1.5, 110,225,100, "S"},
    {"b", 0,-1.05,0.5, 1.1,1.1,0.7, 205,255,190, "S"},
    {"bm", 0.5,-1.85,0.4, 0.8,0.5,1.0, 110,225,100, "S"},
    {"bm", 1.05,-0.9,0.15, 0.55,1.0,0.55, 110,225,100, "S", 0,0,10},
    {"b", 0,0.7,0, 2.6,2.3,2.3, 120,235,105, "S"},                       -- head
    {"bm", 0.7,2.6,-0.05, 0.75,2.6,0.45, 120,235,105, "S", 0,0,-8},      -- ears
    {"bm", 0.7,2.6,0.14, 0.4,2.0,0.25, 255,150,225, "S", 0,0,-8},
    {"bm", 0.7,0.85,0.9, 0.85,1.15,0.45, 15,15,30, "S", 0,0,-18},        -- big alien eyes
    {"bm", 0.6,1.15,1.1, 0.22,0.3,0.12, 255,255,255, "S"},
    {"bm", 0.85,0.6,1.08, 0.12,0.12,0.08, 255,255,255, "S"},
    {"b", 0,0.4,1.12, 0.22,0.16,0.14, 255,120,190, "S"},
    {"b", 0,0.18,1.05, 0.4,0.1,0.1, 40,110,40, "S"},
    {"c", 0,2.05,0.3, 0.09,0.9,0.09, 60,160,60, "S", -20,0,0},           -- antenna
    {"b", 0,2.55,0.6, 0.42,0.42,0.42, 255,80,220, "N"},
    {"b", 0,-1.3,-0.95, 0.75,0.75,0.75, 255,255,255, "S"},               -- tail
}

PETS.comet_fox = {
    {"b", 0,-1.0,0, 1.8,1.7,1.7, 255,140,40, "S"},
    {"b", 0,-1.0,0.55, 1.1,1.2,0.7, 255,240,215, "S"},
    {"bm", 0.5,-1.85,0.3, 0.7,0.6,0.9, 90,50,40, "S"},
    {"bm", 1.05,-0.9,0.2, 0.55,1.0,0.55, 255,140,40, "S", 0,0,10},
    {"bm", 1.1,-1.4,0.25, 0.5,0.4,0.5, 90,50,40, "S"},
    {"b", 0,0.7,0, 2.7,2.2,2.3, 255,140,40, "S"},                        -- head
    {"bm", 0.95,0.3,0.55, 1.0,0.9,0.9, 255,240,215, "S"},               -- cheek fluff
    {"b", 0,0.35,1.02, 1.0,0.8,0.8, 255,240,215, "S"},
    {"b", 0,0.55,1.4, 0.3,0.22,0.22, 30,20,25, "S"},
    {"bm", 0.6,0.95,0.98, 0.36,0.5,0.28, 30,20,25, "S"},
    {"bm", 0.54,1.1,1.1, 0.13,0.16,0.1, 255,255,255, "S"},
    {"bm", 0.9,2.0,0, 0.85,1.4,0.5, 255,140,40, "S", 0,0,-22},           -- ears
    {"bm", 0.9,1.95,0.2, 0.5,0.9,0.25, 90,50,40, "S", 0,0,-22},
    {"bm", 1.08,2.55,0, 0.3,0.5,0.3, 255,220,80, "N", 0,0,-22},         -- ear flames
    {"b", 1.0,-1.2,-0.9, 1.3,1.2,1.4, 255,120,30, "S"},                  -- flame tail
    {"b", 1.5,-0.55,-1.0, 1.25,1.4,1.2, 255,140,30, "N"},
    {"b", 1.75,0.3,-1.05, 1.05,1.3,1.0, 255,190,50, "N"},
    {"b", 1.75,1.1,-1.05, 0.75,1.0,0.75, 255,235,120, "N"},
    {"b", 1.65,1.7,-1.0, 0.42,0.6,0.42, 255,255,220, "N"},
    {"b", 2.5,0.6,-0.6, 0.18,0.18,0.18, 255,220,90, "N"},               -- embers
    {"b", 1.1,2.1,-0.7, 0.15,0.15,0.15, 255,180,60, "N"},
}

PETS.robot_bear = {
    {"b", 0,-1.0,0, 2.0,1.8,1.7, 240,244,255, "S"},
    {"b", 0,-0.85,0.7, 0.9,0.7,0.3, 30,50,110, "S"},
    {"b", 0,-0.85,0.82, 0.42,0.42,0.2, 80,230,255, "N"},                 -- chest core
    {"bm", 0.55,-1.95,0.2, 0.85,0.8,1.0, 200,210,235, "S"},
    {"bm", 0.55,-2.25,0.4, 0.95,0.4,1.2, 90,110,160, "S"},
    {"bm", 1.25,-0.9,0.1, 0.7,1.3,0.7, 240,244,255, "S", 0,0,10},
    {"bm", 1.3,-1.55,0.15, 0.65,0.55,0.65, 90,110,160, "S"},
    {"c", 0,-0.02,0, 0.9,0.3,0.9, 140,155,195, "M"},
    {"b", 0,0.85,0, 2.8,2.4,2.4, 240,244,255, "S"},                      -- head
    {"b", 0,0.8,0.95, 2.1,1.5,0.5, 20,35,90, "S"},                       -- face screen
    {"bm", 0.5,0.95,1.16, 0.42,0.55,0.15, 80,235,255, "N"},             -- eyes
    {"b", 0,0.5,1.16, 0.7,0.14,0.12, 80,235,255, "N"},                   -- smile
    {"bm", 1.25,1.75,0, 0.95,0.95,0.7, 240,244,255, "S"},                -- ears
    {"bm", 1.25,1.75,0.3, 0.55,0.55,0.4, 110,130,180, "S"},
    {"c", 0,2.2,0, 0.1,0.7,0.1, 140,155,195, "M"},                       -- antenna
    {"b", 0,2.65,0, 0.36,0.36,0.36, 255,90,120, "N"},
    {"bm", 1.38,0.9,0.4, 0.2,0.2,0.2, 140,155,195, "M"},                 -- bolts
}

PETS.star_dragon = {
    {"b", 0,-0.9,-0.1, 2.0,1.9,2.3, 42,54,140, "S"},
    {"b", 0,-1.0,0.6, 1.2,1.5,0.9, 255,215,110, "S"},                    -- gold belly
    {"bm", 0.65,-1.85,0.25, 0.8,0.7,1.0, 42,54,140, "S"},
    {"bm", 0.65,-2.15,0.6, 0.6,0.25,0.5, 255,215,110, "S"},
    {"bm", 1.15,-0.9,0.3, 0.6,1.0,0.6, 42,54,140, "S", 0,0,12},
    {"b", 0,0.95,0.55, 2.5,2.1,2.3, 46,60,150, "S"},                     -- head
    {"b", 0,0.6,1.7, 1.3,0.9,1.0, 56,72,170, "S"},                       -- snout
    {"bm", 0.25,0.75,2.12, 0.14,0.14,0.1, 15,15,40, "S"},
    {"bm", 0.7,1.15,1.35, 0.5,0.55,0.3, 255,235,120, "N"},              -- glowing eyes
    {"bm", 0.7,1.15,1.52, 0.16,0.42,0.12, 20,15,40, "S"},
    {"bm", 0.7,2.1,0.35, 0.35,1.1,0.35, 255,215,110, "S", -35,0,-15},   -- horns
    {"b", 0,2.05,0.25, 0.35,0.35,0.35, 255,215,110, "S"},
    {"b", 0,1.85,-0.35, 0.3,0.3,0.3, 255,215,110, "S"},
    {"bm", 1.75,0.45,-0.6, 2.1,1.5,0.18, 100,70,205, "S", 0,-25,25},    -- wings
    {"bm", 2.0,0.8,-0.58, 1.3,0.9,0.12, 140,110,240, "S", 0,-25,25},
    {"bm", 1.75,0.5,-0.45, 0.28,0.28,0.15, 255,235,120, "N"},
    {"b", 0.6,-1.4,-1.3, 1.2,1.0,1.2, 42,54,140, "S"},                   -- tail
    {"b", 1.15,-1.2,-1.75, 0.9,0.8,0.95, 42,54,140, "S"},
    {"b", 1.65,-0.85,-1.95, 0.7,0.65,0.75, 42,54,140, "S"},
    {"b", 1.95,-0.4,-1.95, 0.95,0.26,0.2, 255,225,110, "N", 0,0,0},     -- star tip
    {"b", 1.95,-0.4,-1.95, 0.95,0.26,0.2, 255,225,110, "N", 0,0,60},
    {"b", 1.95,-0.4,-1.95, 0.95,0.26,0.2, 255,225,110, "N", 0,0,120},
}

PETS.cosmic_golem = {
    {"b", 0,-0.2,0, 3.0,2.8,2.3, 76,50,150, "L"},                        -- torso
    {"b", 0,0.1,0.95, 1.1,1.1,0.5, 20,10,50, "S"},                       -- chest cavity
    {"b", 0,0.1,1.08, 0.7,0.7,0.35, 255,220,90, "N"},                    -- star core
    {"b", 0,0.1,1.2, 1.3,0.16,0.1, 255,240,150, "N"},
    {"b", 0,0.1,1.2, 0.16,1.3,0.1, 255,240,150, "N"},
    {"b", 0,2.05,0.15, 1.9,1.6,1.7, 92,62,178, "L"},                     -- head
    {"k", 0,2.4,0.85, 1.5,0.25,0.4, 60,38,120, "L"},
    {"bm", 0.42,2.15,0.95, 0.42,0.2,0.15, 255,100,220, "N", 0,0,-12},   -- eyes
    {"bm", 1.9,1.0,0, 1.5,1.3,1.5, 110,80,200, "L"},                     -- shoulders
    {"bm", 2.2,-0.6,0.1, 1.1,2.0,1.1, 76,50,150, "L"},                   -- arms
    {"bm", 2.25,-1.9,0.2, 1.5,1.4,1.5, 92,62,178, "L"},                  -- fists
    {"bm", 0.85,-2.2,0, 1.3,1.6,1.3, 76,50,150, "L"},                    -- legs
    {"bm", 0.85,-2.9,0.25, 1.5,0.7,1.7, 60,38,120, "L"},
    {"km", 2.0,1.9,0, 0.35,1.3,0.35, 255,110,220, "N", 0,0,-20},        -- crystals
    {"km", 2.55,1.6,0.2, 0.3,1.0,0.3, 120,220,255, "N", 0,0,-40},
    {"k", 0.5,1.6,-1.0, 0.35,1.4,0.35, 255,110,220, "N", -30,0,0},
    {"k", -0.6,1.5,-1.0, 0.3,1.1,0.3, 120,220,255, "N", -30,0,15},
    {"k", -3.2,0.6,0.8, 0.3,0.3,0.3, 120,220,255, "N", 30,30,30},        -- floating shards
    {"k", 3.2,1.9,0.6, 0.35,0.35,0.35, 255,110,220, "N", 30,30,30},
}

-- Generic blob for any pet id without a hand-made model.
local FALLBACK = {
    {"b", 0,-0.4,0, 2.6,2.4,2.4, 140,120,230, "S"},
    {"bm", 0.6,-0.1,1.0, 0.45,0.6,0.3, 20,20,40, "S"},
    {"bm", 0.55,0.05,1.15, 0.14,0.18,0.1, 255,255,255, "S"},
    {"b", 0,-0.7,1.15, 0.5,0.2,0.15, 255,150,190, "S"},
    {"bm", 0.9,0.9,0, 0.7,0.9,0.5, 140,120,230, "S", 0,0,-20},
}

----------------------------------------------------------------------------
-- EGGS  (deep-space egg: indigo shell, nebula patches, gold rings, star specks)
----------------------------------------------------------------------------
local function buildEgg(detail)
    local model = Instance.new("Model")
    local rx, ry, rz = 1.5, 2.0, 1.5
    makePart("b", ZERO, v3(rx * 2, ry * 2, rz * 2), Color3.fromRGB(30, 24, 100), "S", ZERO).Parent = model
    -- Point + outward normal on the egg surface (theta around, lat = -1..1 up).
    local function surface(theta, lat)
        local rr = math.sqrt(math.max(0, 1 - lat * lat))
        local x, z = math.cos(theta) * rr, math.sin(theta) * rr
        return v3(rx * x, ry * lat, rz * z), v3(x / rx, lat / ry, z / rz).Unit
    end
    local function patch(theta, lat, w, h, color, tr, mat)
        local pos, n = surface(theta, lat)
        local p = makePart("b", pos, v3(w, h, 0.3), color, mat or "S", ZERO, tr)
        p.CFrame = CFrame.lookAt(pos * 0.985, pos * 0.985 + n)
        p.Parent = model
    end
    local function speck(theta, lat, size, color)
        local pos = surface(theta, lat)
        makePart("b", pos * 1.0, v3(size, size, size), color, "N", ZERO).Parent = model
    end
    patch(1.2, 0.45, 1.1, 0.9, Color3.fromRGB(150, 60, 225), 0.2)
    patch(2.1, -0.15, 0.9, 1.1, Color3.fromRGB(60, 150, 255), 0.3)
    patch(1.6, -0.55, 1.0, 0.7, Color3.fromRGB(230, 80, 200), 0.3)
    patch(0.5, 0.05, 0.8, 0.8, Color3.fromRGB(90, 70, 220), 0.3)
    patch(2.5, 0.6, 0.7, 0.9, Color3.fromRGB(200, 80, 240), 0.35)
    -- shine
    patch(2.3, 0.55, 0.5, 0.85, Color3.fromRGB(255, 255, 255), 0.55)
    local gold, pink, cyan, white = Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 130, 220),
        Color3.fromRGB(110, 235, 255), Color3.fromRGB(255, 255, 255)
    local cols = {gold, pink, cyan, white}
    local rng = Random.new(19)
    local count = detail and 22 or 8
    for i = 1, count do
        speck(rng:NextNumber(0.2, 2.9), rng:NextNumber(-0.85, 0.9), rng:NextNumber(0.12, 0.28), cols[(i % 4) + 1])
    end
    if detail then
        -- gold + magenta bands (thin discs slightly wider than the shell)
        makePart("c", v3(0, 0.3, 0), v3(3.1, 0.12, 3.1), gold, "N", ZERO).Parent = model
        makePart("c", v3(0, -0.95, 0), v3(2.75, 0.1, 2.75), Color3.fromRGB(255, 110, 210), "N", ZERO).Parent = model
    end
    return finish(model)
end

local PILES = {
    [1] = {{0, 0, 0, 1}},
    [3] = {{-1.7, -0.5, 0.2, 0.85}, {1.7, -0.5, 0.2, 0.85}, {0, 0.3, -0.7, 0.9}},
    [6] = {{-3, -1, 0, 0.75}, {0, -1, 0, 0.75}, {3, -1, 0, 0.75}, {-1.5, 0.6, -0.3, 0.75},
        {1.5, 0.6, -0.3, 0.75}, {0, 2.2, -0.6, 0.75}},
    [10] = {{-3.6, -1.2, 0, 0.62}, {-1.2, -1.2, 0, 0.62}, {1.2, -1.2, 0, 0.62}, {3.6, -1.2, 0, 0.62},
        {-2.4, 0.2, -0.4, 0.62}, {0, 0.2, -0.4, 0.62}, {2.4, 0.2, -0.4, 0.62},
        {-1.2, 1.6, -0.8, 0.62}, {1.2, 1.6, -0.8, 0.62}, {0, 3.0, -1.2, 0.62}},
}

local eggTemplate, eggSmallTemplate
function Models.Egg(count)
    count = count or 1
    if not eggTemplate then
        eggTemplate = buildEgg(true)
        eggSmallTemplate = buildEgg(false)
    end
    if count <= 1 then return eggTemplate:Clone() end
    local key = count <= 3 and 3 or (count <= 10 and 6 or 10)
    local pile = Instance.new("Model")
    for _, e in ipairs(PILES[key]) do
        local egg = eggSmallTemplate:Clone()
        egg:ScaleTo(e[4])
        egg:PivotTo(CFrame.new(e[1], e[2], e[3]))
        egg.Parent = pile
    end
    return finish(pile)
end

local petTemplates = {}
function Models.Pet(id)
    local template = petTemplates[id]
    if not template then
        template = Instance.new("Model")
        addRows(template, PETS[id] or FALLBACK)
        finish(template)
        petTemplates[id] = template
    end
    return template:Clone()
end
Models.PetData = PETS -- exposed so other tools can inspect the rows

----------------------------------------------------------------------------
-- VIEWPORT + SPIN CONTROLLER  (one shared RenderStepped for all spinning views)
----------------------------------------------------------------------------
local spinners = {}
local stepConn

local function step(dt)
    for vp, s in pairs(spinners) do
        if not vp.Parent then
            spinners[vp] = nil
        else
            s.t = s.t + dt
            local yaw
            if s.mode == "spin" then yaw = s.base + s.t * 1.7
            else yaw = s.base + math.sin(s.t * 1.9) * 0.55 end
            local bob = math.sin(s.t * 2.4) * s.bob
            s.model:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
        end
    end
    if next(spinners) == nil and stepConn then
        stepConn:Disconnect()
        stepConn = nil
    end
end

function Models.View(parent, model, opts)
    opts = opts or {}
    local vp = Instance.new("ViewportFrame")
    vp.Name = opts.Name or "Model"
    vp.BackgroundTransparency = 1
    vp.BorderSizePixel = 0
    vp.Size = opts.Size or UDim2.fromScale(1, 1)
    vp.Position = opts.Position or UDim2.new()
    vp.AnchorPoint = opts.AnchorPoint or Vector2.new()
    vp.ZIndex = opts.ZIndex or 1
    vp.ImageColor3 = opts.Tint or Color3.new(1, 1, 1)
    vp.Ambient = Color3.fromRGB(160, 160, 190)
    vp.LightColor = Color3.fromRGB(255, 246, 236)
    vp.LightDirection = v3(-0.6, -1, -0.9)
    local cam = Instance.new("Camera")
    cam.FieldOfView = 30
    cam.Parent = vp
    vp.CurrentCamera = cam
    model.Parent = vp

    local size = model:GetExtentsSize()
    local vh = 2 * math.tan(math.rad(15))
    -- Tight framing: fill the frame, with a little room for the sway animation.
    local w = math.max(size.X, size.Z) * 0.98
    local margin = opts.Margin or 1.03
    local dist = math.max(size.Y * margin / vh, w * margin / (vh * (opts.Aspect or 1))) + size.Z * 0.5
    cam.CFrame = CFrame.lookAt(v3(0, size.Y * 0.1, dist), v3(0, -size.Y * 0.01, 0))
    local base = opts.Yaw or -0.45
    model:PivotTo(CFrame.Angles(0, base, 0))
    vp.Parent = parent

    local ctl = {}
    function ctl.Spin(on, mode)
        if on then
            spinners[vp] = {model = model, base = base, t = 0, mode = mode or "spin", bob = size.Y * (opts.Bob or 0.02)}
            if not stepConn then stepConn = RunService.RenderStepped:Connect(step) end
        else
            spinners[vp] = nil
            model:PivotTo(CFrame.Angles(0, base, 0))
        end
    end
    function ctl.Destroy()
        spinners[vp] = nil
        vp:Destroy()
    end
    return vp, ctl
end

function Models.PetView(parent, id, opts)
    return Models.View(parent, Models.Pet(id), opts)
end
function Models.EggView(parent, count, opts)
    return Models.View(parent, Models.Egg(count), opts)
end

return Models
