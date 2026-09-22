--==============================================================
-- StudioLite Map Importer Mobile V3
-- Importador para exports V5 com IDs internos + referências.
-- Compatível também com exports V4 antigos (modo legado).
-- Processamento em lotes para reduzir travamentos no celular.
--==============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local SoundService = game:GetService("SoundService")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local CONFIG = {
    ImportFolderName = "StudioLite_Imported_Map",
    ClearPreviousImport = true,

    ImportWorkspace = true,
    ImportLighting = true,
    ImportReplicatedStorage = true,
    ImportReplicatedFirst = true,
    ImportStarterGui = true,
    ImportStarterPack = true,
    ImportStarterPlayer = true,
    ImportSoundService = true,
    ImportMaterialService = true,

    ImportAttributes = true,
    ImportTags = true,
    ImportReferences = true,
    ImportTerrain = true,
    ImportCollisionGroups = true,

    AnchorImportedParts = false,

    BatchSize = 100,
    ParserYieldEvery = 5000,
    MaxParserDepth = 100,
    PrintProgress = true,
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
        print("[StudioLite Importer V3] "..tostring(message))
    end
end

-------------------------------------------------
-- PATHS / FILES
-------------------------------------------------
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

local function listDirectory(path)
    if type(API.listfiles) ~= "function" then
        return {}
    end

    local ok, result =
        pcall(API.listfiles,path)

    if ok and type(result) == "table" then
        return result
    end

    return {}
end

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

local function looksLikeExport(path)
    if type(path) ~= "string" then
        return false
    end

    local base =
        normalizePath(path):
        match("([^/]+)$")
        or path

    return base:
        match("^StudioLite_Map_.+%.lua$")
        ~= nil
end

local function collectExportFiles(preferred)
    local found = {}
    local seen = {}

    local function addFile(path)
        path = normalizePath(path)

        if path
            and not seen[path]
            and looksLikeExport(path)
            and isFile(path)
        then
            seen[path] = true
            found[#found + 1] = path
        end
    end

    if type(preferred) == "string"
        and preferred ~= ""
    then
        addFile(preferred)

        local base =
            preferred:
            match("([^/\\]+)$")

        if base then
            for _, directory
                in ipairs(
                    candidateDirectories()
                )
            do
                addFile(
                    directory
                    .."/"
                    ..base
                )
            end
        end
    end

    for _, directory
        in ipairs(
            candidateDirectories()
        )
    do
        local files =
            listDirectory(directory)

        for _, path
            in ipairs(files)
        do
            if type(path) == "string" then
                local normalized =
                    normalizePath(path)

                if looksLikeExport(
                    normalized
                )
                then
                    addFile(normalized)
                else
                    local name =
                        normalized:
                        match(
                            "([^/]+)$"
                        )

                    if name ==
                        "StudioLiteExports"
                    then
                        for _, child
                            in ipairs(
                                listDirectory(
                                    normalized
                                )
                            )
                        do
                            addFile(child)
                        end
                    end
                end
            end
        end
    end

    table.sort(
        found,
        function(a,b)
            local aa =
                a:
                match(
                    "(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)"
                )
                or a

            local bb =
                b:
                match(
                    "(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)"
                )
                or b

            if aa == bb then
                return a > b
            end

            return aa > bb
        end
    )

    return found
end

-------------------------------------------------
-- PARSER DO ARQUIVO DATA-ONLY
-------------------------------------------------
local function parseExportTable(source)
    if type(source) ~= "string"
        or source == ""
    then
        return nil,"arquivo vazio"
    end

    local returnStart =
        source:
        find(
            "return%s+"
        )

    if not returnStart then
        return nil,
            "não encontrei return"
    end

    local tableStart =
        source:
        find(
            "{",
            returnStart,
            true
        )

    if not tableStart then
        return nil,
            "não encontrei tabela"
    end

    local parser = {
        s=source,
        i=tableStart,
        n=#source,
        steps=0
    }

    local function tick()
        parser.steps =
            parser.steps + 1

        if CONFIG.ParserYieldEvery > 0
            and parser.steps
                % CONFIG.ParserYieldEvery
                == 0
        then
            task.wait()
        end
    end

    local function skipSpace()
        while parser.i <= parser.n do
            local byte =
                string.byte(
                    parser.s,
                    parser.i
                )

            if byte == 32
                or byte == 9
                or byte == 10
                or byte == 13
            then
                parser.i =
                    parser.i + 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        if parser.s:
            sub(
                parser.i,
                parser.i
            ) ~= '"'
        then
            return nil,
                "string esperada em "
                ..tostring(parser.i)
        end

        parser.i =
            parser.i + 1

        local out = {}

        while parser.i <= parser.n do
            local ch =
                parser.s:
                sub(
                    parser.i,
                    parser.i
                )

            if ch == '"' then
                parser.i =
                    parser.i + 1

                return table.concat(out)
            end

            if ch == "\\" then
                parser.i =
                    parser.i + 1

                if parser.i > parser.n then
                    return nil,
                        "escape incompleto"
                end

                local esc =
                    parser.s:
                    sub(
                        parser.i,
                        parser.i
                    )

                if esc == "n" then
                    out[#out + 1] = "\n"
                    parser.i = parser.i + 1
                elseif esc == "r" then
                    out[#out + 1] = "\r"
                    parser.i = parser.i + 1
                elseif esc == "t" then
                    out[#out + 1] = "\t"
                    parser.i = parser.i + 1
                elseif esc == "\\" then
                    out[#out + 1] = "\\"
                    parser.i = parser.i + 1
                elseif esc == '"' then
                    out[#out + 1] = '"'
                    parser.i = parser.i + 1
                elseif esc:match("%d") then
                    local digits =
                        parser.s:
                        sub(
                            parser.i,
                            parser.i + 2
                        )

                    local numberText =
                        digits:
                        match(
                            "^(%d%d?%d?)"
                        )

                    local byteValue =
                        tonumber(numberText)

                    if not byteValue
                        or byteValue < 0
                        or byteValue > 255
                    then
                        return nil,
                            "escape numérico inválido"
                    end

                    out[#out + 1] =
                        string.char(
                            byteValue
                        )

                    parser.i =
                        parser.i
                        + #numberText
                else
                    out[#out + 1] = esc
                    parser.i = parser.i + 1
                end
            else
                out[#out + 1] = ch
                parser.i = parser.i + 1
            end

            tick()
        end

        return nil,
            "string não terminada"
    end

    local function parseIdentifier()
        local start =
            parser.i

        while parser.i <= parser.n do
            local ch =
                parser.s:
                sub(
                    parser.i,
                    parser.i
                )

            if ch:
                match(
                    "[A-Za-z0-9_]"
                )
            then
                parser.i =
                    parser.i + 1
            else
                break
            end
        end

        if parser.i == start then
            return nil
        end

        return parser.s:
            sub(
                start,
                parser.i - 1
            )
    end

    local function parseNumber()
        local start =
            parser.i

        while parser.i <= parser.n do
            local ch =
                parser.s:
                sub(
                    parser.i,
                    parser.i
                )

            if ch:
                match(
                    "[0-9eE%+%-%.]"
                )
            then
                parser.i =
                    parser.i + 1
            else
                break
            end
        end

        local text =
            parser.s:
            sub(
                start,
                parser.i - 1
            )

        local number =
            tonumber(text)

        if number == nil then
            return nil,
                "número inválido: "
                ..text
        end

        return number
    end

    local function parseTable(depth)
        if depth >
            CONFIG.MaxParserDepth
        then
            return nil,
                "profundidade máxima excedida"
        end

        if parser.s:
            sub(
                parser.i,
                parser.i
            ) ~= "{"
        then
            return nil,
                "{ esperado"
        end

        parser.i =
            parser.i + 1

        local result = {}
        local arrayIndex = 1

        while true do
            skipSpace()
            tick()

            local ch =
                parser.s:
                sub(
                    parser.i,
                    parser.i
                )

            if ch == "}" then
                parser.i =
                    parser.i + 1

                return result
            end

            if ch == "" then
                return nil,
                    "tabela não terminada"
            end

            local key = nil
            local value = nil

            if ch == "[" then
                parser.i =
                    parser.i + 1

                skipSpace()

                local parsedKey, keyError =
                    parseValue(
                        depth + 1
                    )

                if keyError then
                    return nil,keyError
                end

                key = parsedKey

                skipSpace()

                if parser.s:
                    sub(
                        parser.i,
                        parser.i
                    ) ~= "]"
                then
                    return nil,
                        "] esperado"
                end

                parser.i =
                    parser.i + 1

                skipSpace()

                if parser.s:
                    sub(
                        parser.i,
                        parser.i
                    ) ~= "="
                then
                    return nil,
                        "= esperado"
                end

                parser.i =
                    parser.i + 1

                skipSpace()

                local parsedValue,
                    valueError =
                    parseValue(
                        depth + 1
                    )

                if valueError then
                    return nil,valueError
                end

                value = parsedValue

            elseif ch:
                match(
                    "[A-Za-z_]"
                )
            then
                local save =
                    parser.i

                local identifier =
                    parseIdentifier()

                skipSpace()

                if parser.s:
                    sub(
                        parser.i,
                        parser.i
                    ) == "="
                then
                    parser.i =
                        parser.i + 1

                    skipSpace()

                    key = identifier

                    local parsedValue,
                        valueError =
                        parseValue(
                            depth + 1
                        )

                    if valueError then
                        return nil,
                            valueError
                    end

                    value = parsedValue
                else
                    parser.i = save

                    local parsedValue,
                        valueError =
                        parseValue(
                            depth + 1
                        )

                    if valueError then
                        return nil,
                            valueError
                    end

                    value = parsedValue
                end
            else
                local parsedValue,
                    valueError =
                    parseValue(
                        depth + 1
                    )

                if valueError then
                    return nil,
                        valueError
                end

                value = parsedValue
            end

            if key ~= nil then
                result[key] = value
            else
                result[arrayIndex] =
                    value

                arrayIndex =
                    arrayIndex + 1
            end

            skipSpace()

            if parser.s:
                sub(
                    parser.i,
                    parser.i
                ) == ","
            then
                parser.i =
                    parser.i + 1
            end
        end
    end

    parseValue = function(depth)
        skipSpace()
        tick()

        local ch =
            parser.s:
            sub(
                parser.i,
                parser.i
            )

        if ch == "{" then
            return parseTable(depth)
        elseif ch == '"' then
            return parseString()
        elseif ch:
            match(
                "[%+%-0-9]"
            )
        then
            return parseNumber()
        elseif ch:
            match(
                "[A-Za-z_]"
            )
        then
            local identifier =
                parseIdentifier()

            if identifier == "true" then
                return true
            elseif identifier == "false" then
                return false
            elseif identifier == "nil" then
                return nil
            end

            return nil,
                "identificador inesperado: "
                ..tostring(identifier)
        end

        return nil,
            "valor inesperado em "
            ..tostring(parser.i)
            ..": "
            ..tostring(ch)
    end

    local data, errorMessage =
        parseValue(0)

    if errorMessage then
        return nil,errorMessage
    end

    if type(data) ~= "table" then
        return nil,
            "resultado não é tabela"
    end

    return data
end

-------------------------------------------------
-- LOAD EXPORT
-------------------------------------------------
local function loadExport(path)
    if type(API.readfile) ~= "function" then
        return nil,
            "readfile indisponível"
    end

    if not isFile(path) then
        return nil,
            "arquivo não encontrado: "
            ..tostring(path)
    end

    local okRead, source =
        pcall(
            API.readfile,
            path
        )

    if not okRead
        or type(source) ~= "string"
        or source == ""
    then
        return nil,
            "falha ao ler: "
            ..tostring(source)
    end

    if not source:
        find(
            "Studio Lite Map Export",
            1,
            true
        )
        and not source:
            find(
                "StudioLiteMapExport",
                1,
                true
            )
    then
        return nil,
            "arquivo não parece ser export StudioLite"
    end

    local data, parseError =
        parseExportTable(source)

    if data
        and type(data.objects)
            == "table"
    then
        return data,"parser"
    end

    if type(API.loadstring) == "function" then
        local okCompile,
            chunk,
            compileError =
            pcall(
                API.loadstring,
                source
            )

        if okCompile
            and type(chunk)
                == "function"
        then
            local okRun,
                result =
                pcall(chunk)

            if okRun
                and type(result)
                    == "table"
                and type(result.objects)
                    == "table"
            then
                return result,
                    "loadstring"
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
end

-------------------------------------------------
-- COMPATIBILIDADE V4 -> V5
-------------------------------------------------
local function normalizeLegacyData(data)
    if tonumber(data.version) == 5 then
        return data,false
    end

    local pathToId = {}
    local nextId = 1

    for _, record
        in ipairs(
            data.objects
            or {}
        )
    do
        if type(record) == "table" then
            if not record.id then
                record.id = nextId
                nextId = nextId + 1
            end

            if type(record.path)
                == "string"
            then
                pathToId[
                    record.path
                ] = record.id
            end
        end
    end

    for _, record
        in ipairs(
            data.objects
            or {}
        )
    do
        if type(record) == "table"
            and not record.parentId
            and type(record.parent)
                == "string"
        then
            record.parentId =
                pathToId[
                    record.parent
                ]
        end

        record.references =
            record.references
            or {}
    end

    data.version =
        data.version
        or 4

    return data,true
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
    elseif t == "Vector3int16" then
        return Vector3int16.new(
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

        if type(v) == "table"
            and #v >= 12
        then
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
    elseif t == "Rect" then
        local min = decode(value.min)
        local max = decode(value.max)

        if typeof(min) == "Vector2"
            and typeof(max) == "Vector2"
        then
            return Rect.new(min,max)
        end
    elseif t == "BrickColor" then
        if tonumber(value.number) then
            return BrickColor.new(
                tonumber(value.number)
            )
        end

        return BrickColor.new(
            tostring(
                value.name
                or "Medium stone grey"
            )
        )
    elseif t == "EnumItem" then
        local enumType, enumName =
            tostring(
                value.value
                or ""
            ):
            match(
                "^Enum%.([^%.]+)%.(.+)$"
            )

        if enumType
            and enumName
        then
            local enum =
                Enum[enumType]

            if enum then
                local ok, item =
                    pcall(function()
                        return enum[
                            enumName
                        ]
                    end)

                if ok then
                    return item
                end
            end
        end
    elseif t == "ColorSequence" then
        local points = {}

        for _, kp
            in ipairs(
                value.keypoints
                or {}
            )
        do
            local color =
                decode(
                    kp.color
                )

            if typeof(color)
                == "Color3"
            then
                points[#points + 1] =
                    ColorSequenceKeypoint.new(
                        tonumber(kp.time) or 0,
                        color
                    )
            end
        end

        if #points >= 2 then
            return ColorSequence.new(
                points
            )
        end
    elseif t == "NumberSequence" then
        local points = {}

        for _, kp
            in ipairs(
                value.keypoints
                or {}
            )
        do
            points[#points + 1] =
                NumberSequenceKeypoint.new(
                    tonumber(kp.time) or 0,
                    tonumber(kp.value) or 0,
                    tonumber(kp.envelope) or 0
                )
        end

        if #points >= 2 then
            return NumberSequence.new(
                points
            )
        end
    elseif t == "PhysicalProperties" then
        return PhysicalProperties.new(
            tonumber(value.density) or 0.7,
            tonumber(value.friction) or 0.3,
            tonumber(value.elasticity) or 0.5,
            tonumber(value.frictionWeight) or 1,
            tonumber(value.elasticityWeight) or 1
        )
    end

    return nil
end

-------------------------------------------------
-- ROOT DESTINATIONS
-------------------------------------------------
local IMPORT_ATTRIBUTE =
    "StudioLite_ImportOwned"

local IMPORT_ROOT_ATTRIBUTE =
    "StudioLite_ImportRoot"

local workspaceImportRoot = nil
local serviceContainers = {}

local function markImported(instance,rootName)
    pcall(function()
        instance:SetAttribute(
            IMPORT_ATTRIBUTE,
            true
        )

        instance:SetAttribute(
            IMPORT_ROOT_ATTRIBUTE,
            tostring(rootName)
        )
    end)
end

local function clearImportedTopLevels()
    local services = {
        Workspace,
        Lighting,
        ReplicatedStorage,
        ReplicatedFirst,
        StarterGui,
        StarterPack,
        StarterPlayer,
        SoundService,
        MaterialService
    }

    if LocalPlayer then
        local playerGui =
            LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )

        if playerGui then
            services[#services + 1] =
                playerGui
        end
    end

    for _, service
        in ipairs(services)
    do
        for _, child
            in ipairs(
                service:GetChildren()
            )
        do
            local owned = false

            pcall(function()
                owned =
                    child:GetAttribute(
                        IMPORT_ATTRIBUTE
                    ) == true
            end)

            if owned then
                pcall(function()
                    child:Destroy()
                end)
            end
        end
    end

    local old =
        Workspace:
        FindFirstChild(
            CONFIG.ImportFolderName
        )

    if old then
        pcall(function()
            old:Destroy()
        end)
    end
end

local function ensureContainer(service,name)
    local key =
        service:GetFullName()
        .."|"
        ..name

    local existing =
        serviceContainers[key]

    if existing and existing.Parent then
        return existing
    end

    local folder =
        Instance.new("Folder")

    folder.Name =
        "StudioLite_Imported_"
        ..name

    markImported(
        folder,
        name
    )

    folder.Parent =
        service

    serviceContainers[key] =
        folder

    return folder
end

local function getRootDestination(rootName)
    if rootName == "Workspace" then
        return workspaceImportRoot
    elseif rootName == "Lighting" then
        return Lighting
    elseif rootName == "ReplicatedStorage" then
        return CONFIG.ImportReplicatedStorage
            and ensureContainer(
                ReplicatedStorage,
                "ReplicatedStorage"
            )
            or nil
    elseif rootName == "ReplicatedFirst" then
        return CONFIG.ImportReplicatedFirst
            and ensureContainer(
                ReplicatedFirst,
                "ReplicatedFirst"
            )
            or nil
    elseif rootName == "StarterGui" then
        if not CONFIG.ImportStarterGui then
            return nil
        end

        if LocalPlayer then
            local playerGui =
                LocalPlayer:
                FindFirstChildOfClass(
                    "PlayerGui"
                )

            if playerGui then
                return playerGui
            end
        end

        return StarterGui
    elseif rootName == "StarterPack" then
        return CONFIG.ImportStarterPack
            and ensureContainer(
                StarterPack,
                "StarterPack"
            )
            or nil
    elseif rootName == "StarterPlayer" then
        return CONFIG.ImportStarterPlayer
            and ensureContainer(
                StarterPlayer,
                "StarterPlayer"
            )
            or nil
    elseif rootName == "SoundService" then
        return CONFIG.ImportSoundService
            and SoundService
            or nil
    elseif rootName == "MaterialService" then
        return CONFIG.ImportMaterialService
            and MaterialService
            or nil
    end

    return workspaceImportRoot
end

-------------------------------------------------
-- CREATE INSTANCES
-------------------------------------------------
local BLOCKED_CLASSES = {
    Script=true,
    LocalScript=true,
    ModuleScript=true,
    RemoteEvent=true,
    RemoteFunction=true,
    UnreliableRemoteEvent=true,
    Terrain=true
}

local function createFallback(record)
    local props =
        record.properties
        or {}

    if record.class == "MeshPart"
        or props.Size
        or props.CFrame
    then
        local part =
            Instance.new("Part")

        part.Name =
            tostring(
                record.name
                or "ImportedPart"
            )

        pcall(function()
            part:SetAttribute(
                "StudioLite_OriginalClass",
                tostring(
                    record.class
                    or "Unknown"
                )
            )
        end)

        return part,
            "PartFallback"
    end

    local folder =
        Instance.new("Folder")

    folder.Name =
        tostring(
            record.name
            or "ImportedObject"
        )

    pcall(function()
        folder:SetAttribute(
            "StudioLite_OriginalClass",
            tostring(
                record.class
                or "Unknown"
            )
        )
    end)

    return folder,
        "FolderFallback"
end

local function createInstance(record)
    local className =
        tostring(
            record.class
            or "Folder"
        )

    if BLOCKED_CLASSES[
        className
    ]
    then
        return createFallback(
            record
        )
    end

    local ok, instance =
        pcall(
            Instance.new,
            className
        )

    if ok and instance then
        instance.Name =
            tostring(
                record.name
                or className
            )

        return instance,
            "Native"
    end

    return createFallback(
        record
    )
end

-------------------------------------------------
-- PROPERTIES
-------------------------------------------------
local SKIP_PROPERTIES = {
    Name=true,
    Parent=true,
    PrimaryPart=true,
    WorldPivot=true,
    Occupant=true,
    ContentText=true,
    Playing=true
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
    "BrickColor",
    "Material",
    "MaterialVariant",
    "CollisionGroup",
    "MeshId",
    "TextureID",
    "TextureId"
}

local function trySetProperty(
    instance,
    key,
    value
)
    if SKIP_PROPERTIES[key] then
        return true
    end

    local decoded =
        decode(value)

    if decoded == nil
        and value ~= nil
    then
        decoded = value
    end

    return pcall(function()
        instance[key] =
            decoded
    end)
end

local function applyMeshFallback(
    instance,
    record
)
    if not instance:IsA("Part")
        or record.class ~= "MeshPart"
    then
        return
    end

    local props =
        record.properties
        or {}

    local mesh =
        Instance.new(
            "SpecialMesh"
        )

    mesh.Name =
        "StudioLite_MeshFallback"

    mesh.MeshType =
        Enum.MeshType.FileMesh

    if type(props.MeshId)
        == "string"
    then
        pcall(function()
            mesh.MeshId =
                props.MeshId
        end)
    end

    if type(props.TextureID)
        == "string"
    then
        pcall(function()
            mesh.TextureId =
                props.TextureID
        end)
    end

    mesh.Parent =
        instance
end

local function applyProperties(
    instance,
    record
)
    local properties =
        record.properties

    if type(properties)
        ~= "table"
    then
        return 0,0
    end

    local done = {}
    local applied = 0
    local failed = 0

    for _, key
        in ipairs(
            PROPERTY_PRIORITY
        )
    do
        if properties[key]
            ~= nil
        then
            done[key] = true

            if trySetProperty(
                instance,
                key,
                properties[key]
            )
            then
                applied =
                    applied + 1
            else
                failed =
                    failed + 1
            end
        end
    end

    for key, value
        in pairs(properties)
    do
        if not done[key]
            and not SKIP_PROPERTIES[key]
        then
            if trySetProperty(
                instance,
                key,
                value
            )
            then
                applied =
                    applied + 1
            else
                failed =
                    failed + 1
            end
        end
    end

    if CONFIG.AnchorImportedParts
        and instance:
            IsA(
                "BasePart"
            )
    then
        pcall(function()
            instance.Anchored =
                true
        end)
    end

    applyMeshFallback(
        instance,
        record
    )

    return applied,failed
end

-------------------------------------------------
-- ATTRIBUTES / TAGS
-------------------------------------------------
local function applyAttributes(
    instance,
    attributes
)
    if not CONFIG.ImportAttributes
        or type(attributes)
            ~= "table"
    then
        return
    end

    for key, value
        in pairs(attributes)
    do
        local decoded =
            decode(value)

        if decoded == nil
            and value ~= nil
        then
            decoded = value
        end

        pcall(function()
            instance:
                SetAttribute(
                    tostring(key),
                    decoded
                )
        end)
    end
end

local function applyTags(
    instance,
    tags
)
    if not CONFIG.ImportTags
        or type(tags)
            ~= "table"
    then
        return
    end

    for _, tag
        in ipairs(tags)
    do
        pcall(
            CollectionService.AddTag,
            CollectionService,
            instance,
            tostring(tag)
        )
    end
end

-------------------------------------------------
-- COLLISION GROUPS
-------------------------------------------------
local function importCollisionGroups(groups)
    if not CONFIG.ImportCollisionGroups
        or type(groups)
            ~= "table"
    then
        return 0
    end

    local count = 0

    for _, group
        in ipairs(groups)
    do
        if type(group) == "table"
            and type(group.name)
                == "string"
            and group.name ~= ""
            and group.name ~= "Default"
        then
            local ok =
                pcall(function()
                    PhysicsService:
                        RegisterCollisionGroup(
                            group.name
                        )
                end)

            if ok then
                count =
                    count + 1
            end
        end
    end

    return count
end

-------------------------------------------------
-- SERVICE PROPERTIES
-------------------------------------------------
local SERVICE_OBJECTS = {
    Workspace=Workspace,
    Lighting=Lighting,
    SoundService=SoundService,
    MaterialService=MaterialService,
    StarterGui=StarterGui
}

local function applyServiceProperties(
    serviceProperties
)
    if type(serviceProperties)
        ~= "table"
    then
        return 0,0
    end

    local applied = 0
    local failed = 0

    for serviceName, properties
        in pairs(
            serviceProperties
        )
    do
        local service =
            SERVICE_OBJECTS[
                serviceName
            ]

        if service
            and type(properties)
                == "table"
        then
            for key, value
                in pairs(properties)
            do
                local decoded =
                    decode(value)

                if decoded == nil
                    and value ~= nil
                then
                    decoded = value
                end

                local ok =
                    pcall(function()
                        service[key] =
                            decoded
                    end)

                if ok then
                    applied =
                        applied + 1
                else
                    failed =
                        failed + 1
                end
            end
        end
    end

    return applied,failed
end

-------------------------------------------------
-- REFERENCES
-------------------------------------------------
local function resolveExternalPath(path)
    if type(path) ~= "string"
        or path == ""
    then
        return nil
    end

    local node = game

    for segment
        in path:
        gmatch(
            "[^%.]+"
        )
    do
        node =
            node
            and node:
                FindFirstChild(
                    segment
                )

        if not node then
            return nil
        end
    end

    return node
end

local function applyReferences(
    records,
    instanceById
)
    if not CONFIG.ImportReferences then
        return 0,0
    end

    local applied = 0
    local failed = 0

    for index, record
        in ipairs(records)
    do
        local instance =
            instanceById[
                tonumber(
                    record.id
                )
            ]

        if instance
            and type(record.references)
                == "table"
        then
            for property, ref
                in pairs(
                    record.references
                )
            do
                if type(ref)
                    == "table"
                then
                    local target = nil

                    if ref.id then
                        target =
                            instanceById[
                                tonumber(
                                    ref.id
                                )
                            ]
                    elseif ref.externalPath then
                        target =
                            resolveExternalPath(
                                ref.externalPath
                            )
                    end

                    if target then
                        local ok =
                            pcall(function()
                                instance[property] =
                                    target
                            end)

                        if ok then
                            applied =
                                applied + 1
                        else
                            failed =
                                failed + 1
                        end
                    else
                        failed =
                            failed + 1
                    end
                end
            end
        end

        if CONFIG.BatchSize > 0
            and index
                % CONFIG.BatchSize
                == 0
        then
            task.wait()
        end
    end

    return applied,failed
end

-------------------------------------------------
-- MODEL PIVOTS
-------------------------------------------------
local function applyModelPivots(
    records,
    instanceById
)
    local count = 0

    for _, record
        in ipairs(records)
    do
        local instance =
            instanceById[
                tonumber(
                    record.id
                )
            ]

        if instance
            and instance:
                IsA(
                    "Model"
                )
            and type(record.properties)
                == "table"
            and record.properties.WorldPivot
        then
            local cf =
                decode(
                    record.properties.WorldPivot
                )

            if typeof(cf)
                == "CFrame"
            then
                local ok =
                    pcall(function()
                        instance:
                            PivotTo(cf)
                    end)

                if ok then
                    count =
                        count + 1
                end
            end
        end
    end

    return count
end

-------------------------------------------------
-- TERRAIN
-------------------------------------------------
local function materialFromString(value)
    local name =
        tostring(value or ""):
        match(
            "^Enum%.Material%.(.+)$"
        )
        or tostring(value or "")

    local ok, material =
        pcall(function()
            return Enum.Material[
                name
            ]
        end)

    if ok and material then
        return material
    end

    return Enum.Material.Air
end

local function importTerrain(
    terrainData,
    progress
)
    if not CONFIG.ImportTerrain
        or type(terrainData)
            ~= "table"
        or terrainData.enabled
            ~= true
    then
        return 0,0
    end

    local terrain =
        Workspace:
        FindFirstChildOfClass(
            "Terrain"
        )

    if not terrain then
        return 0,
            #(terrainData.chunks or {})
    end

    local resolution =
        tonumber(
            terrainData.resolution
        )
        or 4

    local applied = 0
    local failed = 0

    for chunkIndex, chunk
        in ipairs(
            terrainData.chunks
            or {}
        )
    do
        local ok =
            pcall(function()
                local minCell =
                    chunk.minCell

                local size =
                    chunk.size

                local sx =
                    tonumber(size.x)
                    or 0

                local sy =
                    tonumber(size.y)
                    or 0

                local sz =
                    tonumber(size.z)
                    or 0

                if sx <= 0
                    or sy <= 0
                    or sz <= 0
                then
                    return
                end

                local materials = {}
                local occupancy = {}
                local flatIndex = 0

                for x = 1, sx do
                    materials[x] = {}
                    occupancy[x] = {}

                    for y = 1, sy do
                        materials[x][y] = {}
                        occupancy[x][y] = {}

                        for z = 1, sz do
                            flatIndex =
                                flatIndex + 1

                            materials[x][y][z] =
                                materialFromString(
                                    chunk.materials[
                                        flatIndex
                                    ]
                                )

                            occupancy[x][y][z] =
                                tonumber(
                                    chunk.occupancy[
                                        flatIndex
                                    ]
                                )
                                or 0
                        end
                    end
                end

                local minWorld =
                    Vector3.new(
                        (tonumber(minCell.x) or 0)
                            * resolution,
                        (tonumber(minCell.y) or 0)
                            * resolution,
                        (tonumber(minCell.z) or 0)
                            * resolution
                    )

                local maxWorld =
                    minWorld
                    + Vector3.new(
                        sx * resolution,
                        sy * resolution,
                        sz * resolution
                    )

                local region =
                    Region3.new(
                        minWorld,
                        maxWorld
                    ):
                    ExpandToGrid(
                        resolution
                    )

                terrain:
                    WriteVoxels(
                        region,
                        resolution,
                        materials,
                        occupancy
                    )
            end)

        if ok then
            applied =
                applied + 1
        else
            failed =
                failed + 1
        end

        if progress then
            progress(
                chunkIndex,
                #(terrainData.chunks or {})
            )
        end

        task.wait()
    end

    return applied,failed
end

-------------------------------------------------
-- IMPORT CORE
-------------------------------------------------
local function importMap(
    data,
    progress
)
    local records =
        data.objects
        or {}

    serviceContainers = {}

    if CONFIG.ClearPreviousImport then
        clearImportedTopLevels()
    end

    workspaceImportRoot =
        Instance.new(
            "Folder"
        )

    workspaceImportRoot.Name =
        CONFIG.ImportFolderName

    markImported(
        workspaceImportRoot,
        "Workspace"
    )

    workspaceImportRoot.Parent =
        Workspace

    importCollisionGroups(
        data.collisionGroups
    )

    local instanceById = {}
    local pending = {}

    for _, record
        in ipairs(records)
    do
        if type(record) == "table"
            and record.id
        then
            pending[#pending + 1] =
                record
        end
    end

    local stats = {
        total=#pending,
        created=0,
        native=0,
        fallback=0,
        skipped=0,
        unresolvedParents=0,
        propertiesOk=0,
        propertiesFailed=0,
        referencesOk=0,
        referencesFailed=0,
        servicePropertiesOk=0,
        servicePropertiesFailed=0,
        terrainOk=0,
        terrainFailed=0,
        pivots=0,
        passes=0
    }

    local operations = 0

    while #pending > 0 do
        stats.passes =
            stats.passes + 1

        local nextPending = {}
        local createdThisPass = 0

        for _, record
            in ipairs(pending)
        do
            local parent = nil

            if record.parentId then
                parent =
                    instanceById[
                        tonumber(
                            record.parentId
                        )
                    ]
            else
                parent =
                    getRootDestination(
                        tostring(
                            record.root
                            or "Workspace"
                        )
                    )
            end

            if parent then
                local instance, mode =
                    createInstance(
                        record
                    )

                if instance then
                    markImported(
                        instance,
                        record.root
                    )

                    instance.Parent =
                        parent

                    instanceById[
                        tonumber(record.id)
                    ] = instance

                    local okProps,
                        failedProps =
                        applyProperties(
                            instance,
                            record
                        )

                    stats.propertiesOk =
                        stats.propertiesOk
                        + okProps

                    stats.propertiesFailed =
                        stats.propertiesFailed
                        + failedProps

                    applyAttributes(
                        instance,
                        record.attributes
                    )

                    applyTags(
                        instance,
                        record.tags
                    )

                    if mode == "Native" then
                        stats.native =
                            stats.native + 1
                    else
                        stats.fallback =
                            stats.fallback + 1
                    end

                    stats.created =
                        stats.created + 1

                    createdThisPass =
                        createdThisPass + 1
                else
                    stats.skipped =
                        stats.skipped + 1
                end
            else
                nextPending[
                    #nextPending + 1
                ] = record
            end

            operations =
                operations + 1

            if CONFIG.BatchSize > 0
                and operations
                    % CONFIG.BatchSize
                    == 0
            then
                if progress then
                    progress(
                        "objetos",
                        stats,
                        #nextPending
                    )
                end

                task.wait()
            end
        end

        pending =
            nextPending

        if createdThisPass == 0
            or stats.passes > 100
        then
            break
        end
    end

    -- Nunca perde um objeto apenas porque o pai faltou.
    for _, record
        in ipairs(pending)
    do
        local destination =
            getRootDestination(
                tostring(
                    record.root
                    or "Workspace"
                )
            )
            or workspaceImportRoot

        local instance, mode =
            createInstance(record)

        if instance then
            markImported(
                instance,
                record.root
            )

            instance.Parent =
                destination

            instanceById[
                tonumber(record.id)
            ] = instance

            local okProps,
                failedProps =
                applyProperties(
                    instance,
                    record
                )

            stats.propertiesOk =
                stats.propertiesOk
                + okProps

            stats.propertiesFailed =
                stats.propertiesFailed
                + failedProps

            applyAttributes(
                instance,
                record.attributes
            )

            applyTags(
                instance,
                record.tags
            )

            stats.created =
                stats.created + 1

            stats.unresolvedParents =
                stats.unresolvedParents + 1

            if mode == "Native" then
                stats.native =
                    stats.native + 1
            else
                stats.fallback =
                    stats.fallback + 1
            end
        else
            stats.skipped =
                stats.skipped + 1
        end

        if stats.unresolvedParents % 50
            == 0
        then
            task.wait()
        end
    end

    if progress then
        progress(
            "referencias",
            stats,
            0
        )
    end

    stats.referencesOk,
    stats.referencesFailed =
        applyReferences(
            records,
            instanceById
        )

    stats.pivots =
        applyModelPivots(
            records,
            instanceById
        )

    stats.servicePropertiesOk,
    stats.servicePropertiesFailed =
        applyServiceProperties(
            data.serviceProperties
        )

    if progress then
        progress(
            "terrain",
            stats,
            0
        )
    end

    stats.terrainOk,
    stats.terrainFailed =
        importTerrain(
            data.terrain,
            function(current,total)
                if progress then
                    progress(
                        "terrainChunk",
                        stats,
                        {
                            current=current,
                            total=total
                        }
                    )
                end
            end
        )

    return workspaceImportRoot,
        stats
end

-------------------------------------------------
-- UI
-------------------------------------------------
local guiParent

do
    if type(API.gethui) == "function" then
        local ok, value =
            pcall(API.gethui)

        if ok and value then
            guiParent = value
        end
    end

    if not guiParent then
        local ok, coreGui =
            pcall(function()
                return game:
                    GetService(
                        "CoreGui"
                    )
            end)

        if ok then
            guiParent =
                coreGui
        end
    end

    if not guiParent
        and LocalPlayer
    then
        guiParent =
            LocalPlayer:
            WaitForChild(
                "PlayerGui"
            )
    end
end

if not guiParent then
    error(
        "StudioLite Importer: interface indisponível."
    )
end

local oldGui =
    guiParent:
    FindFirstChild(
        "StudioLiteMapImporter"
    )

if oldGui then
    oldGui:Destroy()
end

local gui =
    Instance.new(
        "ScreenGui"
    )

gui.Name =
    "StudioLiteMapImporter"

gui.ResetOnSpawn =
    false

gui.IgnoreGuiInset =
    false

gui.Parent =
    guiParent

local WIDTH =
    380

local HEIGHT =
    520

local frame =
    Instance.new(
        "Frame"
    )

frame.Size =
    UDim2.fromOffset(
        WIDTH,
        HEIGHT
    )

frame.Position =
    UDim2.new(
        0.5,
        -WIDTH/2,
        0.5,
        -HEIGHT/2
    )

frame.BackgroundColor3 =
    Color3.fromRGB(
        20,
        22,
        28
    )

frame.BorderSizePixel =
    0

frame.Parent =
    gui

Instance.new(
    "UICorner",
    frame
).CornerRadius =
    UDim.new(
        0,
        12
    )

local border =
    Instance.new(
        "UIStroke"
    )

border.Color =
    Color3.fromRGB(
        65,
        70,
        85
    )

border.Thickness =
    1

border.Parent =
    frame

local title =
    Instance.new(
        "TextLabel"
    )

title.Size =
    UDim2.new(
        1,
        -52,
        0,
        48
    )

title.Position =
    UDim2.fromOffset(
        14,
        0
    )

title.BackgroundTransparency =
    1

title.Text =
    "MAP IMPORTER MOBILE V3"

title.TextColor3 =
    Color3.fromRGB(
        245,
        245,
        250
    )

title.TextSize =
    18

title.Font =
    Enum.Font.GothamBold

title.TextXAlignment =
    Enum.TextXAlignment.Left

title.Active =
    true

title.Parent =
    frame

local close =
    Instance.new(
        "TextButton"
    )

close.Size =
    UDim2.fromOffset(
        38,
        38
    )

close.Position =
    UDim2.new(
        1,
        -43,
        0,
        5
    )

close.BackgroundColor3 =
    Color3.fromRGB(
        45,
        48,
        58
    )

close.Text =
    "×"

close.TextColor3 =
    Color3.fromRGB(
        245,
        245,
        250
    )

close.TextSize =
    24

close.Font =
    Enum.Font.GothamBold

close.Parent =
    frame

Instance.new(
    "UICorner",
    close
).CornerRadius =
    UDim.new(
        0,
        9
    )

close.MouseButton1Click:
Connect(function()
    gui:Destroy()
end)

local selectedLabel =
    Instance.new(
        "TextLabel"
    )

selectedLabel.Size =
    UDim2.new(
        1,
        -28,
        0,
        58
    )

selectedLabel.Position =
    UDim2.fromOffset(
        14,
        56
    )

selectedLabel.BackgroundColor3 =
    Color3.fromRGB(
        29,
        32,
        40
    )

selectedLabel.TextColor3 =
    Color3.fromRGB(
        205,
        210,
        220
    )

selectedLabel.TextSize =
    11

selectedLabel.Font =
    Enum.Font.Code

selectedLabel.TextWrapped =
    true

selectedLabel.TextXAlignment =
    Enum.TextXAlignment.Left

selectedLabel.Text =
    "Nenhum arquivo selecionado."

selectedLabel.Parent =
    frame

Instance.new(
    "UICorner",
    selectedLabel
).CornerRadius =
    UDim.new(
        0,
        9
    )

local selectedPadding =
    Instance.new(
        "UIPadding"
    )

selectedPadding.PaddingLeft =
    UDim.new(
        0,
        8
    )

selectedPadding.PaddingRight =
    UDim.new(
        0,
        8
    )

selectedPadding.Parent =
    selectedLabel

local importBtn =
    Instance.new(
        "TextButton"
    )

importBtn.Size =
    UDim2.new(
        1,
        -28,
        0,
        48
    )

importBtn.Position =
    UDim2.fromOffset(
        14,
        126
    )

importBtn.BackgroundColor3 =
    Color3.fromRGB(
        46,
        160,
        90
    )

importBtn.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

importBtn.Text =
    "IMPORTAR MUNDO"

importBtn.TextSize =
    15

importBtn.Font =
    Enum.Font.GothamBold

importBtn.Parent =
    frame

Instance.new(
    "UICorner",
    importBtn
).CornerRadius =
    UDim.new(
        0,
        9
    )

local clearBtn =
    Instance.new(
        "TextButton"
    )

clearBtn.Size =
    UDim2.new(
        1,
        -28,
        0,
        46
    )

clearBtn.Position =
    UDim2.fromOffset(
        14,
        184
    )

clearBtn.BackgroundColor3 =
    Color3.fromRGB(
        155,
        65,
        65
    )

clearBtn.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

clearBtn.Text =
    "LIMPAR IMPORTADO"

clearBtn.TextSize =
    14

clearBtn.Font =
    Enum.Font.GothamBold

clearBtn.Parent =
    frame

Instance.new(
    "UICorner",
    clearBtn
).CornerRadius =
    UDim.new(
        0,
        9
    )

local info =
    Instance.new(
        "TextLabel"
    )

info.Size =
    UDim2.new(
        1,
        -28,
        0,
        270
    )

info.Position =
    UDim2.fromOffset(
        14,
        242
    )

info.BackgroundColor3 =
    Color3.fromRGB(
        29,
        32,
        40
    )

info.TextColor3 =
    Color3.fromRGB(
        205,
        210,
        220
    )

info.TextSize =
    12

info.Font =
    Enum.Font.Code

info.TextXAlignment =
    Enum.TextXAlignment.Left

info.TextYAlignment =
    Enum.TextYAlignment.Top

info.TextWrapped =
    true

info.Text =
    "Status: pronto\n"
    .."Parser: SIM\n"
    .."IDs internos: SIM\n"
    .."Referências: SIM\n"
    .."Terrain V5: SIM\n"
    .."Processamento em lotes: SIM"

info.Parent =
    frame

Instance.new(
    "UICorner",
    info
).CornerRadius =
    UDim.new(
        0,
        9
    )

local busy =
    false

local selectedPath =
    nil

local function setBusy(value)
    busy = value

    importBtn.Active =
        not value

    clearBtn.Active =
        not value

    importBtn.AutoButtonColor =
        not value

    clearBtn.AutoButtonColor =
        not value
end

local function setInfo(text)
    info.Text =
        tostring(text)
end

-------------------------------------------------
-- FILE PICKER
-------------------------------------------------
local selector =
    Instance.new(
        "Frame"
    )

selector.Size =
    UDim2.new(
        1,
        -20,
        1,
        -20
    )

selector.Position =
    UDim2.fromOffset(
        10,
        10
    )

selector.BackgroundColor3 =
    Color3.fromRGB(
        24,
        27,
        34
    )

selector.BorderSizePixel =
    0

selector.Visible =
    false

selector.ZIndex =
    20

selector.Parent =
    frame

Instance.new(
    "UICorner",
    selector
).CornerRadius =
    UDim.new(
        0,
        12
    )

local selectorStroke =
    Instance.new(
        "UIStroke"
    )

selectorStroke.Color =
    Color3.fromRGB(
        78,
        84,
        102
    )

selectorStroke.Parent =
    selector

local selectorTitle =
    Instance.new(
        "TextLabel"
    )

selectorTitle.Size =
    UDim2.new(
        1,
        -105,
        0,
        42
    )

selectorTitle.Position =
    UDim2.fromOffset(
        12,
        6
    )

selectorTitle.BackgroundTransparency =
    1

selectorTitle.Text =
    "ARQUIVOS EXPORTADOS"

selectorTitle.TextColor3 =
    Color3.fromRGB(
        245,
        245,
        250
    )

selectorTitle.TextSize =
    15

selectorTitle.Font =
    Enum.Font.GothamBold

selectorTitle.TextXAlignment =
    Enum.TextXAlignment.Left

selectorTitle.ZIndex =
    21

selectorTitle.Parent =
    selector

local selectorClose =
    Instance.new(
        "TextButton"
    )

selectorClose.Size =
    UDim2.fromOffset(
        82,
        34
    )

selectorClose.Position =
    UDim2.new(
        1,
        -92,
        0,
        10
    )

selectorClose.BackgroundColor3 =
    Color3.fromRGB(
        55,
        60,
        72
    )

selectorClose.Text =
    "FECHAR"

selectorClose.TextColor3 =
    Color3.fromRGB(
        245,
        245,
        250
    )

selectorClose.TextSize =
    12

selectorClose.Font =
    Enum.Font.GothamBold

selectorClose.ZIndex =
    21

selectorClose.Parent =
    selector

Instance.new(
    "UICorner",
    selectorClose
).CornerRadius =
    UDim.new(
        0,
        8
    )

local selectorInfo =
    Instance.new(
        "TextLabel"
    )

selectorInfo.Size =
    UDim2.new(
        1,
        -24,
        0,
        48
    )

selectorInfo.Position =
    UDim2.fromOffset(
        12,
        48
    )

selectorInfo.BackgroundTransparency =
    1

selectorInfo.Text =
    "Procurando exports..."

selectorInfo.TextColor3 =
    Color3.fromRGB(
        170,
        176,
        192
    )

selectorInfo.TextSize =
    11

selectorInfo.Font =
    Enum.Font.Code

selectorInfo.TextWrapped =
    true

selectorInfo.TextXAlignment =
    Enum.TextXAlignment.Left

selectorInfo.ZIndex =
    21

selectorInfo.Parent =
    selector

local fileList =
    Instance.new(
        "ScrollingFrame"
    )

fileList.Size =
    UDim2.new(
        1,
        -24,
        1,
        -156
    )

fileList.Position =
    UDim2.fromOffset(
        12,
        100
    )

fileList.BackgroundColor3 =
    Color3.fromRGB(
        29,
        32,
        40
    )

fileList.BorderSizePixel =
    0

fileList.AutomaticCanvasSize =
    Enum.AutomaticSize.Y

fileList.CanvasSize =
    UDim2.fromOffset(
        0,
        0
    )

fileList.ScrollBarThickness =
    5

fileList.ZIndex =
    21

fileList.Parent =
    selector

Instance.new(
    "UICorner",
    fileList
).CornerRadius =
    UDim.new(
        0,
        9
    )

local listPadding =
    Instance.new(
        "UIPadding"
    )

listPadding.PaddingTop =
    UDim.new(
        0,
        8
    )

listPadding.PaddingBottom =
    UDim.new(
        0,
        8
    )

listPadding.PaddingLeft =
    UDim.new(
        0,
        8
    )

listPadding.PaddingRight =
    UDim.new(
        0,
        8
    )

listPadding.Parent =
    fileList

local listLayout =
    Instance.new(
        "UIListLayout"
    )

listLayout.Padding =
    UDim.new(
        0,
        8
    )

listLayout.Parent =
    fileList

local refreshBtn =
    Instance.new(
        "TextButton"
    )

refreshBtn.Size =
    UDim2.new(
        1,
        -24,
        0,
        42
    )

refreshBtn.Position =
    UDim2.new(
        0,
        12,
        1,
        -50
    )

refreshBtn.BackgroundColor3 =
    Color3.fromRGB(
        56,
        105,
        245
    )

refreshBtn.Text =
    "ATUALIZAR LISTA"

refreshBtn.TextColor3 =
    Color3.fromRGB(
        255,
        255,
        255
    )

refreshBtn.TextSize =
    13

refreshBtn.Font =
    Enum.Font.GothamBold

refreshBtn.ZIndex =
    21

refreshBtn.Parent =
    selector

Instance.new(
    "UICorner",
    refreshBtn
).CornerRadius =
    UDim.new(
        0,
        9
    )

local function basename(path)
    return normalizePath(path):
        match(
            "([^/]+)$"
        )
        or path
end

local function clearRows()
    for _, child
        in ipairs(
            fileList:
            GetChildren()
        )
    do
        if child:
            IsA(
                "TextButton"
            )
        then
            child:
                Destroy()
        end
    end
end

local performImport

local function refreshFileList()
    clearRows()

    selectorInfo.Text =
        "Lendo Delta/Workspace, StudioLiteExports e Downloads..."

    local files =
        collectExportFiles()

    if #files == 0 then
        selectorInfo.Text =
            "Nenhum StudioLite_Map_*.lua encontrado.\n"
            .."listfiles: "
            ..(
                type(API.listfiles)
                    == "function"
                and "SIM"
                or "NÃO"
            )

        return
    end

    selectorInfo.Text =
        tostring(#files)
        .." arquivo(s). Toque no mapa para importar."

    for index, path
        in ipairs(files)
    do
        local row =
            Instance.new(
                "TextButton"
            )

        row.Size =
            UDim2.new(
                1,
                0,
                0,
                60
            )

        row.BackgroundColor3 =
            Color3.fromRGB(
                39,
                43,
                53
            )

        row.TextColor3 =
            Color3.fromRGB(
                235,
                238,
                245
            )

        row.TextSize =
            11

        row.Font =
            Enum.Font.Code

        row.TextWrapped =
            true

        row.TextXAlignment =
            Enum.TextXAlignment.Left

        row.Text =
            basename(path)
            .."\n"
            ..path

        row.ZIndex =
            22

        row.LayoutOrder =
            index

        row.Parent =
            fileList

        Instance.new(
            "UICorner",
            row
        ).CornerRadius =
            UDim.new(
                0,
                8
            )

        local rowPadding =
            Instance.new(
                "UIPadding"
            )

        rowPadding.PaddingLeft =
            UDim.new(
                0,
                8
            )

        rowPadding.PaddingRight =
            UDim.new(
                0,
                8
            )

        rowPadding.Parent =
            row

        row.MouseButton1Click:
        Connect(function()
            selectedPath =
                path

            selectedLabel.Text =
                path

            selector.Visible =
                false

            task.spawn(function()
                performImport(path)
            end)
        end)
    end
end

selectorClose.MouseButton1Click:
Connect(function()
    selector.Visible =
        false
end)

refreshBtn.MouseButton1Click:
Connect(function()
    if busy then
        return
    end

    task.spawn(
        refreshFileList
    )
end)

-------------------------------------------------
-- IMPORT ACTION
-------------------------------------------------
performImport = function(path)
    if busy then
        return
    end

    setBusy(true)

    importBtn.Text =
        "IMPORTANDO..."

    setInfo(
        "Lendo arquivo:\n"
        ..tostring(path)
        .."\n\nParser em lotes..."
    )

    local data, methodOrError =
        loadExport(path)

    if not data then
        setInfo(
            "ERRO AO LER EXPORT:\n"
            ..tostring(
                methodOrError
            )
        )

        importBtn.Text =
            "IMPORTAR MUNDO"

        setBusy(false)
        return
    end

    local legacy = false

    data, legacy =
        normalizeLegacyData(
            data
        )

    setInfo(
        "Export carregado.\n"
        .."Versão: "
        ..tostring(data.version)
        ..(
            legacy
            and " (compatibilidade V4)"
            or ""
        )
        .."\nObjetos: "
        ..tostring(
            #(
                data.objects
                or {}
            )
        )
        .."\nIniciando reconstrução..."
    )

    local okImport,
        rootOrError,
        stats =
        pcall(function()
            return importMap(
                data,
                function(
                    stage,
                    currentStats,
                    extra
                )
                    if stage ==
                        "objetos"
                    then
                        setInfo(
                            "CRIANDO OBJETOS...\n"
                            .."Criados: "
                            ..tostring(
                                currentStats.created
                            )
                            .." / "
                            ..tostring(
                                currentStats.total
                            )
                            .."\nNativos: "
                            ..tostring(
                                currentStats.native
                            )
                            .."\nFallbacks: "
                            ..tostring(
                                currentStats.fallback
                            )
                            .."\nPendentes: "
                            ..tostring(
                                extra
                            )
                            .."\nProps OK: "
                            ..tostring(
                                currentStats.propertiesOk
                            )
                            .."\nProps ignoradas: "
                            ..tostring(
                                currentStats.propertiesFailed
                            )
                        )
                    elseif stage ==
                        "referencias"
                    then
                        setInfo(
                            "Ligando referências, "
                            .."welds e attachments..."
                        )
                    elseif stage ==
                        "terrain"
                    then
                        setInfo(
                            "Preparando Terrain..."
                        )
                    elseif stage ==
                        "terrainChunk"
                    then
                        setInfo(
                            "RECONSTRUINDO TERRAIN...\n"
                            ..tostring(
                                extra.current
                            )
                            .." / "
                            ..tostring(
                                extra.total
                            )
                        )
                    end
                end
            )
        end)

    if not okImport then
        setInfo(
            "ERRO DURANTE IMPORTAÇÃO:\n"
            ..tostring(
                rootOrError
            )
        )
    else
        setInfo(
            "IMPORTAÇÃO CONCLUÍDA\n"
            .."Criados: "
            ..tostring(
                stats.created
            )
            .." / "
            ..tostring(
                stats.total
            )
            .."\nNativos: "
            ..tostring(
                stats.native
            )
            .."\nFallbacks: "
            ..tostring(
                stats.fallback
            )
            .."\nPais ausentes: "
            ..tostring(
                stats.unresolvedParents
            )
            .."\nProps: "
            ..tostring(
                stats.propertiesOk
            )
            .." OK / "
            ..tostring(
                stats.propertiesFailed
            )
            .." ignoradas"
            .."\nReferências: "
            ..tostring(
                stats.referencesOk
            )
            .." OK / "
            ..tostring(
                stats.referencesFailed
            )
            .." falhas"
            .."\nTerrain: "
            ..tostring(
                stats.terrainOk
            )
            .." chunks OK / "
            ..tostring(
                stats.terrainFailed
            )
            .." falhas"
            .."\nDestino: Workspace."
            ..tostring(
                rootOrError
                and rootOrError.Name
                or CONFIG.ImportFolderName
            )
        )

        log(
            "Importação concluída: "
            ..tostring(
                stats.created
            )
            .." objetos."
        )
    end

    importBtn.Text =
        "IMPORTAR MUNDO"

    setBusy(false)
end

-------------------------------------------------
-- BUTTONS
-------------------------------------------------
importBtn.MouseButton1Click:
Connect(function()
    if busy then
        return
    end

    selector.Visible =
        true

    task.spawn(
        refreshFileList
    )
end)

clearBtn.MouseButton1Click:
Connect(function()
    if busy then
        return
    end

    clearImportedTopLevels()

    setInfo(
        "Importação anterior removida."
    )
end)

-------------------------------------------------
-- DRAG
-------------------------------------------------
local dragging =
    false

local dragStart =
    nil

local startPos =
    nil

local activeInput =
    nil

title.InputBegan:
Connect(function(input)
    if input.UserInputType
        == Enum.UserInputType.MouseButton1
        or input.UserInputType
            == Enum.UserInputType.Touch
    then
        dragging =
            true

        activeInput =
            input

        dragStart =
            input.Position

        startPos =
            frame.Position
    end
end)

UIS.InputChanged:
Connect(function(input)
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
            startPos.X.Offset
                + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset
                + delta.Y
        )
end)

UIS.InputEnded:
Connect(function(input)
    if input == activeInput
        or input.UserInputType
            == Enum.UserInputType.MouseButton1
    then
        dragging =
            false

        activeInput =
            nil
    end
end)

log("Map Importer Mobile V3 carregado.")