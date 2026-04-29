-- SolaryM_ReminderNote.lua
-- Système de reminders
-- Parser, note filtrée par joueur, alertes in-combat, glow sur unit frames

SM.ReminderNote = SM.ReminderNote or {}
local RN = SM.ReminderNote
local LGF = LibStub and LibStub("LibGetFrame-1.0", true)

local processed    = {}   -- [encID][phase] = [{...}]
local activeTimers = {}
local glowTimers   = {}
local currentEncID = nil
local currentPhase = 1
local noteFrame    = nil
local NOTE_W, NOTE_H = 320, 400
local lastReceivedName = nil

function RN.GetLastReceived() return lastReceivedName end
function RN.ClearReceived()   lastReceivedName = nil end


-- ── Reminder Alerts ───────────────────────────────────────────
local RA_W_DEFAULT  = 380
local RA_H_DEFAULT  = 38
local RA_ROW_GAP    = 3
local raContainer   = nil
local raActiveAlerts = {}
local raAlertIdSeq  = 0
local raRecentAlerts = {}
local RA_SPAM_THROTTLE = 3

local function RAGetSize()
    local sz = SolaryMDB and SolaryMDB.reminder_alerts_size
    return (sz and sz.w) or RA_W_DEFAULT, (sz and sz.h) or RA_H_DEFAULT
end

-- ============================================================
-- UTILS
-- ============================================================
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

local function ParseField(line, key)
    local val = line:match(key .. ":([^;\n]+)")
    return val and trim(val) or nil
end

local function SecondsToTime(s)
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return string.format("%d:%02d", m, sec)
end

-- ============================================================
-- GLOW SYSTEM
-- ============================================================
local function CreateGlow(parent, r, g, b)
    local gf = CreateFrame("Frame", nil, parent)
    gf:SetFrameLevel(parent:GetFrameLevel() + 10)
    gf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     -3,  3)
    gf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  3, -3)

    local function Edge(p1, p2, horiz)
        local t = gf:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(r, g, b, 1)
        t:SetPoint(p1, gf, p1, 0, 0)
        t:SetPoint(p2, gf, p2, 0, 0)
        if horiz then t:SetHeight(2) else t:SetWidth(2) end
    end
    Edge("TOPLEFT",    "TOPRIGHT",    true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT",    "BOTTOMLEFT",  false)
    Edge("TOPRIGHT",   "BOTTOMRIGHT", false)

    local ag = gf:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.2); a1:SetToAlpha(1.0); a1:SetDuration(0.45); a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1.0); a2:SetToAlpha(0.2); a2:SetDuration(0.45); a2:SetOrder(2)
    ag:Play()
    gf._ag = ag
    return gf
end

local FRAME_MAP = {
    player = function() return PlayerFrame end,
    target = function() return TargetFrame end,
    focus  = function() return FocusFrame  end,
    party1 = function() return _G["PartyMemberFrame1"] end,
    party2 = function() return _G["PartyMemberFrame2"] end,
    party3 = function() return _G["PartyMemberFrame3"] end,
    party4 = function() return _G["PartyMemberFrame4"] end,
}

local function FindUnitFrame(nameOrToken)
    local lo = nameOrToken:lower()
    if FRAME_MAP[lo] then return FRAME_MAP[lo]() end
    -- LibGetFrame-1.0 gère ElvUI, CompactRaid, VuhDo, Grid2, etc.
    if LGF then return LGF.GetUnitFrame(nameOrToken) end
    -- Fallback manuel si LGF absent : descend dans les groupes CompactRaid
    if CompactRaidFrameContainer then
        for _, group in ipairs({CompactRaidFrameContainer:GetChildren()}) do
            for _, child in ipairs({group:GetChildren()}) do
                if child.unit and UnitName(child.unit):lower() == lo then
                    return child
                end
            end
        end
    end
    return nil
end

function RN.GlowUnit(nameOrToken, colors, duration)
    local frame = FindUnitFrame(nameOrToken)
    if not frame then return end
    local r = colors and colors[1] or 0
    local g = colors and colors[2] or 1
    local b = colors and colors[3] or 0
    if not frame._rnGlow then
        frame._rnGlow = CreateGlow(frame, r, g, b)
    end
    frame._rnGlow:Show()
    frame._rnGlow._ag:Play()
    if glowTimers[nameOrToken] then glowTimers[nameOrToken]:Cancel() end
    glowTimers[nameOrToken] = C_Timer.NewTimer(duration or 5, function()
        if frame._rnGlow then
            frame._rnGlow._ag:Stop()
            frame._rnGlow:Hide()
        end
        glowTimers[nameOrToken] = nil
    end)
end

function RN.ClearAllGlows()
    for k, t in pairs(glowTimers) do
        if t.Cancel then t:Cancel() end
        glowTimers[k] = nil
    end
end

-- ============================================================
-- PARSER
-- ============================================================
local function ParseString(str)
    if not str or str == "" then return {} end
    local result = {}
    local encID  = nil

    for line in (str .. "\n"):gmatch("([^\n]*)\n") do
        line = trim(line)
        if line ~= "" then
            if line:find("EncounterID:") then
                local id = line:match("EncounterID:(%d+)")
                if id then encID = tonumber(id); result[encID] = result[encID] or {} end

            elseif encID and line:find("time:") then
                local time = tonumber(ParseField(line, "time"))
                if time then
                    local ph       = tonumber(ParseField(line, "ph")) or 1
                    local text     = ParseField(line, "text")
                    local spellStr = ParseField(line, "spellid") or ParseField(line, "spellID")
                    local spellID  = tonumber(spellStr)
                    local dur      = tonumber(ParseField(line, "dur")) or 8
                    local tagStr   = ParseField(line, "tag") or "everyone"
                    local glowStr  = ParseField(line, "glowunit")
                    local colStr   = ParseField(line, "colors")

                    local tags = {}
                    for t in tagStr:gmatch("%S+") do tags[#tags+1] = t:lower() end

                    local glowunits = {}
                    if glowStr then
                        for g in glowStr:gmatch("%S+") do glowunits[#glowunits+1] = g end
                    end

                    local colors = {0, 1, 0, 1}
                    if colStr then
                        local r,g,b,a = colStr:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s*([%d%.]*)")
                        if r then colors = {tonumber(r), tonumber(g), tonumber(b), tonumber(a) ~= 0 and tonumber(a) or 1} end
                    end

                    if text then
                        text = text:gsub("{star}",     "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:0:64:0:64|t")
                        text = text:gsub("{circle}",   "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:64:128:0:64|t")
                        text = text:gsub("{diamond}",  "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:128:192:0:64|t")
                        text = text:gsub("{triangle}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:192:256:0:64|t")
                        text = text:gsub("{moon}",     "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:0:64:64:128|t")
                        text = text:gsub("{square}",   "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:64:128:64:128|t")
                        text = text:gsub("{cross}",    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:128:192:64:128|t")
                        text = text:gsub("{skull}",    "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:0:0:0:0:256:256:192:256:64:128|t")
                        for i = 1, 8 do text = text:gsub("{rt"..i.."}", "{rt"..i.."}") end
                    end

                    result[encID][ph] = result[encID][ph] or {}
                    table.insert(result[encID][ph], {
                        time      = time,
                        text      = text,
                        spellID   = spellID,
                        tags      = tags,
                        dur       = dur,
                        glowunits = glowunits,
                        colors    = colors,
                        ph        = ph,
                    })
                end
            end
        end
    end

    return result
end

-- ============================================================
-- TAG MATCHING
-- ============================================================
local function MatchTag(tag)
    if tag == "everyone" then return true end

    local name = UnitName("player")
    if name and tag == name:lower() then return true end

    local nick = SolaryMDB and SolaryMDB.reminder_nick
    if nick and nick ~= "" and tag == nick:lower() then return true end

    local role = UnitGroupRolesAssigned("player")
    if tag == "tank"   and role == "TANK"    then return true end
    if tag == "healer" and role == "HEALER"  then return true end
    if tag == "damage" and role == "DAMAGER" then return true end
    if tag == "dps"    and role == "DAMAGER" then return true end

    local gNum = tag:match("^group(%d)$")
    if gNum then
        gNum = tonumber(gNum)
        for i = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid"..i) or ("party"..i)
            if UnitIsUnit(unit, "player") then
                local _, _, sg = GetRaidRosterInfo(i)
                if sg == gNum then return true end
            end
        end
    end

    local specIdx = GetSpecialization()
    if specIdx then
        local specID = GetSpecializationInfo(specIdx)
        if tag == tostring(specID) then return true end
    end

    local _, class = UnitClass("player")
    if class and tag == class:lower() then return true end

    return false
end

local function MatchesTags(tags)
    for _, t in ipairs(tags) do
        if MatchTag(t) then return true end
    end
    return false
end

-- ============================================================
-- NOTE FRAME
-- ============================================================
local function SaveNotePos()
    if not noteFrame or not SolaryMDB then return end
    local p, _, rp, x, y = noteFrame:GetPoint()
    if p then SolaryMDB.reminder_note_pos = {p=p, rp=rp, x=math.floor(x), y=math.floor(y)} end
end

local function NoteExitEditMode()
    if not noteFrame then return end
    noteFrame._editScroll:Hide()
    noteFrame._scroll:Show()
    noteFrame._saveBtn:Hide()
    noteFrame._cancelBtn:Hide()
end

local function NoteEnterEditMode()
    if not noteFrame then return end
    local name = SolaryMDB and SolaryMDB.active_reminder
    local raw = (name and SolaryMDB.reminders and SolaryMDB.reminders[name]) or ""
    noteFrame._editBox:SetText(raw)
    noteFrame._scroll:Hide()
    noteFrame._editScroll:Show()
    noteFrame._saveBtn:Show()
    noteFrame._cancelBtn:Show()
    noteFrame._editBox:SetFocus()
end

local function BuildNoteFrame()
    if noteFrame then return end
    noteFrame = CreateFrame("Frame", "SolaryMReminderNoteFrame", UIParent)
    noteFrame:SetSize(NOTE_W, NOTE_H)
    noteFrame:SetFrameStrata("MEDIUM")
    noteFrame:SetMovable(true)
    noteFrame:EnableMouse(true)
    noteFrame:RegisterForDrag("LeftButton")
    noteFrame:SetScript("OnDragStart", noteFrame.StartMoving)
    noteFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing(); SaveNotePos() end)

    local pos = SolaryMDB and SolaryMDB.reminder_note_pos
    if pos then
        noteFrame:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
    else
        noteFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    end

    local sz = SolaryMDB and SolaryMDB.reminder_note_size
    if sz then noteFrame:SetSize(sz.w, sz.h) end

    noteFrame:SetResizable(true)
    noteFrame:SetResizeBounds(160, 100, 700, 900)

    -- ── Fond ──
    local bg = noteFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.07, 0.88)

    -- ── Bordure fine permanente ──
    local function MakeBorder(point1, point2, isHoriz)
        local t = noteFrame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.30)
        if isHoriz then t:SetHeight(1) else t:SetWidth(1) end
        t:SetPoint(point1, noteFrame, point1, 0, 0)
        t:SetPoint(point2, noteFrame, point2, 0, 0)
        return t
    end
    MakeBorder("TOPLEFT",    "TOPRIGHT",    true)
    MakeBorder("BOTTOMLEFT", "BOTTOMRIGHT", true)
    MakeBorder("TOPLEFT",    "BOTTOMLEFT",  false)
    MakeBorder("TOPRIGHT",   "BOTTOMRIGHT", false)

    -- ── Cadre edit-mode (bordure épaisse + fond teinté, visible quand déverrouillé) ──
    local editModeBorder = {}
    local function MakeEditBorder(p1, p2, horiz)
        local t = noteFrame:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.90)
        if horiz then t:SetHeight(2) else t:SetWidth(2) end
        t:SetPoint(p1, noteFrame, p1, 0, 0)
        t:SetPoint(p2, noteFrame, p2, 0, 0)
        t:Hide()
        editModeBorder[#editModeBorder+1] = t
        return t
    end
    MakeEditBorder("TOPLEFT",    "TOPRIGHT",    true)
    MakeEditBorder("BOTTOMLEFT", "BOTTOMRIGHT", true)
    MakeEditBorder("TOPLEFT",    "BOTTOMLEFT",  false)
    MakeEditBorder("TOPRIGHT",   "BOTTOMRIGHT", false)

    local editModeTint = noteFrame:CreateTexture(nil, "BACKGROUND")
    editModeTint:SetAllPoints()
    editModeTint:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.06)
    editModeTint:Hide()

    local editModeLabel = noteFrame:CreateFontString(nil, "OVERLAY")
    editModeLabel:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    editModeLabel:SetPoint("BOTTOM", noteFrame, "BOTTOM", 0, 6)
    editModeLabel:SetText("Déplacer • Coin bas-droit pour redimensionner")
    editModeLabel:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.80)
    editModeLabel:Hide()

    local function SetEditMode(on)
        for _, t in ipairs(editModeBorder) do t:SetShown(on) end
        editModeTint:SetShown(on)
        editModeLabel:SetShown(on)
    end

    -- ── Header (22px) ──
    local headerBg = noteFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetPoint("TOPLEFT",  noteFrame, "TOPLEFT",  0, 0)
    headerBg:SetPoint("TOPRIGHT", noteFrame, "TOPRIGHT", 0, 0)
    headerBg:SetHeight(22)
    headerBg:SetColorTexture(SM.OR[1]*0.12, SM.OR[2]*0.12, SM.OR[3]*0.18, 1)

    local title = noteFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\ARIALN.TTF", 11, "")
    title:SetPoint("TOPLEFT", noteFrame, "TOPLEFT", 6, -5)
    title:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    title:SetText("SolaryM — Reminders")
    noteFrame._title = title

    local closeBtn = CreateFrame("Button", nil, noteFrame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", noteFrame, "TOPRIGHT", -2, -2)
    local closeFS = closeBtn:CreateFontString(nil, "OVERLAY")
    closeFS:SetFont("Fonts\\ARIALN.TTF", 11, "")
    closeFS:SetAllPoints(); closeFS:SetText("✕"); closeFS:SetTextColor(0.5, 0.5, 0.5, 1)
    closeBtn:SetScript("OnClick",  function() noteFrame:Hide() end)
    closeBtn:SetScript("OnEnter",  function() closeFS:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave",  function() closeFS:SetTextColor(0.5, 0.5, 0.5, 1) end)

    -- ── Bouton lock / edit-mode ──
    local lockBtn = CreateFrame("Button", nil, noteFrame)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)
    local lockFS = lockBtn:CreateFontString(nil, "OVERLAY")
    lockFS:SetFont("Fonts\\ARIALN.TTF", 11, "")
    lockFS:SetAllPoints(); lockFS:SetText("⚙"); lockFS:SetTextColor(0.5, 0.8, 0.5, 1)
    local locked = false
    lockBtn:SetScript("OnClick", function()
        locked = not locked
        if locked then
            lockFS:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
            noteFrame:EnableMouse(false)
            noteFrame:SetMovable(false)
            SetEditMode(false)
        else
            lockFS:SetTextColor(0.5, 0.8, 0.5, 1)
            noteFrame:EnableMouse(true)
            noteFrame:SetMovable(true)
            SetEditMode(true)
        end
    end)
    lockBtn:SetScript("OnEnter", function() lockFS:SetTextColor(1, 1, 0.3, 1) end)
    lockBtn:SetScript("OnLeave", function()
        lockFS:SetTextColor(locked and SM.OR[1] or 0.5, locked and SM.OR[2] or 0.8, locked and SM.OR[3] or 0.5, 1)
    end)

    -- Edit-mode actif par défaut à la première ouverture (si pas de position sauvée)
    if not (SolaryMDB and SolaryMDB.reminder_note_pos) then
        SetEditMode(true)
    end

    -- ── Vue lecture ──
    local scroll = CreateFrame("ScrollFrame", nil, noteFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     noteFrame, "TOPLEFT",     4, -24)
    scroll:SetPoint("BOTTOMRIGHT", noteFrame, "BOTTOMRIGHT", -22, 22)
    noteFrame._scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(noteFrame:GetWidth() - 30)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    noteFrame._content = content

    local textFS = content:CreateFontString(nil, "OVERLAY")
    textFS:SetFont("Fonts\\ARIALN.TTF", 12, "")
    textFS:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
    textFS:SetPoint("RIGHT",   content, "RIGHT",   -4, 0)
    textFS:SetJustifyH("LEFT")
    textFS:SetJustifyV("TOP")
    textFS:SetSpacing(3)
    textFS:SetTextColor(0.88, 0.88, 0.92, 1)
    noteFrame._textFS = textFS

    -- ── Vue édition ──
    local editScroll = CreateFrame("ScrollFrame", nil, noteFrame, "UIPanelScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT",     noteFrame, "TOPLEFT",     4, -24)
    editScroll:SetPoint("BOTTOMRIGHT", noteFrame, "BOTTOMRIGHT", -22, 30)
    editScroll:Hide()
    noteFrame._editScroll = editScroll

    local editBox = CreateFrame("EditBox", nil, editScroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(NOTE_W - 34)
    editBox:SetTextColor(0.88, 0.88, 0.92, 1)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editScroll:SetScrollChild(editBox)
    noteFrame._editBox = editBox

    local saveBtn = CreateFrame("Button", nil, noteFrame)
    saveBtn:SetSize(80, 18)
    saveBtn:SetPoint("BOTTOMLEFT", noteFrame, "BOTTOMLEFT", 4, 4)
    local saveBg = saveBtn:CreateTexture(nil, "BACKGROUND"); saveBg:SetAllPoints()
    saveBg:SetColorTexture(0.1, 0.35, 0.1, 0.9)
    local saveFS = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveFS:SetAllPoints(); saveFS:SetText("Sauvegarder"); saveFS:SetTextColor(0.6, 1, 0.6, 1)
    saveBtn:SetScript("OnEnter", function() saveBg:SetColorTexture(0.15, 0.5, 0.15, 0.95) end)
    saveBtn:SetScript("OnLeave", function() saveBg:SetColorTexture(0.1, 0.35, 0.1, 0.9) end)
    saveBtn:SetScript("OnClick", function()
        local name = SolaryMDB and SolaryMDB.active_reminder
        if name then
            SolaryMDB.reminders[name] = editBox:GetText()
            Reprocess()
        end
        NoteExitEditMode()
        RefreshNoteFrame()
    end)
    saveBtn:Hide()
    noteFrame._saveBtn = saveBtn

    local cancelBtn = CreateFrame("Button", nil, noteFrame)
    cancelBtn:SetSize(60, 18)
    cancelBtn:SetPoint("BOTTOMLEFT", saveBtn, "BOTTOMRIGHT", 4, 0)
    local cancelBg = cancelBtn:CreateTexture(nil, "BACKGROUND"); cancelBg:SetAllPoints()
    cancelBg:SetColorTexture(0.35, 0.1, 0.1, 0.9)
    local cancelFS = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cancelFS:SetAllPoints(); cancelFS:SetText("Annuler"); cancelFS:SetTextColor(1, 0.6, 0.6, 1)
    cancelBtn:SetScript("OnEnter", function() cancelBg:SetColorTexture(0.5, 0.15, 0.15, 0.95) end)
    cancelBtn:SetScript("OnLeave", function() cancelBg:SetColorTexture(0.35, 0.1, 0.1, 0.9) end)
    cancelBtn:SetScript("OnClick", function() NoteExitEditMode() end)
    cancelBtn:Hide()
    noteFrame._cancelBtn = cancelBtn

    -- ── Poignée de resize (plus grande, plus visible) ──
    local grip = CreateFrame("Button", nil, noteFrame)
    grip:SetSize(22, 22)
    grip:SetPoint("BOTTOMRIGHT", noteFrame, "BOTTOMRIGHT", 0, 0)
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
    grip:SetScript("OnEnter", function() gripTex:SetVertexColor(1, 1, 1, 1) end)
    grip:SetScript("OnLeave", function() gripTex:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85) end)
    grip:SetScript("OnMouseDown", function() noteFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp",   function()
        noteFrame:StopMovingOrSizing()
        local w, h = noteFrame:GetWidth(), noteFrame:GetHeight()
        SolaryMDB = SolaryMDB or {}
        SolaryMDB.reminder_note_size = {w = math.floor(w), h = math.floor(h)}
        noteFrame._content:SetWidth(w - 30)
        noteFrame._editBox:SetWidth(w - 34)
    end)

    noteFrame:SetScript("OnSizeChanged", function(self, w, _)
        if self._content then self._content:SetWidth(w - 30) end
        if self._editBox  then self._editBox:SetWidth(w - 34) end
    end)

    noteFrame:Hide()
end

local function RefreshNoteFrame()
    if not noteFrame then BuildNoteFrame() end
    local name = SolaryMDB and SolaryMDB.active_reminder
    if not name or not SolaryMDB.reminders or not SolaryMDB.reminders[name] then
        noteFrame._textFS:SetText("|cff666666Aucun reminder actif.|r")
        noteFrame._content:SetHeight(30)
        return
    end
    noteFrame._title:SetText("SolaryM — " .. name)

    local parsed = ParseString(SolaryMDB.reminders[name])
    local lines  = {}

    for encID, phases in pairs(parsed) do
        local phaseCount = 0
        for ph = 1, 20 do
            local reminders = phases[ph]
            if not reminders then break end

            local applicable = {}
            for _, r in ipairs(reminders) do
                if MatchesTags(r.tags) then applicable[#applicable+1] = r end
            end
            if #applicable > 0 then
                phaseCount = phaseCount + 1
                if ph > 1 then
                    lines[#lines+1] = string.format("|cff%02x%02x%02xPhase %d|r",
                        math.floor(SM.OR[1]*255), math.floor(SM.OR[2]*255), math.floor(SM.OR[3]*255), ph)
                end

                table.sort(applicable, function(a, b) return a.time < b.time end)
                for _, r in ipairs(applicable) do
                    local tStr  = SecondsToTime(r.time)
                    local label = r.text
                    if not label and r.spellID then
                        label = C_Spell.GetSpellName(r.spellID) or ("Spell "..r.spellID)
                    end
                    label = label or "?"
                    local glowIndicator = (#r.glowunits > 0) and " |cffaaffaa[glow]|r" or ""
                    lines[#lines+1] = string.format("|cffaaaaaa%s|r  %s%s", tStr, label, glowIndicator)
                end
            end
        end
    end

    if #lines == 0 then
        noteFrame._textFS:SetText("|cff666666Aucun reminder ne vous concerne.|r")
        noteFrame._content:SetHeight(30)
    else
        noteFrame._textFS:SetText(table.concat(lines, "\n"))
        noteFrame._content:SetHeight(#lines * 17 + 10)
    end
end

-- ============================================================
-- REMINDER ALERTS (container séparé des alertes boss)
-- ============================================================
local RALayoutRows   -- forward-declared, defined below EnsureRAContainer
local FitLabelFont   -- forward-declared, defined below EnsureRAContainer

local function EnsureRAContainer()
    if raContainer then return end
    local w, h = RAGetSize()
    raContainer = CreateFrame("Frame", "SolaryMReminderAlertContainer", UIParent)
    raContainer:SetSize(w, h)
    raContainer:SetFrameStrata("HIGH")
    raContainer:EnableMouse(false)
    local s = SolaryMDB and SolaryMDB.frames and SolaryMDB.frames["reminder_alerts"]
    raContainer:ClearAllPoints()
    if s and s.x then
        raContainer:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
    else
        raContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    -- ── Cadre edit-mode (visible uniquement quand déverrouillé) ──
    local editBg = raContainer:CreateTexture(nil, "BACKGROUND")
    editBg:SetAllPoints()
    editBg:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.08)
    editBg:Hide()
    raContainer._editBg = editBg

    local function MakeRABorder(p1, p2, horiz)
        local t = raContainer:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.90)
        if horiz then t:SetHeight(2) else t:SetWidth(2) end
        t:SetPoint(p1, raContainer, p1, 0, 0)
        t:SetPoint(p2, raContainer, p2, 0, 0)
        t:Hide()
        return t
    end
    local borders = {
        MakeRABorder("TOPLEFT",    "TOPRIGHT",    true),
        MakeRABorder("BOTTOMLEFT", "BOTTOMRIGHT", true),
        MakeRABorder("TOPLEFT",    "BOTTOMLEFT",  false),
        MakeRABorder("TOPRIGHT",   "BOTTOMRIGHT", false),
    }
    raContainer._borders = borders

    local editLabel = raContainer:CreateFontString(nil, "OVERLAY")
    editLabel:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    editLabel:SetPoint("TOPLEFT", raContainer, "BOTTOMLEFT", 0, -4)
    editLabel:SetText("Alertes Reminders — Déplacer • Coin bas-droit pour redimensionner")
    editLabel:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
    editLabel:Hide()
    raContainer._editLabel = editLabel

    -- ── Poignée de resize ──
    local grip = CreateFrame("Button", nil, raContainer)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", raContainer, "BOTTOMRIGHT", 0, 0)
    grip:SetFrameLevel(raContainer:GetFrameLevel() + 5)
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
    grip:SetScript("OnEnter", function() gripTex:SetVertexColor(1, 1, 1, 1) end)
    grip:SetScript("OnLeave", function() gripTex:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85) end)
    grip:SetScript("OnMouseDown", function() raContainer:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        raContainer:StopMovingOrSizing()
        local nw, nh = raContainer:GetWidth(), raContainer:GetHeight()
        nw = math.max(200, math.floor(nw))
        nh = math.max(24,  math.floor(nh))
        raContainer:SetSize(nw, nh)
        SolaryMDB = SolaryMDB or {}
        SolaryMDB.reminder_alerts_size = {w = nw, h = nh}
        -- Redimensionner les alertes actives
        local newIconSize = nh - 6
        local newFontSize = math.max(10, math.floor(nh * 0.53))
        for _, a in ipairs(raActiveAlerts) do
            if a.frame then
                a.frame:SetSize(nw, nh)
                local lblTextX = 0
                if a.icon then
                    a.icon:SetSize(newIconSize, newIconSize)
                    a.icon:ClearAllPoints()
                    a.icon:SetPoint("LEFT", a.frame, "LEFT", 2, 0)
                    lblTextX = newIconSize + 6
                    a.lbl:ClearAllPoints()
                    a.lbl:SetPoint("LEFT",  a.frame, "LEFT",  lblTextX, 0)
                    a.lbl:SetPoint("RIGHT", a.frame, "RIGHT", 0, 0)
                end
                if a.lbl then
                    FitLabelFont(a.lbl, nw - lblTextX - 4, newFontSize)
                end
            end
        end
        RALayoutRows()
    end)
    grip:Hide()
    raContainer._grip = grip
    raContainer:SetResizable(true)
    raContainer:SetResizeBounds(200, 24, 800, 120)

    local function SetEditMode(on)
        editBg:SetShown(on)
        editLabel:SetShown(on)
        grip:SetShown(on)
        for _, t in ipairs(borders) do t:SetShown(on) end
    end
    raContainer._setEditMode = SetEditMode
end

local function RASavePos()
    if not raContainer or not SolaryMDB then return end
    local p, _, rp, x, y = raContainer:GetPoint()
    if p then
        SolaryMDB.frames = SolaryMDB.frames or {}
        SolaryMDB.frames["reminder_alerts"] = {point=p, rp=rp, x=math.floor(x), y=math.floor(y)}
    end
end

RALayoutRows = function()
    if not raContainer then return end
    local _, rh = RAGetSize()
    local totalH = 0
    for i, a in ipairs(raActiveAlerts) do
        if a.frame and a.frame:IsShown() then
            a.frame:ClearAllPoints()
            a.frame:SetPoint("TOPLEFT", raContainer, "TOPLEFT", 0, -totalH)
            totalH = totalH + rh + RA_ROW_GAP
        end
    end
    raContainer:SetHeight(math.max(rh, totalH))
end

local function RARemoveAlert(id)
    for i, a in ipairs(raActiveAlerts) do
        if a.id == id then
            if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
            if a.frame then
                UIFrameFadeOut(a.frame, 0.25, 1, 0)
                local f = a.frame
                C_Timer.NewTimer(0.25, function() f:Hide() end)
            end
            table.remove(raActiveAlerts, i)
            C_Timer.NewTimer(0.3, RALayoutRows)
            return
        end
    end
end

-- Réduit la police proportionnellement pour que le texte tienne sur une ligne
FitLabelFont = function(lbl, maxW, startSize)
    lbl:SetFont("Fonts\\FRIZQT__.TTF", startSize, "OUTLINE")
    local sw = lbl:GetStringWidth()
    if sw > maxW and sw > 0 then
        local fitted = math.max(8, math.floor(startSize * maxW / sw) - 1)
        lbl:SetFont("Fonts\\FRIZQT__.TTF", fitted, "OUTLINE")
    end
end

local function ShowReminderAlert(text, spellId, duration, bypassThrottle)
    if not text or text == "" then return end
    local now = GetTime()
    local key = text
    if not bypassThrottle and raRecentAlerts[key] and (now - raRecentAlerts[key]) < RA_SPAM_THROTTLE then return end
    raRecentAlerts[key] = now

    EnsureRAContainer()
    raAlertIdSeq = raAlertIdSeq + 1
    local id = raAlertIdSeq

    local rw, rh = RAGetSize()
    local f = CreateFrame("Frame", nil, raContainer)
    f:SetSize(rw, rh)
    f:SetAlpha(0)
    f:EnableMouse(false)

    -- Icône si spellId, sinon texte centré pleine largeur
    local textX = 0
    local icon = nil
    if spellId then
        local iconSize = rh - 6
        icon = f:CreateTexture(nil, "OVERLAY")
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("LEFT", f, "LEFT", 2, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(C_Spell.GetSpellTexture(spellId))
        textX = iconSize + 6
    end

    local fontSize = math.max(10, math.floor(rh * 0.53))
    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetWordWrap(false)
    lbl:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    lbl:SetPoint("LEFT",  f, "LEFT",  textX, 0)
    lbl:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    lbl:SetJustifyH(spellId and "LEFT" or "CENTER")
    lbl:SetTextColor(0.75, 0.55, 1.0, 1)  -- violet clair
    lbl:SetText(string.format("%s (%.1f)", text, duration or 0))
    FitLabelFont(lbl, rw - textX - 4, fontSize)

    local alertData = {
        id        = id,
        frame     = f,
        lbl       = lbl,
        icon      = icon,
        text      = text,
        duration  = duration or 8,
        startTime = GetTime(),
    }
    table.insert(raActiveAlerts, 1, alertData)
    RALayoutRows()
    f:Show()
    UIFrameFadeIn(f, 0.12, 0, 1)

    alertData.ticker = C_Timer.NewTicker(0.05, function()
        local elapsed  = GetTime() - alertData.startTime
        local timeLeft = math.max(0, alertData.duration - elapsed)

        if timeLeft <= 2 then
            lbl:SetTextColor(1, 0.2, 0.1, 1)
        elseif timeLeft <= 4 then
            lbl:SetTextColor(1, 0.65, 0.1, 1)
        else
            lbl:SetTextColor(0.75, 0.55, 1.0, 1)
        end

        if timeLeft >= 10 then
            lbl:SetText(string.format("%s (%.0f)", alertData.text, timeLeft))
        else
            lbl:SetText(string.format("%s (%.1f)", alertData.text, timeLeft))
        end

        if timeLeft <= 0 then
            alertData.ticker:Cancel()
            RARemoveAlert(id)
        end
    end)
end

function RN.UnlockAlerts()
    EnsureRAContainer()
    raContainer:EnableMouse(true)
    raContainer:SetMovable(true)
    raContainer:RegisterForDrag("LeftButton")
    raContainer:SetScript("OnDragStart", raContainer.StartMoving)
    raContainer:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); RASavePos()
    end)
    if raContainer._setEditMode then raContainer._setEditMode(true) end
    -- Preview : affiche une alerte factice pour voir la taille réelle
    ShowReminderAlert("Reminder — Alerte Test", nil, 30)
end

function RN.LockAlerts()
    EnsureRAContainer()
    raContainer:EnableMouse(false)
    raContainer:SetMovable(false)
    raContainer:SetScript("OnDragStart", nil)
    raContainer:SetScript("OnDragStop", nil)
    if raContainer._setEditMode then raContainer._setEditMode(false) end
    -- Vider les alertes de preview
    for _, a in ipairs(raActiveAlerts) do
        if a.ticker and not a.ticker:IsCancelled() then a.ticker:Cancel() end
        if a.frame then a.frame:Hide() end
    end
    raActiveAlerts = {}
end

-- ============================================================
-- IN-COMBAT SYSTEM
-- ============================================================
local function CancelTimers()
    for _, t in ipairs(activeTimers) do
        if t.Cancel then pcall(function() t:Cancel() end) end
    end
    activeTimers = {}
end

local function FireReminder(info)
    local text = info.text
    if not text and info.spellID then
        text = C_Spell.GetSpellName(info.spellID) or tostring(info.spellID)
    end
    if text then
        ShowReminderAlert(text, info.spellID, info._firePrealert or info.dur, info._isTest)
    end
    for _, unit in ipairs(info.glowunits) do
        RN.GlowUnit(unit, info.colors, info.dur)
    end
end

local function GetPrealert()
    return (SolaryMDB and SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5
end

local function StartPhase(phase, isTest)
    CancelTimers()
    currentPhase = phase
    if not currentEncID or not processed[currentEncID] then return end
    local reminders = processed[currentEncID][phase]
    if not reminders then return end
    local prealert = GetPrealert()
    for _, info in ipairs(reminders) do
        if MatchesTags(info.tags) then
            local fireAt = math.max(0, info.time - prealert)
            if isTest then info._isTest = true end  -- bypass throttle en mode test
            info._firePrealert = math.min(prealert, info.time)
            local t = C_Timer.NewTimer(fireAt, function() FireReminder(info) end)
            table.insert(activeTimers, t)
        end
    end
end

local function MergeReminders(a, b)
    local result = {}
    local encIDs = {}
    for id in pairs(a) do encIDs[id] = true end
    for id in pairs(b) do encIDs[id] = true end
    for encID in pairs(encIDs) do
        result[encID] = {}
        local phases = {}
        if a[encID] then for ph in pairs(a[encID]) do phases[ph] = true end end
        if b[encID] then for ph in pairs(b[encID]) do phases[ph] = true end end
        for ph in pairs(phases) do
            result[encID][ph] = {}
            local seen = {}
            local function addEntries(src)
                if not src[encID] or not src[encID][ph] then return end
                for _, r in ipairs(src[encID][ph]) do
                    local k = r.time .. "_" .. (r.spellID and tostring(r.spellID) or (r.text or ""))
                    if not seen[k] then
                        seen[k] = true
                        table.insert(result[encID][ph], r)
                    end
                end
            end
            addEntries(a)
            addEntries(b)
            table.sort(result[encID][ph], function(x, y) return x.time < y.time end)
        end
    end
    return result
end

local function Reprocess()
    local sharedName   = SolaryMDB and SolaryMDB.active_reminder
    local personalName = SolaryMDB and SolaryMDB.personal_active
    local sharedData, personalData = {}, {}
    if sharedName   and SolaryMDB.reminders          and SolaryMDB.reminders[sharedName]                    then
        sharedData   = ParseString(SolaryMDB.reminders[sharedName])
    end
    if personalName and SolaryMDB.personal_reminders and SolaryMDB.personal_reminders[personalName] then
        personalData = ParseString(SolaryMDB.personal_reminders[personalName])
    end
    processed = MergeReminders(sharedData, personalData)
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function RN.TestEncounter(encID)
    encID = tonumber(encID)
    if not encID then
        SM.Print("|cffff4444remtest: encID invalide|r")
        return
    end
    Reprocess()
    if not processed[encID] then
        SM.Print("|cffff4444remtest: aucun reminder pour encID "..encID.."|r")
        return
    end
    currentEncID = encID
    currentPhase = 1
    StartPhase(1, true)  -- isTest=true : tous les fireAt forcés à 0, affichage immédiat
    SM.Print("|cff00ff00remtest: simulation encID "..encID.." démarrée|r")
end

function RN.StopTest()
    CancelTimers()
    currentEncID = nil
    currentPhase = 1
    SM.Print("remtest: arrêté")
end

function RN.GetEncounterIDs()
    Reprocess()
    local ids = {}
    for id in pairs(processed) do ids[#ids+1] = id end
    table.sort(ids)
    return ids
end

function RN.Import(name, str)
    if not SolaryMDB then return end
    SolaryMDB.reminders = SolaryMDB.reminders or {}
    local finalName, i = name, 2
    while SolaryMDB.reminders[finalName] do
        finalName = name .. " " .. i; i = i + 1
    end
    SolaryMDB.reminders[finalName] = str
    return finalName
end

function RN.SetActive(name)
    if not SolaryMDB then return end
    SolaryMDB.active_reminder = name
    Reprocess()
    RefreshNoteFrame()
end

function RN.Delete(name)
    if not SolaryMDB or not SolaryMDB.reminders then return end
    SolaryMDB.reminders[name] = nil
    if SolaryMDB.active_reminder == name then
        SolaryMDB.active_reminder = nil
        processed = {}
    end
    RefreshNoteFrame()
end

function RN.GetNames()
    if not SolaryMDB or not SolaryMDB.reminders then return {} end
    local names = {}
    for k in pairs(SolaryMDB.reminders) do names[#names+1] = k end
    table.sort(names)
    return names
end

function RN.OpenNoteInEditMode(name)
    RN.SetActive(name)
    if not noteFrame then BuildNoteFrame() end
    RefreshNoteFrame()
    noteFrame:Show()
    NoteEnterEditMode()
end

function RN.SendNote(name)
    if not SolaryMDB then return end
    local prev = SolaryMDB.active_reminder
    SolaryMDB.active_reminder = name
    RN.BroadcastNote()
    SolaryMDB.active_reminder = prev
end

function RN.ToggleNote()
    if not noteFrame then BuildNoteFrame() end
    if noteFrame:IsShown() then
        noteFrame:Hide()
    else
        RefreshNoteFrame()
        noteFrame:Show()
    end
end

function RN.ShowNote()
    if not noteFrame then BuildNoteFrame() end
    RefreshNoteFrame()
    noteFrame:Show()
end

-- ============================================================
-- BROADCAST (envoi note via AceComm — throttle géré par ChatThrottleLib)
-- ============================================================
local RN_PREFIX = "SolaryMRN"
local AceComm   = LibStub and LibStub("AceComm-3.0", true)

function RN.BroadcastNote()
    if not AceComm then SM.Print("|cffff4444AceComm introuvable.|r"); return end
    if not SolaryMDB then return end
    local name = SolaryMDB.active_reminder
    if not name or not (SolaryMDB.reminders and SolaryMDB.reminders[name]) then
        SM.Print("|cffff4444Aucune note active à envoyer.|r"); return
    end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then
        SM.Print("|cffff4444Tu dois être dans un groupe pour envoyer la note.|r"); return
    end

    local content  = SolaryMDB.reminders[name]
    local safeName = name:sub(1, 50):gsub("[:%s]", "_")
    -- AceComm gère le chunking et le throttle automatiquement
    AceComm:SendCommMessage(RN_PREFIX, safeName..":"..content, channel)
    SM.Print(string.format("|cff00ff00Note '%s' envoyée au %s.|r", name, channel))
end

local function OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= RN_PREFIX then return end
    local me = UnitName("player")
    if sender == me or sender == me.."-"..GetRealmName() then return end

    local noteName, content = message:match("^([^:]+):(.*)$")
    if not noteName then return end

    -- Remplacer la note existante ou l'ajouter (jamais d'incrément de nom)
    SolaryMDB.reminders = SolaryMDB.reminders or {}
    SolaryMDB.reminders[noteName] = content
    RN.SetActive(noteName)
    lastReceivedName = noteName
    SM.Print(string.format("|cff00ff00[Reminder] Note '%s' reçue de %s.|r", noteName, sender))
    if SM.RefreshNotesPanel then SM.RefreshNotesPanel() end
end

-- ============================================================
-- EVENTS
-- ============================================================
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("ENCOUNTER_START")
evFrame:RegisterEvent("ENCOUNTER_END")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encID = ...
        currentEncID  = encID
        currentPhase  = 1
        Reprocess()
        StartPhase(1)
    elseif event == "ENCOUNTER_END" then
        currentEncID = nil
        currentPhase = 1
        CancelTimers()
        RN.ClearAllGlows()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not currentEncID then
            CancelTimers()
            RN.ClearAllGlows()
        end
    end
end)

-- Phase changes via BigWigs timeline (optionnel)
local tlFrame = CreateFrame("Frame")
tlFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
tlFrame:SetScript("OnEvent", function(_, _, spellID)
    -- Détection de phase via spellID configuré dans le reminder (extension future)
    -- Pour l'instant : no-op, les phases peuvent être ajoutées per-boss
end)

-- ============================================================
-- PERSONAL NOTE FRAME (séparé du shared, affiche texte brut)
-- ============================================================
local personalNoteFrame = nil

local function BuildPersonalNoteFrame()
    if personalNoteFrame then return end
    personalNoteFrame = CreateFrame("Frame", "SolaryMPersonalNoteFrame", UIParent)
    personalNoteFrame:SetSize(320, 350)
    personalNoteFrame:SetFrameStrata("MEDIUM")
    personalNoteFrame:SetMovable(true)
    personalNoteFrame:EnableMouse(true)
    personalNoteFrame:RegisterForDrag("LeftButton")
    personalNoteFrame:SetScript("OnDragStart", personalNoteFrame.StartMoving)
    personalNoteFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if SolaryMDB then
            local p, _, rp, x, y = self:GetPoint()
            if p then SolaryMDB.personal_note_pos = {p=p, rp=rp, x=math.floor(x), y=math.floor(y)} end
        end
    end)
    local pos = SolaryMDB and SolaryMDB.personal_note_pos
    if pos then
        personalNoteFrame:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
    else
        personalNoteFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 360, -200)
    end
    local sz = SolaryMDB and SolaryMDB.personal_note_size
    if sz then personalNoteFrame:SetSize(sz.w, sz.h) end
    personalNoteFrame:SetResizable(true)
    personalNoteFrame:SetResizeBounds(160, 100, 600, 800)

    local title = personalNoteFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", personalNoteFrame, "TOPLEFT", 6, -5)
    title:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    title:SetText(SM.T("rem_personal_note_title"))
    personalNoteFrame._title = title

    local closeBtn = CreateFrame("Button", nil, personalNoteFrame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", personalNoteFrame, "TOPRIGHT", -2, -2)
    local closeFS = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeFS:SetAllPoints(); closeFS:SetText("X"); closeFS:SetTextColor(0.5, 0.5, 0.5, 1)
    closeBtn:SetScript("OnClick",  function() personalNoteFrame:Hide() end)
    closeBtn:SetScript("OnEnter",  function() closeFS:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave",  function() closeFS:SetTextColor(0.5, 0.5, 0.5, 1) end)

    local lockBtn = CreateFrame("Button", nil, personalNoteFrame)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, 0)
    local lockFS = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockFS:SetAllPoints(); lockFS:SetText("U"); lockFS:SetTextColor(0.5, 0.8, 0.5, 1)
    local locked = false
    lockBtn:SetScript("OnClick", function()
        locked = not locked
        if locked then
            lockFS:SetText("L"); lockFS:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
            personalNoteFrame:EnableMouse(false); personalNoteFrame:SetMovable(false)
        else
            lockFS:SetText("U"); lockFS:SetTextColor(0.5, 0.8, 0.5, 1)
            personalNoteFrame:EnableMouse(true); personalNoteFrame:SetMovable(true)
        end
    end)
    lockBtn:SetScript("OnEnter", function() lockFS:SetTextColor(1, 1, 0.3, 1) end)
    lockBtn:SetScript("OnLeave", function()
        lockFS:SetTextColor(locked and SM.OR[1] or 0.5, locked and SM.OR[2] or 0.8, locked and SM.OR[3] or 0.5, 1)
    end)

    local scroll = CreateFrame("ScrollFrame", nil, personalNoteFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     personalNoteFrame, "TOPLEFT",     4, -22)
    scroll:SetPoint("BOTTOMRIGHT", personalNoteFrame, "BOTTOMRIGHT", -22, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(personalNoteFrame:GetWidth() - 30)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    personalNoteFrame._content = content

    local textFS = content:CreateFontString(nil, "OVERLAY")
    textFS:SetFont("Fonts\\ARIALN.TTF", 12, "")
    textFS:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2)
    textFS:SetPoint("RIGHT",   content, "RIGHT",   -4, 0)
    textFS:SetJustifyH("LEFT"); textFS:SetJustifyV("TOP")
    textFS:SetSpacing(3)
    textFS:SetTextColor(0.88, 0.88, 0.92, 1)
    personalNoteFrame._textFS = textFS

    local grip = CreateFrame("Button", nil, personalNoteFrame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", personalNoteFrame, "BOTTOMRIGHT", -2, 2)
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
    grip:SetScript("OnMouseDown", function() personalNoteFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        personalNoteFrame:StopMovingOrSizing()
        if SolaryMDB then
            SolaryMDB.personal_note_size = {
                w = math.floor(personalNoteFrame:GetWidth()),
                h = math.floor(personalNoteFrame:GetHeight()),
            }
        end
        personalNoteFrame._content:SetWidth(personalNoteFrame:GetWidth() - 30)
    end)
    personalNoteFrame:SetScript("OnSizeChanged", function(self, w)
        if self._content then self._content:SetWidth(w - 30) end
    end)
    personalNoteFrame:Hide()
end

local function RefreshPersonalNoteFrame()
    if not personalNoteFrame then BuildPersonalNoteFrame() end
    local name = SolaryMDB and SolaryMDB.personal_active
    local rem  = SolaryMDB and SolaryMDB.personal_reminders
    if not name or not rem or not rem[name] then
        personalNoteFrame._textFS:SetText("|cff666666Aucune note personnelle active.|r")
        personalNoteFrame._content:SetHeight(30)
        return
    end
    personalNoteFrame._title:SetText("SolaryM — " .. name)

    local parsed = ParseString(rem[name])
    local lines  = {}

    for encID, phases in pairs(parsed) do
        for ph = 1, 20 do
            local reminders = phases[ph]
            if not reminders then break end
            local applicable = {}
            for _, r in ipairs(reminders) do
                if MatchesTags(r.tags) then applicable[#applicable+1] = r end
            end
            if #applicable > 0 then
                if ph > 1 then
                    lines[#lines+1] = string.format("|cff%02x%02x%02xPhase %d|r",
                        math.floor(SM.OR[1]*255), math.floor(SM.OR[2]*255), math.floor(SM.OR[3]*255), ph)
                end
                table.sort(applicable, function(a, b) return a.time < b.time end)
                for _, r in ipairs(applicable) do
                    local tStr  = SecondsToTime(r.time)
                    local label = r.text
                    if not label and r.spellID then
                        label = C_Spell.GetSpellName(r.spellID) or ("Spell " .. r.spellID)
                    end
                    label = label or "?"
                    local glowIndicator = (#r.glowunits > 0) and " |cffaaffaa[glow]|r" or ""
                    lines[#lines+1] = string.format("|cffaaaaaa%s|r  %s%s", tStr, label, glowIndicator)
                end
            end
        end
    end

    if #lines == 0 then
        personalNoteFrame._textFS:SetText("|cff666666Aucun reminder ne vous concerne.|r")
        personalNoteFrame._content:SetHeight(30)
    else
        personalNoteFrame._textFS:SetText(table.concat(lines, "\n"))
        personalNoteFrame._content:SetHeight(#lines * 17 + 10)
    end
end

function RN.SetPersonalActive(name)
    if not SolaryMDB then return end
    SolaryMDB.personal_active = name
    RefreshPersonalNoteFrame()
end

function RN.ShowPersonalNote()
    if not personalNoteFrame then BuildPersonalNoteFrame() end
    RefreshPersonalNoteFrame()
    personalNoteFrame:Show()
end

function RN.TogglePersonalNote()
    if not personalNoteFrame then BuildPersonalNoteFrame() end
    if personalNoteFrame:IsShown() then
        personalNoteFrame:Hide()
    else
        RefreshPersonalNoteFrame()
        personalNoteFrame:Show()
    end
end

-- ============================================================
-- INIT
-- ============================================================
local initRN = CreateFrame("Frame")
initRN:RegisterEvent("PLAYER_LOGIN")
initRN:SetScript("OnEvent", function(self)
    SolaryMDB.reminders      = SolaryMDB.reminders or {}
    SolaryMDB.reminder_nick  = SolaryMDB.reminder_nick  or ""
    if AceComm then AceComm:RegisterComm(RN_PREFIX, OnCommReceived) end
    Reprocess()
    BuildNoteFrame()
    if SolaryMDB.active_reminder and SolaryMDB.reminders[SolaryMDB.active_reminder] then
        RefreshNoteFrame()
        noteFrame:Show()
    end
    SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
    if SolaryMDB.personal_active and SolaryMDB.personal_reminders[SolaryMDB.personal_active] then
        BuildPersonalNoteFrame()
        RefreshPersonalNoteFrame()
        personalNoteFrame:Show()
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end)
