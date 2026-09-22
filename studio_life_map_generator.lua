--[[
    STUDIO LIFE MAP GENERATOR PRO V3.0.2
    Gerador procedural de mapas em Luau.
    Painel mobile/PC, presets, biomas, terrain opcional, natureza, cidades,
    iluminação, seed, progresso, pausa/cancelamento, undo/redo e validação.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
if not player then
    warn("[MapGen] LocalPlayer indisponível.")
    return
end

local Terrain = Workspace.Terrain

local CONFIG = {
    Version = "3.0.2",
    FolderName = "StudioLife_MapGenerator_PRO",
    Seed = math.random(1, 999999),
    Size = 320,
    Density = 1.0,
    HeightAmplitude = 28,
    SeaLevel = 0,
    RoadDensity = 1.0,
    BuildingDensity = 1.0,
    Quality = "Mobile",
    UseTerrain = false,
    Water = true,
    Decorations = true,
    Interiors = false,
    MaxObjects = 900,
    ChunkStep = 24,
    Biome = "Floresta",
    Theme = "Dia",
    AutoSave = true,
    AutoRecover = true,
    CollisionCheck = true,
    HistoryLimit = 6,
    PersistenceFile = "StudioLife_MapGenerator_PRO_V3.json"
}

local QUALITY = {
    Mobile = {chunk = 28, max = 650, yieldEvery = 8, terrainStep = 24},
    Normal = {chunk = 24, max = 900, yieldEvery = 12, terrainStep = 20},
    Alto = {chunk = 20, max = 1250, yieldEvery = 16, terrainStep = 16},
    Ultra = {chunk = 16, max = 1700, yieldEvery = 20, terrainStep = 12}
}

local BIOMES = {
    Floresta = {
        ground = Color3.fromRGB(65, 126, 57),
        material = Enum.Material.Grass,
        tree = "Tree",
        sky = "Dia"
    },
    Tropical = {
        ground = Color3.fromRGB(76, 145, 62),
        material = Enum.Material.Grass,
        tree = "Palm",
        sky = "Dia"
    },
    Taiga = {
        ground = Color3.fromRGB(79, 112, 76),
        material = Enum.Material.Grass,
        tree = "Pine",
        sky = "Nevoa"
    },
    Neve = {
        ground = Color3.fromRGB(229, 236, 244),
        material = Enum.Material.Snow,
        tree = "Pine",
        sky = "Neve"
    },
    Deserto = {
        ground = Color3.fromRGB(221, 187, 116),
        material = Enum.Material.Sand,
        tree = "Cactus",
        sky = "Dia"
    },
    Savana = {
        ground = Color3.fromRGB(155, 156, 70),
        material = Enum.Material.Grass,
        tree = "Tree",
        sky = "PorDoSol"
    },
    Pantano = {
        ground = Color3.fromRGB(72, 89, 56),
        material = Enum.Material.Ground,
        tree = "DeadTree",
        sky = "Nevoa"
    },
    Vulcanico = {
        ground = Color3.fromRGB(58, 54, 54),
        material = Enum.Material.Basalt,
        tree = "Rock",
        sky = "Terror"
    },
    Cristal = {
        ground = Color3.fromRGB(86, 87, 118),
        material = Enum.Material.Slate,
        tree = "Crystal",
        sky = "Fantasia"
    },
    Alien = {
        ground = Color3.fromRGB(91, 72, 122),
        material = Enum.Material.Slate,
        tree = "Crystal",
        sky = "Alien"
    }
}

local PRESETS = {
    "Floresta", "Tropical", "Taiga", "Neve", "Deserto", "Savana", "Pantano",
    "Montanhas", "Ilha", "Arquipelago", "Vulcao", "Cristais", "Alien",
    "Cidade", "Cyberpunk", "Medieval", "Vila", "Fazenda", "Horror",
    "Arena", "Obby", "Corrida", "Labirinto"
}

local COLORS = {
    bg = Color3.fromRGB(14, 16, 22),
    panel = Color3.fromRGB(23, 27, 36),
    panel2 = Color3.fromRGB(32, 37, 49),
    panel3 = Color3.fromRGB(40, 46, 61),
    accent = Color3.fromRGB(70, 132, 255),
    green = Color3.fromRGB(55, 190, 108),
    orange = Color3.fromRGB(235, 155, 55),
    red = Color3.fromRGB(220, 67, 72),
    text = Color3.fromRGB(242, 245, 252),
    muted = Color3.fromRGB(161, 171, 193)
}

local runtime = {
    busy = false,
    paused = false,
    cancel = false,
    objectCount = 0,
    generatedTerrain = false,
    lastGenerator = nil,
    lastName = "Nenhum",
    stage = "Pronto",
    progress = 0,
    occupancy = {},
    history = {},
    redo = {},
    logs = {},
    recovery = nil,
    baseTerrainBackup = nil,
    selectedPreset = "Floresta",
    previewPreset = "Floresta",
    customPresets = {},
    poiPositions = {},
    lastDuration = 0,
    generationStartedAt = 0
}

local UI = {}

local function logEvent(level, message)
    local stamp = os.date and os.date("%H:%M:%S") or "--:--:--"
    local line = string.format("[%s] %s • %s", stamp, tostring(level or "INFO"), tostring(message or ""))
    table.insert(runtime.logs, line)
    while #runtime.logs > 80 do
        table.remove(runtime.logs, 1)
    end
    if UI.logsBox then
        pcall(function()
            UI.logsBox.Text = table.concat(runtime.logs, "\n")
            UI.logsBox.CursorPosition = #UI.logsBox.Text + 1
        end)
    end
end

local function serializableConfig()
    local data = {}
    for k, v in pairs(CONFIG) do
        local t = type(v)
        if t == "string" or t == "number" or t == "boolean" then
            data[k] = v
        end
    end
    return data
end

local function canUseFilesystem()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function savePersistentState()
    if not CONFIG.AutoSave or not canUseFilesystem() then
        return false
    end

    local payload = {
        version = CONFIG.Version,
        config = serializableConfig(),
        customPresets = runtime.customPresets
    }

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        logEvent("ERRO", "Falha ao codificar autosave")
        return false
    end

    local wrote = pcall(function()
        writefile(CONFIG.PersistenceFile, encoded)
    end)

    if wrote then
        logEvent("SAVE", "Configurações salvas")
    end
    return wrote
end

local function loadPersistentState()
    if not canUseFilesystem() then
        return false
    end

    local exists = false
    pcall(function()
        exists = isfile(CONFIG.PersistenceFile)
    end)
    if not exists then
        return false
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG.PersistenceFile))
    end)

    if not ok or type(decoded) ~= "table" then
        logEvent("ERRO", "Autosave inválido; usando padrão")
        return false
    end

    local source = decoded.config or decoded
    if type(source) == "table" then
        for k, v in pairs(source) do
            if CONFIG[k] ~= nil and type(v) == type(CONFIG[k]) then
                CONFIG[k] = v
            end
        end
    end

    if type(decoded.customPresets) == "table" then
        runtime.customPresets = decoded.customPresets
    end

    logEvent("LOAD", "Configurações restauradas")
    return true
end

local function sanitizeConfig()
    CONFIG.Size = math.clamp(tonumber(CONFIG.Size) or 320, 180, 560)
    CONFIG.Density = math.clamp(tonumber(CONFIG.Density) or 1, 0.45, 1.6)
    CONFIG.HeightAmplitude = math.clamp(tonumber(CONFIG.HeightAmplitude) or 28, 8, 70)
    CONFIG.RoadDensity = math.clamp(tonumber(CONFIG.RoadDensity) or 1, 0.55, 1.6)
    CONFIG.BuildingDensity = math.clamp(tonumber(CONFIG.BuildingDensity) or 1, 0.55, 1.6)
    CONFIG.HistoryLimit = math.clamp(math.floor(tonumber(CONFIG.HistoryLimit) or 6), 1, 8)

    if not QUALITY[CONFIG.Quality] then
        CONFIG.Quality = "Mobile"
    end
    if not BIOMES[CONFIG.Biome] then
        CONFIG.Biome = "Floresta"
    end

    local validThemes = {
        Dia=true, Noite=true, PorDoSol=true, Nevoa=true, Terror=true,
        Cyberpunk=true, Fantasia=true, Alien=true, Neve=true
    }
    if not validThemes[CONFIG.Theme] then
        CONFIG.Theme = "Dia"
    end
end

local function currentQuality()
    sanitizeConfig()
    local q = QUALITY[CONFIG.Quality] or QUALITY.Mobile
    CONFIG.MaxObjects = q.max
    CONFIG.ChunkStep = q.chunk
    return q
end

local function setStatus(text, pct)
    runtime.stage = text or runtime.stage
    if pct ~= nil then
        runtime.progress = math.clamp(pct, 0, 1)
    end

    if UI.status then
        UI.status.Text = runtime.stage
    end
    if UI.progressFill then
        UI.progressFill.Size = UDim2.new(runtime.progress, 0, 1, 0)
    end
    if UI.stats then
        UI.stats.Text = string.format(
            "Objetos: %d/%d  •  Seed: %d  •  %s",
            runtime.objectCount,
            CONFIG.MaxObjects,
            CONFIG.Seed,
            CONFIG.Quality
        )
    end
end

local function checkpoint(i, total, label)
    if runtime.cancel then
        return false
    end

    while runtime.paused and not runtime.cancel do
        setStatus("Pausado • " .. (label or runtime.stage), runtime.progress)
        task.wait(0.1)
    end

    if runtime.cancel then
        return false
    end

    local q = currentQuality()
    if i % q.yieldEvery == 0 then
        if total and total > 0 then
            setStatus(label or runtime.stage, math.clamp(i / total, 0, 1))
        end
        task.wait()
    end

    return true
end

local function folder(parent, name)
    local f = parent:FindFirstChild(name)
    if not f then
        f = Instance.new("Folder")
        f.Name = name
        f.Parent = parent
    end
    return f
end

local function getRoot()
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root then
        root = Instance.new("Folder")
        root.Name = CONFIG.FolderName
        root:SetAttribute("GeneratorVersion", CONFIG.Version)
        root:SetAttribute("GeneratorSeed", CONFIG.Seed)
        root.Parent = Workspace
    end

    folder(root, "TerrainObjects")
    folder(root, "Buildings")
    folder(root, "Vegetation")
    folder(root, "Roads")
    folder(root, "Lights")
    folder(root, "Decorations")
    folder(root, "GameplayObjects")

    return root
end

local function getSub(name)
    return folder(getRoot(), name)
end

local function safeTag(inst, kind)
    pcall(function()
        CollectionService:AddTag(inst, "MapGenGenerated")
        CollectionService:AddTag(inst, "MapGen_" .. kind)
    end)
    pcall(function()
        inst:SetAttribute("GeneratedObject", true)
        inst:SetAttribute("GeneratorSeed", CONFIG.Seed)
        inst:SetAttribute("BiomeType", CONFIG.Biome)
        inst:SetAttribute("ObjectKind", kind)
    end)
end

local function canCreate()
    return runtime.objectCount < CONFIG.MaxObjects and not runtime.cancel
end

local function makePart(kind, props)
    if not canCreate() then
        return nil
    end

    local p = Instance.new(props.ClassName or "Part")
    p.Name = props.Name or kind
    p.Size = props.Size or Vector3.new(4, 1, 4)
    p.CFrame = props.CFrame or CFrame.new()
    p.Anchored = props.Anchored ~= false
    p.CanCollide = props.CanCollide ~= false
    p.CanTouch = props.CanTouch ~= false
    p.CanQuery = props.CanQuery ~= false
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.Color = props.Color or Color3.fromRGB(180, 180, 180)
    p.Transparency = props.Transparency or 0
    p.CastShadow = props.CastShadow ~= false

    if props.Shape then
        p.Shape = props.Shape
    end

    if p:IsA("SpawnLocation") then
        p.Neutral = true
        p.AllowTeamChangeOnTouch = false
    end

    p.Parent = props.Parent or getSub("Decorations")
    safeTag(p, kind)

    if CONFIG.Quality == "Mobile" and props.CastShadow == nil then
        p.CastShadow = false
    end

    runtime.objectCount += 1
    return p
end

local function clearFolder(name)
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root then return end
    local f = root:FindFirstChild(name)
    if f then
        f:ClearAllChildren()
    end
end

local function clearGeneratorEffects()
    for _, n in ipairs({
        "MapGen_Atmosphere",
        "MapGen_Bloom",
        "MapGen_ColorCorrection"
    }) do
        local x = Lighting:FindFirstChild(n)
        if x then x:Destroy() end
    end
end

local TERRAIN_BACKUP_HALF = 360

local function terrainCellRegion()
    local minWorld = Vector3.new(-TERRAIN_BACKUP_HALF, -100, -TERRAIN_BACKUP_HALF)
    local maxWorld = Vector3.new(TERRAIN_BACKUP_HALF, 220, TERRAIN_BACKUP_HALF)
    local minCell = Terrain:WorldToCell(minWorld)
    local maxCell = Terrain:WorldToCell(maxWorld)

    local minV = Vector3int16.new(
        math.floor(math.min(minCell.X, maxCell.X)),
        math.floor(math.min(minCell.Y, maxCell.Y)),
        math.floor(math.min(minCell.Z, maxCell.Z))
    )
    local maxV = Vector3int16.new(
        math.ceil(math.max(minCell.X, maxCell.X)),
        math.ceil(math.max(minCell.Y, maxCell.Y)),
        math.ceil(math.max(minCell.Z, maxCell.Z))
    )

    return Region3int16.new(minV, maxV), minV
end

local function copyTerrainState()
    local ok, state = pcall(function()
        local region, corner = terrainCellRegion()
        return {
            data = Terrain:CopyRegion(region),
            corner = corner
        }
    end)

    if ok then
        return state
    end

    logEvent("WARN", "Snapshot de Terrain indisponível")
    return nil
end

local function restoreTerrainState(state)
    if not state or not state.data or not state.corner then
        return false
    end

    local ok = pcall(function()
        Terrain:PasteRegion(state.data, state.corner, true)
    end)

    if not ok then
        logEvent("WARN", "Não foi possível restaurar Terrain")
    end
    return ok
end

local function clearGeneratedTerrain()
    if not runtime.generatedTerrain then
        return
    end

    if runtime.baseTerrainBackup then
        restoreTerrainState(runtime.baseTerrainBackup)
    else
        local region, _ = terrainCellRegion()
        local min = Terrain:CellCornerToWorld(region.Min.X, region.Min.Y, region.Min.Z)
        local max = Terrain:CellCornerToWorld(region.Max.X, region.Max.Y, region.Max.Z)
        pcall(function()
            Terrain:FillBlock(
                CFrame.new((min + max) / 2),
                Vector3.new(math.abs(max.X-min.X), math.abs(max.Y-min.Y), math.abs(max.Z-min.Z)),
                Enum.Material.Air
            )
        end)
    end

    runtime.generatedTerrain = false
end

local function cloneRoot()
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root then return nil end
    local ok, clone = pcall(function() return root:Clone() end)
    if ok and clone then
        clone.Parent = nil
        return clone
    end
    return nil
end

local function captureState(forceTerrain)
    return {
        root = cloneRoot(),
        terrain = (forceTerrain or runtime.generatedTerrain or CONFIG.UseTerrain) and copyTerrainState() or nil,
        generatedTerrain = runtime.generatedTerrain,
        objectCount = runtime.objectCount,
        lastName = runtime.lastName
    }
end

local function restoreState(state)
    if not state then return false end

    local current = Workspace:FindFirstChild(CONFIG.FolderName)
    if current then current:Destroy() end

    if state.root then
        local rootClone = state.root:Clone()
        rootClone.Parent = Workspace
    end

    if state.terrain then
        restoreTerrainState(state.terrain)
    end

    runtime.generatedTerrain = state.generatedTerrain == true
    runtime.objectCount = state.objectCount or 0
    runtime.lastName = state.lastName or "Nenhum"
    return true
end

local function saveSnapshot()
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root and not runtime.generatedTerrain then
        return
    end

    table.insert(runtime.history, captureState(false))
    while #runtime.history > CONFIG.HistoryLimit do
        table.remove(runtime.history, 1)
    end
    table.clear(runtime.redo)
end

local function captureRecovery()
    runtime.recovery = captureState(CONFIG.UseTerrain or runtime.generatedTerrain)
end

local function restoreRecovery()
    if runtime.recovery then
        restoreState(runtime.recovery)
        logEvent("RECOVERY", "Estado anterior restaurado")
        runtime.recovery = nil
        return true
    end
    return false
end

local function resetRuntimeForGeneration()
    runtime.cancel = false
    runtime.paused = false
    runtime.objectCount = 0
    runtime.occupancy = {}
    runtime.poiPositions = {}
    runtime.progress = 0
end

local function clearMap(makeHistory)
    if makeHistory ~= false then
        saveSnapshot()
    end

    clearGeneratedTerrain()

    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if root then
        root:Destroy()
    end

    runtime.objectCount = 0
    runtime.occupancy = {}
    runtime.poiPositions = {}
    runtime.lastName = "Nenhum"
    logEvent("INFO", "Mapa gerado removido")
    setStatus("Mapa apagado", 0)
end

local function undo()
    local prev = table.remove(runtime.history)
    if not prev then
        setStatus("Nada para desfazer", runtime.progress)
        return
    end

    table.insert(runtime.redo, captureState(false))
    restoreState(prev)
    logEvent("UNDO", "Estado restaurado")
    setStatus("Undo concluído", 1)
end

local function redo()
    local nextMap = table.remove(runtime.redo)
    if not nextMap then
        setStatus("Nada para refazer", runtime.progress)
        return
    end

    table.insert(runtime.history, captureState(false))
    restoreState(nextMap)
    logEvent("REDO", "Estado restaurado")
    setStatus("Redo concluído", 1)
end

local rng = Random.new(CONFIG.Seed)

local function resetRng()
    rng = Random.new(CONFIG.Seed)
end

local function randomXZ(margin)
    local half = CONFIG.Size / 2
    margin = margin or 12
    return rng:NextNumber(-half + margin, half - margin),
           rng:NextNumber(-half + margin, half - margin)
end

local function gridKey(x, z, cell)
    cell = cell or 12
    return tostring(math.floor(x / cell)) .. ":" .. tostring(math.floor(z / cell))
end

local function canPlace(x, z, cell)
    local key = gridKey(x, z, cell)
    return runtime.occupancy[key] == nil
end

local function markPlace(x, z, cell, value)
    runtime.occupancy[gridKey(x, z, cell)] = value or true
end

local function biome()
    return BIOMES[CONFIG.Biome] or BIOMES.Floresta
end

local function groundHeight(x, z, islandMode)
    local scale = 92
    local n1 = math.noise((x + CONFIG.Seed) / scale, (z - CONFIG.Seed) / scale, CONFIG.Seed * 0.0001)
    local n2 = math.noise(x / 37, z / 37, CONFIG.Seed * 0.001) * 0.35
    local h = (n1 + n2) * CONFIG.HeightAmplitude

    if islandMode then
        local radius = CONFIG.Size * 0.46
        local d = math.sqrt(x*x + z*z)
        local edge = math.clamp(1 - (d / radius), 0, 1)
        h = h * edge + (edge * 15) - 8
    end

    return math.max(-16, h)
end

local function createFlatBase(color, material)
    makePart("TerrainBase", {
        Name = "GeneratedGround",
        Size = Vector3.new(CONFIG.Size, 4, CONFIG.Size),
        CFrame = CFrame.new(0, -2, 0),
        Color = color,
        Material = material,
        Parent = getSub("TerrainObjects")
    })
end

local function generateTerrain(islandMode, mountainBoost)
    local b = biome()
    if not CONFIG.UseTerrain then
        createFlatBase(b.ground, b.material)
        return true
    end

    if not runtime.baseTerrainBackup then
        runtime.baseTerrainBackup = copyTerrainState()
    end

    runtime.generatedTerrain = true
    local q = currentQuality()
    local step = q.terrainStep
    local half = math.floor(CONFIG.Size / 2)
    local cells = {}

    for x = -half, half, step do
        for z = -half, half, step do
            table.insert(cells, {x = x, z = z, d = x*x + z*z})
        end
    end

    table.sort(cells, function(a, b)
        return a.d < b.d
    end)

    local total = #cells
    for i, node in ipairs(cells) do
            if not checkpoint(i, total, "Gerando Terrain por chunks...") then
                return false
            end

            local x, z = node.x, node.z
            local h = groundHeight(x, z, islandMode)
            if mountainBoost then
                h *= mountainBoost
            end

            local top = math.max(2, h + 10)
            local material = b.material
            if h > CONFIG.HeightAmplitude * 0.55 and CONFIG.Biome ~= "Deserto" then
                material = CONFIG.Biome == "Neve" and Enum.Material.Snow or Enum.Material.Rock
            end

            pcall(function()
                Terrain:FillBlock(
                    CFrame.new(x, top / 2 - 6, z),
                    Vector3.new(step + 1, top + 12, step + 1),
                    material
                )
            end)
    end

    if CONFIG.Water and islandMode then
        pcall(function()
            Terrain:FillBlock(
                CFrame.new(0, -6, 0),
                Vector3.new(CONFIG.Size + 110, 12, CONFIG.Size + 110),
                Enum.Material.Water
            )
        end)
    end

    return true
end

local function tree(pos, scale, dead)
    scale = scale or 1
    local parent = getSub("Vegetation")
    local h = rng:NextNumber(8, 15) * scale

    local trunk = makePart("Tree", {
        Name = dead and "DeadTreeTrunk" or "TreeTrunk",
        Size = Vector3.new(2.3, h, 2.3) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = dead and Color3.fromRGB(78, 65, 57) or Color3.fromRGB(103, 72, 47),
        Material = Enum.Material.Wood,
        Parent = parent
    })
    if not trunk then return end

    if not dead then
        local crown = makePart("Tree", {
            Name = "TreeLeaves",
            Size = Vector3.new(9.5, 9.5, 9.5) * scale,
            CFrame = CFrame.new(pos + Vector3.new(0, h + 3.4 * scale, 0)),
            Color = Color3.fromRGB(
                rng:NextInteger(35, 70),
                rng:NextInteger(118, 172),
                rng:NextInteger(40, 78)
            ),
            Material = Enum.Material.Grass,
            Shape = Enum.PartType.Ball,
            CanCollide = false,
            Parent = parent
        })
        if crown then crown.CastShadow = true end
    else
        for branch = 1, 3 do
            makePart("Tree", {
                Name = "DeadBranch",
                Size = Vector3.new(1, rng:NextNumber(4, 7), 1),
                CFrame = CFrame.new(pos + Vector3.new(0, h * 0.65, 0))
                    * CFrame.Angles(0, math.rad(branch * 120), math.rad(55)),
                Color = Color3.fromRGB(78, 65, 57),
                Material = Enum.Material.Wood,
                Parent = parent
            })
        end
    end
end

local function pine(pos, scale)
    scale = scale or 1
    local parent = getSub("Vegetation")
    local h = rng:NextNumber(10, 17) * scale

    makePart("Pine", {
        Name = "PineTrunk",
        Size = Vector3.new(2, h, 2) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = Color3.fromRGB(88, 61, 41),
        Material = Enum.Material.Wood,
        Parent = parent
    })

    for layer = 1, 3 do
        local s = (11 - layer * 1.5) * scale
        makePart("Pine", {
            Name = "PineLeaves",
            Size = Vector3.new(s, s * 0.62, s),
            CFrame = CFrame.new(pos + Vector3.new(0, h * 0.48 + layer * 2.5 * scale, 0)),
            Color = CONFIG.Biome == "Neve"
                and Color3.fromRGB(86, 126, 104)
                or Color3.fromRGB(34, 108, 62),
            Material = Enum.Material.Grass,
            Shape = Enum.PartType.Ball,
            CanCollide = false,
            Parent = parent
        })
    end
end

local function palm(pos, scale)
    scale = scale or 1
    local parent = getSub("Vegetation")
    local h = rng:NextNumber(10, 15) * scale

    makePart("Palm", {
        Name = "PalmTrunk",
        Size = Vector3.new(1.8, h, 1.8) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0))
            * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-6, 6))),
        Color = Color3.fromRGB(118, 86, 51),
        Material = Enum.Material.Wood,
        Parent = parent
    })

    for i = 1, 6 do
        makePart("Palm", {
            Name = "PalmLeaf",
            Size = Vector3.new(1.1, 0.45, 8) * scale,
            CFrame = CFrame.new(pos + Vector3.new(0, h + 1, 0))
                * CFrame.Angles(math.rad(-17), math.rad(i * 60), 0)
                * CFrame.new(0, 0, -3.4 * scale),
            Color = Color3.fromRGB(55, 154, 72),
            Material = Enum.Material.Grass,
            CanCollide = false,
            Parent = parent
        })
    end
end

local function cactus(pos, scale)
    scale = scale or 1
    local parent = getSub("Vegetation")
    local h = rng:NextNumber(7, 13) * scale

    makePart("Cactus", {
        Name = "Cactus",
        Size = Vector3.new(2.2, h, 2.2) * scale,
        CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
        Color = Color3.fromRGB(48, 128, 68),
        Material = Enum.Material.SmoothPlastic,
        Parent = parent
    })

    for side = -1, 1, 2 do
        makePart("Cactus", {
            Name = "CactusArm",
            Size = Vector3.new(3.5, 1.4, 1.4) * scale,
            CFrame = CFrame.new(pos + Vector3.new(side * 2, h * 0.58, 0)),
            Color = Color3.fromRGB(48, 128, 68),
            Material = Enum.Material.SmoothPlastic,
            Parent = parent
        })
    end
end

local function rock(pos, scale, crystal)
    scale = scale or 1
    local parent = getSub("Decorations")
    local size = Vector3.new(
        rng:NextNumber(4, 10),
        rng:NextNumber(3, 8),
        rng:NextNumber(4, 10)
    ) * scale

    return makePart(crystal and "Crystal" or "Rock", {
        Name = crystal and "Crystal" or "Rock",
        Size = size,
        CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0))
            * CFrame.Angles(
                math.rad(rng:NextInteger(-15, 15)),
                math.rad(rng:NextInteger(0, 180)),
                math.rad(rng:NextInteger(-15, 15))
            ),
        Color = crystal
            and Color3.fromRGB(rng:NextInteger(100, 175), rng:NextInteger(100, 180), 255)
            or Color3.fromRGB(91, 95, 104),
        Material = crystal and Enum.Material.Neon or Enum.Material.Rock,
        Parent = parent
    })
end

local function bush(pos)
    makePart("Bush", {
        Name = "Bush",
        Size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 4), rng:NextNumber(3, 6)),
        CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)),
        Color = Color3.fromRGB(53, 133, 62),
        Material = Enum.Material.Grass,
        Shape = Enum.PartType.Ball,
        CanCollide = false,
        Parent = getSub("Vegetation")
    })
end

local function flower(pos)
    makePart("Flower", {
        Name = "Flower",
        Size = Vector3.new(0.45, 1.4, 0.45),
        CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0)),
        Color = Color3.fromHSV(rng:NextNumber(), 0.65, 1),
        Material = Enum.Material.Neon,
        CanCollide = false,
        Parent = getSub("Vegetation")
    })
end

local function placeNature(count, mode)
    local b = biome()
    count = math.floor(count * CONFIG.Density)
    local total = math.max(count, 1)

    for i = 1, count do
        if not checkpoint(i, total, "Gerando natureza...") then
            return false
        end

        local x, z = randomXZ(12)
        local cell = 12
        if canPlace(x, z, cell) then
            markPlace(x, z, cell, "Nature")
            local y = CONFIG.UseTerrain and math.max(0, groundHeight(x, z, mode == "Island")) or 0
            local pos = Vector3.new(x, y, z)
            local kind = b.tree

            if kind == "Pine" then
                pine(pos, rng:NextNumber(0.75, 1.2))
            elseif kind == "Palm" then
                palm(pos, rng:NextNumber(0.8, 1.2))
            elseif kind == "Cactus" then
                cactus(pos, rng:NextNumber(0.8, 1.2))
            elseif kind == "DeadTree" then
                tree(pos, rng:NextNumber(0.75, 1.15), true)
            elseif kind == "Crystal" then
                rock(pos, rng:NextNumber(0.8, 1.4), true)
            elseif kind == "Rock" then
                rock(pos, rng:NextNumber(0.8, 1.4), false)
            else
                tree(pos, rng:NextNumber(0.75, 1.2), false)
            end

            if CONFIG.Decorations and rng:NextNumber() < 0.25 then
                if CONFIG.Biome == "Floresta" or CONFIG.Biome == "Tropical" then
                    bush(pos + Vector3.new(rng:NextNumber(-4,4), 0, rng:NextNumber(-4,4)))
                end
            end
        end
    end

    if CONFIG.Decorations and (CONFIG.Biome == "Floresta" or CONFIG.Biome == "Savana") then
        for i = 1, math.floor(24 * CONFIG.Density) do
            local x, z = randomXZ(10)
            flower(Vector3.new(x, 0, z))
        end
    end

    return true
end

local function road(size, cf, neon)
    return makePart("Road", {
        Name = neon and "RoadLine" or "Road",
        Size = size,
        CFrame = cf,
        Color = neon and Color3.fromRGB(255, 220, 66) or Color3.fromRGB(43, 45, 50),
        Material = neon and Enum.Material.Neon or Enum.Material.Pavement,
        CanCollide = not neon,
        Parent = getSub("Roads")
    })
end

local function lamp(pos, cyber)
    local parent = getSub("Lights")
    makePart("Lamp", {
        Name = "LampPole",
        Size = Vector3.new(0.8, 10, 0.8),
        CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)),
        Color = Color3.fromRGB(58, 62, 70),
        Material = Enum.Material.Metal,
        Parent = parent
    })

    local bulb = makePart("Lamp", {
        Name = "LampLight",
        Size = Vector3.new(2.1, 1.2, 2.1),
        CFrame = CFrame.new(pos + Vector3.new(0, 10.4, 0)),
        Color = cyber and Color3.fromRGB(60, 165, 255) or Color3.fromRGB(255, 235, 174),
        Material = Enum.Material.Neon,
        CanCollide = false,
        Parent = parent
    })

    if bulb then
        local light = Instance.new("PointLight")
        light.Range = 28
        light.Brightness = cyber and 2.4 or 1.6
        light.Color = bulb.Color
        light.Parent = bulb
    end
end

local function building(pos, theme, w, d, floors)
    local parent = getSub("Buildings")
    w = w or rng:NextInteger(16, 28)
    d = d or rng:NextInteger(16, 28)
    floors = floors or rng:NextInteger(2, 6)
    local floorH = 7
    local h = floors * floorH

    local color = Color3.fromRGB(
        rng:NextInteger(105, 185),
        rng:NextInteger(105, 185),
        rng:NextInteger(105, 185)
    )

    if theme == "Cyberpunk" then
        color = Color3.fromRGB(rng:NextInteger(35,70), rng:NextInteger(40,75), rng:NextInteger(65,100))
    elseif theme == "Medieval" then
        color = Color3.fromRGB(118, 108, 92)
    end

    local base = makePart("Building", {
        Name = theme .. "_Building",
        Size = Vector3.new(w, h, d),
        CFrame = CFrame.new(pos + Vector3.new(0, h/2, 0)),
        Color = color,
        Material = theme == "Medieval" and Enum.Material.Cobblestone or Enum.Material.Concrete,
        Parent = parent
    })
    if not base then return end

    for floorN = 1, floors do
        if not canCreate() then break end
        for xSlot = -1, 1 do
            local winColor = theme == "Cyberpunk"
                and Color3.fromHSV(rng:NextNumber(0.48, 0.9), 0.9, 1)
                or Color3.fromRGB(95, 188, 255)

            makePart("Window", {
                Name = "Window",
                Size = Vector3.new(3, 3, 0.25),
                CFrame = CFrame.new(pos + Vector3.new(xSlot * (w/4), floorN * floorH - 3, -d/2 - 0.15)),
                Color = winColor,
                Material = theme == "Cyberpunk" and Enum.Material.Neon or Enum.Material.Glass,
                Transparency = theme == "Cyberpunk" and 0 or 0.25,
                CanCollide = false,
                Parent = parent
            })
        end
    end

    makePart("Door", {
        Name = "Door",
        Size = Vector3.new(4, 6, 0.35),
        CFrame = CFrame.new(pos + Vector3.new(0, 3, -d/2 - 0.2)),
        Color = Color3.fromRGB(67, 48, 37),
        Material = Enum.Material.Wood,
        Parent = parent
    })

    if CONFIG.Interiors and floors <= 4 then
        for floorN = 1, floors do
            makePart("Interior", {
                Name = "Floor",
                Size = Vector3.new(w - 1, 0.35, d - 1),
                CFrame = CFrame.new(pos + Vector3.new(0, floorN * floorH - floorH, 0)),
                Color = Color3.fromRGB(115, 112, 105),
                Material = Enum.Material.WoodPlanks,
                Parent = parent
            })
        end
    end
end

local function house(pos, medieval, farm)
    local parent = getSub("Buildings")
    local w, d, h = 18, 16, 9
    local wallColor = medieval and Color3.fromRGB(171, 150, 111)
        or farm and Color3.fromRGB(188, 91, 72)
        or Color3.fromRGB(202, 165, 114)

    makePart("House", {
        Name = "House",
        Size = Vector3.new(w, h, d),
        CFrame = CFrame.new(pos + Vector3.new(0, h/2, 0)),
        Color = wallColor,
        Material = medieval and Enum.Material.WoodPlanks or Enum.Material.SmoothPlastic,
        Parent = parent
    })

    makePart("Roof", {
        Name = "Roof",
        Size = Vector3.new(w + 2, 2, d + 2),
        CFrame = CFrame.new(pos + Vector3.new(0, h + 1, 0))
            * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-3, 3))),
        Color = medieval and Color3.fromRGB(85, 58, 41) or Color3.fromRGB(93, 57, 45),
        Material = Enum.Material.Slate,
        Parent = parent
    })

    makePart("Door", {
        Name = "Door",
        Size = Vector3.new(3.5, 6, 0.35),
        CFrame = CFrame.new(pos + Vector3.new(0, 3, -d/2 - 0.2)),
        Color = Color3.fromRGB(70, 47, 35),
        Material = Enum.Material.Wood,
        Parent = parent
    })
end

local function createRoadGrid(theme)
    local width = 32
    local half = CONFIG.Size / 2
    road(Vector3.new(width, 0.6, CONFIG.Size), CFrame.new(0, 0.3, 0))
    road(Vector3.new(CONFIG.Size, 0.6, width), CFrame.new(0, 0.31, 0))

    local spacing = math.floor(18 / math.max(0.6, CONFIG.RoadDensity))
    for z = -half + 8, half - 8, spacing do
        road(Vector3.new(0.7, 0.12, 7), CFrame.new(0, 0.66, z), true)
    end
    for x = -half + 8, half - 8, spacing do
        road(Vector3.new(7, 0.12, 0.7), CFrame.new(x, 0.67, 0), true)
    end

    for z = -half + 25, half - 25, 34 do
        lamp(Vector3.new(-21, 0, z), theme == "Cyberpunk")
        lamp(Vector3.new(21, 0, z), theme == "Cyberpunk")
    end
end

local function createSpawn(pos)
    makePart("Spawn", {
        ClassName = "SpawnLocation",
        Name = "GeneratedSpawn",
        Size = Vector3.new(12, 1, 12),
        CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)),
        Color = Color3.fromRGB(60, 210, 100),
        Material = Enum.Material.Neon,
        Parent = getSub("GameplayObjects")
    })
end

local function createPOIs(count)
    local parent = getSub("GameplayObjects")
    for i = 1, count do
        local x, z = randomXZ(25)
        if canPlace(x, z, 18) then
            markPlace(x, z, 18, "POI")
            local base = makePart("POI", {
                Name = "PointOfInterest_" .. i,
                Size = Vector3.new(7, 1, 7),
                CFrame = CFrame.new(x, 0.5, z),
                Color = Color3.fromHSV(i / math.max(count,1), 0.7, 1),
                Material = Enum.Material.Neon,
                Parent = parent
            })
            if base then
                table.insert(runtime.poiPositions, Vector3.new(x, 0, z))
                makePart("POI", {
                    Name = "POIMarker",
                    Size = Vector3.new(1.2, 8, 1.2),
                    CFrame = CFrame.new(x, 5, z),
                    Color = base.Color,
                    Material = Enum.Material.Neon,
                    CanCollide = false,
                    Parent = parent
                })
            end
        end
    end
end

local function connectPOIs()
    if #runtime.poiPositions < 2 then return end
    local parent = getSub("Roads")

    for i = 2, #runtime.poiPositions do
        local a = runtime.poiPositions[i - 1]
        local b = runtime.poiPositions[i]
        local mid = (a + b) / 2
        local distance = (b - a).Magnitude

        if distance > 1 then
            makePart("Path", {
                Name = "POI_Path_" .. i,
                Size = Vector3.new(7, 0.35, distance),
                CFrame = CFrame.lookAt(mid + Vector3.new(0,0.18,0), b + Vector3.new(0,0.18,0)),
                Color = Color3.fromRGB(105, 91, 72),
                Material = Enum.Material.Ground,
                Parent = parent
            })
        end
    end
end

local function applyEnvironment(name)
    CONFIG.Theme = name
    clearGeneratorEffects()

    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "MapGen_Atmosphere"
    atmosphere.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "MapGen_Bloom"
    bloom.Parent = Lighting

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "MapGen_ColorCorrection"
    cc.Parent = Lighting

    if name == "Noite" then
        Lighting.ClockTime = 0
        Lighting.Brightness = 1.2
        atmosphere.Density = 0.28
        atmosphere.Color = Color3.fromRGB(110, 135, 180)
        bloom.Intensity = 0.25
    elseif name == "PorDoSol" then
        Lighting.ClockTime = 18.3
        Lighting.Brightness = 2
        atmosphere.Density = 0.2
        atmosphere.Color = Color3.fromRGB(255, 169, 120)
        cc.TintColor = Color3.fromRGB(255, 213, 180)
    elseif name == "Nevoa" then
        Lighting.ClockTime = 8
        Lighting.Brightness = 1.5
        atmosphere.Density = 0.58
        atmosphere.Haze = 2
        atmosphere.Color = Color3.fromRGB(190, 200, 202)
    elseif name == "Terror" then
        Lighting.ClockTime = 1
        Lighting.Brightness = 0.8
        atmosphere.Density = 0.48
        atmosphere.Color = Color3.fromRGB(93, 104, 110)
        cc.Saturation = -0.45
        cc.Contrast = 0.18
    elseif name == "Cyberpunk" then
        Lighting.ClockTime = 22
        Lighting.Brightness = 1.2
        atmosphere.Density = 0.32
        atmosphere.Color = Color3.fromRGB(80, 82, 145)
        bloom.Intensity = 1.25
        bloom.Threshold = 0.75
        cc.Contrast = 0.18
        cc.Saturation = 0.2
    elseif name == "Fantasia" then
        Lighting.ClockTime = 16
        Lighting.Brightness = 2
        atmosphere.Density = 0.25
        atmosphere.Color = Color3.fromRGB(176, 144, 230)
        bloom.Intensity = 0.7
    elseif name == "Alien" then
        Lighting.ClockTime = 21
        Lighting.Brightness = 1.4
        atmosphere.Density = 0.38
        atmosphere.Color = Color3.fromRGB(133, 91, 165)
        cc.TintColor = Color3.fromRGB(180, 145, 225)
        bloom.Intensity = 0.9
    elseif name == "Neve" then
        Lighting.ClockTime = 10
        Lighting.Brightness = 2
        atmosphere.Density = 0.2
        atmosphere.Color = Color3.fromRGB(216, 231, 245)
        cc.Saturation = -0.1
    else
        Lighting.ClockTime = 13.5
        Lighting.Brightness = 2
        atmosphere.Density = 0.18
        atmosphere.Color = Color3.fromRGB(199, 220, 235)
        bloom.Intensity = 0.15
    end
end

local function prepareMap(name, biomeName)
    saveSnapshot()
    clearGeneratedTerrain()

    local old = Workspace:FindFirstChild(CONFIG.FolderName)
    if old then old:Destroy() end

    resetRuntimeForGeneration()
    resetRng()
    CONFIG.Biome = biomeName or CONFIG.Biome
    getRoot():SetAttribute("MapPreset", name)
    getRoot():SetAttribute("GeneratorSeed", CONFIG.Seed)
    setStatus("Preparando " .. name .. "...", 0)
end

local function finishMap(name)
    runtime.lastName = name
    runtime.progress = 1
    runtime.busy = false
    runtime.cancel = false
    runtime.lastDuration = math.max(0, os.clock() - (runtime.generationStartedAt or os.clock()))
    runtime.recovery = nil
    savePersistentState()
    logEvent("OK", string.format("%s concluído em %.2fs com %d objetos", name, runtime.lastDuration, runtime.objectCount))
    setStatus("✓ " .. name .. " concluído", 1)
end

local function failMap(name, err)
    runtime.busy = false
    runtime.cancel = false
    local recovered = false
    if CONFIG.AutoRecover then
        recovered = restoreRecovery()
    end
    warn("[MapGen] " .. tostring(err))
    logEvent("ERRO", name .. " • " .. tostring(err))
    setStatus(
        "Erro em " .. name .. (recovered and " • estado anterior restaurado" or " • veja Logs"),
        runtime.progress
    )
end

local function naturalMap(name, biomeName, natureCount, islandMode, mountainBoost)
    prepareMap(name, biomeName)
    applyEnvironment((BIOMES[biomeName] and BIOMES[biomeName].sky) or "Dia")

    if not generateTerrain(islandMode, mountainBoost) then return end
    if not placeNature(natureCount, islandMode and "Island" or nil) then return end

    for i = 1, math.floor(18 * CONFIG.Density) do
        local x, z = randomXZ(12)
        rock(Vector3.new(x, 0, z), rng:NextNumber(0.6, 1.25), biomeName == "Cristal" or name == "Cristais")
    end

    createSpawn(Vector3.new(0, 2, 0))
    createPOIs(math.clamp(math.floor(CONFIG.Size / 90), 2, 6))
    connectPOIs()
    finishMap(name)
end

local function cityMap(name, theme)
    prepareMap(name, "Floresta")
    createFlatBase(Color3.fromRGB(76, 128, 69), Enum.Material.Grass)
    createRoadGrid(theme)

    local spacing = math.floor(46 / math.max(0.65, CONFIG.BuildingDensity))
    local half = math.floor(CONFIG.Size / 2) - 30
    local total = 0

    for _ = -half, half, spacing do
        for __ = -half, half, spacing do total += 1 end
    end

    local i = 0
    for x = -half, half, spacing do
        for z = -half, half, spacing do
            i += 1
            if not checkpoint(i, total, "Gerando prédios...") then return end
            if math.abs(x) > 26 and math.abs(z) > 26 then
                building(
                    Vector3.new(x + rng:NextNumber(-4,4), 0, z + rng:NextNumber(-4,4)),
                    theme
                )
            end
        end
    end

    applyEnvironment(theme == "Cyberpunk" and "Cyberpunk" or "PorDoSol")
    createSpawn(Vector3.new(18, 1, 18))
    createPOIs(4)
    finishMap(name)
end

local function villageMap(name, medieval, farm)
    prepareMap(name, "Floresta")
    createFlatBase(
        farm and Color3.fromRGB(111, 139, 70) or Color3.fromRGB(77, 136, 65),
        Enum.Material.Grass
    )

    road(Vector3.new(CONFIG.Size, 0.45, 13), CFrame.new(0, 0.23, 0))
    road(Vector3.new(13, 0.45, CONFIG.Size), CFrame.new(0, 0.24, 0))

    local half = math.min(115, CONFIG.Size/2 - 28)
    local positions = {
        Vector3.new(-70,0,-70), Vector3.new(70,0,-70),
        Vector3.new(-70,0,70), Vector3.new(70,0,70),
        Vector3.new(-half,0,-25), Vector3.new(half,0,-25),
        Vector3.new(-half,0,35), Vector3.new(half,0,35)
    }

    for i, pos in ipairs(positions) do
        house(pos, medieval, farm)
        if not farm then
            tree(pos + Vector3.new(14,0,8), 0.85, false)
            tree(pos + Vector3.new(-13,0,7), 0.8, false)
        end
        checkpoint(i, #positions, "Gerando vila...")
    end

    if farm then
        local parent = getSub("Decorations")
        for row = -4, 4 do
            for col = -9, 9 do
                if canCreate() then
                    makePart("Crop", {
                        Name = "Crop",
                        Size = Vector3.new(0.6, rng:NextNumber(1.2, 2.2), 0.6),
                        CFrame = CFrame.new(col * 3, 0.9, row * 4 + 95),
                        Color = Color3.fromRGB(85, 145, 56),
                        Material = Enum.Material.Grass,
                        CanCollide = false,
                        Parent = parent
                    })
                end
            end
        end
    end

    applyEnvironment(medieval and "PorDoSol" or "Dia")
    createSpawn(Vector3.new(8,1,8))
    createPOIs(3)
    finishMap(name)
end

local function volcanoMap()
    prepareMap("Vulcao", "Vulcanico")
    applyEnvironment("Terror")

    if not generateTerrain(false, 1.55) then return end

    local parent = getSub("TerrainObjects")
    for ring = 1, 5 do
        makePart("Volcano", {
            Name = "VolcanoRing",
            Size = Vector3.new(95 - ring*12, 10, 95 - ring*12),
            CFrame = CFrame.new(0, ring*7, 0),
            Color = Color3.fromRGB(60, 54, 52),
            Material = Enum.Material.Basalt,
            Parent = parent
        })
    end

    makePart("Lava", {
        Name = "LavaCore",
        Size = Vector3.new(35, 3, 35),
        CFrame = CFrame.new(0, 39, 0),
        Color = Color3.fromRGB(255, 88, 24),
        Material = Enum.Material.Neon,
        Parent = parent
    })

    placeNature(18)
    createSpawn(Vector3.new(0, 2, -CONFIG.Size/2 + 25))
    finishMap("Vulcao")
end

local function archipelagoMap()
    prepareMap("Arquipelago", "Tropical")
    applyEnvironment("Dia")

    makePart("Ocean", {
        Name = "Ocean",
        Size = Vector3.new(CONFIG.Size + 160, 7, CONFIG.Size + 160),
        CFrame = CFrame.new(0, -5, 0),
        Color = Color3.fromRGB(44, 145, 216),
        Material = Enum.Material.Glass,
        Transparency = 0.18,
        Parent = getSub("TerrainObjects")
    })

    local centers = {
        Vector3.new(-75,0,-55), Vector3.new(70,0,-45),
        Vector3.new(-55,0,72), Vector3.new(72,0,68),
        Vector3.new(0,0,0)
    }

    for i, c in ipairs(centers) do
        local s = rng:NextNumber(55, 88)
        makePart("Island", {
            Name = "Island_" .. i,
            Size = Vector3.new(s, 7, s),
            CFrame = CFrame.new(c + Vector3.new(0,-1,0)),
            Color = Color3.fromRGB(224, 194, 127),
            Material = Enum.Material.Sand,
            Parent = getSub("TerrainObjects")
        })
        palm(c + Vector3.new(rng:NextNumber(-12,12), 3, rng:NextNumber(-12,12)), 0.9)
    end

    createSpawn(Vector3.new(0, 4, 0))
    createPOIs(5)
    finishMap("Arquipelago")
end

local function arenaMap()
    prepareMap("Arena", "Floresta")
    createFlatBase(Color3.fromRGB(66, 68, 74), Enum.Material.Concrete)

    local arena = math.min(CONFIG.Size - 65, 215)
    local h = 25
    local parent = getSub("Buildings")

    local walls = {
        {Vector3.new(arena,h,5), CFrame.new(0,h/2,-arena/2)},
        {Vector3.new(arena,h,5), CFrame.new(0,h/2,arena/2)},
        {Vector3.new(5,h,arena), CFrame.new(-arena/2,h/2,0)},
        {Vector3.new(5,h,arena), CFrame.new(arena/2,h/2,0)}
    }

    for i, data in ipairs(walls) do
        makePart("ArenaWall", {
            Name = "ArenaWall",
            Size = data[1],
            CFrame = data[2],
            Color = Color3.fromRGB(58,61,69),
            Material = Enum.Material.Metal,
            Parent = parent
        })
        checkpoint(i, #walls, "Criando arena...")
    end

    for i = 1, math.floor(22 * CONFIG.Density) do
        local limit = arena/2 - 18
        makePart("ArenaCover", {
            Name = "Cover",
            Size = Vector3.new(rng:NextNumber(7,16), rng:NextNumber(6,14), rng:NextNumber(7,16)),
            CFrame = CFrame.new(rng:NextNumber(-limit,limit), 5, rng:NextNumber(-limit,limit)),
            Color = Color3.fromRGB(96,101,113),
            Material = Enum.Material.Metal,
            Parent = getSub("GameplayObjects")
        })
        if not checkpoint(i, 22, "Criando coberturas...") then return end
    end

    createSpawn(Vector3.new(0,1,0))
    applyEnvironment("PorDoSol")
    finishMap("Arena")
end

local function obbyMap()
    prepareMap("Obby", "Floresta")
    applyEnvironment("Dia")

    local parent = getSub("GameplayObjects")
    makePart("Obby", {
        Name = "Start",
        Size = Vector3.new(24,2,24),
        CFrame = CFrame.new(0,2,0),
        Color = Color3.fromRGB(55,220,105),
        Material = Enum.Material.Neon,
        Parent = parent
    })

    local pos = Vector3.new(0,7,22)
    local stages = math.clamp(math.floor(65 * CONFIG.Density), 35, 110)

    for i = 1, stages do
        if not checkpoint(i, stages, "Gerando Obby...") then return end

        pos += Vector3.new(
            rng:NextNumber(-10,10),
            rng:NextNumber(3.5,6),
            rng:NextNumber(9,14)
        )

        local checkpointStage = i % 10 == 0
        makePart("Obby", {
            Name = checkpointStage and ("Checkpoint_"..i) or ("Stage_"..i),
            Size = checkpointStage
                and Vector3.new(18,2,18)
                or Vector3.new(rng:NextNumber(7,12),2,rng:NextNumber(7,12)),
            CFrame = CFrame.new(pos),
            Color = checkpointStage
                and Color3.fromRGB(255,219,60)
                or Color3.fromHSV(i/stages,0.72,1),
            Material = checkpointStage and Enum.Material.Neon or Enum.Material.SmoothPlastic,
            Parent = parent
        })
    end

    makePart("Obby", {
        Name = "Finish",
        Size = Vector3.new(28,3,28),
        CFrame = CFrame.new(pos + Vector3.new(0,8,18)),
        Color = Color3.fromRGB(255,210,35),
        Material = Enum.Material.Neon,
        Parent = parent
    })

    createSpawn(Vector3.new(0,4,0))
    finishMap("Obby")
end

local function raceMap()
    prepareMap("Corrida", "Floresta")
    createFlatBase(Color3.fromRGB(76,126,66), Enum.Material.Grass)

    local parent = getSub("Roads")
    local trackRadius = math.min(CONFIG.Size * 0.34, 110)
    local segments = 56

    for i = 1, segments do
        if not checkpoint(i, segments, "Gerando pista...") then return end
        local angle = (i/segments) * math.pi * 2
        local x = math.cos(angle) * trackRadius
        local z = math.sin(angle) * trackRadius
        local nextAngle = ((i+1)/segments) * math.pi * 2
        local nx = math.cos(nextAngle) * trackRadius
        local nz = math.sin(nextAngle) * trackRadius
        local dx, dz = nx-x, nz-z
        local length = math.sqrt(dx*dx + dz*dz)

        makePart("RaceTrack", {
            Name = "Track",
            Size = Vector3.new(18,0.65,length + 2),
            CFrame = CFrame.lookAt(Vector3.new(x,0.32,z), Vector3.new(nx,0.32,nz)),
            Color = Color3.fromRGB(45,47,52),
            Material = Enum.Material.Pavement,
            Parent = parent
        })
    end

    makePart("Race", {
        Name = "FinishLine",
        Size = Vector3.new(18,0.2,4),
        CFrame = CFrame.new(trackRadius,0.75,0),
        Color = Color3.fromRGB(245,245,245),
        Material = Enum.Material.Neon,
        Parent = getSub("GameplayObjects")
    })

    createSpawn(Vector3.new(trackRadius,1,8))
    applyEnvironment("Dia")
    finishMap("Corrida")
end

local function mazeMap()
    prepareMap("Labirinto", "Floresta")
    createFlatBase(Color3.fromRGB(70,119,61), Enum.Material.Grass)
    applyEnvironment("Nevoa")

    local parent = getSub("GameplayObjects")
    local cells = CONFIG.Quality == "Mobile" and 13 or 17
    local cell = math.floor(math.min(CONFIG.Size - 50, 260) / cells)
    local half = cells * cell / 2

    for x = 0, cells do
        for z = 0, cells do
            local worldX = -half + x*cell
            local worldZ = -half + z*cell
            if x == 0 or z == 0 or x == cells or z == cells or rng:NextNumber() < 0.33 then
                makePart("MazeWall", {
                    Name = "MazeWall",
                    Size = Vector3.new(cell,10,2),
                    CFrame = CFrame.new(worldX,5,worldZ),
                    Color = Color3.fromRGB(79,83,88),
                    Material = Enum.Material.Slate,
                    Parent = parent
                })
            end
        end
        if not checkpoint(x+1, cells+1, "Gerando labirinto...") then return end
    end

    createSpawn(Vector3.new(-half + cell,1,-half + cell))
    createPOIs(2)
    finishMap("Labirinto")
end

local function horrorMap()
    prepareMap("Horror", "Pantano")
    createFlatBase(Color3.fromRGB(55,65,49), Enum.Material.Ground)
    applyEnvironment("Terror")

    for i = 1, math.floor(35 * CONFIG.Density) do
        local x, z = randomXZ(15)
        tree(Vector3.new(x,0,z), rng:NextNumber(0.8,1.2), true)
        checkpoint(i, 35, "Criando floresta sombria...")
    end

    local oldInteriors = CONFIG.Interiors
    CONFIG.Interiors = true
    building(Vector3.new(0,0,45), "Medieval", 48, 34, 3)
    CONFIG.Interiors = oldInteriors

    for z = -100, 100, 30 do
        lamp(Vector3.new(0,0,z), false)
    end

    createSpawn(Vector3.new(0,1,-110))
    createPOIs(3)
    finishMap("Horror")
end

local function completeProMap()
    prepareMap("Mapa Completo PRO", "Floresta")
    createFlatBase(Color3.fromRGB(72,129,61), Enum.Material.Grass)

    road(Vector3.new(CONFIG.Size,0.55,18), CFrame.new(0,0.27,0))
    road(Vector3.new(18,0.55,CONFIG.Size), CFrame.new(0,0.28,0))

    local half = CONFIG.Size/2 - 35
    local positions = {
        Vector3.new(-65,0,-65), Vector3.new(65,0,-65),
        Vector3.new(-65,0,65), Vector3.new(65,0,65)
    }

    for i, p in ipairs(positions) do
        house(p, false, false)
        lamp(Vector3.new(p.X > 0 and 14 or -14, 0, p.Z), false)
        checkpoint(i,#positions,"Criando distrito...")
    end

    placeNature(35)
    createPOIs(5)
    connectPOIs()
    createSpawn(Vector3.new(9,1,9))

    makePart("Landmark", {
        Name = "CentralLandmark",
        Size = Vector3.new(8,28,8),
        CFrame = CFrame.new(0,14,0),
        Color = Color3.fromRGB(80,145,255),
        Material = Enum.Material.Neon,
        Parent = getSub("Decorations")
    })

    applyEnvironment("PorDoSol")
    finishMap("Mapa Completo PRO")
end

local GENERATORS = {
    Floresta = function() naturalMap("Floresta","Floresta",55,false,1) end,
    Tropical = function() naturalMap("Tropical","Tropical",48,false,1) end,
    Taiga = function() naturalMap("Taiga","Taiga",50,false,1) end,
    Neve = function() naturalMap("Neve","Neve",44,false,1) end,
    Deserto = function() naturalMap("Deserto","Deserto",28,false,0.8) end,
    Savana = function() naturalMap("Savana","Savana",32,false,0.8) end,
    Pantano = function() naturalMap("Pantano","Pantano",38,false,0.7) end,
    Montanhas = function() naturalMap("Montanhas","Taiga",36,false,1.65) end,
    Ilha = function() naturalMap("Ilha","Tropical",34,true,1) end,
    Arquipelago = archipelagoMap,
    Vulcao = volcanoMap,
    Cristais = function() naturalMap("Cristais","Cristal",32,false,1.15) end,
    Alien = function() naturalMap("Alien","Alien",34,false,1.15) end,
    Cidade = function() cityMap("Cidade","Modern") end,
    Cyberpunk = function() cityMap("Cyberpunk","Cyberpunk") end,
    Medieval = function() villageMap("Medieval",true,false) end,
    Vila = function() villageMap("Vila",false,false) end,
    Fazenda = function() villageMap("Fazenda",false,true) end,
    Horror = horrorMap,
    Arena = arenaMap,
    Obby = obbyMap,
    Corrida = raceMap,
    Labirinto = mazeMap,
    ["Mapa Completo PRO"] = completeProMap
}

local function runGenerator(name)
    if runtime.busy then
        setStatus("Já existe uma geração em andamento", runtime.progress)
        return
    end

    local fn = GENERATORS[name]
    if not fn then
        setStatus("Preset desconhecido: " .. tostring(name), runtime.progress)
        return
    end

    captureRecovery()
    runtime.busy = true
    runtime.cancel = false
    runtime.paused = false
    runtime.lastGenerator = name
    runtime.selectedPreset = name
    runtime.generationStartedAt = os.clock()
    logEvent("START", "Gerando " .. name)

    task.spawn(function()
        local ok, err = xpcall(fn, function(e)
            return tostring(e)
        end)
        if not ok then
            failMap(name, err)
        elseif runtime.cancel then
            runtime.busy = false
            if CONFIG.AutoRecover then
                restoreRecovery()
            end
            logEvent("CANCEL", name)
            setStatus("Geração cancelada • estado anterior restaurado", runtime.progress)
        elseif runtime.busy then
            finishMap(name)
        end
    end)
end

local function regenerate()
    if runtime.lastGenerator and GENERATORS[runtime.lastGenerator] then
        runGenerator(runtime.lastGenerator)
    else
        setStatus("Nenhum mapa anterior", runtime.progress)
    end
end

local function validateMap()
    local root = Workspace:FindFirstChild(CONFIG.FolderName)
    if not root then
        setStatus("Validação: nenhum mapa gerado", 0)
        return
    end

    local parts = {}
    local anchored = 0
    local invalid = 0
    local possibleOverlaps = 0

    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") then
            table.insert(parts, inst)
            if inst.Anchored then anchored += 1 end
            if inst.Size.X <= 0 or inst.Size.Y <= 0 or inst.Size.Z <= 0
                or inst.Position.X ~= inst.Position.X
                or inst.Position.Y ~= inst.Position.Y
                or inst.Position.Z ~= inst.Position.Z then
                invalid += 1
            end
        end
    end

    if CONFIG.CollisionCheck and #parts > 1 then
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = {root}
        params.MaxParts = 8

        local sampleCount = math.min(#parts, 180)
        for i = 1, sampleCount do
            local p = parts[i]
            if p.CanCollide and p.Transparency < 0.95 then
                local ok, hits = pcall(function()
                    return Workspace:GetPartBoundsInBox(
                        p.CFrame,
                        Vector3.new(
                            math.max(0.1, p.Size.X - 0.12),
                            math.max(0.1, p.Size.Y - 0.12),
                            math.max(0.1, p.Size.Z - 0.12)
                        ),
                        params
                    )
                end)
                if ok and #hits > 1 then
                    possibleOverlaps += 1
                end
            end
            if i % 30 == 0 then task.wait() end
        end
    end

    local streaming = "?"
    pcall(function()
        streaming = Workspace.StreamingEnabled and "ON" or "OFF"
    end)

    local report = string.format(
        "Validação ✓ Partes:%d • Anchored:%d • Inválidas:%d • Sobreposições possíveis:%d • Streaming:%s",
        #parts, anchored, invalid, possibleOverlaps, streaming
    )
    logEvent("VALIDATE", report)
    setStatus(report, 1)
end

local function exportConfig()
    local data = serializableConfig()

    local ok, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not ok then
        setStatus("Erro ao exportar configuração", runtime.progress)
        return
    end

    if UI.configBox then
        UI.configBox.Text = json
    end

    if setclipboard then
        pcall(setclipboard, json)
        setStatus("Config exportada e copiada", runtime.progress)
    else
        setStatus("Config exportada para a caixa de texto", runtime.progress)
    end
end

local function importConfig()
    if not UI.configBox then return end
    local text = UI.configBox.Text
    local ok, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if not ok or type(data) ~= "table" then
        setStatus("JSON de configuração inválido", runtime.progress)
        return
    end

    local whitelist = {
        Seed=true, Size=true, Density=true, HeightAmplitude=true, SeaLevel=true,
        RoadDensity=true, BuildingDensity=true, Quality=true, UseTerrain=true,
        Water=true, Decorations=true, Interiors=true, Biome=true, Theme=true
    }

    for k,v in pairs(data) do
        if whitelist[k] and CONFIG[k] ~= nil and type(v) == type(CONFIG[k]) then
            CONFIG[k] = v
        end
    end

    currentQuality()
    resetRng()
    savePersistentState()
    logEvent("IMPORT", "Configuração importada")
    setStatus("Configuração importada", runtime.progress)
end

local function saveCustomPreset(name)
    name = tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
    if name == "" then
        setStatus("Digite um nome para o preset", runtime.progress)
        return
    end
    runtime.customPresets[name] = serializableConfig()
    savePersistentState()
    logEvent("PRESET", "Salvo: " .. name)
    setStatus("Preset salvo: " .. name, runtime.progress)
end

local function applyCustomPreset(name)
    local data = runtime.customPresets[name]
    if type(data) ~= "table" then
        setStatus("Preset não encontrado: " .. tostring(name), runtime.progress)
        return
    end

    for k,v in pairs(data) do
        if CONFIG[k] ~= nil and type(v) == type(CONFIG[k]) then
            CONFIG[k] = v
        end
    end
    currentQuality()
    resetRng()
    logEvent("PRESET", "Carregado: " .. name)
    setStatus("Preset carregado: " .. name, runtime.progress)
end

local function autoTuneQuality()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
    local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    if touchOnly or viewport.X < 650 then
        CONFIG.Quality = "Mobile"
    elseif viewport.X < 1100 then
        CONFIG.Quality = "Normal"
    else
        CONFIG.Quality = "Alto"
    end

    currentQuality()
    savePersistentState()
    logEvent("AUTO", "Qualidade automática: " .. CONFIG.Quality)
    setStatus("Qualidade automática: " .. CONFIG.Quality, runtime.progress)
end

local function buildPreview(name)
    local viewport = UI.previewViewport
    if not viewport then return end

    viewport:ClearAllChildren()

    local world = Instance.new("WorldModel")
    world.Parent = viewport

    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(35, 30, 42) * CFrame.Angles(math.rad(-18), math.rad(38), 0)
    camera.Focus = CFrame.new(0,0,0)
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    local function previewPart(size, cf, color, material)
        local p = Instance.new("Part")
        p.Anchored = true
        p.Size = size
        p.CFrame = cf
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Parent = world
        return p
    end

    local bName = ({
        Tropical="Tropical", Taiga="Taiga", Neve="Neve", Deserto="Deserto",
        Savana="Savana", Pantano="Pantano", Vulcao="Vulcanico",
        Cristais="Cristal", Alien="Alien"
    })[name] or "Floresta"
    local b = BIOMES[bName] or BIOMES.Floresta

    previewPart(Vector3.new(48,2,48), CFrame.new(0,-1,0), b.ground, b.material)

    local localRng = Random.new(CONFIG.Seed + #name * 31)

    if name == "Cidade" or name == "Cyberpunk" then
        previewPart(Vector3.new(8,0.4,48), CFrame.new(0,0.2,0), Color3.fromRGB(45,45,50), Enum.Material.Pavement)
        previewPart(Vector3.new(48,0.4,8), CFrame.new(0,0.22,0), Color3.fromRGB(45,45,50), Enum.Material.Pavement)
        for i = 1, 10 do
            local x = (i % 2 == 0) and localRng:NextNumber(8,20) or localRng:NextNumber(-20,-8)
            local z = localRng:NextNumber(-20,20)
            local h = localRng:NextNumber(5,18)
            previewPart(
                Vector3.new(6,h,6),
                CFrame.new(x,h/2,z),
                name == "Cyberpunk" and Color3.fromRGB(52,58,86) or Color3.fromRGB(135,145,155),
                Enum.Material.Concrete
            )
        end
    elseif name == "Obby" then
        local pos = Vector3.new(-18,2,-18)
        for i = 1, 14 do
            pos += Vector3.new(localRng:NextNumber(-2,4), 1.7, 3)
            previewPart(Vector3.new(5,1,5), CFrame.new(pos), Color3.fromHSV(i/14,0.7,1))
        end
    elseif name == "Arena" then
        previewPart(Vector3.new(40,8,2), CFrame.new(0,4,-20), Color3.fromRGB(70,72,80), Enum.Material.Metal)
        previewPart(Vector3.new(40,8,2), CFrame.new(0,4,20), Color3.fromRGB(70,72,80), Enum.Material.Metal)
        previewPart(Vector3.new(2,8,40), CFrame.new(-20,4,0), Color3.fromRGB(70,72,80), Enum.Material.Metal)
        previewPart(Vector3.new(2,8,40), CFrame.new(20,4,0), Color3.fromRGB(70,72,80), Enum.Material.Metal)
    else
        for i = 1, 22 do
            local x = localRng:NextNumber(-20,20)
            local z = localRng:NextNumber(-20,20)
            local h = localRng:NextNumber(2,8)
            local color = b.tree == "Crystal"
                and Color3.fromRGB(120,140,255)
                or b.tree == "Cactus"
                    and Color3.fromRGB(50,135,70)
                    or Color3.fromRGB(55,135,65)
            previewPart(Vector3.new(1.3,h,1.3), CFrame.new(x,h/2,z), color, b.tree=="Crystal" and Enum.Material.Neon or Enum.Material.SmoothPlastic)
        end
    end

    runtime.previewPreset = name
    if UI.previewTitle then
        UI.previewTitle.Text = "Prévia: " .. name
    end
    logEvent("PREVIEW", name)
    setStatus("Prévia atualizada: " .. name, runtime.progress)
end

loadPersistentState()

-- =========================
-- GUI
-- =========================

local guiParent
pcall(function()
    if type(gethui) == "function" then
        guiParent = gethui()
    end
end)
if not guiParent then
    guiParent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
end

local oldGui = guiParent:FindFirstChild("StudioLifeMapGeneratorPRO")
if oldGui then
    pcall(function() oldGui:Destroy() end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLifeMapGeneratorPRO"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent
UI.gui = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(370, 560)
main.Position = UDim2.new(0.5, -185, 0.5, -280)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = gui
UI.main = main

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(63, 72, 95)
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,64)
header.BackgroundColor3 = COLORS.panel
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0,16)
headerCorner.Parent = header

local headerFill = Instance.new("Frame")
headerFill.Position = UDim2.new(0,0,1,-16)
headerFill.Size = UDim2.new(1,0,0,16)
headerFill.BackgroundColor3 = COLORS.panel
headerFill.BorderSizePixel = 0
headerFill.Parent = header

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(15,7)
title.Size = UDim2.new(1,-100,0,27)
title.BackgroundTransparency = 1
title.Text = "MAP GENERATOR PRO V3.0.2"
title.TextColor3 = COLORS.text
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(15,34)
subtitle.Size = UDim2.new(1,-100,0,20)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Procedural • Mobile/PC • v" .. CONFIG.Version
subtitle.TextColor3 = COLORS.muted
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local minimize = Instance.new("TextButton")
minimize.Position = UDim2.new(1,-50,0,11)
minimize.Size = UDim2.fromOffset(39,39)
minimize.BackgroundColor3 = COLORS.panel3
minimize.BorderSizePixel = 0
minimize.Text = "−"
minimize.TextColor3 = COLORS.text
minimize.TextSize = 23
minimize.Font = Enum.Font.GothamBold
minimize.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0,10)
minCorner.Parent = minimize

local tabsBar = Instance.new("ScrollingFrame")
tabsBar.Position = UDim2.fromOffset(8,70)
tabsBar.Size = UDim2.new(1,-16,0,40)
tabsBar.BackgroundTransparency = 1
tabsBar.BorderSizePixel = 0
tabsBar.ScrollBarThickness = 0
tabsBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabsBar.CanvasSize = UDim2.new()
tabsBar.ScrollingDirection = Enum.ScrollingDirection.X
tabsBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0,6)
tabLayout.Parent = tabsBar

local contentHolder = Instance.new("Frame")
contentHolder.Position = UDim2.fromOffset(8,116)
contentHolder.Size = UDim2.new(1,-16,1,-190)
contentHolder.BackgroundTransparency = 1
contentHolder.Parent = main

local bottom = Instance.new("Frame")
bottom.Position = UDim2.new(0,8,1,-68)
bottom.Size = UDim2.new(1,-16,0,60)
bottom.BackgroundColor3 = COLORS.panel
bottom.BorderSizePixel = 0
bottom.Parent = main

local bottomCorner = Instance.new("UICorner")
bottomCorner.CornerRadius = UDim.new(0,12)
bottomCorner.Parent = bottom

local progressBack = Instance.new("Frame")
progressBack.Position = UDim2.fromOffset(10,8)
progressBack.Size = UDim2.new(1,-20,0,6)
progressBack.BackgroundColor3 = COLORS.panel3
progressBack.BorderSizePixel = 0
progressBack.Parent = bottom

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1,0)
progressCorner.Parent = progressBack

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0,0,1,0)
progressFill.BackgroundColor3 = COLORS.accent
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack
UI.progressFill = progressFill

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1,0)
progressFillCorner.Parent = progressFill

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(10,17)
status.Size = UDim2.new(1,-20,0,20)
status.BackgroundTransparency = 1
status.Text = "Pronto"
status.TextColor3 = COLORS.text
status.Font = Enum.Font.GothamSemibold
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = bottom
UI.status = status

local stats = Instance.new("TextLabel")
stats.Position = UDim2.fromOffset(10,36)
stats.Size = UDim2.new(1,-20,0,17)
stats.BackgroundTransparency = 1
stats.Text = ""
stats.TextColor3 = COLORS.muted
stats.Font = Enum.Font.Gotham
stats.TextSize = 9
stats.TextXAlignment = Enum.TextXAlignment.Left
stats.TextTruncate = Enum.TextTruncate.AtEnd
stats.Parent = bottom
UI.stats = stats

local tabFrames = {}
local tabButtons = {}
local activeTab = nil

local function newScroll(name)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = name
    sc.Size = UDim2.fromScale(1,1)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 3
    sc.ScrollBarImageColor3 = COLORS.accent
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.CanvasSize = UDim2.new()
    sc.Visible = false
    sc.Parent = contentHolder

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,7)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = sc

    tabFrames[name] = sc
    return sc
end

local function showTab(name)
    activeTab = name
    for n, frame in pairs(tabFrames) do
        frame.Visible = (n == name)
    end
    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 = (n == name) and COLORS.accent or COLORS.panel2
    end
end

local function addTab(name)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(82,36)
    b.BackgroundColor3 = COLORS.panel2
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.Parent = tabsBar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,9)
    c.Parent = b

    b.MouseButton1Click:Connect(function()
        showTab(name)
    end)

    tabButtons[name] = b
    return newScroll(name)
end

local function section(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-4,0,24)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = COLORS.muted
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function addButton(parent, text, callback, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-4,0,42)
    b.BackgroundColor3 = color or COLORS.panel2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = COLORS.text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,10)
    c.Parent = b

    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback, b)
        if not ok then
            warn("[MapGen UI] " .. tostring(err))
            setStatus("Erro no botão: " .. tostring(err), runtime.progress)
        end
    end)

    return b
end

local function addInfo(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-4,0,34)
    l.BackgroundColor3 = COLORS.panel
    l.BorderSizePixel = 0
    l.Text = text
    l.TextColor3 = COLORS.muted
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextWrapped = true
    l.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,9)
    c.Parent = l
    return l
end

local mapsTab = addTab("Mapas")
local terrainTab = addTab("Terreno")
local natureTab = addTab("Natureza")
local cityTab = addTab("Cidade")
local envTab = addTab("Ambiente")
local previewTab = addTab("Prévia")
local systemTab = addTab("Sistema")
local logsTab = addTab("Logs")

section(mapsTab, "GERADORES")
addButton(mapsTab, "⚡ GERAR MAPA COMPLETO PRO", function()
    runGenerator("Mapa Completo PRO")
end, COLORS.accent)

for _, name in ipairs(PRESETS) do
    addButton(mapsTab, name, function()
        runGenerator(name)
    end)
end

addButton(mapsTab, "🎲 Surpreenda-me", function()
    local name = PRESETS[math.random(1,#PRESETS)]
    runGenerator(name)
end, COLORS.orange)

addButton(mapsTab, "🔁 Regenerar último", regenerate, COLORS.green)

section(terrainTab, "TERRAIN E RELEVO")
local terrainToggle
terrainToggle = addButton(terrainTab, "Terrain real: DESLIGADO", function()
    CONFIG.UseTerrain = not CONFIG.UseTerrain
    terrainToggle.Text = "Terrain real: " .. (CONFIG.UseTerrain and "LIGADO" or "DESLIGADO")
    savePersistentState()
    setStatus("Terrain real " .. (CONFIG.UseTerrain and "ativado" or "desativado"), runtime.progress)
end)

local sizeBtn
sizeBtn = addButton(terrainTab, "Tamanho: " .. CONFIG.Size, function()
    local values = {220,320,420,520}
    local idx = table.find(values, CONFIG.Size) or 2
    idx = idx % #values + 1
    CONFIG.Size = values[idx]
    sizeBtn.Text = "Tamanho: " .. CONFIG.Size
    savePersistentState()
end)

local heightBtn
heightBtn = addButton(terrainTab, "Relevo: " .. CONFIG.HeightAmplitude, function()
    local values = {12,20,28,40,55}
    local idx = table.find(values, CONFIG.HeightAmplitude) or 3
    idx = idx % #values + 1
    CONFIG.HeightAmplitude = values[idx]
    heightBtn.Text = "Relevo: " .. CONFIG.HeightAmplitude
    savePersistentState()
end)

local waterBtn
waterBtn = addButton(terrainTab, "Água: LIGADA", function()
    CONFIG.Water = not CONFIG.Water
    waterBtn.Text = "Água: " .. (CONFIG.Water and "LIGADA" or "DESLIGADA")
    savePersistentState()
end)

addInfo(terrainTab, "Terrain real é opcional. O padrão usa peças para evitar mexer no Terrain existente do mapa.")

section(natureTab, "BIOMA E VEGETAÇÃO")
local biomeBtn
local biomeNames = {"Floresta","Tropical","Taiga","Neve","Deserto","Savana","Pantano","Vulcanico","Cristal","Alien"}
biomeBtn = addButton(natureTab, "Bioma: " .. CONFIG.Biome, function()
    local idx = table.find(biomeNames, CONFIG.Biome) or 1
    idx = idx % #biomeNames + 1
    CONFIG.Biome = biomeNames[idx]
    biomeBtn.Text = "Bioma: " .. CONFIG.Biome
end)

local densityBtn
densityBtn = addButton(natureTab, "Densidade: Normal", function()
    if CONFIG.Density == 1 then
        CONFIG.Density = 1.45
        densityBtn.Text = "Densidade: Alta"
    elseif CONFIG.Density > 1 then
        CONFIG.Density = 0.65
        densityBtn.Text = "Densidade: Baixa"
    else
        CONFIG.Density = 1
        densityBtn.Text = "Densidade: Normal"
    end
end)

local decoBtn
decoBtn = addButton(natureTab, "Decorações: LIGADAS", function()
    CONFIG.Decorations = not CONFIG.Decorations
    decoBtn.Text = "Decorações: " .. (CONFIG.Decorations and "LIGADAS" or "DESLIGADAS")
end)

addButton(natureTab, "Apagar só vegetação", function()
    clearFolder("Vegetation")
    setStatus("Vegetação removida", runtime.progress)
end, COLORS.red)

addButton(natureTab, "Regenerar natureza", function()
    clearFolder("Vegetation")
    placeNature(45)
    setStatus("Natureza regenerada", 1)
end, COLORS.green)

section(cityTab, "CIDADE E CONSTRUÇÕES")
local roadBtn
roadBtn = addButton(cityTab, "Densidade de ruas: Normal", function()
    if CONFIG.RoadDensity == 1 then
        CONFIG.RoadDensity = 1.35
        roadBtn.Text = "Densidade de ruas: Alta"
    elseif CONFIG.RoadDensity > 1 then
        CONFIG.RoadDensity = 0.7
        roadBtn.Text = "Densidade de ruas: Baixa"
    else
        CONFIG.RoadDensity = 1
        roadBtn.Text = "Densidade de ruas: Normal"
    end
end)

local buildBtn
buildBtn = addButton(cityTab, "Densidade de prédios: Normal", function()
    if CONFIG.BuildingDensity == 1 then
        CONFIG.BuildingDensity = 1.35
        buildBtn.Text = "Densidade de prédios: Alta"
    elseif CONFIG.BuildingDensity > 1 then
        CONFIG.BuildingDensity = 0.7
        buildBtn.Text = "Densidade de prédios: Baixa"
    else
        CONFIG.BuildingDensity = 1
        buildBtn.Text = "Densidade de prédios: Normal"
    end
end)

local interiorBtn
interiorBtn = addButton(cityTab, "Interiores simples: DESLIGADOS", function()
    CONFIG.Interiors = not CONFIG.Interiors
    interiorBtn.Text = "Interiores simples: " .. (CONFIG.Interiors and "LIGADOS" or "DESLIGADOS")
end)

addButton(cityTab, "Gerar Cidade", function() runGenerator("Cidade") end, COLORS.accent)
addButton(cityTab, "Gerar Cyberpunk", function() runGenerator("Cyberpunk") end)
addButton(cityTab, "Gerar Medieval", function() runGenerator("Medieval") end)
addButton(cityTab, "Gerar Fazenda", function() runGenerator("Fazenda") end)

section(envTab, "ILUMINAÇÃO E ATMOSFERA")
for _, env in ipairs({"Dia","Noite","PorDoSol","Nevoa","Terror","Cyberpunk","Fantasia","Alien","Neve"}) do
    addButton(envTab, env, function()
        applyEnvironment(env)
        setStatus("Ambiente: " .. env, runtime.progress)
    end)
end

section(previewTab, "PRÉ-VISUALIZAÇÃO")

local previewTitle = Instance.new("TextLabel")
previewTitle.Size = UDim2.new(1,-4,0,30)
previewTitle.BackgroundColor3 = COLORS.panel
previewTitle.BorderSizePixel = 0
previewTitle.Text = "Prévia: " .. runtime.previewPreset
previewTitle.TextColor3 = COLORS.text
previewTitle.Font = Enum.Font.GothamSemibold
previewTitle.TextSize = 12
previewTitle.Parent = previewTab
UI.previewTitle = previewTitle

local previewTitleCorner = Instance.new("UICorner")
previewTitleCorner.CornerRadius = UDim.new(0,9)
previewTitleCorner.Parent = previewTitle

local previewViewport = Instance.new("ViewportFrame")
previewViewport.Size = UDim2.new(1,-4,0,220)
previewViewport.BackgroundColor3 = Color3.fromRGB(20,24,33)
previewViewport.BorderSizePixel = 0
previewViewport.Ambient = Color3.fromRGB(180,180,180)
previewViewport.LightColor = Color3.fromRGB(255,255,255)
previewViewport.LightDirection = Vector3.new(-1,-1,-1)
previewViewport.Parent = previewTab
UI.previewViewport = previewViewport

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0,12)
previewCorner.Parent = previewViewport

local previewCycle
previewCycle = addButton(previewTab, "Preset: " .. runtime.previewPreset, function()
    local idx = table.find(PRESETS, runtime.previewPreset) or 1
    idx = idx % #PRESETS + 1
    runtime.previewPreset = PRESETS[idx]
    previewCycle.Text = "Preset: " .. runtime.previewPreset
    buildPreview(runtime.previewPreset)
end)

addButton(previewTab, "👁 Atualizar prévia", function()
    buildPreview(runtime.previewPreset)
end, COLORS.accent)

addButton(previewTab, "▶ Gerar este preset", function()
    runGenerator(runtime.previewPreset)
end, COLORS.green)

section(systemTab, "DESEMPENHO")
local qualityBtn
qualityBtn = addButton(systemTab, "Qualidade: " .. CONFIG.Quality, function()
    local values = {"Mobile","Normal","Alto","Ultra"}
    local idx = table.find(values, CONFIG.Quality) or 1
    idx = idx % #values + 1
    CONFIG.Quality = values[idx]
    currentQuality()
    qualityBtn.Text = "Qualidade: " .. CONFIG.Quality
    setStatus("Qualidade alterada para " .. CONFIG.Quality, runtime.progress)
end)

addButton(systemTab, "⚙ Qualidade automática", function()
    autoTuneQuality()
    qualityBtn.Text = "Qualidade: " .. CONFIG.Quality
end, COLORS.green)

local seedBtn
seedBtn = addButton(systemTab, "Nova seed", function()
    CONFIG.Seed = math.random(1,999999)
    resetRng()
    setStatus("Seed: " .. CONFIG.Seed, runtime.progress)
end)

addButton(systemTab, "Copiar seed", function()
    if type(setclipboard) == "function" then
        pcall(setclipboard, tostring(CONFIG.Seed))
        setStatus("Seed copiada", runtime.progress)
    else
        setStatus("Seed atual: " .. CONFIG.Seed, runtime.progress)
    end
end)

local autosaveBtn
autosaveBtn = addButton(systemTab, "Autosave: " .. (CONFIG.AutoSave and "LIGADO" or "DESLIGADO"), function()
    CONFIG.AutoSave = not CONFIG.AutoSave
    autosaveBtn.Text = "Autosave: " .. (CONFIG.AutoSave and "LIGADO" or "DESLIGADO")
    if CONFIG.AutoSave then savePersistentState() end
end)

local recoverBtn
recoverBtn = addButton(systemTab, "Auto-recovery: " .. (CONFIG.AutoRecover and "LIGADO" or "DESLIGADO"), function()
    CONFIG.AutoRecover = not CONFIG.AutoRecover
    recoverBtn.Text = "Auto-recovery: " .. (CONFIG.AutoRecover and "LIGADO" or "DESLIGADO")
    savePersistentState()
end)

section(systemTab, "CONTROLE DA GERAÇÃO")
local pauseBtn
pauseBtn = addButton(systemTab, "⏸ Pausar", function()
    if not runtime.busy then
        setStatus("Nenhuma geração ativa", runtime.progress)
        return
    end
    runtime.paused = not runtime.paused
    pauseBtn.Text = runtime.paused and "▶ Continuar" or "⏸ Pausar"
end, COLORS.orange)

addButton(systemTab, "⛔ Cancelar geração", function()
    runtime.cancel = true
    runtime.paused = false
    pauseBtn.Text = "⏸ Pausar"
    setStatus("Cancelando...", runtime.progress)
end, COLORS.red)

section(systemTab, "HISTÓRICO E MANUTENÇÃO")
addButton(systemTab, "↶ Undo", undo)
addButton(systemTab, "↷ Redo", redo)
addButton(systemTab, "✓ Validar mapa", validateMap, COLORS.green)
addButton(systemTab, "🗑 Apagar mapa gerado", function() clearMap(true) end, COLORS.red)

section(systemTab, "PRESETS PERSONALIZADOS")

local presetNameBox = Instance.new("TextBox")
presetNameBox.Size = UDim2.new(1,-4,0,40)
presetNameBox.BackgroundColor3 = COLORS.panel
presetNameBox.BorderSizePixel = 0
presetNameBox.Text = ""
presetNameBox.PlaceholderText = "Nome do preset"
presetNameBox.PlaceholderColor3 = COLORS.muted
presetNameBox.TextColor3 = COLORS.text
presetNameBox.TextSize = 11
presetNameBox.Font = Enum.Font.Gotham
presetNameBox.ClearTextOnFocus = false
presetNameBox.Parent = systemTab

local presetCorner = Instance.new("UICorner")
presetCorner.CornerRadius = UDim.new(0,9)
presetCorner.Parent = presetNameBox

addButton(systemTab, "Salvar preset atual", function()
    saveCustomPreset(presetNameBox.Text)
end)

addButton(systemTab, "Carregar preset", function()
    applyCustomPreset(presetNameBox.Text)
    qualityBtn.Text = "Qualidade: " .. CONFIG.Quality
end)

addButton(systemTab, "Salvar configurações agora", function()
    if savePersistentState() then
        setStatus("Configurações salvas", runtime.progress)
    else
        setStatus("Filesystem não disponível; use Exportar", runtime.progress)
    end
end, COLORS.green)

section(systemTab, "IMPORTAR / EXPORTAR CONFIG")
local configBox = Instance.new("TextBox")
configBox.Size = UDim2.new(1,-4,0,80)
configBox.BackgroundColor3 = COLORS.panel
configBox.BorderSizePixel = 0
configBox.Text = ""
configBox.PlaceholderText = "JSON da configuração"
configBox.PlaceholderColor3 = COLORS.muted
configBox.TextColor3 = COLORS.text
configBox.TextSize = 10
configBox.Font = Enum.Font.Code
configBox.TextWrapped = true
configBox.ClearTextOnFocus = false
configBox.MultiLine = true
configBox.Parent = systemTab
UI.configBox = configBox

local configCorner = Instance.new("UICorner")
configCorner.CornerRadius = UDim.new(0,9)
configCorner.Parent = configBox

addButton(systemTab, "Exportar configuração", exportConfig)
addButton(systemTab, "Importar configuração", importConfig)

section(logsTab, "LOG DE EXECUÇÃO")

local logsBox = Instance.new("TextBox")
logsBox.Size = UDim2.new(1,-4,0,285)
logsBox.BackgroundColor3 = COLORS.panel
logsBox.BorderSizePixel = 0
logsBox.Text = table.concat(runtime.logs, "\n")
logsBox.TextColor3 = COLORS.muted
logsBox.TextSize = 9
logsBox.Font = Enum.Font.Code
logsBox.TextWrapped = false
logsBox.ClearTextOnFocus = false
logsBox.MultiLine = true
logsBox.TextXAlignment = Enum.TextXAlignment.Left
logsBox.TextYAlignment = Enum.TextYAlignment.Top
logsBox.Parent = logsTab
UI.logsBox = logsBox

local logsCorner = Instance.new("UICorner")
logsCorner.CornerRadius = UDim.new(0,9)
logsCorner.Parent = logsBox

addButton(logsTab, "Limpar logs", function()
    table.clear(runtime.logs)
    logsBox.Text = ""
    setStatus("Logs limpos", runtime.progress)
end, COLORS.red)

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tabsBar.Visible = false
        contentHolder.Visible = false
        bottom.Visible = false
        minimize.Text = "+"
        TweenService:Create(main, TweenInfo.new(0.18), {Size = UDim2.fromOffset(370,64)}):Play()
    else
        minimize.Text = "−"
        TweenService:Create(main, TweenInfo.new(0.18), {Size = UDim2.fromOffset(370,560)}):Play()
        task.delay(0.18, function()
            if not minimized then
                tabsBar.Visible = true
                contentHolder.Visible = true
                bottom.Visible = true
            end
        end)
    end
end)

local dragging = false
local dragStart
local startPosition
local dragInput

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position

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
    if input == dragInput and dragging and dragStart and startPosition then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
if viewport and viewport.X < 450 then
    local scale = Instance.new("UIScale")
    scale.Scale = math.clamp(viewport.X / 410, 0.78, 1)
    scale.Parent = main
end

showTab("Mapas")
currentQuality()
buildPreview(runtime.previewPreset)
logEvent("BOOT", "Map Generator PRO V3 carregado")
setStatus("Pronto • PRO V3", 0)

_G.StudioLifeMapGeneratorPRO = {
    Config = CONFIG,
    Generate = runGenerator,
    Clear = function() clearMap(true) end,
    Validate = validateMap,
    Undo = undo,
    Redo = redo,
    ExportConfig = exportConfig,
    ImportConfig = importConfig,
    Save = savePersistentState,
    Load = loadPersistentState,
    SavePreset = saveCustomPreset,
    LoadPreset = applyCustomPreset,
    Preview = buildPreview,
    AutoTune = autoTuneQuality,
    Logs = runtime.logs,
    Version = CONFIG.Version
}

print("[MapGen] Studio Life Map Generator PRO V3.0.2 carregado.")
