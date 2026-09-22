--==============================================================
-- StudioLite Map Exporter Mobile V5
-- Export de alta fidelidade, com IDs internos + referências.
-- Processamento em lotes para reduzir travamentos no celular.
--
-- Limite inevitável:
-- exporta somente dados visíveis ao cliente/ambiente atual.
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
    ExportWorkspace = true,
    ExportLightingChildren = true,
    ExportReplicatedStorage = true,
    ExportReplicatedFirst = true,
    ExportStarterGui = true,
    ExportStarterPack = true,
    ExportStarterPlayer = true,
    ExportSoundService = true,
    ExportMaterialService = true,

    ExportAttributes = true,
    ExportTags = true,
    ExportReferences = true,
    ExportTerrain = true,
    ExportCollisionGroups = true,

    -- Segurança de memória no celular.
    TerrainResolution = 4,
    TerrainChunkCells = 12,
    MaxTerrainCells = 450000,

    BatchSize = 120,
    SaveFolder = "StudioLiteExports",
    PrintProgress = true,
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
    writefile = getGlobal("writefile"),
    readfile = getGlobal("readfile"),
    isfile = getGlobal("isfile"),
    makefolder = getGlobal("makefolder"),
    setclipboard = getGlobal("setclipboard"),
    getworkspace = getGlobal("getworkspace"),
    gethui = getGlobal("gethui"),
}

-------------------------------------------------
-- LOG
-------------------------------------------------
local function log(message)
    if CONFIG.PrintProgress then
        print("[StudioLite Exporter V5] "..tostring(message))
    end
end

-------------------------------------------------
-- SERIALIZAÇÃO DE TIPOS ROBLOX
-------------------------------------------------
local function finiteNumber(n)
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
        return 0
    end
    return n
end

local function serializeValue(value)
    local t = typeof(value)

    if t == "nil" then
        return nil
    elseif t == "string" or t == "boolean" then
        return value
    elseif t == "number" then
        return finiteNumber(value)
    elseif t == "Vector2" then
        return {__type="Vector2",x=value.X,y=value.Y}
    elseif t == "Vector3" then
        return {__type="Vector3",x=value.X,y=value.Y,z=value.Z}
    elseif t == "Vector3int16" then
        return {__type="Vector3int16",x=value.X,y=value.Y,z=value.Z}
    elseif t == "Color3" then
        return {__type="Color3",r=value.R,g=value.G,b=value.B}
    elseif t == "CFrame" then
        local values = {value:GetComponents()}
        for i = 1, #values do
            values[i] = finiteNumber(values[i])
        end
        return {__type="CFrame",values=values}
    elseif t == "UDim" then
        return {__type="UDim",scale=value.Scale,offset=value.Offset}
    elseif t == "UDim2" then
        return {
            __type="UDim2",
            xs=value.X.Scale,
            xo=value.X.Offset,
            ys=value.Y.Scale,
            yo=value.Y.Offset
        }
    elseif t == "NumberRange" then
        return {__type="NumberRange",min=value.Min,max=value.Max}
    elseif t == "Rect" then
        return {
            __type="Rect",
            min=serializeValue(value.Min),
            max=serializeValue(value.Max)
        }
    elseif t == "EnumItem" then
        return {__type="EnumItem",value=tostring(value)}
    elseif t == "BrickColor" then
        return {__type="BrickColor",number=value.Number,name=value.Name}
    elseif t == "ColorSequence" then
        local out = {__type="ColorSequence",keypoints={}}
        for _, kp in ipairs(value.Keypoints) do
            out.keypoints[#out.keypoints + 1] = {
                time=finiteNumber(kp.Time),
                color=serializeValue(kp.Value)
            }
        end
        return out
    elseif t == "NumberSequence" then
        local out = {__type="NumberSequence",keypoints={}}
        for _, kp in ipairs(value.Keypoints) do
            out.keypoints[#out.keypoints + 1] = {
                time=finiteNumber(kp.Time),
                value=finiteNumber(kp.Value),
                envelope=finiteNumber(kp.Envelope)
            }
        end
        return out
    elseif t == "PhysicalProperties" then
        return {
            __type="PhysicalProperties",
            density=value.Density,
            friction=value.Friction,
            elasticity=value.Elasticity,
            frictionWeight=value.FrictionWeight,
            elasticityWeight=value.ElasticityWeight
        }
    end

    return tostring(value)
end

local function safeGet(instance, property)
    local ok, value = pcall(function()
        return instance[property]
    end)

    if ok then
        return value
    end

    return nil
end

local function addProperty(out, instance, property, key)
    local value = safeGet(instance,property)

    if value ~= nil then
        out[key or property] = serializeValue(value)
    end
end

-------------------------------------------------
-- PROPRIEDADES
-------------------------------------------------
local COMMON_PROPERTIES = {
    "Archivable"
}

local CLASS_PROPERTIES = {
    BasePart={
        "CFrame","Size","Color","BrickColor","Material","MaterialVariant",
        "Transparency","Reflectance","Anchored","CanCollide","CanTouch",
        "CanQuery","CastShadow","CollisionGroup","Massless",
        "RootPriority","CustomPhysicalProperties"
    },
    Part={"Shape"},
    MeshPart={
        "MeshId","TextureID","DoubleSided","RenderFidelity",
        "CollisionFidelity"
    },
    SpecialMesh={
        "MeshId","TextureId","MeshType","Scale","Offset","VertexColor"
    },
    Model={"WorldPivot","LevelOfDetail","ModelStreamingMode"},
    Attachment={
        "CFrame","Position","Orientation","Axis","SecondaryAxis","Visible"
    },
    Weld={"C0","C1","Enabled"},
    Motor6D={"C0","C1","Enabled","Transform"},
    Snap={"C0","C1","Enabled"},
    ManualWeld={"C0","C1","Enabled"},
    Rotate={"C0","C1","Enabled"},
    Glue={"C0","C1","Enabled"},
    WeldConstraint={"Enabled"},
    HingeConstraint={
        "ActuatorType","AngularSpeed","AngularVelocity","LimitsEnabled",
        "LowerAngle","UpperAngle","MotorMaxAcceleration","MotorMaxTorque",
        "Radius","Restitution","ServoMaxTorque","TargetAngle"
    },
    BallSocketConstraint={
        "LimitsEnabled","MaxFrictionTorque","Radius",
        "Restitution","TwistLimitsEnabled","TwistLowerAngle",
        "TwistUpperAngle","UpperAngle"
    },
    RopeConstraint={
        "Length","Restitution","Thickness","Visible","WinchEnabled",
        "WinchForce","WinchResponsiveness","WinchSpeed","WinchTarget"
    },
    RodConstraint={"Length","LimitAngle0","LimitAngle1","Thickness","Visible"},
    SpringConstraint={
        "Coils","Damping","FreeLength","LimitsEnabled","MaxForce",
        "MaxLength","MinLength","Radius","Stiffness","Thickness","Visible"
    },
    CylindricalConstraint={
        "ActuatorType","AngularActuatorType","AngularLimitsEnabled",
        "AngularRestitution","AngularSpeed","AngularVelocity",
        "InclinationAngle","LimitsEnabled","LinearResponsiveness",
        "LowerAngle","LowerLimit","MotorMaxAngularAcceleration",
        "MotorMaxForce","MotorMaxTorque","RotationAxisVisible",
        "ServoMaxForce","ServoMaxTorque","Speed","TargetAngle",
        "TargetPosition","UpperAngle","UpperLimit","Velocity"
    },
    PrismaticConstraint={
        "ActuatorType","LimitsEnabled","LinearResponsiveness",
        "LowerLimit","MotorMaxAcceleration","MotorMaxForce",
        "Restitution","ServoMaxForce","Size","Speed",
        "TargetPosition","UpperLimit","Velocity"
    },
    AlignPosition={
        "ApplyAtCenterOfMass","ForceLimitMode","MaxAxesForce",
        "MaxForce","MaxVelocity","Mode","Position","ReactionForceEnabled",
        "Responsiveness","RigidityEnabled"
    },
    AlignOrientation={
        "AlignType","CFrame","MaxAngularVelocity","MaxTorque",
        "Mode","PrimaryAxis","PrimaryAxisOnly","ReactionTorqueEnabled",
        "Responsiveness","RigidityEnabled","SecondaryAxis"
    },
    VectorForce={"ApplyAtCenterOfMass","Force","RelativeTo"},
    LineForce={"ApplyAtCenterOfMass","InverseSquareLaw","Magnitude","MaxForce","ReactionForceEnabled"},
    Torque={"RelativeTo","Torque"},
    AngularVelocity={"AngularVelocity","MaxTorque","ReactionTorqueEnabled","RelativeTo"},
    LinearVelocity={"LineDirection","LineVelocity","MaxAxesForce","MaxForce","PlaneVelocity","PrimaryTangentAxis","RelativeTo","SecondaryTangentAxis","VectorVelocity","VelocityConstraintMode"},
    Decal={"Texture","Color3","Transparency","Face","ZIndex"},
    Texture={"Texture","Color3","Transparency","Face","StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV","ZIndex"},
    SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap","AlphaMode"},
    Sound={"SoundId","Volume","PlaybackSpeed","Looped","TimePosition","RollOffMaxDistance","RollOffMinDistance","RollOffMode","EmitterSize","Playing"},
    ParticleEmitter={
        "Texture","Enabled","Rate","Lifetime","Speed","LightEmission",
        "LightInfluence","LockedToPart","Orientation","Rotation",
        "RotSpeed","SpreadAngle","VelocityInheritance","Color",
        "Transparency","Size","Acceleration","Drag","EmissionDirection",
        "FlipbookFramerate","FlipbookLayout","FlipbookMode",
        "FlipbookStartRandom","Shape","ShapeInOut","ShapePartial",
        "ShapeStyle","Squash","TimeScale","WindAffectsDrag"
    },
    Beam={
        "Texture","TextureLength","TextureMode","TextureSpeed",
        "Width0","Width1","CurveSize0","CurveSize1","FaceCamera",
        "LightEmission","LightInfluence","Color","Transparency",
        "Segments","ZOffset","Enabled"
    },
    Trail={
        "Texture","TextureLength","TextureMode","Lifetime","MinLength",
        "FaceCamera","LightEmission","LightInfluence","Color",
        "Transparency","WidthScale","Enabled"
    },
    Smoke={"Color","Enabled","Opacity","RiseVelocity","Size","TimeScale"},
    Fire={"Color","Enabled","Heat","SecondaryColor","Size","TimeScale"},
    Sparkles={"Enabled","SparkleColor","TimeScale"},
    PointLight={"Brightness","Color","Enabled","Range","Shadows"},
    SpotLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
    SurfaceLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
    Atmosphere={"Color","Decay","Density","Glare","Haze","Offset"},
    BloomEffect={"Enabled","Intensity","Size","Threshold"},
    BlurEffect={"Enabled","Size"},
    ColorCorrectionEffect={"Enabled","Brightness","Contrast","Saturation","TintColor"},
    DepthOfFieldEffect={"Enabled","FarIntensity","FocusDistance","InFocusRadius","NearIntensity"},
    SunRaysEffect={"Enabled","Intensity","Spread"},
    Sky={"CelestialBodiesShown","MoonAngularSize","MoonTextureId","SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxOrientation","SkyboxRt","SkyboxUp","StarCount","SunAngularSize","SunTextureId"},
    Clouds={"Color","Cover","Density","Enabled"},
    BillboardGui={
        "Active","AlwaysOnTop","Brightness","ClipsDescendants","Enabled",
        "LightInfluence","MaxDistance","Size","SizeOffset","StudsOffset",
        "StudsOffsetWorldSpace"
    },
    SurfaceGui={
        "Active","AlwaysOnTop","Brightness","CanvasSize","ClipsDescendants",
        "Enabled","Face","LightInfluence","MaxDistance","PixelsPerStud",
        "SizingMode","ToolPunchThroughDistance","ZOffset"
    },
    ScreenGui={"DisplayOrder","Enabled","IgnoreGuiInset","ResetOnSpawn","ZIndexBehavior","SafeAreaCompatibility","ScreenInsets"},
    GuiObject={
        "Active","AnchorPoint","AutomaticSize","BackgroundColor3",
        "BackgroundTransparency","BorderColor3","BorderMode","BorderSizePixel",
        "ClipsDescendants","LayoutOrder","Position","Rotation","Selectable",
        "SelectionOrder","Size","Visible","ZIndex"
    },
    TextLabel={
        "ContentText","Font","FontFace","LineHeight","MaxVisibleGraphemes",
        "RichText","Text","TextColor3","TextDirection","TextScaled",
        "TextSize","TextStrokeColor3","TextStrokeTransparency",
        "TextTransparency","TextTruncate","TextWrapped","TextXAlignment",
        "TextYAlignment"
    },
    TextButton={
        "AutoButtonColor","ContentText","Font","FontFace","LineHeight",
        "MaxVisibleGraphemes","Modal","RichText","Selected","Style",
        "Text","TextColor3","TextDirection","TextScaled","TextSize",
        "TextStrokeColor3","TextStrokeTransparency","TextTransparency",
        "TextTruncate","TextWrapped","TextXAlignment","TextYAlignment"
    },
    TextBox={
        "ClearTextOnFocus","ContentText","CursorPosition","Font","FontFace",
        "LineHeight","MaxVisibleGraphemes","MultiLine","PlaceholderColor3",
        "PlaceholderText","RichText","SelectionStart","ShowNativeInput",
        "Text","TextColor3","TextDirection","TextEditable","TextScaled",
        "TextSize","TextStrokeColor3","TextStrokeTransparency",
        "TextTransparency","TextTruncate","TextWrapped","TextXAlignment",
        "TextYAlignment"
    },
    ImageLabel={
        "Image","ImageColor3","ImageRectOffset","ImageRectSize",
        "ImageTransparency","ResampleMode","ScaleType","SliceCenter",
        "SliceScale","TileSize"
    },
    ImageButton={
        "AutoButtonColor","Image","ImageColor3","ImageRectOffset",
        "ImageRectSize","ImageTransparency","Modal","ResampleMode",
        "ScaleType","Selected","SliceCenter","SliceScale","Style","TileSize"
    },
    Frame={"Style"},
    ScrollingFrame={
        "AutomaticCanvasSize","BottomImage","CanvasPosition","CanvasSize",
        "ElasticBehavior","HorizontalScrollBarInset","MidImage",
        "ScrollBarImageColor3","ScrollBarImageTransparency",
        "ScrollBarThickness","ScrollingDirection","ScrollingEnabled",
        "TopImage","VerticalScrollBarInset","VerticalScrollBarPosition"
    },
    UIStroke={"ApplyStrokeMode","Color","Enabled","LineJoinMode","Thickness","Transparency"},
    UIGradient={"Color","Enabled","Offset","Rotation","Transparency"},
    UICorner={"CornerRadius"},
    UIAspectRatioConstraint={"AspectRatio","AspectType","DominantAxis"},
    UIScale={"Scale"},
    UIPadding={"PaddingBottom","PaddingLeft","PaddingRight","PaddingTop"},
    UIListLayout={"FillDirection","HorizontalAlignment","HorizontalFlex","ItemLineAlignment","Padding","SortOrder","VerticalAlignment","VerticalFlex","Wraps"},
    UIGridLayout={"CellPadding","CellSize","FillDirection","FillDirectionMaxCells","HorizontalAlignment","SortOrder","StartCorner","VerticalAlignment"},
    UITableLayout={"FillEmptySpaceColumns","FillEmptySpaceRows","MajorAxis","Padding"},
    ProximityPrompt={
        "ActionText","ClickablePrompt","Enabled","Exclusivity",
        "GamepadKeyCode","HoldDuration","KeyboardKeyCode",
        "MaxActivationDistance","ObjectText","RequiresLineOfSight","Style"
    },
    ClickDetector={"CursorIcon","MaxActivationDistance"},
    Highlight={"DepthMode","Enabled","FillColor","FillTransparency","OutlineColor","OutlineTransparency"},
    SpawnLocation={"AllowTeamChangeOnTouch","Duration","Enabled","Neutral","TeamColor"},
    Seat={"Disabled","Occupant"},
    VehicleSeat={"Disabled","HeadsUpDisplay","MaxSpeed","Steer","SteerFloat","Throttle","ThrottleFloat","Torque","TurnSpeed"},
    Animation={"AnimationId"},
    Shirt={"ShirtTemplate","Color3"},
    Pants={"PantsTemplate","Color3"},
    ShirtGraphic={"Graphic","Color3"},
    MaterialVariant={"BaseMaterial","ColorMap","MaterialPattern","MetalnessMap","NormalMap","RoughnessMap","StudsPerTile"},
}

-------------------------------------------------
-- REFERÊNCIAS ENTRE OBJETOS
-------------------------------------------------
local REFERENCE_PROPERTIES = {
    Model={"PrimaryPart"},
    Weld={"Part0","Part1"},
    Motor6D={"Part0","Part1"},
    Snap={"Part0","Part1"},
    ManualWeld={"Part0","Part1"},
    Rotate={"Part0","Part1"},
    Glue={"Part0","Part1"},
    WeldConstraint={"Part0","Part1"},
    HingeConstraint={"Attachment0","Attachment1"},
    BallSocketConstraint={"Attachment0","Attachment1"},
    RopeConstraint={"Attachment0","Attachment1"},
    RodConstraint={"Attachment0","Attachment1"},
    SpringConstraint={"Attachment0","Attachment1"},
    CylindricalConstraint={"Attachment0","Attachment1"},
    PrismaticConstraint={"Attachment0","Attachment1"},
    AlignPosition={"Attachment0","Attachment1"},
    AlignOrientation={"Attachment0","Attachment1"},
    VectorForce={"Attachment0"},
    LineForce={"Attachment0","Attachment1"},
    Torque={"Attachment0"},
    AngularVelocity={"Attachment0"},
    LinearVelocity={"Attachment0"},
    Beam={"Attachment0","Attachment1"},
    Trail={"Attachment0","Attachment1"},
    BillboardGui={"Adornee"},
    SurfaceGui={"Adornee"},
    Highlight={"Adornee"},
    ObjectValue={"Value"},
}

-------------------------------------------------
-- ROOTS EXPORTADOS
-------------------------------------------------
local ROOTS = {}

local function addRoot(name, object, enabled)
    if enabled and object then
        ROOTS[#ROOTS + 1] = {
            name=name,
            object=object
        }
    end
end

addRoot("Workspace",Workspace,CONFIG.ExportWorkspace)
addRoot("Lighting",Lighting,CONFIG.ExportLightingChildren)
addRoot("ReplicatedStorage",ReplicatedStorage,CONFIG.ExportReplicatedStorage)
addRoot("ReplicatedFirst",ReplicatedFirst,CONFIG.ExportReplicatedFirst)
addRoot("StarterGui",StarterGui,CONFIG.ExportStarterGui)
addRoot("StarterPack",StarterPack,CONFIG.ExportStarterPack)
addRoot("StarterPlayer",StarterPlayer,CONFIG.ExportStarterPlayer)
addRoot("SoundService",SoundService,CONFIG.ExportSoundService)
addRoot("MaterialService",MaterialService,CONFIG.ExportMaterialService)

-------------------------------------------------
-- FILTROS
-------------------------------------------------
local function shouldSkip(instance)
    local char = LocalPlayer and LocalPlayer.Character

    if char and (instance == char or instance:IsDescendantOf(char)) then
        return true
    end

    return false
end

-------------------------------------------------
-- COLETA / IDs
-------------------------------------------------
local function collectInstances(progress)
    local entries = {}
    local idByInstance = {}
    local nextId = 1
    local seen = {}

    for _, root in ipairs(ROOTS) do
        local descendants = root.object:GetDescendants()

        for _, instance in ipairs(descendants) do
            if not shouldSkip(instance) and not seen[instance] then
                seen[instance] = true
                idByInstance[instance] = nextId

                entries[#entries + 1] = {
                    id=nextId,
                    root=root.name,
                    instance=instance
                }

                nextId = nextId + 1

                if CONFIG.BatchSize > 0
                    and #entries % CONFIG.BatchSize == 0
                then
                    if progress then
                        progress("indexando",#entries,0)
                    end
                    task.wait()
                end
            end
        end
    end

    return entries,idByInstance
end

local function collectProperties(instance)
    local out = {}

    for _, property in ipairs(COMMON_PROPERTIES) do
        addProperty(out,instance,property)
    end

    for className, properties in pairs(CLASS_PROPERTIES) do
        if instance:IsA(className) then
            for _, property in ipairs(properties) do
                addProperty(out,instance,property)
            end
        end
    end

    return out
end

local function collectAttributes(instance)
    if not CONFIG.ExportAttributes then
        return {}
    end

    local out = {}
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if ok and type(attributes) == "table" then
        for key, value in pairs(attributes) do
            out[tostring(key)] = serializeValue(value)
        end
    end

    return out
end

local function collectTags(instance)
    if not CONFIG.ExportTags then
        return {}
    end

    local ok, tags = pcall(function()
        return CollectionService:GetTags(instance)
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

local function collectReferences(instance,idByInstance)
    if not CONFIG.ExportReferences then
        return {}
    end

    local refs = {}

    for className, properties in pairs(REFERENCE_PROPERTIES) do
        if instance:IsA(className) then
            for _, property in ipairs(properties) do
                local target = safeGet(instance,property)

                if typeof(target) == "Instance" then
                    local targetId = idByInstance[target]

                    if targetId then
                        refs[property] = {
                            id=targetId
                        }
                    else
                        local ok, fullName = pcall(function()
                            return target:GetFullName()
                        end)

                        refs[property] = {
                            externalPath=ok and fullName or target.Name
                        }
                    end
                end
            end
        end
    end

    return refs
end

-------------------------------------------------
-- SERVICE PROPERTIES
-------------------------------------------------
local SERVICE_PROPERTIES = {
    Workspace={
        "Gravity","FallenPartsDestroyHeight","GlobalWind",
        "StreamingEnabled","StreamingMinRadius","StreamingTargetRadius"
    },
    Lighting={
        "Ambient","OutdoorAmbient","Brightness","ClockTime",
        "GeographicLatitude","ExposureCompensation",
        "EnvironmentDiffuseScale","EnvironmentSpecularScale",
        "FogColor","FogStart","FogEnd","GlobalShadows","ShadowSoftness"
    },
    SoundService={
        "AmbientReverb","DistanceFactor","DopplerScale",
        "RespectFilteringEnabled","RolloffScale"
    },
    MaterialService={
        "Use2022Materials"
    },
    StarterGui={
        "ResetPlayerGuiOnSpawn"
    },
}

local SERVICE_OBJECTS = {
    Workspace=Workspace,
    Lighting=Lighting,
    SoundService=SoundService,
    MaterialService=MaterialService,
    StarterGui=StarterGui,
}

local function collectServiceProperties()
    local result = {}

    for serviceName, properties in pairs(SERVICE_PROPERTIES) do
        local service = SERVICE_OBJECTS[serviceName]

        if service then
            local values = {}

            for _, property in ipairs(properties) do
                addProperty(values,service,property)
            end

            result[serviceName] = values
        end
    end

    return result
end

-------------------------------------------------
-- COLLISION GROUPS
-------------------------------------------------
local function collectCollisionGroups()
    if not CONFIG.ExportCollisionGroups then
        return {}
    end

    local ok, groups = pcall(function()
        return PhysicsService:GetRegisteredCollisionGroups()
    end)

    if not ok or type(groups) ~= "table" then
        return {}
    end

    local out = {}

    for _, group in ipairs(groups) do
        if type(group) == "table" then
            out[#out + 1] = {
                name=tostring(group.name or group.Name or ""),
                mask=group.mask or group.Mask
            }
        end
    end

    return out
end

-------------------------------------------------
-- TERRAIN
-------------------------------------------------
local function exportTerrain(progress)
    if not CONFIG.ExportTerrain then
        return {
            enabled=false,
            reason="desativado"
        }
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")

    if not terrain then
        return {
            enabled=false,
            reason="Terrain não encontrado"
        }
    end

    local okExtents, extents = pcall(function()
        return terrain.MaxExtents
    end)

    if not okExtents or not extents then
        return {
            enabled=false,
            reason="MaxExtents indisponível"
        }
    end

    local minCell = extents.Min
    local maxCell = extents.Max

    local sizeX = math.max(0,maxCell.X - minCell.X)
    local sizeY = math.max(0,maxCell.Y - minCell.Y)
    local sizeZ = math.max(0,maxCell.Z - minCell.Z)
    local cellCount = sizeX * sizeY * sizeZ

    if cellCount <= 0 then
        return {
            enabled=true,
            empty=true,
            resolution=CONFIG.TerrainResolution,
            chunks={}
        }
    end

    if cellCount > CONFIG.MaxTerrainCells then
        return {
            enabled=false,
            skipped=true,
            cellCount=cellCount,
            reason="Terrain excede MaxTerrainCells ("..tostring(CONFIG.MaxTerrainCells)..")"
        }
    end

    local chunks = {}
    local chunkCells = math.max(1,CONFIG.TerrainChunkCells)
    local processed = 0

    for x = minCell.X, maxCell.X - 1, chunkCells do
        local x2 = math.min(x + chunkCells,maxCell.X)

        for y = minCell.Y, maxCell.Y - 1, chunkCells do
            local y2 = math.min(y + chunkCells,maxCell.Y)

            for z = minCell.Z, maxCell.Z - 1, chunkCells do
                local z2 = math.min(z + chunkCells,maxCell.Z)

                local worldMin = Vector3.new(
                    x * CONFIG.TerrainResolution,
                    y * CONFIG.TerrainResolution,
                    z * CONFIG.TerrainResolution
                )

                local worldMax = Vector3.new(
                    x2 * CONFIG.TerrainResolution,
                    y2 * CONFIG.TerrainResolution,
                    z2 * CONFIG.TerrainResolution
                )

                local region = Region3.new(worldMin,worldMax):
                    ExpandToGrid(CONFIG.TerrainResolution)

                local okRead, materials, occupancy = pcall(function()
                    return terrain:ReadVoxels(
                        region,
                        CONFIG.TerrainResolution
                    )
                end)

                if okRead
                    and type(materials) == "table"
                    and type(occupancy) == "table"
                then
                    local flatMaterials = {}
                    local flatOccupancy = {}
                    local count = 0

                    for ix = 1, #materials do
                        local planeM = materials[ix]
                        local planeO = occupancy[ix]

                        for iy = 1, #planeM do
                            local rowM = planeM[iy]
                            local rowO = planeO[iy]

                            for iz = 1, #rowM do
                                count = count + 1

                                local material = rowM[iz]
                                flatMaterials[count] =
                                    typeof(material) == "EnumItem"
                                    and tostring(material)
                                    or tostring(material)

                                flatOccupancy[count] =
                                    finiteNumber(rowO[iz] or 0)
                            end
                        end
                    end

                    chunks[#chunks + 1] = {
                        minCell={x=x,y=y,z=z},
                        size={
                            x=x2-x,
                            y=y2-y,
                            z=z2-z
                        },
                        materials=flatMaterials,
                        occupancy=flatOccupancy
                    }
                end

                processed = processed + 1

                if processed % 2 == 0 then
                    if progress then
                        progress("terrain",processed,0)
                    end
                    task.wait()
                end
            end
        end
    end

    return {
        enabled=true,
        resolution=CONFIG.TerrainResolution,
        minCell={x=minCell.X,y=minCell.Y,z=minCell.Z},
        maxCell={x=maxCell.X,y=maxCell.Y,z=maxCell.Z},
        cellCount=cellCount,
        chunks=chunks
    }
end

-------------------------------------------------
-- PAYLOAD
-------------------------------------------------
local function buildPayload(progress)
    local entries,idByInstance =
        collectInstances(progress)

    local payload = {
        format="StudioLiteMapExport",
        version=5,
        placeId=game.PlaceId,
        gameId=game.GameId,
        placeVersion=game.PlaceVersion,
        exportedAt=os.time(),
        serviceProperties=collectServiceProperties(),
        collisionGroups=collectCollisionGroups(),
        objects={},
        terrain=nil,
        stats={
            indexed=#entries,
            objects=0,
            references=0,
            propertyCount=0,
            attributeCount=0,
            tagCount=0,
            fallbackNotes={}
        },
        limitations={
            "Only data visible to the current client/environment can be exported.",
            "Server-only source code and non-replicated objects are not present.",
            "Asset IDs can be preserved, but unavailable/private assets may not render after import."
        }
    }

    for index, entry in ipairs(entries) do
        local instance = entry.instance
        local parent = instance.Parent
        local parentId = parent and idByInstance[parent] or nil

        local properties = collectProperties(instance)
        local attributes = collectAttributes(instance)
        local tags = collectTags(instance)
        local references = collectReferences(instance,idByInstance)

        local record = {
            id=entry.id,
            root=entry.root,
            parentId=parentId,
            class=instance.ClassName,
            name=instance.Name,
            properties=properties,
            attributes=attributes,
            tags=tags,
            references=references
        }

        payload.objects[#payload.objects + 1] = record
        payload.stats.objects = payload.stats.objects + 1

        for _ in pairs(properties) do
            payload.stats.propertyCount =
                payload.stats.propertyCount + 1
        end

        for _ in pairs(attributes) do
            payload.stats.attributeCount =
                payload.stats.attributeCount + 1
        end

        payload.stats.tagCount =
            payload.stats.tagCount + #tags

        for _ in pairs(references) do
            payload.stats.references =
                payload.stats.references + 1
        end

        if CONFIG.BatchSize > 0
            and index % CONFIG.BatchSize == 0
        then
            if progress then
                progress(
                    "objetos",
                    index,
                    #entries
                )
            end
            task.wait()
        end
    end

    payload.terrain = exportTerrain(progress)

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

local function sortedNonArrayKeys(tbl,arrayLength)
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
        local ta = type(a)
        local tb = type(b)

        if ta == tb then
            return tostring(a) < tostring(b)
        end

        return ta < tb
    end)

    return keys
end

local function encodeLua(value,output,indent,seen)
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
        output[#output + 1] =
            quoteLuaString("<circular-reference>")
        return
    end

    seen[value] = true

    local pad = string.rep("    ",indent)
    local childPad = string.rep("    ",indent + 1)
    local arrayLength = #value
    local extraKeys =
        sortedNonArrayKeys(value,arrayLength)

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
        "-- Studio Lite Map Export V5\n",
        "-- Generated by StudioLite Map Exporter Mobile V5\n",
        "-- Data-only export. The importer parses this table without executing game code.\n\n",
        "return "
    }

    encodeLua(payload,output,0,{})
    output[#output + 1] = "\n"

    return table.concat(output)
end

-------------------------------------------------
-- SALVAMENTO
-------------------------------------------------
local function normalizePath(path)
    path = tostring(path):gsub("\\","/")
    path = path:gsub("//+","/")
    return path
end

local function parentPath(path)
    return path:match("^(.*)/[^/]+$")
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

local function ensureFolder(path)
    if type(API.makefolder) ~= "function"
        or type(path) ~= "string"
        or path == ""
    then
        return
    end

    pcall(API.makefolder,path)

    if path:sub(1,1) ~= "/" then
        local current = ""

        for part in path:gmatch("[^/]+") do
            current =
                current == ""
                and part
                or (current.."/"..part)

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

local function buildSaveCandidates(fileName)
    local list = {}
    local seen = {}
    local folder = CONFIG.SaveFolder

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
        "/storage/emulated/0/Delta/Workspace/"..folder.."/"..fileName,
        "Delta Workspace"
    )

    addCandidate(
        list,seen,
        "/storage/emulated/0/Delta/Workspace/Studio Lite/"..folder.."/"..fileName,
        "Studio Lite"
    )

    local ws = getWorkspacePath()

    if ws then
        addCandidate(
            list,seen,
            ws.."/"..folder.."/"..fileName,
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
    if type(API.isfile) == "function" then
        local ok, exists = pcall(API.isfile,path)

        if not ok or exists ~= true then
            return false,"isfile não confirmou o arquivo"
        end
    end

    if type(API.readfile) == "function" then
        local ok, data = pcall(API.readfile,path)

        if not ok then
            return false,"readfile não conseguiu reler"
        end

        if type(data) ~= "string" then
            return false,"readfile retornou dado inválido"
        end

        if #data ~= #contents then
            return false,
                "tamanho diferente: "
                ..tostring(#data)
                .." / "
                ..tostring(#contents)
        end
    end

    return true
end

local function savePayload(payload)
    local okSerialize, source =
        pcall(payloadToLua,payload)

    if not okSerialize then
        return false,{
            message="Falha ao gerar arquivo Lua: "..tostring(source)
        }
    end

    local stamp =
        os.date("!%Y%m%d_%H%M%S")

    local fileName =
        ("StudioLite_Map_%s_%s.lua"):
        format(
            tostring(game.PlaceId),
            stamp
        )

    local errors = {}

    if type(API.writefile) == "function" then
        for _, candidate
            in ipairs(
                buildSaveCandidates(fileName)
            )
        do
            local parent =
                parentPath(candidate.path)

            if parent then
                ensureFolder(parent)
            end

            local okWrite, err =
                pcall(
                    API.writefile,
                    candidate.path,
                    source
                )

            if okWrite then
                local verified, verifyError =
                    verifyWrite(
                        candidate.path,
                        source
                    )

                if verified then
                    return true,{
                        method="file",
                        path=candidate.path,
                        label=candidate.label,
                        bytes=#source,
                        verified=true
                    }
                end

                errors[#errors + 1] =
                    candidate.path
                    .." -> "
                    ..tostring(verifyError)
            else
                errors[#errors + 1] =
                    candidate.path
                    .." -> "
                    ..tostring(err)
            end
        end
    else
        errors[#errors + 1] =
            "writefile indisponível"
    end

    if type(API.setclipboard) == "function" then
        local okClip, errClip =
            pcall(
                API.setclipboard,
                source
            )

        if okClip then
            return true,{
                method="clipboard",
                bytes=#source,
                errors=errors
            }
        end

        errors[#errors + 1] =
            "clipboard -> "
            ..tostring(errClip)
    end

    print(source)

    return true,{
        method="console",
        bytes=#source,
        errors=errors
    }
end

-------------------------------------------------
-- UI
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
    error("StudioLite Exporter: interface indisponível.")
end

local old =
    guiParent:
    FindFirstChild(
        "StudioLiteMapExporter"
    )

if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StudioLiteMapExporter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = guiParent

local WIDTH = 360
local HEIGHT = 470

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(WIDTH,HEIGHT)
frame.Position =
    UDim2.new(
        0.5,-WIDTH/2,
        0.5,-HEIGHT/2
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
title.Text = "MAP EXPORTER MOBILE V5"
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

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,190)
info.Position = UDim2.fromOffset(14,54)
info.BackgroundColor3 = Color3.fromRGB(29,32,40)
info.TextColor3 = Color3.fromRGB(205,210,220)
info.TextSize = 12
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextWrapped = true
info.Text = table.concat({
    "Formato: V5 / IDs internos",
    "Objetos: 0",
    "Referências: 0",
    "Propriedades: 0",
    "Terrain: aguardando",
    "Status: pronto",
},"\n")
info.Parent = frame

Instance.new("UICorner",info).CornerRadius =
    UDim.new(0,9)

local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(1,-28,0,48)
scanBtn.Position = UDim2.fromOffset(14,256)
scanBtn.BackgroundColor3 = Color3.fromRGB(56,105,245)
scanBtn.TextColor3 = Color3.fromRGB(255,255,255)
scanBtn.Text = "ESCANEAR MAPA V5"
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = frame

Instance.new("UICorner",scanBtn).CornerRadius =
    UDim.new(0,9)

local exportBtn = Instance.new("TextButton")
exportBtn.Size = UDim2.new(1,-28,0,48)
exportBtn.Position = UDim2.fromOffset(14,314)
exportBtn.BackgroundColor3 = Color3.fromRGB(46,160,90)
exportBtn.TextColor3 = Color3.fromRGB(255,255,255)
exportBtn.Text = "EXPORTAR MAPA V5"
exportBtn.TextSize = 15
exportBtn.Font = Enum.Font.GothamBold
exportBtn.Parent = frame

Instance.new("UICorner",exportBtn).CornerRadius =
    UDim.new(0,9)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,92)
status.Position = UDim2.fromOffset(14,372)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(155,160,175)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text =
    "Processamento em lotes ativo para reduzir travamentos."
status.Parent = frame

local busy = false
local lastPayload = nil

local function setButtonsEnabled(enabled)
    scanBtn.Active = enabled
    exportBtn.Active = enabled
    scanBtn.AutoButtonColor = enabled
    exportBtn.AutoButtonColor = enabled
end

local function refreshInfo(payload,state)
    local stats =
        payload
        and payload.stats
        or {}

    local terrainText = "aguardando"

    if payload and payload.terrain then
        if payload.terrain.enabled then
            terrainText =
                payload.terrain.empty
                and "vazio"
                or (
                    tostring(
                        #(payload.terrain.chunks or {})
                    )
                    .." chunks"
                )
        else
            terrainText =
                "não exportado"
        end
    end

    info.Text = table.concat({
        "Formato: V5 / IDs internos",
        "Objetos: "..tostring(stats.objects or 0),
        "Referências: "..tostring(stats.references or 0),
        "Propriedades: "..tostring(stats.propertyCount or 0),
        "Atributos: "..tostring(stats.attributeCount or 0),
        "Tags: "..tostring(stats.tagCount or 0),
        "Terrain: "..terrainText,
        "Status: "..tostring(state or "pronto"),
    },"\n")
end

local function runScan()
    if busy then
        return false
    end

    busy = true
    setButtonsEnabled(false)
    scanBtn.Text = "ESCANEANDO..."
    status.Text =
        "Indexando objetos e relações..."

    local ok, result =
        pcall(function()
            return buildPayload(
                function(stage,current,total)
                    if stage == "indexando" then
                        status.Text =
                            "Indexando objetos: "
                            ..tostring(current)
                    elseif stage == "objetos" then
                        status.Text =
                            "Serializando: "
                            ..tostring(current)
                            .." / "
                            ..tostring(total)
                    elseif stage == "terrain" then
                        status.Text =
                            "Lendo Terrain: chunk "
                            ..tostring(current)
                    end

                    task.wait()
                end
            )
        end)

    if ok then
        lastPayload = result
        refreshInfo(lastPayload,"escaneado")
        status.Text =
            "Scanner concluído. Pronto para exportar."
    else
        lastPayload = nil
        refreshInfo(nil,"erro")
        status.Text =
            "Erro no scanner:\n"
            ..tostring(result)
    end

    scanBtn.Text = "ESCANEAR MAPA V5"
    setButtonsEnabled(true)
    busy = false

    return ok
end

scanBtn.MouseButton1Click:Connect(function()
    task.spawn(runScan)
end)

exportBtn.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    task.spawn(function()
        if not lastPayload then
            local ok = runScan()

            if not ok or not lastPayload then
                return
            end
        end

        busy = true
        setButtonsEnabled(false)
        exportBtn.Text = "SALVANDO..."
        status.Text =
            "Gerando arquivo Lua V5..."

        local okCall, saveOk, result =
            pcall(function()
                local ok, value =
                    savePayload(lastPayload)

                return ok,value
            end)

        if not okCall then
            status.Text =
                "Erro inesperado:\n"
                ..tostring(saveOk)
            refreshInfo(lastPayload,"erro")
        elseif saveOk
            and type(result) == "table"
        then
            if result.method == "file" then
                status.Text =
                    "SUCESSO\n"
                    ..tostring(result.path)
                    .."\n"
                    ..tostring(result.bytes)
                    .." bytes"
                refreshInfo(lastPayload,"exportado")
            elseif result.method == "clipboard" then
                status.Text =
                    "Arquivo não pôde ser gravado. "
                    .."Conteúdo copiado para clipboard."
                refreshInfo(lastPayload,"clipboard")
            else
                status.Text =
                    "Conteúdo enviado ao console."
                refreshInfo(lastPayload,"console")
            end
        else
            status.Text =
                "Falha ao exportar:\n"
                ..tostring(
                    type(result) == "table"
                    and result.message
                    or result
                )
            refreshInfo(lastPayload,"erro")
        end

        exportBtn.Text = "EXPORTAR MAPA V5"
        setButtonsEnabled(true)
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
    if not dragging or not dragStart or not startPos then
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

log("Map Exporter Mobile V5 carregado.")