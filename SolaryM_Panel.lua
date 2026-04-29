-- SolaryM_Panel.lua
-- v3.0.3 — Onglets : Spells | Boss Timers | Groupes | Invites | Memory Game | Paramètres | Changelogs | Notes

local mainFrame = nil
local activeTab = 1

local tabBtns   = {}
local tabFrames = {}

local PANEL_W   = 940   -- largeur zone de contenu
local PANEL_H   = 780
local HEADER_H  = 64    -- hauteur header custom
local SIDEBAR_W = 200   -- sidebar gauche avec onglets verticaux
local TOTAL_W   = PANEL_W + SIDEBAR_W
local TAB_H     = 32    -- gardé pour compatibilité
local CONTENT_Y = -HEADER_H  -- offset sous le header
local CONTENT_H = PANEL_H + CONTENT_Y - 8

-- ============================================================
-- TABS
-- ============================================================
local function ShowTab(idx)
    activeTab = idx
    for i, tb in ipairs(tabBtns) do
        if tb._bg then
            if i == idx then
                tb._bg:SetColorTexture(0.12, 0.07, 0.20, 1)
                if tb._lbl    then tb._lbl:SetTextColor(0.90, 0.82, 1.0, 1) end
                if tb._accent then tb._accent:Show() end
                if tb._ico    then tb._ico:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 1) end
            else
                tb._bg:SetColorTexture(0, 0, 0, 0)
                if tb._lbl    then tb._lbl:SetTextColor(0.55, 0.50, 0.62, 1) end
                if tb._accent then tb._accent:Hide() end
                if tb._ico    then tb._ico:SetVertexColor(0.48, 0.42, 0.58, 1) end
            end
        end
    end
    for i, f in ipairs(tabFrames) do if f then f:SetShown(i==idx) end end
end

-- ============================================================
-- MODAL : AJOUTER UN SORT
-- ============================================================
local addSpellModal = nil

local function OpenAddSpellModal()
    if addSpellModal then
        addSpellModal._reset()
        addSpellModal:ClearAllPoints()
        addSpellModal:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 8, 0)
        addSpellModal:Show()
        addSpellModal:Raise()
        return
    end

    local W, H = 440, 360
    local modal = CreateFrame("Frame", "SolaryMAddSpellModal", UIParent)
    addSpellModal = modal
    modal:SetSize(W, H)
    modal:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 8, 0)
    modal:SetFrameStrata("FULLSCREEN_DIALOG")
    modal:SetMovable(true)
    modal:EnableMouse(true)
    modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", modal.StartMoving)
    modal:SetScript("OnDragStop",  modal.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SolaryMAddSpellModal")

    -- Bordure + fond
    local bdr = modal:CreateTexture(nil, "BORDER")
    bdr:SetAllPoints(); bdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.6)
    local bg = modal:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.05, 0.04, 0.09, 0.97)

    -- Header
    local hdr = CreateFrame("Frame", nil, modal)
    hdr:SetPoint("TOPLEFT"); hdr:SetPoint("TOPRIGHT"); hdr:SetHeight(36)
    local hBg = hdr:CreateTexture(nil, "BACKGROUND"); hBg:SetAllPoints(); hBg:SetColorTexture(0.04, 0.04, 0.08, 1)
    local hSep = hdr:CreateTexture(nil, "ARTWORK")
    hSep:SetPoint("BOTTOMLEFT"); hSep:SetPoint("BOTTOMRIGHT"); hSep:SetHeight(1)
    hSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.5)
    hdr:EnableMouse(true); hdr:RegisterForDrag("LeftButton")
    hdr:SetScript("OnDragStart", function() modal:StartMoving() end)
    hdr:SetScript("OnDragStop",  function() modal:StopMovingOrSizing() end)
    local hTitle = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTitle:SetPoint("LEFT", hdr, "LEFT", 12, 0)
    hTitle:SetTextColor(0.85, 0.80, 1.0, 1)
    hTitle:SetText(SM.T("add_spell_btn") or "AJOUTER UN SORT")

    local xBtn = CreateFrame("Button", nil, hdr)
    xBtn:SetSize(28, 28); xBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    local xBg = xBtn:CreateTexture(nil,"BACKGROUND"); xBg:SetAllPoints(); xBg:SetColorTexture(0.32,0.07,0.07,0.85)
    local xLbl = xBtn:CreateFontString(nil,"OVERLAY","GameFontNormal"); xLbl:SetAllPoints()
    xLbl:SetText("\195\151"); xLbl:SetTextColor(1,0.5,0.5,1)
    xBtn:SetScript("OnClick", function() modal:Hide() end)

    local PAD = 14
    local y = -48

    -- Spell ID
    SM.Lbl(modal, "ID du Sort", nil, PAD, y)
    local idIn = SM.Input(modal, W - PAD*2, 22, "Ex: 1249262")
    idIn:SetPoint("TOPLEFT", modal, "TOPLEFT", PAD, y - 16)
    y = y - 44

    local nameLbl = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", modal, "TOPLEFT", PAD, y)
    nameLbl:SetPoint("RIGHT", modal, "RIGHT", -PAD, 0)
    nameLbl:SetJustifyH("LEFT"); nameLbl:SetTextColor(0.75, 0.68, 0.92, 1); nameLbl:SetText("—")
    y = y - 24

    idIn:SetScript("OnTextChanged", function(s)
        local id = tonumber(SM.GetVal(s))
        if not id then nameLbl:SetText("—"); return end
        local entry = SM.GetSpellEntry(id)
        if entry then
            local dname = (SM.LANG=="fr" and entry.fr and entry.fr~="" and entry.fr) or entry.en or tostring(id)
            nameLbl:SetText("|cFF88FF88"..dname.."|r  ["..entry.boss.."] "..entry.zone)
        else
            local sname = C_Spell and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) or nil
            nameLbl:SetText(sname and ("|cFFFFD700"..sname.."|r") or "|cFFAAAAAA? Sort inconnu|r")
        end
    end)

    -- Callout
    SM.Lbl(modal, "Callout (texte affiché à l'écran)", nil, PAD, y)
    local callIn = SM.Input(modal, W - PAD*2, 22, "Ex: DODGE")
    callIn:SetPoint("TOPLEFT", modal, "TOPLEFT", PAD, y - 16)
    y = y - 44

    -- TTS
    SM.Lbl(modal, "TTS (optionnel, texte lu à voix haute)", nil, PAD, y)
    local ttsIn = SM.Input(modal, W - PAD*2, 22, "Ex: dodge")
    ttsIn:SetPoint("TOPLEFT", modal, "TOPLEFT", PAD, y - 16)
    y = y - 44

    -- Zone + Boss dropdowns
    local HALF = math.floor((W - PAD*2 - 8) / 2)
    SM.Lbl(modal, "Zone / Instance", nil, PAD, y)
    SM.Lbl(modal, "Boss", nil, PAD + HALF + 8, y)

    local selectedZone = nil
    local selectedBoss = nil

    local function MakeDropBtn(parent, x, w, hint)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(w, 22); btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
        local bg  = btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints();  bg:SetColorTexture(0.10,0.08,0.16,1)
        local bdr = btn:CreateTexture(nil,"BORDER");     bdr:SetAllPoints(); bdr:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.25)
        local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        lbl:SetPoint("LEFT",btn,"LEFT",8,0); lbl:SetPoint("RIGHT",btn,"RIGHT",-14,0)
        lbl:SetJustifyH("LEFT"); lbl:SetTextColor(0.55,0.50,0.68,1); lbl:SetText(hint)
        local arr = btn:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        arr:SetPoint("RIGHT",btn,"RIGHT",-4,0); arr:SetText("v")
        btn._lbl  = lbl
        return btn
    end

    local zDropBtn = MakeDropBtn(modal, PAD,            HALF, "— choisir —")
    local bDropBtn = MakeDropBtn(modal, PAD + HALF + 8, HALF, "— choisir —")

    local zMenu = CreateFrame("Frame", nil, UIParent)
    zMenu:SetFrameStrata("TOOLTIP"); zMenu:Hide()
    local zMBg = zMenu:CreateTexture(nil,"BACKGROUND"); zMBg:SetAllPoints(); zMBg:SetColorTexture(0.08,0.06,0.14,0.98)

    local bMenu = CreateFrame("Frame", nil, UIParent)
    bMenu:SetFrameStrata("TOOLTIP"); bMenu:Hide()
    local bMBg = bMenu:CreateTexture(nil,"BACKGROUND"); bMBg:SetAllPoints(); bMBg:SetColorTexture(0.08,0.06,0.14,0.98)

    local function MakeMenuItem(parent, w, i, text, onClick)
        local item = CreateFrame("Button", nil, parent)
        item:SetSize(w, 22); item:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i-1)*22)
        local ibg = item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
        local ilbl = item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        ilbl:SetPoint("LEFT",item,"LEFT",8,0); ilbl:SetText(text); ilbl:SetTextColor(0.82,0.75,0.95,1)
        item:SetScript("OnEnter",function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
        item:SetScript("OnLeave",function() ibg:SetColorTexture(0,0,0,0) end)
        item:SetScript("OnClick", onClick)
    end

    local function RebuildBossMenu()
        for _, c in ipairs({bMenu:GetChildren()}) do c:Hide() end
        local bosses = {}
        if selectedZone then
            for _, z in ipairs(SM.SpellDB) do
                if z.zone == selectedZone then
                    for _, b in ipairs(z.bosses) do table.insert(bosses, b.boss) end
                    break
                end
            end
        end
        if #bosses == 0 then bMenu:Hide(); return end
        bMenu:SetSize(HALF, #bosses * 22)
        for i, bname in ipairs(bosses) do
            local bn = bname
            MakeMenuItem(bMenu, HALF, i, bname, function()
                selectedBoss = bn
                bDropBtn._lbl:SetText(bn); bDropBtn._lbl:SetTextColor(0.82,0.75,0.95,1)
                bMenu:Hide()
            end)
        end
    end

    local function RebuildZoneMenu()
        for _, c in ipairs({zMenu:GetChildren()}) do c:Hide() end
        local zones = {}
        for _, z in ipairs(SM.SpellDB) do table.insert(zones, z.zone) end
        zMenu:SetSize(HALF, #zones * 22)
        for i, zname in ipairs(zones) do
            local zn = zname
            MakeMenuItem(zMenu, HALF, i, zname, function()
                selectedZone = zn
                zDropBtn._lbl:SetText(zn); zDropBtn._lbl:SetTextColor(0.82,0.75,0.95,1)
                selectedBoss = nil
                bDropBtn._lbl:SetText("— choisir —"); bDropBtn._lbl:SetTextColor(0.55,0.50,0.68,1)
                zMenu:Hide()
            end)
        end
    end

    zDropBtn:SetScript("OnClick", function()
        if zMenu:IsShown() then zMenu:Hide(); return end
        bMenu:Hide(); RebuildZoneMenu()
        zMenu:ClearAllPoints(); zMenu:SetPoint("TOPLEFT", zDropBtn, "BOTTOMLEFT", 0, -2); zMenu:Show()
    end)
    bDropBtn:SetScript("OnClick", function()
        if bMenu:IsShown() then bMenu:Hide(); return end
        zMenu:Hide(); RebuildBossMenu()
        bMenu:ClearAllPoints(); bMenu:SetPoint("TOPLEFT", bDropBtn, "BOTTOMLEFT", 0, -2); bMenu:Show()
    end)
    y = y - 44

    -- Son
    SM.Lbl(modal, "Son (optionnel)", nil, PAD, y)
    y = y - 18
    local selectedSnd = "(aucun)"
    local SND_W = W - PAD*2 - 54
    local sndDrop = CreateFrame("Button", nil, modal)
    sndDrop:SetSize(SND_W, 24); sndDrop:SetPoint("TOPLEFT", modal, "TOPLEFT", PAD, y)
    local sBg = sndDrop:CreateTexture(nil,"BACKGROUND"); sBg:SetAllPoints(); sBg:SetColorTexture(0.10,0.08,0.16,1)
    local sBdr = sndDrop:CreateTexture(nil,"BORDER"); sBdr:SetAllPoints(); sBdr:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.25)
    local sLbl = sndDrop:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    sLbl:SetPoint("LEFT",sndDrop,"LEFT",8,0); sLbl:SetText(selectedSnd); sLbl:SetTextColor(0.9,0.9,0.9,1)
    local sArr = sndDrop:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    sArr:SetPoint("RIGHT",sndDrop,"RIGHT",-6,0); sArr:SetText("v")
    local sTest = SM.BBtn(modal, 46, 24, "Test", function()
        if selectedSnd ~= "(aucun)" then
            PlaySoundFile("Interface\\AddOns\\SolaryM\\Media\\Sounds\\"..selectedSnd..".ogg","Master")
        end
    end)
    sTest:SetPoint("LEFT", sndDrop, "RIGHT", 4, 0)
    local sMenu = CreateFrame("Frame", nil, UIParent)
    sMenu:SetSize(SND_W, 22); sMenu:SetFrameStrata("TOOLTIP"); sMenu:Hide()
    local sMBg = sMenu:CreateTexture(nil,"BACKGROUND"); sMBg:SetAllPoints(); sMBg:SetColorTexture(0.08,0.06,0.14,0.98)
    sndDrop:SetScript("OnClick", function()
        if sMenu:IsShown() then sMenu:Hide(); return end
        for _, c in ipairs({sMenu:GetChildren()}) do c:Hide() end
        local SNDS = {"(aucun)"}
        for _, s in ipairs(SM.MediaSounds or {}) do table.insert(SNDS, s) end
        sMenu:SetHeight(#SNDS * 22)
        for i, sn in ipairs(SNDS) do
            local item = CreateFrame("Button", nil, sMenu)
            item:SetSize(SND_W, 22); item:SetPoint("TOPLEFT", sMenu, "TOPLEFT", 0, -(i-1)*22)
            local ibg = item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
            local ilbl = item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            ilbl:SetPoint("LEFT",item,"LEFT",8,0); ilbl:SetText(sn); ilbl:SetTextColor(0.85,0.85,0.9,1)
            item:SetScript("OnEnter",function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
            item:SetScript("OnLeave",function() ibg:SetColorTexture(0,0,0,0) end)
            local sv = sn
            item:SetScript("OnClick",function() selectedSnd=sv; sLbl:SetText(sv); sMenu:Hide() end)
        end
        sMenu:ClearAllPoints()
        sMenu:SetPoint("TOPLEFT", sndDrop, "BOTTOMLEFT", 0, -2)
        sMenu:Show()
    end)

    -- Boutons
    local BW = math.floor((W - PAD*2 - 8) / 2)
    local saveBtn = SM.OBtn(modal, BW, 28, "ENREGISTRER", function()
        local id = tonumber(SM.GetVal(idIn))
        if not id then SM.Print("Entre un spell ID valide."); return end
        local callout = SM.GetVal(callIn)
        if callout == "" then SM.Print("Entre un callout."); return end
        local tts  = SM.GetVal(ttsIn)
        local snd  = selectedSnd ~= "(aucun)" and selectedSnd or ""
        local zone = selectedZone or "Personnalisé"
        local boss = selectedBoss or "Personnalisé"

        SolaryMDB.customSpells = SolaryMDB.customSpells or {}
        for i = #SolaryMDB.customSpells, 1, -1 do
            if SolaryMDB.customSpells[i].id == id then table.remove(SolaryMDB.customSpells, i) end
        end
        table.insert(SolaryMDB.customSpells, {
            id=id, callout=callout,
            tts=tts~="" and tts or nil,
            snd=snd~="" and snd or nil,
            zone=zone, boss=boss,
        })

        SolaryMDB.spells[id] = callout
        SM.PendingSpellChanges[id] = callout
        SolaryMDB.spells_tts = SolaryMDB.spells_tts or {}
        if tts ~= "" then
            SolaryMDB.spells_tts[id] = tts
            SM.PendingSpellChanges["__tts_"..id] = tts
        else
            SolaryMDB.spells_tts[id] = nil
            SM.PendingSpellChanges["__tts_"..id] = "__removed__"
        end
        SolaryMDB.spells_snd = SolaryMDB.spells_snd or {}
        if snd ~= "" then SolaryMDB.spells_snd[id] = snd else SolaryMDB.spells_snd[id] = nil end

        SM.InjectCustomSpell({ id=id, callout=callout, zone=zone, boss=boss })
        SM._UpdatePendingCount()
        SM.RefreshSpellList()
        SM.Print("Sort |cFFFFD700"..id.."|r ajouté : \""..callout.."\"")
        modal:Hide()
    end)
    saveBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", PAD, 14)

    local cancelBtn = SM.RBtn(modal, BW, 28, "ANNULER", function() modal:Hide() end)
    cancelBtn:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -PAD, 14)

    modal._reset = function()
        SM.SetVal(idIn, ""); SM.SetVal(callIn, ""); SM.SetVal(ttsIn, "")
        nameLbl:SetText("—")
        selectedSnd = "(aucun)"; sLbl:SetText("(aucun)")
        selectedZone = nil; zDropBtn._lbl:SetText("— choisir —"); zDropBtn._lbl:SetTextColor(0.55,0.50,0.68,1)
        selectedBoss = nil; bDropBtn._lbl:SetText("— choisir —"); bDropBtn._lbl:SetTextColor(0.55,0.50,0.68,1)
        idIn:SetFocus()
    end

    modal:Show()
    modal:Raise()
    idIn:SetFocus()
end

-- ============================================================
-- ONGLET 1 : SPELLS — trié par Zone → Boss → Sort
-- ============================================================
local spellBtns     = {}
local selSpellId    = nil
-- Changements en attente de broadcast (vide après chaque envoi)
SM.PendingSpellChanges = {}

local function BuildSpellsTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    local COL_L  = 420
    local COL_R  = PANEL_W - COL_L - 16
    local COL_H  = CONTENT_H + 4
    local HDR_H  = 44
    local FILT_H = 40

    -- ═══════════════════════════════════════════════════
    -- COLONNE GAUCHE
    -- ═══════════════════════════════════════════════════
    local cL = CreateFrame("Frame", nil, f)
    cL:SetSize(COL_L, COL_H); cL:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -4)

    -- Header gauche
    local cLHdr = CreateFrame("Frame", nil, cL)
    cLHdr:SetPoint("TOPLEFT", cL, "TOPLEFT", 0, 0)
    cLHdr:SetPoint("TOPRIGHT", cL, "TOPRIGHT", 0, 0)
    cLHdr:SetHeight(HDR_H)
    local cLHBg = cLHdr:CreateTexture(nil,"BACKGROUND")
    cLHBg:SetAllPoints(); cLHBg:SetColorTexture(0.05, 0.04, 0.09, 1)
    local cLHSep = cLHdr:CreateTexture(nil,"ARTWORK")
    cLHSep:SetPoint("BOTTOMLEFT"); cLHSep:SetPoint("BOTTOMRIGHT"); cLHSep:SetHeight(1)
    cLHSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)

    local cLTitle = cLHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    cLTitle:SetPoint("LEFT", cLHdr, "LEFT", 12, 0)
    cLTitle:SetTextColor(0.85, 0.80, 1.0, 1)
    cLTitle:SetText(SM.T("spells_header"))

    local addBtn = SM.OBtn(cLHdr, 138, 24, SM.T("add_spell_btn") or "AJOUTER UN SORT", function()
        OpenAddSpellModal()
    end)
    addBtn:SetPoint("RIGHT", cLHdr, "RIGHT", -8, 0)

    -- Rangée filtre
    local cLFilt = CreateFrame("Frame", nil, cL)
    cLFilt:SetPoint("TOPLEFT",  cL, "TOPLEFT",  0, -HDR_H)
    cLFilt:SetPoint("TOPRIGHT", cL, "TOPRIGHT", 0, -HDR_H)
    cLFilt:SetHeight(FILT_H)
    local cLFBg = cLFilt:CreateTexture(nil,"BACKGROUND")
    cLFBg:SetAllPoints(); cLFBg:SetColorTexture(0.06, 0.05, 0.10, 1)

    local ZONE_W = 152
    local searchInput = SM.Input(cLFilt, COL_L - ZONE_W - 20, 26, SM.T("search_placeholder"))
    searchInput:SetPoint("LEFT", cLFilt, "LEFT", 6, 0)
    searchInput:SetScript("OnTextChanged", function() SM.RefreshSpellList() end)
    f._searchInput = searchInput

    -- Dropdown zone
    local zoneFilter = nil
    local zDropBtn = CreateFrame("Button", nil, cLFilt)
    zDropBtn:SetSize(ZONE_W, 26)
    zDropBtn:SetPoint("RIGHT", cLFilt, "RIGHT", -6, 0)
    local zDropBg = zDropBtn:CreateTexture(nil,"BACKGROUND")
    zDropBg:SetAllPoints(); zDropBg:SetColorTexture(0.10, 0.08, 0.16, 1)
    local zDropBdr = zDropBtn:CreateTexture(nil,"BORDER")
    zDropBdr:SetAllPoints(); zDropBdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.25)
    local zDropLbl = zDropBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    zDropLbl:SetPoint("LEFT", zDropBtn, "LEFT", 6, 0)
    zDropLbl:SetPoint("RIGHT", zDropBtn, "RIGHT", -14, 0)
    zDropLbl:SetJustifyH("LEFT")
    zDropLbl:SetTextColor(0.75, 0.68, 0.92, 1)
    zDropLbl:SetText(SM.T("all_zones") or "Toutes les zones")
    local zDropArr = zDropBtn:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    zDropArr:SetPoint("RIGHT", zDropBtn, "RIGHT", -4, 0); zDropArr:SetText("v")

    local zMenu = CreateFrame("Frame", nil, UIParent)
    zMenu:SetSize(ZONE_W, 22)
    zMenu:SetFrameStrata("TOOLTIP"); zMenu:Hide()
    local zMenuBg = zMenu:CreateTexture(nil,"BACKGROUND")
    zMenuBg:SetAllPoints(); zMenuBg:SetColorTexture(0.08, 0.06, 0.14, 0.98)

    local function RebuildZoneMenu()
        for _, c in ipairs({zMenu:GetChildren()}) do c:Hide() end
        local zones = {}
        table.insert(zones, {z="__all__", d=SM.T("all_zones") or "Toutes les zones"})
        for _, zn in ipairs(SM.SpellDB or {}) do
            table.insert(zones, {z=zn.zone, d=zn.zone})
        end
        zMenu:SetHeight(#zones * 22)
        for i, entry in ipairs(zones) do
            local item = CreateFrame("Button", nil, zMenu)
            item:SetSize(ZONE_W, 22)
            item:SetPoint("TOPLEFT", zMenu, "TOPLEFT", 0, -(i-1)*22)
            local ibg = item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
            local ilbl = item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            ilbl:SetPoint("LEFT",item,"LEFT",8,0); ilbl:SetJustifyH("LEFT")
            ilbl:SetText(entry.d); ilbl:SetTextColor(0.82, 0.75, 0.95, 1)
            item:SetScript("OnEnter",function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
            item:SetScript("OnLeave",function() ibg:SetColorTexture(0,0,0,0) end)
            local ez, ed = entry.z, entry.d
            item:SetScript("OnClick",function()
                if ez == "__all__" then zoneFilter = nil else zoneFilter = ez end
                zDropLbl:SetText(ed); zMenu:Hide(); SM.RefreshSpellList()
            end)
        end
    end
    zDropBtn:SetScript("OnClick", function()
        if zMenu:IsShown() then zMenu:Hide(); return end
        RebuildZoneMenu()
        zMenu:ClearAllPoints()
        zMenu:SetPoint("TOPLEFT", zDropBtn, "BOTTOMLEFT", 0, -2)
        zMenu:Show()
    end)
    f._zoneFilter = function() return zoneFilter end

    -- Liste de sorts
    local listH = COL_H - HDR_H - FILT_H - 22
    local spellScroll = SM.Scroll(cL, COL_L - 4, listH)
    spellScroll:SetPoint("TOPLEFT", cL, "TOPLEFT", 2, -(HDR_H + FILT_H))
    f._spellScroll = spellScroll

    -- Compteur
    local countLbl = cL:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    countLbl:SetPoint("BOTTOMLEFT", cL, "BOTTOMLEFT", 8, 4)
    countLbl:SetTextColor(0.45, 0.40, 0.58, 1)
    countLbl:SetText("0 sorts trouvés")
    f._countLbl = countLbl

    -- ═══════════════════════════════════════════════════
    -- COLONNE DROITE
    -- ═══════════════════════════════════════════════════
    local cR = CreateFrame("Frame", nil, f)
    cR:SetSize(COL_R, COL_H); cR:SetPoint("TOPLEFT", cL, "TOPRIGHT", 8, 0)
    SM.BG(cR, SM.DK[1], SM.DK[2], SM.DK[3], 1)

    -- Header droit
    local cRHdr = CreateFrame("Frame", nil, cR)
    cRHdr:SetPoint("TOPLEFT", cR, "TOPLEFT", 0, 0)
    cRHdr:SetPoint("TOPRIGHT", cR, "TOPRIGHT", 0, 0)
    cRHdr:SetHeight(HDR_H)
    local cRHBg = cRHdr:CreateTexture(nil,"BACKGROUND")
    cRHBg:SetAllPoints(); cRHBg:SetColorTexture(0.05, 0.04, 0.09, 1)
    local cRHSep = cRHdr:CreateTexture(nil,"ARTWORK")
    cRHSep:SetPoint("BOTTOMLEFT"); cRHSep:SetPoint("BOTTOMRIGHT"); cRHSep:SetHeight(1)
    cRHSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)
    local cRTitle = cRHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    cRTitle:SetPoint("LEFT", cRHdr, "LEFT", 12, 0)
    cRTitle:SetTextColor(0.85, 0.80, 1.0, 1)
    cRTitle:SetText(SM.T("edit_callout"))

    local y = -(HDR_H + 12)

    SM.Lbl(cR, SM.T("spell_id"), nil, 8, y)
    local idInput = SM.Input(cR, COL_R-16, 22, "Ex: 1249262")
    idInput:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y-14)
    f._idInput = idInput
    y = y - 40

    SM.Lbl(cR, SM.T("spell_name"), nil, 8, y)
    local nameDisplay = cR:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    nameDisplay:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y-14)
    nameDisplay:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    nameDisplay:SetJustifyH("LEFT"); nameDisplay:SetTextColor(0.8,0.8,0.8,1); nameDisplay:SetText("—")
    f._nameDisplay = nameDisplay
    y = y - 28

    SM.Lbl(cR, SM.T("spell_note"), nil, 8, y)
    local noteDisplay = cR:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    noteDisplay:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y-14)
    noteDisplay:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    noteDisplay:SetJustifyH("LEFT"); noteDisplay:SetTextColor(0.5,0.5,0.5,1); noteDisplay:SetText("—")
    f._noteDisplay = noteDisplay
    y = y - 36

    idInput:SetScript("OnTextChanged", function(s)
        local id = tonumber(SM.GetVal(s))
        if not id then nameDisplay:SetText("—"); noteDisplay:SetText("—"); return end
        local entry = SM.GetSpellEntry(id)
        if entry then
            local dname = (SM.LANG=="fr" and entry.fr~="" and entry.fr) or entry.en or tostring(entry.id)
            nameDisplay:SetText(dname)
            noteDisplay:SetText(entry.boss and ("["..entry.boss.."] "..entry.zone) or "—")
        else
            local sname = C_Spell and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) or nil
            nameDisplay:SetText(sname or SM.T("unknown_spell")); noteDisplay:SetText("—")
        end
    end)

    SM.Lbl(cR, SM.T("callout_screen"), nil, 8, y)
    local calloutInput = SM.Input(cR, COL_R-16, 24, SM.T("callout_ph"))
    calloutInput:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y-16)
    f._calloutInput = calloutInput
    y = y - 46

    SM.Lbl(cR, SM.T("tts_label"), nil, 8, y)
    local ttsInput = SM.Input(cR, COL_R-16, 24, SM.T("tts_ph"))
    ttsInput:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y-16)
    f._ttsInput = ttsInput
    y = y - 46

    SM.Lbl(cR, SM.T("sound_label"), nil, 8, y)
    y = y - 20

    local function GetSounds()
        local t = {"(aucun)"}
        for _, s in ipairs(SM.MediaSounds or {}) do table.insert(t, s) end
        return t
    end
    local selectedSnd = "(aucun)"

    local sndDropBtn = CreateFrame("Button", nil, cR)
    sndDropBtn:SetSize(COL_R-16-52, 24)
    sndDropBtn:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    local sndDropBg = sndDropBtn:CreateTexture(nil,"BACKGROUND")
    sndDropBg:SetAllPoints(); sndDropBg:SetColorTexture(0.10, 0.08, 0.16, 1)
    local sndDropBdr = sndDropBtn:CreateTexture(nil,"BORDER")
    sndDropBdr:SetAllPoints(); sndDropBdr:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.25)
    local sndDropLbl = sndDropBtn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    sndDropLbl:SetPoint("LEFT",sndDropBtn,"LEFT",8,0); sndDropLbl:SetText(selectedSnd); sndDropLbl:SetTextColor(0.9,0.9,0.9,1)
    local sndDropArr = sndDropBtn:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    sndDropArr:SetPoint("RIGHT",sndDropBtn,"RIGHT",-6,0); sndDropArr:SetText("v")

    local sndTestBtn = SM.BBtn(cR, 46, 24, "Test", function()
        if selectedSnd ~= "(aucun)" then
            PlaySoundFile("Interface\\AddOns\\SolaryM\\Media\\Sounds\\"..selectedSnd..".ogg", "Master")
        end
    end)
    sndTestBtn:SetPoint("LEFT", sndDropBtn, "RIGHT", 4, 0)

    local sndMenu = CreateFrame("Frame", nil, cR)
    sndMenu:SetSize(COL_R-16-52, 22)
    sndMenu:SetPoint("TOPLEFT", sndDropBtn, "BOTTOMLEFT", 0, -2)
    sndMenu:SetFrameStrata("TOOLTIP")
    local sndMenuBg = sndMenu:CreateTexture(nil,"BACKGROUND")
    sndMenuBg:SetAllPoints(); sndMenuBg:SetColorTexture(0.08,0.06,0.14,0.98)
    sndMenu:Hide()

    sndDropBtn:SetScript("OnClick", function()
        if sndMenu:IsShown() then sndMenu:Hide(); return end
        for _, c in ipairs({sndMenu:GetChildren()}) do c:Hide() end
        local SOUNDS = GetSounds()
        sndMenu:SetHeight(#SOUNDS * 22)
        for i, sname in ipairs(SOUNDS) do
            local item = CreateFrame("Button", nil, sndMenu)
            item:SetSize(COL_R-16-52, 22)
            item:SetPoint("TOPLEFT", sndMenu, "TOPLEFT", 0, -(i-1)*22)
            local ibg = item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
            local ilbl = item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            ilbl:SetPoint("LEFT",item,"LEFT",8,0); ilbl:SetText(sname); ilbl:SetTextColor(0.85,0.85,0.9,1)
            item:SetScript("OnEnter",function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
            item:SetScript("OnLeave",function() ibg:SetColorTexture(0,0,0,0) end)
            local sn = sname
            item:SetScript("OnClick",function() selectedSnd=sn; sndDropLbl:SetText(sn); sndMenu:Hide() end)
        end
        sndMenu:Show()
    end)

    f._sndInput = {
        GetText = function() return selectedSnd ~= "(aucun)" and selectedSnd or "" end,
        SetText = function(_, v)
            selectedSnd = (v and v ~= "") and v or "(aucun)"
            sndDropLbl:SetText(selectedSnd)
        end,
    }
    y = y - 34

    local BW2 = math.floor((COL_R-16-6)/2)
    SM.OBtn(cR, BW2, 26, SM.T("btn_save"), function()
        local newId = tonumber(SM.GetVal(idInput))
        if not newId then SM.Print("Entre un spell ID.") return end
        local callout = SM.GetVal(calloutInput)
        if callout == "" then SM.Print("Entre un callout.") return end
        SolaryMDB.spellIdRemap = SolaryMDB.spellIdRemap or {}
        if selSpellId and selSpellId ~= newId then
            SolaryMDB.spells[selSpellId] = nil
            SolaryMDB.spellIdRemap[selSpellId] = newId
            SM.PendingSpellChanges[selSpellId] = "__removed__"
        elseif selSpellId then
            local oldRemapId = SolaryMDB.spellIdRemap[selSpellId]
            if oldRemapId then
                SolaryMDB.spells[oldRemapId] = nil
                SM.PendingSpellChanges[oldRemapId] = "__removed__"
            end
            SolaryMDB.spellIdRemap[selSpellId] = nil
            SM.PendingSpellChanges["__remap_clear_" .. selSpellId] = "__remap_clear__"
        end
        SolaryMDB.spells[newId] = callout
        SM.PendingSpellChanges[newId] = callout
        local ttsText = SM.GetVal(ttsInput)
        SolaryMDB.spells_tts = SolaryMDB.spells_tts or {}
        if ttsText ~= "" then
            SolaryMDB.spells_tts[newId] = ttsText
            SM.PendingSpellChanges["__tts_"..newId] = ttsText
        else
            SolaryMDB.spells_tts[newId] = nil
            SM.PendingSpellChanges["__tts_"..newId] = "__removed__"
        end
        local sndText = f._sndInput and f._sndInput:GetText() or ""
        SolaryMDB.spells_snd = SolaryMDB.spells_snd or {}
        if sndText ~= "" then SolaryMDB.spells_snd[newId] = sndText
        else SolaryMDB.spells_snd[newId] = nil end
        SM.SetVal(idInput,""); SM.SetVal(calloutInput,""); SM.SetVal(ttsInput,"")
        if f._sndInput then f._sndInput:SetText("") end
        nameDisplay:SetText("—"); noteDisplay:SetText("—")
        selSpellId = nil
        SM.RefreshSpellList(); SM._UpdatePendingCount()
        SM.Print("Spell |cFFFFD700"..newId.."|r % \""..callout.."\"")
    end):SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)

    SM.RBtn(cR, BW2, 26, SM.T("btn_reset"), function()
        if not selSpellId then SM.Print("Sélectionne un sort.") return end
        local entry = SM.GetSpellEntry(selSpellId)
        local defaultCallout = entry and ((SM.LANG=="fr" and entry.fr) or entry.en) or nil
        SolaryMDB.spells[selSpellId] = defaultCallout
        SolaryMDB.spellIdRemap = SolaryMDB.spellIdRemap or {}
        local remappedId = SolaryMDB.spellIdRemap[selSpellId]
        if remappedId then
            SolaryMDB.spells[remappedId] = nil
            SolaryMDB.spellIdRemap[selSpellId] = nil
            SM.PendingSpellChanges[remappedId] = "__removed__"
        end
        SM.PendingSpellChanges[selSpellId] = defaultCallout or "__removed__"
        SM._UpdatePendingCount()
        selSpellId = nil
        SM.SetVal(idInput,""); SM.SetVal(calloutInput,"")
        nameDisplay:SetText("—"); noteDisplay:SetText("—")
        SM.RefreshSpellList(); SM.Print("Sort réinitialisé.")
    end):SetPoint("TOPLEFT", cR, "TOPLEFT", 8+BW2+6, y)
    y = y - 34

    SM.BBtn(cR, COL_R-16, 26, SM.T("btn_test2"), function()
        local callout = SM.GetVal(calloutInput)
        if callout == "" then callout = (selSpellId and SolaryMDB.spells[selSpellId]) or "SOAK" end
        SM.TestAlert(callout, selSpellId, 8)
    end):SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    y = y - 34

    SM.RBtn(cR, COL_R-16, 26, "SUPPRIMER LE SORT", function()
        if not selSpellId then SM.Print("Sélectionne un sort d'abord."); return end
        local id = selSpellId

        SolaryMDB.customSpells = SolaryMDB.customSpells or {}
        local isCustom = false
        for i = #SolaryMDB.customSpells, 1, -1 do
            if SolaryMDB.customSpells[i].id == id then
                table.remove(SolaryMDB.customSpells, i); isCustom = true
            end
        end

        SolaryMDB.spells[id] = nil
        SolaryMDB.spells_tts = SolaryMDB.spells_tts or {}; SolaryMDB.spells_tts[id] = nil
        SolaryMDB.spells_snd = SolaryMDB.spells_snd or {}; SolaryMDB.spells_snd[id] = nil
        SM.PendingSpellChanges[id] = "__removed__"
        SM.PendingSpellChanges["__tts_"..id] = "__removed__"

        if isCustom then
            SM.RemoveCustomSpell(id)
            SM.Print("Sort |cFFFFD700"..id.."|r supprimé.")
        else
            SM.Print("Sort |cFFFFD700"..id.."|r : callout supprimé (sort de base conservé).")
        end

        selSpellId = nil
        SM.SetVal(idInput,""); SM.SetVal(calloutInput,""); SM.SetVal(ttsInput,"")
        if f._sndInput then f._sndInput:SetText("") end
        nameDisplay:SetText("—"); noteDisplay:SetText("—")
        SM._UpdatePendingCount(); SM.RefreshSpellList()
    end):SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    y = y - 34

    -- ── Section SYNCHRONISATION RAID ──────────────────────────
    local sepSync = cR:CreateTexture(nil,"ARTWORK")
    sepSync:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    sepSync:SetPoint("TOPRIGHT", cR, "TOPRIGHT", -8, y)
    sepSync:SetHeight(1); sepSync:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.35)
    y = y - 14

    SM.Lbl(cR, SM.T("raid_sync"), "GameFontNormal", 8, y, SM.OR)
    y = y - 20

    local syncDesc = cR:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    syncDesc:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    syncDesc:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    syncDesc:SetJustifyH("LEFT"); syncDesc:SetTextColor(0.45, 0.40, 0.58, 1)
    syncDesc:SetText(SM.T("raid_sync_desc"))
    y = y - 30

    SM.Lbl(cR, SM.T("img_label"), nil, 8, y)
    y = y - 18

    local imgDropdown = CreateFrame("Frame", "SolaryMImgDropdown", cR, "UIDropDownMenuTemplate")
    imgDropdown:SetPoint("TOPLEFT", cR, "TOPLEFT", -4, y+4)
    UIDropDownMenu_SetWidth(imgDropdown, COL_R - 90)
    UIDropDownMenu_SetText(imgDropdown, SM.T("no_image"))

    local mediaImages = {}
    local function ScanMediaImages()
        mediaImages = {}
        local known = SolaryMDB.mediaFiles or {}
        for _, fname in ipairs(known) do table.insert(mediaImages, fname) end
        local hasBreak = false
        for _, ff in ipairs(mediaImages) do if ff == "break" then hasBreak = true end end
        if not hasBreak then table.insert(mediaImages, 1, "break") end
    end
    ScanMediaImages()

    local selectedImg = nil
    UIDropDownMenu_Initialize(imgDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = SM.T("no_image_dash"); info.value = nil
        info.func = function() selectedImg=nil; UIDropDownMenu_SetText(imgDropdown, SM.T("no_image")) end
        info.checked = selectedImg == nil; UIDropDownMenu_AddButton(info)
        for _, fname in ipairs(mediaImages) do
            info = UIDropDownMenu_CreateInfo()
            info.text = fname; info.value = fname
            local fn = fname
            info.func = function() selectedImg=fn; UIDropDownMenu_SetText(imgDropdown, fn) end
            info.checked = selectedImg == fname; UIDropDownMenu_AddButton(info)
        end
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cFFAAAAAA "..SM.T("refresh_list").."|r"; info.value = "__refresh"
        info.func = function() ScanMediaImages(); UIDropDownMenu_Refresh(imgDropdown) end
        UIDropDownMenu_AddButton(info)
    end)
    y = y - 32

    local mediaInfo = cR:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    mediaInfo:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    mediaInfo:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    mediaInfo:SetJustifyH("LEFT"); mediaInfo:SetTextColor(0.38,0.34,0.50,1)
    mediaInfo:SetText(SM.T("media_info"))
    y = y - 22

    local pendingLbl = cR:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    pendingLbl:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    pendingLbl:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    pendingLbl:SetJustifyH("LEFT")
    pendingLbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    pendingLbl:SetText(SM.T("pending_none"))
    f._pendingLbl = pendingLbl
    y = y - 22

    local broadcastBtn = SM.Btn(cR, COL_R-16, 30, SM.T("btn_broadcast"),
        SM.PRP[1], SM.PRP[2], SM.PRP[3], function()
        SM.BroadcastSpells(selectedImg)
    end)
    broadcastBtn:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    y = y - 38

    local broadcastStatus = cR:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    broadcastStatus:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    broadcastStatus:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    broadcastStatus:SetJustifyH("LEFT"); broadcastStatus:SetTextColor(0.38,0.34,0.50,1)
    broadcastStatus:SetText(SM.T("last_broadcast"))
    f._broadcastStatus = broadcastStatus
    y = y - 22

    local info = cR:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    info:SetPoint("TOPLEFT", cR, "TOPLEFT", 8, y)
    info:SetPoint("RIGHT", cR, "RIGHT", -8, 0)
    info:SetJustifyH("LEFT"); info:SetTextColor(0.38,0.34,0.50,1)
    info:SetText(SM.T("spell_info"))

    return f
end

-- ============================================================
-- REFRESH SPELLS — liste groupée par zone puis boss
-- ============================================================
function SM.RefreshSpellList()
    local f = tabFrames[1]
    if not f or not f._spellScroll then return end
    local scroll = f._spellScroll
    for _, b in ipairs(spellBtns) do b:Hide() end
    spellBtns = {}

    local filter     = f._searchInput and SM.GetVal(f._searchInput):lower() or ""
    local zoneFilter = f._zoneFilter and f._zoneFilter()
    local W          = scroll.content:GetWidth()
    local yOff       = 0
    local spellCount = 0
    local typeCol    = { raid={1,0.6,0}, dungeon={0.4,0.8,1}, custom={0.80,0.55,1.0} }

    local function spellMatchesFilter(spell)
        if filter == "" then return true end
        local callout = SolaryMDB.spells[spell.id] or (SM.LANG=="fr" and spell.fr) or spell.en or ""
        local sname = spell.en or spell.fr or ""
        local boss  = spell.boss or ""
        return sname:lower():find(filter,1,true)
            or callout:lower():find(filter,1,true)
            or boss:lower():find(filter,1,true)
    end

    local function bossHasMatch(boss)
        for _, spell in ipairs(boss.spells) do
            if spellMatchesFilter(spell) then return true end
        end
        return false
    end

    local function zoneHasMatch(zone)
        for _, boss in ipairs(zone.bosses) do
            if bossHasMatch(boss) then return true end
        end
        return false
    end

    for _, zone in ipairs(SM.SpellDB) do
        if (not zoneFilter or zone.zone == zoneFilter) and zoneHasMatch(zone) then
            local tc = typeCol[zone.type] or {0.7,0.7,0.7}

            -- En-tête zone
            local zRow = CreateFrame("Frame", nil, scroll.content)
            zRow:SetSize(W, 28); zRow:SetPoint("TOPLEFT", 0, -yOff)
            local zBg = zRow:CreateTexture(nil,"BACKGROUND"); zBg:SetAllPoints()
            zBg:SetColorTexture(tc[1]*0.18, tc[2]*0.14, tc[3]*0.22, 1)
            local zLbl = zRow:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
            zLbl:SetPoint("LEFT",8,0); zLbl:SetPoint("RIGHT",zRow,"RIGHT",-60,0)
            zLbl:SetJustifyH("LEFT"); zLbl:SetTextColor(tc[1],tc[2],tc[3],1); zLbl:SetText(zone.zone)
            local zTag = zRow:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            zTag:SetPoint("RIGHT",zRow,"RIGHT",-6,0)
            zTag:SetTextColor(tc[1]*0.8,tc[2]*0.8,tc[3]*0.8,1)
            zTag:SetText(zone.type == "raid" and "RAID" or SM.T("type_dungeon"))
            table.insert(spellBtns, zRow); yOff = yOff + 30

            for _, boss in ipairs(zone.bosses) do
                if bossHasMatch(boss) then
                    -- En-tête boss
                    local bRow = CreateFrame("Frame", nil, scroll.content)
                    bRow:SetSize(W, 26); bRow:SetPoint("TOPLEFT", 0, -yOff)
                    SM.BG(bRow, 0.10, 0.08, 0.18, 1)
                    local bLbl = bRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
                    bLbl:SetPoint("LEFT",16,0); bLbl:SetPoint("RIGHT",bRow,"RIGHT",-4,0)
                    bLbl:SetJustifyH("LEFT"); bLbl:SetTextColor(0.85, 0.72, 0.98, 1)
                    bLbl:SetText(boss.boss)
                    table.insert(spellBtns, bRow); yOff = yOff + 28

                    for _, spell in ipairs(boss.spells) do
                        if spellMatchesFilter(spell) then
                            spellCount = spellCount + 1
                            local defCallout = (SM.LANG=="fr" and spell.fr) or spell.en or ""
                            local remapId2   = SolaryMDB.spellIdRemap and SolaryMDB.spellIdRemap[spell.id]
                            local activeId2  = remapId2 or spell.id
                            local callout    = SolaryMDB.spells[activeId2] or defCallout
                            local isCustom   = (SolaryMDB.spells[activeId2] and SolaryMDB.spells[activeId2] ~= defCallout) or (remapId2 ~= nil)
                            local isSel      = (selSpellId == spell.id)

                            local btn = CreateFrame("Button", nil, scroll.content)
                            btn:SetSize(W, 30); btn:SetPoint("TOPLEFT", 0, -yOff)
                            local bg = btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints()
                            bg:SetColorTexture(
                                isSel and 0.18 or 0.08,
                                isSel and 0.08 or 0.06,
                                isSel and 0.28 or 0.12, 1)
                            btn._bg = bg

                            -- Icône du sort
                            local spellTex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell.id)
                                or (GetSpellTexture and GetSpellTexture(spell.id))
                            local fIco = btn:CreateTexture(nil,"ARTWORK")
                            fIco:SetSize(22, 22); fIco:SetPoint("LEFT", btn, "LEFT", 4, 0)
                            fIco:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                            if spellTex then fIco:SetTexture(spellTex) else fIco:Hide() end

                            local fCall = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
                            fCall:SetPoint("LEFT",32,0); fCall:SetWidth(120); fCall:SetJustifyH("LEFT")
                            fCall:SetTextColor(
                                isCustom and SM.OR[1] or 0.92,
                                isCustom and SM.OR[2] or 0.90,
                                isCustom and SM.OR[3] or 0.98, 1)
                            fCall:SetText(callout)
                            local fName = btn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                            fName:SetPoint("LEFT",btn,"LEFT",152,0); fName:SetPoint("RIGHT",btn,"RIGHT",-56,0)
                            fName:SetJustifyH("LEFT"); fName:SetTextColor(0.58,0.54,0.68,1)
                            fName:SetText((spell.boss or "")..(spell.en and (" — "..spell.en) or ""))
                            local fId = btn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                            fId:SetPoint("RIGHT",btn,"RIGHT",-6,0); fId:SetTextColor(0.38,0.34,0.50,1)
                            local displayId = (SolaryMDB.spellIdRemap and SolaryMDB.spellIdRemap[spell.id]) or spell.id
                            fId:SetText(tostring(displayId))

                            local sid      = spell.id
                            local sname_en = spell.en or ""
                            local sname_fr = spell.fr or ""
                            local scallout = callout
                            local _idx     = SM.SpellIndex and SM.SpellIndex[spell.id]
                            local sboss    = (_idx and _idx.boss) or ""
                            local szone    = (_idx and _idx.zone) or ""

                            btn:SetScript("OnClick", function()
                                selSpellId = sid
                                local remapId  = SolaryMDB.spellIdRemap and SolaryMDB.spellIdRemap[sid]
                                local activeId = remapId or sid
                                if f._idInput      then SM.SetVal(f._idInput, tostring(activeId)) end
                                if f._calloutInput then SM.SetVal(f._calloutInput, SolaryMDB.spells[activeId] or scallout) end
                                if f._ttsInput then
                                    local ttsData = SolaryMDB.spells_tts and SolaryMDB.spells_tts[activeId]
                                    SM.SetVal(f._ttsInput, type(ttsData)=="string" and ttsData or "")
                                end
                                if f._sndInput then
                                    f._sndInput:SetText(SolaryMDB.spells_snd and SolaryMDB.spells_snd[activeId] or "")
                                end
                                if f._nameDisplay then
                                    f._nameDisplay:SetText((SM.LANG=="fr" and sname_fr~="" and sname_fr) or sname_en)
                                end
                                if f._noteDisplay then
                                    f._noteDisplay:SetText(sboss~="" and ("["..sboss.."] "..szone) or "—")
                                end
                                SM.RefreshSpellList()
                            end)
                            btn:SetScript("OnEnter", function(s)
                                if selSpellId ~= sid then s._bg:SetColorTexture(0.12, 0.08, 0.20, 1) end
                                GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
                                GameTooltip:SetText(sname_en~="" and sname_en or tostring(sid), SM.OR[1],SM.OR[2],SM.OR[3])
                                if sname_fr~="" and sname_fr~=sname_en then
                                    GameTooltip:AddLine(sname_fr, 0.8, 0.8, 0.8, true)
                                end
                                GameTooltip:AddLine("Boss: "..sboss, 0.6, 0.6, 0.6, true)
                                GameTooltip:AddLine("Zone: "..szone, 0.5, 0.5, 0.5, true)
                                GameTooltip:AddLine("ID: "..sid, 0.4, 0.4, 0.4, true)
                                GameTooltip:Show()
                            end)
                            btn:SetScript("OnLeave", function(s)
                                if selSpellId ~= sid then s._bg:SetColorTexture(0.08, 0.06, 0.12, 1) end
                                GameTooltip:Hide()
                            end)
                            table.insert(spellBtns, btn); yOff = yOff + 28
                        end
                    end
                end
            end
            yOff = yOff + 4
        end
    end
    scroll.content:SetHeight(math.max(yOff, 1))
    if f._countLbl then
        f._countLbl:SetText(spellCount.." "..(SM.T("spells_found") or "sorts trouvés"))
    end
end

-- ============================================================
-- ONGLET 2 : GROUPES
-- ============================================================
local function BuildGroupsTab(parent)
    local f = CreateFrame("Frame",nil,parent)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",SIDEBAR_W,CONTENT_Y)
    f:SetSize(PANEL_W,CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.07, 0.10, 1)  -- fond opaque

    local HALF = math.floor((PANEL_W-24)/2)

    -- ── Ligne de boutons ─────────────────────────────────────
    local btnOE = SM.OBtn(f, math.floor(HALF*0.9), 28, SM.T("split_odd_even"), function()
        SM.Groups.SplitOddEven()
        SM.RefreshGroupsTab("default", f)
        local oeA, oeB = SM.Groups.GetSplitLabels()
        SM.Print(string.format("Split |cFFFFD700%s|r vs |cFFFFD700%s|r", oeA, oeB))
    end)
    btnOE:SetPoint("TOPLEFT",f,"TOPLEFT",8,-10)

    local btnH = SM.OBtn(f, math.floor(HALF*0.9), 28, SM.T("split_halves"), function()
        SM.Groups.SplitHalves()
        SM.RefreshGroupsTab("default", f)
        local _, _, hA, hB = SM.Groups.GetSplitLabels()
        SM.Print(string.format("Split |cFFFFD700%s|r vs |cFFFFD700%s|r", hA, hB))
    end)
    btnH:SetPoint("TOPLEFT",f,"TOPLEFT", 8 + math.floor(HALF*0.9) + 12, -10)

    -- Labels dynamiques sous les boutons (affichent ex: "Grp 1/3/5" / "Grp 2/4/6")
    local lblSplit = f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    lblSplit:SetPoint("TOPLEFT",f,"TOPLEFT",8,-44)
    lblSplit:SetTextColor(0.6,0.6,0.6,1)
    lblSplit:SetText("Raid 10/25 → Impairs (1/3/5) vs Pairs (2/4/6)   |   Mythic 20 → 1/3 vs 2/4")
    f._lblSplit = lblSplit

    -- ── Colonnes A / B ────────────────────────────────────────
    local colA = CreateFrame("Frame",nil,f)
    colA:SetSize(HALF, CONTENT_H-62); colA:SetPoint("TOPLEFT",f,"TOPLEFT",8,-58)
    SM.BG(colA,SM.DK[1],SM.DK[2],SM.DK[3],0.7)
    SM.Lbl(colA,SM.T("group_a"),"GameFontNormal",8,-8,SM.OR)
    local sA = SM.Scroll(colA,HALF-4,CONTENT_H-90)
    sA:SetPoint("TOPLEFT",colA,"TOPLEFT",2,-28)

    local colB = CreateFrame("Frame",nil,f)
    colB:SetSize(HALF, CONTENT_H-62); colB:SetPoint("TOPLEFT",f,"TOPLEFT",8+HALF+8,-58)
    SM.BG(colB,SM.DK[1],SM.DK[2],SM.DK[3],0.7)
    SM.Lbl(colB,SM.T("group_b"),"GameFontNormal",8,-8,SM.OR)
    local sB = SM.Scroll(colB,HALF-4,CONTENT_H-90)
    sB:SetPoint("TOPLEFT",colB,"TOPLEFT",2,-28)

    f._scrollA=sA; f._scrollB=sB
    return f
end

function SM.RefreshGroupsTab(bossName, f)
    f = f or tabFrames[3]
    if not f or not f._scrollA then return end
    local key = "default"
    local groups = SolaryMDB.groups[key] or {A={},B={}}
    local rc = {TANK={0.2,0.6,1},HEALER={0.1,0.9,0.3},DAMAGER={1,0.8,0.1},NONE={0.7,0.7,0.7}}
    local function Fill(scroll, list)
        for _, c in ipairs({scroll.content:GetChildren()}) do c:Hide() end
        local sorted = SM.Groups.SortByRole()
        local roleMap = {}
        for _, g in ipairs({sorted.tanks, sorted.healers, sorted.dps}) do
            for _, m in ipairs(g) do roleMap[m.name] = m.role end
        end
        local yOff = 0
        for _, name in ipairs(list) do
            local row = CreateFrame("Frame",nil,scroll.content)
            row:SetSize(scroll.content:GetWidth(),24); row:SetPoint("TOPLEFT",0,-yOff)
            SM.BG(row,0.1,0.1,0.13,1)
            local role = roleMap[name] or "NONE"
            local c = rc[role] or rc.NONE
            local ri = role=="TANK" and "T" or role=="HEALER" and "H" or "D"
            local fr = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            fr:SetPoint("LEFT",4,0); fr:SetWidth(14)
            fr:SetTextColor(c[1],c[2],c[3],1); fr:SetText(ri)
            local fn = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            fn:SetPoint("LEFT",22,0); fn:SetPoint("RIGHT",row,"RIGHT",-4,0)
            fn:SetJustifyH("LEFT"); fn:SetTextColor(0.9,0.9,0.9,1); fn:SetText(name)
            yOff = yOff + 26
        end
        scroll.content:SetHeight(math.max(yOff,1))
    end
    Fill(f._scrollA, groups.A or {})
    Fill(f._scrollB, groups.B or {})

    if f._lblSplit then
        if IsInRaid() then
            local oeA, oeB, hA, hB = SM.Groups.GetSplitLabels()
            f._lblSplit:SetText(string.format("Impairs/Pairs : |cFFFFD700%s|r vs |cFFFFD700%s|r   |   Moitiés : |cFFFFD700%s|r vs |cFFFFD700%s|r", oeA, oeB, hA, hB))
        else
            f._lblSplit:SetText("Hors raid : split équilibré par rôle (T/H/DPS alternés)")
        end
    end
end

-- ============================================================
-- HELPERS UI (toggle pill, spell icon) — utilisés par plusieurs onglets
-- ============================================================
local function MakeToggle(parent, isOn, onChange)
    local TW, TH = 40, 22
    local tog = CreateFrame("Button", nil, parent)
    tog:SetSize(TW, TH)
    local trackBg = tog:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    local thumb = tog:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(TH - 4, TH - 4)
    local state = isOn
    local function Refresh()
        thumb:ClearAllPoints()
        if state then
            trackBg:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
            thumb:SetColorTexture(0.96, 0.92, 1.0, 1)
            thumb:SetPoint("RIGHT", tog, "RIGHT", -2, 0)
        else
            trackBg:SetColorTexture(0.16, 0.14, 0.22, 1)
            thumb:SetColorTexture(0.45, 0.42, 0.55, 1)
            thumb:SetPoint("LEFT", tog, "LEFT", 2, 0)
        end
    end
    tog:SetScript("OnClick", function()
        state = not state; Refresh(); onChange(state)
    end)
    tog._setState = function(v) state = v; Refresh() end
    Refresh()
    return tog
end

local function GetSpellTex(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
    return nil
end

-- ============================================================
-- ONGLET 3 : INVITES
-- ============================================================
local function BuildInviteTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    local HDR_H      = 44
    local PAD        = 8
    local CW         = PANEL_W - PAD * 2
    local AUTO_H     = HDR_H + 62
    local INVITE_H   = 40
    local RANK_H     = CONTENT_H + 8 - AUTO_H - PAD * 3

    -- ── SECTION : Auto-invite ────────────────────────────────
    local autoCard = CreateFrame("Frame", nil, f)
    autoCard:SetSize(CW, AUTO_H)
    autoCard:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)

    local aHdr = CreateFrame("Frame", nil, autoCard)
    aHdr:SetPoint("TOPLEFT"); aHdr:SetPoint("TOPRIGHT"); aHdr:SetHeight(HDR_H)
    local _ahb = aHdr:CreateTexture(nil,"BACKGROUND"); _ahb:SetAllPoints()
    _ahb:SetColorTexture(0.05, 0.04, 0.09, 1)
    local _ahs = aHdr:CreateTexture(nil,"ARTWORK")
    _ahs:SetPoint("BOTTOMLEFT"); _ahs:SetPoint("BOTTOMRIGHT"); _ahs:SetHeight(1)
    _ahs:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)
    local aTitle = aHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    aTitle:SetPoint("LEFT", aHdr, "LEFT", 12, 0); aTitle:SetTextColor(0.85, 0.80, 1.0, 1)
    aTitle:SetText(SM.T("autoinvite") or "AUTO-INVITE")
    local aSub = aHdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    aSub:SetPoint("BOTTOMLEFT", aHdr, "BOTTOMLEFT", 12, 6); aSub:SetTextColor(0.45, 0.40, 0.60, 1)
    aSub:SetText(SM.T("autoinvite_desc") or "")

    local aBod = autoCard:CreateTexture(nil,"BACKGROUND")
    aBod:SetAllPoints(); aBod:SetColorTexture(0.09, 0.07, 0.14, 1)

    local togRow = CreateFrame("Frame", nil, autoCard)
    togRow:SetSize(CW - 8, 44)
    togRow:SetPoint("TOPLEFT", autoCard, "TOPLEFT", 4, -HDR_H - 9)
    SM.BG(togRow, 0.10, 0.08, 0.16, 1)
    local acc = togRow:CreateTexture(nil,"ARTWORK")
    acc:SetSize(3, 44); acc:SetPoint("LEFT")
    acc:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)

    local togLbl = togRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    togLbl:SetPoint("TOPLEFT", togRow, "TOPLEFT", 14, -8); togLbl:SetTextColor(0.92, 0.88, 1.0, 1)
    togLbl:SetText(SM.T("autoinvite") or "Auto-invite")

    local kws = SolaryMDB.invite and SolaryMDB.invite.keywords or {"inv", "+1"}
    local kwLbl = togRow:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    kwLbl:SetPoint("BOTTOMLEFT", togRow, "BOTTOMLEFT", 14, 8)
    kwLbl:SetTextColor(SM.OR[1]*0.75, SM.OR[2]*0.65, SM.OR[3]*0.88, 1)
    kwLbl:SetText((SM.T("keywords") or "Mots-clés").."  "..table.concat(kws, "  ·  "))

    local isEnabled = SM.Invite and SM.Invite.IsAutoInviteEnabled and SM.Invite.IsAutoInviteEnabled() or false
    local invTog = MakeToggle(togRow, isEnabled, function(v)
        if SM.Invite and SM.Invite.SetAutoInvite then SM.Invite.SetAutoInvite(v) end
    end)
    invTog:SetPoint("RIGHT", togRow, "RIGHT", -10, 0)
    f._invTog = invTog

    -- ── SECTION : Rangs de guilde ────────────────────────────
    local rankCard = CreateFrame("Frame", nil, f)
    rankCard:SetSize(CW, RANK_H)
    rankCard:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD - AUTO_H - PAD)

    local rHdr = CreateFrame("Frame", nil, rankCard)
    rHdr:SetPoint("TOPLEFT"); rHdr:SetPoint("TOPRIGHT"); rHdr:SetHeight(HDR_H)
    local _rhb = rHdr:CreateTexture(nil,"BACKGROUND"); _rhb:SetAllPoints()
    _rhb:SetColorTexture(0.05, 0.04, 0.09, 1)
    local _rhs = rHdr:CreateTexture(nil,"ARTWORK")
    _rhs:SetPoint("BOTTOMLEFT"); _rhs:SetPoint("BOTTOMRIGHT"); _rhs:SetHeight(1)
    _rhs:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)
    local rTitle = rHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    rTitle:SetPoint("LEFT", rHdr, "LEFT", 12, 0); rTitle:SetTextColor(0.85, 0.80, 1.0, 1)
    rTitle:SetText(SM.T("guild_rank") or "RANGS DE GUILDE")
    local rSub = rHdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    rSub:SetPoint("BOTTOMLEFT", rHdr, "BOTTOMLEFT", 12, 6); rSub:SetTextColor(0.45, 0.40, 0.60, 1)
    rSub:SetText(SM.T("guild_rank_desc") or "")

    local loadBtn = SM.OBtn(rHdr, 130, 28, SM.T("btn_load_ranks") or "Charger les rangs", function()
        SM.RefreshRankList(f)
    end)
    loadBtn:SetPoint("RIGHT", rHdr, "RIGHT", -10, 0)

    local rBod = rankCard:CreateTexture(nil,"BACKGROUND")
    rBod:SetAllPoints(); rBod:SetColorTexture(0.09, 0.07, 0.14, 1)

    local rScroll = SM.Scroll(rankCard, CW - 4, RANK_H - HDR_H - INVITE_H - 6)
    rScroll:SetPoint("TOPLEFT", rankCard, "TOPLEFT", 2, -HDR_H)
    f._rankFrame  = rScroll.content
    f._rankScroll = rScroll

    local inviteBtn = SM.GBtn(rankCard, CW - 8, INVITE_H - 4, SM.T("btn_invite_sel") or "INVITER LA SÉLECTION", function()
        if SM.Invite then SM.Invite.InviteByRanks(f._selectedRanks or {}) end
    end)
    inviteBtn:SetPoint("BOTTOMLEFT", rankCard, "BOTTOMLEFT", 4, 4)

    f._selectedRanks = {}
    return f
end

function SM.RefreshRankList(f)
    f = f or tabFrames[3]
    if not f or not f._rankFrame then return end
    local rf = f._rankFrame
    f._selectedRanks = {}
    for _, c in ipairs({rf:GetChildren()}) do c:Hide() end

    local ranks = SM.Invite and SM.Invite.GetGuildRanks and SM.Invite.GetGuildRanks() or {}
    if #ranks == 0 then
        local lbl = rf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", 16, -20); lbl:SetTextColor(0.45, 0.40, 0.60, 1)
        lbl:SetText(SM.T("not_in_guild") or "Pas en guilde")
        rf:SetHeight(60)
        return
    end

    local COLS = 4
    local BW   = math.floor((rf:GetWidth() - 8 - (COLS - 1) * 6) / COLS)
    local BH   = 34
    local GAP  = 6

    for i, rank in ipairs(ranks) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local btn = CreateFrame("Button", nil, rf)
        btn:SetSize(BW, BH)
        btn:SetPoint("TOPLEFT", rf, "TOPLEFT", col * (BW + GAP), -row * (BH + GAP))

        local bg = btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints()
        bg:SetColorTexture(0.10, 0.08, 0.16, 1); btn._bg = bg
        local bdr = btn:CreateTexture(nil,"BORDER"); bdr:SetAllPoints()
        bdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18); btn._bdr = bdr

        local fs = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
        fs:SetAllPoints(); fs:SetJustifyH("CENTER")
        fs:SetTextColor(0.78, 0.72, 0.92, 1); fs:SetText(rank.name); btn._fs = fs

        btn:SetScript("OnEnter", function(s)
            if not s._sel then s._bg:SetColorTexture(0.14, 0.10, 0.22, 1) end
        end)
        btn:SetScript("OnLeave", function(s)
            if not s._sel then s._bg:SetColorTexture(0.10, 0.08, 0.16, 1) end
        end)

        local sel = false
        btn:SetScript("OnClick", function(s)
            sel = not sel; s._sel = sel
            if sel then
                s._bg:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
                s._bdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.6)
                s._fs:SetTextColor(0.05, 0.05, 0.08, 1)
                table.insert(f._selectedRanks, rank.index)
            else
                s._bg:SetColorTexture(0.10, 0.08, 0.16, 1)
                s._bdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)
                s._fs:SetTextColor(0.78, 0.72, 0.92, 1)
                for j, ri in ipairs(f._selectedRanks) do
                    if ri == rank.index then table.remove(f._selectedRanks, j); break end
                end
            end
        end)
    end

    local rows = math.ceil(#ranks / COLS)
    rf:SetHeight(math.max(rows * (BH + GAP), 60))
end

-- ============================================================
-- ONGLET 4 : PARAMÈTRES
-- ============================================================
local function MakeSlider(parent, label, minV, maxV, step, getValue, setValue, x, y, w)
    w = w or 200
    local H = 6   -- hauteur de la barre
    local THUMB = 12  -- taille du curseur

    -- Label + valeur sur la même ligne
    local lbl = parent:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetTextColor(0.65, 0.65, 0.7, 1)

    local valLbl = parent:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    valLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x + w + 8, y)
    valLbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    valLbl:SetJustifyH("LEFT")

    -- Barre de fond (track)
    local track = parent:CreateTexture(nil, "ARTWORK")
    track:SetSize(w, H)
    track:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    track:SetColorTexture(0.15, 0.15, 0.20, 1)

    -- Barre de remplissage (fill)
    local fill = parent:CreateTexture(nil, "ARTWORK")
    fill:SetSize(1, H)
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    fill:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)

    -- Curseur (thumb)
    local thumb = parent:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(2, 14)
    thumb:SetPoint("CENTER", track, "LEFT", 0, 0)
    thumb:SetColorTexture(1, 1, 1, 1)

    -- Frame invisible pour capturer les clics/drag
    local hitbox = CreateFrame("Button", nil, parent)
    hitbox:SetSize(w, 18)
    hitbox:SetPoint("CENTER", track, "CENTER", 0, 0)
    hitbox:EnableMouse(true)

    local dragging = false
    local curVal = getValue()

    local function SetSliderValue(newVal)
        newVal = math.max(minV, math.min(maxV, newVal))
        newVal = math.floor(newVal / step + 0.5) * step
        curVal = newVal
        local pct = (newVal - minV) / (maxV - minV)
        fill:SetWidth(math.max(1, w * pct))
        thumb:SetPoint("CENTER", track, "LEFT", w * pct, 0)
        lbl:SetText(label .. " : " .. math.floor(newVal))
        valLbl:SetText(tostring(math.floor(newVal)))
        setValue(newVal)
    end

    local function GetMousePct()
        local mx = GetCursorPosition() / UIParent:GetEffectiveScale()
        local tx, _ = track:GetLeft(), track:GetBottom()
        local pct = math.max(0, math.min(1, (mx - tx) / w))
        return pct
    end

    hitbox:SetScript("OnMouseDown", function(s, btn)
        if btn == "LeftButton" then
            dragging = true
            SetSliderValue(minV + GetMousePct() * (maxV - minV))
        end
    end)
    hitbox:SetScript("OnMouseUp", function() dragging = false end)
    hitbox:SetScript("OnUpdate", function()
        if dragging then
            SetSliderValue(minV + GetMousePct() * (maxV - minV))
        end
    end)

    -- Scroll wheel
    hitbox:EnableMouseWheel(true)
    hitbox:SetScript("OnMouseWheel", function(_, delta)
        SetSliderValue(curVal + delta * step)
    end)

    SetSliderValue(curVal)
    return hitbox, y - 32
end

local function BuildSettingsTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    local HDR_H    = 44
    local PAD      = 12   -- marges extérieures et entre cartes
    local BODY_PAD = 14   -- padding haut/bas dans le corps de chaque carte
    local ITEM_GAP = 12   -- espace entre les lignes
    local COL_W    = math.floor((PANEL_W - PAD * 3) / 2)
    local ROW_W    = COL_W - 8
    local SLIDE_W  = COL_W - 32

    -- Hauteur totale disponible dans f
    local AVAIL = CONTENT_H + 8 - PAD * 2   -- 708px

    local hasBreak = SM.IsEditor() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")

    -- Hauteurs colonne gauche : les deux cartes se partagent AVAIL
    local ALERTS_H = math.floor((AVAIL - PAD) * 0.43)
    local PA_H     = AVAIL - ALERTS_H - PAD

    -- Hauteurs colonne droite : 2 ou 3 cartes se partagent AVAIL
    local FRAMES_H, STATUS_H, BREAK_H
    if hasBreak then
        FRAMES_H = math.floor((AVAIL - PAD * 2) / 3)
        STATUS_H = FRAMES_H
        BREAK_H  = AVAIL - FRAMES_H - STATUS_H - PAD * 2
    else
        FRAMES_H = math.floor((AVAIL - PAD) / 2)
        STATUS_H = AVAIL - FRAMES_H - PAD
    end

    -- Tailles de lignes dynamiques dans chaque carte
    -- Gauche-Alertes : 4 lignes (toggle, prealert, slider1, slider2)
    local aBody = ALERTS_H - HDR_H - BODY_PAD * 2
    local aItem = math.floor((aBody - ITEM_GAP * 3) / 4)
    -- Gauche-PA : 4 lignes (toggle_paw, scale, toggle_defaults, edit)
    local pBody = PA_H - HDR_H - BODY_PAD * 2
    local pItem = math.floor((pBody - ITEM_GAP * 3) / 4)

    -- ── Helpers ──────────────────────────────────────────────
    local function MkCard(x, yTop, w, h, titleKey, subKey)
        local card = CreateFrame("Frame", nil, f)
        card:SetSize(w, h); card:SetPoint("TOPLEFT", f, "TOPLEFT", x, -yTop)
        SM.BG(card, 0.09, 0.07, 0.14, 1)
        local hdr = CreateFrame("Frame", nil, card)
        hdr:SetPoint("TOPLEFT"); hdr:SetPoint("TOPRIGHT"); hdr:SetHeight(HDR_H)
        local _hb = hdr:CreateTexture(nil,"BACKGROUND"); _hb:SetAllPoints()
        _hb:SetColorTexture(0.05, 0.04, 0.09, 1)
        local _hs = hdr:CreateTexture(nil,"ARTWORK")
        _hs:SetPoint("BOTTOMLEFT"); _hs:SetPoint("BOTTOMRIGHT"); _hs:SetHeight(1)
        _hs:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)
        local t = hdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        t:SetPoint("LEFT", hdr, "LEFT", 12, 0); t:SetTextColor(0.85, 0.80, 1.0, 1)
        t:SetText(SM.T(titleKey) or titleKey)
        if subKey then
            local s = hdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            s:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 12, 6); s:SetTextColor(0.45, 0.40, 0.60, 1)
            s:SetText(SM.T(subKey) or subKey)
        end
        return card
    end

    local function MkTogRow(card, yOff, h, labelKey, state, onChange)
        local row = CreateFrame("Frame", nil, card)
        row:SetSize(ROW_W, h); row:SetPoint("TOPLEFT", card, "TOPLEFT", 4, yOff)
        SM.BG(row, 0.10, 0.08, 0.16, 1)
        local acc = row:CreateTexture(nil,"ARTWORK")
        acc:SetSize(3, h); acc:SetPoint("LEFT")
        acc:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        local lbl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
        lbl:SetPoint("LEFT", row, "LEFT", 14, 0); lbl:SetPoint("RIGHT", row, "RIGHT", -56, 0)
        lbl:SetJustifyH("LEFT"); lbl:SetTextColor(0.92, 0.88, 1.0, 1)
        lbl:SetText(SM.T(labelKey) or labelKey)
        local tog = MakeToggle(row, state, onChange)
        tog:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        return tog
    end

    local function MkBodyRow(card, yOff, h)
        local row = CreateFrame("Frame", nil, card)
        row:SetSize(ROW_W, h); row:SetPoint("TOPLEFT", card, "TOPLEFT", 4, yOff)
        SM.BG(row, 0.10, 0.08, 0.16, 1)
        local acc = row:CreateTexture(nil,"ARTWORK")
        acc:SetSize(3, h); acc:SetPoint("LEFT")
        acc:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.6)
        return row
    end

    -- ── COLONNE GAUCHE ─────────────────────────────────────────
    local lx = PAD

    -- CARD : Alertes + apparence
    local cardAlerts = MkCard(lx, PAD, COL_W, ALERTS_H, "alert_appearance", "alerts_desc")
    local by = -(HDR_H + BODY_PAD)

    MkTogRow(cardAlerts, by, aItem, "alerts_enabled", SolaryMDB.alerts_enabled ~= false, function(v)
        SolaryMDB.alerts_enabled = v
    end)
    by = by - aItem - ITEM_GAP

    local paRow = MkBodyRow(cardAlerts, by, aItem)
    local paLbl = paRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    paLbl:SetPoint("LEFT", paRow, "LEFT", 14, 0); paLbl:SetTextColor(0.78, 0.72, 0.92, 1)
    paLbl:SetText(SM.T("prealert_label"))
    local prein = SM.Input(paRow, 64, 28, "5")
    prein:SetPoint("RIGHT", paRow, "RIGHT", -14, 0)
    SM.SetVal(prein, tostring((SolaryMDB.boss_timers and SolaryMDB.boss_timers.prealert_sec) or 5))
    prein:SetScript("OnTextChanged", function(s)
        local v = tonumber(SM.GetVal(s))
        if v and v >= 1 and v <= 30 then
            SolaryMDB.boss_timers = SolaryMDB.boss_timers or {}
            SolaryMDB.boss_timers.prealert_sec = v
        end
    end)
    by = by - aItem - ITEM_GAP

    -- Sliders centrés verticalement dans leur slot
    local slCenter = -math.floor((aItem - 32) / 2)
    MakeSlider(cardAlerts, SM.T("alert_width"), 150, 700, 1,
        function() return (SolaryMDB.alert and SolaryMDB.alert.width) or 380 end,
        function(v)
            SolaryMDB.alert = SolaryMDB.alert or {}; SolaryMDB.alert.width = math.floor(v)
            if SM.SetAlertWidth then SM.SetAlertWidth(math.floor(v)) end
        end, 16, by + slCenter, SLIDE_W)
    by = by - aItem - ITEM_GAP

    MakeSlider(cardAlerts, SM.T("alert_fontsize"), 10, 48, 1,
        function() return (SolaryMDB.alert and SolaryMDB.alert.fontSize) or 22 end,
        function(v)
            SolaryMDB.alert = SolaryMDB.alert or {}; SolaryMDB.alert.fontSize = math.floor(v)
        end, 16, by + slCenter, SLIDE_W)

    -- CARD : Private Auras
    local cardPA = MkCard(lx, PAD + ALERTS_H + PAD, COL_W, PA_H, "pa_sounds", nil)
    local py = -(HDR_H + BODY_PAD)

    MkTogRow(cardPA, py, pItem, "paw_label", SolaryMDB.paw_enabled ~= false, function(v)
        SolaryMDB.paw_enabled = v; SM.SetupPrivateWarningText()
    end)
    py = py - pItem - ITEM_GAP

    local scRow = MkBodyRow(cardPA, py, pItem)
    local scTitleLbl = scRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    scTitleLbl:SetPoint("LEFT", scRow, "LEFT", 14, 0); scTitleLbl:SetTextColor(0.9, 0.9, 0.95, 1)
    scTitleLbl:SetText(SM.T("paw_scale"))
    local sc = {val = SolaryMDB.paw_scale or 2}
    local scValLbl = scRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    scValLbl:SetPoint("CENTER", scRow, "CENTER", 0, 0)
    scValLbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    scValLbl:SetText(string.format("%.1f", sc.val))
    local function applyPAScale(s)
        s = math.max(0.5, math.min(8.0, math.floor(s * 2 + 0.5) / 2))
        sc.val = s; scValLbl:SetText(string.format("%.1f", s))
        SolaryMDB.paw_scale = s; SM.SetupPrivateWarningText()
    end
    local scBtnH = math.min(pItem - 14, 40)
    SM.OBtn(scRow, 36, scBtnH, "−", function() applyPAScale(sc.val - 0.5) end):SetPoint("RIGHT", scValLbl, "LEFT", -10, 0)
    SM.OBtn(scRow, 36, scBtnH, "+", function() applyPAScale(sc.val + 0.5) end):SetPoint("LEFT",  scValLbl, "RIGHT", 10, 0)
    py = py - pItem - ITEM_GAP

    MkTogRow(cardPA, py, pItem, "pa_defaults", SolaryMDB.pa_use_defaults ~= false, function(v)
        SolaryMDB.pa_use_defaults = v; SM.RegisterAllPASounds()
    end)
    py = py - pItem - ITEM_GAP

    local editRow = MkBodyRow(cardPA, py, pItem)
    editRow._bg = nil  -- déjà via SM.BG interne de MkBodyRow
    SM.BBtn(editRow, ROW_W - 20, math.min(pItem - 12, 44), SM.T("btn_edit_pa"), function()
        SM.OpenPASoundsWindow()
    end):SetPoint("CENTER", editRow, "CENTER", 0, 0)

    -- ── COLONNE DROITE ─────────────────────────────────────────
    local rx = PAD + COL_W + PAD
    local ry = PAD

    -- CARD : Position des cadres
    local cardFrames = MkCard(rx, ry, COL_W, FRAMES_H, "frames_pos", "frames_cmd")
    local fBody  = FRAMES_H - HDR_H - BODY_PAD * 2
    local fRow   = MkBodyRow(cardFrames, -(HDR_H + BODY_PAD), fBody)
    local fBtnH  = math.min(fBody - 10, 64)
    local fBtnW  = math.floor((ROW_W - 16) / 2)
    SM.RBtn(fRow, fBtnW, fBtnH, SM.T("btn_lock"), function()
        if SM.LockAllFrames then SM.LockAllFrames() end; SM.MoveMode = false
    end):SetPoint("LEFT",  fRow, "LEFT",  8, 0)
    SM.OBtn(fRow, fBtnW, fBtnH, SM.T("btn_move"), function()
        if SM.UnlockAllFrames then SM.UnlockAllFrames() end; SM.MoveMode = true
    end):SetPoint("RIGHT", fRow, "RIGHT", -8, 0)
    ry = ry + FRAMES_H + PAD

    -- CARD : Statut
    local cardStatus = MkCard(rx, ry, COL_W, STATUS_H, "status_lbl", nil)
    local sBody  = STATUS_H - HDR_H - BODY_PAD * 2
    local stRow  = MkBodyRow(cardStatus, -(HDR_H + BODY_PAD), sBody)
    local lineY  = math.floor(sBody * 0.25)
    local bwS = BigWigsLoader and "|cFF55FF55BigWigs \226\128\148|r" or "|cFFAAAAAA\226\128\148BigWigs|r"
    local dbS = DBM          and "|cFF55FF55DBM \226\128\148|r"     or "|cFFAAAAAA\226\128\148DBM|r"
    local edS = SM.IsEditor() and ("|cFF55FF55"..SM.T("editor_lbl").."|r") or ("|cFFAAAAAA"..SM.T("reception_lbl").."|r")
    local spS = "|cFFFFD700"..tostring(#SM.DefaultSpells).." "..SM.T("spells_loaded").."|r"
    local stL1 = stRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    stL1:SetPoint("TOPLEFT", stRow, "TOPLEFT", 14, -lineY)
    stL1:SetPoint("RIGHT", stRow, "RIGHT", -8, 0)
    stL1:SetJustifyH("LEFT"); stL1:SetTextColor(0.88, 0.84, 0.98, 1); stL1:SetText(bwS.."     "..dbS)
    local stL2 = stRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    stL2:SetPoint("TOPLEFT", stRow, "TOPLEFT", 14, -(lineY + math.floor(sBody * 0.45)))
    stL2:SetPoint("RIGHT", stRow, "RIGHT", -8, 0)
    stL2:SetJustifyH("LEFT"); stL2:SetTextColor(0.88, 0.84, 0.98, 1); stL2:SetText(edS.."     "..spS)
    ry = ry + STATUS_H + PAD

    -- CARD : Break timer
    if hasBreak then
        local cardBreak = MkCard(rx, ry, COL_W, BREAK_H, "break_timer", "break_desc")
        local bBody = BREAK_H - HDR_H - BODY_PAD * 2
        local bRow  = MkBodyRow(cardBreak, -(HDR_H + BODY_PAD), bBody)
        local bBtnH = math.min(bBody - 10, 44)

        local breakImgSel = SM.T("random_lbl")
        local dropW = math.floor(ROW_W * 0.42)
        local dropBtn = CreateFrame("Button", nil, bRow)
        dropBtn:SetSize(dropW, bBtnH); dropBtn:SetPoint("LEFT", bRow, "LEFT", 10, 0)
        local dBg = dropBtn:CreateTexture(nil,"BACKGROUND"); dBg:SetAllPoints()
        dBg:SetColorTexture(0.12, 0.10, 0.18, 1)
        local dBdr = dropBtn:CreateTexture(nil,"BORDER"); dBdr:SetAllPoints()
        dBdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.25)
        local dLbl = dropBtn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        dLbl:SetPoint("LEFT", dropBtn, "LEFT", 8, 0); dLbl:SetPoint("RIGHT", dropBtn, "RIGHT", -14, 0)
        dLbl:SetJustifyH("LEFT"); dLbl:SetText(breakImgSel)
        dropBtn:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"):SetPoint("RIGHT", dropBtn, "RIGHT", -4, 0)

        local dropMenu = CreateFrame("Frame", nil, UIParent)
        dropMenu:SetFrameStrata("TOOLTIP"); dropMenu:Hide()
        dropMenu:CreateTexture(nil,"BACKGROUND"):SetAllPoints()
        dropMenu:GetRegions():SetColorTexture(0.08, 0.06, 0.14, 0.98)

        dropBtn:SetScript("OnClick", function()
            if dropMenu:IsShown() then dropMenu:Hide(); return end
            for _, c in ipairs({dropMenu:GetChildren()}) do c:Hide() end
            local imgs = {SM.T("random_lbl")}
            for _, n in ipairs(SM.MediaBreak or {}) do table.insert(imgs, n) end
            dropMenu:SetSize(dropW, #imgs * 22)
            dropMenu:ClearAllPoints(); dropMenu:SetPoint("BOTTOMLEFT", dropBtn, "TOPLEFT", 0, 2)
            for i, name in ipairs(imgs) do
                local item = CreateFrame("Button", nil, dropMenu)
                item:SetSize(dropW, 22); item:SetPoint("TOPLEFT", dropMenu, "TOPLEFT", 0, -(i-1)*22)
                local ibg = item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
                local ilbl = item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                ilbl:SetPoint("LEFT", item, "LEFT", 8, 0); ilbl:SetText(name); ilbl:SetTextColor(0.85,0.82,0.95,1)
                item:SetScript("OnEnter", function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
                item:SetScript("OnLeave", function() ibg:SetColorTexture(0,0,0,0) end)
                local sn = name
                item:SetScript("OnClick", function() breakImgSel=sn; dLbl:SetText(sn); dropMenu:Hide() end)
            end
            dropMenu:Show()
        end)

        local durInput = SM.Input(bRow, 56, bBtnH, "5")
        durInput:SetPoint("LEFT", dropBtn, "RIGHT", 10, 0)
        local minLbl = bRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        minLbl:SetPoint("LEFT", durInput, "RIGHT", 6, 0)
        minLbl:SetTextColor(0.55, 0.50, 0.68, 1); minLbl:SetText("min")

        SM.GBtn(bRow, math.floor(ROW_W * 0.28), bBtnH, SM.T("btn_launch_break"), function()
            dropMenu:Hide()
            SM._breakForcedImage = (breakImgSel ~= SM.T("random_lbl")) and breakImgSel or nil
            local mins = tonumber(SM.GetVal(durInput)) or 5
            if SM.BroadcastBreak then SM.BroadcastBreak(mins * 60) end
        end):SetPoint("RIGHT", bRow, "RIGHT", -10, 0)
    end

    return f
end

-- ============================================================
-- ONGLET 5 : NOTES / ASSIGNATIONS
-- ============================================================

-- ============================================================
-- BUILD + TOGGLE
-- ============================================================
-- ONGLET BOSS TIMERS
-- ============================================================
local function BuildBossTimerTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    local COL_W = math.floor((PANEL_W - 28) / 2)
    local HDR_H = 44
    local ROW_W = COL_W - 4   -- largeur des lignes dans le scroll

    -- ── COLONNE GAUCHE : Mécaniques intelligentes ────────
    local cL = CreateFrame("Frame", nil, f)
    cL:SetSize(COL_W, CONTENT_H + 4)
    cL:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -4)

    local cLHdr = CreateFrame("Frame", nil, cL)
    cLHdr:SetPoint("TOPLEFT", cL, "TOPLEFT", 0, 0)
    cLHdr:SetPoint("TOPRIGHT", cL, "TOPRIGHT", 0, 0); cLHdr:SetHeight(HDR_H)
    local _hb = cLHdr:CreateTexture(nil,"BACKGROUND"); _hb:SetAllPoints(); _hb:SetColorTexture(0.05,0.04,0.09,1)
    local _hs = cLHdr:CreateTexture(nil,"ARTWORK")
    _hs:SetPoint("BOTTOMLEFT"); _hs:SetPoint("BOTTOMRIGHT"); _hs:SetHeight(1)
    _hs:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.4)
    local cLTitle = cLHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    cLTitle:SetPoint("LEFT", cLHdr, "LEFT", 12, 0); cLTitle:SetTextColor(0.85,0.80,1.0,1)
    cLTitle:SetText(SM.T("smart_header") or "MÉCANIQUES INTELLIGENTES")
    local cLSub = cLHdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    cLSub:SetPoint("BOTTOMLEFT", cLHdr, "BOTTOMLEFT", 12, 6); cLSub:SetTextColor(0.45,0.40,0.60,1)
    cLSub:SetText(SM.T("smart_desc") or "")

    local leftScroll = SM.Scroll(cL, COL_W - 4, CONTENT_H + 4 - HDR_H - 2)
    leftScroll:SetPoint("TOPLEFT", cL, "TOPLEFT", 2, -HDR_H)

    local ly = 0
    if SM.SmartAlert then
        for _, mech in ipairs(SM.SmartAlert.GetMechanics()) do
            local MECH_H = 82
            local row = CreateFrame("Frame", nil, leftScroll.content)
            row:SetSize(ROW_W, MECH_H); row:SetPoint("TOPLEFT", 0, -ly)
            SM.BG(row, 0.09, 0.07, 0.14, 1)
            local acc = row:CreateTexture(nil,"ARTWORK")
            acc:SetSize(3, MECH_H); acc:SetPoint("LEFT")
            acc:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],1)

            -- Icône sort
            local ico = row:CreateTexture(nil,"ARTWORK")
            ico:SetSize(38,38); ico:SetPoint("LEFT", row, "LEFT", 12, 0)
            local icoTex = GetSpellTex(mech.spellID)
            if icoTex then ico:SetTexture(icoTex) else ico:SetColorTexture(SM.OR[1]*0.35, SM.OR[2]*0.2, SM.OR[3]*0.45, 1) end

            -- Toggle
            local mechID = mech.id
            local tog = MakeToggle(row, SM.SmartAlert.IsEnabled(mechID), function(v)
                SM.SmartAlert.SetEnabled(mechID, v)
            end)
            tog:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -16)

            -- Go button
            local _soakCast, _belorenSim = 0, 0
            local goBtn = SM.GBtn(row, 46, 24, "Go", function()
                if mech.type == "group_soak_fixed" then
                    _soakCast = _soakCast + 1
                    local isOdd = (_soakCast % 2 == 1)
                    local sub = 1
                    local name = UnitName("player")
                    for i=1,40 do local n,_,sg=GetRaidRosterInfo(i); if n==name and sg then sub=sg; break end end
                    local iMyTurn = (isOdd and sub<=2) or (not isOdd and sub>=3)
                    local msg = iMyTurn and "|cFF00FF00SOAK|r" or ((SM.LANG=="fr") and "|cFFFF4444SOAK PAS|r" or "|cFFFF4444DONT SOAK|r")
                    if SM.ShowTimedAlert then SM.ShowTimedAlert(msg, nil, mech.duration) end
                elseif mech.type == "beloren_feather" then
                    _belorenSim = _belorenSim + 1
                    if SM.Beloren then SM.Beloren._simulate(_belorenSim%2==1 and "light" or "void") end
                end
            end)
            goBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 10)

            local nameLbl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 60, -12)
            nameLbl:SetPoint("RIGHT", tog, "LEFT", -8, 0)
            nameLbl:SetJustifyH("LEFT"); nameLbl:SetTextColor(0.92,0.88,1.0,1)
            nameLbl:SetText(mech.label)

            local descLbl = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            descLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 60, -30)
            descLbl:SetPoint("RIGHT", tog, "LEFT", -8, 0)
            descLbl:SetJustifyH("LEFT"); descLbl:SetTextColor(0.52,0.48,0.62,1)
            descLbl:SetText(SM.LANG=="fr" and (mech.desc_fr or mech.desc_en) or (mech.desc_en or mech.desc_fr))

            local bossLbl = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            bossLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 60, 10)
            bossLbl:SetPoint("RIGHT", goBtn, "LEFT", -6, 0)
            bossLbl:SetJustifyH("LEFT"); bossLbl:SetTextColor(SM.OR[1]*0.7,SM.OR[2]*0.55,SM.OR[3]*0.8,1)
            bossLbl:SetText(mech.boss)

            ly = ly + MECH_H + 6
        end
    end
    -- Section Taunt Alerts
    do
        ly = ly + 10
        local tSep = leftScroll.content:CreateTexture(nil,"ARTWORK")
        tSep:SetSize(ROW_W - 16, 1); tSep:SetPoint("TOPLEFT", leftScroll.content, "TOPLEFT", 8, -ly)
        tSep:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.3)
        ly = ly + 14

        local tauntHdrRow = CreateFrame("Frame", nil, leftScroll.content)
        tauntHdrRow:SetSize(ROW_W, 32); tauntHdrRow:SetPoint("TOPLEFT", 0, -ly)
        SM.BG(tauntHdrRow, 0.05, 0.04, 0.09, 1)
        local tauntTitle = tauntHdrRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        tauntTitle:SetPoint("LEFT", tauntHdrRow, "LEFT", 10, 0)
        tauntTitle:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
        tauntTitle:SetText(SM.LANG=="fr" and "ALERTES DE TAUNT" or "TAUNT ALERTS")
        ly = ly + 36

        local ROW_HT = 48
        local tauntRow = CreateFrame("Frame", nil, leftScroll.content)
        tauntRow:SetSize(ROW_W, ROW_HT); tauntRow:SetPoint("TOPLEFT", 0, -ly)
        SM.BG(tauntRow, 0.09, 0.07, 0.14, 1)
        local tauntAcc = tauntRow:CreateTexture(nil,"ARTWORK")
        tauntAcc:SetSize(3, ROW_HT); tauntAcc:SetPoint("LEFT")
        tauntAcc:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.6)

        if SolaryMDB.taunt_alerts_enabled == nil then SolaryMDB.taunt_alerts_enabled = true end
        local tauntTog = MakeToggle(tauntRow, SolaryMDB.taunt_alerts_enabled, function(v)
            SolaryMDB.taunt_alerts_enabled = v
        end)
        tauntTog:SetPoint("RIGHT", tauntRow, "RIGHT", -10, 0)

        local tauntLbl = tauntRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        tauntLbl:SetPoint("TOPLEFT", tauntRow, "TOPLEFT", 14, -10)
        tauntLbl:SetPoint("RIGHT", tauntTog, "LEFT", -8, 0)
        tauntLbl:SetJustifyH("LEFT"); tauntLbl:SetTextColor(0.92,0.88,1.0,1)
        tauntLbl:SetText(SM.LANG=="fr" and "Alertes de switch de taunt" or "Taunt switch alerts")

        local tauntDescLbl = tauntRow:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        tauntDescLbl:SetPoint("BOTTOMLEFT", tauntRow, "BOTTOMLEFT", 14, 8)
        tauntDescLbl:SetPoint("RIGHT", tauntTog, "LEFT", -8, 0)
        tauntDescLbl:SetJustifyH("LEFT"); tauntDescLbl:SetTextColor(0.52,0.48,0.62,1)
        tauntDescLbl:SetText("Lightblinded Vanguard (HM)")
        ly = ly + ROW_HT + 4
    end

    leftScroll.content:SetHeight(math.max(ly, CONTENT_H - HDR_H))

    -- ── COLONNE DROITE : Alertes de cast + Mythic Casts ──
    local cR = CreateFrame("Frame", nil, f)
    cR:SetSize(COL_W, CONTENT_H + 4)
    cR:SetPoint("TOPLEFT", cL, "TOPRIGHT", 12, 0)

    local cRHdr = CreateFrame("Frame", nil, cR)
    cRHdr:SetPoint("TOPLEFT", cR, "TOPLEFT", 0, 0)
    cRHdr:SetPoint("TOPRIGHT", cR, "TOPRIGHT", 0, 0); cRHdr:SetHeight(HDR_H)
    local _rhb = cRHdr:CreateTexture(nil,"BACKGROUND"); _rhb:SetAllPoints(); _rhb:SetColorTexture(0.05,0.04,0.09,1)
    local _rhs = cRHdr:CreateTexture(nil,"ARTWORK")
    _rhs:SetPoint("BOTTOMLEFT"); _rhs:SetPoint("BOTTOMRIGHT"); _rhs:SetHeight(1)
    _rhs:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.4)
    local cRTitle = cRHdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    cRTitle:SetPoint("LEFT", cRHdr, "LEFT", 12, 0); cRTitle:SetTextColor(0.85,0.80,1.0,1)
    cRTitle:SetText(SM.T("castbar_header") or "ALERTES DE CAST")
    local cRSub = cRHdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    cRSub:SetPoint("BOTTOMLEFT", cRHdr, "BOTTOMLEFT", 12, 6); cRSub:SetTextColor(0.45,0.40,0.60,1)
    cRSub:SetText(SM.T("castbar_desc") or "")

    -- Go test dans le header droite
    if SM.CastBar then
        local testCBBtn = SM.GBtn(cRHdr, 46, 26, "Go", function()
            for _, mech in ipairs(SM.CastBar.GetMechanics()) do
                if SM.CastBar.IsEnabled(mech.id) then
                    if SM.CastBar.Test then SM.CastBar.Test(mech.label, mech.duration) end
                    return
                end
            end
        end)
        testCBBtn:SetPoint("RIGHT", cRHdr, "RIGHT", -10, 0)
    end

    local rightScroll = SM.Scroll(cR, COL_W - 4, CONTENT_H + 4 - HDR_H - 2)
    rightScroll:SetPoint("TOPLEFT", cR, "TOPLEFT", 2, -HDR_H)

    local ry = 0
    local CAST_H = 48

    -- Lignes CastBar
    if SM.CastBar then
        for _, mech in ipairs(SM.CastBar.GetMechanics()) do
            local row = CreateFrame("Frame", nil, rightScroll.content)
            row:SetSize(ROW_W, CAST_H); row:SetPoint("TOPLEFT", 0, -ry)
            SM.BG(row, 0.09, 0.07, 0.14, 1)
            local acc = row:CreateTexture(nil,"ARTWORK")
            acc:SetSize(3, CAST_H); acc:SetPoint("LEFT")
            acc:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.6)

            -- Icône sort
            local ico = row:CreateTexture(nil,"ARTWORK")
            ico:SetSize(34, 34); ico:SetPoint("LEFT", row, "LEFT", 10, 0)
            local tex = GetSpellTex(mech.spellID)
            if tex then ico:SetTexture(tex) else ico:SetColorTexture(SM.OR[1]*0.35,SM.OR[2]*0.2,SM.OR[3]*0.45,1) end

            -- Toggle
            local mechID = mech.id
            local tog = MakeToggle(row, SM.CastBar.IsEnabled(mechID), function(v)
                SM.CastBar.SetEnabled(mechID, v)
            end)
            tog:SetPoint("RIGHT", row, "RIGHT", -10, 0)

            local nameLbl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 54, -10)
            nameLbl:SetPoint("RIGHT", tog, "LEFT", -8, 0)
            nameLbl:SetJustifyH("LEFT"); nameLbl:SetTextColor(0.92,0.88,1.0,1)
            nameLbl:SetText(mech.label)

            local bossLbl = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            bossLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 54, 8)
            bossLbl:SetPoint("RIGHT", tog, "LEFT", -8, 0)
            bossLbl:SetJustifyH("LEFT"); bossLbl:SetTextColor(SM.OR[1]*0.65,SM.OR[2]*0.5,SM.OR[3]*0.75,1)
            bossLbl:SetText(mech.boss)

            ry = ry + CAST_H + 4
        end
    end

    -- Section Mythic Casts
    if SM.MythicCasts then
        ry = ry + 10
        local sep = rightScroll.content:CreateTexture(nil,"ARTWORK")
        sep:SetSize(ROW_W - 16, 1); sep:SetPoint("TOPLEFT", rightScroll.content, "TOPLEFT", 8, -ry)
        sep:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.3)
        ry = ry + 14

        -- Mini header section
        local mcHdrRow = CreateFrame("Frame", nil, rightScroll.content)
        mcHdrRow:SetSize(ROW_W, 32); mcHdrRow:SetPoint("TOPLEFT", 0, -ry)
        SM.BG(mcHdrRow, 0.05, 0.04, 0.09, 1)
        local mcTitle = mcHdrRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        mcTitle:SetPoint("LEFT", mcHdrRow, "LEFT", 10, 0)
        mcTitle:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
        mcTitle:SetText(SM.T("mythic_casts_header") or "CASTS ADDS (M+ & RAID)")

        local mcUnlocked = false
        local goBtn = SM.GBtn(mcHdrRow, 52, 24, "Go", function() end)
        goBtn:SetScript("OnClick", function()
            if mcUnlocked then
                mcUnlocked=false; goBtn._fs:SetText("Go")
                if SM.MythicCasts.Lock then SM.MythicCasts.Lock() end
            else
                mcUnlocked=true; goBtn._fs:SetText("Lock")
                if SM.MythicCasts.Unlock then SM.MythicCasts.Unlock() end
            end
        end)
        goBtn:SetPoint("RIGHT", mcHdrRow, "RIGHT", -6, 0)
        ry = ry + 36

        -- Ligne activer/désactiver
        local ROW_H2 = 40
        local mcEnRow = CreateFrame("Frame", nil, rightScroll.content)
        mcEnRow:SetSize(ROW_W, ROW_H2); mcEnRow:SetPoint("TOPLEFT", 0, -ry)
        SM.BG(mcEnRow, 0.09, 0.07, 0.14, 1)
        local mcAcc = mcEnRow:CreateTexture(nil,"ARTWORK")
        mcAcc:SetSize(3,ROW_H2); mcAcc:SetPoint("LEFT")
        mcAcc:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.6)

        local mcTog = MakeToggle(mcEnRow, SM.MythicCasts.IsEnabled(), function(v)
            SM.MythicCasts.SetEnabled(v)
        end)
        mcTog:SetPoint("RIGHT", mcEnRow, "RIGHT", -10, 0)

        local mcLbl = mcEnRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        mcLbl:SetPoint("LEFT", mcEnRow, "LEFT", 14, 0)
        mcLbl:SetPoint("RIGHT", mcTog, "LEFT", -8, 0)
        mcLbl:SetJustifyH("LEFT"); mcLbl:SetTextColor(0.92,0.88,1.0,1)
        mcLbl:SetText(SM.T("mythic_casts_enable") or "Activer les casts adds")
        ry = ry + ROW_H2 + 4

        -- Ligne taille
        local scRow = CreateFrame("Frame", nil, rightScroll.content)
        scRow:SetSize(ROW_W, ROW_H2); scRow:SetPoint("TOPLEFT", 0, -ry)
        SM.BG(scRow, 0.09, 0.07, 0.14, 1)
        local scAcc = scRow:CreateTexture(nil,"ARTWORK")
        scAcc:SetSize(3,ROW_H2); scAcc:SetPoint("LEFT")
        scAcc:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.6)

        local scTitleLbl = scRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        scTitleLbl:SetPoint("LEFT", scRow, "LEFT", 14, 0)
        scTitleLbl:SetTextColor(0.9,0.9,0.95,1)
        scTitleLbl:SetText(SM.T("mythic_casts_scale") or "Taille")

        local curScale = SM.MythicCasts.GetScale and SM.MythicCasts.GetScale() or 1.0
        local scValLbl = scRow:CreateFontString(nil,"OVERLAY","GameFontNormal")
        scValLbl:SetPoint("CENTER", scRow, "CENTER", 0, 0)
        scValLbl:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
        scValLbl:SetText(math.floor(curScale*100+0.5).."%")

        local function applyScale(s)
            s = math.max(0.50, math.min(2.0, math.floor(s*20+0.5)/20))
            scValLbl:SetText(math.floor(s*100+0.5).."%")
            if SM.MythicCasts.SetScale then SM.MythicCasts.SetScale(s) end
            curScale = s
        end
        local scMin = SM.OBtn(scRow, 28, 24, "−", function() applyScale(curScale-0.05) end)
        scMin:SetPoint("RIGHT", scValLbl, "LEFT", -6, 0)
        local scPlus = SM.OBtn(scRow, 28, 24, "+", function() applyScale(curScale+0.05) end)
        scPlus:SetPoint("LEFT", scValLbl, "RIGHT", 6, 0)

        ry = ry + ROW_H2 + 4
    end

    rightScroll.content:SetHeight(math.max(ry, CONTENT_H - HDR_H))

    return f
end

-- ============================================================
local function BuildMemoryTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.07, 0.10, 1)
    if SM.MemoryGame and SM.MemoryGame.BuildInputPanel then
        local p = SM.MemoryGame.BuildInputPanel(f, PANEL_W, CONTENT_H)
        p:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    end
    return f
end

local function BuildVersionTab(parent)
    if SM.VersionCheck and SM.VersionCheck.BuildTab then
        local f = SM.VersionCheck.BuildTab(parent, PANEL_W, CONTENT_H+8)
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
        return f
    end
    -- Fallback si module non chargé
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.07, 0.10, 1)
    return f
end

local CHANGELOGS = {
    {
        version = "3.0.3",
        date    = "29 Avril 2026",
        fr = {
            "Alertes Boss — Fix du double-fire résiduel : BigWigs fire parfois deux fois le même sort (prédictif + CLEU), et UNIT_SPELLCAST_START se déclenchait en parallèle ; les deux sont maintenant dédupliqués",
            "Alertes Boss — Fix des alertes cônes & rebirth Belo'ren qui ne se déclenchaient pas avec BigWigs actif",
            "Belo'ren — Nouvelle barre de progression dédiée aux hits de cônes (violet → orange → rouge)",
            "SmartCasts — Alertes de switch de taunt pour Lightblinded Vanguard (HM), tanks uniquement",
            "SmartCasts — Toggle pour activer/désactiver les alertes de taunt",
        },
        en = {
            "Boss Alerts — Fixed residual double-fire: BigWigs sometimes fires the same spell twice (predictive + CLEU), and UNIT_SPELLCAST_START was also firing in parallel; both are now deduplicated",
            "Boss Alerts — Fixed Belo'ren cone & rebirth alerts not firing when BigWigs was active",
            "Belo'ren — New dedicated progress bar for cone hits (purple → orange → red)",
            "SmartCasts — Taunt switch alerts for Lightblinded Vanguard (HM), tanks only",
            "SmartCasts — Toggle to enable/disable taunt alerts",
        },
    },
    {
        version = "3.0.2",
        date    = "28 Avril 2026",
        fr = {
            "Notes — Refonte de l'onglet Notes : layout 3 colonnes (bibliothèque, éditeur, actions)",
            "Notes — Notes partagées et personnelles fusionnées dans un seul onglet avec sous-onglets",
            "Notes — Fix du bouton 'Afficher' : ouvre le bon cadre selon le mode (partagée ou personnelle)",
            "Notes — Label 'Bibliothèque de Notes' renommé en 'Notes'",
            "Alertes Reminders — Grip de resize pour ajuster la largeur et la hauteur du conteneur",
            "Alertes Reminders — Cadre violet visible en mode édition pour repérer facilement le conteneur",
            "Alertes Reminders — Taille du texte proportionnelle à la hauteur, auto-réduite pour rester sur une ligne",
            "Alertes Boss — Fix du double-affichage : BossTimer et Alert.lua hookaient BigWigs/DBM en même temps",
            "Alertes Boss — Suppression du spam throttle qui bloquait plusieurs mécaniques simultanées",
            "Rappels Note — Fix du timer affiché : le décompte démarre maintenant depuis le prealert et atteint 0 exactement au moment de la mécanique",
            "Rappels Note — Fix du compteur de rotation de groupe : deux configs de même nom ne partagent plus le même compteur",
        },
        en = {
            "Notes — Notes tab redesign: 3-column layout (library, editor, actions)",
            "Notes — Shared and personal notes merged into a single tab with sub-tabs",
            "Notes — Fixed 'Display' button: opens the correct frame based on mode (shared or personal)",
            "Notes — 'Bibliothèque de Notes' label renamed to 'Notes'",
            "Reminder Alerts — Resize grip to adjust container width and height",
            "Reminder Alerts — Purple visible frame in edit mode to easily locate the container",
            "Reminder Alerts — Font size proportional to height, auto-shrunk to always stay on one line",
            "Boss Alerts — Fixed double display: BossTimer and Alert.lua were both hooking BigWigs/DBM",
            "Boss Alerts — Removed spam throttle that was blocking simultaneous mechanics",
            "Note Reminders — Fixed displayed timer: countdown now starts from prealert and hits 0 exactly when the mechanic fires",
            "Note Reminders — Fixed group rotation counter: two configs with the same name no longer share the same counter",
        },
    },
    {
        version = "3.0.1",
        date    = "27 Avril 2026",
        fr = {
            "Notes — Fix du bug de duplication : une note reçue mise à jour écrase l'existante au lieu d'en créer une nouvelle",
            "Notes — L'éditeur se met à jour automatiquement à la réception d'une note modifiée",
            "Notes — Remplacement du protocole d'envoi par AceComm/ChatThrottleLib (plus de notes perdues lors d'envois rapprochés)",
            "DBM — WIP sera bientôt réparer (erreur 'Attempt to register unknown event DBM_TimerStart' corrigée dans Alert, BossTimer et Assignments)",
        },
        en = {
            "Notes — Fixed note duplication bug: a received updated note now overwrites the existing one instead of creating a new one",
            "Notes — Editor now auto-updates when a modified note is received",
            "Notes — Replaced send protocol with AceComm/ChatThrottleLib (no more dropped notes on rapid sends)",
            "DBM — WIP will soon be repaired ('Attempt to register unknown event DBM_TimerStart' error fixed in Alert, BossTimer and Assignments)",
        },
    },
    {
        version = "3.0.0",
        date    = "27 Avril 2026",
        fr = {
            "Général — Refonte graphique de l'addon, plus compréhensible, plus clair",
            "MythicCasts — Fix du bug de secretvalue, fonctionne à nouveau normalement",
            "Spells — Ajout d'un bouton 'Supprimé' et 'Ajouter un sort' dans l'onglet"
        },
        en = {
            "General — Addon visual overhaul, more understandable and clearer",
            "MythicCasts — Fixed the secretvalue bug; it now works normally again",
            "Spells — Added 'Delete' and 'Add Spell' buttons to the tab.",
        },
    },
    {
        version = "2.0.5",
        date    = "26 Avril 2026",
        fr = {
            "MythicCasts — Les adds de Vaelgor & Ezzorak ainsi que Chimaerus n'afficherons plus leurs castsbar",
            "BossTimers — Fix sur le retour de multiples erreurs LUA contre Belo'ren & Crown",
            "Général — Le panel n'empêche plus le déplacement du personnage"
        },
        en = {
            "MythicCasts — Vaelgor & Ezzorak's add, as well as Chimaerus, will no longer display their cast bars.",
            "BossTimers — Fix on the return of multiple LUA errors against Belo'ren & Crown",
            "General — Panel no longer prevents the character from moving"
        },
    },
        {
        version = "2.0.4",
        date    = "25 Avril 2026",
        fr = {
            "Notes — Notes personnels sont désormais fonctionnel dans l'onglet 'Notes'",
            "Notes — Dropdowns affichent désormais uniquement les boss qui ont une note existante",
            "Général — Appuyer sur 'Echap' ferme maintenant le panel de l'addon",
            "Général — Changer la langue de l'addon ne reset plus le panel au milieu de l'écran"
        },
        en = {
            "Notes — Personal notes are now working in 'Notes' tab",
            "Notes — Dropdowns now only show the bosses with existing notes",
            "General — Pressing 'Escape' button now close the addon panel",
            "General — Changing the addon's language no longer resets the panel in the middle of the screen",
        },
    },
    {
        version = "2.0.3",
        date    = "24 Avril 2026",
        fr = {
            "Notes — Refonte visuelle complète du panneau Notes Partagées (layout deux colonnes, liste scrollable, éditeur droit)",
            "Notes — Dropdown boss & difficulté avec flèche texturée, icônes de boss via l'Encounter Journal",
            "Notes — Liste des boss mise à jour pour l'extension Midnight (Flèche du vide, Marche sur Quel'Danas, La faille du rêve)",
            "Notes — Sous-onglet 'Mes Notes' marqué WIP",
            "Notes — Suppression des caractères Unicode non supportés par les polices du jeu",
            "Notes — Correction du layout des boutons d'action en bas du panneau droit",
            "Notes — Champ de renommage ajouté dans l'éditeur droit",
            "Notes — Créer une note pré-assigne le boss du filtre actif et focus le champ nom automatiquement",
            "BossTimers — Correction erreur 'secret keys' sur UNIT_SPELLCAST_START (sorts protégés ignorés)",
        },
        en = {
            "Notes — Full visual rework of the Shared Notes panel (two-column layout, scrollable list, right-side editor)",
            "Notes — Boss & difficulty dropdowns with textured arrow, boss icons via Encounter Journal",
            "Notes — Boss list updated for the Midnight expansion (The Voidspire, March on Quel'Danas, The Dreamrift)",
            "Notes — 'My Notes' sub-tab marked WIP",
            "Notes — Removed Unicode characters unsupported by game fonts",
            "Notes — Fixed action button layout at the bottom of the right panel",
            "Notes — Rename field added in the right editor panel",
            "Notes — Creating a note pre-assigns the active boss filter and auto-focuses the name field",
            "BossTimers — Fixed 'secret keys' error on UNIT_SPELLCAST_START (protected spells now ignored)",
        },
    },
    {
        version = "2.0.2",
        date    = "24 Avril 2026",
        fr = {
            "MythicCasts — A nouveau fonctionnel, sans erreur LUA",
            "Reminders — Onglet Note Personnel rajouté (WIP)",
            "BossTimers — Plus d'erreur LUA pendant Crown/Belo'ren"
        },
        en = {
            "MythicCasts — Now works properly, no more LUA errors",
            "Reminders — Personal Notes now with Reminders (WIP)",
            "BossTimers — No more LUA errors while fighting Crown/Belo'ren"
        },
    },
    {
        version = "2.0.1",
        date    = "22 Avril 2026",
        fr = {
            "TOC — Passer en version 12.0.5 ",
            "Reminders — Erreur LUA du aux changements API fixé",
            "Reminders — Bouton Envoyer au raid a été placé sous la note, il ne gêne plus la box",
        },
        en = {
            "TOC — Updated to match 12.0.5",
            "Reminders — LUA errors caused by API changes fixed",
            "Reminders — Send to raid button is now under the note, no longer inside the box"
        },
    },
    {
        version = "2.0.0",
        date    = "21 Avril 2026",
        fr = {
            "Memory Game — L'ura (Midnight Falls) : affichage des runes en combat via CHAT_MSG_RAID",
            "Memory Game — icônes affichées via FontString + SetFormattedText",
            "Memory Game — bridge propre : RegisterEvent depuis contexte non-tainté (C_Timer + OnUpdate)",
            "Memory Game — icônes redimensionnées à 256px pour une lisibilité optimale en raid",
            "Memory Game — macros SOLMG_1..5 (7242384, etc.)",
            "Reminder — zone de collage de note avec scroll (plus de débordement sur les boutons)",
        },
        en = {
            "Memory Game — L'ura (Midnight Falls): rune display in combat via CHAT_MSG_RAID",
            "Memory Game — icons displayed via FontString + SetFormattedText",
            "Memory Game — clean bridge: RegisterEvent from untainted context (C_Timer + OnUpdate)",
            "Memory Game — icons resized to 256px for optimal raid readability",
            "Memory Game — SOLMG_1..5 (7242384, etc.)",
            "Reminder — note paste box now has a scroll (no more overflow onto buttons)",
        },
    },
    {
        version = "1.1.2",
        date    = "18 Avril 2026",
        fr = {
            "Mythic Casts — barre verte (interruptible) / grise (non interruptible)",
            "Mythic Casts — timer (ex: 3.2s) affiché à droite, coloré selon temps restant",
            "Mythic Casts — target inline à droite du nom du sort, colorée par classe",
            "Mythic Casts — filtrage des mobs hors combat avec le joueur",
            "Mythic Casts — icône affichée par-dessus la barre (corrige le recouvrement)",
            "Mythic Casts — slider de taille (50%–200%) dans le panel, sauvegardé",
            "Mythic Casts — correction du bouton Go (preview) dans le panel",
            "Correction erreur ADDON_ACTION_FORBIDDEN au login (RegisterEvent déplacé dans PLAYER_LOGIN)",
        },
        en = {
            "Mythic Casts — green bar (interruptible) / grey (not interruptible)",
            "Mythic Casts — timer (e.g. 3.2s) displayed on the right, color-coded by time left",
            "Mythic Casts — target inline right of spell name, class-colored",
            "Mythic Casts — filter out mobs not in combat with the player",
            "Mythic Casts — icon rendered above the bar fill (fixes overlap)",
            "Mythic Casts — size slider (50%–200%) in panel, saved between sessions",
            "Mythic Casts — fixed Go button (preview) in panel",
            "Fix ADDON_ACTION_FORBIDDEN error on login (RegisterEvent moved to PLAYER_LOGIN)",
        },
    },
    {
        version = "1.1.1",
        date    = "17 Avril 2026",
        fr = {
            "Module Mythic Casts — casts des adds en M+ et en raid (nameplates)",
            "Mythic Casts — affichage texte avec icône, décompte et target ciblée",
            "Mythic Casts — accent orange (interruptible) ou rouge (non interruptible)",
            "Mythic Casts — conteneur indépendant, déplaçable via Paramètres",
            "Mythic Casts — système de callouts : alerte centrale sur casts critiques",
            "Demiar (Crown) — callout STOP CAST sur Interrupting Tremor (1243743)",
            "Boutons — redesign : fond solide sombre, accent coloré gauche, hover propre",
            "Mode Move — les cadres désactivés n'apparaissent plus lors du déplacement",
            "Suppression des traductions FR de la SpellDB (193 entrées)",
        },
        en = {
            "Mythic Casts module — add casts in M+ and raid (nameplates)",
            "Mythic Casts — text display with icon, countdown and spell target",
            "Mythic Casts — orange accent (interruptible) or red (not interruptible)",
            "Mythic Casts — independent container, movable via Settings",
            "Mythic Casts — callout system: central alert on critical casts",
            "Demiar (Crown) — STOP CAST callout on Interrupting Tremor (1243743)",
            "Buttons — redesign: solid dark background, colored left accent, clean hover",
            "Move mode — disabled frames no longer appear when repositioning",
            "Removed FR translations from SpellDB (193 entries)",
        },
    },
    {
        version = "1.1.0",
        date    = "16 Avril 2026",
        fr = {
            "SmartCast — onglet renommé, réorganisé avec deux colonnes (mécaniques / alertes cast)",
            "Alertes cast — affichage texte décompté, conteneur séparé des alertes boss",
            "Alertes cast — support fixed, phased et spell_cast (détection CLEU)",
            "L'ura — Glaives, Transition (6.5s) et Intermission (30s) ajoutées",
            "Belo'ren — fenêtre Rebirth 30s détectée via CLEU (spellID 1263412)",
            "Belo'ren — icônes Light/Void depuis C_Spell.GetSpellTexture en simulation",
            "SmartAlert — descriptions traduites (desc_fr / desc_en)",
            "SmartAlert — SOAK / DONT SOAK sans labels de groupe",
            "Internationalisation complète FR/EN — bouton bascule dans le panel",
            "Pré-alerte déplacée dans Paramètres, s'applique aux alertes boss en général",
            "Suppression du doublon Media/break.tga (-1.4 Mo)",
        },
        en = {
            "SmartCast — tab renamed, reorganised with two columns (mechanics / cast alerts)",
            "Cast alerts — counted-down text display, container separate from boss alerts",
            "Cast alerts — fixed, phased and spell_cast support (CLEU detection)",
            "L'ura — Glaives, Transition (6.5s) and Intermission (30s) added",
            "Belo'ren — Rebirth 30s window detected via CLEU (spellID 1263412)",
            "Belo'ren — Light/Void icons from C_Spell.GetSpellTexture in simulation",
            "SmartAlert — translated descriptions (desc_fr / desc_en)",
            "SmartAlert — SOAK / DONT SOAK without group labels",
            "Full FR/EN internationalisation — toggle button in panel",
            "Pre-alert moved to Settings, applies to boss alerts in general",
            "Removed duplicate Media/break.tga (-1.4 MB)",
        },
    },
    {
        version = "1.0.5",
        date    = "15 Avril 2026",
        fr = {
            "Onglets dynamiques selon le rôle — éditeurs et non-éditeurs voient des onglets différents",
            "Non-éditeurs : uniquement Boss Timers, Paramètres, Changelogs",
            "Éditeurs : accès complet à tous les onglets",
            "Break Timer masqué pour les non-éditeurs",
            "Memory Game restreint aux éditeurs (envoi des symboles uniquement)",
            "Onglet Invites masqué pour les non-éditeurs",
            "Onglet Versions masqué pour les non-éditeurs",
            "Bouton Stop Break supprimé",
        },
        en = {
            "Dynamic tabs based on role — editors and non-editors see different tabs",
            "Non-editors: Boss Timers, Settings, Changelogs only",
            "Editors: full access to all tabs",
            "Break Timer hidden for non-editors",
            "Memory Game restricted to editors (symbol sending only)",
            "Invites tab hidden for non-editors",
            "Versions tab hidden for non-editors",
            "Stop Break button removed",
        },
    },
    {
        version = "1.0.4",
        date    = "15 Avril 2026",
        fr = {
            "Bouton minimap — icône Solary cliquable autour de la minimap via LibDBIcon",
            "Break Timer — images aléatoires sans répétition (shuffle)",
            "Break Timer — dropdown pour choisir une image spécifique ou aléatoire",
            "Break Timer — correction du bug stop/restart (timer de fade annulé proprement)",
            "Break Timer — correction du stop broadcast qui se déclenchait sur soi-même",
            "Sons Private Auras — sons baseline Midnight S1 Raid (29 sorts)",
            "Sons Private Auras — fenêtre dédiée avec liste scrollable",
            "Onglet Changelogs avec toggle Français/English",
        },
        en = {
            "Minimap button — Solary icon around the minimap via LibDBIcon",
            "Break Timer — random images without repetition (shuffle)",
            "Break Timer — dropdown to pick a specific or random image",
            "Break Timer — fixed stop/restart bug (fade timer properly cancelled)",
            "Break Timer — fixed stop broadcast triggering on self",
            "Private Aura Sounds — Midnight S1 Raid baseline sounds (29 spells)",
            "Private Aura Sounds — dedicated window with scrollable list",
            "Changelogs tab with French/English toggle",
        },
    },
    {
        version = "1.0.3",
        date    = "14 Avril 2026",
        fr = {
            "Sons Private Auras — fenêtre dédiée avec liste scrollable",
            "Sons Private Auras baseline Midnight S1 Raid intégrés (29 sorts)",
            "Activation/désactivation des sons par défaut via checkbox",
            "Correction Belo'ren — plus de gate ENCOUNTER_START, détection via UNIT_AURA directement",
            "Correction BossTimer — ProcessBWBar hors de portée (nil value)",
            "Correction Alert — barText secret ne plante plus sur :lower()",
            "Break Timer — images aléatoires depuis Media/Break/",
            "Scan automatique Media/Sounds et Media/Break au login",
            "Dropdown sons dynamique (liste depuis scan, pas hardcodée)",
            "Dropdown sons dans l'onglet Spells pour chaque mécanique",
            "Private Aura Warning Text — repositionnement précis via deux frames",
            "Suppression de la liste des éditeurs de l'onglet Paramètres",
        },
        en = {
            "Private Aura Sounds — dedicated window with scrollable list",
            "Midnight S1 Raid baseline PA sounds built-in (29 spells)",
            "Enable/disable default PA sounds via checkbox",
            "Belo'ren fix — removed ENCOUNTER_START gate, direct UNIT_AURA detection",
            "BossTimer fix — ProcessBWBar out of scope (nil value)",
            "Alert fix — secret barText no longer crashes on :lower()",
            "Break Timer — random images from Media/Break/",
            "Auto-scan Media/Sounds and Media/Break on login",
            "Dynamic sound dropdown (from scan, not hardcoded)",
            "Sound dropdown in Spells tab per mechanic",
            "Private Aura Warning Text — precise repositioning via two frames",
            "Removed editors list from Settings tab",
        },
    },
    {
        version = "1.0.2",
        date    = "13 Avril 2026",
        fr = {
            "Module Belo'ren — détection Light/Void Feather via filtrage UNIT_AURA",
            "Affichage icône de la plume au centre de l'écran pendant 5 secondes",
            "Private Aura Warning Text — repositionner le texte Blizzard via SetPrivateWarningTextAnchor",
            "Son par mécanique — dropdown dans l'onglet Spells",
            "Suppression de SolaryM_Auras.lua (inutilisé)",
        },
        en = {
            "Belo'ren module — Light/Void Feather detection via UNIT_AURA filter",
            "Feather icon display centered on screen for 5 seconds",
            "Private Aura Warning Text — reposition Blizzard text via SetPrivateWarningTextAnchor",
            "Sound per mechanic — dropdown in Spells tab",
            "Removed SolaryM_Auras.lua (unused)",
        },
    },
    {
        version = "1.0.1",
        date    = "12 Avril 2026",
        fr = {
            "Version Check — sections RAID et GUILDE séparées",
            "Version Check — affiche les membres sans l'addon en rouge (NON INSTALLÉ)",
            "Version Check — réponses via canal RAID/GUILD (WHISPER bloqué en Midnight)",
            "Break Timer — Stop Break broadcast au raid (cache l'image chez tout le monde)",
            "TTS — joue 2 secondes avant l'impact de la mécanique",
            "Paramètres — compactage pour faire rentrer le Break Timer dans le cadre",
        },
        en = {
            "Version Check — separate RAID and GUILD sections",
            "Version Check — members without addon shown in red (NOT INSTALLED)",
            "Version Check — replies via RAID/GUILD channel (WHISPER blocked in Midnight)",
            "Break Timer — Stop Break broadcast to raid (hides image for everyone)",
            "TTS — plays 2 seconds before mechanic impact",
            "Settings — compacted to fit Break Timer inside frame",
        },
    },
    {
        version = "1.0.0",
        date    = "11 Avril 2026",
        fr = {
            "Sortie initiale de SolaryM",
            "Onglet Spells — callouts par sort avec TTS, broadcast raid",
            "Boss Timers — alertes visuelles via hook BigWigs",
            "Invites — gestion des invitations raid",
            "Memory Game L'ura — barre de saisie + broadcast en temps réel",
            "Version Check — vérifier qui a l'addon dans le raid/guilde",
            "Paramètres — seuil d'affichage, taille alertes, break timer",
        },
        en = {
            "Initial release of SolaryM",
            "Spells tab — per-spell callouts with TTS, raid broadcast",
            "Boss Timers — visual alerts via BigWigs hook",
            "Invites — raid invitation management",
            "Memory Game L'ura — input bar + real-time broadcast",
            "Version Check — see who has the addon in raid/guild",
            "Settings — display threshold, alert size, break timer",
        },
    },
}

local function BuildChangelogsTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PANEL_W, CONTENT_H+8)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:Hide()

    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.03, 0.09, 1)

    -- Header bar
    local hdrBg = f:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    hdrBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    hdrBg:SetHeight(48)
    hdrBg:SetColorTexture(0.08, 0.05, 0.14, 1)

    local hdrLine = f:CreateTexture(nil, "ARTWORK")
    hdrLine:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -48)
    hdrLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -48)
    hdrLine:SetHeight(2)
    hdrLine:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.7)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
    title:SetTextColor(0.90, 0.82, 1.0, 1)
    title:SetText("Changelogs")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    sub:SetPoint("LEFT", title, "RIGHT", 8, -1)
    sub:SetText("SolaryM")
    sub:SetTextColor(0.42, 0.35, 0.55, 1)

    -- Toggle langue
    local lang = "fr"
    local langBtn = SM.BBtn(f, 80, 24, "English", nil)
    langBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -12)

    -- Scroll
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -58)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 8)
    local scrollContent = CreateFrame("Frame", nil, scroll)
    local CW = PANEL_W - 52
    scrollContent:SetSize(CW, 1)
    scroll:SetScrollChild(scrollContent)

    local lineLabels = {}

    local function BuildLines()
        local ry = 10
        for idx, entry in ipairs(CHANGELOGS) do
            local maxLines = math.max(#entry.fr, #entry.en)
            local CARD_H = maxLines * 20 + 48
            local cy = ry

            -- Card background
            local cardBg = scrollContent:CreateTexture(nil, "BACKGROUND")
            cardBg:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -cy)
            cardBg:SetSize(CW, CARD_H)
            if idx == 1 then
                cardBg:SetColorTexture(0.11, 0.07, 0.19, 1)
            else
                cardBg:SetColorTexture(0.07, 0.04, 0.12, 1)
            end

            -- Left accent bar
            local accent = scrollContent:CreateTexture(nil, "OVERLAY")
            accent:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -cy)
            accent:SetSize(3, CARD_H)
            if idx == 1 then
                accent:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
            else
                accent:SetColorTexture(SM.OR[1]*0.65, SM.OR[2]*0.65, SM.OR[3]*0.65, 0.65)
            end

            -- Version + date label
            local vhdr = scrollContent:CreateFontString(nil, "OVERLAY")
            vhdr:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
            vhdr:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 12, -(cy+8))

            -- "NEW" badge on latest entry
            if idx == 1 then
                local nbBg = scrollContent:CreateTexture(nil, "ARTWORK")
                nbBg:SetSize(38, 17)
                nbBg:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -6, -(cy+8))
                nbBg:SetColorTexture(0.18, 0.72, 0.35, 0.85)
                local nbTxt = scrollContent:CreateFontString(nil, "OVERLAY")
                nbTxt:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                nbTxt:SetPoint("CENTER", nbBg, "CENTER", 0, 0)
                nbTxt:SetText("NEW")
                nbTxt:SetTextColor(1, 1, 1, 1)
            end

            -- Thin rule below header zone
            local rule = scrollContent:CreateTexture(nil, "ARTWORK")
            rule:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 6, -(cy+30))
            rule:SetSize(CW - 12, 1)
            rule:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12)

            -- Bullet lines
            local entryLines = {}
            for i = 1, maxLines do
                local ly = cy + 36 + (i-1)*20
                local dot = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                dot:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 14, -ly)
                dot:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)
                dot:SetText("•")

                local lbl = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 26, -ly)
                lbl:SetPoint("RIGHT", scrollContent, "RIGHT", -4, 0)
                lbl:SetJustifyH("LEFT")
                lbl:SetTextColor(0.83, 0.80, 0.89, 1)
                table.insert(entryLines, {dot=dot, lbl=lbl})
            end
            table.insert(lineLabels, {vhdr=vhdr, lines=entryLines, entry=entry})
            ry = ry + CARD_H + 10
        end
        scrollContent:SetHeight(math.max(ry, 1))
    end

    local function Rebuild()
        for _, block in ipairs(lineLabels) do
            local entry = block.entry
            block.vhdr:SetText("|cFFD4BEFFv"..entry.version.."|r  |cFF7A7788"..entry.date.."|r")
            local lines = lang == "fr" and entry.fr or entry.en
            for i, pair in ipairs(block.lines) do
                local txt = lines[i] or ""
                pair.lbl:SetText(txt)
                pair.dot:SetShown(txt ~= "")
                pair.lbl:SetShown(txt ~= "")
            end
        end
    end

    BuildLines()

    langBtn:SetScript("OnClick", function()
        if lang == "fr" then
            lang = "en"
            if langBtn._fs then langBtn._fs:SetText("Français") end
        else
            lang = "fr"
            if langBtn._fs then langBtn._fs:SetText("English") end
        end
        Rebuild()
    end)

    Rebuild()
    return f
end

-- ============================================================
-- ONGLET NOTES — layout 3 colonnes : Bibliothèque | Éditeur | Actions
-- ============================================================
local function BuildRemindersTab(parent)
    local RN = SM.ReminderNote

    if not StaticPopupDialogs["SOLARYM_CONFIRM_DEL"] then
        StaticPopupDialogs["SOLARYM_CONFIRM_DEL"] = {
            text = "%s", button1 = SM.T("rem_btn_delete"), button2 = SM.T("rem_btn_cancel"),
            OnAccept = function(self) if self._cb then self._cb() end end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    local function ConfirmDel(text, cb)
        local d = StaticPopup_Show("SOLARYM_CONFIRM_DEL", text)
        if d then d._cb = cb end
    end

    -- ── Frame principale ──────────────────────────────────────
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, CONTENT_Y)
    f:SetSize(PANEL_W, CONTENT_H+8); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    -- ── Constantes layout ──────────────────────────────────────
    local HDR_H    = 88
    local LEFT_W   = 280
    local RIGHT_W  = 230
    local CENTER_W = PANEL_W - LEFT_W - RIGHT_W - 2
    local COL_TOP  = HDR_H + 1
    local COL_H    = CONTENT_H + 8 - COL_TOP
    local PAD      = 10
    local ROW_H    = 28
    local ROW_GAP  = 2
    local LHDR_H   = 32
    local STAB_H   = 32
    local CHDR_H   = 32
    local RHDR_H   = 32

    -- ── État ──────────────────────────────────────────────────
    local currentMode  = "shared"
    local selName      = nil
    local listRows     = {}
    local filterBoss   = nil

    -- ── Helpers données ───────────────────────────────────────
    local function getReminders()
        if not SolaryMDB then return {} end
        if currentMode == "personal" then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            return SolaryMDB.personal_reminders
        end
        SolaryMDB.reminders = SolaryMDB.reminders or {}
        return SolaryMDB.reminders
    end

    local function getMeta(name)
        if not SolaryMDB then return {} end
        if currentMode == "personal" then
            SolaryMDB.personal_reminders_meta = SolaryMDB.personal_reminders_meta or {}
            SolaryMDB.personal_reminders_meta[name] = SolaryMDB.personal_reminders_meta[name] or {}
            return SolaryMDB.personal_reminders_meta[name]
        end
        SolaryMDB.reminders_meta = SolaryMDB.reminders_meta or {}
        SolaryMDB.reminders_meta[name] = SolaryMDB.reminders_meta[name] or {}
        return SolaryMDB.reminders_meta[name]
    end

    local function getNoteNames()
        local rem = getReminders()
        local names = {}
        for k in pairs(rem) do names[#names+1] = k end
        table.sort(names)
        return names
    end

    -- ── Forward declarations ──────────────────────────────────
    local LoadNoteInEditor, RefreshList
    local noteEditor, noteNameInput, bossDrop, diffDrop
    local recvRow, recvNameLbl, filterDrop
    local listChild, listScrollBar, listScroll, lScrollW
    local rNoSelLbl, loadSendBtn, unloadBtn

    -- ── EJ icon cache ─────────────────────────────────────────
    local ejIconCache = {}
    do
        local targets = {[3134]=true,[3135]=true,[3176]=true,[3177]=true,[3178]=true,
                         [3179]=true,[3180]=true,[3181]=true,[3182]=true,[3183]=true,[3306]=true}
        local found = 0
        for jID = 1, 4000 do
            if found >= 11 then break end
            local ename, _, _, _, _, _, dungeonEncID = EJ_GetEncounterInfo(jID)
            if ename and dungeonEncID and targets[dungeonEncID] then
                local _, _, _, _, icon = EJ_GetCreatureInfo(1, jID)
                ejIconCache[dungeonEncID] = icon or false
                found = found + 1
            end
        end
    end

    -- ── Boss / Difficulté ──────────────────────────────────────
    local BOSS_LIST = {
        {text=SM.T("rem_boss_none"),  value=nil},
        {text="-- The Voidspire --",           value=nil, isHeader=true},
        {text="Imperator Averzian",             value=3176},
        {text="Vorasius",                       value=3177},
        {text="Vaelgor & Ezzorak",              value=3178},
        {text="Fallen King Salhadaar",          value=3179},
        {text="Lightblinded Vanguard",          value=3180},
        {text="Crown of the Cosmos",            value=3181},
        {text="-- March on Quel'Danas --",      value=nil, isHeader=true},
        {text="Belo'ren",                       value=3182},
        {text="Midnight Falls",                 value=3183},
        {text="-- The Dreamrift --",            value=nil, isHeader=true},
        {text="Chimaerus",                      value=3306},
    }
    local DIFF_LIST = {
        {text="Normal",                 value="normal"},
        {text=SM.T("rem_diff_heroic"), value="heroic"},
        {text=SM.T("rem_diff_mythic"), value="mythic"},
    }

    -- ── MakeDrop ──────────────────────────────────────────────
    local function MakeDrop(dropParent, popupAnchor, w, h, items, onSelect)
        local btn = CreateFrame("Button", nil, dropParent)
        btn:SetSize(w, h)
        local bgTex = btn:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints(); bgTex:SetColorTexture(0.05, 0.04, 0.09, 1)

        local btnIcon = btn:CreateTexture(nil, "ARTWORK")
        btnIcon:SetSize(h-6, h-6)
        btnIcon:SetPoint("LEFT", btn, "LEFT", 4, 0)
        btnIcon:Hide()

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\ARIALN.TTF", 12, "")
        lbl:SetPoint("LEFT",  btn, "LEFT",  8, 0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
        lbl:SetJustifyH("LEFT"); lbl:SetJustifyV("MIDDLE")
        lbl:SetTextColor(0.82, 0.82, 0.86, 1)
        btn._lbl = lbl

        local arr = btn:CreateTexture(nil, "OVERLAY")
        arr:SetSize(16, 14)
        arr:SetPoint("RIGHT", btn, "RIGHT", 2, -1)
        arr:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Up]])
        arr:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.85)

        local popup = CreateFrame("Frame", nil, popupAnchor, "BackdropTemplate")
        popup:SetWidth(w)
        popup:SetFrameLevel(popupAnchor:GetFrameLevel() + 80)
        popup:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background", tile=true, tileSize=32,
            edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
        })
        popup:SetBackdropColor(0.07, 0.06, 0.11, 0.98)
        popup:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.28)
        popup:Hide()
        btn._popup = popup

        local selValue = nil
        local rowBtns  = {}

        local function getEncIcon(encID)
            if type(encID) ~= "number" then return nil end
            local v = ejIconCache[encID]
            if v then return v end
            return nil
        end

        local function applyBtnIcon(iconImg)
            lbl:ClearAllPoints()
            if iconImg then
                btnIcon:SetTexture(iconImg); btnIcon:Show()
                lbl:SetPoint("LEFT",  btnIcon, "RIGHT", 4, 0)
            else
                btnIcon:Hide()
                lbl:SetPoint("LEFT",  btn, "LEFT", 8, 0)
            end
            lbl:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
        end

        local function UpdateHL()
            for i, rb in ipairs(rowBtns) do
                local same = (items[i].value == selValue) and not items[i].isHeader
                rb._sel:SetAlpha(same and 1 or 0)
                local isH = items[i].isHeader
                rb._lbl:SetTextColor(
                    same and 1 or (isH and 0.45 or 0.80),
                    same and 1 or (isH and 0.45 or 0.80),
                    same and 1 or (isH and 0.52 or 0.84), 1)
            end
        end

        local totalPopH = 0
        for i, item in ipairs(items) do
            local itemH = item.isHeader and 16 or 24
            local rb = CreateFrame("Button", nil, popup)
            rb:SetHeight(itemH)
            rb:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -(totalPopH+1))
            rb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -(totalPopH+1))
            local rbSel = rb:CreateTexture(nil, "BACKGROUND")
            rbSel:SetAllPoints()
            rbSel:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.14)
            rbSel:SetAlpha(0); rb._sel = rbSel
            if not item.isHeader then
                rb:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
                local hlt = rb:GetHighlightTexture()
                if hlt then hlt:SetBlendMode("ADD"); hlt:SetAlpha(0.18) end
            end
            local lblXOff = item.isHeader and 6 or 10
            if not item.isHeader and type(item.value) == "number" then
                local iconImg = getEncIcon(item.value)
                if iconImg then
                    local rbIcon = rb:CreateTexture(nil, "ARTWORK")
                    rbIcon:SetSize(16, 16)
                    rbIcon:SetPoint("LEFT", rb, "LEFT", 4, 0)
                    rbIcon:SetTexture(iconImg)
                    lblXOff = 24
                end
            end
            local rbLbl = rb:CreateFontString(nil, "OVERLAY")
            rbLbl:SetFont("Fonts\\ARIALN.TTF", item.isHeader and 10 or 12, "")
            rbLbl:SetPoint("LEFT",  rb, "LEFT",  lblXOff, 0)
            rbLbl:SetPoint("RIGHT", rb, "RIGHT", -4, 0)
            rbLbl:SetJustifyH("LEFT"); rbLbl:SetJustifyV("MIDDLE")
            rbLbl:SetText(item.text)
            rbLbl:SetTextColor(item.isHeader and 0.45 or 0.80,
                               item.isHeader and 0.45 or 0.80,
                               item.isHeader and 0.52 or 0.84, 1)
            rb._lbl = rbLbl
            if not item.isHeader then
                local iv = item
                rb:SetScript("OnClick", function()
                    selValue = iv.value
                    lbl:SetText(iv.text)
                    applyBtnIcon(type(iv.value) == "number" and getEncIcon(iv.value) or nil)
                    UpdateHL(); popup:Hide()
                    if onSelect then onSelect(iv.value, iv.text) end
                end)
            end
            rowBtns[i] = rb
            totalPopH = totalPopH + itemH
        end
        popup:SetHeight(totalPopH + 2)

        for _, item in ipairs(items) do
            if not item.isHeader then
                selValue = item.value; lbl:SetText(item.text)
                applyBtnIcon(type(item.value) == "number" and getEncIcon(item.value) or nil)
                break
            end
        end
        UpdateHL()

        btn:SetScript("OnClick", function()
            if popup:IsShown() then popup:Hide()
            else
                popup:ClearAllPoints()
                popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
                popup:Show()
            end
        end)
        btn.GetValue = function() return selValue end
        btn.SetByID  = function(val)
            for _, item in ipairs(items) do
                if item.value == val then
                    selValue = item.value; lbl:SetText(item.text)
                    applyBtnIcon(type(item.value) == "number" and getEncIcon(item.value) or nil)
                    UpdateHL(); return
                end
            end
            selValue = nil; lbl:SetText(items[1].text)
            applyBtnIcon(nil); UpdateHL()
        end
        btn.RefreshVisible = function(visibleSet)
            local totalH = 0
            for i, rb in ipairs(rowBtns) do
                local iv = items[i]
                local show = (visibleSet == nil) or (iv.value == nil) or (visibleSet[iv.value] == true)
                if show then
                    rb:Show()
                    rb:ClearAllPoints()
                    rb:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -(totalH+1))
                    rb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -(totalH+1))
                    totalH = totalH + rb:GetHeight()
                else
                    rb:Hide()
                end
            end
            popup:SetHeight(totalH + 2)
        end
        return btn
    end  -- /MakeDrop

    -- ══════════════════════════════════════════════════════════
    -- ZONE HEADER
    -- ══════════════════════════════════════════════════════════
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    hdr:SetHeight(HDR_H)
    SM.BG(hdr, 0.06, 0.05, 0.09, 1)

    local hdrAccent = hdr:CreateTexture(nil, "ARTWORK")
    hdrAccent:SetWidth(3)
    hdrAccent:SetPoint("TOPLEFT",    hdr, "TOPLEFT",    0, 0)
    hdrAccent:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
    hdrAccent:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)

    local titleFS = hdr:CreateFontString(nil, "OVERLAY")
    titleFS:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    titleFS:SetPoint("TOPLEFT", hdr, "TOPLEFT", 18, -10)
    titleFS:SetText("NOTES DE RAID")
    titleFS:SetTextColor(1, 1, 1, 1)

    local subFS = hdr:CreateFontString(nil, "OVERLAY")
    subFS:SetFont("Fonts\\ARIALN.TTF", 11, "")
    subFS:SetPoint("BOTTOMLEFT", titleFS, "BOTTOMRIGHT", 10, 2)
    subFS:SetText("Gère, édite et diffuse tes notes de boss")
    subFS:SetTextColor(SM.OR[1]*0.75, SM.OR[2]*0.75, SM.OR[3]*0.75, 1)

    -- Filtre boss dans le header
    local filterItems = {{text=SM.T("rem_filter_all_boss"), value=nil}}
    for _, b in ipairs(BOSS_LIST) do
        if not b.isHeader and b.value then
            filterItems[#filterItems+1] = {text=b.text, value=b.value}
        end
    end
    filterDrop = MakeDrop(hdr, f, 210, 26, filterItems, function(val)
        filterBoss = val
        RefreshList()
    end)
    filterDrop:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 18, 10)

    local newNoteBtn = SM.OBtn(hdr, 148, 26, SM.T("rem_btn_create"), nil)
    newNoteBtn:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -PAD, 10)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetHeight(1)
    hdrSep:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -HDR_H)
    hdrSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HDR_H)
    hdrSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.28)

    -- ══════════════════════════════════════════════════════════
    -- COLONNE GAUCHE — BIBLIOTHÈQUE
    -- ══════════════════════════════════════════════════════════
    local lBg = CreateFrame("Frame", nil, f)
    lBg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -COL_TOP)
    lBg:SetSize(LEFT_W, COL_H)
    SM.BG(lBg, 0.07, 0.06, 0.10, 1)

    -- En-tête section
    local lHdrBg = lBg:CreateTexture(nil, "BACKGROUND")
    lHdrBg:SetPoint("TOPLEFT",  lBg, "TOPLEFT",  0, 0)
    lHdrBg:SetPoint("TOPRIGHT", lBg, "TOPRIGHT", 0, 0)
    lHdrBg:SetHeight(LHDR_H)
    lHdrBg:SetColorTexture(0.09, 0.08, 0.14, 1)

    local lHdrLbl = lBg:CreateFontString(nil, "OVERLAY")
    lHdrLbl:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    lHdrLbl:SetPoint("TOPLEFT", lBg, "TOPLEFT", PAD, -10)
    lHdrLbl:SetText("NOTES")
    lHdrLbl:SetTextColor(SM.OR[1]*0.85, SM.OR[2]*0.85, SM.OR[3]*0.85, 1)

    -- Diviseur droit
    local lDiv = lBg:CreateTexture(nil, "OVERLAY")
    lDiv:SetWidth(1)
    lDiv:SetPoint("TOPRIGHT",    lBg, "TOPRIGHT", 0, 0)
    lDiv:SetPoint("BOTTOMRIGHT", lBg, "BOTTOMRIGHT", 0, 0)
    lDiv:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)

    -- Sous-onglets TOUS LES BOSS | MES NOTES
    local stabW = math.floor(LEFT_W / 2)
    local function MakeLStab(label, xOff, w)
        local btn = CreateFrame("Button", nil, lBg)
        btn:SetSize(w, STAB_H)
        btn:SetPoint("TOPLEFT", lBg, "TOPLEFT", xOff, -LHDR_H)
        local sbg = btn:CreateTexture(nil, "BACKGROUND")
        sbg:SetAllPoints(); sbg:SetColorTexture(0.06, 0.05, 0.09, 1)
        btn._bg = sbg
        btn:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
        local shlt = btn:GetHighlightTexture()
        if shlt then shlt:SetBlendMode("ADD"); shlt:SetAlpha(0.10) end
        local lfs = btn:CreateFontString(nil, "OVERLAY")
        lfs:SetFont("Fonts\\ARIALN.TTF", 11, "")
        lfs:SetAllPoints(); lfs:SetJustifyH("CENTER"); lfs:SetJustifyV("MIDDLE")
        lfs:SetText(label); lfs:SetTextColor(0.48, 0.48, 0.55, 1)
        btn._lbl = lfs
        local ac = btn:CreateTexture(nil, "ARTWORK")
        ac:SetHeight(2)
        ac:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  2, 0)
        ac:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 0)
        ac:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        ac:Hide()
        btn._accent = ac
        return btn
    end

    local sharedStab   = MakeLStab(SM.T("rem_filter_all_boss"), 0,      stabW)
    local personalStab = MakeLStab(SM.T("rem_subtab_personal"), stabW, LEFT_W - stabW)

    local stabSepY = -(LHDR_H + STAB_H)
    local stabSep = lBg:CreateTexture(nil, "ARTWORK")
    stabSep:SetHeight(1)
    stabSep:SetPoint("TOPLEFT",  lBg, "TOPLEFT",  0, stabSepY)
    stabSep:SetPoint("TOPRIGHT", lBg, "TOPRIGHT", 0, stabSepY)
    stabSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)

    -- Boutons d'action
    local actY = stabSepY - 5
    local bW3  = math.floor((LEFT_W - PAD*2 - 4) / 3)
    local importBtn = SM.Btn(lBg, bW3, 24, SM.T("rem_btn_import"),
        SM.OR[1]*0.10, SM.OR[2]*0.10, SM.OR[3]*0.16, nil)
    importBtn:SetPoint("TOPLEFT", lBg, "TOPLEFT", PAD, actY)

    unloadBtn = SM.Btn(lBg, bW3, 24, SM.T("rem_btn_unload"), 0.10, 0.10, 0.14, nil)
    unloadBtn:SetPoint("LEFT", importBtn, "RIGHT", 2, 0)

    local delAllBtn = SM.RBtn(lBg, bW3, 24, SM.T("rem_btn_del_all"), nil)
    delAllBtn:SetPoint("LEFT", unloadBtn, "RIGHT", 2, 0)

    -- Ligne Reçu (mode partagé seulement)
    local recvY = actY - 24 - 5
    recvRow = CreateFrame("Frame", nil, lBg)
    recvRow:SetPoint("TOPLEFT",  lBg, "TOPLEFT",  PAD, recvY)
    recvRow:SetPoint("TOPRIGHT", lBg, "TOPRIGHT", -PAD, recvY)
    recvRow:SetHeight(18)

    local recvLabel = recvRow:CreateFontString(nil, "OVERLAY")
    recvLabel:SetFont("Fonts\\ARIALN.TTF", 11, "")
    recvLabel:SetPoint("LEFT", recvRow, "LEFT", 0, 0)
    recvLabel:SetText(SM.T("rem_recv_label"))
    recvLabel:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)

    recvNameLbl = recvRow:CreateFontString(nil, "OVERLAY")
    recvNameLbl:SetFont("Fonts\\ARIALN.TTF", 11, "")
    recvNameLbl:SetPoint("LEFT",  recvLabel, "RIGHT",  4, 0)
    recvNameLbl:SetPoint("RIGHT", recvRow,   "RIGHT", -22, 0)
    recvNameLbl:SetJustifyH("LEFT")
    recvNameLbl:SetTextColor(0.75, 0.75, 0.80, 1)
    recvNameLbl:SetText(SM.T("rem_recv_none"))

    local recvXBtn = CreateFrame("Button", nil, recvRow)
    recvXBtn:SetSize(18, 18)
    recvXBtn:SetPoint("RIGHT", recvRow, "RIGHT", 0, 0)
    local recvXFS = recvXBtn:CreateFontString(nil, "OVERLAY")
    recvXFS:SetFont("Fonts\\ARIALN.TTF", 11, "")
    recvXFS:SetAllPoints(); recvXFS:SetText("[X]")
    recvXFS:SetTextColor(0.40, 0.40, 0.46, 1)
    recvXBtn:SetScript("OnEnter", function() recvXFS:SetTextColor(1, 0.3, 0.3, 1) end)
    recvXBtn:SetScript("OnLeave", function() recvXFS:SetTextColor(0.40, 0.40, 0.46, 1) end)
    recvXBtn:SetScript("OnClick", function()
        if RN then RN.ClearReceived() end
        recvNameLbl:SetText(SM.T("rem_recv_none"))
    end)

    -- Séparateur avant liste
    local lSep2Y = recvY - 18 - 5
    local lSep2 = lBg:CreateTexture(nil, "ARTWORK")
    lSep2:SetHeight(1)
    lSep2:SetPoint("TOPLEFT",  lBg, "TOPLEFT",  0, lSep2Y)
    lSep2:SetPoint("TOPRIGHT", lBg, "TOPRIGHT", 0, lSep2Y)
    lSep2:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12)

    -- Zone liste scrollable
    lScrollW = LEFT_W - PAD*2 - 14
    local listTopY = lSep2Y - 4
    listScroll = CreateFrame("ScrollFrame", nil, lBg)
    listScroll:SetPoint("TOPLEFT",     lBg, "TOPLEFT",     PAD,     listTopY)
    listScroll:SetPoint("BOTTOMRIGHT", lBg, "BOTTOMRIGHT", -PAD-14, PAD)

    listScrollBar = CreateFrame("Slider", nil, lBg, "UIPanelScrollBarTemplate")
    listScrollBar:SetPoint("TOPLEFT",    listScroll, "TOPRIGHT",    2, -16)
    listScrollBar:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 2,  16)
    listScrollBar:SetMinMaxValues(0, 0); listScrollBar:SetValueStep(ROW_H)
    listScrollBar:SetScript("OnValueChanged", function(_, val)
        listScroll:SetVerticalScroll(val)
    end)
    listScrollBar:SetValue(0)
    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(_, delta)
        local cur = listScrollBar:GetValue()
        local lo, hi = listScrollBar:GetMinMaxValues()
        listScrollBar:SetValue(math.max(lo, math.min(hi, cur - delta * ROW_H * 3)))
    end)

    listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(lScrollW, 1)
    listScroll:SetScrollChild(listChild)

    -- ══════════════════════════════════════════════════════════
    -- COLONNE CENTRE — ÉDITEUR DE NOTE
    -- ══════════════════════════════════════════════════════════
    local cX  = LEFT_W + 1
    local cBg = CreateFrame("Frame", nil, f)
    cBg:SetPoint("TOPLEFT", f, "TOPLEFT", cX, -COL_TOP)
    cBg:SetSize(CENTER_W, COL_H)
    SM.BG(cBg, 0.07, 0.06, 0.10, 1)

    local cHdrBg = cBg:CreateTexture(nil, "BACKGROUND")
    cHdrBg:SetPoint("TOPLEFT",  cBg, "TOPLEFT",  0, 0)
    cHdrBg:SetPoint("TOPRIGHT", cBg, "TOPRIGHT", 0, 0)
    cHdrBg:SetHeight(CHDR_H)
    cHdrBg:SetColorTexture(0.09, 0.08, 0.14, 1)

    local cHdrLbl = cBg:CreateFontString(nil, "OVERLAY")
    cHdrLbl:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    cHdrLbl:SetPoint("TOPLEFT", cBg, "TOPLEFT", PAD, -10)
    cHdrLbl:SetText("ÉDITEUR DE NOTE")
    cHdrLbl:SetTextColor(SM.OR[1]*0.85, SM.OR[2]*0.85, SM.OR[3]*0.85, 1)

    local cDiv = cBg:CreateTexture(nil, "OVERLAY")
    cDiv:SetWidth(1)
    cDiv:SetPoint("TOPRIGHT",    cBg, "TOPRIGHT", 0, 0)
    cDiv:SetPoint("BOTTOMRIGHT", cBg, "BOTTOMRIGHT", 0, 0)
    cDiv:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)

    -- Champ nom
    local nameY = -(CHDR_H + 6)
    noteNameInput = CreateFrame("EditBox", nil, cBg, "InputBoxTemplate")
    noteNameInput:SetPoint("TOPLEFT",  cBg, "TOPLEFT",  PAD+4, nameY)
    noteNameInput:SetPoint("TOPRIGHT", cBg, "TOPRIGHT", -PAD-4, nameY)
    noteNameInput:SetHeight(24)
    noteNameInput:SetFont("Fonts\\ARIALN.TTF", 13, "")
    noteNameInput:SetAutoFocus(false); noteNameInput:SetMaxLetters(128)
    noteNameInput:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    noteNameInput:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
    noteNameInput:SetScript("OnEditFocusLost", function(s)
        if not selName then return end
        local newName = s:GetText()
        if newName == "" or newName == selName then return end
        local rem = getReminders()
        if not rem then return end
        rem[newName] = rem[selName]; rem[selName] = nil
        local metaKey = currentMode == "personal" and "personal_reminders_meta" or "reminders_meta"
        if SolaryMDB then
            SolaryMDB[metaKey] = SolaryMDB[metaKey] or {}
            SolaryMDB[metaKey][newName] = SolaryMDB[metaKey][selName]
            SolaryMDB[metaKey][selName] = nil
        end
        if currentMode == "shared" and SolaryMDB and SolaryMDB.active_reminder == selName then
            SolaryMDB.active_reminder = newName
        end
        selName = newName
        RefreshList()
    end)

    -- Boss + Diff
    local dropY     = nameY - 24 - 5
    local bossDropW = math.floor(CENTER_W * 0.58) - PAD
    local diffDropW = math.floor(CENTER_W * 0.30)
    bossDrop = MakeDrop(cBg, f, bossDropW, 26, BOSS_LIST, nil)
    bossDrop:SetPoint("TOPLEFT", cBg, "TOPLEFT", PAD, dropY)
    diffDrop = MakeDrop(cBg, f, diffDropW, 26, DIFF_LIST, nil)
    diffDrop:SetPoint("LEFT", bossDrop, "RIGHT", 6, 0)

    local cSepY = dropY - 26 - 5
    local cSep2 = cBg:CreateTexture(nil, "ARTWORK")
    cSep2:SetHeight(1)
    cSep2:SetPoint("TOPLEFT",  cBg, "TOPLEFT",  0, cSepY)
    cSep2:SetPoint("TOPRIGHT", cBg, "TOPRIGHT", 0, cSepY)
    cSep2:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.15)

    rNoSelLbl = cBg:CreateFontString(nil, "OVERLAY")
    rNoSelLbl:SetFont("Fonts\\ARIALN.TTF", 14, "")
    rNoSelLbl:SetPoint("CENTER", cBg, "CENTER", 0, 20)
    rNoSelLbl:SetText(SM.T("rem_no_selection"))
    rNoSelLbl:SetTextColor(0.28, 0.28, 0.32, 1)

    local edTopY = cSepY - 4
    local edScroll = CreateFrame("ScrollFrame", nil, cBg, "UIPanelScrollFrameTemplate")
    edScroll:SetPoint("TOPLEFT",     cBg, "TOPLEFT",      PAD,      edTopY)
    edScroll:SetPoint("BOTTOMRIGHT", cBg, "BOTTOMRIGHT", -(PAD+18), PAD)
    SM.BG(edScroll, 0.04, 0.04, 0.07, 0.80)

    noteEditor = CreateFrame("EditBox", nil, edScroll)
    noteEditor:SetMultiLine(true); noteEditor:SetAutoFocus(false)
    noteEditor:SetFont("Fonts\\ARIALN.TTF", 13, "")
    noteEditor:SetMaxLetters(0)
    noteEditor:SetWidth(CENTER_W - PAD*2 - 20)
    noteEditor:SetTextColor(0.88, 0.88, 0.92, 1)
    noteEditor:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    noteEditor:SetScript("OnTextChanged", function(s)
        local w = edScroll:GetWidth()
        if w > 0 then s:SetWidth(w) end
    end)
    edScroll:SetScrollChild(noteEditor)
    edScroll:SetScript("OnSizeChanged", function(s, w)
        if w > 0 then noteEditor:SetWidth(w) end
    end)
    edScroll:SetScript("OnMouseDown", function() noteEditor:SetFocus() end)

    -- ══════════════════════════════════════════════════════════
    -- COLONNE DROITE — ACTIONS & TEST
    -- ══════════════════════════════════════════════════════════
    local rX  = LEFT_W + 1 + CENTER_W + 1
    local rBg = CreateFrame("Frame", nil, f)
    rBg:SetPoint("TOPLEFT", f, "TOPLEFT", rX, -COL_TOP)
    rBg:SetSize(RIGHT_W, COL_H)
    SM.BG(rBg, 0.07, 0.06, 0.10, 1)

    local rHdrBg = rBg:CreateTexture(nil, "BACKGROUND")
    rHdrBg:SetPoint("TOPLEFT",  rBg, "TOPLEFT",  0, 0)
    rHdrBg:SetPoint("TOPRIGHT", rBg, "TOPRIGHT", 0, 0)
    rHdrBg:SetHeight(RHDR_H)
    rHdrBg:SetColorTexture(0.09, 0.08, 0.14, 1)

    local rHdrLbl = rBg:CreateFontString(nil, "OVERLAY")
    rHdrLbl:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    rHdrLbl:SetPoint("TOPLEFT", rBg, "TOPLEFT", PAD, -10)
    rHdrLbl:SetText("ACTIONS & TEST")
    rHdrLbl:SetTextColor(SM.OR[1]*0.85, SM.OR[2]*0.85, SM.OR[3]*0.85, 1)

    local rPAD  = PAD
    local BW    = RIGHT_W - rPAD*2
    local BH    = 26
    local rCurY = -(RHDR_H + 8)

    local function MakeRSection(label)
        local sep = rBg:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  rBg, "TOPLEFT",  0, rCurY)
        sep:SetPoint("TOPRIGHT", rBg, "TOPRIGHT", 0, rCurY)
        sep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.12)
        local fs = rBg:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
        fs:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY - 5)
        fs:SetText(label)
        fs:SetTextColor(0.42, 0.42, 0.52, 1)
        rCurY = rCurY - 20
    end

    MakeRSection("APERÇU EN JEU")
    local showBtn = SM.Btn(rBg, BW, BH, SM.T("rem_btn_show"), 0.08, 0.12, 0.20, nil)
    showBtn:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY)
    rCurY = rCurY - BH - 10

    MakeRSection("ENVOYER AU RAID")
    loadSendBtn = SM.BBtn(rBg, BW, BH, SM.T("rem_btn_load_send"), nil)
    loadSendBtn:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY)
    rCurY = rCurY - BH - 10

    MakeRSection("COMMANDES")
    local saveBtn2 = SM.OBtn(rBg, BW, BH, SM.T("rem_btn_save"), nil)
    saveBtn2:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY)
    rCurY = rCurY - BH - 4

    local halfBW = math.floor((BW - 4) / 2)
    local testBtn = SM.OBtn(rBg, halfBW, BH, SM.T("rem_btn_test"), nil)
    testBtn:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY)
    local stopBtn = SM.RBtn(rBg, halfBW, BH, SM.T("rem_btn_stop"), nil)
    stopBtn:SetPoint("LEFT", testBtn, "RIGHT", 4, 0)
    rCurY = rCurY - BH - 4

    local delBtn2 = SM.RBtn(rBg, BW, BH, SM.T("rem_btn_delete"), nil)
    delBtn2:SetPoint("TOPLEFT", rBg, "TOPLEFT", rPAD, rCurY)

    -- ══════════════════════════════════════════════════════════
    -- OVERLAY IMPORT (couvre centre + droite)
    -- ══════════════════════════════════════════════════════════
    local importOverlay = CreateFrame("Frame", nil, f, "BackdropTemplate")
    importOverlay:SetPoint("TOPLEFT",     f, "TOPLEFT",     cX, -COL_TOP)
    importOverlay:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  0,  0)
    importOverlay:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background", tile=true, tileSize=64,
        edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
    })
    importOverlay:SetBackdropColor(0.06, 0.05, 0.10, 0.97)
    importOverlay:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.20)
    importOverlay:SetFrameLevel(f:GetFrameLevel() + 20)
    importOverlay:Hide()

    local impPAD = PAD + 4
    local impOvW = CENTER_W + RIGHT_W + 2

    local impTitle = importOverlay:CreateFontString(nil, "OVERLAY")
    impTitle:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    impTitle:SetPoint("TOPLEFT", importOverlay, "TOPLEFT", impPAD, -impPAD)
    impTitle:SetText(SM.T("rem_import_header"))
    impTitle:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)

    local impCloseBtn = CreateFrame("Button", nil, importOverlay)
    impCloseBtn:SetSize(20, 20)
    impCloseBtn:SetPoint("TOPRIGHT", importOverlay, "TOPRIGHT", -impPAD, -impPAD)
    local impCloseFS = impCloseBtn:CreateFontString(nil, "OVERLAY")
    impCloseFS:SetFont("Fonts\\ARIALN.TTF", 13, "")
    impCloseFS:SetAllPoints(); impCloseFS:SetText("[X]")
    impCloseFS:SetTextColor(0.40, 0.40, 0.46, 1)
    impCloseBtn:SetScript("OnEnter", function() impCloseFS:SetTextColor(1, 0.3, 0.3, 1) end)
    impCloseBtn:SetScript("OnLeave", function() impCloseFS:SetTextColor(0.40, 0.40, 0.46, 1) end)
    impCloseBtn:SetScript("OnClick", function() importOverlay:Hide() end)

    local impNameHdr = importOverlay:CreateFontString(nil, "OVERLAY")
    impNameHdr:SetFont("Fonts\\ARIALN.TTF", 12, "")
    impNameHdr:SetPoint("TOPLEFT", importOverlay, "TOPLEFT", impPAD, -(impPAD + 30))
    impNameHdr:SetText(SM.T("rem_name_label"))
    impNameHdr:SetTextColor(0.60, 0.60, 0.66, 1)

    local impNameInput = SM.Input(importOverlay, impOvW - impPAD*2, 22, SM.T("rem_name_ph"))
    impNameInput:SetPoint("TOPLEFT", importOverlay, "TOPLEFT", impPAD, -(impPAD + 48))

    local impPasteHdr = importOverlay:CreateFontString(nil, "OVERLAY")
    impPasteHdr:SetFont("Fonts\\ARIALN.TTF", 12, "")
    impPasteHdr:SetPoint("TOPLEFT", importOverlay, "TOPLEFT", impPAD, -(impPAD + 82))
    impPasteHdr:SetText(SM.T("rem_paste_label"))
    impPasteHdr:SetTextColor(0.60, 0.60, 0.66, 1)

    local impPasteScroll = CreateFrame("ScrollFrame", nil, importOverlay, "UIPanelScrollFrameTemplate")
    impPasteScroll:SetPoint("TOPLEFT",     importOverlay, "TOPLEFT",      impPAD,      -(impPAD + 100))
    impPasteScroll:SetPoint("BOTTOMRIGHT", importOverlay, "BOTTOMRIGHT", -(impPAD+18),  36)
    SM.BG(impPasteScroll, 0.04, 0.04, 0.07, 1)

    local impPasteBox = CreateFrame("EditBox", nil, impPasteScroll)
    impPasteBox:SetMultiLine(true); impPasteBox:SetAutoFocus(false)
    impPasteBox:SetFont("Fonts\\ARIALN.TTF", 12, "")
    impPasteBox:SetMaxLetters(0)
    impPasteBox:SetWidth(impOvW - impPAD*2 - 20)
    impPasteBox:SetTextColor(0.88, 0.88, 0.92, 1)
    impPasteBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    impPasteScroll:SetScrollChild(impPasteBox)
    impPasteScroll:SetScript("OnMouseDown", function() impPasteBox:SetFocus() end)

    local impConfirmBtn = SM.OBtn(importOverlay, 110, 24, SM.T("rem_btn_import"), nil)
    impConfirmBtn:SetPoint("BOTTOMLEFT", importOverlay, "BOTTOMLEFT", impPAD, impPAD)
    local impCancelBtn = SM.RBtn(importOverlay, 80, 24, SM.T("rem_btn_cancel"), nil)
    impCancelBtn:SetPoint("LEFT", impConfirmBtn, "RIGHT", 4, 0)
    impCancelBtn:SetScript("OnClick", function() importOverlay:Hide() end)

    -- ══════════════════════════════════════════════════════════
    -- LOGIQUE CORE
    -- ══════════════════════════════════════════════════════════
    function LoadNoteInEditor(name)
        selName = name
        rNoSelLbl:Hide()
        noteNameInput:SetText(name)
        noteNameInput:SetTextColor(1, 1, 1, 1)
        local rem = getReminders()
        noteEditor:SetText(rem[name] or "")
        local meta = getMeta(name)
        bossDrop.SetByID(meta.boss)
        diffDrop.SetByID(meta.diff)
        RefreshList()
    end

    function RefreshList()
        for _, ro in ipairs(listRows) do ro.btn:Hide() end
        listRows = {}

        if currentMode == "shared" then
            if RN and RN.GetLastReceived then
                recvNameLbl:SetText(RN.GetLastReceived() or SM.T("rem_recv_none"))
            end
            recvRow:Show(); loadSendBtn:Show(); unloadBtn:Show()
        else
            recvRow:Hide(); loadSendBtn:Hide(); unloadBtn:Hide()
        end

        local names = getNoteNames()
        local totalH = 0
        local hasVisible = false

        local bossesWithNotes = {}
        for _, n in ipairs(names) do
            local m = getMeta(n)
            if m.boss then bossesWithNotes[m.boss] = true end
        end
        if filterBoss and not bossesWithNotes[filterBoss] then
            filterBoss = nil
            if filterDrop then filterDrop.SetByID(nil) end
        end

        for _, name in ipairs(names) do
            local skip = filterBoss and (getMeta(name).boss ~= filterBoss)
            if not skip then
                hasVisible = true
                local btn = CreateFrame("Button", nil, listChild)
                btn:SetSize(lScrollW, ROW_H)
                btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -totalH)

                btn:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
                local hlt = btn:GetHighlightTexture()
                if hlt then hlt:SetBlendMode("ADD"); hlt:SetAlpha(0.22) end

                local isSel    = (name == selName)
                local isActive = (currentMode == "shared" and SolaryMDB
                                  and SolaryMDB.active_reminder == name)

                local selTex = btn:CreateTexture(nil, "BACKGROUND")
                selTex:SetPoint("LEFT",   btn, "LEFT",   2, 0)
                selTex:SetPoint("RIGHT",  btn, "RIGHT",  0, 0)
                selTex:SetPoint("TOP",    btn, "TOP",    0, 0)
                selTex:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
                selTex:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.15)
                selTex:SetAlpha(isSel and 1 or 0)

                local accentTex = btn:CreateTexture(nil, "ARTWORK")
                accentTex:SetWidth(2)
                accentTex:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
                accentTex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
                accentTex:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
                if isSel then accentTex:Show() else accentTex:Hide() end

                local activeDot = btn:CreateTexture(nil, "OVERLAY")
                activeDot:SetSize(6, 6)
                activeDot:SetPoint("LEFT", btn, "LEFT", 6, 0)
                activeDot:SetColorTexture(0.2, 0.9, 0.2, 1)
                if isActive then activeDot:Show() else activeDot:Hide() end

                local editBtn = CreateFrame("Button", nil, btn)
                editBtn:SetSize(16, 16)
                editBtn:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
                local editIcon = editBtn:CreateTexture(nil, "ARTWORK")
                editIcon:SetAllPoints()
                editIcon:SetTexture([[Interface\GossipFrame\PetitionGossipIcon]])
                editIcon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
                editIcon:SetVertexColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.65)
                editBtn:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
                local eH = editBtn:GetHighlightTexture()
                if eH then eH:SetBlendMode("ADD"); eH:SetAlpha(0.5) end

                local lbl = btn:CreateFontString(nil, "OVERLAY")
                lbl:SetFont("Fonts\\ARIALN.TTF", 13, "")
                lbl:SetPoint("LEFT",  btn, "LEFT",  isActive and 16 or 10, 0)
                lbl:SetPoint("RIGHT", editBtn, "LEFT", -2, 0)
                lbl:SetJustifyH("LEFT"); lbl:SetJustifyV("MIDDLE")
                lbl:SetText(name)
                if isSel then
                    lbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
                elseif isActive then
                    lbl:SetTextColor(0.4, 0.9, 0.4, 1)
                else
                    lbl:SetTextColor(0.85, 0.85, 0.88, 1)
                end

                local renameBox = CreateFrame("EditBox", nil, btn, "InputBoxTemplate")
                renameBox:SetPoint("LEFT",  btn,     "LEFT",  isActive and 16 or 8, 0)
                renameBox:SetPoint("RIGHT", editBtn, "LEFT",  -2, 0)
                renameBox:SetHeight(ROW_H - 8)
                renameBox:SetFont("Fonts\\ARIALN.TTF", 13, "")
                renameBox:SetAutoFocus(false); renameBox:Hide()
                renameBox:SetScript("OnEscapePressed", function(s) s:Hide(); lbl:Show() end)
                renameBox:SetScript("OnEditFocusLost", function(s) s:Hide(); lbl:Show() end)
                local rn = name
                renameBox:SetScript("OnEnterPressed", function(s)
                    local newName = s:GetText()
                    s:Hide()
                    if newName == "" or newName == rn or not SolaryMDB then lbl:Show(); return end
                    local rem = getReminders()
                    rem[newName] = rem[rn]; rem[rn] = nil
                    local metaKey = currentMode == "personal" and "personal_reminders_meta" or "reminders_meta"
                    SolaryMDB[metaKey] = SolaryMDB[metaKey] or {}
                    SolaryMDB[metaKey][newName] = SolaryMDB[metaKey][rn]
                    SolaryMDB[metaKey][rn] = nil
                    if currentMode == "shared" and SolaryMDB.active_reminder == rn then
                        SolaryMDB.active_reminder = newName
                    end
                    if selName == rn then selName = newName; LoadNoteInEditor(newName) end
                    RefreshList()
                end)
                editBtn:SetScript("OnClick", function()
                    lbl:Hide(); renameBox:SetText(rn); renameBox:Show(); renameBox:SetFocus()
                end)

                local cn = name
                btn:SetScript("OnClick", function() LoadNoteInEditor(cn) end)
                listRows[#listRows+1] = {btn=btn, sel=selTex, accent=accentTex, lbl=lbl}
                totalH = totalH + ROW_H + ROW_GAP
            end
        end

        if not hasVisible and not listChild._emptyLbl then
            listChild._emptyLbl = listChild:CreateFontString(nil, "OVERLAY")
            listChild._emptyLbl:SetFont("Fonts\\ARIALN.TTF", 12, "")
            listChild._emptyLbl:SetPoint("TOPLEFT", listChild, "TOPLEFT", 8, -10)
            listChild._emptyLbl:SetTextColor(0.35, 0.35, 0.40, 1)
            listChild._emptyLbl:SetText(SM.T("rem_list_empty"))
        end
        if listChild._emptyLbl then
            listChild._emptyLbl:SetShown(not hasVisible)
        end

        listChild:SetHeight(math.max(totalH, 1))
        local sh = listScroll:GetHeight()
        local maxScroll = sh > 0 and math.max(0, totalH - sh) or 0
        listScrollBar:SetMinMaxValues(0, maxScroll)
        if listScrollBar:GetValue() > maxScroll then listScrollBar:SetValue(maxScroll) end
        if filterDrop then filterDrop.RefreshVisible(bossesWithNotes) end
    end

    -- ══════════════════════════════════════════════════════════
    -- SWITCH SOUS-ONGLETS
    -- ══════════════════════════════════════════════════════════
    local function activateSharedMode()
        currentMode = "shared"
        selName = nil; rNoSelLbl:Show()
        noteEditor:SetText(""); noteNameInput:SetText("")
        sharedStab._bg:SetColorTexture(SM.OR[1]*0.13, SM.OR[2]*0.13, SM.OR[3]*0.18, 1)
        sharedStab._lbl:SetTextColor(1, 1, 1, 1); sharedStab._accent:Show()
        personalStab._bg:SetColorTexture(0.06, 0.05, 0.09, 1)
        personalStab._lbl:SetTextColor(0.48, 0.48, 0.55, 1); personalStab._accent:Hide()
        -- test/stop visibles uniquement pour les notes partagées (liées aux boss encounters)
        testBtn:Show(); stopBtn:Show()
        RefreshList()
    end

    local function activatePersonalMode()
        currentMode = "personal"
        selName = nil; rNoSelLbl:Show()
        noteEditor:SetText(""); noteNameInput:SetText("")
        personalStab._bg:SetColorTexture(SM.OR[1]*0.13, SM.OR[2]*0.13, SM.OR[3]*0.18, 1)
        personalStab._lbl:SetTextColor(1, 1, 1, 1); personalStab._accent:Show()
        sharedStab._bg:SetColorTexture(0.06, 0.05, 0.09, 1)
        sharedStab._lbl:SetTextColor(0.48, 0.48, 0.55, 1); sharedStab._accent:Hide()
        testBtn:Hide(); stopBtn:Hide()
        RefreshList()
    end

    sharedStab:SetScript("OnClick",   activateSharedMode)
    personalStab:SetScript("OnClick", activatePersonalMode)

    -- ══════════════════════════════════════════════════════════
    -- HANDLERS BOUTONS
    -- ══════════════════════════════════════════════════════════
    importBtn:SetScript("OnClick", function() importOverlay:Show() end)

    unloadBtn:SetScript("OnClick", function()
        if currentMode == "shared" and SolaryMDB then
            SolaryMDB.active_reminder = nil
        end
        RefreshList()
    end)

    delAllBtn:SetScript("OnClick", function()
        if not SolaryMDB then return end
        local rem = getReminders()
        local count = 0
        for _ in pairs(rem) do count = count + 1 end
        if count == 0 then return end
        ConfirmDel(SM.T("rem_confirm_del_all_fmt"):format(count), function()
            if currentMode == "shared" then
                SolaryMDB.reminders      = {}
                SolaryMDB.reminders_meta = {}
            else
                SolaryMDB.personal_reminders      = {}
                SolaryMDB.personal_reminders_meta = {}
            end
            selName = nil
            noteEditor:SetText(""); noteNameInput:SetText(""); rNoSelLbl:Show()
            RefreshList()
        end)
    end)

    newNoteBtn:SetScript("OnClick", function()
        local noteName = (noteNameInput and noteNameInput:GetText() ~= "")
            and noteNameInput:GetText() or "Nouvelle note"
        if currentMode == "shared" then
            if not RN then return end
            local finalName = RN.Import(noteName, "")
            local meta = getMeta(finalName)
            if bossDrop then meta.boss = bossDrop.GetValue() end
            if diffDrop then meta.diff = diffDrop.GetValue() end
            selName = finalName
            RefreshList(); LoadNoteInEditor(finalName); noteEditor:SetFocus()
        else
            if not SolaryMDB then return end
            local rem = getReminders()
            local finalName = noteName
            local i = 2
            while rem[finalName] do finalName = noteName.."_"..i; i = i + 1 end
            rem[finalName] = ""
            local meta = getMeta(finalName)
            if bossDrop then meta.boss = bossDrop.GetValue() end
            if diffDrop then meta.diff = diffDrop.GetValue() end
            selName = finalName
            RefreshList(); LoadNoteInEditor(finalName); noteEditor:SetFocus()
        end
    end)

    loadSendBtn:SetScript("OnClick", function()
        if not selName or not RN then return end
        if SolaryMDB then
            SolaryMDB.reminders = SolaryMDB.reminders or {}
            SolaryMDB.reminders[selName] = noteEditor:GetText()
        end
        RN.SetActive(selName); RN.BroadcastNote(); RefreshList()
    end)

    saveBtn2:SetScript("OnClick", function()
        if not selName or not SolaryMDB then return end
        local rem = getReminders()
        rem[selName] = noteEditor:GetText()
        local meta = getMeta(selName)
        if bossDrop then meta.boss = bossDrop.GetValue() end
        if diffDrop then meta.diff = diffDrop.GetValue() end
    end)

    delBtn2:SetScript("OnClick", function()
        if not selName then return end
        local n = selName
        ConfirmDel(SM.T("rem_confirm_del_note"):format(n), function()
            if currentMode == "shared" then
                if RN then RN.Delete(n) end
            else
                if SolaryMDB then
                    if SolaryMDB.personal_reminders then
                        SolaryMDB.personal_reminders[n] = nil
                    end
                    if SolaryMDB.personal_reminders_meta then
                        SolaryMDB.personal_reminders_meta[n] = nil
                    end
                end
            end
            selName = nil
            noteEditor:SetText(""); noteNameInput:SetText(""); rNoSelLbl:Show()
            RefreshList()
        end)
    end)

    showBtn:SetScript("OnClick", function()
        if not RN then return end
        if currentMode == "personal" then
            if selName then
                if SolaryMDB then
                    SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
                    SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
                end
                if RN.SetPersonalActive then RN.SetPersonalActive(selName) end
            end
            if RN.TogglePersonalNote then RN.TogglePersonalNote() end
        else
            RN.ToggleNote()
        end
    end)

    testBtn:SetScript("OnClick", function()
        if not RN or currentMode == "personal" then return end
        local ids = RN.GetEncounterIDs and RN.GetEncounterIDs() or {}
        local id  = ids[1] and tostring(ids[1]) or ""
        if id ~= "" then RN.TestEncounter(id) end
        if SM.Notes and SM.Notes.TestGlow then SM.Notes.TestGlow() end
    end)

    stopBtn:SetScript("OnClick", function()
        if not RN or currentMode == "personal" then return end
        RN.StopTest()
        if SM.Notes and SM.Notes.StopGlows then SM.Notes.StopGlows() end
    end)

    impConfirmBtn:SetScript("OnClick", function()
        local name    = SM.GetVal(impNameInput)
        local content = impPasteBox:GetText()
        if name == "" or content == "" then return end
        if currentMode == "shared" then
            if not RN then return end
            local finalName = RN.Import(name, content)
            SM.SetVal(impNameInput, ""); impPasteBox:SetText("")
            importOverlay:Hide(); LoadNoteInEditor(finalName)
        else
            if not SolaryMDB then return end
            local rem = getReminders()
            local finalName = name
            local i = 2
            while rem[finalName] do finalName = name.."_"..i; i = i + 1 end
            rem[finalName] = content
            SM.SetVal(impNameInput, ""); impPasteBox:SetText("")
            importOverlay:Hide(); LoadNoteInEditor(finalName)
        end
    end)

    f._refreshList = RefreshList
    f:SetScript("OnShow", activateSharedMode)

    SM.RefreshNotesPanel = function()
        if not f:IsShown() then return end
        RefreshList()
        if currentMode == "shared" then
            local recv = RN and RN.GetLastReceived and RN.GetLastReceived()
            if recv and selName == recv and SolaryMDB and SolaryMDB.reminders then
                noteEditor:SetText(SolaryMDB.reminders[recv] or "")
            end
        end
    end

    activateSharedMode()
    return f
end


-- ============================================================
-- FENÊTRE PRIVATE AURA SOUNDS
-- ============================================================
local paSoundsWindow = nil


local function Build()
    if mainFrame then return end

    -- ─── Frame principale (sans template) ─────────────────────
    mainFrame = CreateFrame("Frame","SolaryMPanel",UIParent)
    mainFrame:SetSize(TOTAL_W, PANEL_H)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true); mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")

    local _dOffX, _dOffY = 0, 0
    local function _StartDrag()
        local cx, cy = GetCursorPosition()
        local sc = mainFrame:GetEffectiveScale()
        _dOffX = mainFrame:GetLeft() - cx / sc
        _dOffY = mainFrame:GetTop()  - cy / sc
        mainFrame:SetScript("OnUpdate", function(mf)
            local mx, my = GetCursorPosition()
            local s = mf:GetEffectiveScale()
            mf:ClearAllPoints()
            mf:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", _dOffX + mx/s, _dOffY + my/s)
        end)
    end
    local function _StopDrag()
        mainFrame:SetScript("OnUpdate", nil)
    end

    mainFrame:SetScript("OnDragStart", _StartDrag)
    mainFrame:SetScript("OnDragStop",  _StopDrag)
    mainFrame:SetFrameStrata("DIALOG")

    -- Fond principal
    local mainBg = mainFrame:CreateTexture(nil,"BACKGROUND")
    mainBg:SetAllPoints()
    mainBg:SetColorTexture(0.07, 0.06, 0.10, 1)

    -- Bordure 1px
    local bT = mainFrame:CreateTexture(nil,"BORDER")
    bT:SetPoint("TOPLEFT"); bT:SetPoint("TOPRIGHT"); bT:SetHeight(1)
    bT:SetColorTexture(0.22, 0.16, 0.32, 1)
    local bB = mainFrame:CreateTexture(nil,"BORDER")
    bB:SetPoint("BOTTOMLEFT"); bB:SetPoint("BOTTOMRIGHT"); bB:SetHeight(1)
    bB:SetColorTexture(0.22, 0.16, 0.32, 1)
    local bL = mainFrame:CreateTexture(nil,"BORDER")
    bL:SetPoint("TOPLEFT"); bL:SetPoint("BOTTOMLEFT"); bL:SetWidth(1)
    bL:SetColorTexture(0.22, 0.16, 0.32, 1)
    local bR = mainFrame:CreateTexture(nil,"BORDER")
    bR:SetPoint("TOPRIGHT"); bR:SetPoint("BOTTOMRIGHT"); bR:SetWidth(1)
    bR:SetColorTexture(0.22, 0.16, 0.32, 1)

    -- ─── Header ───────────────────────────────────────────────
    local header = CreateFrame("Frame", nil, mainFrame)
    header:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", _StartDrag)
    header:SetScript("OnDragStop",  _StopDrag)

    local headerBg = header:CreateTexture(nil,"BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.04, 0.04, 0.08, 1)

    -- Ligne séparatrice sous le header
    local headerLine = mainFrame:CreateTexture(nil,"ARTWORK")
    headerLine:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  0, -HEADER_H)
    headerLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, -HEADER_H)
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.35)

    -- Icône logo dans le header
    local logoIcon = header:CreateTexture(nil,"OVERLAY")
    logoIcon:SetSize(44, 44)
    logoIcon:SetPoint("LEFT", header, "LEFT", 10, 0)
    logoIcon:SetTexture("Interface\\AddOns\\SolaryM\\Media\\solary_icon.png")

    -- SOLARYM + sous-titre dans le header
    local logoText = header:CreateFontString(nil,"OVERLAY")
    logoText:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    logoText:SetPoint("LEFT", header, "LEFT", 62, 8)
    logoText:SetTextColor(0.72, 0.55, 0.95, 1)
    logoText:SetText("SOLARY|cFFDD88FFM|r")

    local subText = header:CreateFontString(nil,"OVERLAY")
    subText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    subText:SetPoint("LEFT", header, "LEFT", 64, -11)
    subText:SetTextColor(0.52, 0.42, 0.68, 1)
    subText:SetText("Mythic Tools")

    -- Bouton langue FR/EN
    local langBtn = CreateFrame("Button", nil, header)
    langBtn:SetSize(38, 20)
    langBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -46, -10)
    local langBg = langBtn:CreateTexture(nil,"BACKGROUND")
    langBg:SetAllPoints(); langBg:SetColorTexture(0.10, 0.11, 0.18, 1)
    local langBdr = langBtn:CreateTexture(nil,"BORDER")
    langBdr:SetAllPoints(); langBdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.40)
    local langLbl = langBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    langLbl:SetPoint("CENTER"); langLbl:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
    langLbl:SetText(SM.LANG == "fr" and "FR" or "EN")
    langBtn:SetScript("OnClick", function()
        SM.SetLang(SM.LANG == "fr" and "en" or "fr")
        local point, _, relPoint, x, y = mainFrame:GetPoint()
        local prevTab = activeTab
        mainFrame:Hide()
        mainFrame = nil
        wipe(tabBtns)
        wipe(tabFrames)
        Build()
        if point then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint(point, UIParent, relPoint, x, y)
        end
        ShowTab(prevTab <= #tabFrames and prevTab or 1)
        if SM.IsEditor() and prevTab == 1 then SM.RefreshSpellList() end
        mainFrame:Show()
        tinsert(UISpecialFrames, "SolaryMPanel")
    end)
    langBtn:SetScript("OnEnter", function() langBdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1) end)
    langBtn:SetScript("OnLeave", function() langBdr:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.40) end)

    -- Bouton fermer
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -8)
    local closeBg = closeBtn:CreateTexture(nil,"BACKGROUND")
    closeBg:SetAllPoints(); closeBg:SetColorTexture(0.32, 0.07, 0.07, 0.85)
    local closeLbl = closeBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    closeLbl:SetPoint("CENTER"); closeLbl:SetTextColor(0.90, 0.90, 0.90, 1)
    closeLbl:SetText("\195\151")
    closeBtn:SetScript("OnClick",  function() mainFrame:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.65, 0.12, 0.12, 1) end)
    closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0.32, 0.07, 0.07, 0.85) end)

    -- ─── Sidebar gauche ──────────────────────────────────────
    local sidebar = CreateFrame("Frame", nil, mainFrame)
    sidebar:SetPoint("TOPLEFT",    mainFrame, "TOPLEFT",    0, -HEADER_H)
    sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0,  0)
    sidebar:SetWidth(SIDEBAR_W)

    local sidebarBg = sidebar:CreateTexture(nil,"BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0.05, 0.05, 0.09, 1)

    -- Ligne de séparation sidebar / contenu
    local sideDiv = mainFrame:CreateTexture(nil,"ARTWORK")
    sideDiv:SetPoint("TOPLEFT",    mainFrame, "TOPLEFT",    SIDEBAR_W, -HEADER_H)
    sideDiv:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", SIDEBAR_W,  0)
    sideDiv:SetWidth(1)
    sideDiv:SetColorTexture(0.20, 0.14, 0.28, 1)

    -- Version en bas de la sidebar
    local sideVer = sidebar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    sideVer:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 10)
    sideVer:SetTextColor(0.38, 0.34, 0.50, 1)
    sideVer:SetText("v"..SM.VERSION)

    -- ─── Onglets verticaux ────────────────────────────────────
    local tabNames
    if SM.IsEditor() then
        tabNames = {SM.T("tab_spells"),SM.T("tab_smartcast"),SM.T("tab_invites"),SM.T("tab_memory"),SM.T("tab_versions"),SM.T("tab_settings"),SM.T("tab_changelogs"),SM.T("tab_reminders")}
    else
        tabNames = {SM.T("tab_smartcast"),SM.T("tab_settings"),SM.T("tab_changelogs"),SM.T("tab_reminders")}
    end
    local TAB_BTN_H = 40
    local TAB_BTN_W = SIDEBAR_W

    local function MakeSideTab(idx, name, yOff)
        local tb = CreateFrame("Button", nil, sidebar)
        tb:SetSize(TAB_BTN_W, TAB_BTN_H)
        tb:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, yOff)

        local bg = tb:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0)
        tb._bg = bg

        local accent = tb:CreateTexture(nil,"ARTWORK")
        accent:SetSize(2, TAB_BTN_H - 4)
        accent:SetPoint("LEFT", tb, "LEFT", 0, 0)
        accent:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        accent:Hide()
        tb._accent = accent

        local lbl = tb:CreateFontString(nil,"OVERLAY","GameFontNormal")
        lbl:SetPoint("LEFT", tb, "LEFT", 18, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(0.55, 0.55, 0.58, 1)
        lbl:SetText(name)
        tb._lbl = lbl

        tb:SetScript("OnEnter", function(s)
            if activeTab ~= idx then
                s._bg:SetColorTexture(0.10, 0.07, 0.16, 1)
                s._lbl:SetTextColor(0.82, 0.75, 0.95, 1)
            end
        end)
        tb:SetScript("OnLeave", function(s)
            if activeTab ~= idx then
                s._bg:SetColorTexture(0, 0, 0, 0)
                s._lbl:SetTextColor(0.55, 0.50, 0.62, 1)
            end
        end)

        local i = idx
        tb:SetScript("OnClick", function() ShowTab(i) end)
        table.insert(tabBtns, tb)
    end

    local startY = -8
    for i, name in ipairs(tabNames) do
        MakeSideTab(i, name, startY - (i-1) * (TAB_BTN_H + 1))
    end

    -- ─── Contenu des onglets ─────────────────────────────────
    if SM.IsEditor() then
        tabFrames[1] = BuildSpellsTab(mainFrame)
        SM._spellTabFrame = tabFrames[1]
        tabFrames[2] = BuildBossTimerTab(mainFrame)
        tabFrames[3] = BuildInviteTab(mainFrame)
        tabFrames[4] = BuildMemoryTab(mainFrame)
        tabFrames[5] = BuildVersionTab(mainFrame)
        tabFrames[6] = BuildSettingsTab(mainFrame)
        tabFrames[7] = BuildChangelogsTab(mainFrame)
        tabFrames[8] = BuildRemindersTab(mainFrame)
    else
        tabFrames[1] = BuildBossTimerTab(mainFrame)
        tabFrames[2] = BuildSettingsTab(mainFrame)
        tabFrames[3] = BuildChangelogsTab(mainFrame)
        tabFrames[4] = BuildRemindersTab(mainFrame)
    end
    mainFrame:EnableKeyboard(true)
    mainFrame:SetPropagateKeyboardInput(true)
    mainFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    mainFrame:Hide()
end

-- Une seule insertion dans UISpecialFrames — permet Échap pour fermer
tinsert(UISpecialFrames, "SolaryMPanel")

function SM.TogglePanel()
    Build()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        SolaryMDB=SolaryMDB or {}
        if SM.IsEditor() then
            ShowTab(1)
            SM.RefreshSpellList()
        else
            ShowTab(1)  -- Boss Timers est tab 1 pour non-éditeurs
        end
        mainFrame:Show()
    end
end

-- SM.OpenPanel = alias pour SM.TogglePanel (appelé par Core)
-- Met à jour le label "N changements en attente" dans l'onglet Spells
function SM._UpdatePendingCount()
    local f = SM._spellTabFrame
    if not f or not f._pendingLbl then return end
    local n = 0
    for _ in pairs(SM.PendingSpellChanges) do n = n + 1 end
    if n == 0 then
        f._pendingLbl:SetText(SM.T("pending_none"))
        f._pendingLbl:SetTextColor(0.5, 0.5, 0.5, 1)
    elseif n == 1 then
        f._pendingLbl:SetText("|cFFFFAA00"..SM.T("pending_one").."|r — "..SM.T("pending_ready"))
        f._pendingLbl:SetTextColor(1, 0.82, 0, 1)
    else
        f._pendingLbl:SetText("|cFFFFAA00"..n.." "..SM.T("pending_multi").."|r — "..SM.T("pending_ready_pl"))
        f._pendingLbl:SetTextColor(1, 0.82, 0, 1)
    end
end

SM.OpenPanel = SM.TogglePanel


-- ============================================================
-- ONGLET CHANGELOGS
-- ============================================================

function SM.OpenPASoundsWindow()
    if paSoundsWindow then
        if paSoundsWindow:IsShown() then paSoundsWindow:Hide() else paSoundsWindow:Show() end
        return
    end

    local W, H = 500, 560
    paSoundsWindow = CreateFrame("Frame", "SolaryMPASoundsWindow", UIParent, "BackdropTemplate")
    paSoundsWindow:SetSize(W, H)
    paSoundsWindow:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    paSoundsWindow:SetFrameStrata("DIALOG")
    paSoundsWindow:SetMovable(true)
    paSoundsWindow:EnableMouse(true)
    paSoundsWindow:RegisterForDrag("LeftButton")
    paSoundsWindow:SetScript("OnDragStart", paSoundsWindow.StartMoving)
    paSoundsWindow:SetScript("OnDragStop", paSoundsWindow.StopMovingOrSizing)
    paSoundsWindow:SetBackdrop({bgFile="Interface\Buttons\WHITE8X8", edgeFile="Interface\Buttons\WHITE8X8", edgeSize=1})
    paSoundsWindow:SetBackdropColor(0.06,0.06,0.09,0.98)
    paSoundsWindow:SetBackdropBorderColor(SM.OR[1],SM.OR[2],SM.OR[3],0.5)

    -- Titre
    local title = paSoundsWindow:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP",paSoundsWindow,"TOP",0,-10)
    title:SetTextColor(SM.OR[1],SM.OR[2],SM.OR[3],1)
    title:SetText("Sons Private Auras")

    -- Bouton fermer
    SM.RBtn(paSoundsWindow,60,22,SM.T("btn_close"),function() paSoundsWindow:Hide() end):SetPoint("TOPRIGHT",paSoundsWindow,"TOPRIGHT",-8,-6)

    -- Background complet (titre + liste + barre ajout)
    local fullBg=paSoundsWindow:CreateTexture(nil,"BACKGROUND")
    fullBg:SetPoint("TOPLEFT",paSoundsWindow,"TOPLEFT",1,-1)
    fullBg:SetPoint("BOTTOMRIGHT",paSoundsWindow,"BOTTOMRIGHT",-1,1)
    fullBg:SetColorTexture(0.06,0.06,0.09,1)

    -- Background zone liste (légèrement différent)
    local listBg=paSoundsWindow:CreateTexture(nil,"BACKGROUND")
    listBg:SetPoint("TOPLEFT",paSoundsWindow,"TOPLEFT",8,-28)
    listBg:SetPoint("BOTTOMRIGHT",paSoundsWindow,"BOTTOMRIGHT",-8,88)
    listBg:SetColorTexture(0.04,0.04,0.07,1)

    -- Headers
    local function Hdr(txt,x)
        local h=paSoundsWindow:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        h:SetPoint("TOPLEFT",paSoundsWindow,"TOPLEFT",x,-32)
        h:SetTextColor(0.35,0.35,0.4,1); h:SetText(txt)
    end
    Hdr(SM.T("col_spell"),12); Hdr("SPELLID",230); Hdr(SM.T("col_sound"),310)

    local sep=paSoundsWindow:CreateTexture(nil,"ARTWORK"); sep:SetSize(W-16,1)
    sep:SetPoint("TOPLEFT",paSoundsWindow,"TOPLEFT",8,-44)
    sep:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.3)

    -- Scroll list
    local scroll=CreateFrame("ScrollFrame",nil,paSoundsWindow,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",paSoundsWindow,"TOPLEFT",8,-50)
    scroll:SetPoint("BOTTOMRIGHT",paSoundsWindow,"BOTTOMRIGHT",-28,90)
    local scrollContent=CreateFrame("Frame",nil,scroll)
    scrollContent:SetSize(W-36,1)
    scroll:SetScrollChild(scrollContent)

    local function MakeDropdown(parent, x, y, w, getVal, onSelect)
        local btn=CreateFrame("Button",nil,parent)
        btn:SetSize(w,22); btn:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
        local bg=btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.1,0.1,0.14,1)
        local bdr=btn:CreateTexture(nil,"BORDER"); bdr:SetAllPoints(); bdr:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2)
        local lbl=btn:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        lbl:SetPoint("LEFT",btn,"LEFT",6,0); lbl:SetText(getVal()); lbl:SetTextColor(0.9,0.9,0.9,1)
        local arr=btn:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
        arr:SetPoint("RIGHT",btn,"RIGHT",-4,0); arr:SetText("v")

        local menu=CreateFrame("Frame",nil,paSoundsWindow); menu:SetFrameStrata("TOOLTIP")
        menu:SetSize(w,22); menu:SetPoint("TOPLEFT",btn,"BOTTOMLEFT",0,-2)
        local mbg=menu:CreateTexture(nil,"BACKGROUND"); mbg:SetAllPoints(); mbg:SetColorTexture(0.06,0.06,0.09,0.98)
        menu:Hide()

        btn:SetScript("OnClick",function()
            if menu:IsShown() then menu:Hide(); return end
            for _,c in ipairs({menu:GetChildren()}) do c:Hide() end
            local sounds={"(aucun)"}
            for _, s in ipairs(SM.MediaSounds or {}) do table.insert(sounds, s) end
            menu:SetHeight(#sounds*22)
            for i,sname in ipairs(sounds) do
                local item=CreateFrame("Button",nil,menu)
                item:SetSize(w,22); item:SetPoint("TOPLEFT",menu,"TOPLEFT",0,-(i-1)*22)
                local ibg=item:CreateTexture(nil,"BACKGROUND"); ibg:SetAllPoints(); ibg:SetColorTexture(0,0,0,0)
                local ilbl=item:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                ilbl:SetPoint("LEFT",item,"LEFT",6,0); ilbl:SetText(sname); ilbl:SetTextColor(0.85,0.85,0.9,1)
                item:SetScript("OnEnter",function() ibg:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.2) end)
                item:SetScript("OnLeave",function() ibg:SetColorTexture(0,0,0,0) end)
                local sn=sname
                item:SetScript("OnClick",function() lbl:SetText(sn); onSelect(sn); menu:Hide() end)
            end
            menu:Show()
        end)
        return btn, lbl
    end

    local function RefreshList()
        for _,c in ipairs({scrollContent:GetChildren()}) do c:Hide() end
        SolaryMDB.pa_sounds = SolaryMDB.pa_sounds or {}

        -- Construire liste combinée : defaults + custom
        local rows = {}
        if SolaryMDB.pa_use_defaults ~= false then
            for id, snd in pairs(SM.PA_DEFAULTS_RAID) do
                local custom = SolaryMDB.pa_sounds[id]
                rows[id] = {sound=custom or snd, isDefault=(custom==nil), isCustom=(custom~=nil)}
            end
        end
        for id, snd in pairs(SolaryMDB.pa_sounds) do
            if not rows[id] then rows[id]={sound=snd, isDefault=false, isCustom=true} end
        end

        -- Trier par nom de sort
        local sorted = {}
        for id, info in pairs(rows) do
            local si = C_Spell.GetSpellInfo(id)
            table.insert(sorted, {id=id, name=(si and si.name or "SpellID "..id), sound=info.sound, isDefault=info.isDefault, isCustom=info.isCustom})
        end
        table.sort(sorted, function(a,b) return a.name < b.name end)

        local ry = 0
        local ROW_H = 26
        for i, entry in ipairs(sorted) do
            local row=CreateFrame("Frame",nil,scrollContent)
            row:SetSize(W-36,ROW_H); row:SetPoint("TOPLEFT",scrollContent,"TOPLEFT",0,-ry)
            local rb=row:CreateTexture(nil,"BACKGROUND"); rb:SetAllPoints()
            if i%2==0 then rb:SetColorTexture(0.09,0.09,0.12,1) else rb:SetColorTexture(0.06,0.06,0.09,1) end

            -- Nom du sort
            local nl=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            nl:SetPoint("LEFT",row,"LEFT",4,0); nl:SetWidth(218)
            nl:SetJustifyH("LEFT")
            -- Truncate name to avoid overflow
            local dispName = entry.name
            nl:SetText(dispName)
            nl:SetTextColor(entry.isDefault and 0.5 or 0.9, entry.isDefault and 0.5 or 0.9, entry.isDefault and 0.55 or 0.9, 1)

            -- SpellID
            local il=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            il:SetPoint("LEFT",row,"LEFT",222,0)
            il:SetText(tostring(entry.id)); il:SetTextColor(0.35,0.35,0.4,1)

            -- Dropdown son
            local eid = entry.id
            local _, sndLbl = MakeDropdown(row, 300, -2, 130, function() return entry.sound end, function(sn)
                SolaryMDB.pa_sounds[eid] = sn
                SM.RegisterPASound(eid, sn)
                RefreshList()
            end)
            sndLbl:SetText(entry.sound)

            -- Bouton supprimer (custom seulement)
            if entry.isCustom or not entry.isDefault then
                SM.RBtn(row,22,20,"x",function()
                    SolaryMDB.pa_sounds[eid]=nil
                    SM.RegisterPASound(eid,nil)
                    RefreshList()
                end):SetPoint("RIGHT",row,"RIGHT",-2,0)
            end

            ry = ry + ROW_H
        end

        if #sorted == 0 then
            local el=scrollContent:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            el:SetPoint("TOPLEFT",scrollContent,"TOPLEFT",4,0)
            el:SetTextColor(0.4,0.4,0.45,1); el:SetText(SM.T("pa_empty"))
        end

        scrollContent:SetHeight(math.max(ry,22))
    end

    -- Barre d'ajout — ancrée en bas de la fenêtre
    local addBar=CreateFrame("Frame",nil,paSoundsWindow)
    addBar:SetSize(W-16,32); addBar:SetPoint("BOTTOMLEFT",paSoundsWindow,"BOTTOMLEFT",8,52)

    local addId=SM.Input(addBar,90,24,"SpellID")
    addId:SetPoint("LEFT",addBar,"LEFT",0,0)

    local addSndSel = (SM.MediaSounds and SM.MediaSounds[1]) or "Soak"
    local _, addSndLbl = MakeDropdown(addBar, 96, -3, 150, function() return addSndSel end, function(sn)
        addSndSel = sn
    end)

    SM.GBtn(addBar,60,24,"Add",function()
        local id=tonumber(SM.GetVal(addId))
        if not id then SM.Print(SM.T("invalid_spellid")); return end
        SolaryMDB.pa_sounds=SolaryMDB.pa_sounds or {}
        SolaryMDB.pa_sounds[id]=addSndSel
        SM.RegisterPASound(id,addSndSel)
        SM.SetVal(addId,"")
        RefreshList()
    end):SetPoint("LEFT",addBar,"LEFT",252,0)

    SM.RBtn(addBar,100,24,SM.T("btn_delete_all"),function()
        SolaryMDB.pa_sounds={}
        SM.PASoundIDs={}
        RefreshList()
    end):SetPoint("RIGHT",addBar,"RIGHT",-4,0)

    local sep2=paSoundsWindow:CreateTexture(nil,"ARTWORK"); sep2:SetSize(W-16,1)
    sep2:SetPoint("BOTTOMLEFT",paSoundsWindow,"BOTTOMLEFT",8,86)
    sep2:SetColorTexture(SM.OR[1],SM.OR[2],SM.OR[3],0.3)

    RefreshList()
    paSoundsWindow:Show()
end
