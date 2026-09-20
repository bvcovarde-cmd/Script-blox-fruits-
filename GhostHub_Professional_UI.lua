-- Ghost Hub Professional UI
-- Keyless | Mobile + PC | Roblox/Luau
-- Interface base para modulos autorizados.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
if not player then return end

local function parentGui()
    if typeof(gethui) == "function" then
        local ok, gui = pcall(gethui)
        if ok and gui then return gui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return player:WaitForChild("PlayerGui")
end

local root = parentGui()
local GUI_NAME = "GhostHub_Professional"

pcall(function()
    local old = root:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

local Theme = {
    bg = Color3.fromRGB(14,15,20),
    panel = Color3.fromRGB(20,21,28),
    panel2 = Color3.fromRGB(27,29,38),
    panel3 = Color3.fromRGB(34,36,47),
    border = Color3.fromRGB(57,60,76),
    text = Color3.fromRGB(244,246,252),
    muted = Color3.fromRGB(153,159,178),
    accent = Color3.fromRGB(126,93,255),
    success = Color3.fromRGB(83,211,135),
    warning = Color3.fromRGB(255,187,80),
    danger = Color3.fromRGB(255,91,112)
}

local State = {
    open = true,
    minimized = false,
    page = "Home",
    scale = 1
}

local function new(class, props)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    return o
end

local function corner(o,r)
    return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=o})
end

local function stroke(o,c,t)
    return new("UIStroke",{Color=c or Theme.border,Transparency=t or 0.4,Thickness=1,Parent=o})
end

local function tw(o,p,d)
    local t = TweenService:Create(o,TweenInfo.new(d or .16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),p)
    t:Play()
    return t
end

local function safe(name,fn,...)
    if typeof(fn) ~= "function" then return false end
    local a = table.pack(...)
    local ok,res = pcall(function()
        return fn(table.unpack(a,1,a.n))
    end)
    if not ok then warn("[Ghost Hub]["..tostring(name).."] "..tostring(res)) end
    return ok,res
end

local gui = new("ScreenGui",{
    Name=GUI_NAME,
    ResetOnSpawn=false,
    IgnoreGuiInset=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    Parent=root
})

local scale = new("UIScale",{Scale=1,Parent=gui})

local notes = new("Frame",{
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-12,0,12),
    Size=UDim2.fromOffset(320,430),
    BackgroundTransparency=1,
    Parent=gui
})
new("UIListLayout",{Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Right,Parent=notes})

local function notify(title,msg,kind,seconds)
    local color = Theme.accent
    if kind=="success" then color=Theme.success
    elseif kind=="warning" then color=Theme.warning
    elseif kind=="danger" then color=Theme.danger end

    local box = new("Frame",{
        Size=UDim2.fromOffset(310,64),
        BackgroundColor3=Theme.panel2,
        BorderSizePixel=0,
        Parent=notes
    })
    corner(box,10); stroke(box,color,.25)

    new("Frame",{
        Size=UDim2.new(0,4,1,0),
        BackgroundColor3=color,
        BorderSizePixel=0,
        Parent=box
    })

    new("TextLabel",{
        Position=UDim2.fromOffset(14,8),
        Size=UDim2.new(1,-28,0,19),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,
        Text=tostring(title or "Ghost Hub"),
        TextColor3=Theme.text,
        TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=box
    })

    new("TextLabel",{
        Position=UDim2.fromOffset(14,29),
        Size=UDim2.new(1,-28,0,27),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        Text=tostring(msg or ""),
        TextWrapped=true,
        TextColor3=Theme.muted,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=box
    })

    box.BackgroundTransparency=1
    box.Position=UDim2.fromOffset(16,0)
    tw(box,{BackgroundTransparency=0,Position=UDim2.fromOffset(0,0)},.18)

    task.delay(seconds or 3,function()
        if not box.Parent then return end
        tw(box,{BackgroundTransparency=1,Position=UDim2.fromOffset(16,0)},.15)
        task.wait(.17)
        if box.Parent then box:Destroy() end
    end)
end

local main = new("Frame",{
    AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.new(.5,0,.5,0),
    Size=UDim2.fromOffset(760,470),
    BackgroundColor3=Theme.bg,
    BorderSizePixel=0,
    ClipsDescendants=true,
    Parent=gui
})
corner(main,14); stroke(main,Theme.border,.12)

local top = new("Frame",{
    Size=UDim2.new(1,0,0,52),
    BackgroundColor3=Theme.panel,
    BorderSizePixel=0,
    Parent=main
})

local logo = new("Frame",{
    Position=UDim2.fromOffset(16,17),
    Size=UDim2.fromOffset(18,18),
    BackgroundColor3=Theme.accent,
    BorderSizePixel=0,
    Parent=top
})
corner(logo,6)

new("TextLabel",{
    Position=UDim2.fromOffset(44,6),
    Size=UDim2.fromOffset(200,22),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamBold,
    Text="GHOST HUB",
    TextColor3=Theme.text,
    TextSize=16,
    TextXAlignment=Enum.TextXAlignment.Left,
    Parent=top
})

new("TextLabel",{
    Position=UDim2.fromOffset(44,27),
    Size=UDim2.fromOffset(240,15),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    Text="Professional UI  •  Keyless",
    TextColor3=Theme.muted,
    TextSize=10,
    TextXAlignment=Enum.TextXAlignment.Left,
    Parent=top
})

local fpsLabel = new("TextLabel",{
    AnchorPoint=Vector2.new(1,.5),
    Position=UDim2.new(1,-92,.5,0),
    Size=UDim2.fromOffset(86,26),
    BackgroundColor3=Theme.panel3,
    Font=Enum.Font.GothamMedium,
    Text="● ONLINE",
    TextColor3=Theme.success,
    TextSize=10,
    Parent=top
})
corner(fpsLabel,20)

local minBtn = new("TextButton",{
    AnchorPoint=Vector2.new(1,.5),
    Position=UDim2.new(1,-48,.5,0),
    Size=UDim2.fromOffset(31,31),
    BackgroundColor3=Theme.panel3,
    BorderSizePixel=0,
    AutoButtonColor=false,
    Font=Enum.Font.GothamBold,
    Text="−",
    TextColor3=Theme.text,
    TextSize=18,
    Parent=top
})
corner(minBtn,8)

local closeBtn = new("TextButton",{
    AnchorPoint=Vector2.new(1,.5),
    Position=UDim2.new(1,-10,.5,0),
    Size=UDim2.fromOffset(31,31),
    BackgroundColor3=Theme.panel3,
    BorderSizePixel=0,
    AutoButtonColor=false,
    Font=Enum.Font.GothamBold,
    Text="×",
    TextColor3=Theme.text,
    TextSize=18,
    Parent=top
})
corner(closeBtn,8)

local side = new("Frame",{
    Position=UDim2.fromOffset(0,52),
    Size=UDim2.new(0,190,1,-52),
    BackgroundColor3=Theme.panel,
    BorderSizePixel=0,
    Parent=main
})

local search = new("TextBox",{
    Position=UDim2.fromOffset(11,13),
    Size=UDim2.new(1,-22,0,36),
    BackgroundColor3=Theme.panel2,
    BorderSizePixel=0,
    ClearTextOnFocus=false,
    PlaceholderText="Pesquisar função...",
    PlaceholderColor3=Theme.muted,
    Text="",
    TextColor3=Theme.text,
    Font=Enum.Font.Gotham,
    TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
    Parent=side
})
corner(search,8); stroke(search,Theme.border,.5)
new("UIPadding",{PaddingLeft=UDim.new(0,11),PaddingRight=UDim.new(0,11),Parent=search})

local tabHost = new("ScrollingFrame",{
    Position=UDim2.fromOffset(10,61),
    Size=UDim2.new(1,-20,1,-125),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=2,
    ScrollBarImageColor3=Theme.border,
    CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
    Parent=side
})
new("UIListLayout",{Padding=UDim.new(0,6),Parent=tabHost})

local userCard = new("Frame",{
    Position=UDim2.new(0,10,1,-55),
    Size=UDim2.new(1,-20,0,45),
    BackgroundColor3=Theme.panel2,
    BorderSizePixel=0,
    Parent=side
})
corner(userCard,9)

local avatar = new("TextLabel",{
    Position=UDim2.fromOffset(7,7),
    Size=UDim2.fromOffset(31,31),
    BackgroundColor3=Theme.accent,
    BorderSizePixel=0,
    Font=Enum.Font.GothamBold,
    Text=string.upper(string.sub(player.Name,1,1)),
    TextColor3=Color3.new(1,1,1),
    TextSize=13,
    Parent=userCard
})
corner(avatar,8)

new("TextLabel",{
    Position=UDim2.fromOffset(45,5),
    Size=UDim2.new(1,-51,0,18),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamMedium,
    Text=player.DisplayName,
    TextColor3=Theme.text,
    TextSize=10,
    TextTruncate=Enum.TextTruncate.AtEnd,
    TextXAlignment=Enum.TextXAlignment.Left,
    Parent=userCard
})

new("TextLabel",{
    Position=UDim2.fromOffset(45,22),
    Size=UDim2.new(1,-51,0,16),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    Text="@"..player.Name,
    TextColor3=Theme.muted,
    TextSize=9,
    TextTruncate=Enum.TextTruncate.AtEnd,
    TextXAlignment=Enum.TextXAlignment.Left,
    Parent=userCard
})

local content = new("Frame",{
    Position=UDim2.fromOffset(190,52),
    Size=UDim2.new(1,-190,1,-52),
    BackgroundTransparency=1,
    Parent=main
})

local pages, tabs, searchable = {}, {}, {}

local function page(name,title,sub)
    local frame = new("Frame",{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,Parent=content})

    new("TextLabel",{
        Position=UDim2.fromOffset(18,13),
        Size=UDim2.new(1,-36,0,25),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,
        Text=title or name,
        TextColor3=Theme.text,
        TextSize=19,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=frame
    })

    new("TextLabel",{
        Position=UDim2.fromOffset(18,39),
        Size=UDim2.new(1,-36,0,17),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        Text=sub or "",
        TextColor3=Theme.muted,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=frame
    })

    local sc = new("ScrollingFrame",{
        Position=UDim2.fromOffset(18,67),
        Size=UDim2.new(1,-36,1,-80),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        ScrollBarThickness=3,
        ScrollBarImageColor3=Theme.border,
        CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Parent=frame
    })
    new("UIListLayout",{Padding=UDim.new(0,10),Parent=sc})

    pages[name]={frame=frame,scroll=sc}
    return sc
end

local function show(name)
    State.page=name
    for n,p in pairs(pages) do p.frame.Visible=(n==name) end
    for n,b in pairs(tabs) do
        local on=n==name
        b:SetAttribute("Selected",on)
        tw(b,{
            BackgroundColor3=on and Theme.accent or Theme.panel2,
            TextColor3=on and Color3.new(1,1,1) or Theme.muted
        },.12)
    end
end

local function tab(name,label)
    local b = new("TextButton",{
        Size=UDim2.new(1,0,0,36),
        BackgroundColor3=Theme.panel2,
        BorderSizePixel=0,
        AutoButtonColor=false,
        Font=Enum.Font.GothamMedium,
        Text="   "..(label or name),
        TextColor3=Theme.muted,
        TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=tabHost
    })
    corner(b,8)
    b.MouseButton1Click:Connect(function() show(name) end)
    b.MouseEnter:Connect(function()
        if not b:GetAttribute("Selected") then tw(b,{BackgroundColor3=Theme.panel3},.1) end
    end)
    b.MouseLeave:Connect(function()
        if not b:GetAttribute("Selected") then tw(b,{BackgroundColor3=Theme.panel2},.1) end
    end)
    tabs[name]=b
end

local function section(parent,title,desc)
    local card = new("Frame",{
        Size=UDim2.new(1,-4,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=Theme.panel2,
        BorderSizePixel=0,
        Parent=parent
    })
    corner(card,10); stroke(card,Theme.border,.5)

    local inner = new("Frame",{
        Position=UDim2.fromOffset(12,10),
        Size=UDim2.new(1,-24,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,
        Parent=card
    })
    new("UIListLayout",{Padding=UDim.new(0,8),Parent=inner})

    new("TextLabel",{
        Size=UDim2.new(1,0,0,19),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,
        Text=title,
        TextColor3=Theme.text,
        TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=inner
    })

    if desc and desc~="" then
        new("TextLabel",{
            Size=UDim2.new(1,0,0,0),
            AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,
            Font=Enum.Font.Gotham,
            Text=desc,
            TextWrapped=true,
            TextColor3=Theme.muted,
            TextSize=9,
            TextXAlignment=Enum.TextXAlignment.Left,
            Parent=inner
        })
    end

    new("Frame",{Size=UDim2.new(1,0,0,2),BackgroundTransparency=1,LayoutOrder=9999,Parent=inner})
    return inner
end

local function register(obj,text)
    table.insert(searchable,{o=obj,t=string.lower(tostring(text or ""))})
end

local function button(parent,text,fn,accent)
    local b = new("TextButton",{
        Size=UDim2.new(1,0,0,37),
        BackgroundColor3=accent and Theme.accent or Theme.panel3,
        BorderSizePixel=0,
        AutoButtonColor=false,
        Font=Enum.Font.GothamMedium,
        Text="   "..text,
        TextColor3=Theme.text,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=parent
    })
    corner(b,8); register(b,text)
    b.MouseButton1Click:Connect(function()
        local ok,res=safe(text,fn)
        if not ok then notify("Erro","Falha ao executar "..text,"danger",3)
        elseif type(res)=="string" and res~="" then notify(text,res,"success",3) end
    end)
    return b
end

local function toggle(parent,text,default,fn)
    local val=default==true
    local row = new("Frame",{
        Size=UDim2.new(1,0,0,39),
        BackgroundColor3=Theme.panel3,
        BorderSizePixel=0,
        Parent=parent
    })
    corner(row,8); register(row,text)

    new("TextLabel",{
        Position=UDim2.fromOffset(12,0),
        Size=UDim2.new(1,-70,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamMedium,
        Text=text,
        TextColor3=Theme.text,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=row
    })

    local sw = new("TextButton",{
        AnchorPoint=Vector2.new(1,.5),
        Position=UDim2.new(1,-10,.5,0),
        Size=UDim2.fromOffset(42,22),
        BackgroundColor3=val and Theme.accent or Color3.fromRGB(67,70,84),
        BorderSizePixel=0,
        AutoButtonColor=false,
        Text="",
        Parent=row
    })
    corner(sw,20)

    local knob = new("Frame",{
        Position=val and UDim2.new(1,-20,.5,-8) or UDim2.new(0,4,.5,-8),
        Size=UDim2.fromOffset(16,16),
        BackgroundColor3=Color3.new(1,1,1),
        BorderSizePixel=0,
        Parent=sw
    })
    corner(knob,20)

    local function render()
        tw(sw,{BackgroundColor3=val and Theme.accent or Color3.fromRGB(67,70,84)},.13)
        tw(knob,{Position=val and UDim2.new(1,-20,.5,-8) or UDim2.new(0,4,.5,-8)},.13)
    end

    sw.MouseButton1Click:Connect(function()
        val=not val
        render()
        safe(text,fn,val)
    end)
end

local function slider(parent,text,minv,maxv,def,fn)
    local value=math.clamp(tonumber(def) or minv,minv,maxv)
    local box = new("Frame",{
        Size=UDim2.new(1,0,0,57),
        BackgroundColor3=Theme.panel3,
        BorderSizePixel=0,
        Parent=parent
    })
    corner(box,8); register(box,text)

    new("TextLabel",{
        Position=UDim2.fromOffset(12,4),
        Size=UDim2.new(1,-80,0,20),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamMedium,
        Text=text,
        TextColor3=Theme.text,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=box
    })

    local valueLabel = new("TextLabel",{
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-12,0,4),
        Size=UDim2.fromOffset(55,20),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,
        Text=tostring(value),
        TextColor3=Theme.accent,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right,
        Parent=box
    })

    local bar = new("Frame",{
        Position=UDim2.fromOffset(12,35),
        Size=UDim2.new(1,-24,0,7),
        BackgroundColor3=Color3.fromRGB(56,59,72),
        BorderSizePixel=0,
        Parent=box
    })
    corner(bar,20)

    local fill = new("Frame",{
        Size=UDim2.new((value-minv)/math.max(1,maxv-minv),0,1,0),
        BackgroundColor3=Theme.accent,
        BorderSizePixel=0,
        Parent=bar
    })
    corner(fill,20)

    local dragging=false
    local function setX(x)
        local a=math.clamp((x-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1)
        value=math.floor(minv+(maxv-minv)*a+.5)
        valueLabel.Text=tostring(value)
        fill.Size=UDim2.new(a,0,1,0)
        safe(text,fn,value)
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setX(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            setX(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
end

local function info(parent,label,getter)
    local row = new("Frame",{
        Size=UDim2.new(1,0,0,33),
        BackgroundColor3=Theme.panel3,
        BorderSizePixel=0,
        Parent=parent
    })
    corner(row,8)

    new("TextLabel",{
        Position=UDim2.fromOffset(12,0),
        Size=UDim2.new(.45,-12,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamMedium,
        Text=label,
        TextColor3=Theme.muted,
        TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
        Parent=row
    })

    local val = new("TextLabel",{
        Position=UDim2.new(.45,0,0,0),
        Size=UDim2.new(.55,-12,1,0),
        BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,
        Text="...",
        TextColor3=Theme.text,
        TextSize=9,
        TextTruncate=Enum.TextTruncate.AtEnd,
        TextXAlignment=Enum.TextXAlignment.Right,
        Parent=row
    })

    task.spawn(function()
        while row.Parent and gui.Parent do
            local ok,res=safe(label,getter)
            val.Text=ok and tostring(res) or "N/A"
            task.wait(1)
        end
    end)
end

local names = {
    {"Home","Home","Visão geral, status e utilidades."},
    {"Farm","Farm","Estrutura de automação autorizada."},
    {"Bosses","Bosses","Organização e status de bosses."},
    {"Raids","Raids","Atividades, progresso e temporizadores."},
    {"Fruits","Fruits","Filtros e utilidades visuais."},
    {"Sea","Sea Events","Acompanhamento de eventos marítimos."},
    {"Race","Race / Progress","Status e checklists de progressão."},
    {"Teleport","Navigation","Pontos autorizados do seu ambiente."},
    {"Visual","Visual","Ajustes locais de desempenho e HUD."},
    {"Server","Server","Informações do servidor."},
    {"Settings","Settings","Aparência e manutenção."}
}

for _,x in ipairs(names) do
    page(x[1],x[2],x[3])
    tab(x[1],x[2])
end

do
    local sc=pages.Home.scroll
    local s=section(sc,"Status","Informações ao vivo do cliente.")
    info(s,"Jogador",function() return player.Name end)
    info(s,"Display",function() return player.DisplayName end)
    info(s,"PlaceId",function() return game.PlaceId end)
    info(s,"JobId",function() return game.JobId~="" and game.JobId or "Studio/Local" end)
    info(s,"Jogadores",function() return #Players:GetPlayers() end)

    local q=section(sc,"Quick Actions","Ferramentas rápidas da interface.")
    button(q,"Testar notificações",function()
        notify("Ghost Hub","Sistema de notificações funcionando.","success",3)
    end,true)
    button(q,"Centralizar painel",function()
        main.Position=UDim2.new(.5,0,.5,0)
        return "Painel centralizado."
    end)
end

local function placeholders(name,title,items)
    local s=section(pages[name].scroll,title,"Área pronta para conectar apenas callbacks autorizados.")
    for _,txt in ipairs(items) do
        button(s,txt,function()
            notify("Módulo","A interface está pronta; a lógica operacional deste recurso não foi incluída.","warning",3)
        end)
    end
end

placeholders("Farm","Farm Controls",{"Selecionar alvo","Selecionar missão","Método de farm","Controle de distância","Controle de velocidade","Pausar rotina","Retomar rotina","Status da rotina"})
placeholders("Bosses","Boss Controls",{"Selecionar boss","Status do boss","Fila de bosses","Prioridade","Aviso de spawn","Histórico"})
placeholders("Raids","Raid Controls",{"Selecionar atividade","Status atual","Contador de progresso","Temporizador","Aviso de conclusão","Histórico"})
placeholders("Fruits","Fruit Tools",{"Filtro de frutas","Lista detectada","Ordenar por nome","Ordenar por distância","Favoritos","Alertas visuais"})
placeholders("Sea","Sea Event Tools",{"Painel de eventos","Status do evento","Alertas","Distância","Temporizador","Histórico"})
placeholders("Race","Progress Tools",{"Status de progressão","Checklist","Requisitos","Temporizadores","Indicadores visuais","Histórico"})
placeholders("Teleport","Navigation",{"Ponto 01","Ponto 02","Ponto 03","Ponto 04","Ponto 05","Ponto 06"})

do
    local sc=pages.Visual.scroll
    local s=section(sc,"Performance","Ajustes locais para reduzir peso visual.")

    toggle(s,"Ocultar efeitos locais",false,function(on)
        for _,o in ipairs(workspace:GetDescendants()) do
            if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") then
                o.Enabled=not on
            end
        end
        notify("Visual",on and "Efeitos ocultados." or "Efeitos restaurados.","success",2)
    end)

    toggle(s,"Low Graphics",false,function(on)
        pcall(function()
            Lighting.GlobalShadows=not on
            if on then Lighting.FogEnd=100000 end
        end)
        for _,o in ipairs(workspace:GetDescendants()) do
            if o:IsA("BasePart") and on then
                o.Material=Enum.Material.SmoothPlastic
                o.Reflectance=0
            end
        end
        notify("Visual",on and "Low Graphics ativado." or "Low Graphics desativado parcialmente.","success",2)
    end)

    local h=section(sc,"HUD","Tamanho e posição da interface.")
    slider(h,"Escala da interface",75,125,100,function(v)
        State.scale=v/100
        scale.Scale=State.scale
    end)
    button(h,"Centralizar painel",function()
        main.Position=UDim2.new(.5,0,.5,0)
        return "Painel centralizado."
    end)
end

do
    local sc=pages.Server.scroll
    local s=section(sc,"Server Info","Leituras do servidor atual.")
    info(s,"PlaceId",function() return game.PlaceId end)
    info(s,"JobId",function() return game.JobId~="" and game.JobId or "Studio/Local" end)
    info(s,"Players",function() return #Players:GetPlayers() end)
    info(s,"Ping",function()
        local ok,res=pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)
        return ok and res or "N/A"
    end)
    local a=section(sc,"Actions","Utilidades simples.")
    button(a,"Copiar JobId",function()
        if typeof(setclipboard)=="function" then
            setclipboard(game.JobId)
            return "JobId copiado."
        end
        return "setclipboard indisponível."
    end)
end

do
    local sc=pages.Settings.scroll
    local a=section(sc,"Appearance","Personalização visual.")
    slider(a,"Escala",75,125,100,function(v)
        State.scale=v/100
        scale.Scale=State.scale
    end)

    local n=section(sc,"Notifications","Testes rápidos.")
    button(n,"Notificação sucesso",function() notify("Sucesso","Tudo certo por aqui.","success",3) end)
    button(n,"Notificação aviso",function() notify("Aviso","Isto é apenas um teste.","warning",3) end)
    button(n,"Notificação erro",function() notify("Erro","Teste de erro funcionando.","danger",3) end)

    local m=section(sc,"Maintenance","Controles gerais.")
    button(m,"Fechar painel",function() gui:Destroy() end)
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    local q=string.lower(search.Text)
    for _,x in ipairs(searchable) do
        if x.o and x.o.Parent then
            x.o.Visible=(q=="" or string.find(x.t,q,1,true)~=nil)
        end
    end
end)

do
    local dragging=false
    local dragStart,startPos,active

    top.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=i.Position
            startPos=main.Position
            active=i
        end
    end)

    top.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            active=i
        end
    end)

    UIS.InputChanged:Connect(function(i)
        if dragging and i==active then
            local d=i.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
end

minBtn.MouseButton1Click:Connect(function()
    State.minimized=not State.minimized
    if State.minimized then
        side.Visible=false
        content.Visible=false
        tw(main,{Size=UDim2.fromOffset(420,52)},.18)
        minBtn.Text="+"
    else
        tw(main,{Size=UDim2.fromOffset(760,470)},.18)
        task.delay(.14,function()
            if main.Parent then side.Visible=true; content.Visible=true end
        end)
        minBtn.Text="−"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    tw(main,{Size=UDim2.fromOffset(0,0),BackgroundTransparency=1},.15)
    task.wait(.17)
    gui:Destroy()
end)

local floating = new("TextButton",{
    Position=UDim2.new(0,14,.5,-26),
    Size=UDim2.fromOffset(52,52),
    BackgroundColor3=Theme.accent,
    BorderSizePixel=0,
    AutoButtonColor=false,
    Font=Enum.Font.GothamBold,
    Text="GH",
    TextColor3=Color3.new(1,1,1),
    TextSize=14,
    Parent=gui
})
corner(floating,26); stroke(floating,Color3.new(1,1,1),.72)

floating.MouseButton1Click:Connect(function()
    State.open=not State.open
    main.Visible=State.open
end)

local frames=0
local mark=os.clock()
RunService.RenderStepped:Connect(function()
    frames+=1
    local now=os.clock()
    if now-mark>=1 then
        local fps=math.floor(frames/(now-mark))
        fpsLabel.Text=("● %d FPS"):format(fps)
        frames=0
        mark=now
    end
end)

task.spawn(function()
    while gui.Parent do
        local cam=workspace.CurrentCamera
        if cam then
            local w=cam.ViewportSize.X
            if w<700 then scale.Scale=math.min(State.scale,.78)
            elseif w<900 then scale.Scale=math.min(State.scale,.9)
            else scale.Scale=State.scale end
        end
        task.wait(1)
    end
end)

show("Home")
notify("Ghost Hub","Interface carregada sem key.","success",4)
print("[Ghost Hub] Professional UI loaded.")
