-- SolaryM_Groups.lua — Roster, AutoSplit, sous-groupes raid

SM.Groups = SM.Groups or {}

-- ============================================================
-- ROSTER
-- ============================================================
function SM.Groups.GetRoster()
    local members = {}
    local total   = GetNumGroupMembers()

    if IsInRaid() then
        for i = 1, total do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local name, _, subgroup, _, class, fileName = GetRaidRosterInfo(i)
                table.insert(members, {
                    name     = name or UnitName(unit),
                    class    = fileName or select(2, UnitClass(unit)),
                    role     = UnitGroupRolesAssigned(unit),
                    subgroup = subgroup or 0,
                    unit     = unit,
                    isOnline = UnitIsConnected(unit),
                })
            end
        end
    elseif IsInGroup() then
        -- Groupe M+ (party 1-4 + player)
        for i = 1, total - 1 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(members, {
                    name     = UnitName(unit),
                    class    = select(2, UnitClass(unit)),
                    role     = UnitGroupRolesAssigned(unit),
                    subgroup = 1,
                    unit     = unit,
                    isOnline = UnitIsConnected(unit),
                })
            end
        end
    end

    table.insert(members, {
        name     = UnitName("player"),
        class    = select(2, UnitClass("player")),
        role     = UnitGroupRolesAssigned("player"),
        subgroup = IsInRaid() and (select(3, GetRaidRosterInfo(
            (function()
                local myName = UnitName("player")
                for i = 1, GetNumGroupMembers() do
                    if select(1, GetRaidRosterInfo(i)) == myName then return i end
                end
                return 1
            end)()
        )) or 0) or 1,
        unit     = "player",
        isOnline = true,
    })

    return members
end

-- ============================================================
-- SORT PAR RÔLE
-- ============================================================
function SM.Groups.SortByRole()
    local roster = SM.Groups.GetRoster()
    local sorted = { tanks = {}, healers = {}, dps = {} }
    for _, m in ipairs(roster) do
        if m.role == "TANK"   then table.insert(sorted.tanks,   m)
        elseif m.role == "HEALER" then table.insert(sorted.healers, m)
        else                           table.insert(sorted.dps,     m) end
    end
    local sn = function(a, b) return a.name < b.name end
    table.sort(sorted.tanks,   sn)
    table.sort(sorted.healers, sn)
    table.sort(sorted.dps,     sn)
    return sorted
end

-- ============================================================
-- AUTO SPLIT A/B — répartition équilibrée rôles
-- ============================================================
function SM.Groups.AutoSplit(bossKey)
    local sorted = SM.Groups.SortByRole()
    local A, B   = {}, {}

    -- Distribue alternativement : T1→A, T2→B, H1→A…
    local function distrib(list)
        for i, m in ipairs(list) do
            if i % 2 == 1 then table.insert(A, m)
            else               table.insert(B, m) end
        end
    end
    distrib(sorted.tanks)
    distrib(sorted.healers)
    distrib(sorted.dps)

    local key = bossKey or "default"
    SolaryMDB.groups[key] = { A = {}, B = {} }
    for _, m in ipairs(A) do table.insert(SolaryMDB.groups[key].A, m.name) end
    for _, m in ipairs(B) do table.insert(SolaryMDB.groups[key].B, m.name) end

    return SolaryMDB.groups[key]
end

-- ============================================================
-- MOVE PLAYER entre groupes A/B
-- ============================================================
function SM.Groups.MovePlayer(bossKey, playerName, toGroup)
    local key = bossKey or "default"
    if not SolaryMDB.groups[key] then
        return
    end
    for _, grp in ipairs({ "A", "B" }) do
        local list = SolaryMDB.groups[key][grp] or {}
        for i, n in ipairs(list) do
            if n == playerName then
                table.remove(list, i)
                break
            end
        end
    end
    SolaryMDB.groups[key][toGroup] = SolaryMDB.groups[key][toGroup] or {}
    table.insert(SolaryMDB.groups[key][toGroup], playerName)
end

-- ============================================================
-- GROUPES IMPAIRS/PAIRS (pour soak rotation raid)
-- ============================================================
function SM.Groups.GetOddGroups()
    if not IsInRaid() then return {} end
    local seen = {}
    for i = 1, GetNumGroupMembers() do
        local _, _, subgroup = GetRaidRosterInfo(i)
        if subgroup and (subgroup % 2 == 1) then seen[subgroup] = true end
    end
    local t = {}
    for g in pairs(seen) do table.insert(t, g) end
    table.sort(t)
    return t
end

function SM.Groups.GetEvenGroups()
    if not IsInRaid() then return {} end
    local seen = {}
    for i = 1, GetNumGroupMembers() do
        local _, _, subgroup = GetRaidRosterInfo(i)
        if subgroup and (subgroup % 2 == 0) then seen[subgroup] = true end
    end
    local t = {}
    for g in pairs(seen) do table.insert(t, g) end
    table.sort(t)
    return t
end

function SM.Groups.GetMySubgroup()
    if not IsInRaid() then return nil end
    local myName = UnitName("player")
    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name == myName then
            return subgroup
        end
    end
    return nil
end

-- Est-ce que je suis dans un groupe impair ?
function SM.Groups.IsMeInOddGroup()
    local sg = SM.Groups.GetMySubgroup()
    return sg and (sg % 2 == 1) or false
end

-- Format liste de groupes : {1,3,5} → "1/3/5"
function SM.Groups.FormatGroups(groups)
    return table.concat(groups, "/")
end

-- ============================================================
-- CONTEXTE M+ vs RAID
-- ============================================================
function SM.Groups.IsInMythicPlus()
    local _, _, difficulty = GetInstanceInfo()
    -- difficulty 8 = Mythic Keystone (M+)
    return difficulty == 8
end

function SM.Groups.IsInRaidInstance()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "raid"
end

function SM.Groups.GetGroupContext()
    if SM.Groups.IsInMythicPlus() then
        return "mplus"
    elseif SM.Groups.IsInRaidInstance() then
        return "raid"
    elseif IsInGroup() then
        return "party"
    else
        return "solo"
    end
end

-- ============================================================
-- SPLIT IMPAIRS / PAIRS (groupes raid réels)
-- Raid 10/25 : 1/3/5 vs 2/4/6   |   Mythic 20 : 1/3 vs 2/4
-- ============================================================
function SM.Groups.SplitOddEven()
    local key = "default"
    SolaryMDB.groups[key] = { A = {}, B = {} }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name and subgroup then
                if subgroup % 2 == 1 then
                    table.insert(SolaryMDB.groups[key].A, name)
                else
                    table.insert(SolaryMDB.groups[key].B, name)
                end
            end
        end
    else
        return SM.Groups.AutoSplit(key)
    end
    return SolaryMDB.groups[key]
end

-- ============================================================
-- SPLIT MOITIÉS (groupes 1-2-3 vs 4-5-6 / adaptatif Mythic)
-- ============================================================
function SM.Groups.SplitHalves()
    local key = "default"
    SolaryMDB.groups[key] = { A = {}, B = {} }
    if IsInRaid() then
        local usedGroups = {}
        for i = 1, GetNumGroupMembers() do
            local _, _, sg = GetRaidRosterInfo(i)
            if sg then usedGroups[sg] = true end
        end
        local gl = {}
        for g in pairs(usedGroups) do table.insert(gl, g) end
        table.sort(gl)
        local half = math.ceil(#gl / 2)
        local side = {}
        for idx, g in ipairs(gl) do side[g] = idx <= half and "A" or "B" end
        for i = 1, GetNumGroupMembers() do
            local name, _, sg = GetRaidRosterInfo(i)
            if name and sg then
                table.insert(SolaryMDB.groups[key][side[sg] or "A"], name)
            end
        end
    else
        return SM.Groups.AutoSplit(key)
    end
    return SolaryMDB.groups[key]
end

-- Labels lisibles pour le panel (ex: "Grp 1/3/5" / "Grp 2/4/6")
function SM.Groups.GetSplitLabels()
    if not IsInRaid() then return "Rôles A", "Rôles B", "Rôles A", "Rôles B" end
    local usedGroups = {}
    for i = 1, GetNumGroupMembers() do
        local _, _, sg = GetRaidRosterInfo(i)
        if sg then usedGroups[sg] = true end
    end
    local gl = {}
    for g in pairs(usedGroups) do table.insert(gl, g) end
    table.sort(gl)
    local half = math.ceil(#gl / 2)
    local oddL, evenL, loL, hiL = {}, {}, {}, {}
    for idx, g in ipairs(gl) do
        if g % 2 == 1 then table.insert(oddL, g) else table.insert(evenL, g) end
        if idx <= half then table.insert(loL, g) else table.insert(hiL, g) end
    end
    return
        "Grp " .. table.concat(oddL, "/"),
        "Grp " .. table.concat(evenL, "/"),
        "Grp " .. table.concat(loL, "/"),
        "Grp " .. table.concat(hiL, "/")
end
