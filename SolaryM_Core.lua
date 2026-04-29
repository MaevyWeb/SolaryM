-- SolaryM_Core.lua
-- Init, SavedVariables, droits, helpers UI partagés
-- v3.0.2 — Midnight Season 1

SolaryM_Editors = {}

SM = SM or {}
SM.VERSION = "3.0.2"

-- ============================================================
-- SCAN MEDIA — sons et images (peuplé au login)
-- ============================================================
SM.MediaSounds = {}
SM.MediaBreak  = {}

local SOUNDS_PATH = "Interface\\AddOns\\SolaryM\\Media\\Sounds\\"
local BREAK_PATH  = "Interface\\AddOns\\SolaryM\\Media\\Break\\"

-- Liste des sons livrés avec l'addon
local BUNDLED_SOUNDS = {
    "Charge","Clear","Debuff","Dispel","Fixate",
    "Interrupt","Soak","Spread","Stack","Targeted",
}
-- Liste des images break livrées avec l'addon
-- ↓ Ajoute ici le nom (sans extension) de chaque image dans Media/Break/
-- ↓ Ajoute ici le nom (sans extension) de chaque image dans Media/Break/
local BUNDLED_BREAK = { "break", "meme", "squirrel", "cat", "nanterre", "dog" }

local function ScanMedia()
    -- Sons : bundled + extra depuis DB
    SM.MediaSounds = {}
    local seen = {}
    for _, n in ipairs(BUNDLED_SOUNDS) do
        if not seen[n] then seen[n]=true; table.insert(SM.MediaSounds, n) end
    end
    if SolaryMDB and SolaryMDB.extraSounds then
        for _, n in ipairs(SolaryMDB.extraSounds) do
            if not seen[n] then seen[n]=true; table.insert(SM.MediaSounds, n) end
        end
    end
    table.sort(SM.MediaSounds)

    -- Images break
    SM.MediaBreak = {}
    local seenB = {}
    for _, n in ipairs(BUNDLED_BREAK) do
        if not seenB[n] then seenB[n]=true; table.insert(SM.MediaBreak, n) end
    end
    if SolaryMDB and SolaryMDB.extraBreak then
        for _, n in ipairs(SolaryMDB.extraBreak) do
            if not seenB[n] then seenB[n]=true; table.insert(SM.MediaBreak, n) end
        end
    end
end

-- Peupler immédiatement avec les sons bundled
-- Les extra (DB) seront ajoutés au login
do
    SM.MediaSounds = {}
    for _, n in ipairs(BUNDLED_SOUNDS) do table.insert(SM.MediaSounds, n) end
    table.sort(SM.MediaSounds)
    SM.MediaBreak = {}
    for _, n in ipairs(BUNDLED_BREAK) do table.insert(SM.MediaBreak, n) end
end

-- Shuffle sans répétition
local breakQueue = {}

local function ShuffleBreakQueue()
    breakQueue = {}
    for _, n in ipairs(SM.MediaBreak) do table.insert(breakQueue, n) end
    -- Fisher-Yates shuffle
    for i = #breakQueue, 2, -1 do
        local j = math.random(1, i)
        breakQueue[i], breakQueue[j] = breakQueue[j], breakQueue[i]
    end
end

function SM.GetRandomBreakImage()
    if #SM.MediaBreak == 0 then return BREAK_PATH.."break.tga" end
    if #breakQueue == 0 then ShuffleBreakQueue() end
    local name = table.remove(breakQueue, 1)
    return BREAK_PATH..name..".tga"
end

function SM.GetBreakImagePath(name)
    return BREAK_PATH..name..".tga"
end

function SM.GetSoundPath(name)
    return SOUNDS_PATH..name..".ogg"
end


-- Palette couleurs
SM.OR  = { 0.55, 0.28, 0.92 }  -- violet/purple
SM.DK  = { 0.04, 0.04, 0.06 }   -- fond sombre (quasi noir)
SM.RED = { 0.75, 0.12, 0.12 }
SM.GRN = { 0.1,  0.65, 0.2  }
SM.BLU = { 0.1,  0.28, 0.6  }
SM.YEL = { 1,    0.85, 0    }
SM.PRP = { 0.55, 0.2,  0.9  }

-- ============================================================
-- DEBUG
-- ============================================================
SM.DEBUG = true   -- mettre false pour prod

function SM.D(msg)
    if SM.DEBUG then
        print("|cff888888[SM-DBG]|r " .. tostring(msg))
    end
end

-- ============================================================
-- HELPERS GÉNÉRAUX
-- ============================================================
function SM.IsEditor()
    local name = UnitName("player")
    if not name then return false end
    for _, n in ipairs(SolaryM_Editors) do
        if n == name then return true end
    end
    return false
end

-- TTS : overlap=true pour toujours jouer immédiatement, peu importe ce qui joue
-- ============================================================
-- PRIVATE AURA WARNING TEXT —
-- PAWMover : frame visible/draggable avec preview text
-- PAWAnchor : frame invisible ancrée à PAWMover, reçoit SetPrivateWarningTextAnchor
-- ============================================================
SM._pawMover = nil
SM._pawAnchor = nil

function SM.SetupPrivateWarningText()
    if not C_UnitAuras or not C_UnitAuras.SetPrivateWarningTextAnchor then return end

    local scale = SolaryMDB.paw_scale or 2
    local previewFont = 20 * scale

    -- Créer la frame mover si besoin
    if not SM._pawMover then
        SM._pawMover = CreateFrame("Frame", "SolaryMPAWMover", UIParent, "BackdropTemplate")
        local s = SolaryMDB.paw_pos
        if s and s.x then
            SM._pawMover:SetPoint(s.point or "CENTER", UIParent, s.rp or "CENTER", s.x, s.y)
        else
            SM._pawMover:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        end
        SM._pawMover:SetMovable(true)
        SM._pawMover:EnableMouse(false)
        SM._pawMover:RegisterForDrag("LeftButton")
        SM._pawMover:SetScript("OnDragStart", function(f) if SM.MoveMode then f:StartMoving() end end)
        SM._pawMover:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            local pt,_,rp,x,y = f:GetPoint()
            SolaryMDB.paw_pos = {point=pt, rp=rp, x=math.floor(x), y=math.floor(y)}
        end)

        -- Text de preview ("<secret value> targets you...")
        local previewText = SM._pawMover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        previewText:SetFont("Fonts\\FRIZQT__.TTF", previewFont, "OUTLINE")
        previewText:SetText("<secret value> te cible avec le sort <secret value>")
        previewText:SetPoint("CENTER", SM._pawMover, "CENTER", 0, 0)
        previewText:SetTextColor(1, 0.82, 0, 1)
        SM._pawMover._text = previewText
        SM._pawMover._text:Hide()
    end

    -- Mettre à jour la taille et la font selon le scale actuel
    SM._pawMover:SetSize(500, previewFont * 1.5)
    if SM._pawMover._text then
        SM._pawMover._text:SetFont("Fonts\\FRIZQT__.TTF", previewFont, "OUTLINE")
    end

    -- Créer la frame anchor si besoin
    if not SM._pawAnchor then
        SM._pawAnchor = CreateFrame("Frame", nil, UIParent)
    end

    if SolaryMDB.paw_enabled == false then return end

    -- Ancrer PAWAnchor à PAWMover avec offset
    local h = SM._pawMover:GetHeight()
    local offset = -0.8 * h / scale

    SM._pawAnchor:SetPoint("TOPLEFT",     SM._pawMover, "TOPLEFT",     0, offset)
    SM._pawAnchor:SetPoint("BOTTOMRIGHT", SM._pawMover, "BOTTOMRIGHT", 0, offset)
    SM._pawAnchor:SetScale(scale)

    local textanchor = {
        point         = "CENTER",
        relativeTo    = SM._pawAnchor,
        relativePoint = "CENTER",
        offsetX       = 0,
        offsetY       = 0,
    }
    pcall(C_UnitAuras.SetPrivateWarningTextAnchor, SM._pawAnchor, textanchor)
end

function SM.PreviewPrivateWarningText(show)
    if not SM._pawMover then SM.SetupPrivateWarningText() end
    if show then
        SM._pawMover:SetBackdrop({bgFile="Interface\Buttons\WHITE8X8", edgeFile="Interface\Buttons\WHITE8X8", edgeSize=1})
        SM._pawMover:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
        SM._pawMover:SetBackdropBorderColor(SM.OR[1], SM.OR[2], SM.OR[3], 0.8)
        SM._pawMover:EnableMouse(true)
        if SM._pawMover._text then SM._pawMover._text:Show() end
        SM._pawMover:Show()
    else
        SM._pawMover:SetBackdrop(nil)
        SM._pawMover:EnableMouse(false)
        if SM._pawMover._text then SM._pawMover._text:Hide() end
    end
end

-- ============================================================
-- PRIVATE AURA SOUNDS — (AddPrivateAuraAppliedSound)
-- SolaryMDB.pa_sounds = { [spellID] = "SoundName" }
-- ============================================================
SM.PASoundIDs = {}

-- Sons baseline Midnight S1 Raid (depuis SoundListRaid)
SM.PA_DEFAULTS_RAID = {
    [1260203] = "Soak",     -- Umbral Collapse
    [1249265] = "Soak",     -- Umbral Collapse
    [1280023] = "Targeted", -- Void Marked
    [1283069] = "Fixate",   -- Weakened
    [1254113] = "Fixate",   -- Vorasius Fixate
    [1248697] = "Debuff",   -- Despotic Command
    [1268992] = "Targeted", -- Shattering Twilight
    [1253024] = "Targeted", -- Shattering Twilight (Tank)
    [1255612] = "Targeted", -- Dread Breath
    [1270497] = "Spread",   -- Shadowmark
    [1248994] = "Targeted", -- Execution Sentence
    [1248985] = "Targeted", -- Execution Sentence
    [1246487] = "Spread",   -- Avenger's Shield
    [1232470] = "Soak",     -- Grasp of Emptiness
    [1260027] = "Soak",     -- Grasp of Emptiness Mythic
    [1239111] = "Soak",     -- Aspect of the End
    [1233602] = "Targeted", -- Silverstrike Arrow
    [1237623] = "Targeted", -- Ranger Captain's Mark
    [1259861] = "Targeted", -- Ranger Captain's Mark Mythic
    [1283236] = "Targeted", -- Void Expulsion
    [1238708] = "Targeted", -- Feather
    [1257087] = "Clear",    -- Consuming Miasma
    [1264756] = "Targeted", -- Rift Madness
    [1241339] = "Targeted", -- Void Dive
    [1241292] = "Targeted", -- Light Dive
    [1242091] = "Targeted", -- Void Quill
    [1241992] = "Targeted", -- Light Quill
    [1284527] = "Targeted", -- Galvanize
    [1281184] = "Spread",   -- Criticality
    [1249609] = "Targeted", -- Dark Rune
    [1285510] = "Targeted", -- Starsplinter
}

function SM.RegisterPASound(spellID, soundName)
    if not C_UnitAuras or not C_UnitAuras.AddPrivateAuraAppliedSound then return end
    if not spellID then return end

    -- Vérifier private aura
    local ok, isPrivate = pcall(C_UnitAuras.AuraIsPrivate, spellID)
    if not ok or not isPrivate then
        SM.Print("SpellID "..spellID.." n'est pas une private aura.")
        return
    end

    -- Supprimer l'ancien
    if SM.PASoundIDs[spellID] then
        pcall(C_UnitAuras.RemovePrivateAuraAppliedSound, SM.PASoundIDs[spellID])
        SM.PASoundIDs[spellID] = nil
    end

    if not soundName or soundName == "" then return end

    local ok2, id = pcall(C_UnitAuras.AddPrivateAuraAppliedSound, {
        unitToken     = "player",
        spellID       = spellID,
        soundFileName = SM.GetSoundPath(soundName),
        outputChannel = "master",
    })
    if ok2 and id then SM.PASoundIDs[spellID] = id end
end

function SM.RegisterAllPASounds()
    if not SolaryMDB then return end
    SolaryMDB.pa_sounds = SolaryMDB.pa_sounds or {}
    -- Sons defaults si activés
    if SolaryMDB.pa_use_defaults ~= false then
        for spellID, soundName in pairs(SM.PA_DEFAULTS_RAID) do
            -- Ne pas écraser un son custom
            if not SolaryMDB.pa_sounds[spellID] then
                SM.RegisterPASound(spellID, soundName)
            end
        end
    end
    -- Sons custom du joueur
    for spellID, soundName in pairs(SolaryMDB.pa_sounds) do
        SM.RegisterPASound(spellID, soundName)
    end
end

function SM.TTS(text, rate, volume)
    if not text or text == "" then return end
    if not C_VoiceChat or not C_VoiceChat.SpeakText then return end
    local voiceID = SolaryMDB and SolaryMDB.tts_voice or 0
    rate   = rate   or (SolaryMDB and SolaryMDB.tts_rate   or 0)
    volume = volume or (SolaryMDB and SolaryMDB.tts_volume or 100)
    -- overlap=true : interrompt le TTS en cours et joue immédiatement
    pcall(C_VoiceChat.SpeakText, voiceID, text, rate, volume, true)
end

function SM.TTSClear() end -- compatibilité

function SM.Print(msg)
    print("|cFFFFAA00SolaryM|r " .. (msg or ""))
end

-- Raccourci pour GetSpellInfo compatible Retail/Midnight
-- En Midnight, C_Spell.GetSpellName remplace GetSpellInfo
function SM.SpellName(id)
    if not id or id == 0 then return nil end
    -- Midnight API (12.x)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    end
    -- Fallback Retail classique
    local name = GetSpellInfo and GetSpellInfo(id)
    return name
end

-- ── Helpers UI ──────────────────────────────────────────────
function SM.BG(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function SM.Btn(p, w, h, lbl, r, g, b, fn)
    local btn = CreateFrame("Button", nil, p)
    btn:SetSize(w, h)
    btn._r = r; btn._g = g; btn._b = b

    -- Fond sombre solide
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.13, 0.96)
    btn._bg = bg

    -- Fond coloré (hover overlay) — invisible par défaut
    local bgHover = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    bgHover:SetAllPoints()
    bgHover:SetColorTexture(r, g, b, 0)
    btn._bgHover = bgHover

    -- Bordure extérieure fine (neutre)
    for _, t in ipairs({{"TOPLEFT","TOPRIGHT",0,1},{"BOTTOMLEFT","BOTTOMRIGHT",0,1},{"TOPLEFT","BOTTOMLEFT",1,0},{"TOPRIGHT","BOTTOMRIGHT",1,0}}) do
        local l = btn:CreateTexture(nil, "BORDER")
        l:SetColorTexture(0.28, 0.28, 0.32, 1)
        l:SetPoint(t[1]); l:SetPoint(t[2]); l:SetSize(t[3], t[4])
    end

    -- Accent coloré — bordure gauche (2px)
    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetSize(2, h - 2)
    accent:SetPoint("LEFT", btn, "LEFT", 1, 0)
    accent:SetColorTexture(r, g, b, 0.90)
    btn._accent = accent

    -- Liseré lumineux en haut
    local shine = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    shine:SetPoint("TOPLEFT",  btn, "TOPLEFT",  1, -1)
    shine:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    shine:SetHeight(1)
    shine:SetColorTexture(1, 1, 1, 0.07)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(); fs:SetJustifyH("CENTER")
    fs:SetTextColor(r + (1-r)*0.55, g + (1-g)*0.55, b + (1-b)*0.55, 1)
    fs:SetText(lbl)
    btn._fs = fs

    btn:SetScript("OnClick", fn)
    btn:SetScript("OnEnter", function(s)
        s._bgHover:SetColorTexture(s._r, s._g, s._b, 0.18)
        s._accent:SetColorTexture(s._r, s._g, s._b, 1)
        s._fs:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(s)
        s._bgHover:SetColorTexture(s._r, s._g, s._b, 0)
        s._accent:SetColorTexture(s._r, s._g, s._b, 0.90)
        s._fs:SetTextColor(s._r + (1-s._r)*0.55, s._g + (1-s._g)*0.55, s._b + (1-s._b)*0.55, 1)
    end)
    return btn
end

function SM.OBtn(p, w, h, l, fn) return SM.Btn(p, w, h, l, SM.OR[1],  SM.OR[2],  SM.OR[3],  fn) end
function SM.RBtn(p, w, h, l, fn) return SM.Btn(p, w, h, l, SM.RED[1], SM.RED[2], SM.RED[3], fn) end
function SM.GBtn(p, w, h, l, fn) return SM.Btn(p, w, h, l, SM.GRN[1], SM.GRN[2], SM.GRN[3], fn) end
function SM.BBtn(p, w, h, l, fn) return SM.Btn(p, w, h, l, SM.BLU[1], SM.BLU[2], SM.BLU[3], fn) end

function SM.Input(p, w, h, hint)
    local eb = CreateFrame("EditBox", nil, p)
    eb:SetSize(w, h)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetMaxLetters(200)
    SM.BG(eb, 0.05, 0.05, 0.08, 1)
    local line = eb:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.5)
    eb._hint = hint
    eb:SetText(hint or "")
    eb:SetTextColor(0.45, 0.45, 0.45, 1)
    eb:SetScript("OnEditFocusGained", function(s)
        if s:GetText() == (s._hint or "") then
            s:SetText("")
            s:SetTextColor(1, 1, 1, 1)
        end
    end)
    eb:SetScript("OnEditFocusLost", function(s)
        if s:GetText() == "" then
            s:SetText(s._hint or "")
            s:SetTextColor(0.45, 0.45, 0.45, 1)
        end
    end)
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    return eb
end

function SM.GetVal(eb)
    local t = eb:GetText()
    return (t == (eb._hint or "")) and "" or t
end

function SM.SetVal(eb, v)
    if v and v ~= "" then
        eb:SetText(v)
        eb:SetTextColor(1, 1, 1, 1)
    else
        eb:SetText(eb._hint or "")
        eb:SetTextColor(0.45, 0.45, 0.45, 1)
    end
end

function SM.Scroll(p, w, h)
    local sf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    sf:SetSize(w, h)
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(w - 20, 1)
    sf:SetScrollChild(c)
    sf.content = c
    return sf
end

function SM.Lbl(p, text, size, x, y, col)
    local fs = p:CreateFontString(nil, "OVERLAY", size or "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", p, "TOPLEFT", x or 0, y or 0)
    fs:SetText(text)
    if col then fs:SetTextColor(col[1], col[2], col[3], 1) end
    return fs
end

-- Séparateur horizontal
function SM.Sep(p, y, w)
    local t = p:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    t:SetSize(w or 200, 1)
    t:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.3)
    return t
end

-- ============================================================
-- SONS — hooks préparés (fichiers .ogg à placer par l'user)
-- ============================================================
SM.SOUNDS = {
    -- Alertes de boss
    alert         = "Interface\\AddOns\\SolaryM\\Media\\alert.ogg",
    soak          = "Interface\\AddOns\\SolaryM\\Media\\prepare-soak.ogg",
    aoe           = "Interface\\AddOns\\SolaryM\\Media\\prepare-aoe.ogg",
    interrupt     = "Interface\\AddOns\\SolaryM\\Media\\interrupt-now.ogg",
    tankbuster    = "Interface\\AddOns\\SolaryM\\Media\\tank-buster.ogg",
    spread        = "Interface\\AddOns\\SolaryM\\Media\\spread-now.ogg",
    stack         = "Interface\\AddOns\\SolaryM\\Media\\prepare-stack.ogg",
    dispel        = "Interface\\AddOns\\SolaryM\\Media\\prepare-dispel.ogg",
    dodge         = "Interface\\AddOns\\SolaryM\\Media\\dodge-frontal.ogg",
    switch_adds   = "Interface\\AddOns\\SolaryM\\Media\\switch-add.ogg",
    phase_change  = "Interface\\AddOns\\SolaryM\\Media\\phase-change.ogg",
    enrage        = "Interface\\AddOns\\SolaryM\\Media\\boss-enrage.ogg",
    vuln          = "Interface\\AddOns\\SolaryM\\Media\\boss-vuln.ogg",
    special       = "Interface\\AddOns\\SolaryM\\Media\\special-mechanic.ogg",
    -- Countdown
    cd5           = "Interface\\AddOns\\SolaryM\\Media\\countdown-5.ogg",
    cd4           = "Interface\\AddOns\\SolaryM\\Media\\countdown-4.ogg",
    cd3           = "Interface\\AddOns\\SolaryM\\Media\\countdown-3.ogg",
    cd2           = "Interface\\AddOns\\SolaryM\\Media\\countdown-2.ogg",
    cd1           = "Interface\\AddOns\\SolaryM\\Media\\countdown-1.ogg",
}

-- Map callout → clé son
SM.CALLOUT_SOUND = {
    ["SOAK"]              = "soak",
    ["AOE INCOMING"]      = "aoe",
    ["AOE IMMINENTE"]     = "aoe",
    ["INTERRUPT"]         = "interrupt",
    ["INTERRUPT NOW"]     = "interrupt",
    ["INTERROMPRE"]       = "interrupt",
    ["TANK BUSTER"]       = "tankbuster",
    ["SPREAD NOW"]        = "spread",
    ["SPREAD"]            = "spread",
    ["STACK UP"]          = "stack",
    ["STACK"]             = "stack",
    ["DISPEL"]            = "dispel",
    ["DODGE"]             = "dodge",
    ["DODGE FRONTAL"]     = "dodge",
    ["ESQUIVER"]          = "dodge",
    ["ESQUIVER FRONTAL"]  = "dodge",
    ["SWITCH ADDS"]       = "switch_adds",
    ["FOCUS ADDS"]        = "switch_adds",
    ["PHASE CHANGE"]      = "phase_change",
    ["CHANGEMENT PHASE"]  = "phase_change",
    ["BOSS ENRAGE"]       = "enrage",
    ["BOSS VULNERABLE"]   = "vuln",
    ["BOSS VULNÉRABLE"]   = "vuln",
    ["SPECIAL"]           = "special",
    ["MÉCA SPÉCIALE"]     = "special",
}

function SM.PlaySound(key)
    local path = SM.SOUNDS[key]
    if not path then
        return
    end
    -- PlaySoundFile retourne false si le fichier n'existe pas → pas d'erreur
    local ok = PlaySoundFile(path, "Master")
    if not ok then
    end
end

SolaryM_Editors = {"Maevibro","Erenar","Jarell","Alta","Navii","Maevywar","Cotover","Maevi","Pouchaman"}

function SM.PlaySoundForCallout(callout)
    if not callout then return end
    local key = SM.CALLOUT_SOUND[callout]
    if key then
        SM.PlaySound(key)
    else
        SM.PlaySound("alert")   -- son générique si pas de mapping
    end
end

-- ============================================================
-- LANGUE — FR ou EN selon le client WoW
-- ============================================================
SM.LANG = (GetLocale() == "frFR") and "fr" or "en"

-- ============================================================
-- TRADUCTIONS UI
-- ============================================================
SM.Strings = {
    -- Onglets
    tab_spells          = { fr = "Sorts",          en = "Spells" },
    tab_smartcast       = { fr = "SmartCast",       en = "SmartCast" },
    tab_invites         = { fr = "Invites",         en = "Invites" },
    tab_memory          = { fr = "Memory Game",     en = "Memory Game" },
    tab_versions        = { fr = "Versions",        en = "Versions" },
    tab_settings        = { fr = "Paramètres",      en = "Settings" },
    tab_changelogs      = { fr = "Changelogs",      en = "Changelogs" },
    tab_reminders       = { fr = "Notes",            en = "Notes" },
    rem_subtab_shared   = { fr = "Notes Raid", en = "Shared Notes" },
    rem_subtab_personal = { fr = "Mes Notes", en = "My Notes" },
    -- Reminders tab
    rem_import_header   = { fr = "Importer une note",                               en = "Import a note" },
    rem_name_ph         = { fr = "Nom de la note (ex: Raid Mercredi)",              en = "Note name (e.g. Wednesday Raid)" },
    rem_paste_ph        = { fr = "Colle ici le contenu de la note Viserio...",      en = "Paste the Viserio note content here..." },
    rem_btn_import      = { fr = "Importer",        en = "Import" },
    rem_saved_header    = { fr = "Notes sauvegardées",                              en = "Saved notes" },
    rem_no_notes        = { fr = "Aucune note importée.",                           en = "No imported notes." },
    rem_btn_activate    = { fr = "Activer",          en = "Activate" },
    rem_btn_delete      = { fr = "Supprimer",        en = "Delete" },
    rem_btn_shownote    = { fr = "Afficher la note", en = "Show note" },
    rem_active_prefix   = { fr = "Active : ",        en = "Active: " },
    rem_nick_label      = { fr = "Ton pseudo (surnom) :",                           en = "Your nickname:" },
    rem_nick_ph         = { fr = "Ex: Maevi",        en = "e.g. Maevi" },
    rem_btn_broadcast   = { fr = "Envoyer au raid",  en = "Send to raid" },
    rem_notes_shared_suffix = { fr = "Raid",                               en = "Shared" },
    rem_notes_personal_hl   = { fr = "Notes",                              en = "Personal" },
    rem_notes_personal_rest = { fr = "Personnelles",                       en = "Notes" },
    rem_filter_all_boss     = { fr = "Tous les boss",                      en = "All bosses" },
    rem_list_empty          = { fr = "Aucune note",                        en = "No notes" },
    rem_no_selection        = { fr = "Selectionne ou cree une note",       en = "Select or create a note" },
    rem_btn_create          = { fr = "+ Créer une note",                   en = "+ Create a note" },
    rem_btn_import_shared   = { fr = "Copier depuis partagée",             en = "Copy from shared" },
    rem_btn_unload          = { fr = "Désactiver",                         en = "Deactivate" },
    rem_btn_del_all         = { fr = "Tout suppr.",                        en = "Delete all" },
    rem_btn_load_send       = { fr = "Charger & Envoyer",                  en = "Load & Send" },
    rem_btn_save            = { fr = "Sauvegarder",                        en = "Save" },
    rem_btn_show            = { fr = "Afficher",                           en = "Show" },
    rem_btn_cancel          = { fr = "Annuler",                            en = "Cancel" },
    rem_btn_test            = { fr = "Test",                               en = "Test" },
    rem_btn_stop            = { fr = "Stop",                               en = "Stop" },
    rem_recv_label          = { fr = "Reçu :",                             en = "Received:" },
    rem_recv_none           = { fr = "Aucune",                             en = "None" },
    rem_name_label          = { fr = "Nom de la note",                     en = "Note name" },
    rem_paste_label         = { fr = "Contenu (colle ta note ici)",        en = "Content (paste here)" },
    rem_confirm_del_note    = { fr = "Supprimer la note |cffFFAA00%s|r ?", en = "Delete note |cffFFAA00%s|r?" },
    rem_confirm_del_all_fmt = { fr = "Supprimer toutes les notes (%d) ?",  en = "Delete all notes (%d)?" },
    rem_personal_note_title  = { fr = "Note Personnelle",                  en = "Personal Note" },
    rem_boss_none           = { fr = "Aucun Boss",                         en = "No Boss" },
    rem_diff_heroic         = { fr = "Héroïque",                           en = "Heroic" },
    rem_diff_mythic         = { fr = "Mythique",                           en = "Mythic" },
    -- Spells tab
    spells_header       = { fr = "Sorts — par zone et boss",                    en = "Spells — by zone and boss" },
    add_spell_btn       = { fr = "Ajouter un sort",                              en = "Add a spell" },
    all_zones           = { fr = "Toutes les zones",                             en = "All zones" },
    spells_found        = { fr = "sorts trouvés",                                en = "spells found" },
    search_placeholder  = { fr = "Rechercher un sort ou callout...",             en = "Search for a spell or callout..." },
    edit_callout        = { fr = "Modifier le callout",                          en = "Edit callout" },
    spell_id            = { fr = "Spell ID :",                                   en = "Spell ID:" },
    spell_name          = { fr = "Nom du sort :",                                en = "Spell name:" },
    spell_note          = { fr = "Note :",                                       en = "Note:" },
    unknown_spell       = { fr = "Sort inconnu",                                 en = "Unknown spell" },
    callout_screen      = { fr = "Callout affiché sur ton écran :",              en = "Callout shown on your screen:" },
    callout_ph          = { fr = "Ex: SOAK, INTERRUPT, BOUGER...",               en = "Ex: SOAK, INTERRUPT, MOVE..." },
    tts_label           = { fr = "TTS — texte lu à voix haute (pour toi) :",    en = "TTS — text read aloud (for you):" },
    tts_ph              = { fr = "Ex: bite bite, soakez gauche...",              en = "Ex: bite bite, soak left..." },
    sound_label         = { fr = "Son — joué à l'affichage de l'alerte (pour toi) :", en = "Sound — played when the alert shows (for you):" },
    btn_test            = { fr = "Test",            en = "Test" },
    btn_save            = { fr = "Sauvegarder",     en = "Save" },
    btn_reset           = { fr = "Réinitialiser",   en = "Reset" },
    btn_test2           = { fr = "Tester",          en = "Test" },
    raid_sync           = { fr = "Synchronisation raid",                         en = "Raid synchronization" },
    raid_sync_desc      = { fr = "Envoie tes callouts custom à tous les membres du raid qui ont SolaryM.", en = "Send your custom callouts to all raid members who have SolaryM." },
    img_label           = { fr = "Image à envoyer au raid (dossier Media) :",   en = "Image to send to raid (Media folder):" },
    no_image            = { fr = "Aucune image",    en = "No image" },
    no_image_dash       = { fr = "— Aucune image —",en = "— No image —" },
    refresh_list        = { fr = "Rafraîchir la liste",                          en = "Refresh list" },
    media_info          = { fr = "Place tes images (.tga) dans SolaryM/Media/\net ajoute-les via /sm addmedia <nom>", en = "Place your images (.tga) in SolaryM/Media/\nand add them via /sm addmedia <name>" },
    pending_none        = { fr = "0 changement en attente",                      en = "0 pending changes" },
    pending_one         = { fr = "1 changement en attente",                      en = "1 pending change" },
    pending_ready       = { fr = "prêt à envoyer",  en = "ready to send" },
    pending_multi       = { fr = "changements en attente",                       en = "pending changes" },
    pending_ready_pl    = { fr = "prêts à envoyer", en = "ready to send" },
    btn_broadcast       = { fr = "Envoyer au raid", en = "Send to raid" },
    last_broadcast      = { fr = "Dernier envoi : jamais",                       en = "Last broadcast: never" },
    spell_info          = { fr = "Clique sur un sort pour le sélectionner.\nTrouve les IDs sur wowhead.com/spell=ID", en = "Click on a spell to select it.\nFind IDs on wowhead.com/spell=ID" },
    type_dungeon        = { fr = "DONJON",          en = "DUNGEON" },
    -- SmartCast tab
    smart_header        = { fr = "Mécaniques intelligentes",                     en = "Smart Mechanics" },
    smart_desc          = { fr = "Alertes personnalisées selon ton debuff ou groupe.", en = "Personalized alerts based on your debuff or group." },
    castbar_header      = { fr = "Alertes de cast",                              en = "Cast Alerts" },
    castbar_desc        = { fr = "Alerte texte lors des casts importants du boss.", en = "Text alert on important boss casts." },
    mythic_casts_header = { fr = "Casts adds (M+ & Raid)",                         en = "Add Casts (M+ & Raid)" },
    mythic_casts_desc   = { fr = "Affiche les casts des adds en M+ et en raid (nameplates).", en = "Shows add casts in M+ and raid (nameplates)." },
    mythic_casts_enable = { fr = "Activer les casts adds",                         en = "Enable add casts" },
    mythic_casts_scale  = { fr = "Taille",                                          en = "Size" },
    -- Invites tab
    split_odd_even      = { fr = "⚡ Split Impairs / Pairs",                     en = "⚡ Split Odd / Even" },
    split_halves        = { fr = "⚡ Split Moitié / Moitié",                     en = "⚡ Split Halves / Halves" },
    split_info          = { fr = "Raid 10/25 → Impairs (1/3/5) vs Pairs (2/4/6)   |   Mythic 20 → 1/3 vs 2/4", en = "Raid 10/25 → Odd (1/3/5) vs Even (2/4/6)   |   Mythic 20 → 1/3 vs 2/4" },
    group_a             = { fr = "Groupe A",        en = "Group A" },
    group_b             = { fr = "Groupe B",        en = "Group B" },
    autoinvite          = { fr = "Auto-invite",     en = "Auto-invite" },
    autoinvite_desc     = { fr = "Invite quand quelqu'un écrit un mot-clé en whisper ou chat guilde.", en = "Invite when someone writes a keyword in whisper or guild chat." },
    btn_enable          = { fr = "Activer",         en = "Enable" },
    btn_disable         = { fr = "Désactiver",      en = "Disable" },
    keywords            = { fr = "Mots-clés :",     en = "Keywords:" },
    guild_rank          = { fr = "Inviter par rang de guilde",                   en = "Invite by guild rank" },
    guild_rank_desc     = { fr = "Clique sur les rangs à inviter (membres en ligne uniquement).", en = "Click on ranks to invite (online members only)." },
    btn_load_ranks      = { fr = "Charger les rangs",                            en = "Load ranks" },
    btn_invite_sel      = { fr = "Inviter la sélection",                         en = "Invite selection" },
    not_in_guild        = { fr = "Pas en guilde — ouvre le panneau guilde d'abord.", en = "Not in guild — open the guild panel first." },
    -- Versions tab
    vc_title            = { fr = "VERSION CHECK",                                    en = "VERSION CHECK" },
    vc_subtitle         = { fr = "Version actuelle : ",                              en = "Current version: " },
    vc_check_btn        = { fr = "Vérifier raid / guilde",                          en = "Check raid / guild" },
    vc_clear_btn        = { fr = "Effacer",                                          en = "Clear" },
    vc_sending          = { fr = "Requête envoyée — réponses attendues dans 5s...", en = "Request sent — waiting for responses (5s)..." },
    vc_members          = { fr = "membres",                                          en = "members" },
    vc_section_raid     = { fr = "RAID",                                             en = "RAID" },
    vc_section_guild    = { fr = "GUILDE",                                           en = "GUILD" },
    vc_uptodate         = { fr = "À JOUR",                                           en = "UP TO DATE" },
    vc_outdated         = { fr = "OUTDATED",                                         en = "OUTDATED" },
    vc_missing          = { fr = "NON INSTALLÉ",                                     en = "NOT INSTALLED" },
    -- Settings tab
    alerts_enabled      = { fr = "Afficher les alertes de mécaniques",           en = "Show mechanic alerts" },
    alerts_desc         = { fr = "Active le cadre visuel qui s'affiche lors d'une alerte de sort ou de mécanique.", en = "Enables the visual frame that appears when a spell or mechanic alert shows." },
    prealert_label      = { fr = "Pré-alerte alertes boss (sec avant cast) :",   en = "Boss alert pre-alert (sec before cast):" },
    paw_label           = { fr = "Repositionner le texte des Private Auras au centre", en = "Reposition Private Aura text to center" },
    paw_scale           = { fr = "Taille : ",       en = "Size: " },
    pa_sounds           = { fr = "Sons Private Auras",                           en = "Private Aura Sounds" },
    pa_defaults         = { fr = "Utiliser les sons par défaut (Midnight S1 Raid)", en = "Use default sounds (Midnight S1 Raid)" },
    btn_edit_pa         = { fr = "Editer les sons Private Auras",                en = "Edit Private Aura Sounds" },
    frames_pos          = { fr = "Position des cadres",                          en = "Frame positions" },
    frames_cmd          = { fr = "/sm move déplace et reverrouille (toggle)",    en = "/sm move to move and toggle lock" },
    btn_lock            = { fr = "Verrouiller",     en = "Lock" },
    btn_move            = { fr = "Déplacer",        en = "Move" },
    alert_appearance    = { fr = "Apparence des alertes",                        en = "Alert appearance" },
    alert_width         = { fr = "Largeur",         en = "Width" },
    alert_fontsize      = { fr = "Taille texte",    en = "Font size" },
    status_lbl          = { fr = "Statut",          en = "Status" },
    editor_lbl          = { fr = "Éditeur",         en = "Editor" },
    reception_lbl       = { fr = "Réception",       en = "Listener" },
    spells_loaded       = { fr = "sorts chargés",   en = "spells loaded" },
    break_timer         = { fr = "Break Timer",     en = "Break Timer" },
    break_desc          = { fr = "Lance un break pour tout le raid avec image et compte à rebours.", en = "Launch a break for the whole raid with image and countdown." },
    random_lbl          = { fr = "Aléatoire",       en = "Random" },
    btn_launch_break    = { fr = "Lancer le break", en = "Launch break" },
    -- PA Sounds window
    pa_win_title        = { fr = "Sons Private Auras",                           en = "Private Aura Sounds" },
    btn_close           = { fr = "Fermer",          en = "Close" },
    col_spell           = { fr = "SORT",            en = "SPELL" },
    col_sound           = { fr = "SON",             en = "SOUND" },
    no_sound            = { fr = "(aucun)",         en = "(none)" },
    pa_empty            = { fr = "Aucun son configuré. Active les sons par défaut dans Paramètres.", en = "No sounds configured. Enable default sounds in Settings." },
    btn_delete_all      = { fr = "Tout supprimer",  en = "Delete all" },
    invalid_spellid     = { fr = "SpellID invalide.", en = "Invalid SpellID." },
}

function SM.T(key)
    local s = SM.Strings[key]
    if not s then return key end
    return SM.LANG == "fr" and (s.fr or s.en) or (s.en or s.fr)
end

function SM.SetLang(lang)
    SM.LANG = lang
    SolaryMDB.lang = lang
end

function SM.L(key)
    -- `key` est un callout qui peut être en EN ou FR selon la DB
    -- On retourne la version dans la langue courante si disponible
    local spell = SM.GetSpellByCallout and SM.GetSpellByCallout(key)
    if spell then
        return SM.LANG == "fr" and spell.fr or spell.en
    end
    return key
end

-- ============================================================
-- INIT
-- ============================================================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end

    SolaryMDB = SolaryMDB or {}
    -- Appliquer la préférence de langue sauvegardée (override du client)
    if SolaryMDB.lang then SM.LANG = SolaryMDB.lang end
    SolaryMDB.spells        = SolaryMDB.spells        or {}
    SolaryMDB.spellIdRemap  = SolaryMDB.spellIdRemap  or {}
    SolaryMDB.customSpells  = SolaryMDB.customSpells  or {}
    SolaryMDB.groups       = SolaryMDB.groups       or {}
    SolaryMDB.invite       = SolaryMDB.invite       or { keywords = { "inv", "+1" }, ranks = {} }
    SolaryMDB.alert        = SolaryMDB.alert        or { threshold = 8, sounds = true }
    SolaryMDB.auras        = SolaryMDB.auras        or {}
    SolaryMDB.notes        = SolaryMDB.notes        or { raw = "", groups = {}, mechConfigs = {}, dispelConfigs = {}, version = 0 }
    SolaryMDB.assignments  = SolaryMDB.assignments  or {}
    SolaryMDB.boss_timers  = SolaryMDB.boss_timers  or { enabled = true, prealert_sec = 5 }
    SolaryMDB.frames       = SolaryMDB.frames       or {}  -- positions des cadres déplaçables
    -- Tailles persitées (fontSize, width) dans SolaryMDB.alert et SolaryMDB.notes


    -- Seed la SpellDB dans SolaryMDB.spells
    SM.SeedSpells()
    SM.LoadCustomSpells()

    SM.Print("v" .. SM.VERSION .. " chargé — /sm pour ouvrir le panel | /sm debug pour toggle debug")
    C_Timer.NewTimer(1, SM.CreateMinimapButton)
end)

-- ============================================================
-- ÉTAT GLOBAL MODE DÉPLACEMENT
-- ============================================================
SM.MoveMode = false

function SM.UnlockAllFrames()
    -- Boss alerts : seulement si la feature est active
    if SM.ToggleAlertLock and SolaryMDB.alerts_enabled ~= false then
        SM.ToggleAlertLock(false)
    end
    -- Break Timer : pas de toggle global, toujours affiché
    if SM.ToggleBreakLock then SM.ToggleBreakLock(false) end
    -- Cast Alerts : pas de toggle global, toujours affiché
    if SM.CastBar then SM.CastBar.Unlock() end
    if SM.CastBar then SM.CastBar.UnlockConeBar() end
    -- Mythic Casts : seulement si activé
    if SM.MythicCasts and SolaryMDB.mythic_casts_enabled ~= false then
        SM.MythicCasts.Unlock()
    end
    -- Private Warning Text : toujours affiché
    SM.PreviewPrivateWarningText(true)
    -- Reminder Alerts
    if SM.ReminderNote then SM.ReminderNote.UnlockAlerts() end
    -- Memory Game : éditeurs seulement
    if SM.MemoryGame then
        SM.MemoryGame.unlocked = true
        local df = SM.MemoryGame.BuildDisplayFrame()
        df:Show()
        SM.Print("Memory Game : déplace la carte, puis /sm move pour verrouiller.")
    end
end

function SM.LockAllFrames()
    if SM.ToggleAlertLock   then SM.ToggleAlertLock(true)   end
    if SM.ToggleBreakLock   then SM.ToggleBreakLock(true)   end
    if SM.CastBar           then SM.CastBar.Lock()          end
    if SM.CastBar           then SM.CastBar.LockConeBar()   end
    if SM.MythicCasts       then SM.MythicCasts.Lock()      end
    if SM.ReminderNote then SM.ReminderNote.LockAlerts() end
    -- Memory Game : reverrouiller + cacher les frames si vides
    SM.PreviewPrivateWarningText(false)
    if SM.MemoryGame then
        SM.MemoryGame.unlocked = false
        local df = SM.MemoryGame.BuildDisplayFrame()
        if not SM.MemoryGame.HasSequence() then df:Hide() end
    end
end

-- ============================================================
-- COMMANDES SLASH
-- ============================================================
SLASH_SOLARYM1 = "/sm"
SLASH_SOLARYM2 = "/solarym"
SlashCmdList["SOLARYM"] = function(msg)
    local m = (msg or ""):lower():trim()

    if m == "debug" then
        SM.DEBUG = not SM.DEBUG
        SM.Print("Debug " .. (SM.DEBUG and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
    elseif m == "mg" or m == "memory" then
        -- Barre de saisie memory game (éditeurs seulement)
        if SM.MemoryGame and SM.IsEditor() then
            SM.MemoryGame.ToggleInputBar()
        elseif not SM.IsEditor() then
            SM.Print("La barre Memory Game est réservée aux éditeurs.")
        end
    elseif m == "mmtest" then
        SM.CreateMinimapButton()
        SM.Print("Minimap button créé")
    elseif m == "mgreset" then
        if SM.MemoryGame then SM.MemoryGame.Reset() end
    elseif m == "mgtest" then
        if SM.MemoryGame then SM.MemoryGame.TestSequence() end
    elseif m == "test" then
            if SM.ShowTimedAlert then SM.ShowTimedAlert("SOAK", "Test Mechanic", 8) end
        SM.PlaySound("soak")
    elseif m == "reset" then
        if SM.BossTimer and SM.BossTimer.Reset then SM.BossTimer.Reset() end
        
    elseif m == "move" then
        -- Toggle : déverrouille ou reverrouille TOUS les cadres d'un coup
        SM.MoveMode = not SM.MoveMode
        if SM.MoveMode then
            if SM.UnlockAllFrames then SM.UnlockAllFrames() end
        else
            if SM.LockAllFrames then SM.LockAllFrames() end
            
        end
    elseif m:match("^addmedia%s+(.+)$") then
        local fname = m:match("^addmedia%s+(.+)$"):gsub("%s+$","")
        SolaryMDB.mediaFiles = SolaryMDB.mediaFiles or {}
        -- Vérifier qu'il n'existe pas déjà
        for _, f in ipairs(SolaryMDB.mediaFiles) do
            if f == fname then SM.Print("'"..fname.."' déjà dans la liste."); return end
        end
        table.insert(SolaryMDB.mediaFiles, fname)
        SM.Print("|cFFFFD700"..fname.."|r ajouté à la liste Media.")
    elseif m == "listmedia" then
        local files = SolaryMDB.mediaFiles or {}
        if #files == 0 then SM.Print("Aucun fichier Media enregistré.") return end
        SM.Print("Fichiers Media : " .. table.concat(files, ", "))
    elseif m == "mcdebug" then
        if SM.MythicCasts and SM.MythicCasts.ToggleDebug then
            SM.MythicCasts.ToggleDebug()
        end
    elseif m:match("^remtest%s+(.+)$") then
        local encID = m:match("^remtest%s+(.+)$")
        if SM.ReminderNote then SM.ReminderNote.TestEncounter(encID) end
    elseif m == "remstop" then
        if SM.ReminderNote then SM.ReminderNote.StopTest() end
    elseif m == "remids" then
        if SM.ReminderNote then
            local ids = SM.ReminderNote.GetEncounterIDs()
            if #ids == 0 then SM.Print("Aucun encID dans la note active.")
            else SM.Print("EncounterIDs : " .. table.concat(ids, ", ")) end
        end
    else
        if SM.OpenPanel then SM.OpenPanel() end
    end
end

-- ============================================================
-- BOUTON MINIMAP
-- ============================================================
local minimapBtn = nil

function SM.CreateMinimapButton()
    if minimapBtn then return end

    local icon = LibStub and LibStub("LibDataBroker-1.1", true)
    local dbicon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not icon or not dbicon then
        SM.Print("LibDBIcon introuvable")
        return
    end

    local ldb = icon:NewDataObject("SolaryM", {
        type  = "launcher",
        icon  = "Interface\\AddOns\\SolaryM\\Media\\solary_icon.png",
        label = "SolaryM",
        OnClick = function(self, btn)
            if btn == "LeftButton" and SM.TogglePanel then
                SM.TogglePanel()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("SolaryM", SM.OR[1], SM.OR[2], SM.OR[3])
            tt:AddLine("Clic pour ouvrir/fermer", 0.7, 0.7, 0.7)
        end,
    })

    SolaryMDB.minimap = SolaryMDB.minimap or {}
    dbicon:Register("SolaryM", ldb, SolaryMDB.minimap)
    minimapBtn = dbicon:GetMinimapButton("SolaryM")
end

-- Créer au login

