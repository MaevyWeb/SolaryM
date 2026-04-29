-- SolaryM_Notes.lua — Notes de raid parsées et broadcastées

local AceComm      = LibStub and LibStub("AceComm-3.0", true)
local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local COMM_PREFIX  = "SolaryMN"
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local LGF = LibStub and LibStub("LibGetFrame-1.0", true)

SM.Notes = {}

-- ============================================================
-- PERMISSION — RL, assist, ou éditeur SolaryM
-- ============================================================
local function CanSend()
    return SM.IsEditor() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- ============================================================
-- PARSE NOTE
-- ============================================================
function SM.Notes.Parse(text)
    local groups = {}
    local inside = false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = strtrim(line)
        if line:lower() == "solarystart" then
            inside = true
        elseif line:lower() == "solaryend" then
            break
        elseif inside and line ~= "" then
            local group = {}
            for name in line:gmatch("[^,]+") do
                name = strtrim(name)
                if name ~= "" then table.insert(group, name) end
            end
            if #group > 0 then table.insert(groups, group) end
        end
    end
    return groups
end

-- Retourne l'index du groupe du joueur courant (nil si pas dans la note)
local function GetMyGroupIndex()
    local myName = UnitName("player")
    local groups = SolaryMDB.notes and SolaryMDB.notes.groups or {}
    for gIdx, group in ipairs(groups) do
        for _, name in ipairs(group) do
            if name == myName then return gIdx end
        end
    end
    return nil
end

-- ============================================================
-- RUNTIME : compteur de déclenchement par mécanique
-- ============================================================
local mechFireCount    = {}  -- { [configRef] = count } reset à chaque encounter
local mechLastFire     = {}  -- { [configRef] = timestamp } pour détecter les re-fires BW
local mechPendingTimer = {}  -- { [configRef] = C_Timer } annulé si BW re-fire la même bar

-- ============================================================
-- AFFICHAGE NOTE CALLOUT (texte vert — distinct du blanc BW et cyan aura)
-- ============================================================
local noteAlerts   = {}
local noteAlertSeq = 0
local noteContainer = nil

local function SaveNotePos()
    if not SolaryMDB or not SolaryMDB.frames then return end
    local point, _, rp, x, y = noteContainer:GetPoint()
    if not point then return end
    SolaryMDB.frames["note"] = { point=point, rp=rp, x=math.floor(x), y=math.floor(y) }
end

local function EnsureNoteContainer()
    if noteContainer then return end
    noteContainer = CreateFrame("Frame", "SolaryMNoteContainer", UIParent)
    noteContainer:SetSize(400, 35)
    noteContainer:SetFrameStrata("HIGH")
    noteContainer:EnableMouse(false)
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["note"]
    if s and s.x then
        noteContainer:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        noteContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    end
end

local function LayoutNoteRows()
    if not noteContainer then return end
    local y = 0
    for i = #noteAlerts, 1, -1 do
        local a = noteAlerts[i]
        if a.frame and a.frame:IsShown() then
            a.frame:ClearAllPoints()
            a.frame:SetPoint("BOTTOMLEFT", noteContainer, "BOTTOMLEFT", 0, y)
            y = y + 32 + 3
        end
    end
    noteContainer:SetSize(400, math.max(35, y))
end

local function RemoveNoteRow(id)
    for i, a in ipairs(noteAlerts) do
        if a.id == id then
            if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
            if a.frame then
                UIFrameFadeOut(a.frame, 0.2, 1, 0)
                local f = a.frame
                C_Timer.NewTimer(0.2, function() f:Hide() end)
            end
            table.remove(noteAlerts, i)
            C_Timer.NewTimer(0.25, LayoutNoteRows)
            return
        end
    end
end

local function ShowNoteCallout(callout, duration)
    EnsureNoteContainer()
    noteAlertSeq = noteAlertSeq + 1
    local id = noteAlertSeq
    local f = CreateFrame("Frame", nil, noteContainer)
    f:SetSize(400, 32); f:SetAlpha(0); f:EnableMouse(false)
    local lbl = f:CreateFontString(nil, "OVERLAY")
    local _nfs = (SM.Resize and SM.Resize.GetNotesFontSize and SM.Resize.GetNotesFontSize()) or 22
    lbl:SetFont("Fonts\\FRIZQT__.TTF", _nfs, "OUTLINE")
    lbl:SetPoint("CENTER", f, "CENTER", 0, 0)   -- centré comme les alertes boss
    lbl:SetJustifyH("CENTER")
    lbl:SetTextColor(0.2, 1, 0.4, 1)  -- vert vif
    local rowData = { id=id, frame=f, lbl=lbl, callout=callout, startTime=GetTime(), duration=duration }
    table.insert(noteAlerts, 1, rowData)
    LayoutNoteRows()
    f:Show(); UIFrameFadeIn(f, 0.12, 0, 1)
    if duration and duration > 0 then
        rowData.ticker = C_Timer.NewTicker(0.05, function()
            local tl = math.max(0, rowData.duration - (GetTime() - rowData.startTime))
            if     tl <= 1 then lbl:SetTextColor(1, 0.4, 0.1, 1)
            elseif tl <= 3 then lbl:SetTextColor(1, 0.8, 0.1, 1)
            else               lbl:SetTextColor(0.2, 1, 0.4, 1) end
            lbl:SetText(callout .. " (" .. string.format("%.1f", tl) .. ")")
            if tl <= 0 then rowData.ticker:Cancel(); RemoveNoteRow(id) end
        end)
    else
        lbl:SetText(callout)
        C_Timer.NewTimer(8, function() RemoveNoteRow(id) end)
    end
    return id
end

local function ClearAllNoteAlerts()
    for _, a in ipairs(noteAlerts) do
        if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
        if a.frame then a.frame:Hide() end
    end
    noteAlerts = {}
end

-- ============================================================
-- FRAMEGLOWS — LibCustomGlow + LibGetFrame
-- ============================================================
local activeGlowFrames = {}
local glowSeq = 0

local function GlowPlayers(names, glowId)
    if not LCG or not LGF then return end
    activeGlowFrames[glowId] = {}
    for _, name in ipairs(names) do
        if UnitExists(name) then
            local f = LGF.GetUnitFrame(name)
            if f then
                LCG.PixelGlow_Stop(f, glowId)
                LCG.PixelGlow_Start(f, {{0.2, 1, 0.4, 1}}, 8, 0.25, 15, 2, 0, 0, true, glowId)
                table.insert(activeGlowFrames[glowId], f)
            end
        end
    end
end

local function StopGlows(glowId)
    if not LCG then return end
    if glowId then
        local frames = activeGlowFrames[glowId]
        if frames then
            for _, f in ipairs(frames) do LCG.PixelGlow_Stop(f, glowId) end
            activeGlowFrames[glowId] = nil
        end
    else
        for id, frames in pairs(activeGlowFrames) do
            for _, f in ipairs(frames) do LCG.PixelGlow_Stop(f, id) end
        end
        wipe(activeGlowFrames)
    end
end

function SM.Notes.TestGlow()
    if not LCG or not LGF then
        SM.Print("|cffff4444LibCustomGlow ou LibGetFrame introuvable.|r")
        return
    end
    local groups = SolaryMDB.notes and SolaryMDB.notes.groups or {}
    local targets = (groups[1] and #groups[1] > 0) and groups[1] or { UnitName("player") }
    glowSeq = glowSeq + 1
    local gid = "smn_glow_test_" .. glowSeq
    GlowPlayers(targets, gid)
    C_Timer.NewTimer(5, function() StopGlows(gid) end)
    SM.Print("|cff00ff00[Glow test] " .. #targets .. " joueur(s) pendant 5s.|r")
end

function SM.Notes.StopGlows()
    StopGlows()
end

-- ============================================================
-- DÉCLENCHEMENT — appelé par SolaryM_Alert.lua quand BW/DBM fire
-- ============================================================
function SM.Notes.OnMechFired(barText, barTime)
    if not barText then return end
    local configs = SolaryMDB.notes and SolaryMDB.notes.mechConfigs or {}

    -- pcall pour éviter le taint sur barText
    local ok, barLower = pcall(function() return barText:lower() end)
    if not ok then return end

    for _, config in ipairs(configs) do
        local configLower = config.mechName:lower()
        if configLower == barLower or barLower:find(configLower, 1, true) then

            -- Détecter un re-fire BW dans les 3s (confirmation CLEU après prédiction pull)
            local now = GetTime()
            local isResync = mechLastFire[config] and (now - mechLastFire[config]) < 3
            mechLastFire[config] = now

            -- N'incrémenter la rotation QUE sur un vrai nouveau cast, pas sur une re-sync BW
            if not isResync then
                mechFireCount[config] = (mechFireCount[config] or 0) + 1
            end
            local count = mechFireCount[config] or 1

            local groups = SolaryMDB.notes and SolaryMDB.notes.groups or {}
            local numGroups = #groups
            if numGroups == 0 then return end

            -- Groupe actif ce tour
            local activeGroupIdx
            if config.rotate then
                activeGroupIdx = ((count - 1) % numGroups) + 1
            else
                activeGroupIdx = 1
            end

            local threshold = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec)
                           or (SolaryMDB.alert and SolaryMDB.alert.threshold)
                           or 5

            -- Glow des frames du groupe actif (visible par tous, pas seulement le joueur local)
            local activeGroup = groups[activeGroupIdx]
            if activeGroup then
                glowSeq = glowSeq + 1
                local gid = "smn_glow_" .. glowSeq
                local glowDur = math.min(barTime or threshold, threshold)
                if barTime and barTime > threshold then
                    C_Timer.NewTimer(barTime - threshold, function()
                        GlowPlayers(activeGroup, gid)
                        C_Timer.NewTimer(glowDur, function() StopGlows(gid) end)
                    end)
                else
                    GlowPlayers(activeGroup, gid)
                    C_Timer.NewTimer(glowDur, function() StopGlows(gid) end)
                end
            end

            -- Callout texte uniquement si le joueur est dans la note
            local myGroupIdx = GetMyGroupIndex()
            if not myGroupIdx then return end

            local callout = nil
            if myGroupIdx == activeGroupIdx then
                callout = config.callouts and config.callouts[1] or "ACTIF"
            else
                callout = config.restCallout or nil
            end

            if callout and callout ~= "" then
                -- Annuler le timer précédent si BW re-fire la même bar (re-sync)
                if mechPendingTimer[config] and not mechPendingTimer[config]:IsCancelled() then
                    mechPendingTimer[config]:Cancel()
                end
                if barTime and barTime > threshold then
                    mechPendingTimer[config] = C_Timer.NewTimer(barTime - threshold, function()
                        mechPendingTimer[config] = nil
                        ShowNoteCallout(callout, threshold)
                    end)
                else
                    mechPendingTimer[config] = nil
                    ShowNoteCallout(callout, barTime or threshold)
                end
            end
        end
    end
end

-- ============================================================
-- DISPEL — appelé par SolaryM_Auras.lua quand une aura est appliquée
-- Config : { spellId=XXXX, assignments={ ["VictimName"]="HealerName" } }
-- ============================================================
local activeDispelAlerts = {}

function SM.Notes.OnAuraApplied(spellId, targetName)
    if not spellId or not targetName then return end
    local dispelConfigs = SolaryMDB.notes and SolaryMDB.notes.dispelConfigs or {}
    local myName = UnitName("player")

    for _, dc in ipairs(dispelConfigs) do
        if dc.spellId == spellId and dc.assignments then
            -- Je dois dispel quelqu'un ?
            for victim, healer in pairs(dc.assignments) do
                if healer == myName and victim == targetName then
                    local callout = "DISPEL " .. victim
                    if activeDispelAlerts[spellId .. victim] then
                        SM.HideAuraCallout(activeDispelAlerts[spellId .. victim])
                    end
                    activeDispelAlerts[spellId .. victim] = ShowNoteCallout(callout, nil)
                end
            end
        end
    end
end

function SM.Notes.OnAuraRemoved(spellId)
    -- Nettoie les alertes de dispel liées à ce spell
    local myName = UnitName("player")
    for key, id in pairs(activeDispelAlerts) do
        if key:find("^" .. spellId) then
            RemoveNoteRow(id)
            activeDispelAlerts[key] = nil
        end
    end
end

-- ============================================================
-- ENCOUNTER EVENTS — reset compteurs
-- ============================================================
local encFrame = CreateFrame("Frame")
encFrame:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_START" then
        mechFireCount    = {}
        mechLastFire     = {}
        mechPendingTimer = {}
    elseif event == "ENCOUNTER_END" then
        mechFireCount    = {}
        mechLastFire     = {}
        mechPendingTimer = {}
        ClearAllNoteAlerts()
        StopGlows()
        for k in pairs(activeDispelAlerts) do activeDispelAlerts[k] = nil end
    end
end)

-- ============================================================
-- BROADCAST VIA ACECOMM
-- ============================================================
function SM.Notes.Broadcast()
    if not CanSend() then SM.Print("Tu n'as pas les droits pour broadcaster.") return end
    if not AceComm or not AceSerializer then SM.Print("AceComm manquant.") return end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then SM.Print("Pas dans un groupe.") return end

    -- Incrémente la version pour déclencher l'alerte update chez les membres
    SolaryMDB.notes.version = (SolaryMDB.notes.version or 0) + 1

    local data = {
        type    = "notes",
        notes   = SolaryMDB.notes,
        version = SolaryMDB.notes.version,
        sender  = UnitName("player"),
    }
    AceComm:SendCommMessage(COMM_PREFIX, AceSerializer:Serialize(data), channel)
    SM.Print("Notes broadcastées (v" .. SolaryMDB.notes.version .. ").")
end

-- ============================================================
-- RÉCEPTION
-- ============================================================
local function OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if not AceSerializer then return end
    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then return end

    if data.type == "notes" then
        local oldVersion = SolaryMDB.notes and SolaryMDB.notes.version or 0
        SolaryMDB.notes = data.notes
        SM.Print("|cFF00FF66Notes reçues de |cFFFFD700" .. sender .. "|r (v" .. (data.version or 0) .. ").")

        -- Alerte update si version différente
        if SM.ShowUpdateAlert then
            SM.ShowUpdateAlert(sender, data.version)
        end

        if SM.RefreshNotesPanel then SM.RefreshNotesPanel() end
    end
end

-- ============================================================
-- MOVER noteContainer
-- ============================================================
local moverNote = nil
function SM.ToggleNoteLock(locked)
    EnsureNoteContainer()
    if locked then
        noteContainer:EnableMouse(false); noteContainer:SetMovable(false)
        noteContainer:SetScript("OnDragStart", nil); noteContainer:SetScript("OnDragStop", nil)
        if moverNote then moverNote:Hide() end
        -- Cacher les poignées de resize
        if SM.Resize and SM.Resize.OnNoteLock then SM.Resize.OnNoteLock() end
        -- Cacher le cadre de test s'il n'y a pas d'alertes actives
        if noteContainer._isMoverTest then
            noteContainer:Hide()
            noteContainer._isMoverTest = false
        end
    else
        noteContainer:EnableMouse(true); noteContainer:SetMovable(true)
        noteContainer:RegisterForDrag("LeftButton")
        noteContainer:SetScript("OnDragStart", noteContainer.StartMoving)
        noteContainer:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveNotePos()
        end)
        if not moverNote then
            moverNote = CreateFrame("Frame", nil, noteContainer)
            moverNote:SetAllPoints(noteContainer)
            local bg = moverNote:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints()
            bg:SetColorTexture(0.05,0.05,0.05,0.7)
            for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
                local l = moverNote:CreateTexture(nil,"BORDER"); l:SetColorTexture(0.2,1,0.4,1)
                l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
            end
            local lbl = moverNote:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            lbl:SetPoint("CENTER"); lbl:SetTextColor(0.2,1,0.4,1); lbl:SetText("SolaryM — Assignations")
            moverNote:Hide()
        end
        moverNote:Show()
        noteContainer._isMoverTest = true
        noteContainer:Show()
        -- Afficher les poignées de resize
        if SM.Resize and SM.Resize.OnNoteUnlock then SM.Resize.OnNoteUnlock() end
        ShowNoteCallout("SOAK GRP A (exemple)", 20)
    end
end

-- ============================================================
-- INIT
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end
    SolaryMDB.frames = SolaryMDB.frames or {}
    EnsureNoteContainer()
    -- RegisterEvent ici pour éviter ADDON_ACTION_FORBIDDEN
    -- encFrame events: enregistrés dans PLAYER_LOGIN ci-dessus
    SolaryMDB.notes = SolaryMDB.notes or {
        raw          = "",
        groups       = {},
        mechConfigs  = {},
        dispelConfigs= {},
        version      = 0,
    }
    if AceComm then AceComm:RegisterComm(COMM_PREFIX, OnCommReceived) end
end)

-- (RegisterEvent faits dans PLAYER_LOGIN)
