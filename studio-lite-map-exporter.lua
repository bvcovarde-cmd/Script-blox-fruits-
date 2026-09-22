-- Studio Lite Map Exporter Mobile
-- Exporta apenas dados visíveis ao cliente. Não lê conteúdo privado do servidor.
-- Salva JSON usando writefile quando disponível no ambiente que executa o script.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LocalPlayer = Players.LocalPlayer

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
	if t == "Vector2" then return {__type="Vector2", x=v.X, y=v.Y} end
	if t == "Vector3" then return {__type="Vector3", x=v.X, y=v.Y, z=v.Z} end
	if t == "Color3" then return {__type="Color3", r=v.R, g=v.G, b=v.B} end
	if t == "CFrame" then return {__type="CFrame", values={v:GetComponents()}} end
	if t == "UDim" then return {__type="UDim", scale=v.Scale, offset=v.Offset} end
	if t == "UDim2" then
		return {__type="UDim2", xs=v.X.Scale, xo=v.X.Offset, ys=v.Y.Scale, yo=v.Y.Offset}
	end
	if t == "NumberRange" then return {__type="NumberRange", min=v.Min, max=v.Max} end
	if t == "EnumItem" then return {__type="EnumItem", value=tostring(v)} end
	if t == "BrickColor" then return {__type="BrickColor", number=v.Number, name=v.Name} end
	if t == "ColorSequence" then
		local out = {__type="ColorSequence", keypoints={}}
		for _,k in ipairs(v.Keypoints) do
			table.insert(out.keypoints,{time=k.Time,color=ser(k.Value)})
		end
		return out
	end
	if t == "NumberSequence" then
		local out = {__type="NumberSequence", keypoints={}}
		for _,k in ipairs(v.Keypoints) do
			table.insert(out.keypoints,{time=k.Time,value=k.Value,envelope=k.Envelope})
		end
		return out
	end
	return tostring(v)
end

local function safeGet(obj, prop)
	local ok, value = pcall(function() return obj[prop] end)
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
	local ok, full = pcall(function() return obj:GetFullName() end)
	return ok and full or obj.Name
end

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
	Sky={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","SunTextureId","MoonTextureId"},
}

local COMMON_PROPS = {
	"Name","Archivable"
}

local CLASS_PROPS = {
	BasePart={"CFrame","Size","Color","Material","MaterialVariant","Transparency","Reflectance","Anchored","CanCollide","CanTouch","CanQuery","CastShadow","CollisionGroup","Massless"},
	Part={"Shape"},
	MeshPart={"MeshId","TextureID","DoubleSided","RenderFidelity","CollisionFidelity"},
	SpecialMesh={"MeshId","TextureId","MeshType","Scale","Offset","VertexColor"},
	Decal={"Texture","Color3","Transparency","Face"},
	Texture={"Texture","Color3","Transparency","Face","StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV"},
	Attachment={"CFrame","Position","Orientation","Axis","SecondaryAxis","Visible"},
	Sound={"SoundId","Volume","PlaybackSpeed","Looped","RollOffMaxDistance","RollOffMinDistance","RollOffMode","EmitterSize"},
	ParticleEmitter={"Texture","Enabled","Rate","Lifetime","Speed","LightEmission","LightInfluence","LockedToPart","Orientation","Rotation","RotSpeed","SpreadAngle","VelocityInheritance","Color","Transparency","Size"},
	Beam={"Texture","TextureLength","TextureMode","TextureSpeed","Width0","Width1","CurveSize0","CurveSize1","FaceCamera","LightEmission","LightInfluence","Color","Transparency","Segments"},
	Trail={"Texture","TextureLength","TextureMode","Lifetime","MinLength","FaceCamera","LightEmission","LightInfluence","Color","Transparency","WidthScale"},
	PointLight={"Brightness","Color","Enabled","Range","Shadows"},
	SpotLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
	SurfaceLight={"Brightness","Color","Enabled","Range","Shadows","Angle","Face"},
	SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap","AlphaMode"},
	Model={"WorldPivot","LevelOfDetail"},
	Animation={"AnimationId"},
	Shirt={"ShirtTemplate","Color3"},
	Pants={"PantsTemplate","Color3"},
	ShirtGraphic={"Graphic","Color3"},
}

local function collectProperties(obj)
	local p = {}
	for _,prop in ipairs(COMMON_PROPS) do addProp(p,obj,prop) end
	for className, props in pairs(CLASS_PROPS) do
		if obj:IsA(className) then
			for _,prop in ipairs(props) do addProp(p,obj,prop) end
		end
	end
	if obj:IsA("Model") then
		local primary = safeGet(obj,"PrimaryPart")
		if primary then p.PrimaryPartPath = pathOf(primary) end
	end
	return p
end

local function collectAttributes(obj)
	local out = {}
	local ok, attrs = pcall(function() return obj:GetAttributes() end)
	if ok then
		for k,v in pairs(attrs) do out[k] = ser(v) end
	end
	return out
end

local function collectTags(obj)
	local ok, tags = pcall(function() return CollectionService:GetTags(obj) end)
	return ok and tags or {}
end

local function isLocalCharacterObject(obj)
	local char = LocalPlayer and LocalPlayer.Character
	return char and (obj == char or obj:IsDescendantOf(char))
end

local roots = {
	{service="Workspace", object=workspace},
	{service="Lighting", object=Lighting},
	{service="ReplicatedStorage", object=ReplicatedStorage},
	{service="ReplicatedFirst", object=ReplicatedFirst},
}

local function readLighting()
	local props = {
		"Ambient","OutdoorAmbient","Brightness","ClockTime","GeographicLatitude",
		"ExposureCompensation","EnvironmentDiffuseScale","EnvironmentSpecularScale",
		"FogColor","FogStart","FogEnd","GlobalShadows","ShadowSoftness"
	}
	local out = {}
	for _,prop in ipairs(props) do addProp(out,Lighting,prop) end
	return out
end

local function buildPayload(progress)
	local payload = {
		format="StudioLiteMapExport",
		version=2,
		placeId=game.PlaceId,
		gameId=game.GameId,
		placeVersion=game.PlaceVersion,
		exportedAt=os.time(),
		lighting=readLighting(),
		objects={},
		assets={},
		stats={objects=0,assets=0,skipped=0},
		notes={
			"Export contains only objects/properties visible to the client.",
			"Server-only objects, private scripts, and hidden source are not exported.",
			"Terrain voxel data is not included by this mobile exporter."
		}
	}

	local assetSeen = {}
	local processed = 0

	for _,root in ipairs(roots) do
		local list = root.object:GetDescendants()
		for _,obj in ipairs(list) do
			processed += 1
			if not isLocalCharacterObject(obj) then
				local record = {
					class=obj.ClassName,
					name=obj.Name,
					path=pathOf(obj),
					parent=obj.Parent and pathOf(obj.Parent) or nil,
					root=root.service,
					properties=collectProperties(obj),
					attributes=collectAttributes(obj),
					tags=collectTags(obj),
				}
				table.insert(payload.objects,record)
				payload.stats.objects += 1

				for className, props in pairs(ASSET_PROPS) do
					if obj:IsA(className) then
						for _,prop in ipairs(props) do
							local value = safeGet(obj,prop)
							if typeof(value) == "string" and value ~= "" then
								local key = className.."|"..prop.."|"..value
								if not assetSeen[key] then
									assetSeen[key] = true
									table.insert(payload.assets,{
										class=className,
										property=prop,
										value=value,
										firstPath=pathOf(obj),
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

			if processed % 250 == 0 then
				if progress then progress(processed,payload.stats.objects,payload.stats.assets) end
				task.wait()
			end
		end
	end

	return payload
end

local function savePayload(payload)
	local okEncode, json = pcall(function() return HttpService:JSONEncode(payload) end)
	if not okEncode then
		return false, "Falha ao gerar JSON: "..tostring(json)
	end

	local stamp = os.date("!%Y%m%d_%H%M%S")
	local fileName = ("StudioLite_Map_%s_%s.json"):format(tostring(game.PlaceId),stamp)
	local path = fileName

	if type(writefile) == "function" then
		if type(makefolder) == "function" then
			pcall(function() makefolder("StudioLiteExports") end)
			path = "StudioLiteExports/"..fileName
		end
		local okWrite, err = pcall(function() writefile(path,json) end)
		if okWrite then
			return true, path, #json
		end
		if type(setclipboard) ~= "function" then
			return false, "writefile falhou: "..tostring(err)
		end
	end

	if type(setclipboard) == "function" then
		local okClip, err = pcall(function() setclipboard(json) end)
		if okClip then
			return true, "clipboard", #json
		end
		return false, "Não foi possível copiar o JSON: "..tostring(err)
	end

	print(json)
	return true, "console", #json
end

-- UI
local parent
do
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and result then parent = result end
	end
	if not parent then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
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

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(330,290)
frame.Position = UDim2.new(0.5,-165,0.5,-145)
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
top.Text = "MAP EXPORTER MOBILE"
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
close.MouseButton1Click:Connect(function() gui:Destroy() end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-28,0,62)
info.Position = UDim2.fromOffset(14,54)
info.BackgroundColor3 = Color3.fromRGB(29,32,40)
info.TextColor3 = Color3.fromRGB(205,210,220)
info.TextSize = 13
info.Font = Enum.Font.Code
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = "Objetos: 0\nAssets: 0\nStatus: pronto"
info.Parent = frame
Instance.new("UICorner",info).CornerRadius = UDim.new(0,9)

local function button(text,y)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1,-28,0,46)
	b.Position = UDim2.fromOffset(14,y)
	b.BackgroundColor3 = Color3.fromRGB(56,105,245)
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Text = text
	b.TextSize = 15
	b.Font = Enum.Font.GothamBold
	b.Parent = frame
	Instance.new("UICorner",b).CornerRadius = UDim.new(0,9)
	return b
end

local scanBtn = button("ESCANEAR MAPA",128)
local exportBtn = button("EXPORTAR E SALVAR",182)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-28,0,44)
status.Position = UDim2.fromOffset(14,236)
status.BackgroundTransparency = 1
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(155,160,175)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.Text = "Salva JSON na pasta do executor quando writefile estiver disponível."
status.Parent = frame

local busy = false
local lastPayload

local function setStatus(s)
	status.Text = s
end

local function refreshStats(payload,label)
	if payload then
		info.Text = ("Objetos: %d\nAssets: %d\nStatus: %s"):format(
			payload.stats.objects or 0,
			payload.stats.assets or 0,
			label or "pronto"
		)
	else
		info.Text = "Objetos: 0\nAssets: 0\nStatus: "..(label or "pronto")
	end
end

local function runScan(after)
	if busy then return end
	busy = true
	scanBtn.Text = "ESCANEANDO..."
	exportBtn.Active = false
	setStatus("Lendo objetos visíveis ao cliente...")

	local ok, result = pcall(function()
		return buildPayload(function(processed,objects,assets)
			info.Text = ("Objetos: %d\nAssets: %d\nStatus: analisando %d..."):format(objects,assets,processed)
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
	busy = false

	if after then after(ok,lastPayload) end
end

scanBtn.MouseButton1Click:Connect(function()
	task.spawn(runScan)
end)

exportBtn.MouseButton1Click:Connect(function()
	if busy then return end
	task.spawn(function()
		if not lastPayload then
			runScan()
			if not lastPayload then return end
		end

		busy = true
		exportBtn.Text = "SALVANDO..."
		setStatus("Gerando arquivo JSON...")

		local ok, where, bytes = savePayload(lastPayload)
		if ok then
			if where == "clipboard" then
				setStatus(("JSON copiado para a área de transferência (%d bytes)."):format(bytes or 0))
			elseif where == "console" then
				setStatus(("JSON enviado ao console (%d bytes)."):format(bytes or 0))
			else
				setStatus(("Salvo em: %s (%d bytes)"):format(where,bytes or 0))
			end
			refreshStats(lastPayload,"exportado")
		else
			setStatus(tostring(where))
			refreshStats(lastPayload,"erro ao salvar")
		end

		exportBtn.Text = "EXPORTAR E SALVAR"
		busy = false
	end)
end)

-- arrastar no celular/PC
local UIS = game:GetService("UserInputService")
local dragging, dragStart, startPos, dragInput

top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

top.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and input == dragInput and dragStart and startPos then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset + delta.X,startPos.Y.Scale,startPos.Y.Offset + delta.Y)
	end
end)

print("[Studio Lite Map Exporter] carregado.")
