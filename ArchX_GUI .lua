--============================================================================--
--  ArchX GUI Framework (Full Standalone Lua / Luau Script)
--  Author: ZyrexScript
--  Note: Logo & Background Asset IDs are hardcoded below so end-users cannot
--        modify them through the in-game GUI.
--============================================================================--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--============================================================================--
-- 1. KONFIGURASI PATEN (Hanya bisa diubah di dalam source code ini)
--============================================================================--
local CONFIG = {
    Title        = "ArchX",
    Subtitle     = "ZyrexScript • discord.gg/zyrex",
    BackgroundID = "rbxassetid://136806144474646",
    LogoID       = "rbxassetid://111892209979191",
}

-- Hapus instance GUI lama jika script dijalankan ulang (anti-duplikat)
local GuiParent = (gethui and gethui()) or CoreGui
local ExistingGui = GuiParent:FindFirstChild("ArchX_MainGUI")
if ExistingGui then
    ExistingGui:Destroy()
end

--============================================================================--
-- 2. SISTEM RAINBOW GRID / BORDER (Berlaku untuk elemen GUI, KECUALI Logo)
--============================================================================--
local RainbowGradients = {}

local function ApplyRainbow(uiObject, thickness)
    if not uiObject then return end

    for _, child in ipairs(uiObject:GetChildren()) do
        if child:IsA("UIStroke") and child.Name == "ArchX_RainbowStroke" then
            child:Destroy()
        end
    end

    local stroke = Instance.new("UIStroke")
    stroke.Name = "ArchX_RainbowStroke"
    stroke.Thickness = thickness or 1.4
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Parent = uiObject

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 65, 65)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 190, 50)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 255, 120)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(50, 220, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(130, 100, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 80, 220)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 65, 65)),
    })
    gradient.Parent = stroke
    table.insert(RainbowGradients, gradient)
    return stroke
end

RunService.RenderStepped:Connect(function(dt)
    for i = #RainbowGradients, 1, -1 do
        local grad = RainbowGradients[i]
        if grad and grad.Parent then
            grad.Rotation = (grad.Rotation + (85 * dt)) % 360
        else
            table.remove(RainbowGradients, i)
        end
    end
end)

--============================================================================--
-- 3. CONTROLLER & STATE SESSION
--============================================================================--
local ArchX = {
    Stats = {
        StartClock = os.date("%H:%M:%S"),
        StartTick  = tick(),
        Caught     = 0,
        Sold       = 0,
    },
    Flags = {
        AntiAFK        = true,
        BlackScreenAFK = false,
        WebhookEnabled = false,
        WebhookURL     = "",
    },
    Callbacks = {
        OnTestWebhook = nil,
    }
}

--============================================================================--
-- 4. SCREEN GUI & SISTEM NOTIFIKASI MULTI-WARNA
--============================================================================--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ArchX_MainGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

local NotifHolder = Instance.new("Frame")
NotifHolder.Name = "Notifications"
NotifHolder.Size = UDim2.new(0, 300, 1, -24)
NotifHolder.Position = UDim2.new(1, -314, 0, 12)
NotifHolder.BackgroundTransparency = 1
NotifHolder.ZIndex = 200
NotifHolder.Parent = ScreenGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifLayout.Padding = UDim.new(0, 8)
NotifLayout.Parent = NotifHolder

local NOTIF_THEMES = {
    PET      = { Color = Color3.fromRGB(74, 222, 128),  Hex = "#4ADE80", Tag = "PET" },
    MUTATION = { Color = Color3.fromRGB(192, 132, 252), Hex = "#C084FC", Tag = "MUTATION" },
    CPS      = { Color = Color3.fromRGB(56, 189, 248),  Hex = "#38BDF8", Tag = "CPS" },
    INFO     = { Color = Color3.fromRGB(96, 165, 250),  Hex = "#60A5FA", Tag = "ARCHX" },
    WARN     = { Color = Color3.fromRGB(251, 146, 60),  Hex = "#FB923C", Tag = "WARNING" },
    ERROR    = { Color = Color3.fromRGB(248, 113, 113), Hex = "#F87171", Tag = "ALERT" },
}

function ArchX:Notify(category, title, richMessage, duration)
    local theme = NOTIF_THEMES[string.upper(category or "INFO")] or NOTIF_THEMES.INFO

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 58)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.ZIndex = 201
    card.Parent = NotifHolder
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    ApplyRainbow(card, 1.1)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = theme.Color
    accent.BorderSizePixel = 0
    accent.ZIndex = 202
    accent.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -18, 0, 20)
    titleLbl.Position = UDim2.new(0, 12, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.RichText = true
    titleLbl.Text = string.format(
        '<font color="%s"><b>[%s]</b></font> <font color="#FFFFFF"><b>%s</b></font>',
        theme.Hex,
        theme.Tag,
        tostring(title or "")
    )
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 202
    titleLbl.Parent = card

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -18, 0, 26)
    msgLbl.Position = UDim2.new(0, 12, 0, 25)
    msgLbl.BackgroundTransparency = 1
    msgLbl.RichText = true
    msgLbl.Text = tostring(richMessage or "")
    msgLbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextSize = 11
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.TextWrapped = true
    msgLbl.ZIndex = 202
    msgLbl.Parent = card

    task.delay(duration or 3.5, function()
        if card and card.Parent then
            local fade = TweenService:Create(
                card,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }
            )
            fade:Play()
            fade.Completed:Connect(function()
                if card then card:Destroy() end
            end)
        end
    end)
end

--============================================================================--
-- 5. MAIN WINDOW & HEADER (Background ID + Logo Kiri ArchX Tanpa Grid)
--============================================================================--
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 345)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -172)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.ZIndex = 1
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
ApplyRainbow(MainFrame, 2) -- Rainbow Grid pada bingkai utama GUI

-- Wallpaper Background Paten (ID: 136806144474646)
local Wallpaper = Instance.new("ImageLabel")
Wallpaper.Name = "Wallpaper"
Wallpaper.Size = UDim2.new(1, 0, 1, 0)
Wallpaper.BackgroundTransparency = 1
Wallpaper.BorderSizePixel = 0
Wallpaper.Image = CONFIG.BackgroundID
Wallpaper.ImageTransparency = 0.72
Wallpaper.ScaleType = Enum.ScaleType.Crop
Wallpaper.ZIndex = 1
Wallpaper.Parent = MainFrame

-- Overlay gelap tipis agar teks tetap tajam di atas wallpaper
local DarkTint = Instance.new("Frame")
DarkTint.Size = UDim2.new(1, 0, 1, 0)
DarkTint.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
DarkTint.BackgroundTransparency = 0.35
DarkTint.BorderSizePixel = 0
DarkTint.ZIndex = 2
DarkTint.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Header.BackgroundTransparency = 0.25
Header.BorderSizePixel = 0
Header.ZIndex = 3
Header.Parent = MainFrame

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HeaderLine.BackgroundTransparency = 0.85
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 4
HeaderLine.Parent = Header
ApplyRainbow(HeaderLine, 0.8)

-- Container Brand (Logo Bersih di Kiri + Tulisan ArchX)
local BrandBox = Instance.new("Frame")
BrandBox.Size = UDim2.new(0.72, 0, 1, 0)
BrandBox.Position = UDim2.new(0, 14, 0, 0)
BrandBox.BackgroundTransparency = 1
BrandBox.ZIndex = 4
BrandBox.Parent = Header

local BrandLayout = Instance.new("UIListLayout")
BrandLayout.FillDirection = Enum.FillDirection.Horizontal
BrandLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BrandLayout.Padding = UDim.new(0, 10)
BrandLayout.Parent = BrandBox

-- Logo di sebelah kiri tulisan ArchX (BERSIH: Tanpa grid / stroke merah)
local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Name = "HeaderLogo"
HeaderLogo.Size = UDim2.new(0, 30, 0, 30)
HeaderLogo.BackgroundTransparency = 1
HeaderLogo.BorderSizePixel = 0
HeaderLogo.Image = CONFIG.LogoID
HeaderLogo.ScaleType = Enum.ScaleType.Fit
HeaderLogo.ZIndex = 5
HeaderLogo.Parent = BrandBox

local TitleStack = Instance.new("Frame")
TitleStack.Size = UDim2.new(0, 300, 0, 34)
TitleStack.BackgroundTransparency = 1
TitleStack.ZIndex = 5
TitleStack.Parent = BrandBox

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 18)
TitleLabel.Position = UDim2.new(0, 0, 0, 1)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = CONFIG.Title
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 6
TitleLabel.Parent = TitleStack

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(1, 0, 0, 14)
SubTitleLabel.Position = UDim2.new(0, 0, 0, 19)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = CONFIG.Subtitle
SubTitleLabel.TextColor3 = Color3.fromRGB(170, 175, 190)
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextSize = 11
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.ZIndex = 6
SubTitleLabel.Parent = TitleStack

-- Tombol Minimize (-) & Close (X) -> Keduanya menyembunyikan GUI (bukan Destroy)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -72, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.ZIndex = 5
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)
ApplyRainbow(MinBtn, 1)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(42, 26, 32)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 105, 105)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.ZIndex = 5
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
ApplyRainbow(CloseBtn, 1)

local function HideMainGUI()
    MainFrame.Visible = false
end

MinBtn.MouseButton1Click:Connect(HideMainGUI)
CloseBtn.MouseButton1Click:Connect(HideMainGUI)

-- Dragging untuk Header MainFrame
do
    local winDragging, winStart, winPos = false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            winDragging = true
            winStart = input.Position
            winPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if winDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - winStart
            MainFrame.Position = UDim2.new(
                winPos.X.Scale,
                winPos.X.Offset + delta.X,
                winPos.Y.Scale,
                winPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            winDragging = false
        end
    end)
end

--============================================================================--
-- 6. LOGO DRAG MUNCUL DULUAN + ANIMASI REAKTIF (Tanpa Putar & Tanpa Grid)
--============================================================================--
local DragButton = Instance.new("ImageButton")
DragButton.Name = "ArchX_DragLogo"
DragButton.Size = UDim2.new(0, 54, 0, 54)
DragButton.Position = UDim2.new(0.04, 0, 0.22, 0)
DragButton.BackgroundTransparency = 1
DragButton.BorderSizePixel = 0
DragButton.Image = CONFIG.LogoID
DragButton.ScaleType = Enum.ScaleType.Fit
DragButton.ZIndex = 120
DragButton.Visible = true -- Langsung tampil sejak script dijalankan
DragButton.Parent = ScreenGui

local function PlayReactiveAnimation()
    -- Animasi pegas membal (Spring Bounce) tanpa memutar gambar
    local squash = TweenService:Create(
        DragButton,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 44, 0, 44) }
    )
    local spring = TweenService:Create(
        DragButton,
        TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 54, 0, 54) }
    )
    squash:Play()
    squash.Completed:Connect(function()
        spring:Play()
    end)

    -- Gelombang cahaya radial (Ripple Pulse) di belakang logo
    local ripple = Instance.new("Frame")
    ripple.Size = UDim2.new(0.65, 0, 0.65, 0)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.BackgroundColor3 = Color3.fromRGB(110, 205, 255)
    ripple.BackgroundTransparency = 0.42
    ripple.BorderSizePixel = 0
    ripple.ZIndex = 119
    ripple.Parent = DragButton
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)

    local wave = TweenService:Create(
        ripple,
        TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(1.65, 0, 1.65, 0), BackgroundTransparency = 1 }
    )
    wave:Play()
    wave.Completed:Connect(function()
        if ripple then ripple:Destroy() end
    end)
end

do
    local dragging, dragStart, startPos, movedDist = false, nil, nil, 0

    DragButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = DragButton.Position
            movedDist = 0
            TweenService:Create(DragButton, TweenInfo.new(0.08), { Size = UDim2.new(0, 48, 0, 48) }):Play()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            movedDist = delta.Magnitude
            DragButton.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            PlayReactiveAnimation()
            if movedDist < 8 then
                MainFrame.Visible = not MainFrame.Visible
            end
        end
    end)
end

--============================================================================--
-- 7. SIDEBAR NAVIGASI & PROFIL PLAYER
--============================================================================--
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -48)
Body.Position = UDim2.new(0, 0, 0, 48)
Body.BackgroundTransparency = 1
Body.ZIndex = 3
Body.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 158, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
Sidebar.BackgroundTransparency = 0.35
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 4
Sidebar.Parent = Body

local SideDivider = Instance.new("Frame")
SideDivider.Size = UDim2.new(0, 1, 1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 0)
SideDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SideDivider.BackgroundTransparency = 0.85
SideDivider.BorderSizePixel = 0
SideDivider.ZIndex = 5
SideDivider.Parent = Sidebar
ApplyRainbow(SideDivider, 0.8)

local TabListFrame = Instance.new("Frame")
TabListFrame.Size = UDim2.new(1, -16, 1, -68)
TabListFrame.Position = UDim2.new(0, 8, 0, 10)
TabListFrame.BackgroundTransparency = 1
TabListFrame.ZIndex = 5
TabListFrame.Parent = Sidebar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Padding = UDim.new(0, 6)
TabListLayout.Parent = TabListFrame

-- Kartu Profil Player di Pojok Kiri Bawah
local ProfileCard = Instance.new("Frame")
ProfileCard.Size = UDim2.new(1, -16, 0, 46)
ProfileCard.Position = UDim2.new(0, 8, 1, -54)
ProfileCard.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
ProfileCard.BackgroundTransparency = 0.2
ProfileCard.BorderSizePixel = 0
ProfileCard.ZIndex = 5
ProfileCard.Parent = Sidebar
Instance.new("UICorner", ProfileCard).CornerRadius = UDim.new(0, 8)
ApplyRainbow(ProfileCard, 1)

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 32, 0, 32)
AvatarImg.Position = UDim2.new(0, 7, 0.5, -16)
AvatarImg.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
AvatarImg.BorderSizePixel = 0
AvatarImg.ZIndex = 6
AvatarImg.Parent = ProfileCard
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    local ok, thumb = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size100x100
        )
    end)
    if ok and thumb then
        AvatarImg.Image = thumb
    end
end)

local DispName = Instance.new("TextLabel")
DispName.Size = UDim2.new(1, -48, 0, 16)
DispName.Position = UDim2.new(0, 44, 0, 7)
DispName.BackgroundTransparency = 1
DispName.Text = LocalPlayer.DisplayName
DispName.TextColor3 = Color3.fromRGB(255, 255, 255)
DispName.Font = Enum.Font.GothamBold
DispName.TextSize = 11
DispName.TextXAlignment = Enum.TextXAlignment.Left
DispName.TextTruncate = Enum.TextTruncate.AtEnd
DispName.ZIndex = 6
DispName.Parent = ProfileCard

local UserNameLbl = Instance.new("TextLabel")
UserNameLbl.Size = UDim2.new(1, -48, 0, 14)
UserNameLbl.Position = UDim2.new(0, 44, 0, 23)
UserNameLbl.BackgroundTransparency = 1
UserNameLbl.Text = "@" .. LocalPlayer.Name
UserNameLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
UserNameLbl.Font = Enum.Font.Gotham
UserNameLbl.TextSize = 10
UserNameLbl.TextXAlignment = Enum.TextXAlignment.Left
UserNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
UserNameLbl.ZIndex = 6
UserNameLbl.Parent = ProfileCard

-- Area Konten Tab Kanan
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -158, 1, 0)
ContentArea.Position = UDim2.new(0, 158, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 4
ContentArea.Parent = Body

local Tabs = {}
local ActiveTabName = nil

local function SelectTab(tabName)
    ActiveTabName = tabName
    for name, data in pairs(Tabs) do
        local isSelected = (name == tabName)
        data.Page.Visible = isSelected
        data.Indicator.Visible = isSelected
        data.Button.BackgroundTransparency = isSelected and 0.15 or 0.75
        data.Label.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 180, 195)
    end
end

local function CreateTab(name, iconText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 46)
    btn.BackgroundTransparency = 0.75
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 6
    btn.Parent = TabListFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    ApplyRainbow(btn, 0.9)

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0, 18)
    indicator.Position = UDim2.new(0, 4, 0.5, -9)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 85, 130)
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.ZIndex = 7
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -18, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("%s  %s", iconText, name)
    lbl.TextColor3 = Color3.fromRGB(175, 180, 195)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "_Page"
    page.Size = UDim2.new(1, -12, 1, -12)
    page.Position = UDim2.new(0, 6, 0, 6)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(140, 145, 165)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 5
    page.Parent = ContentArea

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = page

    Tabs[name] = {
        Button    = btn,
        Indicator = indicator,
        Label     = lbl,
        Page      = page,
    }

    btn.MouseButton1Click:Connect(function()
        SelectTab(name)
    end)

    return page
end

-- Helper Komponen UI Reusable
local function AddToggleCard(parent, title, desc, defaultState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 52)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0
    card.ZIndex = 6
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
    ApplyRainbow(card, 1)

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -74, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 7)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = title
    tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.ZIndex = 7
    tLbl.Parent = card

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -74, 0, 16)
    dLbl.Position = UDim2.new(0, 12, 0, 27)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Color3.fromRGB(165, 170, 185)
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 10
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.TextTruncate = Enum.TextTruncate.AtEnd
    dLbl.ZIndex = 7
    dLbl.Parent = card

    local state = defaultState or false
    local switchBg = Instance.new("TextButton")
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -56, 0.5, -11)
    switchBg.BackgroundColor3 = state and Color3.fromRGB(255, 75, 125) or Color3.fromRGB(55, 55, 70)
    switchBg.Text = ""
    switchBg.AutoButtonColor = false
    switchBg.ZIndex = 7
    switchBg.Parent = card
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 8
    knob.Parent = switchBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function SetState(val)
        state = val
        TweenService:Create(switchBg, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Color3.fromRGB(255, 75, 125) or Color3.fromRGB(55, 55, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        if callback then
            task.spawn(callback, state)
        end
    end

    switchBg.MouseButton1Click:Connect(function()
        SetState(not state)
    end)

    return { SetState = SetState, GetState = function() return state end }
end

local function AddButtonCard(parent, title, desc, btnLabel, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 52)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0
    card.ZIndex = 6
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
    ApplyRainbow(card, 1)

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -95, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 7)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = title
    tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.ZIndex = 7
    tLbl.Parent = card

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -95, 0, 16)
    dLbl.Position = UDim2.new(0, 12, 0, 27)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Color3.fromRGB(165, 170, 185)
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 10
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.ZIndex = 7
    dLbl.Parent = card

    local actionBtn = Instance.new("TextButton")
    actionBtn.Size = UDim2.new(0, 72, 0, 26)
    actionBtn.Position = UDim2.new(1, -84, 0.5, -13)
    actionBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    actionBtn.Text = btnLabel or "Run"
    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 11
    actionBtn.ZIndex = 7
    actionBtn.Parent = card
    Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)
    ApplyRainbow(actionBtn, 0.9)

    actionBtn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)

    return actionBtn
end

local function AddInputCard(parent, title, placeholder, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 62)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0
    card.ZIndex = 6
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
    ApplyRainbow(card, 1)

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -24, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 6)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = title
    tLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.ZIndex = 7
    tLbl.Parent = card

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 26)
    box.Position = UDim2.new(0, 12, 0, 28)
    box.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    box.Text = ""
    box.PlaceholderText = placeholder or ""
    box.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    box.TextColor3 = Color3.fromRGB(235, 240, 250)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.ZIndex = 7
    box.Parent = card
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = box

    box.FocusLost:Connect(function()
        if callback then task.spawn(callback, box.Text) end
    end)

    return box
end

--============================================================================--
-- 8. PEMBUATAN TAB & DASHBOARD MONITORING LENGKAP
--    (Tanpa Update Point Throw & Tanpa Input Logo/Background ID)
--============================================================================--
local AutoFarmPage = CreateTab("Auto Farm", "⚡")
local ShopPage     = CreateTab("Shop & Stand", "🛒")
local PlayerPage   = CreateTab("Player", "🏃")
local AFKStatsPage = CreateTab("AFK & Stats", "🛡️")

-- Tab: Auto Farm (Slot Siap Pakai)
AddToggleCard(AutoFarmPage, "Auto Collect & Farm", "Menjalankan siklus farming otomatis", false, function(on)
    ArchX:Notify("INFO", "Auto Farm", on and 'Status: <font color="#4ADE80"><b>AKTIF</b></font>' or 'Status: <font color="#F87171"><b>NONAKTIF</b></font>', 2.5)
end)

AddToggleCard(AutoFarmPage, "Auto Sell Inventory", "Menjual item otomatis saat tas penuh", false, function(on)
    ArchX:Notify("INFO", "Auto Sell", on and 'Auto Sell <font color="#4ADE80"><b>Diaktifkan</b></font>' or 'Auto Sell <font color="#F87171"><b>Dimatikan</b></font>', 2.5)
end)

-- Tab: Shop & Stand
AddButtonCard(ShopPage, "Claim Daily / Event Reward", "Mengambil hadiah harian yang tersedia", "Claim", function()
    ArchX:Notify("INFO", "Shop & Stand", 'Mengecek klaim hadiah tersedia...', 2.5)
end)

-- Tab: Player
AddToggleCard(PlayerPage, "Sprint Speed Boost (2x)", "Meningkatkan kecepatan jalan karakter", false, function(on)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = on and 32 or 16
    end
end)

--============================================================================--
-- Tab: AFK & Stats -> DASHBOARD MONITORING + ANTI-AFK + HEMAT DAYA
--============================================================================--
local DashboardCard = Instance.new("Frame")
DashboardCard.Name = "SessionMonitoringDashboard"
DashboardCard.Size = UDim2.new(1, -10, 0, 142)
DashboardCard.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
DashboardCard.BackgroundTransparency = 0.14
DashboardCard.BorderSizePixel = 0
DashboardCard.ZIndex = 6
DashboardCard.Parent = AFKStatsPage
Instance.new("UICorner", DashboardCard).CornerRadius = UDim.new(0, 10)
ApplyRainbow(DashboardCard, 1.3)

local DashHeader = Instance.new("TextLabel")
DashHeader.Size = UDim2.new(1, -20, 0, 24)
DashHeader.Position = UDim2.new(0, 12, 0, 6)
DashHeader.BackgroundTransparency = 1
DashHeader.Text = "📊 Session Monitoring Dashboard"
DashHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
DashHeader.Font = Enum.Font.GothamBold
DashHeader.TextSize = 13
DashHeader.TextXAlignment = Enum.TextXAlignment.Left
DashHeader.ZIndex = 7
DashHeader.Parent = DashboardCard

local DashGrid = Instance.new("Frame")
DashGrid.Size = UDim2.new(1, -20, 1, -36)
DashGrid.Position = UDim2.new(0, 10, 0, 30)
DashGrid.BackgroundTransparency = 1
DashGrid.ZIndex = 7
DashGrid.Parent = DashboardCard

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0.485, 0, 0.46, 0)
GridLayout.CellPadding = UDim2.new(0.03, 0, 0.08, 0)
GridLayout.Parent = DashGrid

local function CreateStatBox(labelText, defaultColor)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    box.BackgroundTransparency = 0.15
    box.BorderSizePixel = 0
    box.ZIndex = 8
    box.Parent = DashGrid
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 0, 15)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(170, 175, 195)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 9
    lbl.Parent = box

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -14, 0, 20)
    val.Position = UDim2.new(0, 8, 0, 19)
    val.BackgroundTransparency = 1
    val.Text = "..."
    val.TextColor3 = defaultColor
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.TextTruncate = Enum.TextTruncate.AtEnd
    val.ZIndex = 9
    val.Parent = box

    return val
end

local TimeValueLbl   = CreateStatBox("🕒 Mulai & Durasi", Color3.fromRGB(56, 189, 248))
local PetValueLbl    = CreateStatBox("🐾 Pet Ditangkap", Color3.fromRGB(74, 222, 128))
local PingValueLbl   = CreateStatBox("📶 Koneksi (Ping)", Color3.fromRGB(250, 204, 21))
local PlayerValueLbl = CreateStatBox("👥 Player di Server", Color3.fromRGB(192, 132, 252))

-- Helper Publik untuk Menambah Counter Pet
function ArchX:AddCaught(count)
    ArchX.Stats.Caught = ArchX.Stats.Caught + (count or 1)
end

function ArchX:AddSold(count)
    ArchX.Stats.Sold = ArchX.Stats.Sold + (count or 1)
end

-- Loop Pembaruan Dashboard Real-Time
task.spawn(function()
    while DashboardCard and DashboardCard.Parent do
        local elapsed = math.floor(tick() - ArchX.Stats.StartTick)
        local hrs = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        TimeValueLbl.Text = string.format("%s (%02d:%02d:%02d)", ArchX.Stats.StartClock, hrs, mins, secs)

        PetValueLbl.Text = string.format("%d Caught • %d Sold", ArchX.Stats.Caught, ArchX.Stats.Sold)

        local pingMs = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        PingValueLbl.Text = string.format("%d ms", pingMs)
        if pingMs < 110 then
            PingValueLbl.TextColor3 = Color3.fromRGB(74, 222, 128)
        elseif pingMs < 220 then
            PingValueLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
        else
            PingValueLbl.TextColor3 = Color3.fromRGB(248, 113, 113)
        end

        local totalPlayers = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        PlayerValueLbl.Text = string.format("%d / %d Orang", totalPlayers, maxPlayers)

        task.wait(1)
    end
end)

-- Built-in Anti-AFK
LocalPlayer.Idled:Connect(function()
    if ArchX.Flags.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

AddToggleCard(AFKStatsPage, "Built-in Anti-AFK", "Mencegah terputus dari server saat diam", true, function(on)
    ArchX.Flags.AntiAFK = on
end)

-- Mode Hemat Daya Layar Hitam
local BlackOverlay = Instance.new("TextButton")
BlackOverlay.Name = "PowerSaverOverlay"
BlackOverlay.Size = UDim2.new(1, 0, 1, 0)
BlackOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackOverlay.Text = "Mode Hemat Daya Aktif
(Ketuk layar di mana saja untuk kembali)"
BlackOverlay.TextColor3 = Color3.fromRGB(160, 165, 180)
BlackOverlay.Font = Enum.Font.GothamMedium
BlackOverlay.TextSize = 14
BlackOverlay.Visible = false
BlackOverlay.ZIndex = 190
BlackOverlay.Parent = ScreenGui

local PowerSaverToggle = AddToggleCard(AFKStatsPage, "Mode Hemat Daya Layar Hitam", "Menutup layar saat AFK (ketuk layar untuk kembali)", false, function(on)
    ArchX.Flags.BlackScreenAFK = on
    BlackOverlay.Visible = on
end)

BlackOverlay.MouseButton1Click:Connect(function()
    BlackOverlay.Visible = false
    PowerSaverToggle.SetState(false)
end)

-- Discord Webhook Controls
AddInputCard(AFKStatsPage, "Discord Webhook URL", "Paste https://discord.com/api/webhooks/...", function(txt)
    ArchX.Flags.WebhookURL = txt
end)

AddToggleCard(AFKStatsPage, "Enable Discord Webhook", "Kirim laporan tangkapan ke Discord", false, function(on)
    ArchX.Flags.WebhookEnabled = on
end)

AddButtonCard(AFKStatsPage, "Test Discord Webhook", "Kirim pesan uji coba ke webhook Anda", "Test", function()
    if ArchX.Flags.WebhookURL == "" then
        ArchX:Notify("WARN", "Webhook Kosong", 'Masukkan URL <font color="#FB923C"><b>Discord Webhook</b></font> terlebih dahulu.', 3)
        return
    end
    if ArchX.Callbacks.OnTestWebhook then
        ArchX.Callbacks.OnTestWebhook(ArchX.Flags.WebhookURL)
    end
    ArchX:Notify("INFO", "Webhook Test", 'Pesan uji coba dikirim ke <font color="#38BDF8"><b>Discord</b></font>.', 3)
end)

-- Buka Tab AFK & Stats secara default agar dashboard langsung terlihat
SelectTab("AFK & Stats")

-- Notifikasi Pembuka Multi-Warna
ArchX:Notify(
    "INFO",
    "ArchX Loaded",
    'UI siap! <font color="#38BDF8"><b>Drag Logo</b></font> aktif & <font color="#C084FC"><b>Rainbow Grid</b></font> terpasang.',
    4
)

return ArchX
