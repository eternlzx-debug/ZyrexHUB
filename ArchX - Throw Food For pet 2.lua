-- ArchX (Clean Multi-Language Edition - Upgraded)
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

-- === KONFIGURASI ASET & BRANDING PATEN ===
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

-- === DETEKSI NAMA GAME ===
local okGame, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
local gameName = (okGame and gameInfo and gameInfo.Name) or "Throw Food for Animals"

-- === STATE & VARIABEL GLOBAL ===
local DISCORD_LINK = CONFIG.DiscordLink
local currentLang = "EN"

local runningTap = false
local runningSteal = false
local runningEquip = false
local runningSell = false
local runningTrain = false
local runningUpgrade = false
local runningFood = false
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
local connections = {}
local sessionStartTick = tick()
local sessionStartClock = os.date("%H:%M:%S")

local totalStealCount = 0
local totalSoldCount = 0
local totalRareCount = 0
local lastCaughtName = "-"
local lastCatchTick = 0
local lastPlotFullTick = 0

-- State Smart Auto Buy
local insufficientCashFlag = false
local lastInsufficientTick = 0
local foodWaitingForCash = false
local standWaitingForCash = false
local bestAffordableFoodKey = nil
local cachedFoodCatalog = nil

-- === SISTEM MULTI-BAHASA (10 BAHASA UTAMA PEMAIN ROBLOX) ===
local LANGUAGE_LIST = {
    { code = "ID", label = "Indonesia (Bahasa Indonesia)" },
    { code = "EN", label = "English (Global / US)" },
    { code = "ES", label = "Español (América Latina / España)" },
    { code = "PT", label = "Português (Brasil)" },
    { code = "RU", label = "Русский (Россия)" },
    { code = "TL", label = "Filipino (Tagalog)" },
    { code = "VI", label = "Tiếng Việt (Việt Nam)" },
    { code = "AR", label = "العربية (Arabic)" },
    { code = "KO", label = "한국어 (대한민국)" },
    { code = "JA", label = "日本語 (日本)" },
}

local TRANSLATIONS = {
    ID = {
        welcome_desc = "Terima kasih telah menggunakan ArchX. Bergabunglah ke server Discord kami untuk pembaruan skrip terbaru.",
        copy_invite = "Copy Invite",
        copied = "Tersalin!",
        close = "Tutup",
        info_title = "Informasi Fitur",
        understood = "Mengerti",
        afk_overlay = "🌙 MODE HEMAT DAYA AFK AKTIF\nTampilan 3D dinonaktifkan untuk menjaga suhu perangkat.\n\nKetuk layar di mana saja untuk kembali.",
        tab_farm = "Auto Farm",
        tab_shop = "Shop & Stand",
        tab_player = "Player",
        tab_afk = "AFK & Stats",
        tap_title = "Auto Tap x2",
        tap_desc = "Mengaktifkan bonus ketukan ganda secara otomatis saat latihan",
        tap_help = "Menekan tombol bonus ketukan ganda (x2) secara otomatis ketika muncul selama sesi latihan berlangsung.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Menangkap hewan secara otomatis dan menampilkan detail tangkapan",
        steal_help = "Mengunci posisi berdiri pada titik lempar, melakukan lemparan otomatis, dan menampilkan notifikasi khusus hewan yang tertangkap.",
        train_title = "Auto Train",
        train_desc_off = "Status: Nonaktif",
        train_desc_on = "Status: Sesi latihan aktif",
        train_help = "Mengirim perintah mulai latihan (Training_Start) saat diaktifkan dan menghentikannya (Training_Stop) saat dinonaktifkan.",
        equip_title = "Auto Equip Best",
        equip_desc = "Memasang hewan dengan pendapatan tertinggi secara berkala",
        equip_help = "Memilih dan memasang hewan dengan pendapatan per detik tertinggi ke dalam kandang Anda secara berkala.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Status: Nonaktif (Pilih filter di bawah)",
        sell_desc_on = "Status: Aktif menjual sesuai kriteria pilihan",
        sell_help = "Menjual hewan di dalam tas secara otomatis apabila memenuhi kriteria Tier, Mutasi, atau Jenis Hewan yang dipilih.",
        sel_tier = "Select Tier To Sell",
        sel_tier_help = "Pilih tingkat kelangkaan (Tier) hewan yang akan dijual otomatis.",
        sel_mut = "Select Mutations To Sell",
        sel_mut_help = "Pilih jenis mutasi hewan yang akan dijual otomatis.",
        sel_ani = "Select Animals To Sell",
        sel_ani_help = "Pilih nama hewan tertentu yang akan dijual otomatis.",
        select_btn = "Pilih...",
        selected_fmt = "Dipilih (%d)",
        food_title = "Auto Buy Food High",
        food_desc_idle = "Status: Siap membeli makanan tertinggi otomatis",
        food_desc_buy = "Status: Membeli Food Terbaik (%s)",
        food_desc_wait = "Status: Menunggu uang mencukupi",
        food_help = "Mendeteksi dan membeli makanan dengan tingkat tertinggi yang terjangkau secara otomatis.",
        stand_title = "Auto Upgrade Stand",
        stand_desc_idle = "Status: Siap meningkatkan stand otomatis",
        stand_desc_ok = "Status: Stand berhasil ditingkatkan",
        stand_desc_wait = "Status: Menunggu uang mencukupi",
        stand_help = "Meningkatkan level stand Anda secara otomatis ketika uang mencukupi.",
        ws_title = "WalkSpeed",
        ws_help = "Mengatur kecepatan berjalan karakter Anda.",
        jp_title = "JumpPower",
        jp_help = "Mengatur tinggi lompatan karakter Anda.",
        fly_title = "Fly",
        fly_desc = "Memungkinkan karakter terbang bebas di udara",
        fly_help = "Mengaktifkan mode terbang ke segala arah sesuai arah kamera.",
        flyspd_title = "Fly Speed",
        flyspd_help = "Mengatur kecepatan pergerakan saat terbang.",
        noclip_title = "NoClip",
        noclip_desc = "Menembus dinding dan penghalang objek",
        noclip_help = "Menonaktifkan benturan fisik karakter agar dapat melewati dinding dan rintangan.",
        lang_title = "Bahasa GUI (Language)",
        lang_help = "Pilih bahasa antarmuka GUI sesuai negara Anda.",
        antiafk_title = "Built-in Anti-AFK",
        antiafk_desc = "Mencegah terputus dari server saat ditinggal diam",
        antiafk_help = "Menjaga sesi tetap aktif agar akun tidak dikeluarkan otomatis saat AFK.",
        black_title = "Mode Hemat Daya Layar Hitam",
        black_desc = "Mematikan tampilan 3D saat AFK (ketuk layar untuk kembali)",
        black_help = "Menonaktifkan render 3D untuk menghemat baterai dan menjaga suhu perangkat.",
        notif_mode_title = "Mode Notifikasi & Discord",
        notif_mode_help = "Pilih apakah notifikasi layar dan Discord menampilkan semua tangkapan (Lengkap) atau hanya hewan langka/mutasi (Rare Only).",
        btn_full = "Lengkap (All)",
        btn_rare = "Rare Only",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "Tempel tautan Webhook Discord untuk menerima laporan otomatis.",
        wh_url_ph = "Tempel URL https://discord.com/api/webhooks/...",
        wh_en_title = "Aktifkan Discord Webhook",
        wh_en_desc_off = "Nonaktif",
        wh_en_desc_on = "Aktif: Mengirim catatan ke Discord",
        wh_en_help = "Mengirim pesan pemberitahuan ke saluran Discord sesuai mode pilihan.",
        wh_test_title = "Test Kirim Discord Webhook",
        wh_test_desc = "Menguji koneksi pengiriman pesan ke Discord",
        wh_test_help = "Mengirim pesan percobaan untuk memastikan Webhook berfungsi.",
        stat_title = "Dashboard Statistik Sesi",
        stat_fmt = "Tertangkap: %d Pet  •  Terjual: %d",
        stat_help = "Dashboard pemantauan lengkap: durasi sesi, jumlah tangkapan, kecepatan per menit, tangkapan langka, serta status server.",
        dash_time = "🕒 Mulai & Durasi",
        dash_caught = "🐾 Total Tertangkap",
        dash_sold = "💰 Total Terjual",
        dash_rare = "🌟 Langka & Mutasi",
        dash_last = "🏆 Tangkapan Terakhir",
        dash_server = "🌐 Server & Ping",
        dash_reset = "Reset",
        relock_title = "Perbarui Titik Kunci Auto Steal",
        relock_desc = "Simpan posisi berdiri saat ini sebagai titik lempar",
        relock_help = "Memperbarui koordinat posisi berdiri utama untuk fitur Auto Steal.",
        unload_title = "Matikan Skrip Permanen (Unload)",
        unload_desc = "Hentikan semua fitur dan hapus GUI ArchX sepenuhnya",
        unload_help = "Menutup total skrip ArchX beserta logo floating dari layar.",
    },
    EN = {
        welcome_desc = "Thank you for using ArchX. Join our Discord server for the latest script updates.",
        copy_invite = "Copy Invite",
        copied = "Copied!",
        close = "Close",
        info_title = "Feature Information",
        understood = "Got It",
        afk_overlay = "🌙 AFK BATTERY SAVER ACTIVE\n3D rendering is disabled to keep your device cool.\n\nTap anywhere on the screen to return.",
        tab_farm = "Auto Farm",
        tab_shop = "Shop & Stand",
        tab_player = "Player",
        tab_afk = "AFK & Stats",
        tap_title = "Auto Tap x2",
        tap_desc = "Automatically clicks the x2 bonus button during training",
        tap_help = "Automatically triggers the x2 tap bonus button whenever it appears during training.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Automatically catches pets and shows catch details",
        steal_help = "Locks your standing spot, performs automatic throws, and shows notifications strictly for caught pets.",
        train_title = "Auto Train",
        train_desc_off = "Status: Inactive",
        train_desc_on = "Status: Training session active",
        train_help = "Fires Training_Start when enabled and Training_Stop when disabled.",
        equip_title = "Auto Equip Best",
        equip_desc = "Periodically equips your highest earning pets",
        equip_help = "Automatically equips your highest CPS pets onto your plot periodically.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Status: Inactive (Select filters below)",
        sell_desc_on = "Status: Selling pets matching selected filters",
        sell_help = "Automatically sells backpack pets matching any selected Tier, Mutation, or Animal.",
        sel_tier = "Select Tier To Sell",
        sel_tier_help = "Choose which pet rarities (Tiers) to sell automatically.",
        sel_mut = "Select Mutations To Sell",
        sel_mut_help = "Choose which pet mutations to sell automatically.",
        sel_ani = "Select Animals To Sell",
        sel_ani_help = "Choose specific animal species to sell automatically.",
        select_btn = "Select...",
        selected_fmt = "Selected (%d)",
        food_title = "Auto Buy Food High",
        food_desc_idle = "Status: Ready to auto-buy highest food",
        food_desc_buy = "Status: Buying Best Food (%s)",
        food_desc_wait = "Status: Waiting for enough cash",
        food_help = "Automatically detects and purchases the highest affordable food tier.",
        stand_title = "Auto Upgrade Stand",
        stand_desc_idle = "Status: Ready to auto-upgrade stand",
        stand_desc_ok = "Status: Stand upgraded successfully",
        stand_desc_wait = "Status: Waiting for enough cash",
        stand_help = "Automatically upgrades your stand level whenever you have enough cash.",
        ws_title = "WalkSpeed",
        ws_help = "Adjusts your character's walking and running speed.",
        jp_title = "JumpPower",
        jp_help = "Adjusts your character's jump height.",
        fly_title = "Fly",
        fly_desc = "Allows your character to fly freely in the air",
        fly_help = "Enables directional flight controlled by your camera angle.",
        flyspd_title = "Fly Speed",
        flyspd_help = "Adjusts movement speed while flying.",
        noclip_title = "NoClip",
        noclip_desc = "Walk through walls and solid obstacles",
        noclip_help = "Disables character collision to pass through walls and fences.",
        lang_title = "GUI Language",
        lang_help = "Select your preferred interface language.",
        antiafk_title = "Built-in Anti-AFK",
        antiafk_desc = "Prevents idle disconnect after 20 minutes",
        antiafk_help = "Keeps your session active so you are not kicked while idle.",
        black_title = "Black Screen Power Saver",
        black_desc = "Disables 3D rendering while AFK (tap screen to return)",
        black_help = "Turns off 3D graphics rendering to save battery and reduce heat.",
        notif_mode_title = "Notification & Discord Mode",
        notif_mode_help = "Choose whether screen and Discord alerts show all catches (All) or only rare/mutated pets (Rare Only).",
        btn_full = "All Catches",
        btn_rare = "Rare Only",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "Paste your Discord Webhook URL for automated catch logs.",
        wh_url_ph = "Paste https://discord.com/api/webhooks/...",
        wh_en_title = "Enable Discord Webhook",
        wh_en_desc_off = "Disabled",
        wh_en_desc_on = "Active: Sending catch alerts to Discord",
        wh_en_help = "Sends catch notifications to your Discord channel based on the chosen mode.",
        wh_test_title = "Test Discord Webhook",
        wh_test_desc = "Send a test message to verify your webhook",
        wh_test_help = "Sends a sample embed to verify your Discord Webhook connection.",
        stat_title = "Session Statistics Dashboard",
        stat_fmt = "Caught: %d Pets  •  Sold: %d",
        stat_help = "Full real-time session dashboard: uptime, total caught & rate/min, total sold, rare catches, last catch, and server ping.",
        dash_time = "🕒 Start & Uptime",
        dash_caught = "🐾 Total Caught",
        dash_sold = "💰 Total Sold",
        dash_rare = "🌟 Rare & Mutated",
        dash_last = "🏆 Last Caught",
        dash_server = "🌐 Server & Ping",
        dash_reset = "Reset",
        relock_title = "Update Auto Steal Spot",
        relock_desc = "Save current standing position as throw point",
        relock_help = "Updates the locked standing position used by Auto Steal.",
        unload_title = "Unload Script Completely",
        unload_desc = "Stop all automation and remove ArchX GUI",
        unload_help = "Completely closes ArchX and removes the floating logo from your screen.",
    },
    ES = {
        welcome_desc = "Gracias por usar ArchX. Únete a nuestro Discord para recibir las últimas actualizaciones.",
        copy_invite = "Copiar Invitación",
        copied = "¡Copiado!",
        close = "Cerrar",
        info_title = "Información",
        understood = "Entendido",
        afk_overlay = "🌙 MODO AHORRO AFK ACTIVO\nRenderizado 3D desactivado.\n\nToca la pantalla para volver.",
        tab_farm = "Auto Farm",
        tab_shop = "Tienda y Stand",
        tab_player = "Jugador",
        tab_afk = "AFK y Stats",
        tap_title = "Auto Tap x2",
        tap_desc = "Presiona automáticamente el bono x2 al entrenar",
        tap_help = "Activa automáticamente el bono x2 durante el entrenamiento.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Atrapa mascotas automáticamente y muestra sus datos",
        steal_help = "Fija tu posición, lanza automáticamente y notifica solo las mascotas atrapadas.",
        train_title = "Auto Train",
        train_desc_off = "Estado: Inactivo",
        train_desc_on = "Estado: Entrenamiento activo",
        train_help = "Envía Training_Start al activar y Training_Stop al desactivar.",
        equip_title = "Auto Equip Best",
        equip_desc = "Equipa las mejores mascotas periódicamente",
        equip_help = "Equipa automáticamente tus mascotas con mayores ingresos.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Estado: Inactivo (Elige filtros abajo)",
        sell_desc_on = "Estado: Vendiendo mascotas seleccionadas",
        sell_help = "Vende mascotas de la mochila según Tier, Mutación o Animal.",
        sel_tier = "Seleccionar Tier",
        sel_tier_help = "Elige las rarezas que se venderán automáticamente.",
        sel_mut = "Seleccionar Mutaciones",
        sel_mut_help = "Elige las mutaciones que se venderán automáticamente.",
        sel_ani = "Seleccionar Animales",
        sel_ani_help = "Elige los animales específicos para vender.",
        select_btn = "Elegir...",
        selected_fmt = "Elegidos (%d)",
        food_title = "Auto Comprar Comida High",
        food_desc_idle = "Estado: Listo para comprar comida",
        food_desc_buy = "Estado: Comprando Comida (%s)",
        food_desc_wait = "Estado: Esperando dinero suficiente",
        food_help = "Compra automáticamente la mejor comida disponible.",
        stand_title = "Auto Mejorar Stand",
        stand_desc_idle = "Estado: Listo para mejorar stand",
        stand_desc_ok = "Estado: Stand mejorado",
        stand_desc_wait = "Estado: Esperando dinero suficiente",
        stand_help = "Mejora tu stand automáticamente cuando tengas dinero.",
        ws_title = "Velocidad (WalkSpeed)",
        ws_help = "Ajusta la velocidad al caminar.",
        jp_title = "Salto (JumpPower)",
        jp_help = "Ajusta la altura del salto.",
        fly_title = "Volar (Fly)",
        fly_desc = "Permite volar libremente por el mapa",
        fly_help = "Activa el vuelo libre según la dirección de la cámara.",
        flyspd_title = "Velocidad de Vuelo",
        flyspd_help = "Ajusta la velocidad al volar.",
        noclip_title = "NoClip",
        noclip_desc = "Atraviesa paredes y obstáculos",
        noclip_help = "Desactiva las colisiones del personaje.",
        lang_title = "Idioma (Language)",
        lang_help = "Cambia el idioma de toda la interfaz.",
        antiafk_title = "Anti-AFK Integrado",
        antiafk_desc = "Evita desconexión por inactividad",
        antiafk_help = "Mantiene tu sesión activa mientras estás AFK.",
        black_title = "Pantalla Negra Ahorro AFK",
        black_desc = "Desactiva gráficos 3D (toca para volver)",
        black_help = "Apaga el renderizado 3D para ahorrar batería.",
        notif_mode_title = "Modo Notificación y Discord",
        notif_mode_help = "Elige entre mostrar todas las capturas o solo las raras.",
        btn_full = "Completo (All)",
        btn_rare = "Solo Raros",
        wh_url_title = "URL Webhook Discord",
        wh_url_help = "Pega tu enlace Webhook de Discord.",
        wh_url_ph = "Pega https://discord.com/api/webhooks/...",
        wh_en_title = "Activar Webhook Discord",
        wh_en_desc_off = "Desactivado",
        wh_en_desc_on = "Activo: Enviando alertas a Discord",
        wh_en_help = "Envía alertas de captura a tu canal de Discord.",
        wh_test_title = "Probar Webhook Discord",
        wh_test_desc = "Envía un mensaje de prueba a Discord",
        wh_test_help = "Verifica la conexión con tu Webhook.",
        stat_title = "Panel de Estadísticas",
        stat_fmt = "Atrapados: %d  •  Vendidos: %d",
        stat_help = "Muestra el panel completo de estadísticas de la sesión.",
        dash_time = "🕒 Inicio y Duración",
        dash_caught = "🐾 Atrapados",
        dash_sold = "💰 Vendidos",
        dash_rare = "🌟 Raros y Mutados",
        dash_last = "🏆 Última Captura",
        dash_server = "🌐 Servidor y Ping",
        dash_reset = "Reiniciar",
        relock_title = "Actualizar Punto Auto Steal",
        relock_desc = "Guardar posición actual como punto de lanzamiento",
        relock_help = "Actualiza la posición fijada para Auto Steal.",
        unload_title = "Cerrar Script (Unload)",
        unload_desc = "Detener funciones y eliminar GUI",
        unload_help = "Cierra completamente ArchX de la pantalla.",
    },
    PT = {
        welcome_desc = "Obrigado por usar o ArchX. Entre no nosso Discord para novidades e atualizações.",
        copy_invite = "Copiar Convite",
        copied = "Copiado!",
        close = "Fechar",
        info_title = "Informação",
        understood = "Entendi",
        afk_overlay = "🌙 MODO ECONOMIA AFK ATIVO\nRenderização 3D desativada.\n\nToque na tela para voltar.",
        tab_farm = "Auto Farm",
        tab_shop = "Loja e Stand",
        tab_player = "Jogador",
        tab_afk = "AFK e Stats",
        tap_title = "Auto Tap x2",
        tap_desc = "Clica automaticamente no bônus x2 durante o treino",
        tap_help = "Ativa o bônus x2 automaticamente ao treinar.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Captura pets automaticamente e mostra os detalhes",
        steal_help = "Trava sua posição, arremessa automaticamente e notifica apenas pets capturados.",
        train_title = "Auto Train",
        train_desc_off = "Status: Inativo",
        train_desc_on = "Status: Treino ativo",
        train_help = "Envia Training_Start ao ligar e Training_Stop ao desligar.",
        equip_title = "Auto Equip Best",
        equip_desc = "Equipa os melhores pets periodicamente",
        equip_help = "Equipa automaticamente seus pets mais fortes.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Status: Inativo (Escolha filtros abaixo)",
        sell_desc_on = "Status: Vendendo pets selecionados",
        sell_help = "Vende pets da mochila conforme Tier, Mutação ou Animal.",
        sel_tier = "Selecionar Tier",
        sel_tier_help = "Escolha as raridades para vender automaticamente.",
        sel_mut = "Selecionar Mutações",
        sel_mut_help = "Escolha as mutações para vender automaticamente.",
        sel_ani = "Selecionar Animais",
        sel_ani_help = "Escolha os animais específicos para vender.",
        select_btn = "Escolher...",
        selected_fmt = "Escolhidos (%d)",
        food_title = "Auto Comprar Comida High",
        food_desc_idle = "Status: Pronto para comprar comida",
        food_desc_buy = "Status: Comprando Comida (%s)",
        food_desc_wait = "Status: Aguardando dinheiro",
        food_help = "Compra automaticamente a melhor comida disponível.",
        stand_title = "Auto Melhorar Stand",
        stand_desc_idle = "Status: Pronto para melhorar stand",
        stand_desc_ok = "Status: Stand melhorado",
        stand_desc_wait = "Status: Aguardando dinheiro",
        stand_help = "Melhora seu stand automaticamente quando houver dinheiro.",
        ws_title = "Velocidade (WalkSpeed)",
        ws_help = "Ajusta a velocidade de caminhada.",
        jp_title = "Pulo (JumpPower)",
        jp_help = "Ajusta a altura do pulo.",
        fly_title = "Voar (Fly)",
        fly_desc = "Permite voar livremente pelo mapa",
        fly_help = "Ativa o modo de voo controlado pela câmera.",
        flyspd_title = "Velocidade de Voo",
        flyspd_help = "Ajusta a velocidade ao voar.",
        noclip_title = "NoClip",
        noclip_desc = "Atravessa paredes e obstáculos",
        noclip_help = "Desativa colisões do personagem.",
        lang_title = "Idioma (Language)",
        lang_help = "Altera o idioma de toda a interface.",
        antiafk_title = "Anti-AFK Integrado",
        antiafk_desc = "Evita desconexão por inatividade",
        antiafk_help = "Mantém sua conta conectada enquanto estiver AFK.",
        black_title = "Tela Preta Economia AFK",
        black_desc = "Desativa gráficos 3D (toque para voltar)",
        black_help = "Desliga o 3D para economizar bateria.",
        notif_mode_title = "Modo Notificação e Discord",
        notif_mode_help = "Escolha entre mostrar todas as capturas ou apenas raros.",
        btn_full = "Completo (All)",
        btn_rare = "Apenas Raros",
        wh_url_title = "URL Webhook Discord",
        wh_url_help = "Cole o link do seu Webhook do Discord.",
        wh_url_ph = "Cole https://discord.com/api/webhooks/...",
        wh_en_title = "Ativar Webhook Discord",
        wh_en_desc_off = "Desativado",
        wh_en_desc_on = "Ativo: Enviando alertas para o Discord",
        wh_en_help = "Envia alertas de captura para o seu Discord.",
        wh_test_title = "Testar Webhook Discord",
        wh_test_desc = "Envia uma mensagem de teste ao Discord",
        wh_test_help = "Testa a conexão com o seu Webhook.",
        stat_title = "Painel de Estatísticas",
        stat_fmt = "Capturados: %d  •  Vendidos: %d",
        stat_help = "Mostra o painel completo de estatísticas da sessão.",
        dash_time = "🕒 Início e Duração",
        dash_caught = "🐾 Capturados",
        dash_sold = "💰 Vendidos",
        dash_rare = "🌟 Raros e Mutados",
        dash_last = "🏆 Última Captura",
        dash_server = "🌐 Servidor e Ping",
        dash_reset = "Zerar",
        relock_title = "Atualizar Ponto Auto Steal",
        relock_desc = "Salvar posição atual como ponto de arremesso",
        relock_help = "Atualiza a posição travada para o Auto Steal.",
        unload_title = "Descarregar Script (Unload)",
        unload_desc = "Parar funções e remover GUI",
        unload_help = "Fecha completamente o ArchX.",
    },
    RU = {
        welcome_desc = "Спасибо за использование ArchX. Присоединяйтесь к нашему Discord для обновлений.",
        copy_invite = "Копировать",
        copied = "Скопировано!",
        close = "Закрыть",
        info_title = "Информация",
        understood = "Понятно",
        afk_overlay = "🌙 РЕЖИМ ЭКОНОМИИ AFK АКТИВЕН\n3D-рендеринг отключен.\n\nНажмите на экран, чтобы вернуться.",
        tab_farm = "Авто Фарм",
        tab_shop = "Магазин",
        tab_player = "Игрок",
        tab_afk = "AFK и Стат.",
        tap_title = "Auto Tap x2",
        tap_desc = "Автоматически нажимает бонус x2 при тренировке",
        tap_help = "Автоматически активирует бонус x2 во время тренировки.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Автоматическая ловля питомцев с уведомлениями",
        steal_help = "Фиксирует позицию, бросает автоматически и уведомляет только о пойманных питомцах.",
        train_title = "Auto Train",
        train_desc_off = "Статус: Выключено",
        train_desc_on = "Статус: Тренировка активна",
        train_help = "Отправляет Training_Start при включении и Training_Stop при выключении.",
        equip_title = "Auto Equip Best",
        equip_desc = "Периодически экипирует лучших питомцев",
        equip_help = "Автоматически ставит питомцев с наибольшим доходом.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Статус: Выкл (Выберите фильтры ниже)",
        sell_desc_on = "Статус: Продажа по выбранным фильтрам",
        sell_help = "Автоматически продает питомцев из рюкзака по выбранным критериям.",
        sel_tier = "Выбрать Редкость (Tier)",
        sel_tier_help = "Выберите редкость питомцев для автопродажи.",
        sel_mut = "Выбрать Мутации",
        sel_mut_help = "Выберите мутации для автопродажи.",
        sel_ani = "Выбрать Животных",
        sel_ani_help = "Выберите конкретных животных для продажи.",
        select_btn = "Выбрать...",
        selected_fmt = "Выбрано (%d)",
        food_title = "Авто Покупка Еды High",
        food_desc_idle = "Статус: Готово к покупке еды",
        food_desc_buy = "Статус: Покупка еды (%s)",
        food_desc_wait = "Статус: Ожидание денег",
        food_help = "Автоматически покупает лучшую доступную еду.",
        stand_title = "Авто Улучшение Стенда",
        stand_desc_idle = "Статус: Готово к улучшению",
        stand_desc_ok = "Статус: Стенд улучшен",
        stand_desc_wait = "Статус: Ожидание денег",
        stand_help = "Автоматически улучшает стенд при наличии денег.",
        ws_title = "Скорость (WalkSpeed)",
        ws_help = "Изменяет скорость бега персонажа.",
        jp_title = "Прыжок (JumpPower)",
        jp_help = "Изменяет высоту прыжка персонажа.",
        fly_title = "Полёт (Fly)",
        fly_desc = "Позволяет свободно летать по карте",
        fly_help = "Включает свободный полёт по направлению камеры.",
        flyspd_title = "Скорость Полёта",
        flyspd_help = "Регулирует скорость в режиме полёта.",
        noclip_title = "NoClip",
        noclip_desc = "Прохождение сквозь стены",
        noclip_help = "Отключает столкновения персонажа.",
        lang_title = "Язык интерфейса (Language)",
        lang_help = "Выберите язык всего меню.",
        antiafk_title = "Встроенный Anti-AFK",
        antiafk_desc = "Защита от кика за бездействие",
        antiafk_help = "Предотвращает отключение от сервера при AFK.",
        black_title = "Чёрный экран (Экономия AFK)",
        black_desc = "Отключает 3D графику (нажмите для возврата)",
        black_help = "Отключает 3D рендер для экономии заряда.",
        notif_mode_title = "Режим уведомлений и Discord",
        notif_mode_help = "Выберите показ всех питомцев или только редких.",
        btn_full = "Все (All)",
        btn_rare = "Только Редкие",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "Вставьте ссылку Discord Webhook.",
        wh_url_ph = "Вставьте https://discord.com/api/webhooks/...",
        wh_en_title = "Включить Discord Webhook",
        wh_en_desc_off = "Выключено",
        wh_en_desc_on = "Включено: Отправка в Discord",
        wh_en_help = "Отправляет уведомления о поимке в Discord.",
        wh_test_title = "Тест Discord Webhook",
        wh_test_desc = "Отправить тестовое сообщение",
        wh_test_help = "Проверяет работу Discord Webhook.",
        stat_title = "Панель статистики сессии",
        stat_fmt = "Поймано: %d  •  Продано: %d",
        stat_help = "Полная панель статистики текущей сессии.",
        dash_time = "🕒 Старт и Время",
        dash_caught = "🐾 Поймано",
        dash_sold = "💰 Продано",
        dash_rare = "🌟 Редкие и Мутации",
        dash_last = "🏆 Последний улов",
        dash_server = "🌐 Сервер и Пинг",
        dash_reset = "Сброс",
        relock_title = "Обновить точку Auto Steal",
        relock_desc = "Сохранить текущую позицию для броска",
        relock_help = "Обновляет зафиксированную точку Auto Steal.",
        unload_title = "Выгрузить скрипт (Unload)",
        unload_desc = "Остановить все функции и удалить GUI",
        unload_help = "Полностью закрывает ArchX.",
    },
    TL = {
        welcome_desc = "Salamat sa paggamit ng ArchX. Sumali sa aming Discord para sa mga bagong update.",
        copy_invite = "Kopyahin Invite",
        copied = "Nakopya na!",
        close = "Isara",
        info_title = "Impormasyon",
        understood = "Naintindihan",
        afk_overlay = "🌙 AFK BATTERY SAVER AKTIBO\nNaka-off ang 3D graphics.\n\nPindutin ang screen upang bumalik.",
        tab_farm = "Auto Farm",
        tab_shop = "Tindahan",
        tab_player = "Player",
        tab_afk = "AFK at Stats",
        tap_title = "Auto Tap x2",
        tap_desc = "Awtomatikong pinipindot ang x2 bonus habang nag-eensayo",
        tap_help = "Awtomatikong pinipindot ang x2 bonus button.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Awtomatikong nanghuhuli ng pet at nagpapakita ng detalye",
        steal_help = "Nila-lock ang posisyon, naghahagis nang kusa, at nag-aabiso lamang sa nahuling pet.",
        train_title = "Auto Train",
        train_desc_off = "Status: Naka-off",
        train_desc_on = "Status: Nag-eensayo",
        train_help = "Nagpapadala ng Training_Start kapag naka-on at Training_Stop kapag naka-off.",
        equip_title = "Auto Equip Best",
        equip_desc = "Awtomatikong naglalagay ng pinakamalakas na pet",
        equip_help = "Pinipili at inilalagay ang pinakamataas na kita na pet.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Status: Naka-off (Pumili ng filter sa ibaba)",
        sell_desc_on = "Status: Nagbebenta ayon sa napili",
        sell_help = "Awtomatikong nagbebenta ng pet ayon sa Tier, Mutation, o Animal.",
        sel_tier = "Pumili ng Tier",
        sel_tier_help = "Piliin ang rarity ng pet na ibebenta.",
        sel_mut = "Pumili ng Mutation",
        sel_mut_help = "Piliin ang mutation ng pet na ibebenta.",
        sel_ani = "Pumili ng Hayop",
        sel_ani_help = "Piliin ang partikular na hayop na ibebenta.",
        select_btn = "Piliin...",
        selected_fmt = "Napili (%d)",
        food_title = "Auto Bili ng Pagkain High",
        food_desc_idle = "Status: Handa nang bumili ng pagkain",
        food_desc_buy = "Status: Bumibili ng Pagkain (%s)",
        food_desc_wait = "Status: Naghihintay ng sapat na pera",
        food_help = "Awtomatikong bumibili ng pinakamataas na pagkaing kaya ng pera.",
        stand_title = "Auto Upgrade Stand",
        stand_desc_idle = "Status: Handa nang mag-upgrade ng stand",
        stand_desc_ok = "Status: Na-upgrade na ang stand",
        stand_desc_wait = "Status: Naghihintay ng sapat na pera",
        stand_help = "Awtomatikong nag-a-upgrade ng stand kapag may sapat na pera.",
        ws_title = "WalkSpeed",
        ws_help = "Binabago ang bilis ng pagtakbo.",
        jp_title = "JumpPower",
        jp_help = "Binabago ang taas ng talon.",
        fly_title = "Lumipad (Fly)",
        fly_desc = "Malayang paglipad sa ere",
        fly_help = "Pinapayagan kang lumipad ayon sa direksyon ng camera.",
        flyspd_title = "Bilis ng Lipad",
        flyspd_help = "Binabago ang bilis habang lumilipad.",
        noclip_title = "NoClip",
        noclip_desc = "Tumagos sa mga pader at harang",
        noclip_help = "Tinatanggal ang banggaan upang makadaan sa pader.",
        lang_title = "Wika ng GUI (Language)",
        lang_help = "Piliin ang wika para sa buong menu.",
        antiafk_title = "Built-in Anti-AFK",
        antiafk_desc = "Pinipigilan ang pagka-disconnect kapag AFK",
        antiafk_help = "Pinapanatiling aktibo ang laro kahit nakatayo lamang.",
        black_title = "Black Screen Power Saver",
        black_desc = "Pinapatay ang 3D view (pindutin upang bumalik)",
        black_help = "Pinapatay ang 3D graphics upang makatipid sa baterya.",
        notif_mode_title = "Mode ng Abiso at Discord",
        notif_mode_help = "Piliin kung lahat ng huli o Rare Only lamang ang ipapakita.",
        btn_full = "Lahat (All)",
        btn_rare = "Rare Only",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "Ilagay ang iyong Discord Webhook link.",
        wh_url_ph = "Ilagay ang https://discord.com/api/webhooks/...",
        wh_en_title = "I-on ang Discord Webhook",
        wh_en_desc_off = "Naka-off",
        wh_en_desc_on = "Naka-on: Nagpapadala sa Discord",
        wh_en_help = "Nagpapadala ng ulat sa iyong Discord channel.",
        wh_test_title = "Subukan ang Discord Webhook",
        wh_test_desc = "Magpadala ng pansubok na mensahe",
        wh_test_help = "Sinusubukan kung gumagana ang iyong Webhook.",
        stat_title = "Dashboard ng Estadistika",
        stat_fmt = "Nahuli: %d Pet  •  Nabenta: %d",
        stat_help = "Kumpletong dashboard ng estadistika sa sesyon na ito.",
        dash_time = "🕒 Simula at Oras",
        dash_caught = "🐾 Nahuling Pet",
        dash_sold = "💰 Nabentang Pet",
        dash_rare = "🌟 Rare at Mutation",
        dash_last = "🏆 Huling Nahuli",
        dash_server = "🌐 Server at Ping",
        dash_reset = "I-reset",
        relock_title = "I-update ang Pwesto ng Auto Steal",
        relock_desc = "I-save ang kasalukuyang pwesto",
        relock_help = "Binabago ang nakatagong pwesto para sa Auto Steal.",
        unload_title = "Isara ang Script (Unload)",
        unload_desc = "Itigil lahat at tanggalin ang GUI",
        unload_help = "Tuluyang isinasara ang ArchX.",
    },
    VI = {
        welcome_desc = "Cảm ơn bạn đã sử dụng ArchX. Tham gia Discord để nhận bản cập nhật mới nhất.",
        copy_invite = "Sao chép Link",
        copied = "Đã sao chép!",
        close = "Đóng",
        info_title = "Thông tin tính năng",
        understood = "Đã hiểu",
        afk_overlay = "🌙 CHẾ ĐỘ TIẾT KIỆM PIN AFK\nĐã tắt hiển thị 3D.\n\nChạm vào màn hình để quay lại.",
        tab_farm = "Auto Farm",
        tab_shop = "Cửa hàng",
        tab_player = "Nhân vật",
        tab_afk = "AFK & Thống kê",
        tap_title = "Auto Tap x2",
        tap_desc = "Tự động nhấn thưởng x2 khi đang luyện tập",
        tap_help = "Tự động kích hoạt nút thưởng x2 trong lúc luyện tập.",
        steal_title = "Auto Steal Pet",
        steal_desc = "Tự động bắt thú và hiển thị chi tiết",
        steal_help = "Khóa vị trí đứng, tự động ném và chỉ thông báo thú vừa bắt được.",
        train_title = "Auto Train",
        train_desc_off = "Trạng thái: Tắt",
        train_desc_on = "Trạng thái: Đang luyện tập",
        train_help = "Gửi lệnh Training_Start khi bật và Training_Stop khi tắt.",
        equip_title = "Auto Equip Best",
        equip_desc = "Tự động trang bị thú mạnh nhất định kỳ",
        equip_help = "Tự động chọn thú có thu nhập cao nhất.",
        sell_title = "Auto Sell Selected",
        sell_desc_off = "Trạng thái: Tắt (Chọn bộ lọc bên dưới)",
        sell_desc_on = "Trạng thái: Đang bán theo bộ lọc",
        sell_help = "Tự động bán thú trong túi theo Tier, Đột biến hoặc Loài.",
        sel_tier = "Chọn Tier cần bán",
        sel_tier_help = "Chọn độ hiếm của thú muốn bán tự động.",
        sel_mut = "Chọn Đột biến cần bán",
        sel_mut_help = "Chọn loại đột biến muốn bán tự động.",
        sel_ani = "Chọn Loài thú cần bán",
        sel_ani_help = "Chọn tên thú cụ thể muốn bán tự động.",
        select_btn = "Chọn...",
        selected_fmt = "Đã chọn (%d)",
        food_title = "Tự động mua thức ăn High",
        food_desc_idle = "Trạng thái: Sẵn sàng mua thức ăn",
        food_desc_buy = "Trạng thái: Đang mua thức ăn (%s)",
        food_desc_wait = "Trạng thái: Đang chờ đủ tiền",
        food_help = "Tự động mua loại thức ăn cao cấp nhất phù hợp số dư.",
        stand_title = "Tự động nâng cấp Stand",
        stand_desc_idle = "Trạng thái: Sẵn sàng nâng cấp",
        stand_desc_ok = "Trạng thái: Đã nâng cấp Stand",
        stand_desc_wait = "Trạng thái: Đang chờ đủ tiền",
        stand_help = "Tự động nâng cấp Stand khi có đủ tiền.",
        ws_title = "Tốc độ chạy (WalkSpeed)",
        ws_help = "Điều chỉnh tốc độ di chuyển của nhân vật.",
        jp_title = "Độ cao nhảy (JumpPower)",
        jp_help = "Điều chỉnh độ cao khi nhảy.",
        fly_title = "Bay (Fly)",
        fly_desc = "Cho phép nhân vật bay tự do",
        fly_help = "Bật chế độ bay theo hướng camera.",
        flyspd_title = "Tốc độ bay",
        flyspd_help = "Điều chỉnh tốc độ khi bay.",
        noclip_title = "Xuyên tường (NoClip)",
        noclip_desc = "Đi xuyên qua tường và vật cản",
        noclip_help = "Tắt va chạm vật lý của nhân vật.",
        lang_title = "Ngôn ngữ (Language)",
        lang_help = "Chọn ngôn ngữ hiển thị cho toàn bộ menu.",
        antiafk_title = "Chống AFK tích hợp",
        antiafk_desc = "Ngăn bị ngắt kết nối khi treo máy",
        antiafk_help = "Giữ kết nối máy chủ khi bạn không thao tác.",
        black_title = "Màn hình đen tiết kiệm pin",
        black_desc = "Tắt đồ họa 3D khi AFK (chạm để quay lại)",
        black_help = "Tắt hiển thị 3D để giảm nhiệt và tiết kiệm pin.",
        notif_mode_title = "Chế độ thông báo & Discord",
        notif_mode_help = "Chọn hiển thị tất cả thú bắt được hoặc chỉ thú hiếm.",
        btn_full = "Tất cả (All)",
        btn_rare = "Chỉ thú hiếm",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "Dán liên kết Discord Webhook của bạn.",
        wh_url_ph = "Dán https://discord.com/api/webhooks/...",
        wh_en_title = "Bật Discord Webhook",
        wh_en_desc_off = "Đang tắt",
        wh_en_desc_on = "Đang bật: Gửi thông báo về Discord",
        wh_en_help = "Gửi thông báo bắt thú về kênh Discord.",
        wh_test_title = "Kiểm tra Discord Webhook",
        wh_test_desc = "Gửi tin nhắn thử nghiệm tới Discord",
        wh_test_help = "Kiểm tra kết nối Webhook Discord.",
        stat_title = "Bảng Thống Kê Phiên Chơi",
        stat_fmt = "Đã bắt: %d  •  Đã bán: %d",
        stat_help = "Bảng theo dõi chi tiết toàn bộ thống kê phiên chơi.",
        dash_time = "🕒 Bắt đầu & Thời lượng",
        dash_caught = "🐾 Đã bắt",
        dash_sold = "💰 Đã bán",
        dash_rare = "🌟 Thú Hiếm & Đột biến",
        dash_last = "🏆 Bắt gần nhất",
        dash_server = "🌐 Server & Ping",
        dash_reset = "Đặt lại",
        relock_title = "Cập nhật vị trí Auto Steal",
        relock_desc = "Lưu vị trí đứng hiện tại làm điểm ném",
        relock_help = "Cập nhật tọa độ đứng cố định cho Auto Steal.",
        unload_title = "Tắt Script Hoàn Toàn (Unload)",
        unload_desc = "Dừng tất cả và xóa GUI",
        unload_help = "Đóng hoàn toàn ArchX.",
    },
    AR = {
        welcome_desc = "شكراً لاستخدامك ArchX. انضم إلى خادم ديسكورد للحصول على آخر التحديثات.",
        copy_invite = "نسخ الرابط",
        copied = "تم النسخ!",
        close = "إغلاق",
        info_title = "معلومات الميزة",
        understood = "فهمت",
        afk_overlay = "🌙 وضع توفير الطاقة نشط\nتم إيقاف العرض ثلاثي الأبعاد.\n\nالمس الشاشة للعودة.",
        tab_farm = "تجميع تلقائي",
        tab_shop = "المتجر",
        tab_player = "اللاعب",
        tab_afk = "AFK والإحصاءات",
        tap_title = "ضغط تلقائي x2",
        tap_desc = "تفعيل مكافأة x2 تلقائياً أثناء التدريب",
        tap_help = "يضغط تلقائياً على زر مضاعفة التدريب x2.",
        steal_title = "صيد تلقائي للحيوانات",
        steal_desc = "يصطاد الحيوانات تلقائياً ويعرض تفاصيلها",
        steal_help = "يثبت موقعك ويرمي تلقائياً ويعرض إشعارات للحيوانات المصطادة فقط.",
        train_title = "تدريب تلقائي",
        train_desc_off = "الحالة: متوقف",
        train_desc_on = "الحالة: التدريب نشط",
        train_help = "يرسل أمر بدء التدريب عند التفعيل وإيقافه عند الإلغاء.",
        equip_title = "تجهيز الأفضل تلقائياً",
        equip_desc = "يجهز أقوى الحيوانات دخلاً بشكل دوري",
        equip_help = "يختار ويضع الحيوانات الأعلى دخلاً تلقائياً.",
        sell_title = "بيع المحدد تلقائياً",
        sell_desc_off = "الحالة: متوقف (اختر الفلاتر أدناه)",
        sell_desc_on = "الحالة: يبيع حسب الفلاتر المختارة",
        sell_help = "يبيع الحيوانات تلقائياً حسب الندرة أو الطفرة أو النوع.",
        sel_tier = "اختر الندرة للبيع",
        sel_tier_help = "حدد درجات الندرة التي سيتم بيعها تلقائياً.",
        sel_mut = "اختر الطفرات للبيع",
        sel_mut_help = "حدد الطفرات التي سيتم بيعها تلقائياً.",
        sel_ani = "اختر الحيوانات للبيع",
        sel_ani_help = "حدد أسماء الحيوانات للبيع التلقائي.",
        select_btn = "اختر...",
        selected_fmt = "المحدد (%d)",
        food_title = "شراء أفضل طعام تلقائياً",
        food_desc_idle = "الحالة: جاهز لشراء أفضل طعام",
        food_desc_buy = "الحالة: شراء طعام (%s)",
        food_desc_wait = "الحالة: بانتظار توفر المال",
        food_help = "يشتري أعلى مستوى طعام متاح حسب رصيدك.",
        stand_title = "ترقية المنصة تلقائياً",
        stand_desc_idle = "الحالة: جاهز للترقية",
        stand_desc_ok = "الحالة: تمت ترقية المنصة",
        stand_desc_wait = "الحالة: بانتظار توفر المال",
        stand_help = "يرقي مستوى منصتك تلقائياً عند توفر المال.",
        ws_title = "سرعة المشي",
        ws_help = "تعديل سرعة حركة الشخصية.",
        jp_title = "قوة القفز",
        jp_help = "تعديل ارتفاع القفز.",
        fly_title = "طيران (Fly)",
        fly_desc = "يتيح للشخصية الطيران بحرية",
        fly_help = "تفعيل الطيران الحر حسب اتجاه الكاميرا.",
        flyspd_title = "سرعة الطيران",
        flyspd_help = "تعديل السرعة أثناء الطيران.",
        noclip_title = "اختراق الجدران (NoClip)",
        noclip_desc = "المرور عبر الجدران والعوائق",
        noclip_help = "إلغاء التصادم للمرور عبر الجدران.",
        lang_title = "لغة القائمة (Language)",
        lang_help = "اختر لغة الواجهة المناسبة لك.",
        antiafk_title = "مضاد الخمول (Anti-AFK)",
        antiafk_desc = "يمنع الفصل التلقائي من السيرفر",
        antiafk_help = "يحافظ على نشاط الجلسة أثناء عدم اللعب.",
        black_title = "شاشة سوداء لتوفير الطاقة",
        black_desc = "إيقاف العرض ثلاثي الأبعاد (المس للعودة)",
        black_help = "يوقف الرسوميات ثلاثية الأبعاد لتوفير البطارية.",
        notif_mode_title = "وضع الإشعارات وديسكورد",
        notif_mode_help = "اختر عرض جميع الحيوانات أو النادرة فقط.",
        btn_full = "الكل (All)",
        btn_rare = "النادر فقط",
        wh_url_title = "رابط Discord Webhook",
        wh_url_help = "الصق رابط ويب هوك ديسكورد.",
        wh_url_ph = "الصق https://discord.com/api/webhooks/...",
        wh_en_title = "تفعيل إشعارات ديسكورد",
        wh_en_desc_off = "معطل",
        wh_en_desc_on = "مفعل: إرسال التنبيهات إلى ديسكورد",
        wh_en_help = "يرسل إشعارات الصيد إلى قناة ديسكورد.",
        wh_test_title = "اختبار ديسكورد Webhook",
        wh_test_desc = "إرسال رسالة تجريبية إلى ديسكورد",
        wh_test_help = "يتحقق من عمل رابط ديسكورد.",
        stat_title = "لوحة إحصاءات الجلسة",
        stat_fmt = "تم صيد: %d  •  تم بيع: %d",
        stat_help = "لوحة معلومات شاملة لإحصاءات الجلسة.",
        dash_time = "🕒 البدء والمدة",
        dash_caught = "🐾 المصطاد",
        dash_sold = "💰 المباع",
        dash_rare = "🌟 النادر والطفرات",
        dash_last = "🏆 آخر صيد",
        dash_server = "🌐 السيرفر والبينغ",
        dash_reset = "تصفير",
        relock_title = "تحديث موقع الصيد التلقائي",
        relock_desc = "حفظ موقعك الحالي كنقطة رمي",
        relock_help = "يحدث إحداثيات الوقوف للصيد التلقائي.",
        unload_title = "إغلاق السكربت نهائياً",
        unload_desc = "إيقاف جميع الميزات وإزالة الواجهة",
        unload_help = "يغلق ArchX بالكامل.",
    },
    KO = {
        welcome_desc = "ArchX를 사용해 주셔서 감사합니다. 최신 업데이트를 위해 Discord에 참여하세요.",
        copy_invite = "초대 복사",
        copied = "복사됨!",
        close = "닫기",
        info_title = "기능 안내",
        understood = "확인",
        afk_overlay = "🌙 AFK 절전 모드 활성화\n3D 렌더링이 꺼졌습니다.\n\n화면을 터치하면 돌아갑니다.",
        tab_farm = "자동 파밍",
        tab_shop = "상점 & 스탠드",
        tab_player = "플레이어",
        tab_afk = "AFK & 통계",
        tap_title = "자동 탭 x2",
        tap_desc = "훈련 중 x2 보너스 버튼을 자동으로 클릭",
        tap_help = "훈련 중 나타나는 x2 탭 보너스를 자동으로 누릅니다.",
        steal_title = "자동 펫 포획",
        steal_desc = "펫을 자동으로 잡고 획득 정보를 표시",
        steal_help = "위치를 고정하고 자동 던지기를 수행하며 포획된 펫 알림만 표시합니다.",
        train_title = "자동 훈련",
        train_desc_off = "상태: 꺼짐",
        train_desc_on = "상태: 훈련 진행 중",
        train_help = "켜면 Training_Start를 실행하고 끄면 Training_Stop을 실행합니다.",
        equip_title = "최고 펫 자동 장착",
        equip_desc = "수익이 가장 높은 펫을 주기적으로 장착",
        equip_help = "초당 수익이 가장 높은 펫을 자동으로 배치합니다.",
        sell_title = "선택 펫 자동 판매",
        sell_desc_off = "상태: 꺼짐 (아래 필터 선택)",
        sell_desc_on = "상태: 선택한 조건으로 판매 중",
        sell_help = "선택한 등급, 돌연변이, 동물과 일치하는 펫을 자동 판매합니다.",
        sel_tier = "판매할 등급 선택",
        sel_tier_help = "자동 판매할 펫 등급을 선택하세요.",
        sel_mut = "판매할 돌연변이 선택",
        sel_mut_help = "자동 판매할 돌연변이를 선택하세요.",
        sel_ani = "판매할 동물 선택",
        sel_ani_help = "자동 판매할 특정 동물을 선택하세요.",
        select_btn = "선택...",
        selected_fmt = "선택됨 (%d)",
        food_title = "최고 먹이 자동 구매",
        food_desc_idle = "상태: 최고 먹이 구매 준비 완료",
        food_desc_buy = "상태: 먹이 구매 중 (%s)",
        food_desc_wait = "상태: 돈이 모이기를 기다리는 중",
        food_help = "보유 금액으로 살 수 있는 가장 높은 등급의 먹이를 자동 구매합니다.",
        stand_title = "스탠드 자동 업그레이드",
        stand_desc_idle = "상태: 업그레이드 준비 완료",
        stand_desc_ok = "상태: 스탠드 업그레이드 완료",
        stand_desc_wait = "상태: 돈이 모이기를 기다리는 중",
        stand_help = "돈이 충분할 때 스탠드를 자동으로 업그레이드합니다.",
        ws_title = "이동 속도 (WalkSpeed)",
        ws_help = "캐릭터의 이동 속도를 조절합니다.",
        jp_title = "점프력 (JumpPower)",
        jp_help = "캐릭터의 점프 높이를 조절합니다.",
        fly_title = "비행 (Fly)",
        fly_desc = "공중에서 자유롭게 비행합니다",
        fly_help = "카메라 방향에 따라 자유롭게 비행합니다.",
        flyspd_title = "비행 속도",
        flyspd_help = "비행 중 이동 속도를 조절합니다.",
        noclip_title = "벽 통과 (NoClip)",
        noclip_desc = "벽과 장애물을 통과합니다",
        noclip_help = "캐릭터 충돌을 비활성화하여 벽을 통과합니다.",
        lang_title = "GUI 언어 (Language)",
        lang_help = "전체 메뉴의 언어를 선택하세요.",
        antiafk_title = "내장 Anti-AFK",
        antiafk_desc = "자리비움 연결 끊김 방지",
        antiafk_help = "장시간 방치 시 서버에서 튕기는 것을 방지합니다.",
        black_title = "블랙 스크린 절전 모드",
        black_desc = "AFK 중 3D 화면 끄기 (터치하여 복귀)",
        black_help = "배터리 절약 및 발열 방지를 위해 3D 렌더링을 끕니다.",
        notif_mode_title = "알림 및 Discord 모드",
        notif_mode_help = "모든 포획 알림 또는 희귀/돌연변이 전용 알림을 선택합니다.",
        btn_full = "전체 (All)",
        btn_rare = "희귀 전용",
        wh_url_title = "Discord 웹훅 URL",
        wh_url_help = "Discord 웹훅 주소를 입력하세요.",
        wh_url_ph = "https://discord.com/api/webhooks/... 붙여넣기",
        wh_en_title = "Discord 웹훅 활성화",
        wh_en_desc_off = "비활성화됨",
        wh_en_desc_on = "활성화됨: Discord로 알림 전송 중",
        wh_en_help = "선택한 모드에 따라 Discord 채널로 포획 알림을 보냅니다.",
        wh_test_title = "Discord 웹훅 테스트",
        wh_test_desc = "Discord로 테스트 메시지 전송",
        wh_test_help = "웹훅 연결이 정상인지 테스트합니다.",
        stat_title = "세션 통계 대시보드",
        stat_fmt = "포획: %d마리  •  판매: %d마리",
        stat_help = "이번 세션의 상세 통계 대시보드입니다.",
        dash_time = "🕒 시작 및 경과 시간",
        dash_caught = "🐾 총 포획 수",
        dash_sold = "💰 총 판매 수",
        dash_rare = "🌟 희귀 & 돌연변이",
        dash_last = "🏆 최근 포획",
        dash_server = "🌐 서버 & 핑",
        dash_reset = "초기화",
        relock_title = "자동 포획 위치 업데이트",
        relock_desc = "현재 서 있는 위치를 던지기 지점으로 저장",
        relock_help = "자동 포획에 사용되는 고정 위치를 갱신합니다.",
        unload_title = "스크립트 완전 종료 (Unload)",
        unload_desc = "모든 기능 중지 및 GUI 제거",
        unload_help = "ArchX를 완전히 종료합니다.",
    },
    JA = {
        welcome_desc = "ArchXをご利用いただきありがとうございます。最新情報はDiscordをご確認ください。",
        copy_invite = "招待をコピー",
        copied = "コピー完了！",
        close = "閉じる",
        info_title = "機能説明",
        understood = "了解",
        afk_overlay = "🌙 AFK省電力モード有効\n3D描画をオフにしています。\n\n画面をタップすると戻ります。",
        tab_farm = "オートファーム",
        tab_shop = "ショップ",
        tab_player = "プレイヤー",
        tab_afk = "AFK & 統計",
        tap_title = "オートタップ x2",
        tap_desc = "トレーニング中のx2ボーナスを自動クリック",
        tap_help = "トレーニング中に表示されるx2ボーナスボタンを自動で押します。",
        steal_title = "オートペット捕獲",
        steal_desc = "ペットを自動捕獲し詳細を通知",
        steal_help = "立ち位置を固定して自動投擲を行い、捕獲したペットのみ通知します。",
        train_title = "オートトレーニング",
        train_desc_off = "状態: オフ",
        train_desc_on = "状態: トレーニング中",
        train_help = "オンでTraining_Start、オフでTraining_Stopを実行します。",
        equip_title = "最強ペット自動装備",
        equip_desc = "収益が最も高いペットを定期的に装備",
        equip_help = "最も収益の高いペットを自動で配置します。",
        sell_title = "選択ペット自動売却",
        sell_desc_off = "状態: オフ（下で条件を選択）",
        sell_desc_on = "状態: 選択条件で自動売却中",
        sell_help = "選択したレア度・変異・動物に一致するペットを自動売却します。",
        sel_tier = "売却するレア度を選択",
        sel_tier_help = "自動売却するペットのレア度を選択します。",
        sel_mut = "売却する変異を選択",
        sel_mut_help = "自動売却する変異タイプを選択します。",
        sel_ani = "売却する動物を選択",
        sel_ani_help = "自動売却する特定の動物名を選択します。",
        select_btn = "選択...",
        selected_fmt = "選択中 (%d)",
        food_title = "最高フード自動購入",
        food_desc_idle = "状態: 購入待機中",
        food_desc_buy = "状態: フード購入中 (%s)",
        food_desc_wait = "状態: 所持金不足のため待機中",
        food_help = "所持金で購入可能な最高ランクのフードを自動購入します。",
        stand_title = "スタンド自動強化",
        stand_desc_idle = "状態: 強化待機中",
        stand_desc_ok = "状態: スタンド強化完了",
        stand_desc_wait = "状態: 所持金不足のため待機中",
        stand_help = "所持金が貯まると自動でスタンドを強化します。",
        ws_title = "移動速度 (WalkSpeed)",
        ws_help = "キャラクターの移動速度を調整します。",
        jp_title = "ジャンプ力 (JumpPower)",
        jp_help = "キャラクターのジャンプ力を調整します。",
        fly_title = "飛行 (Fly)",
        fly_desc = "空中を自由に飛行します",
        fly_help = "カメラの向きに合わせて自由に飛行できます。",
        flyspd_title = "飛行速度",
        flyspd_help = "飛行中の移動速度を調整します。",
        noclip_title = "壁抜け (NoClip)",
        noclip_desc = "壁や障害物をすり抜けます",
        noclip_help = "当たり判定を無効化して壁を通過します。",
        lang_title = "GUI言語 (Language)",
        lang_help = "メニュー全体の表示言語を切り替えます。",
        antiafk_title = "内蔵 Anti-AFK",
        antiafk_desc = "放置時の切断を防止します",
        antiafk_help = "長時間操作しなくてもサーバーから切断されなくなります。",
        black_title = "ブラックスクリーン省電力",
        black_desc = "AFK中に3D描画をオフ（タップで復帰）",
        black_help = "3D描画を停止してバッテリー消費と発熱を抑えます。",
        notif_mode_title = "通知 & Discordモード",
        notif_mode_help = "全ての捕獲を通知するか、レア/変異のみ通知するか選択します。",
        btn_full = "すべて (All)",
        btn_rare = "レアのみ",
        wh_url_title = "Discord Webhook URL",
        wh_url_help = "DiscordのWebhook URLを貼り付けてください。",
        wh_url_ph = "https://discord.com/api/webhooks/... を貼り付け",
        wh_en_title = "Discord Webhookを有効化",
        wh_en_desc_off = "オフ",
        wh_en_desc_on = "オン: Discordへ通知送信中",
        wh_en_help = "選択したモードに応じてDiscordへ捕獲通知を送ります。",
        wh_test_title = "Discord Webhookテスト",
        wh_test_desc = "Discordへテストメッセージを送信",
        wh_test_help = "Webhookの接続を確認します。",
        stat_title = "セッション統計ダッシュボード",
        stat_fmt = "捕獲: %d匹  •  売却: %d匹",
        stat_help = "現在のセッションの詳細統計ダッシュボードです。",
        dash_time = "🕒 開始と経過時間",
        dash_caught = "🐾 総捕獲数",
        dash_sold = "💰 総売却数",
        dash_rare = "🌟 レア & 変異",
        dash_last = "🏆 最新の捕獲",
        dash_server = "🌐 サーバー & Ping",
        dash_reset = "リセット",
        relock_title = "自動捕獲の立ち位置を更新",
        relock_desc = "現在の立ち位置を投擲ポイントとして保存",
        relock_help = "自動捕獲で使用する固定位置を更新します。",
        unload_title = "スクリプト完全終了 (Unload)",
        unload_desc = "全機能を停止してGUIを削除",
        unload_help = "ArchXを完全に終了します。",
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

local function NormalizeStr(str)
    return tostring(str or ""):lower():gsub("[%s_%-%[%]]", "")
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.BrandName
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetGuiParent

-- === PALET WARNA ARCHX ===
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
    Purple      = Color3.fromRGB(192, 132, 252),
    White       = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(246, 246, 250),
    TextMuted   = Color3.fromRGB(168, 160, 178),
    SwitchOff   = Color3.fromRGB(54, 46, 62),
}

local currentPingMs = 0
local currentFpsVal = 60

-- === TOP-CENTER FPS & MS MONITOR (WARNA PUTIH BERSIH & BISA DI-DRAG) ===
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
            currentFpsVal = fps
            frameCount = 0
            lastSample = now
            FpsLbl.Text = tostring(fps) .. " FPS"
            FpsLbl.TextColor3 = THEME.White

            local pingMs = 0
            pcall(function()
                pingMs = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
            end)
            currentPingMs = pingMs
            PingLbl.Text = tostring(pingMs) .. " ms"
            PingLbl.TextColor3 = THEME.White
        end
    end))
end

-- === DISCORD WEBHOOK SENDER ===
local function SendDiscordWebhook(titleText, detailText, hexColor)
    if not webhookUrl or not webhookUrl:find("discord.com/api/webhooks/") then return false end
    local httpReq = (syn and syn.request) or (http and http.request) or http_request or request
    if not httpReq then return false end

    local payload = {
        username = "ArchX Logger",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=150&height=150&format=png",
        embeds = {{
            title = titleText,
            description = detailText,
            color = hexColor or 16723555,
            fields = {
                { name = "Player", value = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", inline = true },
                { name = "Game", value = gameName, inline = true },
                { name = "Total", value = tostring(totalStealCount) .. " Pet", inline = true }
            },
            footer = { text = "ArchX • " .. os.date("%H:%M:%S") }
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
NotifyContainer.Name = "ArchXNotifications"
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
    Card.BackgroundTransparency = 0.08
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
end

-- === UPGRADED ANIMATED STEALING HUD PILL (DUAL RINGS + PULSE + SHIMMER) ===
local StealPill = Instance.new("Frame")
StealPill.Name = "StealingStatusPill"
StealPill.Size = UDim2.new(0, 232, 0, 40)
StealPill.Position = UDim2.new(0.5, -116, 0.85, 0)
StealPill.BackgroundColor3 = THEME.BgMain
StealPill.BackgroundTransparency = 0.08
StealPill.Active = true
StealPill.Visible = false
StealPill.ZIndex = 20
StealPill.Parent = ScreenGui
Instance.new("UICorner", StealPill).CornerRadius = UDim.new(1, 0)
MakeDraggable(StealPill, StealPill)

local PillScale = Instance.new("UIScale")
PillScale.Scale = 0.85
PillScale.Parent = StealPill

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = THEME.Accent
PillStroke.Thickness = 1.6
PillStroke.Transparency = 0.1
PillStroke.Parent = StealPill

local PillBorderGrad = Instance.new("UIGradient")
PillBorderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, THEME.Accent),
    ColorSequenceKeypoint.new(0.5, THEME.Blue),
    ColorSequenceKeypoint.new(1, THEME.Accent)
})
PillBorderGrad.Parent = PillStroke

-- Radar / Pulse Ripple di sisi kiri
local PulseRipple = Instance.new("Frame")
PulseRipple.Size = UDim2.new(0, 22, 0, 22)
PulseRipple.Position = UDim2.new(0, 12, 0.5, -11)
PulseRipple.BackgroundColor3 = THEME.Accent
PulseRipple.BackgroundTransparency = 0.5
PulseRipple.BorderSizePixel = 0
PulseRipple.ZIndex = 21
PulseRipple.Parent = StealPill
Instance.new("UICorner", PulseRipple).CornerRadius = UDim.new(1, 0)

-- Cincin Luar (Berputar Searah Jarum Jam)
local OuterSpinner = Instance.new("Frame")
OuterSpinner.Size = UDim2.new(0, 22, 0, 22)
OuterSpinner.Position = UDim2.new(0, 12, 0.5, -11)
OuterSpinner.BackgroundTransparency = 1
OuterSpinner.ZIndex = 22
OuterSpinner.Parent = StealPill
Instance.new("UICorner", OuterSpinner).CornerRadius = UDim.new(1, 0)

local OuterStroke = Instance.new("UIStroke")
OuterStroke.Color = THEME.Accent
OuterStroke.Thickness = 2.4
OuterStroke.Parent = OuterSpinner

local OuterGrad = Instance.new("UIGradient")
OuterGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.6, 0.25),
    NumberSequenceKeypoint.new(1, 1)
})
OuterGrad.Parent = OuterSpinner

-- Cincin Dalam (Berputar Berlawanan Arah)
local InnerSpinner = Instance.new("Frame")
InnerSpinner.Size = UDim2.new(0, 13, 0, 13)
InnerSpinner.Position = UDim2.new(0, 16.5, 0.5, -6.5)
InnerSpinner.BackgroundTransparency = 1
InnerSpinner.ZIndex = 23
InnerSpinner.Parent = StealPill
Instance.new("UICorner", InnerSpinner).CornerRadius = UDim.new(1, 0)

local InnerStroke = Instance.new("UIStroke")
InnerStroke.Color = THEME.Blue
InnerStroke.Thickness = 2
InnerStroke.Parent = InnerSpinner

local InnerGrad = Instance.new("UIGradient")
InnerGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.55, 0.3),
    NumberSequenceKeypoint.new(1, 1)
})
InnerGrad.Parent = InnerSpinner

-- Titik Inti Berdenyut
local CoreDot = Instance.new("Frame")
CoreDot.Size = UDim2.new(0, 5, 0, 5)
CoreDot.Position = UDim2.new(0, 20.5, 0.5, -2.5)
CoreDot.BackgroundColor3 = THEME.White
CoreDot.BorderSizePixel = 0
CoreDot.ZIndex = 24
CoreDot.Parent = StealPill
Instance.new("UICorner", CoreDot).CornerRadius = UDim.new(1, 0)

local StealPillLbl = Instance.new("TextLabel")
StealPillLbl.Size = UDim2.new(1, -108, 1, 0)
StealPillLbl.Position = UDim2.new(0, 42, 0, 0)
StealPillLbl.BackgroundTransparency = 1
StealPillLbl.TextColor3 = THEME.White
StealPillLbl.TextSize = 12
StealPillLbl.Font = Enum.Font.GothamBold
StealPillLbl.TextXAlignment = Enum.TextXAlignment.Left
StealPillLbl.Text = "Stealing..."
StealPillLbl.ZIndex = 22
StealPillLbl.Parent = StealPill

local StealCountBadge = Instance.new("TextLabel")
StealCountBadge.Size = UDim2.new(0, 54, 0, 22)
StealCountBadge.Position = UDim2.new(1, -62, 0.5, -11)
StealCountBadge.BackgroundColor3 = THEME.BgCard
StealCountBadge.TextColor3 = THEME.Green
StealCountBadge.TextSize = 11
StealCountBadge.Font = Enum.Font.GothamBold
StealCountBadge.Text = "0 Pet"
StealCountBadge.ZIndex = 22
StealCountBadge.Parent = StealPill
Instance.new("UICorner", StealCountBadge).CornerRadius = UDim.new(1, 0)

local CountBadgeStroke = Instance.new("UIStroke")
CountBadgeStroke.Color = THEME.Border
CountBadgeStroke.Thickness = 1
CountBadgeStroke.Parent = StealCountBadge

local stealPillShown = false
local dotPhase = 0
local lastDotStep = 0
local catchFlashTick = 0

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    if not StealPill.Visible then return end
    local now = tick()

    -- Rotasi ganda berlawanan arah
    OuterSpinner.Rotation = (OuterSpinner.Rotation + 420 * dt) % 360
    InnerSpinner.Rotation = (InnerSpinner.Rotation - 560 * dt) % 360
    PillBorderGrad.Rotation = (PillBorderGrad.Rotation + 140 * dt) % 360

    -- Animasi radar ripple meluas
    local rippleCycle = (now * 1.35) % 1
    local rSize = 18 + (16 * rippleCycle)
    PulseRipple.Size = UDim2.new(0, rSize, 0, rSize)
    PulseRipple.Position = UDim2.new(0, 23 - (rSize * 0.5), 0.5, -(rSize * 0.5))
    PulseRipple.BackgroundTransparency = 0.45 + (0.55 * rippleCycle)

    -- Animasi denyut titik inti
    local corePulse = 4 + math.abs(math.sin(now * 6)) * 2.5
    CoreDot.Size = UDim2.new(0, corePulse, 0, corePulse)
    CoreDot.Position = UDim2.new(0, 23 - (corePulse * 0.5), 0.5, -(corePulse * 0.5))

    -- Animasi titik teks "Stealing." -> "Stealing.." -> "Stealing..."
    if (now - lastDotStep) >= 0.35 then
        lastDotStep = now
        dotPhase = (dotPhase % 3) + 1
        StealPillLbl.Text = "Stealing" .. string.rep(".", dotPhase)
    end

    -- Kilatan hijau saat baru berhasil menangkap pet
    if (now - catchFlashTick) < 0.45 then
        PillStroke.Color = THEME.Green
        CountBadgeStroke.Color = THEME.Green
    else
        PillStroke.Color = THEME.Accent
        CountBadgeStroke.Color = THEME.Border
    end
end))

local function PulseStealCatchBadge()
    catchFlashTick = tick()
    StealCountBadge.Text = tostring(totalStealCount) .. " Pet"
    TweenService:Create(PillScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.07}):Play()
    task.delay(0.14, function()
        if stealPillShown then
            TweenService:Create(PillScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)
end

local function SetStealPillVisible(show)
    if not runningSteal then
        show = false
    end
    StealCountBadge.Text = tostring(totalStealCount) .. " Pet"
    if show and not stealPillShown then
        stealPillShown = true
        StealPill.Visible = true
        PillScale.Scale = 0.8
        TweenService:Create(PillScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    elseif not show and stealPillShown then
        stealPillShown = false
        local tw = TweenService:Create(PillScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.8})
        tw:Play()
        tw.Completed:Connect(function()
            if not stealPillShown then
                StealPill.Visible = false
            end
        end)
    end
end

-- === EKSTRAKSI DATA PET ===
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
    local primaryId = tool.Name
    local altId = nil
    local displayName = nil

    for k, v in pairs(tool:GetAttributes()) do
        local kl = tostring(k):lower()
        local vs = tostring(v)
        table.insert(texts, kl .. ":" .. vs)
        if kl == "uid" or kl == "uuid" or kl == "guid" or kl == "instanceid" or kl == "key" then
            primaryId = vs
        elseif kl == "id" or kl == "animalid" or kl == "petid" then
            altId = vs
        elseif kl == "displayname" or kl == "animalname" or kl == "petname" or kl == "animal" or kl == "species" then
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
            if (nl == "uid" or nl == "uuid" or nl == "guid" or nl == "key") and vs ~= "" then
                primaryId = vs
            elseif (nl == "id" or nl == "animalid" or nl == "petid") and vs ~= "" then
                altId = vs
            elseif (nl == "displayname" or nl == "animalname" or nl == "animal" or nl == "species") and vs ~= "" and not vs:match("^a%d+$") then
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
        sellId = primaryId,
        toolName = tool.Name,
        altId = altId,
        rawJoined = table.concat(texts, " | "),
        name = displayName,
        cps = cps or "$?/s",
        mutation = mutation,
        size = size,
        tier = tier
    }
end

local RefreshDashboardStats = nil

-- Notifikasi HANYA dipanggil oleh siklus Auto Steal
local function NotifyStolenPetOnly(petName, cpsStr, mutationStr, sizeStr)
    if not runningSteal then return end
    if (tick() - lastCatchTick) < 0.45 then return end

    lastCatchTick = tick()
    totalStealCount += 1
    PulseStealCatchBadge()

    local finalName = (petName and petName ~= "") and petName or "Pet"
    local finalCps = (cpsStr and cpsStr ~= "") and cpsStr or "$?/s"
    local finalMut = (mutationStr and mutationStr ~= "") and mutationStr or "Normal"
    local finalSize = (sizeStr and sizeStr ~= "") and sizeStr or "Normal"

    local detailFormatted = string.format("CPS: %s  •  Mutasi: %s  •  Ukuran: %s", finalCps, finalMut, finalSize)
    local combined = finalName .. " " .. detailFormatted
    local isRare = IsRareOrMutated(combined)

    if isRare then
        totalRareCount += 1
    end
    if finalMut ~= "Normal" then
        lastCaughtName = "[" .. finalMut .. "] " .. finalName
    else
        lastCaughtName = finalName
    end

    if RefreshDashboardStats then
        RefreshDashboardStats()
    end

    local col, rb, hexCol = ResolveCardStyleFromText(combined)

    if webhookEnabled and (not notifRareOnly or isRare) then
        task.spawn(function()
            SendDiscordWebhook("🎉 Stolen Pet: " .. finalName, detailFormatted, hexCol)
        end)
    end

    if not notifRareOnly or isRare then
        ShowNotif(finalName, detailFormatted, col, rb, 4.2)
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

-- === AUTO SELL BERDASARKAN TIER, MUTATION & ANIMAL (BACKPACK + EQUIPPED) ===
local statusSellLbl = nil

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

    -- Cek Tier
    for tierKey, isSelected in pairs(selectedSellTiers) do
        if isSelected and NormalizeStr(profile.tier) == NormalizeStr(tierKey) then
            return true
        end
    end

    -- Cek Mutation
    for mutKey, isSelected in pairs(selectedSellMutations) do
        if isSelected then
            if NormalizeStr(mutKey) == "none" and NormalizeStr(profile.mutation) == "normal" then
                return true
            elseif NormalizeStr(profile.mutation) == NormalizeStr(mutKey) then
                return true
            end
        end
    end

    -- Cek Animal (mendukung format "CrownIbex" maupun "Crown Ibex")
    local normName = NormalizeStr(profile.name)
    local normJoined = NormalizeStr(profile.rawJoined)
    for animalKey, isSelected in pairs(selectedSellAnimals) do
        if isSelected then
            local normKey = NormalizeStr(animalKey)
            if normKey ~= "" and (normName:find(normKey, 1, true) or normJoined:find(normKey, 1, true)) then
                return true
            end
        end
    end

    return false
end

local isSellingBusy = false
local function RunAutoSellCycle()
    if not runningSell or not PlotSellAnimalRemote or isSellingBusy then return end
    isSellingBusy = true

    pcall(function()
        local candidates = {}
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(candidates, item)
                end
            end
        end
        local char = LocalPlayer.Character
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(candidates, item)
                end
            end
        end

        local soldThisPass = 0
        for _, item in ipairs(candidates) do
            if not runningSell then break end
            if item and item.Parent then
                local profile = ExtractFullPetProfile(item)
                if ShouldSellPetProfile(profile) then
                    -- Coba ID utama terlebih dahulu
                    pcall(function()
                        PlotSellAnimalRemote:InvokeServer(profile.sellId)
                    end)
                    task.wait(0.08)

                    -- Fallback jika server memakai tool.Name atau altId
                    if item and item.Parent and profile.toolName ~= profile.sellId then
                        pcall(function()
                            PlotSellAnimalRemote:InvokeServer(profile.toolName)
                        end)
                        task.wait(0.08)
                    end
                    if item and item.Parent and profile.altId and profile.altId ~= profile.sellId then
                        pcall(function()
                            PlotSellAnimalRemote:InvokeServer(profile.altId)
                        end)
                        task.wait(0.08)
                    end

                    if not item or not item.Parent then
                        soldThisPass += 1
                        totalSoldCount += 1
                    end
                end
            end
        end

        if soldThisPass > 0 then
            if statusSellLbl then
                statusSellLbl.Text = T("sell_desc_on") .. " (" .. totalSoldCount .. ")"
            end
            if RefreshDashboardStats then
                RefreshDashboardStats()
            end
        end
    end)

    isSellingBusy = false
end

-- === DETEKSI PESAN INSUFFICIENT CASH / PENUH ===
local statusFoodLbl = nil
local statusStandLbl = nil

table.insert(connections, LocalPlayer.PlayerGui.DescendantAdded:Connect(function(desc)
    if not desc:IsA("TextLabel") or desc:IsDescendantOf(ScreenGui) then return end
    task.defer(function()
        if not desc or not desc.Parent then return end
        local txt = desc.Text
        if type(txt) ~= "string" or txt == "" then return end
        local lower = txt:lower()

        if lower:find("tidak cukup uang") or lower:find("uang tidak cukup") or lower:find("not enough") or lower:find("insufficient") then
            insufficientCashFlag = true
            lastInsufficientTick = tick()
            if runningFood then
                foodWaitingForCash = true
                if statusFoodLbl then statusFoodLbl.Text = T("food_desc_wait") end
            end
            if runningUpgrade then
                standWaitingForCash = true
                if statusStandLbl then statusStandLbl.Text = T("stand_desc_wait") end
            end
        elseif lower:find("penuh") or lower:find("full") then
            if runningSell then task.spawn(RunAutoSellCycle) end
            if runningSteal and (tick() - lastPlotFullTick) > 6 then
                lastPlotFullTick = tick()
                ShowNotif("Ransel / Kandang Penuh!", txt, Color3.fromRGB(255, 85, 85), false)
            end
        end
    end)
end))

-- === ANTI-AFK ===
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

-- === FLOATING LOGO BUTTON (LANGSUNG MUNCUL SEJAK WELCOME & ANTI-DEAD GUI) ===
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

-- === WELCOME POPUP (TANPA KOTAK HITAM DI BELAKANG) ===
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

-- Koneksi Klik/Geser Logo Floating (Buka/Tutup MainFrame tanpa Dead GUI)
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

-- Klik X hanya menyembunyikan MainFrame (tidak mematikan script / no dead GUI)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end)

local function UnloadArchXScript()
    runningTap, runningSteal, runningEquip, runningSell, runningTrain = false, false, false, false, false
    runningUpgrade, runningFood, flyEnabled, noclipEnabled = false, false, false, false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    ScreenGui:Destroy()
end

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

-- === BUILDER KOMPONEN UI ===
local function CreateHelpButton(parent, titleKeyOrText, helpKeyOrText)
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
        ShowFeatureInfo(T(titleKeyOrText), T(helpKeyOrText))
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
        if not state then
            desc.Text = T(descKey)
        end
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

-- === DASHBOARD STATISTIK SESI LENGKAP ===
local function CreateSessionDashboardCard(parentPage)
    local dashCard = Instance.new("Frame")
    dashCard.Name = "SessionDashboardCard"
    dashCard.Size = UDim2.new(1, -6, 0, 214)
    dashCard.BackgroundColor3 = THEME.BgCard
    dashCard.BackgroundTransparency = 0.12
    dashCard.ZIndex = 4
    dashCard.Parent = parentPage
    Instance.new("UICorner", dashCard).CornerRadius = UDim.new(0, 10)

    local dashStroke = Instance.new("UIStroke")
    dashStroke.Color = THEME.AccentSoft
    dashStroke.Thickness = 1.2
    dashStroke.Parent = dashCard

    local headerTitle = Instance.new("TextLabel")
    headerTitle.Size = UDim2.new(1, -110, 0, 22)
    headerTitle.Position = UDim2.new(0, 14, 0, 8)
    headerTitle.BackgroundTransparency = 1
    headerTitle.TextColor3 = THEME.TextPrimary
    headerTitle.TextSize = 13
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.Text = "📊 " .. T("stat_title")
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.TextTruncate = Enum.TextTruncate.AtEnd
    headerTitle.ZIndex = 5
    headerTitle.Parent = dashCard

    local qBtn = CreateHelpButton(dashCard, "stat_title", "stat_help")
    qBtn.Position = UDim2.new(1, -92, 0, 9)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0, 54, 0, 20)
    resetBtn.Position = UDim2.new(1, -66, 0, 9)
    resetBtn.BackgroundColor3 = THEME.BgSidebar
    resetBtn.TextColor3 = THEME.TextMuted
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 10
    resetBtn.Text = T("dash_reset")
    resetBtn.ZIndex = 5
    resetBtn.Parent = dashCard
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

    local resetStroke = Instance.new("UIStroke")
    resetStroke.Color = THEME.Border
    resetStroke.Thickness = 1
    resetStroke.Parent = resetBtn

    local gridFrame = Instance.new("Frame")
    gridFrame.Size = UDim2.new(1, -24, 1, -44)
    gridFrame.Position = UDim2.new(0, 12, 0, 36)
    gridFrame.BackgroundTransparency = 1
    gridFrame.ZIndex = 5
    gridFrame.Parent = dashCard

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.486, 0, 0, 50)
    gridLayout.CellPadding = UDim2.new(0.028, 0, 0, 7)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = gridFrame

    local function MakeMetricTile(order, labelKey, valueColor)
        local tile = Instance.new("Frame")
        tile.LayoutOrder = order
        tile.BackgroundColor3 = THEME.BgSidebar
        tile.BackgroundTransparency = 0.1
        tile.ZIndex = 6
        tile.Parent = gridFrame
        Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 8)

        local tStroke = Instance.new("UIStroke")
        tStroke.Color = THEME.Border
        tStroke.Thickness = 1
        tStroke.Parent = tile

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -14, 0, 16)
        lbl.Position = UDim2.new(0, 8, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = THEME.TextMuted
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = T(labelKey)
        lbl.ZIndex = 7
        lbl.Parent = tile

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(1, -14, 0, 20)
        val.Position = UDim2.new(0, 8, 0, 23)
        val.BackgroundTransparency = 1
        val.TextColor3 = valueColor
        val.Font = Enum.Font.GothamBold
        val.TextSize = 11.5
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextTruncate = Enum.TextTruncate.AtEnd
        val.Text = "-"
        val.ZIndex = 7
        val.Parent = tile

        RegisterLanguageUpdater(function()
            lbl.Text = T(labelKey)
        end)

        return val
    end

    local valTime   = MakeMetricTile(1, "dash_time",   THEME.Blue)
    local valCaught = MakeMetricTile(2, "dash_caught", THEME.Green)
    local valSold   = MakeMetricTile(3, "dash_sold",   THEME.Gold)
    local valRare   = MakeMetricTile(4, "dash_rare",   THEME.Purple)
    local valLast   = MakeMetricTile(5, "dash_last",   THEME.TextPrimary)
    local valServer = MakeMetricTile(6, "dash_server", THEME.Green)

    local function UpdateAllTiles()
        local elapsed = math.max(1, math.floor(tick() - sessionStartTick))
        local hrs = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        valTime.Text = string.format("%s (%02d:%02d:%02d)", sessionStartClock, hrs, mins, secs)

        local perMin = (totalStealCount / elapsed) * 60
        valCaught.Text = string.format("%d Pet (%.1f/m)", totalStealCount, perMin)

        valSold.Text = string.format("%d Pet", totalSoldCount)
        valRare.Text = string.format("%d Rare / Mutasi", totalRareCount)
        valLast.Text = lastCaughtName

        local pCount = #Players:GetPlayers()
        local pMax = Players.MaxPlayers
        valServer.Text = string.format("%d/%d • %d ms", pCount, pMax, currentPingMs)
        if currentPingMs <= 90 then
            valServer.TextColor3 = THEME.Green
        elseif currentPingMs <= 180 then
            valServer.TextColor3 = THEME.Gold
        else
            valServer.TextColor3 = THEME.Red
        end
    end

    RefreshDashboardStats = UpdateAllTiles

    resetBtn.MouseButton1Click:Connect(function()
        sessionStartTick = tick()
        sessionStartClock = os.date("%H:%M:%S")
        totalStealCount = 0
        totalSoldCount = 0
        totalRareCount = 0
        lastCaughtName = "-"
        UpdateAllTiles()
        ShowNotif("ArchX", "Statistik sesi berhasil di-reset.", THEME.Blue, false, 2.5)
    end)

    RegisterLanguageUpdater(function()
        headerTitle.Text = "📊 " .. T("stat_title")
        resetBtn.Text = T("dash_reset")
        UpdateAllTiles()
    end)

    task.spawn(function()
        while dashCard and dashCard.Parent do
            UpdateAllTiles()
            task.wait(1)
        end
    end)

    UpdateAllTiles()
end

-- === KARTU PILIHAN DUA TOMBOL TERPISAH ===
local function CreateTwoChoiceModeCard(parentPage, titleKey, helpKey, onSelectRareOnly)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 74)
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
    title.Text = T(titleKey)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -34, 0, 7)

    local btnFull = Instance.new("TextButton")
    btnFull.Size = UDim2.new(0.46, 0, 0, 30)
    btnFull.Position = UDim2.new(0, 14, 0, 34)
    btnFull.BackgroundColor3 = THEME.Accent
    btnFull.TextColor3 = Color3.new(1, 1, 1)
    btnFull.Font = Enum.Font.GothamBold
    btnFull.TextSize = 11.5
    btnFull.Text = T("btn_full")
    btnFull.ZIndex = 5
    btnFull.Parent = card
    Instance.new("UICorner", btnFull).CornerRadius = UDim.new(0, 7)

    local btnRare = Instance.new("TextButton")
    btnRare.Size = UDim2.new(0.46, 0, 0, 30)
    btnRare.Position = UDim2.new(1, -14, 0, 34)
    btnRare.AnchorPoint = Vector2.new(1, 0)
    btnRare.BackgroundColor3 = THEME.BgSidebar
    btnRare.TextColor3 = THEME.TextMuted
    btnRare.Font = Enum.Font.GothamBold
    btnRare.TextSize = 11.5
    btnRare.Text = T("btn_rare")
    btnRare.ZIndex = 5
    btnRare.Parent = card
    Instance.new("UICorner", btnRare).CornerRadius = UDim.new(0, 7)

    local function RefreshChoiceVisuals()
        if notifRareOnly then
            btnFull.BackgroundColor3 = THEME.BgSidebar
            btnFull.TextColor3 = THEME.TextMuted
            btnRare.BackgroundColor3 = THEME.Gold
            btnRare.TextColor3 = Color3.fromRGB(20, 16, 12)
        else
            btnFull.BackgroundColor3 = THEME.Accent
            btnFull.TextColor3 = Color3.new(1, 1, 1)
            btnRare.BackgroundColor3 = THEME.BgSidebar
            btnRare.TextColor3 = THEME.TextMuted
        end
    end

    btnFull.MouseButton1Click:Connect(function()
        onSelectRareOnly(false)
        RefreshChoiceVisuals()
    end)

    btnRare.MouseButton1Click:Connect(function()
        onSelectRareOnly(true)
        RefreshChoiceVisuals()
    end)

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey)
        btnFull.Text = T("btn_full")
        btnRare.Text = T("btn_rare")
    end)

    RefreshChoiceVisuals()
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

local function CreateMultiSelectCard(parentPage, titleKey, helpKey, itemsProvider, selectionMap)
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
    title.Size = UDim2.new(1, -135, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.Text = T(titleKey)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 6
    title.Parent = headerBar

    local qBtn = CreateHelpButton(headerBar, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -118, 0.5, -10)

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 82, 0, 28)
    selectBtn.Position = UDim2.new(1, -92, 0.5, -14)
    selectBtn.BackgroundColor3 = THEME.BgSidebar
    selectBtn.TextColor3 = THEME.TextPrimary
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.TextSize = 11.5
    selectBtn.Text = T("select_btn")
    selectBtn.ZIndex = 6
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
    listContainer.BorderSizePixel = 0
    listContainer.ScrollBarThickness = 3
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

    local function UpdateSelectCountText()
        local count = 0
        for _, v in pairs(selectionMap) do
            if v then count += 1 end
        end
        selectBtn.Text = count > 0 and string.format(T("selected_fmt"), count) or T("select_btn")
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
            rowBtn.BackgroundTransparency = selectionMap[itemName] and 0.1 or 0.65
            rowBtn.Font = Enum.Font.GothamSemibold
            rowBtn.TextSize = 11.5
            rowBtn.TextXAlignment = Enum.TextXAlignment.Left
            rowBtn.Text = (selectionMap[itemName] and "[ON]  " or "[OFF] ") .. itemName
            rowBtn.TextColor3 = selectionMap[itemName] and THEME.Green or THEME.TextMuted
            rowBtn.ZIndex = 6
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
                rowBtn.BackgroundTransparency = active and 0.1 or 0.65
                UpdateSelectCountText()
                if runningSell and active then
                    task.spawn(RunAutoSellCycle)
                end
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

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey)
        UpdateSelectCountText()
    end)

    return RebuildOptions
end

-- === KARTU PEMILIH BAHASA ===
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
    listContainer.Size = UDim2.new(1, -20, 0, 165)
    listContainer.Position = UDim2.new(0, 10, 0, 50)
    listContainer.BackgroundColor3 = THEME.BgInput
    listContainer.BorderSizePixel = 0
    listContainer.ScrollBarThickness = 3
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
            Size = expanded and UDim2.new(1, -6, 0, 224) or UDim2.new(1, -6, 0, 48)
        }):Play()
        stroke.Color = expanded and THEME.AccentSoft or THEME.Border
    end)

    RegisterLanguageUpdater(function()
        title.Text = T("lang_title")
        langBtn.Text = "🌐 " .. currentLang
    end)
end

local function CreateCardInput(parentPage, titleKey, helpKey, placeholderKey, onChanged)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 68)
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
    title.Size = UDim2.new(1, -54, 0, 18)
    title.Position = UDim2.new(0, 14, 0, 7)
    title.BackgroundTransparency = 1
    title.TextColor3 = THEME.TextPrimary
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Text = T(titleKey)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 5
    title.Parent = card

    local qBtn = CreateHelpButton(card, titleKey, helpKey)
    qBtn.Position = UDim2.new(1, -34, 0, 6)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -28, 0, 28)
    box.Position = UDim2.new(0, 14, 0, 30)
    box.BackgroundColor3 = THEME.BgInput
    box.TextColor3 = THEME.TextPrimary
    box.PlaceholderColor3 = THEME.TextMuted
    box.PlaceholderText = T(placeholderKey)
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextSize = 11
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.ZIndex = 5
    box.Parent = card
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = box

    box.FocusLost:Connect(function()
        onChanged(box.Text, box)
    end)

    RegisterLanguageUpdater(function()
        title.Text = T(titleKey)
        box.PlaceholderText = T(placeholderKey)
    end)

    return box
end

-- === POSISI LOCK UNTUK AUTO STEAL ===
table.insert(connections, RunService.Heartbeat:Connect(function()
    if runningSteal and savedPadCFrame then
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

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
    local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
    if hrp and runningSteal and savedPadCFrame then
        task.wait(0.1)
        hrp.CFrame = savedPadCFrame
    end
end))

-- === SMART AUTO BUY FOOD HIGH (DISCOVERY + CASH VERIFICATION) ===
local function ReadPlayerCashSnapshot()
    local total = 0
    local found = false
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local nl = v.Name:lower()
                if nl:find("cash") or nl:find("coin") or nl:find("money") or nl:find("dollar") or nl:find("uang") then
                    total += v.Value
                    found = true
                end
            end
        end
    end
    for k, v in pairs(LocalPlayer:GetAttributes()) do
        if type(v) == "number" then
            local kl = tostring(k):lower()
            if kl:find("cash") or kl:find("coin") or kl:find("money") or kl:find("uang") then
                total += v
                found = true
            end
        end
    end
    return found, total
end

local function DiscoverFoodCandidates()
    if cachedFoodCatalog and #cachedFoodCatalog > 0 then
        return cachedFoodCatalog
    end

    local list = {}
    local seen = {}
    local function AddCandidate(key, label, rank)
        local idStr = tostring(key)
        if not seen[idStr] then
            seen[idStr] = true
            table.insert(list, { key = key, label = label or ("#" .. idStr), rank = rank or 0 })
        end
    end

    -- 1. Pindai GUI Toko (PlayerGui) untuk mendeteksi item makanan yang tersedia
    pcall(function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("GuiObject") then
                local nl = gui.Name:lower()
                if nl:find("food") or nl:find("makanan") or nl:find("bait") or nl:find("shopitem") then
                    local num = gui.Name:match("(%d+)")
                    local itemIdAttr = gui:GetAttribute("FoodId") or gui:GetAttribute("ItemId") or gui:GetAttribute("Id") or gui:GetAttribute("Index")
                    local titleTxt = nil
                    for _, lbl in ipairs(gui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text ~= "" and not lbl.Text:find("%$") and #lbl.Text >= 3 and #lbl.Text <= 28 then
                            titleTxt = lbl.Text
                            break
                        end
                    end
                    if itemIdAttr ~= nil then
                        AddCandidate(itemIdAttr, titleTxt or tostring(itemIdAttr), tonumber(itemIdAttr) or (#list + 1))
                    elseif num then
                        local n = tonumber(num)
                        if n and n >= 1 and n <= 50 then
                            AddCandidate(n, titleTxt or ("Tier #" .. n), n)
                        end
                    end
                end
            end
        end
    end)

    -- 2. Pindai ReplicatedStorage jika ada folder/konfigurasi Food
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            local nl = obj.Name:lower()
            if (nl:find("food") or nl:find("makanan")) and (obj:IsA("Folder") or obj:IsA("Configuration")) then
                for _, child in ipairs(obj:GetChildren()) do
                    local num = child.Name:match("(%d+)")
                    local idxAttr = child:GetAttribute("Index") or child:GetAttribute("Id") or child:GetAttribute("Tier")
                    if idxAttr ~= nil then
                        AddCandidate(idxAttr, child.Name, tonumber(idxAttr) or (#list + 1))
                    elseif num then
                        local n = tonumber(num)
                        if n and n >= 1 and n <= 50 then
                            AddCandidate(n, child.Name, n)
                        end
                    else
                        AddCandidate(child.Name, child.Name, #list + 1)
                    end
                end
            end
        end
    end)

    -- 3. Tambahkan rentang indeks numerik standar 1..25 sebagai kandidat universal
    for i = 1, 25 do
        AddCandidate(i, "Tier #" .. tostring(i), i)
    end

    table.sort(list, function(a, b)
        return a.rank > b.rank
    end)

    cachedFoodCatalog = list
    return list
end

local function TryVerifiedFoodPurchase(candidate)
    if not ShopBuyRemote or not candidate then return false end
    insufficientCashFlag = false
    local hasCashBefore, cashBefore = ReadPlayerCashSnapshot()
    local toolsBefore = #SnapshotOwnedTools()

    local ok, res = pcall(function()
        return ShopBuyRemote:InvokeServer(candidate.key)
    end)
    task.wait(0.1)

    if not ok then return false end
    if insufficientCashFlag or (tick() - lastInsufficientTick) < 0.25 then
        return false
    end

    -- Jika server secara eksplisit menolak
    if res == false then
        return false
    end
    if type(res) == "table" and (res.success == false or res.ok == false) then
        return false
    end
    if type(res) == "string" then
        local rl = res:lower()
        if rl:find("fail") or rl:find("not enough") or rl:find("invalid") or rl:find("error") or rl:find("tidak") then
            return false
        end
        return true
    end

    -- Jika server mengembalikan konfirmasi positif eksplisit
    if res == true or (type(res) == "table" and (res.success == true or res.ok == true)) or (type(res) == "number" and res > 0) then
        return true
    end

    -- Jika server mengembalikan nil, verifikasi lewat perubahan cash atau item masuk
    local hasCashAfter, cashAfter = ReadPlayerCashSnapshot()
    if hasCashBefore and hasCashAfter and cashAfter < cashBefore then
        return true
    end
    local toolsAfter = #SnapshotOwnedTools()
    if toolsAfter > toolsBefore then
        return true
    end

    return false
end

local function RunAutoFoodCycle()
    if not runningFood or not ShopBuyRemote then return end
    local catalog = DiscoverFoodCandidates()
    if #catalog == 0 then return end

    -- Jika sudah menemukan makanan tertinggi yang berhasil dibeli, cek apakah bisa naik ke tier lebih tinggi
    if bestAffordableFoodKey then
        local currentPos = nil
        for idx, item in ipairs(catalog) do
            if item.key == bestAffordableFoodKey then
                currentPos = idx
                break
            end
        end

        if currentPos and currentPos > 1 then
            local higherItem = catalog[currentPos - 1]
            if TryVerifiedFoodPurchase(higherItem) then
                bestAffordableFoodKey = higherItem.key
                foodWaitingForCash = false
                if statusFoodLbl then statusFoodLbl.Text = string.format(T("food_desc_buy"), higherItem.label) end
                return
            end
        end

        if currentPos and TryVerifiedFoodPurchase(catalog[currentPos]) then
            foodWaitingForCash = false
            if statusFoodLbl then statusFoodLbl.Text = string.format(T("food_desc_buy"), catalog[currentPos].label) end
            return
        end
    end

    -- Pencarian cepat dari tier tertinggi ke terendah untuk menemukan food terbaik yang terjangkau
    for _, item in ipairs(catalog) do
        if not runningFood then return end
        if TryVerifiedFoodPurchase(item) then
            bestAffordableFoodKey = item.key
            foodWaitingForCash = false
            if statusFoodLbl then statusFoodLbl.Text = string.format(T("food_desc_buy"), item.label) end
            return
        end
    end

    foodWaitingForCash = true
    if statusFoodLbl then statusFoodLbl.Text = T("food_desc_wait") end
end

local function RunAutoStandCycle()
    if not runningUpgrade or not StandUpgradeRemote then return end

    insufficientCashFlag = false
    local ok, res = pcall(function() return StandUpgradeRemote:InvokeServer() end)
    task.wait(0.18)

    if insufficientCashFlag or (tick() - lastInsufficientTick) < 0.35 or (ok and res == false) then
        standWaitingForCash = true
        if statusStandLbl then statusStandLbl.Text = T("stand_desc_wait") end
    else
        standWaitingForCash = false
        if statusStandLbl then statusStandLbl.Text = T("stand_desc_ok") end
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
local FarmPage   = CreateTab("farm", "tab_farm", "⚡")
local ShopPage   = CreateTab("shop", "tab_shop", "🛒")
local PlayerPage = CreateTab("player", "tab_player", "🏃")
local AfkPage    = CreateTab("afk", "tab_afk", "🛡️")

-- ==========================================
-- TAB 1: AUTO FARM & AUTO SELL FILTER
-- ==========================================
CreateCardToggle(
    FarmPage,
    "tap_title",
    "tap_desc",
    "tap_help",
    false,
    function(state) runningTap = state end
)

CreateCardToggle(
    FarmPage,
    "steal_title",
    "steal_desc",
    "steal_help",
    false,
    function(state)
        runningSteal = state
        if state then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then savedPadCFrame = hrp.CFrame end
            totalStealCount = 0
            SetStealPillVisible(true)
        else
            SetStealPillVisible(false)
        end
    end
)

CreateCardToggle(
    FarmPage,
    "train_title",
    "train_desc_off",
    "train_help",
    false,
    function(state, desc)
        runningTrain = state
        if state then
            if runningSteal then
                savedPadCFrame = nil
            end
            if TrainingStartRemote then
                task.spawn(function() pcall(function() TrainingStartRemote:InvokeServer() end) end)
            end
            desc.Text = T("train_desc_on")
        else
            if TrainingStopRemote then
                task.spawn(function() pcall(function() TrainingStopRemote:InvokeServer() end) end)
            end
            desc.Text = T("train_desc_off")
        end
    end
)

CreateCardToggle(
    FarmPage,
    "equip_title",
    "equip_desc",
    "equip_help",
    false,
    function(state)
        runningEquip = state
        if state and PlotEquipBestRemote then
            task.spawn(function() pcall(function() PlotEquipBestRemote:InvokeServer() end) end)
        end
    end
)

statusSellLbl = CreateCardToggle(
    FarmPage,
    "sell_title",
    "sell_desc_off",
    "sell_help",
    false,
    function(state, desc)
        runningSell = state
        if state then
            desc.Text = T("sell_desc_on")
            task.spawn(RunAutoSellCycle)
        else
            desc.Text = T("sell_desc_off")
        end
    end
)

CreateMultiSelectCard(
    FarmPage,
    "sel_tier",
    "sel_tier_help",
    function() return TIER_LIST end,
    selectedSellTiers
)

CreateMultiSelectCard(
    FarmPage,
    "sel_mut",
    "sel_mut_help",
    function() return MUTATION_LIST end,
    selectedSellMutations
)

CreateMultiSelectCard(
    FarmPage,
    "sel_ani",
    "sel_ani_help",
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
statusFoodLbl = CreateCardToggle(
    ShopPage,
    "food_title",
    "food_desc_idle",
    "food_help",
    false,
    function(state, desc)
        runningFood = state
        if state then
            foodWaitingForCash = false
            bestAffordableFoodKey = nil
            cachedFoodCatalog = nil
            desc.Text = T("food_desc_idle")
            task.spawn(RunAutoFoodCycle)
        else
            desc.Text = T("food_desc_idle")
        end
    end
)

statusStandLbl = CreateCardToggle(
    ShopPage,
    "stand_title",
    "stand_desc_idle",
    "stand_help",
    false,
    function(state, desc)
        runningUpgrade = state
        if state then
            standWaitingForCash = false
            desc.Text = T("stand_desc_idle")
            task.spawn(RunAutoStandCycle)
        else
            desc.Text = T("stand_desc_idle")
        end
    end
)

-- ==========================================
-- TAB 3: PLAYER (WALKSPEED, JUMPPOWER, FLY, NOCLIP)
-- ==========================================
CreateCardSlider(
    PlayerPage,
    "ws_title",
    "ws_help",
    16, 250, 20,
    function(val)
        walkSpeedValue = val
        walkSpeedEnabled = true
    end
)

CreateCardSlider(
    PlayerPage,
    "jp_title",
    "jp_help",
    50, 300, 50,
    function(val)
        jumpPowerValue = val
        jumpPowerEnabled = true
    end
)

CreateCardToggle(
    PlayerPage,
    "fly_title",
    "fly_desc",
    "fly_help",
    false,
    function(state)
        flyEnabled = state
        if state then
            StartFly()
        else
            StopFly()
        end
    end
)

CreateCardSlider(
    PlayerPage,
    "flyspd_title",
    "flyspd_help",
    10, 250, 50,
    function(val)
        flySpeedValue = val
    end
)

CreateCardToggle(
    PlayerPage,
    "noclip_title",
    "noclip_desc",
    "noclip_help",
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
-- TAB 4: AFK & STATS
-- ==========================================
CreateSessionDashboardCard(AfkPage)

CreateLanguageSelectorCard(AfkPage)

CreateCardToggle(
    AfkPage,
    "antiafk_title",
    "antiafk_desc",
    "antiafk_help",
    true,
    function(state) runningAntiAfk = state end
)

local _, setBlackScreenToggle = CreateCardToggle(
    AfkPage,
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

CreateTwoChoiceModeCard(
    AfkPage,
    "notif_mode_title",
    "notif_mode_help",
    function(isRareOnlyMode)
        notifRareOnly = isRareOnlyMode
    end
)

CreateCardInput(
    AfkPage,
    "wh_url_title",
    "wh_url_help",
    "wh_url_ph",
    function(txt) webhookUrl = txt:gsub("%s+", "") end
)

CreateCardToggle(
    AfkPage,
    "wh_en_title",
    "wh_en_desc_off",
    "wh_en_help",
    false,
    function(state, desc)
        if state and not webhookUrl:find("discord.com/api/webhooks/") then
            desc.Text = T("wh_url_ph")
            return
        end
        webhookEnabled = state
        desc.Text = state and T("wh_en_desc_on") or T("wh_en_desc_off")
    end
)

CreateCardAction(
    AfkPage,
    "wh_test_title",
    "wh_test_desc",
    "wh_test_help",
    "📨",
    function(desc)
        if not webhookUrl:find("discord.com/api/webhooks/") then
            desc.Text = T("wh_url_ph")
            return
        end
        task.spawn(function()
            local sent = SendDiscordWebhook("✅ ArchX Connected!", "Webhook connected.", 4316290)
            desc.Text = sent and "OK!" or "Error!"
        end)
    end
)

CreateCardAction(
    AfkPage,
    "relock_title",
    "relock_desc",
    "relock_help",
    "📍",
    function(desc)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            savedPadCFrame = hrp.CFrame
            desc.Text = "OK!"
            task.delay(1.5, function()
                if desc then desc.Text = T("relock_desc") end
            end)
        end
    end
)

CreateCardAction(
    AfkPage,
    "unload_title",
    "unload_desc",
    "unload_help",
    "⏻",
    function()
        UnloadArchXScript()
    end
)

-- Inisialisasi teks awal sesuai bahasa default
ApplyLanguage(currentLang)

-- Listener otomatis saat pet baru masuk ke Backpack untuk langsung dijual jika Auto Sell aktif
local function BindBackpackAutoSell(bp)
    if not bp then return end
    table.insert(connections, bp.ChildAdded:Connect(function(child)
        if runningSell and child:IsA("Tool") then
            task.wait(0.15)
            task.spawn(RunAutoSellCycle)
        end
    end))
end
BindBackpackAutoSell(LocalPlayer:FindFirstChild("Backpack"))
table.insert(connections, LocalPlayer.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then
        BindBackpackAutoSell(child)
    end
end))

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

-- Loop 2: Auto Steal Pet
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
                        NotifyStolenPetOnly(prof.name, prof.cps, prof.mutation, prof.size)
                        if runningSell then task.spawn(RunAutoSellCycle) end
                        task.wait(0.35)
                    elseif type(resolveRes) == "string" and #resolveRes > 1 then
                        local cpsVal, mutVal, sizeVal = ParseMetadataFromStrings({resolveRes})
                        NotifyStolenPetOnly(resolveRes, cpsVal, mutVal, sizeVal)
                        if runningSell then task.spawn(RunAutoSellCycle) end
                        task.wait(0.35)
                    elseif type(completeRes) == "string" and #completeRes > 1 then
                        local cpsVal, mutVal, sizeVal = ParseMetadataFromStrings({completeRes})
                        NotifyStolenPetOnly(completeRes, cpsVal, mutVal, sizeVal)
                        if runningSell then task.spawn(RunAutoSellCycle) end
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

-- Loop 5: Auto Sell Selected (Setiap 1.5 detik)
task.spawn(function()
    while ScreenGui.Parent do
        if runningSell then
            RunAutoSellCycle()
            task.wait(1.5)
        else
            task.wait(0.4)
        end
    end
end)

-- Loop 6: Auto Buy Food High
task.spawn(function()
    while ScreenGui.Parent do
        if runningFood then
            RunAutoFoodCycle()
            task.wait(foodWaitingForCash and 2 or 0.45)
        else
            task.wait(0.25)
        end
    end
end)

-- Loop 7: Auto Upgrade Stand
task.spawn(function()
    while ScreenGui.Parent do
        if runningUpgrade then
            RunAutoStandCycle()
            task.wait(standWaitingForCash and 2.5 or 0.65)
        else
            task.wait(0.25)
        end
    end
end)
