--[[
    RYUZENX HUB v1.0
    Dark purple, mobile-friendly UI framework (Luau)
    Target: Delta Executor / Roblox Studio (LocalScript)

    Features: draggable window (mouse + touch), tabs, toggles, sliders,
    buttons, labels, notifications, minimize / close, RightShift toggle.

    Executor-specific APIs used (all optional, with fallbacks):
      - gethui()  -> safer UI parent. Falls back to CoreGui, then PlayerGui.
      - VirtualUser (Anti-AFK demo) -> wrapped in pcall.
]]

-- ========== SERVICES ==========
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ========== THEME ==========
local Theme = {
    Background = Color3.fromRGB(14, 12, 20),
    Topbar     = Color3.fromRGB(24, 18, 38),
    Sidebar    = Color3.fromRGB(19, 16, 29),
    Element    = Color3.fromRGB(32, 27, 46),
    Accent     = Color3.fromRGB(138, 80, 255),
    AccentDark = Color3.fromRGB(88, 48, 170),
    Text       = Color3.fromRGB(240, 235, 255),
    SubText    = Color3.fromRGB(160, 150, 185),
    Off        = Color3.fromRGB(60, 55, 80),
    Font       = Enum.Font.GothamMedium,
    FontBold   = Enum.Font.GothamBold,
}

-- ========== HELPERS ==========
local function safeParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end

    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then
        local probe = Instance.new("Folder")
        local canParent = pcall(function() probe.Parent = core end)
        probe:Destroy()
        if canParent then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function safeCall(fn, ...)
    if typeof(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[RYUZENX] Callback error: " .. tostring(err))
    end
end

-- ========== LIBRARY ==========
local Library = {}
Library.__index = Library

-- Remove an older instance if the script is executed twice
do
    local parent = safeParent()
    local old = parent:FindFirstChild("RyuzenXHub")
    if old then old:Destroy() end
end

function Library.new(title)
    local self = setmetatable({}, Library)
    self.Connections = {}
    self.Tabs = {}
    self.ActiveTab = nil
    self.Minimized = false

    local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    local width  = math.clamp(viewport.X - 40, 300, 520)
    local height = math.clamp(viewport.Y - 60, 220, 340)
    self.FullSize = UDim2.fromOffset(width, height)

    -- ScreenGui
    self.Gui = create("ScreenGui", {
        Name = "RyuzenXHub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    })
    self.Gui.Parent = safeParent()

    -- Main window
    self.Main = create("Frame", {
        Name = "Main",
        Size = self.FullSize,
        Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self.Gui,
    }, {
        corner(12),
        create("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.35 }),
    })

    -- Topbar
    self.Topbar = create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Topbar,
        BorderSizePixel = 0,
        Parent = self.Main,
    }, { corner(12) })

    -- Square off the bottom corners of the topbar
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Theme.Topbar,
        BorderSizePixel = 0,
        Parent = self.Topbar,
    })

    create("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = title or "RYUZENX HUB",
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.FontBold,
        TextSize = 16,
        Parent = self.Topbar,
    })

    local function topButton(text, offsetFromRight, color)
        return create("TextButton", {
            Size = UDim2.fromOffset(32, 28),
            Position = UDim2.new(1, -offsetFromRight, 0.5, -14),
            BackgroundColor3 = color,
            Text = text,
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 16,
            AutoButtonColor = true,
            Parent = self.Topbar,
        }, { corner(7) })
    end

    local minBtn   = topButton("–", 78, Theme.AccentDark)
    local closeBtn = topButton("X", 40, Color3.fromRGB(170, 50, 80))

    -- Body (sidebar + content)
    self.Body = create("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -40),
        Position = UDim2.fromOffset(0, 40),
        BackgroundTransparency = 1,
        Parent = self.Main,
    })

    self.Sidebar = create("ScrollingFrame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 96, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = self.Body,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
    })

    self.Content = create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -96, 1, 0),
        Position = UDim2.fromOffset(96, 0),
        BackgroundTransparency = 1,
        Parent = self.Body,
    })

    -- Notification holder
    self.NotifHolder = create("Frame", {
        Name = "Notifications",
        Size = UDim2.new(0, 260, 1, -20),
        Position = UDim2.new(1, -270, 0, 10),
        BackgroundTransparency = 1,
        Parent = self.Gui,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Top,
        }),
    })

    -- ===== Dragging (mouse + touch) =====
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil

    table.insert(self.Connections, self.Topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    table.insert(self.Connections, self.Topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    -- ===== Minimize / Close =====
    minBtn.MouseButton1Click:Connect(function()
        self.Minimized = not self.Minimized
        if self.Minimized then
            self.Body.Visible = false
            tween(self.Main, 0.2, { Size = UDim2.fromOffset(self.FullSize.X.Offset, 40) })
        else
            tween(self.Main, 0.2, { Size = self.FullSize })
            task.delay(0.15, function()
                if self.Gui and self.Gui.Parent then self.Body.Visible = true end
            end)
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        self:Destroy()
    end)

    -- RightShift toggles visibility (PC)
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            self.Main.Visible = not self.Main.Visible
        end
    end))

    -- Open animation
    self.Main.Size = UDim2.fromOffset(width, 0)
    tween(self.Main, 0.25, { Size = self.FullSize })

    return self
end

function Library:Destroy()
    for _, c in ipairs(self.Connections) do
        pcall(function() c:Disconnect() end)
    end
    self.Connections = {}
    if self.OnDestroy then
        for _, fn in ipairs(self.OnDestroy) do safeCall(fn) end
    end
    if self.Gui then self.Gui:Destroy() end
end

function Library:OnClose(fn)
    self.OnDestroy = self.OnDestroy or {}
    table.insert(self.OnDestroy, fn)
end

-- ========== NOTIFICATIONS ==========
function Library:Notify(title, text, duration)
    duration = duration or 4

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = Theme.Topbar,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.NotifHolder,
    }, {
        corner(10),
        create("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 1 }),
    })

    local bar = create("Frame", {
        Size = UDim2.new(0, 4, 1, -16),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = card,
    }, { corner(2) })

    local t1 = create("TextLabel", {
        Size = UDim2.new(1, -30, 0, 20),
        Position = UDim2.fromOffset(22, 8),
        BackgroundTransparency = 1,
        Text = tostring(title),
        TextColor3 = Theme.Text,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Theme.FontBold,
        TextSize = 14,
        Parent = card,
    })

    local t2 = create("TextLabel", {
        Size = UDim2.new(1, -30, 0, 28),
        Position = UDim2.fromOffset(22, 28),
        BackgroundTransparency = 1,
        Text = tostring(text),
        TextColor3 = Theme.SubText,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Font = Theme.Font,
        TextSize = 12,
        Parent = card,
    })

    local stroke = card:FindFirstChildOfClass("UIStroke")

    -- fade in
    tween(card, 0.25, { BackgroundTransparency = 0.05 })
    tween(stroke, 0.25, { Transparency = 0.3 })
    tween(bar, 0.25, { BackgroundTransparency = 0 })
    tween(t1, 0.25, { TextTransparency = 0 })
    tween(t2, 0.25, { TextTransparency = 0 })

    task.delay(duration, function()
        if not card.Parent then return end
        tween(card, 0.25, { BackgroundTransparency = 1 })
        tween(stroke, 0.25, { Transparency = 1 })
        tween(bar, 0.25, { BackgroundTransparency = 1 })
        tween(t1, 0.25, { TextTransparency = 1 })
        tween(t2, 0.25, { TextTransparency = 1 })
        task.wait(0.3)
        card:Destroy()
    end)
end

-- ========== TABS ==========
function Library:AddTab(name)
    local Tab = {}
    Tab.Library = self

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.SubText,
        Font = Theme.FontBold,
        TextSize = 13,
        AutoButtonColor = false,
        LayoutOrder = #self.Tabs + 1,
        Parent = self.Sidebar,
    }, { corner(8) })

    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.fromOffset(6, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = self.Content,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingRight = UDim.new(0, 6) }),
    })

    Tab.Button = button
    Tab.Page = page
    Tab.Order = 0

    local function nextOrder()
        Tab.Order += 1
        return Tab.Order
    end

    function Tab:Select()
        local lib = self.Library
        for _, t in ipairs(lib.Tabs) do
            t.Page.Visible = false
            tween(t.Button, 0.15, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
        end
        self.Page.Visible = true
        tween(self.Button, 0.15, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
        lib.ActiveTab = self
    end

    button.MouseButton1Click:Connect(function() Tab:Select() end)

    -- ----- Label -----
    function Tab:AddLabel(text)
        local lbl = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Theme.Font,
            TextSize = 13,
            TextWrapped = true,
            LayoutOrder = nextOrder(),
            Parent = page,
        })
        return {
            Set = function(_, newText) lbl.Text = newText end,
        }
    end

    -- ----- Section header -----
    function Tab:AddSection(text)
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = string.upper(text),
            TextColor3 = Theme.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Theme.FontBold,
            TextSize = 12,
            LayoutOrder = nextOrder(),
            Parent = page,
        })
    end

    -- ----- Button -----
    function Tab:AddButton(text, callback)
        local btn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = Theme.Element,
            Text = text,
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 14,
            AutoButtonColor = false,
            LayoutOrder = nextOrder(),
            Parent = page,
        }, { corner(8) })

        btn.MouseButton1Click:Connect(function()
            tween(btn, 0.1, { BackgroundColor3 = Theme.Accent })
            task.delay(0.15, function()
                if btn.Parent then tween(btn, 0.2, { BackgroundColor3 = Theme.Element }) end
            end)
            safeCall(callback)
        end)
    end

    -- ----- Toggle -----
    function Tab:AddToggle(text, default, callback)
        local state = default and true or false

        local row = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = Theme.Element,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = nextOrder(),
            Parent = page,
        }, { corner(8) })

        create("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Theme.Font,
            TextSize = 14,
            Parent = row,
        })

        local track = create("Frame", {
            Size = UDim2.fromOffset(46, 24),
            Position = UDim2.new(1, -58, 0.5, -12),
            BackgroundColor3 = state and Theme.Accent or Theme.Off,
            BorderSizePixel = 0,
            Parent = row,
        }, { corner(12) })

        local knob = create("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = track,
        }, { corner(9) })

        local api = {}

        local function render()
            tween(track, 0.15, { BackgroundColor3 = state and Theme.Accent or Theme.Off })
            tween(knob, 0.15, { Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) })
        end

        function api:Set(value, silent)
            state = value and true or false
            render()
            if not silent then safeCall(callback, state) end
        end

        function api:Get() return state end

        row.MouseButton1Click:Connect(function()
            api:Set(not state)
        end)

        if state then safeCall(callback, state) end
        return api
    end

    -- ----- Slider -----
    function Tab:AddSlider(text, min, max, default, callback)
        local value = math.clamp(default or min, min, max)

        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundColor3 = Theme.Element,
            LayoutOrder = nextOrder(),
            Parent = page,
        }, { corner(8) })

        create("TextLabel", {
            Size = UDim2.new(1, -70, 0, 24),
            Position = UDim2.fromOffset(12, 4),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Theme.Font,
            TextSize = 14,
            Parent = row,
        })

        local valueLabel = create("TextLabel", {
            Size = UDim2.fromOffset(56, 24),
            Position = UDim2.new(1, -66, 0, 4),
            BackgroundTransparency = 1,
            Text = tostring(value),
            TextColor3 = Theme.Accent,
            TextXAlignment = Enum.TextXAlignment.Right,
            Font = Theme.FontBold,
            TextSize = 14,
            Parent = row,
        })

        -- Taller invisible hit area for easy touch input
        local hit = create("TextButton", {
            Size = UDim2.new(1, -24, 0, 24),
            Position = UDim2.fromOffset(12, 28),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = row,
        })

        local bar = create("Frame", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 0.5, -3),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
            Parent = hit,
        }, { corner(3) })

        local fill = create("Frame", {
            Size = UDim2.fromScale((value - min) / (max - min), 1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = bar,
        }, { corner(3) })

        local knob = create("Frame", {
            Size = UDim2.fromOffset(16, 16),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = bar,
        }, { corner(8) })

        local api = {}
        local dragging = false

        local function setValue(v, silent)
            v = math.clamp(math.floor(v + 0.5), min, max)
            value = v
            local alpha = (v - min) / (max - min)
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            valueLabel.Text = tostring(v)
            if not silent then safeCall(callback, v) end
        end

        local function fromInput(input)
            local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            setValue(min + (max - min) * alpha)
        end

        hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromInput(input)
            end
        end)

        table.insert(self.Library.Connections, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                fromInput(input)
            end
        end))

        table.insert(self.Library.Connections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))

        function api:Set(v) setValue(v) end
        function api:Get() return value end
        return api
    end

    table.insert(self.Tabs, Tab)
    if #self.Tabs == 1 then Tab:Select() end
    return Tab
end

-- =====================================================================
--  DEMO / EXAMPLE USAGE  (safe, cosmetic and quality-of-life features)
-- =====================================================================
local Hub = Library.new("RYUZENX HUB  |  v1.0")

-- ----- HOME -----
local Home = Hub:AddTab("Home")
Home:AddSection("Welcome")
Home:AddLabel("Player: " .. LocalPlayer.DisplayName)
Home:AddLabel("Drag the title bar to move. Tap – to minimize.")
Home:AddButton("Test Notification", function()
    Hub:Notify("RYUZENX", "Notification system is working.", 3)
end)

-- ----- VISUALS -----
local Visuals = Hub:AddTab("Visuals")
Visuals:AddSection("Lighting")

local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
}

Visuals:AddToggle("Fullbright", false, function(on)
    if on then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    else
        for prop, val in pairs(originalLighting) do
            pcall(function() Lighting[prop] = val end)
        end
    end
    Hub:Notify("Fullbright", on and "Enabled" or "Disabled", 2)
end)

Visuals:AddToggle("Remove Fog", false, function(on)
    Lighting.FogEnd = on and 1e6 or originalLighting.FogEnd
end)

Visuals:AddSection("Camera")
local cam = Workspace.CurrentCamera
local originalFov = cam and cam.FieldOfView or 70
Visuals:AddSlider("Field of View", 40, 120, math.floor(originalFov), function(v)
    if cam then cam.FieldOfView = v end
end)

-- ----- UTILITY -----
local Utility = Hub:AddTab("Utility")
Utility:AddSection("Quality of life")

local antiAfkConn
Utility:AddToggle("Anti-AFK", false, function(on)
    if on then
        antiAfkConn = LocalPlayer.Idled:Connect(function()
            local ok = pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
            if not ok then warn("[RYUZENX] VirtualUser not available in this environment.") end
        end)
        Hub:Notify("Anti-AFK", "Enabled", 2)
    elseif antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
        Hub:Notify("Anti-AFK", "Disabled", 2)
    end
end)

Utility:AddButton("Rejoin Server", function()
    local TeleportService = game:GetService("TeleportService")
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end)

-- ----- SETTINGS -----
local Settings = Hub:AddTab("Settings")
Settings:AddSection("Interface")
Settings:AddButton("Destroy UI", function()
    Hub:Destroy()
end)

-- Restore anything we changed when the UI closes
Hub:OnClose(function()
    if antiAfkConn then antiAfkConn:Disconnect() end
    for prop, val in pairs(originalLighting) do
        pcall(function() Lighting[prop] = val end)
    end
    if cam then cam.FieldOfView = originalFov end
end)

Hub:Notify("RYUZENX HUB", "Loaded successfully.", 4)

return Library
