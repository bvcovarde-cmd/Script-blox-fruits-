-- Studio Lite Map Exporter Mobile — Delta/Android
-- Exporta somente objetos/propriedades visíveis ao cliente.
-- Tenta salvar em Download, Workspace exposto pelo executor ou sandbox relativo.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------
-- RESOLUÇÃO / DETECÇÃO DE APIs
-------------------------------------------------
local function globalValue(name)
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

local API = {}
local API_NAMES = {
    "writefile","readfile","isfile","delfile",
    "makefolder","isfolder","listfiles",
    "setclipboard","getclipboard","getworkspace"
}

local function detectAPIs()
    for _, name in ipairs(API_NAMES) do
        local fn = globalValue(name)
        API[name] = type(fn) == "function" and fn or nil
    end
end

detectAPIs()

local function getWorkspacePath()
    if not API.getworkspace then
        return nil
    end

    local ok, ws = pcall(API.getworkspace)
    if ok and type(ws) == "string" and ws ~= "" then
        return ws:gsub("\\", "/"):gsub("/+$", "")
    end

    return nil
end

-------------------------------------------------
-- SERIALIZAÇÃO
-------------------------------------------------
local function packNumber(n)
    if n ~= n or n == math.huge or n == -math.huge then
        return 0
    end
    return n
end

local function ser(v)
    local t = typeof(v)

    if t == "nil" then return nil end
    if t == "string" or t == "boolean" then return v end
    if t == "number" then return packNumber(v) end
    if t == "Vector2" then return {__type="Vector2",x=v.X,y=v.Y} end
    if t == "Vector3" then return {__type="Vector3",x=v.X,y=v.Y,z=v.Z} end
    if t == "Color3" then return {__type="Color3",r=v.R,g=v.G,b=v.B} end
    if t == "CFrame" then return {__type="CFrame",values={v:GetComponents()}} end
    if t == "UDim" then return {__type="UDim",scale=v.Scale,offset=v.Offset} end
    if t == "UDim2" then
        return {
            __type="UDim2",
            xs=v.X.Scale,xo=v.X.Offset,
            ys=v.Y.Scale,yo=v.Y.Offset
        }
    end
    if t == "NumberRange" then
        return {__type="NumberRange",min=v.Min,max=v.Max}
    end
    if t == "EnumItem" then
        return {__type="EnumItem",value=tostring(v)}
    end
    if t == "BrickColor" then
        return {__type="BrickColor",number=v.Number,name=v.Name}
    end
    if t == "ColorSequence" then
        local out = {__type="ColorSequence",keypoints={}}
        for _, k in ipairs(v.Keypoints) do
            table.insert(out.keypoints,{time=k.Time,color=ser(k.Value)})
        end
        return out
    end
    if t == "NumberSequence" then
        local out = {__type="NumberSequence",keypoints={}}
        for _, k in ipairs(v.Keypoints) do
            table.insert(out.keypoints,{
                time=k.Time,value=k.Value,envelope=k.Envelope
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
    if ok then return value end
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
    return ok and full or obj.Name
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
        "Texture","Enabled","Rate","Lifetime","Speed","LightEmission",
        "LightInfluence","LockedToPart","Orientation","Rotation",
        "RotSpeed","SpreadAngle","VelocityInheritance","Color",
        "Transparency","Size"
    },
    Beam={
        "Texture","TextureLength","TextureMode","TextureSpeed",
        "Width0","Width1","CurveSize0","CurveSize1",
        "FaceCamera","LightEmission","LightInfluence",
        "Color","Transparency","Segments"
    },
    Trail={
        "Texture","TextureLength","TextureMode","Lifetime","MinLength",
        "FaceCamera","LightEmission","LightInfluence",
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
    local p = {}

    for _, prop in ipairs(COMMON_PROPS) do
        addProp(p,obj,prop)
    end

    for className, props in pairs(CLASS_PROPS) do
        if obj:IsA(className) then
            for _, prop in ipairs(props) do
                addProp(p,obj,prop)
            end
        end
    end

    if obj:IsA("Model") then
        local primary = safeGet(obj,"PrimaryPart")
        if primary then
            p.PrimaryPartPath = pathOf(primary)
        end
    end

    return p
end

local function collectAttributes(obj)
    local out = {}
    local ok, attrs = pcall(function()
        return obj:GetAttributes()
    end)

    if ok then
        for k, v in pairs(attrs) do
            out[k] = ser(v)
        end
    end

    return out
end

local function collectTags(obj)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(obj)
    end)
    return ok and tags or {}
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
        format="StudioLiteMapExport",
        version=3,
        placeId=game.PlaceId,
        gameId=game.GameId,
        placeVersion=game.PlaceVersion,
        exportedAt=os.time(),
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
        local list = root.object:GetDescendants()

        for _, obj in ipairs(list) do
            processed += 1

            if not isLocalCharacterObject(obj) then
                table.insert(payload.objects,{
                    class=obj.ClassName,
                    name=obj.Name,
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
-- SALVAMENTO
-------------------------------------------------
local function normalizePath(path)
    return tostring(path):gsub("\\","/"):gsub("//+","/")
end

local function parentPath(path)
    return path:match("^(.*)/[^/]+$")
end

local function ensureFolder(path)
    if not API.makefolder or not path or path == "" then
        return
    end

    -- Primeiro tenta criar o caminho inteiro.
    pcall(API.makefolder,path)

    -- Fallback para caminhos relativos aninhados.
    if path:sub(1,1) ~= "/" then
        local current = ""
        for part in path:gmatch("[^/]+") do
            current = current == "" and part or (current.."/"..part)
            pcall(API.makefolder,current)
        end
    end
end

local function verifyFile(path,json)
    if API.isfile then
        local ok, exists = pcall(API.isfile,path)
        if not ok or not exists then
            return false,"isfile não confirmou o arquivo"
        end
    end

    if API.readfile then
        local ok, data = pcall(API.readfile,path)
        if not ok then
            return false,"readfile não conseguiu reler o arquivo"
        end
        if type(data) ~= "string" or #data ~= #json then
            return false,"arquivo salvo com tamanho diferente do JSON"
        end
    end

    return true
end

local function addCandidate(list, seen, path, label)
    if type(path) ~= "string" or path == "" then
        return
    end

    path = normalizePath(path)

    if not seen[path] then
        seen[path] = true
        table.insert(list,{path=path,label=label})
    end
end

local function buildSaveCandidates(fileName)
    local list, seen = {}, {}
    local folderName = "StudioLiteExports"

    -- Android externo. Pode falhar por Scoped Storage/permissões do executor.
    addCandidate(list,seen,
        "/storage/emulated/0/Download/"..folderName.."/"..fileName,
        "Download")
    addCandidate(list,seen,
        "/sdcard/Download/"..folderName.."/"..fileName,
        "Download")
    addCandidate(list,seen,
        "/storage/emulated/0/Download/"..fileName,
        "Download")
    addCandidate(list,seen,
        "/sdcard/Download/"..fileName,
        "Download")

    -- Caminhos comuns do Delta. Nem toda versão expõe acesso absoluto.
    addCandidate(list,seen,
        "/storage/emulated/0/Delta/Workspace/"..folderName.."/"..fileName,
        "Delta Workspace")
    addCandidate(list,seen,
        "/storage/emulated/0/Delta/Workspace/"..fileName,
        "Delta Workspace")

    local ws = getWorkspacePath()
    if ws then
        addCandidate(list,seen,ws.."/"..folderName.."/"..fileName,"Workspace")
        addCandidate(list,seen,ws.."/"..fileName,"Workspace")
    end

    -- Normalmente o fallback mais compatível com writefile.
    addCandidate(list,seen,folderName.."/"..fileName,"Sandbox")
    addCandidate(list,seen,fileName,"Sandbox")

    return list
end

local function savePayload(payload)
    local okEncode, json = pcall(function()
        return HttpService:JSONEncode(payload)
    end)

    if not okEncode then
        return false,{
            method="error",
            message="Falha ao gerar JSON: "..tostring(json),
            bytes=0
        }
    end

    local stamp = os.date("!%Y%m%d_%H%M%S")
    local fileName = ("StudioLite_Map_%s_%s.json")
        :format(tostring(game.PlaceId),stamp)

    local errors = {}

    if API.writefile then
        for _, candidate in ipairs(buildSaveCandidates(fileName)) do
            local path = candidate.path
            local parent = parentPath(path)

            if parent then
                ensureFolder(parent)
            end

            local okWrite, errWrite = pcall(API.writefile,path,json)

            if okWrite then
                local verified, verifyErr = verifyFile(path,json)

                if verified then
                    return true,{
                        method="file",
                        path=path,
                        label=candidate.label,
                        bytes=#json,
                        verified=(API.isfile ~= nil or API.readfile ~= nil)
                    }
                end

                table.insert(errors,path.." -> "..tostring(verifyErr))
            else
                table.insert(errors,path.." -> "..tostring(errWrite))
            end
        end
    else
        table.insert(errors,"writefile indisponível")
    end

    if API.setclipboard then
        local okClip, errClip = pcall(API.setclipboard,json)

        if okClip then
            return true,{
                method="clipboard",
                bytes=#json,
                message="Arquivo não pôde ser gravado; JSON copiado para a área de transferência.",
                writeErrors=errors
            }
        end

        table.insert(errors,"setclipboard -> "..tostring(errClip))
    end

    print("=== StudioLite Map Export (JSON) ===")
    print(json)

    return true,{
        method="console",
        bytes=#json,
        message="Nenhuma gravação utilizável; JSON enviado ao console.",
        writeErrors=errors
    }
end

-------------------------------------------------
-- UI
-------------------------------------------------
local parent

do
    if type(globalValue("gethui")) == "function" then
        local ok, result = pcall(globalValue("gethui"))
        if ok and result then
            parent = result
        end
    end

    if not parent then
        local ok, cg = pcall(function()
            return game:GetService("CoreGui")
        end)
        if ok then parent = cg end
    end

    if not parent and LocalPlayer then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

if not parent then
    error("Map Exporter: não foi possível criar a interface.")
end

local old = parent:FindFirstChild("StudioLiteMapExporter")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLiteMapExporter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = parent

local FRAME_W, FRAME_H = 350, 438

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(FRAME_W,FRAME_H)
frame.Position = UDim2.new(0.5,-FRAME_W/2,0.5,-FRAME_H/2)
frame.BackgroundColor3 = Color3.fromRGB(20,22,28)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner",frame).CornerRadius = UDim.new(0,12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65,70,85)
stroke.Thickness = 1
stroke.Parent = frame

local top = Instance.new("TextLabel")
top.Size = UDim2.new(1,-48,0,48)
top.Position = UDim2.fromOffset(14,0)
top.BackgroundTransparency = 1
top.Text = "MAP EXPORTER MOBILE V3"
top.TextColor3 = Color3.fromRGB(245,245,250)
top.TextSize = 18
top.Font = Enum.Font.GothamBold
top.TextXAlignment = Enum.TextXAlignment.Left
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
Instance.new("UICorner",close).CornerRadius = UDim.new(0,9)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,160)
info.Position = UDim2.fromOffset(14,54)
info.BackgroundColor3 = Color3.fromRGB(29,32,40)
info.TextColor3 = Color3.fromRGB(205,210,220)
info.TextSize = 12
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Parent = frame
Instance.new("UICorner",info).CornerRadius = UDim.new(0,9)

local function apiMark(name)
    return API[name] and "SIM" or "NÃO"
end

local function buildApiReport()
    local ws = getWorkspacePath()
    return table.concat({
        "APIs:",
        "writefile: "..apiMark("writefile"),
        "readfile: "..apiMark("readfile"),
        "isfile: "..apiMark("isfile"),
        "makefolder: "..apiMark("makefolder"),
        "setclipboard: "..apiMark("setclipboard"),
        "getworkspace: "..apiMark("getworkspace"),
        "workspace: "..(ws or "<não exposto>")
    },"\n")
end

local function baseInfoText(objCount,assetCount,statusText)
    return ("Objetos: %d\nAssets: %d\n%s\nStatus: %s")
        :format(objCount,assetCount,buildApiReport(),statusText or "pronto")
end

info.Text = baseInfoText(0,0,"pronto")

local function makeButton(text,y,color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-28,0,46)
    b.Position = UDim2.fromOffset(14,y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Text = text
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.Parent = frame
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,9)
    return b
end

local scanBtn = makeButton("ESCANEAR MAPA",224,Color3.fromRGB(56,105,245))
local exportBtn = makeButton("EXPORTAR E SALVAR",278,Color3.fromRGB(46,160,90))

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,100)
status.Position = UDim2.fromOffset(14,332)
status.BackgroundTransparency = 1
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(155,160,175)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Pronto."
status.Parent = frame

-------------------------------------------------
-- ESTADO
-------------------------------------------------
local busy = false
local lastPayload

local function setStatus(text)
    status.Text = tostring(text)
end

local function refreshStats(payload,label)
    local oc = payload and payload.stats and payload.stats.objects or 0
    local ac = payload and payload.stats and payload.stats.assets or 0
    info.Text = baseInfoText(oc,ac,label)
end

-------------------------------------------------
-- SCAN
-------------------------------------------------
local function runScan()
    if busy then return false end

    busy = true
    scanBtn.Text = "ESCANEANDO..."
    exportBtn.Active = false
    exportBtn.AutoButtonColor = false
    setStatus("Lendo objetos visíveis ao cliente...")

    local ok, result = pcall(function()
        return buildPayload(function(processed,objects,assets)
            info.Text = ("Objetos: %d\nAssets: %d\nAnalisando: %d\n%s\nStatus: escaneando")
                :format(objects,assets,processed,buildApiReport())
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
-- EXPORTAR
-------------------------------------------------
exportBtn.MouseButton1Click:Connect(function()
    if busy then return end

    task.spawn(function()
        if not lastPayload then
            local scanOk = runScan()
            if not scanOk or not lastPayload then
                return
            end
        end

        busy = true
        scanBtn.Active = false
        exportBtn.Text = "SALVANDO..."
        setStatus("Gerando JSON e testando locais de gravação...")

        local callOk, ok, result = pcall(function()
            local saveOk, saveResult = savePayload(lastPayload)
            return saveOk,saveResult
        end)

        if not callOk then
            setStatus("ERRO inesperado ao exportar:\n"..tostring(ok))
            refreshStats(lastPayload,"erro ao salvar")
        elseif ok and type(result) == "table" then
            if result.method == "file" then
                local verification = result.verified and "verificado" or "gravado"
                setStatus(
                    ("SUCESSO!\n%s\n%s\n%d bytes (%s)")
                    :format(
                        tostring(result.label or "Arquivo"),
                        tostring(result.path),
                        tonumber(result.bytes) or 0,
                        verification
                    )
                )
                refreshStats(lastPayload,"exportado")
            elseif result.method == "clipboard" then
                setStatus(
                    ("JSON copiado para a área de transferência.\n%d bytes\nDownload/Workspace não aceitaram gravação.")
                    :format(tonumber(result.bytes) or 0)
                )
                refreshStats(lastPayload,"clipboard")
            else
                local extra = ""
                if result.writeErrors and #result.writeErrors > 0 then
                    extra = "\nÚltimo erro: "..tostring(result.writeErrors[#result.writeErrors])
                end
                setStatus(
                    ("JSON enviado ao console (%d bytes).%s")
                    :format(tonumber(result.bytes) or 0,extra)
                )
                refreshStats(lastPayload,"console")
            end
        else
            local message = type(result) == "table"
                and result.message
                or tostring(result)
            setStatus("ERRO ao salvar:\n"..tostring(message))
            refreshStats(lastPayload,"erro ao salvar")
        end

        exportBtn.Text = "EXPORTAR E SALVAR"
        scanBtn.Active = true
        busy = false
    end)
end)

-------------------------------------------------
-- ARRASTAR
-------------------------------------------------
local dragging = false
local dragStart
local startPos
local activeInput

top.Active = true

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        activeInput = input
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging or not dragStart or not startPos then
        return
    end

    if activeInput and activeInput.UserInputType == Enum.UserInputType.Touch then
        if input ~= activeInput then
            return
        end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end

    local delta = input.Position - dragStart

    frame.Position = UDim2.new(
        startPos.X.Scale,startPos.X.Offset + delta.X,
        startPos.Y.Scale,startPos.Y.Offset + delta.Y
    )
end)

UIS.InputEnded:Connect(function(input)
    if input == activeInput
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        activeInput = nil
    end
end)

print("[Studio Lite Map Exporter V3] carregado.")
