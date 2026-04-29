-- SolaryM_VersionCheck.lua
-- Version check raid + guilde
-- Affiche tout le monde : ceux qui ont l'addon ET ceux qui ne l'ont pas

SM.VersionCheck = SM.VersionCheck or {}
local VC = SM.VersionCheck

local AceComm   = LibStub and LibStub("AceComm-3.0", true)
local VC_PREFIX = "SolaryMVC"

-- Normalise un nom (retire le realm si présent)
local function NormName(name)
    if not name then return nil end
    return (name:match("^([^%-]+)")) or name
end

VC.responses  = {}   -- [name] = version string
VC.allMembers = {}   -- [name] = true (tous les membres du raid/guilde au moment de la requête)
VC.requestTime = nil
VC.waitTimer   = nil

-- ============================================================
-- COLLECTE DES MEMBRES
-- ============================================================
local function CollectRaidMembers()
    local members = {}
    local n = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, n do
            local name = NormName(UnitName("raid"..i))
            if name then members[name] = true end
        end
    elseif IsInGroup() then
        for i = 1, n-1 do
            local name = NormName(UnitName("party"..i))
            if name then members[name] = true end
        end
        local me = NormName(UnitName("player"))
        if me then members[me] = true end
    end
    return members
end

local function CollectGuildMembers()
    local members = {}
    if not IsInGuild() then return members end
    local n = GetNumGuildMembers()
    for i = 1, n do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online then
            name = name:match("^([^%-]+)") or name
            members[name] = true
        end
    end
    return members
end

-- ============================================================
-- ENVOI / RÉCEPTION
-- ============================================================
function VC.SendRequest()
    if not AceComm then SM.Print("AceComm introuvable."); return end

    wipe(VC.responses)
    VC.requestTime = GetTime()

    -- S'inclure soi-même
    local me = NormName(UnitName("player"))
    if me then VC.responses[me] = SM.VERSION end

    -- Annuler le timer précédent
    if VC.waitTimer then VC.waitTimer:Cancel(); VC.waitTimer = nil end

    -- Collecter tous les membres avec leur source
    VC.allMembers  = {}  -- [name] = "raid" | "guild"
    local raidMembers  = CollectRaidMembers()
    local guildMembers = CollectGuildMembers()
    for name in pairs(raidMembers)  do VC.allMembers[name] = "raid"  end
    for name in pairs(guildMembers) do
        if not VC.allMembers[name] then VC.allMembers[name] = "guild" end
    end
    if me then VC.allMembers[me] = VC.allMembers[me] or "raid" end

    -- Broadcast : RAID en priorité (fonctionne en Midnight), GUILD en complément
    if IsInRaid() then
        AceComm:SendCommMessage(VC_PREFIX, "VER_REQUEST", "RAID")
    elseif IsInGroup() then
        AceComm:SendCommMessage(VC_PREFIX, "VER_REQUEST", "PARTY")
    end
    if IsInGuild() then
        AceComm:SendCommMessage(VC_PREFIX, "VER_REQUEST", "GUILD")
    end

    -- Refresh immédiat puis après 5s (laisser le temps aux réponses d'arriver)
    if VC.RefreshUI then VC.RefreshUI() end
    VC.waitTimer = C_Timer.NewTimer(5, function()
        VC.waitTimer = nil
        if VC.RefreshUI then VC.RefreshUI() end
    end)
end

function VC.SendReply(channel)
    if not AceComm then return end
    local me = NormName(UnitName("player")) or ""
    AceComm:SendCommMessage(VC_PREFIX, "VER_REPLY:"..me..":"..SM.VERSION, channel)
end

local function OnVCMessage(prefix, message, distribution, sender)
    if prefix ~= VC_PREFIX then return end
    local myName = UnitName("player")

    if message == "VER_REQUEST" then
        if NormName(sender) ~= myName then VC.SendReply(distribution) end
    elseif message:match("^VER_REPLY:") then
        local data = message:sub(11)
        local name, ver = data:match("^([^:]+):(.+)$")
        if name and ver then
            VC.responses[NormName(name)] = ver
        else
            VC.responses[NormName(sender)] = data
        end
        if VC.RefreshUI then VC.RefreshUI() end
    end
end

if AceComm then
    AceComm:RegisterComm(VC_PREFIX, OnVCMessage)
end

-- ============================================================
-- CONSTRUCTION DE L'ONGLET
-- ============================================================
function VC.BuildTab(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h); f:Hide()
    SM.BG(f, 0.07, 0.06, 0.10, 1)

    local HDR_H = 44

    -- ── Header ──────────────────────────────────────────────
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetPoint("TOPLEFT"); hdr:SetPoint("TOPRIGHT"); hdr:SetHeight(HDR_H)
    local _hb = hdr:CreateTexture(nil,"BACKGROUND"); _hb:SetAllPoints()
    _hb:SetColorTexture(0.05, 0.04, 0.09, 1)
    local _hs = hdr:CreateTexture(nil,"ARTWORK")
    _hs:SetPoint("BOTTOMLEFT"); _hs:SetPoint("BOTTOMRIGHT"); _hs:SetHeight(1)
    _hs:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.4)

    local title = hdr:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("LEFT", hdr, "LEFT", 12, 0); title:SetTextColor(0.85, 0.80, 1.0, 1)
    title:SetText(SM.T("vc_title"))

    local sub = hdr:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    sub:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 12, 6); sub:SetTextColor(0.45, 0.40, 0.60, 1)
    sub:SetText(SM.T("vc_subtitle")..SM.VERSION)

    local countLbl = hdr:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    countLbl:SetPoint("LEFT", title, "RIGHT", 14, 0)
    countLbl:SetTextColor(SM.OR[1]*0.75, SM.OR[2]*0.65, SM.OR[3]*0.88, 1)
    countLbl:SetText("")
    f._countLbl = countLbl

    local clearBtn = SM.RBtn(hdr, 80, 28, SM.T("vc_clear_btn"), function()
        wipe(VC.responses); wipe(VC.allMembers)
        if VC.RefreshUI then VC.RefreshUI() end
    end)
    clearBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)

    local checkBtn = SM.BBtn(hdr, 170, 28, SM.T("vc_check_btn"), function()
        VC.SendRequest()
        sub:SetText(SM.T("vc_sending"))
        sub:SetTextColor(SM.OR[1], SM.OR[2], SM.OR[3], 1)
        C_Timer.NewTimer(5.5, function()
            sub:SetText(SM.T("vc_subtitle")..SM.VERSION)
            sub:SetTextColor(0.45, 0.40, 0.60, 1)
        end)
    end)
    checkBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)

    -- ── Liste scrollable ─────────────────────────────────────
    local scroll = SM.Scroll(f, w - 4, h - HDR_H - 2)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -HDR_H)
    local sc = scroll.content

    -- ── Refresh ──────────────────────────────────────────────
    function VC.RefreshUI()
        for _, child in ipairs({sc:GetChildren()}) do child:Hide() end

        local ROW_H  = 30
        local SECT_H = 28
        local CW     = sc:GetWidth()
        local ry     = 0
        local count  = 0

        local raidOk, raidOutdated, raidNone   = {}, {}, {}
        local guildOk, guildOutdated, guildNone = {}, {}, {}

        for name, ver in pairs(VC.responses) do
            local src   = (VC.allMembers and VC.allMembers[name]) or "guild"
            local entry = {name=name, ver=ver}
            if ver == SM.VERSION then
                if src == "raid" then table.insert(raidOk, entry)
                else                  table.insert(guildOk, entry) end
            else
                if src == "raid" then table.insert(raidOutdated, entry)
                else                  table.insert(guildOutdated, entry) end
            end
        end
        for name, src in pairs(VC.allMembers or {}) do
            if not VC.responses[name] then
                local entry = {name=name}
                if src == "raid" then table.insert(raidNone, entry)
                else                  table.insert(guildNone, entry) end
            end
        end

        local function sort(t) table.sort(t, function(a,b) return a.name < b.name end) end
        sort(raidOk); sort(raidOutdated); sort(raidNone)
        sort(guildOk); sort(guildOutdated); sort(guildNone)

        local function AddSection(label, n)
            local row = CreateFrame("Frame", nil, sc)
            row:SetSize(CW, SECT_H); row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -ry)
            SM.BG(row, SM.OR[1]*0.14, SM.OR[2]*0.09, SM.OR[3]*0.20, 1)
            local acc = row:CreateTexture(nil,"ARTWORK")
            acc:SetPoint("BOTTOMLEFT"); acc:SetPoint("BOTTOMRIGHT"); acc:SetHeight(1)
            acc:SetColorTexture(SM.OR[1], SM.OR[2], SM.OR[3], 0.3)
            local lbl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            lbl:SetPoint("LEFT", row, "LEFT", 12, 0); lbl:SetTextColor(0.85, 0.80, 1.0, 1)
            lbl:SetText(label)
            local cnt = row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            cnt:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
            cnt:SetTextColor(SM.OR[1]*0.65, SM.OR[2]*0.55, SM.OR[3]*0.80, 1)
            cnt:SetText("("..n..")")
            ry = ry + SECT_H
        end

        local function AddRow(name, ver, statusText, r, g, b)
            count = count + 1
            local row = CreateFrame("Frame", nil, sc)
            row:SetSize(CW, ROW_H); row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -ry)
            local even = (count % 2 == 0)
            SM.BG(row, even and 0.10 or 0.08, even and 0.08 or 0.06, even and 0.16 or 0.12, 1)

            local acc = row:CreateTexture(nil,"ARTWORK")
            acc:SetSize(3, ROW_H); acc:SetPoint("LEFT")
            acc:SetColorTexture(r, g, b, 0.75)

            local nl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            nl:SetPoint("LEFT", row, "LEFT", 12, 0); nl:SetWidth(math.floor(CW * 0.42))
            nl:SetJustifyH("LEFT"); nl:SetTextColor(0.88, 0.84, 0.98, 1); nl:SetText(name)

            local vl = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            vl:SetPoint("LEFT", row, "LEFT", math.floor(CW * 0.46), 0)
            vl:SetWidth(math.floor(CW * 0.28)); vl:SetJustifyH("LEFT")
            vl:SetText(ver or "—"); vl:SetTextColor(r, g, b, 1)

            local sl = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            sl:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            sl:SetJustifyH("RIGHT"); sl:SetText(statusText); sl:SetTextColor(r, g, b, 1)

            ry = ry + ROW_H
        end

        local raidTotal  = #raidOk  + #raidOutdated  + #raidNone
        local guildTotal = #guildOk + #guildOutdated + #guildNone
        local sUpToDate = SM.T("vc_uptodate")
        local sOutdated = SM.T("vc_outdated")
        local sMissing  = SM.T("vc_missing")

        if raidTotal > 0 then
            AddSection(SM.T("vc_section_raid"), raidTotal)
            for _,e in ipairs(raidOk)       do AddRow(e.name, e.ver, sUpToDate, 0.30, 0.85, 0.30) end
            for _,e in ipairs(raidOutdated)  do AddRow(e.name, e.ver, sOutdated, 1.00, 0.55, 0.15) end
            for _,e in ipairs(raidNone)      do AddRow(e.name, "—",   sMissing,  0.85, 0.20, 0.20) end
        end

        if guildTotal > 0 then
            if raidTotal > 0 then ry = ry + 6 end
            AddSection(SM.T("vc_section_guild"), guildTotal)
            for _,e in ipairs(guildOk)       do AddRow(e.name, e.ver, sUpToDate, 0.30, 0.85, 0.30) end
            for _,e in ipairs(guildOutdated)  do AddRow(e.name, e.ver, sOutdated, 1.00, 0.55, 0.15) end
            for _,e in ipairs(guildNone)      do AddRow(e.name, "—",   sMissing,  0.85, 0.20, 0.20) end
        end

        sc:SetHeight(math.max(ry, 1))
        countLbl:SetText(count > 0 and (count.." "..SM.T("vc_members")) or "")
    end

    VC.RefreshUI()
    return f
end
