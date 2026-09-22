--==============================================================
-- StudioLite Map Importer Mobile V2
-- Corrige "Falha ao compilar export: nil"
-- Abre seletor de arquivos exportados ao tocar em IMPORTAR MUNDO
-- Suporta exports V4 grandes sem depender de loadstring para ler a tabela
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
    YieldEvery = 120,
    ParserYieldEvery = 5000,
    MaxParserDepth = 80,
}

-------------------------------------------------
-- API
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
    isfolder = getGlobal("isfolder"),
    listfiles = getGlobal("listfiles"),
    getworkspace = getGlobal("getworkspace"),
    gethui = getGlobal("gethui"),
    loadstring = getGlobal("loadstring"),
}

-------------------------------------------------
-- LOG
-------------------------------------------------
local function log(message)
    if CONFIG.PrintProgress then
        print("[StudioLite Importer V2] "..tostring(message))
    end
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
        if ok then
            return exists == true
        end
    end

    if type(API.readfile) == "function" then
        local ok, value = pcall(API.readfile,path)
        return ok and type(value) == "string"
    end

    return false
end

-------------------------------------------------
-- PASTAS / LISTAGEM
-------------------------------------------------
local function addUnique(list,seen,value)
    value = normalizePath(value)

    if value and value ~= "" and not seen[value] then
        seen[value] = true
        list[#list + 1] = value
    end
end

local function candidateDirectories()
    local list = {}
    local seen = {}

    local function add(path)
        addUnique(list,seen,path)
    end

    add("StudioLiteExports")
    add(".")
    add("workspace")
    add("workspace/StudioLiteExports")

    add("/storage/emulated/0/Download")
    add("/storage/emulated/0/Download/StudioLiteExports")

    add("/sdcard/Download")
    add("/sdcard/Download/StudioLiteExports")

    add("/storage/emulated/0/Delta/Workspace")
    add("/storage/emulated/0/Delta/Workspace/StudioLiteExports")
    add("/storage/emulated/0/Delta/Workspace/Studio Lite")
    add("/storage/emulated/0/Delta/Workspace/Studio Lite/StudioLiteExports")
    add("/storage/emulated/0/Delta/Workspace/StudioLife")
    add("/storage/emulated/0/Delta/Workspace/StudioLife/StudioLiteExports")
    add("/storage/emulated/0/Delta/Workspace/Studio life")
    add("/storage/emulated/0/Delta/Workspace/Studio life/StudioLiteExports")

    local ws = getWorkspacePath()

    if ws then
        add(ws)
        add(ws.."/StudioLiteExports")
        add(ws.."/Studio Lite")
        add(ws.."/Studio Lite/StudioLiteExports")
        add(ws.."/StudioLife")
        add(ws.."/StudioLife/StudioLiteExports")
    end

    return list
end

local function listDirectory(directory)
    if type(API.listfiles) ~= "function" then
        return {}
    end

    local ok, files = pcall(API.listfiles,directory)

    if ok and type(files) == "table" then
        return files
    end

    return {}
end

local function looksLikeExport(path)
    if type(path) ~= "string" then
        return false
    end

    local base = normalizePath(path):match("([^/]+)$") or path

    return base:match("^StudioLite_Map_.+%.lua$") ~= nil
        or base:match("^StudioLite_Map_.+%.slmap$") ~= nil
end

local function collectExportFiles(preferred)
    local found = {}
    local seen = {}

    local function addIfFile(path)
        path = normalizePath(path)

        if path and not seen[path] and looksLikeExport(path) and isFile(path) then
            seen[path] = true
            found[#found + 1] = path
        end
    end

    if type(preferred) == "string" and preferred ~= "" then
        if isFile(preferred) then
            addIfFile(preferred)
        end

        local base = preferred:match("([^/\\]+)$")

        if base then
            for _, dir in ipairs(candidateDirectories()) do
                addIfFile(dir.."/"..base)
            end
        end
    end

    for _, dir in ipairs(candidateDirectories()) do
        local files = listDirectory(dir)

        for _, path in ipairs(files) do
            if type(path) == "string" then
                local normalized = normalizePath(path)

                if looksLikeExport(normalized) then
                    addIfFile(normalized)
                else
                    local name = normalized:match("([^/]+)$")

                    if name == "StudioLiteExports" then
                        for _, child in ipairs(listDirectory(normalized)) do
                            addIfFile(child)
                        end
                    end
                end
            end
        end
    end

    local defaultName = CONFIG.DefaultFileName

    for _, dir in ipairs(candidateDirectories()) do
        addIfFile(dir.."/"..defaultName)
    end

    table.sort(found,function(a,b)
        local aa = a:match("(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)")
            or a
        local bb = b:match("(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)")
            or b

        if aa == bb then
            return a > b
        end

        return aa > bb
    end)

    return found
end

-------------------------------------------------
-- PARSER DO FORMATO LUA GERADO PELO EXPORTER
-- Não executa o arquivo para obter os dados.
-- Isso evita limites do compilador em exports grandes.
-------------------------------------------------
local function parseExportTable(source)
    if type(source) ~= "string" or source == "" then
        return nil,"arquivo vazio"
    end

    local returnStart = source:find("return%s+")

    if not returnStart then
        return nil,"não encontrei 'return' no export"
    end

    local tableStart = source:find("{",returnStart,true)

    if not tableStart then
        return nil,"não encontrei a tabela do export"
    end

    local parser = {
        s = source,
        i = tableStart,
        n = #source,
        steps = 0,
    }

    local function tick()
        parser.steps += 1

        if CONFIG.ParserYieldEvery > 0
            and parser.steps % CONFIG.ParserYieldEvery == 0
        then
            task.wait()
        end
    end

    local function skipSpace()
        while parser.i <= parser.n do
            local b = string.byte(parser.s,parser.i)

            if b == 32 or b == 9 or b == 10 or b == 13 then
                parser.i += 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        if parser.s:sub(parser.i,parser.i) ~= '"' then
            return nil,"string esperada na posição "..parser.i
        end

        parser.i += 1

        local out = {}

        while parser.i <= parser.n do
            local ch = parser.s:sub(parser.i,parser.i)

            if ch == '"' then
                parser.i += 1
                return table.concat(out)
            end

            if ch == "\\" then
                parser.i += 1

                if parser.i > parser.n then
                    return nil,"escape incompleto"
                end

                local esc = parser.s:sub(parser.i,parser.i)

                if esc == "n" then
                    out[#out + 1] = "\n"
                    parser.i += 1
                elseif esc == "r" then
                    out[#out + 1] = "\r"
                    parser.i += 1
                elseif esc == "t" then
                    out[#out + 1] = "\t"
                    parser.i += 1
                elseif esc == "\\" then
                    out[#out + 1] = "\\"
                    parser.i += 1
                elseif esc == '"' then
                    out[#out + 1] = '"'
                    parser.i += 1
                elseif esc:match("%d") then
                    local digits = parser.s:sub(parser.i,parser.i + 2)
                    local numberText = digits:match("^(%d%d?%d?)")
                    local byteValue = tonumber(numberText)

                    if not byteValue or byteValue < 0 or byteValue > 255 then
                        return nil,"escape numérico inválido"
                    end

                    out[#out + 1] = string.char(byteValue)
                    parser.i += #numberText
                else
                    out[#out + 1] = esc
                    parser.i += 1
                end
            else
                out[#out + 1] = ch
                parser.i += 1
            end

            tick()
        end

        return nil,"string não terminada"
    end

    local function parseIdentifier()
        local start = parser.i

        while parser.i <= parser.n do
            local ch = parser.s:sub(parser.i,parser.i)

            if ch:match("[A-Za-z0-9_]") then
                parser.i += 1
            else
                break
            end
        end

        if parser.i == start then
            return nil
        end

        return parser.s:sub(start,parser.i - 1)
    end

    local function parseNumber()
        local start = parser.i

        while parser.i <= parser.n do
            local ch = parser.s:sub(parser.i,parser.i)

            if ch:match("[0-9eE%+%-%.]") then
                parser.i += 1
            else
                break
            end
        end

        local text = parser.s:sub(start,parser.i - 1)
        local value = tonumber(text)

        if value == nil then
            return nil,"número inválido: "..text
        end

        return value
    end

    local function parseTable(depth)
        if depth > CONFIG.MaxParserDepth then
            return nil,"profundidade máxima excedida"
        end

        if parser.s:sub(parser.i,parser.i) ~= "{" then
            return nil,"'{' esperado"
        end

        parser.i += 1

        local result = {}
        local arrayIndex = 1

        while true do
            skipSpace()
            tick()

            local ch = parser.s:sub(parser.i,parser.i)

            if ch == "}" then
                parser.i += 1
                return result
            end

            if ch == "" then
                return nil,"tabela não terminada"
            end

            local key = nil
            local value = nil

            if ch == "[" then
                parser.i += 1
                skipSpace()

                local parsedKey, keyErr =
                    parseValue(depth + 1)

                if keyErr then
                    return nil,keyErr
                end

                key = parsedKey

                skipSpace()

                if parser.s:sub(parser.i,parser.i) ~= "]" then
                    return nil,"']' esperado na posição "..parser.i
                end

                parser.i += 1
                skipSpace()

                if parser.s:sub(parser.i,parser.i) ~= "=" then
                    return nil,"'=' esperado após chave"
                end

                parser.i += 1
                skipSpace()

                local parsedValue, valueErr =
                    parseValue(depth + 1)

                if valueErr then
                    return nil,valueErr
                end

                value = parsedValue

            elseif ch:match("[A-Za-z_]") then
                local save = parser.i
                local identifier = parseIdentifier()

                skipSpace()

                if parser.s:sub(parser.i,parser.i) == "=" then
                    parser.i += 1
                    skipSpace()

                    key = identifier

                    local parsedValue, valueErr =
                        parseValue(depth + 1)

                    if valueErr then
                        return nil,valueErr
                    end

                    value = parsedValue
                else
                    parser.i = save

                    local parsedValue, valueErr =
                        parseValue(depth + 1)

                    if valueErr then
                        return nil,valueErr
                    end

                    value = parsedValue
                end
            else
                local parsedValue, valueErr =
                    parseValue(depth + 1)

                if valueErr then
                    return nil,valueErr
                end

                value = parsedValue
            end

            if key ~= nil then
                result[key] = value
            else
                result[arrayIndex] = value
                arrayIndex += 1
            end

            skipSpace()

            if parser.s:sub(parser.i,parser.i) == "," then
                parser.i += 1
            end
        end
    end

    parseValue = function(depth)
        skipSpace()
        tick()

        local ch = parser.s:sub(parser.i,parser.i)

        if ch == "{" then
            return parseTable(depth)
        end

        if ch == '"' then
            return parseString()
        end

        if ch:match("[%+%-0-9]") then
            return parseNumber()
        end

        if ch:match("[A-Za-z_]") then
            local id = parseIdentifier()

            if id == "true" then
                return true
            elseif id == "false" then
                return false
            elseif id == "nil" then
                return nil
            end

            return nil,"identificador inesperado: "..tostring(id)
        end

        return nil,
            "valor inesperado na posição "
            ..tostring(parser.i)
            ..": "
            ..tostring(ch)
    end

    local data, err = parseValue(0)

    if err then
        return nil,err
    end

    if type(data) ~= "table" then
        return nil,"o export não resultou em tabela"
    end

    return data
end

-------------------------------------------------
-- CARREGAR EXPORT
-------------------------------------------------
local function loadExport(path)
    if type(API.readfile) ~= "function" then
        return nil,"readfile não está disponível."
    end

    if not isFile(path) then
        return nil,"arquivo não encontrado: "..tostring(path)
    end

    local okRead, source = pcall(API.readfile,path)

    if not okRead or type(source) ~= "string" or source == "" then
        return nil,
            "falha ao ler arquivo: "
            ..tostring(source)
    end

    if not source:find("Studio Lite Map Export",1,true)
        and not source:find("StudioLiteMapExport",1,true)
    then
        return nil,
            "o arquivo não parece ser um export StudioLite válido"
    end

    -- Método principal: parser próprio, sem compilar arquivo gigante.
    local parsed, parseError =
        parseExportTable(source)

    if parsed and type(parsed.objects) == "table" then
        return parsed,"parser"
    end

    -- Fallback: loadstring, agora preservando a mensagem real.
    if type(API.loadstring) == "function" then
        local okCompile, chunk, compileError =
            pcall(API.loadstring,source)

        if okCompile and type(chunk) == "function" then
            local okRun, data =
                pcall(chunk)

            if okRun
                and type(data) == "table"
                and type(data.objects) == "table"
            then
                return data,"loadstring"
            end

            if not okRun then
                return nil,
                    "parser: "
                    ..tostring(parseError)
                    .."\nloadstring executou com erro: "
                    ..tostring(data)
            end
        end

        return nil,
            "parser: "
            ..tostring(parseError)
            .."\ncompilador: "
            ..tostring(
                compileError
                or chunk
                or "sem mensagem"
            )
    end

    return nil,
        "parser: "
        ..tostring(parseError)
        .."\nloadstring indisponível"
end

-------------------------------------------------
-- DECODIFICAÇÃO
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
    elseif t == "Vector3" then
        return Vector3.new(
            tonumber(value.x) or 0,
            tonumber(value.y) or 0,
            tonumber(value.z) or 0
        )
    elseif t == "Color3" then
        return Color3.new(
            tonumber(value.r) or 0,
            tonumber(value.g) or 0,
            tonumber(value.b) or 0
        )
    elseif t == "CFrame" then
        local v = value.values

        if type(v) == "table" and #v >= 12 then
            return CFrame.new(
                tonumber(v[1]) or 0,
                tonumber(v[2]) or 0,
                tonumber(v[3]) or 0,
                tonumber(v[4]) or 1,
                tonumber(v[5]) or 0,
                tonumber(v[6]) or 0,
                tonumber(v[7]) or 0,
                tonumber(v[8]) or 1,
                tonumber(v[9]) or 0,
                tonumber(v[10]) or 0,
                tonumber(v[11]) or 0,
                tonumber(v[12]) or 1
            )
        end
    elseif t == "UDim" then
        return UDim.new(
            tonumber(value.scale) or 0,
            tonumber(value.offset) or 0
        )
    elseif t == "UDim2" then
        return UDim2.new(
            tonumber(value.xs) or 0,
            tonumber(value.xo) or 0,
            tonumber(value.ys) or 0,
            tonumber(value.yo) or 0
        )
    elseif t == "NumberRange" then
        return NumberRange.new(
            tonumber(value.min) or 0,
            tonumber(value.max) or 0
        )
    elseif t == "BrickColor" then
        if tonumber(value.number) then
            return BrickColor.new(tonumber(value.number))
        end

        return BrickColor.new(
            tostring(value.name or "Medium stone grey")
        )
    elseif t == "EnumItem" then
        local enumType, enumName =
            tostring(value.value or ""):
            match("^Enum%.([^%.]+)%.(.+)$")

        if enumType and enumName then
            local enum = Enum[enumType]

            if enum then
                local ok, item = pcall(function()
                    return enum[enumName]
                end)

                if ok then
                    return item
                end
            end
        end
    elseif t == "ColorSequence" then
        local points = {}

        for _, kp in ipairs(value.keypoints or {}) do
            local color = decode(kp.color)

            if typeof(color) == "Color3" then
                points[#points + 1] =
                    ColorSequenceKeypoint.new(
                        tonumber(kp.time) or 0,
                        color
                    )
            end
        end

        if #points >= 2 then
            return ColorSequence.new(points)
        end
    elseif t == "NumberSequence" then
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
-- INSTÂNCIAS
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
    "MeshId",
    "TextureID",
    "TextureId",
}

local function trySetProperty(instance,key,value)
    if SKIP_PROPERTIES[key] then
        return true
    end

    local decoded = decode(value)

    if decoded == nil and value ~= nil then
        decoded = value
    end

    return pcall(function()
        instance[key] = decoded
    end)
end

local function applyProperties(instance,properties)
    if type(properties) ~= "table" then
        return 0,0
    end

    local applied = 0
    local failed = 0
    local done = {}

    for _, key in ipairs(PROPERTY_PRIORITY) do
        if properties[key] ~= nil then
            done[key] = true

            if trySetProperty(instance,key,properties[key]) then
                applied += 1
            else
                failed += 1
            end
        end
    end

    for key, value in pairs(properties) do
        if not done[key] and not SKIP_PROPERTIES[key] then
            if trySetProperty(instance,key,value) then
                applied += 1
            else
                failed += 1
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

    return applied,failed
end

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
    if not CONFIG.ImportTags or type(tags) ~= "table" then
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

local function applyLighting(data)
    if not CONFIG.ImportLighting or type(data) ~= "table" then
        return 0,0
    end

    local okCount = 0
    local failCount = 0

    for key, value in pairs(data) do
        local decoded = decode(value)

        if decoded == nil and value ~= nil then
            decoded = value
        end

        local ok = pcall(function()
            Lighting[key] = decoded
        end)

        if ok then
            okCount += 1
        else
            failCount += 1
        end
    end

    return okCount,failCount
end

-------------------------------------------------
-- IMPORTAÇÃO
-------------------------------------------------
local function clearPreviousImport()
    local old =
        Workspace:FindFirstChild(
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
        clearPreviousImport()
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

    local byOriginalPath = {
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
        lightingOk=0,
        lightingFailed=0,
    }

    local primaryJobs = {}
    local pivotJobs = {}
    local operations = 0

    while #pending > 0 do
        stats.passes += 1

        local nextPending = {}
        local createdThisPass = 0

        for _, record in ipairs(pending) do
            local parentPath = record.parent
            local parent = nil

            if parentPath == nil or parentPath == "Workspace" then
                parent = root
            else
                parent = byOriginalPath[parentPath]
            end

            if parent then
                local instance, mode =
                    createInstance(record)

                if instance then
                    instance.Parent = parent
                    byOriginalPath[record.path] = instance

                    local okProps, failedProps =
                        applyProperties(
                            instance,
                            record.properties
                        )

                    stats.propertyOk += okProps
                    stats.propertyFailed += failedProps

                    applyAttributes(
                        instance,
                        record.attributes
                    )

                    applyTags(
                        instance,
                        record.tags
                    )

                    if mode == "Native" then
                        stats.native += 1
                    else
                        stats.fallback += 1
                    end

                    local props = record.properties or {}

                    if instance:IsA("Model")
                        and type(props.PrimaryPartPath) == "string"
                    then
                        primaryJobs[#primaryJobs + 1] = {
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

                    stats.created += 1
                    createdThisPass += 1
                else
                    stats.skipped += 1
                end
            else
                nextPending[#nextPending + 1] = record
            end

            operations += 1

            if CONFIG.YieldEvery > 0
                and operations % CONFIG.YieldEvery == 0
            then
                if progress then
                    progress(stats,#nextPending)
                end
                task.wait()
            end
        end

        pending = nextPending

        if createdThisPass == 0 or stats.passes >= 100 then
            break
        end
    end

    -- Pais ausentes: não descarta objeto.
    for _, record in ipairs(pending) do
        local instance, mode =
            createInstance(record)

        if instance then
            instance.Parent = root
            byOriginalPath[record.path] = instance

            local okProps, failedProps =
                applyProperties(
                    instance,
                    record.properties
                )

            stats.propertyOk += okProps
            stats.propertyFailed += failedProps

            applyAttributes(instance,record.attributes)
            applyTags(instance,record.tags)

            stats.created += 1
            stats.unresolved += 1

            if mode == "Native" then
                stats.native += 1
            else
                stats.fallback += 1
            end
        else
            stats.skipped += 1
        end

        operations += 1

        if CONFIG.YieldEvery > 0
            and operations % CONFIG.YieldEvery == 0
        then
            task.wait()
        end
    end

    for _, job in ipairs(primaryJobs) do
        local part = byOriginalPath[job.path]

        if part and part:IsA("BasePart") then
            pcall(function()
                job.model.PrimaryPart = part
            end)
        end
    end

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
-- UI PRINCIPAL
-------------------------------------------------
local guiParent

do
    if type(API.gethui) == "function" then
        local ok, value = pcall(API.gethui)

        if ok and value then
            guiParent = value
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
        "StudioLite Importer: não foi possível criar a interface."
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

local WIDTH = 370
local HEIGHT = 500

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(WIDTH,HEIGHT)
frame.Position = UDim2.new(
    0.5,-WIDTH/2,
    0.5,-HEIGHT/2
)
frame.BackgroundColor3 =
    Color3.fromRGB(20,22,28)
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner",frame).CornerRadius =
    UDim.new(0,12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65,70,85)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-52,0,48)
title.Position = UDim2.fromOffset(14,0)
title.BackgroundTransparency = 1
title.Text = "MAP IMPORTER MOBILE V2"
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
fileLabel.Text = "Arquivo selecionado"
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
fileBox.TextSize = 11
fileBox.Font = Enum.Font.Code
fileBox.TextXAlignment = Enum.TextXAlignment.Left
fileBox.ClearTextOnFocus = false
fileBox.Text = CONFIG.DefaultFileName
fileBox.PlaceholderText = "StudioLite_Map_....lua"
fileBox.Parent = frame

Instance.new("UICorner",fileBox).CornerRadius =
    UDim.new(0,9)

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0,10)
padding.PaddingRight = UDim.new(0,10)
padding.Parent = fileBox

local function makeButton(text,y,color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-28,0,46)
    b.Position = UDim2.fromOffset(14,y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Text = text
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.Parent = frame

    Instance.new("UICorner",b).CornerRadius =
        UDim.new(0,9)

    return b
end

local importBtn = makeButton(
    "IMPORTAR MUNDO",
    136,
    Color3.fromRGB(46,160,90)
)

local clearBtn = makeButton(
    "LIMPAR IMPORTADO",
    190,
    Color3.fromRGB(155,65,65)
)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,250)
info.Position = UDim2.fromOffset(14,244)
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
    "Parser próprio: SIM",
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
    importBtn.Active = not value
    clearBtn.Active = not value
    importBtn.AutoButtonColor = not value
    clearBtn.AutoButtonColor = not value
end

-------------------------------------------------
-- SELETOR DE ARQUIVOS
-------------------------------------------------
local selector = Instance.new("Frame")
selector.Name = "FileSelector"
selector.Size = UDim2.new(1,-20,1,-20)
selector.Position = UDim2.fromOffset(10,10)
selector.BackgroundColor3 = Color3.fromRGB(24,27,34)
selector.BorderSizePixel = 0
selector.Visible = false
selector.ZIndex = 20
selector.Parent = frame

Instance.new("UICorner",selector).CornerRadius =
    UDim.new(0,12)

local selectorStroke = Instance.new("UIStroke")
selectorStroke.Color = Color3.fromRGB(78,84,102)
selectorStroke.Thickness = 1
selectorStroke.Parent = selector

local selectorTitle = Instance.new("TextLabel")
selectorTitle.Size = UDim2.new(1,-100,0,42)
selectorTitle.Position = UDim2.fromOffset(12,6)
selectorTitle.BackgroundTransparency = 1
selectorTitle.Text = "ARQUIVOS EXPORTADOS"
selectorTitle.TextColor3 = Color3.fromRGB(245,245,250)
selectorTitle.TextSize = 15
selectorTitle.Font = Enum.Font.GothamBold
selectorTitle.TextXAlignment = Enum.TextXAlignment.Left
selectorTitle.ZIndex = 21
selectorTitle.Parent = selector

local selectorClose = Instance.new("TextButton")
selectorClose.Size = UDim2.fromOffset(80,34)
selectorClose.Position = UDim2.new(1,-90,0,10)
selectorClose.BackgroundColor3 = Color3.fromRGB(55,60,72)
selectorClose.Text = "FECHAR"
selectorClose.TextColor3 = Color3.fromRGB(245,245,250)
selectorClose.TextSize = 12
selectorClose.Font = Enum.Font.GothamBold
selectorClose.ZIndex = 21
selectorClose.Parent = selector

Instance.new("UICorner",selectorClose).CornerRadius =
    UDim.new(0,8)

local selectorInfo = Instance.new("TextLabel")
selectorInfo.Size = UDim2.new(1,-24,0,42)
selectorInfo.Position = UDim2.fromOffset(12,48)
selectorInfo.BackgroundTransparency = 1
selectorInfo.Text = "Procurando..."
selectorInfo.TextColor3 = Color3.fromRGB(170,176,192)
selectorInfo.TextSize = 11
selectorInfo.Font = Enum.Font.Code
selectorInfo.TextWrapped = true
selectorInfo.TextXAlignment = Enum.TextXAlignment.Left
selectorInfo.ZIndex = 21
selectorInfo.Parent = selector

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1,-24,1,-150)
list.Position = UDim2.fromOffset(12,94)
list.BackgroundColor3 = Color3.fromRGB(29,32,40)
list.BorderSizePixel = 0
list.CanvasSize = UDim2.fromOffset(0,0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 5
list.ZIndex = 21
list.Parent = selector

Instance.new("UICorner",list).CornerRadius =
    UDim.new(0,9)

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0,8)
listPadding.PaddingBottom = UDim.new(0,8)
listPadding.PaddingLeft = UDim.new(0,8)
listPadding.PaddingRight = UDim.new(0,8)
listPadding.Parent = list

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0,8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(1,-24,0,42)
refreshBtn.Position = UDim2.new(0,12,1,-50)
refreshBtn.BackgroundColor3 = Color3.fromRGB(56,105,245)
refreshBtn.Text = "ATUALIZAR LISTA"
refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
refreshBtn.TextSize = 13
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.ZIndex = 21
refreshBtn.Parent = selector

Instance.new("UICorner",refreshBtn).CornerRadius =
    UDim.new(0,9)

local function clearFileRows()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local performImportFromPath

local function basename(path)
    return normalizePath(path):match("([^/]+)$") or path
end

local function refreshFileList()
    clearFileRows()

    selectorInfo.Text =
        "Lendo Delta/Workspace, StudioLiteExports e Downloads..."

    local files =
        collectExportFiles(fileBox.Text)

    if #files == 0 then
        selectorInfo.Text =
            "Nenhum StudioLite_Map_*.lua encontrado.\n"
            .."listfiles: "
            ..(
                type(API.listfiles) == "function"
                and "SIM"
                or "NÃO"
            )

        return
    end

    selectorInfo.Text =
        tostring(#files)
        .." arquivo(s). Toque no arquivo que deseja importar."

    for index, path in ipairs(files) do
        local row = Instance.new("TextButton")
        row.Name = "File_"..index
        row.Size = UDim2.new(1,0,0,58)
        row.BackgroundColor3 = Color3.fromRGB(39,43,53)
        row.TextColor3 = Color3.fromRGB(235,238,245)
        row.TextSize = 11
        row.Font = Enum.Font.Code
        row.TextWrapped = true
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text =
            basename(path)
            .."\n"
            ..path
        row.ZIndex = 22
        row.LayoutOrder = index
        row.Parent = list

        Instance.new("UICorner",row).CornerRadius =
            UDim.new(0,8)

        local rowPadding = Instance.new("UIPadding")
        rowPadding.PaddingLeft = UDim.new(0,8)
        rowPadding.PaddingRight = UDim.new(0,8)
        rowPadding.Parent = row

        row.MouseButton1Click:Connect(function()
            selectedPath = path
            fileBox.Text = path
            selector.Visible = false

            task.spawn(function()
                performImportFromPath(path)
            end)
        end)
    end
end

selectorClose.MouseButton1Click:Connect(function()
    selector.Visible = false
end)

refreshBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    task.spawn(refreshFileList)
end)

-------------------------------------------------
-- IMPORTAR UM ARQUIVO
-------------------------------------------------
performImportFromPath = function(path)
    if busy then
        return
    end

    setBusy(true)
    importBtn.Text = "IMPORTANDO..."

    setInfo(
        "Lendo export:\n"
        ..tostring(path)
        .."\n\nParser próprio ativo..."
    )

    local data, methodOrError =
        loadExport(path)

    if not data then
        setInfo(
            "ERRO AO LER EXPORT:\n"
            ..tostring(methodOrError)
        )

        importBtn.Text = "IMPORTAR MUNDO"
        setBusy(false)
        return
    end

    setInfo(
        "Export lido com sucesso.\n"
        .."Método: "
        ..tostring(methodOrError)
        .."\nObjetos: "
        ..tostring(#data.objects)
        .."\nReconstruindo mundo..."
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
                        .."\nProps OK: "
                        ..tostring(currentStats.propertyOk)
                        .."\nProps ignoradas: "
                        ..tostring(currentStats.propertyFailed)
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
            ..tostring(stats.lightingOk)
            .." OK / "
            ..tostring(stats.lightingFailed)
            .." falhas"
            .."\nDestino: Workspace."
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
end

-------------------------------------------------
-- BOTÕES
-------------------------------------------------
importBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    selector.Visible = true

    task.spawn(refreshFileList)
end)

clearBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    local old =
        Workspace:FindFirstChild(
            CONFIG.ImportFolderName
        )

    if old then
        local ok, err = pcall(function()
            old:Destroy()
        end)

        if ok then
            setInfo("Mapa importado removido.")
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
-- ARRASTAR
-------------------------------------------------
local dragging = false
local dragStart = nil
local startPos = nil
local activeInput = nil

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
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
        and activeInput.UserInputType == Enum.UserInputType.Touch
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
        or input.UserInputType == Enum.UserInputType.MouseButton1
    then
        dragging = false
        activeInput = nil
    end
end)

log("Map Importer Mobile V2 carregado.")