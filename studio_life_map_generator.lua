-- Studio Life Map Generator Pro
-- Gerador visual de mapas para ambientes Roblox compatíveis com execução Lua no cliente.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    return
end

local CONFIG = {
    FolderName = "StudioLife_MapGenerator",
    Size = 320,
    Density = 1,
    Seed = os.time() % 999999,
    MaxObjects = 650
}

local Theme = {
    bg = Color3.fromRGB(16, 18, 24),
    panel = Color3.fromRGB(25, 29, 39),
    panel2 = Color3.fromRGB(34, 39, 52),
    accent = Color3.fromRGB(72, 133, 255),
    green = Color3.fromRGB(55, 190, 105),
    red = Color3.fromRGB(220, 70, 70),
    text = Color3.fromRGB(244, 247, 255),
    muted = Color3.fromRGB(163, 172, 194)
}

local rng = Random.new(CONFIG.Seed)
local busy = false
local currentMap = "Nenhum"

local function resetRng()
    rng = Random.new(CONFIG.Seed)
end

local function getRoot()
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root then
        root = Instance.new("Folder")
        root.Name = CONFIG.FolderName
        root.Parent = Workspace
    end
    return root
end

local function clearMap()
    local old = Workspace:FindFirstChild(CONFIG.FolderName)
    if old then
        old:Destroy()
    end
    currentMap = "Nenhum"
end

local function part(props)
    local p = Instance.new("Part")
    p.Name = props.Name or "Part"
    p.Size = props.Size or Vector3.new(4, 1, 4)
    p.CFrame = props.CFrame or CFrame.new()
    p.Anchored = true
    p.CanCollide = props.CanCollide ~= false
    p.CanTouch = props.CanTouch ~= false
    p.CanQuery = props.CanQuery ~= false
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.Color = props.Color or Color3.fromRGB(180, 180, 180)
    p.Transparency = props.Transparency or 0
    p.CastShadow = props.CastShadow ~= false
    if props.Shape then p.Shape = props.Shape end
    p.Parent = props.Parent or getRoot()
    return p
end

local function randomXZ(margin)
    local half = CONFIG.Size / 2
    margin = margin or 12
    return rng:NextNumber(-half + margin, half - margin),
           rng:NextNumber(-half + margin, half - margin)
end

local function yieldEvery(i, n)
    if i % (n or 20) == 0 then
        task.wait()
    end
end

local function makeBase(color, material, thickness)
    thickness = thickness or 4
    return part({
        Name = "Base",
        Size = Vector3.new(CONFIG.Size, thickness, CONFIG.Size),
        CFrame = CFrame.new(0, -thickness / 2, 0),
        Color = color,
        Material = material
    })
end

local function tree(pos, scale)
    scale = scale or 1
    local root = getRoot()
    local h = rng:NextNumber(9, 15) * scale

    part({
        Name = "TreeTrunk",
        Size = Vector3.new(2.4, h, 2.4) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = Color3.fromRGB(107, 72, 45),
        Material = Enum.Material.Wood,
        Parent = root
    })

    local crown = part({
        Name = "TreeLeaves",
        Size = Vector3.new(10, 10, 10) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h + 3.5 * scale, 0)),
        Color = Color3.fromRGB(
            rng:NextInteger(35, 70),
            rng:NextInteger(125, 175),
            rng:NextInteger(45, 80)
        ),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        Parent = root
    })
    crown.CanCollide = false
end

local function pine(pos, scale)
    scale = scale or 1
    local root = getRoot()
    local h = rng:NextNumber(10, 16) * scale

    part({
        Name = "PineTrunk",
        Size = Vector3.new(2, h, 2) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = Color3.fromRGB(95, 63, 42),
        Material = Enum.Material.Wood,
        Parent = root
    })

    for layer = 1, 3 do
        local s = (11 - layer * 1.6) * scale
        local crown = part({
            Name = "PineLeaves",
            Size = Vector3.new(s, s * 0.65, s),
            CFrame = CFrame.new(pos + Vector3.new(0, h * 0.55 + layer * 2.4 * scale, 0)),
            Color = Color3.fromRGB(32, 112, 64),
            Material = Enum.Material.Grass,
            Shape = Enum.PartType.Ball,
            Parent = root
        })
        crown.CanCollide = false
    end
end

local function rock(pos, scale, snow)
    scale = scale or 1
    local r = part({
        Name = "Rock",
        Size = Vector3.new(
            rng:NextNumber(4, 10),
            rng:NextNumber(3, 7),
            rng:NextNumber(4, 10)
        ) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, 2.5 * scale, 0))
            * CFrame.Angles(
                math.rad(rng:NextInteger(-15, 15)),
                math.rad(rng:NextInteger(0, 180)),
                math.rad(rng:NextInteger(-15, 15))
            ),
        Color = snow and Color3.fromRGB(205, 214, 224) or Color3.fromRGB(93, 96, 103),
        Material = snow and Enum.Material.Slate or Enum.Material.Rock
    })
    return r
end

local function lamp(pos)
    local root = getRoot()
    part({
        Name = "LampPole",
        Size = Vector3.new(0.8, 10, 0.8),
        CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)),
        Color = Color3.fromRGB(62, 66, 73),
        Material = Enum.Material.Metal,
        Parent = root
    })
    local bulb = part({
        Name = "Lamp",
        Size = Vector3.new(2, 1.2, 2),
        CFrame = CFrame.new(pos + Vector3.new(0, 10.4, 0)),
        Color = Color3.fromRGB(255, 238, 180),
        Material = Enum.Material.Neon,
        Parent = root
    })
    local light = Instance.new("PointLight")
    light.Range = 28
    light.Brightness = 1.7
    light.Color = bulb.Color
    light.Parent = bulb
end

local function building(pos, w, d, floors)
    local root = getRoot()
    w = w or rng:NextInteger(16, 28)
    d = d or rng:NextInteger(16, 28)
    floors = floors or rng:NextInteger(2, 6)
    local floorH = 7
    local h = floors * floorH

    part({
        Name = "Building",
        Size = Vector3.new(w, h, d),
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = Color3.fromRGB(
            rng:NextInteger(110, 190),
            rng:NextInteger(110, 190),
            rng:NextInteger(110, 190)
        ),
        Material = Enum.Material.Concrete,
        Parent = root
    })

    for floor = 1, floors do
        local y = floor * floorH - 3
        for x = -1, 1 do
            local window = part({
                Name = "Window",
                Size = Vector3.new(3, 3, 0.25),
                CFrame = CFrame.new(pos + Vector3.new(x * (w / 4), y, -d / 2 - 0.15)),
                Color = Color3.fromRGB(95, 190, 255),
                Material = Enum.Material.Glass,
                Transparency = 0.28,
                CanCollide = false,
                Parent = root
            })
            window.CastShadow = false
        end
    end

    part({
        Name = "Door",
        Size = Vector3.new(4, 6, 0.35),
        CFrame = CFrame.new(pos + Vector3.new(0, 3, -d / 2 - 0.2)),
        Color = Color3.fromRGB(66, 46, 35),
        Material = Enum.Material.Wood,
        Parent = root
    })
end

local function house(pos, color)
    local root = getRoot()
    local w, d, h = 18, 16, 9

    part({
        Name = "House",
        Size = Vector3.new(w, h, d),
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = color,
        Material = Enum.Material.WoodPlanks,
        Parent = root
    })

    part({
        Name = "Roof",
        Size = Vector3.new(w + 2, 2, d + 2),
        CFrame = CFrame.new(pos + Vector3.new(0, h + 1, 0))
            * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-3, 3))),
        Color = Color3.fromRGB(88, 52, 40),
        Material = Enum.Material.Slate,
        Parent = root
    })

    part({
        Name = "Door",
        Size = Vector3.new(3.5, 6, 0.35),
        CFrame = CFrame.new(pos + Vector3.new(0, 3, -d / 2 - 0.2)),
        Color = Color3.fromRGB(70, 46, 34),
        Material = Enum.Material.Wood,
        Parent = root
    })
end

local function road(size, cf)
    part({
        Name = "Road",
        Size = size,
        CFrame = cf,
        Color = Color3.fromRGB(42, 44, 49),
        Material = Enum.Material.Asphalt
    })
end

local function generateForest()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(64, 128, 58), Enum.Material.Grass)

    local trees = math.floor(55 * CONFIG.Density)
    local rocks = math.floor(24 * CONFIG.Density)

    for i = 1, trees do
        local x, z = randomXZ(15)
        tree(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.25))
        yieldEvery(i)
    end

    for i = 1, rocks do
        local x, z = randomXZ(12)
        rock(Vector3.new(x, 0, z), rng:NextNumber(0.7, 1.3))
    end

    road(Vector3.new(CONFIG.Size, 0.6, 11), CFrame.new(0, 0.3, 0))

    Lighting.ClockTime = 13.5
    Lighting.Brightness = 2
    currentMap = "Floresta"
end

local function generateCity()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(80, 132, 70), Enum.Material.Grass)

    road(Vector3.new(34, 0.65, CONFIG.Size), CFrame.new(0, 0.325, 0))
    road(Vector3.new(CONFIG.Size, 0.65, 34), CFrame.new(0, 0.33, 0))

    for z = -CONFIG.Size / 2 + 8, CONFIG.Size / 2 - 8, 16 do
        part({
            Name = "RoadLine",
            Size = Vector3.new(0.7, 0.12, 7),
            CFrame = CFrame.new(0, 0.72, z),
            Color = Color3.fromRGB(255, 221, 66),
            Material = Enum.Material.Neon,
            CanCollide = false
        })
    end

    for x = -CONFIG.Size / 2 + 8, CONFIG.Size / 2 - 8, 16 do
        part({
            Name = "RoadLine",
            Size = Vector3.new(7, 0.12, 0.7),
            CFrame = CFrame.new(x, 0.74, 0),
            Color = Color3.fromRGB(255, 221, 66),
            Material = Enum.Material.Neon,
            CanCollide = false
        })
    end

    local spacing = 46
    local half = math.floor(CONFIG.Size / 2) - 28
    local count = 0

    for x = -half, half, spacing do
        for z = -half, half, spacing do
            if math.abs(x) > 27 and math.abs(z) > 27 then
                building(Vector3.new(x + rng:NextNumber(-4, 4), 0, z + rng:NextNumber(-4, 4)))
                count += 1
                yieldEvery(count, 4)
            end
        end
    end

    for z = -half, half, 34 do
        lamp(Vector3.new(-22, 0, z))
        lamp(Vector3.new(22, 0, z))
    end

    Lighting.ClockTime = 18
    Lighting.Brightness = 2
    currentMap = "Cidade"
end

local function generateIsland()
    clearMap()
    resetRng()

    part({
        Name = "Ocean",
        Size = Vector3.new(CONFIG.Size + 180, 8, CONFIG.Size + 180),
        CFrame = CFrame.new(0, -7, 0),
        Color = Color3.fromRGB(42, 145, 215),
        Material = Enum.Material.Glass,
        Transparency = 0.18
    })

    part({
        Name = "Sand",
        Size = Vector3.new(CONFIG.Size - 60, 8, CONFIG.Size - 60),
        CFrame = CFrame.new(0, -3, 0),
        Color = Color3.fromRGB(224, 194, 128),
        Material = Enum.Material.Sand
    })

    part({
        Name = "Grass",
        Size = Vector3.new(CONFIG.Size - 105, 6, CONFIG.Size - 105),
        CFrame = CFrame.new(0, 2, 0),
        Color = Color3.fromRGB(79, 148, 61),
        Material = Enum.Material.Grass
    })

    local limit = (CONFIG.Size - 130) / 2
    for i = 1, math.floor(34 * CONFIG.Density) do
        local x = rng:NextNumber(-limit, limit)
        local z = rng:NextNumber(-limit, limit)
        tree(Vector3.new(x, 5, z), rng:NextNumber(0.85, 1.15))
        yieldEvery(i)
    end

    for i = 1, math.floor(16 * CONFIG.Density) do
        local x = rng:NextNumber(-limit, limit)
        local z = rng:NextNumber(-limit, limit)
        rock(Vector3.new(x, 5, z), rng:NextNumber(0.7, 1.2))
    end

    Lighting.ClockTime = 14
    Lighting.Brightness = 2.2
    currentMap = "Ilha"
end

local function generateArena()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(65, 67, 72), Enum.Material.Concrete)

    local arena = math.min(CONFIG.Size - 70, 210)
    local wallH = 25

    local walls = {
        {Vector3.new(arena, wallH, 5), CFrame.new(0, wallH / 2, -arena / 2)},
        {Vector3.new(arena, wallH, 5), CFrame.new(0, wallH / 2, arena / 2)},
        {Vector3.new(5, wallH, arena), CFrame.new(-arena / 2, wallH / 2, 0)},
        {Vector3.new(5, wallH, arena), CFrame.new(arena / 2, wallH / 2, 0)}
    }

    for _, data in ipairs(walls) do
        part({
            Name = "ArenaWall",
            Size = data[1],
            CFrame = data[2],
            Color = Color3.fromRGB(57, 60, 68),
            Material = Enum.Material.Metal
        })
    end

    for i = 1, math.floor(22 * CONFIG.Density) do
        local limit = arena / 2 - 18
        part({
            Name = "Cover",
            Size = Vector3.new(
                rng:NextNumber(7, 16),
                rng:NextNumber(6, 14),
                rng:NextNumber(7, 16)
            ),
            CFrame = CFrame.new(
                rng:NextNumber(-limit, limit),
                5,
                rng:NextNumber(-limit, limit)
            ),
            Color = Color3.fromRGB(95, 100, 112),
            Material = Enum.Material.Metal
        })
        yieldEvery(i)
    end

    Lighting.ClockTime = 16
    currentMap = "Arena"
end

local function generateVillage()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(79, 138, 65), Enum.Material.Grass)

    road(Vector3.new(CONFIG.Size, 0.45, 13), CFrame.new(0, 0.23, 0))
    road(Vector3.new(13, 0.45, CONFIG.Size), CFrame.new(0, 0.24, 0))

    local palette = {
        Color3.fromRGB(200, 163, 110),
        Color3.fromRGB(187, 142, 102),
        Color3.fromRGB(173, 126, 95),
        Color3.fromRGB(210, 180, 130)
    }

    local half = CONFIG.Size / 2 - 35
    local positions = {
        Vector3.new(-70,0,-70), Vector3.new(70,0,-70),
        Vector3.new(-70,0,70), Vector3.new(70,0,70),
        Vector3.new(-110,0,-25), Vector3.new(110,0,-25),
        Vector3.new(-110,0,35), Vector3.new(110,0,35)
    }

    for i, pos in ipairs(positions) do
        if math.abs(pos.X) < half and math.abs(pos.Z) < half then
            house(pos, palette[(i - 1) % #palette + 1])
            tree(pos + Vector3.new(14, 0, 8), 0.85)
            tree(pos + Vector3.new(-13, 0, 7), 0.8)
        end
    end

    for z = -half, half, 42 do
        lamp(Vector3.new(-10, 0, z))
    end

    Lighting.ClockTime = 17
    currentMap = "Vila"
end

local function generateDesert()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(222, 188, 119), Enum.Material.Sand)

    for i = 1, math.floor(34 * CONFIG.Density) do
        local x, z = randomXZ(15)
        rock(Vector3.new(x, 0, z), rng:NextNumber(0.5, 1.3))
        yieldEvery(i)
    end

    for i = 1, math.floor(14 * CONFIG.Density) do
        local x, z = randomXZ(20)
        local h = rng:NextNumber(7, 13)
        local cactus = part({
            Name = "Cactus",
            Size = Vector3.new(2.6, h, 2.6),
            CFrame = CFrame.new(x, h/2, z),
            Color = Color3.fromRGB(53, 132, 70),
            Material = Enum.Material.SmoothPlastic
        })
        cactus.Shape = Enum.PartType.Cylinder
        cactus.CFrame = cactus.CFrame * CFrame.Angles(0, 0, math.rad(90))
    end

    Lighting.ClockTime = 12.5
    Lighting.Brightness = 2.5
    currentMap = "Deserto"
end

local function generateSnow()
    clearMap()
    resetRng()
    makeBase(Color3.fromRGB(228, 236, 244), Enum.Material.Snow)

    for i = 1, math.floor(45 * CONFIG.Density) do
        local x, z = randomXZ(14)
        pine(Vector3.new(x, 0, z), rng:NextNumber(0.8, 1.2))
        yieldEvery(i)
    end

    for i = 1, math.floor(20 * CONFIG.Density) do
        local x, z = randomXZ(12)
        rock(Vector3.new(x, 0, z), rng:NextNumber(0.7, 1.2), true)
    end

    road(Vector3.new(CONFIG.Size, 0.5, 10), CFrame.new(0, 0.25, 0))
    Lighting.ClockTime = 10
    Lighting.Brightness = 2
    currentMap = "Neve"
end

local function generateObby()
    clearMap()
    resetRng()

    part({
        Name = "Start",
        Size = Vector3.new(24, 2, 24),
        CFrame = CFrame.new(0, 2, 0),
        Color = Color3.fromRGB(65, 225, 105),
        Material = Enum.Material.Neon
    })

    local pos = Vector3.new(0, 7, 22)
    local stages = math.clamp(math.floor(65 * CONFIG.Density), 35, 110)

    for i = 1, stages do
        local dx = rng:NextNumber(-10, 10)
        local dz = rng:NextNumber(9, 14)
        local dy = rng:NextNumber(3.5, 6)
        pos += Vector3.new(dx, dy, dz)

        local checkpoint = (i % 10 == 0)
        part({
            Name = checkpoint and ("Checkpoint_" .. i) or ("Stage_" .. i),
            Size = checkpoint and Vector3.new(18, 2, 18) or Vector3.new(rng:NextNumber(7, 12), 2, rng:NextNumber(7, 12)),
            CFrame = CFrame.new(pos),
            Color = checkpoint and Color3.fromRGB(255, 221, 65) or Color3.fromHSV(i / stages, 0.74, 1),
            Material = checkpoint and Enum.Material.Neon or Enum.Material.SmoothPlastic
        })

        yieldEvery(i, 15)
    end

    part({
        Name = "Finish",
        Size = Vector3.new(26, 3, 26),
        CFrame = CFrame.new(pos + Vector3.new(0, 8, 18)),
        Color = Color3.fromRGB(255, 215, 40),
        Material = Enum.Material.Neon
    })

    Lighting.ClockTime = 12
    currentMap = "Obby"
end

local generators = {
    {"Floresta", generateForest},
    {"Cidade", generateCity},
    {"Ilha", generateIsland},
    {"Arena", generateArena},
    {"Vila", generateVillage},
    {"Deserto", generateDesert},
    {"Neve", generateSnow},
    {"Obby", generateObby}
}

local function runGenerator(name, fn, setStatus)
    if busy then return end
    busy = true
    if setStatus then setStatus("Gerando " .. name .. "...") end

    local ok, err = pcall(fn)

    if setStatus then
        if ok then
            setStatus("✓ " .. name .. " criado | Seed " .. tostring(CONFIG.Seed))
        else
            setStatus("Erro: " .. tostring(err))
        end
    end

    if not ok then
        warn("[MapGenerator] " .. tostring(err))
    end
    busy = false
end

local parent
pcall(function()
    if gethui then
        parent = gethui()
    end
end)
if not parent then
    parent = player:WaitForChild("PlayerGui")
end

local old = parent:FindFirstChild("StudioLifeMapGeneratorGUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLifeMapGeneratorGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(340, 520)
main.Position = UDim2.new(0.5, -170, 0.5, -260)
main.BackgroundColor3 = Theme.bg
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(62, 70, 92)
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 62)
header.BackgroundColor3 = Theme.panel
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 16)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Position = UDim2.new(0, 0, 1, -16)
headerFix.Size = UDim2.new(1, 0, 0, 16)
headerFix.BackgroundColor3 = Theme.panel
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 28)
title.Position = UDim2.fromOffset(15, 7)
title.BackgroundTransparency = 1
title.Text = "STUDIO LIFE • MAP GENERATOR"
title.TextColor3 = Theme.text
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -70, 0, 20)
subtitle.Position = UDim2.fromOffset(15, 34)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Mobile • Seed " .. tostring(CONFIG.Seed)
subtitle.TextColor3 = Theme.muted
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(40, 40)
minimize.Position = UDim2.new(1, -50, 0, 11)
minimize.BackgroundColor3 = Theme.panel2
minimize.BorderSizePixel = 0
minimize.Text = "−"
minimize.TextColor3 = Theme.text
minimize.TextSize = 24
minimize.Font = Enum.Font.GothamBold
minimize.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 10)
minCorner.Parent = minimize

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(10, 72)
scroll.Size = UDim2.new(1, -20, 1, -82)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Theme.accent
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local status = Instance.new("TextLabel")
local function setStatus(text)
    status.Text = text
end

local function section(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -4, 0, 26)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Theme.muted
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = scroll
end

local function button(text, callback, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -4, 0, 44)
    b.BackgroundColor3 = color or Theme.panel2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Theme.text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = scroll

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = b

    b.MouseButton1Click:Connect(function()
        callback(b)
    end)
    return b
end

section("MAPAS")

for _, item in ipairs(generators) do
    local name, fn = item[1], item[2]
    button(name, function()
        runGenerator(name, fn, setStatus)
    end)
end

button("🎲 Mapa aleatório", function()
    local item = generators[rng:NextInteger(1, #generators)]
    runGenerator(item[1], item[2], setStatus)
end, Theme.accent)

section("CONFIGURAÇÕES")

button("🔢 Nova seed", function()
    CONFIG.Seed = math.random(1, 999999)
    resetRng()
    subtitle.Text = "Mobile • Seed " .. tostring(CONFIG.Seed)
    setStatus("Nova seed: " .. tostring(CONFIG.Seed))
end)

local sizeButton
sizeButton = button("📐 Tamanho: " .. CONFIG.Size, function()
    local values = {220, 320, 420, 520}
    local index = table.find(values, CONFIG.Size) or 2
    index = index % #values + 1
    CONFIG.Size = values[index]
    sizeButton.Text = "📐 Tamanho: " .. CONFIG.Size
    setStatus("Tamanho alterado para " .. CONFIG.Size)
end)

local densityButton
densityButton = button("🌳 Densidade: Normal", function()
    if CONFIG.Density == 1 then
        CONFIG.Density = 1.45
        densityButton.Text = "🌳 Densidade: Alta"
    elseif CONFIG.Density > 1 then
        CONFIG.Density = 0.65
        densityButton.Text = "🌳 Densidade: Baixa"
    else
        CONFIG.Density = 1
        densityButton.Text = "🌳 Densidade: Normal"
    end
    setStatus("Densidade atualizada")
end)

button("🔁 Regenerar mapa atual", function()
    if currentMap == "Nenhum" then
        setStatus("Nenhum mapa para regenerar")
        return
    end
    for _, item in ipairs(generators) do
        if item[1] == currentMap then
            runGenerator(item[1], item[2], setStatus)
            return
        end
    end
end, Theme.green)

button("🗑️ Apagar mapa", function()
    clearMap()
    setStatus("Mapa apagado")
end, Theme.red)

status.Size = UDim2.new(1, -4, 0, 42)
status.BackgroundColor3 = Theme.panel
status.BorderSizePixel = 0
status.Text = "Pronto • Seed " .. tostring(CONFIG.Seed)
status.TextColor3 = Theme.muted
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = scroll

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = status

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        scroll.Visible = false
        minimize.Text = "+"
        TweenService:Create(main, TweenInfo.new(0.18), {
            Size = UDim2.fromOffset(340, 62)
        }):Play()
    else
        minimize.Text = "−"
        TweenService:Create(main, TweenInfo.new(0.18), {
            Size = UDim2.fromOffset(340, 520)
        }):Play()
        task.delay(0.18, function()
            if not minimized then
                scroll.Visible = true
            end
        end)
    end
end)

local dragging = false
local dragStart
local startPos
local dragInput

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging and dragStart and startPos then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

setStatus("Pronto • Seed " .. tostring(CONFIG.Seed))
