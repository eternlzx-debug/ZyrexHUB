--[[
    ============================================================================
    ArchX Hub | Throw a Seed (v3.1 - High-Contrast Mobile & PC Edition)
    Author: RyuzenX (@RyzureX)
    Architecture: Single-File Modular (CONFIG, Theme, Janitor, Util, Data, SeedManager, UI)
    Fix Log (v3.1):
      - Replaced CanvasGroup with native Frame + UIStroke + UIScale to eliminate
        mobile downscaling blur and stuck semi-transparent overlays.
      - Upgraded to High-Contrast Obsidian & Electric Amethyst palette (97% opaque
        panels, elevated card layers, crisp pure-white primary text, bright
        lavender secondary text, and glowing 1.4px borders).
      - Added live Background Opacity & UI Scale controls in Config tab.
    ============================================================================
]]

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Cleanup Existing Instance (Safe Re-execution)
local HUB_GUI_NAME = "ArchX_ThrowASeed_Hub_v31"
pcall(function()
    if CoreGui:FindFirstChild(HUB_GUI_NAME) then
        CoreGui:FindFirstChild(HUB_GUI_NAME):Destroy()
    end
end)
pcall(function()
    if PlayerGui:FindFirstChild(HUB_GUI_NAME) then
        PlayerGui:FindFirstChild(HUB_GUI_NAME):Destroy()
    end
end)

-- ============================================================================
-- MODULE 1: CONFIG
-- ============================================================================
local CONFIG = {
    HubName = "ArchX Hub",
    GameTitle = "Throw a Seed",
    Version = "v3.1",
    LogoAsset = "rbxassetid://111892209979191",
    BgAsset = "rbxassetid://136806144474646",

    -- Visual & Performance Defaults (High Clarity)
    UIScale = 1.0,
    AnimSpeed = 0.16,
    PanelOpacity = 0.97, -- 0.97 = BackgroundTransparency 0.03 (Crisp & Solid)
    NeonBorders = true,

    -- Automation States
    AutoThrow = false,
    AutoAim = true,
    AutoCollect = false,
    AutoTrack = false,
    AutoSellMany = false,
    AutoTrain = false,
    AutoXPBoost = false,
    AutoRequest = false,
    AntiAFK = true,

    -- Timings & Movement
    ThrowDelay = 0.25,
    CollectDelay = 0.35,
    SellDelay = 3.0,
    TrainDelay = 0.20,
    SelectedSeed = "CloudSeed",
    WalkSpeed = 24,
    JumpPower = 55,
    CustomMoveEnabled = false,
}

-- ============================================================================
-- MODULE 2: THEME (HIGH-CONTRAST OBSIDIAN & ELECTRIC PURPLE)
-- ============================================================================
local Theme = {
    -- Layered Solid Surfaces (High separation so cards never blend into dark bg)
    MainBg = Color3.fromRGB(16, 15, 25),         -- Deep Obsidian Indigo
    SidebarBg = Color3.fromRGB(22, 20, 35),      -- Distinct Sidebar Panel
    HeaderBg = Color3.fromRGB(24, 22, 38),       -- Top Bar Surface
    CardBg = Color3.fromRGB(30, 28, 48),         -- Elevated Card Container
    CardAltBg = Color3.fromRGB(38, 35, 60),      -- Interactive Control Surface
    InputBg = Color3.fromRGB(20, 18, 32),        -- Recessed Input / Track

    -- Crisp Borders & Accents
    Accent = Color3.fromRGB(148, 92, 255),       -- Electric Amethyst
    AccentBright = Color3.fromRGB(182, 138, 255),-- Highlight Lavender
    AccentDark = Color3.fromRGB(88, 50, 168),    -- Muted Purple Pill Fill
    StrokeMain = Color3.fromRGB(148, 92, 255),   -- Window Outline
    StrokeCard = Color3.fromRGB(76, 68, 118),    -- Clear Card Separator

    -- High-Legibility Typography (Always TextTransparency = 0)
    TextPrimary = Color3.fromRGB(252, 252, 255),   -- Pure Crisp White
    TextSecondary = Color3.fromRGB(198, 195, 224), -- Bright Silver-Lavender
    TextMuted = Color3.fromRGB(152, 148, 182),     -- Readable Caption Grey

    -- Status Indicators
    Success = Color3.fromRGB(52, 211, 153),      -- Emerald Green
    Warning = Color3.fromRGB(251, 191, 36),      -- Amber Gold
    Danger = Color3.fromRGB(248, 113, 113),      -- Coral Red
}

-- ============================================================================
-- MODULE 3: JANITOR (LIFECYCLE & MEMORY CLEANUP)
-- ============================================================================
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({ _tasks = {} }, Janitor)
end

function Janitor:Add(taskObj, methodName)
    table.insert(self._tasks, { obj = taskObj, method = methodName })
    return taskObj
end

function Janitor:Connect(signal, callback)
    local conn = signal:Connect(callback)
    self:Add(conn, "Disconnect")
    return conn
end

function Janitor:Cleanup()
    for i = #self._tasks, 1, -1 do
        local item = self._tasks[i]
        pcall(function()
            if typeof(item.obj) == "RBXScriptConnection" then
                if item.obj.Connected then item.obj:Disconnect() end
            elseif type(item.obj) == "function" then
                item.obj()
            elseif item.method and item.obj[item.method] then
                item.obj[item.method](item.obj)
            elseif item.obj.Destroy then
                item.obj:Destroy()
            end
        end)
        self._tasks[i] = nil
    end
end

local HubJanitor = Janitor.new()

-- ============================================================================
-- MODULE 4: UTIL (UI BUILDERS, TWEENS, DRAGGING, REMOTE RESOLVER)
-- ============================================================================
local Util = {}

function Util.Create(className, props, children)
    local inst = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                inst[k] = v
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

function Util.AddCorner(parent, radius)
    return Util.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

function Util.AddStroke(parent, color, thickness, transparency)
    return Util.Create("UIStroke", {
        Color = color or Theme.StrokeCard,
        Thickness = thickness or 1.2,
        Transparency = transparency or 0.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

function Util.AddPadding(parent, top, bottom, left, right)
    return Util.Create("UIPadding", {
        PaddingTop = UDim.new(0, top or 8),
        PaddingBottom = UDim.new(0, bottom or top or 8),
        PaddingLeft = UDim.new(0, left or top or 10),
        PaddingRight = UDim.new(0, right or left or top or 10),
        Parent = parent
    })
end

function Util.Tween(obj, duration, props, style, dir)
    local info = TweenInfo.new(
        duration or CONFIG.AnimSpeed,
        style or Enum.EasingStyle.Quart,
        dir or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

-- Cross-Platform Draggable Handler (Supports Touch & Mouse cleanly)
function Util.MakeDraggable(dragHandle, targetFrame, onClickCallback)
    local dragging = false
    local dragStart, startPos
    local movedDistance = 0

    HubJanitor:Connect(dragHandle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDistance = 0
        end
    end)

    HubJanitor:Connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            movedDistance = delta.Magnitude
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    HubJanitor:Connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if movedDistance < 8 and onClickCallback then
                onClickCallback()
            end
        end
    end)
end

-- ============================================================================
-- MODULE 5: DATA & REMOTE LAYER
-- ============================================================================
local Data = {
    Remotes = {},
    RemoteNames = {
        "Aim",
        "Throw",
        "Collect",
        "Track",
        "Request",
        "XPBoost",
        "StopTrain",
        "SellMany"
    },
    SessionStats = {
        StartTime = os.clock(),
        ThrowsCount = 0,
        CollectsCount = 0,
        SellsCount = 0,
        RemoteCalls = 0,
    },
    RemoteLogs = {}
}

function Data.LogRemote(remoteName, direction, payloadStr)
    Data.SessionStats.RemoteCalls += 1
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] %s -> %s (%s)", timestamp, direction, remoteName, payloadStr or "nil")
    table.insert(Data.RemoteLogs, 1, entry)
    if #Data.RemoteLogs > 45 then
        table.remove(Data.RemoteLogs)
    end
end

function Data.ScanRemotes()
    table.clear(Data.Remotes)
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            Data.Remotes[desc.Name] = desc
        end
    end
    return Data.Remotes
end

function Data.FireRemote(name, ...)
    local args = { ... }
    local remote = Data.Remotes[name] or ReplicatedStorage:FindFirstChild(name, true)
    if not remote then
        Data.LogRemote(name, "MISS", "Remote not found in ReplicatedStorage")
        return false, "Not found"
    end

    Data.Remotes[name] = remote
    local argPreview = #args > 0 and tostring(args[1]) or "no-args"

    local ok, res = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
            return true
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpack(args))
        end
    end)

    if ok then
        Data.LogRemote(name, "FIRE", argPreview)
    else
        Data.LogRemote(name, "ERR", tostring(res))
    end
    return ok, res
end

function Data.GetPlayerStats()
    local stats = {
        Coins = "0",
        Power = "0",
        Seeds = "0",
        Rebirths = "0"
    }

    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, val in ipairs(ls:GetChildren()) do
            if val:IsA("ValueBase") then
                local lower = string.lower(val.Name)
                if string.find(lower, "coin") or string.find(lower, "cash") or string.find(lower, "money") then
                    stats.Coins = tostring(val.Value)
                elseif string.find(lower, "power") or string.find(lower, "strength") or string.find(lower, "force") then
                    stats.Power = tostring(val.Value)
                elseif string.find(lower, "seed") or string.find(lower, "throw") then
                    stats.Seeds = tostring(val.Value)
                elseif string.find(lower, "rebirth") or string.find(lower, "prestige") then
                    stats.Rebirths = tostring(val.Value)
                end
            end
        end
    end

    -- Fallback attribute check
    for attrName, attrVal in pairs(LocalPlayer:GetAttributes()) do
        local lower = string.lower(attrName)
        if string.find(lower, "coin") or string.find(lower, "cash") then
            stats.Coins = tostring(attrVal)
        elseif string.find(lower, "power") or string.find(lower, "strength") then
            stats.Power = tostring(attrVal)
        end
    end

    return stats
end

Data.ScanRemotes()

-- ============================================================================
-- MODULE 6: SEED MANAGER (PHASE 3 - 14 SEED MODELS DATABASE & INSPECTOR)
-- ============================================================================
local SeedManager = {
    Database = {
        { Name = "BasicSeed",   Tier = "Common",    Multiplier = "1.0x", Color = Color3.fromRGB(185, 195, 210) },
        { Name = "SproutSeed",  Tier = "Common",    Multiplier = "1.2x", Color = Color3.fromRGB(134, 239, 172) },
        { Name = "CloudSeed",   Tier = "Rare",      Multiplier = "1.8x", Color = Color3.fromRGB(125, 211, 252) },
        { Name = "AquaSeed",    Tier = "Rare",      Multiplier = "2.1x", Color = Color3.fromRGB(56, 189, 248) },
        { Name = "BlossomSeed", Tier = "Rare",      Multiplier = "2.5x", Color = Color3.fromRGB(244, 114, 182) },
        { Name = "EmberSeed",   Tier = "Epic",      Multiplier = "3.2x", Color = Color3.fromRGB(251, 146, 60) },
        { Name = "VoltSeed",    Tier = "Epic",      Multiplier = "3.8x", Color = Color3.fromRGB(250, 204, 21) },
        { Name = "FrostSeed",   Tier = "Epic",      Multiplier = "4.4x", Color = Color3.fromRGB(103, 232, 249) },
        { Name = "CrystalSeed", Tier = "Legendary", Multiplier = "5.5x", Color = Color3.fromRGB(192, 132, 252) },
        { Name = "ShadowSeed",  Tier = "Legendary", Multiplier = "6.8x", Color = Color3.fromRGB(167, 139, 250) },
        { Name = "SolarSeed",   Tier = "Mythic",    Multiplier = "8.5x", Color = Color3.fromRGB(253, 224, 71) },
        { Name = "LunarSeed",   Tier = "Mythic",    Multiplier = "9.2x", Color = Color3.fromRGB(165, 180, 252) },
        { Name = "NovaSeed",    Tier = "Secret",    Multiplier = "12.0x",Color = Color3.fromRGB(244, 63, 94) },
        { Name = "DivineSeed",  Tier = "Secret",    Multiplier = "15.0x",Color = Color3.fromRGB(255, 255, 255) },
    }
}

function SeedManager.GetSeedInfo(seedName)
    for _, item in ipairs(SeedManager.Database) do
        if item.Name == seedName then
            return item
        end
    end
    return SeedManager.Database[3] -- Default CloudSeed
end

function SeedManager.InspectActiveSeeds()
    local found = {}
    local containers = { workspace, LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }

    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("Tool") or obj:IsA("BasePart"))
                    and string.find(string.lower(obj.Name), "seed") then
                    local attrCount = 0
                    for _ in pairs(obj:GetAttributes()) do attrCount += 1 end
                    table.insert(found, {
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Parent = obj.Parent and obj.Parent.Name or "nil",
                        Attributes = attrCount
                    })
                    if #found >= 20 then break end
                end
            end
        end
    end
    return found
end

-- ============================================================================
-- MODULE 7: HIGH-CONTRAST UI ENGINE (NATIVE FRAME + UISCALE)
-- ============================================================================
local UI = {
    IsOpen = false,
    ActiveTab = "ActionCenter",
    Pages = {},
    NavButtons = {},
    BorderStrokes = {},
    SurfaceFrames = {},
}

local ScreenGui = Util.Create("ScreenGui", {
    Name = HUB_GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true
})

local protectedOk = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not protectedOk then
    ScreenGui.Parent = PlayerGui
end
HubJanitor:Add(ScreenGui, "Destroy")

--// Floating Toggle Button (Top-Left / Draggable)
local ToggleBtn = Util.Create("TextButton", {
    Name = "ArchX_FloatingToggle",
    Size = UDim2.new(0, 48, 0, 48),
    Position = UDim2.new(0, 16, 0, 82),
    BackgroundColor3 = Theme.MainBg,
    BackgroundTransparency = 0.04,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 50,
    Parent = ScreenGui
})
Util.AddCorner(ToggleBtn, 12)
local ToggleStroke = Util.AddStroke(ToggleBtn, Theme.AccentBright, 1.8, 0.05)

local ToggleLogo = Util.Create("ImageLabel", {
    Size = UDim2.new(0, 34, 0, 34),
    Position = UDim2.new(0.5, -17, 0.5, -17),
    BackgroundTransparency = 1,
    Image = CONFIG.LogoAsset,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 51,
    Parent = ToggleBtn
})

--// Main Hub Window (Native Frame - NO CanvasGroup dimming!)
local DefaultWindowPos = UDim2.new(0.5, -285, 0.5, -185)
local MainFrame = Util.Create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 570, 0, 370),
    Position = DefaultWindowPos,
    BackgroundColor3 = Theme.MainBg,
    BackgroundTransparency = 1 - CONFIG.PanelOpacity, -- 0.03 (Crisp & Dark-Solid)
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 10,
    Parent = ScreenGui
})
Util.AddCorner(MainFrame, 14)
local MainStroke = Util.AddStroke(MainFrame, Theme.StrokeMain, 1.6, 0.12)
table.insert(UI.BorderStrokes, MainStroke)
table.insert(UI.SurfaceFrames, MainFrame)

-- Subtle Dark Purple Watermark Wallpaper (Low opacity so text stays 100% readable)
local Wallpaper = Util.Create("ImageLabel", {
    Name = "Wallpaper",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image = CONFIG.BgAsset,
    ImageColor3 = Color3.fromRGB(120, 80, 210),
    ImageTransparency = 0.90, -- Very subtle texture, zero interference with text
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 10,
    Parent = MainFrame
})
Util.AddCorner(Wallpaper, 14)

-- UIScale for Crisp Responsive Sizing
local MainUIScale = Util.Create("UIScale", {
    Scale = CONFIG.UIScale,
    Parent = MainFrame
})

--// Top Header Bar
local HeaderBar = Util.Create("Frame", {
    Name = "HeaderBar",
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Theme.HeaderBg,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = MainFrame
})
Util.AddCorner(HeaderBar, 14)

-- Bottom square cover for HeaderBar
Util.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Theme.HeaderBg,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ZIndex = 12,
    Parent = HeaderBar
})

-- Header Divider Line
Util.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Theme.StrokeCard,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 14,
    Parent = HeaderBar
})

local HeaderLogo = Util.Create("ImageLabel", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(0, 12, 0.5, -14),
    BackgroundTransparency = 1,
    Image = CONFIG.LogoAsset,
    ZIndex = 13,
    Parent = HeaderBar
})

local HeaderTitle = Util.Create("TextLabel", {
    Size = UDim2.new(0, 110, 1, 0),
    Position = UDim2.new(0, 46, 0, 0),
    BackgroundTransparency = 1,
    Text = CONFIG.HubName,
    TextColor3 = Theme.TextPrimary,
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 13,
    Parent = HeaderBar
})

local GameBadge = Util.Create("TextLabel", {
    Size = UDim2.new(0, 132, 0, 22),
    Position = UDim2.new(0, 142, 0.5, -11),
    BackgroundColor3 = Theme.AccentDark,
    BackgroundTransparency = 0.15,
    Text = "THROW A SEED • " .. CONFIG.Version,
    TextColor3 = Theme.TextPrimary,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    ZIndex = 13,
    Parent = HeaderBar
})
Util.AddCorner(GameBadge, 6)
Util.AddStroke(GameBadge, Theme.AccentBright, 1, 0.35)

-- Live White FPS / MS Status Monitor
local PerfLabel = Util.Create("TextLabel", {
    Name = "PerfLabel",
    Size = UDim2.new(0, 115, 0, 22),
    Position = UDim2.new(1, -195, 0.5, -11),
    BackgroundColor3 = Theme.InputBg,
    BackgroundTransparency = 0.1,
    Text = "60 FPS  |  45 ms",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 11,
    Font = Enum.Font.GothamSemibold,
    ZIndex = 13,
    Parent = HeaderBar
})
Util.AddCorner(PerfLabel, 6)
Util.AddStroke(PerfLabel, Theme.StrokeCard, 1, 0.35)

-- Header Window Controls (Minimize & Close)
local MinBtn = Util.Create("TextButton", {
    Size = UDim2.new(0, 28, 0, 26),
    Position = UDim2.new(1, -68, 0.5, -13),
    BackgroundColor3 = Theme.CardAltBg,
    Text = "—",
    TextColor3 = Theme.TextPrimary,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    ZIndex = 14,
    Parent = HeaderBar
})
Util.AddCorner(MinBtn, 6)

local CloseBtn = Util.Create("TextButton", {
    Size = UDim2.new(0, 28, 0, 26),
    Position = UDim2.new(1, -35, 0.5, -13),
    BackgroundColor3 = Color3.fromRGB(145, 42, 62),
    Text = "×",
    TextColor3 = Theme.TextPrimary,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    ZIndex = 14,
    Parent = HeaderBar
})
Util.AddCorner(CloseBtn, 6)

--// Left Navigation Sidebar
local Sidebar = Util.Create("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 148, 1, -46),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundColor3 = Theme.SidebarBg,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ZIndex = 11,
    Parent = MainFrame
})
Util.AddPadding(Sidebar, 10, 10, 8, 8)

-- Sidebar Right Divider
Util.Create("Frame", {
    Size = UDim2.new(0, 1, 1, -46),
    Position = UDim2.new(0, 148, 0, 46),
    BackgroundColor3 = Theme.StrokeCard,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 13,
    Parent = MainFrame
})

local SidebarList = Util.Create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Sidebar
})

--// Right Content Container
local ContentArea = Util.Create("Frame", {
    Name = "ContentArea",
    Size = UDim2.new(1, -150, 1, -46),
    Position = UDim2.new(0, 150, 0, 46),
    BackgroundTransparency = 1,
    ZIndex = 11,
    Parent = MainFrame
})

-- ============================================================================
-- UI COMPONENT BUILDERS (HIGH CONTRAST CARDS, TOGGLES, SLIDERS, BUTTONS)
-- ============================================================================
function UI.CreatePage(tabId)
    local scroll = Util.Create("ScrollingFrame", {
        Name = tabId .. "_Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.AccentBright,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 12,
        Parent = ContentArea
    })
    Util.AddPadding(scroll, 12, 16, 12, 14)

    Util.Create("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll
    })

    UI.Pages[tabId] = scroll
    return scroll
end

function UI.AddBannerHeader(parent, title, subtitle, badgeText)
    local banner = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0,
        ZIndex = 13,
        Parent = parent
    })
    Util.AddCorner(banner, 10)
    local st = Util.AddStroke(banner, Theme.Accent, 1.3, 0.25)
    table.insert(UI.BorderStrokes, st)

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -95, 0, 22),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = banner
    })

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -95, 0, 18),
        Position = UDim2.new(0, 12, 0, 31),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = banner
    })

    if badgeText then
        local pill = Util.Create("TextLabel", {
            Size = UDim2.new(0, 72, 0, 24),
            Position = UDim2.new(1, -84, 0.5, -12),
            BackgroundColor3 = Theme.AccentDark,
            Text = badgeText,
            TextColor3 = Theme.TextPrimary,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            ZIndex = 14,
            Parent = banner
        })
        Util.AddCorner(pill, 6)
        Util.AddStroke(pill, Theme.AccentBright, 1, 0.25)
    end
end

function UI.AddSectionLabel(parent, text)
    return Util.Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = Theme.AccentBright,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
        Parent = parent
    })
end

function UI.AddToggle(parent, title, desc, defaultVal, callback)
    local state = defaultVal or false

    local card = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0,
        ZIndex = 13,
        Parent = parent
    })
    Util.AddCorner(card, 9)
    local stroke = Util.AddStroke(card, state and Theme.Accent or Theme.StrokeCard, 1.2, state and 0.2 or 0.35)

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 20),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = card
    })

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -74, 0, 16),
        Position = UDim2.new(0, 12, 0, 28),
        BackgroundTransparency = 1,
        Text = desc,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = card
    })

    local switchTrack = Util.Create("TextButton", {
        Size = UDim2.new(0, 46, 0, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = state and Theme.Accent or Theme.InputBg,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
        Parent = card
    })
    Util.AddCorner(switchTrack, 12)
    Util.AddStroke(switchTrack, state and Theme.AccentBright or Theme.StrokeCard, 1.2, 0.2)

    local knob = Util.Create("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 15,
        Parent = switchTrack
    })
    Util.AddCorner(knob, 9)

    local function setState(newVal)
        state = newVal
        Util.Tween(switchTrack, 0.14, {
            BackgroundColor3 = state and Theme.Accent or Theme.InputBg
        })
        Util.Tween(knob, 0.14, {
            Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        })
        stroke.Color = state and Theme.Accent or Theme.StrokeCard
        stroke.Transparency = state and 0.15 or 0.35
        if callback then callback(state) end
    end

    HubJanitor:Connect(switchTrack.MouseButton1Click, function()
        setState(not state)
    end)

    return { Set = setState, Get = function() return state end }
end

function UI.AddSlider(parent, title, desc, minVal, maxVal, defaultVal, decimals, suffix, callback)
    local currentVal = math.clamp(defaultVal, minVal, maxVal)
    local fmt = "%." .. tostring(decimals or 1) .. "f" .. (suffix or "")

    local card = Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0,
        ZIndex = 13,
        Parent = parent
    })
    Util.AddCorner(card, 9)
    Util.AddStroke(card, Theme.StrokeCard, 1.2, 0.3)

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 20),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = card
    })

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -80, 0, 16),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = desc,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = card
    })

    local valLabel = Util.Create("TextLabel", {
        Size = UDim2.new(0, 62, 0, 22),
        Position = UDim2.new(1, -74, 0, 10),
        BackgroundColor3 = Theme.InputBg,
        Text = string.format(fmt, currentVal),
        TextColor3 = Theme.AccentBright,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ZIndex = 14,
        Parent = card
    })
    Util.AddCorner(valLabel, 6)
    Util.AddStroke(valLabel, Theme.Accent, 1, 0.35)

    local track = Util.Create("TextButton", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 50),
        BackgroundColor3 = Theme.InputBg,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
        Parent = card
    })
    Util.AddCorner(track, 4)
    Util.AddStroke(track, Theme.StrokeCard, 1, 0.35)

    local pct = (currentVal - minVal) / (maxVal - minVal)
    local fill = Util.Create("Frame", {
        Size = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 15,
        Parent = track
    })
    Util.AddCorner(fill, 4)

    local thumb = Util.Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(pct, -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 16,
        Parent = track
    })
    Util.AddCorner(thumb, 7)
    Util.AddStroke(thumb, Theme.Accent, 1.5, 0)

    local sliding = false
    local function updateFromInput(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local raw = minVal + (maxVal - minVal) * relX
        local mult = 10 ^ (decimals or 1)
        currentVal = math.floor(raw * mult + 0.5) / mult

        fill.Size = UDim2.new(relX, 0, 1, 0)
        thumb.Position = UDim2.new(relX, -7, 0.5, -7)
        valLabel.Text = string.format(fmt, currentVal)
        if callback then callback(currentVal) end
    end

    HubJanitor:Connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromInput(input.Position)
        end
    end)

    HubJanitor:Connect(UserInputService.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position)
        end
    end)

    HubJanitor:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    return {
        Set = function(v)
            currentVal = math.clamp(v, minVal, maxVal)
            local r = (currentVal - minVal) / (maxVal - minVal)
            fill.Size = UDim2.new(r, 0, 1, 0)
            thumb.Position = UDim2.new(r, -7, 0.5, -7)
            valLabel.Text = string.format(fmt, currentVal)
        end
    }
end

function UI.AddButton(parent, title, accentColor, callback)
    local btn = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = accentColor or Theme.CardAltBg,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        ZIndex = 13,
        Parent = parent
    })
    Util.AddCorner(btn, 8)
    Util.AddStroke(btn, Theme.AccentBright, 1.2, 0.3)

    HubJanitor:Connect(btn.MouseButton1Click, function()
        Util.Tween(btn, 0.08, { BackgroundTransparency = 0.25 })
        task.delay(0.09, function()
            if btn and btn.Parent then
                Util.Tween(btn, 0.1, { BackgroundTransparency = 0 })
            end
        end)
        if callback then callback() end
    end)

    return btn
end

-- ============================================================================
-- SIDEBAR NAVIGATION & TAB SWITCHING
-- ============================================================================
function UI.SelectTab(tabId)
    UI.ActiveTab = tabId
    for id, page in pairs(UI.Pages) do
        page.Visible = (id == tabId)
    end
    for id, nav in pairs(UI.NavButtons) do
        local isSelected = (id == tabId)
        Util.Tween(nav.Btn, 0.14, {
            BackgroundColor3 = isSelected and Theme.AccentDark or Theme.CardBg,
            BackgroundTransparency = isSelected and 0 or 0.35
        })
        nav.Label.TextColor3 = isSelected and Theme.TextPrimary or Theme.TextSecondary
        nav.Indicator.Visible = isSelected
        nav.Stroke.Color = isSelected and Theme.AccentBright or Theme.StrokeCard
        nav.Stroke.Transparency = isSelected and 0.15 or 0.55
    end
end

function UI.AddNavTab(tabId, labelText, iconGlyph)
    local btn = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0.35,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 13,
        Parent = Sidebar
    })
    Util.AddCorner(btn, 8)
    local stroke = Util.AddStroke(btn, Theme.StrokeCard, 1.1, 0.55)

    local indicator = Util.Create("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 3, 0.5, -10),
        BackgroundColor3 = Theme.AccentBright,
        Visible = false,
        ZIndex = 15,
        Parent = btn
    })
    Util.AddCorner(indicator, 2)

    local icon = Util.Create("TextLabel", {
        Size = UDim2.new(0, 22, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = iconGlyph,
        TextColor3 = Theme.AccentBright,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        ZIndex = 14,
        Parent = btn
    })

    local lbl = Util.Create("TextLabel", {
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Theme.TextSecondary,
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = btn
    })

    UI.NavButtons[tabId] = {
        Btn = btn,
        Label = lbl,
        Indicator = indicator,
        Stroke = stroke
    }

    HubJanitor:Connect(btn.MouseButton1Click, function()
        UI.SelectTab(tabId)
    end)
end

-- Create All 5 Tabs
UI.AddNavTab("ActionCenter", "Action Center", "⚡")
UI.AddNavTab("Training",     "Training",      "💪")
UI.AddNavTab("SeedManager",  "Seed Manager",  "🌱")
UI.AddNavTab("Inspector",    "Inspector",     "🔍")
UI.AddNavTab("Config",       "Config",        "⚙️")

-- ============================================================================
-- TAB 1: ACTION CENTER (DASHBOARD & CORE AUTOMATION)
-- ============================================================================
local PageAction = UI.CreatePage("ActionCenter")
UI.AddBannerHeader(PageAction, "Action Center & Telemetry", "Live player metrics and core throw automation", "ACTIVE")

-- Live Stats Grid (2x2 High-Contrast Cards)
local StatsGrid = Util.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundTransparency = 1,
    ZIndex = 13,
    Parent = PageAction
})
Util.Create("UIGridLayout", {
    CellSize = UDim2.new(0.485, 0, 0, 44),
    CellPadding = UDim2.new(0.03, 0, 0, 8),
    Parent = StatsGrid
})

local function MakeStatTile(title, initialVal, accentCol)
    local tile = Util.Create("Frame", {
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 0,
        ZIndex = 13,
        Parent = StatsGrid
    })
    Util.AddCorner(tile, 8)
    Util.AddStroke(tile, Theme.StrokeCard, 1.1, 0.35)

    Util.Create("TextLabel", {
        Size = UDim2.new(1, -16, 0, 15),
        Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextSecondary,
        TextSize = 10,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = tile
    })

    local valLbl = Util.Create("TextLabel", {
        Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.new(0, 10, 0, 20),
        BackgroundTransparency = 1,
        Text = initialVal,
        TextColor3 = accentCol or Theme.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
        Parent = tile
    })
    return valLbl
end

local StatCoinsLbl = MakeStatTile("COINS / CASH", "0", Theme.Success)
local StatPowerLbl = MakeStatTile("POWER / STRENGTH", "0", Theme.AccentBright)
local StatThrowsLbl = MakeStatTile("SESSION THROWS", "0", Theme.TextPrimary)
local StatUptimeLbl = MakeStatTile("SESSION UPTIME", "00:00", Theme.Warning)

UI.AddSectionLabel(PageAction, "Core Automation")

UI.AddToggle(PageAction, "Auto Aim & Throw Seed", "Fires Aim & Throw remotes with active seed", CONFIG.AutoThrow, function(v)
    CONFIG.AutoThrow = v
end)

UI.AddToggle(PageAction, "Auto Collect Drops", "Continuously triggers Collect remote for nearby drops", CONFIG.AutoCollect, function(v)
    CONFIG.AutoCollect = v
end)

UI.AddToggle(PageAction, "Auto Track Target", "Keeps Track remote locked onto optimal throw trajectory", CONFIG.AutoTrack, function(v)
    CONFIG.AutoTrack = v
end)

UI.AddToggle(PageAction, "Auto Sell Many", "Periodically fires SellMany remote to convert stock", CONFIG.AutoSellMany, function(v)
    CONFIG.AutoSellMany = v
end)

UI.AddSlider(PageAction, "Throw Loop Interval", "Delay between automatic Aim + Throw cycles", 0.05, 1.50, CONFIG.ThrowDelay, 2, "s", function(v)
    CONFIG.ThrowDelay = v
end)

-- ============================================================================
-- TAB 2: TRAINING ASSISTANT
-- ============================================================================
local PageTrain = UI.CreatePage("Training")
UI.AddBannerHeader(PageTrain, "Training Assistant", "Power gain routines, XP boosts, and movement", "TRAIN")

UI.AddSectionLabel(PageTrain, "Power & Boost Routines")

UI.AddToggle(PageTrain, "Auto Power Train", "Runs automated training cycles for strength gain", CONFIG.AutoTrain, function(v)
    CONFIG.AutoTrain = v
    if not v then
        Data.FireRemote("StopTrain")
    end
end)

UI.AddToggle(PageTrain, "Auto XP Boost", "Triggers XPBoost remote when available", CONFIG.AutoXPBoost, function(v)
    CONFIG.AutoXPBoost = v
end)

UI.AddToggle(PageTrain, "Auto Request Rewards", "Claims milestone/quest packets via Request remote", CONFIG.AutoRequest, function(v)
    CONFIG.AutoRequest = v
end)

UI.AddButton(PageTrain, "Force Stop Training (StopTrain Remote)", Theme.AccentDark, function()
    CONFIG.AutoTrain = false
    Data.FireRemote("StopTrain")
end)

UI.AddSectionLabel(PageTrain, "Player Mobility & Anti-AFK")

UI.AddToggle(PageTrain, "Custom Movement Override", "Applies WalkSpeed & JumpPower smoothly", CONFIG.CustomMoveEnabled, function(v)
    CONFIG.CustomMoveEnabled = v
end)

UI.AddSlider(PageTrain, "WalkSpeed", "Character movement speed on ground", 16, 120, CONFIG.WalkSpeed, 0, "", function(v)
    CONFIG.WalkSpeed = v
end)

UI.AddSlider(PageTrain, "JumpPower", "Vertical jump impulse strength", 50, 200, CONFIG.JumpPower, 0, "", function(v)
    CONFIG.JumpPower = v
end)

-- ============================================================================
-- TAB 3: SEED MANAGER (PHASE 3 - 14 SEED MODELS)
-- ============================================================================
local PageSeed = UI.CreatePage("SeedManager")
UI.AddBannerHeader(PageSeed, "Seed Manager (Phase 3)", "14-Seed database selector and workspace inspector", "14 SEEDS")

-- Active Seed Highlight Card
local ActiveSeedCard = Util.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = Theme.CardAltBg,
    ZIndex = 13,
    Parent = PageSeed
})
Util.AddCorner(ActiveSeedCard, 9)
Util.AddStroke(ActiveSeedCard, Theme.AccentBright, 1.3, 0.2)

local ActiveSeedText = Util.Create("TextLabel", {
    Size = UDim2.new(1, -24, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Selected Target Seed: CloudSeed  [Rare • 1.8x]",
    TextColor3 = Theme.TextPrimary,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 14,
    Parent = ActiveSeedCard
})

UI.AddSectionLabel(PageSeed, "Select Seed Model (14 Models)")

-- Grid of 14 Seeds
local SeedGrid = Util.Create("Frame", {
    Size = UDim2.new(1, 0, 0, 266),
    BackgroundTransparency = 1,
    ZIndex = 13,
    Parent = PageSeed
})
Util.Create("UIGridLayout", {
    CellSize = UDim2.new(0.485, 0, 0, 32),
    CellPadding = UDim2.new(0.03, 0, 0, 6),
    Parent = SeedGrid
})

local SeedButtons = {}
for _, seedData in ipairs(SeedManager.Database) do
    local isCurrent = (seedData.Name == CONFIG.SelectedSeed)
    local sBtn = Util.Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = isCurrent and Theme.AccentDark or Theme.CardBg,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 14,
        Parent = SeedGrid
    })
    Util.AddCorner(sBtn, 7)
    local sStroke = Util.AddStroke(sBtn, isCurrent and Theme.AccentBright or Theme.StrokeCard, 1.1, isCurrent and 0.15 or 0.4)

    Util.Create("TextLabel", {
        Size = UDim2.new(0.65, 0, 1, 0),
        Position = UDim2.new(0, 9, 0, 0),
        BackgroundTransparency = 1,
        Text = seedData.Name,
        TextColor3 = Theme.TextPrimary,
        TextSize = 11,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15,
        Parent = sBtn
    })

    Util.Create("TextLabel", {
        Size = UDim2.new(0.32, -8, 1, 0),
        Position = UDim2.new(0.68, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = seedData.Multiplier,
        TextColor3 = seedData.Color,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 15,
        Parent = sBtn
    })

    SeedButtons[seedData.Name] = { Btn = sBtn, Stroke = sStroke }

    HubJanitor:Connect(sBtn.MouseButton1Click, function()
        CONFIG.SelectedSeed = seedData.Name
        ActiveSeedText.Text = string.format("Selected Target Seed: %s  [%s • %s]", seedData.Name, seedData.Tier, seedData.Multiplier)
        for name, item in pairs(SeedButtons) do
            local sel = (name == seedData.Name)
            item.Btn.BackgroundColor3 = sel and Theme.AccentDark or Theme.CardBg
            item.Stroke.Color = sel and Theme.AccentBright or Theme.StrokeCard
            item.Stroke.Transparency = sel and 0.15 or 0.4
        end
    end)
end

UI.AddSectionLabel(PageSeed, "Live Workspace Seed Inspector")

local SeedInspectBox = Util.Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 74),
    BackgroundColor3 = Theme.InputBg,
    Text = "Click 'Scan Active Seed Models' to inspect live instances & attributes.",
    TextColor3 = Theme.TextSecondary,
    TextSize = 11,
    Font = Enum.Font.Code,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 13,
    Parent = PageSeed
})
Util.AddCorner(SeedInspectBox, 8)
Util.AddStroke(SeedInspectBox, Theme.StrokeCard, 1.1, 0.35)
Util.AddPadding(SeedInspectBox, 8, 8, 10, 10)

UI.AddButton(PageSeed, "Scan Active Seed Models", Theme.AccentDark, function()
    local items = SeedManager.InspectActiveSeeds()
    if #items == 0 then
        SeedInspectBox.Text = "[Scanner] No active 'Seed' objects found in Workspace/Backpack right now."
    else
        local lines = { string.format("[Scanner] Found %d seed objects:", #items) }
        for i = 1, math.min(4, #items) do
            local it = items[i]
            table.insert(lines, string.format("• %s (%s) in %s | Attrs: %d", it.Name, it.Class, it.Parent, it.Attributes))
        end
        SeedInspectBox.Text = table.concat(lines, "\n")
    end
end)

-- ============================================================================
-- TAB 4: REMOTE INSPECTOR
-- ============================================================================
local PageInspector = UI.CreatePage("Inspector")
UI.AddBannerHeader(PageInspector, "Remote Inspector", "Verify and test documented game remotes", "REMOTES")

local RemoteStatusBox = Util.Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 130),
    BackgroundColor3 = Theme.InputBg,
    Text = "Initializing remote scan...",
    TextColor3 = Theme.TextPrimary,
    TextSize = 11,
    Font = Enum.Font.Code,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 13,
    Parent = PageInspector
})
Util.AddCorner(RemoteStatusBox, 8)
Util.AddStroke(RemoteStatusBox, Theme.StrokeCard, 1.1, 0.3)
Util.AddPadding(RemoteStatusBox, 8, 8, 10, 10)

local function RefreshRemoteBox()
    Data.ScanRemotes()
    local lines = { "=== DOCUMENTED REMOTES STATUS ===" }
    for _, rName in ipairs(Data.RemoteNames) do
        local found = Data.Remotes[rName]
        local status = found and ("OK (" .. found.ClassName .. ")") or "PENDING"
        table.insert(lines, string.format("• %-10s : %s", rName, status))
    end
    if #Data.RemoteLogs > 0 then
        table.insert(lines, "\n=== RECENT TRAFFIC ===")
        for i = 1, math.min(3, #Data.RemoteLogs) do
            table.insert(lines, Data.RemoteLogs[i])
        end
    end
    RemoteStatusBox.Text = table.concat(lines, "\n")
end

UI.AddButton(PageInspector, "Re-Scan ReplicatedStorage Remotes", Theme.AccentDark, function()
    RefreshRemoteBox()
end)

UI.AddButton(PageInspector, "Test Fire Aim + Throw (Selected Seed)", Theme.CardAltBg, function()
    Data.FireRemote("Aim", CONFIG.SelectedSeed)
    Data.FireRemote("Throw", CONFIG.SelectedSeed)
    RefreshRemoteBox()
end)

-- ============================================================================
-- TAB 5: CONFIG (INTERFACE & CONFIG SETTINGS - HIGH CLARITY FIX)
-- ============================================================================
local PageConfig = UI.CreatePage("Config")
UI.AddBannerHeader(PageConfig, "Interface & Config Settings", "Customize UI scale, opacity, and animation timing", "CONFIG")

UI.AddSectionLabel(PageConfig, "Visual & Performance")

UI.AddSlider(PageConfig, "UI Scale", "Adjust the overall size of the hub window", 0.75, 1.35, CONFIG.UIScale, 2, "x", function(v)
    CONFIG.UIScale = v
    MainUIScale.Scale = v
end)

UI.AddSlider(PageConfig, "Animation Speed", "Control open/close and tab transition smoothness", 0.05, 0.40, CONFIG.AnimSpeed, 2, "s", function(v)
    CONFIG.AnimSpeed = v
end)

UI.AddSlider(PageConfig, "Panel Opacity", "Increase solidity so background map never bleeds through", 0.85, 1.00, CONFIG.PanelOpacity, 2, "", function(v)
    CONFIG.PanelOpacity = v
    MainFrame.BackgroundTransparency = math.clamp(1 - v, 0, 0.15)
end)

UI.AddToggle(PageConfig, "High-Contrast Neon Borders", "Highlights active panels with crisp amethyst outlines", CONFIG.NeonBorders, function(v)
    CONFIG.NeonBorders = v
    for _, st in ipairs(UI.BorderStrokes) do
        if st and st.Parent then
            st.Transparency = v and 0.15 or 0.65
        end
    end
end)

UI.AddSectionLabel(PageConfig, "Hub Management")

UI.AddButton(PageConfig, "Center Window Position", Theme.CardAltBg, function()
    Util.Tween(MainFrame, 0.2, { Position = DefaultWindowPos })
end)

UI.AddButton(PageConfig, "Unload & Destroy ArchX Hub", Color3.fromRGB(135, 38, 56), function()
    HubJanitor:Cleanup()
end)

-- ============================================================================
-- OPEN / CLOSE ANIMATION (CRISP SCALE POP - ZERO STUCK TRANSPARENCY)
-- ============================================================================
function UI.SetOpen(openState)
    UI.IsOpen = openState
    if openState then
        MainFrame.Visible = true
        MainFrame.BackgroundTransparency = math.clamp(1 - CONFIG.PanelOpacity, 0, 0.15)
        MainUIScale.Scale = CONFIG.UIScale * 0.90
        Util.Tween(MainUIScale, CONFIG.AnimSpeed, { Scale = CONFIG.UIScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        local tw = Util.Tween(MainUIScale, CONFIG.AnimSpeed * 0.85, { Scale = CONFIG.UIScale * 0.90 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tw.Completed:Once(function()
            if not UI.IsOpen and MainFrame and MainFrame.Parent then
                MainFrame.Visible = false
            end
        end)
    end
end

Util.MakeDraggable(ToggleBtn, ToggleBtn, function()
    UI.SetOpen(not UI.IsOpen)
end)

Util.MakeDraggable(HeaderBar, MainFrame, nil)

HubJanitor:Connect(MinBtn.MouseButton1Click, function()
    UI.SetOpen(false)
end)

HubJanitor:Connect(CloseBtn.MouseButton1Click, function()
    UI.SetOpen(false)
end)

-- ============================================================================
-- BACKGROUND RUNTIME LOOPS (FPS/MS, TELEMETRY, SAFE AUTOMATION)
-- ============================================================================
-- Live FPS & Ping Counter
local frameCount = 0
local lastFpsUpdate = os.clock()
HubJanitor:Connect(RunService.RenderStepped, function()
    frameCount += 1
    local now = os.clock()
    if now - lastFpsUpdate >= 0.5 then
        local fps = math.floor(frameCount / (now - lastFpsUpdate) + 0.5)
        local ping = 0
        pcall(function()
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
        end)
        PerfLabel.Text = string.format("%d FPS  |  %d ms", fps, ping)
        frameCount = 0
        lastFpsUpdate = now
    end
end)

-- Anti-AFK
HubJanitor:Connect(LocalPlayer.Idled, function()
    if CONFIG.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Telemetry & Movement Loop
local alive = true
HubJanitor:Add(function() alive = false end)

task.spawn(function()
    while alive do
        if UI.IsOpen then
            local stats = Data.GetPlayerStats()
            StatCoinsLbl.Text = stats.Coins
            StatPowerLbl.Text = stats.Power
            StatThrowsLbl.Text = tostring(Data.SessionStats.ThrowsCount)

            local elapsed = math.floor(os.clock() - Data.SessionStats.StartTime)
            StatUptimeLbl.Text = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
        end

        if CONFIG.CustomMoveEnabled and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = CONFIG.WalkSpeed
                hum.JumpPower = CONFIG.JumpPower
            end
        end
        task.wait(0.35)
    end
end)

-- Auto Throw Loop
task.spawn(function()
    while alive do
        if CONFIG.AutoThrow then
            if CONFIG.AutoAim then
                Data.FireRemote("Aim", CONFIG.SelectedSeed)
            end
            local ok = Data.FireRemote("Throw", CONFIG.SelectedSeed)
            if ok then
                Data.SessionStats.ThrowsCount += 1
            end
            task.wait(CONFIG.ThrowDelay)
        else
            task.wait(0.2)
        end
    end
end)

-- Auto Collect & Track Loop
task.spawn(function()
    while alive do
        if CONFIG.AutoTrack then
            Data.FireRemote("Track", CONFIG.SelectedSeed)
        end
        if CONFIG.AutoCollect then
            local ok = Data.FireRemote("Collect")
            if ok then
                Data.SessionStats.CollectsCount += 1
            end
            task.wait(CONFIG.CollectDelay)
        else
            task.wait(0.25)
        end
    end
end)

-- Auto Train / Boost / Request Loop
task.spawn(function()
    while alive do
        if CONFIG.AutoTrain then
            Data.FireRemote("Request", "Train")
        end
        if CONFIG.AutoXPBoost then
            Data.FireRemote("XPBoost")
        end
        if CONFIG.AutoRequest then
            Data.FireRemote("Request")
        end
        task.wait(CONFIG.TrainDelay)
    end
end)

-- Auto Sell Many Loop
task.spawn(function()
    while alive do
        if CONFIG.AutoSellMany then
            local ok = Data.FireRemote("SellMany")
            if ok then
                Data.SessionStats.SellsCount += 1
            end
            task.wait(CONFIG.SellDelay)
        else
            task.wait(0.5)
        end
    end
end)

-- Initialize Default State
RefreshRemoteBox()
UI.SelectTab("ActionCenter")
UI.SetOpen(true)
