-- Aero | AeroHub v5: ESP, auto-steal (fireproximityprompt, throttled), auto return (HOME / STAGE1 / stage-by-stage), speed(CFrame), fly, noclip, antiragdoll-fixed, tp
local Players, RunService, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
if env.AeroCleanup then pcall(env.AeroCleanup) end

local S = {speed=false, fly=false, noclip=false, antiragdoll=false, antihit=false, taptp=false,
           espLoot=false, espPlr=false, autoSteal=false, autoWalk=false, antiafk=false, autoHome=false,
           retStage=false, stepBack=false}
local V = {walk=20, fly=60, range=20}
local hold = {up=false, down=false}
local conns, baseWS, savedCF = {}, 16, nil
local flyBV, flyBG
local hasFP = fireproximityprompt ~= nil
local lastFire = {}
local tapStart = {}
local HOP, HOP_WAIT, STAGE1_Z = 120, 0.7, -70
local hopping = false
local statusLbl

local function hum()  local c = lp.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function root() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function setFacing(on) local r = root() local sf = r and r:FindFirstChild("SpiderFacing") if sf then sf.Enabled = on end end
local function setStatus(t) if statusLbl then statusLbl.Text = t end end

local function tpTo(cf) local r = root() if not r then return end r.CFrame = cf r.AssemblyLinearVelocity = Vector3.zero end

-- posisi base milik kamu (TrainerSpot, CFrame dunia)
local function homeCF()
    local plot = lp:GetAttribute("Plot")
    local map = workspace:FindFirstChild("Map")
    local bases = map and map:FindFirstChild("Bases")
    local base = plot and bases and bases:FindFirstChild("Base" .. plot)
    local spot = base and base:GetAttribute("TrainerSpot")
    if typeof(spot) == "CFrame" then return spot + Vector3.new(0, 4, 0) end
    return nil
end

-- ===== zona (dari Workspace.Map.Limits) =====
local function zoneRanges()
    local out = {}
    local limits = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Limits")
    if not limits then return out end
    for _, f in ipairs(limits:GetChildren()) do
        local n = f.Name:match("^Zone_(%d+)")
        local zmin, zmax = f:GetAttribute("ZMin"), f:GetAttribute("ZMax")
        if n and zmin and zmax then
            out[#out+1] = { n = tonumber(n), zmin = math.min(zmin, zmax), zmax = math.max(zmin, zmax) }
        end
    end
    table.sort(out, function(a, b) return a.n < b.n end)
    return out
end

local function zoneAt(z)
    for _, zr in ipairs(zoneRanges()) do
        if z >= zr.zmin and z <= zr.zmax then return zr.n end
    end
    return nil
end

local function zoneCenter(n)
    if n == 1 then return STAGE1_Z end
    for _, zr in ipairs(zoneRanges()) do
        if zr.n == n then return (zr.zmin + zr.zmax) / 2 end
    end
    return nil
end

-- tengah Stage 1 (Zone_1_Stage1) untuk TP STAGE1 / return langsung
local function groundAt(x, z)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { lp.Character }
    local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rp)
    return hit and hit.Position or nil
end

local function stageCF()
    local g = groundAt(0, STAGE1_Z)
    return g and CFrame.new(g + Vector3.new(0, 4, 0)) or nil
end

local function returnCF()
    if S.retStage then return stageCF() end
    return homeCF()
end

-- lompatan bertahap ke Z target: tiap langkah maksimal HOP stud, cek apakah sampai
local function stepToZ(targetZ)
    if hopping then return false end
    hopping = true
    local ok = true
    while S.stepBack do
        local r = root()
        if not r then ok = false break end
        local z = r.Position.Z
        local dz = targetZ - z
        if math.abs(dz) <= 8 then break end
        local nz = z + math.clamp(dz, -HOP, HOP)
        local g = groundAt(0, nz)
        if not g then ok = false break end
        tpTo(CFrame.new(g + Vector3.new(0, 4, 0)))
        task.wait(HOP_WAIT)
        local now = root()
        if not now or math.abs(now.Position.Z - nz) > 15 then ok = false break end
    end
    hopping = false
    return ok
end

-- dari zona sekarang, lompat zona demi zona ke Stage 1
local function goStageByStage()
    local r = root()
    if not r then return end
    local cur = zoneAt(r.Position.Z) or 0
    for n = math.max(cur - 1, 1), 1, -1 do
        local z = zoneCenter(n)
        if not z then setStatus("zona "..n.." tidak ketemu") return end
        setStatus("menuju zona "..n)
        if not stepToZ(z) then setStatus("tertahan di sekitar zona "..n) return end
    end
    setStatus("sampai stage 1")
end

local function tapTeleport(sp)
    local r, h, cam = root(), hum(), workspace.CurrentCamera
    if not (r and h and cam) then return end
    local ray = cam:ScreenPointToRay(sp.X, sp.Y)
    local rp = RaycastParams.new() rp.FilterType = Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances = {lp.Character}
    local hit = workspace:Raycast(ray.Origin, ray.Direction*3000, rp)
    if not hit then return end
    local rot = r.CFrame - r.CFrame.Position
    tpTo(CFrame.new(hit.Position + Vector3.new(0, h.HipHeight + r.Size.Y/2 + 0.5, 0)) * rot)
end

local function stopFly() if flyBV then flyBV:Destroy() flyBV=nil end if flyBG then flyBG:Destroy() flyBG=nil end local h=hum() if h then h.PlatformStand=false end setFacing(true) end
local function startFly()
    local r,h = root(), hum() if not (r and h) then return end
    stopFly() setFacing(false)
    flyBV = Instance.new("BodyVelocity") flyBV.MaxForce=Vector3.new(1,1,1)*1e9 flyBV.Velocity=Vector3.zero flyBV.Parent=r
    flyBG = Instance.new("BodyGyro") flyBG.MaxTorque=Vector3.new(1,1,1)*1e9 flyBG.P=9e4 flyBG.CFrame=r.CFrame flyBG.Parent=r
    h.PlatformStand = true
end

local function setRagdollStates(enabled) local h=hum() if not h then return end h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, enabled) h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled) end
local function setHit(enabled) local c=lp.Character if not c then return end for _,ch in ipairs(c:GetChildren()) do local p = ch:IsA("BasePart") and ch or (ch:IsA("Accessory") and ch:FindFirstChild("Handle")) if p then p.CanTouch=enabled p.CanQuery=enabled end end end

-- ===== proximity prompt helpers =====
local function livePrompts()
    local list = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled then list[#list+1] = p end
    end
    return list
end
local function promptPos(p)
    local parent = p.Parent
    return parent and parent:IsA("BasePart") and parent.Position or (parent and parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
end
local function nearestPrompt()
    local r = root() if not r then return nil end
    local best, bestD = nil, math.huge
    for _, p in ipairs(livePrompts()) do
        local pos = promptPos(p)
        if pos then
            local d = (pos - r.Position).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best, bestD
end

-- ===== ESP =====
local function tagLoot(p)
    local parent = p.Parent
    if not parent or parent:FindFirstChild("AeroTag") then return end
    local bb = Instance.new("BillboardGui") bb.Name="AeroTag" bb.Adornee = parent:IsA("BasePart") and parent or parent.PrimaryPart
    bb.Size = UDim2.fromOffset(160,36) bb.AlwaysOnTop = true bb.Parent = parent
    local lbl = Instance.new("TextLabel") lbl.Size=UDim2.fromScale(1,1) lbl.BackgroundTransparency=1 lbl.TextColor3=Color3.fromRGB(80,220,120)
    lbl.Font=Enum.Font.GothamBold lbl.TextSize=14 lbl.TextStrokeTransparency=0 lbl.Parent=bb
    conns["esp_"..p:GetDebugId()] = RunService.Heartbeat:Connect(function()
        if not (S.espLoot and p.Parent and p.Enabled) then if bb then bb:Destroy() end return end
        local r = root() local pos = promptPos(p)
        if r and pos then lbl.Text = string.format("%s (%.0fm)", p.ActionText ~= "" and p.ActionText or p.ObjectText, (pos-r.Position).Magnitude) end
    end)
end

local plrHighlights = {}
local function tagPlayer(plr)
    if plr == lp then return end
    local function apply(c)
        if plrHighlights[plr] then plrHighlights[plr]:Destroy() end
        local hl = Instance.new("Highlight") hl.FillColor=Color3.fromRGB(220,60,60) hl.FillTransparency=0.6 hl.OutlineTransparency=0 hl.Parent=c
        hl.Enabled = S.espPlr
        plrHighlights[plr] = hl
    end
    if plr.Character then apply(plr.Character) end
    conns["plrchar_"..plr.UserId] = plr.CharacterAdded:Connect(apply)
end
for _, p in ipairs(Players:GetPlayers()) do tagPlayer(p) end
conns.plradd = Players.PlayerAdded:Connect(tagPlayer)

-- ===== main loop =====
conns.hb = RunService.Heartbeat:Connect(function(dt)
    local c, h, r = lp.Character, hum(), root()
    if not (c and h and r) or h.Health <= 0 then return end
    local cam = workspace.CurrentCamera

    if S.speed and not S.fly then
        local md = h.MoveDirection
        if md.Magnitude > 0.01 then r.CFrame = r.CFrame + md.Unit * V.walk * dt end
    end

    if S.fly then
        if not (flyBV and flyBV.Parent) then startFly() end
        if flyBV and flyBG then
            h.PlatformStand = true
            local dir, md = Vector3.zero, h.MoveDirection
            if md.Magnitude > 0 then
                local lv = cam.CFrame:VectorToObjectSpace(md)
                dir = cam.CFrame.RightVector*lv.X + cam.CFrame.LookVector*-lv.Z
            end
            dir = dir + Vector3.new(0, (hold.up and 1 or 0)-(hold.down and 1 or 0), 0)
            flyBV.Velocity = dir.Magnitude > 0.01 and dir.Unit*V.fly or Vector3.zero
            local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
            if flat.Magnitude > 0.01 then flyBG.CFrame = CFrame.lookAt(r.Position, r.Position+flat) end
        end
    end

    if S.antiragdoll then
        local st = h:GetState()
        if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
        for _, d in ipairs(c:GetDescendants()) do
            if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and not d.Enabled then d.Enabled = true end
        end
    end

    if S.antihit then setHit(false) end

    if S.espLoot then for _, p in ipairs(livePrompts()) do tagLoot(p) end end

    -- throttle: tiap prompt di-fire maksimal sekali per 0.6s
    if S.autoSteal and hasFP then
        local now = os.clock()
        for _, p in ipairs(livePrompts()) do
            local pos = promptPos(p)
            if pos and (pos - r.Position).Magnitude <= p.MaxActivationDistance and now - (lastFire[p] or 0) > 0.6 then
                lastFire[p] = now
                pcall(fireproximityprompt, p)
                if S.autoHome and p.ActionText == "Steal" then
                    task.delay(0.3, function()
                        if not S.autoHome then return end
                        if p:IsDescendantOf(workspace) and p.Enabled then return end
                        if S.stepBack then
                            task.spawn(goStageByStage)
                        else
                            local cf = returnCF()
                            if cf then tpTo(cf) end
                        end
                    end)
                end
            end
        end
    end

    if S.autoWalk then
        local p, d = nearestPrompt()
        if p then
            local pos = promptPos(p)
            if pos and d and d > 3 then
                local target = Vector3.new(pos.X, r.Position.Y, pos.Z)
                local dir = target - r.Position
                if dir.Magnitude > 0.1 then
                    r.CFrame = CFrame.lookAt(r.Position, target) + dir.Unit * V.walk * dt
                end
            end
        end
    end
end)

conns.step = RunService.Stepped:Connect(function()
    if not S.noclip then return end
    local c = lp.Character if not c then return end
    for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
end)

conns.char = lp.CharacterAdded:Connect(function(c) local h = c:WaitForChild("Humanoid",10) if h and S.antiragdoll then setRagdollStates(false) end end)
conns.kd = UIS.InputBegan:Connect(function(i,gp) if gp then return end if i.KeyCode==Enum.KeyCode.Space then hold.up=true elseif i.KeyCode==Enum.KeyCode.LeftShift then hold.down=true end end)
conns.ku = UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.Space then hold.up=false elseif i.KeyCode==Enum.KeyCode.LeftShift then hold.down=false end end)

local function isPointer(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
conns.tapB = UIS.InputBegan:Connect(function(i,gp) if gp or not S.taptp or not isPointer(i) then return end tapStart[i]={pos=i.Position,t=os.clock()} end)
conns.tapE = UIS.InputEnded:Connect(function(i) local st=tapStart[i] if not st then return end tapStart[i]=nil if S.taptp and (i.Position-st.pos).Magnitude<12 and os.clock()-st.t<0.35 then tapTeleport(i.Position) end end)

-- anti-afk
conns.afk = lp.Idled:Connect(function() if S.antiafk then local VU = game:GetService("VirtualUser") VU:CaptureController() VU:ClickButton2(Vector2.new()) end end)

-- ===== UI =====
local function mk(c,p,parent) local i=Instance.new(c) for k,v in pairs(p) do i[k]=v end i.Parent=parent return i end
local ok, gp = pcall(function() return gethui and gethui() or game:GetService("CoreGui") end)
if not ok or not gp then gp = lp:WaitForChild("PlayerGui") end
local gui = mk("ScreenGui", {Name="AeroHub", ResetOnSpawn=false}, gp)
local main = mk("Frame", {Size=UDim2.fromOffset(240,0), AutomaticSize=Enum.AutomaticSize.Y, Position=UDim2.fromOffset(20,80), BackgroundColor3=Color3.fromRGB(18,18,24), BorderSizePixel=0}, gui)
mk("UICorner", {CornerRadius=UDim.new(0,8)}, main)
mk("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder}, main)
local ON, OFF, W = Color3.fromRGB(46,160,90), Color3.fromRGB(45,45,58), Color3.new(1,1,1)

local title = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundColor3=Color3.fromRGB(30,30,42), BorderSizePixel=0, LayoutOrder=1}, main)
mk("UICorner", {CornerRadius=UDim.new(0,8)}, title)
mk("TextLabel", {Size=UDim2.new(1,-70,1,0), Position=UDim2.fromOffset(10,0), BackgroundTransparency=1, Text="AERO", TextColor3=W, Font=Enum.Font.GothamBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}, title)
local moneyLbl = mk("TextLabel", {Size=UDim2.new(1,-12,0,16), BackgroundTransparency=1, Text="", TextColor3=Color3.fromRGB(255,215,80), Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0}, main)
statusLbl = mk("TextLabel", {Size=UDim2.new(1,-12,0,16), BackgroundTransparency=1, Text="siap", TextColor3=W, Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0}, main)

local body = mk("Frame", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, LayoutOrder=2}, main)
mk("UIPadding", {PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6), PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6)}, body)
mk("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)}, body)

local order = 0
local function nextOrder() order=order+1 return order end
local function smallBtn(text, parent, pos, anchor)
    local b = mk("TextButton", {Size=UDim2.fromOffset(28,22), Position=pos, AnchorPoint=anchor or Vector2.zero, BackgroundColor3=OFF, Text=text, TextColor3=W, Font=Enum.Font.GothamBold, TextSize=14}, parent)
    mk("UICorner", {CornerRadius=UDim.new(0,5)}, b) return b
end
local minBtn = smallBtn("-", title, UDim2.new(1,-34,0,4), Vector2.new(1,0))
local xBtn = smallBtn("x", title, UDim2.new(1,-4,0,4), Vector2.new(1,0))
minBtn.Activated:Connect(function() body.Visible = not body.Visible end)

local function toggle(name, key, onChange)
    local b = mk("TextButton", {Size=UDim2.new(1,0,0,32), BackgroundColor3=OFF, Text=name..": OFF", TextColor3=W, Font=Enum.Font.GothamBold, TextSize=14, LayoutOrder=nextOrder()}, body)
    mk("UICorner", {CornerRadius=UDim.new(0,6)}, b)
    b.Activated:Connect(function()
        S[key] = not S[key]
        b.Text = name..": "..(S[key] and "ON" or "OFF")
        b.BackgroundColor3 = S[key] and ON or OFF
        if onChange then onChange(S[key]) end
    end)
end
local function stepper(label, key, step, lo, hi)
    local row = mk("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, LayoutOrder=nextOrder()}, body)
    local val = mk("TextLabel", {Size=UDim2.new(1,-64,1,0), Position=UDim2.fromOffset(32,0), BackgroundTransparency=1, TextColor3=W, Font=Enum.Font.Gotham, TextSize=13}, row)
    local minus = smallBtn("-", row, UDim2.fromOffset(0,3))
    local plus = smallBtn("+", row, UDim2.new(1,0,0,3), Vector2.new(1,0))
    local function refresh() val.Text = label..": "..V[key] end
    minus.Activated:Connect(function() V[key]=math.max(lo,V[key]-step) refresh() end)
    plus.Activated:Connect(function() V[key]=math.min(hi,V[key]+step) refresh() end)
    refresh()
end

toggle("AUTO STEAL", "autoSteal")
toggle("AUTO RETURN (after steal)", "autoHome")
toggle("RETURN STAGE BY STAGE", "stepBack")
toggle("RETURN TO STAGE1 (direct)", "retStage")
toggle("AUTO WALK TO LOOT", "autoWalk")
toggle("LOOT ESP", "espLoot")
toggle("PLAYER ESP", "espPlr", function(on) for _,hl in pairs(plrHighlights) do hl.Enabled = on end end)
stepper("Range", "range", 5, 5, 100)
toggle("ANTI-AFK", "antiafk")

toggle("SPEED", "speed")
stepper("Walk", "walk", 5, 5, 100)
toggle("FLY", "fly", function(on) if on then startFly() else stopFly() end end)
stepper("Fly spd", "fly", 10, 10, 300)
local upRow = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=nextOrder()}, body)
local function holdBtn(text,pos,key)
    local b = mk("TextButton", {Size=UDim2.new(0.5,-2,1,0), Position=pos, BackgroundColor3=OFF, Text=text, TextColor3=W, Font=Enum.Font.GothamBold, TextSize=13}, upRow)
    mk("UICorner", {CornerRadius=UDim.new(0,6)}, b)
    b.InputBegan:Connect(function(i) if isPointer(i) then hold[key]=true end end)
    b.InputEnded:Connect(function(i) if isPointer(i) then hold[key]=false end end)
end
holdBtn("UP (hold)", UDim2.new(0,0,0,0), "up")
holdBtn("DOWN (hold)", UDim2.new(0.5,2,0,0), "down")
toggle("NOCLIP", "noclip")
toggle("ANTI RAGDOLL", "antiragdoll", function(on) setRagdollStates(not on) end)
toggle("ANTI HIT", "antihit", function(on) if not on then setHit(true) end end)
toggle("TAP TP", "taptp", function() tapStart = {} end)

local posRow = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=nextOrder()}, body)
local posLbl = mk("TextLabel", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, Text="Saved: -", TextColor3=W, Font=Enum.Font.Gotham, TextSize=12, LayoutOrder=nextOrder()}, body)
local function rowBtn(text,pos,cb) local b=mk("TextButton",{Size=UDim2.new(0.5,-2,1,0),Position=pos,BackgroundColor3=OFF,Text=text,TextColor3=W,Font=Enum.Font.GothamBold,TextSize=13}, posRow) mk("UICorner",{CornerRadius=UDim.new(0,6)},b) b.Activated:Connect(cb) end
rowBtn("SET POS", UDim2.new(0,0,0,0), function() local r=root() if not r then return end savedCF=r.CFrame local p=savedCF.Position posLbl.Text=string.format("Saved: %d, %d, %d",p.X,p.Y,p.Z) end)
rowBtn("TP SAVED", UDim2.new(0.5,2,0,0), function() if savedCF then tpTo(savedCF) end end)
local tpRow = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, LayoutOrder=nextOrder()}, body)
local function tpBtn(text,pos,fn) local b=mk("TextButton",{Size=UDim2.new(0.5,-2,1,0),Position=pos,BackgroundColor3=OFF,Text=text,TextColor3=W,Font=Enum.Font.GothamBold,TextSize=13}, tpRow) mk("UICorner",{CornerRadius=UDim.new(0,6)},b) b.Activated:Connect(function() local cf=fn() if cf then tpTo(cf) end end) end
tpBtn("TP HOME", UDim2.new(0,0,0,0), homeCF)
tpBtn("TP STAGE1", UDim2.new(0.5,2,0,0), stageCF)

conns.money = RunService.Heartbeat:Connect(function()
    local v = lp:GetAttribute("Money")
    if v then moneyLbl.Text = "Money: "..tostring(v) end
end)

local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
    if isPointer(i) then
        dragging, dragStart, startPos = true, i.Position, main.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
conns.drag = UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)

env.AeroCleanup = function()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    for _, hl in pairs(plrHighlights) do pcall(function() hl:Destroy() end) end
    S.stepBack = false
    stopFly() setHit(true) setRagdollStates(true)
    if gui then gui:Destroy() end
    env.AeroCleanup = nil
end
xBtn.Activated:Connect(env.AeroCleanup)
