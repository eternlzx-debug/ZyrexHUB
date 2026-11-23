--[[
    RYUZENX — THROW A SEED HUB
    PHASE 1 + 2 + 3: GUI FOUNDATION + DATA READ-ONLY + SEED MANAGER ENGINE
    Developer : RyuzenX
    Target    : Roblox Luau (Studio / Delta Executor), Android + PC
    Catatan   : Phase 3 adalah Read-Only Inspector & Seed Database Engine.
                Tidak ada pemanggilan RemoteEvent / RemoteFunction otomatis ke server.

    Struktur modul:
      1. CONFIG       -> ukuran, tab navigasi, key toggle
      2. THEME        -> palet warna Dark Purple + Black & tipografi
      3. JANITOR      -> manajemen koneksi & instance (anti memory leak)
      4. UTIL         -> helper Create / Tween / Corner / Stroke / Padding
      5. UI           -> komponen reusable (Section, Label, Button, TextBox)
      6. HUB CORE     -> window, drag aman mobile, minimize/reopen, close, tab, layout responsif
      7. DATA LAYER   -> pembacaan aman attribute pemain, ModuleScript config, & Workspace
      8. SEED MANAGER -> Seed Database, Model Inspector, Rarity, Shop Docs, & Seed Stats
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Hapus instance lama agar tidak terjadi GUI atau koneksi ganda saat reload
if shared.RyuzenXHub and type(shared.RyuzenXHub.Destroy) == "function" then
    pcall(shared.RyuzenXHub.Destroy, shared.RyuzenXHub)
end

--------------------------------------------------------------------------------
-- 1. CONFIG
--------------------------------------------------------------------------------
local CONFIG = {
    GuiName = "RyuzenXThrowASeedHub",
    Brand = "RYUZENX",
    Title = "THROW A SEED HUB",
    Version = "v1.3.0 | Phase 3",
    ToggleKey = Enum.KeyCode.RightShift,

    TitleBarHeight = 40,
    Desktop = { Width = 580, Height = 380, Sidebar = 140 },
    Mobile = { Width = 470, Height = 290, Sidebar = 100 },
    CompactBelowWidth = 520,
    MinSize = Vector2.new(300, 220),
    ScreenFill = Vector2.new(0.94, 0.86),
    ScaleRange = { Min = 0.6, Max = 1.6 },
    FloatButtonSize = 46,

    Tabs = {
        { Id = "Main", Title = "Main", Phase = "PHASE 2" },
        { Id = "Training", Title = "Training", Phase = "PHASE 2" },
        { Id = "SeedManager", Title = "Seed Manager", Phase = "PHASE 3" },
        { Id = "Garden", Title = "Garden", Phase = "PHASE 2" },
        { Id = "Index", Title = "Index", Phase = "PHASE 2" },
        { Id = "Settings", Title = "Settings", Phase = "PHASE 2" },
    },
}

--------------------------------------------------------------------------------
-- 2. THEME (Dark Purple + Black)
--------------------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(10, 8, 16),
    Surface = Color3.fromRGB(19, 15, 30),
    SurfaceLight = Color3.fromRGB(32, 25, 52),
    Accent = Color3.fromRGB(140, 82, 255),
    AccentDark = Color3.fromRGB(88, 44, 185),
    AccentLight = Color3.fromRGB(184, 128, 255),
    Stroke = Color3.fromRGB(78, 48, 140),
    Text = Color3.fromRGB(242, 236, 255),
    TextDim = Color3.fromRGB(154, 142, 182),
    Danger = Color3.fromRGB(235, 70, 105),
    Green = Color3.fromRGB(110, 230, 140),
    Gold = Color3.fromRGB(255, 200, 80),

    FontRegular = Enum.Font.Gotham,
    FontMedium = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
}

--------------------------------------------------------------------------------
-- 3. JANITOR
--------------------------------------------------------------------------------
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({ _items = {} }, Janitor)
end

function Janitor:Add(item)
    table.insert(self._items, item)
    return item
end

function Janitor:Cleanup()
    for _, item in ipairs(self._items) do
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then
            item:Disconnect()
        elseif kind == "Instance" then
            pcall(function()
                item:Destroy()
            end)
        elseif kind == "function" then
            pcall(item)
        end
    end
    table.clear(self._items)
end

--------------------------------------------------------------------------------
-- 4. UTIL
--------------------------------------------------------------------------------
local Util = {}

function Util.Create(className, props, children)
    local instance = Instance.new(className)
    local parent
    for key, value in pairs(props or {}) do
        if key == "Parent" then
            parent = value
        else
            instance[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    instance.Parent = parent
    return instance
end

function Util.Tween(instance, duration, goals, style, direction)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        goals
    )
    tween:Play()
    return tween
end

function Util.Corner(parent, radius)
    return Util.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function Util.Stroke(parent, color, thickness, transparency)
    return Util.Create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Util.Padding(parent, top, right, bottom, left)
    return Util.Create("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingRight = UDim.new(0, right or top),
        PaddingBottom = UDim.new(0, bottom or top),
        PaddingLeft = UDim.new(0, left or right or top),
        Parent = parent,
    })
end

local Create, Tween = Util.Create, Util.Tween

--------------------------------------------------------------------------------
-- 5. UI COMPONENTS
--------------------------------------------------------------------------------
local UI = {}

function UI.Section(parent, title, layoutOrder)
    local card = Create("Frame", {
        Name = "Section",
        LayoutOrder = layoutOrder or 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Util.Corner(card, 10)
    Util.Stroke(card, Theme.Stroke, 1, 0.6)
    Util.Padding(card, 10, 12, 10, 12)
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })
    if title then
        Create("TextLabel", {
            Name = "Title",
            LayoutOrder = -1,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = title,
            TextSize = 14,
            TextColor3 = Theme.AccentLight,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })
    end
    return card
end

function UI.Label(parent, text, options)
    options = options or {}
    return Create("TextLabel", {
        Name = "Label",
        LayoutOrder = options.Order or 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = options.Bold and Theme.FontBold or Theme.FontRegular,
        Text = text,
        TextSize = options.Size or 13,
        TextColor3 = options.Color or Theme.Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = parent,
    })
end

function UI.Button(parent, text, onClick, janitor)
    local button = Create("TextButton", {
        Name = "Button",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.AccentDark,
        AutoButtonColor = false,
        Font = Theme.FontMedium,
        Text = text,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Parent = parent,
    })
    Util.Corner(button, 8)

    local function bind(connection)
        if janitor then
            janitor:Add(connection)
        end
    end
    bind(button.MouseEnter:Connect(function()
        Tween(button, 0.15, { BackgroundColor3 = Theme.Accent })
    end))
    bind(button.MouseLeave:Connect(function()
        Tween(button, 0.15, { BackgroundColor3 = Theme.AccentDark })
    end))
    bind(button.Activated:Connect(function()
        if onClick then
            local ok, err = pcall(onClick)
            if not ok then
                warn("[RyuzenX] Button error: " .. tostring(err))
            end
        end
    end))
    return button
end

function UI.TextBox(parent, placeholder, onChanged, janitor, layoutOrder)
    local holder = Create("Frame", {
        Name = "SearchBoxHolder",
        LayoutOrder = layoutOrder or 0,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.SurfaceLight,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Util.Corner(holder, 8)
    local stroke = Util.Stroke(holder, Theme.Stroke, 1, 0.4)

    local box = Create("TextBox", {
        Name = "Input",
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -42, 1, 0),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Font = Theme.FontRegular,
        PlaceholderText = placeholder or "Cari...",
        PlaceholderColor3 = Theme.TextDim,
        Text = "",
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    })

    local clearBtn = Create("TextButton", {
        Name = "Clear",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = Theme.Surface,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = "×",
        TextSize = 14,
        TextColor3 = Theme.TextDim,
        Visible = false,
        Parent = holder,
    })
    Util.Corner(clearBtn, 6)

    local function bind(conn)
        if janitor then
            janitor:Add(conn)
        end
    end

    bind(box.Focused:Connect(function()
        Tween(stroke, 0.15, { Color = Theme.AccentLight, Transparency = 0 })
    end))
    bind(box.FocusLost:Connect(function()
        Tween(stroke, 0.15, { Color = Theme.Stroke, Transparency = 0.4 })
    end))
    bind(box:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = #box.Text > 0
        if onChanged then
            pcall(onChanged, box.Text)
        end
    end))
    bind(clearBtn.Activated:Connect(function()
        box.Text = ""
    end))

    return box, holder
end

--------------------------------------------------------------------------------
-- 6. HUB CORE
--------------------------------------------------------------------------------
local janitor = Janitor.new()

local Hub = {
    Config = CONFIG,
    Theme = Theme,
    UI = UI,
    Util = Util,
    Janitor = janitor,
    Tabs = {},
    TabOrder = {},
}

local state = {
    destroyed = false,
    closing = false,
    minimized = false,
    activeTab = nil,
    userScale = 1,
    windowTransparency = 0,
    mobileOverride = nil,
    compact = false,
    sidebarWidth = CONFIG.Desktop.Sidebar,
    base = Vector2.new(CONFIG.Desktop.Width, CONFIG.Desktop.Height),
    animToken = 0,
}
Hub.State = state

local screenGui = Create("ScreenGui", {
    Name = CONFIG.GuiName,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})
janitor:Add(screenGui)

local function mountScreenGui(gui)
    local candidates = {}
    local okHui, hui = pcall(function()
        return gethui()
    end)
    if okHui and typeof(hui) == "Instance" then
        table.insert(candidates, hui)
    end
    table.insert(candidates, game:GetService("CoreGui"))
    table.insert(candidates, LocalPlayer:WaitForChild("PlayerGui"))

    for _, parent in ipairs(candidates) do
        local okMount = pcall(function()
            local old = parent:FindFirstChild(CONFIG.GuiName)
            if old then
                old:Destroy()
            end
            gui.Parent = parent
        end)
        if okMount and gui.Parent == parent then
            return parent
        end
    end
    return nil
end

local mountedIn = mountScreenGui(screenGui)
if not mountedIn then
    warn("[RyuzenX] Gagal memasang GUI ke parent mana pun.")
    return
end
Hub.MountedIn = mountedIn

local function getViewport()
    local size = screenGui.AbsoluteSize
    if size.X > 0 and size.Y > 0 then
        return size
    end
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function clampCenter(center, size)
    local viewport = getViewport()
    local half = size / 2
    local x = (size.X >= viewport.X) and (viewport.X / 2) or math.clamp(center.X, half.X, viewport.X - half.X)
    local y = (size.Y >= viewport.Y) and (viewport.Y / 2) or math.clamp(center.Y, half.Y, viewport.Y - half.Y)
    return Vector2.new(x, y)
end

local function makeDraggable(handle, target, options)
    options = options or {}
    local dragging = false
    local moved = false
    local activeInput = nil
    local startPointer = Vector2.zero
    local startPosition = target.Position
    local tapThreshold = options.TapThreshold or 6

    janitor:Add(handle.InputBegan:Connect(function(input)
        local inputType = input.UserInputType
        if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
            return
        end
        if options.ExcludeRightPx then
            local rightEdge = handle.AbsolutePosition.X + handle.AbsoluteSize.X
            if input.Position.X >= (rightEdge - options.ExcludeRightPx) then
                return
            end
        end
        dragging = true
        moved = false
        activeInput = input
        startPointer = Vector2.new(input.Position.X, input.Position.Y)
        startPosition = target.Position
    end))

    janitor:Add(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouchMove = input.UserInputType == Enum.UserInputType.Touch and input == activeInput
        if not (isMouseMove or isTouchMove) then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
        if not moved and delta.Magnitude < tapThreshold then
            return
        end
        moved = true
        local center = Vector2.new(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
        center = clampCenter(center, target.AbsoluteSize)
        target.Position = UDim2.fromOffset(center.X, center.Y)
    end))

    janitor:Add(UserInputService.InputEnded:Connect(function(input)
        if not dragging or not activeInput then
            return
        end
        local isEnd = input == activeInput
            or (input.UserInputType == Enum.UserInputType.MouseButton1
                and activeInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not isEnd then
            return
        end
        dragging = false
        activeInput = nil
        if not moved and options.OnTap then
            options.OnTap()
        end
    end))
end

local startViewport = getViewport()

local root = Create("Frame", {
    Name = "Root",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(startViewport.X / 2, startViewport.Y / 2),
    Size = UDim2.fromOffset(CONFIG.Desktop.Width, CONFIG.Desktop.Height),
    Visible = false,
    Parent = screenGui,
})

local window = Create("CanvasGroup", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(CONFIG.Desktop.Width, CONFIG.Desktop.Height),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Parent = root,
})
Util.Corner(window, 14)
Util.Stroke(window, Theme.Stroke, 1.5, 0.15)
local windowScale = Create("UIScale", { Scale = 1, Parent = window })

local titleBar = Create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, CONFIG.TitleBarHeight),
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Active = true,
    Parent = window,
})

local titleAccent = Create("Frame", {
    Name = "AccentLine",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = titleBar,
})
Create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.AccentDark),
        ColorSequenceKeypoint.new(0.5, Theme.AccentLight),
        ColorSequenceKeypoint.new(1, Theme.AccentDark),
    }),
    Parent = titleAccent,
})

Create("TextLabel", {
    Name = "Title",
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -100, 1, 0),
    BackgroundTransparency = 1,
    Font = Theme.FontBold,
    RichText = true,
    Text = string.format('<font color="#B880FF">%s</font>  —  %s', CONFIG.Brand, CONFIG.Title),
    TextSize = 14,
    TextColor3 = Theme.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

local function createTitleButton(name, text, offsetX, hoverColor)
    local button = Create("TextButton", {
        Name = name,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(32, 28),
        BackgroundColor3 = Theme.SurfaceLight,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = text,
        TextSize = 16,
        TextColor3 = Theme.Text,
        Parent = titleBar,
    })
    Util.Corner(button, 8)
    janitor:Add(button.MouseEnter:Connect(function()
        Tween(button, 0.15, { BackgroundColor3 = hoverColor })
    end))
    janitor:Add(button.MouseLeave:Connect(function()
        Tween(button, 0.15, { BackgroundColor3 = Theme.SurfaceLight })
    end))
    return button
end

local minimizeButton = createTitleButton("Minimize", "–", -46, Theme.Accent)
local closeButton = createTitleButton("Close", "×", -8, Theme.Danger)

local body = Create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(0, CONFIG.TitleBarHeight),
    Size = UDim2.new(1, 0, 1, -CONFIG.TitleBarHeight),
    BackgroundTransparency = 1,
    Parent = window,
})

local sidebar = Create("ScrollingFrame", {
    Name = "Sidebar",
    Size = UDim2.new(0, CONFIG.Desktop.Sidebar, 1, 0),
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Parent = body,
})
Util.Padding(sidebar, 8, 8, 8, 8)
Create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = sidebar,
})

Create("TextLabel", {
    Name = "Version",
    LayoutOrder = 999,
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Font = Theme.FontRegular,
    Text = CONFIG.Version,
    TextSize = 11,
    TextColor3 = Theme.TextDim,
    Parent = sidebar,
})

local contentFrame = Create("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(CONFIG.Desktop.Sidebar, 0),
    Size = UDim2.new(1, -CONFIG.Desktop.Sidebar, 1, 0),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = body,
})

local floatButton = Create("TextButton", {
    Name = "ReopenButton",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(44, 120),
    Size = UDim2.fromOffset(CONFIG.FloatButtonSize, CONFIG.FloatButtonSize),
    BackgroundColor3 = Theme.AccentDark,
    AutoButtonColor = false,
    Font = Theme.FontBold,
    Text = "RX",
    TextSize = 16,
    TextColor3 = Theme.Text,
    Visible = false,
    Parent = screenGui,
})
Util.Corner(floatButton, CONFIG.FloatButtonSize)
Util.Stroke(floatButton, Theme.AccentLight, 1.5, 0.2)
local floatScale = Create("UIScale", { Scale = 0, Parent = floatButton })

janitor:Add(floatButton.MouseEnter:Connect(function()
    Tween(floatButton, 0.15, { BackgroundColor3 = Theme.Accent })
end))
janitor:Add(floatButton.MouseLeave:Connect(function()
    Tween(floatButton, 0.15, { BackgroundColor3 = Theme.AccentDark })
end))

--------------------------------------------------------------------------------
-- LAYOUT & ANIMATION
--------------------------------------------------------------------------------
local function isMobileDevice()
    if state.mobileOverride ~= nil then
        return state.mobileOverride
    end
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function applyLayout()
    if state.destroyed then
        return
    end

    local viewport = getViewport()
    local profile = isMobileDevice() and CONFIG.Mobile or CONFIG.Desktop
    local available = viewport / state.userScale

    local width = math.max(math.min(profile.Width, available.X * CONFIG.ScreenFill.X), CONFIG.MinSize.X)
    local height = math.max(math.min(profile.Height, available.Y * CONFIG.ScreenFill.Y), CONFIG.MinSize.Y)
    state.base = Vector2.new(math.floor(width), math.floor(height))
    state.compact = width < CONFIG.CompactBelowWidth
    state.sidebarWidth = state.compact and CONFIG.Mobile.Sidebar or CONFIG.Desktop.Sidebar

    local scaledSize = state.base * state.userScale
    root.Size = UDim2.fromOffset(scaledSize.X, scaledSize.Y)
    window.Size = UDim2.fromOffset(state.base.X, state.base.Y)

    sidebar.Size = UDim2.new(0, state.sidebarWidth, 1, 0)
    contentFrame.Position = UDim2.fromOffset(state.sidebarWidth, 0)
    contentFrame.Size = UDim2.new(1, -state.sidebarWidth, 1, 0)

    for _, id in ipairs(Hub.TabOrder) do
        local tab = Hub.Tabs[id]
        tab.Button.Size = UDim2.new(1, 0, 0, state.compact and 34 or 38)
        tab.Button.TextSize = state.compact and 13 or 14
    end

    local rootCenter = Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
    rootCenter = clampCenter(rootCenter, scaledSize)
    root.Position = UDim2.fromOffset(rootCenter.X, rootCenter.Y)

    local floatSize = Vector2.new(CONFIG.FloatButtonSize, CONFIG.FloatButtonSize)
    local floatCenter = Vector2.new(floatButton.Position.X.Offset, floatButton.Position.Y.Offset)
    floatCenter = clampCenter(floatCenter, floatSize)
    floatButton.Position = UDim2.fromOffset(floatCenter.X, floatCenter.Y)

    if not state.minimized and not state.closing then
        windowScale.Scale = state.userScale
    end
end

janitor:Add(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout))

local HIDDEN_SCALE_FACTOR = 0.88

local function playShow()
    state.animToken += 1
    root.Visible = true
    window.GroupTransparency = 1
    windowScale.Scale = state.userScale * HIDDEN_SCALE_FACTOR
    Tween(window, 0.3, { GroupTransparency = state.windowTransparency }, Enum.EasingStyle.Quad)
    Tween(windowScale, 0.4, { Scale = state.userScale }, Enum.EasingStyle.Back)
end

local function playHide()
    state.animToken += 1
    Tween(window, 0.2, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Tween(windowScale, 0.2, { Scale = state.userScale * HIDDEN_SCALE_FACTOR }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    return 0.2
end

function Hub:Minimize()
    if state.destroyed or state.closing or state.minimized then
        return
    end
    state.minimized = true
    local duration = playHide()
    local token = state.animToken
    task.delay(duration, function()
        if state.destroyed or token ~= state.animToken or not state.minimized then
            return
        end
        root.Visible = false
        floatButton.Visible = true
        Tween(floatScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
end

function Hub:Restore()
    if state.destroyed or state.closing or not state.minimized then
        return
    end
    state.minimized = false
    state.animToken += 1
    local token = state.animToken
    Tween(floatScale, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.15, function()
        if state.destroyed or token ~= state.animToken then
            return
        end
        floatButton.Visible = false
    end)
    applyLayout()
    playShow()
end

function Hub:Toggle()
    if state.minimized then
        self:Restore()
    else
        self:Minimize()
    end
end

function Hub:Close()
    if state.destroyed or state.closing then
        return
    end
    state.closing = true
    if state.minimized then
        self:Destroy()
        return
    end
    local duration = playHide()
    task.delay(duration + 0.02, function()
        self:Destroy()
    end)
end

function Hub:Destroy()
    if state.destroyed then
        return
    end
    state.destroyed = true
    janitor:Cleanup()
    if shared.RyuzenXHub == self then
        shared.RyuzenXHub = nil
    end
end

function Hub:SetScale(value)
    state.userScale = math.clamp(tonumber(value) or 1, CONFIG.ScaleRange.Min, CONFIG.ScaleRange.Max)
    applyLayout()
end

function Hub:SetTransparency(value)
    state.windowTransparency = math.clamp(tonumber(value) or 0, 0, 0.6)
    if not state.minimized and not state.closing then
        Tween(window, 0.2, { GroupTransparency = state.windowTransparency })
    end
end

function Hub:SetMobileMode(value)
    state.mobileOverride = value
    applyLayout()
end

function Hub:Relayout()
    applyLayout()
end

--------------------------------------------------------------------------------
-- TAB SYSTEM
--------------------------------------------------------------------------------
local function styleTab(tab, active)
    Tween(tab.Button, 0.2, {
        BackgroundColor3 = active and Theme.AccentDark or Theme.SurfaceLight,
        BackgroundTransparency = active and 0 or 1,
        TextColor3 = active and Theme.Text or Theme.TextDim,
    })
    Tween(tab.Indicator, 0.2, { BackgroundTransparency = active and 0 or 1 })
end

local function buildPage(tab)
    local page = Create("CanvasGroup", {
        Name = "Page_" .. tab.Id,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = contentFrame,
    })

    local scroll = Create("ScrollingFrame", {
        Name = "Scroll",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = page,
    })
    Util.Padding(scroll, 12, 12, 12, 12)
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })

    local placeholder = Create("Frame", {
        Name = "Placeholder",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = scroll,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = placeholder,
    })
    UI.Label(placeholder, tab.Title, { Bold = true, Size = 20, Order = 0 })
    UI.Label(placeholder, "Memuat modul " .. tab.Phase .. "...", { Color = Theme.TextDim, Order = 1 })

    return page, scroll, placeholder
end

function Hub:AddTab(definition)
    if self.Tabs[definition.Id] then
        return self.Tabs[definition.Id]
    end

    local tab = {
        Id = definition.Id,
        Title = definition.Title,
        Phase = definition.Phase or "-",
    }

    tab.Button = Create("TextButton", {
        Name = "Tab_" .. tab.Id,
        LayoutOrder = #self.TabOrder + 1,
        Size = UDim2.new(1, 0, 0, state.compact and 34 or 38),
        BackgroundColor3 = Theme.SurfaceLight,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Theme.FontMedium,
        Text = tab.Title,
        TextSize = state.compact and 13 or 14,
        TextColor3 = Theme.TextDim,
        Parent = sidebar,
    })
    Util.Corner(tab.Button, 8)

    tab.Indicator = Create("Frame", {
        Name = "Indicator",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(0, 3, 0.55, 0),
        BackgroundColor3 = Theme.AccentLight,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = tab.Button,
    })
    Util.Corner(tab.Indicator, 2)

    tab.Page, tab.Content, tab.Placeholder = buildPage(tab)

    janitor:Add(tab.Button.MouseEnter:Connect(function()
        if state.activeTab ~= tab.Id then
            Tween(tab.Button, 0.15, { BackgroundTransparency = 0.5 })
        end
    end))
    janitor:Add(tab.Button.MouseLeave:Connect(function()
        if state.activeTab ~= tab.Id then
            Tween(tab.Button, 0.15, { BackgroundTransparency = 1 })
        end
    end))
    janitor:Add(tab.Button.Activated:Connect(function()
        self:SelectTab(tab.Id)
    end))

    self.Tabs[tab.Id] = tab
    table.insert(self.TabOrder, tab.Id)
    return tab
end

function Hub:SelectTab(id)
    local tab = self.Tabs[id]
    if not tab or state.activeTab == id then
        return
    end

    local previous = state.activeTab and self.Tabs[state.activeTab]
    if previous then
        previous.Page.Visible = false
        styleTab(previous, false)
    end

    state.activeTab = id
    styleTab(tab, true)

    tab.Page.Position = UDim2.fromOffset(0, 12)
    tab.Page.GroupTransparency = 1
    tab.Page.Visible = true
    Tween(tab.Page, 0.28, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
end

function Hub:ClearPlaceholder(id)
    local tab = self.Tabs[id]
    if tab and tab.Placeholder then
        tab.Placeholder:Destroy()
        tab.Placeholder = nil
    end
end

makeDraggable(titleBar, root, { ExcludeRightPx = 86 })
makeDraggable(floatButton, floatButton, {
    OnTap = function()
        Hub:Restore()
    end,
})

janitor:Add(minimizeButton.Activated:Connect(function()
    Hub:Minimize()
end))
janitor:Add(closeButton.Activated:Connect(function()
    Hub:Close()
end))

janitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or state.destroyed then
        return
    end
    if input.KeyCode == CONFIG.ToggleKey then
        Hub:Toggle()
    end
end))

for _, definition in ipairs(CONFIG.Tabs) do
    Hub:AddTab(definition)
end
applyLayout()

--------------------------------------------------------------------------------
-- SHARED HELPERS UNTUK MODUL DATA & TAB
--------------------------------------------------------------------------------
local SUFFIXES = {
    { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" },
}

local function fmt(n)
    n = tonumber(n)
    if not n then
        return "-"
    end
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    for _, s in ipairs(SUFFIXES) do
        if n >= s[1] then
            return sign .. tostring(tonumber(string.format("%.3g", n / s[1]))) .. s[2]
        end
    end
    return sign .. tostring(tonumber(string.format("%.3g", n)))
end

local function str(v)
    return v == nil and "-" or tostring(v)
end

local function attr(name)
    return LocalPlayer:GetAttribute(name)
end

local function counter()
    local n = 0
    return function()
        n += 1
        return n
    end
end

local function statRow(parent, label, nextOrder)
    local row = Create("Frame", {
        Name = "Row",
        LayoutOrder = nextOrder(),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Create("TextLabel", {
        Size = UDim2.new(0.52, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = label,
        TextSize = 13,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    local value = Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.48, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = "-",
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })
    return function(text, color)
        value.Text = text
        value.TextColor3 = color or Theme.Text
    end
end

local function progressBar(parent, order)
    local holder = Create("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 9),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Util.Corner(holder, 4)
    local fill = Create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = holder,
    })
    Util.Corner(fill, 4)
    local last = -1
    return function(ratio)
        ratio = math.clamp(tonumber(ratio) or 0, 0, 1)
        if math.abs(ratio - last) < 0.002 then
            return
        end
        last = ratio
        Tween(fill, 0.3, { Size = UDim2.fromScale(ratio, 1) })
    end
end

local function listFrame(parent, order, padding)
    local list = Create("Frame", {
        Name = "List",
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, padding or 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = list,
    })
    return list
end

local function buttonRow(parent, order, leftText, leftFn, rightText, rightFn)
    local row = Create("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })
    local left = UI.Button(row, leftText, leftFn, janitor)
    left.Size = rightText and UDim2.new(0.5, -3, 1, 0) or UDim2.new(1, 0, 1, 0)
    left.LayoutOrder = 1
    if rightText then
        local right = UI.Button(row, rightText, rightFn, janitor)
        right.Size = UDim2.new(0.5, -3, 1, 0)
        right.LayoutOrder = 2
    end
end

--------------------------------------------------------------------------------
-- 7. DATA LAYER (PHASE 2 READ-ONLY)
--------------------------------------------------------------------------------
local Data = { _modules = {}, _retryAt = {} }

local FALLBACK_TIERS = {
    "Common", "Uncommon?", "Rare?", "Epic?", "Legendary?", "Mythic?",
    "Divine", "Cosmic", "Celestial", "Secret", "Eternal", "Infinity",
}

function Data.Reset()
    Data._modules = {}
    Data._retryAt = {}
    Data._seeds = nil
    Data._tiers = nil
end

function Data.Module(name)
    local cached = Data._modules[name]
    if cached then
        return cached
    end
    if (Data._retryAt[name] or 0) > os.clock() then
        return nil
    end
    local inst = ReplicatedStorage:FindFirstChild(name)
    if inst and inst:IsA("ModuleScript") then
        local ok, result = pcall(require, inst)
        if ok and type(result) == "table" then
            Data._modules[name] = result
            return result
        end
    end
    Data._retryAt[name] = os.clock() + 5
    return nil
end

function Data.Constant(key)
    for _, moduleName in ipairs({ "Balance", "PlantConfig", "ZoneConfig" }) do
        local m = Data.Module(moduleName)
        if m and type(m[key]) == "number" then
            return m[key]
        end
    end
    return nil
end

function Data.Seeds()
    if Data._seeds then
        return Data._seeds
    end
    local balance = Data.Module("Balance")
    if not balance or type(balance.Seeds) ~= "table" then
        return nil
    end
    local list = {}
    for key, value in pairs(balance.Seeds) do
        if type(key) == "number" and type(value) == "table" then
            table.insert(list, {
                index = key,
                name = value.name or ("Seed " .. tostring(key)),
                luck = tonumber(value.luck),
                price = tonumber(value.price),
                robux = tonumber(value.robux),
                rarity = value.rarity or value.tier,
            })
        end
    end
    table.sort(list, function(a, b)
        return a.index < b.index
    end)
    if #list == 0 then
        return nil
    end
    Data._seeds = list
    return list
end

function Data.SeedByIndex(index)
    local seeds = Data.Seeds()
    if not seeds or not index then
        return nil
    end
    for _, seed in ipairs(seeds) do
        if seed.index == index then
            return seed
        end
    end
    return nil
end

function Data.Tiers()
    if Data._tiers then
        return Data._tiers
    end
    for _, moduleName in ipairs({ "PlantConfig", "Balance" }) do
        local m = Data.Module(moduleName)
        if m then
            for _, value in pairs(m) do
                if type(value) == "table" and type(value[1]) == "table" and value[1].name == "Common" then
                    Data._tiers = value
                    return value
                end
            end
        end
    end
    return nil
end

function Data.TierName(n)
    n = tonumber(n)
    if not n then
        return "?"
    end
    local tiers = Data.Tiers()
    if tiers and type(tiers[n]) == "table" and tiers[n].name then
        return tostring(tiers[n].name)
    end
    return FALLBACK_TIERS[n] or ("Tier " .. tostring(n))
end

function Data.MyPlants()
    local result, plotName, plotCount = {}, nil, 0
    local map = workspace:FindFirstChild("Map")
    local plots = map and map:FindFirstChild("Plots")
    if not plots then
        return result, nil, 0
    end
    local userId = LocalPlayer.UserId
    for _, plot in ipairs(plots:GetChildren()) do
        plotCount += 1
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                if tonumber(plant:GetAttribute("Owner")) == userId then
                    plotName = plot.Name
                    table.insert(result, {
                        id = plant:GetAttribute("PlantId") or plant.Name,
                        name = plant:GetAttribute("Plant"),
                        rarity = tonumber(plant:GetAttribute("Rarity")),
                        size = plant:GetAttribute("Size"),
                        mutation = plant:GetAttribute("Mutation"),
                        income = tonumber(plant:GetAttribute("Income")) or 0,
                    })
                end
            end
        end
    end
    table.sort(result, function(a, b)
        return a.income > b.income
    end)
    return result, plotName, plotCount
end

Hub.Data = Data

--------------------------------------------------------------------------------
-- 8. SEED MANAGER ENGINE (PHASE 3)
--------------------------------------------------------------------------------
local SeedManager = {
    -- Database awal 14 model hasil observasi Dex Explorer (tanpa properti rekayasa)
    InitialSeedNames = {
        "CandySeed",
        "CloudSeed",
        "CosmicSeed",
        "CrystalSeed",
        "DiamondSeed",
        "GoldenSeed",
        "LavaSeed",
        "LuckySeed",
        "MagicSeed",
        "PearlSeed",
        "PlainSeed",
        "RainbowSeed",
        "StarSeed",
        "SunnySeed",
    },

    -- Dokumentasi observasi SimpleSpy (hanya referensi, tidak pernah dipanggil otomatis)
    ShopDocumentation = {
        TrackEvent = 'Track("MenuBoxShop")',
        PurchaseRequest = 'Request("BuySeed", {i = 3})',
    },

    -- Observasi Dex Explorer khusus CloudSeed (referensi struktur terverifikasi)
    CloudSeedReference = {
        Parent = "SeedModels",
        PrimaryPart = "Root",
        BaseSizeAttribute = 2.599,
        BodySize = "2.599, 1.71, 1.49",
        Material = "SmoothPlastic",
        BrickColor = "Institutional white",
        Anchored = true,
        CanCollide = false,
        CanQuery = true,
        CanTouch = true,
        Hierarchy = { "Body", "Body_Glow", "Body_Glow_2", "Root" },
    },

    Entries = {},
    SelectedName = "CloudSeed",
    SearchQuery = "",
    CollectionHistory = {},
    SeedModelsFolder = nil,
}

local function formatVector3(v)
    return string.format("%.3f, %.3f, %.3f", v.X, v.Y, v.Z)
end

local function formatAttrValue(v)
    local t = typeof(v)
    if t == "number" then
        return tostring(tonumber(string.format("%.4g", v)))
    elseif t == "Vector3" then
        return formatVector3(v)
    elseif t == "Color3" then
        return string.format("RGB(%d,%d,%d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
    end
    return tostring(v)
end

-- Pencarian aman folder SeedModels di client tanpa mengasumsikan path tunggal
function SeedManager:LocateSeedModelsFolder()
    local directRS = ReplicatedStorage:FindFirstChild("SeedModels")
    if directRS then
        self.SeedModelsFolder = directRS
        return directRS
    end

    local directWS = workspace:FindFirstChild("SeedModels")
    if directWS then
        self.SeedModelsFolder = directWS
        return directWS
    end

    local deepRS = ReplicatedStorage:FindFirstChild("SeedModels", true)
    if deepRS then
        self.SeedModelsFolder = deepRS
        return deepRS
    end

    local deepWS = workspace:FindFirstChild("SeedModels", true)
    if deepWS then
        self.SeedModelsFolder = deepWS
        return deepWS
    end

    self.SeedModelsFolder = nil
    return nil
end

-- Cocokkan nama model dengan Balance.Seeds hanya jika nama identik/terverifikasi
function SeedManager:FindConfigMatch(modelName)
    local seeds = Data.Seeds()
    if not seeds then
        return nil
    end
    local target = string.lower(modelName)
    local stripped = string.gsub(target, "seed$", "")
    for _, s in ipairs(seeds) do
        local cfgName = string.lower(tostring(s.name or ""))
        local cfgStripped = string.gsub(cfgName, "%s*seed$", "")
        if cfgName == target or (stripped ~= "" and cfgStripped == stripped) then
            return s
        end
    end
    return nil
end

-- Bangun ulang database seed dari daftar terverifikasi + model aktual di client
function SeedManager:ScanDatabase()
    local folder = self:LocateSeedModelsFolder()
    local seen = {}
    local entries = {}

    local function registerSeed(name)
        if seen[name] then
            return
        end
        seen[name] = true

        local model = nil
        if folder then
            local found = folder:FindFirstChild(name)
            if found and found:IsA("Model") then
                model = found
            end
        end

        local cfg = self:FindConfigMatch(name)
        table.insert(entries, {
            Name = name,
            Available = model ~= nil,
            Instance = model,
            Config = cfg,
        })
    end

    for _, baseName in ipairs(self.InitialSeedNames) do
        registerSeed(baseName)
    end

    -- Tambahkan jika ada model tambahan di dalam SeedModels yang belum tercatat
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") and not seen[child.Name] then
                registerSeed(child.Name)
            end
        end
    end

    table.sort(entries, function(a, b)
        return a.Name < b.Name
    end)

    self.Entries = entries
    if not seen[self.SelectedName] and #entries > 0 then
        self.SelectedName = entries[1].Name
    end
    return entries
end

function SeedManager:GetSelectedEntry()
    for _, entry in ipairs(self.Entries) do
        if entry.Name == self.SelectedName then
            return entry
        end
    end
    return self.Entries[1]
end

-- Inspeksi real-time model, properti BasePart/Model, attribute, dan hierarki
function SeedManager:InspectEntry(entry)
    if not entry then
        return nil
    end

    local result = {
        Name = entry.Name,
        Available = false,
        Path = "Tidak tersedia di client",
        RarityText = "Model tidak tersedia di client",
        RarityKnown = false,
        Properties = {},
        Attributes = {},
        Hierarchy = {},
        IsCloudReference = (entry.Name == "CloudSeed"),
    }

    local model = entry.Instance
    if not model or not model.Parent then
        local folder = self.SeedModelsFolder or self:LocateSeedModelsFolder()
        local refetched = folder and folder:FindFirstChild(entry.Name)
        if refetched and refetched:IsA("Model") then
            model = refetched
            entry.Instance = model
            entry.Available = true
        else
            entry.Instance = nil
            entry.Available = false
        end
    end

    -- Cek Rarity dari sumber terverifikasi (Attribute model atau Balance.Seeds)
    local modelRarity = model and (model:GetAttribute("Rarity") or model:GetAttribute("Tier"))
    if modelRarity ~= nil then
        local tierNum = tonumber(modelRarity)
        result.RarityText = tierNum and string.format("Tier %d (%s)", tierNum, Data.TierName(tierNum)) or tostring(modelRarity)
        result.RarityKnown = true
    elseif entry.Config and entry.Config.rarity ~= nil then
        local tierNum = tonumber(entry.Config.rarity)
        result.RarityText = tierNum and string.format("Tier %d (%s)", tierNum, Data.TierName(tierNum)) or tostring(entry.Config.rarity)
        result.RarityKnown = true
    elseif model then
        result.RarityText = "Tidak diketahui (belum terverifikasi)"
    else
        result.RarityText = "Model tidak tersedia di client"
    end

    if not model then
        return result
    end

    result.Available = true
    local okPath, fullName = pcall(function()
        return model:GetFullName()
    end)
    result.Path = okPath and fullName or (model.Parent and model.Parent.Name .. "." .. model.Name or model.Name)

    -- 1. Model Properties
    table.insert(result.Properties, { Key = "Parent", Value = model.Parent and model.Parent.Name or "nil" })
    table.insert(result.Properties, { Key = "PrimaryPart", Value = model.PrimaryPart and model.PrimaryPart.Name or "None" })

    local okExt, extSize = pcall(function()
        return model:GetExtentsSize()
    end)
    if okExt and extSize then
        table.insert(result.Properties, { Key = "Model Extents", Value = formatVector3(extSize) })
    end

    local bodyPart = model:FindFirstChild("Body")
    local inspectPart = (bodyPart and bodyPart:IsA("BasePart") and bodyPart)
        or (model.PrimaryPart and model.PrimaryPart:IsA("BasePart") and model.PrimaryPart)
        or model:FindFirstChildWhichIsA("BasePart")

    if inspectPart then
        local prefix = inspectPart.Name
        table.insert(result.Properties, { Key = prefix .. ".Size", Value = formatVector3(inspectPart.Size) })
        table.insert(result.Properties, { Key = prefix .. ".Material", Value = inspectPart.Material.Name })
        table.insert(result.Properties, { Key = prefix .. ".BrickColor", Value = inspectPart.BrickColor.Name })
        table.insert(result.Properties, { Key = prefix .. ".Anchored", Value = tostring(inspectPart.Anchored) })
        table.insert(result.Properties, { Key = prefix .. ".CanCollide", Value = tostring(inspectPart.CanCollide) })
        table.insert(result.Properties, { Key = prefix .. ".CanQuery", Value = tostring(inspectPart.CanQuery) })
        table.insert(result.Properties, { Key = prefix .. ".CanTouch", Value = tostring(inspectPart.CanTouch) })
    end

    -- 2. Attributes
    local attrs = model:GetAttributes()
    local attrKeys = {}
    for k in pairs(attrs) do
        table.insert(attrKeys, k)
    end
    table.sort(attrKeys)
    for _, k in ipairs(attrKeys) do
        table.insert(result.Attributes, { Key = k, Value = formatAttrValue(attrs[k]) })
    end

    -- 3. Hierarchy
    local function traverse(node, depth)
        local children = node:GetChildren()
        table.sort(children, function(a, b)
            return a.Name < b.Name
        end)
        for _, child in ipairs(children) do
            table.insert(result.Hierarchy, {
                Depth = depth,
                Name = child.Name,
                ClassName = child.ClassName,
            })
            traverse(child, depth + 1)
        end
    end
    traverse(model, 0)

    return result
end

-- Hitung inventaris seed aktual di Backpack & Character (tanpa angka palsu)
function SeedManager:GetInventoryStats()
    local knownLookup = {}
    for _, entry in ipairs(self.Entries) do
        knownLookup[string.lower(entry.Name)] = entry.Name
    end

    local counts = {}
    local totalTools = 0
    local sourcesChecked = 0

    local function scanContainer(container)
        if not container then
            return
        end
        sourcesChecked += 1
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lower = string.lower(item.Name)
                local matchedName = knownLookup[lower]
                if not matchedName and (string.find(lower, "seed", 1, true) or item:GetAttribute("Seed") ~= nil) then
                    matchedName = item.Name
                end
                if matchedName then
                    counts[matchedName] = (counts[matchedName] or 0) + 1
                    totalTools += 1
                end
            end
        end
    end

    scanContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scanContainer(LocalPlayer.Character)

    return {
        Available = sourcesChecked > 0,
        Total = totalTools,
        ByName = counts,
    }
end

function SeedManager:RecordHistory(text)
    local stamp = os.date("%H:%M:%S")
    table.insert(self.CollectionHistory, 1, string.format("[%s] %s", stamp, text))
    if #self.CollectionHistory > 15 then
        table.remove(self.CollectionHistory)
    end
end

-- Listener pasif untuk riwayat perubahan seed selama sesi berjalan
function SeedManager:BindSessionObservers(onUpdate)
    local function notify()
        if onUpdate then
            task.defer(onUpdate)
        end
    end

    janitor:Add(LocalPlayer:GetAttributeChangedSignal("Seed"):Connect(function()
        local val = LocalPlayer:GetAttribute("Seed")
        local cfg = Data.SeedByIndex(tonumber(val))
        local label = cfg and string.format("#%s (%s)", tostring(val), cfg.name) or tostring(val)
        self:RecordHistory("Attribute Seed berubah -> " .. label)
        notify()
    end))

    local function watchContainer(container)
        if not container then
            return
        end
        janitor:Add(container.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                local lower = string.lower(child.Name)
                if string.find(lower, "seed", 1, true) or child:GetAttribute("Seed") ~= nil then
                    self:RecordHistory("Tool terdeteksi: " .. child.Name)
                    notify()
                end
            end
        end))
        janitor:Add(container.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                local lower = string.lower(child.Name)
                if string.find(lower, "seed", 1, true) or child:GetAttribute("Seed") ~= nil then
                    self:RecordHistory("Tool dilepas/hilang: " .. child.Name)
                    notify()
                end
            end
        end))
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        watchContainer(backpack)
    end
    if LocalPlayer.Character then
        watchContainer(LocalPlayer.Character)
    end
    janitor:Add(LocalPlayer.CharacterAdded:Connect(function(char)
        watchContainer(char)
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            watchContainer(bp)
        end
        notify()
    end))
end

Hub.SeedManager = SeedManager

--------------------------------------------------------------------------------
-- 9. TAB BUILDERS (PHASE 2 + PHASE 3 INTEGRATION)
--------------------------------------------------------------------------------
do
    -- MAIN (Phase 2) -----------------------------------------------------------
    local function buildMain(content)
        local o = counter()
        local card = UI.Section(content, "Statistik Utama", o())
        local ro = counter()
        local r = {
            money = statRow(card, "Uang (Money)", ro),
            income = statRow(card, "Income", ro),
            level = statRow(card, "Level", ro),
            xp = statRow(card, "XP", ro),
            strength = statRow(card, "Strength", ro),
            seed = statRow(card, "Seed Aktif", ro),
            slot = statRow(card, "Slot Taman", ro),
            rebirth = statRow(card, "Rebirths", ro),
            throws = statRow(card, "Throws", ro),
            best = statRow(card, "Jarak Terbaik", ro),
        }

        local boost = UI.Section(content, "Boost (Nilai Mentah)", o())
        local bo = counter()
        local b = {
            money = statRow(boost, "Boost_Money", bo),
            luck2 = statRow(boost, "Boost_Luck2", bo),
            luck5 = statRow(boost, "Boost_Luck5", bo),
            train = statRow(boost, "Boost_Train", bo),
        }

        return function()
            r.money("$" .. fmt(attr("Money")), Theme.Gold)
            r.income("$" .. fmt(attr("Income")) .. "/s", Theme.Green)
            r.level(str(attr("Level")))
            r.xp(fmt(attr("XP")) .. " / " .. fmt(attr("XPNeed")))
            r.strength(fmt(attr("Strength")))
            local seedIndex = tonumber(attr("Seed"))
            local seed = Data.SeedByIndex(seedIndex)
            r.seed(seed and string.format("#%s %s", tostring(seedIndex), seed.name) or str(attr("Seed")))
            r.slot(str(attr("Placed")) .. " / " .. str(attr("Capacity")))
            r.rebirth(str(attr("Rebirths")))
            r.throws(str(attr("Throws")))
            r.best(str(attr("BestDistance")))
            b.money(str(attr("Boost_Money")))
            b.luck2(str(attr("Boost_Luck2")))
            b.luck5(str(attr("Boost_Luck5")))
            b.train(str(attr("Boost_Train")))
        end
    end

    -- TRAINING (Phase 2) -------------------------------------------------------
    local function buildTraining(content)
        local o = counter()
        local card = UI.Section(content, "Training", o())
        local ro = counter()
        local r = {
            strength = statRow(card, "Strength", ro),
            nextZone = statRow(card, "Strength Zona Berikut", ro),
            zone = statRow(card, "ZoneReach", ro),
            maxStrength = statRow(card, "Strength Maks (Config)", ro),
            boost = statRow(card, "Boost_Train", ro),
        }

        local bars = UI.Section(content, "Progres", o())
        local bo = counter()
        UI.Label(bars, "Strength menuju zona berikut", { Color = Theme.TextDim, Size = 12, Order = bo() })
        local strengthBar = progressBar(bars, bo())
        local xpLabel = UI.Label(bars, "XP Level", { Color = Theme.TextDim, Size = 12, Order = bo() })
        local xpBar = progressBar(bars, bo())

        return function()
            local strength = tonumber(attr("Strength"))
            local nextZone = tonumber(attr("NextZoneStrength"))
            r.strength(fmt(strength))
            r.nextZone(fmt(nextZone))
            r.zone(str(attr("ZoneReach")))
            local zoneCfg = Data.Module("ZoneConfig")
            r.maxStrength(fmt(zoneCfg and zoneCfg.EndStrength))
            r.boost(str(attr("Boost_Train")))
            if strength and nextZone and nextZone > 0 then
                strengthBar(strength / nextZone)
            end
            local xp, need = tonumber(attr("XP")), tonumber(attr("XPNeed"))
            xpLabel.Text = string.format("XP Level %s (%s / %s)", str(attr("Level")), fmt(xp), fmt(need))
            if xp and need and need > 0 then
                xpBar(xp / need)
            end
        end
    end

    -- SEED MANAGER (Phase 3 Engine) --------------------------------------------
    local function buildSeedManager(content, refreshActive)
        local o = counter()

        -- 1. Kontrol Pencarian & Refresh
        local ctrlCard = UI.Section(content, "Seed Database & Filter", o())
        local co = counter()
        UI.TextBox(ctrlCard, "Cari nama seed (mis. CloudSeed)...", function(query)
            SeedManager.SearchQuery = query
            if refreshActive then
                refreshActive()
            end
        end, janitor, co())

        buttonRow(ctrlCard, co(), "Refresh Database & Client", function()
            Data.Reset()
            SeedManager:ScanDatabase()
            if refreshActive then
                refreshActive()
            end
        end)

        local dbSummary = UI.Label(ctrlCard, "Memindai database seed...", {
            Color = Theme.TextDim,
            Size = 12,
            Order = co(),
        })
        local seedListContainer = listFrame(ctrlCard, co(), 4)

        -- 2. Panel Informasi Seed Terpilih
        local infoCard = UI.Section(content, "Informasi Seed Terpilih", o())
        local io = counter()
        local infoRows = {
            name = statRow(infoCard, "Nama Model", io),
            status = statRow(infoCard, "Status Client", io),
            rarity = statRow(infoCard, "Rarity", io),
            path = statRow(infoCard, "Path Hierarki", io),
            cfgMatch = statRow(infoCard, "Data Balance.Seeds", io),
        }
        local cloudRefNote = UI.Label(infoCard, "", {
            Color = Theme.TextDim,
            Size = 11,
            Order = io(),
        })
        cloudRefNote.Visible = false

        -- 3. Property Viewer
        local propCard = UI.Section(content, "Property Viewer", o())
        local propStatus = UI.Label(propCard, "Pilih seed untuk melihat properti.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = 1,
        })
        local propList = listFrame(propCard, 2, 2)

        -- 4. Attribute Viewer
        local attrCard = UI.Section(content, "Attribute Viewer", o())
        local attrStatus = UI.Label(attrCard, "Pilih seed untuk melihat attribute.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = 1,
        })
        local attrList = listFrame(attrCard, 2, 2)

        -- 5. Model Hierarchy Viewer
        local hierCard = UI.Section(content, "Model Hierarchy", o())
        local hierStatus = UI.Label(hierCard, "Pilih seed untuk melihat hierarki.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = 1,
        })
        local hierList = listFrame(hierCard, 2, 2)

        -- 6. Seed Statistics (Read-Only Live Client)
        local statCard = UI.Section(content, "Seed Statistics", o())
        local so = counter()
        local statRows = {
            dbTotal = statRow(statCard, "Database Terdaftar", so),
            clientAvail = statRow(statCard, "Model Tersedia di Client", so),
            activeSeed = statRow(statCard, "Seed Aktif (Attribute)", so),
            invCount = statRow(statCard, "Jumlah Seed di Inventory", so),
        }
        local invDetailLabel = UI.Label(statCard, "", {
            Color = Theme.TextDim,
            Size = 12,
            Order = so(),
        })
        local historyHeader = UI.Label(statCard, "Riwayat Aktivitas Seed (Sesi Ini):", {
            Bold = true,
            Color = Theme.AccentLight,
            Size = 12,
            Order = so(),
        })
        local historyBody = UI.Label(statCard, "Belum ada aktivitas seed tercatat di sesi ini.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = so(),
        })

        -- 7. Seed Shop Documentation (Read-Only Reference)
        local shopCard = UI.Section(content, "Seed Shop Information (Dokumentasi)", o())
        local sho = counter()
        local shopRows = {
            track = statRow(shopCard, "Observed Track", sho),
            buy = statRow(shopCard, "Observed Request", sho),
            cfgCount = statRow(shopCard, "Entri Balance.Seeds", sho),
        }
        shopRows.track(SeedManager.ShopDocumentation.TrackEvent, Theme.AccentLight)
        shopRows.buy(SeedManager.ShopDocumentation.PurchaseRequest, Theme.Gold)
        UI.Label(shopCard, "Hanya dokumentasi hasil observasi SimpleSpy. Tidak ada pemanggilan remote otomatis.", {
            Color = Theme.TextDim,
            Size = 11,
            Order = sho(),
        })

        SeedManager:ScanDatabase()
        SeedManager:BindSessionObservers(refreshActive)

        local lastListSig = ""
        local lastDetailSig = ""

        local function clearChildren(container)
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiObject") then
                    child:Destroy()
                end
            end
        end

        return function()
            if not SeedManager.SeedModelsFolder or not SeedManager.SeedModelsFolder.Parent then
                SeedManager:ScanDatabase()
            end

            local query = string.lower(string.gsub(SeedManager.SearchQuery or "", "^%s*(.-)%s*$", "%1"))
            local filtered = {}
            local availableCount = 0

            for _, entry in ipairs(SeedManager.Entries) do
                if entry.Available then
                    availableCount += 1
                end
                if query == "" or string.find(string.lower(entry.Name), query, 1, true) then
                    table.insert(filtered, entry)
                end
            end

            dbSummary.Text = string.format(
                "Menampilkan %d dari %d seed (%d tersedia di client)",
                #filtered,
                #SeedManager.Entries,
                availableCount
            )

            local listParts = { SeedManager.SelectedName, query }
            for _, e in ipairs(filtered) do
                table.insert(listParts, e.Name .. (e.Available and ":1" or ":0"))
            end
            local listSig = table.concat(listParts, "|")

            if listSig ~= lastListSig then
                lastListSig = listSig
                clearChildren(seedListContainer)

                if #filtered == 0 then
                    UI.Label(seedListContainer, "Tidak ada seed yang cocok dengan pencarian.", {
                        Color = Theme.TextDim,
                        Size = 12,
                    })
                else
                    for idx, entry in ipairs(filtered) do
                        local isSelected = (entry.Name == SeedManager.SelectedName)
                        local rowBtn = Create("TextButton", {
                            Name = "Entry_" .. entry.Name,
                            LayoutOrder = idx,
                            Size = UDim2.new(1, 0, 0, 30),
                            BackgroundColor3 = isSelected and Theme.AccentDark or Theme.SurfaceLight,
                            BackgroundTransparency = isSelected and 0.15 or 0.55,
                            AutoButtonColor = false,
                            Text = "",
                            Parent = seedListContainer,
                        })
                        Util.Corner(rowBtn, 7)
                        if isSelected then
                            Util.Stroke(rowBtn, Theme.AccentLight, 1, 0.25)
                        end

                        Create("TextLabel", {
                            Position = UDim2.fromOffset(10, 0),
                            Size = UDim2.new(0.58, -10, 1, 0),
                            BackgroundTransparency = 1,
                            Font = isSelected and Theme.FontBold or Theme.FontMedium,
                            Text = entry.Name,
                            TextSize = 13,
                            TextColor3 = Theme.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Parent = rowBtn,
                        })

                        Create("TextLabel", {
                            AnchorPoint = Vector2.new(1, 0),
                            Position = UDim2.new(1, -10, 0, 0),
                            Size = UDim2.new(0.42, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Font = Theme.FontRegular,
                            Text = entry.Available and "Tersedia" or "Tidak tersedia",
                            TextSize = 12,
                            TextColor3 = entry.Available and Theme.Green or Theme.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Parent = rowBtn,
                        })

                        janitor:Add(rowBtn.Activated:Connect(function()
                            SeedManager.SelectedName = entry.Name
                            if refreshActive then
                                refreshActive()
                            end
                        end))
                    end
                end
            end

            -- Update panel detail untuk seed yang dipilih
            local selected = SeedManager:GetSelectedEntry()
            local inspected = SeedManager:InspectEntry(selected)

            if inspected then
                infoRows.name(inspected.Name, Theme.AccentLight)
                infoRows.status(
                    inspected.Available and "Tersedia di Client" or "Tidak Tersedia di Client",
                    inspected.Available and Theme.Green or Theme.Danger
                )
                infoRows.rarity(
                    inspected.RarityText,
                    inspected.RarityKnown and Theme.Gold or Theme.TextDim
                )
                infoRows.path(inspected.Path, Theme.TextDim)

                if selected and selected.Config then
                    local cfg = selected.Config
                    local priceStr = cfg.price and (cfg.price == 0 and "Gratis" or ("$" .. fmt(cfg.price)))
                        or (cfg.robux and (tostring(cfg.robux) .. " R$") or "-")
                    infoRows.cfgMatch(
                        string.format("#%d · Luck x%s · %s", cfg.index, tostring(cfg.luck or "?"), priceStr),
                        Theme.Green
                    )
                else
                    infoRows.cfgMatch("Tidak ada kecocokan langsung", Theme.TextDim)
                end

                if inspected.IsCloudReference and not inspected.Available then
                    local ref = SeedManager.CloudSeedReference
                    cloudRefNote.Text = string.format(
                        "Referensi Dex (CloudSeed): Parent=%s | PrimaryPart=%s | BaseSize=%s | Children=%s",
                        ref.Parent,
                        ref.PrimaryPart,
                        tostring(ref.BaseSizeAttribute),
                        table.concat(ref.Hierarchy, ", ")
                    )
                    cloudRefNote.Visible = true
                else
                    cloudRefNote.Visible = false
                end

                local detailSig = table.concat({
                    inspected.Name,
                    tostring(inspected.Available),
                    tostring(#inspected.Properties),
                    tostring(#inspected.Attributes),
                    tostring(#inspected.Hierarchy),
                }, ":")

                if detailSig ~= lastDetailSig then
                    lastDetailSig = detailSig

                    -- Render Property Viewer
                    clearChildren(propList)
                    if #inspected.Properties == 0 then
                        propStatus.Text = inspected.Available
                            and "Tidak ada properti BasePart/Model terbaca."
                            or "Model tidak tersedia di client — properti tidak dapat dibaca."
                    else
                        propStatus.Text = tostring(#inspected.Properties) .. " properti terbaca dari instance:"
                        local po = counter()
                        for _, prop in ipairs(inspected.Properties) do
                            local setter = statRow(propList, prop.Key, po)
                            setter(prop.Value, Theme.Text)
                        end
                    end

                    -- Render Attribute Viewer
                    clearChildren(attrList)
                    if #inspected.Attributes == 0 then
                        attrStatus.Text = inspected.Available
                            and "Model tidak memiliki attribute."
                            or "Model tidak tersedia di client — attribute tidak dapat dibaca."
                    else
                        attrStatus.Text = tostring(#inspected.Attributes) .. " attribute ditemukan:"
                        local ao = counter()
                        for _, item in ipairs(inspected.Attributes) do
                            local setter = statRow(attrList, item.Key, ao)
                            setter(item.Value, Theme.AccentLight)
                        end
                    end

                    -- Render Hierarchy Viewer
                    clearChildren(hierList)
                    if #inspected.Hierarchy == 0 then
                        hierStatus.Text = inspected.Available
                            and "Model tidak memiliki child instance."
                            or "Model tidak tersedia di client — hierarki tidak tersedia."
                    else
                        hierStatus.Text = tostring(#inspected.Hierarchy) .. " node hierarki ditemukan:"
                        for idx, node in ipairs(inspected.Hierarchy) do
                            local indent = string.rep("   ", node.Depth)
                            UI.Label(
                                hierList,
                                string.format("%s└ %s [%s]", indent, node.Name, node.ClassName),
                                { Color = Theme.Text, Size = 12, Order = idx }
                            )
                        end
                    end
                end
            end

            -- Update Seed Statistics (murni data aktual)
            statRows.dbTotal(tostring(#SeedManager.Entries) .. " seed")
            statRows.clientAvail(
                string.format("%d / %d", availableCount, #SeedManager.Entries),
                availableCount > 0 and Theme.Green or Theme.TextDim
            )

            local seedAttr = attr("Seed")
            local activeCfg = Data.SeedByIndex(tonumber(seedAttr))
            statRows.activeSeed(
                activeCfg and string.format("#%s %s", tostring(seedAttr), activeCfg.name) or str(seedAttr)
            )

            local inv = SeedManager:GetInventoryStats()
            if not inv.Available then
                statRows.invCount("Tidak terdeteksi", Theme.TextDim)
                invDetailLabel.Text = "Backpack / Character belum tersedia."
            else
                statRows.invCount(tostring(inv.Total) .. " item", inv.Total > 0 and Theme.Green or Theme.TextDim)
                if inv.Total > 0 then
                    local parts = {}
                    for k, v in pairs(inv.ByName) do
                        table.insert(parts, string.format("%s: %d", k, v))
                    end
                    table.sort(parts)
                    invDetailLabel.Text = "Rincian: " .. table.concat(parts, " · ")
                else
                    invDetailLabel.Text = "Tidak ada item seed di Backpack/Character saat ini."
                end
            end

            if #SeedManager.CollectionHistory > 0 then
                historyHeader.Visible = true
                historyBody.Text = table.concat(SeedManager.CollectionHistory, "\n")
            else
                historyHeader.Visible = true
                historyBody.Text = "Belum ada aktivitas seed tercatat di sesi ini."
            end

            local cfgSeeds = Data.Seeds()
            shopRows.cfgCount(
                cfgSeeds and (tostring(#cfgSeeds) .. " entri terbaca") or "Tidak terbaca di client",
                cfgSeeds and Theme.Green or Theme.TextDim
            )
        end
    end

    -- GARDEN (Phase 2) ---------------------------------------------------------
    local function addPlantRow(parent, plant, order, multiplier)
        local row = Create("Frame", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = Theme.SurfaceLight,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Parent = parent,
        })
        Util.Corner(row, 8)
        local function label(props)
            props.BackgroundTransparency = 1
            props.Parent = row
            return Create("TextLabel", props)
        end
        label({
            Position = UDim2.fromOffset(8, 3),
            Size = UDim2.new(0.58, -8, 0, 18),
            Font = Theme.FontMedium,
            Text = tostring(plant.id) .. " · " .. tostring(plant.name or "?"),
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        label({
            Position = UDim2.fromOffset(8, 22),
            Size = UDim2.new(0.58, -8, 0, 16),
            Font = Theme.FontRegular,
            Text = string.format(
                "T%s %s · Size %s · Mut %s",
                str(plant.rarity), Data.TierName(plant.rarity), str(plant.size), str(plant.mutation)
            ),
            TextSize = 11,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        label({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 3),
            Size = UDim2.new(0.42, 0, 0, 18),
            Font = Theme.FontMedium,
            Text = "$" .. fmt(plant.income) .. "/s",
            TextSize = 13,
            TextColor3 = Theme.Green,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        if multiplier then
            label({
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 22),
                Size = UDim2.new(0.42, 0, 0, 16),
                Font = Theme.FontRegular,
                Text = "jual ~$" .. fmt(plant.income * multiplier),
                TextSize = 11,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
        end
    end

    local function buildGarden(content)
        local o = counter()
        local summary = UI.Section(content, "Ringkasan", o())
        local so = counter()
        local s = {
            slot = statRow(summary, "Slot (Attribute)", so),
            found = statRow(summary, "Tanaman Terdeteksi", so),
            income = statRow(summary, "Total Income", so),
            plot = statRow(summary, "Plot Terdeteksi", so),
        }
        local card = UI.Section(content, "Tanaman Milikmu", o())
        local status = UI.Label(card, "Memuat...", { Color = Theme.TextDim, Size = 12, Order = 1 })
        local list = listFrame(card, 2, 4)

        local lastSignature

        return function()
            local plants, plotName = Data.MyPlants()
            local total = 0
            local parts = {}
            for _, p in ipairs(plants) do
                total += p.income
                table.insert(parts, tostring(p.id) .. ":" .. tostring(p.income))
            end
            s.slot(str(attr("Placed")) .. " / " .. str(attr("Capacity")))
            s.found(tostring(#plants))
            s.income("$" .. fmt(total) .. "/s", Theme.Green)
            s.plot(plotName or "-")

            local signature = table.concat(parts, "|")
            if signature == lastSignature then
                return
            end
            lastSignature = signature

            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end
            if #plants == 0 then
                status.Text = "Tidak ada tanaman terdeteksi (atau data belum dimuat)."
                return
            end
            status.Text = "Diurutkan dari Income tertinggi."
            local multiplier = Data.Constant("SellMultiplier")
            for i, plant in ipairs(plants) do
                addPlantRow(list, plant, i, multiplier)
            end
        end
    end

    -- INDEX (Phase 2) ----------------------------------------------------------
    local function buildIndex(content)
        local o = counter()
        local card = UI.Section(content, "Tier Rarity", o())
        local status = UI.Label(card, "Memuat...", { Color = Theme.TextDim, Size = 12, Order = 1 })
        local list = listFrame(card, 2, 3)

        local rows, built = {}, false

        return function()
            local tiers = Data.Tiers()
            if not tiers then
                status.Text = "Tabel tier belum ditemukan."
                return
            end
            status.Text = tostring(#tiers) .. " tier. Angka kanan = jumlah tanamanmu di tier itu."
            if not built then
                built = true
                for n = 1, #tiers do
                    local tier = tiers[n]
                    if type(tier) == "table" then
                        local row = Create("Frame", {
                            LayoutOrder = n,
                            Size = UDim2.new(1, 0, 0, 24),
                            BackgroundTransparency = 1,
                            Parent = list,
                        })
                        local swatchColor = Theme.TextDim
                        if type(tier.color) == "string" then
                            local ok, c = pcall(Color3.fromHex, "#" .. tier.color)
                            if ok then
                                swatchColor = c
                            end
                        end
                        local swatch = Create("Frame", {
                            AnchorPoint = Vector2.new(0, 0.5),
                            Position = UDim2.new(0, 4, 0.5, 0),
                            Size = UDim2.fromOffset(14, 14),
                            BackgroundColor3 = swatchColor,
                            BorderSizePixel = 0,
                            Parent = row,
                        })
                        Util.Corner(swatch, 4)
                        Create("TextLabel", {
                            Position = UDim2.fromOffset(26, 0),
                            Size = UDim2.new(0.6, -26, 1, 0),
                            BackgroundTransparency = 1,
                            Font = Theme.FontMedium,
                            Text = tostring(n) .. ". " .. tostring(tier.name or "?"),
                            TextSize = 13,
                            TextColor3 = Theme.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Parent = row,
                        })
                        rows[n] = Create("TextLabel", {
                            AnchorPoint = Vector2.new(1, 0),
                            Position = UDim2.new(1, -6, 0, 0),
                            Size = UDim2.new(0.4, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Font = Theme.FontRegular,
                            Text = "",
                            TextSize = 12,
                            TextColor3 = Theme.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Parent = row,
                        })
                    end
                end
            end

            local perTier = {}
            for _, p in ipairs((Data.MyPlants())) do
                if p.rarity then
                    perTier[p.rarity] = (perTier[p.rarity] or 0) + 1
                end
            end
            for n, label in pairs(rows) do
                label.Text = perTier[n] and (tostring(perTier[n]) .. " tanaman") or ""
            end
        end
    end

    -- SETTINGS (Phase 2 + Diagnostik SeedModels) -------------------------------
    local function buildSettings(content, refreshNow)
        local o = counter()
        local card = UI.Section(content, "Tampilan", o())
        local ro = counter()
        local scaleRow = statRow(card, "Skala UI", ro)
        buttonRow(card, ro(), "Skala -", function()
            Hub:SetScale(Hub.State.userScale - 0.1)
            refreshNow()
        end, "Skala +", function()
            Hub:SetScale(Hub.State.userScale + 0.1)
            refreshNow()
        end)

        local alphaRow = statRow(card, "Transparansi Window", ro)
        buttonRow(card, ro(), "Transparansi -", function()
            Hub:SetTransparency(Hub.State.windowTransparency - 0.1)
            refreshNow()
        end, "Transparansi +", function()
            Hub:SetTransparency(Hub.State.windowTransparency + 0.1)
            refreshNow()
        end)

        local modeRow = statRow(card, "Mode Layout", ro)
        buttonRow(card, ro(), "Ganti Mode (Auto / Mobile / Desktop)", function()
            local current = Hub.State.mobileOverride
            if current == nil then
                Hub:SetMobileMode(true)
            elseif current == true then
                Hub:SetMobileMode(false)
            else
                Hub:SetMobileMode(nil)
            end
            refreshNow()
        end)

        local diag = UI.Section(content, "Diagnostik Data", o())
        local dO = counter()
        local d = {
            balance = statRow(diag, "Modul Balance", dO),
            seeds = statRow(diag, "Balance.Seeds", dO),
            seedModels = statRow(diag, "Folder SeedModels", dO),
            tiers = statRow(diag, "Tabel Tier", dO),
            mult = statRow(diag, "SellMultiplier", dO),
            plots = statRow(diag, "Plot di Workspace", dO),
            plot = statRow(diag, "Plot Milikmu", dO),
            plants = statRow(diag, "Tanaman Milikmu", dO),
        }
        buttonRow(diag, dO(), "Muat Ulang Semua Data", function()
            Data.Reset()
            SeedManager:ScanDatabase()
            refreshNow()
        end)

        return function()
            scaleRow(string.format("%.1fx", Hub.State.userScale))
            alphaRow(string.format("%.0f%%", Hub.State.windowTransparency * 100))
            local mode = Hub.State.mobileOverride
            modeRow(mode == nil and "Auto" or (mode and "Mobile" or "Desktop"))

            local balance = Data.Module("Balance")
            d.balance(balance and "OK" or "Gagal", balance and Theme.Green or Theme.Danger)
            local seeds = Data.Seeds()
            d.seeds(seeds and tostring(#seeds) or "0", seeds and Theme.Green or Theme.Danger)
            local folder = SeedManager.SeedModelsFolder or SeedManager:LocateSeedModelsFolder()
            d.seedModels(
                folder and folder:GetFullName() or "Tidak ditemukan",
                folder and Theme.Green or Theme.TextDim
            )
            local tiers = Data.Tiers()
            d.tiers(tiers and (tostring(#tiers) .. " tier") or "tidak ada", tiers and Theme.Green or Theme.Danger)
            local mult = Data.Constant("SellMultiplier")
            d.mult(mult and tostring(mult) or "-", mult and Theme.Green or Theme.Danger)
            local plants, plotName, plotCount = Data.MyPlants()
            d.plots(tostring(plotCount))
            d.plot(plotName or "-", plotName and Theme.Green or Theme.Danger)
            d.plants(tostring(#plants))
        end
    end

    ----------------------------------------------------------------------------
    -- MOUNT & POLLING
    ----------------------------------------------------------------------------
    local refreshers = {}
    local warned = {}

    local function refreshActive()
        local id = Hub.State.activeTab
        local fn = id and refreshers[id]
        if not fn then
            return
        end
        local ok, err = pcall(fn)
        if not ok and not warned[id] then
            warned[id] = true
            warn("[RyuzenX] Refresh tab " .. tostring(id) .. " error: " .. tostring(err))
        end
    end

    local function mount(id, builder)
        local tab = Hub.Tabs[id]
        if not tab then
            return
        end
        Hub:ClearPlaceholder(id)
        local ok, fn = pcall(builder, tab.Content, refreshActive)
        if ok and type(fn) == "function" then
            refreshers[id] = fn
        else
            warn("[RyuzenX] Gagal membangun tab " .. id .. ": " .. tostring(fn))
        end
    end

    mount("Main", buildMain)
    mount("Training", buildTraining)
    mount("SeedManager", buildSeedManager)
    mount("Garden", buildGarden)
    mount("Index", buildIndex)
    mount("Settings", buildSettings)

    local baseSelectTab = Hub.SelectTab
    function Hub:SelectTab(id)
        baseSelectTab(self, id)
        task.defer(refreshActive)
    end

    task.spawn(function()
        while not Hub.State.destroyed do
            if not Hub.State.minimized and not Hub.State.closing then
                refreshActive()
            end
            task.wait(1)
        end
    end)

    Hub.Phase = 3
    Hub:SelectTab("Main")
    playShow()
    refreshActive()
end

shared.RyuzenXHub = Hub
return Hub
