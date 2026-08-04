-- Trusted, revisioned synchronization for raid-wide +1 and roll bonuses.
-- Snapshots are atomic and contain data only; no received payload is executed.
local _, GA = ...

local RuleSync = { PROTOCOL = 1, MAX_ENTRIES = 500, applying = false }
GA.RuleSync = RuleSync

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end
local function now() return (type(time) == "function" and time()) or 0 end
local function safeName(name) return type(name) == "string" and name ~= "" and #name <= 64 and not string.find(name, "[^%w%-%._]") end
local function checksum(text)
    local value = 7
    for index = 1, #text do
        value = value * 33 + string.byte(text, index)
        value = value - math.floor(value / 65521) * 65521
    end
    return tostring(value)
end
local function sortedKeys(source)
    local result = {}
    for name in pairs(source or {}) do result[#result + 1] = name end
    table.sort(result)
    return result
end

function RuleSync:GetStore()
    GA.DB.data.ruleSync = type(GA.DB.data.ruleSync) == "table" and GA.DB.data.ruleSync or {}
    local store = GA.DB.data.ruleSync
    store.trusted, store.lastBySender = type(store.trusted) == "table" and store.trusted or {},
        type(store.lastBySender) == "table" and store.lastBySender or {}
    store.revision = tonumber(store.revision) or 0
    return store
end

function RuleSync:SetTrusted(player, trusted)
    local playerKey = key(player)
    if playerKey == "" then return false, "Spielername fehlt" end
    self:GetStore().trusted[playerKey] = trusted and true or nil
    GA.Events:Emit("GA_RULESYNC_TRUST_CHANGED", player, trusted and true or false)
    return true
end

function RuleSync:IsRosterAuthority(player)
    local playerKey = key(player)
    if playerKey == "" then return false end
    if GA.RollSession and type(GA.RollSession.IsAuthority) == "function" then
        local ok, result = pcall(GA.RollSession.IsAuthority, GA.RollSession, player)
        if ok and result then return true end
    end
    if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
        for index = 1, (GetNumRaidMembers() or 0) do
            local name, rank = GetRaidRosterInfo(index)
            if key(name) == playerKey then return (tonumber(rank) or 0) > 0 end
        end
    end
    if type(GetNumPartyMembers) == "function" and type(UnitName) == "function" and type(UnitIsPartyLeader) == "function" then
        for index = 0, (GetNumPartyMembers() or 0) do
            local unit = index == 0 and "player" or ("party" .. index)
            if key(UnitName(unit)) == playerKey then return UnitIsPartyLeader(unit) and true or false end
        end
    end
    return false
end

function RuleSync:IsRosterMember(player)
    local playerKey = key(player)
    if playerKey == "" then return false end
    if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
        for index = 1, (GetNumRaidMembers() or 0) do
            if key(GetRaidRosterInfo(index)) == playerKey then return true end
        end
    end
    if type(GetNumPartyMembers) == "function" and type(UnitName) == "function" then
        for index = 0, (GetNumPartyMembers() or 0) do
            local unit = index == 0 and "player" or ("party" .. index)
            if key(UnitName(unit)) == playerKey then return true end
        end
    end
    return false
end

function RuleSync:CanPublish()
    local localName = type(UnitName) == "function" and UnitName("player") or nil
    return self:IsRosterAuthority(localName) or self:GetStore().trusted[key(localName)] == true
end

function RuleSync:IsTrusted(player)
    local playerKey = key(player)
    local localKey = key(UnitName and UnitName("player"))
    if playerKey ~= "" and playerKey == localKey then return true end
    return self:GetStore().trusted[playerKey] == true or self:IsRosterAuthority(player)
end

function RuleSync:BuildPayload()
    local lines = {}
    for _, player in ipairs(sortedKeys(GA.DB.data.plusOnes)) do
        local value = tonumber(GA.DB.data.plusOnes[player])
        if safeName(player) and value and value >= 0 and value <= 1000000 then lines[#lines + 1] = "P\t" .. player .. "\t" .. value end
    end
    for _, player in ipairs(sortedKeys(GA.DB.data.boostedRolls)) do
        local value = tonumber(GA.DB.data.boostedRolls[player])
        if safeName(player) and value and value >= -100 and value <= 100 then lines[#lines + 1] = "B\t" .. player .. "\t" .. value end
    end
    return table.concat(lines, "\n")
end

function RuleSync:ParsePayload(payload)
    if type(payload) ~= "string" or #payload > 12000 then return nil, "Snapshot ist zu groß" end
    local plus, boosts, count = {}, {}, 0
    for line in string.gmatch(payload .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            count = count + 1
            if count > self.MAX_ENTRIES then return nil, "Zu viele Regelwerte" end
            local kind, player, value = string.match(line, "^([PB])\t([^\t]+)\t([^\t]+)$")
            value = tonumber(value)
            if not kind or not safeName(player) or not value or value ~= math.floor(value) then return nil, "Ungültiger Datensatz" end
            player = key(player)
            if kind == "P" and value >= 0 and value <= 1000000 then plus[player] = value ~= 0 and value or nil
            elseif kind == "B" and value >= -100 and value <= 100 then boosts[player] = value ~= 0 and value or nil
            else return nil, "Wert außerhalb des Bereichs" end
        end
    end
    return { plusOnes = plus, boostedRolls = boosts, count = count }
end

function RuleSync:SendSnapshot(channel, target)
    if not GA.Comm or not self:CanPublish() then return nil, "Lokaler Spieler darf keine Regeldaten veröffentlichen" end
    local store, payload = self:GetStore(), self:BuildPayload()
    store.revision = store.revision + 1
    local packet, err = GA.Comm:Send("RS_SNAP", { self.PROTOCOL, store.revision, checksum(payload), payload }, channel, target)
    if packet then GA.Events:Emit("GA_RULESYNC_SENT", target, store.revision) end
    return packet, err
end

function RuleSync:Request(player)
    if not GA.Comm or key(player) == "" then return nil, "Spieler fehlt" end
    return GA.Comm:Send("RS_REQ", { self.PROTOCOL, tostring(now()) }, "WHISPER", player)
end

function RuleSync:ReceiveSnapshot(fields, sender)
    if not self:IsTrusted(sender) then GA.Events:Emit("GA_RULESYNC_REJECTED", sender, "UNTRUSTED"); return false, "Nicht vertrauenswürdig" end
    local protocol, revision, expected, payload = tonumber(fields[1]), tonumber(fields[2]), fields[3], fields[4]
    if protocol ~= self.PROTOCOL or not revision or revision < 1 or checksum(payload or "") ~= expected then
        GA.Events:Emit("GA_RULESYNC_REJECTED", sender, "INVALID"); return false, "Ungültiger Snapshot"
    end
    local store, senderKey = self:GetStore(), key(sender)
    local previous = store.lastBySender[senderKey]
    if previous and revision < previous.revision then return false, "Veralteter Snapshot" end
    if previous and revision == previous.revision then
        if previous.checksum == expected then return false, "Bereits angewendet" end
        GA.Events:Emit("GA_RULESYNC_CONFLICT", sender, revision); return false, "Revisionskonflikt"
    end
    local parsed, err = self:ParsePayload(payload)
    if not parsed then GA.Events:Emit("GA_RULESYNC_REJECTED", sender, err); return false, err end
    self.applying = true
    GA.DB.data.plusOnes, GA.DB.data.boostedRolls = parsed.plusOnes, parsed.boostedRolls
    store.lastBySender[senderKey] = { revision = revision, checksum = expected, at = now() }
    GA.Events:Emit("GA_RULESYNC_APPLIED", sender, revision, parsed.count)
    GA.Events:Emit("GA_PLUSONE_RESET", "RULE_SYNC")
    GA.Events:Emit("GA_BOOST_RESET", "RULE_SYNC")
    self.applying = false
    return true, parsed.count
end

function RuleSync:OnLocalChange()
    if self.applying or not self:CanPublish() then return end
    self:SendSnapshot()
end

function RuleSync:OnInitialize()
    self:GetStore()
    if GA.Comm then
        GA.Comm:RegisterHandler("RS_REQ", function(fields, sender)
            if tonumber(fields[1]) == RuleSync.PROTOCOL and RuleSync:CanPublish() and RuleSync:IsRosterMember(sender) then
                RuleSync:SendSnapshot("WHISPER", sender)
            end
        end)
        GA.Comm:RegisterHandler("RS_SNAP", function(fields, sender) RuleSync:ReceiveSnapshot(fields, sender) end)
    end
    for _, event in ipairs({ "GA_PLUSONE_CHANGED", "GA_PLUSONE_RESET", "GA_BOOST_CHANGED", "GA_BOOST_RESET" }) do
        GA.Events:On(event, function() RuleSync:OnLocalChange() end, self)
    end
    return true
end

GA:RegisterModule("RuleSync", RuleSync)
