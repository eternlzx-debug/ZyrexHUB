--[[
    RYUZENX — THROW A SEED HUB
    MODUL REMOTE INSPECTOR & DOKUMENTASI OBSERVASI CLIENT (v1.4.0)
    Developer : RyuzenX
    Game      : Throw a Seed (Place/Game ID: 129081220403721)
    Platform  : Android & PC (Roblox Studio / Delta Mobile)
    Tema      : Dark Purple + Black (RYUzenX Visual Identity)

    PRINSIP KEAMANAN & ARSITEKTUR:
    1. READ-ONLY & NON-INTRUSIVE: Modul ini TIDAK PERNAH memanggil FireServer()
       atau InvokeServer() secara otomatis maupun manual.
    2. DATA GROUNDING: Seluruh entri berasal dari log observasi SimpleSpy dan
       struktur Dex Explorer milik developer. Tidak ada parameter fiktif.
    3. STATUS LABELING:
       - VERIFIED : Objek terkonfirmasi ada di client saat runtime & strukturnya jelas.
       - OBSERVED : Remote & contoh parameter pernah tertangkap di SimpleSpy,
                    namun parameter lengkap/validasi server belum sepenuhnya diuji.
       - UNKNOWN  : Nama objek terlihat di Dex Explorer, tetapi fungsi, parameter,
                    atau izin aksesnya belum diketahui/belum pernah tertangkap.
]]

--------------------------------------------------------------------------------
-- BAGIAN 1: DATA LAYER — REGISTRY DOKUMENTASI REMOTE & OBJEK DEX EXPLORER
--------------------------------------------------------------------------------
local RemoteDocs = {
    -- =========================================================================
    -- KATEGORI: THROW & COLLECTION (SimpleSpy Capture #1)
    -- =========================================================================
    {
        Id = "Aim",
        Name = "Aim",
        ExpectedClass = "RemoteEvent",
        ExpectedPath = "ReplicatedStorage.Remotes.Aim",
        Category = "Throw",
        Method = "FireServer",
        Status = "OBSERVED",
        RiskLevel = "Low (Gameplay Action)",
        Parameters = {
            {
                Signature = "Aim:FireServer()",
                SampleArgs = "Tanpa argumen (0 args)",
                Notes = "Dipanggil pertama kali sebelum Throw:InvokeServer(...) dimulai.",
            },
        },
        Description = "Memulai fase membidik (aiming) sebelum lemparan seed dieksekusi.",
        DeveloperNotes = "Tertangkap di SimpleSpy tanpa parameter. Perlu verifikasi apakah memerlukan state karakter tertentu di server.",
    },
    {
        Id = "Throw",
        Name = "Throw",
        ExpectedClass = "RemoteFunction",
        ExpectedPath = "ReplicatedStorage.Remotes.Throw",
        Category = "Throw",
        Method = "InvokeServer",
        Status = "OBSERVED",
        RiskLevel = "Medium (Gameplay Action)",
        Parameters = {
            {
                Signature = "Throw:InvokeServer(power: number)",
                SampleArgs = "0.9998674666487104",
                Notes = "Angka float mendekati 1.0 (Full Power / zona hijau sempurna pada power bar).",
            },
        },
        Description = "Mengeksekusi lemparan seed dengan nilai kekuatan (power ratio) tertentu.",
        DeveloperNotes = "Nilai 0.9998674666487104 adalah contoh tangkapan SimpleSpy saat bar penuh. Rentang valid diduga [0.0 .. 1.0].",
    },
    {
        Id = "Collect",
        Name = "Collect",
        ExpectedClass = "RemoteEvent",
        ExpectedPath = "ReplicatedStorage.Remotes.Collect",
        Category = "Throw",
        Method = "FireServer",
        Status = "OBSERVED",
        RiskLevel = "Low (Gameplay Action)",
        Parameters = {
            {
                Signature = "Collect:FireServer()",
                SampleArgs = "Tanpa argumen (0 args)",
                Notes = "Dipanggil setelah proses lemparan selesai untuk mengklaim/menempatkan hasil.",
            },
        },
        Description = "Menyelesaikan siklus lemparan dan memproses hasil seed yang dilempar.",
        DeveloperNotes = "Tertangkap setelah Throw:InvokeServer() selesai merespons.",
    },

    -- =========================================================================
    -- KATEGORI: SHOP & TELEMETRY (SimpleSpy Capture #2)
    -- =========================================================================
    {
        Id = "Track",
        Name = "Track",
        ExpectedClass = "RemoteEvent",
        ExpectedPath = "ReplicatedStorage.Remotes.Track",
        Category = "UI / Telemetry",
        Method = "FireServer",
        Status = "OBSERVED",
        RiskLevel = "Low (UI Tracking)",
        Parameters = {
            {
                Signature = 'Track:FireServer("MenuBoxShop")',
                SampleArgs = '"MenuBoxShop"',
                Notes = "Tercatat saat membuka menu toko seed/box.",
            },
            {
                Signature = 'Track:FireServer("MenuSell")',
                SampleArgs = '"MenuSell"',
                Notes = "Tercatat saat membuka menu penjualan tanaman.",
            },
        },
        Description = "Mengirim event pelacakan/pembukaan menu UI ke server.",
        DeveloperNotes = "Dua string teramati: 'MenuBoxShop' dan 'MenuSell'. Kemungkinan ada string menu lain yang belum tertangkap.",
    },
    {
        Id = "Request",
        Name = "Request",
        ExpectedClass = "RemoteFunction",
        ExpectedPath = "ReplicatedStorage.Remotes.Request",
        Category = "Multi-Action Dispatcher",
        Method = "InvokeServer",
        Status = "OBSERVED",
        RiskLevel = "Medium-High (Economy & State)",
        Parameters = {
            {
                Signature = 'Request:InvokeServer("BuySeed", { i = number })',
                SampleArgs = '"BuySeed", { i = 3 }',
                Notes = "Membeli seed berdasarkan indeks urutan (contoh tangkapan: i = 3). Indeks dinamis mengikuti katalog Balance.Seeds.",
            },
            {
                Signature = 'Request:InvokeServer("XPBoost", { id = number })',
                SampleArgs = '"XPBoost", { id = 1 }',
                Notes = "Mengaktifkan/meminta XP Boost dengan ID tertentu (contoh tangkapan: id = 1).",
            },
            {
                Signature = 'Request:InvokeServer("StopTrain", {})',
                SampleArgs = '"StopTrain", {}',
                Notes = "Menghentikan sesi training aktif dengan payload tabel kosong {}.",
            },
            {
                Signature = 'Request:InvokeServer("SellMany", { ids = {string...} })',
                SampleArgs = '"SellMany", { ids = {"P1", "P3", "P2"} }',
                Notes = "Menjual beberapa tanaman sekaligus berdasarkan daftar PlantId (contoh: P1, P2, P3).",
            },
        },
        Description = "RemoteFunction utama berbasis pola (ActionName, PayloadTable) untuk transaksi, training, dan penjualan.",
        DeveloperNotes = "Action lain (mis. mulai training, upgrade, atau boost selain XPBoost) masih UNKNOWN dan perlu rekaman SimpleSpy tambahan.",
    },

    -- =========================================================================
    -- KATEGORI: OBJEK DEX EXPLORER BELUM TERVERIFIKASI (UNKNOWN / RESTRICTED)
    -- =========================================================================
    {
        Id = "Notify",
        Name = "Notify",
        ExpectedClass = "RemoteEvent (Perkiraan)",
        ExpectedPath = "ReplicatedStorage.Remotes.Notify",
        Category = "Server -> Client Notification",
        Method = "OnClientEvent (Perkiraan)",
        Status = "UNKNOWN",
        RiskLevel = "Unknown",
        Parameters = {
            {
                Signature = "Belum ada tangkapan SimpleSpy",
                SampleArgs = "UNKNOWN",
                Notes = "Kemungkinan digunakan server untuk mengirim pesan notifikasi ke client.",
            },
        },
        Description = "Objek terdeteksi di Dex Explorer. Belum pernah tertangkap pada panggilan client -> server.",
        DeveloperNotes = "JANGAN dipanggil ke server. Pantau melalui OnClientEvent jika diperlukan.",
    },
    {
        Id = "Here",
        Name = "Here",
        ExpectedClass = "RemoteEvent / RemoteFunction (Perkiraan)",
        ExpectedPath = "ReplicatedStorage.Remotes.Here",
        Category = "Unknown",
        Method = "UNKNOWN",
        Status = "UNKNOWN",
        RiskLevel = "Unknown",
        Parameters = {
            {
                Signature = "Belum ada tangkapan SimpleSpy",
                SampleArgs = "UNKNOWN",
                Notes = "Fungsi dan struktur argumen belum diketahui.",
            },
        },
        Description = "Nama objek ditemukan di Dex Explorer tanpa rekaman trafik SimpleSpy.",
        DeveloperNotes = "Tandai UNKNOWN. Lakukan observasi pasif saat berinteraksi dengan objek/zona di map.",
    },
    {
        Id = "GiveMoney",
        Name = "GiveMoney",
        ExpectedClass = "RemoteEvent / RemoteFunction (Perkiraan)",
        ExpectedPath = "ReplicatedStorage.Remotes.GiveMoney",
        Category = "Restricted / Server-Guarded",
        Method = "UNKNOWN",
        Status = "UNKNOWN",
        RiskLevel = "High (Restricted / Admin-Guarded)",
        Parameters = {
            {
                Signature = "Tidak diobservasi / Dilarang dipanggil",
                SampleArgs = "UNKNOWN",
                Notes = "Kemungkinan remote khusus admin/developer atau server-side reward.",
            },
        },
        Description = "Terlihat di Dex Explorer. Tidak ada bukti izin penggunaan untuk client reguler.",
        DeveloperNotes = "DILARANG memanggil remote ini. Hanya didokumentasikan sebagai inventaris objek Dex.",
    },
    {
        Id = "AdminGiveSecret",
        Name = "AdminGiveSecret",
        ExpectedClass = "RemoteEvent / RemoteFunction (Perkiraan)",
        ExpectedPath = "ReplicatedStorage.Remotes.AdminGiveSecret",
        Category = "Restricted / Admin-Only",
        Method = "UNKNOWN",
        Status = "UNKNOWN",
        RiskLevel = "High (Admin-Only / Restricted)",
        Parameters = {
            {
                Signature = "Tidak diobservasi / Dilarang dipanggil",
                SampleArgs = "UNKNOWN",
                Notes = "Remote administratif yang dilindungi pengecekan UserId/Rank di server.",
            },
        },
        Description = "Terlihat di Dex Explorer. Merupakan endpoint khusus admin/developer.",
        DeveloperNotes = "DILARANG memanggil atau memalsukan parameter. Hanya dicatat sebagai dokumentasi struktur.",
    },

    -- =========================================================================
    -- KATEGORI: ASSET CONTAINER TERVERIFIKASI
    -- =========================================================================
    {
        Id = "SeedModels",
        Name = "SeedModels",
        ExpectedClass = "Folder",
        ExpectedPath = "ReplicatedStorage.SeedModels (atau Workspace.SeedModels)",
        Category = "Asset Container",
        Method = "N/A (Folder Model)",
        Status = "VERIFIED",
        RiskLevel = "Safe (Read-Only Asset)",
        Parameters = {
            {
                Signature = "14 Model Seed Terdokumentasi",
                SampleArgs = "CandySeed, CloudSeed, CosmicSeed, CrystalSeed, DiamondSeed, GoldenSeed, LavaSeed, LuckySeed, MagicSeed, PearlSeed, PlainSeed, RainbowSeed, StarSeed, SunnySeed",
                Notes = "Diverifikasi melalui Dex Explorer (contoh: CloudSeed memiliki PrimaryPart=Root, BaseSize=2.599).",
            },
        },
        Description = "Folder penyimpanan model 3D seed yang digunakan oleh modul Seed Manager.",
        DeveloperNotes = "Sudah terintegrasi dengan modul SeedManager pada Phase 3.",
    },
}

--------------------------------------------------------------------------------
-- BAGIAN 2: REMOTE INSPECTOR ENGINE (READ-ONLY RUNTIME SCANNER)
--------------------------------------------------------------------------------
local RemoteInspector = {
    Entries = RemoteDocs,
    SelectedId = "Request",
    SearchQuery = "",
    StatusFilter = "ALL", -- "ALL" | "VERIFIED" | "OBSERVED" | "UNKNOWN"
    SessionNotes = {},    -- Catatan tambahan per RemoteId selama sesi berjalan
    RemotesFolder = nil,
}

-- Mencari folder Remotes atau objek target secara aman tanpa membuat instance baru
function RemoteInspector:LocateObject(entry)
    local rs = game:GetService("ReplicatedStorage")
    local remotesFolder = rs:FindFirstChild("Remotes")
    if remotesFolder then
        self.RemotesFolder = remotesFolder
        local inRemotes = remotesFolder:FindFirstChild(entry.Name)
        if inRemotes then
            return inRemotes
        end
    end

    local directRS = rs:FindFirstChild(entry.Name)
    if directRS then
        return directRS
    end

    local deepRS = rs:FindFirstChild(entry.Name, true)
    if deepRS then
        return deepRS
    end

    if entry.Name == "SeedModels" then
        local wsModels = workspace:FindFirstChild("SeedModels", true)
        if wsModels then
            return wsModels
        end
    end

    return nil
end

-- Memeriksa keberadaan objek aktual di client dan menggabungkannya dengan dokumentasi
function RemoteInspector:InspectEntry(entry)
    if not entry then
        return nil
    end

    local liveObj = self:LocateObject(entry)
    local liveExists = liveObj ~= nil
    local actualClass = liveExists and liveObj.ClassName or (entry.ExpectedClass .. " [Belum terdeteksi]")
    local actualPath = entry.ExpectedPath

    if liveExists then
        local okPath, fullPath = pcall(function()
            return liveObj:GetFullName()
        end)
        if okPath and fullPath then
            actualPath = fullPath
        end
    end

    -- Jika status awal UNKNOWN tetapi objek ditemukan langsung di client sebagai Folder/Model aman,
    -- status dokumentasi tetap mempertahankan tingkat kepercayaan observasi remote.
    local effectiveStatus = entry.Status
    if liveExists and entry.Status == "VERIFIED" then
        effectiveStatus = "VERIFIED"
    end

    return {
        Id = entry.Id,
        Name = entry.Name,
        LiveExists = liveExists,
        ActualClass = actualClass,
        ActualPath = actualPath,
        Category = entry.Category,
        Method = entry.Method,
        Status = effectiveStatus,
        RiskLevel = entry.RiskLevel,
        Parameters = entry.Parameters or {},
        Description = entry.Description,
        DeveloperNotes = entry.DeveloperNotes,
        CustomNotes = self.SessionNotes[entry.Id] or {},
    }
end

function RemoteInspector:GetSelectedEntry()
    for _, item in ipairs(self.Entries) do
        if item.Id == self.SelectedId then
            return item
        end
    end
    return self.Entries[1]
end

function RemoteInspector:AddSessionNote(remoteId, noteText)
    noteText = tostring(noteText or ""):match("^%s*(.-)%s*$")
    if noteText == "" then
        return false
    end
    self.SessionNotes[remoteId] = self.SessionNotes[remoteId] or {}
    local stamped = string.format("[%s] %s", os.date("%H:%M:%S"), noteText)
    table.insert(self.SessionNotes[remoteId], 1, stamped)
    return true
end

function RemoteInspector:GetSummaryCounts()
    local counts = {
        Total = #self.Entries,
        VERIFIED = 0,
        OBSERVED = 0,
        UNKNOWN = 0,
        LiveFound = 0,
    }
    for _, entry in ipairs(self.Entries) do
        counts[entry.Status] = (counts[entry.Status] or 0) + 1
        if self:LocateObject(entry) ~= nil then
            counts.LiveFound += 1
        end
    end
    return counts
end

--------------------------------------------------------------------------------
-- BAGIAN 3: UI TAB BUILDER — INTEGRASI KE RYUzenX HUB (Theme, UI, Janitor)
--------------------------------------------------------------------------------
--[[
    Cara Integrasi ke RyuzenX_ThrowASeed_Hub_v1.3.0.lua:
    1. Tambahkan definisi tab ke dalam CONFIG.Tabs:
       { Id = "RemoteInspector", Title = "Remotes", Phase = "DOCS" },
    2. Tempelkan RemoteDocs & RemoteInspector sebelum bagian TAB BUILDERS.
    3. Daftarkan tab di bagian MOUNT & POLLING:
       mount("RemoteInspector", buildRemoteInspector)
]]

local function buildRemoteInspector(content, refreshActive)
    -- Referensi komponen dari Hub (Theme, UI, Util, Janitor)
    local Create = Util.Create
    local o = counter()

    local function statusColor(status)
        if status == "VERIFIED" then
            return Theme.Green
        elseif status == "OBSERVED" then
            return Theme.Gold
        else
            return Theme.Danger
        end
    end

    -- 1. Header & Ringkasan Status Observasi
    local summaryCard = UI.Section(content, "Remote Inspector & Dokumentasi", o())
    local so = counter()
    UI.Label(
        summaryCard,
        "Mode Read-Only: Menampilkan hasil observasi SimpleSpy & Dex Explorer tanpa memanggil remote ke server.",
        { Color = Theme.TextDim, Size = 12, Order = so() }
    )

    local sumRows = {
        total = statRow(summaryCard, "Total Objek Terdokumentasi", so),
        live = statRow(summaryCard, "Terdeteksi Aktif di Client", so),
        breakdown = statRow(summaryCard, "Verified / Observed / Unknown", so),
    }

    -- 2. Pencarian & Filter Label Status
    local filterCard = UI.Section(content, "Filter & Daftar Objek", o())
    local fo = counter()

    UI.TextBox(filterCard, "Cari nama remote, parameter, atau kategori...", function(query)
        RemoteInspector.SearchQuery = query
        if refreshActive then
            refreshActive()
        end
    end, janitor, fo())

    -- Baris Tombol Filter Status (ALL / VERIFIED / OBSERVED / UNKNOWN)
    local filterRow = Create("Frame", {
        Name = "FilterRow",
        LayoutOrder = fo(),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent = filterCard,
    })
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = filterRow,
    })

    local filterButtons = {}
    local filterModes = { "ALL", "VERIFIED", "OBSERVED", "UNKNOWN" }
    for idx, mode in ipairs(filterModes) do
        local btn = Create("TextButton", {
            Name = "Filter_" .. mode,
            LayoutOrder = idx,
            Size = UDim2.new(0.25, -4, 1, 0),
            BackgroundColor3 = Theme.SurfaceLight,
            AutoButtonColor = false,
            Font = Theme.FontBold,
            Text = mode,
            TextSize = 11,
            TextColor3 = Theme.TextDim,
            Parent = filterRow,
        })
        Util.Corner(btn, 6)
        filterButtons[mode] = btn

        janitor:Add(btn.Activated:Connect(function()
            RemoteInspector.StatusFilter = mode
            if refreshActive then
                refreshActive()
            end
        end))
    end

    local listSummary = UI.Label(filterCard, "Memuat daftar objek...", {
        Color = Theme.TextDim,
        Size = 12,
        Order = fo(),
    })
    local entryListContainer = listFrame(filterCard, fo(), 4)

    -- 3. Detail Objek & Lokasi di Client
    local detailCard = UI.Section(content, "Detail Objek & Status Verifikasi", o())
    local doOrder = counter()
    local detailRows = {
        name = statRow(detailCard, "Nama Objek", doOrder),
        status = statRow(detailCard, "Label Verifikasi", doOrder),
        class = statRow(detailCard, "ClassName", doOrder),
        live = statRow(detailCard, "Keberadaan di Client", doOrder),
        path = statRow(detailCard, "Lokasi / Path", doOrder),
        category = statRow(detailCard, "Kategori", doOrder),
        method = statRow(detailCard, "Metode Panggilan", doOrder),
        risk = statRow(detailCard, "Tingkat Risiko", doOrder),
    }
    local descLabel = UI.Label(detailCard, "-", {
        Color = Theme.Text,
        Size = 12,
        Order = doOrder(),
    })

    -- 4. Parameter yang Pernah Diamati (SimpleSpy)
    local paramCard = UI.Section(content, "Parameter Teramati (SimpleSpy)", o())
    local paramContainer = listFrame(paramCard, 1, 6)

    -- 5. Catatan Observasi Developer & Tambah Catatan Sesi
    local noteCard = UI.Section(content, "Catatan Observasi & Keamanan", o())
    local noOrder = counter()
    local devNoteLabel = UI.Label(noteCard, "-", {
        Color = Theme.TextDim,
        Size = 12,
        Order = noOrder(),
    })

    local noteInputBox = UI.TextBox(noteCard, "Tambah catatan observasi sesi ini...", nil, janitor, noOrder())
    buttonRow(noteCard, noOrder(), "Simpan Catatan ke Objek Ini", function()
        local current = RemoteInspector:GetSelectedEntry()
        if current and RemoteInspector:AddSessionNote(current.Id, noteInputBox.Text) then
            noteInputBox.Text = ""
            if refreshActive then
                refreshActive()
            end
        end
    end)

    local sessionNoteLabel = UI.Label(noteCard, "Belum ada catatan sesi tambahan.", {
        Color = Theme.AccentLight,
        Size = 11,
        Order = noOrder(),
    })

    local lastListSig = ""
    local lastDetailSig = ""

    local function clearGuiChildren(container)
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end

    return function()
        -- Update ringkasan atas
        local counts = RemoteInspector:GetSummaryCounts()
        sumRows.total(tostring(counts.Total) .. " objek")
        sumRows.live(
            string.format("%d / %d ditemukan", counts.LiveFound, counts.Total),
            counts.LiveFound > 0 and Theme.Green or Theme.TextDim
        )
        sumRows.breakdown(
            string.format("%dV · %dO · %dU", counts.VERIFIED, counts.OBSERVED, counts.UNKNOWN),
            Theme.AccentLight
        )

        -- Update tampilan tombol filter
        for mode, btn in pairs(filterButtons) do
            local active = (RemoteInspector.StatusFilter == mode)
            btn.BackgroundColor3 = active and Theme.AccentDark or Theme.SurfaceLight
            btn.TextColor3 = active and Theme.Text or Theme.TextDim
        end

        -- Filter daftar entri
        local q = string.lower((RemoteInspector.SearchQuery or ""):match("^%s*(.-)%s*$"))
        local filtered = {}
        for _, entry in ipairs(RemoteInspector.Entries) do
            local matchStatus = (RemoteInspector.StatusFilter == "ALL") or (entry.Status == RemoteInspector.StatusFilter)
            local matchQuery = (q == "")
                or string.find(string.lower(entry.Name), q, 1, true)
                or string.find(string.lower(entry.Category), q, 1, true)
                or string.find(string.lower(entry.Description), q, 1, true)
            if matchStatus and matchQuery then
                table.insert(filtered, entry)
            end
        end

        listSummary.Text = string.format("Menampilkan %d dari %d objek dokumentasi", #filtered, #RemoteInspector.Entries)

        local sigParts = { RemoteInspector.SelectedId, RemoteInspector.StatusFilter, q }
        for _, e in ipairs(filtered) do
            table.insert(sigParts, e.Id .. ":" .. e.Status)
        end
        local listSig = table.concat(sigParts, "|")

        if listSig ~= lastListSig then
            lastListSig = listSig
            clearGuiChildren(entryListContainer)

            if #filtered == 0 then
                UI.Label(entryListContainer, "Tidak ada objek yang sesuai dengan filter.", {
                    Color = Theme.TextDim,
                    Size = 12,
                })
            else
                for idx, entry in ipairs(filtered) do
                    local isSelected = (entry.Id == RemoteInspector.SelectedId)
                    local rowBtn = Create("TextButton", {
                        Name = "RemoteRow_" .. entry.Id,
                        LayoutOrder = idx,
                        Size = UDim2.new(1, 0, 0, 32),
                        BackgroundColor3 = isSelected and Theme.AccentDark or Theme.SurfaceLight,
                        BackgroundTransparency = isSelected and 0.15 or 0.55,
                        AutoButtonColor = false,
                        Text = "",
                        Parent = entryListContainer,
                    })
                    Util.Corner(rowBtn, 7)
                    if isSelected then
                        Util.Stroke(rowBtn, Theme.AccentLight, 1, 0.25)
                    end

                    Create("TextLabel", {
                        Position = UDim2.fromOffset(10, 0),
                        Size = UDim2.new(0.62, -10, 1, 0),
                        BackgroundTransparency = 1,
                        Font = isSelected and Theme.FontBold or Theme.FontMedium,
                        Text = string.format("%s  (%s)", entry.Name, entry.Category),
                        TextSize = 12,
                        TextColor3 = Theme.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = rowBtn,
                    })

                    Create("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0),
                        Position = UDim2.new(1, -10, 0, 0),
                        Size = UDim2.new(0.36, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Font = Theme.FontBold,
                        Text = entry.Status,
                        TextSize = 11,
                        TextColor3 = statusColor(entry.Status),
                        TextXAlignment = Enum.TextXAlignment.Right,
                        Parent = rowBtn,
                    })

                    janitor:Add(rowBtn.Activated:Connect(function()
                        RemoteInspector.SelectedId = entry.Id
                        if refreshActive then
                            refreshActive()
                        end
                    end))
                end
            end
        end

        -- Render detail objek terpilih
        local selected = RemoteInspector:GetSelectedEntry()
        local info = RemoteInspector:InspectEntry(selected)
        if info then
            detailRows.name(info.Name, Theme.AccentLight)
            detailRows.status(info.Status, statusColor(info.Status))
            detailRows.class(info.ActualClass, Theme.Text)
            detailRows.live(
                info.LiveExists and "Tersedia di Client" or "Tidak ditemukan saat ini",
                info.LiveExists and Theme.Green or Theme.TextDim
            )
            detailRows.path(info.ActualPath, Theme.TextDim)
            detailRows.category(info.Category, Theme.Text)
            detailRows.method(info.Method, Theme.AccentLight)
            detailRows.risk(info.RiskLevel, info.Status == "UNKNOWN" and Theme.Danger or Theme.Gold)
            descLabel.Text = "Deskripsi: " .. info.Description
            devNoteLabel.Text = "Catatan Observasi: " .. info.DeveloperNotes

            if #info.CustomNotes > 0 then
                sessionNoteLabel.Text = "Catatan Sesi Tambahan:\n" .. table.concat(info.CustomNotes, "\n")
            else
                sessionNoteLabel.Text = "Belum ada catatan sesi tambahan untuk objek ini."
            end

            local detailSig = info.Id .. ":" .. tostring(info.LiveExists) .. ":" .. tostring(#info.Parameters)
            if detailSig ~= lastDetailSig then
                lastDetailSig = detailSig
                clearGuiChildren(paramContainer)

                for pIdx, param in ipairs(info.Parameters) do
                    local box = Create("Frame", {
                        Name = "ParamBox_" .. tostring(pIdx),
                        LayoutOrder = pIdx,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Theme.SurfaceLight,
                        BackgroundTransparency = 0.45,
                        BorderSizePixel = 0,
                        Parent = paramContainer,
                    })
                    Util.Corner(box, 8)
                    Util.Padding(box, 8, 10, 8, 10)
                    Create("UIListLayout", {
                        Padding = UDim.new(0, 3),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Parent = box,
                    })

                    UI.Label(box, param.Signature, {
                        Bold = true,
                        Color = Theme.AccentLight,
                        Size = 12,
                        Order = 1,
                    })
                    UI.Label(box, "Contoh Teramati: " .. param.SampleArgs, {
                        Color = Theme.Gold,
                        Size = 11,
                        Order = 2,
                    })
                    UI.Label(box, param.Notes, {
                        Color = Theme.TextDim,
                        Size = 11,
                        Order = 3,
                    })
                end
            end
        end
    end
end

Hub.RemoteInspector = RemoteInspector
return RemoteInspector
