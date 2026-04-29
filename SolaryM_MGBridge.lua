-- SolaryM_MGBridge.lua
-- Ce frame gère ENCOUNTER_START/END et CHAT_MSG_RAID en contexte load-time propre.
-- RÈGLE : aucun appel vers du code SolaryM dans SetScript/OnUpdate (évite la taint).
-- Chemin combat  : ENCOUNTER_START → timer propre → RegisterEvent → arg1 propre
--                  → tonumber(arg1) → SetTexture(fileDataID).
-- Chemin test    : TestWindow() pose testPending=true (boolean, non-tainté)
--                  → OnUpdate propre lit le flag → RegisterEvent propre.

SolaryM_MGBridge = {
    seq         = 0,
    iconDisplay = {},   -- Texture widgets (SetTexture fonctionne avec fileDataID number)
    numDisplay  = {},
    mainFrame   = nil,
    hideTimer   = nil,
    testPending = false,  -- flag écrit depuis code tainté, lu depuis OnUpdate propre
}

local B = SolaryM_MGBridge

local LURA_ID = 3183
local RUNE_TIMINGS = {
    [14] = {10, 80, 150},
    [15] = {10, 80, 150},
    [16] = {33, 95, 157},
}

local bridgeFrame = CreateFrame("Frame")
bridgeFrame:RegisterEvent("ENCOUNTER_START")
bridgeFrame:RegisterEvent("ENCOUNTER_END")

-- OnUpdate : handler load-time (propre). Permet d'activer le test depuis
-- un contexte propre même si l'appel initial vient de code tainté.
bridgeFrame:SetScript("OnUpdate", function()
    if not B.testPending then return end
    B.testPending = false
    bridgeFrame:RegisterEvent("CHAT_MSG_RAID")
    bridgeFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
end)

bridgeFrame:SetScript("OnEvent", function(_, event, arg1, _, arg3)
    -- ── ENCOUNTER_START ──────────────────────────────────────────
    if event == "ENCOUNTER_START" then
        if arg1 ~= LURA_ID then return end
        local timings = RUNE_TIMINGS[arg3] or RUNE_TIMINGS[15]
        for _, t in ipairs(timings) do
            -- Ces timers sont créés depuis un handler propre → Register propre → arg1 propre
            C_Timer.NewTimer(math.max(0, t - 2), function()
                SolaryM_MGBridge.Reset()
                bridgeFrame:RegisterEvent("CHAT_MSG_RAID")
                bridgeFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
            end)
            C_Timer.NewTimer(t + 15, function()
                bridgeFrame:UnregisterEvent("CHAT_MSG_RAID")
                bridgeFrame:UnregisterEvent("CHAT_MSG_RAID_LEADER")
            end)
        end
        return
    end

    -- ── ENCOUNTER_END ────────────────────────────────────────────
    if event == "ENCOUNTER_END" then
        if arg1 ~= LURA_ID then return end
        bridgeFrame:UnregisterEvent("CHAT_MSG_RAID")
        bridgeFrame:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        C_Timer.NewTimer(3, function() SolaryM_MGBridge.Reset() end)
        return
    end

    -- ── CHAT_MSG_RAID / CHAT_MSG_RAID_LEADER ─────────────────────
    -- SetFormattedText("|T%s:48:48|t", arg1).
    -- Pas de tonumber — on passe arg1 directement
    if not B.mainFrame then return end
    if B.seq >= 5 then return end
    B.seq = B.seq + 1
    local pos = B.seq
    B.iconDisplay[pos]:SetFormattedText("|T%s:256:256|t", arg1)
    B.iconDisplay[pos]:Show()
    B.numDisplay[pos]:SetText(tostring(pos))
    B.numDisplay[pos]:Show()
    B.mainFrame:Show()
    if B.hideTimer then B.hideTimer:Cancel() end
    B.hideTimer = C_Timer.NewTimer(15, function()
        SolaryM_MGBridge.Reset()
    end)
end)

function SolaryM_MGBridge.Reset()
    if B.hideTimer then B.hideTimer:Cancel(); B.hideTimer = nil end
    B.seq = 0
    for i = 1, 5 do
        if B.iconDisplay[i] then B.iconDisplay[i]:Hide() end
        if B.numDisplay[i]  then B.numDisplay[i]:Hide()  end
    end
    if B.mainFrame then B.mainFrame:Hide() end
end

-- Mode test : pose le flag testPending (boolean, pas tainté).
-- OnUpdate (propre, load-time) lit le flag et fait le RegisterEvent depuis
-- un contexte propre → arg1 reçu comme string normale en combat.
function SolaryM_MGBridge.TestWindow()
    SolaryM_MGBridge.Reset()
    B.testPending = true  -- lu par OnUpdate propre au prochain frame
    C_Timer.NewTimer(60, function()
        bridgeFrame:UnregisterEvent("CHAT_MSG_RAID")
        bridgeFrame:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    end)
end

-- Affichage direct (panel hors-combat, pas de secret string)
function SolaryM_MGBridge.ShowRune(fileDataID)
    if not B.mainFrame then return end
    if B.seq >= 5 then return end
    B.seq = B.seq + 1
    local pos = B.seq
    B.iconDisplay[pos]:SetTexture(fileDataID)
    B.iconDisplay[pos]:Show()
    B.numDisplay[pos]:SetText(tostring(pos))
    B.numDisplay[pos]:Show()
    B.mainFrame:Show()
    if B.hideTimer then B.hideTimer:Cancel() end
    B.hideTimer = C_Timer.NewTimer(30, function() SolaryM_MGBridge.Reset() end)
end
