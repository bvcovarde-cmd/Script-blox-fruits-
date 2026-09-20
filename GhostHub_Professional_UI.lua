--[[
    GHOST FRUITS HUB - REBUILD
    Keyless | Mobile + PC | Roblox/Luau
    UI reconstruida do zero em estilo de hub moderno.

    Importante:
    - Sem sistema de key.
    - Sem bypass/anti-cheat/dupe.
    - Abas de automacao possuem hooks visuais para uso autorizado.
]]

local VERSION = "1.0.0-REBUILD"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end

    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)

    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = getGuiParent()
local GUI_NAME = "GhostFruitsHub_Rebuild"

pcall(function()
    local old = GuiParent:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

local Theme = {
    Background = Color3.fromRGB(10, 12, 17),
    Sidebar = Color3.fromRGB(14, 17, 23),
    Panel = Color3.fromRGB(19, 23, 31),
    Panel2 = Color3.fromRGB(25, 30, 40),
    Panel3 = Color3.fromRGB(31, 37, 49),
    Stroke = Color3.fromRGB(53, 62, 80),
    Text = Color3.fromRGB(245, 247, 252),
    Muted = Color3.fromRGB(145, 155, 177),
    Accent = Color3.fromRGB(83, 145, 255),
    Accent2 = Color3.fromRGB(111, 92, 255),
    Success = Color3.fromRGB(83, 211, 139),
    Warning = Color3.fromRGB(255, 188, 87),
    Danger = Color3.fromRGB(255, 93, 112)
}

local State = {
    Open = true,
    Minimized = false,
    Page = "Home",
    Scale = 1,
    ReduceMotion = false,
    Compact = false
}

local function new(className, props)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    return object
end

local function corner(object, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = object
    })
end

local function stroke(object, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0.35,
        Thickness = thickness or 1,
        Parent = object
    })
end

local function tween(object, duration, props)
    if State.ReduceMotion then
        for key, value in pairs(props) do
            pcall(function() object[key] = value end)
        end
        return
    end

    local anim = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    )
    anim:Play()
    return anim
end

local function safe(name, callback, ...)
    if typeof(callback) ~= "function" then
        return false, "callback ausente"
    end

    local args = table.pack(...)
    local ok, result = pcall(function()
        return callback(table.unpack(args, 1, args.n))
    end)

    if not ok then
        warn(("[Ghost Fruits][%s] %s"):format(tostring(name), tostring(result)))
    end

    return ok, result
end

local Gui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = GuiParent
})

local Scale = new("UIScale", {
    Scale = 1,
    Parent = Gui
})

local Notifications = new("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(330, 500),
    BackgroundTransparency = 1,
    Parent = Gui
})

new("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Parent = Notifications
})

local function notify(title, message, kind, duration)
    kind = kind or "info"
    duration = duration or 3

    local color = Theme.Accent
    if kind == "success" then color = Theme.Success end
    if kind == "warning" then color = Theme.Warning end
    if kind == "danger" then color = Theme.Danger end

    local active = {}
    for _, child in ipairs(Notifications:GetChildren()) do
        if child:IsA("Frame") then table.insert(active, child) end
    end

    while #active >= 5 do
        local oldest = table.remove(active, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end

    local card = new("Frame", {
        Size = UDim2.fromOffset(320, 70),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = Notifications
    })
    corner(card, 10)
    stroke(card, color, 0.25, 1)

    new("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = card
    })

    new("TextLabel", {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -40, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(title or "Ghost Fruits"),
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    new("TextLabel", {
        Position = UDim2.fromOffset(14, 30),
        Size = UDim2.new(1, -40, 0, 30),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = tostring(message or ""),
        TextWrapped = true,
        TextColor3 = Theme.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    local close = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 7),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 15,
        Parent = card
    })

    local removed = false

    local function remove()
        if removed then return end
        removed = true
        tween(card, 0.14, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 0)
        })
        task.delay(0.16, function()
            if card.Parent then card:Destroy() end
        end)
    end

    close.MouseButton1Click:Connect(remove)
    task.delay(duration, remove)
end

local Main = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(820, 500),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = Gui
})
corner(Main, 14)
stroke(Main, Theme.Stroke, 0.15, 1)

local Topbar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Parent = Main
})

local Logo = new("Frame", {
    Position = UDim2.fromOffset(15, 16),
    Size = UDim2.fromOffset(22, 22),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Parent = Topbar
})
corner(Logo, 7)

new("TextLabel", {
    Position = UDim2.fromOffset(46, 7),
    Size = UDim2.fromOffset(250, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "GHOST FRUITS",
    TextColor3 = Theme.Text,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Topbar
})

new("TextLabel", {
    Position = UDim2.fromOffset(46, 28),
    Size = UDim2.fromOffset(310, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Premium Hub • Keyless • " .. VERSION,
    TextColor3 = Theme.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Topbar
})

local FpsPill = new("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -134, 0.5, 0),
    Size = UDim2.fromOffset(96, 26),
    BackgroundColor3 = Theme.Panel2,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamMedium,
    Text = "● 0 FPS",
    TextColor3 = Theme.Success,
    TextSize = 10,
    Parent = Topbar
})
corner(FpsPill, 20)

local MinButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -66, 0.5, 0),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = Theme.Panel2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "−",
    TextColor3 = Theme.Text,
    TextSize = 18,
    Parent = Topbar
})
corner(MinButton, 8)

local CloseButton = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -26, 0.5, 0),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = Theme.Panel2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = Theme.Text,
    TextSize = 18,
    Parent = Topbar
})
corner(CloseButton, 8)

local Sidebar = new("Frame", {
    Position = UDim2.fromOffset(0, 54),
    Size = UDim2.new(0, 205, 1, -54),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Parent = Main
})

local Search = new("TextBox", {
    Position = UDim2.fromOffset(12, 12),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderText = "Search...",
    PlaceholderColor3 = Theme.Muted,
    Text = "",
    TextColor3 = Theme.Text,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Sidebar
})
corner(Search, 8)
stroke(Search, Theme.Stroke, 0.45, 1)

new("UIPadding", {
    PaddingLeft = UDim.new(0, 11),
    PaddingRight = UDim.new(0, 11),
    Parent = Search
})

local TabHost = new("ScrollingFrame", {
    Position = UDim2.fromOffset(10, 60),
    Size = UDim2.new(1, -20, 1, -125),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.Stroke,
    Parent = Sidebar
})

new("UIListLayout", {
    Padding = UDim.new(0, 6),
    Parent = TabHost
})

local UserCard = new("Frame", {
    Position = UDim2.new(0, 10, 1, -56),
    Size = UDim2.new(1, -20, 0, 46),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Parent = Sidebar
})
corner(UserCard, 9)

local AvatarLetter = new("TextLabel", {
    Position = UDim2.fromOffset(7, 7),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = string.upper(string.sub(LocalPlayer.Name, 1, 1)),
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Parent = UserCard
})
corner(AvatarLetter, 8)

new("TextLabel", {
    Position = UDim2.fromOffset(47, 5),
    Size = UDim2.new(1, -53, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = LocalPlayer.DisplayName,
    TextColor3 = Theme.Text,
    TextSize = 10,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = UserCard
})

new("TextLabel", {
    Position = UDim2.fromOffset(47, 23),
    Size = UDim2.new(1, -53, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "@" .. LocalPlayer.Name,
    TextColor3 = Theme.Muted,
    TextSize = 9,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = UserCard
})

local Content = new("Frame", {
    Position = UDim2.fromOffset(205, 54),
    Size = UDim2.new(1, -205, 1, -54),
    BackgroundTransparency = 1,
    Parent = Main
})

local Pages = {}
local Tabs = {}
local Searchables = {}

local function registerSearch(object, text)
    table.insert(Searchables, {
        Object = object,
        Text = string.lower(tostring(text or ""))
    })
end

local function makePage(name, titleText, subtitleText)
    local page = new("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = Content
    })

    new("TextLabel", {
        Position = UDim2.fromOffset(18, 14),
        Size = UDim2.new(1, -36, 0, 25),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = titleText,
        TextColor3 = Theme.Text,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = page
    })

    new("TextLabel", {
        Position = UDim2.fromOffset(18, 40),
        Size = UDim2.new(1, -36, 0, 17),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = subtitleText or "",
        TextColor3 = Theme.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = page
    })

    local scroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(18, 68),
        Size = UDim2.new(1, -36, 1, -82),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Stroke,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = page
    })

    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        Parent = scroll
    })

    Pages[name] = {
        Frame = page,
        Scroll = scroll
    }
end

local function makeTab(name, label)
    local button = new("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = "   " .. label,
        TextColor3 = Theme.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TabHost
    })
    corner(button, 8)

    Tabs[name] = button
end

local function showPage(name)
    if not Pages[name] then return end
    State.Page = name

    for pageName, page in pairs(Pages) do
        page.Frame.Visible = pageName == name
    end

    for tabName, button in pairs(Tabs) do
        local active = tabName == name
        tween(button, 0.12, {
            BackgroundColor3 = active and Theme.Accent or Theme.Panel,
            TextColor3 = active and Theme.Text or Theme.Muted
        })
    end
end

local function section(parent, titleText, description)
    local card = new("Frame", {
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(card, 10)
    stroke(card, Theme.Stroke, 0.5, 1)

    local inner = new("Frame", {
        Position = UDim2.fromOffset(12, 10),
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card
    })

    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        Parent = inner
    })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 19),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = titleText,
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inner
    })

    if description and description ~= "" then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = description,
            TextWrapped = true,
            TextColor3 = Theme.Muted,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = inner
        })
    end

    new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundTransparency = 1,
        LayoutOrder = 99999,
        Parent = inner
    })

    return inner
end

local function button(parent, text, callback, accent)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = accent and Theme.Accent or Theme.Panel2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = "   " .. text,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent
    })
    corner(b, 8)
    registerSearch(b, text)

    local locked = false

    b.MouseButton1Click:Connect(function()
        if locked then return end
        locked = true

        local ok, result = safe(text, callback)
        if not ok then
            notify("Error", text .. " falhou.", "danger", 3)
        elseif type(result) == "string" and result ~= "" then
            notify(text, result, "success", 3)
        end

        task.delay(0.2, function()
            locked = false
        end)
    end)

    b.MouseEnter:Connect(function()
        tween(b, 0.1, {BackgroundTransparency = 0.08})
    end)

    b.MouseLeave:Connect(function()
        tween(b, 0.1, {BackgroundTransparency = 0})
    end)

    return b
end

local function toggle(parent, text, defaultValue, callback)
    local value = defaultValue == true

    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(row, 8)
    registerSearch(row, text)

    new("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -76, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    local switch = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = value and Theme.Accent or Color3.fromRGB(67, 70, 84),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Parent = row
    })
    corner(switch, 20)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = switch
    })
    corner(knob, 20)

    local function render()
        tween(switch, 0.13, {
            BackgroundColor3 = value and Theme.Accent or Color3.fromRGB(67, 70, 84)
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

        local ok = safe(text, callback, value)
        if not ok then
            value = previous
            render()
        end
    end)

    return row
end

local function slider(parent, text, minValue, maxValue, defaultValue, callback)
    local value = math.clamp(tonumber(defaultValue) or minValue, minValue, maxValue)

    local box = new("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(box, 8)
    registerSearch(box, text)

    new("TextLabel", {
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -90, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = box
    })

    local valueLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 4),
        Size = UDim2.fromOffset(60, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(value),
        TextColor3 = Theme.Accent,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = box
    })

    local bar = new("Frame", {
        Position = UDim2.fromOffset(12, 37),
        Size = UDim2.new(1, -24, 0, 8),
        BackgroundColor3 = Theme.Panel3,
        BorderSizePixel = 0,
        Parent = box
    })
    corner(bar, 20)

    local fill = new("Frame", {
        Size = UDim2.new((value - minValue) / math.max(1, maxValue - minValue), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = bar
    })
    corner(fill, 20)

    local dragging = false

    local function applyFromX(x)
        local alpha = math.clamp(
            (x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X),
            0,
            1
        )

        value = math.floor(minValue + ((maxValue - minValue) * alpha) + 0.5)
        valueLabel.Text = tostring(value)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        safe(text, callback, value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            applyFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            applyFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return box
end

local function dropdown(parent, text, values, defaultIndex, callback)
    values = values or {"Default"}
    defaultIndex = math.clamp(tonumber(defaultIndex) or 1, 1, #values)

    local index = defaultIndex
    local open = false

    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = parent
    })
    corner(holder, 8)
    registerSearch(holder, text)

    local mainButton = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })

    local list = new("Frame", {
        Position = UDim2.fromOffset(8, 40),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder
    })

    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = list
    })

    local function refresh()
        mainButton.Text = ("   %s   •   %s"):format(text, tostring(values[index]))
    end

    local function setOpen(newValue)
        open = newValue == true
        local target = 40
        if open then
            target = 48 + (#values * 32)
        end
        tween(holder, 0.15, {Size = UDim2.new(1, 0, 0, target)})
    end

    for i, option in ipairs(values) do
        local optionButton = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            Text = "   " .. tostring(option),
            TextColor3 = Theme.Muted,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = list
        })
        corner(optionButton, 6)

        local optionIndex = i
        optionButton.MouseButton1Click:Connect(function()
            index = optionIndex
            refresh()
            setOpen(false)
            safe(text, callback, values[index], index)
        end)
    end

    mainButton.MouseButton1Click:Connect(function()
        setOpen(not open)
    end)

    refresh()
    return holder
end

local function info(parent, text, getter)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        Parent = parent
    })
    corner(row, 8)

    new("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.48, -12, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = Theme.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    local valueLabel = new("TextLabel", {
        Position = UDim2.new(0.48, 0, 0, 0),
        Size = UDim2.new(0.52, -12, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "...",
        TextColor3 = Theme.Text,
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row
    })

    task.spawn(function()
        while row.Parent and Gui.Parent do
            local ok, result = safe("Info:" .. text, getter)
            valueLabel.Text = ok and tostring(result) or "N/A"
            task.wait(1)
        end
    end)
end

local pageDefs = {
    {"Home", "Home", "Status geral e informações do jogador."},
    {"Main", "Main", "Controles principais e presets do hub."},
    {"Farm", "Auto Farm", "Seleção e controles de automação autorizada."},
    {"Boss", "Boss", "Controles e lista de bosses."},
    {"Items", "Items", "Ferramentas de itens e inventário."},
    {"Fruits", "Fruits", "Filtros, lista e alertas."},
    {"Raid", "Raid", "Status e controles de raid."},
    {"Sea", "Sea Events", "Painel de eventos marítimos."},
    {"Race", "Race V4", "Status e checklist de progressão."},
    {"Teleport", "Teleport", "Pontos e navegação autorizada."},
    {"Visual", "Visual", "HUD, FPS e otimizações locais."},
    {"Server", "Server", "Informações e utilidades do servidor."},
    {"Settings", "Settings", "Preferências da interface."}
}

for _, def in ipairs(pageDefs) do
    makePage(def[1], def[2], def[3])
    makeTab(def[1], def[2])
end

for name, tabButton in pairs(Tabs) do
    local pageName = name

    tabButton.MouseButton1Click:Connect(function()
        showPage(pageName)
    end)

    tabButton.MouseEnter:Connect(function()
        if State.Page ~= pageName then
            tween(tabButton, 0.1, {BackgroundColor3 = Theme.Panel2})
        end
    end)

    tabButton.MouseLeave:Connect(function()
        if State.Page ~= pageName then
            tween(tabButton, 0.1, {BackgroundColor3 = Theme.Panel})
        end
    end)
end

local function unavailableModule(name)
    notify(
        "Módulo visual",
        name .. " está preparado na interface; conecte apenas lógica autorizada.",
        "warning",
        4
    )
end

do
    local s = section(Pages.Home.Scroll, "Account", "Informações do cliente atual.")
    info(s, "Player", function() return LocalPlayer.Name end)
    info(s, "Display", function() return LocalPlayer.DisplayName end)
    info(s, "PlaceId", function() return game.PlaceId end)
    info(s, "JobId", function() return game.JobId ~= "" and game.JobId or "Studio/Local" end)
    info(s, "Players", function() return #Players:GetPlayers() end)

    local character = section(Pages.Home.Scroll, "Character", "Status ao vivo.")
    info(character, "Health", function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return "N/A" end
        return ("%d/%d"):format(math.floor(hum.Health), math.floor(hum.MaxHealth))
    end)

    info(character, "WalkSpeed", function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return hum and hum.WalkSpeed or "N/A"
    end)

    local quick = section(Pages.Home.Scroll, "Quick", "Ações rápidas do painel.")
    button(quick, "Test Notification", function()
        notify("Ghost Fruits", "Painel funcionando.", "success", 3)
        return "OK"
    end, true)

    button(quick, "Center UI", function()
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        return "Interface centralizada."
    end)
end

do
    local s = section(Pages.Main.Scroll, "General", "Configuração principal do painel.")
    dropdown(s, "Mode", {"Default", "Mobile", "Performance"}, 1, function(value)
        if value == "Mobile" then
            State.Scale = 0.85
            Scale.Scale = State.Scale
        elseif value == "Performance" then
            State.Scale = 0.9
            Scale.Scale = State.Scale
        else
            State.Scale = 1
            Scale.Scale = State.Scale
        end
        notify("Mode", value .. " aplicado.", "success", 2)
    end)

    toggle(s, "Auto Execute Selected Module", false, function()
        unavailableModule("Auto Execute Selected Module")
    end)

    toggle(s, "Auto Reconnect UI State", false, function(enabled)
        notify("Main", enabled and "Estado visual marcado." or "Estado visual desmarcado.", "info", 2)
    end)
end

do
    local s = section(Pages.Farm.Scroll, "Auto Farm", "Controles visuais equivalentes aos hubs desse estilo.")
    dropdown(s, "Farm Mode", {"Level", "Mastery", "Material", "Quest"}, 1, function()
        unavailableModule("Farm Mode")
    end)
    toggle(s, "Auto Farm", false, function() unavailableModule("Auto Farm") end)
    toggle(s, "Auto Quest", false, function() unavailableModule("Auto Quest") end)
    toggle(s, "Auto Next Quest", false, function() unavailableModule("Auto Next Quest") end)
    toggle(s, "Auto Mastery", false, function() unavailableModule("Auto Mastery") end)
    slider(s, "Farm Distance", 1, 50, 15, function() end)
    slider(s, "Farm Delay", 1, 100, 20, function() end)
end

do
    local s = section(Pages.Boss.Scroll, "Boss", "Seleção e estado de boss.")
    dropdown(s, "Select Boss", {"Auto", "Nearest", "Selected"}, 1, function()
        unavailableModule("Select Boss")
    end)
    toggle(s, "Auto Boss", false, function() unavailableModule("Auto Boss") end)
    toggle(s, "Auto Quest Boss", false, function() unavailableModule("Auto Quest Boss") end)
    toggle(s, "Boss Spawn Alert", false, function(enabled)
        notify("Boss", enabled and "Alerta visual ativado." or "Alerta visual desativado.", "info", 2)
    end)
end

do
    local s = section(Pages.Items.Scroll, "Items", "Organização de inventário e filtros.")
    dropdown(s, "Item Filter", {"All", "Weapons", "Accessories", "Materials"}, 1, function() end)
    button(s, "Refresh Inventory View", function()
        return "Visualização atualizada."
    end)
    toggle(s, "Favorite Filter", false, function() end)
    toggle(s, "Rare Item Alert", false, function(enabled)
        notify("Items", enabled and "Alertas visuais ativados." or "Alertas visuais desativados.", "info", 2)
    end)
end

do
    local s = section(Pages.Fruits.Scroll, "Fruits", "Lista, filtro e alertas visuais.")
    dropdown(s, "Fruit Filter", {"All", "Common", "Rare", "Legendary", "Mythical"}, 1, function() end)
    toggle(s, "Fruit ESP UI", false, function(enabled)
        notify("Fruits", enabled and "Indicadores de UI ativados." or "Indicadores de UI desativados.", "info", 2)
    end)
    toggle(s, "Fruit Spawn Alert", false, function(enabled)
        notify("Fruits", enabled and "Alerta visual ativado." or "Alerta visual desativado.", "info", 2)
    end)
    button(s, "Refresh Fruit List", function()
        return "Lista visual atualizada."
    end)
end

do
    local s = section(Pages.Raid.Scroll, "Raid", "Controles de interface para raids.")
    dropdown(s, "Raid Type", {"Auto", "Flame", "Ice", "Light", "Dark"}, 1, function()
        unavailableModule("Raid Type")
    end)
    toggle(s, "Auto Raid", false, function() unavailableModule("Auto Raid") end)
    toggle(s, "Raid Timer", false, function(enabled)
        notify("Raid", enabled and "Timer visual ativado." or "Timer visual desativado.", "info", 2)
    end)
    toggle(s, "Completion Alert", false, function(enabled)
        notify("Raid", enabled and "Alerta ativado." or "Alerta desativado.", "info", 2)
    end)
end

do
    local s = section(Pages.Sea.Scroll, "Sea Events", "Monitor visual de eventos.")
    dropdown(s, "Event Filter", {"All", "Sea Beast", "Terrorshark", "Ship Raid"}, 1, function() end)
    toggle(s, "Event Alert", false, function(enabled)
        notify("Sea Events", enabled and "Alertas ativados." or "Alertas desativados.", "info", 2)
    end)
    toggle(s, "Distance Display", false, function() end)
    toggle(s, "Event Timer", false, function() end)
end

do
    local s = section(Pages.Race.Scroll, "Race V4", "Checklist e indicadores.")
    dropdown(s, "Race", {"Current", "Human", "Mink", "Fish", "Ghoul", "Cyborg"}, 1, function() end)
    toggle(s, "Progress Checklist", false, function(enabled)
        notify("Race", enabled and "Checklist ativado." or "Checklist desativado.", "info", 2)
    end)
    toggle(s, "Trial Timer", false, function() end)
    button(s, "Refresh Progress", function()
        return "Status visual atualizado."
    end)
end

do
    local s = section(Pages.Teleport.Scroll, "Teleport", "Pontos visuais para navegação autorizada.")
    for _, name in ipairs({"First Sea", "Second Sea", "Third Sea", "Spawn", "Cafe", "Mansion"}) do
        local pointName = name
        button(s, pointName, function()
            unavailableModule("Teleport: " .. pointName)
        end)
    end
end

local GraphicsBackup = {
    Lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd
    },
    Effects = setmetatable({}, {__mode = "k"})
}

local function setEffectsHidden(hidden)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
            if GraphicsBackup.Effects[obj] == nil then
                GraphicsBackup.Effects[obj] = obj.Enabled
            end
            obj.Enabled = hidden and false or GraphicsBackup.Effects[obj]
        end
    end
end

do
    local s = section(Pages.Visual.Scroll, "Performance", "Recursos locais do cliente.")
    toggle(s, "Hide Effects", false, function(enabled)
        setEffectsHidden(enabled)
        return true
    end)

    toggle(s, "Low Graphics", false, function(enabled)
        if enabled then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
        else
            Lighting.GlobalShadows = GraphicsBackup.Lighting.GlobalShadows
            Lighting.FogEnd = GraphicsBackup.Lighting.FogEnd
        end
        return true
    end)

    slider(s, "UI Scale", 75, 125, 100, function(value)
        State.Scale = value / 100
        Scale.Scale = State.Scale
    end)

    toggle(s, "Reduce Motion", false, function(enabled)
        State.ReduceMotion = enabled
    end)
end

do
    local s = section(Pages.Server.Scroll, "Server Info", "Dados do servidor atual.")
    info(s, "PlaceId", function() return game.PlaceId end)
    info(s, "JobId", function() return game.JobId ~= "" and game.JobId or "Studio/Local" end)
    info(s, "Players", function() return #Players:GetPlayers() end)
    info(s, "Ping", function()
        local ok, result = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)
        return ok and result or "N/A"
    end)

    button(s, "Copy JobId", function()
        if typeof(setclipboard) == "function" then
            setclipboard(game.JobId)
            return "JobId copiado."
        end
        return "Clipboard não disponível."
    end)

    button(s, "Rejoin Current Place", function()
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        if not ok then error(err) end
    end)
end

do
    local s = section(Pages.Settings.Scroll, "Interface", "Ajustes da própria UI.")
    slider(s, "Scale", 75, 125, 100, function(value)
        State.Scale = value / 100
        Scale.Scale = State.Scale
    end)

    toggle(s, "Reduce Animations", false, function(enabled)
        State.ReduceMotion = enabled
    end)

    button(s, "Center Window", function()
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        return "Janela centralizada."
    end)

    button(s, "Test Success Notification", function()
        notify("Success", "Tudo funcionando.", "success", 3)
    end)

    button(s, "Test Warning Notification", function()
        notify("Warning", "Teste concluído.", "warning", 3)
    end)
end

Search:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(Search.Text)

    for _, item in ipairs(Searchables) do
        if item.Object and item.Object.Parent then
            item.Object.Visible = query == ""
                or string.find(item.Text, query, 1, true) ~= nil
        end
    end
end)

do
    local dragging = false
    local dragStart
    local startPosition
    local activeInput

    Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Main.Position
            activeInput = input
        end
    end)

    Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == activeInput then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

MinButton.MouseButton1Click:Connect(function()
    State.Minimized = not State.Minimized

    if State.Minimized then
        Sidebar.Visible = false
        Content.Visible = false
        tween(Main, 0.18, {Size = UDim2.fromOffset(430, 54)})
        MinButton.Text = "+"
    else
        tween(Main, 0.18, {Size = UDim2.fromOffset(820, 500)})
        task.delay(State.ReduceMotion and 0 or 0.14, function()
            if Main.Parent then
                Sidebar.Visible = true
                Content.Visible = true
            end
        end)
        MinButton.Text = "−"
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    tween(Main, 0.15, {
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1
    })
    task.wait(State.ReduceMotion and 0 or 0.17)
    if Gui.Parent then Gui:Destroy() end
end)

local Floating = new("TextButton", {
    Position = UDim2.new(0, 14, 0.5, -26),
    Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "GF",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Parent = Gui
})
corner(Floating, 26)
stroke(Floating, Color3.new(1, 1, 1), 0.72, 1)

Floating.MouseButton1Click:Connect(function()
    State.Open = not State.Open
    Main.Visible = State.Open
end)

local fpsFrames = 0
local fpsMark = os.clock()

RunService.RenderStepped:Connect(function()
    fpsFrames = fpsFrames + 1
    local now = os.clock()

    if now - fpsMark >= 1 then
        local fps = math.floor(fpsFrames / math.max(0.001, now - fpsMark))
        FpsPill.Text = ("● %d FPS"):format(fps)
        fpsFrames = 0
        fpsMark = now
    end
end)

task.spawn(function()
    while Gui.Parent do
        local camera = workspace.CurrentCamera
        if camera then
            local width = camera.ViewportSize.X

            if width < 650 then
                Scale.Scale = math.min(State.Scale, 0.72)
            elseif width < 850 then
                Scale.Scale = math.min(State.Scale, 0.86)
            else
                Scale.Scale = State.Scale
            end
        end

        task.wait(1)
    end
end)

showPage("Home")
notify("Ghost Fruits", "Rebuild carregado sem key.", "success", 4)

print("[Ghost Fruits] Rebuild loaded.")
