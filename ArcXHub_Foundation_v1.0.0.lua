--[[
    ============================================================================
    ARCXHUB — ADVANCED GAMING INTERFACE & GUI FOUNDATION
    ============================================================================
    Project     : ArcXHub
    Developer   : RyuzenX
    Target Game : Throw a Seed
    Environment : Roblox Luau (Delta Executor Android/PC & Roblox Studio)
    Version     : v1.0.0 (GUI Foundation + Modular Architecture)
    Theme       : Dark Purple + Black + Neon Violet Glassmorphism

    ARCHITECTURE MODULES:
      [1] Core          -> Janitor cleanup, anti-duplicate guard, viewport & drag utils
      [2] Theme         -> Dark Purple/Black palette, Neon Violet gradients, typography
      [3] Animations    -> Anti-stacking Tween manager, pulse, spinner, particle system
      [4] Notifications -> Slide-in / Fade-out toast notification stack
      [5] Components    -> Futuristic 'A' Logo, Glass Cards, Toggle, Slider, Dropdown, Input
      [6] Navigation    -> Animated Slide-In Sidebar & Smooth Fade Tab Controller
      [7] Settings      -> Live UI scale, glass opacity, layout mode, safe config save/load
      [8] FeatureModules-> Complete Home Dashboard + 7 Interactive Local Feature Tabs
    ============================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Anti-duplicate instance cleanup (menghapus UI lama sebelum memuat ulang)
local function cleanupPreviousInstance()
    local okEnv, env = pcall(function()
        return getgenv and getgenv() or shared
    end)
    local store = (okEnv and type(env) == "table") and env or shared
    if store.ArcXHubInstance and type(store.ArcXHubInstance.Destroy) == "function" then
        pcall(store.ArcXHubInstance.Destroy, store.ArcXHubInstance)
    end
    return store
end

local GlobalStore = cleanupPreviousInstance()

--------------------------------------------------------------------------------
-- [1] CORE MODULE: JANITOR, SAFE HELPERS & DRAG ENGINE
--------------------------------------------------------------------------------
local Core = {}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({
        _connections = {},
        _instances = {},
        _threads = {},
        _callbacks = {},
    }, Janitor)
end

function Janitor:AddConnection(conn)
    if typeof(conn) == "RBXScriptConnection" then
        table.insert(self._connections, conn)
    end
    return conn
end

function Janitor:AddInstance(inst)
    if typeof(inst) == "Instance" then
        table.insert(self._instances, inst)
    end
    return inst
end

function Janitor:AddThread(thread)
    if type(thread) == "thread" then
        table.insert(self._threads, thread)
    end
    return thread
end

function Janitor:AddCallback(fn)
    if type(fn) == "function" then
        table.insert(self._callbacks, fn)
    end
    return fn
end

function Janitor:Cleanup()
    for _, conn in ipairs(self._connections) do
        if conn.Connected then
            pcall(function()
                conn:Disconnect()
            end)
        end
    end
    table.clear(self._connections)

    for _, thread in ipairs(self._threads) do
        pcall(function()
            task.cancel(thread)
        end)
    end
    table.clear(self._threads)

    for _, cb in ipairs(self._callbacks) do
        pcall(cb)
    end
    table.clear(self._callbacks)

    for _, inst in ipairs(self._instances) do
        pcall(function()
            if inst and inst.Parent then
                inst:Destroy()
            end
        end)
    end
    table.clear(self._instances)
end

Core.Janitor = Janitor

function Core.Create(className, props, children)
    local inst = Instance.new(className)
    local parent = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then
                parent = v
            else
                inst[k] = v
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

function Core.Corner(parent, radius)
    return Core.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

function Core.Stroke(parent, color, thickness, transparency)
    return Core.Create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function Core.Padding(parent, top, right, bottom, left)
    return Core.Create("UIPadding", {
        PaddingTop = UDim.new(0, top or 8),
        PaddingRight = UDim.new(0, right or top or 8),
        PaddingBottom = UDim.new(0, bottom or top or 8),
        PaddingLeft = UDim.new(0, left or right or top or 8),
        Parent = parent,
    })
end

function Core.MountGui(screenGui, guiName)
    local targets = {}
    local okHui, hui = pcall(function()
        return gethui and gethui()
    end)
    if okHui and typeof(hui) == "Instance" then
        table.insert(targets, hui)
    end
    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and typeof(coreGui) == "Instance" then
        table.insert(targets, coreGui)
    end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if playerGui then
        table.insert(targets, playerGui)
    end

    for _, container in ipairs(targets) do
        local ok = pcall(function()
            local existing = container:FindFirstChild(guiName)
            if existing then
                existing:Destroy()
            end
            screenGui.Parent = container
        end)
        if ok and screenGui.Parent == container then
            return container
        end
    end
    return nil
end

function Core.GetViewport(screenGui)
    if screenGui and screenGui.AbsoluteSize.X > 0 and screenGui.AbsoluteSize.Y > 0 then
        return screenGui.AbsoluteSize
    end
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

function Core.ClampPosition(center, boxSize, viewport)
    local half = boxSize * 0.5
    local minX = math.min(half.X + 6, viewport.X * 0.5)
    local maxX = math.max(viewport.X - half.X - 6, viewport.X * 0.5)
    local minY = math.min(half.Y + 6, viewport.Y * 0.5)
    local maxY = math.max(viewport.Y - half.Y - 6, viewport.Y * 0.5)
    return Vector2.new(
        math.clamp(center.X, minX, maxX),
        math.clamp(center.Y, minY, maxY)
    )
end

-- Drag handler universal untuk Mouse (PC) dan Touch (Android) tanpa bentrok dengan klik
function Core.MakeDraggable(janitor, handle, target, screenGui, options)
    options = options or {}
    local dragging = false
    local dragged = false
    local activeInput = nil
    local startMouse = Vector2.zero
    local startPos = target.Position
    local threshold = options.TapThreshold or 6

    janitor:AddConnection(handle.InputBegan:Connect(function(input)
        local uType = input.UserInputType
        if uType ~= Enum.UserInputType.MouseButton1 and uType ~= Enum.UserInputType.Touch then
            return
        end
        if options.ExcludeRightPx then
            local rightEdge = handle.AbsolutePosition.X + handle.AbsoluteSize.X
            if input.Position.X >= (rightEdge - options.ExcludeRightPx) then
                return
            end
        end
        dragging = true
        dragged = false
        activeInput = input
        startMouse = Vector2.new(input.Position.X, input.Position.Y)
        startPos = target.Position
    end))

    janitor:AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouch = input.UserInputType == Enum.UserInputType.Touch and input == activeInput
        if not (isMouse or isTouch) then
            return
        end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startMouse
        if not dragged and delta.Magnitude < threshold then
            return
        end
        dragged = true
        local viewport = Core.GetViewport(screenGui)
        local rawCenter = Vector2.new(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        local clamped = Core.ClampPosition(rawCenter, target.AbsoluteSize, viewport)
        target.Position = UDim2.fromOffset(clamped.X, clamped.Y)
    end))

    janitor:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if not dragging or not activeInput then
            return
        end
        local ended = (input == activeInput)
            or (input.UserInputType == Enum.UserInputType.MouseButton1
                and activeInput.UserInputType == Enum.UserInputType.MouseButton1)
        if not ended then
            return
        end
        dragging = false
        activeInput = nil
        if not dragged and type(options.OnTap) == "function" then
            pcall(options.OnTap)
        end
    end))
end

--------------------------------------------------------------------------------
-- [2] THEME MODULE: DARK PURPLE + BLACK + NEON VIOLET GLASSMORPHISM
--------------------------------------------------------------------------------
local Theme = {
    Brand = "ArcXHub",
    Developer = "RyuzenX",
    TargetGame = "Throw a Seed",
    Version = "v1.0.0",

    -- Core Palette
    Obsidian = Color3.fromRGB(7, 5, 13),          -- Deepest Black-Purple
    Background = Color3.fromRGB(12, 9, 22),       -- Main Window Glass Base
    SidebarBg = Color3.fromRGB(15, 11, 28),       -- Sidebar Surface
    CardBg = Color3.fromRGB(21, 16, 38),          -- Glass Card
    CardElevated = Color3.fromRGB(30, 22, 54),    -- Hover / Interactive Control
    ControlTrack = Color3.fromRGB(38, 28, 66),    -- Slider / Switch Track

    -- Neon Violet Accents
    NeonViolet = Color3.fromRGB(157, 78, 221),    -- Primary Neon Accent
    ElectricPurple = Color3.fromRGB(199, 125, 255), -- Highlight Glow
    DeepViolet = Color3.fromRGB(90, 42, 158),     -- Pressed / Active Fill
    BorderGlow = Color3.fromRGB(123, 63, 196),    -- Glass Border Stroke

    -- Status Colors
    Success = Color3.fromRGB(72, 229, 155),
    Warning = Color3.fromRGB(255, 196, 77),
    Danger = Color3.fromRGB(244, 78, 112),
    Info = Color3.fromRGB(125, 185, 255),

    -- Typography
    TextPrimary = Color3.fromRGB(245, 240, 255),
    TextSecondary = Color3.fromRGB(172, 158, 204),
    TextMuted = Color3.fromRGB(118, 105, 148),

    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,
    FontRegular = Enum.Font.Gotham,
}

function Theme.ApplyGlassGradient(parent, rotation)
    return Core.Create("UIGradient", {
        Rotation = rotation or 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 22, 58)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 12, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 7, 18)),
        }),
        Parent = parent,
    })
end

function Theme.ApplyNeonGradient(parent, rotation)
    return Core.Create("UIGradient", {
        Rotation = rotation or 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.DeepViolet),
            ColorSequenceKeypoint.new(0.5, Theme.NeonViolet),
            ColorSequenceKeypoint.new(1, Theme.ElectricPurple),
        }),
        Parent = parent,
    })
end

--------------------------------------------------------------------------------
-- [3] ANIMATIONS MODULE: ANTI-STACKING TWEEN ENGINE, PULSE, SPINNER & PARTICLES
--------------------------------------------------------------------------------
local Animations = {
    _activeTweens = setmetatable({}, { __mode = "k" }),
}

-- Memastikan animasi pada objek yang sama tidak menumpuk
function Animations.Play(instance, duration, goals, style, direction)
    if not instance or not instance.Parent then
        return nil
    end
    local existing = Animations._activeTweens[instance]
    if existing then
        pcall(function()
            existing:Cancel()
        end)
    end
    local info = TweenInfo.new(
        duration or 0.22,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, info, goals)
    Animations._activeTweens[instance] = tween
    tween.Completed:Connect(function()
        if Animations._activeTweens[instance] == tween then
            Animations._activeTweens[instance] = nil
        end
    end)
    tween:Play()
    return tween
end

-- Feedback Hover & Press universal untuk tombol interaktif
function Animations.BindButtonFeedback(janitor, button, normalColor, hoverColor, pressColor)
    normalColor = normalColor or button.BackgroundColor3
    hoverColor = hoverColor or Theme.CardElevated
    pressColor = pressColor or Theme.DeepViolet

    local isHovered = false

    janitor:AddConnection(button.MouseEnter:Connect(function()
        isHovered = true
        Animations.Play(button, 0.16, { BackgroundColor3 = hoverColor })
    end))

    janitor:AddConnection(button.MouseLeave:Connect(function()
        isHovered = false
        Animations.Play(button, 0.18, { BackgroundColor3 = normalColor })
    end))

    janitor:AddConnection(button.InputBegan:Connect(function(input)
        local uType = input.UserInputType
        if uType == Enum.UserInputType.MouseButton1 or uType == Enum.UserInputType.Touch then
            Animations.Play(button, 0.1, { BackgroundColor3 = pressColor })
        end
    end))

    janitor:AddConnection(button.InputEnded:Connect(function(input)
        local uType = input.UserInputType
        if uType == Enum.UserInputType.MouseButton1 or uType == Enum.UserInputType.Touch then
            Animations.Play(button, 0.16, { BackgroundColor3 = isHovered and hoverColor or normalColor })
        end
    end))
end

-- Rotating loading indicator (ringan & otomatis berhenti saat janitor cleanup)
function Animations.StartSpinner(janitor, spinnerObj, isPausedFn)
    local thread = task.spawn(function()
        while spinnerObj and spinnerObj.Parent do
            if not (isPausedFn and isPausedFn()) then
                spinnerObj.Rotation = (spinnerObj.Rotation + 8) % 360
                task.wait(0.03)
            else
                task.wait(0.25)
            end
        end
    end)
    janitor:AddThread(thread)
    return thread
end

-- Pulse animation untuk Floating Logo
function Animations.StartPulse(janitor, pulseRing, isActiveFn)
    local thread = task.spawn(function()
        local expand = true
        while pulseRing and pulseRing.Parent do
            if not isActiveFn or isActiveFn() then
                if expand then
                    Animations.Play(pulseRing, 1.15, {
                        Size = UDim2.new(1, 14, 1, 14),
                        BackgroundTransparency = 0.88,
                    }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                else
                    Animations.Play(pulseRing, 1.15, {
                        Size = UDim2.new(1, 2, 1, 2),
                        BackgroundTransparency = 0.55,
                    }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                end
                expand = not expand
                task.wait(1.2)
            else
                task.wait(0.3)
            end
        end
    end)
    janitor:AddThread(thread)
    return thread
end

-- Subtle ambient particle system pada latar belakang window
function Animations.CreateParticleField(janitor, container, count, stateRef)
    local layer = Core.Create("Frame", {
        Name = "AmbientParticles",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = container,
    })

    local rng = Random.new()
    local particles = {}

    for i = 1, (count or 14) do
        local sizePx = rng:NextInteger(3, 7)
        local dot = Core.Create("Frame", {
            Name = "Particle_" .. tostring(i),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.08, 0.92)),
            Size = UDim2.fromOffset(sizePx, sizePx),
            BackgroundColor3 = (i % 2 == 0) and Theme.ElectricPurple or Theme.NeonViolet,
            BackgroundTransparency = rng:NextNumber(0.68, 0.88),
            BorderSizePixel = 0,
            ZIndex = 1,
            Parent = layer,
        })
        Core.Corner(dot, sizePx)
        table.insert(particles, dot)
    end

    local thread = task.spawn(function()
        while layer and layer.Parent do
            local enabled = stateRef.particlesEnabled and not stateRef.minimized and not stateRef.destroyed
            layer.Visible = stateRef.particlesEnabled
            if enabled then
                for _, dot in ipairs(particles) do
                    if dot and dot.Parent then
                        local nextX = rng:NextNumber(0.05, 0.95)
                        local nextY = rng:NextNumber(0.06, 0.94)
                        local nextAlpha = rng:NextNumber(0.65, 0.9)
                        local dur = rng:NextNumber(3.2, 5.5)
                        Animations.Play(dot, dur, {
                            Position = UDim2.fromScale(nextX, nextY),
                            BackgroundTransparency = nextAlpha,
                        }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                    end
                end
                task.wait(3.4)
            else
                task.wait(0.4)
            end
        end
    end)
    janitor:AddThread(thread)
    return layer
end

--------------------------------------------------------------------------------
-- [4] NOTIFICATIONS MODULE: SLIDE IN / FADE OUT TOAST SYSTEM
--------------------------------------------------------------------------------
local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(janitor, screenGui, stateRef)
    local self = setmetatable({
        _janitor = janitor,
        _state = stateRef,
        _count = 0,
    }, Notifications)

    self._holder = Core.Create("Frame", {
        Name = "NotificationStack",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.new(0, 270, 0, 240),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = screenGui,
    })

    Core.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self._holder,
    })

    return self
end

function Notifications:Push(title, message, kind, duration)
    if self._state and not self._state.notificationsEnabled then
        return
    end
    duration = duration or 3.2
    self._count += 1

    local accentColor = Theme.NeonViolet
    local badgeText = "INFO"
    if kind == "success" then
        accentColor = Theme.Success
        badgeText = "OK"
    elseif kind == "warning" then
        accentColor = Theme.Warning
        badgeText = "WARN"
    elseif kind == "error" then
        accentColor = Theme.Danger
        badgeText = "ALERT"
    end

    local wrapper = Core.Create("Frame", {
        Name = "ToastWrapper_" .. tostring(self._count),
        LayoutOrder = self._count,
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = self._holder,
    })

    local card = Core.Create("CanvasGroup", {
        Name = "ToastCard",
        Position = UDim2.fromOffset(300, 0), -- Mulai di luar layar kanan untuk Slide In
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        GroupTransparency = 0.06,
        Parent = wrapper,
    })
    Core.Corner(card, 10)
    Core.Stroke(card, accentColor, 1.2, 0.25)

    -- Garis aksen kiri
    Core.Create("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
    })

    -- Badge status
    local badge = Core.Create("TextLabel", {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.fromOffset(42, 16),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.82,
        Font = Theme.FontBold,
        Text = badgeText,
        TextSize = 10,
        TextColor3 = accentColor,
        Parent = card,
    })
    Core.Corner(badge, 4)

    -- Title
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(60, 7),
        Size = UDim2.new(1, -68, 0, 18),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(title or "ArcXHub"),
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = card,
    })

    -- Message
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(12, 27),
        Size = UDim2.new(1, -20, 0, 26),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = tostring(message or ""),
        TextSize = 11,
        TextColor3 = Theme.TextSecondary,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    -- Progress timer bar di bagian bawah toast
    local timerBar = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
    })

    -- Slide In Animation
    Animations.Play(card, 0.28, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Animations.Play(timerBar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    -- Auto Fade Out & Cleanup
    task.delay(duration, function()
        if not wrapper or not wrapper.Parent then
            return
        end
        Animations.Play(card, 0.24, {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(60, 0),
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.25, function()
            if wrapper and wrapper.Parent then
                wrapper:Destroy()
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- [5] COMPONENTS MODULE: FUTURISTIC 'A' LOGO & INTERACTIVE CONTROLS
--------------------------------------------------------------------------------
local Components = {}

-- Logo huruf 'A' bergaya futuristik berbasis geometri vector UI (tanpa bergantung aset eksternal)
function Components.CreateFuturisticLogoA(parent, sizePx)
    sizePx = sizePx or 30
    local emblem = Core.Create("Frame", {
        Name = "ArcXLogoA",
        Size = UDim2.fromOffset(sizePx, sizePx),
        BackgroundColor3 = Theme.Obsidian,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(emblem, math.floor(sizePx * 0.28))
    Core.Stroke(emblem, Theme.ElectricPurple, 1.4, 0.15)
    Theme.ApplyGlassGradient(emblem, 135)

    local canvas = Core.Create("Frame", {
        Name = "VectorCanvas",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.76, 0.76),
        BackgroundTransparency = 1,
        Parent = emblem,
    })

    -- Kaki kiri huruf A (miring)
    local leftLeg = Core.Create("Frame", {
        Name = "LeftBlade",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.35, 0.52),
        Size = UDim2.new(0.16, 0, 0.84, 0),
        Rotation = 20,
        BackgroundColor3 = Theme.ElectricPurple,
        BorderSizePixel = 0,
        Parent = canvas,
    })
    Core.Corner(leftLeg, 3)
    Theme.ApplyNeonGradient(leftLeg, 90)

    -- Kaki kanan huruf A (miring)
    local rightLeg = Core.Create("Frame", {
        Name = "RightBlade",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.65, 0.52),
        Size = UDim2.new(0.16, 0, 0.84, 0),
        Rotation = -20,
        BackgroundColor3 = Theme.ElectricPurple,
        BorderSizePixel = 0,
        Parent = canvas,
    })
    Core.Corner(rightLeg, 3)
    Theme.ApplyNeonGradient(rightLeg, 90)

    -- Palang energi horizontal futuristik di tengah A
    local crossCore = Core.Create("Frame", {
        Name = "EnergyCrossbar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.63),
        Size = UDim2.new(0.54, 0, 0.13, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = canvas,
    })
    Core.Corner(crossCore, 2)

    -- Apex node di puncak huruf A
    local apex = Core.Create("Frame", {
        Name = "ApexNode",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.14),
        Size = UDim2.new(0.2, 0, 0.14, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = canvas,
    })
    Core.Corner(apex, 2)

    return emblem
end

function Components.CreatePageHeader(parent, title, subtitle, badgeText)
    local headerCard = Core.Create("Frame", {
        Name = "PageHeader",
        LayoutOrder = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(headerCard, 12)
    Core.Stroke(headerCard, Theme.BorderGlow, 1, 0.45)
    Core.Padding(headerCard, 12, 14, 12, 14)

    local topRow = Core.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Parent = headerCard,
    })

    Core.Create("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = title,
        TextSize = 17,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = topRow,
    })

    if badgeText then
        local pill = Core.Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(82, 20),
            BackgroundColor3 = Theme.DeepViolet,
            BackgroundTransparency = 0.35,
            Font = Theme.FontBold,
            Text = badgeText,
            TextSize = 10,
            TextColor3 = Theme.ElectricPurple,
            Parent = topRow,
        })
        Core.Corner(pill, 6)
        Core.Stroke(pill, Theme.NeonViolet, 1, 0.4)
    end

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(0, 25),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = subtitle,
        TextSize = 12,
        TextColor3 = Theme.TextSecondary,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerCard,
    })

    return headerCard
end

function Components.CreateSection(parent, title, order)
    local card = Core.Create("Frame", {
        Name = "Section_" .. tostring(title or "Block"),
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(card, 11)
    Core.Stroke(card, Theme.BorderGlow, 1, 0.55)
    Core.Padding(card, 11, 12, 11, 12)

    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })

    if title then
        Core.Create("TextLabel", {
            Name = "SectionTitle",
            LayoutOrder = 0,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = string.upper(title),
            TextSize = 11,
            TextColor3 = Theme.ElectricPurple,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })
    end

    return card
end

function Components.CreateInfoRow(parent, labelText, initialValue, valueColor, order)
    local row = Core.Create("Frame", {
        Name = "InfoRow",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    Core.Create("TextLabel", {
        Size = UDim2.new(0.54, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = labelText,
        TextSize = 12,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    local valLabel = Core.Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.46, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(initialValue or "-"),
        TextSize = 12,
        TextColor3 = valueColor or Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    return function(newText, newColor)
        valLabel.Text = tostring(newText)
        if newColor then
            valLabel.TextColor3 = newColor
        end
    end
end

function Components.CreateButton(janitor, parent, text, onClick, options)
    options = options or {}
    local baseColor = options.Color or Theme.DeepViolet
    local hoverColor = options.HoverColor or Theme.NeonViolet

    local btn = Core.Create("TextButton", {
        Name = "ActionBtn",
        LayoutOrder = options.Order or 1,
        Size = options.Size or UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = baseColor,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = text,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        Parent = parent,
    })
    Core.Corner(btn, 8)
    Core.Stroke(btn, Theme.ElectricPurple, 1, 0.55)

    Animations.BindButtonFeedback(janitor, btn, baseColor, hoverColor, Theme.Obsidian)

    janitor:AddConnection(btn.Activated:Connect(function()
        if type(onClick) == "function" then
            local ok, err = pcall(onClick)
            if not ok then
                warn("[ArcXHub] Button callback error: " .. tostring(err))
            end
        end
    end))

    return btn
end

-- Toggle Switch dengan animasi halus
function Components.CreateToggle(janitor, parent, labelText, descText, defaultState, onChanged, order)
    local state = defaultState == true

    local holder = Core.Create("Frame", {
        Name = "ToggleControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, descText and 46 or 34),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(holder, 8)
    Core.Padding(holder, 6, 10, 6, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(0, descText and 1 or 4),
        Size = UDim2.new(1, -56, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = labelText,
        TextSize = 13,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = holder,
    })

    if descText then
        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.new(1, -56, 0, 14),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = descText,
            TextSize = 11,
            TextColor3 = Theme.TextMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = holder,
        })
    end

    local switchTrack = Core.Create("TextButton", {
        Name = "SwitchTrack",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(44, 22),
        BackgroundColor3 = state and Theme.NeonViolet or Theme.ControlTrack,
        AutoButtonColor = false,
        Text = "",
        Parent = holder,
    })
    Core.Corner(switchTrack, 11)
    local trackStroke = Core.Stroke(switchTrack, state and Theme.ElectricPurple or Theme.BorderGlow, 1, 0.3)

    local knob = Core.Create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = switchTrack,
    })
    Core.Corner(knob, 8)

    local function setState(newVal, silent)
        state = newVal == true
        Animations.Play(switchTrack, 0.2, {
            BackgroundColor3 = state and Theme.NeonViolet or Theme.ControlTrack,
        })
        Animations.Play(trackStroke, 0.2, {
            Color = state and Theme.ElectricPurple or Theme.BorderGlow,
        })
        Animations.Play(knob, 0.22, {
            Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        if not silent and type(onChanged) == "function" then
            pcall(onChanged, state)
        end
    end

    janitor:AddConnection(switchTrack.Activated:Connect(function()
        setState(not state, false)
    end))

    return {
        Set = setState,
        Get = function()
            return state
        end,
    }
end

-- Interactive Slider (Mendukung Mouse & Touchscreen Android)
function Components.CreateSlider(janitor, parent, labelText, minVal, maxVal, defaultVal, step, suffix, onChanged, order)
    minVal = minVal or 0
    maxVal = maxVal or 100
    step = step or 1
    suffix = suffix or ""
    local currentVal = math.clamp(defaultVal or minVal, minVal, maxVal)

    local holder = Core.Create("Frame", {
        Name = "SliderControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(holder, 8)
    Core.Padding(holder, 7, 10, 8, 10)

    Core.Create("TextLabel", {
        Size = UDim2.new(0.68, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = labelText,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    })

    local valDisplay = Core.Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.32, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(currentVal) .. suffix,
        TextSize = 12,
        TextColor3 = Theme.ElectricPurple,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = holder,
    })

    local hitArea = Core.Create("TextButton", {
        Name = "SliderHitArea",
        Position = UDim2.fromOffset(0, 21),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = holder,
    })

    local track = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme.ControlTrack,
        BorderSizePixel = 0,
        Parent = hitArea,
    })
    Core.Corner(track, 3)

    local initialRatio = (maxVal > minVal) and ((currentVal - minVal) / (maxVal - minVal)) or 0
    local fill = Core.Create("Frame", {
        Size = UDim2.fromScale(initialRatio, 1),
        BackgroundColor3 = Theme.NeonViolet,
        BorderSizePixel = 0,
        Parent = track,
    })
    Core.Corner(fill, 3)

    local thumb = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(initialRatio, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = track,
    })
    Core.Corner(thumb, 7)
    Core.Stroke(thumb, Theme.ElectricPurple, 1.5, 0.1)

    local function formatNumber(v)
        if step < 1 then
            return string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
        end
        return tostring(math.floor(v + 0.5))
    end

    local function setValue(raw, silent)
        local snapped = minVal + math.floor(((raw - minVal) / step) + 0.5) * step
        currentVal = math.clamp(snapped, minVal, maxVal)
        local ratio = (maxVal > minVal) and ((currentVal - minVal) / (maxVal - minVal)) or 0
        valDisplay.Text = formatNumber(currentVal) .. suffix
        fill.Size = UDim2.fromScale(ratio, 1)
        thumb.Position = UDim2.fromScale(ratio, 0.5)
        if not silent and type(onChanged) == "function" then
            pcall(onChanged, currentVal)
        end
    end

    local sliding = false
    local activeInput = nil

    local function updateFromScreenX(x)
        local left = track.AbsolutePosition.X
        local width = math.max(track.AbsoluteSize.X, 1)
        local ratio = math.clamp((x - left) / width, 0, 1)
        setValue(minVal + ratio * (maxVal - minVal), false)
    end

    janitor:AddConnection(hitArea.InputBegan:Connect(function(input)
        local uType = input.UserInputType
        if uType == Enum.UserInputType.MouseButton1 or uType == Enum.UserInputType.Touch then
            sliding = true
            activeInput = input
            updateFromScreenX(input.Position.X)
        end
    end))

    janitor:AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not sliding then
            return
        end
        local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouch = input.UserInputType == Enum.UserInputType.Touch and input == activeInput
        if isMouse or isTouch then
            updateFromScreenX(input.Position.X)
        end
    end))

    janitor:AddConnection(UserInputService.InputEnded:Connect(function(input)
        if not sliding then
            return
        end
        if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
            activeInput = nil
        end
    end))

    return {
        Set = setValue,
        Get = function()
            return currentVal
        end,
    }
end

-- Interactive Dropdown Selector
function Components.CreateDropdown(janitor, parent, labelText, optionsList, defaultOption, onSelect, order)
    optionsList = optionsList or { "Option 1" }
    local selected = defaultOption or optionsList[1]
    local expanded = false

    local wrapper = Core.Create("Frame", {
        Name = "DropdownControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 36),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(wrapper, 8)
    Core.Padding(wrapper, 6, 10, 6, 10)

    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = wrapper,
    })

    local headerBtn = Core.Create("TextButton", {
        Name = "Header",
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = wrapper,
    })

    Core.Create("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = labelText,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerBtn,
    })

    local selectedLabel = Core.Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(selected) .. "  ▾",
        TextSize = 12,
        TextColor3 = Theme.ElectricPurple,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = headerBtn,
    })

    local listContainer = Core.Create("Frame", {
        Name = "OptionsList",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = wrapper,
    })

    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listContainer,
    })

    local function setExpanded(state)
        expanded = state
        listContainer.Visible = expanded
        selectedLabel.Text = tostring(selected) .. (expanded and "  ▴" or "  ▾")
    end

    for idx, opt in ipairs(optionsList) do
        local optBtn = Core.Create("TextButton", {
            Name = "Opt_" .. tostring(opt),
            LayoutOrder = idx,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.Background,
            AutoButtonColor = false,
            Font = Theme.FontMedium,
            Text = tostring(opt),
            TextSize = 12,
            TextColor3 = (opt == selected) and Theme.ElectricPurple or Theme.TextSecondary,
            Parent = listContainer,
        })
        Core.Corner(optBtn, 6)
        Animations.BindButtonFeedback(janitor, optBtn, Theme.Background, Theme.DeepViolet, Theme.NeonViolet)

        janitor:AddConnection(optBtn.Activated:Connect(function()
            selected = opt
            for _, child in ipairs(listContainer:GetChildren()) do
                if child:IsA("TextButton") then
                    child.TextColor3 = (child.Text == tostring(selected)) and Theme.ElectricPurple or Theme.TextSecondary
                end
            end
            setExpanded(false)
            if type(onSelect) == "function" then
                pcall(onSelect, selected)
            end
        end))
    end

    janitor:AddConnection(headerBtn.Activated:Connect(function()
        setExpanded(not expanded)
    end))

    return {
        Get = function()
            return selected
        end,
        Set = function(val, silent)
            selected = val
            selectedLabel.Text = tostring(selected) .. (expanded and "  ▴" or "  ▾")
            if not silent and type(onSelect) == "function" then
                pcall(onSelect, selected)
            end
        end,
    }
end

-- Search / Text Input Box
function Components.CreateTextInput(janitor, parent, placeholder, defaultText, onChanged, order)
    local holder = Core.Create("Frame", {
        Name = "InputHolder",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(holder, 8)
    local stroke = Core.Stroke(holder, Theme.BorderGlow, 1, 0.5)

    local box = Core.Create("TextBox", {
        Name = "TextInput",
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Font = Theme.FontRegular,
        PlaceholderText = placeholder or "Type here...",
        PlaceholderColor3 = Theme.TextMuted,
        Text = defaultText or "",
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    })

    local clearBtn = Core.Create("TextButton", {
        Name = "ClearBtn",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Theme.Background,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = "×",
        TextSize = 13,
        TextColor3 = Theme.TextSecondary,
        Visible = #(defaultText or "") > 0,
        Parent = holder,
    })
    Core.Corner(clearBtn, 6)

    janitor:AddConnection(box.Focused:Connect(function()
        Animations.Play(stroke, 0.16, { Color = Theme.ElectricPurple, Transparency = 0 })
    end))

    janitor:AddConnection(box.FocusLost:Connect(function()
        Animations.Play(stroke, 0.16, { Color = Theme.BorderGlow, Transparency = 0.5 })
    end))

    janitor:AddConnection(box:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = #box.Text > 0
        if type(onChanged) == "function" then
            pcall(onChanged, box.Text)
        end
    end))

    janitor:AddConnection(clearBtn.Activated:Connect(function()
        box.Text = ""
    end))

    return box
end

--------------------------------------------------------------------------------
-- [6] NAVIGATION MODULE: SLIDE-IN SIDEBAR & SMOOTH FADE PAGE CONTROLLER
--------------------------------------------------------------------------------
local Navigation = {}
Navigation.__index = Navigation

function Navigation.new(janitor, sidebarScroll, contentContainer, onTabSelected)
    return setmetatable({
        _janitor = janitor,
        _sidebar = sidebarScroll,
        _content = contentContainer,
        _onTabSelected = onTabSelected,
        _tabs = {},
        _order = {},
        _activeId = nil,
    }, Navigation)
end

function Navigation:AddTab(def)
    local id = def.Id
    if self._tabs[id] then
        return self._tabs[id]
    end

    local orderIndex = #self._order + 1
    table.insert(self._order, id)

    local btn = Core.Create("TextButton", {
        Name = "Nav_" .. id,
        LayoutOrder = orderIndex,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = self._sidebar,
    })
    Core.Corner(btn, 8)

    local indicator = Core.Create("Frame", {
        Name = "ActiveBar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(0, 3, 0.58, 0),
        BackgroundColor3 = Theme.ElectricPurple,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = btn,
    })
    Core.Corner(indicator, 2)

    local badge = Core.Create("TextLabel", {
        Name = "Glyph",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Theme.DeepViolet,
        BackgroundTransparency = 0.65,
        Font = Theme.FontBold,
        Text = def.Glyph or "•",
        TextSize = 10,
        TextColor3 = Theme.TextSecondary,
        Parent = btn,
    })
    Core.Corner(badge, 5)

    local label = Core.Create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(33, 0),
        Size = UDim2.new(1, -38, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = def.Title,
        TextSize = 12,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = btn,
    })

    local page = Core.Create("CanvasGroup", {
        Name = "Page_" .. id,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        Parent = self._content,
    })

    local scroll = Core.Create("ScrollingFrame", {
        Name = "PageScroll",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.NeonViolet,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = page,
    })
    Core.Padding(scroll, 12, 12, 14, 12)
    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })

    local tabObj = {
        Id = id,
        Title = def.Title,
        Button = btn,
        Indicator = indicator,
        Badge = badge,
        Label = label,
        Page = page,
        Scroll = scroll,
    }

    self._janitor:AddConnection(btn.MouseEnter:Connect(function()
        if self._activeId ~= id then
            Animations.Play(btn, 0.15, { BackgroundTransparency = 0.55 })
        end
    end))

    self._janitor:AddConnection(btn.MouseLeave:Connect(function()
        if self._activeId ~= id then
            Animations.Play(btn, 0.15, { BackgroundTransparency = 1 })
        end
    end))

    self._janitor:AddConnection(btn.Activated:Connect(function()
        self:Select(id)
    end))

    self._tabs[id] = tabObj
    return tabObj
end

function Navigation:Select(id)
    local nextTab = self._tabs[id]
    if not nextTab or self._activeId == id then
        return
    end

    local prevTab = self._activeId and self._tabs[self._activeId]
    if prevTab then
        prevTab.Page.Visible = false
        prevTab.Page.GroupTransparency = 1
        Animations.Play(prevTab.Button, 0.18, { BackgroundTransparency = 1 })
        Animations.Play(prevTab.Indicator, 0.18, { BackgroundTransparency = 1 })
        prevTab.Label.Font = Theme.FontMedium
        prevTab.Label.TextColor3 = Theme.TextSecondary
        prevTab.Badge.BackgroundTransparency = 0.65
        prevTab.Badge.TextColor3 = Theme.TextSecondary
    end

    self._activeId = id
    Animations.Play(nextTab.Button, 0.2, {
        BackgroundColor3 = Theme.DeepViolet,
        BackgroundTransparency = 0.25,
    })
    Animations.Play(nextTab.Indicator, 0.2, { BackgroundTransparency = 0 })
    nextTab.Label.Font = Theme.FontBold
    nextTab.Label.TextColor3 = Theme.TextPrimary
    nextTab.Badge.BackgroundTransparency = 0.15
    nextTab.Badge.TextColor3 = Theme.TextPrimary

    -- Smooth Fade + Subtle Rise Transition
    nextTab.Page.Position = UDim2.fromOffset(0, 10)
    nextTab.Page.GroupTransparency = 1
    nextTab.Page.Visible = true
    Animations.Play(nextTab.Page, 0.25, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 0),
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if type(self._onTabSelected) == "function" then
        pcall(self._onTabSelected, id)
    end
end

function Navigation:GetActiveId()
    return self._activeId
end

--------------------------------------------------------------------------------
-- [7] SETTINGS & CONFIGURATION LAYER
--------------------------------------------------------------------------------
local SettingsManager = {
    FileName = "ArcXHub_ThrowASeed_Config.json",
    Defaults = {
        uiScale = 1.0,
        glassTransparency = 0.08,
        layoutMode = "Auto", -- "Auto" | "Mobile" | "Desktop"
        particlesEnabled = true,
        notificationsEnabled = true,
        toggleKeyName = "RightShift",
    },
}

function SettingsManager.Save(data)
    local HttpService = game:GetService("HttpService")
    local okEncode, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not okEncode then
        return false, "Gagal mengodekan konfigurasi."
    end

    local okWrite = pcall(function()
        if type(writefile) == "function" then
            writefile(SettingsManager.FileName, json)
        else
            error("writefile unavailable")
        end
    end)

    if okWrite then
        return true, "Konfigurasi disimpan ke file lokal."
    end
    return false, "API writefile tidak tersedia; pengaturan aktif di memori sesi."
end

function SettingsManager.Load()
    local HttpService = game:GetService("HttpService")
    local okRead, raw = pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(SettingsManager.FileName) then
            return readfile(SettingsManager.FileName)
        end
        return nil
    end)
    if okRead and type(raw) == "string" and #raw > 0 then
        local okDecode, parsed = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if okDecode and type(parsed) == "table" then
            return parsed, true
        end
    end
    return nil, false
end

--------------------------------------------------------------------------------
-- [8] HUB CONTROLLER & FEATURE MODULES (8 TABS)
--------------------------------------------------------------------------------
local ArcXHub = {}
local janitor = Janitor.new()

local HubState = {
    destroyed = false,
    closing = false,
    minimized = false,
    sessionStart = os.clock(),

    -- Configurable settings
    uiScale = SettingsManager.Defaults.uiScale,
    glassTransparency = SettingsManager.Defaults.glassTransparency,
    layoutMode = SettingsManager.Defaults.layoutMode,
    particlesEnabled = SettingsManager.Defaults.particlesEnabled,
    notificationsEnabled = SettingsManager.Defaults.notificationsEnabled,
    toggleKey = Enum.KeyCode.RightShift,

    -- Local interactive mock/preview states (zero remote calls)
    localFarmActive = false,
    localFarmPower = 0.98,
    localFarmThrows = 5,
    localFarmMode = "Balanced",
    localSellPreview = true,
    localSellMinRarity = "Rare",
    localSellThreshold = 85,
    localBoostReminder = 30,
    selectedSeed = "CloudSeed",
    selectedRemote = "Request",
}

-- Load saved config if available
do
    local saved = SettingsManager.Load()
    if saved then
        if type(saved.uiScale) == "number" then
            HubState.uiScale = math.clamp(saved.uiScale, 0.65, 1.45)
        end
        if type(saved.glassTransparency) == "number" then
            HubState.glassTransparency = math.clamp(saved.glassTransparency, 0, 0.55)
        end
        if type(saved.layoutMode) == "string" then
            HubState.layoutMode = saved.layoutMode
        end
        if type(saved.particlesEnabled) == "boolean" then
            HubState.particlesEnabled = saved.particlesEnabled
        end
        if type(saved.notificationsEnabled) == "boolean" then
            HubState.notificationsEnabled = saved.notificationsEnabled
        end
        if type(saved.toggleKeyName) == "string" and Enum.KeyCode[saved.toggleKeyName] then
            HubState.toggleKey = Enum.KeyCode[saved.toggleKeyName]
        end
    end
end

-- Create Root ScreenGui
local screenGui = Core.Create("ScreenGui", {
    Name = "ArcXHub_ThrowASeed",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 1000,
})
janitor:AddInstance(screenGui)

local mountedContainer = Core.MountGui(screenGui, "ArcXHub_ThrowASeed")
if not mountedContainer then
    warn("[ArcXHub] Gagal memasang ScreenGui ke container mana pun.")
    return
end

local notifier = Notifications.new(janitor, screenGui, HubState)

-- Responsive Dimensions
local WINDOW_SPECS = {
    TitleBarHeight = 44,
    Desktop = { Width = 620, Height = 400, Sidebar = 152 },
    Mobile = { Width = 470, Height = 295, Sidebar = 114 },
    MinSize = Vector2.new(310, 230),
}

local startViewport = Core.GetViewport(screenGui)

local rootAnchor = Core.Create("Frame", {
    Name = "RootAnchor",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(startViewport.X * 0.5, startViewport.Y * 0.5),
    Size = UDim2.fromOffset(WINDOW_SPECS.Desktop.Width, WINDOW_SPECS.Desktop.Height),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = screenGui,
})

local mainWindow = Core.Create("CanvasGroup", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WINDOW_SPECS.Desktop.Width, WINDOW_SPECS.Desktop.Height),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Parent = rootAnchor,
})
Core.Corner(mainWindow, 14)
Core.Stroke(mainWindow, Theme.BorderGlow, 1.5, 0.18)
Theme.ApplyGlassGradient(mainWindow, 135)

local windowScale = Core.Create("UIScale", {
    Scale = HubState.uiScale,
    Parent = mainWindow,
})

-- Ambient background particle layer
Animations.CreateParticleField(janitor, mainWindow, 14, HubState)

-- HEADER / TITLE BAR
local titleBar = Core.Create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, WINDOW_SPECS.TitleBarHeight),
    BackgroundColor3 = Theme.Obsidian,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
    Parent = mainWindow,
})

-- Bottom neon divider line on header
local headerLine = Core.Create("Frame", {
    Name = "NeonDivider",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = titleBar,
})
Theme.ApplyNeonGradient(headerLine, 0)

-- Futuristic Logo 'A' in Header
local headerLogo = Components.CreateFuturisticLogoA(titleBar, 28)
headerLogo.Position = UDim2.fromOffset(12, 8)

Core.Create("TextLabel", {
    Name = "BrandTitle",
    Position = UDim2.fromOffset(48, 5),
    Size = UDim2.new(1, -145, 0, 18),
    BackgroundTransparency = 1,
    Font = Theme.FontBold,
    RichText = true,
    Text = '<font color="#C77DFF">ArcX</font>Hub',
    TextSize = 15,
    TextColor3 = Theme.TextPrimary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

Core.Create("TextLabel", {
    Name = "Subtitle",
    Position = UDim2.fromOffset(48, 22),
    Size = UDim2.new(1, -145, 0, 14),
    BackgroundTransparency = 1,
    Font = Theme.FontRegular,
    Text = string.format("%s  •  by %s", Theme.TargetGame, Theme.Developer),
    TextSize = 10,
    TextColor3 = Theme.TextMuted,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = titleBar,
})

local function createHeaderActionBtn(name, symbol, offsetX, hoverCol)
    local btn = Core.Create("TextButton", {
        Name = name,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(30, 26),
        BackgroundColor3 = Theme.CardElevated,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = symbol,
        TextSize = 15,
        TextColor3 = Theme.TextPrimary,
        Parent = titleBar,
    })
    Core.Corner(btn, 7)
    Core.Stroke(btn, Theme.BorderGlow, 1, 0.55)
    Animations.BindButtonFeedback(janitor, btn, Theme.CardElevated, hoverCol, Theme.Obsidian)
    return btn
end

local minimizeBtn = createHeaderActionBtn("MinimizeBtn", "–", -44, Theme.NeonViolet)
local closeBtn = createHeaderActionBtn("CloseBtn", "×", -10, Theme.Danger)

-- BODY CONTAINER
local bodyFrame = Core.Create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(0, WINDOW_SPECS.TitleBarHeight),
    Size = UDim2.new(1, 0, 1, -WINDOW_SPECS.TitleBarHeight),
    BackgroundTransparency = 1,
    ZIndex = 3,
    Parent = mainWindow,
})

-- SIDEBAR CONTAINER (Supports Slide-In Animation)
local sidebarHolder = Core.Create("Frame", {
    Name = "SidebarHolder",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(0, WINDOW_SPECS.Desktop.Sidebar, 1, 0),
    BackgroundColor3 = Theme.SidebarBg,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Parent = bodyFrame,
})

-- Vertical divider between sidebar and content
Core.Create("Frame", {
    Name = "SidebarDivider",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = Theme.BorderGlow,
    BackgroundTransparency = 0.65,
    BorderSizePixel = 0,
    Parent = sidebarHolder,
})

local sidebarScroll = Core.Create("ScrollingFrame", {
    Name = "NavScroll",
    Size = UDim2.new(1, 0, 1, -28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Parent = sidebarHolder,
})
Core.Padding(sidebarScroll, 10, 8, 8, 8)
Core.Create("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = sidebarScroll,
})

Core.Create("TextLabel", {
    Name = "FooterVersion",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
    Font = Theme.FontMedium,
    Text = string.format("%s  •  RyuzenX", Theme.Version),
    TextSize = 10,
    TextColor3 = Theme.TextMuted,
    Parent = sidebarHolder,
})

-- MAIN CONTENT VIEWPORT
local contentViewport = Core.Create("Frame", {
    Name = "ContentViewport",
    Position = UDim2.fromOffset(WINDOW_SPECS.Desktop.Sidebar, 0),
    Size = UDim2.new(1, -WINDOW_SPECS.Desktop.Sidebar, 1, 0),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = bodyFrame,
})

-- FLOATING REOPEN LOGO BUTTON (With Pulse Animation & Futuristic 'A')
local floatingAnchor = Core.Create("Frame", {
    Name = "FloatingLogoButton",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(46, 130),
    Size = UDim2.fromOffset(48, 48),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 40,
    Parent = screenGui,
})

local floatingScale = Core.Create("UIScale", {
    Scale = 0,
    Parent = floatingAnchor,
})

local pulseRing = Core.Create("Frame", {
    Name = "PulseHalo",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 4, 1, 4),
    BackgroundColor3 = Theme.NeonViolet,
    BackgroundTransparency = 0.65,
    BorderSizePixel = 0,
    Parent = floatingAnchor,
})
Core.Corner(pulseRing, 16)

local floatingLogo = Components.CreateFuturisticLogoA(floatingAnchor, 46)
floatingLogo.AnchorPoint = Vector2.new(0.5, 0.5)
floatingLogo.Position = UDim2.fromScale(0.5, 0.5)

Animations.StartPulse(janitor, pulseRing, function()
    return HubState.minimized and not HubState.destroyed
end)

-- RESPONSIVE LAYOUT & WINDOW LIFECYCLE
local animSequence = 0
local activeSidebarWidth = WINDOW_SPECS.Desktop.Sidebar

local function resolveMobileMode()
    if HubState.layoutMode == "Mobile" then
        return true
    elseif HubState.layoutMode == "Desktop" then
        return false
    end
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function applyResponsiveLayout()
    if HubState.destroyed then
        return
    end
    local viewport = Core.GetViewport(screenGui)
    local profile = resolveMobileMode() and WINDOW_SPECS.Mobile or WINDOW_SPECS.Desktop
    local safeBounds = viewport / HubState.uiScale

    local w = math.max(math.min(profile.Width, safeBounds.X * 0.94), WINDOW_SPECS.MinSize.X)
    local h = math.max(math.min(profile.Height, safeBounds.Y * 0.86), WINDOW_SPECS.MinSize.Y)
    activeSidebarWidth = (w < 510) and WINDOW_SPECS.Mobile.Sidebar or WINDOW_SPECS.Desktop.Sidebar

    local scaledSize = Vector2.new(math.floor(w * HubState.uiScale), math.floor(h * HubState.uiScale))
    rootAnchor.Size = UDim2.fromOffset(scaledSize.X, scaledSize.Y)
    mainWindow.Size = UDim2.fromOffset(math.floor(w), math.floor(h))

    sidebarHolder.Size = UDim2.new(0, activeSidebarWidth, 1, 0)
    contentViewport.Position = UDim2.fromOffset(activeSidebarWidth, 0)
    contentViewport.Size = UDim2.new(1, -activeSidebarWidth, 1, 0)

    local currentCenter = Vector2.new(rootAnchor.Position.X.Offset, rootAnchor.Position.Y.Offset)
    local clampedCenter = Core.ClampPosition(currentCenter, scaledSize, viewport)
    rootAnchor.Position = UDim2.fromOffset(clampedCenter.X, clampedCenter.Y)

    local floatPos = Vector2.new(floatingAnchor.Position.X.Offset, floatingAnchor.Position.Y.Offset)
    local clampedFloat = Core.ClampPosition(floatPos, Vector2.new(52, 52), viewport)
    floatingAnchor.Position = UDim2.fromOffset(clampedFloat.X, clampedFloat.Y)

    if not HubState.minimized and not HubState.closing then
        windowScale.Scale = HubState.uiScale
    end
end

janitor:AddConnection(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout))

local function playOpenAnimation()
    animSequence += 1
    rootAnchor.Visible = true
    mainWindow.GroupTransparency = 1
    windowScale.Scale = HubState.uiScale * 0.86

    -- Sidebar Slide-In effect
    sidebarHolder.Position = UDim2.fromOffset(-24, 0)
    Animations.Play(sidebarHolder, 0.34, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    -- Main Window Fade + Scale
    Animations.Play(mainWindow, 0.3, { GroupTransparency = HubState.glassTransparency }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Animations.Play(windowScale, 0.38, { Scale = HubState.uiScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function playCloseAnimation()
    animSequence += 1
    Animations.Play(mainWindow, 0.22, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Animations.Play(windowScale, 0.22, { Scale = HubState.uiScale * 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    return 0.22
end

function ArcXHub:Minimize()
    if HubState.destroyed or HubState.closing or HubState.minimized then
        return
    end
    HubState.minimized = true
    local dur = playCloseAnimation()
    local token = animSequence
    task.delay(dur, function()
        if HubState.destroyed or token ~= animSequence or not HubState.minimized then
            return
        end
        rootAnchor.Visible = false
        floatingAnchor.Visible = true
        floatingScale.Scale = 0.2
        Animations.Play(floatingScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
end

function ArcXHub:Restore()
    if HubState.destroyed or HubState.closing or not HubState.minimized then
        return
    end
    HubState.minimized = false
    animSequence += 1
    local token = animSequence
    Animations.Play(floatingScale, 0.16, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.16, function()
        if HubState.destroyed or token ~= animSequence then
            return
        end
        floatingAnchor.Visible = false
    end)
    applyResponsiveLayout()
    playOpenAnimation()
end

function ArcXHub:ToggleVisibility()
    if HubState.minimized then
        self:Restore()
    else
        self:Minimize()
    end
end

function ArcXHub:Close()
    if HubState.destroyed or HubState.closing then
        return
    end
    HubState.closing = true
    if HubState.minimized then
        self:Destroy()
        return
    end
    local dur = playCloseAnimation()
    task.delay(dur + 0.03, function()
        self:Destroy()
    end)
end

function ArcXHub:Destroy()
    if HubState.destroyed then
        return
    end
    HubState.destroyed = true
    janitor:Cleanup()
    if GlobalStore.ArcXHubInstance == self then
        GlobalStore.ArcXHubInstance = nil
    end
end

-- Bind Dragging & Titlebar Actions
Core.MakeDraggable(janitor, titleBar, rootAnchor, screenGui, { ExcludeRightPx = 84 })
Core.MakeDraggable(janitor, floatingLogo, floatingAnchor, screenGui, {
    OnTap = function()
        ArcXHub:Restore()
    end,
})

janitor:AddConnection(minimizeBtn.Activated:Connect(function()
    ArcXHub:Minimize()
end))

janitor:AddConnection(closeBtn.Activated:Connect(function()
    ArcXHub:Close()
end))

janitor:AddConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or HubState.destroyed then
        return
    end
    if input.KeyCode == HubState.toggleKey then
        ArcXHub:ToggleVisibility()
    end
end))

-- INITIALIZE NAVIGATION & 8 TABS
local nav = Navigation.new(janitor, sidebarScroll, contentViewport)

local TAB_DEFINITIONS = {
    { Id = "Home", Title = "Home", Glyph = "H" },
    { Id = "MainFarm", Title = "Main Farm", Glyph = "F" },
    { Id = "Upgrade", Title = "Upgrade", Glyph = "U" },
    { Id = "AutoSell", Title = "Auto Sell", Glyph = "S" },
    { Id = "ItemBoost", Title = "Item Boost", Glyph = "B" },
    { Id = "SeedManager", Title = "Seed Manager", Glyph = "M" },
    { Id = "RemoteInspector", Title = "Remote Inspector", Glyph = "R" },
    { Id = "Settings", Title = "Settings", Glyph = "⚙" },
}

for _, def in ipairs(TAB_DEFINITIONS) do
    nav:AddTab(def)
end

--------------------------------------------------------------------------------
-- BUILD TAB 1: HOME DASHBOARD
--------------------------------------------------------------------------------
do
    local page = nav._tabs["Home"].Scroll
    Components.CreatePageHeader(
        page,
        "Welcome to ArcXHub",
        "Command center untuk Throw a Seed. Seluruh kontrol pada fase ini berjalan secara lokal dengan simulasi data aman.",
        "ONLINE"
    )

    -- Status & Rotating Sync Indicator Card
    local statusCard = Components.CreateSection(page, "Hub Telemetry & Status", 1)
    local syncRow = Core.Create("Frame", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = statusCard,
    })
    Core.Corner(syncRow, 7)

    local spinner = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        Parent = syncRow,
    })
    local spinRing = Core.Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.ElectricPurple,
        BorderSizePixel = 0,
        Parent = spinner,
    })
    Core.Corner(spinRing, 3)
    Animations.StartSpinner(janitor, spinner, function()
        return HubState.minimized or HubState.destroyed
    end)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(1, -38, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = "UI Engine Active  •  Animation & Event Guard Running",
        TextSize = 11,
        TextColor3 = Theme.Success,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = syncRow,
    })

    -- Pembacaan aman attribute pemain jika tersedia, atau fallback ke mock data
    local function readSafeStat(attrName, fallback)
        local val = LocalPlayer:GetAttribute(attrName)
        return val ~= nil and tostring(val) or fallback
    end

    local setUser = Components.CreateInfoRow(statusCard, "Developer / User", string.format("%s (@%s)", Theme.Developer, LocalPlayer.Name), Theme.ElectricPurple, 2)
    local setEnv = Components.CreateInfoRow(statusCard, "Environment Mode", resolveMobileMode() and "Mobile Touch (Android)" or "Desktop (PC)", Theme.TextPrimary, 3)
    local setUptime = Components.CreateInfoRow(statusCard, "Session Uptime", "00:00", Theme.Info, 4)

    -- Mock Game Overview Card
    local gameCard = Components.CreateSection(page, "Throw a Seed — Session Overview (Mock / Read-Only)", 2)
    local setCoins = Components.CreateInfoRow(gameCard, "Money (Attribute / Mock)", "$" .. readSafeStat("Money", "12,500 [Mock]"), Theme.Warning, 1)
    local setStrength = Components.CreateInfoRow(gameCard, "Strength", readSafeStat("Strength", "450 [Mock]"), Theme.TextPrimary, 2)
    local setSlots = Components.CreateInfoRow(gameCard, "Garden Capacity", readSafeStat("Placed", "3") .. " / " .. readSafeStat("Capacity", "6"), Theme.Success, 3)
    local setFarmStatus = Components.CreateInfoRow(gameCard, "Local Farm Preview", "IDLE", Theme.TextMuted, 4)

    -- Quick Actions Card
    local quickCard = Components.CreateSection(page, "Quick Actions & Shortcuts", 3)
    Components.CreateButton(janitor, quickCard, "Test Notification Toast", function()
        notifier:Push("ArcXHub System", "Notifikasi animasi Slide-In & Fade-Out berjalan normal!", "success", 3)
    end, { Order = 1 })

    Components.CreateButton(janitor, quickCard, "Open Main Farm Tab", function()
        nav:Select("MainFarm")
    end, { Order = 2, Color = Theme.CardElevated })

    Components.CreateButton(janitor, quickCard, "Open Configuration Settings", function()
        nav:Select("Settings")
    end, { Order = 3, Color = Theme.CardElevated })

    -- Live Uptime & Safe Attribute Refresher (Throttled 1s, tidak membebani RenderStepped)
    janitor:AddThread(task.spawn(function()
        while not HubState.destroyed do
            if not HubState.minimized then
                local elapsed = math.floor(os.clock() - HubState.sessionStart)
                local mins = math.floor(elapsed / 60)
                local secs = elapsed % 60
                setUptime(string.format("%02d:%02d", mins, secs))
                setEnv(resolveMobileMode() and "Mobile Touch (Android)" or "Desktop (PC)")
                setCoins("$" .. readSafeStat("Money", "12,500 [Mock]"))
                setStrength(readSafeStat("Strength", "450 [Mock]"))
                setSlots(readSafeStat("Placed", "3") .. " / " .. readSafeStat("Capacity", "6"))
                setFarmStatus(
                    HubState.localFarmActive and "RUNNING (LOCAL PREVIEW)" or "IDLE",
                    HubState.localFarmActive and Theme.Success or Theme.TextMuted
                )
            end
            task.wait(1)
        end
    end))
end

--------------------------------------------------------------------------------
-- BUILD TAB 2: MAIN FARM (LOCAL INTERACTIVE CONTROLLER)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["MainFarm"].Scroll
    Components.CreatePageHeader(
        page,
        "Main Farm Controller",
        "Konfigurasi parameter lemparan dan siklus latihan lokal. Tidak mengirim panggilan Remote ke server publik.",
        "LOCAL UI"
    )

    local ctrlCard = Components.CreateSection(page, "Automation Parameters", 1)
    local setStateLabel = Components.CreateInfoRow(ctrlCard, "Controller Status", "STOPPED", Theme.Danger, 1)

    Components.CreateToggle(janitor, ctrlCard, "Local Simulation Mode", "Mengaktifkan penghitung siklus lokal untuk pengujian UI", false, function(on)
        HubState.localFarmActive = on
        setStateLabel(on and "ACTIVE (SIMULATION)" or "STOPPED", on and Theme.Success or Theme.Danger)
        notifier:Push("Main Farm", on and "Simulasi lokal diaktifkan." or "Simulasi lokal dihentikan.", on and "info" or "warning", 2.5)
    end, 2)

    Components.CreateSlider(janitor, ctrlCard, "Target Throw Power", 0.10, 1.00, HubState.localFarmPower, 0.02, "", function(val)
        HubState.localFarmPower = val
    end, 3)

    Components.CreateSlider(janitor, ctrlCard, "Throws Per Turn", 1, 20, HubState.localFarmThrows, 1, "x", function(val)
        HubState.localFarmThrows = val
    end, 4)

    Components.CreateDropdown(janitor, ctrlCard, "Training Preset", { "Balanced", "High Strength", "Quick Cycle" }, HubState.localFarmMode, function(opt)
        HubState.localFarmMode = opt
        notifier:Push("Preset Updated", "Mode latihan diubah ke: " .. tostring(opt), "info", 2)
    end, 5)
end

--------------------------------------------------------------------------------
-- BUILD TAB 3: UPGRADE (MOCK DATA + INTERACTIVE PREVIEW)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["Upgrade"].Scroll
    Components.CreatePageHeader(
        page,
        "Upgrade Planner",
        "Perencanaan prioritas peningkatan atribut pemain menggunakan data mock lokal.",
        "MOCK DATA"
    )

    local mockUpgrades = {
        { Name = "Throw Strength", Level = 14, NextCost = "$2,400 [Mock]" },
        { Name = "Garden Capacity", Level = 6, NextCost = "$5,000 [Mock]" },
        { Name = "Training Multiplier", Level = 9, NextCost = "$3,750 [Mock]" },
    }

    for idx, upg in ipairs(mockUpgrades) do
        local card = Components.CreateSection(page, upg.Name, idx)
        local currentLvl = upg.Level
        local setLvl = Components.CreateInfoRow(card, "Current Level", "Lv. " .. tostring(currentLvl), Theme.ElectricPurple, 1)
        Components.CreateInfoRow(card, "Estimated Cost", upg.NextCost, Theme.Warning, 2)
        Components.CreateButton(janitor, card, "Simulate Plan Increment (+1 Lv)", function()
            currentLvl += 1
            setLvl("Lv. " .. tostring(currentLvl) .. " (Planned)")
            notifier:Push("Upgrade Planner", upg.Name .. " direncanakan ke Lv. " .. tostring(currentLvl), "info", 2.2)
        end, { Order = 3 })
    end
end

--------------------------------------------------------------------------------
-- BUILD TAB 4: AUTO SELL (FILTER & DRY-RUN PREVIEW)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["AutoSell"].Scroll
    Components.CreatePageHeader(
        page,
        "Auto Sell Filter",
        "Atur filter kelangkaan dan ambang kapasitas sebelum menjalankan simulasi penjualan.",
        "PREVIEW"
    )

    local sellCard = Components.CreateSection(page, "Filter Configuration", 1)
    Components.CreateToggle(janitor, sellCard, "Dry-Run Simulation Mode", "Pratinjau daftar item tanpa eksekusi transaksi", true, function(on)
        HubState.localSellPreview = on
    end, 1)

    Components.CreateDropdown(janitor, sellCard, "Max Rarity to Sell", { "Common", "Uncommon", "Rare", "Epic" }, HubState.localSellMinRarity, function(opt)
        HubState.localSellMinRarity = opt
    end, 2)

    Components.CreateSlider(janitor, sellCard, "Storage Trigger Threshold", 20, 100, HubState.localSellThreshold, 5, "%", function(val)
        HubState.localSellThreshold = val
    end, 3)

    Components.CreateButton(janitor, sellCard, "Run Local Filter Preview", function()
        notifier:Push(
            "Sell Preview",
            string.format("Filter aktif: <= %s pada kapasitas %d%% (Mock: 2 item cocok).", HubState.localSellMinRarity, HubState.localSellThreshold),
            "success",
            3
        )
    end, { Order = 4 })
end

--------------------------------------------------------------------------------
-- BUILD TAB 5: ITEM BOOST (MOCK INVENTORY & REMINDER)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["ItemBoost"].Scroll
    Components.CreatePageHeader(
        page,
        "Item Boost Monitor",
        "Pemantauan durasi boost dan pengingat lokal sebelum efek boost berakhir.",
        "MONITOR"
    )

    local boostCard = Components.CreateSection(page, "Active & Mock Boosts", 1)
    Components.CreateInfoRow(boostCard, "2x XP Boost", "14m 20s [Mock]", Theme.Success, 1)
    Components.CreateInfoRow(boostCard, "2x Luck Boost", "Inactive", Theme.TextMuted, 2)
    Components.CreateInfoRow(boostCard, "2x Money Boost", "Inactive", Theme.TextMuted, 3)

    Components.CreateSlider(janitor, boostCard, "Expiry Reminder Alert", 5, 120, HubState.localBoostReminder, 5, "s", function(val)
        HubState.localBoostReminder = val
    end, 4)
end

--------------------------------------------------------------------------------
-- BUILD TAB 6: SEED MANAGER (SEARCHABLE DATABASE)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["SeedManager"].Scroll
    Components.CreatePageHeader(
        page,
        "Seed Database & Inspector",
        "Pencarian daftar model seed Throw a Seed yang telah terverifikasi di client.",
        "14 SEEDS"
    )

    local SEEDS_DB = {
        { Name = "CloudSeed", Rarity = "Special", Note = "PrimaryPart: Root | BaseSize: 2.599" },
        { Name = "CosmicSeed", Rarity = "Cosmic", Note = "Model terdaftar di SeedModels" },
        { Name = "CrystalSeed", Rarity = "Rare", Note = "Model terdaftar di SeedModels" },
        { Name = "DiamondSeed", Rarity = "Legendary", Note = "Model terdaftar di SeedModels" },
        { Name = "GoldenSeed", Rarity = "Epic", Note = "Model terdaftar di SeedModels" },
        { Name = "RainbowSeed", Rarity = "Mythic", Note = "Model terdaftar di SeedModels" },
        { Name = "StarSeed", Rarity = "Celestial", Note = "Model terdaftar di SeedModels" },
        { Name = "CandySeed", Rarity = "Uncommon", Note = "Model terdaftar di SeedModels" },
        { Name = "LavaSeed", Rarity = "Epic", Note = "Model terdaftar di SeedModels" },
        { Name = "LuckySeed", Rarity = "Special", Note = "Model terdaftar di SeedModels" },
        { Name = "MagicSeed", Rarity = "Rare", Note = "Model terdaftar di SeedModels" },
        { Name = "PearlSeed", Rarity = "Rare", Note = "Model terdaftar di SeedModels" },
        { Name = "PlainSeed", Rarity = "Common", Note = "Model terdaftar di SeedModels" },
        { Name = "SunnySeed", Rarity = "Uncommon", Note = "Model terdaftar di SeedModels" },
    }

    local dbCard = Components.CreateSection(page, "Search & Selection", 1)
    local selectedLabel = Components.CreateInfoRow(dbCard, "Selected Seed", HubState.selectedSeed, Theme.ElectricPurple, 2)
    local detailLabel = Components.CreateInfoRow(dbCard, "Verification Note", SEEDS_DB[1].Note, Theme.TextSecondary, 3)

    local listHolder = Core.Create("Frame", {
        Name = "SeedList",
        LayoutOrder = 4,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = dbCard,
    })
    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listHolder,
    })

    local function renderSeedList(filterText)
        for _, child in ipairs(listHolder:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local q = string.lower(filterText or "")
        local count = 0
        for _, item in ipairs(SEEDS_DB) do
            if q == "" or string.find(string.lower(item.Name), q, 1, true) then
                count += 1
                local rowBtn = Core.Create("TextButton", {
                    LayoutOrder = count,
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = Theme.CardElevated,
                    AutoButtonColor = false,
                    Font = Theme.FontMedium,
                    Text = string.format("  %s  (%s)", item.Name, item.Rarity),
                    TextSize = 12,
                    TextColor3 = Theme.TextPrimary,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = listHolder,
                })
                Core.Corner(rowBtn, 6)
                Animations.BindButtonFeedback(janitor, rowBtn, Theme.CardElevated, Theme.DeepViolet, Theme.NeonViolet)

                janitor:AddConnection(rowBtn.Activated:Connect(function()
                    HubState.selectedSeed = item.Name
                    selectedLabel(item.Name)
                    detailLabel(item.Note)
                end))
            end
        end
    end

    Components.CreateTextInput(janitor, dbCard, "Cari nama seed (mis. CloudSeed)...", "", function(text)
        renderSeedList(text)
    end, 1)

    renderSeedList("")
end

--------------------------------------------------------------------------------
-- BUILD TAB 7: REMOTE INSPECTOR (READ-ONLY DOCUMENTATION VIEWER)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["RemoteInspector"].Scroll
    Components.CreatePageHeader(
        page,
        "Remote Inspector (Read-Only)",
        "Dokumentasi observasi struktur client tanpa menjalankan pemanggilan Remote ke server.",
        "READ-ONLY"
    )

    local REMOTE_DOCS = {
        { Name = "SeedModels", Class = "Folder", Status = "VERIFIED", Sig = "Container 14 Model Seed di client" },
        { Name = "Aim", Class = "RemoteEvent", Status = "OBSERVED", Sig = "Aim:FireServer() — Fase mulai membidik" },
        { Name = "Throw", Class = "RemoteFunction", Status = "OBSERVED", Sig = "Throw:InvokeServer(power: number)" },
        { Name = "Collect", Class = "RemoteEvent", Status = "OBSERVED", Sig = "Collect:FireServer() — Klaim hasil lemparan" },
        { Name = "Track", Class = "RemoteEvent", Status = "OBSERVED", Sig = 'Track:FireServer("MenuBoxShop" | "MenuSell")' },
        { Name = "Request", Class = "RemoteFunction", Status = "OBSERVED", Sig = 'Request:InvokeServer(action: string, payload: table)' },
        { Name = "Notify", Class = "RemoteEvent", Status = "UNKNOWN", Sig = "Belum ada rekaman payload (Server -> Client)" },
        { Name = "Here", Class = "Unknown", Status = "UNKNOWN", Sig = "Terlihat di Dex Explorer, fungsi belum diketahui" },
        { Name = "GiveMoney", Class = "Restricted", Status = "UNKNOWN", Sig = "Endpoint terproteksi — dilarang dipanggil" },
        { Name = "AdminGiveSecret", Class = "Restricted", Status = "UNKNOWN", Sig = "Endpoint khusus admin — dilarang dipanggil" },
    }

    local docCard = Components.CreateSection(page, "Observed Endpoints Registry", 1)
    for idx, doc in ipairs(REMOTE_DOCS) do
        local badgeColor = Theme.Danger
        if doc.Status == "VERIFIED" then
            badgeColor = Theme.Success
        elseif doc.Status == "OBSERVED" then
            badgeColor = Theme.Warning
        end

        local row = Core.Create("Frame", {
            LayoutOrder = idx,
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = Theme.CardElevated,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Parent = docCard,
        })
        Core.Corner(row, 8)
        Core.Padding(row, 6, 10, 6, 10)

        Core.Create("TextLabel", {
            Size = UDim2.new(0.68, 0, 0, 16),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = string.format("%s  [%s]", doc.Name, doc.Class),
            TextSize = 12,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        Core.Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0.32, 0, 0, 16),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = doc.Status,
            TextSize = 11,
            TextColor3 = badgeColor,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })

        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(0, 18),
            Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = doc.Sig,
            TextSize = 11,
            TextColor3 = Theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
    end
end

--------------------------------------------------------------------------------
-- BUILD TAB 8: SETTINGS & CONFIGURATION PANEL
--------------------------------------------------------------------------------
do
    local page = nav._tabs["Settings"].Scroll
    Components.CreatePageHeader(
        page,
        "Interface & Config Settings",
        "Sesuaikan skala tampilan Android/PC, transparansi kaca, efek partikel, serta penyimpanan konfigurasi.",
        "CONFIG"
    )

    local visualCard = Components.CreateSection(page, "Visual & Responsiveness", 1)

    local scaleSlider = Components.CreateSlider(janitor, visualCard, "UI Scale", 0.65, 1.45, HubState.uiScale, 0.05, "x", function(val)
        HubState.uiScale = val
        applyResponsiveLayout()
    end, 1)

    local glassSlider = Components.CreateSlider(janitor, visualCard, "Glass Transparency", 0, 0.55, HubState.glassTransparency, 0.05, "", function(val)
        HubState.glassTransparency = val
        if not HubState.minimized and not HubState.closing then
            Animations.Play(mainWindow, 0.18, { GroupTransparency = val })
        end
    end, 2)

    local modeDropdown = Components.CreateDropdown(janitor, visualCard, "Layout Profile", { "Auto", "Mobile", "Desktop" }, HubState.layoutMode, function(opt)
        HubState.layoutMode = opt
        applyResponsiveLayout()
    end, 3)

    local particleToggle = Components.CreateToggle(janitor, visualCard, "Ambient Violet Particles", "Efek partikel bergerak halus di latar belakang", HubState.particlesEnabled, function(on)
        HubState.particlesEnabled = on
    end, 4)

    local notifToggle = Components.CreateToggle(janitor, visualCard, "Toast Notifications", "Tampilkan notifikasi pop-up saat ada perubahan", HubState.notificationsEnabled, function(on)
        HubState.notificationsEnabled = on
    end, 5)

    local keyDropdown = Components.CreateDropdown(janitor, visualCard, "PC Toggle Keybind", { "RightShift", "RightControl", "Insert", "K" }, HubState.toggleKey.Name, function(opt)
        if Enum.KeyCode[opt] then
            HubState.toggleKey = Enum.KeyCode[opt]
        end
    end, 6)

    local configCard = Components.CreateSection(page, "Configuration Storage", 2)
    Components.CreateButton(janitor, configCard, "Save Configuration", function()
        local ok, msg = SettingsManager.Save({
            uiScale = HubState.uiScale,
            glassTransparency = HubState.glassTransparency,
            layoutMode = HubState.layoutMode,
            particlesEnabled = HubState.particlesEnabled,
            notificationsEnabled = HubState.notificationsEnabled,
            toggleKeyName = HubState.toggleKey.Name,
        })
        notifier:Push("Configuration", msg, ok and "success" or "warning", 3)
    end, { Order = 1 })

    Components.CreateButton(janitor, configCard, "Reset to Default", function()
        HubState.uiScale = SettingsManager.Defaults.uiScale
        HubState.glassTransparency = SettingsManager.Defaults.glassTransparency
        HubState.layoutMode = SettingsManager.Defaults.layoutMode
        HubState.particlesEnabled = SettingsManager.Defaults.particlesEnabled
        HubState.notificationsEnabled = SettingsManager.Defaults.notificationsEnabled
        HubState.toggleKey = Enum.KeyCode.RightShift

        scaleSlider.Set(HubState.uiScale, true)
        glassSlider.Set(HubState.glassTransparency, true)
        modeDropdown.Set(HubState.layoutMode, true)
        particleToggle.Set(HubState.particlesEnabled, true)
        notifToggle.Set(HubState.notificationsEnabled, true)
        keyDropdown.Set("RightShift", true)

        applyResponsiveLayout()
        Animations.Play(mainWindow, 0.2, { GroupTransparency = HubState.glassTransparency })
        notifier:Push("Configuration", "Seluruh pengaturan dikembalikan ke nilai bawaan.", "info", 2.8)
    end, { Order = 2, Color = Theme.CardElevated })
end

--------------------------------------------------------------------------------
-- INITIALIZE & LAUNCH ARCXHUB
--------------------------------------------------------------------------------
applyResponsiveLayout()
nav:Select("Home")
playOpenAnimation()

task.delay(0.35, function()
    if not HubState.destroyed then
        notifier:Push("ArcXHub Loaded", "GUI Foundation v1.0.0 siap digunakan (Android & PC).", "success", 3.2)
    end
end)

GlobalStore.ArcXHubInstance = ArcXHub
return ArcXHub
