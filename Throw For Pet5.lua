-- ZyrexHub V2.3 (Complete Edition) by ZyrexScript
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")

if CoreGui:FindFirstChild("ZyrexHub") then
    CoreGui.ZyrexHub:Destroy()
end

-- === DETEKSI NAMA GAME ===
local okGame, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
local gameName = (okGame and gameInfo and gameInfo.Name) or "Throw Food for Animals"

-- === STATE & VARIABEL GLOBAL ===
local DISCORD_LINK = "https://discord.gg/zyrex"
local DEFAULT_LOGO_ID = "rbxassetid://113865305400607"
local DEFAULT_BG_ID   = "rbxassetid://84587193599064"

local runningTap = false
local runningSteal = false
local runningEquip = false
local runningSell = false
local runningTrain = false
local runningUpgrade = false
local runningFood = false
local runningMicroStep = true
local runningAntiAfk = true
local notifRareOnly = false
local webhookEnabled = false
local webhookUrl = ""

-- Player Modifiers State
local walkSpeedValue = 20
local jumpPowerValue = 50
local walkSpeedEnabled = false
local jumpPowerEnabled = false
local flyEnabled = false
local flySpeedValue = 50
local noclipEnabled = false

-- Multi-Select Filter State untuk Auto Sell
local selectedSellTiers = {}
local selectedSellMutations = {}
local selectedSellAnimals = {}

local savedPadCFrame = nil
local savedTrainRelativeOffset = nil -- Menyimpan posisi relatif terhadap plot/kandang sendiri
local initialSpawnPos = nil
local isMicroStepping = false
local connections = {}
local sessionStartTick = tick()

local totalStealCount = 0
local totalSoldCount = 0
local catchNotifiedThisCycle = false
local lastCatchTick = 0
local lastPlotFullTick = 0
local lastCatchNotifRef = nil

-- State Smart Anti-Spam Buy
local insufficientCashFlag = false
local lastInsufficientTick = 0
local foodWaitingForCash = false
local standWaitingForCash = false
local bestAffordableFoodIdx = nil
local lastKnownCashSnapshot = ""
local lastNumericCash = nil
local cashIncreasedSignal = false

-- Referensi UI
local statusFoodLbl = nil
local statusStandLbl = nil
local statusSellLbl = nil
local statusTrainLbl = nil
local statStealCountLbl = nil
local statCashLbl = nil
local StealPill = nil
local SpinnerRing = nil

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZyrexHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = gethui and gethui() or CoreGui

-- Rekam titik awal spawn untuk referensi plot milik sendiri
task.defer(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        initialSpawnPos = hrp.Position
    end
end)

-- === PALET WARNA ZYREX V2 (SEMI-TRANSPARAN AGAR BACKGROUND TERLIHAT JELAS) ===
local THEME = {
    BgMain      = Color3.fromRGB(16, 12, 19),
    BgSidebar   = Color3.fromRGB(20, 14, 24),
    BgCard      = Color3.fromRGB(26, 18, 30),
    BgCardHover = Color3.fromRGB(36, 24, 42),
    BgInput     = Color3.fromRGB(16, 12, 20),
    Border      = Color3.fromRGB(68, 46, 72),
    Accent      = Color3.fromRGB(255, 46, 99),
    AccentSoft  = Color3.fromRGB(190, 36, 78),
    Gold        = Color3.fromRGB(255, 195, 65),
    Green       = Color3.fromRGB(55, 210, 120),
    Red         = Color3.fromRGB(220, 55, 75),
    Blue        = Color3.fromRGB(80, 195, 255),
    TextPrimary = Color3.fromRGB(248, 248, 252),
    TextMuted   = Color3.fromRGB(185, 175, 192),
    SwitchOff   = Color3.fromRGB(54, 42, 58),
}

-- === DATA KATEGORI TIER, MUTASI, UKURAN & HEWAN ===
local TIER_LIST = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
    "Secret", "Divine", "Celestial", "Eternal", "Cosmic", "Supreme", "Sovereign"
}

local MUTATION_LIST = {
    "None", "Gold", "Diamond", "Emerald", "Ruby", "Rainbow", "Champion"
}

local SIZE_KEYWORDS = {
    "Infinite", "Cosmic", "Monstrous", "Titanic", "Gigantic", "Colossal", "Huge"
}

local DEFAULT_ANIMALS = {
    "CrownIbex", "CrownbreakerAurochs", "CursedOwl", "CursedRaven",
    "Demon", "Dimetrodon", "Dingo", "Pemanen Limbah"
}

local function FormatAssetId(raw)
    local cleaned = tostring(raw or ""):gsub("%s+", "")
    if cleaned == "" then return nil end
    local digits = cleaned:match("(%d+)")
    if digits then
        return "rbxassetid://" .. digits
    end
    return cleaned
end

local function IsRareOrMutated(text)
    local lower = tostring(text or ""):lower()
    local highKeywords = {
        "gold", "diamond", "emerald", "ruby", "rainbow", "champion",
        "huge", "colossal", "gigantic", "titanic", "monstrous", "cosmic", "infinite",
        "rare", "epic", "legendary", "mythic", "secret", "divine", "celestial", "eternal", "supreme", "sovereign"
    }
    for _, kw in ipairs(highKeywords) do
        if lower:find(kw, 1, true) then
            return true
        end
    end
    return false
end

-- === HELPER DRAG (TOUCH & MOUSE) ===
local function MakeDraggable(dragHandle, targetFrame)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    table.insert(connections, dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))
    table.insert(connections, dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- === 10. TOP-CENTER FPS & MS MONITOR (BISA DI-DRAG) ===
local PerfBar = Instance.new("Frame")
PerfBar.Name = "ZyrexPerfHUD"
PerfBar.Size = UDim2.new(0, 196, 0, 28)
PerfBar.Position = UDim2.new(0.5, -98, 0, 6)
PerfBar.BackgroundColor3 = THEME.BgMain
PerfBar.BackgroundTransparency = 0.22
PerfBar.BorderSizePixel = 0
PerfBar.Active = true
PerfBar.ZIndex = 30
PerfBar.Parent = ScreenGui
Instance.new("UICorner", PerfBar).CornerRadius = UDim.new(1, 0)

local PerfStroke = Instance.new("UIStroke")
PerfStroke.Color = THEME.Border
PerfStroke.Thickness = 1.2
PerfStroke.Parent = PerfBar

MakeDraggable(PerfBar, PerfBar)

local FpsLbl = Instance.new("TextLabel")
FpsLbl.Size = UDim2.new(0.48, 0, 1, 0)
FpsLbl.Position = UDim2.new(0.03, 0, 0, 0)
FpsLbl.BackgroundTransparency = 1
FpsLbl.TextColor3 = THEME.Green
FpsLbl.Font = Enum.Font.GothamBold
FpsLbl.TextSize = 11
FpsLbl.Text = "60 FPS"
FpsLbl.ZIndex = 31
FpsLbl.Parent = PerfBar

local PerfSep = Instance.new("Frame")
PerfSep.Size = UDim2.new(0, 1, 0.55, 0)
PerfSep.Position = UDim2.new(0.5, 0, 0.225, 0)
PerfSep.BackgroundColor3 = THEME.Border
PerfSep.BorderSizePixel = 0
PerfSep.ZIndex = 31
PerfSep.Parent = PerfBar

local PingLbl = Instance.new("TextLabel")
PingLbl.Size = UDim2.new(0.48, 0, 1, 0)
PingLbl.Position = UDim2.new(0.51, 0, 0, 0)
PingLbl.BackgroundTransparency = 1
PingLbl.TextColor3 = THEME.Blue
PingLbl.Font = Enum.Font.GothamBold
PingLbl.TextSize = 11
PingLbl.Text = "0 ms"
PingLbl.ZIndex = 31
PingLbl.Parent = PerfBar

do
    local frameCount = 0
    local lastSample = tick()
    table.insert(connections, RunService.RenderStepped:Connect(function()
        frameCount += 1
        local now = tick()
        if (now - lastSample) >= 0.5 then
            local fps = math.floor(frameCount / (now - lastSample) + 0.5)
            frameCount = 0
            lastSample = now
            FpsLbl.Text = tostring(fps) .. " FPS"
            if fps >= 45 then
                FpsLbl.TextColor3 = THEME.Green
            elseif fps >= 25 then
                FpsLbl.TextColor3 = THEME.Gold
            else
                FpsLbl.TextColor3 = THEME.Red
            end

            local pingMs = 0
            pcall(function()
                pingMs = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
            end)
            PingLbl.Text = tostring(pingMs) .. " ms"
            if pingMs <= 90 then
                PingLbl.TextColor3 = THEME.Green
            elseif pingMs <= 180 then
                PingLbl.TextColor3 = THEME.Gold
            else
                PingLbl.TextColor3 = THEME.Red
            end
        end
    end))
end

-- === SISTEM TELEPORT PRESISI (ANTI-JATUH, TENGAH BULATAN & DETEKSI KANDANG SENDIRI) ===
local function SafeUprightTeleport(targetWorldPos, extraOffset)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end

    local desiredPos = targetWorldPos + (extraOffset or Vector3.zero)

    -- Raycast vertikal untuk menemukan permukaan lantai tepat di bawah titik tujuan agar karakter tidak melayang atau terjatuh
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { char }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local rayResult = workspace:Raycast(desiredPos + Vector3.new(0, 14, 0), Vector3.new(0, -35, 0), rayParams)
    local finalY = rayResult and (rayResult.Position.Y + 3.1) or (desiredPos.Y + 2.5)

    -- Pastikan orientasi selalu tegak lurus (UpVector = 0,1,0) sehingga karakter tidak miring/terjatuh
    local currentLook = hrp.CFrame.LookVector
    local flatLook = Vector3.new(currentLook.X, 0, currentLook.Z)
    if flatLook.Magnitude < 0.05 then
        flatLook = Vector3.new(0, 0, -1)
    else
        flatLook = flatLook.Unit
    end

    local finalPos = Vector3.new(desiredPos.X, finalY, desiredPos.Z)
    local uprightCFrame = CFrame.lookAt(finalPos, finalPos + flatLook, Vector3.new(0, 1, 0))

    if hum then
        hum.Sit = false
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = uprightCFrame

    task.defer(function()
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = uprightCFrame
        end
    end)

    return true
end

local function IsPartInsideAnyPlayerCharacter(inst)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and inst:IsDescendantOf(plr.Character) then
            return true
        end
    end
    return false
end

local function GetBestBasePartFromInstance(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj
    end
    local model = obj:FindFirstAncestorOfClass("Model")
    if model then
        if model.PrimaryPart then return model.PrimaryPart end
        local bestPart = nil
        local bestArea = -1
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local area = p.Size.X * p.Size.Z
                if area > bestArea then
                    bestArea = area
                    bestPart = p
                end
            end
        end
        if bestPart then return bestPart end
    end
    return obj:FindFirstAncestorWhichIsA("BasePart")
end

-- Deteksi Plot / Kandang milik sendiri di antara kandang-kandang random
local function FindMyPlotContainer()
    local myNameLower = LocalPlayer.Name:lower()
    local myDispLower = LocalPlayer.DisplayName:lower()
    local myUserIdStr = tostring(LocalPlayer.UserId)

    local candidateContainers = {}
    for _, folderName in ipairs({"Plots", "Bases", "Tycoons", "Kandang", "Stands", "PlayerPlots"}) do
        local f = workspace:FindFirstChild(folderName)
        if f then
            for _, child in ipairs(f:GetChildren()) do
                table.insert(candidateContainers, child)
            end
        end
    end

    -- Jika struktur folder berbeda, pindai model tingkat atas yang memiliki tanda kepemilikan
    if #candidateContainers == 0 then
        for _, child in ipairs(workspace:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child.Name ~= "Terrain" then
                local n = child.Name:lower()
                if n:find("plot") or n:find("base") or n:find("kandang") or n:find("tycoon") or n:find("stand") then
                    table.insert(candidateContainers, child)
                end
            end
        end
    end

    -- 1. Cek atribut, ValueBase, atau papan nama (TextLabel) milik LocalPlayer
    for _, container in ipairs(candidateContainers) do
        for k, v in pairs(container:GetAttributes()) do
            local kl = tostring(k):lower()
            local vs = tostring(v):lower()
            if (kl:find("owner") or kl:find("player") or kl:find("user")) and (vs == myNameLower or vs == myUserIdStr) then
                return container
            end
        end

        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("ObjectValue") and desc.Value == LocalPlayer then
                return container
            elseif (desc:IsA("StringValue") or desc:IsA("IntValue") or desc:IsA("NumberValue")) then
                local nl = desc.Name:lower()
                local vs = tostring(desc.Value):lower()
                if (nl:find("owner") or nl:find("player") or nl:find("user")) and (vs == myNameLower or vs == myUserIdStr) then
                    return container
                end
            elseif desc:IsA("TextLabel") and desc.Text ~= "" then
                local tl = desc.Text:lower()
                if tl == myNameLower or tl == myDispLower or tl:find("@" .. myNameLower, 1, true) then
                    return container
                end
            end
        end
    end

    -- 2. Fallback: Pilih plot yang paling dekat dengan posisi awal spawn karakter Anda
    local refPos = initialSpawnPos or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position)
    if refPos and #candidateContainers > 0 then
        local closestPlot = nil
        local closestDist = math.huge
        for _, container in ipairs(candidateContainers) do
            local pivotPos = nil
            if container:IsA("Model") then
                pivotPos = container:GetPivot().Position
            else
                local bp = container:FindFirstChildWhichIsA("BasePart", true)
                if bp then pivotPos = bp.Position end
            end
            if pivotPos then
                local d = (pivotPos - refPos).Magnitude
                if d < closestDist then
                    closestDist = d
                    closestPlot = container
                end
            end
        end
        if closestPlot and closestDist < 160 then
            return closestPlot
        end
    end

    return nil
end

local function FindCenterCirclePadNear(anchorPos, searchRoot, maxRadius)
    local root = searchRoot or workspace
    local bestPad = nil
    local bestDist = maxRadius or 24

    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") and not IsPartInsideAnyPlayerCharacter(obj) then
            local n = obj.Name:lower()
            local isCircleShape = (obj:IsA("Part") and obj.Shape == Enum.PartType.Cylinder)
                or n:find("pad") or n:find("circle") or n:find("ring") or n:find("zone") or n:find("bulat") or n:find("spot")
            if isCircleShape then
                local dist = (obj.Position - anchorPos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPad = obj
                end
            end
        end
    end

    return bestPad
end

-- Teleport ke fasilitas umum di Plaza (Shop Makanan / Sell Pet) tepat di tengah lingkaran interaksi
local function TeleportToPlazaFacility(includeKeywords, excludeKeywords)
    local bestPart = nil
    local bestScore = -1

    for _, obj in ipairs(workspace:GetDescendants()) do
        if not IsPartInsideAnyPlayerCharacter(obj) then
            local rawText = ""
            if obj:IsA("TextLabel") and obj.Text ~= "" then
                rawText = obj.Text:lower()
            elseif obj:IsA("ProximityPrompt") then
                rawText = (obj.ActionText .. " " .. obj.ObjectText .. " " .. obj.Name):lower()
            elseif obj:IsA("Model") or obj:IsA("BasePart") then
                rawText = obj.Name:lower()
            end

            if rawText ~= "" then
                local excluded = false
                if excludeKeywords then
                    for _, ex in ipairs(excludeKeywords) do
                        if rawText:find(ex, 1, true) then
                            excluded = true
                            break
                        end
                    end
                end

                if not excluded then
                    for idx, kw in ipairs(includeKeywords) do
                        if rawText:find(kw, 1, true) then
                            local score = (#includeKeywords - idx + 1) * 15
                            if obj:IsA("TextLabel") or obj:IsA("ProximityPrompt") then
                                score += 12
                            end
                            local part = GetBestBasePartFromInstance(obj)
                            if part and score > bestScore then
                                bestScore = score
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    if bestPart then
        -- Cari lingkaran interaksi (bulatan) di sekitar konter tersebut agar karakter mendarat tepat di tengah bulatan
        local circlePad = FindCenterCirclePadNear(bestPart.Position, workspace, 22)
        if circlePad then
            return SafeUprightTeleport(circlePad.Position, Vector3.zero)
        else
            return SafeUprightTeleport(bestPart.Position, Vector3.new(0, 0, 0))
        end
    end
    return false
end

-- Teleport khusus ke zona Train di dalam Kandang/Plot milik sendiri
local function TeleportToMyOwnTrainSpot()
    local myPlot = FindMyPlotContainer()

    -- Jika pengguna sudah menyimpan titik relatif kandang sendiri via tombol Copy/Set Pos
    if myPlot and savedTrainRelativeOffset then
        local plotPivot = myPlot:IsA("Model") and myPlot:GetPivot() or (myPlot:FindFirstChildWhichIsA("BasePart", true) and myPlot:FindFirstChildWhichIsA("BasePart", true).CFrame)
        if plotPivot then
            local worldTarget = plotPivot:PointToWorldSpace(savedTrainRelativeOffset)
            return SafeUprightTeleport(worldTarget, Vector3.zero)
        end
    end

    local searchScope = myPlot or workspace
    local bestPart = nil
    local bestScore = -1
    local trainKeywords = {"train", "latih", "gym", "punch", "dummy", "dumbbell", "weight", "barbel"}

    for _, obj in ipairs(searchScope:GetDescendants()) do
        if not IsPartInsideAnyPlayerCharacter(obj) then
            local rawText = ""
            if obj:IsA("TextLabel") and obj.Text ~= "" then
                rawText = obj.Text:lower()
            elseif obj:IsA("ProximityPrompt") then
                rawText = (obj.ActionText .. " " .. obj.ObjectText .. " " .. obj.Name):lower()
            elseif obj:IsA("Model") or obj:IsA("BasePart") then
                rawText = obj.Name:lower()
            end

            if rawText ~= "" then
                for idx, kw in ipairs(trainKeywords) do
                    if rawText:find(kw, 1, true) then
                        local score = (#trainKeywords - idx + 1) * 15
                        if obj:IsA("TextLabel") or obj:IsA("ProximityPrompt") then
                            score += 10
                        end
                        local part = GetBestBasePartFromInstance(obj)
                        if part then
                            -- Jika tidak menemukan folder plot spesifik, prioritaskan yang paling dekat dengan spawn awal Anda
                            if not myPlot and initialSpawnPos then
                                local dist = (part.Position - initialSpawnPos).Magnitude
                                score = score - (dist * 0.25)
                            end
                            if score > bestScore then
                                bestScore = score
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end

    if bestPart then
        local circlePad = FindCenterCirclePadNear(bestPart.Position, searchScope, 18)
        if circlePad then
            return SafeUprightTeleport(circlePad.Position, Vector3.zero)
        end
        return SafeUprightTeleport(bestPart.Position, Vector3.zero)
    end
    return false
end

-- === DISCORD WEBHOOK SENDER ===
local function SendDiscordWebhook(titleText, detailText, hexColor)
    if not webhookUrl or not webhookUrl:find("discord.com/api/webhooks/") then return false end
    local httpReq = (syn and syn.request) or (http and http.request) or http_request or request
    if not httpReq then return false end

    local payload = {
        username = "ZyrexHub V2 Logger",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=150&height=150&format=png",
        embeds = {{
            title = titleText,
            description = detailText,
            color = hexColor or 16723555,
            fields = {
                { name = "Player", value = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", inline = true },
                { name = "Game", value = gameName, inline = true },
                { name = "Total Sesi", value = tostring(totalStealCount) .. " Pet", inline = true }
            },
            footer = { text = "ZyrexScript • " .. os.date("%H:%M:%S") }
        }}
    }

    local ok = pcall(function()
        httpReq({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return ok
end

-- === PEWARNAAN KARTU NOTIFIKASI ===
local function ResolveCardStyleFromText(text)
    local lower = tostring(text or ""):lower()
    if lower:find("rainbow") or lower:find("sovereign") or lower:find("infinite") then
        return Color3.fromRGB(255, 80, 210), true, 16732370
    elseif lower:find("supreme") or lower:find("cosmic") or lower:find("celestial") or lower:find("eternal") then
        return Color3.fromRGB(195, 95, 255), false, 12804095
    elseif lower:find("divine") or lower:find("secret") or lower:find("mythic") or lower:find("ruby") then
        return Color3.fromRGB(255, 55, 95), false, 16725855
    elseif lower:find("legendary") or lower:find("gold") or lower:find("titanic") or lower:find("champion") then
        return Color3.fromRGB(255, 195, 50), false, 16761650
    elseif lower:find("emerald") or lower:find("uncommon") then
        return Color3.fromRGB(60, 220, 125), false, 3988605
    elseif lower:find("diamond") or lower:find("rare") or lower:find("epic") or lower:find("huge") then
        return Color3.fromRGB(80, 200, 255), false, 5294335
    end
    return THEME.Accent, false, 16723555
end

-- === SISTEM NOTIFIKASI KANAN LAYAR ===
local NotifyContainer = Instance.new("Frame")
NotifyContainer.Name = "ZyrexNotifications"
NotifyContainer.Size = UDim2.new(0, 300, 0.72, 0)
NotifyContainer.Position = UDim2.new(1, -312, 0.14, 0)
NotifyContainer.BackgroundTransparency = 1
NotifyContainer.ZIndex = 25
NotifyContainer.Parent = ScreenGui

local NotifyLayout = Instance.new("UIListLayout")
NotifyLayout.Parent = NotifyContainer
NotifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifyLayout.Padding = UDim.new(0, 8)

local function ShowNotif(titleText, detailText, customColor, isRainbow, duration)
    local accentColor = customColor or THEME.Accent

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 62)
    Wrapper.BackgroundTransparency = 1
    Wrapper.Parent = NotifyContainer

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(1, 0, 1, 0)
    Card.Position = UDim2.new(1, 30, 0, 0)
    Card.BackgroundColor3 = THEME.BgMain
    Card.BackgroundTransparency = 0.12
    Card.BorderSizePixel = 0
    Card.Parent = Wrapper
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = accentColor
    Stroke.Thickness = 1.5
    Stroke.Transparency = 0.15
    Stroke.Parent = Card

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(0, 4, 0.72, 0)
    Bar.Position = UDim2.new(0, 8, 0.14, 0)
    Bar.BackgroundColor3 = accentColor
    Bar.BorderSizePixel = 0
    Bar.Parent = Card
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -36, 0, 20)
    TitleLbl.Position = UDim2.new(0, 18, 0, 7)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.TextColor3 = THEME.TextPrimary
    TitleLbl.TextSize = 12
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLbl.Text = titleText
    TitleLbl.Parent = Card

    local DetailLbl = Instance.new("TextLabel")
    DetailLbl.Size = UDim2.new(1, -22, 0, 26)
    DetailLbl.Position = UDim2.new(0, 18, 0, 28)
    DetailLbl.BackgroundTransparency = 1
    DetailLbl.TextColor3 = THEME.Green
    DetailLbl.TextSize = 10.5
    DetailLbl.Font = Enum.Font.GothamSemibold
    DetailLbl.TextXAlignment = Enum.TextXAlignment.Left
    DetailLbl.TextYAlignment = Enum.TextYAlignment.Top
    DetailLbl.TextWrapped = true
    DetailLbl.Text = detailText or ""
    DetailLbl.Parent = Card

    local CloseX = Instance.new("TextButton")
    CloseX.Size = UDim2.new(0, 18, 0, 18)
    CloseX.Position = UDim2.new(1, -22, 0, 5)
    CloseX.BackgroundTransparency = 1
    CloseX.TextColor3 = THEME.TextMuted
    CloseX.Font = Enum.Font.GothamBold
    CloseX.TextSize = 11
    CloseX.Text = "×"
    CloseX.Parent = Card

    local dismissed = false
    local rbConn = nil
    if isRainbow then
        rbConn = RunService.RenderStepped:Connect(function()
            if dismissed then return end
            local c = Color3.fromHSV((tick() * 0.6) % 1, 0.85, 1)
            Stroke.Color = c
            Bar.BackgroundColor3 = c
        end)
    end

    local function Dismiss()
        if dismissed then return end
        dismissed = true
        if rbConn then rbConn:Disconnect() end
        local tw = TweenService:Create(Card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 30, 0, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            if Wrapper then Wrapper:Destroy() end
        end)
    end

    CloseX.MouseButton1Click:Connect(Dismiss)
    TweenService:Create(Card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.delay(duration or 4.2, Dismiss)

    return { titleLbl = TitleLbl, detailLbl = DetailLbl, detail = detailText or "" }
end

-- === 8. PILL STATUS STEALING DENGAN LOADING SPINNER BERPUTAR ===
StealPill = Instance.new("Frame")
StealPill.Name = "StealingStatusPill"
StealPill.Size = UDim2.new(0, 210, 0, 34)
StealPill.Position = UDim2.new(0.5, -105, 0.86, 0)
StealPill.BackgroundColor3 = THEME.BgMain
StealPill.BackgroundTransparency = 0.16
StealPill.Visible = false
StealPill.ZIndex = 20
StealPill.Parent = ScreenGui
Instance.new("UICorner", StealPill).CornerRadius = UDim.new(1, 0)

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = THEME.Accent
PillStroke.Thickness = 1.3
PillStroke.Transparency = 0.25
PillStroke.Parent = StealPill

SpinnerRing = Instance.new("Frame")
SpinnerRing.Size = UDim2.new(0, 18, 0, 18)
SpinnerRing.Position = UDim2.new(0, 14, 0.5, -9)
SpinnerRing.BackgroundTransparency = 1
SpinnerRing.ZIndex = 21
SpinnerRing.Parent = StealPill
Instance.new("UICorner", SpinnerRing).CornerRadius = UDim.new(1, 0)

local SpinnerStroke = Instance.new("UIStroke")
SpinnerStroke.Color = THEME.Accent
SpinnerStroke.Thickness = 2.4
SpinnerStroke.Parent = SpinnerRing

local SpinnerGrad = Instance.new("UIGradient")
SpinnerGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.65, 0.2),
    NumberSequenceKeypoint.new(1, 1)
})
SpinnerGrad.Parent = SpinnerRing

local StealPillLbl = Instance.new("TextLabel")
StealPillLbl.Size = UDim2.new(1, -42, 1, 0)
StealPillLbl.Position = UDim2.new(0, 38, 0, 0)
StealPillLbl.BackgroundTransparency = 1
StealPillLbl.TextColor3 = THEME.TextPrimary
StealPillLbl.TextSize = 12
StealPillLbl.Font = Enum.Font.GothamBold
StealPillLbl.TextXAlignment = Enum.TextXAlignment.Left
StealPillLbl.Text = "Stealing... (0)"
StealPillLbl.ZIndex = 21
StealPillLbl.Parent = StealPill

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    if StealPill.Visible and SpinnerRing then
        SpinnerRing.Rotation = (SpinnerRing.Rotation + 380 * dt) % 360
    end
end))

local function SetStealPillVisible(show)
    if not runningSteal then
        StealPill.Visible = false
        return
    end
    StealPillLbl.Text = "Stealing... (" .. tostring(totalStealCount) .. ")"
    StealPill.Visible = show
end

-- === 6. EKSTRAKSI LENGKAP DATA PET (NAMA, CPS HINGGA OCD+, MUTASI, UKURAN) ===
local function ParseMetadataFromStrings(textList)
    local joined = table.concat(textList, " | ")
    local lower = joined:lower()

    local cpsFound = joined:match("%$[%d%.]+%s*%a*/s")
    if not cpsFound then
        local rawNum = joined:match("([%d%.]+%s*%a+/s)")
        if rawNum then cpsFound = "$" .. rawNum end
    end

    local mutationFound = "Normal"
    for _, mut in ipairs(MUTATION_LIST) do
        if mut ~= "None" and lower:find(mut:lower(), 1, true) then
            mutationFound = mut
            break
        end
    end

    local sizeFound = "Normal"
    for _, sz in ipairs(SIZE_KEYWORDS) do
        if lower:find(sz:lower(), 1, true) then
            sizeFound = sz
            break
        end
    end

    local tierFound = "Common"
    for i = #TIER_LIST, 1, -1 do
        local tr = TIER_LIST[i]
        if lower:find(tr:lower(), 1, true) then
            tierFound = tr
            break
        end
    end

    return cpsFound, mutationFound, sizeFound, tierFound
end

local function ExtractFullPetProfile(tool)
    local texts = {}
    local rawId = tool.Name
    local displayName = nil

    for k, v in pairs(tool:GetAttributes()) do
        local kl = tostring(k):lower()
        local vs = tostring(v)
        table.insert(texts, kl .. ":" .. vs)
        if kl == "id" or kl == "animalid" or kl == "petid" or kl == "uid" or kl == "uuid" or kl == "key" then
            rawId = vs
        elseif kl == "displayname" or kl == "animalname" or kl == "petname" or kl == "animal" then
            if vs ~= "" and not vs:match("^a%d+$") then
                displayName = vs
            end
        end
    end

    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text ~= "" then
            table.insert(texts, desc.Text)
            if not displayName and not desc.Text:find("%$") and not desc.Text:find("/s") and #desc.Text > 2 then
                displayName = desc.Text
            end
        elseif desc:IsA("ValueBase") then
            local nl = desc.Name:lower()
            local vs = tostring(desc.Value)
            table.insert(texts, nl .. ":" .. vs)
            if (nl == "id" or nl == "animalid" or nl == "petid" or nl == "uid") and vs ~= "" then
                rawId = vs
            elseif (nl == "displayname" or nl == "animalname" or nl == "animal") and vs ~= "" and not vs:match("^a%d+$") then
                displayName = vs
            end
        end
    end

    if tool.ToolTip ~= "" then
        table.insert(texts, tool.ToolTip)
    end
    table.insert(texts, tool.Name)

    if not displayName then
        if not tool.Name:match("^a%d+$") then
            displayName = tool.Name
        else
            displayName = "Animal (" .. tool.Name .. ")"
        end
    end

    local cps, mutation, size, tier = ParseMetadataFromStrings(texts)
    return {
        sellId = rawId,
        name = displayName,
        cps = cps or "$?/s",
        mutation = mutation,
        size = size,
        tier = tier
    }
end

local lastPopupCapturedMeta = { name = nil, cps = nil, mutation = nil, size = nil, tick = 0 }

local function RegisterVerifiedCatch(petName, cpsStr, mutationStr, sizeStr)
    SetStealPillVisible(false)

    local finalName = (petName and petName ~= "" and not petName:match("^a%d+$")) and petName
        or ((tick() - lastPopupCapturedMeta.tick) < 2.5 and lastPopupCapturedMeta.name)
        or petName or "Pet Tertangkap"

    local finalCps = (cpsStr and cpsStr ~= "$?/s" and cpsStr ~= "") and cpsStr
        or ((tick() - lastPopupCapturedMeta.tick) < 2.5 and lastPopupCapturedMeta.cps)
        or "$?/s"

    local finalMut = (mutationStr and mutationStr ~= "Normal") and mutationStr
        or ((tick() - lastPopupCapturedMeta.tick) < 2.5 and lastPopupCapturedMeta.mutation)
        or "Normal"

    local finalSize = (sizeStr and sizeStr ~= "Normal") and sizeStr
        or ((tick() - lastPopupCapturedMeta.tick) < 2.5 and lastPopupCapturedMeta.size)
        or "Normal"

    local detailFormatted = string.format("CPS: %s  •  Mutasi: %s  •  Ukuran: %s", finalCps, finalMut, finalSize)
    local combined = finalName .. " " .. detailFormatted
    local isRare = IsRareOrMutated(combined)

    if catchNotifiedThisCycle or (tick() - lastCatchTick) < 0.75 then
        if lastCatchNotifRef and lastCatchNotifRef.detailLbl and lastCatchNotifRef.detailLbl.Parent then
            if finalName and not finalName:match("^Animal %(") then
                lastCatchNotifRef.titleLbl.Text = finalName
            end
            if finalCps ~= "$?/s" then
                lastCatchNotifRef.detailLbl.Text = detailFormatted
            end
        end
        return
    end

    catchNotifiedThisCycle = true
    lastCatchTick = tick()
    totalStealCount += 1
    if statStealCountLbl then
        statStealCountLbl.Text = "Tertangkap: " .. totalStealCount .. " Pet  •  Terjual: " .. totalSoldCount
    end

    local col, rb, hexCol = ResolveCardStyleFromText(combined)

    if webhookEnabled and isRare then
        task.spawn(function()
            SendDiscordWebhook("🎉 Rare Catch: " .. finalName, detailFormatted, hexCol)
        end)
    end

    if not (notifRareOnly and not isRare) then
        lastCatchNotifRef = ShowNotif(finalName, detailFormatted, col, rb, 4.5)
    end
end

-- === PEMANTAU SALDO UANG OTOMATIS ===
local function ParseCashValue(str)
    if type(str) ~= "string" then return nil end
    local numPart, suffix = str:match("%$?%s*([%d%.]+)%s*(%a*)")
    local num = tonumber(numPart)
    if not num then return nil end
    local mults = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12,
        qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24,
        oc = 1e27, no = 1e30, dc = 1e33, udc = 1e36, ud = 1e36,
        ddc = 1e39, dd = 1e39, tdc = 1e42, td = 1e42,
        qad = 1e45, qid = 1e48, sxd = 1e51, spd = 1e54,
        ocd = 1e57, nod = 1e60, vg = 1e63, uvg = 1e66, dvg = 1e69, tv = 1e72, cent = 1e99
    }
    local m = suffix and mults[suffix:lower()] or 1
    return num * m
end

local function ResetSmartBuyState()
    foodWaitingForCash = false
    standWaitingForCash = false
    insufficientCashFlag = false
    bestAffordableFoodIdx = nil
    cashIncreasedSignal = true
end

local function OnCashTextObserved(rawText)
    if not rawText or rawText == "" then return end
    if rawText ~= lastKnownCashSnapshot then
        lastKnownCashSnapshot = rawText
        if statCashLbl then
            statCashLbl.Text = "Saldo terdeteksi: " .. rawText
        end
        local numeric = ParseCashValue(rawText)
        if numeric then
            if lastNumericCash and numeric > lastNumericCash then
                foodWaitingForCash = false
                standWaitingForCash = false
                insufficientCashFlag = false
                cashIncreasedSignal = true
            end
            lastNumericCash = numeric
        else
            foodWaitingForCash = false
            standWaitingForCash = false
            cashIncreasedSignal = true
        end
    end
end

-- === REMOTES GAME ===
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local ShopBuyRemote = RemotesFolder and RemotesFolder:WaitForChild("Shop_Buy", 10)
local StandUpgradeRemote = RemotesFolder and RemotesFolder:WaitForChild("Stand_Upgrade", 10)
local PlotEquipBestRemote = RemotesFolder and RemotesFolder:WaitForChild("Plot_EquipBest", 10)
local PlotSellAnimalRemote = RemotesFolder and RemotesFolder:WaitForChild("Plot_SellAnimal", 10)
local TrainingStartRemote = RemotesFolder and RemotesFolder:WaitForChild("Training_Start", 10)
local TrainingStopRemote = RemotesFolder and RemotesFolder:WaitForChild("Training_Stop", 10)

-- === 2. AUTO SELL BERDASARKAN TIER, MUTATION & ANIMAL YANG DIPILIH ===
local function ShouldSellPetProfile(profile)
    local hasAnyFilter = false
    for _, v in pairs(selectedSellTiers) do if v then hasAnyFilter = true break end end
    if not hasAnyFilter then
        for _, v in pairs(selectedSellMutations) do if v then hasAnyFilter = true break end end
    end
    if not hasAnyFilter then
        for _, v in pairs(selectedSellAnimals) do if v then hasAnyFilter = true break end end
    end
    if not hasAnyFilter then
        return false
    end

    if selectedSellTiers[profile.tier] then return true end
    if selectedSellMutations[profile.mutation] then return true end

    local lowerName = profile.name:lower()
    for animalKey, isSelected in pairs(selectedSellAnimals) do
        if isSelected and lowerName:find(animalKey:lower(), 1, true) then
            return true
        end
    end

    return false
end

local function RunAutoSellCycle()
    if not runningSell or not PlotSellAnimalRemote then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end

    local soldThisPass = 0
    for _, item in ipairs(bp:GetChildren()) do
        if not runningSell then break end
        if item:IsA("Tool") then
            local profile = ExtractFullPetProfile(item)
            if ShouldSellPetProfile(profile) then
                local sellArg = profile.sellId
                pcall(function()
                    PlotSellAnimalRemote:InvokeServer(sellArg)
                end)
                soldThisPass += 1
                totalSoldCount += 1
                task.wait(0.1)
                if soldThisPass >= 5 then break end
            end
        end
    end

    if soldThisPass > 0 then
        if statusSellLbl then
            statusSellLbl.Text = "Status: Terjual " .. totalSoldCount .. " pet sesuai filter"
        end
        if statStealCountLbl then
            statStealCountLbl.Text = "Tertangkap: " .. totalStealCount .. " Pet  •  Terjual: " .. totalSoldCount
        end
    end
end

-- === LISTENER PLAYERGUI (CATCH SCREEN + ANTI-SPAM UANG) ===
table.insert(connections, LocalPlayer.PlayerGui.DescendantAdded:Connect(function(desc)
    if not desc:IsA("TextLabel") then return end

    task.defer(function()
        if not desc or not desc.Parent then return end
        local txt = desc.Text
        if type(txt) ~= "string" or txt == "" then return end

        if txt:match("^%$[%d%.]+%a+$") and not txt:find("/s") then
            OnCashTextObserved(txt)
            table.insert(connections, desc:GetPropertyChangedSignal("Text"):Connect(function()
                OnCashTextObserved(desc.Text)
            end))
            return
        end

        local lower = txt:lower()

        if lower:find("tidak cukup uang") or lower:find("uang tidak cukup") or lower:find("not enough") then
            insufficientCashFlag = true
            lastInsufficientTick = tick()
            if runningFood then
                foodWaitingForCash = true
                if statusFoodLbl then statusFoodLbl.Text = "Status: Menunggu uang cukup" end
            end
            if runningUpgrade then
                standWaitingForCash = true
                if statusStandLbl then statusStandLbl.Text = "Status: Menunggu uang cukup" end
            end
            return
        end

        if runningSteal and txt:find("/s") and not desc:IsDescendantOf(ScreenGui) then
            task.wait(0.05)
            if not desc or not desc.Parent then return end
            local parentContainer = desc.Parent
            if parentContainer.Parent and not parentContainer.Parent:IsA("ScreenGui") and #parentContainer:GetDescendants() <= 4 then
                parentContainer = parentContainer.Parent
            end

            local siblingTexts = { txt }
            local detectedPetName = nil
            local isCatchPopup = false

            for _, sib in ipairs(parentContainer:GetDescendants()) do
                if sib:IsA("TextLabel") and sib ~= desc and sib.Text ~= "" then
                    local st = sib.Text
                    table.insert(siblingTexts, st)
                    if st:lower():find("klik untuk melanjutkan") or st:lower():find("click to continue") or st:find("Obtained!") then
                        isCatchPopup = true
                    elseif not st:find("%$") and #st > 2 then
                        detectedPetName = st
                    end
                end
            end

            if isCatchPopup or detectedPetName then
                local cpsVal, mutVal, sizeVal = ParseMetadataFromStrings(siblingTexts)
                lastPopupCapturedMeta = {
                    name = detectedPetName,
                    cps = cpsVal or txt,
                    mutation = mutVal,
                    size = sizeVal,
                    tick = tick()
                }
                RegisterVerifiedCatch(detectedPetName or "Pet Tertangkap", cpsVal or txt, mutVal, sizeVal)
            end
        elseif lower:find("penuh") or lower:find("full") then
            if runningSell then task.spawn(RunAutoSellCycle) end
            if runningSteal and (tick() - lastPlotFullTick) > 6 then
                lastPlotFullTick = tick()
                ShowNotif("Ransel / Kandang Penuh!", runningSell and "Menjual hewan sesuai filter Anda..." or txt, Color3.fromRGB(255, 85, 85), false)
            end
        end
    end)
end))

task.defer(function()
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Text:match("^%$[%d%.]+%a+$") and not gui.Text:find("/s") then
            OnCashTextObserved(gui.Text)
            table.insert(connections, gui:GetPropertyChangedSignal("Text"):Connect(function()
                OnCashTextObserved(gui.Text)
            end))
            break
        end
    end
end)

-- === ANTI-AFK 20 MENIT ===
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if runningAntiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

-- === SNAPSHOT INVENTORY ===
local function SnapshotOwnedTools()
    local items = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then for _, v in ipairs(bp:GetChildren()) do items[v] = true end end
    local char = LocalPlayer.Character
    if char then for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then items[v] = true end end end
    return items
end

local function FindNewlyAddedTool(beforeSnapshot)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then for _, v in ipairs(bp:GetChildren()) do if not beforeSnapshot[v] then return v end end end
    local char = LocalPlayer.Character
    if char then for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") and not beforeSnapshot[v] then return v end end end
    return nil
end

-- === FLOATING LOGO MINIMIZE (DENGAN ASSET ID LOGO) ===
local FloatingBtn = Instance.new("ImageButton")
FloatingBtn.Name = "FloatingLogo"
FloatingBtn.Size = UDim2.new(0, 56, 0, 56)
FloatingBtn.Position = UDim2.new(0.05, 0, 0.22, 0)
FloatingBtn.BackgroundColor3 = THEME.BgMain
FloatingBtn.Image = DEFAULT_LOGO_ID
FloatingBtn.ScaleType = Enum.ScaleType.Crop
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Visible = false
FloatingBtn.ZIndex = 22
FloatingBtn.Parent = ScreenGui
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(0, 14)

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = THEME.Accent
FloatStroke.Thickness = 2
FloatStroke.Parent = FloatingBtn
MakeDraggable(FloatingBtn, FloatingBtn)

-- === BLACK-SCREEN AFK OVERLAY ===
local AfkOverlay = Instance.new("TextButton")
AfkOverlay.Name = "AfkBatteryOverlay"
AfkOverlay.Size = UDim2.new(1, 0, 1, 0)
AfkOverlay.BackgroundColor3 = Color3.fromRGB(6, 5, 8)
AfkOverlay.Text = ""
AfkOverlay.AutoButtonColor = false
AfkOverlay.Visible = false
AfkOverlay.ZIndex = 50
AfkOverlay.Parent = ScreenGui

local AfkInfoLbl = Instance.new("TextLabel")
AfkInfoLbl.Size = UDim2.new(0.9, 0, 0, 120)
AfkInfoLbl.Position = UDim2.new(0.05, 0, 0.5, -60)
AfkInfoLbl.BackgroundTransparency = 1
AfkInfoLbl.TextColor3 = THEME.TextPrimary
AfkInfoLbl.TextSize = 15
AfkInfoLbl.Font = Enum.Font.GothamBold
AfkInfoLbl.Text = "🌙 MODE HEMAT DAYA AFK AKTIF\nTampilan 3D dinonaktifkan untuk menjaga suhu perangkat.\n\nKetuk layar di mana saja untuk kembali."
AfkInfoLbl.ZIndex = 51
AfkInfoLbl.Parent = AfkOverlay

local disableBlackScreenCallback = nil
AfkOverlay.MouseButton1Click:Connect(function()
    AfkOverlay.Visible = false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if disableBlackScreenCallback then disableBlackScreenCallback() end
end)

-- === POPUP PENJELASAN FORMAL (? INFO MODAL) ===
local InfoModalBackdrop = Instance.new("TextButton")
InfoModalBackdrop.Size = UDim2.new(1, 0, 1, 0)
InfoModalBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
InfoModalBackdrop.BackgroundTransparency = 0.45
InfoModalBackdrop.Text = ""
InfoModalBackdrop.AutoButtonColor = false
InfoModalBackdrop.Visible = false
InfoModalBackdrop.ZIndex = 40
InfoModalBackdrop.Parent = ScreenGui

local InfoModalBox = Instance.new("Frame")
InfoModalBox.Size = UDim2.new(0, 340, 0, 165)
InfoModalBox.Position = UDim2.new(0.5, -170, 0.5, -82)
InfoModalBox.BackgroundColor3 = THEME.BgMain
InfoModalBox.ZIndex = 41
InfoModalBox.Parent = InfoModalBackdrop
Instance.new("UICorner", InfoModalBox).CornerRadius = UDim.new(0, 12)

local InfoModalStroke = Instance.new("UIStroke")
InfoModalStroke.Color = THEME.Accent
InfoModalStroke.Thickness = 1.5
InfoModalStroke.Parent = InfoModalBox

local InfoModalTitle = Instance.new("TextLabel")
InfoModalTitle.Size = UDim2.new(1, -28, 0, 24)
InfoModalTitle.Position = UDim2.new(0, 14, 0, 12)
InfoModalTitle.BackgroundTransparency = 1
InfoModalTitle.TextColor3 = THEME.TextPrimary
InfoModalTitle.Font = Enum.Font.GothamBold
InfoModalTitle.TextSize = 14
InfoModalTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoModalTitle.Text = "Informasi Fitur"
InfoModalTitle.ZIndex = 42
InfoModalTitle.Parent = InfoModalBox

local InfoModalBody = Instance.new("TextLabel")
InfoModalBody.Size = UDim2.new(1, -28, 0, 76)
InfoModalBody.Position = UDim2.new(0, 14, 0, 40)
InfoModalBody.BackgroundTransparency = 1
InfoModalBody.TextColor3 = THEME.TextMuted
InfoModalBody.Font = Enum.Font.Gotham
InfoModalBody.TextSize = 12
InfoModalBody.TextWrapped = true
InfoModalBody.TextXAlignment = Enum.TextXAlignment.Left
InfoModalBody.TextYAlignment = Enum.TextYAlignment.Top
InfoModalBody.Text = ""
InfoModalBody.ZIndex = 42
InfoModalBody.Parent = InfoModalBox

local InfoModalClose = Instance.new("TextButton")
InfoModalClose.Size = UDim2.new(0, 100, 0, 28)
InfoModalClose.Position = UDim2.new(0.5, -50, 1, -38)
InfoModalClose.BackgroundColor3 = THEME.Accent
InfoModalClose.TextColor3 = Color3.new(1, 1, 1)
InfoModalClose.Font = Enum.Font.GothamBold
InfoModalClose.TextSize = 12
InfoModalClose.Text = "Mengerti"
InfoModalClose.ZIndex = 42
InfoModalClose.Parent = InfoModalBox
Instance.new("UICorner", InfoModalClose).CornerRadius = UDim.new(0, 8)

local function ShowFeatureInfo(featureTitle, formalDescription)
    InfoModalTitle.Text = featureTitle
    InfoModalBody.Text = formalDescription
    InfoModalBackdrop.Visible = true
end

InfoModalClose.MouseButton1Click:Connect(function() InfoModalBackdrop.Visible = false end)
InfoModalBackdrop.MouseButton1Click:Connect(function() InfoModalBackdrop.Visible = false end)

-- === MAIN WINDOW V2 (BACKGROUND LEBIH JERNIH & TERANG) ===
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 565, 0, 355)
MainFrame.Position = UDim2.new(0.5, -282, 0.5, -177)
MainFrame.BackgroundColor3 = THEME.BgMain
MainFrame.BackgroundTransparency = 0.34
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = THEME.Border
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local BgImage = Instance.new("ImageLabel")
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.Image = DEFAULT_BG_ID
BgImage.ScaleType = Enum.ScaleType.Crop
BgImage.ImageTransparency = 0.28 -- Background terlihat jelas dan tidak tertutup hitam pekat
BgImage.Parent = MainFrame
Instance.new("UICorner", BgImage).CornerRadius = UDim.new(0, 14)

-- === WELCOME SAMBUTAN POPUP MODAL ===
local WelcomeBackdrop = Instance.new("Frame")
WelcomeBackdrop.Name = "WelcomeModal"
WelcomeBackdrop.Size = UDim2.new(1, 0, 1, 0)
WelcomeBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
WelcomeBackdrop.BackgroundTransparency = 0.35
WelcomeBackdrop.ZIndex = 35
WelcomeBackdrop.Parent = ScreenGui

local WelcomeCard = Instance.new("Frame")
WelcomeCard.Size = UDim2.new(0, 420, 0, 265)
WelcomeCard.Position = UDim2.new(0.5, -210, 0.5, -132)
WelcomeCard.BackgroundColor3 = THEME.BgMain
WelcomeCard.BackgroundTransparency = 0.12
WelcomeCard.ZIndex = 36
WelcomeCard.Parent = WelcomeBackdrop
Instance.new("UICorner", WelcomeCard).CornerRadius = UDim.new(0, 14)

local WelcomeStroke = Instance.new("UIStroke")
WelcomeStroke.Color = THEME.Accent
WelcomeStroke.Thickness = 1.8
WelcomeStroke.Parent = WelcomeCard

local WelcomeLogo = Instance.new("ImageLabel")
WelcomeLogo.Size = UDim2.new(0, 44, 0, 44)
WelcomeLogo.Position = UDim2.new(0.5, -22, 0, 12)
WelcomeLogo.BackgroundColor3 = THEME.BgSidebar
WelcomeLogo.Image = DEFAULT_LOGO_ID
WelcomeLogo.ScaleType = Enum.ScaleType.Crop
WelcomeLogo.ZIndex = 37
WelcomeLogo.Parent = WelcomeCard
Instance.new("UICorner", WelcomeLogo).CornerRadius = UDim.new(0, 10)

local WelcomeTitle = Instance.new("TextLabel")
WelcomeTitle.Size = UDim2.new(1, -24, 0, 26)
WelcomeTitle.Position = UDim2.new(0, 12, 0, 60)
WelcomeTitle.BackgroundTransparency = 1
WelcomeTitle.TextColor3 = THEME.TextPrimary
WelcomeTitle.Font = Enum.Font.GothamBlack
WelcomeTitle.TextSize = 19
WelcomeTitle.Text = "Welcome to ZyrexHub V2"
WelcomeTitle.ZIndex = 37
WelcomeTitle.Parent = WelcomeCard

local WelcomeUser = Instance.new("TextLabel")
WelcomeUser.Size = UDim2.new(1, -24, 0, 18)
WelcomeUser.Position = UDim2.new(0, 12, 0, 86)
WelcomeUser.BackgroundTransparency = 1
WelcomeUser.TextColor3 = THEME.Accent
WelcomeUser.Font = Enum.Font.GothamBold
WelcomeUser.TextSize = 12.5
WelcomeUser.Text = "Halo, " .. LocalPlayer.DisplayName .. "!"
WelcomeUser.ZIndex = 37
WelcomeUser.Parent = WelcomeCard

local WelcomeDesc = Instance.new("TextLabel")
WelcomeDesc.Size = UDim2.new(0.88, 0, 0, 32)
WelcomeDesc.Position = UDim2.new(0.06, 0, 0, 108)
WelcomeDesc.BackgroundTransparency = 1
WelcomeDesc.TextColor3 = THEME.TextMuted
WelcomeDesc.Font = Enum.Font.Gotham
WelcomeDesc.TextSize = 11.5
WelcomeDesc.TextWrapped = true
WelcomeDesc.Text = "Terima kasih telah menggunakan ZyrexHub V2. Bergabunglah ke server Discord kami untuk pembaruan skrip terbaru."
WelcomeDesc.ZIndex = 37
WelcomeDesc.Parent = WelcomeCard

local DiscordBox = Instance.new("Frame")
DiscordBox.Size = UDim2.new(0.86, 0, 0, 48)
DiscordBox.Position = UDim2.new(0.07, 0, 0, 146)
DiscordBox.BackgroundColor3 = THEME.BgSidebar
DiscordBox.ZIndex = 37
DiscordBox.Parent = WelcomeCard
Instance.new("UICorner", DiscordBox).CornerRadius = UDim.new(0, 10)

local DiscordBoxStroke = Instance.new("UIStroke")
DiscordBoxStroke.Color = THEME.Border
DiscordBoxStroke.Thickness = 1
DiscordBoxStroke.Parent = DiscordBox

local DiscordTag = Instance.new("TextLabel")
DiscordTag.Size = UDim2.new(1, 0, 0, 15)
DiscordTag.Position = UDim2.new(0, 0, 0, 5)
DiscordTag.BackgroundTransparency = 1
DiscordTag.TextColor3 = THEME.Blue
DiscordTag.Font = Enum.Font.GothamBold
DiscordTag.TextSize = 9.5
DiscordTag.Text = "DISCORD INVITE"
DiscordTag.ZIndex = 38
DiscordTag.Parent = DiscordBox

local DiscordUrlLbl = Instance.new("TextLabel")
DiscordUrlLbl.Size = UDim2.new(1, 0, 0, 22)
DiscordUrlLbl.Position = UDim2.new(0, 0, 0, 20)
DiscordUrlLbl.BackgroundTransparency = 1
DiscordUrlLbl.TextColor3 = THEME.TextPrimary
DiscordUrlLbl.Font = Enum.Font.GothamBold
DiscordUrlLbl.TextSize = 14
DiscordUrlLbl.Text = "discord.gg/zyrex"
DiscordUrlLbl.ZIndex = 38
DiscordUrlLbl.Parent = DiscordBox

local CopyInviteBtn = Instance.new("TextButton")
CopyInviteBtn.Size = UDim2.new(0.41, 0, 0, 36)
CopyInviteBtn.Position = UDim2.new(0.07, 0, 1, -48)
CopyInviteBtn.BackgroundColor3 = THEME.Green
CopyInviteBtn.TextColor3 = Color3.new(1, 1, 1)
CopyInviteBtn.Font = Enum.Font.GothamBold
CopyInviteBtn.TextSize = 13
CopyInviteBtn.Text = "Copy Invite"
CopyInviteBtn.ZIndex = 37
CopyInviteBtn.Parent = WelcomeCard
Instance.new("UICorner", CopyInviteBtn).CornerRadius = UDim.new(0, 9)

local CloseWelcomeBtn = Instance.new("TextButton")
CloseWelcomeBtn.Size = UDim2.new(0.41, 0, 0, 36)
CloseWelcomeBtn.Position = UDim2.new(0.52, 0, 1, -48)
CloseWelcomeBtn.BackgroundColor3 = THEME.Red
CloseWelcomeBtn.TextColor3 = Color3.new(1, 1, 1)
CloseWelcomeBtn.Font = Enum.Font.GothamBold
CloseWelcomeBtn.TextSize = 13
CloseWelcomeBtn.Text = "Close"
CloseWelcomeBtn.ZIndex = 37
CloseWelcomeBtn.Parent = WelcomeCard
Instance.new("UICorner", CloseWelcomeBtn).CornerRadius = UDim.new(0, 9)

CopyInviteBtn.MouseButton1Click:Connect(function()
    local clipFn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if clipFn then
        pcall(function() clipFn(DISCORD_LINK) end)
        CopyInviteBtn.Text = "Copied!"
        ShowNotif("Tautan Disalin", "Undangan Discord berhasil disalin ke clipboard.", THEME.Green, false, 3)
        task.delay(1.8, function()
            if CopyInviteBtn then CopyInviteBtn.Text = "Copy Invite" end
        end)
    else
        CopyInviteBtn.Text = "discord.gg/zyrex"
    end
end)

CloseWelcomeBtn.MouseButton1Click:Connect(function()
    WelcomeBackdrop.Visible = false
    MainFrame.Visible = true
end)

-- === TOP BAR ===
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = THEME.BgSidebar
TopBar.BackgroundTransparency = 0.45
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
MakeDraggable(TopBar, MainFrame)

local TopDivider = Instance.new("Frame")
TopDivider.Size = UDim2.new(1, 0, 0, 1)
TopDivider.Position = UDim2.new(0, 0, 1, -1)
TopDivider.BackgroundColor3 = THEME.Border
TopDivider.BorderSizePixel = 0
TopDivider.Parent = TopBar

-- Logo Image di Header (Menggunakan Asset ID)
local HeaderIcon = Instance.new("ImageLabel")
HeaderIcon.Size = UDim2.new(0, 30, 0, 30)
HeaderIcon.Position = UDim2.new(0, 14, 0.5, -15)
HeaderIcon.BackgroundColor3 = THEME.BgMain
HeaderIcon.Image = DEFAULT_LOGO_ID
HeaderIcon.ScaleType = Enum.ScaleType.Crop
HeaderIcon.Parent = TopBar
Instance.new("UICorner", HeaderIcon).CornerRadius = UDim.new(0, 8)

local HeaderIconStroke = Instance.new("UIStroke")
HeaderIconStroke.Color = THEME.Accent
HeaderIconStroke.Thickness = 1.3
HeaderIconStroke.Parent = HeaderIcon

local function ApplyLogoAsset(assetId)
    local formatted = FormatAssetId(assetId)
    if not formatted then return false end
    FloatingBtn.Image = formatted
    HeaderIcon.Image = formatted
    WelcomeLogo.Image = formatted
    return true
end

local function ApplyBackgroundAsset(assetId)
    local formatted = FormatAssetId(assetId)
    if not formatted then return false end
    BgImage.Image = formatted
    return true
end

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -150, 0, 20)
TitleLbl.Position = UDim2.new(0, 52, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3 = THEME.TextPrimary
TitleLbl.TextSize = 14
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.Text = "ZyrexHub V2  |  " .. gameName
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
TitleLbl.Parent = TopBar

local SubTitleLbl = Instance.new("TextLabel")
SubTitleLbl.Size = UDim2.new(1, -150, 0, 16)
SubTitleLbl.Position = UDim2.new(0, 52, 0, 25)
SubTitleLbl.BackgroundTransparency = 1
SubTitleLbl.TextColor3 = THEME.TextMuted
SubTitleLbl.TextSize = 11
SubTitleLbl.Font = Enum.Font.Gotham
SubTitleLbl.Text = "ZyrexScript  •  discord.gg/zyrex"
SubTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLbl.Parent = TopBar

local function CreateHeaderBtn(text, offsetX, hoverColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 26, 0, 26)
    btn.Position = UDim2.new(1, offsetX, 0.5, -13)
    btn.BackgroundColor3 = THEME.BgCard
    btn.BackgroundTransparency = 0.25
    btn.TextColor3 = THEME.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = text
    btn.Parent = TopBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local st = Instance.new("UIStroke")
    st.Color = THEME.Border
    st.Thickness = 1
    st.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.BgCard}):Play()
    end)
    return btn
end

local CloseBtn = CreateHeaderBtn("×", -38, Color3.fromRGB(200, 45, 75))
local CompactBtn = CreateHeaderBtn("▣", -70, THEME.BgCardHover)
local MinimizeBtn = CreateHeaderBtn("–", -102, THEME.BgCardHover)

local isCompactMode = false
CompactBtn.MouseButton1Click:Connect(function()
    isCompactMode = not isCompactMode
    local targetSize = isCompactMode and UDim2.new(0, 475, 0, 295) or UDim2.new(0, 565, 0, 355)
    TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end)

FloatingBtn.MouseButton1Click:Connect(function()
    FloatingBtn.Visible = false
    MainFrame.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    runningTap, runningSteal, runningEquip, runningSell, runningTrain = false, false, false, false, false
    runningUpgrade, runningFood, runningMicroStep, flyEnabled, noclipEnabled = false, false, false, false, false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    ScreenGui:Destroy()
end)

-- === SIDEBAR + PROFIL PLAYER ===
local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 165, 1, -48)
SideBar.Position = UDim2.new(0, 0, 0, 48)
SideBar.BackgroundColor3 = THEME.BgSidebar
SideBar.BackgroundTransparency = 0.48
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame

local SideDivider = Instance.new("Frame")
SideDivider.Size = UDim2.new(0, 1, 1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 0)
SideDivider.BackgroundColor3 = THEME.Border
SideDivider.BorderSizePixel = 0
SideDivider.Parent = SideBar

local TabListFrame = Instance.new("Frame")
TabListFrame.Size = UDim2.new(1, -16, 1, -74)
TabListFrame.Position = UDim2.new(0, 8, 0, 10)
TabListFrame.BackgroundTransparency = 1
TabListFrame.Parent = SideBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.Parent = TabListFrame
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 5)

local ProfileCard = Instance.new("Frame")
ProfileCard.Size = UDim2.new(1, -16, 0, 52)
ProfileCard.Position = UDim2.new(0, 8, 1, -60)
ProfileCard.BackgroundColor3 = THEME.BgCard
ProfileCard.BackgroundTransparency = 0.35
ProfileCard.Parent = SideBar
Instance.new("UICorner", ProfileCard).CornerRadius = UDim.new(0, 10)

local ProfileStroke = Instance.new("UIStroke")
ProfileStroke.Color = THEME.Border
ProfileStroke.Thickness = 1
ProfileStroke.Parent = ProfileCard

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.new(0, 34, 0, 34)
AvatarImg.Position = UDim2.new(0, 9, 0.5, -17)
AvatarImg.BackgroundColor3 = THEME.BgMain
AvatarImg.Parent = ProfileCard
Instance.new("UICorner", AvatarImg).CornerRadius = UDim.new(1, 0)

local AvatarStroke = Instance.new("UIStroke")
AvatarStroke.Color = THEME.Accent
AvatarStroke.Thickness = 1.4
AvatarStroke.Parent = AvatarImg

task.spawn(function()
    local okThumb, content = pcall(function()
        return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if okThumb and content then AvatarImg.Image = content end
end)

local DisplayNameLbl = Instance.new("TextLabel")
DisplayNameLbl.Size = UDim2.new(1, -52, 0, 17)
DisplayNameLbl.Position = UDim2.new(0, 49, 0, 9)
DisplayNameLbl.BackgroundTransparency = 1
DisplayNameLbl.TextColor3 = THEME.TextPrimary
DisplayNameLbl.TextSize = 11
DisplayNameLbl.Font = Enum.Font.GothamBold
DisplayNameLbl.Text = LocalPlayer.DisplayName
DisplayNameLbl.TextXAlignment = Enum.TextXAlignment.Left
DisplayNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
DisplayNameLbl.Parent = ProfileCard

local UserNameLbl = Instance.new("TextLabel")
UserNameLbl.Size = UDim2.new(1, -52, 0, 15)
UserNameLbl.Position = UDim2.new(0, 49, 0, 26)
UserNameLbl.BackgroundTransparency = 1
UserNameLbl.TextColor3 = THEME.TextMuted
UserNameLbl.TextSize = 10
UserNameLbl.Font = Enum.Font.Gotham
UserNameLbl.Text = "@" .. LocalPlayer.Name
UserNameLbl.TextXAlignment = Enum.TextXAlignment.Left
UserNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
UserNameLbl.Parent = ProfileCard

-- === CONTAINER HALAMAN ===
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -177, 1, -60)
PagesContainer.Position = UDim2.new(0, 171, 0, 54)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local tabs = {}
local activeTabName = nil

local function CreateTab(tabName, iconGlyph)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.BgCard
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = TabListFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.58, 0)
    indicator.Position = UDim2.new(0, 4, 0.21, 0)
    indicator.BackgroundColor3 = THEME.Accent
    indicator.Visible = false
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 24, 1, 0)
    iconLbl.Position = UDim2.new(0, 12, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.TextColor3 = THEME.TextMuted
    iconLbl.TextSize = 13
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.Text = iconGlyph
    iconLbl.Parent = btn

    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, -42, 1, 0)
    textLbl.Position = UDim2.new(0, 38, 0, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.TextColor3 = THEME.TextMuted
    textLbl.TextSize = 12
    textLbl.Font = Enum.Font.GothamSemibold
    textLbl.Text = tabName
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.Parent = PagesContainer

    local layout = Instance.new("UIListLayout")
    layout.Parent = page
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end))

    local tabObj = { btn = btn, indicator = indicator, iconLbl = iconLbl, textLbl = textLbl, page = page }
    tabs[tabName] = tabObj

    local function SelectTab()
        activeTabName = tabName
        for name, item in pairs(tabs) do
            local isSelected = (name == tabName)
            item.page.Visible = isSelected
            item.indicator.Visible = isSelected
            TweenService:Create(item.btn, TweenInfo.new(0.18), {
                BackgroundTransparency = isSelected and 0.35 or 1
            }):Play()
            item.iconLbl.TextColor3 = isSelected and THEME.Accent or THEME.TextMuted
            item.textLbl.TextColor3 = isSelected and THEME.TextPrimary or THEME.TextMuted
        end
    end

    btn.MouseButton1Click:Connect(SelectTab)
    if not activeTabName then SelectTab() end
    return page
end

-- === BUILDER KOMPONEN UI V2 ===
local function CreateHelpButton(parent, titleText, formalHelpText)
    local qBtn = Instance.new("TextButton")
    qBtn.Size = UDim2.new(0, 20, 0, 20)
    qBtn.BackgroundColor3 = THEME.BgSidebar
    qBtn.BackgroundTransparency = 0.25
    qBtn.TextColor3 = THEME.TextMuted
    qBtn.Font = Enum.Font.GothamBold
    qBtn.TextSize = 11
    qBtn.Text = "?"
    qBtn.Parent = parent
    Instance.new("UICorner", qBtn).CornerRadius = UDim.new(1, 0)

    local st = Instance.new("UIStroke")
    st.Color = THEME.Border
    st.Thickness = 1
    st.Parent = qBtn

    qBtn.MouseButton1Click:Connect(function()
        ShowFeatureInfo(titleText, formalHelpText)
    end)
    return qBtn
end

local function CreateCardToggle(parentPage, titleText, descText, formalHelp, defaultState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 56)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.36
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = defaultState and THEME.AccentSoft or THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 0, 20)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = titleText
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleText, formalHelp)
    qBtn.Position = UDim2.new(1, -82, 0.5, -10)

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -100, 0, 18)
    desc.Position = UDim2.new(0, 14, 0, 29)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = THEME.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.Text = descText
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.Parent = card

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(0, 42, 0, 22)
    switchBtn.Position = UDim2.new(1, -54, 0.5, -11)
    switchBtn.BackgroundColor3 = defaultState and THEME.Accent or THEME.SwitchOff
    switchBtn.Text = ""
    switchBtn.Parent = card
    Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 205, 215)
    knob.Parent = switchBtn
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState or false
    local function SetState(newState, silent)
        state = newState
        TweenService:Create(switchBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = state and THEME.Accent or THEME.SwitchOff
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 205, 215)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.18), {
            Color = state and THEME.AccentSoft or THEME.Border
        }):Play()
        if not silent then callback(state, desc) end
    end

    switchBtn.MouseButton1Click:Connect(function()
        SetState(not state, false)
    end)

    return desc, SetState
end

local function CreateCardAction(parentPage, titleText, descText, formalHelp, actionGlyph, callback)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, -6, 0, 56)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.36
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -92, 0, 20)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = titleText
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleText, formalHelp)
    qBtn.Position = UDim2.new(1, -74, 0.5, -10)

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -92, 0, 18)
    desc.Position = UDim2.new(0, 14, 0, 29)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = THEME.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.Text = descText
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.Parent = card

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 30, 0, 30)
    badge.Position = UDim2.new(1, -44, 0.5, -15)
    badge.BackgroundColor3 = THEME.BgSidebar
    badge.BackgroundTransparency = 0.25
    badge.TextColor3 = THEME.Accent
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 14
    badge.Text = actionGlyph or "✦"
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

    card.MouseButton1Click:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.12), {Color = THEME.Accent}):Play()
        task.delay(0.2, function()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.2), {Color = THEME.Border}):Play() end
        end)
        callback(desc, badge)
    end)

    return desc
end

local function CreateCardSlider(parentPage, titleText, formalHelp, minVal, maxVal, defaultVal, onChanged)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 64)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.36
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -54, 0, 20)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = titleText .. ": " .. tostring(defaultVal)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleText, formalHelp)
    qBtn.Position = UDim2.new(1, -34, 0, 8)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -28, 0, 14)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = THEME.BgInput
    track.BackgroundTransparency = 0.2
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local function UpdateFromInput(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * relX + 0.5)
        fill.Size = UDim2.new(relX, 0, 1, 0)
        title.Text = titleText .. ": " .. tostring(val)
        onChanged(val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            UpdateFromInput(input.Position)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    sliding = false
                end
            end)
        end
    end)

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromInput(input.Position)
        end
    end))
end

local function CreateMultiSelectCard(parentPage, titleText, formalHelp, itemsProvider, selectionMap)
    local expanded = false
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 48)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.36
    card.ClipsDescendants = true
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local headerBar = Instance.new("Frame")
    headerBar.Size = UDim2.new(1, 0, 0, 48)
    headerBar.BackgroundTransparency = 1
    headerBar.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -135, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = titleText
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = headerBar

    local qBtn = CreateHelpButton(headerBar, titleText, formalHelp)
    qBtn.Position = UDim2.new(1, -118, 0.5, -10)

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 82, 0, 28)
    selectBtn.Position = UDim2.new(1, -92, 0.5, -14)
    selectBtn.BackgroundColor3 = THEME.BgSidebar
    selectBtn.BackgroundTransparency = 0.2
    selectBtn.TextColor3 = THEME.TextPrimary
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.TextSize = 11.5
    selectBtn.Text = "Select..."
    selectBtn.Parent = headerBar
    Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 7)

    local selStroke = Instance.new("UIStroke")
    selStroke.Color = THEME.Border
    selStroke.Thickness = 1
    selStroke.Parent = selectBtn

    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Size = UDim2.new(1, -20, 0, 148)
    listContainer.Position = UDim2.new(0, 10, 0, 50)
    listContainer.BackgroundColor3 = THEME.BgInput
    listContainer.BackgroundTransparency = 0.25
    listContainer.BorderSizePixel = 0
    listContainer.ScrollBarThickness = 3
    listContainer.ScrollBarImageColor3 = THEME.Accent
    listContainer.Parent = card
    Instance.new("UICorner", listContainer).CornerRadius = UDim.new(0, 8)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = listContainer
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 3)

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 6)
    listPad.PaddingBottom = UDim.new(0, 6)
    listPad.PaddingLeft = UDim.new(0, 8)
    listPad.PaddingRight = UDim.new(0, 8)
    listPad.Parent = listContainer

    local function UpdateSelectCountText()
        local count = 0
        for _, v in pairs(selectionMap) do
            if v then count += 1 end
        end
        selectBtn.Text = count > 0 and ("Selected (" .. count .. ")") or "Select..."
        selectBtn.TextColor3 = count > 0 and THEME.Accent or THEME.TextPrimary
    end

    local function RebuildOptions()
        for _, child in ipairs(listContainer:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local items = itemsProvider()
        for _, itemName in ipairs(items) do
            local rowBtn = Instance.new("TextButton")
            rowBtn.Size = UDim2.new(1, 0, 0, 24)
            rowBtn.BackgroundColor3 = THEME.BgCard
            rowBtn.BackgroundTransparency = selectionMap[itemName] and 0.15 or 0.65
            rowBtn.Font = Enum.Font.GothamSemibold
            rowBtn.TextSize = 11.5
            rowBtn.TextXAlignment = Enum.TextXAlignment.Left
            rowBtn.Text = (selectionMap[itemName] and "[ON]  " or "[OFF] ") .. itemName
            rowBtn.TextColor3 = selectionMap[itemName] and THEME.Green or THEME.TextMuted
            rowBtn.Parent = listContainer
            Instance.new("UICorner", rowBtn).CornerRadius = UDim.new(0, 6)

            local rPad = Instance.new("UIPadding")
            rPad.PaddingLeft = UDim.new(0, 8)
            rPad.Parent = rowBtn

            rowBtn.MouseButton1Click:Connect(function()
                selectionMap[itemName] = not selectionMap[itemName]
                local active = selectionMap[itemName]
                rowBtn.Text = (active and "[ON]  " or "[OFF] ") .. itemName
                rowBtn.TextColor3 = active and THEME.Green or THEME.TextMuted
                rowBtn.BackgroundTransparency = active and 0.15 or 0.65
                UpdateSelectCountText()
            end)
        end
        listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
        UpdateSelectCountText()
    end

    selectBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            RebuildOptions()
        end
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = expanded and UDim2.new(1, -6, 0, 206) or UDim2.new(1, -6, 0, 48)
        }):Play()
        stroke.Color = expanded and THEME.AccentSoft or THEME.Border
    end)

    return RebuildOptions
end

local function CreateCardInput(parentPage, titleText, formalHelp, placeholderText, onChanged)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 68)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.36
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -54, 0, 18)
    title.Position = UDim2.new(0, 14, 0, 7)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Text = titleText
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleText, formalHelp)
    qBtn.Position = UDim2.new(1, -34, 0, 6)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -28, 0, 28)
    box.Position = UDim2.new(0, 14, 0, 30)
    box.BackgroundColor3 = THEME.BgInput
    box.BackgroundTransparency = 0.2
    box.TextColor3 = THEME.TextPrimary
    box.PlaceholderColor3 = THEME.TextMuted
    box.PlaceholderText = placeholderText
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextSize = 11
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.Parent = card
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = box

    box.FocusLost:Connect(function()
        onChanged(box.Text, box)
    end)

    return box
end

-- === POSISI LOCK + MICRO-STEP WAKEUP ===
local function StartPositionLock()
    table.insert(connections, RunService.Heartbeat:Connect(function()
        if runningSteal and savedPadCFrame and not isMicroStepping then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                if (hrp.Position - savedPadCFrame.Position).Magnitude > 0.35 then
                    hrp.CFrame = savedPadCFrame
                end
            end
        end
    end))
end
StartPositionLock()

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        if not initialSpawnPos then initialSpawnPos = hrp.Position end
        if runningSteal and savedPadCFrame then
            task.wait(0.1)
            hrp.CFrame = savedPadCFrame
        end
    end
end))

local lastMicroStepTick = 0
local function PerformMicroStepWakeup()
    if not runningMicroStep or (tick() - lastMicroStepTick) < 1.8 then return end
    lastMicroStepTick = tick()

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    isMicroStepping = true
    pcall(function()
        hum:Move(Vector3.new(0, 0, -1), true)
        task.wait(0.08)
        hum:Move(Vector3.new(0, 0, 1), true)
        task.wait(0.08)
        hum:Move(Vector3.zero, true)
    end)
    if runningSteal and savedPadCFrame then
        hrp.CFrame = savedPadCFrame
    end
    isMicroStepping = false
end

-- === SMART ANTI-SPAM BUY FOOD & UPGRADE STAND ===
local function TrySingleFoodBuy(index)
    if not ShopBuyRemote then return false end
    insufficientCashFlag = false
    local ok, res = pcall(function() return ShopBuyRemote:InvokeServer(index) end)
    task.wait(0.16)
    if insufficientCashFlag or (tick() - lastInsufficientTick) < 0.35 then return false end
    return ok and res ~= false
end

local function RunSmartFoodCycle()
    if not runningFood or not ShopBuyRemote or foodWaitingForCash then return end
    PerformMicroStepWakeup()

    if bestAffordableFoodIdx then
        if bestAffordableFoodIdx < 30 and TrySingleFoodBuy(bestAffordableFoodIdx + 1) then
            bestAffordableFoodIdx += 1
            if statusFoodLbl then statusFoodLbl.Text = "Status: Membeli Food Tingkat #" .. bestAffordableFoodIdx end
            return
        end
        if TrySingleFoodBuy(bestAffordableFoodIdx) then
            if statusFoodLbl then statusFoodLbl.Text = "Status: Membeli Food Tingkat #" .. bestAffordableFoodIdx end
        else
            foodWaitingForCash = true
            if statusFoodLbl then statusFoodLbl.Text = "Status: Menunggu uang cukup" end
        end
        return
    end

    for i = 30, 1, -1 do
        if not runningFood then return end
        if TrySingleFoodBuy(i) then
            bestAffordableFoodIdx = i
            if statusFoodLbl then statusFoodLbl.Text = "Status: Terkunci di Food Tingkat #" .. i end
            return
        end
        if i == 1 then
            foodWaitingForCash = true
            if statusFoodLbl then statusFoodLbl.Text = "Status: Menunggu uang cukup" end
        end
    end
end

local function RunSmartStandCycle()
    if not runningUpgrade or not StandUpgradeRemote or standWaitingForCash then return end
    PerformMicroStepWakeup()

    insufficientCashFlag = false
    local ok, res = pcall(function() return StandUpgradeRemote:InvokeServer() end)
    task.wait(0.18)

    if insufficientCashFlag or (tick() - lastInsufficientTick) < 0.35 or (ok and res == false) then
        standWaitingForCash = true
        if statusStandLbl then statusStandLbl.Text = "Status: Menunggu uang cukup" end
    else
        if statusStandLbl then statusStandLbl.Text = "Status: Stand berhasil ditingkatkan" end
    end
end

-- === ENGINE PLAYER (WALKSPEED, JUMPPOWER, FLY, NOCLIP) ===
local flyBodyVel = nil
local flyBodyGyro = nil

local function StopFly()
    if flyBodyVel then flyBodyVel:Destroy() flyBodyVel = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
end

local function StartFly()
    StopFly()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    flyBodyVel = Instance.new("BodyVelocity")
    flyBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBodyVel.Velocity = Vector3.zero
    flyBodyVel.Parent = hrp

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBodyGyro.P = 9e4
    flyBodyGyro.CFrame = hrp.CFrame
    flyBodyGyro.Parent = hrp
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if hum then
        if walkSpeedEnabled then hum.WalkSpeed = walkSpeedValue end
        if jumpPowerEnabled then
            hum.UseJumpPower = true
            hum.JumpPower = jumpPowerValue
        end
    end

    if flyEnabled and hrp and hum then
        if not flyBodyVel or not flyBodyVel.Parent then
            StartFly()
        end
        local cam = workspace.CurrentCamera
        if cam and flyBodyVel and flyBodyGyro then
            local moveDir = hum.MoveDirection
            local vertical = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vertical -= 1 end

            local targetVel = Vector3.zero
            if moveDir.Magnitude > 0.05 then
                local camLook = cam.CFrame.LookVector
                local camRight = cam.CFrame.RightVector
                local flatForward = Vector3.new(camLook.X, 0, camLook.Z).Unit
                local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
                local forwardAmt = moveDir:Dot(flatForward)
                local rightAmt = moveDir:Dot(flatRight)
                targetVel = (camLook * forwardAmt + camRight * rightAmt) * flySpeedValue
            end
            targetVel = targetVel + Vector3.new(0, vertical * flySpeedValue, 0)
            flyBodyVel.Velocity = targetVel
            flyBodyGyro.CFrame = cam.CFrame
        end
    end
end))

table.insert(connections, RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

-- === MEMBUAT 4 TAB NAVIGASI ===
local FarmPage   = CreateTab("Auto Farm", "⚡")
local ShopPage   = CreateTab("Shop & Stand", "🛒")
local PlayerPage = CreateTab("Player", "🏃")
local AfkPage    = CreateTab("AFK & Stats", "🛡️")

-- ==========================================
-- TAB 1: AUTO FARM & AUTO SELL FILTER
-- ==========================================
CreateCardToggle(
    FarmPage,
    "Auto Tap x2",
    "Mengaktifkan bonus ketukan ganda secara otomatis saat latihan",
    "Fitur ini secara otomatis menekan tombol bonus ketukan ganda (x2) yang muncul selama sesi latihan berlangsung.",
    false,
    function(state) runningTap = state end
)

CreateCardToggle(
    FarmPage,
    "Auto Steal Pet",
    "Menangkap hewan secara otomatis dan menampilkan detail hasil tangkapan",
    "Fitur ini mempertahankan posisi karakter pada titik lempar, melakukan lemparan secara otomatis, serta menampilkan nama, pendapatan per detik, mutasi, dan ukuran hewan yang didapatkan.",
    false,
    function(state)
        runningSteal = state
        if state then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then savedPadCFrame = hrp.CFrame end
            totalStealCount = 0
            SetStealPillVisible(true)
            ShowNotif("Auto Steal Aktif", "Posisi dikunci dan penangkapan otomatis dimulai.", THEME.Accent, false)
        else
            SetStealPillVisible(false)
        end
    end
)

statusTrainLbl = CreateCardToggle(
    FarmPage,
    "Auto Train",
    "Status: Nonaktif (Otomatis ke tempat latihan kandang sendiri)",
    "Saat diaktifkan, karakter akan berpindah tepat ke tengah zona latihan di kandang Anda sendiri dan memulai sesi latihan secara otomatis. Saat dinonaktifkan, sesi latihan akan dihentikan.",
    false,
    function(state, desc)
        runningTrain = state
        if state then
            if runningSteal then
                savedPadCFrame = nil
            end
            local okTp = TeleportToMyOwnTrainSpot()
            if TrainingStartRemote then
                task.spawn(function() pcall(function() TrainingStartRemote:InvokeServer() end) end)
            end
            desc.Text = okTp and "Status: Berlatih di zona latihan kandang Anda" or "Status: Sesi latihan dimulai"
            ShowNotif("Auto Train Aktif", "Karakter diarahkan ke tempat latihan kandang Anda.", THEME.Green, false)
        else
            if TrainingStopRemote then
                task.spawn(function() pcall(function() TrainingStopRemote:InvokeServer() end) end)
            end
            desc.Text = "Status: Sesi latihan dihentikan"
            ShowNotif("Auto Train Berhenti", "Sesi latihan telah diakhiri.", THEME.Gold, false)
        end
    end
)

CreateCardAction(
    FarmPage,
    "Set & Copy Posisi Kandang (Train)",
    "Berdiri di tengah bulatan Train lalu ketuk untuk menyimpan posisi relatif",
    "Menyimpan posisi berdiri Anda sebagai titik latihan relatif terhadap kandang Anda sehingga tetap akurat meskipun lokasi kandang berpindah-pindah secara acak, sekaligus menyalin koordinat ke clipboard.",
    "📌",
    function(desc)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local myPlot = FindMyPlotContainer()
        local posStr = string.format("Vector3.new(%.2f, %.2f, %.2f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)

        if myPlot then
            local plotPivot = myPlot:IsA("Model") and myPlot:GetPivot() or (myPlot:FindFirstChildWhichIsA("BasePart", true) and myPlot:FindFirstChildWhichIsA("BasePart", true).CFrame)
            if plotPivot then
                savedTrainRelativeOffset = plotPivot:PointToObjectSpace(hrp.Position)
                posStr = posStr .. string.format(" | Offset: Vector3.new(%.2f, %.2f, %.2f)", savedTrainRelativeOffset.X, savedTrainRelativeOffset.Y, savedTrainRelativeOffset.Z)
                desc.Text = "Titik relatif kandang tersimpan & disalin!"
            end
        else
            desc.Text = "Koordinat disalin: " .. string.format("%.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        end

        local clipFn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
        if clipFn then pcall(function() clipFn(posStr) end) end
        ShowNotif("Posisi Tersimpan & Disalin", posStr, THEME.Blue, false, 4)
    end
)

CreateCardToggle(
    FarmPage,
    "Auto Equip Best",
    "Memasang hewan dengan pendapatan tertinggi secara berkala",
    "Fitur ini secara berkala memilih dan menempatkan hewan dengan nilai pendapatan per detik tertinggi ke dalam kandang Anda.",
    false,
    function(state)
        runningEquip = state
        if state and PlotEquipBestRemote then
            task.spawn(function() pcall(function() PlotEquipBestRemote:InvokeServer() end) end)
        end
    end
)

CreateCardAction(
    FarmPage,
    "Go To Sell Pet",
    "Berpindah tegak lurus ke tengah lingkaran penjualan hewan",
    "Memindahkan posisi karakter Anda secara instan dan berdiri tegak di tengah area penjualan hewan.",
    "🏪",
    function(desc)
        local ok = TeleportToPlazaFacility({"jual", "sell", "merchant", "penjual"}, {"food", "makanan", "toko", "shop", "train"})
        desc.Text = ok and "Berhasil tiba di tengah area Sell Pet" or "Area penjualan tidak ditemukan di sekitar"
        ShowNotif("Teleport Sell Pet", ok and "Karakter berdiri di tengah lingkaran penjualan." or "Mencari konter penjualan...", THEME.Blue, false)
    end
)

statusSellLbl = CreateCardToggle(
    FarmPage,
    "Auto Sell Selected",
    "Status: Nonaktif (Pilih filter Tier, Mutasi, atau Hewan di bawah)",
    "Menjual hewan di dalam tas secara otomatis apabila memenuhi salah satu kriteria Tier, Mutasi, atau Jenis Hewan yang Anda pilih pada daftar di bawah.",
    false,
    function(state, desc)
        runningSell = state
        if state then
            desc.Text = "Status: Aktif menjual sesuai kriteria pilihan"
            task.spawn(RunAutoSellCycle)
        else
            desc.Text = "Status: Nonaktif"
        end
    end
)

CreateMultiSelectCard(
    FarmPage,
    "Select Tier To Sell",
    "Pilih tingkat kelangkaan (Tier) hewan yang ingin dijual secara otomatis saat Auto Sell aktif.",
    function() return TIER_LIST end,
    selectedSellTiers
)

CreateMultiSelectCard(
    FarmPage,
    "Select Mutations To Sell",
    "Pilih jenis mutasi hewan yang ingin dijual secara otomatis saat Auto Sell aktif.",
    function() return MUTATION_LIST end,
    selectedSellMutations
)

CreateMultiSelectCard(
    FarmPage,
    "Select Animals To Sell",
    "Pilih nama hewan tertentu yang ingin dijual secara otomatis saat Auto Sell aktif.",
    function()
        local map = {}
        local combined = {}
        for _, name in ipairs(DEFAULT_ANIMALS) do
            if not map[name] then map[name] = true table.insert(combined, name) end
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if item:IsA("Tool") then
                    local prof = ExtractFullPetProfile(item)
                    if prof.name and not prof.name:match("^Animal %(") and not map[prof.name] then
                        map[prof.name] = true
                        table.insert(combined, prof.name)
                    end
                end
            end
        end
        table.sort(combined)
        return combined
    end,
    selectedSellAnimals
)

-- ==========================================
-- TAB 2: SHOP & STAND
-- ==========================================
CreateCardAction(
    ShopPage,
    "Go To Shop Makanan",
    "Berpindah tegak lurus ke tengah lingkaran toko makanan hewan",
    "Memindahkan posisi karakter Anda secara instan dan berdiri tegak di tengah area pembelian makanan hewan.",
    "🍖",
    function(desc)
        local ok = TeleportToPlazaFacility({"food", "makanan", "toko", "shop", "feed"}, {"sell", "jual", "train", "latih"})
        desc.Text = ok and "Berhasil tiba di tengah Shop Makanan" or "Toko makanan tidak ditemukan di sekitar"
        ShowNotif("Teleport Shop Makanan", ok and "Karakter berdiri di tengah lingkaran toko makanan." or "Mencari toko makanan...", THEME.Gold, false)
    end
)

statusFoodLbl = CreateCardToggle(
    ShopPage,
    "Smart Auto Buy Food",
    "Status: Siap membeli makanan terbaik sesuai saldo",
    "Membeli makanan dengan tingkat tertinggi yang sesuai dengan jumlah uang Anda secara otomatis, dan berhenti sementara apabila saldo belum mencukupi.",
    false,
    function(state, desc)
        runningFood = state
        if state then
            foodWaitingForCash = false
            bestAffordableFoodIdx = nil
            desc.Text = "Status: Memeriksa pilihan makanan..."
            task.spawn(RunSmartFoodCycle)
        else
            desc.Text = "Status: Nonaktif"
        end
    end
)

statusStandLbl = CreateCardToggle(
    ShopPage,
    "Smart Auto Upgrade Stand",
    "Status: Siap meningkatkan kapasitas stand sesuai saldo",
    "Meningkatkan level stan Anda secara otomatis ketika saldo uang mencukupi tanpa memunculkan peringatan berulang.",
    false,
    function(state, desc)
        runningUpgrade = state
        if state then
            standWaitingForCash = false
            desc.Text = "Status: Memeriksa peningkatan stan..."
            task.spawn(RunSmartStandCycle)
        else
            desc.Text = "Status: Nonaktif"
        end
    end
)

CreateCardToggle(
    ShopPage,
    "Auto Zone Wakeup",
    "Menjaga interaksi area toko dan stan tetap aktif saat diam",
    "Memastikan area interaksi toko dan stan tetap responsif meskipun karakter dalam keadaan diam.",
    true,
    function(state) runningMicroStep = state end
)

-- ==========================================
-- TAB 3: PLAYER (WALKSPEED, JUMPPOWER, FLY, NOCLIP)
-- ==========================================
CreateCardSlider(
    PlayerPage,
    "WalkSpeed",
    "Mengatur kecepatan berjalan dan berlari karakter Anda.",
    16, 250, 20,
    function(val)
        walkSpeedValue = val
        walkSpeedEnabled = true
    end
)

CreateCardSlider(
    PlayerPage,
    "JumpPower",
    "Mengatur ketinggian lompatan karakter Anda.",
    50, 300, 50,
    function(val)
        jumpPowerValue = val
        jumpPowerEnabled = true
    end
)

CreateCardToggle(
    PlayerPage,
    "Fly",
    "Memungkinkan karakter terbang bebas di udara",
    "Mengaktifkan mode terbang sehingga Anda dapat bergerak bebas ke segala arah di udara sesuai arah kamera.",
    false,
    function(state)
        flyEnabled = state
        if state then
            StartFly()
            ShowNotif("Mode Terbang Aktif", "Gunakan kontrol arah untuk terbang.", THEME.Blue, false)
        else
            StopFly()
        end
    end
)

CreateCardSlider(
    PlayerPage,
    "Fly Speed",
    "Mengatur kecepatan pergerakan karakter saat mode terbang aktif.",
    10, 250, 50,
    function(val)
        flySpeedValue = val
    end
)

CreateCardToggle(
    PlayerPage,
    "NoClip",
    "Menembus dinding dan penghalang objek di sekitar",
    "Menonaktifkan benturan fisik karakter sehingga Anda dapat melewati dinding, pagar, maupun rintangan lainnya.",
    false,
    function(state)
        noclipEnabled = state
        if not state and LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
)

-- ==========================================
-- TAB 4: AFK & STATS (TERMASUK PENGATURAN LOGO & BACKGROUND ASSET ID)
-- ==========================================
CreateCardInput(
    AfkPage,
    "Logo Asset ID (Icon & Minimize)",
    "Masukkan angka Asset ID Roblox atau rbxassetid://... untuk mengganti gambar logo pada menu dan tombol melayang.",
    "Contoh: 84587193599064",
    function(txt)
        if ApplyLogoAsset(txt) then
            ShowNotif("Logo Diperbarui", "Gambar logo berhasil diperbarui.", THEME.Green, false, 3)
        end
    end
)

CreateCardInput(
    AfkPage,
    "Background Asset ID (Wallpaper Menu)",
    "Masukkan angka Asset ID Roblox atau rbxassetid://... untuk mengganti gambar latar belakang jendela utama.",
    "Contoh: 84587193599064",
    function(txt)
        if ApplyBackgroundAsset(txt) then
            ShowNotif("Background Diperbarui", "Gambar latar belakang berhasil diperbarui.", THEME.Green, false, 3)
        end
    end
)

CreateCardToggle(
    AfkPage,
    "Built-in Anti-AFK",
    "Mencegah terputus dari server saat ditinggal diam",
    "Menjaga sesi permainan tetap aktif agar akun tidak dikeluarkan secara otomatis oleh sistem saat ditinggal dalam waktu lama.",
    true,
    function(state) runningAntiAfk = state end
)

local _, setBlackScreenToggle = CreateCardToggle(
    AfkPage,
    "Mode Hemat Daya Layar Hitam",
    "Mematikan tampilan 3D saat AFK (ketuk layar untuk kembali)",
    "Menonaktifkan tampilan grafis 3D untuk menghemat baterai dan menjaga suhu perangkat tetap stabil selama mode AFK.",
    false,
    function(state)
        AfkOverlay.Visible = state
        pcall(function() RunService:Set3dRenderingEnabled(not state) end)
    end
)
disableBlackScreenCallback = function()
    setBlackScreenToggle(false, true)
end

CreateCardAction(
    AfkPage,
    "Filter Notifikasi Tangkapan",
    "Mode saat ini: Semua Tangkapan",
    "Mengatur apakah notifikasi layar menampilkan seluruh hewan yang tertangkap atau hanya hewan dengan mutasi maupun tingkat kelangkaan tinggi.",
    "🔔",
    function(desc, badge)
        notifRareOnly = not notifRareOnly
        if notifRareOnly then
            desc.Text = "Mode saat ini: Hanya Rare, Mutasi & Ukuran Besar"
            badge.Text = "★"
            ShowNotif("Filter Diperbarui", "Menampilkan tangkapan Rare dan Mutasi saja.", THEME.Gold, false)
        else
            desc.Text = "Mode saat ini: Semua Tangkapan"
            badge.Text = "🔔"
            ShowNotif("Filter Diperbarui", "Menampilkan seluruh hasil tangkapan.", THEME.Blue, false)
        end
    end
)

CreateCardInput(
    AfkPage,
    "Discord Webhook URL",
    "Masukkan alamat Webhook Discord untuk menerima catatan otomatis saat mendapatkan hewan langka.",
    "Tempel URL https://discord.com/api/webhooks/...",
    function(txt) webhookUrl = txt:gsub("%s+", "") end
)

CreateCardToggle(
    AfkPage,
    "Aktifkan Discord Webhook",
    "Kirim laporan otomatis ke Discord untuk tangkapan langka",
    "Mengirimkan pesan pemberitahuan beserta rincian hewan ke saluran Discord Anda setiap kali berhasil mendapatkan hewan langka atau bermutasi.",
    false,
    function(state, desc)
        if state and not webhookUrl:find("discord.com/api/webhooks/") then
            desc.Text = "Masukkan URL Webhook yang valid terlebih dahulu"
            ShowNotif("Webhook Belum Diisi", "Silakan masukkan tautan Webhook Discord di atas.", THEME.Red, false)
            return
        end
        webhookEnabled = state
        desc.Text = state and "Aktif: Mengirim catatan tangkapan langka" or "Nonaktif"
    end
)

CreateCardAction(
    AfkPage,
    "Test Kirim Discord Webhook",
    "Menguji koneksi pengiriman pesan ke saluran Discord Anda",
    "Mengirimkan pesan percobaan untuk memastikan tautan Webhook Discord berfungsi dengan baik.",
    "📨",
    function(desc)
        if not webhookUrl:find("discord.com/api/webhooks/") then
            desc.Text = "URL Webhook belum valid"
            return
        end
        desc.Text = "Mengirim pesan percobaan..."
        task.spawn(function()
            local sent = SendDiscordWebhook("✅ ZyrexHub V2 Connected!", "Koneksi Webhook berhasil dan siap mencatat tangkapan langka.", 4316290)
            desc.Text = sent and "Berhasil terkirim ke Discord" or "Gagal mengirim pesan percobaan"
        end)
    end
)

statStealCountLbl = CreateCardAction(
    AfkPage,
    "Statistik Sesi Permainan",
    "Tertangkap: 0 Pet  •  Terjual: 0",
    "Menampilkan jumlah total hewan yang berhasil ditangkap dan dijual selama sesi permainan berlangsung.",
    "🐾",
    function()
        local elapsed = math.floor(tick() - sessionStartTick)
        local mins = math.floor(elapsed / 60)
        local secs = elapsed % 60
        ShowNotif("Ringkasan Sesi (" .. mins .. "m " .. secs .. "s)", "Tertangkap: " .. totalStealCount .. " | Terjual: " .. totalSoldCount, THEME.Green, false)
    end
)

statCashLbl = CreateCardAction(
    AfkPage,
    "Monitor Saldo & Segarkan Pembelian",
    "Saldo terdeteksi: " .. (lastKnownCashSnapshot ~= "" and lastKnownCashSnapshot or "Menunggu pembaruan..."),
    "Menampilkan saldo uang terkini dan menyegarkan kembali status pembelian otomatis apabila sempat tertunda.",
    "💰",
    function(desc)
        ResetSmartBuyState()
        desc.Text = "Status pembelian disegarkan"
        ShowNotif("Pembelian Disegarkan", "Pemeriksaan pembelian otomatis dimulai ulang.", THEME.Gold, false)
    end
)

CreateCardAction(
    AfkPage,
    "Perbarui Titik Kunci Auto Steal",
    "Menyimpan posisi berdiri karakter saat ini sebagai titik lempar",
    "Memperbarui koordinat posisi berdiri utama yang digunakan saat fitur Auto Steal aktif.",
    "📍",
    function(desc)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            savedPadCFrame = hrp.CFrame
            desc.Text = "Titik posisi berhasil diperbarui"
            ShowNotif("Titik Diperbarui", "Koordinat berdiri Auto Steal telah disimpan ulang.", THEME.Accent, false)
        end
    end
)

-- === BACKGROUND LOOPS ===
-- Loop 1: Auto Tap x2
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.2)
        if runningTap then
            pcall(function()
                for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if (gui:IsA("ImageButton") or gui:IsA("TextButton")) and gui.Visible then
                        local name = gui.Name:lower()
                        if (name:find("tapbonus") or name:find("training_tap") or name:find("x2") or name:find("2x"))
                            and gui.AbsoluteSize.X > 20 and gui.AbsoluteSize.X < 150
                            and gui.AbsoluteSize.Y > 20 and gui.AbsoluteSize.Y < 150 then
                            if firesignal then
                                firesignal(gui.Activated)
                                firesignal(gui.MouseButton1Click)
                            end
                            break
                        end
                    end
                end
            end)
        end
    end
end)

-- Loop 2: Auto Steal Pet + Loading Spinner State
task.spawn(function()
    if not RemotesFolder then return end
    local ThrowStart = RemotesFolder:WaitForChild("Throw_Start", 10)
    local ThrowMeter = RemotesFolder:WaitForChild("Throw_MeterStarted", 10)
    local ThrowResolve = RemotesFolder:WaitForChild("Throw_Resolve", 10)
    local ThrowComplete = RemotesFolder:WaitForChild("Throw_Complete", 10)
    local lastCycleTick = tick()

    while ScreenGui.Parent do
        if runningSteal then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not savedPadCFrame then savedPadCFrame = hrp.CFrame end

                SetStealPillVisible(true)

                if (tick() - lastCycleTick) > 3.5 then
                    pcall(function() ThrowComplete:InvokeServer() end)
                    hrp.CFrame = savedPadCFrame
                    lastCycleTick = tick()
                    task.wait(0.15)
                end

                catchNotifiedThisCycle = false
                local beforeTools = SnapshotOwnedTools()

                local ok = pcall(function()
                    if ThrowStart:InvokeServer() == false then
                        ThrowComplete:InvokeServer()
                        task.wait(0.1)
                        ThrowStart:InvokeServer()
                    end
                    task.wait(0.07)
                    if not runningSteal then return end
                    ThrowMeter:FireServer()
                    task.wait(0.07)
                    if not runningSteal then return end
                    local resolveRes = ThrowResolve:InvokeServer(1)
                    task.wait(0.07)
                    if not runningSteal then return end
                    local completeRes = ThrowComplete:InvokeServer()

                    lastCycleTick = tick()
                    task.wait(0.18)

                    local newTool = FindNewlyAddedTool(beforeTools)
                    if newTool then
                        local prof = ExtractFullPetProfile(newTool)
                        RegisterVerifiedCatch(prof.name, prof.cps, prof.mutation, prof.size)
                        task.wait(0.35)
                    elseif type(resolveRes) == "string" and #resolveRes > 1 then
                        local cpsVal, mutVal, sizeVal = ParseMetadataFromStrings({resolveRes})
                        RegisterVerifiedCatch(resolveRes, cpsVal, mutVal, sizeVal)
                        task.wait(0.35)
                    elseif type(completeRes) == "string" and #completeRes > 1 then
                        local cpsVal, mutVal, sizeVal = ParseMetadataFromStrings({completeRes})
                        RegisterVerifiedCatch(completeRes, cpsVal, mutVal, sizeVal)
                        task.wait(0.35)
                    end
                end)

                if not ok then
                    pcall(function() ThrowComplete:InvokeServer() end)
                    task.wait(0.25)
                else
                    task.wait(0.22)
                end
            else
                task.wait(0.25)
            end
        else
            SetStealPillVisible(false)
            lastCycleTick = tick()
            task.wait(0.2)
        end
    end
end)

-- Loop 3: Auto Train Keep-Alive
task.spawn(function()
    while ScreenGui.Parent do
        if runningTrain and TrainingStartRemote then
            pcall(function() TrainingStartRemote:InvokeServer() end)
            task.wait(3)
        else
            task.wait(0.4)
        end
    end
end)

-- Loop 4: Auto Equip Best (15s)
task.spawn(function()
    while ScreenGui.Parent do
        if runningEquip and PlotEquipBestRemote then
            task.spawn(function() pcall(function() PlotEquipBestRemote:InvokeServer() end) end)
            task.wait(15)
        else
            task.wait(0.5)
        end
    end
end)

-- Loop 5: Auto Sell Selected (Setiap 3 detik)
task.spawn(function()
    while ScreenGui.Parent do
        if runningSell then
            RunAutoSellCycle()
            task.wait(3)
        else
            task.wait(0.4)
        end
    end
end)

-- Loop 6: Smart Auto Buy Food
task.spawn(function()
    local lastCheck = 0
    while ScreenGui.Parent do
        if runningFood then
            if not foodWaitingForCash or cashIncreasedSignal or (tick() - lastCheck) > 12 then
                cashIncreasedSignal = false
                lastCheck = tick()
                RunSmartFoodCycle()
            end
            task.wait(0.6)
        else
            task.wait(0.25)
        end
    end
end)

-- Loop 7: Smart Auto Upgrade Stand
task.spawn(function()
    local lastCheck = 0
    while ScreenGui.Parent do
        if runningUpgrade then
            if not standWaitingForCash or cashIncreasedSignal or (tick() - lastCheck) > 12 then
                cashIncreasedSignal = false
                lastCheck = tick()
                RunSmartStandCycle()
            end
            task.wait(0.6)
        else
            task.wait(0.25)
        end
    end
end)
