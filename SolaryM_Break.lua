-- SolaryM_Break.lua — Break timer avec broadcast raid

local AceComm       = LibStub and LibStub("AceComm-3.0", true)
local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
local COMM_PREFIX   = "SolaryMB"

local breakFrame  = nil
local breakTicker = nil
local breakHideTimer = nil
local updateFrame = nil
local breakLocked = true
local moverBreak  = nil
local breakHandleR = nil
local breakHandleB = nil
local breakResizePanel = nil

local BREAK_W_MIN, BREAK_W_MAX   = 120, 600
local BREAK_FONT_MIN, BREAK_FONT_MAX = 10, 60

-- ============================================================
-- HELPERS TAILLE SAUVEGARDÉE
-- ============================================================
local function GetBreakWidth()
    return (SolaryMDB and SolaryMDB.breakf and SolaryMDB.breakf.width) or 300
end

local function GetBreakHeight()
    return (SolaryMDB and SolaryMDB.breakf and SolaryMDB.breakf.height) or 200
end

local function GetBreakFontSize()
    return (SolaryMDB and SolaryMDB.breakf and SolaryMDB.breakf.fontSize) or 28
end

-- ============================================================
-- HELPERS POSITION
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
        frame:SetPoint(s.point or dp, UIParent, s.rp or dp, s.x, s.y)
    else
        frame:SetPoint(dp, UIParent, dp, dx, dy)
    end
end

-- ============================================================
-- BREAK FRAME
-- ============================================================
local BORDER = {
    {"TOPLEFT","TOPRIGHT",0,2},
    {"BOTTOMLEFT","BOTTOMRIGHT",0,2},
    {"TOPLEFT","BOTTOMLEFT",2,0},
    {"TOPRIGHT","BOTTOMRIGHT",2,0},
}

local function CreateBreakFrame()
    if breakFrame then return end
    local bw = GetBreakWidth()
    local bh = GetBreakHeight()
    breakFrame = CreateFrame("Frame", "SolaryMBreak", UIParent)
    breakFrame:SetSize(bw, bh)
    breakFrame:SetFrameStrata("HIGH")
    breakFrame:SetMovable(true)
    breakFrame:EnableMouse(true)
    breakFrame:RegisterForDrag("LeftButton")
    breakFrame:SetScript("OnDragStart", breakFrame.StartMoving)
    breakFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePos("break", self)
    end)
    LoadFramePos("break", breakFrame, "TOPLEFT", 20, -20)

    local bg = breakFrame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.04,0.04,0.06,0.9)

    for _, t in ipairs(BORDER) do
        local l = breakFrame:CreateTexture(nil,"BORDER")
        l:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
    end

    local img = breakFrame:CreateTexture(nil,"ARTWORK")
    img:SetSize(bw*0.6, bh*0.6)
    img:SetPoint("TOP", breakFrame, "TOP", 0, -10)
    img:SetTexture("Interface\\AddOns\\SolaryM\\Media\\Break\\break.tga")
    breakFrame._img = img

    local timerLbl = breakFrame:CreateFontString(nil,"OVERLAY")
    timerLbl:SetFont("Fonts\\FRIZQT__.TTF", GetBreakFontSize(), "OUTLINE")
    timerLbl:SetPoint("BOTTOM", breakFrame, "BOTTOM", 0, 12)
    timerLbl:SetTextColor(1,0.9,0.2,1)
    timerLbl:SetText("5:00")
    breakFrame._timer = timerLbl

    breakFrame:Hide()
end

local function ApplyBreakSize()
    if not breakFrame then return end
    local bw, bh = GetBreakWidth(), GetBreakHeight()
    breakFrame:SetSize(bw, bh)
    if breakFrame._img   then breakFrame._img:SetSize(bw*0.6, bh*0.6) end
    if breakFrame._timer then breakFrame._timer:SetFont("Fonts\\FRIZQT__.TTF", GetBreakFontSize(), "OUTLINE") end
    if moverBreak        then moverBreak:SetAllPoints(breakFrame) end
end

-- ============================================================
-- RESIZE HANDLE
-- ============================================================
local function MakeBreakResizeHandle(parent, anchor, w, h, onResize)
    local handle = CreateFrame("Frame", nil, parent)
    handle:SetSize(w, h)
    handle:EnableMouse(true)
    handle:SetFrameStrata("DIALOG")
    local tex = handle:CreateTexture(nil,"OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.7)
    handle:SetScript("OnEnter", function()
        if anchor == "RIGHT" then
            SetCursor("Interface\\CURSOR\\ui-cursor-sizer-left-right")
        else
            SetCursor("Interface\\CURSOR\\ui-cursor-sizer-up-down")
        end
    end)
    handle:SetScript("OnLeave", function() ResetCursor() end)
    local sx, sy = 0, 0
    handle:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        sx, sy = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local sc = UIParent:GetEffectiveScale()
            onResize((cx-sx)/sc, (cy-sy)/sc)
            sx, sy = cx, cy
        end)
    end)
    handle:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        ResetCursor()
    end)
    return handle
end

local function EnsureBreakResizePanel()
    if breakResizePanel then return end
    breakResizePanel = CreateFrame("Frame", nil, UIParent)
    breakResizePanel:SetSize(130, 42)
    breakResizePanel:SetFrameStrata("TOOLTIP")
    local bg = breakResizePanel:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0.85)
    local lbl = breakResizePanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    breakResizePanel._lbl = lbl
    breakResizePanel:Hide()
end

local function UpdateBreakResizePanel()
    if not breakResizePanel then return end
    breakResizePanel._lbl:SetText(string.format("W: %d  H: %d\nTexte: %d", GetBreakWidth(), GetBreakHeight(), GetBreakFontSize()))
end

local function ShowBreakHandles()
    if not breakFrame then return end
    EnsureBreakResizePanel()
    breakResizePanel:ClearAllPoints()
    breakResizePanel:SetPoint("BOTTOMLEFT", breakFrame, "TOPLEFT", 0, 4)
    breakResizePanel:Show()
    UpdateBreakResizePanel()

    if not breakHandleR then
        breakHandleR = MakeBreakResizeHandle(breakFrame, "RIGHT", 8, 30, function(dx, dy)
            local newW = math.max(BREAK_W_MIN, math.min(BREAK_W_MAX, GetBreakWidth() + dx))
            SolaryMDB.breakf = SolaryMDB.breakf or {}
            SolaryMDB.breakf.width = math.floor(newW)
            ApplyBreakSize()
            UpdateBreakResizePanel()
        end)
    end
    breakHandleR:ClearAllPoints()
    breakHandleR:SetPoint("RIGHT", breakFrame, "RIGHT", 0, 0)
    breakHandleR:Show()

    if not breakHandleB then
        breakHandleB = MakeBreakResizeHandle(breakFrame, "BOTTOM", 30, 8, function(dx, dy)
            -- dy négatif = drag vers le bas = agrandir
            local newH = math.max(80, math.min(400, GetBreakHeight() - math.floor(dy)))
            local newFS = math.max(BREAK_FONT_MIN, math.min(BREAK_FONT_MAX, math.floor(newH * 0.14)))
            SolaryMDB.breakf = SolaryMDB.breakf or {}
            SolaryMDB.breakf.height   = newH
            SolaryMDB.breakf.fontSize = newFS
            ApplyBreakSize()
            UpdateBreakResizePanel()
        end)
    end
    breakHandleB:ClearAllPoints()
    breakHandleB:SetPoint("BOTTOM", breakFrame, "BOTTOM", 0, 0)
    breakHandleB:Show()
end

local function HideBreakHandles()
    if breakHandleR      then breakHandleR:Hide() end
    if breakHandleB      then breakHandleB:Hide() end
    if breakResizePanel  then breakResizePanel:Hide() end
end

local function CreateUpdateFrame()
    if updateFrame then return end
    updateFrame = CreateFrame("Frame","SolaryMUpdate",UIParent)
    updateFrame:SetSize(320,180)
    updateFrame:SetFrameStrata("DIALOG")
    updateFrame:SetMovable(true); updateFrame:EnableMouse(true)
    updateFrame:RegisterForDrag("LeftButton")
    updateFrame:SetScript("OnDragStart", updateFrame.StartMoving)
    updateFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePos("update", self)
    end)
    LoadFramePos("update", updateFrame, "CENTER", 0, 100)

    local bg = updateFrame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.04,0.04,0.06,0.95)
    for _, t in ipairs(BORDER) do
        local l = updateFrame:CreateTexture(nil,"BORDER")
        l:SetColorTexture(1,0.4,0.1,1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
    end

    local img = updateFrame:CreateTexture(nil,"ARTWORK")
    img:SetSize(160,100); img:SetPoint("TOP",updateFrame,"TOP",0,-10)
    img:SetTexture("Interface\\AddOns\\SolaryM\\Media\\update")

    local lbl = updateFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    lbl:SetPoint("BOTTOM",updateFrame,"BOTTOM",0,36)
    lbl:SetTextColor(1,0.9,0.2,1); lbl:SetText("Mise à jour reçue !")
    updateFrame._lbl = lbl

    local subLbl = updateFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    subLbl:SetPoint("BOTTOM",updateFrame,"BOTTOM",0,18)
    subLbl:SetTextColor(0.8,0.8,0.8,1)
    updateFrame._sub = subLbl

    local closeBtn = CreateFrame("Button",nil,updateFrame,"UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT",updateFrame,"TOPRIGHT",-2,-2)
    closeBtn:SetScript("OnClick", function() updateFrame:Hide() end)

    updateFrame:Hide()
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function SM.StartBreak(seconds)
    CreateBreakFrame()
    if breakTicker and not breakTicker:IsCancelled() then breakTicker:Cancel() end
    if breakHideTimer then breakHideTimer:Cancel(); breakHideTimer = nil end
    UIFrameFadeRemoveFrame(breakFrame)
    breakFrame:SetAlpha(1)
    if breakFrame._img then
        local path
        if SM._breakForcedImage and SM.GetBreakImagePath then
            path = SM.GetBreakImagePath(SM._breakForcedImage)
            SM._breakForcedImage = nil
        elseif SM.GetRandomBreakImage then
            path = SM.GetRandomBreakImage()
        end
        if path then breakFrame._img:SetTexture(path) end
    end
    local endTime = GetTime() + seconds
    breakFrame:Show()
    breakTicker = C_Timer.NewTicker(0.5, function()
        local remaining = math.max(0, endTime - GetTime())
        local mins = math.floor(remaining/60)
        local secs = math.floor(remaining%60)
        breakFrame._timer:SetText(string.format("%d:%02d", mins, secs))
        if remaining <= 0 then
            breakTicker:Cancel()
            UIFrameFadeOut(breakFrame, 1, 1, 0)
            breakHideTimer = C_Timer.NewTimer(1, function() breakFrame:Hide(); breakHideTimer = nil end)
        end
    end)
end

function SM.StopBreak()
    if breakTicker and not breakTicker:IsCancelled() then breakTicker:Cancel() end
    if breakHideTimer then breakHideTimer:Cancel(); breakHideTimer = nil end
    UIFrameFadeRemoveFrame(breakFrame)
    breakFrame:SetAlpha(1)
    if breakFrame then breakFrame:Hide() end
    -- Annule aussi le break BigWigs
    local channel = IsInGroup(2) and "INSTANCE_CHAT" or "RAID"
    if IsInGroup() then
        local myName = UnitName("player")
        C_ChatInfo.SendAddonMessage("BigWigs", "P^Break^0", channel)
        if BigWigsLoader then
            BigWigsLoader.SendMessage({}, "BigWigs_PluginComm", "Break", 0, myName)
        end
        -- Broadcaster le stop aux membres SolaryM pour cacher leur image
        if AceComm and AceSerializer then
            local smChannel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
            if smChannel then
                local data = { type="stopbreak", sender=myName }
                AceComm:SendCommMessage(COMM_PREFIX, AceSerializer:Serialize(data), smChannel)
            end
        end
    end
end

function SM.BroadcastBreak(seconds)
    if not (SM.IsEditor() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        SM.Print("Tu n'as pas les droits."); return
    end
    local mins = math.floor(seconds / 60)

    -- Déclenche le break BigWigs via le même canal que plugin:Sync("Break", seconds)
    -- BW plugin Sync envoie "P^Break^seconds" sur le prefix "BigWigs"
    -- BW le reçoit, fire BigWigs_PluginComm(msg="Break", seconds, sender)
    -- que le plugin Break intercepte via plugin:BigWigs_PluginComm
    local channel = IsInGroup(2) and "INSTANCE_CHAT" or "RAID"
    if IsInGroup() then
        local myName = UnitName("player")
        -- Message BigWigs plugin sync : "P^Break^seconds"
        C_ChatInfo.SendAddonMessage("BigWigs", "P^Break^" .. seconds, channel)
        -- Aussi déclencher localement (BW ne s'envoie pas le message à soi-même)
        if BigWigsLoader then
            BigWigsLoader.SendMessage({}, "BigWigs_PluginComm", "Break", seconds, myName)
        end
    end

    -- Broadcast SolaryM aux membres du raid
    if AceComm and AceSerializer then
        local smChannel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
        if smChannel then
            local data = { type="break", seconds=seconds, sender=UnitName("player") }
            AceComm:SendCommMessage(COMM_PREFIX, AceSerializer:Serialize(data), smChannel)
        end
    end

    SM.StartBreak(seconds)
    SM.Print("Break de " .. mins .. " min broadcasté.")
end

function SM.ShowUpdateAlert(sender, version)
    CreateUpdateFrame()
    updateFrame._lbl:SetText("Mise à jour reçue ! (v" .. (version or "?") .. ")")
    updateFrame._sub:SetText("De : " .. (sender or "?") .. "   — /reload pour appliquer")
    updateFrame:SetAlpha(0); updateFrame:Show()
    UIFrameFadeIn(updateFrame, 0.3, 0, 1)
    C_Timer.NewTimer(15, function()
        if updateFrame:IsShown() then
            UIFrameFadeOut(updateFrame, 0.5, 1, 0)
            C_Timer.NewTimer(0.5, function() updateFrame:Hide() end)
        end
    end)
end

-- ============================================================
-- RÉCEPTION COMM
-- ============================================================
local function OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end
    if not AceSerializer then return end
    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then return end
    if data.type == "break" and data.seconds then
        if sender ~= UnitName("player") then SM.StartBreak(data.seconds) end
    elseif data.type == "stopbreak" then
        local me = UnitName("player")
        local senderShort = sender and (sender:match("^([^%-]+)") or sender) or ""
        local meShort = me and (me:match("^([^%-]+)") or me) or ""
        if senderShort ~= meShort then SM.StopBreak() end
    end
end

-- ============================================================
-- TOGGLE MOVER + RESIZE
-- ============================================================
function SM.ToggleBreakLock(locked)
    CreateBreakFrame()
    if locked == nil then
        breakLocked = not breakLocked
        locked = breakLocked
    else
        breakLocked = locked
    end

    if locked then
        if moverBreak then moverBreak:Hide() end
        HideBreakHandles()
        if breakFrame._isMoverTest then
            breakFrame:Hide()
            breakFrame._isMoverTest = false
        end
    else
        if not moverBreak then
            moverBreak = CreateFrame("Frame", nil, breakFrame)
            moverBreak:SetAllPoints(breakFrame)
            local bg = moverBreak:CreateTexture(nil,"BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(0.04,0.04,0.06,0.8)
            for _, t in ipairs(BORDER) do
                local l = moverBreak:CreateTexture(nil,"BORDER")
                l:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],1)
                l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3],t[4])
            end
            local lbl = moverBreak:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            lbl:SetPoint("CENTER")
            lbl:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
            lbl:SetText("SolaryM — Break Timer (déplacer)")
            moverBreak:Hide()
        end
        moverBreak:Show()
        breakFrame._timer:SetText("5:00")
        breakFrame._isMoverTest = true
        breakFrame:Show()
        ShowBreakHandles()
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
    CreateBreakFrame()
    CreateUpdateFrame()
    if AceComm then
        AceComm:RegisterComm(COMM_PREFIX, OnCommReceived)
    end
end)
