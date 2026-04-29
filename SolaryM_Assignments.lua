-- SolaryM_Assignments.lua — Callouts personnalisés par joueur

local AceComm       = LibStub and LibStub("AceComm-3.0", true)
local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local COMM_PREFIX   = "SolaryM"

local currentBoss    = nil
local currentEncID   = nil
local bwHandle       = {}
local activeTimers   = {}
local activeAlerts   = {}

-- ============================================================
-- CONTAINER D'ALERTES ASSIGNMENTS (séparé du container Alert)
-- ============================================================
local assignContainer = nil
local ASSIGN_W = 360
local ASSIGN_H = 48
local ASSIGN_GAP = 6
local ASSIGN_FONT_SIZE = 17

local function GetAssignFontSize()
    return (SolaryMDB and SolaryMDB.assign and SolaryMDB.assign.fontSize) or ASSIGN_FONT_SIZE
end

local function GetAssignWidth()
    return (SolaryMDB and SolaryMDB.assign and SolaryMDB.assign.width) or ASSIGN_W
end

local function SaveAssignPos(frame)
    if not SolaryMDB or not SolaryMDB.frames then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    if not point then return end
    SolaryMDB.frames["assign"] = { point=point, rp=relPoint, x=math.floor(x), y=math.floor(y) }
end

local function LoadAssignPos(frame)
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["assign"]
    frame:ClearAllPoints()
    if s and s.x then
        frame:SetPoint(s.point or "TOP", UIParent, s.rp or "TOP", s.x, s.y)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -170)
    end
end

local function CreateAssignContainer()
    if assignContainer then return end
    ASSIGN_W = GetAssignWidth()
    assignContainer = CreateFrame("Frame", "SolaryMAssignments", UIParent)
    assignContainer:SetSize(ASSIGN_W, 1)
    assignContainer:SetFrameStrata("HIGH")
    assignContainer:SetMovable(true)
    assignContainer:EnableMouse(false)
    LoadAssignPos(assignContainer)
end

local function LayoutAssigns()
    if not assignContainer then return end
    local y = 0
    for _, a in ipairs(activeAlerts) do
        if a.frame and a.frame:IsShown() then
            a.frame:SetPoint("TOPLEFT", assignContainer, "TOPLEFT", 0, -y)
            y = y + ASSIGN_H + ASSIGN_GAP
        end
    end
    assignContainer:SetHeight(math.max(y, 1))
end

local function RemoveAssign(id)
    for i, a in ipairs(activeAlerts) do
        if a.id == id then
            if a.ticker then a.ticker:Cancel() end
            if a.frame then
                UIFrameFadeOut(a.frame, 0.3, 1, 0)
                local f = a.frame
                C_Timer.NewTimer(0.3, function() f:Hide() end)
            end
            table.remove(activeAlerts, i)
            C_Timer.NewTimer(0.35, LayoutAssigns)
            return
        end
    end
end

local assignIdCounter = 0
local function ShowAssignAlert(callout, mechName, duration)
    if not assignContainer then CreateAssignContainer() end

    local curW = GetAssignWidth()

    assignIdCounter = assignIdCounter + 1
    local id = assignIdCounter

    local f = CreateFrame("Frame", nil, assignContainer)
    f:SetSize(curW, ASSIGN_H)
    f:SetAlpha(0)

    -- Fond
    SM.BG(f, 0.04, 0.04, 0.07, 0.95)

    -- Barre progression
    local bar = f:CreateTexture(nil, "BORDER")
    bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    bar:SetHeight(3); bar:SetWidth(curW)
    bar:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.9)

    -- Accent gauche (violet pour distinguer des alertes boss)
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetSize(5, ASSIGN_H); accent:SetPoint("LEFT")
    accent:SetColorTexture(SM.PRP[1], SM.PRP[2], SM.PRP[3], 1)

    -- Icône assignment
    local ico = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ico:SetPoint("LEFT", f, "LEFT", 10, 2)
    ico:SetTextColor(SM.PRP[1], SM.PRP[2], SM.PRP[3], 1)
    ico:SetText("★")

    -- Callout
    local lblCallout = f:CreateFontString(nil, "OVERLAY")
    local _afs = GetAssignFontSize()
    lblCallout:SetFont("Fonts\\FRIZQT__.TTF", _afs, "OUTLINE")
    lblCallout:SetPoint("LEFT", f, "LEFT", 32, 4)
    lblCallout:SetPoint("RIGHT", f, "RIGHT", -60, 0)
    lblCallout:SetJustifyH("LEFT")
    lblCallout:SetTextColor(1, 0.9, 0.2, 1)
    lblCallout:SetText(callout or "")

    -- Nom mécanique
    if mechName and mechName ~= callout and mechName ~= "" then
        local lblMech = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lblMech:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 32, 6)
        lblMech:SetTextColor(0.4, 0.4, 0.4, 1)
        lblMech:SetText(mechName)
    end

    -- Timer
    local lblTimer = f:CreateFontString(nil, "OVERLAY")
    local _afs2 = GetAssignFontSize()
    lblTimer:SetFont("Fonts\\FRIZQT__.TTF", _afs2, "OUTLINE")
    lblTimer:SetPoint("RIGHT", f, "RIGHT", -10, 2)
    lblTimer:SetTextColor(1, 1, 1, 1)
    lblTimer:SetText(string.format("%.0fs", duration or 0))

    local alertData = { id = id, frame = f }
    table.insert(activeAlerts, 1, alertData)
    LayoutAssigns()

    f:Show()
    UIFrameFadeIn(f, 0.2, 0, 1)

    SM.PlaySoundForCallout(callout)

    -- Ticker
    local startTime = GetTime()
    alertData.ticker = C_Timer.NewTicker(0.05, function()
        local elapsed  = GetTime() - startTime
        local timeLeft = math.max(0, duration - elapsed)
        local pct      = timeLeft / duration

        if timeLeft >= 10 then
            lblTimer:SetText(string.format("%.0f", timeLeft))
        else
            lblTimer:SetText(string.format("%.1f", timeLeft))
            lblTimer:SetTextColor(1, 0.3, 0.1, 1)
            accent:SetColorTexture(1, 0.2, 0.1, 1)
        end

        bar:SetWidth(math.max(0, curW * pct))

        if timeLeft <= 0 then
            alertData.ticker:Cancel()
            RemoveAssign(id)
        end
    end)
end

local function ClearAllAssigns()
    for _, a in ipairs(activeAlerts) do
        if a.ticker then a.ticker:Cancel() end
        if a.frame then a.frame:Hide() end
    end
    activeAlerts = {}
    for _, t in ipairs(activeTimers) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    activeTimers = {}
end

-- ============================================================
-- LOOKUP — callout de ce joueur pour cette mécanique
-- Clé = par bossName OU par encounterID
-- ============================================================
local function GetMyCallout(mechKey)
    if not mechKey then return nil end
    local myName = UnitName("player")
    if not myName then return nil end

    -- Chercher par encounterID d'abord (plus précis)
    if currentEncID then
        local byEnc = SolaryMDB.assignments and SolaryMDB.assignments[tostring(currentEncID)]
        if byEnc and byEnc[mechKey] then
            local callout = byEnc[mechKey][myName]
            if callout and callout ~= "" then
                return callout
            end
        end
    end

    -- Fallback par nom de boss
    if currentBoss then
        local byName = SolaryMDB.assignments and SolaryMDB.assignments[currentBoss]
        if byName and byName[mechKey] then
            local callout = byName[mechKey][myName]
            if callout and callout ~= "" then
                return callout
            end
        end
    end

    return nil
end

-- ============================================================
-- DÉCLENCHEMENT — quand BW/DBM signale une mécanique
-- ============================================================
local function OnMechTriggered(mechKey, barTime)
    if not currentBoss and not currentEncID then return end

    local callout = GetMyCallout(mechKey)
    if not callout or callout == "" then return end

    local threshold = (SolaryMDB.alert and SolaryMDB.alert.threshold) or 8

    if barTime and barTime > threshold then
        local t = C_Timer.NewTimer(barTime - threshold, function()
            ShowAssignAlert(callout, mechKey, threshold)
        end)
        table.insert(activeTimers, t)
    else
        ShowAssignAlert(callout, mechKey, barTime or threshold)
    end
end

-- ============================================================
-- HOOKS BIGWIGS
-- ============================================================
local function OnBWBar(_, module, key, barText, barTime)
    if not currentBoss and not currentEncID then return end
    if not barText then return end
    OnMechTriggered(barText, barTime)
    if type(key) == "number" then
        local entry = SM.GetSpellEntry and SM.GetSpellEntry(key)
        if entry then
            OnMechTriggered(tostring(key), barTime)
        end
    end
end

local function OnBWEngage(_, module)
    ClearAllAssigns()
    if module then
        currentBoss = module.displayName or module.moduleName
    end
end

local function OnBWEnd()
    ClearAllAssigns()
    currentBoss  = nil
    currentEncID = nil
end

-- ============================================================
-- HOOK DBM
-- ============================================================
local dbmHandle = {}
local function OnDBMTimerStart(_, id, timeLeft, timerType, spellId, dbmType, spellName)
    if not currentBoss and not currentEncID then return end
    local mechKey = spellName
    if not mechKey and spellId then mechKey = tostring(spellId) end
    if mechKey then
        OnMechTriggered(mechKey, timeLeft)
    end
end

-- ============================================================
-- ENCOUNTER EVENTS (RegisterEvent dans PLAYER_LOGIN)
-- ============================================================
local encounterFrame = CreateFrame("Frame")
encounterFrame:SetScript("OnEvent", function(self, event, encID, encName)
    if event == "ENCOUNTER_START" then
        currentEncID = encID
        if not currentBoss then currentBoss = encName end
        ClearAllAssigns()
    elseif event == "ENCOUNTER_END" then
        ClearAllAssigns()
        currentBoss  = nil
        currentEncID = nil
    end
end)

-- ============================================================
-- BROADCAST VIA ACECOMM
-- ============================================================
local function OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if not AceSerializer then return end

    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then
        return
    end

    if data.type == "assignments" then
        SolaryMDB.assignments = data.assignments or {}
        SM.Print("Assignments reçus de |cFFFFD700" .. sender .. "|r — " ..
            (data.count or "?") .. " mécaniques.")
    elseif data.type == "groups" then
        SolaryMDB.groups = data.groups or {}
        SM.Print("Groupes reçus de |cFFFFD700" .. sender .. "|r.")
    elseif data.type == "spells_sync" then
        -- On reçoit aussi son propre message avec AceComm : on l'ignore
        local myName = UnitName("player")
        if sender == myName then return end
        -- Gérer les clés TTS séparément
        if data.spells then
            SolaryMDB.spells_tts = SolaryMDB.spells_tts or {}
            for k, v in pairs(data.spells) do
                if type(k) == "string" and k:sub(1,6) == "__tts_" then
                    local spellId = tonumber(k:sub(7))
                    if spellId then
                        if v == "__removed__" then
                            SolaryMDB.spells_tts[spellId] = nil
                        else
                            SolaryMDB.spells_tts[spellId] = v
                        end
                    end
                end
            end
        end

        local cachedSender = sender
        local cachedImg    = data.imgName
        local cachedCount  = data.count
        local cachedSpells = data.spells or {}

        local cachedRemap = data.spellIdRemap or {}

        -- Tout hors du contexte AceComm pour éviter ADDON_ACTION_FORBIDDEN
        C_Timer.NewTimer(0, function()
            -- Merger les changements reçus dans la DB locale (clés numériques)
            SolaryMDB.spells = SolaryMDB.spells or {}
            SolaryMDB.spellIdRemap = SolaryMDB.spellIdRemap or {}
            for id, callout in pairs(cachedSpells) do
                -- Clés spéciales de nettoyage de remap: "__remap_clear_1251361"
                local remapClearId = tostring(id):match("^__remap_clear_(%d+)$")
                if remapClearId then
                    -- Supprimer ce remap chez le receiver
                    SolaryMDB.spellIdRemap[tonumber(remapClearId)] = nil
                else
                    local numId = tonumber(id) or id
                    if callout == "__removed__" then
                        SolaryMDB.spells[numId] = nil
                    else
                        SolaryMDB.spells[numId] = callout
                    end
                end
            end

            -- Appliquer le remap d'IDs reçu (peut aussi supprimer des remaps via nil)
            for oldId, newId in pairs(cachedRemap) do
                local numOld = tonumber(oldId) or oldId
                local numNew = tonumber(newId) or newId
                if numNew == 0 then
                    SolaryMDB.spellIdRemap[numOld] = nil
                else
                    SolaryMDB.spellIdRemap[numOld] = numNew
                end
            end

            -- Afficher la popup au frame suivant
            C_Timer.NewTimer(0, function()
                SM.ShowSpellSyncPopup(cachedSender, cachedImg, cachedCount)
            end)
        end)
    end
end

function SM.BroadcastAssignments()
    if not SM.IsEditor() then SM.Print("Tu n'as pas les droits d'éditeur."); return end
    if not AceComm or not AceSerializer then
        SM.Print("AceComm/AceSerializer introuvable — broadcast impossible.")
        return
    end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then SM.Print("Tu n'es pas dans un groupe."); return end

    local count = 0
    for boss, mechs in pairs(SolaryMDB.assignments or {}) do
        for _, _ in pairs(mechs) do count = count + 1 end
    end

    local data = { type = "assignments", assignments = SolaryMDB.assignments, count = count }
    AceComm:SendCommMessage(COMM_PREFIX, AceSerializer:Serialize(data), channel)
    SM.Print(string.format("Assignments broadcastés (%d mécaniques).", count))
end

function SM.BroadcastGroups()
    if not SM.IsEditor() then return end
    if not AceComm or not AceSerializer then return end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then return end
    local data = { type = "groups", groups = SolaryMDB.groups }
    AceComm:SendCommMessage(COMM_PREFIX, AceSerializer:Serialize(data), channel)
    SM.Print("Groupes broadcastés.")
end

function SM.BroadcastSpells(imgName)
    if not SM.IsEditor() then SM.Print("Tu n'as pas les droits d'éditeur."); return end
    if not AceComm or not AceSerializer then
        SM.Print("AceComm/AceSerializer introuvable."); return
    end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then SM.Print("Tu n'es pas dans un groupe."); return end

    -- N'envoyer que les changements depuis le dernier broadcast
    -- IMPORTANT: copier dans une table locale AVANT de sérialiser
    -- car ChatThrottleLib est async (OnUpdate) — si on wipe avant l'envoi réel, la table est vide
    local spellsSnapshot = {}
    local count = 0
    for id, callout in pairs(SM.PendingSpellChanges) do
        spellsSnapshot[id] = callout
        -- Ne pas compter les marqueurs internes de nettoyage dans le total affiché
        if not tostring(id):match("^__remap_clear_") then
            count = count + 1
        end
    end

    if count == 0 then
        SM.Print("Aucun changement en attente — modifie un callout d'abord.")
        return
    end

    -- Construire le remap partiel (uniquement les IDs changés)
    local remapToSend = {}
    for oldId, newId in pairs(SolaryMDB.spellIdRemap or {}) do
        if spellsSnapshot[tonumber(newId)] then
            remapToSend[oldId] = newId
        end
    end

    -- Sérialiser MAINTENANT avec les données copiées, avant tout wipe
    local serialized = AceSerializer:Serialize({
        type        = "spells_sync",
        spells      = spellsSnapshot,
        spellIdRemap= remapToSend,
        count       = count,
        imgName     = imgName and imgName ~= "" and imgName or nil,
    })
    AceComm:SendCommMessage(COMM_PREFIX, serialized, channel)
    SM.Print(string.format("|cFF9933FFChangements broadcastés|r — %d sort(s) envoyé(s) au raid.", count))

    -- Vider les pending APRÈS la sérialisation (snapshot déjà pris)
    wipe(SM.PendingSpellChanges)

    -- Mettre à jour le statut et le compteur dans le panel
    local f = SM._spellTabFrame
    if f then
        if f._broadcastStatus then
            local timeStr = date("%H:%M:%S")
            f._broadcastStatus:SetText(string.format("Dernier envoi : %s — %d sort(s)", timeStr, count))
            f._broadcastStatus:SetTextColor(0.2, 0.9, 0.3, 1)
        end
        if SM._UpdatePendingCount then SM._UpdatePendingCount() end
    end
end

-- Helper pour assigner depuis le panel
function SM.SetAssignment(bossKey, mechName, playerName, callout)
    SolaryMDB.assignments = SolaryMDB.assignments or {}
    SolaryMDB.assignments[bossKey] = SolaryMDB.assignments[bossKey] or {}
    SolaryMDB.assignments[bossKey][mechName] = SolaryMDB.assignments[bossKey][mechName] or {}
    if callout and callout ~= "" then
        SolaryMDB.assignments[bossKey][mechName][playerName] = callout
    else
        SolaryMDB.assignments[bossKey][mechName][playerName] = nil
    end
end

-- Test
function SM.TestAssignAlert(callout, mechName, duration)
    if not assignContainer then CreateAssignContainer() end
    ShowAssignAlert(callout or "SOAK G1/G3", mechName or "Test Mechanic", duration or 8)
end

-- ============================================================
-- POPUP DE SYNC SPELLS (reçue par les non-éditeurs)
-- ============================================================
local syncPopup = nil

-- Créée une seule fois à PLAYER_LOGIN (évite le taint de CreateFrame dans un callback réseau)
local function BuildSyncPopup()
    if syncPopup then return end
    local W, H = 420, 260
    syncPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    syncPopup:SetSize(W, H)
    syncPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    syncPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    syncPopup:SetBackdrop({
        bgFile   = "Interface\ChatFrame\ChatFrameBackground",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        edgeSize = 26, insets = {left=9, right=9, top=9, bottom=9}
    })
    syncPopup:SetBackdropColor(0.05, 0.05, 0.1, 0.96)
    syncPopup:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.9)
    syncPopup:SetMovable(true); syncPopup:EnableMouse(true)
    syncPopup:RegisterForDrag("LeftButton")
    syncPopup:SetScript("OnDragStart", syncPopup.StartMoving)
    syncPopup:SetScript("OnDragStop", syncPopup.StopMovingOrSizing)

    local titleBar = syncPopup:CreateTexture(nil,"ARTWORK")
    titleBar:SetSize(W-20, 2); titleBar:SetPoint("TOPLEFT", 10, -28)
    titleBar:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.8)

    local title = syncPopup:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP", 0, -12); title:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    title:SetText("|cFFFFAA00SolaryM|r — Mise à jour des callouts")

    -- Image fixe (on cache/montre selon le broadcast)
    local img = syncPopup:CreateTexture(nil,"ARTWORK")
    img:SetSize(120, 80); img:SetPoint("TOP", 0, -36)
    syncPopup._img = img

    -- Message
    local msg = syncPopup:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    msg:SetPoint("TOP", 0, -125)
    msg:SetWidth(W - 40); msg:SetJustifyH("CENTER")
    syncPopup._msg = msg

    -- Bouton Reload
    local reloadBtn = CreateFrame("Button", nil, syncPopup)
    reloadBtn:SetSize(160, 32); reloadBtn:SetPoint("BOTTOM", 0, 44)
    local rbg = reloadBtn:CreateTexture(nil,"BACKGROUND"); rbg:SetAllPoints()
    rbg:SetColorTexture(SM.GRN[1], SM.GRN[2], SM.GRN[3], 0.9)
    local rfs = reloadBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    rfs:SetAllPoints(); rfs:SetJustifyH("CENTER"); rfs:SetTextColor(1,1,1,1)
    rfs:SetText("Reload UI")
    reloadBtn:SetScript("OnEnter", function() rbg:SetColorTexture(0.15, 0.9, 0.3, 1) end)
    reloadBtn:SetScript("OnLeave", function() rbg:SetColorTexture(SM.GRN[1], SM.GRN[2], SM.GRN[3], 0.9) end)
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)

    -- Bouton Fermer
    local closeBtn = CreateFrame("Button", nil, syncPopup)
    closeBtn:SetSize(100, 26); closeBtn:SetPoint("BOTTOM", 0, 12)
    local cbg = closeBtn:CreateTexture(nil,"BACKGROUND"); cbg:SetAllPoints()
    cbg:SetColorTexture(0.25, 0.25, 0.28, 0.9)
    local cfs = closeBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    cfs:SetAllPoints(); cfs:SetJustifyH("CENTER"); cfs:SetTextColor(0.7,0.7,0.7,1)
    cfs:SetText("Plus tard")
    closeBtn:SetScript("OnClick", function() syncPopup:Hide() end)

    syncPopup:Hide()
end

function SM.ShowSpellSyncPopup(sender, imgName, count)
    -- Tout le corps est différé pour éviter ADDON_ACTION_FORBIDDEN
    -- (SetTexture, SetText, Show, UIFrameFadeIn sont tous protégés dans le contexte AceComm)
    C_Timer.NewTimer(0, function()
        if not syncPopup then return end  -- sécurité

        -- Image
        if imgName and imgName ~= "" and syncPopup._img then
            syncPopup._img:SetTexture("Interface\\AddOns\\SolaryM\\Media\\" .. imgName)
            syncPopup._img:Show()
        elseif syncPopup._img then
            syncPopup._img:Hide()
        end

        -- Message
        local countStr = count and count > 0 and ("|cFFFFD700" .. count .. " sorts custom|r") or "les callouts"
        if syncPopup._msg then
            syncPopup._msg:SetText(string.format(
                "|cFFFFAA00%s|r a mis à jour %s.\n\nReload pour appliquer les changements.",
                sender or "Le RL", countStr
            ))
        end

        syncPopup:SetAlpha(0)
        syncPopup:Show()
        UIFrameFadeIn(syncPopup, 0.4, 0, 1)
        PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN)
    end)
end

-- ============================================================
-- INIT
-- ============================================================
local aFrame = CreateFrame("Frame")
aFrame:RegisterEvent("PLAYER_LOGIN")
aFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    CreateAssignContainer()

    -- RegisterEvent ici pour éviter ADDON_ACTION_FORBIDDEN
    -- encounterFrame events: enregistrés dans PLAYER_ENTERING_WORLD ci-dessous

    BuildSyncPopup()
    if AceComm then
        AceComm:RegisterComm(COMM_PREFIX, OnCommReceived)
    end

    if BigWigsLoader then
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_StartBar",     OnBWBar)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossEngage", OnBWEngage)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWipe",   OnBWEnd)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWin",    OnBWEnd)
    end

    if DBM and DBM.RegisterCallback then
        DBM.RegisterCallback(dbmHandle, "DBM_TimerStart", OnDBMTimerStart)
    end
end)

-- RegisterEvent dans PLAYER_ENTERING_WORLD (protections levées)
local _assignPEW = CreateFrame("Frame")
_assignPEW:RegisterEvent("PLAYER_ENTERING_WORLD")
_assignPEW:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_ENTERING_WORLD" then return end
    encounterFrame:RegisterEvent("ENCOUNTER_START")
    encounterFrame:RegisterEvent("ENCOUNTER_END")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
