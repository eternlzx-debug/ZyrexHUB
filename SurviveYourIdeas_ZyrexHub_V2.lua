-- Survive Your Ideas | ZyrexScript Hub V2 (Mobile Optimized)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- State Konfigurasi
local State = {
    walkSpeedEnabled = false,
    walkSpeedValue = 50,
    jumpPowerEnabled = false,
    jumpPowerValue = 100,
    fly = false,
    flySpeed = 65,
    noclip = false,
    antiDie = false,
    godMode = false,
    autoMedkit = false,
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
MainFrame.Size = UDim2.new(0, 265, 0, 360)
MainFrame.Position = UDim2.new(0.5, -132, 0.18, 0)
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
Title.Text = "Survive Your Ideas V2 | Zyrex"
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
    MainFrame.Size = minimized and UDim2.new(0, 265, 0, 34) or UDim2.new(0, 265, 0, 360)
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

local function createToggle(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 33)
    btn.BackgroundColor3 = Color3.fromRGB(35, 39, 48)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.Parent = Container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        btn.Text = text .. (active and ": ON" or ": OFF")
        btn.BackgroundColor3 = active and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(35, 39, 48)
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
-- LOGIKA NOCLIP BARU (ANTI-SINK & ANTI-FLING)
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
        -- Hentikan momentum agar tidak mental saat kolisi kembali aktif
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        -- Cek posisi kaki terhadap permukaan lantai di bawahnya
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

    -- Kembalikan status CanCollide persis seperti semula
    for part, wasCollidable in pairs(originalCollisions) do
        if part and part.Parent then
            part.CanCollide = wasCollidable
        end
    end
    table.clear(originalCollisions)
end

-- ==========================================
-- LOGIKA FLY & GOD MODE
-- ==========================================
local function toggleFly(enabled)
    State.fly = enabled
    local _, hum, hrp = getCharParts()
    if enabled and hum and hrp then
        hum.PlatformStand = true
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

    -- 2. ESP Item (Medkit, AWP, dll) & NPC/Ancaman di Workspace
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj ~= LocalPlayer.Character and obj.Name ~= "SYI_SkyPlatform" then
            if obj:IsA("Tool") then
                addHighlight(obj, Color3.fromRGB(0, 255, 140), "[ITEM] " .. obj.Name)
            elseif obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and not Players:GetPlayerFromCharacter(obj) and hum.Health > 0 then
                    addHighlight(obj, Color3.fromRGB(255, 65, 65), "[HAZARD] " .. obj.Name)
                elseif string.find(string.lower(obj.Name), "medkit") or string.find(string.lower(obj.Name), "awp") then
                    addHighlight(obj, Color3.fromRGB(0, 255, 140), "[ITEM] " .. obj.Name)
                end
            end
        end
    end
end

-- ==========================================
-- SUSUNAN MENU FITUR
-- ==========================================
createSection("SURVIVE YOUR IDEAS SPECIAL")

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

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(skyPos)
    btn.Text = "Di Atas Langit Aman!"
    task.wait(1.5)
    btn.Text = "Panic Safe Sky (Anti-Nuke/Tsunami)"
end)

createActionButton("Return to Arena (Turun dari Sky)", Color3.fromRGB(50, 90, 140), function(btn)
    local _, _, hrp = getCharParts()
    if hrp and State.preSkyCFrame then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = State.preSkyCFrame + Vector3.new(0, 3, 0)
    else
        btn.Text = "Belum pernah ke Safe Sky!"
        task.wait(1.2)
        btn.Text = "Return to Arena (Turun dari Sky)"
    end
end)

createToggle("Auto-Use Medkit (HP < 75%)", function(on)
    State.autoMedkit = on
end)

createToggle("ESP Items / Players / Hazards", function(on)
    State.espEnabled = on
    if on then refreshESP() else clearESP() end
end)

createSection("MOVEMENT & PHYSICS")

createToggle("WalkSpeed", function(on)
    State.walkSpeedEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.WalkSpeed = 16 end
end)

createAdjuster("Speed Value", State.walkSpeedValue, 16, 250, 10, function(v)
    State.walkSpeedValue = v
end)

createToggle("JumpPower", function(on)
    State.jumpPowerEnabled = on
    local _, hum = getCharParts()
    if not on and hum then hum.JumpPower = 50 end
end)

createAdjuster("Jump Value", State.jumpPowerValue, 50, 400, 15, function(v)
    State.jumpPowerValue = v
end)

createToggle("Mobile Fly", function(on)
    toggleFly(on)
end)

createAdjuster("Fly Speed", State.flySpeed, 20, 250, 15, function(v)
    State.flySpeed = v
end)

createToggle("Noclip (Fixed)", function(on)
    State.noclip = on
    if on then
        applyNoclip()
    else
        disableNoclip()
    end
end)

createSection("PROTECTION & TELEPORT")

createToggle("Anti-Die + Anti-Void", function(on)
    State.antiDie = on
    local _, hum = getCharParts()
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not on)
        hum.BreakJointsOnDeath = not on
    end
end)

createToggle("God Mode (Client Touch)", function(on)
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
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = State.savedCFrame
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

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 2)
    btn.Text = "TP -> " .. target.DisplayName
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
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3.5, 0))
        end
    end)
    btn.Text = "Tap TP ditambahkan ke Tas!"
    task.wait(1.5)
    btn.Text = "Get Tap-Teleport Tool"
end)

-- ==========================================
-- LOOPS UTAMA
-- ==========================================
local lastMedkitUse = 0
local lastEspRefresh = 0

local steppedConn = RunService.Stepped:Connect(function()
    if State.noclip then
        applyNoclip()
    end
end)

local heartbeatConn = RunService.Heartbeat:Connect(function()
    local char, hum, hrp = getCharParts()
    if not char or not hum or not hrp then return end

    -- Paksa Noclip di Heartbeat + Penahan Lantai saat jalan darat
    if State.noclip then
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

    -- WalkSpeed & JumpPower Lock
    if State.walkSpeedEnabled then
        hum.WalkSpeed = State.walkSpeedValue
    end
    if State.jumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = State.jumpPowerValue
    end

    -- Mobile Fly Update
    if State.fly and flyBV and flyBG then
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
            flyBV.Velocity = (camCF.LookVector * forwardAmt + camCF.RightVector * rightAmt) * State.flySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
    end

    -- Anti-Die & Anti-Void
    if State.antiDie then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum.BreakJointsOnDeath = false
        if hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > -40 then
            lastSafeCFrame = hrp.CFrame
        elseif hrp.Position.Y < -90 and lastSafeCFrame then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = lastSafeCFrame + Vector3.new(0, 5, 0)
        end
    end

    -- God Mode (Client Touch)
    if State.godMode then
        if hum.Health > 0 and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
        setCharacterTouch(false)
    end

    -- Auto-Use Medkit
    if State.autoMedkit and hum.Health > 0 and hum.Health < (hum.MaxHealth * 0.75) and (tick() - lastMedkitUse) > 1.2 then
        local medkit = char:FindFirstChildOfClass("Tool")
        if not (medkit and string.find(string.lower(medkit.Name), "medkit")) then
            medkit = nil
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp then
                for _, item in ipairs(bp:GetChildren()) do
                    if item:IsA("Tool") and (string.find(string.lower(item.Name), "medkit") or string.find(string.lower(item.Name), "heal")) then
                        medkit = item
                        break
                    end
                end
            end
        end

        if medkit then
            lastMedkitUse = tick()
            hum:EquipTool(medkit)
            task.defer(function()
                if medkit and medkit.Parent == char then
                    medkit:Activate()
                end
            end)
        end
    end

    -- Refresh ESP tiap 1.5 detik agar ringan di HP
    if State.espEnabled and (tick() - lastEspRefresh) > 1.5 then
        lastEspRefresh = tick()
        refreshESP()
    end
end)

-- Re-apply saat respawn
local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
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
    State.walkSpeedEnabled = false
    State.jumpPowerEnabled = false
    State.noclip = false
    State.antiDie = false
    State.godMode = false
    State.autoMedkit = false
    State.espEnabled = false

    toggleFly(false)
    disableNoclip()
    setCharacterTouch(true)
    clearESP()

    if skyPlatform then
        skyPlatform:Destroy()
        skyPlatform = nil
    end

    local _, hum = getCharParts()
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
    end

    steppedConn:Disconnect()
    heartbeatConn:Disconnect()
    charConn:Disconnect()
    ScreenGui:Destroy()
end)
