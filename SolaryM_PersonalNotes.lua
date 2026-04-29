-- SolaryM_PersonalNotes.lua
-- Notes personnelles avec filtre boss/diff, identiques aux notes partagées
-- mais sans diffusion. Stockage : SolaryMDB.personal_reminders (hash name→text)
-- et SolaryMDB.personal_reminders_meta (hash name→{boss,diff})

SM.PersonalNotes = SM.PersonalNotes or {}
local PN = SM.PersonalNotes

function PN.BuildTab(parent, W, H)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(W, H)
    f:Hide()

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

    -- ── Constantes layout ──────────────────────────────────────
    local LEFT_W   = 280
    local lPAD     = 10
    local L_ROW_H  = 30
    local L_ROW_GAP = 2
    local L_HDR_H  = 22
    local L_BTN_H  = 24
    local L_DROP_H = 26
    local R_TBAR_H = 28
    local R_BBAR_H = 32
    local R_PAD    = 10
    local lScrollW = LEFT_W - lPAD * 2 - 14

    -- ── State ──────────────────────────────────────────────────
    local selName    = nil
    local listRows   = {}
    local filterBoss = nil
    local filterDrop
    local noteEditor, noteNameInput, bossDrop, diffDrop, pNoSelLbl
    local listScroll, listScrollBar, listChild

    -- ── Data helpers ───────────────────────────────────────────
    local function getReminders()
        if not SolaryMDB then return {} end
        SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
        return SolaryMDB.personal_reminders
    end

    local function getMeta(name)
        if not SolaryMDB then return {} end
        SolaryMDB.personal_reminders_meta = SolaryMDB.personal_reminders_meta or {}
        SolaryMDB.personal_reminders_meta[name] = SolaryMDB.personal_reminders_meta[name] or {}
        return SolaryMDB.personal_reminders_meta[name]
    end

    local function getNoteNames()
        local rem   = getReminders()
        local names = {}
        for k in pairs(rem) do names[#names+1] = k end
        table.sort(names)
        return names
    end

    -- ── EJ icon cache ──────────────────────────────────────────
    local ejIconCache = {}
    do
        local targets = {[3134]=true,[3135]=true,[3176]=true,[3177]=true,[3178]=true,
                         [3179]=true,[3180]=true,[3181]=true,[3182]=true,[3183]=true,[3306]=true}
        local found = 0
        for jID = 1, 4000 do
            if found >= 11 then break end
            local name, _, _, _, _, _, dungeonEncID = EJ_GetEncounterInfo(jID)
            if name and dungeonEncID and targets[dungeonEncID] then
                local _, _, _, _, icon = EJ_GetCreatureInfo(1, jID)
                ejIconCache[dungeonEncID] = icon or false
                found = found + 1
            end
        end
    end

    -- ── Boss / Diff lists ──────────────────────────────────────
    local BOSS_LIST = {
        {text=SM.T("rem_boss_none"),         value=nil},
        {text="-- The Voidspire --",         value=nil, isHeader=true},
        {text="Imperator Averzian",          value=3176},
        {text="Vorasius",                    value=3177},
        {text="Vaelgor & Ezzorak",           value=3178},
        {text="Fallen King Salhadaar",       value=3179},
        {text="Lightblinded Vanguard",       value=3180},
        {text="Crown of the Cosmos",         value=3181},
        {text="-- March on Quel'Danas --",   value=nil, isHeader=true},
        {text="Belo'ren",                    value=3182},
        {text="Midnight Falls",              value=3183},
        {text="-- The Dreamrift --",         value=nil, isHeader=true},
        {text="Chimaerus",                   value=3306},
    }
    local DIFF_LIST = {
        {text="Normal",                  value="normal"},
        {text=SM.T("rem_diff_heroic"),   value="heroic"},
        {text=SM.T("rem_diff_mythic"),   value="mythic"},
    }

    -- ── MakeDrop ───────────────────────────────────────────────
    local function MakeDrop(par, w, h, items, onSelect)
        local btn = CreateFrame("Button", nil, par)
        btn:SetSize(w, h)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.09, 1)

        local btnIcon = btn:CreateTexture(nil, "ARTWORK")
        btnIcon:SetSize(h - 6, h - 6)
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

        local popup = CreateFrame("Frame", nil, f, "BackdropTemplate")
        popup:SetWidth(w)
        popup:SetFrameLevel(f:GetFrameLevel() + 60)
        popup:SetBackdrop({
            bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 32,
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        })
        popup:SetBackdropColor(0.07, 0.07, 0.11, 0.98)
        popup:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.28)
        popup:Hide()
        btn._popup = popup

        local selValue = nil
        local rowBtns  = {}

        local function getEncIcon(encID)
            if type(encID) ~= "number" then return nil end
            local v = ejIconCache[encID]
            return v or nil
        end

        local function applyBtnIcon(iconImg)
            lbl:ClearAllPoints()
            if iconImg then
                btnIcon:SetTexture(iconImg); btnIcon:Show()
                lbl:SetPoint("LEFT", btnIcon, "RIGHT", 4, 0)
            else
                btnIcon:Hide()
                lbl:SetPoint("LEFT", btn, "LEFT", 8, 0)
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
            rb:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -(totalPopH + 1))
            rb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -(totalPopH + 1))
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
            rbLbl:SetTextColor(
                item.isHeader and 0.45 or 0.80,
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
                    rb:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -(totalH + 1))
                    rb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -(totalH + 1))
                    totalH = totalH + rb:GetHeight()
                else
                    rb:Hide()
                end
            end
            popup:SetHeight(totalH + 2)
        end
        return btn
    end

    -- ── LoadNoteInEditor ───────────────────────────────────────
    local function LoadNoteInEditor(name)
        selName = name
        if not name then
            noteEditor:SetText("")
            noteNameInput:SetText("")
            pNoSelLbl:Show()
            return
        end
        pNoSelLbl:Hide()
        noteNameInput:SetText(name)
        noteNameInput:SetTextColor(1, 1, 1, 1)
        local rem     = getReminders()
        local content = rem[name] or ""
        noteEditor:SetText(content)
        local meta = getMeta(name)
        bossDrop.SetByID(meta.boss)
        diffDrop.SetByID(meta.diff)
    end

    -- ── RefreshList ────────────────────────────────────────────
    local function RefreshList()
        for _, ro in ipairs(listRows) do ro.btn:Hide() end
        listRows = {}

        local names    = getNoteNames()
        local totalH   = 0
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
                btn:SetSize(lScrollW, L_ROW_H)
                btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -totalH)

                btn:SetHighlightTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
                local hlt = btn:GetHighlightTexture()
                if hlt then hlt:SetBlendMode("ADD"); hlt:SetAlpha(0.22) end

                local isSel = (name == selName)

                local sel = btn:CreateTexture(nil, "BACKGROUND")
                sel:SetPoint("LEFT",   btn, "LEFT",   2, 0)
                sel:SetPoint("RIGHT",  btn, "RIGHT",  0, 0)
                sel:SetPoint("TOP",    btn, "TOP",    0, 0)
                sel:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
                sel:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.15)
                sel:SetAlpha(isSel and 1 or 0)

                local accent = btn:CreateTexture(nil, "ARTWORK")
                accent:SetWidth(2)
                accent:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
                accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
                accent:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 1)
                if isSel then accent:Show() else accent:Hide() end

                -- Icône rename (côté droit)
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
                lbl:SetPoint("LEFT",  btn,     "LEFT",  10, 0)
                lbl:SetPoint("RIGHT", editBtn, "LEFT",  -2, 0)
                lbl:SetJustifyH("LEFT"); lbl:SetJustifyV("MIDDLE")
                lbl:SetText(name)
                lbl:SetTextColor(
                    isSel and SM.OR[1] or 0.85,
                    isSel and SM.OR[2] or 0.85,
                    isSel and SM.OR[3] or 0.88, 1)

                -- EditBox inline pour renommer
                local renameBox = CreateFrame("EditBox", nil, btn, "InputBoxTemplate")
                renameBox:SetPoint("LEFT",  btn,     "LEFT",  8, 0)
                renameBox:SetPoint("RIGHT", editBtn, "LEFT", -2, 0)
                renameBox:SetHeight(L_ROW_H - 8)
                renameBox:SetFont("Fonts\\ARIALN.TTF", 13, "")
                renameBox:SetAutoFocus(false)
                renameBox:Hide()
                renameBox:SetScript("OnEscapePressed", function(s) s:Hide(); lbl:Show() end)
                renameBox:SetScript("OnEditFocusLost", function(s) s:Hide(); lbl:Show() end)
                local rn = name
                renameBox:SetScript("OnEnterPressed", function(s)
                    local newName = s:GetText()
                    s:Hide()
                    if newName == "" or newName == rn or not SolaryMDB then lbl:Show(); return end
                    SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
                    SolaryMDB.personal_reminders[newName] = SolaryMDB.personal_reminders[rn]
                    SolaryMDB.personal_reminders[rn] = nil
                    SolaryMDB.personal_reminders_meta = SolaryMDB.personal_reminders_meta or {}
                    SolaryMDB.personal_reminders_meta[newName] = SolaryMDB.personal_reminders_meta[rn]
                    SolaryMDB.personal_reminders_meta[rn] = nil
                    if SolaryMDB.personal_active == rn then SolaryMDB.personal_active = newName end
                    if selName == rn then selName = newName; LoadNoteInEditor(newName) end
                    RefreshList()
                end)
                editBtn:SetScript("OnClick", function()
                    lbl:Hide()
                    renameBox:SetText(rn)
                    renameBox:Show()
                    renameBox:SetFocus()
                end)

                local cn = name
                btn:SetScript("OnClick", function()
                    if selName and SolaryMDB and noteEditor then
                        SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
                        SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
                    end
                    LoadNoteInEditor(cn)
                    RefreshList()
                end)

                listRows[#listRows+1] = {btn=btn, sel=sel, accent=accent, lbl=lbl}
                totalH = totalH + L_ROW_H + L_ROW_GAP
            end
        end

        if not listChild._emptyLbl then
            listChild._emptyLbl = listChild:CreateFontString(nil, "OVERLAY")
            listChild._emptyLbl:SetFont("Fonts\\ARIALN.TTF", 12, "")
            listChild._emptyLbl:SetPoint("TOPLEFT", listChild, "TOPLEFT", 8, -10)
            listChild._emptyLbl:SetTextColor(0.35, 0.35, 0.40, 1)
            listChild._emptyLbl:SetText(SM.T("rem_list_empty"))
        end
        listChild._emptyLbl:SetShown(not hasVisible)

        listChild:SetHeight(math.max(totalH, 1))
        local sh = listScroll:GetHeight()
        local maxScroll = sh > 0 and math.max(0, totalH - sh) or 0
        listScrollBar:SetMinMaxValues(0, maxScroll)
        if listScrollBar:GetValue() > maxScroll then listScrollBar:SetValue(maxScroll) end

        if filterDrop then filterDrop.RefreshVisible(bossesWithNotes) end
    end

    -- ── Panneau gauche ─────────────────────────────────────────
    local lBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    lBg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    lBg:SetSize(LEFT_W, H)
    lBg:SetBackdrop({bgFile=[[Interface\Tooltips\UI-Tooltip-Background]], tile=true, tileSize=64})
    lBg:SetBackdropColor(0.07, 0.07, 0.10, 1)

    local lDivider = lBg:CreateTexture(nil, "OVERLAY")
    lDivider:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.20)
    lDivider:SetWidth(1)
    lDivider:SetPoint("TOPRIGHT",    lBg, "TOPRIGHT",    0, 0)
    lDivider:SetPoint("BOTTOMRIGHT", lBg, "BOTTOMRIGHT", 0, 0)

    local blueHex = string.format("%02x%02x%02x",
        math.floor(SM.OR[1]*255), math.floor(SM.OR[2]*255), math.floor(SM.OR[3]*255))
    local titleHdr = lBg:CreateFontString(nil, "OVERLAY")
    titleHdr:SetFont("Fonts\\ARIALN.TTF", 15, "")
    titleHdr:SetPoint("TOPLEFT", lBg, "TOPLEFT", lPAD, -lPAD)
    titleHdr:SetText("|cff"..blueHex..SM.T("rem_notes_personal_hl").."|r "..SM.T("rem_notes_personal_rest"))
    titleHdr:SetTextColor(1, 1, 1, 1)

    local lSepY = -(lPAD + L_HDR_H + 4)
    local lSep = lBg:CreateTexture(nil, "ARTWORK")
    lSep:SetHeight(1)
    lSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)
    lSep:SetPoint("TOPLEFT",  lBg, "TOPLEFT",  0, lSepY)
    lSep:SetPoint("TOPRIGHT", lBg, "TOPRIGHT", 0, lSepY)

    -- Filtre boss
    local filterItems = {{text=SM.T("rem_filter_all_boss"), value=nil}}
    for _, b in ipairs(BOSS_LIST) do
        if not b.isHeader and b.value then
            filterItems[#filterItems+1] = {text=b.text, value=b.value}
        end
    end
    filterDrop = MakeDrop(lBg, LEFT_W - lPAD * 2, L_DROP_H, filterItems, function(val)
        filterBoss = val
        RefreshList()
    end)
    local filterDropY = lSepY - 5
    filterDrop:SetPoint("TOPLEFT", lBg, "TOPLEFT", lPAD, filterDropY)

    -- Zone liste scrollable
    local lScrollTopY = filterDropY - L_DROP_H - 4
    local lScrollBtmY = L_BTN_H * 2 + lPAD * 3

    listScroll = CreateFrame("ScrollFrame", nil, lBg)
    listScroll:SetPoint("TOPLEFT",     lBg, "TOPLEFT",     lPAD,         lScrollTopY)
    listScroll:SetPoint("BOTTOMRIGHT", lBg, "BOTTOMRIGHT", -(lPAD + 14), lScrollBtmY)

    listScrollBar = CreateFrame("Slider", nil, lBg, "UIPanelScrollBarTemplate")
    listScrollBar:SetPoint("TOPLEFT",    listScroll, "TOPRIGHT",    2, -16)
    listScrollBar:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 2,  16)
    listScrollBar:SetMinMaxValues(0, 0); listScrollBar:SetValueStep(L_ROW_H)
    listScrollBar:SetScript("OnValueChanged", function(_, val)
        listScroll:SetVerticalScroll(val)
    end)
    listScrollBar:SetValue(0)
    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(_, delta)
        local cur    = listScrollBar:GetValue()
        local lo, hi = listScrollBar:GetMinMaxValues()
        listScrollBar:SetValue(math.max(lo, math.min(hi, cur - delta * L_ROW_H * 3)))
    end)

    listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(lScrollW, 1)
    listScroll:SetScrollChild(listChild)

    -- Bouton créer
    local createBtn = SM.OBtn(lBg, LEFT_W - lPAD * 2, L_BTN_H, SM.T("rem_btn_create"), function()
        if selName and SolaryMDB and noteEditor then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
        end
        local noteName = "Nouvelle note"
        if not SolaryMDB then return end
        SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
        -- Éviter les doublons
        local finalName = noteName
        local idx = 1
        while SolaryMDB.personal_reminders[finalName] ~= nil do
            idx = idx + 1
            finalName = noteName .. " " .. idx
        end
        SolaryMDB.personal_reminders[finalName] = ""
        local meta = getMeta(finalName)
        if bossDrop then meta.boss = bossDrop.GetValue() end
        if diffDrop  then meta.diff = diffDrop.GetValue()  end
        selName = finalName
        RefreshList()
        LoadNoteInEditor(finalName)
        if noteEditor then noteEditor:SetFocus() end
    end)
    createBtn:SetPoint("BOTTOMLEFT", lBg, "BOTTOMLEFT", lPAD, lPAD)

    -- Bouton copier depuis note partagée
    local importSharedBtn = SM.Btn(lBg, LEFT_W - lPAD * 2, L_BTN_H, SM.T("rem_btn_import_shared"), 0.12, 0.28, 0.55, function()
        if selName and SolaryMDB and noteEditor then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
        end
        if not SolaryMDB then return end
        local sharedName = SolaryMDB.active_reminder
        local sharedRaw  = sharedName and SolaryMDB.reminders and SolaryMDB.reminders[sharedName]
        if not sharedRaw or sharedRaw == "" then
            SM.Print("|cffff8800Aucune note partagée active.|r"); return
        end
        SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
        local finalName = sharedName
        local idx = 2
        while SolaryMDB.personal_reminders[finalName] ~= nil do
            finalName = sharedName .. " " .. idx; idx = idx + 1
        end
        SolaryMDB.personal_reminders[finalName] = sharedRaw
        selName = finalName
        RefreshList()
        LoadNoteInEditor(finalName)
        if noteEditor then noteEditor:SetFocus() end
    end)
    importSharedBtn:SetPoint("BOTTOMLEFT", lBg, "BOTTOMLEFT", lPAD, lPAD + L_BTN_H + lPAD)

    -- ── Panneau droit ──────────────────────────────────────────
    local rX = LEFT_W + 1
    local rW = W - rX
    local rBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rBg:SetPoint("TOPLEFT", f, "TOPLEFT", rX, 0)
    rBg:SetSize(rW, H)
    rBg:SetBackdrop({bgFile=[[Interface\Tooltips\UI-Tooltip-Background]], tile=true, tileSize=64})
    rBg:SetBackdropColor(0.07, 0.07, 0.10, 1)

    -- Boss + Diff dropdowns (lecture seule après création)
    local bossDropW = math.floor(rW * 0.56) - R_PAD
    local diffDropW = math.floor(rW * 0.30)

    bossDrop = MakeDrop(rBg, bossDropW, R_TBAR_H, BOSS_LIST, nil)
    bossDrop:SetPoint("TOPLEFT", rBg, "TOPLEFT", R_PAD, -R_PAD)

    diffDrop = MakeDrop(rBg, diffDropW, R_TBAR_H, DIFF_LIST, nil)
    diffDrop:SetPoint("LEFT", bossDrop, "RIGHT", 6, 0)

    -- Champ nom de la note
    local nameInputY = -(R_PAD + R_TBAR_H + 5)
    noteNameInput = CreateFrame("EditBox", nil, rBg, "InputBoxTemplate")
    noteNameInput:SetPoint("TOPLEFT",  rBg, "TOPLEFT",  R_PAD + 4, nameInputY)
    noteNameInput:SetPoint("TOPRIGHT", rBg, "TOPRIGHT", -R_PAD - 4, nameInputY)
    noteNameInput:SetHeight(22)
    noteNameInput:SetFont("Fonts\\ARIALN.TTF", 14, "")
    noteNameInput:SetAutoFocus(false)
    noteNameInput:SetMaxLetters(128)
    noteNameInput:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    noteNameInput:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
    noteNameInput:SetScript("OnEditFocusLost", function(s)
        if not selName then return end
        local newName = s:GetText()
        if newName == "" or newName == selName then return end
        if SolaryMDB then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[newName] = SolaryMDB.personal_reminders[selName]
            SolaryMDB.personal_reminders[selName] = nil
            SolaryMDB.personal_reminders_meta = SolaryMDB.personal_reminders_meta or {}
            SolaryMDB.personal_reminders_meta[newName] = SolaryMDB.personal_reminders_meta[selName]
            SolaryMDB.personal_reminders_meta[selName] = nil
        end
        selName = newName
        RefreshList()
    end)

    -- Séparateur
    local rTopSep = rBg:CreateTexture(nil, "ARTWORK")
    rTopSep:SetHeight(1)
    rTopSep:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.18)
    local sepY = nameInputY - 22 - 4
    rTopSep:SetPoint("TOPLEFT",  rBg, "TOPLEFT",  0, sepY)
    rTopSep:SetPoint("TOPRIGHT", rBg, "TOPRIGHT", 0, sepY)

    -- Placeholder
    pNoSelLbl = rBg:CreateFontString(nil, "OVERLAY")
    pNoSelLbl:SetFont("Fonts\\ARIALN.TTF", 14, "")
    pNoSelLbl:SetPoint("CENTER", rBg, "CENTER", 0, 14)
    pNoSelLbl:SetText(SM.T("rem_no_selection"))
    pNoSelLbl:SetTextColor(0.28, 0.28, 0.32, 1)

    -- Éditeur
    local edTopY = sepY - 4
    local edScroll = CreateFrame("ScrollFrame", nil, rBg, "UIPanelScrollFrameTemplate")
    edScroll:SetPoint("TOPLEFT",     rBg, "TOPLEFT",      R_PAD,          edTopY)
    edScroll:SetPoint("BOTTOMRIGHT", rBg, "BOTTOMRIGHT", -(R_PAD + 18),  R_BBAR_H + R_PAD)

    noteEditor = CreateFrame("EditBox", nil, edScroll)
    noteEditor:SetMultiLine(true); noteEditor:SetAutoFocus(false)
    noteEditor:SetFont("Fonts\\ARIALN.TTF", 13, "")
    noteEditor:SetMaxLetters(0)
    noteEditor:SetWidth(rW - R_PAD * 2 - 20)
    noteEditor:SetTextColor(0.88, 0.88, 0.92, 1)
    noteEditor:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    noteEditor:SetScript("OnTextChanged", function(s, userInput)
        local w = edScroll:GetWidth()
        if w > 0 then s:SetWidth(w) end
        if userInput and selName and SolaryMDB then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[selName] = s:GetText()
        end
    end)
    edScroll:SetScrollChild(noteEditor)
    edScroll:SetScript("OnSizeChanged", function(s, w)
        if w > 0 then noteEditor:SetWidth(w) end
    end)
    edScroll:SetScript("OnMouseDown", function() noteEditor:SetFocus() end)

    -- Boutons d'action
    local B_H    = 24
    local B_Y       = R_PAD
    local saveBtn   = SM.OBtn(rBg, 110, B_H, SM.T("rem_btn_save"),   nil)
    local delBtn    = SM.RBtn(rBg,  90, B_H, SM.T("rem_btn_delete"), nil)
    local affBtn    = SM.Btn( rBg,  90, B_H, SM.T("rem_btn_show"), 0.08, 0.12, 0.20, nil)

    saveBtn:SetPoint("BOTTOMLEFT", rBg, "BOTTOMLEFT", R_PAD,                   B_Y)
    delBtn:SetPoint( "BOTTOMLEFT", rBg, "BOTTOMLEFT", R_PAD + 110 + 4,         B_Y)
    affBtn:SetPoint( "BOTTOMLEFT", rBg, "BOTTOMLEFT", R_PAD + 110 + 4 + 90 + 4, B_Y)

    saveBtn:SetScript("OnClick", function()
        if not selName or not SolaryMDB then return end
        SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
        SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
        RefreshList()
    end)

    delBtn:SetScript("OnClick", function()
        if not selName or not SolaryMDB then return end
        local n = selName
        ConfirmDel(SM.T("rem_confirm_del_note"):format(n), function()
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[n] = nil
            SolaryMDB.personal_reminders_meta = SolaryMDB.personal_reminders_meta or {}
            SolaryMDB.personal_reminders_meta[n] = nil
            if SolaryMDB.personal_active == n then SolaryMDB.personal_active = nil end
            selName = nil
            noteEditor:SetText(""); noteNameInput:SetText(""); pNoSelLbl:Show()
            RefreshList()
        end)
    end)

    affBtn:SetScript("OnClick", function()
        if not selName then return end
        if SolaryMDB then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
        end
        local RN = SM.ReminderNote
        if RN and RN.SetPersonalActive and RN.ShowPersonalNote then
            RN.SetPersonalActive(selName)
            RN.ShowPersonalNote()
        end
    end)

    -- ── Lifecycle ──────────────────────────────────────────────
    f:HookScript("OnShow", function() RefreshList() end)
    f:HookScript("OnHide", function()
        if selName and SolaryMDB then
            SolaryMDB.personal_reminders = SolaryMDB.personal_reminders or {}
            SolaryMDB.personal_reminders[selName] = noteEditor:GetText()
        end
    end)

    RefreshList()
    return f
end
