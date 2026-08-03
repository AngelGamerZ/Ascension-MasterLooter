-- Secure, advisory trade handshake. This module only coordinates peers; it
-- never opens, fills or accepts the protected Blizzard trade UI.
local _, GA = ...

local TradeCoordination = {
    PROTOCOL = 1, REQUEST_TTL = 90, PRESENCE_TTL = 300, MAX_TRACKED = 100,
    counter = 0, outbound = {}, inbound = {}, seen = {}, presence = {},
}
GA.TradeCoordination = TradeCoordination

local function now() return (GetTime and GetTime()) or 0 end
local function wallTime() return (time and time()) or 0 end
local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end
local function playerName() return (UnitName and UnitName("player")) or "player" end
local function sameName(left, right) return baseName(left) ~= "" and baseName(left) == baseName(right) end

local function groupMember(name)
    local wanted = baseName(name)
    if wanted == "" then return false end
    for unit in GA.Compat:IterateGroupUnits() do
        if baseName(GA.Compat:UnitFullName(unit)) == wanted then return true end
    end
    return false
end

local function validID(value)
    return type(value) == "string" and #value >= 3 and #value <= 64 and
        not string.find(value, "[^A-Za-z0-9%._%-]")
end

local function capTable(storage, timestampField, maximum)
    local count, oldestKey, oldest = 0
    for key, entry in pairs(storage) do
        count = count + 1
        local stamp = tonumber(entry[timestampField]) or 0
        if not oldest or stamp < oldest then oldest, oldestKey = stamp, key end
    end
    if count >= maximum and oldestKey then storage[oldestKey] = nil end
end

function TradeCoordination:Prune()
    local current = now()
    for key, entry in pairs(self.outbound) do if current > entry.expiresAt then self.outbound[key] = nil end end
    for key, entry in pairs(self.inbound) do if current > entry.expiresAt then self.inbound[key] = nil end end
    for key, entry in pairs(self.seen) do if current - entry.seenAt > self.REQUEST_TTL then self.seen[key] = nil end end
    for key, entry in pairs(self.presence) do
        if current - entry.lastSeen > self.PRESENCE_TTL or not groupMember(entry.name) then self.presence[key] = nil end
    end
end

function TradeCoordination:MarkPresent(name, source)
    if not groupMember(name) then return nil end
    local key = baseName(name)
    if not self.presence[key] then capTable(self.presence, "lastSeen", self.MAX_TRACKED) end
    local entry = self.presence[key] or { name = name }
    entry.name, entry.lastSeen, entry.source = name, now(), source or "TRADE_HANDSHAKE"
    self.presence[key] = entry
    GA.Events:Emit("GA_TRADE_PRESENCE_UPDATED", entry)
    return entry
end

function TradeCoordination:HasAddon(name)
    self:Prune()
    if GA.VersionCheck and GA.VersionCheck.HasAddon then
        local found, entry = GA.VersionCheck:HasAddon(name, self.PRESENCE_TTL)
        if found then return true, entry end
    end
    local entry = self.presence[baseName(name)]
    return entry ~= nil, entry
end

local function makeID()
    TradeCoordination.counter = TradeCoordination.counter + 1
    return baseName(playerName()) .. ".trade." .. tostring(math.floor(now() * 1000)) .. "." .. tostring(TradeCoordination.counter)
end

-- API for the trade module. Returns the tracked request and whether HELLO has
-- already proven that the recipient runs MasterLooter.
function TradeCoordination:Request(name, itemCount)
    if not GA.Compat:IsInGroup() or not groupMember(name) then return nil, "recipient is not in the group" end
    if not GA.RollSession or not GA.RollSession:IsAuthority(playerName()) then return nil, "local player is not loot authority" end
    itemCount = math.max(1, math.min(6, math.floor(tonumber(itemCount) or 1)))
    self:Prune()
    capTable(self.outbound, "createdAt", self.MAX_TRACKED)
    local request = {
        id = makeID(), owner = playerName(), winner = name, itemCount = itemCount,
        createdAt = now(), expiresAt = now() + self.REQUEST_TTL, status = "SENT",
    }
    local packet, sendError = GA.Comm:Send("TRADE_REQUEST", {
        self.PROTOCOL, request.id, request.owner, request.winner, request.itemCount, wallTime() + self.REQUEST_TTL,
    }, "WHISPER", name)
    if not packet then return nil, sendError end
    self.outbound[request.id] = request
    local hasAddon = self:HasAddon(name)
    GA.Events:Emit("GA_TRADE_REQUEST_SENT", request, hasAddon)
    return request, hasAddon
end

function TradeCoordination:OnRequest(fields, sender, channel)
    local protocol, id = tonumber(fields[1]), tostring(fields[2] or "")
    local owner, winner = tostring(fields[3] or ""), tostring(fields[4] or "")
    local itemCount, expiresWall = tonumber(fields[5]), tonumber(fields[6])
    if protocol ~= self.PROTOCOL or not validID(id) or channel ~= "WHISPER" or
        not sameName(sender, owner) or not sameName(winner, playerName()) or not groupMember(sender) or
        not GA.RollSession or not GA.RollSession:IsAuthority(sender) or not itemCount or itemCount < 1 or itemCount > 6 or
        itemCount ~= math.floor(itemCount) or not expiresWall or expiresWall < wallTime() - 5 or
        expiresWall > wallTime() + self.REQUEST_TTL + 10 then return end
    self:Prune()
    local seenKey = "REQUEST:" .. baseName(sender) .. ":" .. id
    if self.seen[seenKey] then return end
    capTable(self.seen, "seenAt", self.MAX_TRACKED)
    self.seen[seenKey] = { seenAt = now() }
    capTable(self.inbound, "createdAt", self.MAX_TRACKED)
    local request = {
        id = id, owner = sender, winner = playerName(), itemCount = itemCount,
        createdAt = now(), expiresAt = now() + math.min(self.REQUEST_TTL, math.max(1, expiresWall - wallTime())),
        status = "RECEIVED",
    }
    self.inbound[id] = request
    self:MarkPresent(sender, "TRADE_REQUEST")
    GA.Events:Emit("GA_TRADE_REQUEST", request)
    -- READY only confirms addon presence and receipt. It does not accept trade.
    GA.Comm:Send("TRADE_READY", { self.PROTOCOL, id, playerName(), owner }, "WHISPER", sender)
end

function TradeCoordination:OnReady(fields, sender, channel)
    local protocol, id = tonumber(fields[1]), tostring(fields[2] or "")
    local winner, owner = tostring(fields[3] or ""), tostring(fields[4] or "")
    if protocol ~= self.PROTOCOL or not validID(id) or channel ~= "WHISPER" or not groupMember(sender) or
        not sameName(sender, winner) or not sameName(owner, playerName()) then return end
    self:Prune()
    local request = self.outbound[id]
    if not request or not sameName(request.winner, sender) or request.status == "READY" then return end
    request.status, request.readyAt = "READY", now()
    self:MarkPresent(sender, "TRADE_READY")
    GA.Events:Emit("GA_TRADE_PEER_READY", request)
end

function TradeCoordination:OnInitialize()
    GA.Comm:RegisterHandler("TRADE_REQUEST", function(fields, sender, channel)
        TradeCoordination:OnRequest(fields, sender, channel)
    end)
    GA.Comm:RegisterHandler("TRADE_READY", function(fields, sender, channel)
        TradeCoordination:OnReady(fields, sender, channel)
    end)
    GA.Events:On("PARTY_MEMBERS_CHANGED", function() TradeCoordination:Prune() end, self)
    GA.Events:On("RAID_ROSTER_UPDATE", function() TradeCoordination:Prune() end, self)
    return true
end

GA:RegisterModule("TradeCoordination", TradeCoordination)
