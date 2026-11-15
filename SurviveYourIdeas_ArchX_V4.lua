-- Survive Your Ideas | ArchX Edition (Full ArchX GUI Template)
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")

local Camera = workspace.CurrentCamera

-- === KONFIGURASI ASET & BRANDING PATEN ARCHX ===
local CONFIG = {
    BrandName    = "ArchX",
    DiscordLink  = "https://discord.gg/zyrex",
    BackgroundID = "rbxassetid://136806144474646",
    LogoID       = "rbxassetid://111892209979191",
}

local targetGuiParent = (gethui and gethui()) or CoreGui
if targetGuiParent:FindFirstChild(CONFIG.BrandName) then
    targetGuiParent[CONFIG.BrandName]:Destroy()
end
if targetGuiParent:FindFirstChild("SYI_ArchXHub") then
    targetGuiParent.SYI_ArchXHub:Destroy()
end
if workspace:FindFirstChild("SYI_SkyPlatform") then
    workspace.SYI_SkyPlatform:Destroy()
end

-- === DETEKSI NAMA GAME ===
local okGame, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
local gameName = (okGame and gameInfo and gameInfo.Name) or "Survive Your Ideas"

-- === STATE KONFIGURASI GAME ===
local DISCORD_LINK = CONFIG.DiscordLink
local currentLang = "ID"

local State = {
    antiBackTP       = true,
    walkSpeedEnabled = false,
    walkSpeedValue   = 50,
    jumpPowerEnabled = false,
    jumpPowerValue   = 100,
    fly              = false,
    flySpeed         = 65,
    noclip           = false,
    antiRagdoll      = false,
    antiDie          = false,
    godMode          = false,
    antiSpamHit      = true,
    espEnabled       = false,
    runningAntiAfk   = true,
    savedCFrame      = nil,
    preSkyCFrame     = nil,
    playerIndex      = 1
}

local connections = {}
local activeCharConns = {}
local lastSafeCFrame = nil
local originalCollisions = {}
local espFolder = nil
local skyPlatform = nil
local flyBV, flyBG = nil, nil
local currentTpId = 0
local isTeleporting = false
local lastHealthSeen = 100
local lastDodgeTick = 0
local lastEspRefresh = 0

-- === SISTEM MULTI-BAHASA (ID & EN) ===
local LANGUAGE_LIST = {
    { code = "ID", label = "Indonesia (Bahasa Indonesia)" },
    { code = "EN", label = "English (Global / US)" },
}

local TRANSLATIONS = {
    ID = {
        welcome_desc = "Terima kasih telah menggunakan ArchX. Bergabunglah ke server Discord kami untuk pembaruan skrip terbaru.",
        copy_invite  = "Copy Invite",
        copied       = "Tersalin!",
        close        = "Tutup",
        info_title   = "Informasi Fitur",
        understood   = "Mengerti",
        afk_overlay  = "🌙 MODE HEMAT DAYA AFK AKTIF\nTampilan 3D dinonaktifkan untuk menjaga suhu perangkat.\n\nKetuk layar di mana saja untuk kembali.",

        -- Tabs
        tab_arena    = "Arena & Sky",
        tab_move     = "Movement",
        tab_protect  = "Protection",
        tab_tp       = "Teleport",
        tab_settings = "AFK & Settings",

        -- Tab 1: Arena & Sky
        backtp_title = "Immune Back-TP",
        backtp_desc  = "Mencegah karakter ditarik balik (rubberband) saat bergerak cepat",
        backtp_help  = "Menstabilkan state fisika karakter dan memecah jarak teleportasi agar tidak ditarik kembali oleh sistem anti-TP server.",

        sky_title    = "Panic Safe Sky (Anti-Nuke)",
        sky_desc     = "Teleport ke platform langit aman untuk menghindari ledakan",
        sky_help     = "Membuat pijakan neon di ketinggian aman (Y >= 260) dan memindahkan karakter ke atas langit secara instan.",

        ret_title    = "Return to Arena",
        ret_desc     = "Kembali ke posisi terakhir di arena sebelum naik ke langit",
        ret_help     = "Mengembalikan posisi karakter dari platform langit ke titik arena sebelum Panic Safe Sky ditekan.",

        esp_title    = "ESP Players, Items & Hazards",
        esp_desc     = "Menampilkan sorotan tembus pandang pemain, item, dan ancaman",
        esp_help     = "Menandai pemain lain (kuning), item/senjata seperti AWP/Gun (hijau), serta NPC/bahaya (merah) beserta jaraknya.",

        -- Tab 2: Movement
        ws_en_title  = "Enable WalkSpeed",
        ws_en_desc   = "Aktifkan kecepatan berjalan/berlari kustom",
        ws_en_help   = "Mengaktifkan pengubah kecepatan berjalan karakter (mendukung Hybrid CFrame saat Immune Back-TP aktif).",
        ws_val_title = "WalkSpeed Value",
        ws_val_help  = "Mengatur nilai kecepatan berjalan karakter Anda (16 - 250).",

        jp_en_title  = "Enable JumpPower",
        jp_en_desc   = "Aktifkan tinggi lompatan kustom",
        jp_en_help   = "Mengaktifkan pengubah daya lompat karakter.",
        jp_val_title = "JumpPower Value",
        jp_val_help  = "Mengatur kekuatan lompatan karakter Anda (50 - 400).",

        fly_title    = "Mobile Fly",
        fly_desc     = "Terbang bebas mengikuti arah kamera & joystick",
        fly_help     = "Memungkinkan karakter terbang ke segala arah menggunakan joystick layar atau tombol arah.",
        flyspd_title = "Fly Speed",
        flyspd_help  = "Mengatur kecepatan pergerakan saat terbang (20 - 250).",

        noclip_title = "NoClip (Anti-Sink)",
        noclip_desc  = "Menembus dinding & objek tanpa jatuh ke bawah tanah",
        noclip_help  = "Menonaktifkan benturan dinding sambil mempertahankan raycast lantai agar karakter tidak tenggelam.",

        -- Tab 3: Protection
        god_title    = "God Mode (Instant Lock)",
        god_desc     = "Mengunci HP tetap penuh & menonaktifkan hitbox sentuh",
        god_help     = "Memulihkan HP seketika setiap kali berkurang dan mematikan deteksi sentuhan (CanTouch) pada tubuh karakter.",

        spamhit_title = "Anti-Spam Hit (Auto-Evade 2x)",
        spamhit_desc  = "Menghindar otomatis saat kena pukul pertama agar hit ke-2 miss",
        spamhit_help  = "Melakukan pergeseran micro-evade otomatis tepat setelah menerima hit pertama untuk menghindari kombo pukulan/pedang.",

        ragdoll_title = "Anti-Ragdoll",
        ragdoll_desc  = "Mencegah karakter terpental, jatuh, atau lumpuh",
        ragdoll_help  = "Mengunci sendi Motor6D dan menonaktifkan state Ragdoll/FallingDown/Physics.",

        antidie_title = "Anti-Die + Anti-Void",
        antidie_desc  = "Mencegah kematian & kembali ke daratan jika jatuh ke void",
        antidie_help  = "Memblokir status Dead pada Humanoid dan mengembalikan karakter ke titik aman terakhir jika jatuh di bawah Y = -90.",

        -- Tab 4: Teleport
        savepos_title = "Save Current Position",
        savepos_desc  = "Simpan koordinat lokasi berdiri saat ini",
        savepos_help  = "Menyimpan posisi CFrame Anda saat ini untuk digunakan pada tombol Teleport to Saved Pos.",

        tppos_title   = "Teleport to Saved Pos",
        tppos_desc    = "Berpindah ke koordinat yang telah disimpan",
        tppos_help    = "Melakukan teleportasi aman ke posisi terakhir yang Anda simpan.",

        tpplr_title   = "Teleport to Next Player",
        tpplr_desc    = "Berpindah ke posisi pemain lain secara bergantian",
        tpplr_help    = "Memindahkan karakter ke dekat pemain lain di server satu per satu setiap kali ditekan.",

        tptool_title  = "Get Tap-Teleport Tool",
        tptool_desc   = "Tambahkan item Tap TP ke dalam tas (Backpack)",
        tptool_help   = "Memberikan tool bernama 'Tap TP' di tas; gunakan dan ketuk permukaan mana saja untuk teleport.",

        -- Tab 5: Settings & AFK
        lang_title    = "Bahasa GUI (Language)",
        lang_help     = "Pilih bahasa antarmuka menu ArchX.",
        antiafk_title = "Built-in Anti-AFK",
        antiafk_desc  = "Mencegah terputus dari server saat ditinggal diam",
        antiafk_help  = "Menjaga sesi tetap aktif agar akun tidak terkena kick idle 20 menit.",
        black_title   = "Mode Hemat Daya Layar Hitam",
        black_desc    = "Mematikan tampilan 3D saat AFK (ketuk layar untuk kembali)",
        black_help    = "Menonaktifkan render 3D untuk menghemat baterai dan menjaga suhu perangkat.",
        unload_title  = "Matikan Skrip Permanen (Unload)",
        unload_desc   = "Hentikan semua fitur, bersihkan efek, dan hapus GUI",
        unload_help   = "Menutup total skrip ArchX, memulihkan status karakter, dan menghapus logo floating.",
    },
    EN = {
        welcome_desc = "Thank you for using ArchX. Join our Discord server for the latest script updates.",
        copy_invite  = "Copy Invite",
        copied       = "Copied!",
        close        = "Close",
        info_title   = "Feature Information",
        understood   = "Got It",
        afk_overlay  = "🌙 AFK BATTERY SAVER ACTIVE\n3D rendering is disabled to keep your device cool.\n\nTap anywhere on the screen to return.",

        tab_arena    = "Arena & Sky",
        tab_move     = "Movement",
        tab_protect  = "Protection",
        tab_tp       = "Teleport",
        tab_settings = "AFK & Settings",

        backtp_title = "Immune Back-TP",
        backtp_desc  = "Prevents rubberbanding / pull-back when moving fast",
        backtp_help  = "Stabilizes character physics states and splits long teleports into safe steps to bypass server back-TP.",

        sky_title    = "Panic Safe Sky (Anti-Nuke)",
        sky_desc     = "Teleport to a high sky platform to evade blasts",
        sky_help     = "Creates a neon platform high in the sky (Y >= 260) and teleports you safely above the arena.",

        ret_title    = "Return to Arena",
        ret_desc     = "Return to your last arena position before going to sky",
        ret_help     = "Teleports you back down from the sky platform to your saved pre-sky arena position.",

        esp_title    = "ESP Players, Items & Hazards",
        esp_desc     = "Highlights players, weapons/items, and hazards through walls",
        esp_help     = "Displays distance tags and highlights for players (yellow), items/guns (green), and hazards/NPCs (red).",

        ws_en_title  = "Enable WalkSpeed",
        ws_en_desc   = "Enable custom walking and running speed",
        ws_en_help   = "Activates custom movement speed (uses Hybrid CFrame movement when Immune Back-TP is active).",
        ws_val_title = "WalkSpeed Value",
        ws_val_help  = "Adjusts your character's walking speed (16 - 250).",

        jp_en_title  = "Enable JumpPower",
        jp_en_desc   = "Enable custom jump height",
        jp_en_help   = "Activates custom jump height modifier.",
        jp_val_title = "JumpPower Value",
        jp_val_help  = "Adjusts your character's jump power (50 - 400).",

        fly_title    = "Mobile Fly",
        fly_desc     = "Fly freely controlled by camera and thumbstick",
        fly_help     = "Enables directional flight controlled by your camera angle and movement stick.",
        flyspd_title = "Fly Speed",
        flyspd_help  = "Adjusts movement speed while flying (20 - 250).",

        noclip_title = "NoClip (Anti-Sink)",
        noclip_desc  = "Walk through walls without sinking under the floor",
        noclip_help  = "Disables wall collisions while keeping ground raycast support so you never fall through floors.",

        god_title    = "God Mode (Instant Lock)",
        god_desc     = "Locks HP at maximum and disables touch hitboxes",
        god_help     = "Instantly restores health whenever damaged and disables CanTouch on character parts.",

        spamhit_title = "Anti-Spam Hit (Auto-Evade 2x)",
        spamhit_desc  = "Auto-evades after the 1st hit so the 2nd hit misses",
        spamhit_help  = "Performs a quick micro-evade right after taking a hit to dodge follow-up melee/weapon swings.",

        ragdoll_title = "Anti-Ragdoll",
        ragdoll_desc  = "Prevents knockback, tripping, or ragdoll states",
        ragdoll_help  = "Keeps Motor6D joints enabled and blocks Ragdoll/FallingDown/Physics states.",

        antidie_title = "Anti-Die + Anti-Void",
        antidie_desc  = "Prevents death and recovers you if falling into void",
        antidie_help  = "Blocks the Humanoid Dead state and teleports you back to safe ground if falling below Y = -90.",

        savepos_title = "Save Current Position",
        savepos_desc  = "Save your current standing coordinates",
        savepos_help  = "Stores your current CFrame location for quick teleportation.",

        tppos_title   = "Teleport to Saved Pos",
        tppos_desc    = "Teleport to your previously saved coordinates",
        tppos_help    = "Safely teleports your character to the location saved via Save Current Position.",

        tpplr_title   = "Teleport to Next Player",
        tpplr_desc    = "Cycle teleportation to other players in the server",
        tpplr_help    = "Teleports you to each player in the server one by one.",

        tptool_title  = "Get Tap-Teleport Tool",
        tptool_desc   = "Add a Tap TP tool into your Backpack",
        tptool_help   = "Gives you a 'Tap TP' tool; equip it and tap anywhere to teleport there.",

        lang_title    = "GUI Language",
        lang_help     = "Select your preferred interface language.",
        antiafk_title = "Built-in Anti-AFK",
        antiafk_desc  = "Prevents idle disconnect after 20 minutes",
        antiafk_help  = "Keeps your session active so you are not kicked while idle.",
        black_title   = "Black Screen Power Saver",
        black_desc    = "Disables 3D rendering while AFK (tap screen to return)",
        black_help    = "Turns off 3D graphics rendering to save battery and reduce device heat.",
        unload_title  = "Unload Script Completely",
        unload_desc   = "Stop all features, clean effects, and remove GUI",
        unload_help   = "Completely closes ArchX, restores character defaults, and removes the floating logo.",
    }
}

local function T(key)
    local dict = TRANSLATIONS[currentLang] or TRANSLATIONS.ID
    return dict[key] or TRANSLATIONS.ID[key] or key
end

local languageUpdaters = {}
local function RegisterLanguageUpdater(fn)
    table.insert(languageUpdaters, fn)
end

local function ApplyLanguage(langCode)
    currentLang = langCode
    for _, fn in ipairs(languageUpdaters) do
        pcall(fn)
    end
end

-- === HELPER DRAG (TOUCH & MOUSE DENGAN DETEKSI TAP VS DRAG) ===
local function MakeDraggable(dragHandle, targetFrame, onTapCallback)
    local dragging, dragInput, dragStart, startPos, movedDistance = false, nil, nil, nil, 0
    table.insert(connections, dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDistance = 0
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onTapCallback and movedDistance <= 8 then
                        onTapCallback()
                    end
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
            movedDistance = delta.Magnitude
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local function getCharParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hum, hrp
end

-- === SCREEN GUI UTAMA ARCHX ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.BrandName
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetGuiParent

-- === PALET WARNA PATEN ARCHX ===
local THEME = {
    BgMain      = Color3.fromRGB(16, 13, 20),
    BgSidebar   = Color3.fromRGB(22, 18, 28),
    BgCard      = Color3.fromRGB(28, 23, 35),
    BgCardHover = Color3.fromRGB(38, 31, 48),
    BgInput     = Color3.fromRGB(18, 15, 24),
    Border      = Color3.fromRGB(64, 52, 76),
    Accent      = Color3.fromRGB(255, 46, 99),
    AccentSoft  = Color3.fromRGB(190, 36, 78),
    Gold        = Color3.fromRGB(255, 195, 65),
    Green       = Color3.fromRGB(55, 210, 120),
    Red         = Color3.fromRGB(220, 55, 75),
    Blue        = Color3.fromRGB(80, 195, 255),
    White       = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(246, 246, 250),
    TextMuted   = Color3.fromRGB(168, 160, 178),
    SwitchOff   = Color3.fromRGB(54, 46, 62),
}

-- === TOP-CENTER FPS & MS MONITOR ===
local PerfBar = Instance.new("Frame")
PerfBar.Name = "ArchXPerfHUD"
PerfBar.Size = UDim2.new(0, 196, 0, 28)
PerfBar.Position = UDim2.new(0.5, -98, 0, 44)
PerfBar.BackgroundColor3 = THEME.BgMain
PerfBar.BackgroundTransparency = 0.14
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
FpsLbl.TextColor3 = THEME.White
FpsLbl.Font = Enum.Font.GothamBold
FpsLbl.TextSize = 11.5
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
PingLbl.TextColor3 = THEME.White
PingLbl.Font = Enum.Font.GothamBold
PingLbl.TextSize = 11.5
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

            local pingMs = 0
            pcall(function()
                pingMs = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
            end)
            PingLbl.Text = tostring(pingMs) .. " ms"
        end
    end))
end

-- === FLOATING LOGO BUTTON ===
local FloatingBtn = Instance.new("ImageButton")
FloatingBtn.Name = "ArchX_FloatingLogo"
FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
FloatingBtn.Position = UDim2.new(0.035, 0, 0.22, 0)
FloatingBtn.BackgroundTransparency = 1
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Image = CONFIG.LogoID
FloatingBtn.ScaleType = Enum.ScaleType.Fit
FloatingBtn.Visible = true
FloatingBtn.ZIndex = 39
FloatingBtn.Parent = ScreenGui

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
AfkInfoLbl.Text = T("afk_overlay")
AfkInfoLbl.ZIndex = 51
AfkInfoLbl.Parent = AfkOverlay

RegisterLanguageUpdater(function()
    AfkInfoLbl.Text = T("afk_overlay")
end)

local disableBlackScreenCallback = nil
AfkOverlay.MouseButton1Click:Connect(function()
    AfkOverlay.Visible = false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if disableBlackScreenCallback then disableBlackScreenCallback() end
end)

-- === POPUP PENJELASAN (? INFO MODAL) ===
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
InfoModalBox.Size = UDim2.new(0, 340, 0, 175)
InfoModalBox.Position = UDim2.new(0.5, -170, 0.5, -87)
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
InfoModalTitle.Text = T("info_title")
InfoModalTitle.ZIndex = 42
InfoModalTitle.Parent = InfoModalBox

local InfoModalBody = Instance.new("TextLabel")
InfoModalBody.Size = UDim2.new(1, -28, 0, 86)
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
InfoModalClose.Text = T("understood")
InfoModalClose.ZIndex = 42
InfoModalClose.Parent = InfoModalBox
Instance.new("UICorner", InfoModalClose).CornerRadius = UDim.new(0, 8)

RegisterLanguageUpdater(function()
    InfoModalClose.Text = T("understood")
end)

local function ShowFeatureInfo(featureTitle, formalDescription)
    InfoModalTitle.Text = featureTitle
    InfoModalBody.Text = formalDescription
    InfoModalBackdrop.Visible = true
end

InfoModalClose.MouseButton1Click:Connect(function() InfoModalBackdrop.Visible = false end)
InfoModalBackdrop.MouseButton1Click:Connect(function() InfoModalBackdrop.Visible = false end)

-- === MAIN WINDOW ARCHX ===
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 565, 0, 355)
MainFrame.Position = UDim2.new(0.5, -282, 0.5, -165)
MainFrame.BackgroundColor3 = THEME.BgMain
MainFrame.BackgroundTransparency = 0.08
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = THEME.Border
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local MainWallpaper = Instance.new("ImageLabel")
MainWallpaper.Name = "ArchX_Wallpaper"
MainWallpaper.Size = UDim2.new(1, 0, 1, 0)
MainWallpaper.BackgroundTransparency = 1
MainWallpaper.BorderSizePixel = 0
MainWallpaper.Image = CONFIG.BackgroundID
MainWallpaper.ImageTransparency = 0.78
MainWallpaper.ScaleType = Enum.ScaleType.Crop
MainWallpaper.ZIndex = 0
MainWallpaper.Parent = MainFrame

-- === WELCOME POPUP ===
local WelcomeBackdrop = Instance.new("Frame")
WelcomeBackdrop.Name = "WelcomeModal"
WelcomeBackdrop.Size = UDim2.new(1, 0, 1, 0)
WelcomeBackdrop.BackgroundTransparency = 1
WelcomeBackdrop.BorderSizePixel = 0
WelcomeBackdrop.ZIndex = 35
WelcomeBackdrop.Parent = ScreenGui

local WelcomeCard = Instance.new("Frame")
WelcomeCard.Size = UDim2.new(0, 420, 0, 265)
WelcomeCard.Position = UDim2.new(0.5, -210, 0.5, -125)
WelcomeCard.BackgroundColor3 = THEME.BgMain
WelcomeCard.BackgroundTransparency = 0.06
WelcomeCard.Active = true
WelcomeCard.ClipsDescendants = true
WelcomeCard.ZIndex = 36
WelcomeCard.Parent = WelcomeBackdrop
Instance.new("UICorner", WelcomeCard).CornerRadius = UDim.new(0, 14)
MakeDraggable(WelcomeCard, WelcomeCard)

local WelcomeStroke = Instance.new("UIStroke")
WelcomeStroke.Color = THEME.Accent
WelcomeStroke.Thickness = 1.8
WelcomeStroke.Parent = WelcomeCard

local WelcomeWallpaper = Instance.new("ImageLabel")
WelcomeWallpaper.Size = UDim2.new(1, 0, 1, 0)
WelcomeWallpaper.BackgroundTransparency = 1
WelcomeWallpaper.BorderSizePixel = 0
WelcomeWallpaper.Image = CONFIG.BackgroundID
WelcomeWallpaper.ImageTransparency = 0.82
WelcomeWallpaper.ScaleType = Enum.ScaleType.Crop
WelcomeWallpaper.ZIndex = 36
WelcomeWallpaper.Parent = WelcomeCard

local WelcomeLogo = Instance.new("ImageLabel")
WelcomeLogo.Size = UDim2.new(0, 44, 0, 44)
WelcomeLogo.Position = UDim2.new(0.5, -22, 0, 12)
WelcomeLogo.BackgroundTransparency = 1
WelcomeLogo.BorderSizePixel = 0
WelcomeLogo.Image = CONFIG.LogoID
WelcomeLogo.ScaleType = Enum.ScaleType.Fit
WelcomeLogo.ZIndex = 37
WelcomeLogo.Parent = WelcomeCard

local WelcomeTitle = Instance.new("TextLabel")
WelcomeTitle.Size = UDim2.new(1, -24, 0, 26)
WelcomeTitle.Position = UDim2.new(0, 12, 0, 58)
WelcomeTitle.BackgroundTransparency = 1
WelcomeTitle.TextColor3 = THEME.TextPrimary
WelcomeTitle.Font = Enum.Font.GothamBlack
WelcomeTitle.TextSize = 19
WelcomeTitle.Text = "Welcome to ArchX"
WelcomeTitle.ZIndex = 37
WelcomeTitle.Parent = WelcomeCard

local WelcomeUser = Instance.new("TextLabel")
WelcomeUser.Size = UDim2.new(1, -24, 0, 18)
WelcomeUser.Position = UDim2.new(0, 12, 0, 84)
WelcomeUser.BackgroundTransparency = 1
WelcomeUser.TextColor3 = THEME.Accent
WelcomeUser.Font = Enum.Font.GothamBold
WelcomeUser.TextSize = 12.5
WelcomeUser.Text = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")"
WelcomeUser.ZIndex = 37
WelcomeUser.Parent = WelcomeCard

local WelcomeDesc = Instance.new("TextLabel")
WelcomeDesc.Size = UDim2.new(0.88, 0, 0, 34)
WelcomeDesc.Position = UDim2.new(0.06, 0, 0, 106)
WelcomeDesc.BackgroundTransparency = 1
WelcomeDesc.TextColor3 = THEME.TextMuted
WelcomeDesc.Font = Enum.Font.Gotham
WelcomeDesc.TextSize = 11.5
WelcomeDesc.TextWrapped = true
WelcomeDesc.Text = T("welcome_desc")
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
CopyInviteBtn.Text = T("copy_invite")
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
CloseWelcomeBtn.Text = T("close")
CloseWelcomeBtn.ZIndex = 37
CloseWelcomeBtn.Parent = WelcomeCard
Instance.new("UICorner", CloseWelcomeBtn).CornerRadius = UDim.new(0, 9)

RegisterLanguageUpdater(function()
    WelcomeDesc.Text = T("welcome_desc")
    CopyInviteBtn.Text = T("copy_invite")
    CloseWelcomeBtn.Text = T("close")
end)

CopyInviteBtn.MouseButton1Click:Connect(function()
    local clipFn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if clipFn then
        pcall(function() clipFn(DISCORD_LINK) end)
        CopyInviteBtn.Text = T("copied")
        task.delay(1.8, function()
            if CopyInviteBtn then CopyInviteBtn.Text = T("copy_invite") end
        end)
    else
        CopyInviteBtn.Text = "discord.gg/zyrex"
    end
end)

CloseWelcomeBtn.MouseButton1Click:Connect(function()
    WelcomeBackdrop.Visible = false
    MainFrame.Visible = true
    FloatingBtn.Visible = true
end)

MakeDraggable(FloatingBtn, FloatingBtn, function()
    if WelcomeBackdrop.Visible then
        WelcomeBackdrop.Visible = false
        MainFrame.Visible = true
    else
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- === TOP BAR ===
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = THEME.BgSidebar
TopBar.BackgroundTransparency = 0.18
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = MainFrame
MakeDraggable(TopBar, MainFrame)

local TopDivider = Instance.new("Frame")
TopDivider.Size = UDim2.new(1, 0, 0, 1)
TopDivider.Position = UDim2.new(0, 0, 1, -1)
TopDivider.BackgroundColor3 = THEME.Border
TopDivider.BorderSizePixel = 0
TopDivider.ZIndex = 3
TopDivider.Parent = TopBar

local TopLogo = Instance.new("ImageLabel")
TopLogo.Name = "ArchX_HeaderLogo"
TopLogo.Size = UDim2.new(0, 30, 0, 30)
TopLogo.Position = UDim2.new(0, 14, 0.5, -15)
TopLogo.BackgroundTransparency = 1
TopLogo.BorderSizePixel = 0
TopLogo.Image = CONFIG.LogoID
TopLogo.ScaleType = Enum.ScaleType.Fit
TopLogo.ZIndex = 3
TopLogo.Parent = TopBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -170, 0, 20)
TitleLbl.Position = UDim2.new(0, 52, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3 = THEME.TextPrimary
TitleLbl.TextSize = 14
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.Text = "ArchX  |  " .. gameName
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
TitleLbl.ZIndex = 3
TitleLbl.Parent = TopBar

local SubTitleLbl = Instance.new("TextLabel")
SubTitleLbl.Size = UDim2.new(1, -170, 0, 16)
SubTitleLbl.Position = UDim2.new(0, 52, 0, 25)
SubTitleLbl.BackgroundTransparency = 1
SubTitleLbl.TextColor3 = THEME.TextMuted
SubTitleLbl.TextSize = 11
SubTitleLbl.Font = Enum.Font.Gotham
SubTitleLbl.Text = "ArchX  •  discord.gg/zyrex"
SubTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLbl.ZIndex = 3
SubTitleLbl.Parent = TopBar

local function CreateHeaderBtn(text, offsetX, hoverColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 26, 0, 26)
    btn.Position = UDim2.new(1, offsetX, 0.5, -13)
    btn.BackgroundColor3 = THEME.BgCard
    btn.TextColor3 = THEME.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Text = text
    btn.ZIndex = 3
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

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end)

-- === SIDEBAR + PROFIL PLAYER ===
local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 165, 1, -48)
SideBar.Position = UDim2.new(0, 0, 0, 48)
SideBar.BackgroundColor3 = THEME.BgSidebar
SideBar.BackgroundTransparency = 0.22
SideBar.BorderSizePixel = 0
SideBar.ZIndex = 2
SideBar.Parent = MainFrame

local SideDivider = Instance.new("Frame")
SideDivider.Size = UDim2.new(0, 1, 1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 0)
SideDivider.BackgroundColor3 = THEME.Border
SideDivider.BorderSizePixel = 0
SideDivider.ZIndex = 3
SideDivider.Parent = SideBar

local TabListFrame = Instance.new("Frame")
TabListFrame.Size = UDim2.new(1, -16, 1, -74)
TabListFrame.Position = UDim2.new(0, 8, 0, 10)
TabListFrame.BackgroundTransparency = 1
TabListFrame.ZIndex = 3
TabListFrame.Parent = SideBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.Parent = TabListFrame
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 5)

local ProfileCard = Instance.new("Frame")
ProfileCard.Size = UDim2.new(1, -16, 0, 52)
ProfileCard.Position = UDim2.new(0, 8, 1, -60)
ProfileCard.BackgroundColor3 = THEME.BgCard
ProfileCard.BackgroundTransparency = 0.12
ProfileCard.ZIndex = 3
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
AvatarImg.ZIndex = 4
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
DisplayNameLbl.ZIndex = 4
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
UserNameLbl.ZIndex = 4
UserNameLbl.Parent = ProfileCard

-- === CONTAINER HALAMAN ===
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -177, 1, -60)
PagesContainer.Position = UDim2.new(0, 171, 0, 54)
PagesContainer.BackgroundTransparency = 1
PagesContainer.ZIndex = 2
PagesContainer.Parent = MainFrame

local tabs = {}
local activeTabId = nil

local function CreateTab(tabId, langKey, iconGlyph)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.BgCard
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 4
    btn.Parent = TabListFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.58, 0)
    indicator.Position = UDim2.new(0, 4, 0.21, 0)
    indicator.BackgroundColor3 = THEME.Accent
    indicator.Visible = false
    indicator.ZIndex = 5
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
    iconLbl.ZIndex = 5
    iconLbl.Parent = btn

    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, -42, 1, 0)
    textLbl.Position = UDim2.new(0, 38, 0, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.TextColor3 = THEME.TextMuted
    textLbl.TextSize = 12
    textLbl.Font = Enum.Font.GothamSemibold
    textLbl.Text = T(langKey)
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.ZIndex = 5
    textLbl.Parent = btn

    RegisterLanguageUpdater(function()
        textLbl.Text = T(langKey)
    end)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.ZIndex = 3
    page.Parent = PagesContainer

    local layout = Instance.new("UIListLayout")
    layout.Parent = page
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end))

    local tabObj = { btn = btn, indicator = indicator, iconLbl = iconLbl, textLbl = textLbl, page = page }
    tabs[tabId] = tabObj

    local function SelectTab()
        activeTabId = tabId
        for id, item in pairs(tabs) do
            local isSelected = (id == tabId)
            item.page.Visible = isSelected
            item.indicator.Visible = isSelected
            TweenService:Create(item.btn, TweenInfo.new(0.18), {
                BackgroundTransparency = isSelected and 0.12 or 1
            }):Play()
            item.iconLbl.TextColor3 = isSelected and THEME.Accent or THEME.TextMuted
            item.textLbl.TextColor3 = isSelected and THEME.TextPrimary or THEME.TextMuted
        end
    end

    btn.MouseButton1Click:Connect(SelectTab)
    if not activeTabId then SelectTab() end
    return page
end

-- === BUILDER KOMPONEN UI ARCHX ===
local function CreateHelpButton(parent, titleKey, helpKey)
    local qBtn = Instance.new("TextButton")
    qBtn.Size = UDim2.new(0, 20, 0, 20)
    qBtn.BackgroundColor3 = THEME.BgSidebar
    qBtn.TextColor3 = THEME.TextMuted
    qBtn.Font = Enum.Font.GothamBold
    qBtn.TextSize = 11
    qBtn.Text = "?"
    qBtn.ZIndex = 5
    qBtn.Parent = parent
    Instance.new("UICorner", qBtn).CornerRadius = UDim.new(1, 0)

    local st = Instance.new("UIStroke")
    st.Color = THEME.Border
    st.Thickness = 1
    st.Parent = qBtn

    qBtn.MouseButton1Click:Connect(function()
        ShowFeatureInfo(T(titleKey), T(helpKey))
    end)
    return qBtn
end

local function CreateCardToggle(parentPage, titleKey, descKey, helpKey, defaultState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 56)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.14
    card.ZIndex = 4
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
    title.Text = T(titleKey)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 5
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -82, 0.5, -10)

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -100, 0, 18)
    desc.Position = UDim2.new(0, 14, 0, 29)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = THEME.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.Text = T(descKey)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.ZIndex = 5
    desc.Parent = card

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(0, 42, 0, 22)
    switchBtn.Position = UDim2.new(1, -54, 0.5, -11)
    switchBtn.BackgroundColor3 = defaultState and THEME.Accent or THEME.SwitchOff
    switchBtn.Text = ""
    switchBtn.ZIndex = 5
    switchBtn.Parent = card
    Instance.new("UICorner", switchBtn).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(185, 180, 192)
    knob.ZIndex = 6
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
            BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(185, 180, 192)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.18), {
            Color = state and THEME.AccentSoft or THEME.Border
        }):Play()
        if not silent then callback(state, desc) end
    end

    switchBtn.MouseButton1Click:Connect(function()
        SetState(not state, false)
    end)

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey)
        desc.Text = T(descKey)
    end)

    return desc, SetState
end

local function CreateCardAction(parentPage, titleKey, descKey, helpKey, actionGlyph, callback)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, -6, 0, 56)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.14
    card.Text = ""
    card.AutoButtonColor = false
    card.ZIndex = 4
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
    title.Text = T(titleKey)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -74, 0.5, -10)

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -92, 0, 18)
    desc.Position = UDim2.new(0, 14, 0, 29)
    desc.BackgroundTransparency = 1
    desc.TextColor3 = THEME.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.Text = T(descKey)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextTruncate = Enum.TextTruncate.AtEnd
    desc.ZIndex = 5
    desc.Parent = card

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 30, 0, 30)
    badge.Position = UDim2.new(1, -44, 0.5, -15)
    badge.BackgroundColor3 = THEME.BgSidebar
    badge.TextColor3 = THEME.Accent
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 14
    badge.Text = actionGlyph or "✦"
    badge.ZIndex = 5
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey)
        desc.Text = T(descKey)
    end)

    card.MouseButton1Click:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.12), {Color = THEME.Accent}):Play()
        task.delay(0.2, function()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.2), {Color = THEME.Border}):Play() end
        end)
        callback(desc, badge)
    end)

    return desc
end

local function CreateCardSlider(parentPage, titleKey, helpKey, minVal, maxVal, defaultVal, onChanged)
    local currentVal = defaultVal
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 64)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.14
    card.ZIndex = 4
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
    title.Text = T(titleKey) .. ": " .. tostring(currentVal)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -34, 0, 8)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -28, 0, 14)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = THEME.BgInput
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 5
    track.Parent = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local function UpdateFromInput(inputPos)
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        currentVal = math.floor(minVal + (maxVal - minVal) * relX + 0.5)
        fill.Size = UDim2.new(relX, 0, 1, 0)
        title.Text = T(titleKey) .. ": " .. tostring(currentVal)
        onChanged(currentVal)
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

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey) .. ": " .. tostring(currentVal)
    end)
end

local function CreateLanguageSelectorCard(parentPage)
    local expanded = false
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 48)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 0.14
    card.ClipsDescendants = true
    card.ZIndex = 4
    card.Parent = parentPage
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = card

    local headerBar = Instance.new("Frame")
    headerBar.Size = UDim2.new(1, 0, 0, 48)
    headerBar.BackgroundTransparency = 1
    headerBar.ZIndex = 5
    headerBar.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -145, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = T("lang_title")
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 6
    title.Parent = headerBar

    local qBtn = CreateHelpButton(headerBar, "lang_title", "lang_help")
    qBtn.Position = UDim2.new(1, -128, 0.5, -10)

    local langBtn = Instance.new("TextButton")
    langBtn.Size = UDim2.new(0, 92, 0, 28)
    langBtn.Position = UDim2.new(1, -102, 0.5, -14)
    langBtn.BackgroundColor3 = THEME.BgSidebar
    langBtn.TextColor3 = THEME.Accent
    langBtn.Font = Enum.Font.GothamBold
    langBtn.TextSize = 11.5
    langBtn.Text = "🌐 " .. currentLang
    langBtn.ZIndex = 6
    langBtn.Parent = headerBar
    Instance.new("UICorner", langBtn).CornerRadius = UDim.new(0, 7)

    local selStroke = Instance.new("UIStroke")
    selStroke.Color = THEME.Border
    selStroke.Thickness = 1
    selStroke.Parent = langBtn

    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Size = UDim2.new(1, -20, 0, 68)
    listContainer.Position = UDim2.new(0, 10, 0, 50)
    listContainer.BackgroundColor3 = THEME.BgInput
    listContainer.BorderSizePixel = 0
    listContainer.ScrollBarThickness = 2
    listContainer.ScrollBarImageColor3 = THEME.Accent
    listContainer.ZIndex = 5
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

    local rowButtons = {}
    for _, langInfo in ipairs(LANGUAGE_LIST) do
        local rBtn = Instance.new("TextButton")
        rBtn.Size = UDim2.new(1, 0, 0, 25)
        rBtn.BackgroundColor3 = THEME.BgCard
        rBtn.BackgroundTransparency = (currentLang == langInfo.code) and 0.1 or 0.65
        rBtn.Font = Enum.Font.GothamSemibold
        rBtn.TextSize = 11.5
        rBtn.TextXAlignment = Enum.TextXAlignment.Left
        rBtn.Text = ((currentLang == langInfo.code) and "●  " or "○  ") .. langInfo.label
        rBtn.TextColor3 = (currentLang == langInfo.code) and THEME.Green or THEME.TextMuted
        rBtn.ZIndex = 6
        rBtn.Parent = listContainer
        Instance.new("UICorner", rBtn).CornerRadius = UDim.new(0, 6)

        local rPad = Instance.new("UIPadding")
        rPad.PaddingLeft = UDim.new(0, 8)
        rPad.Parent = rBtn

        rowButtons[langInfo.code] = { btn = rBtn, label = langInfo.label }

        rBtn.MouseButton1Click:Connect(function()
            ApplyLanguage(langInfo.code)
            for code, item in pairs(rowButtons) do
                local active = (code == currentLang)
                item.btn.Text = (active and "●  " or "○  ") .. item.label
                item.btn.TextColor3 = active and THEME.Green or THEME.TextMuted
                item.btn.BackgroundTransparency = active and 0.1 or 0.65
            end
        end)
    end
    listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)

    langBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = expanded and UDim2.new(1, -6, 0, 126) or UDim2.new(1, -6, 0, 48)
        }):Play()
        stroke.Color = expanded and THEME.AccentSoft or THEME.Border
    end)

    RegisterLanguageUpdater(function()
        title.Text = T("lang_title")
        langBtn.Text = "🌐 " .. currentLang
    end)
end

-- ==========================================
-- ENGINE SURVIVE YOUR IDEAS
-- ==========================================

-- 1. Anti-AFK
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if State.runningAntiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

-- 2. NoClip (Anti-Sink & Anti-Fling)
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

-- 3. Anti-Ragdoll
local function enforceAntiRagdoll(char, hum)
    if not char or not hum then return end
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
        or st == Enum.HumanoidStateType.Physics then
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

-- 4. God Mode + Anti-Spam Hit (Auto-Evade 2x)
local function bindCharacterProtection(char)
    for _, conn in ipairs(activeCharConns) do
        conn:Disconnect()
    end
    table.clear(activeCharConns)

    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    lastHealthSeen = hum.Health

    local hcConn = hum.HealthChanged:Connect(function(newHp)
        if State.godMode or State.antiDie then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
        end

        if State.godMode then
            if newHp < lastHealthSeen then
                if hum.MaxHealth < 100 then hum.MaxHealth = 100 end
                hum.Health = hum.MaxHealth

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

    local stConn = hum.StateChanged:Connect(function(_, newState)
        if (State.godMode or State.antiDie) and newState == Enum.HumanoidStateType.Dead then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.Health = hum.MaxHealth
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
    table.insert(activeCharConns, stConn)
end

-- 5. Smart Teleport (Immune Back-TP)
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

-- 6. Mobile Fly & Touch
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

-- 7. ESP Players, Items & Hazards
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
        bb.Size = UDim2.new(0, 125, 0, 24)
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
    espFolder.Parent = ScreenGui

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

-- === UNLOAD TOTAL SKRIP ===
local function UnloadArchXScript()
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
        if conn and conn.Connected then conn:Disconnect() end
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

    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    ScreenGui:Destroy()
end

-- === MEMBUAT 5 TAB NAVIGASI ARCHX ===
local ArenaPage   = CreateTab("arena", "tab_arena", "⚡")
local MovePage    = CreateTab("move", "tab_move", "🏃")
local ProtectPage = CreateTab("protect", "tab_protect", "🛡️")
local TpPage      = CreateTab("tp", "tab_tp", "📍")
local SettingPage = CreateTab("settings", "tab_settings", "⚙️")

-- ==========================================
-- TAB 1: ARENA & SKY
-- ==========================================
CreateCardToggle(
    ArenaPage,
    "backtp_title",
    "backtp_desc",
    "backtp_help",
    true,
    function(on)
        State.antiBackTP = on
        local _, hum = getCharParts()
        if hum and not on and State.walkSpeedEnabled then
            hum.WalkSpeed = State.walkSpeedValue
        end
    end
)

CreateCardAction(
    ArenaPage,
    "sky_title",
    "sky_desc",
    "sky_help",
    "🚀",
    function(desc)
        local _, _, hrp = getCharParts()
        if not hrp then return end

        if not skyPlatform or not skyPlatform.Parent then
            skyPlatform = Instance.new("Part")
            skyPlatform.Name = "SYI_SkyPlatform"
            skyPlatform.Size = Vector3.new(35, 2, 35)
            skyPlatform.Anchored = true
            skyPlatform.CanCollide = true
            skyPlatform.Transparency = 0.35
            skyPlatform.Material = Enum.Material.Neon
            skyPlatform.Color = THEME.Accent
            skyPlatform.Parent = workspace
        end

        State.preSkyCFrame = hrp.CFrame
        local skyPos = Vector3.new(hrp.Position.X, math.max(260, hrp.Position.Y + 220), hrp.Position.Z)
        skyPlatform.Position = skyPos - Vector3.new(0, 4, 0)

        desc.Text = "Teleporting to Safe Sky..."
        task.spawn(function()
            smartTeleport(CFrame.new(skyPos))
            desc.Text = "Safe Sky Active!"
            task.wait(1.5)
            if desc then desc.Text = T("sky_desc") end
        end)
    end
)

CreateCardAction(
    ArenaPage,
    "ret_title",
    "ret_desc",
    "ret_help",
    "🪂",
    function(desc)
        local _, _, hrp = getCharParts()
        if hrp and State.preSkyCFrame then
            desc.Text = "Returning to Arena..."
            task.spawn(function()
                smartTeleport(State.preSkyCFrame + Vector3.new(0, 3, 0))
                desc.Text = T("ret_desc")
            end)
        else
            desc.Text = "No saved sky return point!"
            task.delay(1.5, function()
                if desc then desc.Text = T("ret_desc") end
            end)
        end
    end
)

CreateCardToggle(
    ArenaPage,
    "esp_title",
    "esp_desc",
    "esp_help",
    false,
    function(on)
        State.espEnabled = on
        if on then refreshESP() else clearESP() end
    end
)

-- ==========================================
-- TAB 2: MOVEMENT
-- ==========================================
CreateCardToggle(
    MovePage,
    "ws_en_title",
    "ws_en_desc",
    "ws_en_help",
    false,
    function(on)
        State.walkSpeedEnabled = on
        local _, hum = getCharParts()
        if not on and hum then hum.WalkSpeed = 16 end
    end
)

CreateCardSlider(
    MovePage,
    "ws_val_title",
    "ws_val_help",
    16, 250, State.walkSpeedValue,
    function(val)
        State.walkSpeedValue = val
    end
)

CreateCardToggle(
    MovePage,
    "jp_en_title",
    "jp_en_desc",
    "jp_en_help",
    false,
    function(on)
        State.jumpPowerEnabled = on
        local _, hum = getCharParts()
        if not on and hum then hum.JumpPower = 50 end
    end
)

CreateCardSlider(
    MovePage,
    "jp_val_title",
    "jp_val_help",
    50, 400, State.jumpPowerValue,
    function(val)
        State.jumpPowerValue = val
    end
)

CreateCardToggle(
    MovePage,
    "fly_title",
    "fly_desc",
    "fly_help",
    false,
    function(on)
        toggleFly(on)
    end
)

CreateCardSlider(
    MovePage,
    "flyspd_title",
    "flyspd_help",
    20, 250, State.flySpeed,
    function(val)
        State.flySpeed = val
    end
)

CreateCardToggle(
    MovePage,
    "noclip_title",
    "noclip_desc",
    "noclip_help",
    false,
    function(on)
        State.noclip = on
        if on then
            applyNoclip()
        else
            disableNoclip()
        end
    end
)

-- ==========================================
-- TAB 3: PROTECTION
-- ==========================================
CreateCardToggle(
    ProtectPage,
    "god_title",
    "god_desc",
    "god_help",
    false,
    function(on)
        State.godMode = on
        setCharacterTouch(not on)
        local _, hum = getCharParts()
        if hum and on then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum.BreakJointsOnDeath = false
            hum.Health = hum.MaxHealth
        end
    end
)

CreateCardToggle(
    ProtectPage,
    "spamhit_title",
    "spamhit_desc",
    "spamhit_help",
    true,
    function(on)
        State.antiSpamHit = on
    end
)

CreateCardToggle(
    ProtectPage,
    "ragdoll_title",
    "ragdoll_desc",
    "ragdoll_help",
    false,
    function(on)
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
    end
)

CreateCardToggle(
    ProtectPage,
    "antidie_title",
    "antidie_desc",
    "antidie_help",
    false,
    function(on)
        State.antiDie = on
        local _, hum = getCharParts()
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not on)
            hum.BreakJointsOnDeath = not on
        end
    end
)

-- ==========================================
-- TAB 4: TELEPORT
-- ==========================================
CreateCardAction(
    TpPage,
    "savepos_title",
    "savepos_desc",
    "savepos_help",
    "📌",
    function(desc)
        local _, _, hrp = getCharParts()
        if hrp then
            State.savedCFrame = hrp.CFrame
            desc.Text = string.format("Saved: (%.0f, %.0f, %.0f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            task.delay(2, function()
                if desc then desc.Text = T("savepos_desc") end
            end)
        end
    end
)

CreateCardAction(
    TpPage,
    "tppos_title",
    "tppos_desc",
    "tppos_help",
    "⚡",
    function(desc)
        local _, _, hrp = getCharParts()
        if hrp and State.savedCFrame then
            task.spawn(function()
                smartTeleport(State.savedCFrame)
            end)
            desc.Text = "Teleported!"
            task.delay(1.2, function()
                if desc then desc.Text = T("tppos_desc") end
            end)
        else
            desc.Text = "No saved position yet!"
            task.delay(1.5, function()
                if desc then desc.Text = T("tppos_desc") end
            end)
        end
    end
)

CreateCardAction(
    TpPage,
    "tpplr_title",
    "tpplr_desc",
    "tpplr_help",
    "👥",
    function(desc)
        local _, _, hrp = getCharParts()
        if not hrp then return end
        local others = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(others, plr)
            end
        end
        if #others == 0 then
            desc.Text = "No other players found!"
            task.delay(1.5, function()
                if desc then desc.Text = T("tpplr_desc") end
            end)
            return
        end
        if State.playerIndex > #others then State.playerIndex = 1 end
        local target = others[State.playerIndex]
        State.playerIndex += 1

        desc.Text = "TP -> " .. target.DisplayName
        task.spawn(function()
            smartTeleport(target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 2))
            task.wait(1.5)
            if desc then desc.Text = T("tpplr_desc") end
        end)
    end
)

CreateCardAction(
    TpPage,
    "tptool_title",
    "tptool_desc",
    "tptool_help",
    "🪄",
    function(desc)
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end
        if backpack:FindFirstChild("Tap TP") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Tap TP")) then
            desc.Text = "Tap TP already in Backpack!"
            task.delay(1.5, function()
                if desc then desc.Text = T("tptool_desc") end
            end)
            return
        end

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
        desc.Text = "Tap TP added to Backpack!"
        task.delay(1.5, function()
            if desc then desc.Text = T("tptool_desc") end
        end)
    end
)

-- ==========================================
-- TAB 5: AFK & SETTINGS
-- ==========================================
CreateLanguageSelectorCard(SettingPage)

CreateCardToggle(
    SettingPage,
    "antiafk_title",
    "antiafk_desc",
    "antiafk_help",
    true,
    function(state)
        State.runningAntiAfk = state
    end
)

local _, setBlackScreenToggle = CreateCardToggle(
    SettingPage,
    "black_title",
    "black_desc",
    "black_help",
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
    SettingPage,
    "unload_title",
    "unload_desc",
    "unload_help",
    "⏻",
    function()
        UnloadArchXScript()
    end
)

ApplyLanguage(currentLang)

if LocalPlayer.Character then
    bindCharacterProtection(LocalPlayer.Character)
end

-- ==========================================
-- LOOPS UTAMA (STEPPED + HEARTBEAT + RESPAWN)
-- ==========================================
table.insert(connections, RunService.Stepped:Connect(function()
    if State.noclip then
        applyNoclip()
    end
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
end))

table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    local char, hum, hrp = getCharParts()
    if not char or not hum or not hrp then return end

    -- Anti-Ragdoll
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

    -- NoClip + Penahan Lantai Raycast
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
end))

-- Re-apply saat karakter respawn
table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
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
end))
