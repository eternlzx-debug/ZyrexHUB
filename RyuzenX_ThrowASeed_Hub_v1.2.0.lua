--[[
    RYUZENX — THROW A SEED HUB
    PHASE 1 + 2: GUI FOUNDATION + ESSENTIAL STATS (READ-ONLY)
    Developer : RyuzenX
    Target    : Roblox Luau (Studio / Executor), Android + PC
    Catatan   : Hanya membaca data lokal & config (tanpa pemanggilan Remote).
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
    Version = "v1.2.0 | Phase 2",
    ToggleKey = Enum.KeyCode.RightShift,

    TitleBarHeight = 40,
    Desktop = { Width = 560, Height = 360, Sidebar = 135 },
    Mobile = { Width = 460, Height = 285, Sidebar = 100 },
    CompactBelowWidth = 510,
    MinSize = Vector2.new(300, 220),
    ScreenFill = Vector2.new(0.94, 0.86),
    ScaleRange = { Min = 0.6, Max = 1.6 },
    FloatButtonSize = 46,

    Tabs = {
        { Id = "Main", Title = "Main" },
        { Id = "Seeds", Title = "Seeds" },
        { Id = "Garden", Title = "Garden" },
        { Id = "Settings", Title = "Settings" },
    },
}

--------------------------------------------------------------------------------
-- 2. THEME
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

    local function bind(conn)
        if janitor then
            janitor:Add(conn)
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
    warn("[RyuzenX] Gagal memasang GUI.")
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

function Hub:AddTab(definition)
    if self.Tabs[definition.Id] then
        return self.Tabs[definition.Id]
    end

    local tab = {
        Id = definition.Id,
        Title = definition.Title,
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

    tab.Page = page
    tab.Content = scroll

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
-- 7. DATA LAYER & ESSENTIAL STATS TABS (READ-ONLY)
--------------------------------------------------------------------------------
do
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
        local result, plotName = {}, nil
        local map = workspace:FindFirstChild("Map")
        local plots = map and map:FindFirstChild("Plots")
        if not plots then
            return result, nil
        end
        local userId = LocalPlayer.UserId
        for _, plot in ipairs(plots:GetChildren()) do
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
        return result, plotName
    end

    local function attr(name)
        return LocalPlayer:GetAttribute(name)
    end

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
            Size = UDim2.new(1, 0, 0, 8),
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

    -- TAB 1: MAIN (Statistik Inti + Progres) -----------------------------------
    local function buildMain(content)
        local o = counter()
        local core = UI.Section(content, "Statistik Utama", o())
        local ro = counter()
        local r = {
            money = statRow(core, "Money", ro),
            income = statRow(core, "Income", ro),
            level = statRow(core, "Level", ro),
            strength = statRow(core, "Strength", ro),
            zone = statRow(core, "Zone", ro),
            seed = statRow(core, "Seed Aktif", ro),
            slot = statRow(core, "Slot Taman", ro),
            rebirth = statRow(core, "Rebirths", ro),
        }

        local prog = UI.Section(content, "Progres", o())
        local po = counter()
        local xpLabel = UI.Label(prog, "XP: -", { Color = Theme.TextDim, Size = 12, Order = po() })
        local xpBar = progressBar(prog, po())
        local strLabel = UI.Label(prog, "Next Zone: -", { Color = Theme.TextDim, Size = 12, Order = po() })
        local strBar = progressBar(prog, po())

        return function()
            r.money("$" .. fmt(attr("Money")), Theme.Gold)
            r.income("$" .. fmt(attr("Income")) .. "/s", Theme.Green)
            r.level(str(attr("Level")))

            local strength = tonumber(attr("Strength"))
            local nextZone = tonumber(attr("NextZoneStrength"))
            r.strength(fmt(strength))
            r.zone(str(attr("ZoneReach")))

            local seedIndex = tonumber(attr("Seed"))
            local seed = Data.SeedByIndex(seedIndex)
            r.seed(seed and string.format("#%s %s", tostring(seedIndex), seed.name) or str(attr("Seed")))
            r.slot(str(attr("Placed")) .. " / " .. str(attr("Capacity")))
            r.rebirth(str(attr("Rebirths")))

            local xp, need = tonumber(attr("XP")), tonumber(attr("XPNeed"))
            xpLabel.Text = string.format("XP: %s / %s", fmt(xp), fmt(need))
            if xp and need and need > 0 then
                xpBar(xp / need)
            end

            strLabel.Text = string.format("Strength Zona Berikut: %s / %s", fmt(strength), fmt(nextZone))
            if strength and nextZone and nextZone > 0 then
                strBar(strength / nextZone)
            end
        end
    end

    -- TAB 2: SEEDS (Daftar & Harga Seed) ---------------------------------------
    local function buildSeeds(content)
        local o = counter()
        local card = UI.Section(content, "Daftar Seed", o())
        local status = UI.Label(card, "Memuat data...", { Color = Theme.TextDim, Size = 12, Order = 1 })
        local list = listFrame(card, 2, 3)

        local rows, built = {}, false

        return function()
            local seeds = Data.Seeds()
            if not seeds then
                status.Text = "Balance.Seeds belum terbaca."
                return
            end
            status.Text = tostring(#seeds) .. " seed · Hijau = uang cukup · Ungu = aktif"

            if not built then
                built = true
                for i, seed in ipairs(seeds) do
                    local bg = Create("Frame", {
                        Name = "Seed" .. tostring(seed.index),
                        LayoutOrder = i,
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = Theme.AccentDark,
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Parent = list,
                    })
                    Util.Corner(bg, 6)
                    Create("TextLabel", {
                        Position = UDim2.fromOffset(8, 0),
                        Size = UDim2.new(0.5, -8, 1, 0),
                        BackgroundTransparency = 1,
                        Font = Theme.FontMedium,
                        Text = tostring(seed.index) .. ". " .. seed.name,
                        TextSize = 13,
                        TextColor3 = Theme.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = bg,
                    })
                    local info = Create("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0),
                        Position = UDim2.new(1, -8, 0, 0),
                        Size = UDim2.new(0.5, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Font = Theme.FontRegular,
                        Text = "",
                        TextSize = 13,
                        TextColor3 = Theme.TextDim,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = bg,
                    })
                    rows[i] = { seed = seed, bg = bg, info = info }
                end
            end

            local money = tonumber(attr("Money")) or 0
            local active = tonumber(attr("Seed"))
            for _, row in ipairs(rows) do
                local s = row.seed
                local priceText, color = "-", Theme.TextDim
                if s.price then
                    priceText = s.price == 0 and "Gratis" or ("$" .. fmt(s.price))
                    color = money >= s.price and Theme.Green or Theme.TextDim
                elseif s.robux then
                    priceText = tostring(s.robux) .. " R$"
                    color = Theme.Gold
                end
                row.info.Text = string.format("x%s · %s", tostring(s.luck or "?"), priceText)
                row.info.TextColor3 = color
                row.bg.BackgroundTransparency = (active == s.index) and 0.55 or 1
            end
        end
    end

    -- TAB 3: GARDEN (Ringkasan Kebun & Tanaman) --------------------------------
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
            Text = tostring(plant.name or "?"),
            TextSize = 13,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        label({
            Position = UDim2.fromOffset(8, 22),
            Size = UDim2.new(0.58, -8, 0, 16),
            Font = Theme.FontRegular,
            Text = string.format("%s · Size %s · Mut %s", Data.TierName(plant.rarity), str(plant.size), str(plant.mutation)),
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
                Text = "Jual ~$" .. fmt(plant.income * multiplier),
                TextSize = 11,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
        end
    end

    local function buildGarden(content)
        local o = counter()
        local summary = UI.Section(content, "Ringkasan Kebun", o())
        local so = counter()
        local s = {
            slot = statRow(summary, "Slot Terpakai", so),
            income = statRow(summary, "Total Income", so),
            plot = statRow(summary, "Plot Aktif", so),
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

            s.slot(string.format("%s / %s (%d terdeteksi)", str(attr("Placed")), str(attr("Capacity")), #plants))
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
                status.Text = "Tidak ada tanaman terdeteksi."
                return
            end
            status.Text = "Diurutkan dari Income tertinggi:"
            local multiplier = Data.Constant("SellMultiplier")
            for i, plant in ipairs(plants) do
                addPlantRow(list, plant, i, multiplier)
            end
        end
    end

    -- TAB 4: SETTINGS ----------------------------------------------------------
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

        local alphaRow = statRow(card, "Transparansi", ro)
        buttonRow(card, ro(), "Opak (-)", function()
            Hub:SetTransparency(Hub.State.windowTransparency - 0.1)
            refreshNow()
        end, "Transparan (+)", function()
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

        local diag = UI.Section(content, "Status Data", o())
        local dO = counter()
        local dConfig = statRow(diag, "Config (Balance)", dO)
        local dPlot = statRow(diag, "Plot & Tanaman", dO)
        buttonRow(diag, dO(), "Muat Ulang Data", function()
            Data.Reset()
            refreshNow()
        end)

        return function()
            scaleRow(string.format("%.1fx", Hub.State.userScale))
            alphaRow(string.format("%.0f%%", Hub.State.windowTransparency * 100))
            local mode = Hub.State.mobileOverride
            modeRow(mode == nil and "Auto" or (mode and "Mobile" or "Desktop"))

            local seeds = Data.Seeds()
            dConfig(seeds and ("OK (" .. #seeds .. " seed)") or "Gagal", seeds and Theme.Green or Theme.Danger)

            local plants, plotName = Data.MyPlants()
            dPlot(plotName and string.format("%s (%d tanaman)", plotName, #plants) or "Tidak ditemukan", plotName and Theme.Green or Theme.Danger)
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
        local ok, fn = pcall(builder, tab.Content, refreshActive)
        if ok and type(fn) == "function" then
            refreshers[id] = fn
        else
            warn("[RyuzenX] Gagal membangun tab " .. id .. ": " .. tostring(fn))
        end
    end

    mount("Main", buildMain)
    mount("Seeds", buildSeeds)
    mount("Garden", buildGarden)
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

    Hub.Data = Data
    Hub.Phase = 2
    Hub:SelectTab("Main")
    playShow()
    refreshActive()
end

shared.RyuzenXHub = Hub
return Hub
