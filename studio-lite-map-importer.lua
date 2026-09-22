--==============================================================
-- StudioLite Map Importer Mobile V1
-- Reconstrói exports .lua gerados pelo Map Exporter Mobile V4+
-- Focado em Studio Lite / ambiente móvel com readfile + loadstring.
--
-- IMPORTANTE:
-- • Reconstrói somente dados que EXISTEM no arquivo exportado.
-- • Não recupera scripts/source privados ou Terrain voxel não exportado.
-- • A importação é criada dentro de Workspace.StudioLite_Imported_Map.
--==============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local CONFIG = {
    DefaultFileName = "StudioLite_Map_109530157755211_20260922_031615.lua",
    ImportFolderName = "StudioLite_Imported_Map",
    ImportLighting = true,
    ImportAttributes = true,
    ImportTags = true,
    ClearPreviousImport = true,
    AnchorImportedParts = false,
    PrintProgress = true,
    YieldEvery = 150,
}

-------------------------------------------------
-- API DO AMBIENTE
-------------------------------------------------
local function getGlobal(name)
    local ok, env

    if type(getgenv) == "function" then
        ok, env = pcall(getgenv)
        if ok and type(env) == "table" and env[name] ~= nil then
            return env[name]
        end
    end

    if type(getfenv) == "function" then
        ok, env = pcall(getfenv)
        if ok and type(env) == "table" and env[name] ~= nil then
            return env[name]
        end
    end

    if type(_G) == "table" and _G[name] ~= nil then
        return _G[name]
    end

    return nil
end

local API = {
    readfile = getGlobal("readfile"),
    isfile = getGlobal("isfile"),
    listfiles = getGlobal("listfiles"),
    getworkspace = getGlobal("getworkspace"),
    gethui = getGlobal("gethui"),
    loadstring = getGlobal("loadstring"),
}

-------------------------------------------------
-- HELPERS
-------------------------------------------------
local function log(message)
    if CONFIG.PrintProgress then
        print("[StudioLite Importer] "..tostring(message))
    end
end

local function safeCall(fn,...)
    local result = {pcall(fn,...)}
    local ok = table.remove(result,1)

    if not ok then
        return false,result[1]
    end

    return true,table.unpack(result)
end

local function normalizePath(path)
    if type(path) ~= "string" then
        return nil
    end

    path = path:gsub("\\","/")
    path = path:gsub("//+","/")

    return path
end

local function getWorkspacePath()
    if type(API.getworkspace) ~= "function" then
        return nil
    end

    local ok, value = pcall(API.getworkspace)

    if ok and type(value) == "string" and value ~= "" then
        return normalizePath(value):gsub("/+$","")
    end

    return nil
end

local function isFile(path)
    if type(path) ~= "string" or path == "" then
        return false
    end

    if type(API.isfile) == "function" then
        local ok, exists = pcall(API.isfile,path)
        return ok and exists == true
    end

    if type(API.readfile) == "function" then
        local ok = pcall(API.readfile,path)
        return ok
    end

    return false
end

-------------------------------------------------
-- LOCALIZADOR DO EXPORT
-------------------------------------------------
local function addUnique(list,seen,value)
    value = normalizePath(value)

    if value and value ~= "" and not seen[value] then
        seen[value] = true
        list[#list + 1] = value
    end
end

local function knownCandidates(fileName)
    local list = {}
    local seen = {}

    addUnique(list,seen,fileName)
    addUnique(list,seen,"StudioLiteExports/"..fileName)

    addUnique(
        list,
        seen,
        "/storage/emulated/0/Download/"..fileName
    )

    addUnique(
        list,
        seen,
        "/storage/emulated/0/Download/StudioLiteExports/"..fileName
    )

    addUnique(
        list,
        seen,
        "/sdcard/Download/"..fileName
    )

    addUnique(
        list,
        seen,
        "/sdcard/Download/StudioLiteExports/"..fileName
    )

    addUnique(
        list,
        seen,
        "/storage/emulated/0/Delta/Workspace/"..fileName
    )

    addUnique(
        list,
        seen,
        "/storage/emulated/0/Delta/Workspace/StudioLiteExports/"..fileName
    )

    local ws = getWorkspacePath()

    if ws then
        addUnique(list,seen,ws.."/"..fileName)
        addUnique(list,seen,ws.."/StudioLiteExports/"..fileName)
    end

    return list
end

local function scanDirectoryForExports(directory,list,seen)
    if type(API.listfiles) ~= "function" then
        return
    end

    local ok, files = pcall(API.listfiles,directory)

    if not ok or type(files) ~= "table" then
        return
    end

    for _, path in ipairs(files) do
        if type(path) == "string" then
            local normalized = normalizePath(path)
            local base = normalized:match("([^/]+)$") or normalized

            if base:match("^StudioLite_Map_.+%.lua$") then
                addUnique(list,seen,normalized)
            end
        end
    end
end

local function discoverExport(preferred)
    if preferred and preferred ~= "" and isFile(preferred) then
        return normalizePath(preferred)
    end

    local preferredBase =
        preferred
        and preferred:match("([^/\\]+)$")
        or CONFIG.DefaultFileName

    for _, path in ipairs(knownCandidates(preferredBase)) do
        if isFile(path) then
            return path
        end
    end

    local found = {}
    local seen = {}

    scanDirectoryForExports("StudioLiteExports",found,seen)

    local ws = getWorkspacePath()

    if ws then
        scanDirectoryForExports(ws,found,seen)
        scanDirectoryForExports(ws.."/StudioLiteExports",found,seen)
    end

    scanDirectoryForExports(
        "/storage/emulated/0/Download",
        found,
        seen
    )

    scanDirectoryForExports(
        "/storage/emulated/0/Download/StudioLiteExports",
        found,
        seen
    )

    scanDirectoryForExports(
        "/sdcard/Download",
        found,
        seen
    )

    scanDirectoryForExports(
        "/sdcard/Download/StudioLiteExports",
        found,
        seen
    )

    table.sort(found,function(a,b)
        return a > b
    end)

    for _, path in ipairs(found) do
        if isFile(path) then
            return path
        end
    end

    return nil
end

-------------------------------------------------
-- CARREGAR ARQUIVO .LUA
-------------------------------------------------
local function loadExport(path)
    if type(API.readfile) ~= "function" then
        return nil,"readfile não está disponível."
    end

    if type(API.loadstring) ~= "function" then
        return nil,"loadstring não está disponível."
    end

    if not isFile(path) then
        return nil,"Arquivo não encontrado: "..tostring(path)
    end

    local okRead, source = pcall(API.readfile,path)

    if not okRead or type(source) ~= "string" or source == "" then
        return nil,"Falha ao ler arquivo: "..tostring(source)
    end

    -- Aceita somente o formato criado pelo nosso exporter.
    if not source:find("Studio Lite Map Export",1,true)
        and not source:find("StudioLiteMapExport",1,true)
    then
        return nil,"O arquivo não parece ser um export StudioLite válido."
    end

    local okCompile, chunk = pcall(API.loadstring,source)

    if not okCompile or type(chunk) ~= "function" then
        return nil,"Falha ao compilar export: "..tostring(chunk)
    end

    local okRun, data = pcall(chunk)

    if not okRun then
        return nil,"Falha ao abrir dados do export: "..tostring(data)
    end

    if type(data) ~= "table" then
        return nil,"O export não retornou uma tabela."
    end

    if type(data.objects) ~= "table" then
        return nil,"O export não contém objects."
    end

    return data
end

-------------------------------------------------
-- DECODIFICADOR DE TIPOS
-------------------------------------------------
local function decode(value)
    if type(value) ~= "table" then
        return value
    end

    local t = value.__type

    if not t then
        return value
    end

    if t == "Vector2" then
        return Vector2.new(
            tonumber(value.x) or 0,
            tonumber(value.y) or 0
        )
    end

    if t == "Vector3" then
        return Vector3.new(
            tonumber(value.x) or 0,
            tonumber(value.y) or 0,
            tonumber(value.z) or 0
        )
    end

    if t == "Color3" then
        return Color3.new(
            tonumber(value.r) or 0,
            tonumber(value.g) or 0,
            tonumber(value.b) or 0
        )
    end

    if t == "CFrame" then
        local values = value.values

        if type(values) == "table" and #values >= 12 then
            return CFrame.new(
                tonumber(values[1]) or 0,
                tonumber(values[2]) or 0,
                tonumber(values[3]) or 0,
                tonumber(values[4]) or 1,
                tonumber(values[5]) or 0,
                tonumber(values[6]) or 0,
                tonumber(values[7]) or 0,
                tonumber(values[8]) or 1,
                tonumber(values[9]) or 0,
                tonumber(values[10]) or 0,
                tonumber(values[11]) or 0,
                tonumber(values[12]) or 1
            )
        end
    end

    if t == "UDim" then
        return UDim.new(
            tonumber(value.scale) or 0,
            tonumber(value.offset) or 0
        )
    end

    if t == "UDim2" then
        return UDim2.new(
            tonumber(value.xs) or 0,
            tonumber(value.xo) or 0,
            tonumber(value.ys) or 0,
            tonumber(value.yo) or 0
        )
    end

    if t == "NumberRange" then
        return NumberRange.new(
            tonumber(value.min) or 0,
            tonumber(value.max) or 0
        )
    end

    if t == "BrickColor" then
        if tonumber(value.number) then
            return BrickColor.new(tonumber(value.number))
        end

        return BrickColor.new(
            tostring(value.name or "Medium stone grey")
        )
    end

    if t == "EnumItem" then
        local enumType, enumName =
            tostring(value.value or ""):
            match("^Enum%.([^%.]+)%.(.+)$")

        if enumType and enumName then
            local enum = Enum[enumType]

            if enum then
                local ok, item = pcall(function()
                    return enum[enumName]
                end)

                if ok and item then
                    return item
                end
            end
        end

        return nil
    end

    if t == "ColorSequence" then
        local points = {}

        for _, kp in ipairs(value.keypoints or {}) do
            local c = decode(kp.color)

            if typeof(c) == "Color3" then
                points[#points + 1] =
                    ColorSequenceKeypoint.new(
                        tonumber(kp.time) or 0,
                        c
                    )
            end
        end

        if #points >= 2 then
            return ColorSequence.new(points)
        end
    end

    if t == "NumberSequence" then
        local points = {}

        for _, kp in ipairs(value.keypoints or {}) do
            points[#points + 1] =
                NumberSequenceKeypoint.new(
                    tonumber(kp.time) or 0,
                    tonumber(kp.value) or 0,
                    tonumber(kp.envelope) or 0
                )
        end

        if #points >= 2 then
            return NumberSequence.new(points)
        end
    end

    return nil
end

-------------------------------------------------
-- CRIAÇÃO SEGURA DE INSTÂNCIA
-------------------------------------------------
local BLOCKED_CLASSES = {
    Script = true,
    LocalScript = true,
    ModuleScript = true,
    RemoteEvent = true,
    RemoteFunction = true,
    UnreliableRemoteEvent = true,
}

local function makeFallback(record)
    local props = record.properties or {}

    if props.Size or props.CFrame then
        local part = Instance.new("Part")
        part.Name = tostring(record.name or "ImportedPart")
        part:SetAttribute(
            "StudioLite_OriginalClass",
            tostring(record.class or "Unknown")
        )
        return part,"PartFallback"
    end

    local folder = Instance.new("Folder")
    folder.Name = tostring(record.name or "ImportedObject")
    folder:SetAttribute(
        "StudioLite_OriginalClass",
        tostring(record.class or "Unknown")
    )

    return folder,"FolderFallback"
end

local function createInstance(record)
    local className = tostring(record.class or "Folder")

    if BLOCKED_CLASSES[className] then
        return makeFallback(record)
    end

    local ok, instance = pcall(
        Instance.new,
        className
    )

    if ok and instance then
        instance.Name = tostring(record.name or className)
        return instance,"Native"
    end

    return makeFallback(record)
end

-------------------------------------------------
-- PROPRIEDADES
-------------------------------------------------
local SKIP_PROPERTIES = {
    Name = true,
    Parent = true,
    PrimaryPartPath = true,
    WorldPivot = true,
}

local PROPERTY_PRIORITY = {
    "Archivable",
    "Size",
    "CFrame",
    "Position",
    "Orientation",
    "Anchored",
    "CanCollide",
    "CanTouch",
    "CanQuery",
    "Transparency",
    "Color",
    "Material",
    "MaterialVariant",
}

local function trySetProperty(instance,key,value)
    if SKIP_PROPERTIES[key] then
        return true
    end

    local decoded = decode(value)

    if decoded == nil and value ~= nil then
        decoded = value
    end

    local ok = pcall(function()
        instance[key] = decoded
    end)

    return ok
end

local function applyProperties(instance,properties)
    if type(properties) ~= "table" then
        return 0,0
    end

    local done = {}
    local okCount = 0
    local failCount = 0

    for _, key in ipairs(PROPERTY_PRIORITY) do
        if properties[key] ~= nil then
            done[key] = true

            if trySetProperty(instance,key,properties[key]) then
                okCount = okCount + 1
            else
                failCount = failCount + 1
            end
        end
    end

    for key, value in pairs(properties) do
        if not done[key] and not SKIP_PROPERTIES[key] then
            if trySetProperty(instance,key,value) then
                okCount = okCount + 1
            else
                failCount = failCount + 1
            end
        end
    end

    if CONFIG.AnchorImportedParts
        and instance:IsA("BasePart")
    then
        pcall(function()
            instance.Anchored = true
        end)
    end

    return okCount,failCount
end

-------------------------------------------------
-- ATTRIBUTES / TAGS
-------------------------------------------------
local function applyAttributes(instance,attributes)
    if not CONFIG.ImportAttributes
        or type(attributes) ~= "table"
    then
        return
    end

    for key, value in pairs(attributes) do
        local decoded = decode(value)

        if decoded == nil and value ~= nil then
            decoded = value
        end

        pcall(function()
            instance:SetAttribute(tostring(key),decoded)
        end)
    end
end

local function applyTags(instance,tags)
    if not CONFIG.ImportTags
        or type(tags) ~= "table"
    then
        return
    end

    for _, tag in ipairs(tags) do
        pcall(
            CollectionService.AddTag,
            CollectionService,
            instance,
            tostring(tag)
        )
    end
end

-------------------------------------------------
-- LIGHTING
-------------------------------------------------
local function applyLighting(data)
    if not CONFIG.ImportLighting
        or type(data) ~= "table"
    then
        return 0,0
    end

    local okCount = 0
    local failCount = 0

    for property, value in pairs(data) do
        local decoded = decode(value)

        if decoded == nil and value ~= nil then
            decoded = value
        end

        local ok = pcall(function()
            Lighting[property] = decoded
        end)

        if ok then
            okCount = okCount + 1
        else
            failCount = failCount + 1
        end
    end

    return okCount,failCount
end

-------------------------------------------------
-- IMPORTADOR
-------------------------------------------------
local function destroyPreviousImport()
    local old = Workspace:FindFirstChild(
        CONFIG.ImportFolderName
    )

    if old then
        pcall(function()
            old:Destroy()
        end)
    end
end

local function createImportRoot(data)
    if CONFIG.ClearPreviousImport then
        destroyPreviousImport()
    end

    local root = Instance.new("Folder")
    root.Name = CONFIG.ImportFolderName
    root:SetAttribute(
        "StudioLite_SourcePlaceId",
        tonumber(data.placeId) or 0
    )
    root:SetAttribute(
        "StudioLite_ImportTime",
        os.time()
    )
    root.Parent = Workspace

    return root
end

local function importMap(data,progress)
    local records = {}

    for _, record in ipairs(data.objects or {}) do
        if type(record) == "table"
            and record.root == "Workspace"
            and type(record.path) == "string"
        then
            records[#records + 1] = record
        end
    end

    local root = createImportRoot(data)

    local map = {
        Workspace = root
    }

    local pending = {}

    for _, record in ipairs(records) do
        pending[#pending + 1] = record
    end

    local stats = {
        total=#records,
        created=0,
        native=0,
        fallback=0,
        skipped=0,
        propertyOk=0,
        propertyFailed=0,
        unresolved=0,
        passes=0,
    }

    local primaryPartJobs = {}
    local pivotJobs = {}
    local processed = 0

    while #pending > 0 do
        stats.passes = stats.passes + 1

        local nextPending = {}
        local createdThisPass = 0

        for _, record in ipairs(pending) do
            local parentPath = record.parent
            local parent

            if parentPath == "Workspace" or parentPath == nil then
                parent = root
            else
                parent = map[parentPath]
            end

            if parent then
                local instance, mode = createInstance(record)

                if instance then
                    instance.Parent = parent
                    map[record.path] = instance

                    local okProps, failedProps =
                        applyProperties(
                            instance,
                            record.properties
                        )

                    stats.propertyOk =
                        stats.propertyOk + okProps

                    stats.propertyFailed =
                        stats.propertyFailed + failedProps

                    applyAttributes(
                        instance,
                        record.attributes
                    )

                    applyTags(
                        instance,
                        record.tags
                    )

                    if mode == "Native" then
                        stats.native = stats.native + 1
                    else
                        stats.fallback = stats.fallback + 1
                    end

                    local props = record.properties or {}

                    if instance:IsA("Model")
                        and type(props.PrimaryPartPath) == "string"
                    then
                        primaryPartJobs[#primaryPartJobs + 1] = {
                            model=instance,
                            path=props.PrimaryPartPath
                        }
                    end

                    if instance:IsA("Model")
                        and type(props.WorldPivot) == "table"
                    then
                        pivotJobs[#pivotJobs + 1] = {
                            model=instance,
                            value=props.WorldPivot
                        }
                    end

                    stats.created = stats.created + 1
                    createdThisPass = createdThisPass + 1
                else
                    stats.skipped = stats.skipped + 1
                end
            else
                nextPending[#nextPending + 1] = record
            end

            processed = processed + 1

            if CONFIG.YieldEvery > 0
                and processed % CONFIG.YieldEvery == 0
            then
                if progress then
                    progress(stats,#nextPending)
                end
                task.wait()
            end
        end

        pending = nextPending

        if createdThisPass == 0 then
            break
        end

        if stats.passes > 100 then
            break
        end
    end

    -- Objetos com pai ausente: importa no root em vez de perder.
    for _, record in ipairs(pending) do
        local instance, mode = createInstance(record)

        if instance then
            instance.Parent = root
            map[record.path] = instance

            local okProps, failedProps =
                applyProperties(
                    instance,
                    record.properties
                )

            stats.propertyOk =
                stats.propertyOk + okProps

            stats.propertyFailed =
                stats.propertyFailed + failedProps

            applyAttributes(instance,record.attributes)
            applyTags(instance,record.tags)

            stats.created = stats.created + 1
            stats.unresolved = stats.unresolved + 1

            if mode == "Native" then
                stats.native = stats.native + 1
            else
                stats.fallback = stats.fallback + 1
            end
        else
            stats.skipped = stats.skipped + 1
        end
    end

    -- PrimaryPart depois que toda a hierarquia existir.
    for _, job in ipairs(primaryPartJobs) do
        local part = map[job.path]

        if part and part:IsA("BasePart") then
            pcall(function()
                job.model.PrimaryPart = part
            end)
        end
    end

    -- Pivot por último para evitar mover modelo vazio.
    for _, job in ipairs(pivotJobs) do
        local cf = decode(job.value)

        if typeof(cf) == "CFrame" then
            pcall(function()
                job.model:PivotTo(cf)
            end)
        end
    end

    local lightingOk, lightingFailed =
        applyLighting(data.lighting)

    stats.lightingOk = lightingOk
    stats.lightingFailed = lightingFailed

    return root,stats
end

-------------------------------------------------
-- UI
-------------------------------------------------
local guiParent

do
    if type(API.gethui) == "function" then
        local ok, result = pcall(API.gethui)

        if ok and result then
            guiParent = result
        end
    end

    if not guiParent then
        local ok, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)

        if ok then
            guiParent = coreGui
        end
    end

    if not guiParent and LocalPlayer then
        guiParent =
            LocalPlayer:WaitForChild("PlayerGui")
    end
end

if not guiParent then
    error(
        "StudioLite Importer: não foi possível criar interface."
    )
end

local oldGui =
    guiParent:FindFirstChild(
        "StudioLiteMapImporter"
    )

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLiteMapImporter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = guiParent

local WIDTH = 360
local HEIGHT = 480

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(WIDTH,HEIGHT)
frame.Position =
    UDim2.new(
        0.5,
        -WIDTH/2,
        0.5,
        -HEIGHT/2
    )
frame.BackgroundColor3 =
    Color3.fromRGB(20,22,28)
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner",frame).CornerRadius =
    UDim.new(0,12)

local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(65,70,85)
border.Thickness = 1
border.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-52,0,48)
title.Position = UDim2.fromOffset(14,0)
title.BackgroundTransparency = 1
title.Text = "MAP IMPORTER MOBILE V1"
title.TextColor3 = Color3.fromRGB(245,245,250)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(38,38)
close.Position = UDim2.new(1,-43,0,5)
close.BackgroundColor3 = Color3.fromRGB(45,48,58)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(245,245,250)
close.TextSize = 24
close.Font = Enum.Font.GothamBold
close.Parent = frame

Instance.new("UICorner",close).CornerRadius =
    UDim.new(0,9)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local fileLabel = Instance.new("TextLabel")
fileLabel.Size = UDim2.new(1,-28,0,22)
fileLabel.Position = UDim2.fromOffset(14,56)
fileLabel.BackgroundTransparency = 1
fileLabel.Text = "Arquivo exportado (.lua)"
fileLabel.TextColor3 = Color3.fromRGB(180,185,200)
fileLabel.TextSize = 12
fileLabel.Font = Enum.Font.Gotham
fileLabel.TextXAlignment = Enum.TextXAlignment.Left
fileLabel.Parent = frame

local fileBox = Instance.new("TextBox")
fileBox.Size = UDim2.new(1,-28,0,46)
fileBox.Position = UDim2.fromOffset(14,78)
fileBox.BackgroundColor3 = Color3.fromRGB(29,32,40)
fileBox.TextColor3 = Color3.fromRGB(235,238,245)
fileBox.PlaceholderColor3 = Color3.fromRGB(120,125,140)
fileBox.TextSize = 12
fileBox.Font = Enum.Font.Code
fileBox.TextXAlignment = Enum.TextXAlignment.Left
fileBox.ClearTextOnFocus = false
fileBox.Text = CONFIG.DefaultFileName
fileBox.PlaceholderText = "StudioLite_Map_....lua"
fileBox.Parent = frame

Instance.new("UICorner",fileBox).CornerRadius =
    UDim.new(0,9)

local boxPadding = Instance.new("UIPadding")
boxPadding.PaddingLeft = UDim.new(0,10)
boxPadding.PaddingRight = UDim.new(0,10)
boxPadding.Parent = fileBox

local function makeButton(text,y,color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1,-28,0,46)
    button.Position = UDim2.fromOffset(14,y)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.fromRGB(255,255,255)
    button.Text = text
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.Parent = frame

    Instance.new("UICorner",button).CornerRadius =
        UDim.new(0,9)

    return button
end

local findBtn = makeButton(
    "LOCALIZAR EXPORT",
    136,
    Color3.fromRGB(70,85,130)
)

local importBtn = makeButton(
    "IMPORTAR MUNDO",
    190,
    Color3.fromRGB(46,160,90)
)

local clearBtn = makeButton(
    "LIMPAR IMPORTADO",
    244,
    Color3.fromRGB(155,65,65)
)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,168)
info.Position = UDim2.fromOffset(14,304)
info.BackgroundColor3 = Color3.fromRGB(29,32,40)
info.TextColor3 = Color3.fromRGB(205,210,220)
info.TextSize = 12
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Text = table.concat({
    "Status: pronto",
    "readfile: "..(
        type(API.readfile) == "function"
        and "SIM"
        or "NÃO"
    ),
    "isfile: "..(
        type(API.isfile) == "function"
        and "SIM"
        or "NÃO"
    ),
    "listfiles: "..(
        type(API.listfiles) == "function"
        and "SIM"
        or "NÃO"
    ),
    "loadstring: "..(
        type(API.loadstring) == "function"
        and "SIM"
        or "NÃO"
    ),
},"\n")
info.Parent = frame

Instance.new("UICorner",info).CornerRadius =
    UDim.new(0,9)

local busy = false
local selectedPath = nil

local function setInfo(text)
    info.Text = tostring(text)
end

local function setBusy(value)
    busy = value

    findBtn.Active = not value
    importBtn.Active = not value
    clearBtn.Active = not value

    findBtn.AutoButtonColor = not value
    importBtn.AutoButtonColor = not value
    clearBtn.AutoButtonColor = not value
end

-------------------------------------------------
-- BOTÃO LOCALIZAR
-------------------------------------------------
findBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    setBusy(true)
    findBtn.Text = "PROCURANDO..."
    setInfo("Procurando arquivo exportado...")

    task.spawn(function()
        local path =
            discoverExport(
                fileBox.Text
            )

        if path then
            selectedPath = path
            fileBox.Text = path

            setInfo(
                "Arquivo encontrado:\n"
                ..path
                .."\n\nPronto para importar."
            )
        else
            selectedPath = nil

            setInfo(
                "Arquivo não encontrado.\n"
                .."Confirme o nome ou caminho do .lua."
            )
        end

        findBtn.Text = "LOCALIZAR EXPORT"
        setBusy(false)
    end)
end)

-------------------------------------------------
-- BOTÃO IMPORTAR
-------------------------------------------------
importBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    setBusy(true)
    importBtn.Text = "IMPORTANDO..."
    setInfo("Localizando export...")

    task.spawn(function()
        local path =
            selectedPath

        if not path
            or not isFile(path)
        then
            path =
                discoverExport(
                    fileBox.Text
                )
        end

        if not path then
            setInfo(
                "ERRO:\n"
                .."Nenhum arquivo StudioLite_Map_*.lua foi encontrado."
            )

            importBtn.Text = "IMPORTAR MUNDO"
            setBusy(false)
            return
        end

        selectedPath = path
        fileBox.Text = path

        setInfo(
            "Lendo arquivo:\n"
            ..path
        )

        local data, loadError =
            loadExport(path)

        if not data then
            setInfo(
                "ERRO AO LER EXPORT:\n"
                ..tostring(loadError)
            )

            importBtn.Text = "IMPORTAR MUNDO"
            setBusy(false)
            return
        end

        setInfo(
            "Export válido.\n"
            .."Objetos no arquivo: "
            ..tostring(
                type(data.objects) == "table"
                and #data.objects
                or 0
            )
            .."\nIniciando reconstrução..."
        )

        local okImport, rootOrError, stats =
            pcall(function()
                return importMap(
                    data,
                    function(currentStats,pending)
                        setInfo(
                            "IMPORTANDO...\n"
                            .."Criados: "
                            ..tostring(currentStats.created)
                            .." / "
                            ..tostring(currentStats.total)
                            .."\nNativos: "
                            ..tostring(currentStats.native)
                            .."\nFallbacks: "
                            ..tostring(currentStats.fallback)
                            .."\nPendentes: "
                            ..tostring(pending)
                            .."\nPasso: "
                            ..tostring(currentStats.passes)
                        )
                    end
                )
            end)

        if not okImport then
            setInfo(
                "ERRO DURANTE IMPORTAÇÃO:\n"
                ..tostring(rootOrError)
            )
        else
            local root = rootOrError

            setInfo(
                "IMPORTAÇÃO CONCLUÍDA\n"
                .."Criados: "
                ..tostring(stats.created)
                .." / "
                ..tostring(stats.total)
                .."\nNativos: "
                ..tostring(stats.native)
                .."\nFallbacks: "
                ..tostring(stats.fallback)
                .."\nPais ausentes: "
                ..tostring(stats.unresolved)
                .."\nProps OK: "
                ..tostring(stats.propertyOk)
                .."\nProps ignoradas: "
                ..tostring(stats.propertyFailed)
                .."\nLighting: "
                ..tostring(stats.lightingOk or 0)
                .." OK / "
                ..tostring(stats.lightingFailed or 0)
                .." falhas"
                .."\nPasta: Workspace."
                ..tostring(
                    root
                    and root.Name
                    or CONFIG.ImportFolderName
                )
            )

            log(
                "Importação concluída: "
                ..tostring(stats.created)
                .." objetos."
            )
        end

        importBtn.Text = "IMPORTAR MUNDO"
        setBusy(false)
    end)
end)

-------------------------------------------------
-- BOTÃO LIMPAR
-------------------------------------------------
clearBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    local old =
        Workspace:
        FindFirstChild(
            CONFIG.ImportFolderName
        )

    if old then
        local ok, err =
            pcall(function()
                old:Destroy()
            end)

        if ok then
            setInfo(
                "Mapa importado removido."
            )
        else
            setInfo(
                "Falha ao remover:\n"
                ..tostring(err)
            )
        end
    else
        setInfo(
            "Nenhuma importação encontrada."
        )
    end
end)

-------------------------------------------------
-- ARRASTAR PAINEL
-------------------------------------------------
local dragging = false
local dragStart = nil
local startPos = nil
local activeInput = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType
        == Enum.UserInputType.MouseButton1
        or input.UserInputType
        == Enum.UserInputType.Touch
    then
        dragging = true
        activeInput = input
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging
        or not dragStart
        or not startPos
    then
        return
    end

    if activeInput
        and activeInput.UserInputType
            == Enum.UserInputType.Touch
    then
        if input ~= activeInput then
            return
        end
    elseif input.UserInputType
        ~= Enum.UserInputType.MouseMovement
    then
        return
    end

    local delta =
        input.Position
        - dragStart

    frame.Position =
        UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
end)

UIS.InputEnded:Connect(function(input)
    if input == activeInput
        or input.UserInputType
            == Enum.UserInputType.MouseButton1
    then
        dragging = false
        activeInput = nil
    end
end)

log("Map Importer Mobile V1 carregado.")