-- SolaryM_BossTimer.lua — Timers boss via BigWigs/DBM ou standalone (UNIT_SPELLCAST sur boss units)

SM.BossTimer = SM.BossTimer or {}
local BT = SM.BossTimer

-- ============================================================
-- ÉTAT
-- ============================================================
local currentEncounterID   = nil
local currentEncounterName = nil
local currentDifficulty    = nil
local currentPhase         = 1
local phaseDetectLast      = 0
local bwBarBuffer          = {}
local activeTimers         = {}
local pendingAlerts        = {}
local pullTime             = nil
local bwHandle             = {}
local lastSeenCast         = {}
local lastBWBar            = {}  -- { [spellId] = timestamp } dédup double-fire BW
local hasBWOrDBM           = false

-- Forward declarations — fonctions définies plus bas mais appelées dans OnEvent/CancelAll
local ProcessBWBar
local SetupTauntAlerts
local CancelTauntAlerts

-- ============================================================
-- HELPERS
-- ============================================================
local function CancelAll()
    for _, t in pairs(activeTimers) do
        if t.ticker and not t.ticker:IsCancelled() then t.ticker:Cancel() end
    end
    activeTimers = {}
    for _, t in ipairs(pendingAlerts) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    pendingAlerts     = {}
    pullTime          = nil
    currentPhase      = 1
    phaseDetectLast   = 0
    if SM.CastBar and SM.CastBar.HideConeBar then SM.CastBar.HideConeBar() end
    CancelTauntAlerts()
end

local function NextCastTime(first, cd, count)
    if not first then return nil end
    if count == 0 then return first end
    if not cd then return nil end
    if type(cd) == "number" then
        return first + cd * count
    elseif type(cd) == "table" then
        local t = first
        for i = 1, count do
            local idx = ((i - 1) % #cd) + 1
            t = t + cd[idx]
        end
        return t
    end
    return nil
end

-- ============================================================
-- DÉCLENCHEMENT D'UNE ALERTE
-- ============================================================
local function FireAlert(entry, timeUntil)
    local callout = SolaryMDB.spells and SolaryMDB.spells[entry.id]
    if not callout or callout == "" then
        callout = (SM.LANG == "fr") and entry.fr or entry.en
    end

    if SolaryMDB.boss_timers and SolaryMDB.boss_timers.sounds ~= false then
        SM.PlaySoundForCallout(callout)
    end

    if callout and callout ~= "" then
        local duration = SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec or 5
        if SM.ShowTimedAlert then
            SM.ShowTimedAlert(callout, entry and entry.id, duration)
        end
    end

    if SM.IsEditor() and SolaryMDB.boss_timers and SolaryMDB.boss_timers.raid_warn then
        local msg = string.format("[SolaryM] %s — %.0fs", callout, timeUntil or 0)
        if IsInRaid() then
            C_Timer.NewTimer(0, function()
                if IsInRaid() then SendChatMessage(msg, "RAID_WARNING") end
            end)
        end
    end
end

-- ============================================================
-- BELO'REN — CÔNES (Rebirth)
-- Temps depuis Death Drop (début Rebirth)
-- NM/HC : {12.2, 16.2, 20.2, 24.2, 28.2, 32.2, 36.2, 40.2}
-- Mythic : {11.7, 15.2, 18.7, 22.2, 25.7, 29.2, 32.7, 36.2, 39.7}
-- ============================================================
local BELOREN_CONE_NM = {12.2, 16.2, 20.2, 24.2, 28.2, 32.2, 36.2, 40.2}
local BELOREN_CONE_M  = {11.7, 15.2, 18.7, 22.2, 25.7, 29.2, 32.7, 36.2, 39.7}
local coneEntry       = {id=1242792, en="CONE HIT", fr="COUP CÔNE", type="mechanic"}

local function ScheduleBeloCones(coneTimes, prealert, encID)
    for _, t in ipairs(coneTimes) do
        local fireAt = t - prealert
        if fireAt > 0 then
            table.insert(pendingAlerts, C_Timer.NewTimer(fireAt, function()
                if currentEncounterID ~= encID then return end
                FireAlert(coneEntry, prealert)
                if SM.CastBar and SM.CastBar.ShowConeBar then
                    local label = (SM.LANG == "fr") and coneEntry.fr or coneEntry.en
                    SM.CastBar.ShowConeBar(label, coneEntry.id, prealert)
                end
            end))
        end
    end
end

-- ============================================================
-- PHASE DETECTION — ENCOUNTER_TIMELINE_EVENT_ADDED
-- Une barre de durée connue apparaît sur la
-- timeline d'instance → signal de début de phase suivante.
-- ============================================================

-- Entrée synthétique pour l'alerte de transition (pas un vrai sort)
local REBIRTH_ENTRY = {id=0, en="REBIRTH", fr="RENAISSANCE", type="mechanic"}

-- Belo'ren : Death Drop (durée 6s) → boss atterrit → début de la phase suivante
-- Timers P2 et P3 identiques
local BELOREN_PHASE_TIMERS = {
    [1241282] = {60.6, 110.6, 160.6},
    [1242260] = {69.2, 79.2, 89.2, 119.2, 129.2, 139.2, 169.2},
}

local function SchedulePhaseTimers(timerMap)
    local prealert = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
    local encID    = currentEncounterID
    for spellId, times in pairs(timerMap) do
        local entry = SM.SpellIndex and SM.SpellIndex[spellId]
        if entry then
            for _, t in ipairs(times) do
                local fireAt = t - prealert
                if fireAt > 0 then
                    local e = entry
                    local timer = C_Timer.NewTimer(fireAt, function()
                        if currentEncounterID == encID then FireAlert(e, prealert) end
                    end)
                    table.insert(pendingAlerts, timer)
                end
            end
        end
    end
end

-- ============================================================
-- PLANIFIER LES TIMERS POUR UN BOSS
-- Supporte entry.times / entry.times_m (absolus depuis le pull)
-- et entry.first / entry.cd (ancien format)
-- ============================================================
local function ScheduleBossTimers(encounterID, difficulty)
    local spells = SM.GetBossSpells and SM.GetBossSpells(encounterID) or {}
    local prealert = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
    local isMythic = (difficulty == 16)

    for _, entry in ipairs(spells) do

        -- Nouvelle syntaxe : times = {t1, t2, ...} absolus depuis le pull
        local times = (isMythic and entry.times_m) or entry.times
        if times then
            for _, t in ipairs(times) do
                local fireAt = t - prealert
                if fireAt > 0 then
                    local ce = entry
                    local timer = C_Timer.NewTimer(fireAt, function()
                        if currentEncounterID == encounterID then
                            FireAlert(ce, prealert)
                        end
                    end)
                    table.insert(pendingAlerts, timer)
                end
            end
        end

        -- Ancienne syntaxe : first + cd
        if entry.first and entry.first > 0 then
            local delay = entry.first - prealert
            if delay > 0 then
                local t = C_Timer.NewTimer(delay, function()
                    FireAlert(entry, prealert)
                end)
                table.insert(pendingAlerts, t)
            elseif entry.first > 0 then
                local t = C_Timer.NewTimer(0.1, function()
                    FireAlert(entry, entry.first)
                end)
                table.insert(pendingAlerts, t)
            end

            if entry.cd then
                local count = 1
                local maxCasts = 30
                local nextTime = NextCastTime(entry.first, entry.cd, count)
                while nextTime and nextTime < 600 and count <= maxCasts do
                    local fireAt = nextTime - prealert
                    if fireAt > 0 then
                        local ce = entry
                        local t = C_Timer.NewTimer(fireAt, function()
                            if currentEncounterID ~= encounterID then return end
                            FireAlert(ce, prealert)
                        end)
                        table.insert(pendingAlerts, t)
                    end
                    count = count + 1
                    nextTime = NextCastTime(entry.first, entry.cd, count)
                end
            end
        end
    end
end

-- ============================================================
-- RESYNCHRO sur cast réel (COMBAT_LOG)
-- ============================================================
local function OnRealCast(spellID, entry)
    local now = GetTime()
    local ok1, recent = pcall(function() return lastSeenCast[spellID] end)
    if ok1 and recent and (now - recent) < 2 then return end
    pcall(function() lastSeenCast[spellID] = now end)

    local callout
    local ok2, custom = pcall(function() return SolaryMDB.spells and SolaryMDB.spells[spellID] end)
    if ok2 and custom and custom ~= "" then
        callout = custom
    else
        callout = (SM.LANG == "fr") and entry.fr or entry.en
    end

    if callout and callout ~= "" then
        if SM.ShowTimedAlert then
            SM.ShowTimedAlert(callout, entry and entry.id, 3)
        end
        SM.PlaySoundForCallout(callout)
    end
end

-- ============================================================
-- FRAME PRINCIPALE — EVENTS WoW
-- ============================================================
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, ...)
    -- ── ENCOUNTER_START ──────────────────────────────────────
    if event == "ENCOUNTER_START" then
        local encID, encName, diff, groupSize = ...

        if SolaryMDB.boss_timers and SolaryMDB.boss_timers.enabled == false then
            return
        end

        CancelAll()
        currentEncounterID   = encID
        currentEncounterName = encName
        currentDifficulty    = diff
        pullTime             = GetTime()
        lastSeenCast         = {}
        lastBWBar            = {}

        local spells = SM.GetBossSpells and SM.GetBossSpells(encID) or {}
        if #spells == 0 then return end

        local hasBW  = BigWigsLoader ~= nil
        local hasDBM = DBM ~= nil
        hasBWOrDBM   = hasBW or hasDBM
        SM.Print(string.format("Boss Timer actif — |cffFFAA00%s|r (%d sorts)%s",
            encName or "?", #spells,
            (hasBW and " [BW]") or (hasDBM and " [DBM]") or " [standalone]"))
        if not hasBW and not hasDBM then
            ScheduleBossTimers(encID, diff)
        end

        -- Alerts tank spécifiques (indépendant de BW/DBM)
        if encID == 3180 then SetupTauntAlerts(diff) end

        -- Rejouer les barres BW reçues avant ENCOUNTER_START
        if #bwBarBuffer > 0 then
            local now = GetTime()
            for _, bar in ipairs(bwBarBuffer) do
                local elapsed = now - bar.t
                local adjustedTime = (bar.barTime or 0) - elapsed
                if adjustedTime > 0 then
                    ProcessBWBar(bar.key, bar.barText, adjustedTime)
                end
            end
            wipe(bwBarBuffer)
        end

    -- ── ENCOUNTER_END ────────────────────────────────────────
    elseif event == "ENCOUNTER_END" then
        CancelAll()
        currentEncounterID   = nil
        currentEncounterName = nil
        currentDifficulty    = nil
        hasBWOrDBM           = false
        wipe(bwBarBuffer)
        lastSeenCast         = {}
        lastBWBar            = {}

    -- ── ENCOUNTER_TIMELINE_EVENT_ADDED ───────────────────────
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        if not currentEncounterID then return end
        local info = ...
        if not info or not info.duration then return end
        local now = GetTime()
        if now - phaseDetectLast < 5 then return end  -- debounce

        -- Belo'ren : Death Drop (duration=6 dans le journal) → début du Rebirth
        if currentEncounterID == 3182 and info.duration == 6 then
            phaseDetectLast = now
            currentPhase    = currentPhase + 1
            FireAlert(REBIRTH_ENTRY, 0)
            local prealert  = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
            local coneTimes = (currentDifficulty == 16) and BELOREN_CONE_M or BELOREN_CONE_NM
            ScheduleBeloCones(coneTimes, prealert, currentEncounterID)
            if not hasBWOrDBM then
                SchedulePhaseTimers(BELOREN_PHASE_TIMERS)
            end
        end

    -- ── PLAYER_REGEN_ENABLED ─────────────────────────────────
    elseif event == "PLAYER_REGEN_ENABLED" then
        if currentEncounterID then return end
        CancelAll()
        lastSeenCast = {}

    -- ── UNIT_SPELLCAST (boss1-boss5) ─────────────────────────
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not currentEncounterID then return end
        if hasBWOrDBM then return end  -- BW/DBM gèrent déjà le pre-alert, éviter le double
        local unit, castGUID, spellID = ...
        if type(spellID) ~= "number" then return end
        -- spellID peut être une "secret key" sur certains boss — pcall pour éviter le crash
        local ok, entry = pcall(function() return SM.SpellIndex and SM.SpellIndex[spellID] end)
        if not ok or not entry then return end
        OnRealCast(spellID, entry)
    end
end)

-- ============================================================
-- HOOK BIGWIGS
-- ============================================================
ProcessBWBar = function(key, barText, barTime)
    if not currentEncounterID then return end
    local spellId = nil
    if type(key) == "number" then spellId = key end
    if not spellId and barText then
        local ok, r = pcall(function() return SM.NameToSpellId and SM.NameToSpellId[barText:lower()] end)
        if ok then spellId = r end
    end

    -- Dédup BW double-fire (prédictif + re-sync CLEU dans les 3s)
    if spellId then
        local now = GetTime()
        if lastBWBar[spellId] and (now - lastBWBar[spellId]) < 3 then return end
        lastBWBar[spellId] = now
    end

    -- Belo'ren : Death Drop (1246709, barTime ≤ 8) → fallback si ENCOUNTER_TIMELINE_EVENT_ADDED n'a pas fire
    if currentEncounterID == 3182 and spellId == 1246709 and barTime and barTime <= 8 then
        local now = GetTime()
        if now - phaseDetectLast >= 3 then  -- l'event n'a pas déjà géré cette phase
            phaseDetectLast = now
            currentPhase    = currentPhase + 1
            local prealert  = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
            local isMythic  = (currentDifficulty == 16)
            local coneTimes = isMythic and BELOREN_CONE_M or BELOREN_CONE_NM
            FireAlert(REBIRTH_ENTRY, 0)
            ScheduleBeloCones(coneTimes, prealert, currentEncounterID)
        end
        return  -- ne pas traiter 1246709 comme un sort normal en plus
    end

    if spellId and SM.SpellIndex and SM.SpellIndex[spellId] then
        local entry = SM.SpellIndex[spellId]
        local prealert = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
        if barTime and barTime > prealert then
            local t = C_Timer.NewTimer(barTime - prealert, function()
                if currentEncounterID then FireAlert(entry, prealert) end
            end)
            table.insert(pendingAlerts, t)
        elseif barTime then
            FireAlert(entry, barTime)
        end
    end
end

local function OnBWBar(_, module, key, barText, barTime)
    if not currentEncounterID then
        table.insert(bwBarBuffer, {key=key, barText=barText, barTime=barTime, t=GetTime()})
        return
    end
    ProcessBWBar(key, barText, barTime)
end

-- ============================================================
-- HOOK DBM
-- ============================================================
local dbmHandle = {}
local function OnDBMTimerStart(_, id, timeLeft, timerType, spellId, dbmType, spellName)
    if not currentEncounterID then return end
    if spellId and SM.SpellIndex and SM.SpellIndex[spellId] then
        local entry = SM.SpellIndex[spellId]
        local prealert = (SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
        if timeLeft and timeLeft > prealert then
            local t = C_Timer.NewTimer(timeLeft - prealert, function()
                if currentEncounterID then FireAlert(entry, prealert) end
            end)
            table.insert(pendingAlerts, t)
        elseif timeLeft then
            FireAlert(entry, timeLeft)
        end
    end
end

-- ============================================================
-- INIT
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_START",    "boss1", "boss2", "boss3", "boss4", "boss5")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "boss1", "boss2", "boss3", "boss4", "boss5")

    SolaryMDB.boss_timers = SolaryMDB.boss_timers or {}
    if SolaryMDB.boss_timers.enabled    == nil then SolaryMDB.boss_timers.enabled    = true  end
    if SolaryMDB.boss_timers.prealert_sec == nil then SolaryMDB.boss_timers.prealert_sec = 5 end
    if SolaryMDB.boss_timers.sounds     == nil then SolaryMDB.boss_timers.sounds     = true  end
    if SolaryMDB.boss_timers.raid_warn  == nil then SolaryMDB.boss_timers.raid_warn  = false end

    if BigWigsLoader then
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_StartBar",   OnBWBar)
        BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWipe", function() end)
    end

    if DBM and DBM.RegisterCallback then
        DBM.RegisterCallback(dbmHandle, "DBM_TimerStart", OnDBMTimerStart)
    end
end)

-- ============================================================
-- TANK ALERTS — Lightblinded Vanguard (3180)
-- fenêtre UNIT_SPELLCAST_START + check threat
-- Timings depuis WCL (cast success) minus 3.2s
-- ============================================================
local TAUNT_SPELLS = {
    [115546]=true, -- Provoke (Moine)
    [56222] =true, -- Dark Command (Chevalier de la Mort)
    [185245]=true, -- Torment (Chasseur de démons)
    [2649]  =true, -- Grognement (Druide)
    [6795]  =true, -- Raillerie (Guerrier ancien)
    [355]   =true, -- Provocation (Guerrier)
    [62124] =true, -- Rappel à l'ordre (Paladin)
    [49576] =true, -- Poigne de la mort (Chevalier de la Mort)
}

local TAUNT_TIMES_NM = {29,71,113,127,151,191,243,303,323,346,33,75,115,131,155,175,195,247,307,327,350}
local TAUNT_TIMES_M  = {61,65,115,119,151,155,169,173,223,227,277,281,313,317,331,335,385,389,439,443}

local tauntEntry     = {id=0, en="TAUNT", fr="TAUNT", type="mechanic"}
local tauntFrame     = nil
local tauntTimers    = {}
local tauntBlacklist = {}

CancelTauntAlerts = function()
    for i, t in pairs(tauntTimers) do
        if t and not t:IsCancelled() then t:Cancel() end
        tauntTimers[i] = nil
    end
    if tauntFrame then
        tauntFrame:UnregisterEvent("UNIT_SPELLCAST_START")
    end
    tauntBlacklist = {}
end

SetupTauntAlerts = function(difficulty)
    if SolaryMDB.taunt_alerts_enabled == false then return end
    if UnitGroupRolesAssigned("player") ~= "TANK" then return end

    if not tauntFrame then
        tauntFrame = CreateFrame("Frame")
        tauntFrame:SetScript("OnEvent", function(_, e, u, _, spellID)
            if e == "UNIT_SPELLCAST_START" then
                if not u:find("^nameplate%d") then return end
                if not C_NamePlate.GetNamePlateForUnit(u) then return end
                if tauntBlacklist[u] then return end
                tauntBlacklist[u] = true
                tauntFrame:UnregisterEvent("UNIT_SPELLCAST_START")
                local threat = UnitThreatSituation("player", u)
                if threat and threat >= 2 then return end
                FireAlert(tauntEntry, 0)
                SM.TTS("Taunt")
                C_Timer.After(7, function() tauntBlacklist = {} end)
            elseif e == "UNIT_SPELLCAST_SUCCEEDED" and TAUNT_SPELLS[spellID] then
                tauntBlacklist = {}
            end
        end)
        tauntFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end

    local times = (difficulty == 16) and TAUNT_TIMES_M or TAUNT_TIMES_NM
    for i, t in ipairs(times) do
        local fireAt = t - 3.2
        if fireAt > 0 then
            tauntTimers[i] = C_Timer.NewTimer(fireAt, function()
                if currentEncounterID ~= 3180 then return end
                tauntFrame:RegisterEvent("UNIT_SPELLCAST_START")
                C_Timer.After(0.4, function()
                    tauntFrame:UnregisterEvent("UNIT_SPELLCAST_START")
                end)
                C_Timer.After(7, function() tauntBlacklist = {} end)
            end)
        end
    end
end

-- ============================================================
-- FONCTIONS PUBLIQUES
-- ============================================================
function BT.Reset()
    CancelAll()
    currentEncounterID   = nil
    currentEncounterName = nil
    currentDifficulty    = nil
end

function BT.GetCurrentBoss()
    return currentEncounterID, currentEncounterName
end

function BT.IsActive()
    return currentEncounterID ~= nil
end

function BT.TestEncounter(encounterID, difficulty)
    encounterID = encounterID or 3306
    difficulty  = difficulty  or 15
    SM.Print(string.format("Test BossTimer — encID=%d diff=%d", encounterID, difficulty))
    CancelAll()
    currentEncounterID   = encounterID
    currentEncounterName = "TEST"
    currentDifficulty    = difficulty
    pullTime             = GetTime()
    ScheduleBossTimers(encounterID, difficulty)
end
