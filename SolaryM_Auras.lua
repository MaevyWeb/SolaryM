-- SolaryM_Auras.lua
-- Détection des debuffs normaux via COMBAT_LOG (SPELL_AURA_APPLIED)
-- Les Private Auras Blizzard ne sont PAS accessibles programmatiquement
-- On détecte uniquement les debuffs normaux par spell ID

local auraContainer
local auraLocked = true
local auraRows   = {}
local auraRowSeq = 0

local function EnsureAuraContainer()
    if auraContainer then return end
    auraContainer = CreateFrame("Frame", "SolaryMAuraContainer", UIParent)
    auraContainer:SetSize(350, 35)
    auraContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    auraContainer:SetFrameStrata("HIGH")
    auraContainer:EnableMouse(false)
end

local function LayoutAuraRows()
    if not auraContainer then return end
    local y = 0
    for i = #auraRows, 1, -1 do
        local a = auraRows[i]
        if a.frame and a.frame:IsShown() then
            a.frame:ClearAllPoints()
            a.frame:SetPoint("BOTTOMLEFT", auraContainer, "BOTTOMLEFT", 0, y)
            y = y + 32 + 3
        end
    end
    auraContainer:SetSize(350, math.max(35, y))
end

local function RemoveAuraRow(id)
    for i, a in ipairs(auraRows) do
        if a.id == id then
            if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
            if a.frame then
                UIFrameFadeOut(a.frame, 0.2, 1, 0)
                local f = a.frame
                C_Timer.NewTimer(0.2, function() f:Hide() end)
            end
            table.remove(auraRows, i)
            C_Timer.NewTimer(0.25, LayoutAuraRows)
            return
        end
    end
end

function SM.ShowAuraCallout(callout, expirationTime)
    EnsureAuraContainer()
    auraRowSeq = auraRowSeq + 1
    local id = auraRowSeq
    local f = CreateFrame("Frame", nil, auraContainer)
    f:SetSize(350, 32); f:SetAlpha(0); f:EnableMouse(false)
    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    lbl:SetPoint("LEFT", f, "LEFT", 0, 0)
    lbl:SetTextColor(0.3, 1, 0.9, 1)
    local rowData = { id=id, frame=f, lbl=lbl, callout=callout, expirationTime=expirationTime }
    table.insert(auraRows, 1, rowData)
    LayoutAuraRows()
    f:Show(); UIFrameFadeIn(f, 0.12, 0, 1)
    if expirationTime and expirationTime > GetTime() then
        rowData.ticker = C_Timer.NewTicker(0.05, function()
            local tl = math.max(0, expirationTime - GetTime())
            if     tl <= 1 then lbl:SetTextColor(1, 0.2, 0.1, 1)
            elseif tl <= 3 then lbl:SetTextColor(1, 0.65, 0.1, 1)
            else               lbl:SetTextColor(0.3, 1, 0.9, 1) end
            lbl:SetText(callout .. " (" .. string.format("%.1f", tl) .. ")")
            if tl <= 0 then rowData.ticker:Cancel(); RemoveAuraRow(id) end
        end)
    else
        lbl:SetText(callout)
        C_Timer.NewTimer(8, function() RemoveAuraRow(id) end)
    end
    return id
end

function SM.HideAuraCallout(id) if id then RemoveAuraRow(id) end end

local function ClearAllAuraRows()
    for _, a in ipairs(auraRows) do
        if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
        if a.frame then a.frame:Hide() end
    end
    auraRows = {}
end

-- ============================================================
-- DB DEBUFFS
-- ============================================================
SM.AuraDB = {
    { id=391977,  name="Oversurge",            callout="OUT DU RAID",         note="" },
    { id=386201,  name="Corrupted Mana",        callout="SORS DE LA ZONE",     note="" },
    { id=396716,  name="Splinterbark",          callout="BIG DOT",             note="" },
    { id=377009,  name="Deafening Screech",     callout="BIG DOT TEST",        note="" },
    { id=376467,  name="Gale Force",            callout="BUFFED DPS TEST",     note="" },
    { id=389011,  name="Overwhelming Power",    callout="STACKS OF HASTE",     note="" },
    { id=389007,  name="Wild Energy",           callout="BIG DOT",             note="" },
    { id=389033,  name="Lasher Toxin",          callout="BIG DOT - DEFENSIVE", note="" },
    { id=1249263, name="Despotic Command",      callout="BORDS + DISPEL",      note="" },
    { id=1260519, name="Twisting Obscurity",    callout="DoT SUR TOI",         note="" },
    { id=1249396, name="Final Verdict",         callout="VULNÉRABLE",          note="" },
    { id=1249397, name="Shield of Righteous",   callout="VULNÉRABLE",          note="" },
    { id=1258612, name="Null Corona",           callout="ABSORB SUR TOI",      note="" },
    { id=1249200, name="Dread Breath",          callout="OUT DU RAID",         note="" },
    { id=1246621, name="Caustic Phlegm",        callout="DoT SUR TOI",         note="" },
    { id=247816,  name="Chains of Subjugation", callout="SPREAD",              note="" },
    { id=69242,   name="Icy Chains",            callout="CHAINES",             note="" },
    { id=69075,   name="Mark of Rimefang",      callout="MARQUE GIVRE",        note="" },
    { id=1228198, name="Corroding Spittle",     callout="DoT CORROSIF",        note="" },
}

SM.AuraIndex = {}
for _, e in ipairs(SM.AuraDB) do SM.AuraIndex[e.id] = e end

-- ============================================================
-- DÉTECTION VIA COMBAT LOG
-- ============================================================
local activeAuraAlerts = {}
local playerGUID = nil

local clogFrame = CreateFrame("Frame")
-- Les RegisterEvent se font dans PLAYER_LOGIN plus bas

clogFrame:SetScript("OnEvent", function(self, event)
    if event == "ENCOUNTER_END" or event == "PLAYER_REGEN_ENABLED" then
        for _, id in pairs(activeAuraAlerts) do SM.HideAuraCallout(id) end
        activeAuraAlerts = {}
        ClearAllAuraRows()
        return
    end
    -- Combat log
    local _, subEvent, _, _, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if destGUID ~= playerGUID then return end

    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_APPLIED_DOSE" then
        local entry = SM.AuraIndex[spellId]
        if entry then
            local callout = (SolaryMDB.auras and SolaryMDB.auras[spellId]) or entry.callout
            local expTime = nil
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
            if auraData and auraData.expirationTime and auraData.expirationTime > 0 then
                expTime = auraData.expirationTime
            end
            if activeAuraAlerts[spellId] then SM.HideAuraCallout(activeAuraAlerts[spellId]) end
            activeAuraAlerts[spellId] = SM.ShowAuraCallout(callout, expTime)
        end
        -- Hook dispel via Notes
        if SM.Notes and SM.Notes.OnAuraApplied then
            local _, _, _, _, _, _, _, _, targetName = CombatLogGetCurrentEventInfo()
            SM.Notes.OnAuraApplied(spellId, targetName)
        end
    elseif subEvent == "SPELL_AURA_REMOVED" then
        if SM.AuraIndex[spellId] and activeAuraAlerts[spellId] then
            SM.HideAuraCallout(activeAuraAlerts[spellId])
            activeAuraAlerts[spellId] = nil
        end
        if SM.Notes and SM.Notes.OnAuraRemoved then
            SM.Notes.OnAuraRemoved(spellId)
        end
    end
end)

-- ============================================================
-- MOVER
-- ============================================================
local moverAura = nil

local function MakeMoverFrame(container, label)
    local m = CreateFrame("Frame", nil, container)
    m:SetAllPoints(container)
    local bg = m:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.05, 0.7)
    for _, t in ipairs({
        {"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},
        {"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0},
    }) do
        local l = m:CreateTexture(nil,"BORDER")
        l:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
    end
    local lbl = m:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetPoint("CENTER"); lbl:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
    lbl:SetText(label)
    m:Hide()
    return m
end

function SM.ToggleAuraLock()
    EnsureAuraContainer()
    auraLocked = not auraLocked
    if auraLocked then
        auraContainer:EnableMouse(false); auraContainer:SetMovable(false)
        auraContainer:SetScript("OnDragStart", nil); auraContainer:SetScript("OnDragStop", nil)
        if moverAura then moverAura:Hide() end
        for i = #auraRows, 1, -1 do
            if auraRows[i].isTest then
                if auraRows[i].ticker and not auraRows[i].ticker:IsCancelled() then auraRows[i].ticker:Cancel() end
                if auraRows[i].frame then auraRows[i].frame:Hide() end
                table.remove(auraRows, i)
            end
        end
        LayoutAuraRows()
    else
        auraContainer:EnableMouse(true); auraContainer:SetMovable(true)
        auraContainer:RegisterForDrag("LeftButton")
        auraContainer:SetScript("OnDragStart", auraContainer.StartMoving)
        auraContainer:SetScript("OnDragStop",  auraContainer.StopMovingOrSizing)
        if not moverAura then moverAura = MakeMoverFrame(auraContainer, "SolaryM — Callouts Aura") end
        moverAura:Show()
        auraRowSeq = auraRowSeq + 1
        local id = auraRowSeq
        local f = CreateFrame("Frame", nil, auraContainer)
        f:SetSize(350, 32); f:EnableMouse(false)
        local lbl = f:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
        lbl:SetPoint("LEFT", f, "LEFT", 0, 0)
        lbl:SetTextColor(0.3, 1, 0.9, 1)
        lbl:SetText("OUT DU RAID (8.0)")
        table.insert(auraRows, 1, { id=id, frame=f, lbl=lbl, isTest=true })
        LayoutAuraRows(); f:Show()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then return end
    EnsureAuraContainer()
    SolaryMDB = SolaryMDB or {}
    SolaryMDB.auras = SolaryMDB.auras or {}
    -- RegisterEvent ici — seul endroit safe dans Midnight
    playerGUID = UnitGUID("player")
    clogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    clogFrame:RegisterEvent("ENCOUNTER_END")
    clogFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end)
