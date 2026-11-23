--[[
    ============================================================================
    ARCXHUB — NEON PURPLE GLASSMORPHISM EDITION (1:1 CONCEPT UI)
    ============================================================================
    Project     : ArcXHub
    Developer   : RyuzenX
    Target Game : Throw a Seed
    Environment : Roblox Luau (Delta Executor Android/PC & Roblox Studio)
    Version     : v1.0.0 (Exact Concept Layout + Modular Architecture)
    ============================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Anti-duplicate instance cleanup
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
        CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8),
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

function Core.CopyText(text)
    local ok = pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(tostring(text))
        elseif type(toclipboard) == "function" then
            toclipboard(tostring(text))
        else
            error("clipboard unavailable")
        end
    end)
    return ok
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
-- [2] THEME & OPTIONAL CUSTOM ASSET IDS
--------------------------------------------------------------------------------
local Theme = {
    Brand = "ArcXHub",
    Developer = "RyuzenX",
    TargetGame = "Throw a Seed",
    Version = "v1.0.0",
    DiscordInvite = "https://discord.gg/arcxhub",

    -- Optional rbxassetid:// overrides (leave "" to use built-in neon vector art)
    CustomAssets = {
        HeroAnimeBanner = "", -- e.g. "rbxassetid://YOUR_BANNER_ID"
        TreasureChest = "",   -- e.g. "rbxassetid://YOUR_CHEST_ID"
        GameThumbnail = "",   -- Leave "" to auto-load Throw a Seed GameIcon via rbxthumb
    },

    -- Core Neon Violet + Obsidian Glassmorphism Palette
    Obsidian = Color3.fromRGB(8, 6, 16),
    Background = Color3.fromRGB(13, 9, 25),
    SidebarBg = Color3.fromRGB(15, 10, 30),
    CardBg = Color3.fromRGB(20, 14, 39),
    CardInner = Color3.fromRGB(26, 18, 50),
    CardElevated = Color3.fromRGB(34, 24, 64),
    ControlTrack = Color3.fromRGB(42, 30, 76),

    -- Neon Violet & Magenta Glow Accents
    NeonViolet = Color3.fromRGB(168, 85, 247),
    ElectricPurple = Color3.fromRGB(216, 140, 255),
    MagentaGlow = Color3.fromRGB(217, 70, 239),
    DeepViolet = Color3.fromRGB(88, 38, 162),
    BorderGlow = Color3.fromRGB(138, 72, 219),
    DiscordBlurple = Color3.fromRGB(114, 137, 218),

    -- Status Colors
    Success = Color3.fromRGB(52, 211, 153),
    SuccessBg = Color3.fromRGB(16, 54, 42),
    Warning = Color3.fromRGB(251, 191, 36),
    Danger = Color3.fromRGB(244, 63, 94),
    Info = Color3.fromRGB(129, 140, 248),

    -- Typography
    TextPrimary = Color3.fromRGB(248, 244, 255),
    TextSecondary = Color3.fromRGB(186, 170, 219),
    TextMuted = Color3.fromRGB(128, 112, 164),

    FontBlack = Enum.Font.GothamBlack,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,
    FontRegular = Enum.Font.Gotham,
}

function Theme.ApplyGlassGradient(parent, rotation)
    return Core.Create("UIGradient", {
        Rotation = rotation or 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 20, 62)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 11, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 7, 20)),
        }),
        Parent = parent,
    })
end

function Theme.ApplyNeonGradient(parent, rotation)
    return Core.Create("UIGradient", {
        Rotation = rotation or 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.DeepViolet),
            ColorSequenceKeypoint.new(0.5, Theme.NeonViolet),
            ColorSequenceKeypoint.new(1, Theme.ElectricPurple),
        }),
        Parent = parent,
    })
end

function Theme.ApplyActiveTabGradient(parent)
    return Core.Create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(134, 54, 224)),
            ColorSequenceKeypoint.new(0.65, Color3.fromRGB(84, 34, 156)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 20, 92)),
        }),
        Parent = parent,
    })
end

--------------------------------------------------------------------------------
-- [3] VECTOR ICON ENGINE (CRISP PROCEDURAL ICONS MATCHING CONCEPT PNG)
--------------------------------------------------------------------------------
local Icons = {}

function Icons.Crown(parent, sizePx, color, rotation)
    sizePx = sizePx or 14
    color = color or Theme.ElectricPurple
    local root = Core.Create("Frame", {
        Name = "CrownIcon",
        Size = UDim2.fromOffset(sizePx, sizePx),
        BackgroundTransparency = 1,
        Rotation = rotation or 0,
        Parent = parent,
    })
    -- Base band
    local base = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.92, 0),
        Size = UDim2.new(0.84, 0, 0.24, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = root,
    })
    Core.Corner(base, 2)

    -- 3 Spikes
    local spikes = {
        { x = 0.2, h = 0.48, rot = -14 },
        { x = 0.5, h = 0.62, rot = 0 },
        { x = 0.8, h = 0.48, rot = 14 },
    }
    for _, s in ipairs(spikes) do
        local spike = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(s.x, 0.78),
            Size = UDim2.new(0.22, 0, s.h, 0),
            Rotation = s.rot,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = root,
        })
        Core.Corner(spike, 2)
    end
    return root
end

function Icons.Create(name, parent, sizePx, color)
    sizePx = sizePx or 16
    color = color or Theme.TextSecondary
    local holder = Core.Create("Frame", {
        Name = "Icon_" .. tostring(name),
        Size = UDim2.fromOffset(sizePx, sizePx),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    if name == "Home" then
        local roof = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.36),
            Size = UDim2.fromScale(0.54, 0.54),
            Rotation = 45,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(roof, 2)
        local body = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.9),
            Size = UDim2.fromScale(0.64, 0.48),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(body, 2)
    elseif name == "MainFarm" or name == "SeedManager" then
        local stem = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.92),
            Size = UDim2.new(0.14, 0, 0.62, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(stem, 2)
        local leafL = Core.Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.fromScale(0.5, 0.45),
            Size = UDim2.fromScale(0.4, 0.24),
            Rotation = -28,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(leafL, 4)
        local leafR = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0.5, 0.34),
            Size = UDim2.fromScale(0.42, 0.24),
            Rotation = 28,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(leafR, 4)
    elseif name == "Upgrade" then
        local head = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.36),
            Size = UDim2.fromScale(0.46, 0.46),
            Rotation = 45,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(head, 2)
        local shaft = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.92),
            Size = UDim2.fromScale(0.28, 0.56),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(shaft, 2)
    elseif name == "AutoSell" then
        local basket = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.54, 0.44),
            Size = UDim2.fromScale(0.64, 0.38),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(basket, 2)
        local handle = Core.Create("Frame", {
            Position = UDim2.fromScale(0.1, 0.2),
            Size = UDim2.fromScale(0.22, 0.14),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(handle, 2)
        for _, wx in ipairs({ 0.36, 0.72 }) do
            local wheel = Core.Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(wx, 0.8),
                Size = UDim2.fromScale(0.18, 0.18),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = holder,
            })
            Core.Corner(wheel, 1)
        end
    elseif name == "ItemBoost" then
        local box = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.92),
            Size = UDim2.fromScale(0.72, 0.52),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(box, 2)
        local lid = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0.24),
            Size = UDim2.fromScale(0.82, 0.18),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(lid, 2)
    elseif name == "RemoteInspector" then
        local lens = Core.Create("Frame", {
            Position = UDim2.fromScale(0.12, 0.12),
            Size = UDim2.fromScale(0.56, 0.56),
            BackgroundTransparency = 1,
            Parent = holder,
        })
        Core.Corner(lens, 1)
        Core.Stroke(lens, color, 1.8, 0)
        local stem = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.74, 0.74),
            Size = UDim2.fromScale(0.36, 0.16),
            Rotation = 45,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(stem, 2)
    elseif name == "Settings" then
        local outer = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.68, 0.68),
            BackgroundTransparency = 1,
            Parent = holder,
        })
        Core.Corner(outer, 1)
        Core.Stroke(outer, color, 2.2, 0)
        local dot = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.24, 0.24),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(dot, 1)
    elseif name == "Play" then
        Core.Create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = "▶",
            TextSize = math.floor(sizePx * 0.85),
            TextColor3 = color,
            Parent = holder,
        })
    elseif name == "Pin" then
        local head = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0.1),
            Size = UDim2.fromScale(0.58, 0.58),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(head, 1)
        local tip = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.66),
            Size = UDim2.fromScale(0.34, 0.34),
            Rotation = 45,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(tip, 2)
    elseif name == "Bolt" then
        Core.Create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = "⚡",
            TextSize = math.floor(sizePx * 0.9),
            TextColor3 = color,
            Parent = holder,
        })
    elseif name == "Gamepad" then
        local pad = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.84, 0.54),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(pad, 4)
    elseif name == "Pulse" then
        local bars = { 0.35, 0.85, 0.55, 0.95, 0.4 }
        for i, h in ipairs(bars) do
            local b = Core.Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.14 + (i - 1) * 0.18, 0.5),
                Size = UDim2.new(0.11, 0, h * 0.78, 0),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = holder,
            })
            Core.Corner(b, 2)
        end
    elseif name == "Chart" then
        local heights = { 0.42, 0.78, 0.58 }
        for i, h in ipairs(heights) do
            local bar = Core.Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.fromScale(0.24 + (i - 1) * 0.26, 0.88),
                Size = UDim2.new(0.18, 0, h, 0),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Parent = holder,
            })
            Core.Corner(bar, 2)
        end
    elseif name == "Clock" then
        local ring = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.82, 0.82),
            BackgroundTransparency = 1,
            Parent = holder,
        })
        Core.Corner(ring, 1)
        Core.Stroke(ring, color, 1.5, 0)
        Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.new(0.12, 0, 0.28, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
    elseif name == "Coin" then
        local coin = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.8, 0.8),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(coin, 1)
    elseif name == "Bell" then
        local dome = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0.14),
            Size = UDim2.fromScale(0.62, 0.56),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(dome, 5)
        local rim = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.78),
            Size = UDim2.fromScale(0.82, 0.16),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Parent = holder,
        })
        Core.Corner(rim, 2)
    end

    return holder
end

--------------------------------------------------------------------------------
-- [4] ANIMATIONS MODULE: ANTI-STACKING TWEEN ENGINE, PULSE, SPINNER & PARTICLES
--------------------------------------------------------------------------------
local Animations = {
    _activeTweens = setmetatable({}, { __mode = "k" }),
}

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

function Animations.StartPulse(janitor, pulseRing, isActiveFn)
    local thread = task.spawn(function()
        local expand = true
        while pulseRing and pulseRing.Parent do
            if not isActiveFn or isActiveFn() then
                if expand then
                    Animations.Play(pulseRing, 1.15, {
                        Size = UDim2.new(1, 18, 1, 18),
                        BackgroundTransparency = 0.88,
                    }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                else
                    Animations.Play(pulseRing, 1.15, {
                        Size = UDim2.new(1, 4, 1, 4),
                        BackgroundTransparency = 0.52,
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

    for i = 1, (count or 16) do
        local sizePx = rng:NextInteger(3, 6)
        local dot = Core.Create("Frame", {
            Name = "Particle_" .. tostring(i),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.08, 0.92)),
            Size = UDim2.fromOffset(sizePx, sizePx),
            BackgroundColor3 = (i % 2 == 0) and Theme.ElectricPurple or Theme.NeonViolet,
            BackgroundTransparency = rng:NextNumber(0.65, 0.88),
            BorderSizePixel = 0,
            ZIndex = 1,
            Parent = layer,
        })
        Core.Corner(dot, 1)
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
                        local nextAlpha = rng:NextNumber(0.62, 0.88)
                        local dur = rng:NextNumber(3.2, 5.4)
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
-- [5] NOTIFICATIONS MODULE: SLIDE IN / FADE OUT TOAST SYSTEM
--------------------------------------------------------------------------------
local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(janitor, screenGui, stateRef, onStatusUpdate)
    local self = setmetatable({
        _janitor = janitor,
        _state = stateRef,
        _onStatusUpdate = onStatusUpdate,
        _count = 0,
    }, Notifications)

    self._holder = Core.Create("Frame", {
        Name = "NotificationStack",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.new(0, 265, 0, 220),
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
    if type(self._onStatusUpdate) == "function" then
        pcall(self._onStatusUpdate, tostring(message or title))
    end
    if self._state and not self._state.notificationsEnabled then
        return
    end
    duration = duration or 3.0
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
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
        Parent = self._holder,
    })

    local card = Core.Create("CanvasGroup", {
        Name = "ToastCard",
        Position = UDim2.fromOffset(290, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        GroupTransparency = 0.05,
        Parent = wrapper,
    })
    Core.Corner(card, 10)
    Core.Stroke(card, accentColor, 1.2, 0.25)

    Core.Create("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
    })

    local badge = Core.Create("TextLabel", {
        Position = UDim2.fromOffset(12, 7),
        Size = UDim2.fromOffset(40, 15),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.82,
        Font = Theme.FontBold,
        Text = badgeText,
        TextSize = 9,
        TextColor3 = accentColor,
        Parent = card,
    })
    Core.Corner(badge, 4)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(58, 6),
        Size = UDim2.new(1, -66, 0, 17),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(title or "ArcXHub"),
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = card,
    })

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(12, 25),
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

    local timerBar = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
    })

    Animations.Play(card, 0.26, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Animations.Play(timerBar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    task.delay(duration, function()
        if not wrapper or not wrapper.Parent then
            return
        end
        Animations.Play(card, 0.22, {
            GroupTransparency = 1,
            Position = UDim2.fromOffset(55, 0),
        }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.24, function()
            if wrapper and wrapper.Parent then
                wrapper:Destroy()
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- [6] COMPONENTS MODULE: FUTURISTIC 'A' EMBLEM & CONTROLS
--------------------------------------------------------------------------------
local Components = {}

function Components.CreateFuturisticLogoA(parent, sizePx, circular)
    sizePx = sizePx or 34
    local emblem = Core.Create("Frame", {
        Name = "ArcXLogoA",
        Size = UDim2.fromOffset(sizePx, sizePx),
        BackgroundColor3 = Theme.Obsidian,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(emblem, circular and UDim.new(1, 0) or UDim.new(0, math.floor(sizePx * 0.28)))
    Core.Stroke(emblem, Theme.ElectricPurple, 1.6, 0.1)
    Theme.ApplyGlassGradient(emblem, 135)

    local canvas = Core.Create("Frame", {
        Name = "VectorCanvas",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.7, 0.7),
        BackgroundTransparency = 1,
        Parent = emblem,
    })

    local leftLeg = Core.Create("Frame", {
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

    local rightLeg = Core.Create("Frame", {
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

    local crossCore = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.63),
        Size = UDim2.new(0.56, 0, 0.13, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = canvas,
    })
    Core.Corner(crossCore, 2)

    local apex = Core.Create("Frame", {
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
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(headerCard, 12)
    Core.Stroke(headerCard, Theme.BorderGlow, 1, 0.4)
    Core.Padding(headerCard, 11, 14, 11, 14)

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
        TextSize = 16,
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
            BackgroundTransparency = 0.3,
            Font = Theme.FontBold,
            Text = badgeText,
            TextSize = 10,
            TextColor3 = Theme.ElectricPurple,
            Parent = topRow,
        })
        Core.Corner(pill, 6)
        Core.Stroke(pill, Theme.NeonViolet, 1, 0.35)
    end

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(0, 24),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = subtitle,
        TextSize = 11,
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
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(card, 11)
    Core.Stroke(card, Theme.BorderGlow, 1, 0.5)
    Core.Padding(card, 10, 12, 10, 12)

    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })

    if title then
        Core.Create("TextLabel", {
            Name = "SectionTitle",
            LayoutOrder = 0,
            Size = UDim2.new(1, 0, 0, 16),
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
        Size = UDim2.new(0.55, 0, 1, 0),
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
        Size = UDim2.new(0.45, 0, 1, 0),
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
        Size = options.Size or UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = baseColor,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = text,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        Parent = parent,
    })
    Core.Corner(btn, 8)
    Core.Stroke(btn, Theme.ElectricPurple, 1, 0.5)

    Animations.BindButtonFeedback(janitor, btn, baseColor, hoverColor, Theme.Obsidian)

    janitor:AddConnection(btn.Activated:Connect(function()
        if type(onClick) == "function" then
            pcall(onClick)
        end
    end))

    return btn
end

function Components.CreateToggle(janitor, parent, labelText, descText, defaultState, onChanged, order)
    local state = defaultState == true

    local holder = Core.Create("Frame", {
        Name = "ToggleControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, descText and 44 or 32),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.32,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(holder, 8)
    Core.Padding(holder, 6, 10, 6, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(0, descText and 1 or 3),
        Size = UDim2.new(1, -56, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        Text = labelText,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = holder,
    })

    if descText then
        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(0, 17),
            Size = UDim2.new(1, -56, 0, 14),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = descText,
            TextSize = 10,
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
        Size = UDim2.fromOffset(42, 20),
        BackgroundColor3 = state and Theme.NeonViolet or Theme.ControlTrack,
        AutoButtonColor = false,
        Text = "",
        Parent = holder,
    })
    Core.Corner(switchTrack, 1)
    local trackStroke = Core.Stroke(switchTrack, state and Theme.ElectricPurple or Theme.BorderGlow, 1, 0.25)

    local knob = Core.Create("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = switchTrack,
    })
    Core.Corner(knob, 1)

    local function setState(newVal, silent)
        state = newVal == true
        Animations.Play(switchTrack, 0.2, {
            BackgroundColor3 = state and Theme.NeonViolet or Theme.ControlTrack,
        })
        Animations.Play(trackStroke, 0.2, {
            Color = state and Theme.ElectricPurple or Theme.BorderGlow,
        })
        Animations.Play(knob, 0.22, {
            Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
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

function Components.CreateSlider(janitor, parent, labelText, minVal, maxVal, defaultVal, step, suffix, onChanged, order)
    minVal = minVal or 0
    maxVal = maxVal or 100
    step = step or 1
    suffix = suffix or ""
    local currentVal = math.clamp(defaultVal or minVal, minVal, maxVal)

    local holder = Core.Create("Frame", {
        Name = "SliderControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.32,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(holder, 8)
    Core.Padding(holder, 6, 10, 7, 10)

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
        Position = UDim2.fromOffset(0, 20),
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
    Core.Corner(track, 1)

    local initialRatio = (maxVal > minVal) and ((currentVal - minVal) / (maxVal - minVal)) or 0
    local fill = Core.Create("Frame", {
        Size = UDim2.fromScale(initialRatio, 1),
        BackgroundColor3 = Theme.NeonViolet,
        BorderSizePixel = 0,
        Parent = track,
    })
    Core.Corner(fill, 1)

    local thumb = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(initialRatio, 0.5),
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        Parent = track,
    })
    Core.Corner(thumb, 1)
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

function Components.CreateDropdown(janitor, parent, labelText, optionsList, defaultOption, onSelect, order)
    optionsList = optionsList or { "Option 1" }
    local selected = defaultOption or optionsList[1]
    local expanded = false

    local wrapper = Core.Create("Frame", {
        Name = "DropdownControl",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 34),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.CardElevated,
        BackgroundTransparency = 0.32,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Core.Corner(wrapper, 8)
    Core.Padding(wrapper, 6, 10, 6, 10)

    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = wrapper,
    })

    local headerBtn = Core.Create("TextButton", {
        Name = "Header",
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 22),
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
            Size = UDim2.new(1, 0, 0, 25),
            BackgroundColor3 = Theme.Background,
            AutoButtonColor = false,
            Font = Theme.FontMedium,
            Text = tostring(opt),
            TextSize = 11,
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

function Components.CreateTextInput(janitor, parent, placeholder, defaultText, onChanged, order)
    local holder = Core.Create("Frame", {
        Name = "InputHolder",
        LayoutOrder = order or 1,
        Size = UDim2.new(1, 0, 0, 32),
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
        Size = UDim2.new(1, -38, 1, 0),
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
        Size = UDim2.fromOffset(20, 20),
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
-- [7] NAVIGATION MODULE: GLOWING SIDEBAR & SMOOTH FADE TAB CONTROLLER
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
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.DeepViolet,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = self._sidebar,
    })
    Core.Corner(btn, 8)
    local btnStroke = Core.Stroke(btn, Theme.ElectricPurple, 1.2, 1)

    local activeGrad = Theme.ApplyActiveTabGradient(btn)
    activeGrad.Enabled = false

    local iconHolder = Core.Create("Frame", {
        Name = "IconSlot",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Parent = btn,
    })
    Icons.Create(id, iconHolder, 15, Theme.ElectricPurple)

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
    Core.Padding(scroll, 10, 12, 12, 10)
    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })

    local tabObj = {
        Id = id,
        Title = def.Title,
        Button = btn,
        Stroke = btnStroke,
        Gradient = activeGrad,
        IconHolder = iconHolder,
        Label = label,
        Page = page,
        Scroll = scroll,
    }

    self._janitor:AddConnection(btn.MouseEnter:Connect(function()
        if self._activeId ~= id then
            Animations.Play(btn, 0.15, { BackgroundTransparency = 0.65 })
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
        prevTab.Gradient.Enabled = false
        Animations.Play(prevTab.Button, 0.16, { BackgroundTransparency = 1 })
        Animations.Play(prevTab.Stroke, 0.16, { Transparency = 1 })
        prevTab.Label.Font = Theme.FontMedium
        prevTab.Label.TextColor3 = Theme.TextSecondary
    end

    self._activeId = id
    nextTab.Gradient.Enabled = true
    nextTab.Button.BackgroundColor3 = Color3.new(1, 1, 1)
    Animations.Play(nextTab.Button, 0.18, { BackgroundTransparency = 0.12 })
    Animations.Play(nextTab.Stroke, 0.18, { Transparency = 0.15 })
    nextTab.Label.Font = Theme.FontBold
    nextTab.Label.TextColor3 = Theme.TextPrimary

    nextTab.Page.Position = UDim2.fromOffset(0, 8)
    nextTab.Page.GroupTransparency = 1
    nextTab.Page.Visible = true
    Animations.Play(nextTab.Page, 0.24, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 0),
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    if type(self._onTabSelected) == "function" then
        pcall(self._onTabSelected, id)
    end
end

--------------------------------------------------------------------------------
-- [8] SETTINGS & CONFIGURATION LAYER
--------------------------------------------------------------------------------
local SettingsManager = {
    FileName = "ArcXHub_ThrowASeed_Config.json",
    Defaults = {
        uiScale = 1.0,
        glassTransparency = 0.06,
        layoutMode = "Auto",
        particlesEnabled = true,
        notificationsEnabled = true,
        toggleKeyName = "RightShift",
    },
}

function SettingsManager.Save(data)
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
-- [9] HUB CONTROLLER & EXACT CONCEPT UI ASSEMBLY
--------------------------------------------------------------------------------
local ArcXHub = {}
local janitor = Janitor.new()

local HubState = {
    destroyed = false,
    closing = false,
    minimized = false,
    sessionStart = os.clock(),

    uiScale = SettingsManager.Defaults.uiScale,
    glassTransparency = SettingsManager.Defaults.glassTransparency,
    layoutMode = SettingsManager.Defaults.layoutMode,
    particlesEnabled = SettingsManager.Defaults.particlesEnabled,
    notificationsEnabled = SettingsManager.Defaults.notificationsEnabled,
    toggleKey = Enum.KeyCode.RightShift,

    -- Synchronized Script Status states (reflected on Home Script Status card)
    statusAutoFarm = false,
    statusAutoSell = false,
    statusItemBoost = false,
    statusTraining = false,

    -- Session statistics
    seedsThrownCount = 0,
    moneyEarnedCount = 0,

    -- Local parameters
    localFarmPower = 0.98,
    localFarmThrows = 5,
    localFarmMode = "Balanced",
    localSellPreview = true,
    localSellMinRarity = "Rare",
    localSellThreshold = 85,
    localBoostReminder = 30,
    selectedSeed = "CloudSeed",
}

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
    warn("[ArcXHub] Gagal memasang ScreenGui.")
    return
end

local WINDOW_SPECS = {
    TitleBarHeight = 46,
    FooterBarHeight = 28,
    Desktop = { Width = 690, Height = 435, Sidebar = 158 },
    Mobile = { Width = 520, Height = 325, Sidebar = 124 },
    MinSize = Vector2.new(330, 240),
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
local outerStroke = Core.Stroke(mainWindow, Theme.ElectricPurple, 1.8, 0.12)
Theme.ApplyNeonGradient(outerStroke, 35)
Theme.ApplyGlassGradient(mainWindow, 135)

local windowScale = Core.Create("UIScale", {
    Scale = HubState.uiScale,
    Parent = mainWindow,
})

Animations.CreateParticleField(janitor, mainWindow, 16, HubState)

--------------------------------------------------------------------------------
-- TOP HEADER BAR (EXACT CONCEPT LAYOUT)
--------------------------------------------------------------------------------
local titleBar = Core.Create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, WINDOW_SPECS.TitleBarHeight),
    BackgroundColor3 = Theme.Obsidian,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 6,
    Parent = mainWindow,
})

local headerDivider = Core.Create("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.BorderGlow,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Parent = titleBar,
})
Theme.ApplyNeonGradient(headerDivider, 0)

-- Left Brand: Tilted Crown + "ArcxHub" + "Premium Script Hub"
local brandBox = Core.Create("Frame", {
    Position = UDim2.fromOffset(14, 4),
    Size = UDim2.fromOffset(145, 38),
    BackgroundTransparency = 1,
    Parent = titleBar,
})

local logoCrown = Icons.Crown(brandBox, 13, Theme.ElectricPurple, -18)
logoCrown.Position = UDim2.fromOffset(2, -1)

local brandTitle = Core.Create("TextLabel", {
    Position = UDim2.fromOffset(10, 4),
    Size = UDim2.fromOffset(130, 20),
    BackgroundTransparency = 1,
    Font = Theme.FontBlack,
    Text = "ArcxHub",
    TextSize = 19,
    TextColor3 = Theme.TextPrimary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = brandBox,
})
Core.Create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 155, 255)),
    }),
    Parent = brandTitle,
})

Core.Create("TextLabel", {
    Position = UDim2.fromOffset(16, 24),
    Size = UDim2.fromOffset(125, 13),
    BackgroundTransparency = 1,
    Font = Theme.FontMedium,
    Text = "Premium Script Hub",
    TextSize = 10,
    TextColor3 = Theme.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = brandBox,
})

-- Center Tagline: "✦ Play Smarter. Farm Faster."
local centerTagline = Core.Create("TextLabel", {
    Name = "CenterTagline",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.49, 0.5),
    Size = UDim2.fromOffset(210, 22),
    BackgroundTransparency = 1,
    Font = Theme.FontMedium,
    RichText = true,
    Text = '<font color="#D88CFF">✦</font>  Play Smarter. Farm Faster.',
    TextSize = 12,
    TextColor3 = Theme.TextSecondary,
    Parent = titleBar,
})

-- Right Controls: Version Pill ("★ v1.0.0") + Minimize ("–") + Close ("×")
local versionPill = Core.Create("Frame", {
    Name = "VersionPill",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -78, 0.5, 0),
    Size = UDim2.fromOffset(66, 24),
    BackgroundColor3 = Theme.CardInner,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Parent = titleBar,
})
Core.Corner(versionPill, 1)
Core.Stroke(versionPill, Theme.ElectricPurple, 1, 0.35)

Core.Create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = Theme.FontBold,
    RichText = true,
    Text = '<font color="#FBBF24">★</font> ' .. Theme.Version,
    TextSize = 11,
    TextColor3 = Theme.TextPrimary,
    Parent = versionPill,
})

local function createHeaderActionBtn(name, symbol, offsetX, hoverCol)
    local btn = Core.Create("TextButton", {
        Name = name,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(28, 24),
        BackgroundColor3 = Theme.CardInner,
        AutoButtonColor = false,
        Font = Theme.FontBold,
        Text = symbol,
        TextSize = 14,
        TextColor3 = Theme.TextPrimary,
        Parent = titleBar,
    })
    Core.Corner(btn, 6)
    Core.Stroke(btn, Theme.BorderGlow, 1, 0.45)
    Animations.BindButtonFeedback(janitor, btn, Theme.CardInner, hoverCol, Theme.Obsidian)
    return btn
end

local minimizeBtn = createHeaderActionBtn("MinimizeBtn", "–", -42, Theme.NeonViolet)
local closeBtn = createHeaderActionBtn("CloseBtn", "×", -10, Theme.Danger)

--------------------------------------------------------------------------------
-- BOTTOM STATUS BAR (EXACT CONCEPT LAYOUT)
--------------------------------------------------------------------------------
local bottomBar = Core.Create("Frame", {
    Name = "BottomStatusBar",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, WINDOW_SPECS.FooterBarHeight),
    BackgroundColor3 = Theme.Obsidian,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = mainWindow,
})

Core.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.BorderGlow,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = bottomBar,
})

local bellSlot = Core.Create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 14, 0.5, 0),
    Size = UDim2.fromOffset(14, 14),
    BackgroundTransparency = 1,
    Parent = bottomBar,
})
Icons.Create("Bell", bellSlot, 13, Theme.ElectricPurple)

local bottomStatusLabel = Core.Create("TextLabel", {
    Position = UDim2.fromOffset(33, 0),
    Size = UDim2.new(1, -155, 1, 0),
    BackgroundTransparency = 1,
    Font = Theme.FontMedium,
    RichText = true,
    Text = '<font color="#FFFFFF"><b>ArcXHub</b></font> loaded successfully!',
    TextSize = 11,
    TextColor3 = Theme.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = bottomBar,
})

local devBadge = Core.Create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(88, 20),
    BackgroundColor3 = Theme.CardInner,
    BorderSizePixel = 0,
    Parent = bottomBar,
})
Core.Corner(devBadge, 1)
Core.Stroke(devBadge, Theme.ElectricPurple, 1, 0.3)

local devCrown = Icons.Crown(devBadge, 11, Theme.ElectricPurple, 0)
devCrown.AnchorPoint = Vector2.new(0, 0.5)
devCrown.Position = UDim2.new(0, 8, 0.5, 0)

Core.Create("TextLabel", {
    Position = UDim2.fromOffset(23, 0),
    Size = UDim2.new(1, -26, 1, 0),
    BackgroundTransparency = 1,
    Font = Theme.FontBold,
    Text = Theme.Developer,
    TextSize = 11,
    TextColor3 = Theme.TextPrimary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = devBadge,
})

local notifier = Notifications.new(janitor, screenGui, HubState, function(latestMsg)
    bottomStatusLabel.Text = latestMsg
end)

--------------------------------------------------------------------------------
-- BODY CONTAINER & SIDEBAR WITH DISCORD CARD
--------------------------------------------------------------------------------
local bodyFrame = Core.Create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(0, WINDOW_SPECS.TitleBarHeight),
    Size = UDim2.new(1, 0, 1, -(WINDOW_SPECS.TitleBarHeight + WINDOW_SPECS.FooterBarHeight)),
    BackgroundTransparency = 1,
    ZIndex = 3,
    Parent = mainWindow,
})

local sidebarHolder = Core.Create("Frame", {
    Name = "SidebarHolder",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(0, WINDOW_SPECS.Desktop.Sidebar, 1, 0),
    BackgroundColor3 = Theme.SidebarBg,
    BackgroundTransparency = 0.28,
    BorderSizePixel = 0,
    Parent = bodyFrame,
})

Core.Create("Frame", {
    Name = "SidebarDivider",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = Theme.BorderGlow,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Parent = sidebarHolder,
})

local sidebarScroll = Core.Create("ScrollingFrame", {
    Name = "NavScroll",
    Size = UDim2.new(1, 0, 1, -68),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    Parent = sidebarHolder,
})
Core.Padding(sidebarScroll, 8, 8, 6, 8)
Core.Create("UIListLayout", {
    Padding = UDim.new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = sidebarScroll,
})

-- Bottom Sidebar Card: "Join Our Discord"
local discordCard = Core.Create("Frame", {
    Name = "DiscordCard",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -7),
    Size = UDim2.new(1, -14, 0, 56),
    BackgroundColor3 = Theme.CardInner,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Parent = sidebarHolder,
})
Core.Corner(discordCard, 10)
Core.Stroke(discordCard, Theme.BorderGlow, 1, 0.35)

local discordEmblem = Core.Create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 8, 0.5, 2),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Theme.DiscordBlurple,
    BorderSizePixel = 0,
    Parent = discordCard,
})
Core.Corner(discordEmblem, 1)

local dCrown = Icons.Crown(discordCard, 11, Theme.ElectricPurple, -10)
dCrown.Position = UDim2.fromOffset(16, 4)

Core.Create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = Theme.FontBlack,
    Text = "D",
    TextSize = 14,
    TextColor3 = Theme.TextPrimary,
    Parent = discordEmblem,
})

Core.Create("TextLabel", {
    Position = UDim2.fromOffset(42, 6),
    Size = UDim2.new(1, -46, 0, 14),
    BackgroundTransparency = 1,
    Font = Theme.FontBold,
    Text = "Join Our Discord",
    TextSize = 10,
    TextColor3 = Theme.TextPrimary,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = discordCard,
})

Core.Create("TextLabel", {
    Position = UDim2.fromOffset(42, 19),
    Size = UDim2.new(1, -46, 0, 12),
    BackgroundTransparency = 1,
    Font = Theme.FontRegular,
    Text = "Get Updates & Support!",
    TextSize = 8,
    TextColor3 = Theme.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = discordCard,
})

local discordBtn = Core.Create("TextButton", {
    Position = UDim2.fromOffset(42, 34),
    Size = UDim2.new(1, -48, 0, 16),
    BackgroundColor3 = Theme.DeepViolet,
    AutoButtonColor = false,
    Font = Theme.FontBold,
    Text = "Click Here >",
    TextSize = 9,
    TextColor3 = Theme.TextPrimary,
    Parent = discordCard,
})
Core.Corner(discordBtn, 1)
Core.Stroke(discordBtn, Theme.ElectricPurple, 1, 0.35)
Animations.BindButtonFeedback(janitor, discordBtn, Theme.DeepViolet, Theme.NeonViolet, Theme.Obsidian)

janitor:AddConnection(discordBtn.Activated:Connect(function()
    local copied = Core.CopyText(Theme.DiscordInvite)
    notifier:Push(
        "ArcXHub Discord",
        copied and ("Link Discord disalin: " .. Theme.DiscordInvite) or ("Discord: " .. Theme.DiscordInvite),
        "success",
        3
    )
end))

local contentViewport = Core.Create("Frame", {
    Name = "ContentViewport",
    Position = UDim2.fromOffset(WINDOW_SPECS.Desktop.Sidebar, 0),
    Size = UDim2.new(1, -WINDOW_SPECS.Desktop.Sidebar, 1, 0),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = bodyFrame,
})

--------------------------------------------------------------------------------
-- FLOATING REOPEN CIRCULAR 'A' LOGO BUTTON (BOTTOM RIGHT)
--------------------------------------------------------------------------------
local floatingAnchor = Core.Create("Frame", {
    Name = "FloatingLogoButton",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(startViewport.X - 54, startViewport.Y - 96),
    Size = UDim2.fromOffset(54, 54),
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
    Size = UDim2.new(1, 6, 1, 6),
    BackgroundColor3 = Theme.NeonViolet,
    BackgroundTransparency = 0.58,
    BorderSizePixel = 0,
    Parent = floatingAnchor,
})
Core.Corner(pulseRing, 1)
Core.Stroke(pulseRing, Theme.ElectricPurple, 1.5, 0.25)

local floatingLogo = Components.CreateFuturisticLogoA(floatingAnchor, 48, true)
floatingLogo.AnchorPoint = Vector2.new(0.5, 0.5)
floatingLogo.Position = UDim2.fromScale(0.5, 0.5)

Animations.StartPulse(janitor, pulseRing, function()
    return HubState.minimized and not HubState.destroyed
end)

--------------------------------------------------------------------------------
-- RESPONSIVE LAYOUT & WINDOW LIFECYCLE
--------------------------------------------------------------------------------
local animSequence = 0

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
    local isMobile = resolveMobileMode()
    local profile = isMobile and WINDOW_SPECS.Mobile or WINDOW_SPECS.Desktop
    local safeBounds = viewport / HubState.uiScale

    local w = math.max(math.min(profile.Width, safeBounds.X * 0.94), WINDOW_SPECS.MinSize.X)
    local h = math.max(math.min(profile.Height, safeBounds.Y * 0.88), WINDOW_SPECS.MinSize.Y)
    local sideW = (w < 550) and WINDOW_SPECS.Mobile.Sidebar or WINDOW_SPECS.Desktop.Sidebar

    centerTagline.Visible = w >= 540

    local scaledSize = Vector2.new(math.floor(w * HubState.uiScale), math.floor(h * HubState.uiScale))
    rootAnchor.Size = UDim2.fromOffset(scaledSize.X, scaledSize.Y)
    mainWindow.Size = UDim2.fromOffset(math.floor(w), math.floor(h))

    sidebarHolder.Size = UDim2.new(0, sideW, 1, 0)
    contentViewport.Position = UDim2.fromOffset(sideW, 0)
    contentViewport.Size = UDim2.new(1, -sideW, 1, 0)

    local currentCenter = Vector2.new(rootAnchor.Position.X.Offset, rootAnchor.Position.Y.Offset)
    local clampedCenter = Core.ClampPosition(currentCenter, scaledSize, viewport)
    rootAnchor.Position = UDim2.fromOffset(clampedCenter.X, clampedCenter.Y)

    local floatPos = Vector2.new(floatingAnchor.Position.X.Offset, floatingAnchor.Position.Y.Offset)
    local clampedFloat = Core.ClampPosition(floatPos, Vector2.new(58, 58), viewport)
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
    windowScale.Scale = HubState.uiScale * 0.88

    sidebarHolder.Position = UDim2.fromOffset(-20, 0)
    Animations.Play(sidebarHolder, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    Animations.Play(mainWindow, 0.28, { GroupTransparency = HubState.glassTransparency }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Animations.Play(windowScale, 0.34, { Scale = HubState.uiScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function playCloseAnimation()
    animSequence += 1
    Animations.Play(mainWindow, 0.2, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    Animations.Play(windowScale, 0.2, { Scale = HubState.uiScale * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    return 0.2
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
        Animations.Play(floatingScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
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

Core.MakeDraggable(janitor, titleBar, rootAnchor, screenGui, { ExcludeRightPx = 148 })
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

--------------------------------------------------------------------------------
-- INITIALIZE 8 NAVIGATION TABS
--------------------------------------------------------------------------------
local nav = Navigation.new(janitor, sidebarScroll, contentViewport)

local TAB_DEFINITIONS = {
    { Id = "Home", Title = "Home" },
    { Id = "MainFarm", Title = "Main Farm" },
    { Id = "Upgrade", Title = "Upgrade" },
    { Id = "AutoSell", Title = "Auto Sell" },
    { Id = "ItemBoost", Title = "Item Boost" },
    { Id = "SeedManager", Title = "Seed Manager" },
    { Id = "RemoteInspector", Title = "Remote Inspector" },
    { Id = "Settings", Title = "Settings" },
}

for _, def in ipairs(TAB_DEFINITIONS) do
    nav:AddTab(def)
end

-- Forward references for live cross-tab status sync
local syncStatusUiFn = nil
local farmToggleControl = nil
local sellToggleControl = nil

--------------------------------------------------------------------------------
-- TAB 1: HOME DASHBOARD (EXACT 1:1 HERO BANNER + 2x2 GRID LAYOUT)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["Home"].Scroll

    -- [A] HERO BANNER CARD: "Welcome to ArcXHub!" + Status: Ready + Right Violet Character Aura
    local heroCard = Core.Create("Frame", {
        Name = "HeroBanner",
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 94),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = page,
    })
    Core.Corner(heroCard, 12)
    Core.Stroke(heroCard, Theme.BorderGlow, 1.1, 0.3)

    local heroGrad = Core.Create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 15, 44)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(36, 20, 74)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 36, 158)),
        }),
        Parent = heroCard,
    })
    heroGrad.Name = "HeroAuraGradient"

    -- Right-side Anime Character / Energy Aura Visual
    local artRight = Core.Create("Frame", {
        Name = "CharacterAuraBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0.46, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = heroCard,
    })

    if Theme.CustomAssets.HeroAnimeBanner ~= "" then
        Core.Create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = Theme.CustomAssets.HeroAnimeBanner,
            ScaleType = Enum.ScaleType.Crop,
            Parent = artRight,
        })
    else
        -- Procedural Neon Violet Energy Halo + Stylized Anime Silhouette
        local auraGlow = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.58, 0.52),
            Size = UDim2.fromOffset(110, 110),
            BackgroundColor3 = Theme.NeonViolet,
            BackgroundTransparency = 0.62,
            BorderSizePixel = 0,
            Parent = artRight,
        })
        Core.Corner(auraGlow, 1)

        local cloak = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.56, 1.06),
            Size = UDim2.fromOffset(88, 52),
            BackgroundColor3 = Theme.Obsidian,
            BorderSizePixel = 0,
            Parent = artRight,
        })
        Core.Corner(cloak, 24)
        Core.Stroke(cloak, Theme.ElectricPurple, 1.2, 0.35)

        local head = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.56, 0.44),
            Size = UDim2.fromOffset(42, 44),
            BackgroundColor3 = Color3.fromRGB(24, 18, 38),
            BorderSizePixel = 0,
            Parent = artRight,
        })
        Core.Corner(head, 1)
        Core.Stroke(head, Theme.NeonViolet, 1, 0.4)

        -- Glowing Violet Eyes
        for _, ex in ipairs({ 0.36, 0.64 }) do
            local eye = Core.Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(ex, 0.54),
                Size = UDim2.fromOffset(7, 4),
                BackgroundColor3 = Theme.ElectricPurple,
                BorderSizePixel = 0,
                Parent = head,
            })
            Core.Corner(eye, 1)
        end
    end

    -- Hero Left Copy
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(14, 11),
        Size = UDim2.new(0.64, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Theme.FontBlack,
        RichText = true,
        Text = 'Welcome to <font color="#D946EF">ArcXHub!</font>',
        TextSize = 17,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = heroCard,
    })

    local subRow = Core.Create("Frame", {
        Position = UDim2.fromOffset(14, 34),
        Size = UDim2.new(0.64, 0, 0, 16),
        BackgroundTransparency = 1,
        Parent = heroCard,
    })

    Core.Create("TextLabel", {
        Size = UDim2.fromOffset(172, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = "Your ultimate tools for Throw a Seed",
        TextSize = 11,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = subRow,
    })

    local subCrown = Icons.Crown(subRow, 12, Theme.MagentaGlow, 0)
    subCrown.Position = UDim2.fromOffset(175, 2)

    -- Status: Ready Green Pill
    local readyPill = Core.Create("Frame", {
        Position = UDim2.fromOffset(14, 57),
        Size = UDim2.fromOffset(112, 23),
        BackgroundColor3 = Theme.SuccessBg,
        BorderSizePixel = 0,
        Parent = heroCard,
    })
    Core.Corner(readyPill, 1)
    Core.Stroke(readyPill, Theme.Success, 1, 0.35)

    local readyDot = Core.Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Success,
        BorderSizePixel = 0,
        Parent = readyPill,
    })
    Core.Corner(readyDot, 1)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(22, 0),
        Size = UDim2.new(1, -26, 1, 0),
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        RichText = true,
        Text = 'Status: <font color="#FFFFFF"><b>Ready</b></font>',
        TextSize = 11,
        TextColor3 = Theme.Success,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = readyPill,
    })

    -- [B] ROW 2: 2-COLUMN GRID (LEFT: GAME INFO | RIGHT: QUICK ACTIONS)
    local row2 = Core.Create("Frame", {
        Name = "GridRowTop",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 118),
        BackgroundTransparency = 1,
        Parent = page,
    })

    -- Left Card: Game Info
    local gameInfoCard = Core.Create("Frame", {
        Name = "GameInfoCard",
        Size = UDim2.new(0.49, 0, 1, 0),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Parent = row2,
    })
    Core.Corner(gameInfoCard, 12)
    Core.Stroke(gameInfoCard, Theme.BorderGlow, 1, 0.42)

    local giIcon = Icons.Create("Gamepad", gameInfoCard, 15, Theme.ElectricPurple)
    giIcon.Position = UDim2.fromOffset(12, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(32, 9),
        Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = "Game Info",
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = gameInfoCard,
    })

    -- Game Thumbnail Box (Auto-loads real Throw a Seed GameIcon via rbxthumb!)
    local placeIdNum = (game.PlaceId and game.PlaceId > 0) and game.PlaceId or 129081220403721
    local thumbBox = Core.Create("Frame", {
        Position = UDim2.fromOffset(12, 32),
        Size = UDim2.fromOffset(72, 72),
        BackgroundColor3 = Theme.DeepViolet,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gameInfoCard,
    })
    Core.Corner(thumbBox, 10)
    Core.Stroke(thumbBox, Theme.ElectricPurple, 1.1, 0.35)

    -- Styled Fallback Label behind ImageLabel
    Core.Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Theme.FontBlack,
        Text = "THROW\nA\nSEED",
        TextSize = 12,
        TextColor3 = Theme.Warning,
        Parent = thumbBox,
    })

    local thumbImgUrl = (Theme.CustomAssets.GameThumbnail ~= "" and Theme.CustomAssets.GameThumbnail)
        or ("rbxthumb://type=GameIcon&id=" .. tostring(placeIdNum) .. "&w=150&h=150")
    Core.Create("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = thumbImgUrl,
        ScaleType = Enum.ScaleType.Crop,
        Parent = thumbBox,
    })

    -- Right Metadata Stack in Game Info
    local metaX = 92
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX, 31),
        Size = UDim2.new(1, -(metaX + 8), 0, 11),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = "Game Name",
        TextSize = 9,
        TextColor3 = Theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = gameInfoCard,
    })
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX, 42),
        Size = UDim2.new(1, -(metaX + 8), 0, 13),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = Theme.TargetGame,
        TextSize = 11,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = gameInfoCard,
    })

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX, 57),
        Size = UDim2.new(1, -(metaX + 8), 0, 11),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = "Game ID",
        TextSize = 9,
        TextColor3 = Theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = gameInfoCard,
    })
    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX, 68),
        Size = UDim2.new(1, -(metaX + 8), 0, 13),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(placeIdNum),
        TextSize = 10,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = gameInfoCard,
    })

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX, 83),
        Size = UDim2.new(1, -(metaX + 8), 0, 11),
        BackgroundTransparency = 1,
        Font = Theme.FontRegular,
        Text = "Players",
        TextSize = 9,
        TextColor3 = Theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = gameInfoCard,
    })

    local pDot = Core.Create("Frame", {
        Position = UDim2.fromOffset(metaX, 97),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Theme.Success,
        BorderSizePixel = 0,
        Parent = gameInfoCard,
    })
    Core.Corner(pDot, 1)

    local playersCountLabel = Core.Create("TextLabel", {
        Position = UDim2.fromOffset(metaX + 10, 93),
        Size = UDim2.new(1, -(metaX + 16), 0, 13),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = tostring(#Players:GetPlayers()) .. " Online",
        TextSize = 10,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = gameInfoCard,
    })

    -- Right Card: Quick Actions (4 Tiles + "More >")
    local quickCard = Core.Create("Frame", {
        Name = "QuickActionsCard",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.49, 0, 1, 0),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Parent = row2,
    })
    Core.Corner(quickCard, 12)
    Core.Stroke(quickCard, Theme.BorderGlow, 1, 0.42)

    local qaBolt = Icons.Create("Bolt", quickCard, 14, Theme.MagentaGlow)
    qaBolt.Position = UDim2.fromOffset(11, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(29, 9),
        Size = UDim2.new(1, -90, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = "Quick Actions",
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = quickCard,
    })

    local moreBtn = Core.Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 8),
        Size = UDim2.fromOffset(50, 18),
        BackgroundColor3 = Theme.CardInner,
        AutoButtonColor = false,
        Font = Theme.FontMedium,
        Text = "More >",
        TextSize = 9,
        TextColor3 = Theme.TextSecondary,
        Parent = quickCard,
    })
    Core.Corner(moreBtn, 1)
    Core.Stroke(moreBtn, Theme.BorderGlow, 1, 0.45)
    Animations.BindButtonFeedback(janitor, moreBtn, Theme.CardInner, Theme.DeepViolet, Theme.Obsidian)
    janitor:AddConnection(moreBtn.Activated:Connect(function()
        nav:Select("MainFarm")
    end))

    local tilesHolder = Core.Create("Frame", {
        Position = UDim2.fromOffset(10, 34),
        Size = UDim2.new(1, -20, 0, 70),
        BackgroundTransparency = 1,
        Parent = quickCard,
    })

    Core.Create("UIGridLayout", {
        CellSize = UDim2.new(0.232, 0, 1, 0),
        CellPadding = UDim2.new(0.024, 0, 0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tilesHolder,
    })

    local QUICK_TILES = {
        {
            Label = "Auto Farm",
            Icon = "Play",
            OnClick = function()
                HubState.statusAutoFarm = not HubState.statusAutoFarm
                if farmToggleControl then
                    farmToggleControl.Set(HubState.statusAutoFarm, true)
                end
                if syncStatusUiFn then
                    syncStatusUiFn()
                end
                notifier:Push("Quick Action", "Auto Farm: " .. (HubState.statusAutoFarm and "Enabled" or "Disabled"), HubState.statusAutoFarm and "success" or "warning", 2.2)
            end,
        },
        {
            Label = "Auto Sell",
            Icon = "AutoSell",
            OnClick = function()
                HubState.statusAutoSell = not HubState.statusAutoSell
                if sellToggleControl then
                    sellToggleControl.Set(HubState.statusAutoSell, true)
                end
                if syncStatusUiFn then
                    syncStatusUiFn()
                end
                notifier:Push("Quick Action", "Auto Sell: " .. (HubState.statusAutoSell and "Enabled" or "Disabled"), HubState.statusAutoSell and "success" or "warning", 2.2)
            end,
        },
        {
            Label = "Boost",
            Icon = "ItemBoost",
            OnClick = function()
                HubState.statusItemBoost = not HubState.statusItemBoost
                if syncStatusUiFn then
                    syncStatusUiFn()
                end
                notifier:Push("Quick Action", "Item Boost Monitor: " .. (HubState.statusItemBoost and "Enabled" or "Disabled"), HubState.statusItemBoost and "success" or "warning", 2.2)
            end,
        },
        {
            Label = "Teleport",
            Icon = "Pin",
            OnClick = function()
                nav:Select("SeedManager")
                notifier:Push("Navigation", "Membuka Seed Manager & Lokasi Plot.", "info", 2)
            end,
        },
    }

    for idx, tileDef in ipairs(QUICK_TILES) do
        local tileBtn = Core.Create("TextButton", {
            Name = "Tile_" .. tileDef.Label,
            LayoutOrder = idx,
            BackgroundColor3 = Theme.CardInner,
            AutoButtonColor = false,
            Text = "",
            Parent = tilesHolder,
        })
        Core.Corner(tileBtn, 10)
        Core.Stroke(tileBtn, Theme.BorderGlow, 1, 0.35)
        Animations.BindButtonFeedback(janitor, tileBtn, Theme.CardInner, Theme.DeepViolet, Theme.Obsidian)

        local ic = Icons.Create(tileDef.Icon, tileBtn, 20, Theme.ElectricPurple)
        ic.AnchorPoint = Vector2.new(0.5, 0)
        ic.Position = UDim2.new(0.5, 0, 0, 13)

        Core.Create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -8),
            Size = UDim2.new(1, -4, 0, 14),
            BackgroundTransparency = 1,
            Font = Theme.FontMedium,
            Text = tileDef.Label,
            TextSize = 9,
            TextColor3 = Theme.TextPrimary,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = tileBtn,
        })

        janitor:AddConnection(tileBtn.Activated:Connect(tileDef.OnClick))
    end

    -- [C] ROW 3: 2-COLUMN GRID (LEFT: SCRIPT STATUS | RIGHT: STATISTICS + CHEST)
    local row3 = Core.Create("Frame", {
        Name = "GridRowBottom",
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 122),
        BackgroundTransparency = 1,
        Parent = page,
    })

    -- Left Card: Script Status
    local statusCard = Core.Create("Frame", {
        Name = "ScriptStatusCard",
        Size = UDim2.new(0.49, 0, 1, 0),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Parent = row3,
    })
    Core.Corner(statusCard, 12)
    Core.Stroke(statusCard, Theme.BorderGlow, 1, 0.42)

    local pulseIc = Icons.Create("Pulse", statusCard, 15, Theme.MagentaGlow)
    pulseIc.Position = UDim2.fromOffset(12, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(32, 9),
        Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = "Script Status",
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })

    local statusList = Core.Create("Frame", {
        Position = UDim2.fromOffset(12, 31),
        Size = UDim2.new(1, -24, 0, 82),
        BackgroundTransparency = 1,
        Parent = statusCard,
    })
    Core.Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = statusList,
    })

    local function createStatusRow(order, name, keyField)
        local rBtn = Core.Create("TextButton", {
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 17),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Parent = statusList,
        })

        local leftDot = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(7, 7),
            BackgroundColor3 = Theme.Danger,
            BorderSizePixel = 0,
            Parent = rBtn,
        })
        Core.Corner(leftDot, 1)

        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(0.58, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Theme.FontMedium,
            Text = name,
            TextSize = 11,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = rBtn,
        })

        local rightDot = Core.Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -54, 0.5, 0),
            Size = UDim2.fromOffset(7, 7),
            BackgroundColor3 = Theme.Danger,
            BorderSizePixel = 0,
            Parent = rBtn,
        })
        Core.Corner(rightDot, 1)

        local stateLbl = Core.Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(50, 17),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = "Disabled",
            TextSize = 10,
            TextColor3 = Theme.Danger,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = rBtn,
        })

        janitor:AddConnection(rBtn.Activated:Connect(function()
            HubState[keyField] = not HubState[keyField]
            if keyField == "statusAutoFarm" and farmToggleControl then
                farmToggleControl.Set(HubState[keyField], true)
            elseif keyField == "statusAutoSell" and sellToggleControl then
                sellToggleControl.Set(HubState[keyField], true)
            end
            if syncStatusUiFn then
                syncStatusUiFn()
            end
        end))

        return function(isEnabled)
            local col = isEnabled and Theme.Success or Theme.Danger
            leftDot.BackgroundColor3 = col
            rightDot.BackgroundColor3 = col
            stateLbl.Text = isEnabled and "Enabled" or "Disabled"
            stateLbl.TextColor3 = col
        end
    end

    local setFarmRow = createStatusRow(1, "Auto Farm", "statusAutoFarm")
    local setSellRow = createStatusRow(2, "Auto Sell", "statusAutoSell")
    local setBoostRow = createStatusRow(3, "Item Boost", "statusItemBoost")
    local setTrainRow = createStatusRow(4, "Training Assistant", "statusTraining")

    syncStatusUiFn = function()
        setFarmRow(HubState.statusAutoFarm)
        setSellRow(HubState.statusAutoSell)
        setBoostRow(HubState.statusItemBoost)
        setTrainRow(HubState.statusTraining)
    end
    syncStatusUiFn()

    -- Right Card: Statistics + Purple Gem Treasure Chest Visual
    local statsCard = Core.Create("Frame", {
        Name = "StatisticsCard",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.49, 0, 1, 0),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = row3,
    })
    Core.Corner(statsCard, 12)
    Core.Stroke(statsCard, Theme.BorderGlow, 1, 0.42)

    local chartIc = Icons.Create("Chart", statsCard, 15, Theme.MagentaGlow)
    chartIc.Position = UDim2.fromOffset(12, 10)

    Core.Create("TextLabel", {
        Position = UDim2.fromOffset(32, 9),
        Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1,
        Font = Theme.FontBold,
        Text = "Statistics",
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statsCard,
    })

    -- Right-side Glowing Purple Gem Chest Illustration
    local chestBox = Core.Create("Frame", {
        Name = "TreasureChestArt",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -6, 1, -6),
        Size = UDim2.fromOffset(82, 74),
        BackgroundTransparency = 1,
        Parent = statsCard,
    })

    if Theme.CustomAssets.TreasureChest ~= "" then
        Core.Create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = Theme.CustomAssets.TreasureChest,
            ScaleType = Enum.ScaleType.Fit,
            Parent = chestBox,
        })
    else
        -- Procedural Glowing Neon Purple Gem Chest
        local gemGlow = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.48),
            Size = UDim2.fromOffset(66, 60),
            BackgroundColor3 = Theme.NeonViolet,
            BackgroundTransparency = 0.72,
            BorderSizePixel = 0,
            Parent = chestBox,
        })
        Core.Corner(gemGlow, 1)

        -- Crystals overflowing from chest
        local gemOffsets = {
            { x = 0.34, y = 0.42, rot = -18, col = Theme.ElectricPurple },
            { x = 0.5, y = 0.36, rot = 6, col = Theme.TextPrimary },
            { x = 0.66, y = 0.44, rot = 22, col = Theme.MagentaGlow },
        }
        for _, g in ipairs(gemOffsets) do
            local crystal = Core.Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(g.x, g.y),
                Size = UDim2.fromOffset(14, 18),
                Rotation = g.rot,
                BackgroundColor3 = g.col,
                BorderSizePixel = 0,
                Parent = chestBox,
            })
            Core.Corner(crystal, 3)
        end

        -- Chest Base & Gold-Violet Trim
        local chestBody = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.fromScale(0.5, 0.94),
            Size = UDim2.fromOffset(58, 32),
            BackgroundColor3 = Color3.fromRGB(48, 22, 86),
            BorderSizePixel = 0,
            Parent = chestBox,
        })
        Core.Corner(chestBody, 6)
        Core.Stroke(chestBody, Theme.ElectricPurple, 1.4, 0.2)

        local lockClasp = Core.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0.08),
            Size = UDim2.fromOffset(10, 12),
            BackgroundColor3 = Theme.ElectricPurple,
            BorderSizePixel = 0,
            Parent = chestBody,
        })
        Core.Corner(lockClasp, 2)
    end

    -- Left Metrics Stack in Statistics
    local function createStatLine(yPos, iconName, labelStr, initVal)
        local ic = Icons.Create(iconName, statsCard, 13, Theme.ElectricPurple)
        ic.Position = UDim2.fromOffset(12, yPos + 2)

        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(29, yPos),
            Size = UDim2.fromOffset(74, 17),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = labelStr,
            TextSize = 10,
            TextColor3 = Theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = statsCard,
        })

        local val = Core.Create("TextLabel", {
            Position = UDim2.fromOffset(104, yPos),
            Size = UDim2.new(1, -186, 0, 17),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = initVal,
            TextSize = 11,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = statsCard,
        })
        return val
    end

    local playTimeVal = createStatLine(35, "Clock", "Play Time", "00:00:00")
    local seedsThrownVal = createStatLine(60, "SeedManager", "Seeds Thrown", "0")
    local moneyEarnedVal = createStatLine(85, "Coin", "Money Earned", "0")

    -- Live 1-Second Session Ticker (Play Time, Player Count, Local Simulation Counter)
    janitor:AddThread(task.spawn(function()
        while not HubState.destroyed do
            if not HubState.minimized then
                local elapsed = math.floor(os.clock() - HubState.sessionStart)
                local hrs = math.floor(elapsed / 3600)
                local mins = math.floor((elapsed % 3600) / 60)
                local secs = elapsed % 60
                playTimeVal.Text = string.format("%02d:%02d:%02d", hrs, mins, secs)
                playersCountLabel.Text = tostring(#Players:GetPlayers()) .. " Online"

                if HubState.statusAutoFarm then
                    HubState.seedsThrownCount += 1
                    HubState.moneyEarnedCount += 25
                end

                local liveMoney = LocalPlayer:GetAttribute("Money")
                if liveMoney ~= nil then
                    moneyEarnedVal.Text = tostring(liveMoney)
                else
                    moneyEarnedVal.Text = tostring(HubState.moneyEarnedCount)
                end
                seedsThrownVal.Text = tostring(HubState.seedsThrownCount)
            end
            task.wait(1)
        end
    end))
end

--------------------------------------------------------------------------------
-- TAB 2: MAIN FARM (SYNCHRONIZED WITH HOME SCRIPT STATUS)
--------------------------------------------------------------------------------
do
    local page = nav._tabs["MainFarm"].Scroll
    Components.CreatePageHeader(
        page,
        "Main Farm Controller",
        "Konfigurasi parameter lemparan dan siklus latihan lokal. Tidak mengirim panggilan Remote ke server.",
        "LOCAL UI"
    )

    local ctrlCard = Components.CreateSection(page, "Automation Parameters", 1)
    local setStateLabel = Components.CreateInfoRow(ctrlCard, "Controller Status", "DISABLED", Theme.Danger, 1)

    farmToggleControl = Components.CreateToggle(janitor, ctrlCard, "Auto Farm Simulation", "Sinkron dengan indikator Script Status di tab Home", false, function(on)
        HubState.statusAutoFarm = on
        setStateLabel(on and "ENABLED (LOCAL)" or "DISABLED", on and Theme.Success or Theme.Danger)
        if syncStatusUiFn then
            syncStatusUiFn()
        end
        notifier:Push("Main Farm", on and "Auto Farm simulation diaktifkan." or "Auto Farm simulation dihentikan.", on and "success" or "warning", 2.4)
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
-- TAB 3: UPGRADE PLANNER
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
-- TAB 4: AUTO SELL (SYNCHRONIZED WITH HOME SCRIPT STATUS)
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
    sellToggleControl = Components.CreateToggle(janitor, sellCard, "Auto Sell Simulation", "Sinkron dengan indikator Auto Sell di tab Home", false, function(on)
        HubState.statusAutoSell = on
        if syncStatusUiFn then
            syncStatusUiFn()
        end
        notifier:Push("Auto Sell", on and "Auto Sell simulation aktif." or "Auto Sell simulation nonaktif.", on and "success" or "warning", 2.2)
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
-- TAB 5: ITEM BOOST
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
    Components.CreateToggle(janitor, boostCard, "Boost Expiry Reminder", "Sinkron dengan indikator Item Boost di tab Home", false, function(on)
        HubState.statusItemBoost = on
        if syncStatusUiFn then
            syncStatusUiFn()
        end
    end, 1)

    Components.CreateInfoRow(boostCard, "2x XP Boost", "14m 20s [Mock]", Theme.Success, 2)
    Components.CreateInfoRow(boostCard, "2x Luck Boost", "Inactive", Theme.TextMuted, 3)

    Components.CreateSlider(janitor, boostCard, "Expiry Reminder Alert", 5, 120, HubState.localBoostReminder, 5, "s", function(val)
        HubState.localBoostReminder = val
    end, 4)
end

--------------------------------------------------------------------------------
-- TAB 6: SEED MANAGER (SEARCHABLE DATABASE)
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
                    Size = UDim2.new(1, 0, 0, 27),
                    BackgroundColor3 = Theme.CardElevated,
                    AutoButtonColor = false,
                    Font = Theme.FontMedium,
                    Text = string.format("  %s  (%s)", item.Name, item.Rarity),
                    TextSize = 11,
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
-- TAB 7: REMOTE INSPECTOR (READ-ONLY DOCUMENTATION VIEWER)
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
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = Theme.CardElevated,
            BackgroundTransparency = 0.38,
            BorderSizePixel = 0,
            Parent = docCard,
        })
        Core.Corner(row, 8)
        Core.Padding(row, 5, 10, 5, 10)

        Core.Create("TextLabel", {
            Size = UDim2.new(0.68, 0, 0, 16),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = string.format("%s  [%s]", doc.Name, doc.Class),
            TextSize = 11,
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
            TextSize = 10,
            TextColor3 = badgeColor,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })

        Core.Create("TextLabel", {
            Position = UDim2.fromOffset(0, 17),
            Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1,
            Font = Theme.FontRegular,
            Text = doc.Sig,
            TextSize = 10,
            TextColor3 = Theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })
    end
end

--------------------------------------------------------------------------------
-- TAB 8: SETTINGS & CONFIGURATION PANEL
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

GlobalStore.ArcXHubInstance = ArcXHub
return ArcXHub
