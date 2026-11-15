-- Survive Your Ideas | ZyrexScript Hub V3 (Anti-BackTP + Mobile Optimized)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- State Konfigurasi
local State = {
    antiBackTP = true, -- Aktif otomatis untuk mencegah mental balik saat TP/Fly/Speed
    walkSpeedEnabled = false,
    walkSpeedValue = 50,
    jumpPowerEnabled = false,
    jumpPowerValue = 100,
    fly = false,
    flySpeed = 65,
    noclip = false,
    antiDie = false,
    godMode = false,
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

-- Bersihkan instance lama jika script dijalankan ulang
local guiParent = (gethui and gethui()) or CoreGui
if guiParent:FindFirstChild("SYI_ZyrexHub") then
    guiParent.SYI_ZyrexHub:Destroy()
end
if workspace:FindFirstChild("SYI_SkyPlatform") then
    workspace.SYI_SkyPlatform:Destroy()
end

-- Helper Character
local function getCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hum, hrp
end

-- Setup UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SYI_ZyrexHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = guiParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 268, 0, 365)
MainFrame.Position = UDim2.new(0.5, -134, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 34)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Survive Your Ideas V3 | Zyrex"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -58, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 15
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -29, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(185, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Container Scroll
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -12, 1, -42)
Container.Position = UDim2.new(0, 6, 0, 38)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 4
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 6)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = Container

-- Minimize Logic
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Container.Visible = not minimized
    MainFrame.Size = minimized and UDim2.new(0, 268, 0, 34) or UDim2.new(0, 268, 0, 365)
    MinBtn.Text = minimized and "+" or "-"
end)

-- Komponen UI Builder
local function createSection(titleText)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -4, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. titleText .. " —"
    lbl.TextColor3 = Color3.fromRGB(130, 170, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.Parent = Container
end

local function createToggle(text, defaultActive, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 33)
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Parent = Container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local active = defaultActive or false
    local function updateVisual()
        btn.Text = text .. (active and ": ON" or ": OFF")
        btn.BackgroundColor3 = active and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(35, 39, 48)
    end
    updateVisual()

    btn.MouseButton1Click:Connect(function()
        active = not active
        updateVisual()
        callback(active, btn)
    end)
    return btn
end

local function createAdjuster(label, defaultVal, minVal, maxVal, step, onChange)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -4, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(28, 31, 39)
    frame.Parent = Container
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local val = defaultVal
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(val)
    lbl.TextColor3 = Color3.fromRGB(190, 200, 215)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 36, 0, 22)
    minus.Position = UDim2.new(1, -80, 0, 4)
    minus.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
    minus.Text = "-"
    minus.TextColor3 = Color3.fromRGB(255, 255, 255)
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 14
    minus.Parent = frame
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 5)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 36, 0, 22)
    plus.Position = UDim2.new(1, -40, 0, 4)
    plus.BackgroundColor3 = Color3.fromRGB(50, 55, 68)
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(255, 255, 255)
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 14
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

local function createActionButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 33)
    btn.BackgroundColor3 = color or Color3.fromRGB(45, 75, 130)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Parent = Container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

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
-- SMART TELEPORT (IMMUNE BACK-TP / RUBBERBAND)
-- ==========================================
local function smartTeleport(targetCFrame)
    local char, hum, hrp = getCharParts()
    if not char or not hrp then return end

    currentTpId += 1
    local myTpId = currentTpId

    -- Reset momentum agar server tidak membaca lonjakan kecepatan
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local totalDist = (endPos - startPos).Magnitude

    -- Jika Anti-BackTP OFF atau jarak dekat, langsung pindah dengan velocity nol
    if not State.antiBackTP or totalDist <= 26 then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        return
    end

    -- Micro-step teleport agar perpindahan per-frame tetap di bawah batas anti-rubberband
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
-- LOGIKA FLY & GOD MODE
-- ==========================================
local function toggleFly(enabled)
    State.fly = enabled
    local _, hum, hrp = getCharParts()
    if enabled and hum and hrp then
        hum.PlatformStand = not State.antiBackTP
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

    -- 1. ESP Player lain
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = myHrp and math.floor((plr.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude) or 0
            addHighlight(plr.Character, Color3.fromRGB(255, 215, 0), plr.DisplayName .. " [" .. dist .. "m]")
        end
    end

    -- 2. ESP Item (Tool/Senjata) & NPC/Ancaman di Workspace
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
-- SUSUNAN MENU FITUR
-- ==========================================
createSection("ANTI-RUBBERBAND & ARENA")

createToggle("Immune Back-TP (TP/Fly/Speed)", true, function(on)
    State.antiBackTP = on
    local _, hum = getCharParts()
    if hum and not on and State.walkSpeedEnabled then
        hum.WalkSpeed = State.walkSpeedValue
    end
end)

createActionButton("Panic Safe Sky (Anti-Nuke/Tsunami)", Color3.fromRGB(165, 95, 30), function(btn)
    local _, _, hrp = getCharParts()
    if not hrp then return end

    if not skyPlatform or not skyPlatform.Parent then
        skyPlatform = Instance.new("Part")
        skyPlatform.Name = "SYI_SkyPlatform"
        skyPlatform.Size = Vector3.new(35, 2, 35)
        skyPlatform.Anchored = true
        skyPlatform.CanCollide = true
        skyPlatform.Transparency = 0.45
        skyPlatform.Material = Enum.Material.Neon
        skyPlatform.Color = Color3.fromRGB(0, 170, 255)
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
        btn.Text = "Panic Safe Sky (Anti-Nuke/Tsunami)"
    end)
end)

createActionButton("Return to Arena (Turun dari Sky)", Color3.fromRGB(50, 90, 140), function(btn)
    local _, _, hrp = getCharParts()
    if hrp and State.preSkyCFrame then
        btn.Text = "Turun ke Arena..."
        task.spawn(function()
            smartTeleport(State.preSkyCFrame + Vector3.new(0, 3, 0))
            btn.Text = "Return to Arena (Turun dari Sky)"
        end)
    else
        btn.Text = "Belum pernah ke Safe Sky!"
        task.wait(1.2)
        btn.Text = "Return to Arena (Turun dari Sky)"
    end
end)

createToggle("ESP Items / Players / Hazards", false, function(on)
    State.espEnabled = on
    if on then refreshESP() else clearESP() end
end)

createSection("MOVEMENT & PHYSICS")

createToggle("WalkSpeed", false, function(on)
    State.walkSpeedEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.WalkSpeed = 16 end
end)

createAdjuster("Speed Value", State.walkSpeedValue, 16, 250, 10, function(v)
    State.walkSpeedValue = v
end)

createToggle("JumpPower", false, function(on)
    State.jumpPowerEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.JumpPower = 50 end
end)

createAdjuster("Jump Value", State.jumpPowerValue, 50, 400, 15, function(v)
    State.jumpPowerValue = v
end)

createToggle("Mobile Fly", false, function(on)
    toggleFly(on)
end)

createAdjuster("Fly Speed", State.flySpeed, 20, 250, 15, function(v)
    State.flySpeed = v
end)

createToggle("Noclip (Fixed)", false, function(on)
    State.noclip = on
    if on then
        applyNoclip()
    else
        disableNoclip()
    end
end)

createSection("PROTECTION & TELEPORT")

createToggle("Anti-Die + Anti-Void", false, function(on)
    State.antiDie = on
    local _, hum = getCharParts()
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not on)
        hum.BreakJointsOnDeath = not on
    end
end)

createToggle("God Mode (Client Touch)", false, function(on)
    State.godMode = on
    setCharacterTouch(not on)
end)

createActionButton("Save Current Position", nil, function(btn)
    local _, _, hrp = getCharParts()
    if hrp then
        State.savedCFrame = hrp.CFrame
        btn.Text = string.format("Saved (%.0f, %.0f, %.0f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        task.wait(1.5)
        btn.Text = "Save Current Position"
    end
end)

createActionButton("Teleport to Saved Pos", nil, function(btn)
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

createActionButton("Teleport to Next Player", nil, function(btn)
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

createActionButton("Get Tap-Teleport Tool", nil, function(btn)
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

-- ==========================================
-- LOOPS UTAMA
-- ==========================================
local lastEspRefresh = 0

local steppedConn = RunService.Stepped:Connect(function()
    if State.noclip then
        applyNoclip()
    end
end)

local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    local char, hum, hrp = getCharParts()
    if not char or not hum or not hrp then return end

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

    -- WalkSpeed (Hybrid CFrame Mode saat Immune Back-TP ON agar tidak kena setback)
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

    -- Mobile Fly Update (Hybrid CFrame + Clamped Velocity saat Immune Back-TP ON)
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
                -- Geser posisi via CFrame dan jaga Velocity tetap rendah agar lolos cek server
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

    -- God Mode (Client Touch)
    if State.godMode then
        if hum.Health > 0 and hum.Health < hum.MaxHealth then
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
    local hum = newChar:WaitForChild("Humanoid", 5)
    if hum and State.antiDie then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum.BreakJointsOnDeath = false
    end
    if State.fly then
        task.wait(0.2)
        toggleFly(true)
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
    State.antiDie = false
    State.godMode = false
    State.espEnabled = false

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
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end

    steppedConn:Disconnect()
    heartbeatConn:Disconnect()
    charConn:Disconnect()
    ScreenGui:Destroy()
end)
