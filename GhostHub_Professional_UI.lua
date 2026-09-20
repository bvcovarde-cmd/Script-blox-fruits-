--[[
    GHOST HUB PROFESSIONAL V2
    Keyless | Mobile + PC | Roblox/Luau

    Arquitetura de interface e utilidades locais.
    Modulos de exploit/cheat contra jogos de terceiros nao sao incluidos.

    Build: 2.0.0
]]

local VERSION = "2.0.0"
local BUILD = "2026.09.20"

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

--// Capability detection
local Capabilities = {
    gethui = typeof(gethui) == "function",
    setclipboard = typeof(setclipboard) == "function",
    readfile = typeof(readfile) == "function",
    writefile = typeof(writefile) == "function",
    isfile = typeof(isfile) == "function",
    delfile = typeof(delfile) == "function",
}

local function getGuiParent()
    if Capabilities.gethui then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)

    if okCore and coreGui then
        return coreGui
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = getGuiParent()
local GUI_NAME = "GhostHub_Professional_V2"
local CONFIG_FILE = "GhostHub_Professional_V2_config.json"

--// Destroy old instance
pcall(function()
    local old = GuiParent:FindFirstChild(GUI_NAME)
    if old then
        old:Destroy()
    end
end)

--==================================================
-- MAID / CLEANUP MANAGER
--==================================================

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({
        _items = {}
    }, Maid)
end

function Maid:Give(item)
    table.insert(self._items, item)
    return item
end

function Maid:Clean()
    for i = #self._items, 1, -1 do
        local item = self._items[i]
        self._items[i] = nil

        pcall(function()
            local itemType = typeof(item)

            if itemType == "RBXScriptConnection" then
                if item.Connected then
                    item:Disconnect()
                end
            elseif itemType == "Instance" then
                item:Destroy()
            elseif type(item) == "function" then
                item()
            elseif type(item) == "table" and typeof(item.Destroy) == "function" then
                item:Destroy()
            elseif type(item) == "table" and typeof(item.Clean) == "function" then
                item:Clean()
            end
        end)
    end
end

local GlobalMaid = Maid.new()

--==================================================
-- LOG SYSTEM
--==================================================

local Logs = {
    Max = 150,
    Items = {},
    ListParent = nil
}

local function timestamp()
    local ok, result = pcall(function()
        return os.date("%H:%M:%S")
    end)
    return ok and result or tostring(math.floor(os.clock()))
end

local function pushLog(level, message)
    local entry = {
        time = timestamp(),
        level = tostring(level or "INFO"),
        message = tostring(message or "")
    }

    table.insert(Logs.Items, entry)

    while #Logs.Items > Logs.Max do
        table.remove(Logs.Items, 1)
    end

    print(("[Ghost Hub][%s][%s] %s"):format(entry.time, entry.level, entry.message))
end

pushLog("INFO", "Inicializando Ghost Hub V2.")

--==================================================
-- DEFAULT CONFIG / PERSISTENCE
--==================================================

local Defaults = {
    Theme = "Purple",
    Scale = 1,
    LastPage = "Home",
    ReduceMotion = false,
    CompactSidebar = false,
    PositionX = 0,
    PositionY = 0,
    FloatingX = 14,
    FloatingY = 260,
    Favorites = {},
    Recent = {},
    DevMode = false,
    LowGraphics = false,
    HideEffects = false
}

local Config = {}

local function deepCopy(source)
    local result = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = deepCopy(value)
        else
            result[key] = value
        end
    end

    return result
end

local function mergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = deepCopy(value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            mergeDefaults(target[key], value)
        end
    end

    return target
end

Config = deepCopy(Defaults)

local function loadConfig()
    if not (Capabilities.readfile and Capabilities.isfile) then
        pushLog("WARN", "Persistencia de arquivo indisponivel neste ambiente.")
        return false
    end

    local existsOk, exists = pcall(isfile, CONFIG_FILE)
    if not existsOk or not exists then
        return false
    end

    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" then
        pushLog("ERROR", "Falha ao ler configuracao.")
        return false
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not decodeOk or type(decoded) ~= "table" then
        pushLog("ERROR", "Configuracao corrompida; usando padrao.")
        return false
    end

    Config = mergeDefaults(decoded, Defaults)
    pushLog("INFO", "Configuracao carregada.")
    return true
end

local function saveConfig()
    if not Capabilities.writefile then
        return false
    end

    local encodeOk, encoded = pcall(function()
        return HttpService:JSONEncode(Config)
    end)

    if not encodeOk then
        pushLog("ERROR", "Falha ao serializar configuracao.")
        return false
    end

    local writeOk, writeErr = pcall(writefile, CONFIG_FILE, encoded)

    if not writeOk then
        pushLog("ERROR", "Falha ao salvar configuracao: " .. tostring(writeErr))
        return false
    end

    return true
end

loadConfig()

--==================================================
-- THEMES
--==================================================

local Themes = {
    Purple = {
        bg = Color3.fromRGB(14, 15, 20),
        panel = Color3.fromRGB(20, 21, 28),
        panel2 = Color3.fromRGB(27, 29, 38),
        panel3 = Color3.fromRGB(34, 36, 47),
        border = Color3.fromRGB(57, 60, 76),
        text = Color3.fromRGB(244, 246, 252),
        muted = Color3.fromRGB(153, 159, 178),
        accent = Color3.fromRGB(126, 93, 255),
        success = Color3.fromRGB(83, 211, 135),
        warning = Color3.fromRGB(255, 187, 80),
        danger = Color3.fromRGB(255, 91, 112)
    },

    Ocean = {
        bg = Color3.fromRGB(12, 17, 22),
        panel = Color3.fromRGB(17, 25, 33),
        panel2 = Color3.fromRGB(23, 33, 44),
        panel3 = Color3.fromRGB(30, 42, 55),
        border = Color3.fromRGB(54, 76, 94),
        text = Color3.fromRGB(239, 247, 255),
        muted = Color3.fromRGB(145, 169, 190),
        accent = Color3.fromRGB(67, 170, 255),
        success = Color3.fromRGB(79, 211, 143),
        warning = Color3.fromRGB(255, 190, 83),
        danger = Color3.fromRGB(255, 92, 112)
    },

    Emerald = {
        bg = Color3.fromRGB(12, 18, 17),
        panel = Color3.fromRGB(17, 26, 24),
        panel2 = Color3.fromRGB(23, 35, 32),
        panel3 = Color3.fromRGB(30, 44, 40),
        border = Color3.fromRGB(52, 79, 71),
        text = Color3.fromRGB(240, 251, 247),
        muted = Color3.fromRGB(148, 178, 168),
        accent = Color3.fromRGB(57, 201, 151),
        success = Color3.fromRGB(86, 220, 146),
        warning = Color3.fromRGB(255, 193, 89),
        danger = Color3.fromRGB(255, 95, 115)
    },

    Crimson = {
        bg = Color3.fromRGB(19, 13, 16),
        panel = Color3.fromRGB(28, 19, 23),
        panel2 = Color3.fromRGB(38, 25, 30),
        panel3 = Color3.fromRGB(49, 32, 39),
        border = Color3.fromRGB(82, 53, 63),
        text = Color3.fromRGB(255, 242, 247),
        muted = Color3.fromRGB(188, 147, 162),
        accent = Color3.fromRGB(230, 70, 108),
        success = Color3.fromRGB(85, 211, 137),
        warning = Color3.fromRGB(255, 186, 80),
        danger = Color3.fromRGB(255, 80, 100)
    },

    Mono = {
        bg = Color3.fromRGB(14, 14, 14),
        panel = Color3.fromRGB(21, 21, 21),
        panel2 = Color3.fromRGB(29, 29, 29),
        panel3 = Color3.fromRGB(38, 38, 38),
        border = Color3.fromRGB(66, 66, 66),
        text = Color3.fromRGB(244, 244, 244),
        muted = Color3.fromRGB(158, 158, 158),
        accent = Color3.fromRGB(205, 205, 205),
        success = Color3.fromRGB(103, 215, 145),
        warning = Color3.fromRGB(255, 190, 84),
        danger = Color3.fromRGB(255, 95, 111)
    }
}

local Theme = Themes[Config.Theme] or Themes.Purple
local ThemeBindings = {}

local function bindTheme(object, propertyName, themeKey)
    table.insert(ThemeBindings, {
        object = object,
        property = propertyName,
        key = themeKey
    })

    pcall(function()
        object[propertyName] = Theme[themeKey]
    end)
end

local function applyTheme(name)
    if not Themes[name] then
        return false
    end

    Config.Theme = name
    Theme = Themes[name]

    for i = #ThemeBindings, 1, -1 do
        local binding = ThemeBindings[i]

        if not binding.object or binding.object.Parent == nil then
            table.remove(ThemeBindings, i)
        else
            pcall(function()
                binding.object[binding.property] = Theme[binding.key]
            end)
        end
    end

    saveConfig()
    pushLog("INFO", "Tema aplicado: " .. name)
    return true
end

--==================================================
-- ERROR GUARD / CIRCUIT BREAKER
--==================================================

local Guard = {
    Failures = {},
    Disabled = {},
    MaxFailures = 3
}

function Guard:Reset(name)
    if name then
        self.Failures[name] = nil
        self.Disabled[name] = nil
    else
        self.Failures = {}
        self.Disabled = {}
    end
end

function Guard:Run(name, callback, ...)
    name = tostring(name or "anonymous")

    if self.Disabled[name] then
        pushLog("WARN", "Funcao bloqueada pelo circuit breaker: " .. name)
        return false, "disabled"
    end

    if typeof(callback) ~= "function" then
        return false, "callback ausente"
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return callback(table.unpack(args, 1, args.n))
    end)

    if ok then
        self.Failures[name] = 0
        return true, result
    end

    local count = (self.Failures[name] or 0) + 1
    self.Failures[name] = count

    pushLog("ERROR", ("%s falhou (%d/%d): %s"):format(
        name,
        count,
        self.MaxFailures,
        tostring(result)
    ))

    if count >= self.MaxFailures then
        self.Disabled[name] = true
        pushLog("WARN", "Circuit breaker ativado para: " .. name)
    end

    return false, result
end

--==================================================
-- TASK MANAGER
--==================================================

local TaskManager = {
    Tasks = {}
}

function TaskManager:Stop(name)
    local token = self.Tasks[name]

    if token then
        token.cancelled = true
        self.Tasks[name] = nil
        pushLog("INFO", "Task parada: " .. tostring(name))
        return true
    end

    return false
end

function TaskManager:Start(name, callback)
    self:Stop(name)

    local token = {
        cancelled = false,
        name = name
    }

    self.Tasks[name] = token

    task.spawn(function()
        local ok, err = Guard:Run("Task:" .. tostring(name), callback, token)

        if not ok and err ~= "disabled" then
            pushLog("ERROR", "Task terminou com erro: " .. tostring(name))
        end

        if self.Tasks[name] == token then
            self.Tasks[name] = nil
        end
    end)

    pushLog("INFO", "Task iniciada: " .. tostring(name))
    return token
end

function TaskManager:StopAll()
    local count = 0

    for name, token in pairs(self.Tasks) do
        token.cancelled = true
        self.Tasks[name] = nil
        count = count + 1
    end

    pushLog("INFO", "Stop All executado. Tasks paradas: " .. tostring(count))
    return count
end

--==================================================
-- CHARACTER MANAGER
--==================================================

local CharacterState = {
    Character = nil,
    Humanoid = nil,
    Root = nil,
    Respawns = 0
}

local function refreshCharacter(character)
    CharacterState.Character = character

    if not character then
        CharacterState.Humanoid = nil
        CharacterState.Root = nil
        return
    end

    CharacterState.Humanoid = character:FindFirstChildOfClass("Humanoid")
    CharacterState.Root = character:FindFirstChild("HumanoidRootPart")

    task.spawn(function()
        if character.Parent then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                humanoid = character:WaitForChild("Humanoid", 8)
            end

            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then
                root = character:WaitForChild("HumanoidRootPart", 8)
            end

            if character == CharacterState.Character then
                CharacterState.Humanoid = humanoid
                CharacterState.Root = root
            end
        end
    end)
end

refreshCharacter(LocalPlayer.Character)

GlobalMaid:Give(LocalPlayer.CharacterAdded:Connect(function(character)
    CharacterState.Respawns = CharacterState.Respawns + 1
    refreshCharacter(character)
    pushLog("INFO", "CharacterAdded detectado.")
end))

GlobalMaid:Give(LocalPlayer.CharacterRemoving:Connect(function(character)
    if CharacterState.Character == character then
        refreshCharacter(nil)
    end
end))

--==================================================
-- GRAPHICS RESTORE MANAGER
--==================================================

local GraphicsBackup = {
    Objects = setmetatable({}, { __mode = "k" }),
    Lighting = nil,
    ActiveLow = false,
    ActiveEffects = false
}

local function backupObject(object)
    if GraphicsBackup.Objects[object] then
        return
    end

    if object:IsA("BasePart") then
        GraphicsBackup.Objects[object] = {
            kind = "BasePart",
            Material = object.Material,
            Reflectance = object.Reflectance,
            CastShadow = object.CastShadow
        }
    elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
        GraphicsBackup.Objects[object] = {
            kind = "Effect",
            Enabled = object.Enabled
        }
    end
end

local function backupLighting()
    if GraphicsBackup.Lighting then
        return
    end

    GraphicsBackup.Lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd
    }
end

local function applyObjectGraphics(object)
    if not object or object.Parent == nil then
        return
    end

    if object:IsA("BasePart") and GraphicsBackup.ActiveLow then
        backupObject(object)
        pcall(function()
            object.Material = Enum.Material.SmoothPlastic
            object.Reflectance = 0
            object.CastShadow = false
        end)
    elseif (object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam"))
        and (GraphicsBackup.ActiveEffects or GraphicsBackup.ActiveLow) then
        backupObject(object)
        pcall(function()
            object.Enabled = false
        end)
    end
end

local function refreshGraphicsMode()
    backupLighting()

    local descendants = workspace:GetDescendants()

    for index, object in ipairs(descendants) do
        applyObjectGraphics(object)

        if index % 350 == 0 then
            task.wait()
        end
    end

    if GraphicsBackup.ActiveLow then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        end)
    end
end

local function restoreGraphics()
    for object, data in pairs(GraphicsBackup.Objects) do
        if object and object.Parent then
            pcall(function()
                if data.kind == "BasePart" then
                    object.Material = data.Material
                    object.Reflectance = data.Reflectance
                    object.CastShadow = data.CastShadow
                elseif data.kind == "Effect" then
                    object.Enabled = data.Enabled
                end
            end)
        end
    end

    if GraphicsBackup.Lighting then
        pcall(function()
            Lighting.GlobalShadows = GraphicsBackup.Lighting.GlobalShadows
            Lighting.FogEnd = GraphicsBackup.Lighting.FogEnd
        end)
    end

    GraphicsBackup.Objects = setmetatable({}, { __mode = "k" })
end

local function setLowGraphics(enabled)
    GraphicsBackup.ActiveLow = enabled == true
    Config.LowGraphics = GraphicsBackup.ActiveLow

    if GraphicsBackup.ActiveLow or GraphicsBackup.ActiveEffects then
        task.spawn(refreshGraphicsMode)
    else
        restoreGraphics()
    end

    saveConfig()
end

local function setHideEffects(enabled)
    GraphicsBackup.ActiveEffects = enabled == true
    Config.HideEffects = GraphicsBackup.ActiveEffects

    if GraphicsBackup.ActiveLow or GraphicsBackup.ActiveEffects then
        task.spawn(refreshGraphicsMode)
    else
        restoreGraphics()
    end

    saveConfig()
end

GlobalMaid:Give(workspace.DescendantAdded:Connect(function(object)
    if GraphicsBackup.ActiveLow or GraphicsBackup.ActiveEffects then
        task.defer(function()
            applyObjectGraphics(object)
        end)
    end
end))

--==================================================
-- UI HELPERS
--==================================================

local function create(className, props)
    local object = Instance.new(className)

    for key, value in pairs(props or {}) do
        object[key] = value
    end

    return object
end

local function addCorner(object, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = object
    })
end

local function addStroke(object, themeKey, transparency, thickness)
    local stroke = create("UIStroke", {
        Transparency = transparency or 0.4,
        Thickness = thickness or 1,
        Parent = object
    })

    bindTheme(stroke, "Color", themeKey or "border")
    return stroke
end

local function tween(object, duration, properties)
    if Config.ReduceMotion then
        for propertyName, value in pairs(properties) do
            pcall(function()
                object[propertyName] = value
            end)
        end
        return nil
    end

    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.16,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),
        properties
    )

    animation:Play()
    return animation
end

local function debounce(seconds)
    local locked = false

    return function(callback)
        if locked then
            return
        end

        locked = true
        callback()

        task.delay(seconds or 0.2, function()
            locked = false
        end)
    end
end

--==================================================
-- GUI ROOT
--==================================================

local ScreenGui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = GuiParent
})

GlobalMaid:Give(function()
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
end)

local UIScale = create("UIScale", {
    Scale = tonumber(Config.Scale) or 1,
    Parent = ScreenGui
})

--==================================================
-- NOTIFICATIONS
--==================================================

local NotificationHost = create("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 12),
    Size = UDim2.fromOffset(330, 500),
    BackgroundTransparency = 1,
    Parent = ScreenGui
})

create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 8),
    Parent = NotificationHost
})

local function notify(title, message, kind, duration)
    kind = kind or "info"
    duration = duration or 3

    local colorKey = "accent"

    if kind == "success" then
        colorKey = "success"
    elseif kind == "warning" then
        colorKey = "warning"
    elseif kind == "danger" then
        colorKey = "danger"
    end

    local card = create("Frame", {
        Size = UDim2.fromOffset(320, 72),
        BorderSizePixel = 0,
        Parent = NotificationHost
    })

    bindTheme(card, "BackgroundColor3", "panel2")
    addCorner(card, 10)
    addStroke(card, colorKey, 0.3, 1)

    local stripe = create("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BorderSizePixel = 0,
        Parent = card
    })

    bindTheme(stripe, "BackgroundColor3", colorKey)
    addCorner(stripe, 10)

    local titleLabel = create("TextLabel", {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -40, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(title or "Ghost Hub"),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    bindTheme(titleLabel, "TextColor3", "text")

    local messageLabel = create("TextLabel", {
        Position = UDim2.fromOffset(14, 29),
        Size = UDim2.new(1, -40, 0, 32),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = tostring(message or ""),
        TextWrapped = true,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    bindTheme(messageLabel, "TextColor3", "muted")

    local close = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -7, 0, 7),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextSize = 15,
        Parent = card
    })

    bindTheme(close, "TextColor3", "muted")

    local progress = create("Frame", {
        Position = UDim2.new(0, 4, 1, -3),
        Size = UDim2.new(1, -4, 0, 3),
        BorderSizePixel = 0,
        Parent = card
    })

    bindTheme(progress, "BackgroundColor3", colorKey)

    local removed = false

    local function remove()
        if removed then
            return
        end

        removed = true

        tween(card, 0.15, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 0)
        })

        task.delay(Config.ReduceMotion and 0 or 0.17, function()
            if card.Parent then
                card:Destroy()
            end
        end)
    end

    close.MouseButton1Click:Connect(remove)

    card.BackgroundTransparency = 1
    card.Position = UDim2.fromOffset(18, 0)

    tween(card, 0.18, {
        BackgroundTransparency = 0,
        Position = UDim2.fromOffset(0, 0)
    })

    tween(progress, duration, {
        Size = UDim2.new(0, 0, 0, 3)
    })

    task.delay(duration, remove)
end

--==================================================
-- MAIN WINDOW
--==================================================

local Main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(
        0.5,
        tonumber(Config.PositionX) or 0,
        0.5,
        tonumber(Config.PositionY) or 0
    ),
    Size = UDim2.fromOffset(790, 490),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = ScreenGui
})

bindTheme(Main, "BackgroundColor3", "bg")
addCorner(Main, 14)
addStroke(Main, "border", 0.12, 1)

local Topbar = create("Frame", {
    Name = "Topbar",
    Size = UDim2.new(1, 0, 0, 54),
    BorderSizePixel = 0,
    Parent = Main
})

bindTheme(Topbar, "BackgroundColor3", "panel")

local Logo = create("Frame", {
    Position = UDim2.fromOffset(16, 18),
    Size = UDim2.fromOffset(18, 18),
    BorderSizePixel = 0,
    Parent = Topbar
})

bindTheme(Logo, "BackgroundColor3", "accent")
addCorner(Logo, 6)

local MainTitle = create("TextLabel", {
    Position = UDim2.fromOffset(44, 7),
    Size = UDim2.fromOffset(220, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "GHOST HUB",
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Topbar
})

bindTheme(MainTitle, "TextColor3", "text")

local BuildLabel = create("TextLabel", {
    Position = UDim2.fromOffset(44, 28),
    Size = UDim2.fromOffset(300, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = ("Professional V%s • Keyless"):format(VERSION),
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Topbar
})

bindTheme(BuildLabel, "TextColor3", "muted")

local StatusPill = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -136, 0.5, 0),
    Size = UDim2.fromOffset(100, 27),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamMedium,
    Text = "● START",
    TextSize = 10,
    Parent = Topbar
})

bindTheme(StatusPill, "BackgroundColor3", "panel3")
bindTheme(StatusPill, "TextColor3", "success")
addCorner(StatusPill, 20)

local SidebarToggle = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -100, 0.5, 0),
    Size = UDim2.fromOffset(31, 31),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "≡",
    TextSize = 16,
    Parent = Topbar
})

bindTheme(SidebarToggle, "BackgroundColor3", "panel3")
bindTheme(SidebarToggle, "TextColor3", "text")
addCorner(SidebarToggle, 8)

local MinimizeButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -62, 0.5, 0),
    Size = UDim2.fromOffset(31, 31),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "−",
    TextSize = 18,
    Parent = Topbar
})

bindTheme(MinimizeButton, "BackgroundColor3", "panel3")
bindTheme(MinimizeButton, "TextColor3", "text")
addCorner(MinimizeButton, 8)

local CloseButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -24, 0.5, 0),
    Size = UDim2.fromOffset(31, 31),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextSize = 18,
    Parent = Topbar
})

bindTheme(CloseButton, "BackgroundColor3", "panel3")
bindTheme(CloseButton, "TextColor3", "text")
addCorner(CloseButton, 8)

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = create("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(0, 54),
    Size = UDim2.new(0, 194, 1, -54),
    BorderSizePixel = 0,
    Parent = Main
})

bindTheme(Sidebar, "BackgroundColor3", "panel")

local SearchBox = create("TextBox", {
    Position = UDim2.fromOffset(11, 13),
    Size = UDim2.new(1, -22, 0, 36),
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderText = "Pesquisar função...",
    Text = "",
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Sidebar
})

bindTheme(SearchBox, "BackgroundColor3", "panel2")
bindTheme(SearchBox, "TextColor3", "text")
bindTheme(SearchBox, "PlaceholderColor3", "muted")
addCorner(SearchBox, 8)
addStroke(SearchBox, "border", 0.5, 1)

create("UIPadding", {
    PaddingLeft = UDim.new(0, 11),
    PaddingRight = UDim.new(0, 11),
    Parent = SearchBox
})

local TabHost = create("ScrollingFrame", {
    Position = UDim2.fromOffset(10, 61),
    Size = UDim2.new(1, -20, 1, -130),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = Sidebar
})

bindTheme(TabHost, "ScrollBarImageColor3", "border")

create("UIListLayout", {
    Padding = UDim.new(0, 6),
    Parent = TabHost
})

local UserCard = create("Frame", {
    Position = UDim2.new(0, 10, 1, -58),
    Size = UDim2.new(1, -20, 0, 48),
    BorderSizePixel = 0,
    Parent = Sidebar
})

bindTheme(UserCard, "BackgroundColor3", "panel2")
addCorner(UserCard, 9)

local UserInitial = create("TextLabel", {
    Position = UDim2.fromOffset(8, 8),
    Size = UDim2.fromOffset(32, 32),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = string.upper(string.sub(LocalPlayer.Name, 1, 1)),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Parent = UserCard
})

bindTheme(UserInitial, "BackgroundColor3", "accent")
addCorner(UserInitial, 8)

local UserDisplay = create("TextLabel", {
    Position = UDim2.fromOffset(48, 6),
    Size = UDim2.new(1, -56, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = LocalPlayer.DisplayName,
    TextSize = 10,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = UserCard
})

bindTheme(UserDisplay, "TextColor3", "text")

local UserName = create("TextLabel", {
    Position = UDim2.fromOffset(48, 24),
    Size = UDim2.new(1, -56, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "@" .. LocalPlayer.Name,
    TextSize = 9,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = UserCard
})

bindTheme(UserName, "TextColor3", "muted")

--==================================================
-- CONTENT
--==================================================

local Content = create("Frame", {
    Position = UDim2.fromOffset(194, 54),
    Size = UDim2.new(1, -194, 1, -54),
    BackgroundTransparency = 1,
    Parent = Main
})

local Pages = {}
local Tabs = {}
local Searchables = {}
local Actions = {}
local ActionOrder = {}
local CurrentPage = nil
local SidebarCollapsed = Config.CompactSidebar == true
local Minimized = false
local ScreenOpen = true

local function registerSearch(object, text, category)
    table.insert(Searchables, {
        object = object,
        text = string.lower(tostring(text or "")),
        category = string.lower(tostring(category or ""))
    })
end

local function createPage(name, titleText, subtitleText)
    local frame = create("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = Content
    })

    local title = create("TextLabel", {
        Position = UDim2.fromOffset(18, 13),
        Size = UDim2.new(1, -36, 0, 25),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = titleText or name,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })

    bindTheme(title, "TextColor3", "text")

    local subtitle = create("TextLabel", {
        Position = UDim2.fromOffset(18, 39),
        Size = UDim2.new(1, -36, 0, 17),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = subtitleText or "",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })

    bindTheme(subtitle, "TextColor3", "muted")

    local scroll = create("ScrollingFrame", {
        Position = UDim2.fromOffset(18, 67),
        Size = UDim2.new(1, -36, 1, -80),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = frame
    })

    bindTheme(scroll, "ScrollBarImageColor3", "border")

    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    Pages[name] = {
        Frame = frame,
        Scroll = scroll,
        Title = title,
        Subtitle = subtitle
    }

    return Pages[name]
end

local function createTab(name, label)
    local button = create("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = "   " .. (label or name),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabHost
    })

    bindTheme(button, "BackgroundColor3", "panel2")
    bindTheme(button, "TextColor3", "muted")
    addCorner(button, 8)

    Tabs[name] = button
    return button
end

local function setPage(name)
    if not Pages[name] then
        return false
    end

    CurrentPage = name
    Config.LastPage = name
    saveConfig()

    for pageName, data in pairs(Pages) do
        data.Frame.Visible = pageName == name
    end

    for tabName, button in pairs(Tabs) do
        local selected = tabName == name
        button:SetAttribute("Selected", selected)

        local bgKey = selected and "accent" or "panel2"
        local textKey = selected and "text" or "muted"

        local bg = Theme[bgKey]
        local tx = Theme[textKey]

        tween(button, 0.12, {
            BackgroundColor3 = bg,
            TextColor3 = tx
        })
    end

    return true
end

local function createSection(parent, titleText, description)
    local card = create("Frame", {
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = parent
    })

    bindTheme(card, "BackgroundColor3", "panel2")
    addCorner(card, 10)
    addStroke(card, "border", 0.5, 1)

    local inner = create("Frame", {
        Position = UDim2.fromOffset(12, 10),
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card
    })

    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        Parent = inner
    })

    local title = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 19),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(titleText or "Section"),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inner
    })

    bindTheme(title, "TextColor3", "text")

    if description and description ~= "" then
        local desc = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = tostring(description),
            TextWrapped = true,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = inner
        })

        bindTheme(desc, "TextColor3", "muted")
    end

    create("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundTransparency = 1,
        LayoutOrder = 99999,
        Parent = inner
    })

    return inner
end

--==================================================
-- FAVORITES / RECENT
--==================================================

local FavoritesSection = nil
local RecentSection = nil

local function arrayContains(array, value)
    for _, item in ipairs(array) do
        if item == value then
            return true
        end
    end
    return false
end

local function removeArrayValue(array, value)
    for index = #array, 1, -1 do
        if array[index] == value then
            table.remove(array, index)
        end
    end
end

local function addRecent(actionId)
    removeArrayValue(Config.Recent, actionId)
    table.insert(Config.Recent, 1, actionId)

    while #Config.Recent > 10 do
        table.remove(Config.Recent)
    end

    saveConfig()
end

local function toggleFavorite(actionId)
    if arrayContains(Config.Favorites, actionId) then
        removeArrayValue(Config.Favorites, actionId)
        saveConfig()
        return false
    end

    table.insert(Config.Favorites, actionId)
    saveConfig()
    return true
end

local function clearContainer(container)
    if not container then
        return
    end

    for _, child in ipairs(container:GetChildren()) do
        if child:GetAttribute("GhostDynamic") == true then
            child:Destroy()
        end
    end
end

--==================================================
-- COMPONENTS
--==================================================

local function createActionButton(parent, options)
    options = options or {}

    local id = tostring(options.id or options.text or HttpService:GenerateGUID(false))
    local text = tostring(options.text or id)
    local category = tostring(options.category or "General")
    local callback = options.callback
    local accent = options.accent == true
    local allowFavorite = options.favorite ~= false

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 39),
        BorderSizePixel = 0,
        Parent = parent
    })

    bindTheme(row, "BackgroundColor3", accent and "accent" or "panel3")
    addCorner(row, 8)
    registerSearch(row, text, category)

    local button = create("TextButton", {
        Size = allowFavorite and UDim2.new(1, -39, 1, 0) or UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = "   " .. text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    bindTheme(button, "TextColor3", "text")

    local favoriteButton = nil

    if allowFavorite then
        favoriteButton = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(30, 30),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            Text = arrayContains(Config.Favorites, id) and "★" or "☆",
            TextSize = 15,
            Parent = row
        })

        bindTheme(favoriteButton, "TextColor3", "muted")

        favoriteButton.MouseButton1Click:Connect(function()
            local enabled = toggleFavorite(id)
            favoriteButton.Text = enabled and "★" or "☆"

            if enabled then
                notify("Favoritos", text .. " adicionado.", "success", 2)
            else
                notify("Favoritos", text .. " removido.", "info", 2)
            end
        end)
    end

    local clickGuard = debounce(0.25)

    button.MouseButton1Click:Connect(function()
        clickGuard(function()
            button.Text = "   Executando..."

            addRecent(id)

            local ok, result = Guard:Run("Action:" .. id, callback)

            if not ok then
                notify("Erro", "Falha em " .. text .. ". Veja Logs.", "danger", 4)
            elseif type(result) == "string" and result ~= "" then
                notify(text, result, "success", 3)
            end

            button.Text = "   " .. text
        end)
    end)

    button.MouseEnter:Connect(function()
        tween(row, 0.1, {
            BackgroundTransparency = 0.08
        })
    end)

    button.MouseLeave:Connect(function()
        tween(row, 0.1, {
            BackgroundTransparency = 0
        })
    end)

    Actions[id] = {
        id = id,
        text = text,
        category = category,
        callback = callback
    }

    if not arrayContains(ActionOrder, id) then
        table.insert(ActionOrder, id)
    end

    return row
end

local function createToggle(parent, options)
    options = options or {}

    local text = tostring(options.text or "Toggle")
    local value = options.default == true
    local callback = options.callback
    local settingKey = options.settingKey

    if settingKey and Config[settingKey] ~= nil then
        value = Config[settingKey] == true
    end

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BorderSizePixel = 0,
        Parent = parent
    })

    bindTheme(row, "BackgroundColor3", "panel3")
    addCorner(row, 8)
    registerSearch(row, text, options.category)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -74, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    bindTheme(label, "TextColor3", "text")

    local switch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Parent = row
    })

    addCorner(switch, 20)

    local knob = create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        BorderSizePixel = 0,
        Parent = switch
    })

    bindTheme(knob, "BackgroundColor3", "text")
    addCorner(knob, 20)

    local function render()
        local color = value and Theme.accent or Color3.fromRGB(67, 70, 84)

        tween(switch, 0.13, {
            BackgroundColor3 = color
        })

        tween(knob, 0.13, {
            Position = value
                and UDim2.new(1, -20, 0.5, -8)
                or UDim2.new(0, 4, 0.5, -8)
        })
    end

    render()

    switch.MouseButton1Click:Connect(function()
        local previous = value
        value = not value
        render()

        local ok = true

        if callback then
            ok = Guard:Run("Toggle:" .. text, callback, value)
        end

        if not ok then
            value = previous
            render()
            notify("Erro", "Nao foi possivel alterar " .. text, "danger", 3)
            return
        end

        if settingKey then
            Config[settingKey] = value
            saveConfig()
        end
    end)

    return {
        Object = row,
        Get = function()
            return value
        end,
        Set = function(newValue, fire)
            value = newValue == true
            render()

            if settingKey then
                Config[settingKey] = value
                saveConfig()
            end

            if fire and callback then
                Guard:Run("Toggle:" .. text, callback, value)
            end
        end
    }
end

local function createSlider(parent, options)
    options = options or {}

    local text = tostring(options.text or "Slider")
    local minValue = tonumber(options.min) or 0
    local maxValue = tonumber(options.max) or 100
    local defaultValue = tonumber(options.default) or minValue
    local settingKey = options.settingKey

    if settingKey and tonumber(Config[settingKey]) then
        defaultValue = tonumber(Config[settingKey])
    end

    local value = math.clamp(defaultValue, minValue, maxValue)

    local box = create("Frame", {
        Size = UDim2.new(1, 0, 0, 61),
        BorderSizePixel = 0,
        Parent = parent
    })

    bindTheme(box, "BackgroundColor3", "panel3")
    addCorner(box, 8)
    registerSearch(box, text, options.category)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -96, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = box
    })

    bindTheme(label, "TextColor3", "text")

    local valueBox = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 5),
        Size = UDim2.fromOffset(68, 21),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamBold,
        Text = tostring(value),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = box
    })

    bindTheme(valueBox, "BackgroundColor3", "panel2")
    bindTheme(valueBox, "TextColor3", "accent")
    addCorner(valueBox, 6)

    local bar = create("Frame", {
        Position = UDim2.fromOffset(12, 39),
        Size = UDim2.new(1, -24, 0, 8),
        BorderSizePixel = 0,
        Parent = box
    })

    bindTheme(bar, "BackgroundColor3", "panel2")
    addCorner(bar, 20)

    local fill = create("Frame", {
        BorderSizePixel = 0,
        Parent = bar
    })

    bindTheme(fill, "BackgroundColor3", "accent")
    addCorner(fill, 20)

    local dragging = false
    local maid = Maid.new()
    GlobalMaid:Give(maid)

    local function apply(newValue, fire)
        value = math.clamp(
            math.floor((tonumber(newValue) or minValue) + 0.5),
            minValue,
            maxValue
        )

        local alpha = (value - minValue) / math.max(1, maxValue - minValue)

        valueBox.Text = tostring(value)
        fill.Size = UDim2.new(alpha, 0, 1, 0)

        if settingKey then
            Config[settingKey] = value
            saveConfig()
        end

        if fire and options.callback then
            Guard:Run("Slider:" .. text, options.callback, value)
        end
    end

    local function setFromX(x)
        local alpha = math.clamp(
            (x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X),
            0,
            1
        )

        local newValue = minValue + ((maxValue - minValue) * alpha)
        apply(newValue, true)
    end

    apply(value, false)

    maid:Give(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end))

    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            setFromX(input.Position.X)
        end
    end))

    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    maid:Give(valueBox.FocusLost:Connect(function()
        apply(valueBox.Text, true)
    end))

    return {
        Object = box,
        Get = function()
            return value
        end,
        Set = function(newValue, fire)
            apply(newValue, fire)
        end
    }
end

local function createDropdown(parent, options)
    options = options or {}

    local text = tostring(options.text or "Dropdown")
    local values = options.values or { "Opcao 1" }
    local index = tonumber(options.defaultIndex) or 1
    index = math.clamp(index, 1, math.max(1, #values))

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = parent
    })

    bindTheme(holder, "BackgroundColor3", "panel3")
    addCorner(holder, 8)
    registerSearch(holder, text, options.category)

    local mainButton = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    bindTheme(mainButton, "TextColor3", "text")

    local list = create("Frame", {
        Position = UDim2.fromOffset(8, 40),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder
    })

    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = list
    })

    local open = false

    local function refresh()
        mainButton.Text = ("   %s   •   %s"):format(
            text,
            tostring(values[index] or "")
        )
    end

    local function setOpen(value)
        open = value == true

        local target = 40

        if open then
            target = 48 + (#values * 32)
        end

        tween(holder, 0.15, {
            Size = UDim2.new(1, 0, 0, target)
        })
    end

    for valueIndex, option in ipairs(values) do
        local optionButton = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            Text = "   " .. tostring(option),
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = list
        })

        bindTheme(optionButton, "BackgroundColor3", "panel2")
        bindTheme(optionButton, "TextColor3", "muted")
        addCorner(optionButton, 6)

        optionButton.MouseButton1Click:Connect(function()
            index = valueIndex
            refresh()
            setOpen(false)

            if options.callback then
                Guard:Run(
                    "Dropdown:" .. text,
                    options.callback,
                    values[index],
                    index
                )
            end
        end)
    end

    mainButton.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)

    refresh()

    return {
        Object = holder,
        Get = function()
            return values[index], index
        end
    }
end

local function createInfo(parent, labelText, getter)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BorderSizePixel = 0,
        Parent = parent
    })

    bindTheme(row, "BackgroundColor3", "panel3")
    addCorner(row, 8)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.46, -12, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = tostring(labelText),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    bindTheme(label, "TextColor3", "muted")

    local valueLabel = create("TextLabel", {
        Position = UDim2.new(0.46, 0, 0, 0),
        Size = UDim2.new(0.54, -12, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "...",
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row
    })

    bindTheme(valueLabel, "TextColor3", "text")

    local token = {
        cancelled = false
    }

    GlobalMaid:Give(function()
        token.cancelled = true
    end)

    task.spawn(function()
        while not token.cancelled and row.Parent and ScreenGui.Parent do
            local ok, result = Guard:Run("Info:" .. tostring(labelText), getter)

            if ok then
                valueLabel.Text = tostring(result)
            else
                valueLabel.Text = "N/A"
            end

            task.wait(1)
        end
    end)

    return row
end

--==================================================
-- CREATE PAGES / TABS
--==================================================

local PageDefinitions = {
    { "Home", "Home", "Dashboard, status e ações rápidas." },
    { "Favorites", "Favorites", "Suas ações favoritas." },
    { "Recent", "Recent", "Ações usadas recentemente." },
    { "Farm", "Farm", "Estrutura preparada para módulos autorizados." },
    { "Bosses", "Bosses", "Organização de bosses e status." },
    { "Raids", "Raids", "Atividades, progresso e temporizadores." },
    { "Fruits", "Fruits", "Filtros e utilidades visuais." },
    { "Sea", "Sea Events", "Acompanhamento de eventos marítimos." },
    { "Race", "Race / Progress", "Status e checklist de progressão." },
    { "Navigation", "Navigation", "Pontos e navegação autorizada." },
    { "Visual", "Visual", "Desempenho, gráficos e HUD." },
    { "Server", "Server", "Informações do servidor atual." },
    { "Logs", "Logs", "Eventos, avisos e erros do painel." },
    { "Settings", "Settings", "Aparência, atalhos e manutenção." },
    { "About", "About", "Versão, build e capacidades." }
}

for _, definition in ipairs(PageDefinitions) do
    createPage(definition[1], definition[2], definition[3])
    createTab(definition[1], definition[2])
end

for name, button in pairs(Tabs) do
    button.MouseButton1Click:Connect(function()
        setPage(name)
    end)

    button.MouseEnter:Connect(function()
        if not button:GetAttribute("Selected") then
            tween(button, 0.1, {
                BackgroundColor3 = Theme.panel3
            })
        end
    end)

    button.MouseLeave:Connect(function()
        if not button:GetAttribute("Selected") then
            tween(button, 0.1, {
                BackgroundColor3 = Theme.panel2
            })
        end
    end)
end

--==================================================
-- FAVORITES / RECENT REFRESH
--==================================================

local function renderActionReference(parent, actionId, prefix)
    local action = Actions[actionId]

    if not action then
        return
    end

    local row = createActionButton(parent, {
        id = prefix .. ":" .. actionId,
        text = action.text,
        category = action.category,
        favorite = false,
        callback = function()
            addRecent(actionId)
            return action.callback()
        end
    })

    row:SetAttribute("GhostDynamic", true)
end

local function refreshFavorites()
    if not FavoritesSection then
        return
    end

    clearContainer(FavoritesSection)

    if #Config.Favorites == 0 then
        local empty = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Nenhum favorito ainda. Use a estrela nos botões.",
            TextSize = 10,
            Parent = FavoritesSection
        })

        bindTheme(empty, "TextColor3", "muted")
        empty:SetAttribute("GhostDynamic", true)
        return
    end

    for _, actionId in ipairs(Config.Favorites) do
        renderActionReference(FavoritesSection, actionId, "fav")
    end
end

local function refreshRecent()
    if not RecentSection then
        return
    end

    clearContainer(RecentSection)

    if #Config.Recent == 0 then
        local empty = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = "Nenhuma ação executada nesta configuração.",
            TextSize = 10,
            Parent = RecentSection
        })

        bindTheme(empty, "TextColor3", "muted")
        empty:SetAttribute("GhostDynamic", true)
        return
    end

    for _, actionId in ipairs(Config.Recent) do
        renderActionReference(RecentSection, actionId, "recent")
    end
end

--==================================================
-- HOME
--==================================================

do
    local scroll = Pages.Home.Scroll

    local status = createSection(
        scroll,
        "Live Status",
        "Leituras locais atualizadas automaticamente."
    )

    createInfo(status, "Jogador", function()
        return LocalPlayer.Name
    end)

    createInfo(status, "Display", function()
        return LocalPlayer.DisplayName
    end)

    createInfo(status, "PlaceId", function()
        return game.PlaceId
    end)

    createInfo(status, "JobId", function()
        return game.JobId ~= "" and game.JobId or "Studio/Local"
    end)

    createInfo(status, "Players", function()
        return #Players:GetPlayers()
    end)

    createInfo(status, "Respawns", function()
        return CharacterState.Respawns
    end)

    local character = createSection(
        scroll,
        "Character",
        "Dados do personagem atual."
    )

    createInfo(character, "Vida", function()
        local humanoid = CharacterState.Humanoid

        if not humanoid then
            return "N/A"
        end

        return ("%d / %d"):format(
            math.floor(humanoid.Health),
            math.floor(humanoid.MaxHealth)
        )
    end)

    createInfo(character, "WalkSpeed", function()
        local humanoid = CharacterState.Humanoid
        return humanoid and humanoid.WalkSpeed or "N/A"
    end)

    createInfo(character, "JumpPower", function()
        local humanoid = CharacterState.Humanoid
        return humanoid and humanoid.JumpPower or "N/A"
    end)

    local quick = createSection(
        scroll,
        "Quick Actions",
        "Ações utilitárias locais."
    )

    createActionButton(quick, {
        id = "quick.notification",
        text = "Testar notificações",
        category = "Interface",
        accent = true,
        callback = function()
            notify(
                "Ghost Hub",
                "Notificações funcionando corretamente.",
                "success",
                3
            )
            return "Teste concluído."
        end
    })

    createActionButton(quick, {
        id = "quick.center",
        text = "Centralizar painel",
        category = "Interface",
        callback = function()
            Main.Position = UDim2.new(0.5, 0, 0.5, 0)
            Config.PositionX = 0
            Config.PositionY = 0
            saveConfig()
            return "Painel centralizado."
        end
    })

    createActionButton(quick, {
        id = "quick.stopall",
        text = "Stop All",
        category = "Runtime",
        callback = function()
            local count = TaskManager:StopAll()
            return "Tasks paradas: " .. tostring(count)
        end
    })

    createActionButton(quick, {
        id = "quick.resetguard",
        text = "Resetar circuit breaker",
        category = "Runtime",
        callback = function()
            Guard:Reset()
            return "Proteções de erro resetadas."
        end
    })
end

--==================================================
-- FAVORITES / RECENT
--==================================================

FavoritesSection = createSection(
    Pages.Favorites.Scroll,
    "Favorites",
    "Ações marcadas com estrela."
)

RecentSection = createSection(
    Pages.Recent.Scroll,
    "Recent",
    "Últimas ações executadas."
)

--==================================================
-- MODULE PLACEHOLDERS
--==================================================

local function addModulePage(pageName, titleText, items)
    local section = createSection(
        Pages[pageName].Scroll,
        titleText,
        "Interface pronta. Conecte aqui somente lógica autorizada do seu ambiente."
    )

    for _, item in ipairs(items) do
        local id = pageName .. "." .. string.gsub(string.lower(item), "%s+", "_")

        createActionButton(section, {
            id = id,
            text = item,
            category = pageName,
            callback = function()
                notify(
                    "Módulo não conectado",
                    "A interface está pronta, mas esta lógica operacional não foi incluída.",
                    "warning",
                    4
                )
                return nil
            end
        })
    end
end

addModulePage("Farm", "Farm Controls", {
    "Selecionar alvo",
    "Selecionar missão",
    "Método de farm",
    "Controle de distância",
    "Controle de velocidade",
    "Pausar rotina",
    "Retomar rotina",
    "Status da rotina"
})

addModulePage("Bosses", "Boss Controls", {
    "Selecionar boss",
    "Status do boss",
    "Fila de bosses",
    "Prioridade",
    "Aviso de spawn",
    "Histórico da sessão"
})

addModulePage("Raids", "Raid Controls", {
    "Selecionar atividade",
    "Status atual",
    "Contador de progresso",
    "Temporizador",
    "Aviso de conclusão",
    "Histórico"
})

addModulePage("Fruits", "Fruit Tools", {
    "Filtro de frutas",
    "Lista detectada",
    "Ordenar por nome",
    "Ordenar por distância",
    "Favoritos",
    "Alertas visuais"
})

addModulePage("Sea", "Sea Event Tools", {
    "Painel de eventos",
    "Status do evento",
    "Alertas",
    "Distância",
    "Temporizador",
    "Histórico de eventos"
})

addModulePage("Race", "Progress Tools", {
    "Status de progressão",
    "Checklist",
    "Requisitos",
    "Temporizadores",
    "Indicadores visuais",
    "Histórico da sessão"
})

addModulePage("Navigation", "Navigation", {
    "Ponto 01",
    "Ponto 02",
    "Ponto 03",
    "Ponto 04",
    "Ponto 05",
    "Ponto 06"
})

--==================================================
-- VISUAL
--==================================================

do
    local scroll = Pages.Visual.Scroll

    local performance = createSection(
        scroll,
        "Performance",
        "Ajustes locais com restauração das propriedades originais."
    )

    createToggle(performance, {
        text = "Low Graphics",
        category = "Visual",
        settingKey = "LowGraphics",
        default = Config.LowGraphics,
        callback = function(enabled)
            setLowGraphics(enabled)

            notify(
                "Visual",
                enabled
                    and "Low Graphics ativado."
                    or "Low Graphics restaurado.",
                "success",
                3
            )
        end
    })

    createToggle(performance, {
        text = "Ocultar efeitos locais",
        category = "Visual",
        settingKey = "HideEffects",
        default = Config.HideEffects,
        callback = function(enabled)
            setHideEffects(enabled)

            notify(
                "Visual",
                enabled
                    and "Efeitos ocultados."
                    or "Efeitos restaurados.",
                "success",
                3
            )
        end
    })

    local hud = createSection(
        scroll,
        "HUD",
        "Escala e posicionamento."
    )

    createSlider(hud, {
        text = "Escala da interface",
        min = 75,
        max = 125,
        default = math.floor((tonumber(Config.Scale) or 1) * 100),
        callback = function(value)
            Config.Scale = value / 100
            UIScale.Scale = Config.Scale
            saveConfig()
        end
    })

    createActionButton(hud, {
        id = "visual.center",
        text = "Centralizar painel",
        category = "Visual",
        callback = function()
            Main.Position = UDim2.new(0.5, 0, 0.5, 0)
            Config.PositionX = 0
            Config.PositionY = 0
            saveConfig()
            return "Painel centralizado."
        end
    })

    createToggle(hud, {
        text = "Reduzir animações",
        category = "Visual",
        settingKey = "ReduceMotion",
        default = Config.ReduceMotion,
        callback = function(enabled)
            Config.ReduceMotion = enabled
            saveConfig()
        end
    })
end

--==================================================
-- SERVER
--==================================================

do
    local scroll = Pages.Server.Scroll

    local info = createSection(
        scroll,
        "Server Info",
        "Informações do servidor atual."
    )

    createInfo(info, "PlaceId", function()
        return game.PlaceId
    end)

    createInfo(info, "JobId", function()
        return game.JobId ~= "" and game.JobId or "Studio/Local"
    end)

    createInfo(info, "Players", function()
        return #Players:GetPlayers()
    end)

    createInfo(info, "Ping", function()
        local ok, value = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)

        return ok and value or "N/A"
    end)

    createInfo(info, "Memory", function()
        local ok, value = pcall(function()
            return Stats:GetTotalMemoryUsageMb()
        end)

        if not ok then
            return "N/A"
        end

        return ("%.1f MB"):format(value)
    end)

    local actions = createSection(
        scroll,
        "Actions",
        "Utilidades seguras do cliente."
    )

    createActionButton(actions, {
        id = "server.copyjob",
        text = "Copiar JobId",
        category = "Server",
        callback = function()
            if not Capabilities.setclipboard then
                return "setclipboard não está disponível."
            end

            setclipboard(game.JobId)
            return "JobId copiado."
        end
    })

    createActionButton(actions, {
        id = "server.copyplace",
        text = "Copiar PlaceId",
        category = "Server",
        callback = function()
            if not Capabilities.setclipboard then
                return "setclipboard não está disponível."
            end

            setclipboard(tostring(game.PlaceId))
            return "PlaceId copiado."
        end
    })
end

--==================================================
-- LOG PAGE
--==================================================

do
    local scroll = Pages.Logs.Scroll

    local controls = createSection(
        scroll,
        "Log Controls",
        "Histórico de eventos do painel."
    )

    createActionButton(controls, {
        id = "logs.clear",
        text = "Limpar logs",
        category = "Logs",
        favorite = false,
        callback = function()
            Logs.Items = {}
            pushLog("INFO", "Logs limpos.")
            return "Logs limpos."
        end
    })

    createActionButton(controls, {
        id = "logs.copy",
        text = "Copiar logs",
        category = "Logs",
        favorite = false,
        callback = function()
            if not Capabilities.setclipboard then
                return "setclipboard não está disponível."
            end

            local lines = {}

            for _, entry in ipairs(Logs.Items) do
                table.insert(
                    lines,
                    ("[%s][%s] %s"):format(
                        entry.time,
                        entry.level,
                        entry.message
                    )
                )
            end

            setclipboard(table.concat(lines, "\n"))
            return "Logs copiados."
        end
    })

    Logs.ListParent = createSection(
        scroll,
        "Entries",
        "Atualizado automaticamente."
    )

    task.spawn(function()
        while ScreenGui.Parent do
            if Pages.Logs.Frame.Visible and Logs.ListParent then
                clearContainer(Logs.ListParent)

                local startIndex = math.max(1, #Logs.Items - 39)

                for index = startIndex, #Logs.Items do
                    local entry = Logs.Items[index]

                    local row = create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1,
                        Font = Enum.Font.Code,
                        Text = ("[%s][%s] %s"):format(
                            entry.time,
                            entry.level,
                            entry.message
                        ),
                        TextWrapped = true,
                        TextSize = 9,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = Logs.ListParent
                    })

                    row:SetAttribute("GhostDynamic", true)

                    if entry.level == "ERROR" then
                        bindTheme(row, "TextColor3", "danger")
                    elseif entry.level == "WARN" then
                        bindTheme(row, "TextColor3", "warning")
                    else
                        bindTheme(row, "TextColor3", "muted")
                    end
                end
            end

            task.wait(1)
        end
    end)
end

--==================================================
-- COMMANDS
--==================================================

local Commands = {}

local function registerCommand(name, callback)
    Commands[string.lower(name)] = callback
end

local function runCommand(raw)
    raw = tostring(raw or "")

    if string.sub(raw, 1, 1) == "/" then
        raw = string.sub(raw, 2)
    end

    local parts = {}

    for token in string.gmatch(raw, "%S+") do
        table.insert(parts, token)
    end

    local commandName = string.lower(parts[1] or "")
    table.remove(parts, 1)

    local callback = Commands[commandName]

    if not callback then
        notify(
            "Comando",
            "Comando desconhecido: " .. commandName,
            "warning",
            3
        )
        return false
    end

    local ok, result = Guard:Run(
        "Command:" .. commandName,
        callback,
        parts
    )

    if not ok then
        notify("Comando", "Falha ao executar.", "danger", 3)
        return false
    end

    if type(result) == "string" and result ~= "" then
        notify("Comando", result, "success", 3)
    end

    return true
end

registerCommand("page", function(args)
    local name = args[1]

    if not name then
        return "Uso: /page Home"
    end

    for pageName in pairs(Pages) do
        if string.lower(pageName) == string.lower(name) then
            setPage(pageName)
            return "Página: " .. pageName
        end
    end

    return "Página não encontrada."
end)

registerCommand("scale", function(args)
    local value = tonumber(args[1])

    if not value then
        return "Uso: /scale 90"
    end

    value = math.clamp(value, 75, 125)
    Config.Scale = value / 100
    UIScale.Scale = Config.Scale
    saveConfig()

    return "Escala: " .. tostring(value) .. "%"
end)

registerCommand("theme", function(args)
    local requested = string.lower(table.concat(args, " "))

    for name in pairs(Themes) do
        if string.lower(name) == requested then
            applyTheme(name)
            return "Tema: " .. name
        end
    end

    return "Temas: Purple, Ocean, Emerald, Crimson, Mono"
end)

registerCommand("stopall", function()
    local count = TaskManager:StopAll()
    return "Tasks paradas: " .. tostring(count)
end)

registerCommand("clearlogs", function()
    Logs.Items = {}
    pushLog("INFO", "Logs limpos via comando.")
    return "Logs limpos."
end)

registerCommand("center", function()
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Config.PositionX = 0
    Config.PositionY = 0
    saveConfig()

    return "Painel centralizado."
end)

registerCommand("resetguard", function()
    Guard:Reset()
    return "Circuit breaker resetado."
end)

--==================================================
-- SETTINGS
--==================================================

do
    local scroll = Pages.Settings.Scroll

    local appearance = createSection(
        scroll,
        "Appearance",
        "Tema, escala e animações."
    )

    createDropdown(appearance, {
        text = "Tema",
        category = "Settings",
        values = {
            "Purple",
            "Ocean",
            "Emerald",
            "Crimson",
            "Mono"
        },
        defaultIndex = 1,
        callback = function(value)
            applyTheme(value)
            notify("Tema", value .. " aplicado.", "success", 2)
        end
    })

    createSlider(appearance, {
        text = "Escala",
        min = 75,
        max = 125,
        default = math.floor((tonumber(Config.Scale) or 1) * 100),
        callback = function(value)
            Config.Scale = value / 100
            UIScale.Scale = Config.Scale
            saveConfig()
        end
    })

    createToggle(appearance, {
        text = "Reduzir animações",
        category = "Settings",
        settingKey = "ReduceMotion",
        default = Config.ReduceMotion,
        callback = function(enabled)
            Config.ReduceMotion = enabled
            saveConfig()
        end
    })

    createToggle(appearance, {
        text = "Sidebar compacta",
        category = "Settings",
        settingKey = "CompactSidebar",
        default = Config.CompactSidebar,
        callback = function(enabled)
            Config.CompactSidebar = enabled
            SidebarCollapsed = enabled
            saveConfig()

            if SidebarCollapsed then
                tween(Sidebar, 0.16, {
                    Size = UDim2.new(0, 64, 1, -54)
                })

                tween(Content, 0.16, {
                    Position = UDim2.fromOffset(64, 54),
                    Size = UDim2.new(1, -64, 1, -54)
                })

                SearchBox.Visible = false
                UserCard.Visible = false

                for _, button in pairs(Tabs) do
                    button.Text = string.sub(button.Name, 1, 1)
                    button.TextXAlignment = Enum.TextXAlignment.Center
                end
            else
                tween(Sidebar, 0.16, {
                    Size = UDim2.new(0, 194, 1, -54)
                })

                tween(Content, 0.16, {
                    Position = UDim2.fromOffset(194, 54),
                    Size = UDim2.new(1, -194, 1, -54)
                })

                SearchBox.Visible = true
                UserCard.Visible = true

                for name, button in pairs(Tabs) do
                    button.Text = "   " .. (
                        Pages[name] and Pages[name].Title.Text or name
                    )
                    button.TextXAlignment = Enum.TextXAlignment.Left
                end
            end
        end
    })

    local commandSection = createSection(
        scroll,
        "Command Palette",
        "Comandos: /page, /scale, /theme, /stopall, /clearlogs, /center, /resetguard"
    )

    local CommandBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 38),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Code,
        PlaceholderText = "/page Home",
        Text = "",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = commandSection
    })

    bindTheme(CommandBox, "BackgroundColor3", "panel3")
    bindTheme(CommandBox, "TextColor3", "text")
    bindTheme(CommandBox, "PlaceholderColor3", "muted")
    addCorner(CommandBox, 8)

    create("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = CommandBox
    })

    GlobalMaid:Give(CommandBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and CommandBox.Text ~= "" then
            local raw = CommandBox.Text
            CommandBox.Text = ""
            runCommand(raw)
        end
    end))

    local maintenance = createSection(
        scroll,
        "Maintenance",
        "Diagnóstico e recuperação."
    )

    createActionButton(maintenance, {
        id = "settings.selftest",
        text = "Executar Self-Test",
        category = "Settings",
        favorite = false,
        callback = function()
            local passed = 0
            local failed = 0
            local results = {}

            local function test(name, condition)
                if condition then
                    passed = passed + 1
                    table.insert(results, "PASS " .. name)
                else
                    failed = failed + 1
                    table.insert(results, "FAIL " .. name)
                end
            end

            test("ScreenGui", ScreenGui.Parent ~= nil)
            test("Main", Main.Parent ~= nil)
            test("Pages", next(Pages) ~= nil)
            test("Tabs", next(Tabs) ~= nil)
            test("Theme", Themes[Config.Theme] ~= nil)
            test("Player", LocalPlayer ~= nil)
            test("Character manager", CharacterState ~= nil)

            local jsonOk = pcall(function()
                local encoded = HttpService:JSONEncode(Config)
                HttpService:JSONDecode(encoded)
            end)

            test("Config JSON", jsonOk)

            for _, line in ipairs(results) do
                pushLog(
                    string.sub(line, 1, 4) == "PASS" and "INFO" or "ERROR",
                    "Self-Test: " .. line
                )
            end

            notify(
                "Self-Test",
                ("Pass: %d | Fail: %d"):format(passed, failed),
                failed == 0 and "success" or "warning",
                5
            )

            return ("Pass: %d | Fail: %d"):format(passed, failed)
        end
    })

    createActionButton(maintenance, {
        id = "settings.stopall",
        text = "Stop All Tasks",
        category = "Settings",
        favorite = false,
        callback = function()
            local count = TaskManager:StopAll()
            return "Tasks paradas: " .. tostring(count)
        end
    })

    createActionButton(maintenance, {
        id = "settings.resetguard",
        text = "Resetar proteções de erro",
        category = "Settings",
        favorite = false,
        callback = function()
            Guard:Reset()
            return "Circuit breaker resetado."
        end
    })

    createActionButton(maintenance, {
        id = "settings.resetconfig",
        text = "Resetar configurações",
        category = "Settings",
        favorite = false,
        callback = function()
            Config = deepCopy(Defaults)
            saveConfig()

            notify(
                "Settings",
                "Configurações resetadas. Reabra o painel para aplicar tudo.",
                "warning",
                5
            )

            return "Configuração padrão restaurada."
        end
    })

    createActionButton(maintenance, {
        id = "settings.deleteconfig",
        text = "Apagar arquivo de configuração",
        category = "Settings",
        favorite = false,
        callback = function()
            if not (Capabilities.delfile and Capabilities.isfile) then
                return "API de arquivo indisponível."
            end

            local existsOk, exists = pcall(isfile, CONFIG_FILE)

            if existsOk and exists then
                pcall(delfile, CONFIG_FILE)
                return "Arquivo de configuração apagado."
            end

            return "Nenhum arquivo de configuração encontrado."
        end
    })
end

--==================================================
-- ABOUT
--==================================================

do
    local scroll = Pages.About.Scroll

    local version = createSection(
        scroll,
        "Build",
        "Informações da versão atual."
    )

    createInfo(version, "Version", function()
        return VERSION
    end)

    createInfo(version, "Build", function()
        return BUILD
    end)

    createInfo(version, "Config persistence", function()
        return Capabilities.writefile and "Disponível" or "Indisponível"
    end)

    createInfo(version, "Clipboard", function()
        return Capabilities.setclipboard and "Disponível" or "Indisponível"
    end)

    createInfo(version, "GUI parent", function()
        return GuiParent.Name
    end)

    local architecture = createSection(
        scroll,
        "Architecture",
        "Recursos internos ativos."
    )

    createInfo(architecture, "Theme bindings", function()
        return #ThemeBindings
    end)

    createInfo(architecture, "Actions", function()
        local count = 0
        for _ in pairs(Actions) do
            count = count + 1
        end
        return count
    end)

    createInfo(architecture, "Active tasks", function()
        local count = 0
        for _ in pairs(TaskManager.Tasks) do
            count = count + 1
        end
        return count
    end)

    createInfo(architecture, "Logs", function()
        return #Logs.Items
    end)
end

--==================================================
-- SEARCH
--==================================================

GlobalMaid:Give(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(SearchBox.Text)

    for _, item in ipairs(Searchables) do
        if item.object and item.object.Parent then
            local matches = query == ""
                or string.find(item.text, query, 1, true) ~= nil
                or string.find(item.category, query, 1, true) ~= nil

            item.object.Visible = matches
        end
    end
end))

--==================================================
-- WINDOW DRAG
--==================================================

do
    local dragging = false
    local dragStart = nil
    local startPosition = nil
    local activeInput = nil

    GlobalMaid:Give(Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
            activeInput = input
        end
    end))

    GlobalMaid:Give(Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end))

    GlobalMaid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == activeInput then
            local delta = input.Position - dragStart

            Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))

    GlobalMaid:Give(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false

            Config.PositionX = Main.Position.X.Offset
            Config.PositionY = Main.Position.Y.Offset
            saveConfig()
        end
    end))
end

--==================================================
-- WINDOW RESIZE
--==================================================

local ResizeGrip = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -5, 1, -5),
    Size = UDim2.fromOffset(28, 28),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Font = Enum.Font.Code,
    Text = "◢",
    TextSize = 16,
    Parent = Main
})

bindTheme(ResizeGrip, "TextColor3", "muted")

do
    local resizing = false
    local startMouse = nil
    local startSize = nil

    GlobalMaid:Give(ResizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            startMouse = input.Position
            startSize = Main.AbsoluteSize
        end
    end))

    GlobalMaid:Give(UserInputService.InputChanged:Connect(function(input)
        if resizing and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - startMouse

            local width = math.clamp(
                startSize.X + delta.X,
                620,
                1050
            )

            local height = math.clamp(
                startSize.Y + delta.Y,
                390,
                720
            )

            Main.Size = UDim2.fromOffset(width, height)
        end
    end))

    GlobalMaid:Give(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end))
end

--==================================================
-- SIDEBAR COLLAPSE
--==================================================

local function applySidebarState()
    if SidebarCollapsed then
        tween(Sidebar, 0.16, {
            Size = UDim2.new(0, 64, 1, -54)
        })

        tween(Content, 0.16, {
            Position = UDim2.fromOffset(64, 54),
            Size = UDim2.new(1, -64, 1, -54)
        })

        SearchBox.Visible = false
        UserCard.Visible = false

        for _, button in pairs(Tabs) do
            button.Text = string.sub(button.Name, 1, 1)
            button.TextXAlignment = Enum.TextXAlignment.Center
        end
    else
        tween(Sidebar, 0.16, {
            Size = UDim2.new(0, 194, 1, -54)
        })

        tween(Content, 0.16, {
            Position = UDim2.fromOffset(194, 54),
            Size = UDim2.new(1, -194, 1, -54)
        })

        SearchBox.Visible = true
        UserCard.Visible = true

        for name, button in pairs(Tabs) do
            button.Text = "   " .. (
                Pages[name] and Pages[name].Title.Text or name
            )
            button.TextXAlignment = Enum.TextXAlignment.Left
        end
    end
end

SidebarToggle.MouseButton1Click:Connect(function()
    SidebarCollapsed = not SidebarCollapsed
    Config.CompactSidebar = SidebarCollapsed
    saveConfig()
    applySidebarState()
end)

--==================================================
-- MINIMIZE / CLOSE
--==================================================

MinimizeButton.MouseButton1Click:Connect(function()
    Minimized = not Minimized

    if Minimized then
        Sidebar.Visible = false
        Content.Visible = false
        ResizeGrip.Visible = false

        tween(Main, 0.18, {
            Size = UDim2.fromOffset(440, 54)
        })

        MinimizeButton.Text = "+"
    else
        tween(Main, 0.18, {
            Size = UDim2.fromOffset(790, 490)
        })

        task.delay(Config.ReduceMotion and 0 or 0.14, function()
            if Main.Parent then
                Sidebar.Visible = true
                Content.Visible = true
                ResizeGrip.Visible = true
                applySidebarState()
            end
        end)

        MinimizeButton.Text = "−"
    end
end)

local closing = false

local function closePanel()
    if closing then
        return
    end

    closing = true

    Config.PositionX = Main.Position.X.Offset
    Config.PositionY = Main.Position.Y.Offset
    saveConfig()

    TaskManager:StopAll()

    GraphicsBackup.ActiveLow = false
    GraphicsBackup.ActiveEffects = false
    restoreGraphics()

    tween(Main, 0.15, {
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1
    })

    task.wait(Config.ReduceMotion and 0 or 0.17)

    GlobalMaid:Clean()

    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
end

CloseButton.MouseButton1Click:Connect(closePanel)

--==================================================
-- FLOATING MOBILE BUTTON
--==================================================

local FloatingButton = create("TextButton", {
    Name = "FloatingButton",
    Position = UDim2.fromOffset(
        tonumber(Config.FloatingX) or 14,
        tonumber(Config.FloatingY) or 260
    ),
    Size = UDim2.fromOffset(52, 52),
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "GH",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Parent = ScreenGui
})

bindTheme(FloatingButton, "BackgroundColor3", "accent")
addCorner(FloatingButton, 26)
addStroke(FloatingButton, "text", 0.72, 1)

do
    local moving = false
    local moved = false
    local start = nil
    local startPos = nil

    GlobalMaid:Give(FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            moving = true
            moved = false
            start = input.Position
            startPos = FloatingButton.Position
        end
    end))

    GlobalMaid:Give(UserInputService.InputChanged:Connect(function(input)
        if moving and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - start

            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                moved = true
            end

            FloatingButton.Position = UDim2.fromOffset(
                startPos.X.Offset + delta.X,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    GlobalMaid:Give(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if moving then
                moving = false

                Config.FloatingX = FloatingButton.Position.X.Offset
                Config.FloatingY = FloatingButton.Position.Y.Offset
                saveConfig()

                if not moved then
                    ScreenOpen = not ScreenOpen
                    Main.Visible = ScreenOpen
                end
            end
        end
    end))
end

--==================================================
-- HOTKEYS
--==================================================

GlobalMaid:Give(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        ScreenOpen = not ScreenOpen
        Main.Visible = ScreenOpen
    elseif input.KeyCode == Enum.KeyCode.K
        and (
            UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        ) then
        if Main.Visible and not SidebarCollapsed then
            SearchBox:CaptureFocus()
        end
    end
end))

--==================================================
-- PERFORMANCE MONITOR
--==================================================

local Monitor = {
    FPS = 0,
    FPSMin = math.huge,
    FPSMax = 0,
    Ping = "N/A",
    Memory = "N/A",
    Start = os.clock()
}

do
    local frames = 0
    local mark = os.clock()

    GlobalMaid:Give(RunService.RenderStepped:Connect(function()
        frames = frames + 1

        local now = os.clock()

        if now - mark >= 1 then
            local fps = math.floor(frames / math.max(0.001, now - mark))

            Monitor.FPS = fps
            Monitor.FPSMin = math.min(Monitor.FPSMin, fps)
            Monitor.FPSMax = math.max(Monitor.FPSMax, fps)

            StatusPill.Text = ("● %d FPS"):format(fps)

            frames = 0
            mark = now

            pcall(function()
                Monitor.Ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
            end)

            pcall(function()
                Monitor.Memory = ("%.1f MB"):format(
                    Stats:GetTotalMemoryUsageMb()
                )
            end)
        end
    end))
end

--==================================================
-- RESPONSIVE SCALE / SAFE AREA
--==================================================

task.spawn(function()
    while ScreenGui.Parent do
        local camera = workspace.CurrentCamera

        if camera then
            local viewport = camera.ViewportSize
            local configuredScale = tonumber(Config.Scale) or 1

            if viewport.X < 650 then
                UIScale.Scale = math.min(configuredScale, 0.72)
            elseif viewport.X < 850 then
                UIScale.Scale = math.min(configuredScale, 0.86)
            else
                UIScale.Scale = configuredScale
            end

            local maxX = math.max(0, viewport.X - 56)
            local maxY = math.max(0, viewport.Y - 56)

            local floatX = math.clamp(
                FloatingButton.Position.X.Offset,
                0,
                maxX
            )

            local floatY = math.clamp(
                FloatingButton.Position.Y.Offset,
                0,
                maxY
            )

            FloatingButton.Position = UDim2.fromOffset(floatX, floatY)
        end

        task.wait(1)
    end
end)

--==================================================
-- SELF RECOVERY WATCHDOG
--==================================================

task.spawn(function()
    while ScreenGui.Parent do
        if Main.Parent == nil then
            pushLog("ERROR", "Watchdog detectou Main ausente.")
            break
        end

        for name, token in pairs(TaskManager.Tasks) do
            if token.cancelled then
                TaskManager.Tasks[name] = nil
            end
        end

        task.wait(3)
    end
end)

--==================================================
-- APPLY SAVED VISUAL SETTINGS
--==================================================

if Config.LowGraphics then
    GraphicsBackup.ActiveLow = true
end

if Config.HideEffects then
    GraphicsBackup.ActiveEffects = true
end

if GraphicsBackup.ActiveLow or GraphicsBackup.ActiveEffects then
    task.spawn(refreshGraphicsMode)
end

applyTheme(Config.Theme)
applySidebarState()

--==================================================
-- INITIAL PAGE
--==================================================

if not setPage(Config.LastPage) then
    setPage("Home")
end

-- Refresh reference pages after all actions exist.
refreshFavorites()
refreshRecent()

-- Refresh favorites/recent whenever their pages are selected.
local oldSetPage = setPage

setPage = function(name)
    local result = oldSetPage(name)

    if name == "Favorites" then
        refreshFavorites()
    elseif name == "Recent" then
        refreshRecent()
    end

    return result
end

--==================================================
-- STARTUP SELF-CHECK
--==================================================

do
    local checks = {
        ScreenGui.Parent ~= nil,
        Main.Parent ~= nil,
        next(Pages) ~= nil,
        next(Tabs) ~= nil,
        Themes[Config.Theme] ~= nil,
        LocalPlayer ~= nil
    }

    local passed = 0

    for _, value in ipairs(checks) do
        if value then
            passed = passed + 1
        end
    end

    pushLog(
        passed == #checks and "INFO" or "WARN",
        ("Startup check: %d/%d"):format(passed, #checks)
    )
end

notify(
    "Ghost Hub V" .. VERSION,
    "Interface carregada. Keyless, configurável e com recuperação de erros.",
    "success",
    4
)

pushLog("INFO", "Ghost Hub V2 carregado com sucesso.")
