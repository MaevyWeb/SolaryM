-- SolaryM_MythicCasts.lua:
--   • Chaque row = StatusBar (texture transparente) + texte overlay
--   • bar:SetTimerDuration(activeObj) → bar:SetScript("OnUpdate", function(self)
--       self:GetTimerDuration():GetRemainingDuration()  -- number ordinaire, non-secret
--   Cela contourne les "secret number values" (taint protection Blizzard sur UnitCastingInfo).

SM.MythicCasts = SM.MythicCasts or {}
local MC = SM.MythicCasts

local CAST_W  = 300
local ROW_H   = 38
local ROW_GAP = 2
local MAX_ROWS = 8

local interp = nil  -- Enum.StatusBarInterpolation.None, résolu au premier usage

local container  = nil
local moverFrame = nil
local locked     = true

local activeBars  = {}   -- unit -> bar (StatusBar)
local usedBars    = {}   -- liste ordonnée pour layout
local barPool     = {}   -- réutilisation

local activeCallouts = {}
local inInstance     = false
local MC_DEBUG       = false
local eventsRegistered = false

-- ============================================================
-- POSITION
-- ============================================================
local function SavePos()
    if not container or not SolaryMDB then return end
    SolaryMDB.frames = SolaryMDB.frames or {}
    local point, _, rp, x, y = container:GetPoint()
    if point then
        SolaryMDB.frames["mythic_casts"] = { point=point, rp=rp, x=math.floor(x), y=math.floor(y) }
    end
end

local function LoadPos()
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["mythic_casts"]
    container:ClearAllPoints()
    if s and s.x then
        container:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        container:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end
end

local function EnsureContainer()
    if container then return end
    container = CreateFrame("Frame", "SolaryMMythicCastsContainer", UIParent)
    container:SetSize(CAST_W, ROW_H)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(false)
    LoadPos()
end

-- ============================================================
-- LAYOUT
-- ============================================================
local function ReLayout()
    if not container then return end
    local y = 0
    for i = #usedBars, 1, -1 do
        local b = usedBars[i]
        if b and b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, y)
            y = y + ROW_H + ROW_GAP
        end
    end
    container:SetSize(CAST_W, math.max(ROW_H, y))
    if moverFrame then moverFrame:SetAllPoints(container) end
end

-- ============================================================
-- BAR POOL
-- ============================================================
local function InitBar(bar)
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.06, 0.08, 0.80)
    bar._bg = bg

    -- Icône
    local iconSize = ROW_H - 6
    local iconTex = bar:CreateTexture(nil, "OVERLAY")
    iconTex:SetSize(iconSize, iconSize)
    iconTex:SetPoint("LEFT", bar, "LEFT", 4, 0)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar._icon = iconTex

    -- Accent (barre colorée à gauche)
    local accent = bar:CreateTexture(nil, "OVERLAY")
    accent:SetSize(2, ROW_H - 2)
    accent:SetPoint("LEFT", bar, "LEFT", 1, 0)
    bar._accent = accent

    local textX = iconSize + 10

    -- Nom du sort (pas de contrainte droite, la target s'ancre à sa suite)
    local lbl = bar:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    lbl:SetPoint("LEFT", bar, "LEFT", textX, 0)
    lbl:SetJustifyH("LEFT")
    lbl:SetTextColor(1, 1, 1, 1)
    bar._lbl = lbl

    -- Target : inline à droite du nom (SetTextColor accepte les secret values)
    local targetLbl = bar:CreateFontString(nil, "OVERLAY")
    targetLbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    targetLbl:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    targetLbl:SetJustifyH("LEFT")
    targetLbl:SetTextColor(0.70, 0.70, 0.75, 1)
    bar._targetLbl = targetLbl

    -- Timer : affiché à droite
    local timerLbl = bar:CreateFontString(nil, "OVERLAY")
    timerLbl:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    timerLbl:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    timerLbl:SetJustifyH("RIGHT")
    timerLbl:SetTextColor(1, 1, 1, 1)
    bar._timerLbl = timerLbl
end

local function AcquireBar()
    if not container then return nil end
    local bar
    if #barPool > 0 then
        bar = table.remove(barPool)
        bar:SetParent(container)
    else
        bar = CreateFrame("StatusBar", nil, container)
        bar:SetClampedToScreen(true)
        bar:SetMinMaxValues(0, 1); bar:SetValue(1)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        InitBar(bar)
    end
    bar:SetSize(CAST_W, ROW_H)
    bar:SetAlpha(0)
    bar:Show()
    return bar
end

local function ReleaseBar(bar)
    if not bar then return end
    bar:SetScript("OnUpdate", nil)
    bar:Hide(); bar:ClearAllPoints()
    if bar._lbl then bar._lbl:SetText("") end
    if bar._timerLbl then bar._timerLbl:SetText("") end
    if bar._targetLbl then bar._targetLbl:SetText(""); bar._targetLbl:Hide() end
    table.insert(barPool, bar)
end

-- ============================================================
-- AFFICHER / METTRE À JOUR
-- ============================================================
-- ShowBar : PREVIEW uniquement (durée numérique, valeurs sûres)
local function ShowBar(unit, spellName, icon, duration, targetName)
    local bar = AcquireBar()
    if not bar then return end
    bar._label    = spellName
    bar._isPreview = true
    if bar._icon then bar._icon:SetTexture(icon) end
    local normC = CreateColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.90)
    local sbTex = bar:GetStatusBarTexture()
    if sbTex then sbTex:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.70) end
    if bar._accent then bar._accent:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.90) end
    local displayName = targetName and (spellName .. " |cffffffff- " .. targetName .. "|r") or spellName
    bar._label = displayName
    if bar._lbl then bar._lbl:SetText(displayName); bar._lbl:SetTextColor(1,1,1,1) end
    if bar._targetLbl then bar._targetLbl:SetText(""); bar._targetLbl:Hide() end
    activeBars[unit] = bar
    table.insert(usedBars, 1, bar)
    ReLayout()
    UIFrameFadeIn(bar, 0.10, 0, 1)
    local startTime = GetTime()
    local lbl = bar._lbl
    bar:SetScript("OnUpdate", function(self)
        if not activeBars[unit] then self:SetScript("OnUpdate", nil); return end
        local tl = math.max(0, duration - (GetTime() - startTime))
        if tl <= 1.5 then lbl:SetTextColor(1, 0.2, 0.1, 1)
        elseif tl <= 3 then lbl:SetTextColor(1, 0.65, 0.1, 1)
        else lbl:SetTextColor(1, 1, 1, 1) end
        lbl:SetText(string.format(tl >= 10 and "%s (%.0f)" or "%s (%.1f)", self._label, tl))
        if tl <= 0 then
            self:SetScript("OnUpdate", nil)
            UIFrameFadeOut(self, 0.2, 1, 0)
            C_Timer.NewTimer(0.2, function() self:Hide() end)
            activeBars[unit] = nil
            for i, b in ipairs(usedBars) do if b == self then table.remove(usedBars, i); break end end
            C_Timer.NewTimer(0.25, ReLayout)
        end
    end)
end

local function RemoveBar(unit)
    activeCallouts[unit] = nil
    local bar = activeBars[unit]
    if not bar then return end
    bar:SetScript("OnUpdate", nil)
    UIFrameFadeOut(bar, 0.15, 1, 0)
    C_Timer.NewTimer(0.15, function()
        bar:Hide()
        ReleaseBar(bar)
    end)
    activeBars[unit] = nil
    for i, b in ipairs(usedBars) do if b == bar then table.remove(usedBars, i); break end end
    C_Timer.NewTimer(0.2, ReLayout)
end

local function HideAll()
    for unit, bar in pairs(activeBars) do
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
        ReleaseBar(bar)
    end
    wipe(activeBars); wipe(usedBars); wipe(activeCallouts)
    if container then ReLayout() end
end

-- ============================================================
-- SPELL BLACKLIST — hardcodé, modifier ici directement
-- Activer MC_DEBUG pour voir les IDs dans le chat : /run SM.MythicCasts.ToggleDebug()
-- ============================================================
local MC_BLACKLIST = {
    -- Vaelgor & Ezzorak
    [1245175] = true,  -- Trait du Vide

    -- Chimaerus
    [1261997] = true,  -- Trait d'Essence
}

-- ============================================================
-- CALLOUTS
-- ============================================================
MC.Callouts = {
    [1243743] = { text = "STOP CAST" },  -- Demiar — Interrupting Tremor
}

-- ============================================================
-- DÉTECTION
-- ============================================================
local function IsEnabled()
    return SolaryMDB.mythic_casts_enabled ~= false
end

local function UpdateCast(unit)
    if not IsEnabled() then return end
    if not inInstance then return end
    if not UnitCanAttack("player", unit) then RemoveBar(unit); return end
    if UnitIsUnit(unit, "player") then RemoveBar(unit); return end
    -- Ignorer les mobs hors combat
    if not UnitAffectingCombat(unit) and not UnitExists(unit .. "target") then
        RemoveBar(unit); return
    end

    local objCast    = UnitCastingDuration and UnitCastingDuration(unit)
    local objChannel = UnitChannelDuration  and UnitChannelDuration(unit)
    local activeObj  = objCast or objChannel
    local isChannel  = (objChannel ~= nil and objCast == nil)
    if not activeObj then RemoveBar(unit); return end

    -- Lire les infos du cast (avant d'acquérir la bar pour le check blacklist)
    local name, _, texture, _, _, _, notInterruptible, spellID
    if isChannel then
        name, _, texture, _, _, _, notInterruptible, spellID = UnitChannelInfo(unit)
    else
        name, _, texture, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
    end
    if not name then RemoveBar(unit); return end

    -- Blacklist check : tonumber() convertit les "secret keys" WoW en vrai number Lua indexable
    local safeSpellID = tonumber(tostring(spellID))
    if safeSpellID and MC_BLACKLIST[safeSpellID] then RemoveBar(unit); return end

    -- Acquérir / réutiliser la bar
    local bar = activeBars[unit]
    if not bar then
        bar = AcquireBar(); if not bar then return end
        activeBars[unit] = bar
        table.insert(usedBars, 1, bar)
        UIFrameFadeIn(bar, 0.10, 0, 1)
        ReLayout()
    end

    if MC_DEBUG then
        SM.Print(string.format("[MC] %s | id=%s name=%s", unit, tostring(spellID), name))
    end

    bar._label = name
    if bar._icon then bar._icon:SetTexture(texture) end
    if bar._lbl then bar._lbl:SetText(name .. " (...)"); bar._lbl:SetTextColor(1,1,1,1) end

    -- Couleur fill + accent : SetVertexColorFromBoolean accepte les secret booleans
    if not interp then
        interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.None or 0
    end
    local intC  = CreateColor(0.55, 0.55, 0.60, 0.90)  -- gris = non-interruptible
    local normC = CreateColor(0.15, 0.85, 0.20, 0.90)  -- vert = interruptible
    local sbTex = bar:GetStatusBarTexture()
    if sbTex then sbTex:SetVertexColorFromBoolean(notInterruptible, intC, normC) end
    if bar._accent then bar._accent:SetVertexColorFromBoolean(notInterruptible, intC, normC) end

    -- Nom du sort
    local lbl      = bar._lbl
    local timerLbl = bar._timerLbl
    if lbl then lbl:SetText(name) end

    -- Target inline (SetTextColor accepte les secret values de UnitSpellTargetClass)
    if bar._targetLbl then
        local tn   = UnitSpellTargetName and UnitSpellTargetName(unit)
        local show = (UnitShouldDisplaySpellTargetName and UnitShouldDisplaySpellTargetName(unit)) or (tn ~= nil)
        if show and tn then
            bar._targetLbl:SetText("- " .. tn)
            local tc = UnitSpellTargetClass and UnitSpellTargetClass(unit)
            if tc then
                local c = C_ClassColor and C_ClassColor.GetClassColor(tc)
                if c then bar._targetLbl:SetTextColor(c.r, c.g, c.b, 1) end
            end
            bar._targetLbl:Show()
        else
            bar._targetLbl:SetText(""); bar._targetLbl:Hide()
        end
    end

    -- SetTimerDuration + OnUpdate
    if bar.SetTimerDuration then
        bar:SetTimerDuration(activeObj, interp, isChannel and 1 or 0)
    end
    bar:SetScript("OnUpdate", function(self)
        if not activeBars[unit] then self:SetScript("OnUpdate", nil); return end
        local dur = self:GetTimerDuration()
        if dur then
            local remaining = dur:GetRemainingDuration()
            local fmt = string.format("%.1fs", remaining)
            -- remaining est un secret number : string.format accepte les secrets, <= non
            -- on repasse par tonumber() sur la string pour obtenir un Lua number normal
            local remainingNum = tonumber(string.format("%.2f", remaining))
            if timerLbl then
                if remainingNum and remainingNum <= 1.5 then timerLbl:SetTextColor(1, 0.2, 0.1, 1)
                elseif remainingNum and remainingNum <= 3 then timerLbl:SetTextColor(1, 0.65, 0.1, 1)
                else                                          timerLbl:SetTextColor(1, 1, 1, 1) end
                timerLbl:SetText(fmt)
            end
        else
            self:SetScript("OnUpdate", nil)
            RemoveBar(unit)
        end
    end)
end

-- ============================================================
-- EVENTS
-- ============================================================
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_STOP",  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local eventFrame = CreateFrame("Frame", "SolaryMMythicCastsFrame")

local function EnableEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    for _, e in ipairs(CAST_EVENTS) do eventFrame:RegisterEvent(e) end
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

local function DisableEvents()
    if not eventsRegistered then return end
    eventsRegistered = false
    eventFrame:UnregisterAllEvents()
    HideAll()
end

local function CheckEnvironment()
    local _, instanceType = IsInInstance()
    inInstance = (instanceType == "party" or instanceType == "raid")
    if MC_DEBUG then
        SM.Print(string.format("[MC] CheckEnv type=%s inInstance=%s enabled=%s",
            tostring(instanceType), tostring(inInstance), tostring(IsEnabled())))
    end
    if inInstance and IsEnabled() then EnableEvents() else DisableEvents() end
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        RemoveBar(unit); return
    end
    if MC_DEBUG and (event == "UNIT_SPELLCAST_START" or event == "NAME_PLATE_UNIT_ADDED") then
        SM.Print(string.format("[MC] EVENT %s unit=%s match=%s",
            event, tostring(unit),
            tostring(unit and string.match(unit, "^nameplate%d+$") ~= nil)))
    end
    if not unit or not string.match(unit, "^nameplate%d+$") then return end
    local isStop = event == "UNIT_SPELLCAST_STOP"
               or event == "UNIT_SPELLCAST_INTERRUPTED"
               or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    if isStop then RemoveBar(unit) else UpdateCast(unit) end
end)

-- ============================================================
-- LIFECYCLE
-- ============================================================
local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycleFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
lifecycleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
lifecycleFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, CheckEnvironment)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        CheckEnvironment()
    elseif event == "PLAYER_REGEN_ENABLED" then
        local rem = {}
        for unit in pairs(activeBars) do
            if not UnitExists(unit) or not UnitAffectingCombat(unit) then
                rem[#rem+1] = unit
            end
        end
        for _, u in ipairs(rem) do RemoveBar(u) end
    end
end)

-- ============================================================
-- INIT
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    if SolaryMDB.mythic_casts_enabled == nil then
        SolaryMDB.mythic_casts_enabled = true
    end
    EnsureContainer()
    if container then container:SetScale(SolaryMDB.mythic_casts_scale or 1.0) end
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- ============================================================
-- MOVE MODE
-- ============================================================
local function MakeMover()
    if moverFrame then return end
    EnsureContainer()
    moverFrame = CreateFrame("Frame", nil, container)
    moverFrame:SetAllPoints(container)
    local bg = moverFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.07, 1)
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,2},{"BOTTOMLEFT","BOTTOMRIGHT",0,2},{"TOPLEFT","BOTTOMLEFT",2,0},{"TOPRIGHT","BOTTOMRIGHT",2,0}}) do
        local l = moverFrame:CreateTexture(nil, "BORDER")
        l:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3], t[4])
    end
    local lbl = moverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    lbl:SetText("SolaryM — Mythic Casts (déplacer)")
    moverFrame:Hide()
end

function MC.Unlock()
    EnsureContainer()
    MakeMover()
    locked = false
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", container.StartMoving)
    container:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    moverFrame:Show()
    local previews = {
        { unit="_prev1", name="Frostbolt",      icon=135846, dur=3.2, target="Maevibro" },
        { unit="_prev2", name="Shadow Bolt",    icon=136197, dur=2.0, target="Erenar"   },
        { unit="_prev3", name="Arcane Missile", icon=136096, dur=5.0, target=nil        },
    }
    for _, p in ipairs(previews) do
        ShowBar(p.unit, p.name, p.icon, p.dur, p.target)
    end
end

function MC.Lock()
    if not container then return end
    locked = true
    container:EnableMouse(false)
    container:SetMovable(false)
    container:SetScript("OnDragStart", nil)
    container:SetScript("OnDragStop",  nil)
    if moverFrame then moverFrame:Hide() end
    HideAll()
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function MC.IsEnabled()  return IsEnabled() end
function MC.SetEnabled(enabled)
    SolaryMDB.mythic_casts_enabled = enabled
    if not enabled then DisableEvents() else CheckEnvironment() end
end
function MC.GetScale()
    return SolaryMDB and SolaryMDB.mythic_casts_scale or 1.0
end
function MC.SetScale(s)
    if not SolaryMDB then return end
    SolaryMDB.mythic_casts_scale = s
    EnsureContainer()
    if container then container:SetScale(s) end
end
function MC.ToggleDebug()
    MC_DEBUG = not MC_DEBUG
    SM.Print("MythicCasts debug: " .. (MC_DEBUG and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
    if MC_DEBUG then
        local _, instanceType = IsInInstance()
        SM.Print(string.format("[MC] State — type=%s inInstance=%s eventsReg=%s enabled=%s",
            tostring(instanceType), tostring(inInstance), tostring(eventsRegistered), tostring(IsEnabled())))
    end
end
