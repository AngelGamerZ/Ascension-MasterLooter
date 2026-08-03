local _, GA = ...

local RaidManager = { roster = {} }
GA.RaidManager = RaidManager

local function base(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

function RaidManager:CanManage()
    if GA.Compat:IsInRaid() then
        for index = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do
            local name, rank = GetRaidRosterInfo(index)
            if base(name) == base(UnitName("player")) then return rank == 2 or rank == 1 end
        end
        return false
    end
    if type(IsPartyLeader) == "function" then return IsPartyLeader() and true or false end
    if type(UnitIsPartyLeader) == "function" then return UnitIsPartyLeader("player") and true or false end
    return not GA.Compat:IsInGroup()
end

function RaidManager:Refresh()
    local result = {}
    if GA.Compat:IsInRaid() and type(GetRaidRosterInfo) == "function" then
        for index = 1, (GetNumRaidMembers() or 0) do
            local name, rank, subgroup, level, class, classToken, zone, online, dead, role, masterLooter = GetRaidRosterInfo(index)
            result[#result + 1] = { index = index, name = name, rank = rank or 0, subgroup = subgroup or 1,
                level = level, class = class, classToken = classToken, zone = zone, online = online and true or false,
                dead = dead and true or false, role = role, masterLooter = masterLooter and true or false }
        end
    else
        for unit in GA.Compat:IterateGroupUnits() do
            local name = GA.Compat:UnitFullName(unit)
            if name then result[#result + 1] = { index = #result + 1, unit = unit, name = name, rank = 0, subgroup = 1,
                online = type(UnitIsConnected) ~= "function" or UnitIsConnected(unit), dead = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost(unit) or false } end
        end
    end
    table.sort(result, function(a, b)
        if a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end
        return base(a.name) < base(b.name)
    end)
    self.roster = result
    GA.Events:Emit("GA_RAID_ROSTER_UPDATED", result)
    return result
end

function RaidManager:GetRoster() return self.roster end

function RaidManager:Find(player)
    for _, entry in ipairs(self.roster) do if base(entry.name) == base(player) then return entry end end
end

function RaidManager:Invite(name)
    if type(name) ~= "string" or name == "" then return false, "Spielername erforderlich" end
    if type(InviteUnit) ~= "function" then return false, "InviteUnit nicht verfügbar" end
    InviteUnit(name)
    return true
end

function RaidManager:Move(player, subgroup)
    if not self:CanManage() then return false, "Keine Raid-Berechtigung" end
    subgroup = tonumber(subgroup)
    local entry = self:Find(player)
    if not entry or not subgroup or subgroup < 1 or subgroup > 8 then return false, "Ungültiger Spieler oder Gruppe" end
    if type(SetRaidSubgroup) ~= "function" then return false, "SetRaidSubgroup nicht verfügbar" end
    SetRaidSubgroup(entry.index, math.floor(subgroup))
    return true
end

function RaidManager:Promote(player)
    if not self:CanManage() or type(PromoteToAssistant) ~= "function" then return false, "Beförderung nicht verfügbar" end
    PromoteToAssistant(player); return true
end

function RaidManager:Demote(player)
    if not self:CanManage() or type(DemoteAssistant) ~= "function" then return false, "Degradierung nicht verfügbar" end
    DemoteAssistant(player); return true
end

function RaidManager:ConvertToRaid()
    if GA.Compat:IsInRaid() then return false, "Bereits in einem Raid" end
    if not GA.Compat:IsInGroup() or not self:CanManage() then return false, "Nur der Gruppenleiter kann umwandeln" end
    if type(ConvertToRaid) ~= "function" then return false, "ConvertToRaid nicht verfügbar" end
    ConvertToRaid(); return true
end

function RaidManager:Remove(player)
    if not self:CanManage() then return false, "Keine Gruppen-Berechtigung" end
    if type(UninviteUnit) ~= "function" then return false, "UninviteUnit nicht verfügbar" end
    if base(player) == base(UnitName("player")) then return false, "Der eigene Charakter kann hier nicht entfernt werden" end
    UninviteUnit(player); return true
end

function RaidManager:ReadyCheck()
    if not self:CanManage() then return false, "Keine Gruppen-Berechtigung" end
    if type(DoReadyCheck) ~= "function" then return false, "Bereitschaftscheck nicht verfügbar" end
    DoReadyCheck(); return true
end

function RaidManager:OnInitialize()
    GA.Events:On("RAID_ROSTER_UPDATE", function() RaidManager:Refresh() end, self)
    GA.Events:On("PARTY_MEMBERS_CHANGED", function() RaidManager:Refresh() end, self)
    GA.Events:RegisterGameEvent("RAID_ROSTER_UPDATE")
    GA.Events:RegisterGameEvent("PARTY_MEMBERS_CHANGED")
    self:Refresh()
    return true
end

GA:RegisterModule("RaidManager", RaidManager)
