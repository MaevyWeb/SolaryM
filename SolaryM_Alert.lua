-- SolaryM_Alert.lua — Alertes visuelles boss

local activeAlerts  = {}
local alertIdSeq    = 0
local pendingTimers = {}
local alertLocked   = true
local bwHandle      = {}
local inEncounter   = false

local ALERT_W = 380   -- largeur par défaut, modifiable
local ROW_H   = 34
local ROW_GAP = 3

-- ============================================================
-- SAUVEGARDE / RESTAURATION POSITION
-- ============================================================
local function SaveFramePos(key, frame)
    if not SolaryMDB or not SolaryMDB.frames then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    if not point then return end
    SolaryMDB.frames[key] = { point=point, rp=relPoint, x=math.floor(x), y=math.floor(y) }
end

local function LoadFramePos(key, frame, dp, dx, dy)
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames[key]
    frame:ClearAllPoints()
    if s and s.x then
        frame:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        frame:SetPoint(dp, UIParent, dp, dx, dy)
    end
end

-- ============================================================
-- CONTAINER
-- ============================================================
local alertContainer = nil

local function EnsureContainer()
    if alertContainer then return end
    ALERT_W = (SolaryMDB and SolaryMDB.alert and SolaryMDB.alert.width) or 380
    alertContainer = CreateFrame("Frame", "SolaryMAlertContainer", UIParent)
    alertContainer:SetSize(ALERT_W, ROW_H)
    alertContainer:SetFrameStrata("HIGH")
    alertContainer:EnableMouse(false)
    LoadFramePos("alert", alertContainer, "CENTER", 0, 120)
end

function SM.GetAlertContainer()
    EnsureContainer()
    return alertContainer
end

-- ============================================================
-- MOVER
-- ============================================================
local moverAlert = nil

local function MakeAlertMover()
    if moverAlert then return end
    moverAlert = CreateFrame("Frame", nil, alertContainer)
    moverAlert:SetAllPoints(alertContainer)
    local bg = moverAlert:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05,0.05,0.07,1)
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
        local l = moverAlert:CreateTexture(nil,"BORDER")
        l:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
    end
    local lbl = moverAlert:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
    lbl:SetText("SolaryM — Alertes Boss (déplacer)")
    moverAlert:Hide()
end

local function SetContainerLock(locked)
    alertLocked = locked
    if not alertContainer then return end
    if locked then
        alertContainer:EnableMouse(false)
        alertContainer:SetMovable(false)
        alertContainer:SetScript("OnDragStart", nil)
        alertContainer:SetScript("OnDragStop",  nil)
        if moverAlert then moverAlert:Hide() end
        -- Cacher les poignées de resize
        if SM.Resize and SM.Resize.OnAlertLock then SM.Resize.OnAlertLock() end
        -- Vider les alertes de test
        for _, a in ipairs(activeAlerts) do
            if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
            if a.frame then a.frame:Hide() end
        end
        activeAlerts = {}
    else
        MakeAlertMover()
        alertContainer:EnableMouse(true)
        alertContainer:SetMovable(true)
        alertContainer:RegisterForDrag("LeftButton")
        alertContainer:SetScript("OnDragStart", alertContainer.StartMoving)
        alertContainer:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SaveFramePos("alert", self)
        end)
        moverAlert:Show()
        -- Montrer les poignées de resize
        if SM.Resize and SM.Resize.OnAlertUnlock then SM.Resize.OnAlertUnlock() end
        SM.ShowTimedAlert("SOAK G1/3/5 (30.0)", nil, 30)
    end
end

function SM.ToggleAlertLock(forceLock)
    EnsureContainer()
    if forceLock == nil then
        SetContainerLock(not alertLocked)
    else
        SetContainerLock(forceLock)
    end
end

-- ============================================================
-- LAYOUT
-- ============================================================
local function LayoutRows()
    if not alertContainer then return end
    local y = 0
    for i = #activeAlerts, 1, -1 do
        local a = activeAlerts[i]
        if a.frame and a.frame:IsShown() then
            a.frame:ClearAllPoints()
            a.frame:SetPoint("BOTTOMLEFT", alertContainer, "BOTTOMLEFT", 0, y)
            y = y + ROW_H + ROW_GAP
        end
    end
    alertContainer:SetSize(ALERT_W, math.max(ROW_H, y))
    -- Si moverAlert existe, le redimensionner aussi
    if moverAlert then moverAlert:SetAllPoints(alertContainer) end
end

local function RemoveAlert(id)
    for i, a in ipairs(activeAlerts) do
        if a.id == id then
            if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
            if a.frame then
                UIFrameFadeOut(a.frame, 0.25, 1, 0)
                local f = a.frame
                C_Timer.NewTimer(0.25, function() f:Hide() end)
            end
            table.remove(activeAlerts, i)
            C_Timer.NewTimer(0.3, LayoutRows)
            return
        end
    end
end

-- ============================================================
-- AFFICHAGE
-- Pas de fond, pas de barre
-- ============================================================
local function PlayTTSForSpell(spellId, duration)
    if not spellId then return end

    -- Son personnalisé (joué immédiatement à l'affichage)
    if SolaryMDB and SolaryMDB.spells_snd and SolaryMDB.spells_snd[spellId] then
        local snd = SolaryMDB.spells_snd[spellId]
        if snd ~= "" then
            PlaySoundFile(SM.GetSoundPath(snd), "Master")
        end
    end

    -- TTS (joué 2s avant l'impact)
    if not SolaryMDB or not SolaryMDB.spells_tts then return end
    local ttsData = SolaryMDB.spells_tts[spellId]
    if not ttsData then return end

    local ttsText = type(ttsData)=="string" and ttsData or (type(ttsData)=="table" and ttsData.text or "")
    if not ttsText or ttsText == "" then return end
    if not SM.TTS then return end

    local delay = (duration or 0) - 2
    if delay <= 0 then
        SM.TTS(ttsText)
    else
        C_Timer.NewTimer(delay, function()
            SM.TTS(ttsText)
        end)
    end
end

local function ShowAlert(callout, spellId, duration)
    EnsureContainer()
    -- Jouer le TTS
    PlayTTSForSpell(spellId, duration)

    alertIdSeq = alertIdSeq + 1
    local id = alertIdSeq

    local f = CreateFrame("Frame", nil, alertContainer)
    f:SetSize(ALERT_W, ROW_H)
    f:SetAlpha(0)
    f:EnableMouse(false)

    -- TEXTE centré dans le frame
    local lbl = f:CreateFontString(nil, "OVERLAY")
    local _fs = (SM.Resize and SM.Resize.GetAlertFontSize and SM.Resize.GetAlertFontSize()) or 22
    lbl:SetFont("Fonts\\FRIZQT__.TTF", _fs, "OUTLINE")
    lbl:SetPoint("CENTER", f, "CENTER", 0, 0)
    lbl:SetJustifyH("CENTER")
    lbl:SetTextColor(1, 1, 1, 1)
    lbl:SetText(string.format("%s (%.1f)", callout or "", duration or 0))

    -- ICÔNE SPELL collée à gauche du texte, taille = taille de police
    local iconTex = spellId and (
        (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId))
        or (GetSpellTexture and GetSpellTexture(spellId))
    )
    local ico = f:CreateTexture(nil, "ARTWORK")
    ico:SetSize(_fs, _fs)
    ico:SetPoint("RIGHT", lbl, "LEFT", -4, 0)
    ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if iconTex then
        ico:SetTexture(iconTex)
    else
        ico:Hide()
    end

    local alertData = {
        id        = id,
        frame     = f,
        lbl       = lbl,
        ico       = ico,
        hasIcon   = iconTex ~= nil,
        callout   = callout or "",
        duration  = duration or 8,
        startTime = GetTime(),
        fontSize  = _fs,
    }
    table.insert(activeAlerts, 1, alertData)
    LayoutRows()
    f:Show()
    UIFrameFadeIn(f, 0.12, 0, 1)

    alertData.ticker = C_Timer.NewTicker(0.05, function()
        local elapsed  = GetTime() - alertData.startTime
        local timeLeft = math.max(0, alertData.duration - elapsed)

        -- Mettre à jour la taille de police si elle a changé
        local curFS = (SM.Resize and SM.Resize.GetAlertFontSize and SM.Resize.GetAlertFontSize()) or 22
        if curFS ~= alertData.fontSize then
            lbl:SetFont("Fonts\\FRIZQT__.TTF", curFS, "OUTLINE")
            if alertData.hasIcon then alertData.ico:SetSize(curFS, curFS) end
            alertData.fontSize = curFS
        end

        if timeLeft <= 2 then
            lbl:SetTextColor(1, 0.2, 0.1, 1)
        elseif timeLeft <= 4 then
            lbl:SetTextColor(1, 0.65, 0.1, 1)
        else
            lbl:SetTextColor(1, 1, 1, 1)
        end

        if timeLeft >= 10 then
            lbl:SetText(string.format("%s (%.0f)", alertData.callout, timeLeft))
        else
            lbl:SetText(string.format("%s (%.1f)", alertData.callout, timeLeft))
        end

        if timeLeft <= 0 then
            alertData.ticker:Cancel()
            RemoveAlert(id)
        end
    end)
end

local function ClearAllAlerts()
    for _, a in ipairs(activeAlerts) do
        if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
        if a.frame then a.frame:Hide() end
    end
    activeAlerts = {}
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function SM.ShowTimedAlert(callout, spellId, duration)
    if not callout or callout == "" then return end
    if SolaryMDB.alerts_enabled == false then return end
    ShowAlert(callout, spellId, duration or 8)
end

function SM.TestAlert(callout, mechName, duration)
    EnsureContainer()
    ShowAlert(callout or "SOAK", mechName, duration or 8)
end

function SM.MoveAlert()
    SM.ToggleAlertLock()
end

function SM.SetAlertWidth(w)
    w = tonumber(w)
    if not w or w < 100 or w > 800 then
        SM.Print("Usage: /sm alertsize 100-800"); return
    end
    ALERT_W = w
    SolaryMDB.alert = SolaryMDB.alert or {}
    SolaryMDB.alert.width = w
    if alertContainer then
        alertContainer:SetSize(ALERT_W, alertContainer:GetHeight())
        for _, a in ipairs(activeAlerts) do
            if a.frame then a.frame:SetSize(ALERT_W, ROW_H) end
        end
        LayoutRows()
    end
end

-- ============================================================
-- LOOKUP
-- ============================================================
local function GetCallout(spellId)
    if not spellId or spellId == 0 then return nil end
    local c = SolaryMDB.spells and SolaryMDB.spells[spellId]
    if c and c ~= "" then return c end
    local e = SM.GetSpellEntry and SM.GetSpellEntry(spellId)
    if e then return (SM.LANG=="fr") and e.fr or e.en end
end

local function FindSpellIdByBarText(t)
    if not t then return nil end
    local ok, result = pcall(function()
        return SM.NameToSpellId and SM.NameToSpellId[t:lower()]
    end)
    return ok and result or nil
end

local function TriggerFromSpellId(spellId, barTime)
    -- BossTimer.lua gère déjà les sorts présents dans SpellIndex — éviter le double-fire
    if spellId and SM.SpellIndex and SM.SpellIndex[spellId] then return end
    local callout = GetCallout(spellId)
    if not callout or callout == "" then return end
    local threshold = (SolaryMDB.alert and SolaryMDB.alert.threshold) or 8
    if barTime and barTime > threshold then
        local t = C_Timer.NewTimer(barTime - threshold, function()
            SM.ShowTimedAlert(callout, spellId, threshold)
            SM.PlaySoundForCallout(callout)
        end)
        table.insert(pendingTimers, t)
    else
        SM.ShowTimedAlert(callout, spellId, barTime or threshold)
        SM.PlaySoundForCallout(callout)
    end
end

-- ============================================================
-- HOOKS BIGWIGS
-- ============================================================
local function OnBWBar(_, module, key, barText, barTime)
    -- Pas de gate inEncounter : BW filtre déjà ce qu'il envoie, M+ compris
    local spellId = type(key)=="number" and key or FindSpellIdByBarText(barText)
    if spellId then TriggerFromSpellId(spellId, barTime) end
    if SM.Notes and SM.Notes.OnMechFired and barText then
        pcall(SM.Notes.OnMechFired, barText, barTime)
    end
end

local function OnBWEngage()
    inEncounter = true
    for _, t in ipairs(pendingTimers) do if t and not t:IsCancelled() then t:Cancel() end end
    pendingTimers = {}; ClearAllAlerts()
end

local function OnBWEnd()
    inEncounter = false
    for _, t in ipairs(pendingTimers) do if t and not t:IsCancelled() then t:Cancel() end end
    pendingTimers = {}; ClearAllAlerts()
end

-- ============================================================
-- HOOK DBM
-- ============================================================
local dbmHandle = {}
local function OnDBMTimerStart(_, id, timeLeft, timerType, spellId)
    if spellId and type(spellId)=="number" and spellId > 0 then
        TriggerFromSpellId(spellId, timeLeft)
    end
end

-- ============================================================
-- ENCOUNTER EVENTS (frame sans RegisterEvent au top-level)
-- ============================================================
local encFrame = CreateFrame("Frame")
encFrame:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_START" then
        inEncounter = true
        for _, t in ipairs(pendingTimers) do if t and not t:IsCancelled() then t:Cancel() end end
        pendingTimers = {}; ClearAllAlerts()
    elseif event == "ENCOUNTER_END" or event == "PLAYER_REGEN_ENABLED" then
        inEncounter = false
        for _, t in ipairs(pendingTimers) do if t and not t:IsCancelled() then t:Cancel() end end
        pendingTimers = {}; ClearAllAlerts()
    end
end)

-- ============================================================
-- INIT — PLAYER_LOGIN
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end

    -- Initialiser SolaryMDB.frames pour sauvegarder les positions
    SolaryMDB.frames = SolaryMDB.frames or {}

    EnsureContainer()

    if SolaryMDB.alert and SolaryMDB.alert.width then
        ALERT_W = SolaryMDB.alert.width
        if alertContainer then alertContainer:SetSize(ALERT_W, ROW_H) end
    end

    -- RegisterEvent ICI — pas au top-level
    -- encFrame events: enregistrés dans PLAYER_ENTERING_WORLD ci-dessous

    if BigWigsLoader then
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_StartBar",     OnBWBar)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossEngage", OnBWEngage)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWipe",   OnBWEnd)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWin",    OnBWEnd)
    end
    if DBM and DBM.RegisterCallback then DBM.RegisterCallback(dbmHandle, "DBM_TimerStart", OnDBMTimerStart) end
end)

-- RegisterEvent dans PLAYER_ENTERING_WORLD (protections levées)
local _alertPEW = CreateFrame("Frame")
_alertPEW:RegisterEvent("PLAYER_ENTERING_WORLD")
_alertPEW:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_ENTERING_WORLD" then return end
    encFrame:RegisterEvent("ENCOUNTER_START")
    encFrame:RegisterEvent("ENCOUNTER_END")
    encFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
