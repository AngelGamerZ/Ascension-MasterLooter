-- Lightweight version discovery over the shared 3.3.5a addon transport.
local _, GA = ...

local VersionCheck = {
    participants = {}, broadcastInterval = 15, acknowledgementInterval = 5,
    staleAfter = 300, lastBroadcast = -1000, lastAcknowledgement = {},
    minimumBroadcastInterval = 2, maxParticipants = 80,
}
GA.VersionCheck = VersionCheck

local function now() return (GetTime and GetTime()) or 0 end
local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end

local function isGroupMember(name)
    local wanted = baseName(name)
    if wanted == "" then return false end
    for unit in GA.Compat:IterateGroupUnits() do
        if baseName(GA.Compat:UnitFullName(unit)) == wanted then return true end
    end
    return false
end

local function validFields(fields)
    local version, protocol, addon = tostring(fields[1] or ""), tonumber(fields[2]), tostring(fields[3] or "")
    if #version == 0 or #version > 32 or not protocol or protocol < 0 or protocol > 65535 or
        protocol ~= math.floor(protocol) or #addon == 0 or #addon > 32 then return nil end
    return version, protocol, addon
end

function VersionCheck:Prune()
    local cutoff, count = now() - self.staleAfter, 0
    for key, entry in pairs(self.participants) do
        if entry.lastSeen < cutoff or not isGroupMember(entry.name) then self.participants[key] = nil else count = count + 1 end
    end
    for key, timestamp in pairs(self.lastAcknowledgement) do
        if now() - timestamp > self.staleAfter or not self.participants[key] then self.lastAcknowledgement[key] = nil end
    end
    return count
end

local function update(sender, fields, response)
    if not isGroupMember(sender) then return false end
    local version, protocol, addon = validFields(fields)
    if not version then return false end
    local count = VersionCheck:Prune()
    local key = baseName(sender)
    if not VersionCheck.participants[key] and count >= VersionCheck.maxParticipants then return false end
    local entry = VersionCheck.participants[key] or { name = sender }
    entry.name, entry.version = sender, version
    entry.protocol, entry.addon = protocol, addon
    entry.lastSeen, entry.response = now(), response
    VersionCheck.participants[key] = entry
    GA.Events:Emit("GA_VERSION_UPDATED", entry)
    GA.Events:Emit("GA_VERSION_LIST_UPDATED", VersionCheck.participants)
    return true
end

function VersionCheck:GetPlayer(name) return self.participants[baseName(name)] end

function VersionCheck:GetParticipants(includeStale)
    if not includeStale then self:Prune() end
    local result, cutoff = {}, now() - self.staleAfter
    for _, entry in pairs(self.participants) do
        if includeStale or entry.lastSeen >= cutoff then result[#result + 1] = entry end
    end
    table.sort(result, function(a, b) return baseName(a.name) < baseName(b.name) end)
    return result
end

function VersionCheck:Broadcast(force)
    local current = now()
    local interval = force and self.minimumBroadcastInterval or self.broadcastInterval
    if current - self.lastBroadcast < interval then return false, "rate limited" end
    if not GA.Compat:IsInGroup() then return false, "not in a group" end
    local packet, err = GA.Comm:Send("HELLO", { GA.VERSION or "0", GA.PROTOCOL_VERSION or 1, GA.ADDON_NAME or "MasterLooter" })
    if not packet then return false, err end
    self.lastBroadcast = current
    return true
end

function VersionCheck:OnHello(fields, sender)
    if not isGroupMember(sender) or not update(sender, fields, "HELLO") then return end
    local key, current = baseName(sender), now()
    if current - (self.lastAcknowledgement[key] or -1000) < self.acknowledgementInterval then return end
    self.lastAcknowledgement[key] = current
    GA.Comm:Send("HELLO_ACK", { GA.VERSION or "0", GA.PROTOCOL_VERSION or 1, GA.ADDON_NAME or "MasterLooter" }, "WHISPER", sender)
end

function VersionCheck:OnHelloAck(fields, sender)
    if not isGroupMember(sender) then return end
    update(sender, fields, "HELLO_ACK")
end

function VersionCheck:ScheduleBroadcast()
    if self.broadcastScheduled then return end
    self.broadcastScheduled = true
    GA.Compat:After(1, function()
        VersionCheck.broadcastScheduled = false
        VersionCheck:Broadcast(false)
    end)
end

function VersionCheck:OnInitialize()
    GA.Comm:RegisterHandler("HELLO", function(fields, sender) VersionCheck:OnHello(fields, sender) end)
    GA.Comm:RegisterHandler("HELLO_ACK", function(fields, sender) VersionCheck:OnHelloAck(fields, sender) end)
    GA.Events:On("PLAYER_LOGIN", function() VersionCheck:ScheduleBroadcast() end, self)
    GA.Events:On("PARTY_MEMBERS_CHANGED", function() VersionCheck:ScheduleBroadcast() end, self)
    GA.Events:On("RAID_ROSTER_UPDATE", function() VersionCheck:ScheduleBroadcast() end, self)
    GA.Events:RegisterGameEvent("PLAYER_LOGIN")
    GA.Events:RegisterGameEvent("PARTY_MEMBERS_CHANGED")
    GA.Events:RegisterGameEvent("RAID_ROSTER_UPDATE")
    return true
end

GA:RegisterModule("VersionCheck", VersionCheck)
