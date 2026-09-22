-- Ghost Optimizer Universal
-- Otimizador visual local para Roblox / mobile
-- Nao altera WalkSpeed, JumpPower, hitbox, colisao ou mecanicas do servidor.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
if not player then
    return
end

local playerGui = player:WaitForChild("PlayerGui")
local guiParent = playerGui

pcall(function()
    if type(gethui) == "function" then
        guiParent = gethui()
    end
end)

-- Remove copia antiga
pcall(function()
    local old = guiParent:FindFirstChild("GhostOptimizerUniversal")
    if old then
        old:Destroy()
    end
end)

local VERSION = "2026.09"
local CONFIG_FILE = "GhostOptimizerUniversal.json"

local state = {
    stage = 0,
    auto = false,
    targetFps = 60,
    fpsCap = 60,
    minimized = false,
    running = true,
    lastStageChange = 0,
}

local original = setmetatable({}, {__mode = "k"})
local connections = {}
local originalQuality = nil

pcall(function()
    originalQuality = settings().Rendering.QualityLevel
end)

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function remember(obj, prop)
    if not obj then
        return
    end

    local bucket = original[obj]
    if not bucket then
        bucket = {}
        original[obj] = bucket
    end

    if bucket[prop] == nil then
        pcall(function()
            bucket[prop] = obj[prop]
        end)
    end
end

local function setProp(obj, prop, value)
    if not obj then
        return
    end

    remember(obj, prop)
    pcall(function()
        obj[prop] = value
    end)
end

local function restoreAll()
    for obj, props in pairs(original) do
        if obj then
            for prop, value in pairs(props) do
                pcall(function()
                    obj[prop] = value
                end)
            end
        end
    end

    original = setmetatable({}, {__mode = "k"})

    if originalQuality ~= nil then
        pcall(function()
            settings().Rendering.QualityLevel = originalQuality
        end)
    end
end

local function isEffect(obj)
    return obj:IsA("BloomEffect")
        or obj:IsA("BlurEffect")
        or obj:IsA("SunRaysEffect")
        or obj:IsA("DepthOfFieldEffect")
        or obj:IsA("ColorCorrectionEffect")
end

local function isParticle(obj)
    return obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
end

local function optimizeObject(obj, stage)
    if not obj then
        return
    end

    -- Nivel 1: efeitos caros e sombras
    if stage >= 1 then
        if obj:IsA("BasePart") then
            setProp(obj, "CastShadow", false)
        elseif isEffect(obj) then
            setProp(obj, "Enabled", false)
        elseif isParticle(obj) then
            setProp(obj, "Enabled", false)
        elseif obj:IsA("Clouds") then
            setProp(obj, "Enabled", false)
        end
    end

    -- Nivel 2: materiais, luzes e atmosfera
    if stage >= 2 then
        if obj:IsA("BasePart") then
            setProp(obj, "Material", Enum.Material.Plastic)
            setProp(obj, "Reflectance", 0)
        elseif obj:IsA("PointLight")
            or obj:IsA("SpotLight")
            or obj:IsA("SurfaceLight") then
            setProp(obj, "Enabled", false)
        elseif obj:IsA("Atmosphere") then
            setProp(obj, "Density", 0)
            setProp(obj, "Haze", 0)
            setProp(obj, "Glare", 0)
        end
    end

    -- Nivel 3: ultra leve, oculta texturas 2D decorativas
    if stage >= 3 then
        if obj:IsA("Decal") or obj:IsA("Texture") then
            setProp(obj, "Transparency", 1)
        end
    end
end

local function optimizeTerrain(stage)
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then
        return
    end

    if stage >= 2 then
        setProp(terrain, "WaterWaveSize", 0)
        setProp(terrain, "WaterWaveSpeed", 0)
        setProp(terrain, "WaterReflectance", 0)
    end

    if stage >= 3 then
        setProp(terrain, "Decoration", false)
    end
end

local function optimizeLighting(stage)
    if stage >= 1 then
        setProp(Lighting, "GlobalShadows", false)
    end

    if stage >= 2 then
        setProp(Lighting, "EnvironmentDiffuseScale", 0)
        setProp(Lighting, "EnvironmentSpecularScale", 0)
    end

    if stage >= 3 then
        setProp(Lighting, "FogEnd", 1000000)
    end
end

local function applyQuality(stage)
    pcall(function()
        if stage >= 2 then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        elseif stage == 1 then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level03
        elseif originalQuality ~= nil then
            settings().Rendering.QualityLevel = originalQuality
        end
    end)
end

local function scanWorld(stage)
    optimizeLighting(stage)
    optimizeTerrain(stage)
    applyQuality(stage)

    local descendants = workspace:GetDescendants()
    for i = 1, #descendants do
        optimizeObject(descendants[i], stage)

        -- Evita um pico grande ao processar mapas gigantes.
        if i % 700 == 0 then
            task.wait()
        end
    end

    local lightingChildren = Lighting:GetChildren()
    for i = 1, #lightingChildren do
        optimizeObject(lightingChildren[i], stage)
    end
end

local stageNames = {
    [0] = "NORMAL",
    [1] = "BALANCEADO",
    [2] = "DESEMPENHO",
    [3] = "ULTRA LEVE",
}

local statusLabel
local stageLabel
local autoButton
local capButton

local function setStatus(text)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = tostring(text)
    end
end

local function refreshStageLabel()
    if stageLabel and stageLabel.Parent then
        stageLabel.Text = "PERFIL: " .. (stageNames[state.stage] or tostring(state.stage))
    end
end

local function setStage(newStage, source)
    newStage = math.clamp(tonumber(newStage) or 0, 0, 3)

    if newStage == state.stage and source ~= "force" then
        refreshStageLabel()
        return
    end

    setStatus("Aplicando " .. (stageNames[newStage] or "perfil") .. "...")

    -- Sempre restaura antes de trocar de nivel para evitar propriedades presas.
    restoreAll()
    state.stage = newStage
    state.lastStageChange = os.clock()

    if newStage > 0 then
        scanWorld(newStage)
    end

    refreshStageLabel()
    setStatus("Pronto - " .. (stageNames[newStage] or "perfil"))
end

local function setFpsCap(value)
    value = tonumber(value) or 60
    value = math.clamp(value, 30, 240)
    state.fpsCap = value

    local ok = false
    pcall(function()
        if type(setfpscap) == "function" then
            setfpscap(value)
            ok = true
        end
    end)

    if capButton and capButton.Parent then
        capButton.Text = "LIMITE FPS: " .. tostring(value)
    end

    if ok then
        setStatus("Limite configurado em " .. tostring(value) .. " FPS")
    else
        setStatus("Seu ambiente nao oferece setfpscap")
    end
end

local function saveConfig()
    pcall(function()
        if type(writefile) ~= "function" then
            return
        end

        local encoded = HttpService:JSONEncode({
            auto = state.auto,
            targetFps = state.targetFps,
            fpsCap = state.fpsCap,
        })

        writefile(CONFIG_FILE, encoded)
    end)
end

local function loadConfig()
    pcall(function()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then
            return
        end

        if not isfile(CONFIG_FILE) then
            return
        end

        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            if type(data.auto) == "boolean" then
                state.auto = data.auto
            end
            if tonumber(data.targetFps) then
                state.targetFps = math.clamp(tonumber(data.targetFps), 30, 120)
            end
            if tonumber(data.fpsCap) then
                state.fpsCap = math.clamp(tonumber(data.fpsCap), 30, 240)
            end
        end
    end)
end

loadConfig()

-- GUI -----------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "GhostOptimizerUniversal"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = guiParent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 310, 0, 430)
main.Position = UDim2.new(0.5, -155, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(17, 18, 23)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screen

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.45
stroke.Color = Color3.fromRGB(105, 120, 255)
stroke.Parent = main

local top = Instance.new("Frame")
top.Name = "Top"
top.Size = UDim2.new(1, 0, 0, 52)
top.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
top.BorderSizePixel = 0
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -92, 0, 28)
title.Position = UDim2.new(0, 14, 0, 5)
title.BackgroundTransparency = 1
title.Text = "GHOST OPTIMIZER"
title.TextColor3 = Color3.fromRGB(245, 247, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = top

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(1, -92, 0, 18)
subTitle.Position = UDim2.new(0, 14, 0, 29)
subTitle.BackgroundTransparency = 1
subTitle.Text = "Universal Mobile • " .. VERSION
subTitle.TextColor3 = Color3.fromRGB(145, 150, 170)
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 11
subTitle.Parent = top

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0, 34, 0, 34)
minimize.Position = UDim2.new(1, -76, 0, 9)
minimize.BackgroundColor3 = Color3.fromRGB(36, 39, 50)
minimize.Text = "-"
minimize.TextColor3 = Color3.fromRGB(240, 240, 245)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 18
minimize.AutoButtonColor = true
minimize.Parent = top
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 9)

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 34, 0, 34)
close.Position = UDim2.new(1, -38, 0, 9)
close.BackgroundColor3 = Color3.fromRGB(58, 34, 39)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 225, 230)
close.Font = Enum.Font.GothamBold
close.TextSize = 13
close.AutoButtonColor = true
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 9)

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -20, 1, -62)
content.Position = UDim2.new(0, 10, 0, 58)
content.BackgroundTransparency = 1
content.Parent = main

local monitor = Instance.new("Frame")
monitor.Size = UDim2.new(1, 0, 0, 82)
monitor.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
monitor.BorderSizePixel = 0
monitor.Parent = content
Instance.new("UICorner", monitor).CornerRadius = UDim.new(0, 11)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0.33, 0, 0, 38)
fpsLabel.Position = UDim2.new(0, 0, 0, 5)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS\n--"
fpsLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 13
fpsLabel.Parent = monitor

local pingLabel = fpsLabel:Clone()
pingLabel.Position = UDim2.new(0.33, 0, 0, 5)
pingLabel.Text = "PING\n-- ms"
pingLabel.Parent = monitor

local memLabel = fpsLabel:Clone()
memLabel.Position = UDim2.new(0.66, 0, 0, 5)
memLabel.Text = "MEM\n-- MB"
memLabel.Parent = monitor

stageLabel = Instance.new("TextLabel")
stageLabel.Size = UDim2.new(1, -12, 0, 24)
stageLabel.Position = UDim2.new(0, 6, 1, -29)
stageLabel.BackgroundTransparency = 1
stageLabel.Text = "PERFIL: NORMAL"
stageLabel.TextColor3 = Color3.fromRGB(156, 168, 255)
stageLabel.Font = Enum.Font.GothamSemibold
stageLabel.TextSize = 12
stageLabel.Parent = monitor

local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(1, 0, 0, 236)
listFrame.Position = UDim2.new(0, 0, 0, 90)
listFrame.BackgroundTransparency = 1
listFrame.Parent = content

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -5, 0, 46)
grid.CellPadding = UDim2.new(0, 10, 0, 9)
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = listFrame

local function makeButton(text, callback)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = Color3.fromRGB(30, 33, 43)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(240, 242, 250)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = listFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    connect(b.MouseButton1Click, callback)
    return b
end

local function manualStage(stage)
    state.auto = false
    if autoButton and autoButton.Parent then
        autoButton.Text = "AUTO: OFF"
    end
    saveConfig()
    task.spawn(function()
        setStage(stage)
    end)
end

makeButton("BALANCEADO", function()
    manualStage(1)
end)

makeButton("DESEMPENHO", function()
    manualStage(2)
end)

makeButton("ULTRA LEVE", function()
    manualStage(3)
end)

makeButton("RESTAURAR", function()
    manualStage(0)
end)

autoButton = makeButton("AUTO: " .. (state.auto and "ON" or "OFF"), function()
    state.auto = not state.auto
    autoButton.Text = "AUTO: " .. (state.auto and "ON" or "OFF")
    setStatus(state.auto and "Auto Optimizer ativado" or "Auto Optimizer desativado")
    saveConfig()
end)

capButton = makeButton("LIMITE FPS: " .. tostring(state.fpsCap), function()
    local values = {30, 45, 60, 90}
    local index = 1

    for i = 1, #values do
        if values[i] == state.fpsCap then
            index = i
            break
        end
    end

    index = index + 1
    if index > #values then
        index = 1
    end

    setFpsCap(values[index])
    saveConfig()
end)

makeButton("OTIMIZAR AGORA", function()
    task.spawn(function()
        setStage(math.max(state.stage, 2), "force")
    end)
end)

makeButton("EMERGENCIA FPS", function()
    state.auto = false
    if autoButton and autoButton.Parent then
        autoButton.Text = "AUTO: OFF"
    end
    saveConfig()
    task.spawn(function()
        setStage(3, "force")
    end)
end)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 48)
statusLabel.Position = UDim2.new(0, 0, 1, -48)
statusLabel.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Pronto"
statusLabel.TextColor3 = Color3.fromRGB(165, 170, 188)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.TextSize = 11
statusLabel.Parent = content
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 10)

-- Arrastar no PC e celular
local dragging = false
local dragStart = nil
local startPos = nil
local dragInput = nil

connect(top.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        connect(input.Changed, function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

connect(top.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

connect(UserInputService.InputChanged, function(input)
    if dragging and input == dragInput and dragStart and startPos then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

connect(minimize.MouseButton1Click, function()
    state.minimized = not state.minimized
    content.Visible = not state.minimized

    if state.minimized then
        main.Size = UDim2.new(0, 310, 0, 52)
        minimize.Text = "+"
    else
        main.Size = UDim2.new(0, 310, 0, 430)
        minimize.Text = "-"
    end
end)

local function shutdown()
    if not state.running then
        return
    end

    state.running = false
    restoreAll()

    for i = 1, #connections do
        pcall(function()
            connections[i]:Disconnect()
        end)
    end

    pcall(function()
        screen:Destroy()
    end)
end

connect(close.MouseButton1Click, shutdown)

-- Objetos criados depois da otimizacao tambem recebem o perfil atual.
connect(workspace.DescendantAdded, function(obj)
    if state.running and state.stage > 0 then
        task.defer(function()
            if state.running and obj and obj.Parent then
                optimizeObject(obj, state.stage)
            end
        end)
    end
end)

connect(Lighting.ChildAdded, function(obj)
    if state.running and state.stage > 0 then
        task.defer(function()
            if state.running and obj and obj.Parent then
                optimizeObject(obj, state.stage)
            end
        end)
    end
end)

-- Monitor -------------------------------------------------------------------

local frames = 0
local elapsed = 0
local currentFps = 60
local smoothFps = 60
local lowSamples = 0
local highSamples = 0

connect(RunService.RenderStepped, function(dt)
    if not state.running then
        return
    end

    frames = frames + 1
    elapsed = elapsed + dt

    if elapsed >= 0.75 then
        currentFps = math.floor((frames / elapsed) + 0.5)
        smoothFps = math.floor((smoothFps * 0.65) + (currentFps * 0.35) + 0.5)
        fpsLabel.Text = "FPS\n" .. tostring(currentFps)

        frames = 0
        elapsed = 0
    end
end)

task.spawn(function()
    while state.running do
        local memText = "--"
        pcall(function()
            memText = tostring(math.floor(Stats:GetTotalMemoryUsageMb() + 0.5))
        end)
        memLabel.Text = "MEM\n" .. memText .. " MB"

        local pingText = "--"
        pcall(function()
            local network = Stats:FindFirstChild("Network")
            if network and network:FindFirstChild("ServerStatsItem") then
                local item = network.ServerStatsItem:FindFirstChild("Data Ping")
                if item then
                    local value = item:GetValue()
                    if tonumber(value) then
                        pingText = tostring(math.floor(tonumber(value) + 0.5))
                    else
                        pingText = item:GetValueString()
                    end
                end
            end
        end)
        pingLabel.Text = "PING\n" .. tostring(pingText) .. (tonumber(pingText) and " ms" or "")

        task.wait(1)
    end
end)

-- Auto Optimizer com histerese e cooldown para evitar ficar trocando toda hora.
task.spawn(function()
    while state.running do
        task.wait(3)

        if state.auto and state.running then
            local desired = state.stage

            if smoothFps < 25 then
                desired = 3
                lowSamples = lowSamples + 1
                highSamples = 0
            elseif smoothFps < 38 then
                desired = math.max(state.stage, 2)
                lowSamples = lowSamples + 1
                highSamples = 0
            elseif smoothFps < 50 then
                desired = math.max(state.stage, 1)
                lowSamples = lowSamples + 1
                highSamples = 0
            elseif smoothFps >= 57 then
                highSamples = highSamples + 1
                lowSamples = 0

                if highSamples >= 4 then
                    desired = math.max(0, state.stage - 1)
                    highSamples = 0
                end
            else
                lowSamples = 0
                highSamples = 0
            end

            local cooldownReady = (os.clock() - state.lastStageChange) >= 8

            if desired ~= state.stage and cooldownReady then
                if desired > state.stage or lowSamples >= 2 or smoothFps >= 57 then
                    task.spawn(function()
                        setStage(desired)
                    end)
                    lowSamples = 0
                end
            end
        end
    end
end)

refreshStageLabel()
setFpsCap(state.fpsCap)

if state.auto then
    setStatus("Auto Optimizer ativo - monitorando FPS")
else
    setStatus("Pronto - escolha um perfil ou ative AUTO")
end

print("[Ghost Optimizer Universal] carregado | versao " .. VERSION)
