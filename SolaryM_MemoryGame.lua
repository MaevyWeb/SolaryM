-- SolaryM_MemoryGame.lua
-- Combat  : macro /raid <fileDataID> → CHAT_MSG_RAID → MGBridge (handler propre,
--           RegisterEvent depuis timer propre) → SetTexture(tonumber(arg1)).
-- Hors combat : panel → BroadcastMG → CHAT_MSG_ADDON → DisplayRune (SetTexture normal).
SM.MemoryGame = SM.MemoryGame or {}
local MG = SM.MemoryGame

local MG_ADDON_PREFIX = "SOLMG"
C_ChatInfo.RegisterAddonMessagePrefix(MG_ADDON_PREFIX)

-- FileDataIDs WoW —
-- SetTexture(number) ne passe pas par le système de secret strings.
MG.Runes = {
    { name="Fusée",    id=7242384 },
    { name="Ceinture", id=134635  },
    { name="Bracelet", id=340528  },
    { name="Pantalon", id=351033  },
    { name="Tissu",    id=236903  },
}

local PX = { 50,  60,   0, -60, -50 }
local PY = { 50, -25, -70, -25,  50 }

local mainFrame        = nil
local iconDisplay      = {}
local numDisplay       = {}
local sequence         = {}
local hideTimer        = nil
local sequenceOwner    = nil
local lastReceivedTime = {}

-- ============================================================
-- AFFICHAGE LOCAL (hors combat, via CHAT_MSG_ADDON)
-- ============================================================
local function DisplayRune(pos, runeIdx)
    if not mainFrame then return end
    local rune = MG.Runes[runeIdx]
    if not rune then return end
    if not iconDisplay[pos] or not numDisplay[pos] then return end
    iconDisplay[pos]:SetFormattedText("|T%d:256:256|t", rune.id)
    iconDisplay[pos]:Show()
    numDisplay[pos]:SetText(tostring(pos))
    numDisplay[pos]:Show()
    mainFrame:Show()
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(30, function() LocalReset() end)
end

local function HideAll()
    for i = 1, 5 do
        if iconDisplay[i] then iconDisplay[i]:Hide() end
        if numDisplay[i]  then numDisplay[i]:Hide()  end
    end
end

function LocalReset()
    sequence      = {}
    sequenceOwner = nil
    HideAll()
    if mainFrame then mainFrame:Hide() end
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
    SolaryM_MGBridge.Reset()
end

-- ============================================================
-- TRAITEMENT PAYLOAD (CHAT_MSG_ADDON, hors combat)
-- ============================================================
local function ProcessMGPayload(msg, senderName)
    if msg == "reset" then LocalReset(); return end
    if msg == "undo" then
        if sequenceOwner and sequenceOwner ~= senderName then return end
        local pos = #sequence
        if pos > 0 then
            table.remove(sequence, pos)
            if iconDisplay[pos] then iconDisplay[pos]:Hide() end
            if numDisplay[pos]  then numDisplay[pos]:Hide()  end
            if #sequence == 0 and mainFrame then mainFrame:Hide() end
        end
        return
    end
    local runeIdx = tonumber(msg)
    if not runeIdx or runeIdx < 1 or runeIdx > 5 then return end
    if not MG.Runes[runeIdx] then return end
    if sequenceOwner == nil then
        sequenceOwner = senderName
    elseif sequenceOwner ~= senderName then
        return
    end
    if #sequence >= 5 then return end
    local pos = #sequence + 1
    table.insert(sequence, runeIdx)
    DisplayRune(pos, runeIdx)
end

local function OnMGMessage(msg, sender)
    local shortSender = (sender or ""):match("^([^%-]+)") or (sender or "")
    local key = shortSender .. ":" .. msg
    local t = lastReceivedTime[key]
    if t and (GetTime() - t) < 1.0 then return end
    lastReceivedTime[key] = GetTime()
    ProcessMGPayload(msg, shortSender)
end

-- ============================================================
-- CHAT_MSG_ADDON (hors combat uniquement)
-- ============================================================
local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(_, _, arg1, arg2, _, arg4)
    if arg1 == MG_ADDON_PREFIX then OnMGMessage(arg2, arg4) end
end)

-- ============================================================
-- ENVOI hors combat (boutons panel)
-- ============================================================
local function BroadcastMG(payload)
    local payloadStr = tostring(payload)
    local myName = UnitName("player"):match("^([^%-]+)") or UnitName("player")
    ProcessMGPayload(payloadStr, myName)
    lastReceivedTime[myName .. ":" .. payloadStr] = GetTime()
    local channel = UnitInRaid("player") and "RAID" or (UnitInParty("player") and "PARTY" or nil)
    if not channel then return end
    pcall(C_ChatInfo.SendAddonMessage, MG_ADDON_PREFIX, payloadStr, channel)
end

function MG.AddRune(runeIdx) if not SM.IsEditor() then return false end; BroadcastMG(runeIdx); return true end
function MG.RemoveLast()     if not SM.IsEditor() then return end; BroadcastMG("undo") end
function MG.Reset()          if not SM.IsEditor() then return end; BroadcastMG("reset") end

-- Mode test : le bridge gère son propre RegisterEvent
function MG.TestWindow()
    if not SM.IsEditor() then return end
    LocalReset()
    SolaryM_MGBridge.TestWindow()
    SM.Print("|cff00ff00MG: mode test actif 60s — clique tes macros SOLMG_1..5.|r")
end

-- ============================================================
-- DISPLAY FRAME
-- ============================================================
function MG.BuildDisplayFrame()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "SolaryMMGFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(200, 200)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(s) if MG.unlocked then s:StartMoving() end end)
    mainFrame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local pt, _, rp, x, y = s:GetPoint()
        SolaryMDB.mg_pos = { point=pt, rp=rp, x=math.floor(x), y=math.floor(y) }
    end)
    mainFrame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    mainFrame:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.6)

    local s = SolaryMDB and SolaryMDB.mg_pos
    if s and s.x then
        mainFrame:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end

    local bossBg = mainFrame:CreateTexture(nil, "ARTWORK")
    bossBg:SetSize(34, 34); bossBg:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    bossBg:SetTexture("Interface\\Buttons\\WHITE8X8"); bossBg:SetVertexColor(0.8, 0.08, 0.08, 1)

    local bossLbl = mainFrame:CreateFontString(nil, "OVERLAY")
    bossLbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    bossLbl:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
    bossLbl:SetTextColor(1, 1, 1, 1); bossLbl:SetText("BOSS")

    local tankIcon = mainFrame:CreateTexture(nil, "OVERLAY")
    tankIcon:SetSize(34, 34); tankIcon:SetPoint("CENTER", mainFrame, "CENTER", 0, 48)
    tankIcon:SetTexture("Interface\\AddOns\\SolaryM\\Media\\tank_icon.tga")

    for i = 1, 5 do
        -- FontString : SetFormattedText("|T%s:48:48|t", arg1) fonctionne en combat propre
        iconDisplay[i] = mainFrame:CreateFontString(nil, "OVERLAY")
        iconDisplay[i]:SetFont("Fonts\\FRIZQT__.TTF", 1, "")
        iconDisplay[i]:SetSize(256, 256)
        iconDisplay[i]:SetPoint("CENTER", mainFrame, "CENTER", PX[i], PY[i])
        iconDisplay[i]:Hide()

        numDisplay[i] = mainFrame:CreateFontString(nil, "OVERLAY")
        numDisplay[i]:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        numDisplay[i]:SetTextColor(1, 1, 1, 1)
        numDisplay[i]:SetShadowColor(0, 0, 0, 1); numDisplay[i]:SetShadowOffset(1, -1)
        numDisplay[i]:SetPoint("CENTER", mainFrame, "CENTER", PX[i], PY[i] + 24)
        numDisplay[i]:Hide()
    end

    -- Passe les références au bridge (son SetScript lit ces valeurs en contexte propre)
    SolaryM_MGBridge.mainFrame   = mainFrame
    SolaryM_MGBridge.iconDisplay = iconDisplay
    SolaryM_MGBridge.numDisplay  = numDisplay

    mainFrame:Hide()
    return mainFrame
end

-- ============================================================
-- MACROS
-- ============================================================
function MG.CreateMacros()
    if not SM.IsEditor() then return end
    local created, updated, failed = 0, 0, 0
    for i, rune in ipairs(MG.Runes) do
        local name = "SOLMG_"..i
        local idStr = tostring(rune.id)
        local body  = "/raid "..idStr
        local idx = GetMacroIndexByName(name)
        if idx and idx > 0 then
            EditMacro(idx, name, idStr, body); updated = updated + 1
        else
            local r = CreateMacro(name, idStr, body)
            if r and r > 0 then created = created + 1 else failed = failed + 1 end
        end
    end
    if failed > 0 then
        SM.Print(string.format("|cffff8800MG: %d créée(s), %d màj, %d échec(s) — livre de macros plein ?|r", created, updated, failed))
    else
        SM.Print(string.format("|cff00ff00MG: %d créée(s), %d màj. Glisse SOLMG_1..5 sur ta barre.|r", created, updated))
    end
end

function MG.HasSequence() return #sequence > 0 end

function MG.ToggleInputBar()
    SM.Print("|cffaaaaaa/sm mg : utilise les macros SOLMG_1..5 — crée-les via le panel.|r")
end

-- ============================================================
-- PANEL
-- ============================================================
function MG.BuildInputPanel(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    local y = -14

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    title:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    title:SetText("Memory Game — L'ura (Midnight Falls)")
    y = y - 22

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    sub:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    sub:SetJustifyH("LEFT"); sub:SetTextColor(0.45, 0.45, 0.5, 1)
    sub:SetText("Clique les icones dans l'ordre affiché par le boss — broadcasté au raid.")
    y = y - 30

    local function makeSimpleBtn(label, color, payload)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(100, 24)
        local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(unpack(color))
        local lbl = b:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE"); lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(label); lbl:SetTextColor(1, 1, 1, 1)
        b:SetScript("OnClick", function()
            if not SM.IsEditor() then return end
            BroadcastMG(payload)
        end)
        return b
    end

    makeSimpleBtn("Reset",           {0.55,0.08,0.08,1}, "reset"):SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    makeSimpleBtn("Annuler dernier", {0.1,0.2,0.5,1},    "undo"):SetPoint("TOPLEFT", f, "TOPLEFT", 122, y)
    y = y - 36

    local function makeWideBtn(label, color, fn)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w - 28, 24); b:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
        local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(unpack(color))
        local lbl = b:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE"); lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(label); lbl:SetTextColor(1, 1, 1, 1)
        b:SetScript("OnClick", fn)
        y = y - 34
        return b
    end

    makeWideBtn("Créer macros runes (barre d'action en combat)", {0.15,0.4,0.15,1}, function() MG.CreateMacros() end)
    makeWideBtn("Mode test macros (60s) — active avant de cliquer les macros", {0.1,0.35,0.55,1}, function() MG.TestWindow() end)

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(w - 28, 1); sep:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    sep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.3)
    y = y - 14

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    hint:SetTextColor(0.45, 0.45, 0.5, 1); hint:SetText("Clique les icones dans l'ordre :")
    y = y - 24

    local ICON_SIZE, PADDING = 52, 10
    local perRow = math.floor((w - 28) / (ICON_SIZE + PADDING))
    local col, row = 0, 0

    for i, rune in ipairs(MG.Runes) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT",
            14 + col * (ICON_SIZE + PADDING),
            y  - row * (ICON_SIZE + PADDING + 16))

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(rune.id)

        local border = btn:CreateTexture(nil, "BACKGROUND"); border:SetAllPoints()
        border:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12)

        local nameLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        nameLbl:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        nameLbl:SetText(rune.name); nameLbl:SetTextColor(0.6, 0.6, 0.65, 1)

        btn:SetScript("OnEnter", function() border:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4) end)
        btn:SetScript("OnLeave", function() border:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12) end)

        local runeIdx = i
        btn:SetScript("OnClick", function()
            if not SM.IsEditor() then return end
            BroadcastMG(runeIdx)
            border:SetColorTexture(0.2, 0.85, 0.2, 0.6)
            C_Timer.NewTimer(0.3, function() border:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12) end)
        end)

        col = col + 1
        if col >= perRow then col = 0; row = row + 1 end
    end

    return f
end

local mgInitFrame = CreateFrame("Frame")
mgInitFrame:RegisterEvent("PLAYER_LOGIN")
mgInitFrame:SetScript("OnEvent", function()
    MG.BuildDisplayFrame()
    mgInitFrame:UnregisterAllEvents()
end)
