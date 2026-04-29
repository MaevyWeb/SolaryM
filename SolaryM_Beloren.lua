-- SolaryM_Beloren.lua
-- Détection Light/Void Feather sur Belo'ren (encID 3182)
-- Technique: filtrer HARMFUL|PLAYER pour isoler l'aura du boss

SM.Beloren = SM.Beloren or {}
local BL = SM.Beloren

local ENC_ID      = 3182
local inEncounter = false
local alertFrame  = nil
local alertTimer  = nil
local lastAuraID  = nil

-- ============================================================
-- AFFICHAGE —
-- ============================================================
local function EnsureAlert()
    if alertFrame then return end
    alertFrame = CreateFrame("Frame", "SolaryMBelorenAlert", UIParent)
    alertFrame:SetSize(120, 60)
    alertFrame:SetFrameStrata("HIGH")
    alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    alertFrame:EnableMouse(false)

    local lbl = alertFrame:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 48, "OUTLINE")
    lbl:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
    lbl:SetJustifyH("CENTER")
    lbl:SetShadowColor(0, 0, 0, 1)
    lbl:SetShadowOffset(2, -2)
    alertFrame._lbl = lbl
    alertFrame:Hide()
end

local function ShowFeatherAlert(iconID)
    EnsureAlert()
    if alertTimer then alertTimer:Cancel(); alertTimer = nil end

    -- Afficher uniquement l'icône via |T|
    -- iconID est secret mais |T| accepte les secret values directement
    local ok, ic = pcall(function()
        return "|T"..tostring(iconID)..":28:28|t"
    end)
    alertFrame._lbl:SetText(ok and ic or "?")
    alertFrame:SetAlpha(1)
    alertFrame:Show()

    alertTimer = C_Timer.NewTimer(5, function()
        UIFrameFadeOut(alertFrame, 0.5, 1, 0)
        C_Timer.NewTimer(0.5, function() if alertFrame then alertFrame:Hide() end end)
    end)
end

local function HideFeatherAlert()
    if alertTimer then alertTimer:Cancel(); alertTimer = nil end
    if alertFrame and alertFrame:IsShown() then
        UIFrameFadeOut(alertFrame, 0.3, 1, 0)
        C_Timer.NewTimer(0.3, function() if alertFrame then alertFrame:Hide() end end)
    end
end

-- ============================================================
-- DÉTECTION
-- ============================================================
local function ScanFeather()
    local playerCast = {}
    local ids = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
    if ids then
        for _, id in ipairs(ids) do playerCast[id] = true end
    end

    local auras = C_UnitAuras.GetUnitAuras("player", "HARMFUL", 10,
        Enum.UnitAuraSortRule.ExpirationOnly,
        Enum.UnitAuraSortDirection.Reverse)

    if not auras then HideFeatherAlert(); return end

    for _, aura in ipairs(auras) do
        if not playerCast[aura.auraInstanceID] then
            -- Aura du boss — afficher une seule fois par application
            if lastAuraID == aura.auraInstanceID then return end
            lastAuraID = aura.auraInstanceID
            ShowFeatherAlert(aura.icon)
            return
        end
    end
end

-- ============================================================
-- SIMULATION (panel Go button)
-- ============================================================
local FEATHER_SPELL = { light = 1243559, void = 1243560 }

function BL._simulate(which)
    EnsureAlert()
    if alertTimer then alertTimer:Cancel(); alertTimer = nil end

    local spellID  = FEATHER_SPELL[which]
    local iconPath = spellID and C_Spell.GetSpellTexture(spellID)
    if iconPath then
        alertFrame._lbl:SetText(string.format("|T%s:28:28|t", iconPath))
    else
        alertFrame._lbl:SetText(which == "light" and "|cFFFFEE44LIGHT|r" or "|cFF8833FFVOID|r")
    end

    alertFrame:SetAlpha(1)
    alertFrame:Show()
    alertTimer = C_Timer.NewTimer(5, function()
        UIFrameFadeOut(alertFrame, 0.5, 1, 0)
        C_Timer.NewTimer(0.5, function() if alertFrame then alertFrame:Hide() end end)
    end)
end

-- ============================================================
-- EVENTS — gate sur ENCOUNTER_START pour limiter aux pulls
-- ============================================================
local blFrame = CreateFrame("Frame")
blFrame:RegisterEvent("ENCOUNTER_START")
blFrame:RegisterEvent("ENCOUNTER_END")
blFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
blFrame:RegisterUnitEvent("UNIT_AURA", "player")

blFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encID = ...
        if encID == ENC_ID then
            inEncounter = true
            lastAuraID  = nil
        end

    elseif event == "ENCOUNTER_END" then
        local encID = ...
        if encID == ENC_ID then
            inEncounter = false
            lastAuraID  = nil
            HideFeatherAlert()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        inEncounter = false
        lastAuraID  = nil
        HideFeatherAlert()

    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if unit ~= "player" or not inEncounter then return end
        if updateInfo and (updateInfo.addedAuras or updateInfo.isFullUpdate) then
            ScanFeather()
        end
    end
end)
