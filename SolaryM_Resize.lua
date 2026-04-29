-- SolaryM_Resize.lua — Poignées de resize pour les cadres (mode /sm move)

SM.Resize = SM.Resize or {}
local R = SM.Resize

-- ============================================================
-- CRÉATION D'UNE POIGNÉE DE RESIZE
-- Retourne un frame "handle" attaché à `parent`
-- onResize(deltaX, deltaY) → callback appelé pendant le drag
-- ============================================================
local function MakeResizeHandle(parent, anchor, w, h, onResize)
    local handle = CreateFrame("Frame", nil, parent)
    handle:SetSize(w, h)
    handle:EnableMouse(true)
    handle:SetFrameStrata("DIALOG")

    local tex = handle:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.6)

    handle:SetScript("OnEnter", function()
        if anchor == "RIGHT" or anchor == "LEFT" then
            SetCursor("Interface\\CURSOR\\ui-cursor-sizer-left-right")
        else
            SetCursor("Interface\\CURSOR\\ui-cursor-sizer-up-down")
        end
    end)
    handle:SetScript("OnLeave", function()
        ResetCursor()
    end)

    local startX, startY = 0, 0
    handle:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        startX, startY = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local dx = (cx - startX) / scale
            local dy = (cy - startY) / scale
            startX, startY = cx, cy
            onResize(dx, dy)
        end)
    end)
    handle:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        ResetCursor()
    end)

    return handle
end

-- ============================================================
-- RESIZE DU CONTAINER ALERTES BOSS
-- Horizontal → largeur du cadre
-- Vertical → taille de police du texte
-- ============================================================
local alertHandleR  = nil  -- poignée droite  (→ largeur)
local alertHandleB  = nil  -- poignée bas     (→ taille texte)
local alertResizeFrame = nil  -- petit panel flottant avec les valeurs

local FONT_MIN, FONT_MAX = 10, 40
local WIDTH_MIN, WIDTH_MAX = 150, 700

local function GetAlertFontSize()
    return (SolaryMDB and SolaryMDB.alert and SolaryMDB.alert.fontSize) or 22
end

local function GetAlertWidth()
    return (SolaryMDB and SolaryMDB.alert and SolaryMDB.alert.width) or 380
end

local function ApplyAlertSettings()
    if not alertContainer then return end
    local w = GetAlertWidth()
    local fs = GetAlertFontSize()
    alertContainer:SetSize(w, alertContainer:GetHeight())
    -- Mettre à jour la taille de police de toutes les alertes actives
end

-- Mini-panel flottant qui affiche W/H en temps réel pendant le resize
local function EnsureResizePanel(parent)
    if alertResizeFrame then return alertResizeFrame end
    alertResizeFrame = CreateFrame("Frame", nil, parent)
    alertResizeFrame:SetSize(110, 42)
    alertResizeFrame:SetFrameStrata("TOOLTIP")
    local bg = alertResizeFrame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0.85)
    local lbl = alertResizeFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetPoint("CENTER"); lbl:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
    alertResizeFrame._lbl = lbl
    alertResizeFrame:Hide()
    return alertResizeFrame
end

local function UpdateResizePanel(w, fs)
    if not alertResizeFrame then return end
    alertResizeFrame._lbl:SetText(string.format("W: %d\nTaille: %d", w, fs))
end

function R.ShowAlertHandles()
    local container = SM.GetAlertContainer and SM.GetAlertContainer()
    if not container then return end

    EnsureResizePanel(UIParent)
    alertResizeFrame:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)
    alertResizeFrame:Show()
    UpdateResizePanel(GetAlertWidth(), GetAlertFontSize())

    -- Poignée DROITE : largeur (drag horizontal)
    if not alertHandleR then
        alertHandleR = MakeResizeHandle(container, "RIGHT", 8, 30,
            function(dx, dy)
                local newW = math.max(WIDTH_MIN, math.min(WIDTH_MAX, GetAlertWidth() + dx))
                SolaryMDB.alert = SolaryMDB.alert or {}
                SolaryMDB.alert.width = math.floor(newW)
                if SM.SetAlertWidth then SM.SetAlertWidth(newW) end
                UpdateResizePanel(math.floor(newW), GetAlertFontSize())
            end
        )
    end
    alertHandleR:ClearAllPoints()
    alertHandleR:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    alertHandleR:Show()

    -- Poignée BAS : taille de police (drag vertical, bas = plus petit / haut = plus grand)
    if not alertHandleB then
        alertHandleB = MakeResizeHandle(container, "BOTTOM", 30, 8,
            function(dx, dy)
                -- dy positif = drag vers le haut = plus grand
                local newFS = math.max(FONT_MIN, math.min(FONT_MAX, GetAlertFontSize() - math.floor(dy * 0.5)))
                SolaryMDB.alert = SolaryMDB.alert or {}
                SolaryMDB.alert.fontSize = newFS
                UpdateResizePanel(GetAlertWidth(), newFS)
            end
        )
    end
    alertHandleB:ClearAllPoints()
    alertHandleB:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
    alertHandleB:Show()
end

function R.HideAlertHandles()
    if alertHandleR  then alertHandleR:Hide() end
    if alertHandleB  then alertHandleB:Hide() end
    if alertResizeFrame then alertResizeFrame:Hide() end
end

-- ============================================================
-- APPLICATION DE LA TAILLE DE POLICE AUX ALERTES ACTIVES
-- Appelé depuis Alert.lua à chaque création d'alerte
-- ============================================================
function R.GetAlertFontSize()
    return GetAlertFontSize()
end

