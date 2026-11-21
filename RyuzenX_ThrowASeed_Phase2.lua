--[[
    RYUZENX — THROW A SEED HUB
    PHASE 1 + 2: GUI FOUNDATION + DATA READ-ONLY
    Developer : RyuzenX
    Target    : Roblox Luau (LocalScript di Studio / executor), Android + PC
    Catatan   : Phase 2 hanya MEMBACA data. Tidak ada pemanggilan Remote ke server.

    Struktur modul (semua dalam satu file):
      1. CONFIG   -> ukuran, tab, key toggle
      2. Theme    -> warna & font
      3. Janitor  -> pengelola koneksi/instance (anti memory leak)
      4. Util     -> helper Create / Tween / Corner / Stroke
      5. UI       -> komponen reusable (Section, Label, Button)
      6. Hub      -> window, drag, minimize/reopen, close, tab, layout responsif
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Hapus instance lama (hindari GUI dobel & koneksi dobel saat script dijalankan ulang)
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
    Version = "v1.1.0 | Phase 2",
    ToggleKey = Enum.KeyCode.RightShift, -- PC: sembunyikan/tampilkan

    TitleBarHeight = 40,
    Desktop = { Width = 580, Height = 380, Sidebar = 140 },
    Mobile = { Width = 470, Height = 290, Sidebar = 100 },
    CompactBelowWidth = 520, -- di bawah lebar ini UI memakai mode compact
    MinSize = Vector2.new(300, 220),
    ScreenFill = Vector2.new(0.94, 0.86), -- batas maksimum relatif layar
    ScaleRange = { Min = 0.6, Max = 1.6 },
    FloatButtonSize = 46,

    Tabs = {
        { Id = "Main", Title = "Main", Phase = "PHASE 2" },
        { Id = "Training", Title = "Training", Phase = "PHASE 4" },
        { Id = "SeedManager", Title = "Seed Manager", Phase = "PHASE 3" },
        { Id = "Garden", Title = "Garden", Phase = "PHASE 5" },
        { Id = "Index", Title = "Index", Phase = "PHASE 6" },
        { Id = "Settings", Title = "Settings", Phase = "PHASE 7" },
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
-- 5. UI COMPONENTS (dipakai ulang di Phase 2+)
--------------------------------------------------------------------------------
local UI = {}

-- Kartu section dengan judul. Return: frame kartu (parent untuk isi).
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

-- Label teks otomatis tinggi. options: Color, Size, Bold, Order
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

-- Tombol aksi. janitor dipakai untuk menyimpan koneksi event.
function UI.Button(parent, text, onClick, janitor)
    local button = Create("TextButton", {
        Name = "Button",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.AccentDark,
        AutoButtonColor = false,
        Font = Theme.FontMedium,
        Text = text,
        TextSize = 14,
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

--------------------------------------------------------------------------------
-- 6. HUB
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
    mobileOverride = nil, -- nil = auto, true/false = paksa (untuk Settings di Phase 7)
    compact = false,
    sidebarWidth = CONFIG.Desktop.Sidebar,
    base = Vector2.new(CONFIG.Desktop.Width, CONFIG.Desktop.Height),
    animToken = 0,
}
Hub.State = state

-- ScreenGui ------------------------------------------------------------------
local screenGui = Create("ScreenGui", {
    Name = CONFIG.GuiName,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
})
janitor:Add(screenGui)

-- gethui() bersifat executor-specific; fallback ke CoreGui lalu PlayerGui (Studio).
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

-- Jaga agar elemen (anchor di tengah) tetap berada di dalam layar.
local function clampCenter(center, size)
    local viewport = getViewport()
    local half = size / 2
    local x = (size.X >= viewport.X) and (viewport.X / 2) or math.clamp(center.X, half.X, viewport.X - half.X)
    local y = (size.Y >= viewport.Y) and (viewport.Y / 2) or math.clamp(center.Y, half.Y, viewport.Y - half.Y)
    return Vector2.new(x, y)
end

-- Drag universal (mouse + touch). options: OnTap (dipanggil jika hanya tap, tanpa geser)
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

-- Window ---------------------------------------------------------------------
local startViewport = getViewport()

-- Root: hitbox + posisi (hanya offset, anchor tengah). Window di dalamnya di-scale lewat UIScale.
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

-- Title bar
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

-- Body: sidebar + content
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

-- Tombol floating untuk reopen setelah minimize ---------------------------------
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
-- Layout responsif
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

    -- Jaga posisi tetap di layar
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

--------------------------------------------------------------------------------
-- Animasi tampil / sembunyi
--------------------------------------------------------------------------------
local HIDDEN_SCALE_FACTOR = 0.88

local function playShow()
    state.animToken += 1
    root.Visible = true
    window.GroupTransparency = 1
    windowScale.Scale = state.userScale * HIDDEN_SCALE_FACTOR
    Tween(window, 0.3, { GroupTransparency = state.windowTransparency }, Enum.EasingStyle.Quad)
    Tween(windowScale, 0.4, { Scale = state.userScale }, Enum.EasingStyle.Back)
end

-- Return durasi animasi supaya pemanggil bisa menjadwalkan langkah berikutnya
local function playHide()
    state.animToken += 1
    Tween(window, 0.2, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Tween(windowScale, 0.2, { Scale = state.userScale * HIDDEN_SCALE_FACTOR }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    return 0.2
end

--------------------------------------------------------------------------------
-- Public API: window control
--------------------------------------------------------------------------------
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

-- Hook untuk Phase 7 (Settings)
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

function Hub:SetMobileMode(value) -- nil = auto, true/false = paksa
    state.mobileOverride = value
    applyLayout()
end

function Hub:Relayout()
    applyLayout()
end

--------------------------------------------------------------------------------
-- Tab system
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

    -- Placeholder: hapus lewat Hub:ClearPlaceholder(id) saat fase fitur diisi
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
    UI.Label(placeholder, "Fondasi GUI siap. Fitur tab ini diisi pada " .. tab.Phase .. ".", {
        Color = Theme.TextDim,
        Order = 1,
    })
    local section = UI.Section(placeholder, "Status", 2)
    UI.Label(section, "Belum ada fitur gameplay di Phase 1.", { Color = Theme.TextDim })

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

--------------------------------------------------------------------------------
-- Wiring & startup
--------------------------------------------------------------------------------
makeDraggable(titleBar, root)
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

applyLayout()

for _, definition in ipairs(CONFIG.Tabs) do
    Hub:AddTab(definition)
end
applyLayout() -- terapkan ukuran tombol tab setelah semua tab dibuat

Hub:SelectTab(CONFIG.Tabs[1].Id)
playShow()

shared.RyuzenXHub = Hub

--------------------------------------------------------------------------------
-- PHASE 2: DATA LAYER + TAB READ-ONLY
-- Aturan fase ini:
--   * Hanya MEMBACA data (attribute pemain, ModuleScript config, Workspace).
--   * TIDAK ada pemanggilan RemoteEvent / RemoteFunction.
--   * Data yang belum terverifikasi diberi tanda "?" atau label "dugaan".
--------------------------------------------------------------------------------
do
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local GREEN = Color3.fromRGB(110, 230, 140)
    local GOLD = Color3.fromRGB(255, 200, 80)
    local RED = Theme.Danger

    ----------------------------------------------------------------------------
    -- 1. DATA LAYER
    ----------------------------------------------------------------------------
    local Data = { _modules = {}, _retryAt = {} }

    -- Nama tier 1, 7-12 terverifikasi dari config; 2-6 hanya dugaan (tanda "?").
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

    -- require ModuleScript di ReplicatedStorage (read-only). Gagal -> retry tiap 5 dtk.
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

    -- Cari konstanta angka (mis. SellMultiplier) di modul config yang dikenal.
    function Data.Constant(key)
        for _, moduleName in ipairs({ "Balance", "PlantConfig", "ZoneConfig" }) do
            local m = Data.Module(moduleName)
            if m and type(m[key]) == "number" then
                return m[key], moduleName
            end
        end
        return nil
    end

    -- Balance.Seeds -> list terurut: { index, name, luck, price, robux }
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

    -- Cari tabel tier (entri [1].name == "Common") di PlantConfig / Balance.
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

    -- Tanaman milikmu: cari di SEMUA plot yang Owner-nya == UserId (plot bisa berubah tiap sesi).
    -- Return: list, namaPlot, jumlahPlot
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

    local function attr(name)
        return LocalPlayer:GetAttribute(name)
    end

    local SUFFIXES = {
        { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" },
    }

    local function trim(v)
        return tostring(tonumber(string.format("%.3g", v)))
    end

    local function fmt(n)
        n = tonumber(n)
        if not n then
            return "-"
        end
        local sign = n < 0 and "-" or ""
        n = math.abs(n)
        for _, s in ipairs(SUFFIXES) do
            if n >= s[1] then
                return sign .. trim(n / s[1]) .. s[2]
            end
        end
        return sign .. trim(n)
    end

    local function str(v)
        if v == nil then
            return "-"
        end
        return tostring(v)
    end

    ----------------------------------------------------------------------------
    -- 2. KOMPONEN UI TAMBAHAN (memakai Util/UI/Theme dari Phase 1)
    ----------------------------------------------------------------------------
    local function counter()
        local n = 0
        return function()
            n += 1
            return n
        end
    end

    -- Baris "label ........ nilai". Return fungsi setter(text, color).
    local function statRow(parent, label, nextOrder)
        local row = Create("Frame", {
            Name = "Row",
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        Create("TextLabel", {
            Size = UDim2.new(0.55, 0, 1, 0),
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
            Size = UDim2.new(0.45, 0, 1, 0),
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

    -- Progress bar tipis. Return setter(ratio 0..1).
    local function progressBar(parent, order)
        local holder = Create("Frame", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = Theme.Background,
            BorderSizePixel = 0,
            Parent = parent,
        })
        Util.Corner(holder, 5)
        local fill = Create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Util.Corner(fill, 5)
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

    -- Container list dinamis di dalam kartu section.
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

    local function note(parent, text, order)
        return UI.Label(parent, text, { Color = Theme.TextDim, Size = 12, Order = order })
    end

    ----------------------------------------------------------------------------
    -- 3. TAB BUILDERS (masing-masing return fungsi refresh)
    ----------------------------------------------------------------------------

    -- MAIN ---------------------------------------------------------------------
    local function buildMain(content)
        local o = counter()
        local card = UI.Section(content, "Statistik", o())
        local ro = counter()
        local r = {
            money = statRow(card, "Uang (Money)", ro),
            income = statRow(card, "Income", ro),
            level = statRow(card, "Level", ro),
            xp = statRow(card, "XP", ro),
            strength = statRow(card, "Strength", ro),
            seed = statRow(card, "Seed (attribute)", ro),
            slot = statRow(card, "Slot taman", ro),
            rebirth = statRow(card, "Rebirths", ro),
            throws = statRow(card, "Throws", ro),
            best = statRow(card, "Jarak terbaik", ro),
        }
        local boost = UI.Section(content, "Boost (nilai mentah)", o())
        local bo = counter()
        local b = {
            money = statRow(boost, "Boost_Money", bo),
            luck2 = statRow(boost, "Boost_Luck2", bo),
            luck5 = statRow(boost, "Boost_Luck5", bo),
            train = statRow(boost, "Boost_Train", bo),
        }
        note(content, "Semua angka dibaca dari attribute pemain (read-only). Arti nilai Boost belum diketahui.", o())

        return function()
            r.money(fmt(attr("Money")))
            r.income(fmt(attr("Income")) .. "/s")
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

    -- TRAINING -----------------------------------------------------------------
    local function buildTraining(content)
        local o = counter()
        local card = UI.Section(content, "Training", o())
        local ro = counter()
        local r = {
            strength = statRow(card, "Strength", ro),
            nextZone = statRow(card, "Strength zona berikut", ro),
            zone = statRow(card, "ZoneReach", ro),
            maxStrength = statRow(card, "Strength maks (config)", ro),
            boost = statRow(card, "Boost_Train", ro),
        }
        local bars = UI.Section(content, "Progres", o())
        local bo = counter()
        UI.Label(bars, "Strength menuju zona berikut", { Color = Theme.TextDim, Size = 12, Order = bo() })
        local strengthBar = progressBar(bars, bo())
        local xpLabel = UI.Label(bars, "XP level", { Color = Theme.TextDim, Size = 12, Order = bo() })
        local xpBar = progressBar(bars, bo())
        note(content, "Tombol Pull-up/XPBoost belum dibuat: nama aksi lain dan efek server belum terverifikasi.", o())

        return function()
            local strength = tonumber(attr("Strength"))
            local nextZone = tonumber(attr("NextZoneStrength"))
            r.strength(fmt(strength))
            r.nextZone(fmt(nextZone))
            r.zone(str(attr("ZoneReach")))
            local maxStrength = Data.Module("ZoneConfig")
            maxStrength = maxStrength and maxStrength.EndStrength
            r.maxStrength(fmt(maxStrength))
            r.boost(str(attr("Boost_Train")))
            if strength and nextZone and nextZone > 0 then
                strengthBar(strength / nextZone)
            end
            local xp, need = tonumber(attr("XP")), tonumber(attr("XPNeed"))
            xpLabel.Text = string.format("XP level %s  (%s / %s)", str(attr("Level")), fmt(xp), fmt(need))
            if xp and need and need > 0 then
                xpBar(xp / need)
            end
        end
    end

    -- SEED MANAGER -------------------------------------------------------------
    local function buildSeeds(content)
        local o = counter()
        local card = UI.Section(content, "Daftar seed (Balance.Seeds)", o())
        local status = note(card, "Memuat data...", 1)
        local list = listFrame(card, 2, 3)
        note(content, "Hijau = uangmu cukup. Garis ungu = nilai attribute Seed. Beli seed belum diimplementasikan.", o())

        local rows, built = {}, false

        return function()
            local seeds = Data.Seeds()
            if not seeds then
                status.Text = "Balance.Seeds belum terbaca."
                return
            end
            status.Text = tostring(#seeds) .. " seed ditemukan."
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
                    priceText = s.price == 0 and "gratis" or fmt(s.price)
                    color = money >= s.price and GREEN or Theme.TextDim
                elseif s.robux then
                    priceText = tostring(s.robux) .. " Robux"
                    color = GOLD
                end
                row.info.Text = string.format("x%s · %s", tostring(s.luck or "?"), priceText)
                row.info.TextColor3 = color
                row.bg.BackgroundTransparency = (active == s.index) and 0.55 or 1
            end
        end
    end

    -- GARDEN -------------------------------------------------------------------
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
            TextColor3 = GREEN,
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
            slot = statRow(summary, "Slot (attribute)", so),
            found = statRow(summary, "Tanaman terdeteksi", so),
            income = statRow(summary, "Total Income (dihitung)", so),
            plot = statRow(summary, "Plot terdeteksi", so),
        }
        local card = UI.Section(content, "Tanaman milikmu", o())
        local status = note(card, "Memuat...", 1)
        local list = listFrame(card, 2, 4)
        note(content, "Daftar dicari lewat Owner = UserId (bukan nama plot). Estimasi jual memakai SellMultiplier dari config.", o())

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
            s.income("$" .. fmt(total) .. "/s")
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

    -- INDEX --------------------------------------------------------------------
    local function buildIndex(content)
        local o = counter()
        local card = UI.Section(content, "Tier rarity", o())
        local status = note(card, "Memuat...", 1)
        local list = listFrame(card, 2, 3)
        local info = UI.Section(content, "Belum tersedia", o())
        UI.Label(info, "Daftar 110 tanaman dan status 'dibuka' belum dibaca: struktur PlantConfig belum dipetakan.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = 1,
        })

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

    -- SETTINGS -----------------------------------------------------------------
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
        left.Size = UDim2.new(0.5, -3, 1, 0)
        left.LayoutOrder = 1
        if rightText then
            local right = UI.Button(row, rightText, rightFn, janitor)
            right.Size = UDim2.new(0.5, -3, 1, 0)
            right.LayoutOrder = 2
        else
            left.Size = UDim2.new(1, 0, 1, 0)
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
        local alphaRow = statRow(card, "Transparansi window", ro)
        buttonRow(card, ro(), "Transparansi -", function()
            Hub:SetTransparency(Hub.State.windowTransparency - 0.1)
            refreshNow()
        end, "Transparansi +", function()
            Hub:SetTransparency(Hub.State.windowTransparency + 0.1)
            refreshNow()
        end)
        local modeRow = statRow(card, "Mode layout", ro)
        buttonRow(card, ro(), "Ganti mode (Auto/Mobile/Desktop)", function()
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
        UI.Label(card, "PC: tekan " .. CONFIG.ToggleKey.Name .. " untuk sembunyikan/tampilkan.", {
            Color = Theme.TextDim,
            Size = 12,
            Order = ro(),
        })

        local diag = UI.Section(content, "Diagnostik data", o())
        local dO = counter()
        local d = {
            balance = statRow(diag, "Modul Balance", dO),
            seeds = statRow(diag, "Seed terbaca", dO),
            tiers = statRow(diag, "Tabel tier", dO),
            mult = statRow(diag, "SellMultiplier", dO),
            plots = statRow(diag, "Plot di Workspace", dO),
            plot = statRow(diag, "Plot milikmu", dO),
            plants = statRow(diag, "Tanaman milikmu", dO),
        }
        buttonRow(diag, dO(), "Muat ulang data", function()
            Data.Reset()
            refreshNow()
        end)

        return function()
            scaleRow(string.format("%.1fx", Hub.State.userScale))
            alphaRow(string.format("%.0f%%", Hub.State.windowTransparency * 100))
            local mode = Hub.State.mobileOverride
            modeRow(mode == nil and "Auto" or (mode and "Mobile" or "Desktop"))

            local balance = Data.Module("Balance")
            d.balance(balance and "OK" or "Gagal", balance and GREEN or RED)
            local seeds = Data.Seeds()
            d.seeds(seeds and tostring(#seeds) or "0", seeds and GREEN or RED)
            local tiers = Data.Tiers()
            d.tiers(tiers and (tostring(#tiers) .. " tier") or "tidak ada", tiers and GREEN or RED)
            local mult = Data.Constant("SellMultiplier")
            d.mult(mult and tostring(mult) or "-", mult and GREEN or RED)
            local plants, plotName, plotCount = Data.MyPlants()
            d.plots(tostring(plotCount))
            d.plot(plotName or "-", plotName and GREEN or RED)
            d.plants(tostring(#plants))
        end
    end

    ----------------------------------------------------------------------------
    -- 4. PASANG KE HUB
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
    mount("SeedManager", buildSeeds)
    mount("Garden", buildGarden)
    mount("Index", buildIndex)
    mount("Settings", buildSettings)

    -- Refresh langsung saat pindah tab.
    local baseSelectTab = Hub.SelectTab
    function Hub:SelectTab(id)
        baseSelectTab(self, id)
        task.defer(refreshActive)
    end

    -- Polling 1 dtk, hanya tab aktif, berhenti saat minimize/close.
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
    refreshActive()
end

return Hub
