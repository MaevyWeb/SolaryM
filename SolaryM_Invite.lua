-- SolaryM_Invite.lua — Auto-invite par rang de guilde

SM.Invite = SM.Invite or {}
local autoInviteEnabled = false

local chatFrame = CreateFrame("Frame")
chatFrame:SetScript("OnEvent", function(self, event, message, sender)
    if not autoInviteEnabled then return end
    if not SM.IsEditor() then return end
    local keywords = SolaryMDB.invite and SolaryMDB.invite.keywords or {"inv","+1"}
    local msg = strtrim(message:lower())
    for _, kw in ipairs(keywords) do
        if msg == strtrim(kw:lower()) then
            if sender and sender ~= UnitName("player") then
                C_PartyInfo.InviteUnit(sender)
                SM.Print("Invité : |cFFFFD700"..sender.."|r")
            end
            return
        end
    end
end)

function SM.Invite.SetAutoInvite(enabled)
    autoInviteEnabled = enabled
    SM.Print("Auto-invite : "..(enabled and "|cFF55FF55ON|r" or "|cFFFF4444OFF|r"))
end

function SM.Invite.IsAutoInviteEnabled() return autoInviteEnabled end

function SM.Invite.GetGuildRanks()
    local ranks = {}
    local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    for i = 1, n do
        local name = GuildControlGetRankName and GuildControlGetRankName(i)
        if name and name ~= "" then table.insert(ranks, {index=i, name=name}) end
    end
    return ranks
end

local _convertFrame = CreateFrame("Frame")
_convertFrame:SetScript("OnEvent", function(self)
    if not SM.Invite._pendingConvert then return end
    if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") then
        C_PartyInfo.ConvertToRaid()
        SM.Invite._pendingConvert = false
    end
end)

function SM.Invite.InviteByRanks(rankIndices)
    if not SM.IsEditor() then SM.Print("Tu n'as pas les droits.") return end
    if #rankIndices == 0 then SM.Print("Sélectionne au moins un rang.") return end
    C_GuildInfo.GuildRoster()
    C_Timer.After(1, function()
        local total   = GetNumGuildMembers()
        local invited = 0
        local myName  = UnitName("player")
        local targets = {}
        for _, ri in ipairs(rankIndices) do targets[ri-1] = true end
        for i = 1, total do
            local name, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and name and targets[rankIndex] then
                local short = name:match("^([^%-]+)") or name
                if short ~= myName then
                    C_PartyInfo.InviteUnit(name)
                    invited = invited + 1
                end
            end
        end
        SM.Print("|cFFFFD700"..invited.."|r invitation(s) envoyée(s).")
        if invited > 0 then
            SM.Invite._pendingConvert = true
            _convertFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        end
    end)
end

-- RegisterEvent dans PLAYER_ENTERING_WORLD (CHAT_MSG protégé)
local _invitePEW = CreateFrame("Frame")
_invitePEW:RegisterEvent("PLAYER_ENTERING_WORLD")
_invitePEW:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_ENTERING_WORLD" then return end
    chatFrame:RegisterEvent("CHAT_MSG_WHISPER")
    chatFrame:RegisterEvent("CHAT_MSG_GUILD")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
