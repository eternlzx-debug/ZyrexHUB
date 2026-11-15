-- Survive Your Ideas | ArchX Hub V5 (Sidebar + Rainbow + Anti-Spam Hit)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- State Konfigurasi
local State = {
    antiBackTP = true,
    walkSpeedEnabled = false,
    walkSpeedValue = 50,
    jumpPowerEnabled = false,
    jumpPowerValue = 100,
    fly = false,
    flySpeed = 65,
    noclip = false,
    antiRagdoll = false,
    antiDie = false,
    godMode = false,
    antiSpamHit = true, -- Auto-evade saat kena hit ke-1 agar hit ke-2 miss
    espEnabled = false,
    savedCFrame = nil,
    preSkyCFrame = nil,
    playerIndex = 1
}

local lastSafeCFrame = nil
local originalCollisions = {}
local espFolder = nil
local skyPlatform = nil
local flyBV, flyBG
local currentTpId = 0
local isTeleporting = false
local rainbowTargets = {}
local activeCharConns = {}

-- Tema Warna ArchX (Dark Purple Obsidian - Konsisten dengan Throw Food For Pet)
local Theme = {
    BgMain = Color3.fromRGB(18, 15, 24),
    BgSidebar = Color3.fromRGB(22, 18, 29),
    BgCard = Color3.fromRGB(28, 23, 35),
    BgSubCard = Color3.fromRGB(24, 20, 31),
    Accent = Color3.fromRGB(175, 95, 255),
    AccentDark = Color3.fromRGB(95, 52, 145),
    TextPrimary = Color3.fromRGB(245, 242, 250),
    TextMuted = Color3.fromRGB(172, 165, 188)
}

-- Bersihkan instance lama jika script dijalankan ulang
local guiParent = (gethui and gethui()) or CoreGui
if guiParent:FindFirstChild("SYI_ArchXHub") then
    guiParent.SYI_ArchXHub:Destroy()
end
if workspace:FindFirstChild("SYI_SkyPlatform") then
    workspace.SYI_SkyPlatform:Destroy()
end

-- Fungsi ApplyRainbow (UIStroke + UIGradient Dinamis)
local function ApplyRainbow(instance, thickness, transparency)
    if not instance then return end
    local stroke = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    stroke.Thickness = thickness or 1.4
    stroke.Transparency = transparency or 0.15
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = instance

    local grad = stroke:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 85, 130)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 195, 75)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(85, 245, 175)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 175, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(210, 105, 255))
    })
    grad.Parent = stroke
    table.insert(rainbowTargets, grad)
    return stroke, grad
end

-- Helper Character
local function getCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hum, hrp
end

-- Setup ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SYI_ArchXHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

-- ==========================================
-- ARCHX FLOATING TOGGLE BUTTON (SPRING + RIPPLE)
-- ==========================================
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "ArchXFloatingBtn"
FloatingBtn.Size = UDim2.new(0, 48, 0, 48)
FloatingBtn.Position = UDim2.new(0, 16, 0.25, 0)
FloatingBtn.BackgroundColor3 = Theme.BgCard
FloatingBtn.BackgroundTransparency = 0.08
FloatingBtn.Text = ""
FloatingBtn.AutoButtonColor = false
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.ClipsDescendants = true
FloatingBtn.ZIndex = 20
FloatingBtn.Parent = ScreenGui
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(0, 14)
ApplyRainbow(FloatingBtn, 1.5, 0.2)

local FloatLogo = Instance.new("TextLabel")
FloatLogo.Size = UDim2.new(1, 0, 1, 0)
FloatLogo.BackgroundTransparency = 1
FloatLogo.Text = "AX"
FloatLogo.TextColor3 = Theme.TextPrimary
FloatLogo.Font = Enum.Font.GothamBlack
FloatLogo.TextSize = 16
FloatLogo.ZIndex = 22
FloatLogo.Parent = FloatingBtn

local function playFloatingReaction()
    -- Animasi pegas (spring bounce)
    TweenService:Create(FloatingBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 42, 0, 42)
    }):Play()
    task.delay(0.08, function()
        if FloatingBtn and FloatingBtn.Parent then
            TweenService:Create(FloatingBtn, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 48, 0, 48)
            }):Play()
        end
    end)

    -- Efek ripple lembut
    local ripple = Instance.new("Frame")
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.Size = UDim2.new(0, 6, 0, 6)
    ripple.BackgroundColor3 = Theme.Accent
    ripple.BackgroundTransparency = 0.45
    ripple.ZIndex = 21
    ripple.Parent = FloatingBtn
    Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)

    local tween = TweenService:Create(ripple, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 68, 0, 68),
        BackgroundTransparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function()
        if ripple then ripple:Destroy() end
    end)
end

-- ==========================================
-- MAIN WINDOW ARCHX (SIDEBAR KIRI + KONTEN KANAN)
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "ArchXMain"
MainFrame.Size = UDim2.new(0, 390, 0, 265)
MainFrame.Position = UDim2.new(0.5, -195, 0.22, 0)
MainFrame.BackgroundColor3 = Theme.BgMain
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
ApplyRainbow(MainFrame, 1.6, 0.15)

-- Header Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Theme.BgSidebar
Header.BackgroundTransparency = 0.1
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local BrandTitle = Instance.new("TextLabel")
BrandTitle.Size = UDim2.new(1, -90, 1, 0)
BrandTitle.Position = UDim2.new(0, 12, 0, 0)
BrandTitle.BackgroundTransparency = 1
BrandTitle.Text = "ArchX  •  Survive Your Ideas"
BrandTitle.TextColor3 = Theme.TextPrimary
BrandTitle.Font = Enum.Font.GothamBold
BrandTitle.TextSize = 12
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
BrandTitle.Parent = Header

local HideBtn = Instance.new("TextButton")
HideBtn.Size = UDim2.new(0, 24, 0, 24)
HideBtn.Position = UDim2.new(1, -56, 0, 5)
HideBtn.BackgroundColor3 = Theme.BgCard
HideBtn.Text = "-"
HideBtn.TextColor3 = Theme.TextPrimary
HideBtn.Font = Enum.Font.GothamBold
HideBtn.TextSize = 14
HideBtn.Parent = Header
Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(165, 45, 65)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Theme.TextPrimary
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Toggle Visibility dari Floating Button & Tombol '-'
FloatingBtn.MouseButton1Click:Connect(function()
    playFloatingReaction()
    MainFrame.Visible = not MainFrame.Visible
end)

HideBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Sidebar Navigasi Kiri
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 108, 1, -42)
Sidebar.Position = UDim2.new(0, 6, 0, 38)
Sidebar.BackgroundColor3 = Theme.BgSidebar
Sidebar.BackgroundTransparency = 0.15
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 9)

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, 5)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 6)
SidePad.PaddingLeft = UDim.new(0, 6)
SidePad.PaddingRight = UDim.new(0, 6)
SidePad.Parent = Sidebar

-- Area Konten Kanan
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -124, 1, -42)
ContentArea.Position = UDim2.new(0, 118, 0, 38)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Sistem Tab Navigasi
local tabs = {}
local tabButtons = {}

local function switchTab(tabName)
    for name, page in pairs(tabs) do
        page.Visible = (name == tabName)
    end
    for name, info in pairs(tabButtons) do
        local isSel = (name == tabName)
        info.btn.BackgroundColor3 = isSel and Theme.BgCard or Theme.BgSubCard
        info.btn.TextColor3 = isSel and Theme.TextPrimary or Theme.TextMuted
        info.stroke.Enabled = isSel
    end
end

local function createTab(tabName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Theme.BgSubCard
    btn.BackgroundTransparency = 0.08
    btn.Text = tabName
    btn.TextColor3 = Theme.TextMuted
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local stroke = ApplyRainbow(btn, 1.2, 0.15)
    stroke.Enabled = false

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.Parent = ContentArea

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = page

    tabs[tabName] = page
    tabButtons[tabName] = {btn = btn, stroke = stroke}

    btn.MouseButton1Click:Connect(function()
        switchTab(tabName)
    end)

    return page
end

-- Komponen UI Card di Dalam Tab (BgCard + Rainbow Stroke)
local function createToggle(parentPage, text, defaultActive, callback)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, -2, 0, 33)
    card.BackgroundColor3 = Theme.BgCard
    card.BackgroundTransparency = 0.08
    card.Text = text
    card.TextColor3 = Theme.TextPrimary
    card.Font = Enum.Font.GothamSemibold
    card.TextSize = 11
    card.TextXAlignment = Enum.TextXAlignment.Left
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 38, 0, 19)
    badge.Position = UDim2.new(1, -38, 0.5, -9)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    badge.TextColor3 = Theme.TextPrimary
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

    local stroke = ApplyRainbow(card, 1.1, 0.2)

    local active = defaultActive or false
    local function updateVisual()
        badge.Text = active and "ON" or "OFF"
        badge.BackgroundColor3 = active and Theme.AccentDark or Color3.fromRGB(44, 38, 56)
        stroke.Enabled = active
    end
    updateVisual()

    card.MouseButton1Click:Connect(function()
        active = not active
        updateVisual()
        callback(active, card)
    end)
    return card
end

local function createAdjuster(parentPage, label, defaultVal, minVal, maxVal, step, onChange)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -2, 0, 29)
    frame.BackgroundColor3 = Theme.BgSubCard
    frame.BackgroundTransparency = 0.1
    frame.Parent = parentPage
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local val = defaultVal
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.58, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(val)
    lbl.TextColor3 = Theme.TextMuted
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 32, 0, 21)
    minus.Position = UDim2.new(1, -72, 0, 4)
    minus.BackgroundColor3 = Theme.BgCard
    minus.Text = "-"
    minus.TextColor3 = Theme.TextPrimary
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 13
    minus.Parent = frame
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 5)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 32, 0, 21)
    plus.Position = UDim2.new(1, -36, 0, 4)
    plus.BackgroundColor3 = Theme.AccentDark
    plus.Text = "+"
    plus.TextColor3 = Theme.TextPrimary
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 13
    plus.Parent = frame
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 5)

    minus.MouseButton1Click:Connect(function()
        val = math.max(minVal, val - step)
        lbl.Text = label .. ": " .. tostring(val)
        onChange(val)
    end)

    plus.MouseButton1Click:Connect(function()
        val = math.min(maxVal, val + step)
        lbl.Text = label .. ": " .. tostring(val)
        onChange(val)
    end)
end

local function createActionButton(parentPage, text, withRainbow, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -2, 0, 33)
    btn.BackgroundColor3 = Theme.BgCard
    btn.BackgroundTransparency = 0.08
    btn.Text = text
    btn.TextColor3 = Theme.TextPrimary
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.Parent = parentPage
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    if withRainbow then
        ApplyRainbow(btn, 1.1, 0.25)
    end

    btn.MouseButton1Click:Connect(function()
        callback(btn)
    end)
    return btn
end

-- ==========================================
-- LOGIKA NOCLIP (ANTI-SINK & ANTI-FLING)
-- ==========================================
local function applyNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if originalCollisions[part] == nil then
                originalCollisions[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
end

local function disableNoclip()
    local char, hum, hrp = getCharParts()
    if hrp and char then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local origin = hrp.Position + Vector3.new(0, 4, 0)
        local result = workspace:Raycast(origin, Vector3.new(0, -8, 0), rayParams)
        local hipOffset = (hum and hum.HipHeight or 2) + (hrp.Size.Y * 0.5)

        if result and (hrp.Position.Y - result.Position.Y) < hipOffset then
            local rotOnly = hrp.CFrame - hrp.CFrame.Position
            hrp.CFrame = CFrame.new(hrp.Position.X, result.Position.Y + hipOffset + 0.3, hrp.Position.Z) * rotOnly
        end
    end

    for part, wasCollidable in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = wasCollidable
        end
    end
    table.clear(originalCollisions)
end

-- ==========================================
-- LOGIKA ANTI-RAGDOLL
-- ==========================================
local function enforceAntiRagdoll(char, hum)
    if not char or not hum then return end

    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    if hum.PlatformStand and (State.antiBackTP or not State.fly) then
        hum.PlatformStand = false
    end

    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") and not desc.Enabled then
            desc.Enabled = true
        elseif desc:IsA("BallSocketConstraint") then
            desc:Destroy()
        end
    end
end

-- ==========================================
-- LOGIKA GOD MODE + FIX SPAM HIT (2x PUKUL / PEDANG)
-- ==========================================
local lastHealthSeen = 100
local lastDodgeTick = 0

local function bindCharacterProtection(char)
    for _, conn in ipairs(activeCharConns) do
        conn:Disconnect()
    end
    table.clear(activeCharConns)

    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    lastHealthSeen = hum.Health

    -- Hook langsung ke HealthChanged (bereaksi di frame yang sama sebelum hit ke-2 masuk)
    local hcConn = hum.HealthChanged:Connect(function(newHp)
        if State.godMode or State.antiDie then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
        end

        if State.godMode then
            if newHp < lastHealthSeen then
                -- Pulihkan HP seketika di client
                if hum.MaxHealth < 100 then hum.MaxHealth = 100 end
                hum.Health = hum.MaxHealth

                -- Anti-Spam Hit: Jika HP sempat berkurang (kena pukul/pedang ke-1),
                -- geser micro-evade agar swing/pukulan ke-2 tidak mengenai hitbox!
                if State.antiSpamHit and not isTeleporting and (tick() - lastDodgeTick) > 0.25 then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        lastDodgeTick = tick()
                        local dodgeOffset = (-hrp.CFrame.LookVector * 7) + Vector3.new(0, 6, 0)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.CFrame = hrp.CFrame + dodgeOffset
                    end
                end
            elseif newHp < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end
        lastHealthSeen = hum.Health
    end)
    table.insert(activeCharConns, hcConn)

    -- Cegah state Dead secara langsung jika server mengirim sinyal mati
    local stConn = hum.StateChanged:Connect(function(_, newState)
        if (State.godMode or State.antiDie) and newState == Enum.HumanoidStateType.Dead then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.Health = hum.MaxHealth
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
    table.insert(activeCharConns, stConn)
end

-- ==========================================
-- SMART TELEPORT (IMMUNE BACK-TP / RUBBERBAND)
-- ==========================================
local function smartTeleport(targetCFrame)
    local char, hum, hrp = getCharParts()
    if not char or not hrp then return end

    currentTpId += 1
    local myTpId = currentTpId

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local totalDist = (endPos - startPos).Magnitude

    if not State.antiBackTP or totalDist <= 26 then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end

    isTeleporting = true
    local stepSize = 24
    local steps = math.max(2, math.ceil(totalDist / stepSize))
    local rotOnly = targetCFrame - targetCFrame.Position

    hrp.Anchored = true
    for i = 1, steps do
        if myTpId ~= currentTpId or not hrp or not hrp.Parent then
            break
        end
        local alpha = i / steps
        local nextPos = startPos:Lerp(endPos, alpha)
        hrp.CFrame = CFrame.new(nextPos) * rotOnly
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end

    if hrp and hrp.Parent then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if myTpId == currentTpId then
            hrp.Anchored = false
        end
    end

    if myTpId == currentTpId then
        isTeleporting = false
    end
end

-- ==========================================
-- LOGIKA FLY & GOD MODE TOUCH
-- ==========================================
local function toggleFly(enabled)
    State.fly = enabled
    local _, hum, hrp = getCharParts()
    if enabled and hum and hrp then
        hum.PlatformStand = not (State.antiBackTP or State.antiRagdoll)
        flyBG = Instance.new("BodyGyro")
        flyBG.P = 9e4
        flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBG.CFrame = hrp.CFrame
        flyBG.Parent = hrp

        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = hrp
    else
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        if hum then hum.PlatformStand = false end
    end
end

local function setCharacterTouch(canTouch)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanTouch = canTouch
            part.CanQuery = canTouch or (part.Name == "HumanoidRootPart")
        end
    end
end

-- ==========================================
-- LOGIKA ESP (ITEM, PLAYER, ANCAMAN)
-- ==========================================
local function clearESP()
    if espFolder then
        espFolder:Destroy()
        espFolder = nil
    end
end

local function addHighlight(adornee, color, labelText)
    if not espFolder or not adornee then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = adornee
    hl.FillColor = color
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = espFolder

    local targetPart = adornee:IsA("BasePart") and adornee or adornee:FindFirstChildWhichIsA("BasePart", true)
    if targetPart and labelText then
        local bb = Instance.new("BillboardGui")
        bb.Adornee = targetPart
        bb.Size = UDim2.new(0, 120, 0, 24)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = espFolder

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = labelText
        txt.TextColor3 = color
        txt.TextStrokeTransparency = 0.3
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 11
        txt.Parent = bb
    end
end

local function refreshESP()
    clearESP()
    if not State.espEnabled then return end
    espFolder = Instance.new("Folder")
    espFolder.Name = "SYI_ESP"
    espFolder.Parent = guiParent

    local _, _, myHrp = getCharParts()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = myHrp and math.floor((plr.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude) or 0
            addHighlight(plr.Character, Color3.fromRGB(255, 215, 0), plr.DisplayName .. " [" .. dist .. "m]")
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj ~= LocalPlayer.Character and obj.Name ~= "SYI_SkyPlatform" then
            if obj:IsA("Tool") then
                addHighlight(obj, Color3.fromRGB(0, 255, 140), "[ITEM] " .. obj.Name)
            elseif obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(obj) and hum.Health > 0 then
                    addHighlight(obj, Color3.fromRGB(255, 65, 65), "[HAZARD] " .. obj.Name)
                elseif string.find(string.lower(obj.Name), "awp") or string.find(string.lower(obj.Name), "gun") then
                    addHighlight(obj, Color3.fromRGB(0, 255, 140), "[ITEM] " .. obj.Name)
                end
            end
        end
    end
end

-- ==========================================
-- ISI TAB NAVIGASI ARCHX
-- ==========================================
local tabArena    = createTab("Arena & Sky")
local tabMove     = createTab("Movement")
local tabCombat   = createTab("Protection")
local tabTeleport = createTab("Teleport")

-- TAB 1: ARENA & SKY
createToggle(tabArena, "Immune Back-TP", true, function(on)
    State.antiBackTP = on
    local _, hum = getCharParts()
    if hum and not on and State.walkSpeedEnabled then
        hum.WalkSpeed = State.walkSpeedValue
    end
end)

createActionButton(tabArena, "Panic Safe Sky (Anti-Nuke)", true, function(btn)
    local _, _, hrp = getCharParts()
    if not hrp then return end

    if not skyPlatform or not skyPlatform.Parent then
        skyPlatform = Instance.new("Part")
        skyPlatform.Name = "SYI_SkyPlatform"
        skyPlatform.Size = Vector3.new(35, 2, 35)
        skyPlatform.Anchored = true
        skyPlatform.CanCollide = true
        skyPlatform.Transparency = 0.4
        skyPlatform.Material = Enum.Material.Neon
        skyPlatform.Color = Theme.Accent
        skyPlatform.Parent = workspace
    end

    State.preSkyCFrame = hrp.CFrame
    local skyPos = Vector3.new(hrp.Position.X, math.max(260, hrp.Position.Y + 220), hrp.Position.Z)
    skyPlatform.Position = skyPos - Vector3.new(0, 4, 0)

    btn.Text = "Menuju Langit Aman..."
    task.spawn(function()
        smartTeleport(CFrame.new(skyPos))
        btn.Text = "Di Atas Langit Aman!"
        task.wait(1.2)
        btn.Text = "Panic Safe Sky (Anti-Nuke)"
    end)
end)

createActionButton(tabArena, "Return to Arena", false, function(btn)
    local _, _, hrp = getCharParts()
    if hrp and State.preSkyCFrame then
        btn.Text = "Turun ke Arena..."
        task.spawn(function()
            smartTeleport(State.preSkyCFrame + Vector3.new(0, 3, 0))
            btn.Text = "Return to Arena"
        end)
    else
        btn.Text = "Belum pernah ke Sky!"
        task.wait(1.2)
        btn.Text = "Return to Arena"
    end
end)

createToggle(tabArena, "ESP Items / Players / Hazards", false, function(on)
    State.espEnabled = on
    if on then refreshESP() else clearESP() end
end)

-- TAB 2: MOVEMENT
createToggle(tabMove, "WalkSpeed", false, function(on)
    State.walkSpeedEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.WalkSpeed = 16 end
end)

createAdjuster(tabMove, "Speed Value", State.walkSpeedValue, 16, 250, 10, function(v)
    State.walkSpeedValue = v
end)

createToggle(tabMove, "JumpPower", false, function(on)
    State.jumpPowerEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.JumpPower = 50 end
end)

createAdjuster(tabMove, "Jump Value", State.jumpPowerValue, 50, 400, 15, function(v)
    State.jumpPowerValue = v
end)

createToggle(tabMove, "Mobile Fly", false, function(on)
    toggleFly(on)
end)

createAdjuster(tabMove, "Fly Speed", State.flySpeed, 20, 250, 15, function(v)
    State.flySpeed = v
end)

createToggle(tabMove, "Noclip (Fixed)", false, function(on)
    State.noclip = on
    if on then
        applyNoclip()
    else
        disableNoclip()
    end
end)

-- TAB 3: PROTECTION (ANTI-SPAM HIT, GOD MODE, ANTI-RAGDOLL)
createToggle(tabCombat, "God Mode (Instant Lock)", false, function(on)
    State.godMode = on
    setCharacterTouch(not on)
    local _, hum = getCharParts()
    if hum and on then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum.BreakJointsOnDeath = false
        hum.Health = hum.MaxHealth
    end
end)

createToggle(tabCombat, "Anti-Spam Hit (Auto-Evade 2x)", true, function(on)
    State.antiSpamHit = on
end)

createToggle(tabCombat, "Anti-Ragdoll", false, function(on)
    State.antiRagdoll = on
    local char, hum = getCharParts()
    if hum then
        if on then
            enforceAntiRagdoll(char, hum)
        else
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            if not State.antiBackTP then
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            end
        end
    end
end)

createToggle(tabCombat, "Anti-Die + Anti-Void", false, function(on)
    State.antiDie = on
    local _, hum = getCharParts()
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not on)
        hum.BreakJointsOnDeath = not on
    end
end)

-- TAB 4: TELEPORT
createActionButton(tabTeleport, "Save Current Position", false, function(btn)
    local _, _, hrp = getCharParts()
    if hrp then
        State.savedCFrame = hrp.CFrame
        btn.Text = string.format("Saved (%.0f, %.0f, %.0f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        task.wait(1.5)
        btn.Text = "Save Current Position"
    end
end)

createActionButton(tabTeleport, "Teleport to Saved Pos", true, function(btn)
    local _, _, hrp = getCharParts()
    if hrp and State.savedCFrame then
        task.spawn(function()
            smartTeleport(State.savedCFrame)
        end)
    else
        btn.Text = "Belum ada posisi disimpan!"
        task.wait(1.2)
        btn.Text = "Teleport to Saved Pos"
    end
end)

createActionButton(tabTeleport, "Teleport to Next Player", false, function(btn)
    local _, _, hrp = getCharParts()
    if not hrp then return end
    local others = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(others, plr)
        end
    end
    if #others == 0 then
        btn.Text = "Tidak ada player lain"
        task.wait(1.2)
        btn.Text = "Teleport to Next Player"
        return
    end
    if State.playerIndex > #others then State.playerIndex = 1 end
    local target = others[State.playerIndex]
    State.playerIndex += 1

    btn.Text = "TP -> " .. target.DisplayName
    task.spawn(function()
        smartTeleport(target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 2))
    end)
end)

createActionButton(tabTeleport, "Get Tap-Teleport Tool", false, function(btn)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack or backpack:FindFirstChild("Tap TP") then return end

    local tool = Instance.new("Tool")
    tool.Name = "Tap TP"
    tool.RequiresHandle = false
    tool.Parent = backpack

    local mouse = LocalPlayer:GetMouse()
    tool.Activated:Connect(function()
        local _, _, hrp = getCharParts()
        if hrp and mouse.Hit then
            task.spawn(function()
                smartTeleport(CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.5, 0)))
            end)
        end
    end)
    btn.Text = "Tap TP ditambahkan ke Tas!"
    task.wait(1.5)
    btn.Text = "Get Tap-Teleport Tool"
end)

-- Aktifkan tab pertama secara default
switchTab("Arena & Sky")
if LocalPlayer.Character then
    bindCharacterProtection(LocalPlayer.Character)
end

-- ==========================================
-- LOOPS UTAMA (STEPPED + HEARTBEAT)
-- ==========================================
local lastEspRefresh = 0
local rainbowRot = 0

local steppedConn = RunService.Stepped:Connect(function()
    if State.noclip then
        applyNoclip()
    end
    -- Kunci ulang HP sebelum physics step berikutnya dimulai
    if State.godMode or State.antiDie then
        local _, hum = getCharParts()
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
            if State.godMode and hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end
    end
end)

local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    -- Animasi Rainbow Halus ArchX
    rainbowRot = (rainbowRot + (dt * 95)) % 360
    for i = #rainbowTargets, 1, -1 do
        local grad = rainbowTargets[i]
        if grad and grad.Parent then
            grad.Rotation = rainbowRot
        else
            table.remove(rainbowTargets, i)
        end
    end

    local char, hum, hrp = getCharParts()
    if not char or not hum or not hrp then return end

    -- Anti-Ragdoll Enforcement
    if State.antiRagdoll then
        enforceAntiRagdoll(char, hum)
    end

    -- Stabilisasi State Fisika untuk Immune Back-TP
    if State.antiBackTP then
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        if State.fly then
            hum.PlatformStand = false
            if hum:GetState() == Enum.HumanoidStateType.Freefall then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end

    -- Paksa Noclip di Heartbeat + Penahan Lantai saat jalan darat
    if State.noclip and not isTeleporting then
        applyNoclip()
        if not State.fly then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local hipOffset = hum.HipHeight + (hrp.Size.Y * 0.5)
            local result = workspace:Raycast(hrp.Position, Vector3.new(0, -(hipOffset + 0.6), 0), rayParams)

            if result and hrp.AssemblyLinearVelocity.Y <= 0 then
                local targetY = result.Position.Y + hipOffset
                if hrp.Position.Y < targetY then
                    local rotOnly = hrp.CFrame - hrp.CFrame.Position
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                    hrp.CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z) * rotOnly
                end
            end
        end
    end

    -- WalkSpeed (Hybrid CFrame Mode saat Immune Back-TP ON)
    if State.walkSpeedEnabled and not isTeleporting then
        if State.antiBackTP and not State.fly then
            hum.WalkSpeed = 16
            local moveDir = hum.MoveDirection
            local extraSpeed = math.max(0, State.walkSpeedValue - 16)
            if moveDir.Magnitude > 0 and extraSpeed > 0 then
                local stepVec = moveDir * (extraSpeed * dt)
                local canMove = true

                if not State.noclip then
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {char}
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local hit = workspace:Raycast(hrp.Position, stepVec + (moveDir.Unit * 1.5), rayParams)
                    if hit and hit.Instance.CanCollide then
                        canMove = false
                    end
                end

                if canMove then
                    hrp.CFrame = hrp.CFrame + stepVec
                    local vel = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        math.clamp(vel.X, -22, 22),
                        vel.Y,
                        math.clamp(vel.Z, -22, 22)
                    )
                end
            end
        else
            hum.WalkSpeed = State.walkSpeedValue
        end
    end

    -- JumpPower Lock
    if State.jumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = State.jumpPowerValue
    end

    -- Mobile Fly Update
    if State.fly and flyBV and flyBG and not isTeleporting then
        Camera = workspace.CurrentCamera
        local camCF = Camera.CFrame
        flyBG.CFrame = camCF

        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            local flatForward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            if flatForward.Magnitude > 0 then flatForward = flatForward.Unit end
            local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

            local forwardAmt = moveDir:Dot(flatForward)
            local rightAmt = moveDir:Dot(flatRight)
            local wishDir = (camCF.LookVector * forwardAmt + camCF.RightVector * rightAmt)
            if wishDir.Magnitude > 1 then wishDir = wishDir.Unit end

            if State.antiBackTP then
                hrp.CFrame = hrp.CFrame + (wishDir * State.flySpeed * dt)
                flyBV.Velocity = wishDir * math.min(State.flySpeed, 18)
                hrp.AssemblyLinearVelocity = flyBV.Velocity
            else
                flyBV.Velocity = wishDir * State.flySpeed
            end
        else
            flyBV.Velocity = Vector3.zero
            if State.antiBackTP then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    -- Anti-Die & Anti-Void
    if State.antiDie and not isTeleporting then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum.BreakJointsOnDeath = false
        if hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > -40 then
            lastSafeCFrame = hrp.CFrame
        elseif hrp.Position.Y < -90 and lastSafeCFrame then
            task.spawn(function()
                smartTeleport(lastSafeCFrame + Vector3.new(0, 5, 0))
            end)
        end
    end

    -- God Mode Lock
    if State.godMode then
        if hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
        setCharacterTouch(false)
    end

    -- Refresh ESP tiap 1.5 detik
    if State.espEnabled and (tick() - lastEspRefresh) > 1.5 then
        lastEspRefresh = tick()
        refreshESP()
    end
end)

-- Re-apply saat respawn
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    currentTpId += 1
    isTeleporting = false
    table.clear(originalCollisions)
    bindCharacterProtection(newChar)

    local hum = newChar:WaitForChild("Humanoid", 5)
    if hum then
        if State.antiDie or State.godMode then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
        end
        if State.antiRagdoll then
            enforceAntiRagdoll(newChar, hum)
        end
    end
    if State.fly then
        task.wait(0.2)
        toggleFly(true)
    end
    if State.godMode then
        task.wait(0.1)
        setCharacterTouch(false)
    end
end)

-- Tombol Close (Bersihkan seluruh efek & UI)
CloseBtn.MouseButton1Click:Connect(function()
    currentTpId += 1
    isTeleporting = false
    State.antiBackTP = false
    State.walkSpeedEnabled = false
    State.jumpPowerEnabled = false
    State.noclip = false
    State.antiRagdoll = false
    State.antiDie = false
    State.godMode = false
    State.espEnabled = false

    for _, conn in ipairs(activeCharConns) do
        conn:Disconnect()
    end
    table.clear(activeCharConns)

    toggleFly(false)
    disableNoclip()
    setCharacterTouch(true)
    clearESP()

    if skyPlatform then
        skyPlatform:Destroy()
        skyPlatform = nil
    end

    local _, hum, hrp = getCharParts()
    if hrp then
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum.PlatformStand = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    end

    steppedConn:Disconnect()
    heartbeatConn:Disconnect()
    charConn:Disconnect()
    ScreenGui:Destroy()
end)
