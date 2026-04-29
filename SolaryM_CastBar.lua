-- SolaryM_CastBar.lua — Alertes de cast boss
--
-- Deux types de mécaniques :
--
--   type = "fixed"      → timers absolus depuis le pull (boss à timers fixes)
--   type = "phased"     → timers relatifs au début de chaque phase
--                         transition détectée via ENCOUNTER_TIMELINE_EVENT_ADDED
--   type = "spell_cast" → déclenché par SPELL_CAST_START via CLEU
--
-- Affichage : texte décompté dans un conteneur SÉPARÉ des alertes boss.

SM.CastBar = SM.CastBar or {}
local CB = SM.CastBar

-- ============================================================
-- MÉCANIQUES PAR BOSS
-- ============================================================
CB.Mechanics = {

    -- ── L'ura / Midnight Falls (encID 3183) ──────────────────
    {
        id            = "lura_glaives",
        type          = "fixed",
        boss          = "Midnight Falls",
        encID         = 3183,
        label         = "Glaives",
        duration      = 3.0,
        spellID       = 1253915,
        timers_heroic = { 35, 105, 175 },
        timers_mythic = { 26, 88, 150 },
    },
    {
        id            = "lura_transition_cast",
        type          = "fixed",
        boss          = "Midnight Falls",
        encID         = 3183,
        label         = "Transition",
        duration      = 6.5,
        spellID       = 1251386,
        timers_heroic = { 184.1 },
        timers_mythic = {},
    },
    {
        id            = "lura_transition_channel",
        type          = "fixed",
        boss          = "Midnight Falls",
        encID         = 3183,
        label         = "Intermission",
        duration      = 30.0,
        spellID       = 1249609,
        timers_heroic = { 190.6 },
        timers_mythic = {},
    },

    -- ── Belo'ren, Child of Al'ar (encID 3182) ────────────────
    {
        id       = "beloren_rebirth",
        type     = "spell_cast",
        boss     = "Belo'ren, Child of Al'ar",
        encID    = 3182,
        label    = "Rebirth",
        duration = 30.0,
        spellID  = 1263412,
    },

    -- ── Crown of the Cosmos (encID 3181) ─────────────────────
    {
        id       = "crown_silverstrike",
        type     = "phased",
        boss     = "Crown of the Cosmos",
        encID    = 3181,
        label    = "Silverstrike Arrow",
        duration = 6.0,
        spellID  = 1233602,
        phases   = {
            [1] = {
                timers_heroic = { 24.0, 45.0, 68.0, 91.0, 112.0 },
                timers_mythic = {},
            },
            [2] = { timers_heroic = {}, timers_mythic = {} },
        },
        transition = {
            heroic = { [1] = 25 },
            mythic = {},
        },
    },
    {
        id       = "crown_rangers_mark",
        type     = "phased",
        boss     = "Crown of the Cosmos",
        encID    = 3181,
        label    = "Ranger Captain's Mark",
        duration = 2.0,
        spellID  = 1232467,
        phases   = {
            [1] = { timers_heroic = {}, timers_mythic = {} },
            [2] = {
                timers_heroic = { 18.6, 37.6, 60.6, 79.6, 102.6, 121.6, 144.6, 163.6 },
                timers_mythic = {},
            },
            [3] = { timers_heroic = {}, timers_mythic = {} },
        },
        transition = {
            heroic = { [1] = 25, [2] = 18 },
            mythic = {},
        },
    },

}

-- ============================================================
-- AFFICHAGE — conteneur indépendant, même style texte que les alertes boss
-- ============================================================
local CAST_W   = 380
local ROW_H    = 34
local ROW_GAP  = 3

local castContainer = nil
local castLocked    = true
local activeRows    = {}
local rowIdSeq      = 0
local moverCast     = nil

local function SaveCastPos()
    if not castContainer or not SolaryMDB then return end
    SolaryMDB.frames = SolaryMDB.frames or {}
    local point, _, rp, x, y = castContainer:GetPoint()
    if point then
        SolaryMDB.frames["castbar"] = { point=point, rp=rp, x=math.floor(x), y=math.floor(y) }
    end
end

local function LoadCastPos()
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["castbar"]
    castContainer:ClearAllPoints()
    if s and s.x then
        castContainer:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        castContainer:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
    end
end

local function EnsureContainer()
    if castContainer then return end
    CAST_W = (SolaryMDB and SolaryMDB.castbar_width) or 380
    castContainer = CreateFrame("Frame", "SolaryMCastBarContainer", UIParent)
    castContainer:SetSize(CAST_W, ROW_H)
    castContainer:SetFrameStrata("HIGH")
    castContainer:EnableMouse(false)
    LoadCastPos()
end

local function LayoutRows()
    if not castContainer then return end
    local y = 0
    for i = #activeRows, 1, -1 do
        local r = activeRows[i]
        if r.frame and r.frame:IsShown() then
            r.frame:ClearAllPoints()
            r.frame:SetPoint("BOTTOMLEFT", castContainer, "BOTTOMLEFT", 0, y)
            y = y + ROW_H + ROW_GAP
        end
    end
    castContainer:SetSize(CAST_W, math.max(ROW_H, y))
    if moverCast then moverCast:SetAllPoints(castContainer) end
end

local function RemoveRow(id)
    for i, r in ipairs(activeRows) do
        if r.id == id then
            if r.ticker and not r.ticker:IsCancelled() then r.ticker:Cancel() end
            if r.frame then
                UIFrameFadeOut(r.frame, 0.25, 1, 0)
                local f = r.frame
                C_Timer.NewTimer(0.25, function() f:Hide() end)
            end
            table.remove(activeRows, i)
            C_Timer.NewTimer(0.3, LayoutRows)
            return
        end
    end
end

local function HideAllRows()
    for _, r in ipairs(activeRows) do
        if r.ticker and not r.ticker:IsCancelled() then r.ticker:Cancel() end
        if r.frame then r.frame:Hide() end
    end
    wipe(activeRows)
end

local function ShowCastAlert(label, duration)
    EnsureContainer()

    rowIdSeq = rowIdSeq + 1
    local id = rowIdSeq

    local f = CreateFrame("Frame", nil, castContainer)
    f:SetSize(CAST_W, ROW_H)
    f:SetAlpha(0)
    f:EnableMouse(false)

    local lbl = f:CreateFontString(nil, "OVERLAY")
    local fs  = (SM.Resize and SM.Resize.GetAlertFontSize and SM.Resize.GetAlertFontSize()) or 22
    lbl:SetFont("Fonts\\FRIZQT__.TTF", fs, "OUTLINE")
    lbl:SetPoint("CENTER", f, "CENTER", 0, 0)
    lbl:SetJustifyH("CENTER")
    lbl:SetTextColor(1, 1, 1, 1)
    lbl:SetText(string.format("%s (%.1f)", label or "", duration or 0))

    local rowData = {
        id        = id,
        frame     = f,
        lbl       = lbl,
        label     = label or "",
        duration  = duration or 5,
        startTime = GetTime(),
        fontSize  = fs,
    }
    table.insert(activeRows, 1, rowData)
    LayoutRows()
    f:Show()
    UIFrameFadeIn(f, 0.12, 0, 1)

    rowData.ticker = C_Timer.NewTicker(0.05, function()
        local elapsed  = GetTime() - rowData.startTime
        local timeLeft = math.max(0, rowData.duration - elapsed)

        local curFS = (SM.Resize and SM.Resize.GetAlertFontSize and SM.Resize.GetAlertFontSize()) or 22
        if curFS ~= rowData.fontSize then
            lbl:SetFont("Fonts\\FRIZQT__.TTF", curFS, "OUTLINE")
            rowData.fontSize = curFS
        end

        if timeLeft <= 2 then
            lbl:SetTextColor(1, 0.2, 0.1, 1)
        elseif timeLeft <= 4 then
            lbl:SetTextColor(1, 0.65, 0.1, 1)
        else
            lbl:SetTextColor(1, 1, 1, 1)
        end

        if timeLeft >= 10 then
            lbl:SetText(string.format("%s (%.0f)", rowData.label, timeLeft))
        else
            lbl:SetText(string.format("%s (%.1f)", rowData.label, timeLeft))
        end

        if timeLeft <= 0 then
            rowData.ticker:Cancel()
            RemoveRow(id)
        end
    end)
end

-- ============================================================
-- STATE RUNTIME (scheduling)
-- ============================================================
local pendingTimers  = {}
local phaseTimers    = {}
local activeEncID    = nil
local activeDiffID   = nil
local currentPhase   = {}
local phaseStartTime = {}

-- ============================================================
-- HELPERS scheduling
-- ============================================================
local function IsCBEnabled(mechID)
    return SolaryMDB.castbar_enabled == nil
        or SolaryMDB.castbar_enabled[mechID] ~= false
end

local function CancelTimers(list)
    for _, t in ipairs(list) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    wipe(list)
end

local function ClearAll()
    CancelTimers(pendingTimers)
    CancelTimers(phaseTimers)
    HideAllRows()
    wipe(currentPhase)
    wipe(phaseStartTime)
end

-- ============================================================
-- TYPE "fixed"
-- ============================================================
local function ScheduleFixed(mech, diffID)
    if not IsCBEnabled(mech.id) then return end
    local timers = (diffID == 16) and (mech.timers_mythic or mech.timers)
                                   or (mech.timers_heroic or mech.timers)
    for _, t in ipairs(timers or {}) do
        local handle = C_Timer.NewTimer(t, function()
            if activeEncID ~= mech.encID then return end
            if not IsCBEnabled(mech.id) then return end
            ShowCastAlert(mech.label, mech.duration)
        end)
        table.insert(pendingTimers, handle)
    end
end

-- ============================================================
-- TYPE "phased"
-- ============================================================
local function SchedulePhase(mech, phase, diffID)
    CancelTimers(phaseTimers)

    local phaseData = mech.phases and mech.phases[phase]
    if not phaseData then return end
    if not IsCBEnabled(mech.id) then return end

    currentPhase[mech.id]   = phase
    phaseStartTime[mech.id] = GetTime()

    local timers = (diffID == 16) and (phaseData.timers_mythic or phaseData.timers)
                                   or (phaseData.timers_heroic or phaseData.timers)
    for _, t in ipairs(timers or {}) do
        local handle = C_Timer.NewTimer(t, function()
            if activeEncID ~= mech.encID then return end
            if currentPhase[mech.id] ~= phase then return end
            ShowCastAlert(mech.label, mech.duration)
        end)
        table.insert(phaseTimers, handle)
    end
end

-- ============================================================
-- ENCOUNTER_TIMELINE_EVENT_ADDED
-- ============================================================
local lastTransitionTime = {}

local function RoundDuration(d)
    return math.floor(d * 10 + 0.5) / 10
end

local function OnTimelineEvent(info)
    if not activeEncID or not info or not info.duration then return end
    local now             = GetTime()
    local durationRounded = RoundDuration(info.duration)

    for _, mech in ipairs(CB.Mechanics) do
        if mech.encID == activeEncID and mech.type == "phased" and mech.transition then
            if lastTransitionTime[mech.id] and (now - lastTransitionTime[mech.id]) < 5 then
                return
            end
            local thresholds = (activeDiffID == 16) and mech.transition.mythic
                                                      or mech.transition.heroic
            local phase     = currentPhase[mech.id] or 1
            local threshold = type(thresholds) == "table" and thresholds[phase] or thresholds

            if threshold and durationRounded == threshold then
                local nextPhase = (currentPhase[mech.id] or 1) + 1
                local maxPhase  = 0
                for k in pairs(mech.phases or {}) do
                    if k > maxPhase then maxPhase = k end
                end
                if nextPhase <= maxPhase then
                    lastTransitionTime[mech.id] = now
                    local fromPhase = currentPhase[mech.id] or 1
                    C_Timer.NewTimer(threshold, function()
                        if activeEncID ~= mech.encID then return end
                        SM.Print(string.format("CastBar — %s phase %d → %d",
                            mech.boss or mech.id, fromPhase, nextPhase))
                        SchedulePhase(mech, nextPhase, activeDiffID)
                    end)
                end
            end
        end
    end
end

-- ============================================================
-- TYPE "spell_cast"
-- ============================================================
local function OnCLEU(...)
    if not activeEncID then return end
    local _, subevent, _, _, _, _, _, _, _, _, _, spellID = ...
    if subevent ~= "SPELL_CAST_START" then return end
    for _, mech in ipairs(CB.Mechanics) do
        if mech.type == "spell_cast"
           and mech.encID   == activeEncID
           and mech.spellID == spellID
           and (mech.spellID or 0) > 0
           and IsCBEnabled(mech.id)
        then
            ShowCastAlert(mech.label, mech.duration)
        end
    end
end

-- ============================================================
-- EVENTS
-- ============================================================
local cbFrame = CreateFrame("Frame")
cbFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encID, _, diffID = ...
        activeEncID  = encID
        activeDiffID = diffID
        ClearAll()
        for _, mech in ipairs(CB.Mechanics) do
            if mech.encID == encID then
                if mech.type == "fixed" then
                    ScheduleFixed(mech, diffID)
                elseif mech.type == "phased" then
                    SchedulePhase(mech, 1, diffID)
                end
            end
        end

    elseif event == "ENCOUNTER_END" then
        activeEncID  = nil
        activeDiffID = nil
        ClearAll()

    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        OnTimelineEvent(...)

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCLEU(CombatLogGetCurrentEventInfo())
    end
end)
-- ============================================================
-- INIT
-- ============================================================
local initCB = CreateFrame("Frame")
initCB:RegisterEvent("PLAYER_LOGIN")
initCB:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    cbFrame:RegisterEvent("ENCOUNTER_START")
    cbFrame:RegisterEvent("ENCOUNTER_END")
    cbFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    SolaryMDB.castbar_enabled = SolaryMDB.castbar_enabled or {}
    for _, mech in ipairs(CB.Mechanics) do
        if SolaryMDB.castbar_enabled[mech.id] == nil then
            SolaryMDB.castbar_enabled[mech.id] = true
        end
    end
    EnsureContainer()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- ============================================================
-- MOVE MODE
-- ============================================================
local function MakeMover()
    if moverCast then return end
    EnsureContainer()
    moverCast = CreateFrame("Frame", nil, castContainer)
    moverCast:SetAllPoints(castContainer)
    local bg = moverCast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.07, 1)
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
        local l = moverCast:CreateTexture(nil, "BORDER")
        l:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3], t[4])
    end
    local lbl = moverCast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    lbl:SetText("SolaryM — Cast Alerts (déplacer)")
    moverCast:Hide()
end

function CB.Unlock()
    EnsureContainer()
    MakeMover()
    castLocked = false
    castContainer:EnableMouse(true)
    castContainer:SetMovable(true)
    castContainer:RegisterForDrag("LeftButton")
    castContainer:SetScript("OnDragStart", castContainer.StartMoving)
    castContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveCastPos()
    end)
    moverCast:Show()
    ShowCastAlert("Glaives", 4.5)
end

function CB.Lock()
    if not castContainer then return end
    castLocked = true
    castContainer:EnableMouse(false)
    castContainer:SetMovable(false)
    castContainer:SetScript("OnDragStart", nil)
    castContainer:SetScript("OnDragStop",  nil)
    if moverCast then moverCast:Hide() end
    HideAllRows()
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function CB.Test(label, duration)
    EnsureContainer()
    ShowCastAlert(label or "Glaives", duration or 4.5)
end

function CB.GetMechanics()
    return CB.Mechanics
end

function CB.IsEnabled(mechID)
    return IsCBEnabled(mechID)
end

function CB.SetEnabled(mechID, enabled)
    SolaryMDB.castbar_enabled = SolaryMDB.castbar_enabled or {}
    SolaryMDB.castbar_enabled[mechID] = enabled
end

-- ============================================================
-- CONE BAR — Barre de décompte dédiée (ex: cones Belo'ren)
-- Container séparé, positionnable indépendamment
-- ============================================================
local CONE_W  = 300
local CONE_H  = 32

local coneContainer = nil
local coneMover     = nil
local coneLocked    = true
local coneBarRow    = nil  -- une seule barre active à la fois

local function SaveConePos()
    if not coneContainer or not SolaryMDB then return end
    SolaryMDB.frames = SolaryMDB.frames or {}
    local point, _, rp, x, y = coneContainer:GetPoint()
    if point then
        SolaryMDB.frames["cone_bar"] = { point=point, rp=rp, x=math.floor(x), y=math.floor(y) }
    end
end

local function LoadConePos()
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["cone_bar"]
    coneContainer:ClearAllPoints()
    if s and s.x then
        coneContainer:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        coneContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
end

local function EnsureConeContainer()
    if coneContainer then return end
    CONE_W = (SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["cone_bar_w"]) or 300
    coneContainer = CreateFrame("Frame", "SolaryMConeBarContainer", UIParent)
    coneContainer:SetSize(CONE_W, CONE_H)
    coneContainer:SetFrameStrata("HIGH")
    coneContainer:EnableMouse(false)
    LoadConePos()
end

function CB.ShowConeBar(label, spellID, duration)
    EnsureConeContainer()

    -- Annuler la barre précédente si encore active
    if coneBarRow then
        if coneBarRow.ticker and not coneBarRow.ticker:IsCancelled() then
            coneBarRow.ticker:Cancel()
        end
        if coneBarRow.frame then coneBarRow.frame:Hide() end
        coneBarRow = nil
    end

    local f = CreateFrame("Frame", nil, coneContainer)
    f:SetAllPoints(coneContainer)
    f:SetAlpha(0)
    f:EnableMouse(false)

    -- Fond
    local bgTex = f:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0.04, 0.02, 0.09, 0.9)

    -- Bordure violet
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
        local l = f:CreateTexture(nil, "BORDER")
        l:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3], t[4])
    end

    -- StatusBar (barre de progression qui se vide)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -2)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.75)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.1, 0.05, 0.18, 1)

    -- Icône (optionnel)
    local iconSize  = CONE_H - 6
    local iconOffset = 0
    if spellID and spellID > 0 then
        local iconPath = C_Spell.GetSpellTexture(spellID)
        if iconPath then
            local ic = bar:CreateTexture(nil, "OVERLAY")
            ic:SetSize(iconSize, iconSize)
            ic:SetPoint("LEFT", bar, "LEFT", 3, 0)
            ic:SetTexture(iconPath)
            ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconOffset = iconSize + 6
        end
    end

    -- Texte label + décompte
    local lbl = bar:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    lbl:SetJustifyH("CENTER")
    lbl:SetPoint("LEFT",  bar, "LEFT",  iconOffset + 4, 0)
    lbl:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    lbl:SetTextColor(1, 1, 1, 1)

    coneBarRow = {
        frame     = f,
        bar       = bar,
        lbl       = lbl,
        label     = label or "",
        startTime = GetTime(),
        duration  = duration or 5,
    }

    f:Show()
    UIFrameFadeIn(f, 0.1, 0, 1)

    coneBarRow.ticker = C_Timer.NewTicker(0.05, function()
        if not coneBarRow then return end
        local elapsed  = GetTime() - coneBarRow.startTime
        local timeLeft = math.max(0, coneBarRow.duration - elapsed)
        local pct      = timeLeft / coneBarRow.duration

        bar:SetValue(pct)

        if pct < 0.25 then
            bar:SetStatusBarColor(1, 0.15, 0.05, 0.9)
        elseif pct < 0.5 then
            bar:SetStatusBarColor(1, 0.55, 0.05, 0.9)
        else
            bar:SetStatusBarColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.75)
        end

        if timeLeft >= 10 then
            lbl:SetText(string.format("%s  %.0f", coneBarRow.label, timeLeft))
        else
            lbl:SetText(string.format("%s  %.1f", coneBarRow.label, timeLeft))
        end

        if timeLeft <= 0 then
            coneBarRow.ticker:Cancel()
            UIFrameFadeOut(f, 0.25, 1, 0)
            C_Timer.NewTimer(0.3, function() if f then f:Hide() end end)
            coneBarRow = nil
        end
    end)
end

function CB.HideConeBar()
    if coneBarRow then
        if coneBarRow.ticker and not coneBarRow.ticker:IsCancelled() then
            coneBarRow.ticker:Cancel()
        end
        if coneBarRow.frame then coneBarRow.frame:Hide() end
        coneBarRow = nil
    end
end

local function MakeConeMover()
    if coneMover then return end
    EnsureConeContainer()
    coneMover = CreateFrame("Frame", nil, coneContainer)
    coneMover:SetAllPoints(coneContainer)
    local bg = coneMover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.07, 1)
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
        local l = coneMover:CreateTexture(nil, "BORDER")
        l:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3], t[4])
    end
    local lbl = coneMover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    lbl:SetText("SolaryM — Cone Bar (déplacer)")
    coneMover:Hide()
end

function CB.UnlockConeBar()
    EnsureConeContainer()
    MakeConeMover()
    coneLocked = false
    coneContainer:EnableMouse(true)
    coneContainer:SetMovable(true)
    coneContainer:RegisterForDrag("LeftButton")
    coneContainer:SetScript("OnDragStart", coneContainer.StartMoving)
    coneContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveConePos()
    end)
    coneMover:Show()
    CB.ShowConeBar("CONE HIT", 1242792, 5)
end

function CB.LockConeBar()
    if not coneContainer then return end
    coneLocked = true
    coneContainer:EnableMouse(false)
    coneContainer:SetMovable(false)
    coneContainer:SetScript("OnDragStart", nil)
    coneContainer:SetScript("OnDragStop",  nil)
    if coneMover then coneMover:Hide() end
    CB.HideConeBar()
end
