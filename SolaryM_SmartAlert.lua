-- SolaryM_SmartAlert.lua — Alertes intelligentes (couleur debuff, soak par groupe)
-- Ajouter une mécanique : insérer un bloc dans SA.Mechanics avec type='aura_color' ou 'group_soak'

SM.SmartAlert = SM.SmartAlert or {}
local SA = SM.SmartAlert

-- ============================================================
-- CONFIG — éditée via le panel Boss Timers
-- SolaryMDB.smart_alerts[spellID] = { enabled=true, ... }
-- ============================================================

-- ============================================================
-- DÉFINITIONS DES MÉCANIQUES INTELLIGENTES
-- type = "aura_color"   → selon l'ID du debuff appliqué au joueur
-- type = "group_soak"   → selon groupe impair/pair du joueur
-- ============================================================
SA.Mechanics = {


    -- ── Chimaerus the Undreamt God ────────────────────────
    -- Alndust Upheaval : groupes 1&2 sur casts impairs, groupes 3&4 sur casts pairs
    -- Phases à 0 / 227 / 454 / 681s — Heroic : 2 casts/phase, Mythic : 3 casts/phase
    {
        id        = "chimaerus_soak",
        boss      = "Chimaerus the Undreamt God",
        encID     = 3306,
        label     = "Soak Chimaerus",
        desc_fr   = "Groupes 1&2 soakent les casts impairs, groupes 3&4 les pairs",
        desc_en   = "Groups 1&2 soak odd casts, groups 3&4 soak even casts",
        type      = "group_soak_fixed",
        spellID   = 1262289,
        -- Heroic : 19 + 91 par phase (× 4 phases)
        timers_heroic = { 19, 91, 246, 318, 473, 545, 700, 772 },
        -- Mythic  : 18.7 + 91.4 + 155.6 par phase — phases à 0 / 256.3 / 512.6 / 768.9s
        -- Phases 1+2 confirmées via logs, phases 3+4 extrapolées
        timers_mythic = { 18.7, 91.4, 155.6, 275.0, 347.8, 411.9, 531.3, 604.0, 668.2, 787.6, 860.3, 924.5 },
        duration  = 8,
    },

    -- ── Belo'ren, Child of Al'ar ───────────────────────────
    -- Voidlight Convergence : affiche LUMIÈRE ou OMBRE selon la plume assignée
    -- Détection via filtrage des auras HARMFUL non-player
    {
        id        = "beloren_feather",
        boss      = "Belo'ren, Child of Al'ar",
        encID     = 3182,
        label     = "Light / Void Feather",
        desc_fr   = "Affiche LUMIÈRE ou OMBRE lors de l'assignation de la plume",
        desc_en   = "Shows LIGHT or VOID when the feather is assigned",
        type      = "beloren_feather",
        spellID   = 1243559,
        duration  = 5,
    },

}


-- ============================================================
-- ÉTAT RUNTIME
-- ============================================================
local activeEncID    = nil
local activeTimers   = {}  -- timers C_Timer en cours

-- ============================================================
-- HELPERS
-- ============================================================
local function IsEnabled(mechID)
    return SolaryMDB.smart_alerts and SolaryMDB.smart_alerts[mechID] ~= false
end

local function GetMySubGroup()
    -- Utilise SM.Groups.GetMySubgroup si disponible
    if SM.Groups and SM.Groups.GetMySubgroup then
        return SM.Groups.GetMySubgroup() or 1
    end
    -- Fallback direct
    local name = UnitName("player")
    for i = 1, 40 do
        local name2, _, subgroup = GetRaidRosterInfo(i)
        if name2 == name and subgroup then return subgroup end
    end
    return 1
end

-- Alerte visuelle avec icône optionnelle
local function ShowColorAlert(callout, color, iconPath, duration)
    if SM.ShowTimedAlert then
        SM.ShowTimedAlert(callout, nil, duration or 5)
    end
    SM.PlaySoundForCallout(callout)
end

-- ============================================================
-- TYPE : group_soak_fixed
-- Timers fixes depuis le pull, groupes 1&2 vs 3&4 en alternance
-- ============================================================
local function StartGroupSoakFixed(mech, difficultyID)
    if not IsEnabled(mech.id) then return end

    local timers
    if difficultyID == 16 then
        timers = mech.timers_mythic or mech.timers
    else
        timers = mech.timers_heroic or mech.timers
    end

    for castIndex, timeFromPull in ipairs(timers or {}) do
        -- Alert X secondes avant la mécanique (prealert)
        local prealert = SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec or 5
        local delay = timeFromPull - prealert

        if delay >= 0 then
            local t = C_Timer.NewTimer(delay, function()
                if not activeEncID then return end

                -- Cast impair → groupes 1&2 soakent, cast pair → groupes 3&4
                local isOddCast = (castIndex % 2 == 1)

                -- Alerte visuelle personnalisée selon le groupe du joueur
                local subgroup = GetMySubGroup()
                local iMyTurn  = (isOddCast and subgroup <= 2) or (not isOddCast and subgroup >= 3)
                local msg
                if iMyTurn then
                    msg = "|cFF00FF00SOAK|r"
                else
                    msg = (SM.LANG == "fr") and "|cFFFF4444SOAK PAS|r" or "|cFFFF4444DONT SOAK|r"
                end
                ShowColorAlert(msg, nil, nil, mech.duration)
            end)
            table.insert(activeTimers, t)
        end
    end
end

-- ============================================================
-- ACTIVATION PAR ENCOUNTER
-- ============================================================
local function OnEncounterStart(encID, difficultyID)
    activeEncID = encID

    -- Annuler les anciens timers
    for _, t in ipairs(activeTimers) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    activeTimers = {}

    for _, mech in ipairs(SA.Mechanics) do
        if mech.encID == encID then
            if mech.type == "group_soak_fixed" then
                StartGroupSoakFixed(mech, difficultyID)
            end
        end
    end
end

local function OnEncounterEnd()
    activeEncID = nil
    for _, t in ipairs(activeTimers) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    activeTimers = {}
end

-- ============================================================
-- FRAME EVENT
-- ============================================================
local saFrame = CreateFrame("Frame")
saFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encID, _, difficultyID = ...
        OnEncounterStart(encID, difficultyID)
    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd()
    end
end)

-- RegisterEvent dans PLAYER_ENTERING_WORLD (protections levées)
local _saPEW = CreateFrame("Frame")
_saPEW:RegisterEvent("PLAYER_ENTERING_WORLD")
_saPEW:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_ENTERING_WORLD" then return end
    saFrame:RegisterEvent("ENCOUNTER_START")
    saFrame:RegisterEvent("ENCOUNTER_END")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- ============================================================
-- INIT DB
-- ============================================================
local initSA = CreateFrame("Frame")
initSA:RegisterEvent("PLAYER_LOGIN")
initSA:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    SolaryMDB.smart_alerts = SolaryMDB.smart_alerts or {}
    -- Activer toutes les mécaniques par défaut
    for _, mech in ipairs(SA.Mechanics) do
        if SolaryMDB.smart_alerts[mech.id] == nil then
            SolaryMDB.smart_alerts[mech.id] = true
        end
    end
end)

-- ============================================================
-- API PUBLIQUE (pour le panel)
-- ============================================================
function SA.GetMechanics()
    return SA.Mechanics
end

function SA.SetEnabled(mechID, enabled)
    SolaryMDB.smart_alerts = SolaryMDB.smart_alerts or {}
    SolaryMDB.smart_alerts[mechID] = enabled
    
end

function SA.IsEnabled(mechID)
    return IsEnabled(mechID)
end
