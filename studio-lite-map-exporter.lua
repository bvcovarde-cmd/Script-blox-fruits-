-- Studio Lite Map Exporter Mobile V4 — Lua Export
-- Exporta somente objetos/propriedades visíveis ao cliente.
-- NÃO usa JSONEncode: gera um arquivo .lua ASCII-safe e evita "Can't convert to JSON".

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------
-- APIs DO AMBIENTE
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

local API_NAMES = {
    "writefile","readfile","isfile","makefolder",
    "isfolder","listfiles","setclipboard",
    "getclipboard","getworkspace","gethui"
}

local API = {}

local function detectAPIs()
    for _, name in ipairs(API_NAMES) do
        local fn = getGlobal(name)
        API[name] = type(fn) == "function" and fn or nil
    end
end

detectAPIs()

local function getWorkspacePath()
    if not API.getworkspace then
        return nil
    end

    local ok, path = pcall(API.getworkspace)

    if ok and type(path) == "string" and path ~= "" then
        path = path:gsub("\\", "/")
        path = path:gsub("/+$", "")
        return path
    end

    return nil
end

-------------------------------------------------
-- SERIALIZAÇÃO DE PROPRIEDADES ROBLOX
-------------------------------------------------
local function finiteNumber(n)
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
        return 0
    end
    return n
end

local function ser(v)
    local t = typeof(v)

    if t == "nil" then
        return nil
    elseif t == "string" or t == "boolean" then
        return v
    elseif t == "number" then
        return finiteNumber(v)
    elseif t == "Vector2" then
        return {__type="Vector2",x=finiteNumber(v.X),y=finiteNumber(v.Y)}
    elseif t == "Vector3" then
        return {
            __type="Vector3",
            x=finiteNumber(v.X),
            y=finiteNumber(v.Y),
            z=finiteNumber(v.Z)
        }
    elseif t == "Color3" then
        return {
            __type="Color3",
            r=finiteNumber(v.R),
            g=finiteNumber(v.G),
            b=finiteNumber(v.B)
        }
    elseif t == "CFrame" then
        local values = {v:GetComponents()}
        for i = 1, #values do
            values[i] = finiteNumber(values[i])
        end
        return {__type="CFrame",values=values}
    elseif t == "UDim" then
        return {
            __type="UDim",
            scale=finiteNumber(v.Scale),
            offset=finiteNumber(v.Offset)
        }
    elseif t == "UDim2" then
        return {
            __type="UDim2",
            xs=finiteNumber(v.X.Scale),
            xo=finiteNumber(v.X.Offset),
            ys=finiteNumber(v.Y.Scale),
            yo=finiteNumber(v.Y.Offset)
        }
    elseif t == "NumberRange" then
        return {
            __type="NumberRange",
            min=finiteNumber(v.Min),
            max=finiteNumber(v.Max)
        }
    elseif t == "EnumItem" then
        return {__type="EnumItem",value=tostring(v)}
    elseif t == "BrickColor" then
        return {__type="BrickColor",number=v.Number,name=v.Name}
    elseif t == "ColorSequence" then
        local out = {__type="ColorSequence",keypoints={}}
        for _, k in ipairs(v.Keypoints) do
            table.insert(out.keypoints,{
                time=finiteNumber(k.Time),
                color=ser(k.Value)
            })
        end
        return out
    elseif t == "NumberSequence" then
        local out = {__type="NumberSequence",keypoints={}}
        for _, k in ipairs(v.Keypoints) do
            table.insert(out.keypoints,{
                time=finiteNumber(k.Time),
                value=finiteNumber(k.Value),
                envelope=finiteNumber(k.Envelope)
            })
        end
        return out
    end

    return tostring(v)
end

local function safeGet(obj, prop)
    local ok, value = pcall(function()
        return obj[prop]
    end)

    if ok then
        return value
    end

    return nil
end

local function addProp(tbl, obj, prop, key)
    local value = safeGet(obj, prop)

    if value ~= nil then
        tbl[key or prop] = ser(value)
    end
end

local function pathOf(obj)
    local ok, full = pcall(function()
        return obj:GetFullName()
    end)

    if ok and type(full) == "string" then
        return full
    end

    return tostring(obj.Name)
end

-------------------------------------------------
-- ASSETS / PROPRIEDADES
-------------------------------------------------
local ASSET_PROPS = {
    MeshPart={"MeshId","TextureID"},
    SpecialMesh={"MeshId","TextureId"},
    Decal={"Texture"},
    Texture={"Texture"},
    Sound={"SoundId"},
    Animation={"AnimationId"},
    ParticleEmitter={"Texture"},
    Beam={"Texture"},
    Trail={"Texture"},
    SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap"},
    ImageLabel={"Image"},
    ImageButton={"Image"},
    VideoFrame={"Video"},
    Shirt={"ShirtTemplate"},
    Pants={"PantsTemplate"},
    ShirtGraphic={"Graphic"},
    Sky={
        "SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf",
        "SkyboxRt","SkyboxUp","SunTextureId","MoonTextureId"
    }
}

local COMMON_PROPS = {"Name","Archivable"}

local CLASS_PROPS = {
    BasePart={
        "CFrame","Size","Color","Material","MaterialVariant",
        "Transparency","Reflectance","Anchored","CanCollide",
        "CanTouch","CanQuery","CastShadow","CollisionGroup","Massless"
    },
    Part={"Shape"},
    MeshPart={"MeshId","TextureID","DoubleSided","RenderFidelity","CollisionFidelity"},
    SpecialMesh={"MeshId","TextureId","MeshType","Scale","Offset","VertexColor"},
    Decal={"Texture","Color3","Transparency","Face"},
    Texture={
        "Texture","Color3","Transparency","Face",
        "StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV"
    },
    Attachment={"CFrame","Position","Orientation","Axis","SecondaryAxis","Visible"},
    Sound={
        "SoundId","Volume","PlaybackSpeed","Looped",
        "RollOffMaxDistance","RollOffMinDistance","RollOffMode","EmitterSize"
    },
    ParticleEmitter={
        "Texture","Enabled","Rate","Lifetime","Speed",
        "LightEmission","LightInfluence","LockedToPart",
        "Orientation","Rotation","RotSpeed","SpreadAngle",
        "VelocityInheritance","Color","Transparency","Size"
    },
    Beam={
        "Texture","TextureLength","TextureMode","TextureSpeed",
        "Width0","Width1","CurveSize0","CurveSize1",
        "FaceCamera","LightEmission","LightInfluence",
        "Color","Transparency","Segments"
    },
    Trail={
        "Texture","TextureLength","TextureMode","Lifetime",
        "MinLength","FaceCamera","LightEmission","LightInfluence",
        "Color","Transparency","WidthScale"
    },
    PointLight={"Brightness","Color","Enabled","Range","Shadows"},
    SpotLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
    SurfaceLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
    SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap","AlphaMode"},
    Model={"WorldPivot","LevelOfDetail"},
    Animation={"AnimationId"},
    Shirt={"ShirtTemplate","Color3"},
    Pants={"PantsTemplate","Color3"},
    ShirtGraphic={"Graphic","Color3"}
}

local function collectProperties(obj)
    local out = {}

    for _, prop in ipairs(COMMON_PROPS) do
        addProp(out,obj,prop)
    end

    for className, props in pairs(CLASS_PROPS) do
        if obj:IsA(className) then
            for _, prop in ipairs(props) do
                addProp(out,obj,prop)
            end
        end
    end

    if obj:IsA("Model") then
        local primary = safeGet(obj,"PrimaryPart")
        if primary then
            out.PrimaryPartPath = pathOf(primary)
        end
    end

    return out
end

local function collectAttributes(obj)
    local out = {}

    local ok, attrs = pcall(function()
        return obj:GetAttributes()
    end)

    if ok and type(attrs) == "table" then
        for key, value in pairs(attrs) do
            out[tostring(key)] = ser(value)
        end
    end

    return out
end

local function collectTags(obj)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(obj)
    end)

    if not ok or type(tags) ~= "table" then
        return {}
    end

    local out = {}
    for _, tag in ipairs(tags) do
        out[#out + 1] = tostring(tag)
    end
    return out
end

local function isLocalCharacterObject(obj)
    local char = LocalPlayer and LocalPlayer.Character
    return char and (obj == char or obj:IsDescendantOf(char))
end

local ROOTS = {
    {service="Workspace",object=workspace},
    {service="Lighting",object=Lighting},
    {service="ReplicatedStorage",object=ReplicatedStorage},
    {service="ReplicatedFirst",object=ReplicatedFirst}
}

local function readLighting()
    local props = {
        "Ambient","OutdoorAmbient","Brightness","ClockTime",
        "GeographicLatitude","ExposureCompensation",
        "EnvironmentDiffuseScale","EnvironmentSpecularScale",
        "FogColor","FogStart","FogEnd","GlobalShadows","ShadowSoftness"
    }

    local out = {}

    for _, prop in ipairs(props) do
        addProp(out,Lighting,prop)
    end

    return out
end

-------------------------------------------------
-- SCANNER
-------------------------------------------------
local function buildPayload(progress)
    local payload = {
        format="StudioLiteMapExportLua",
        version=4,
        placeId=finiteNumber(game.PlaceId),
        gameId=finiteNumber(game.GameId),
        placeVersion=finiteNumber(game.PlaceVersion),
        exportedAt=finiteNumber(os.time()),
        lighting=readLighting(),
        objects={},
        assets={},
        stats={objects=0,assets=0,skipped=0},
        notes={
            "Only client-visible objects/properties are exported.",
            "Server-only objects and hidden source are not accessible from the client.",
            "Terrain voxel data is not included."
        }
    }

    local assetSeen = {}
    local processed = 0

    for _, root in ipairs(ROOTS) do
        local descendants = root.object:GetDescendants()

        for _, obj in ipairs(descendants) do
            processed += 1

            if not isLocalCharacterObject(obj) then
                table.insert(payload.objects,{
                    class=tostring(obj.ClassName),
                    name=tostring(obj.Name),
                    path=pathOf(obj),
                    parent=obj.Parent and pathOf(obj.Parent) or nil,
                    root=root.service,
                    properties=collectProperties(obj),
                    attributes=collectAttributes(obj),
                    tags=collectTags(obj)
                })

                payload.stats.objects += 1

                for className, props in pairs(ASSET_PROPS) do
                    if obj:IsA(className) then
                        for _, prop in ipairs(props) do
                            local value = safeGet(obj,prop)

                            if typeof(value) == "string" and value ~= "" then
                                local key = className.."|"..prop.."|"..value

                                if not assetSeen[key] then
                                    assetSeen[key] = true

                                    table.insert(payload.assets,{
                                        class=className,
                                        property=prop,
                                        value=value,
                                        firstPath=pathOf(obj)
                                    })

                                    payload.stats.assets += 1
                                end
                            end
                        end
                    end
                end
            else
                payload.stats.skipped += 1
            end

            if processed % 200 == 0 then
                if progress then
                    progress(processed,payload.stats.objects,payload.stats.assets)
                end
                task.wait()
            end
        end
    end

    return payload
end

-------------------------------------------------
-- SERIALIZADOR LUA ASCII-SAFE
-------------------------------------------------
local function quoteLuaString(value)
    value = tostring(value)

    local out = {'"'}
    local length = #value

    for i = 1, length do
        local byte = string.byte(value,i)

        if byte == 34 then
            out[#out + 1] = '\\"'
        elseif byte == 92 then
            out[#out + 1] = '\\\\'
        elseif byte == 10 then
            out[#out + 1] = '\\n'
        elseif byte == 13 then
            out[#out + 1] = '\\r'
        elseif byte == 9 then
            out[#out + 1] = '\\t'
        elseif byte >= 32 and byte <= 126 then
            out[#out + 1] = string.char(byte)
        else
            out[#out + 1] = string.format("\\%03d",byte)
        end
    end

    out[#out + 1] = '"'
    return table.concat(out)
end

local function validIdentifier(key)
    return type(key) == "string"
        and key:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function sortedNonArrayKeys(tbl, arrayLength)
    local keys = {}

    for key in pairs(tbl) do
        local isArrayKey =
            type(key) == "number"
            and key % 1 == 0
            and key >= 1
            and key <= arrayLength

        if not isArrayKey then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys,function(a,b)
        local ta, tb = type(a), type(b)

        if ta == tb then
            return tostring(a) < tostring(b)
        end

        return ta < tb
    end)

    return keys
end

local function encodeLua(value, output, indent, seen)
    local t = type(value)

    if t == "nil" then
        output[#output + 1] = "nil"
        return
    elseif t == "boolean" then
        output[#output + 1] = value and "true" or "false"
        return
    elseif t == "number" then
        output[#output + 1] = tostring(finiteNumber(value))
        return
    elseif t == "string" then
        output[#output + 1] = quoteLuaString(value)
        return
    elseif t ~= "table" then
        output[#output + 1] = quoteLuaString(tostring(value))
        return
    end

    if seen[value] then
        output[#output + 1] = quoteLuaString("<circular-reference>")
        return
    end

    seen[value] = true

    local pad = string.rep("    ",indent)
    local childPad = string.rep("    ",indent + 1)
    local arrayLength = #value
    local extraKeys = sortedNonArrayKeys(value,arrayLength)

    output[#output + 1] = "{\n"

    for i = 1, arrayLength do
        output[#output + 1] = childPad
        encodeLua(value[i],output,indent + 1,seen)
        output[#output + 1] = ",\n"
    end

    for _, key in ipairs(extraKeys) do
        output[#output + 1] = childPad

        if validIdentifier(key) then
            output[#output + 1] = key
        else
            output[#output + 1] = "["
            encodeLua(key,output,indent + 1,seen)
            output[#output + 1] = "]"
        end

        output[#output + 1] = " = "
        encodeLua(value[key],output,indent + 1,seen)
        output[#output + 1] = ",\n"
    end

    output[#output + 1] = pad
    output[#output + 1] = "}"

    seen[value] = nil
end

local function payloadToLua(payload)
    local output = {
        "-- Studio Lite Map Export\\n",
        "-- Generated by Map Exporter Mobile V4\\n",
        "-- Usage: local data = loadstring(readfile(FILE_PATH))()\\n\\n",
        "return "
    }

    encodeLua(payload,output,0,{})
    output[#output + 1] = "\n"

    return table.concat(output)
end

-------------------------------------------------
-- ARQUIVO / CAMINHOS
-------------------------------------------------
local function normalizePath(path)
    path = tostring(path):gsub("\\","/")
    path = path:gsub("//+","/")
    return path
end

local function parentPath(path)
    return path:match("^(.*)/[^/]+$")
end

local function ensureFolder(path)
    if not API.makefolder or type(path) ~= "string" or path == "" then
        return
    end

    pcall(API.makefolder,path)

    if path:sub(1,1) ~= "/" then
        local current = ""

        for part in path:gmatch("[^/]+") do
            current = current == "" and part or (current.."/"..part)
            pcall(API.makefolder,current)
        end
    end
end

local function addCandidate(list,seen,path,label)
    if type(path) ~= "string" or path == "" then
        return
    end

    path = normalizePath(path)

    if not seen[path] then
        seen[path] = true
        list[#list + 1] = {
            path=path,
            label=label
        }
    end
end

local function buildCandidates(fileName)
    local list = {}
    local seen = {}
    local folder = "StudioLiteExports"

    addCandidate(
        list,seen,
        "/storage/emulated/0/Download/"..folder.."/"..fileName,
        "Download"
    )

    addCandidate(
        list,seen,
        "/sdcard/Download/"..folder.."/"..fileName,
        "Download"
    )

    addCandidate(
        list,seen,
        "/storage/emulated/0/Download/"..fileName,
        "Download"
    )

    addCandidate(
        list,seen,
        "/sdcard/Download/"..fileName,
        "Download"
    )

    addCandidate(
        list,seen,
        "/storage/emulated/0/Delta/Workspace/"..folder.."/"..fileName,
        "Delta Workspace"
    )

    addCandidate(
        list,seen,
        "/storage/emulated/0/Delta/Workspace/"..fileName,
        "Delta Workspace"
    )

    local ws = getWorkspacePath()

    if ws then
        addCandidate(
            list,seen,
            ws.."/"..folder.."/"..fileName,
            "Workspace"
        )

        addCandidate(
            list,seen,
            ws.."/"..fileName,
            "Workspace"
        )
    end

    addCandidate(
        list,seen,
        folder.."/"..fileName,
        "Executor Workspace"
    )

    addCandidate(
        list,seen,
        fileName,
        "Executor Workspace"
    )

    return list
end

local function verifyWrite(path,contents)
    if API.isfile then
        local ok, exists = pcall(API.isfile,path)

        if not ok or exists ~= true then
            return false,"isfile não confirmou o arquivo"
        end
    end

    if API.readfile then
        local ok, data = pcall(API.readfile,path)

        if not ok then
            return false,"readfile não conseguiu reler o arquivo"
        end

        if type(data) ~= "string" then
            return false,"readfile retornou conteúdo inválido"
        end

        if #data ~= #contents then
            return false,
                "tamanho salvo diferente: "
                ..tostring(#data)
                .." / "
                ..tostring(#contents)
        end

        if data ~= contents then
            return false,"conteúdo relido diferente do conteúdo exportado"
        end
    end

    return true
end

local function savePayload(payload)
    local okSerialize, luaSource = pcall(payloadToLua,payload)

    if not okSerialize then
        return false,{
            method="error",
            message="Falha ao gerar script Lua: "..tostring(luaSource),
            bytes=0
        }
    end

    local stamp = os.date("!%Y%m%d_%H%M%S")
    local fileName = ("StudioLite_Map_%s_%s.lua")
        :format(tostring(game.PlaceId),stamp)

    local errors = {}

    if API.writefile then
        for _, candidate in ipairs(buildCandidates(fileName)) do
            local path = candidate.path
            local parent = parentPath(path)

            if parent then
                ensureFolder(parent)
            end

            local okWrite, writeErr = pcall(
                API.writefile,
                path,
                luaSource
            )

            if okWrite then
                local verified, verifyErr = verifyWrite(path,luaSource)

                if verified then
                    return true,{
                        method="file",
                        path=path,
                        label=candidate.label,
                        bytes=#luaSource,
                        verified=(API.isfile ~= nil or API.readfile ~= nil)
                    }
                end

                errors[#errors + 1] =
                    path.." -> "..tostring(verifyErr)
            else
                errors[#errors + 1] =
                    path.." -> "..tostring(writeErr)
            end
        end
    else
        errors[#errors + 1] = "writefile indisponível"
    end

    if API.setclipboard then
        local okClip, clipErr = pcall(API.setclipboard,luaSource)

        if okClip then
            return true,{
                method="clipboard",
                bytes=#luaSource,
                writeErrors=errors
            }
        end

        errors[#errors + 1] =
            "setclipboard -> "..tostring(clipErr)
    end

    print("=== StudioLite Map Export LUA ===")
    print(luaSource)

    return true,{
        method="console",
        bytes=#luaSource,
        writeErrors=errors
    }
end

-------------------------------------------------
-- UI
-------------------------------------------------
local parent

do
    if API.gethui then
        local ok, result = pcall(API.gethui)
        if ok and result then
            parent = result
        end
    end

    if not parent then
        local ok, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)

        if ok then
            parent = coreGui
        end
    end

    if not parent and LocalPlayer then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

if not parent then
    error("Map Exporter: não foi possível criar a interface.")
end

local old = parent:FindFirstChild("StudioLiteMapExporter")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLiteMapExporter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = parent

local FRAME_W = 350
local FRAME_H = 450

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(FRAME_W,FRAME_H)
frame.Position = UDim2.new(
    0.5,
    -FRAME_W / 2,
    0.5,
    -FRAME_H / 2
)
frame.BackgroundColor3 = Color3.fromRGB(20,22,28)
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner",frame).CornerRadius =
    UDim.new(0,12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65,70,85)
stroke.Thickness = 1
stroke.Parent = frame

local top = Instance.new("TextLabel")
top.Size = UDim2.new(1,-48,0,48)
top.Position = UDim2.fromOffset(14,0)
top.BackgroundTransparency = 1
top.Text = "MAP EXPORTER MOBILE V4"
top.TextColor3 = Color3.fromRGB(245,245,250)
top.TextSize = 18
top.Font = Enum.Font.GothamBold
top.TextXAlignment = Enum.TextXAlignment.Left
top.Active = true
top.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(38,38)
close.Position = UDim2.new(1,-43,0,5)
close.BackgroundColor3 = Color3.fromRGB(45,48,58)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(240,240,245)
close.TextSize = 24
close.Font = Enum.Font.GothamBold
close.Parent = frame

Instance.new("UICorner",close).CornerRadius =
    UDim.new(0,9)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,170)
info.Position = UDim2.fromOffset(14,54)
info.BackgroundColor3 = Color3.fromRGB(29,32,40)
info.TextColor3 = Color3.fromRGB(205,210,220)
info.TextSize = 12
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Parent = frame

Instance.new("UICorner",info).CornerRadius =
    UDim.new(0,9)

local function apiMark(name)
    return API[name] and "SIM" or "NÃO"
end

local function apiReport()
    local ws = getWorkspacePath()

    return table.concat({
        "Formato: LUA",
        "writefile: "..apiMark("writefile"),
        "readfile: "..apiMark("readfile"),
        "isfile: "..apiMark("isfile"),
        "makefolder: "..apiMark("makefolder"),
        "setclipboard: "..apiMark("setclipboard"),
        "getworkspace: "..apiMark("getworkspace"),
        "workspace: "..(ws or "<não exposto>")
    },"\n")
end

local function infoText(objects,assets,statusText)
    return (
        "Objetos: %d\n"
        .."Assets: %d\n"
        .."%s\n"
        .."Status: %s"
    ):format(
        objects or 0,
        assets or 0,
        apiReport(),
        statusText or "pronto"
    )
end

info.Text = infoText(0,0,"pronto")

local function createButton(text,y,color)
    local button = Instance.new("TextButton")

    button.Size = UDim2.new(1,-28,0,46)
    button.Position = UDim2.fromOffset(14,y)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.fromRGB(255,255,255)
    button.Text = text
    button.TextSize = 15
    button.Font = Enum.Font.GothamBold
    button.Parent = frame

    Instance.new("UICorner",button).CornerRadius =
        UDim.new(0,9)

    return button
end

local scanBtn = createButton(
    "ESCANEAR MAPA",
    234,
    Color3.fromRGB(56,105,245)
)

local exportBtn = createButton(
    "EXPORTAR COMO LUA",
    288,
    Color3.fromRGB(46,160,90)
)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,104)
status.Position = UDim2.fromOffset(14,342)
status.BackgroundTransparency = 1
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(155,160,175)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Pronto. O arquivo gerado será .lua."
status.Parent = frame

-------------------------------------------------
-- ESTADO
-------------------------------------------------
local busy = false
local lastPayload = nil

local function setStatus(text)
    status.Text = tostring(text)
end

local function refreshStats(payload,label)
    local objects =
        payload
        and payload.stats
        and payload.stats.objects
        or 0

    local assets =
        payload
        and payload.stats
        and payload.stats.assets
        or 0

    info.Text = infoText(objects,assets,label)
end

-------------------------------------------------
-- SCAN
-------------------------------------------------
local function runScan()
    if busy then
        return false
    end

    busy = true
    scanBtn.Text = "ESCANEANDO..."
    exportBtn.Active = false
    exportBtn.AutoButtonColor = false

    setStatus("Lendo objetos visíveis...")

    local ok, result = pcall(function()
        return buildPayload(function(processed,objects,assets)
            info.Text = (
                "Objetos: %d\n"
                .."Assets: %d\n"
                .."Analisando: %d\n"
                .."%s\n"
                .."Status: escaneando"
            ):format(
                objects,
                assets,
                processed,
                apiReport()
            )
        end)
    end)

    if ok then
        lastPayload = result
        refreshStats(lastPayload,"escaneado")
        setStatus("Scanner concluído.")
    else
        lastPayload = nil
        refreshStats(nil,"erro")
        setStatus("Erro no scanner: "..tostring(result))
    end

    scanBtn.Text = "ESCANEAR MAPA"
    exportBtn.Active = true
    exportBtn.AutoButtonColor = true
    busy = false

    return ok
end

scanBtn.MouseButton1Click:Connect(function()
    task.spawn(runScan)
end)

-------------------------------------------------
-- EXPORTAÇÃO
-------------------------------------------------
exportBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    task.spawn(function()
        if not lastPayload then
            local scanOk = runScan()

            if not scanOk or not lastPayload then
                return
            end
        end

        busy = true
        scanBtn.Active = false
        exportBtn.Text = "GERANDO LUA..."

        setStatus(
            "Serializando mapa em Lua e testando locais de gravação..."
        )

        local callOk, saveOk, result = pcall(function()
            local ok, saveResult = savePayload(lastPayload)
            return ok,saveResult
        end)

        if not callOk then
            setStatus(
                "ERRO inesperado:\n"..tostring(saveOk)
            )

            refreshStats(
                lastPayload,
                "erro ao exportar"
            )

        elseif saveOk and type(result) == "table" then
            if result.method == "file" then
                local state =
                    result.verified
                    and "verificado"
                    or "gravado"

                setStatus(
                    (
                        "SUCESSO!\n"
                        .."%s\n"
                        .."%s\n"
                        .."%d bytes (%s)"
                    ):format(
                        tostring(result.label or "Arquivo"),
                        tostring(result.path),
                        tonumber(result.bytes) or 0,
                        state
                    )
                )

                refreshStats(
                    lastPayload,
                    "exportado .lua"
                )

            elseif result.method == "clipboard" then
                setStatus(
                    (
                        "Script Lua copiado para a área de transferência.\n"
                        .."%d bytes.\n"
                        .."A gravação em arquivo foi recusada pelo ambiente."
                    ):format(
                        tonumber(result.bytes) or 0
                    )
                )

                refreshStats(
                    lastPayload,
                    "clipboard"
                )

            else
                local lastError = ""

                if result.writeErrors
                    and #result.writeErrors > 0
                then
                    lastError =
                        "\nÚltimo erro: "
                        ..tostring(
                            result.writeErrors[
                                #result.writeErrors
                            ]
                        )
                end

                setStatus(
                    (
                        "Script Lua enviado ao console (%d bytes).%s"
                    ):format(
                        tonumber(result.bytes) or 0,
                        lastError
                    )
                )

                refreshStats(
                    lastPayload,
                    "console"
                )
            end

        else
            local message =
                type(result) == "table"
                and result.message
                or tostring(result)

            setStatus(
                "ERRO ao exportar:\n"
                ..tostring(message)
            )

            refreshStats(
                lastPayload,
                "erro ao exportar"
            )
        end

        exportBtn.Text = "EXPORTAR COMO LUA"
        scanBtn.Active = true
        busy = false
    end)
end)

-------------------------------------------------
-- ARRASTAR PAINEL
-------------------------------------------------
local dragging = false
local dragStart = nil
local startPos = nil
local activeInput = nil

top.InputBegan:Connect(function(input)
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

    local delta = input.Position - dragStart

    frame.Position = UDim2.new(
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

print("[Studio Lite Map Exporter V4 LUA] carregado.")