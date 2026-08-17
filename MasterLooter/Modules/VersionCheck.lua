-- Lightweight version discovery over the shared 3.3.5a addon transport.
local _, GA = ...

local VersionCheck = {
    participants = {}, broadcastInterval = 15, acknowledgementInterval = 5,
    staleAfter = 300, lastBroadcast = -1000, lastAcknowledgement = {},
    minimumBroadcastInterval = 2, maxParticipants = 80, notifiedVersions = {},
    realmChannelName = "MasterLooterVersion", realmProtocol = "MLV1",
    realmQueryLifetime = 20, realmResponseInterval = 8, realmJoinAttempts = 8,
    realmGlobalResponseInterval = 2, realmResponses = {}, realmLastResponse = -1000,
}
GA.VersionCheck = VersionCheck

local function now() return (GetTime and GetTime()) or 0 end
local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end

local VERSION_STAGE = { alpha = 1, beta = 2, rc = 3 }

local function parseVersion(value)
    if type(value) ~= "string" then return nil end
    local normalized = string.lower((string.gsub(value, "^%s*[vV]", "")))
    normalized = string.gsub(normalized, "%s+$", "")
    local major, minor, patch, suffix = string.match(normalized, "^(%d+)%.(%d+)%.(%d+)(.*)$")
    if not major then return nil end
    suffix = string.gsub(suffix or "", "^[%._%-]+", "")
    local stage = suffix == "" and 4 or nil
    for name, weight in pairs(VERSION_STAGE) do
        if string.find(suffix, name, 1, true) then stage = weight; break end
    end
    if not stage then stage = 0 end
    local revision = tonumber(string.match(suffix, "(%d+)")) or 0
    return { tonumber(major), tonumber(minor), tonumber(patch), stage, revision }
end

function VersionCheck:CompareVersions(left, right)
    local a, b = parseVersion(left), parseVersion(right)
    if not a or not b then return nil end
    for index = 1, 5 do
        if a[index] < b[index] then return -1 end
        if a[index] > b[index] then return 1 end
    end
    return 0
end

local function updateNotificationsEnabled()
    if not GA.DB or type(GA.DB.GetProfile) ~= "function" then return true end
    local ok, current = pcall(GA.DB.GetProfile, GA.DB)
    return not ok or type(current) ~= "table" or current.updateNotificationsEnabled ~= false
end

local function localized(key, fallback, ...)
    if type(GA.L) == "function" then
        local ok, value = pcall(GA.L, GA, key, ...)
        if ok and type(value) == "string" and value ~= "" and value ~= key then return value end
    end
    local ok, value = pcall(string.format, fallback, ...)
    return ok and value or fallback
end

local function trace(action, ...)
    if type(GA.Trace) == "function" then GA:Trace("VERSION", action, ...) end
end

local function getChannelID()
    if type(GetChannelName) ~= "function" then return nil end
    local ok, channelID = pcall(GetChannelName, VersionCheck.realmChannelName)
    channelID = ok and tonumber(channelID) or nil
    return channelID and channelID > 0 and channelID or nil
end

local function channelMatches(...)
    local wanted, channelID = string.lower(VersionCheck.realmChannelName), getChannelID()
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if channelID and tonumber(value) == channelID then return true end
        if type(value) == "string" and string.find(string.lower(value), wanted, 1, true) then return true end
    end
    return false
end

local function splitRealmPacket(message)
    if type(message) ~= "string" or #message > 120 then return nil end
    -- A raw pipe starts WoW's chat escape syntax and makes SendChatMessage fail
    -- with "Invalid escape code".  Every protocol field is deliberately
    -- restricted so a colon is safe as the on-wire separator.
    local protocol, kind, version, nonce = string.match(message, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
    if protocol ~= VersionCheck.realmProtocol or (kind ~= "Q" and kind ~= "R") then return nil end
    if not parseVersion(version) or #version > 32 or not string.match(nonce or "", "^[%w%-]+$") or #nonce > 40 then return nil end
    return kind, version, nonce
end

local function sendRealmPacket(kind, version, nonce)
    if type(SendChatMessage) ~= "function" then return false, "SendChatMessage unavailable" end
    local channelID = getChannelID()
    if not channelID then return false, "version channel unavailable" end
    local payload = table.concat({ VersionCheck.realmProtocol, kind, version, nonce }, ":")
    local ok, err = pcall(SendChatMessage, payload, "CHANNEL", nil, channelID)
    trace(ok and "CHANNEL_SENT" or "CHANNEL_SEND_FAILED", kind, version, channelID, err)
    return ok, err
end

function VersionCheck:CheckForUpdate(entry)
    if type(entry) ~= "table" or entry.addon ~= (GA.ADDON_NAME or "MasterLooter") then return false end
    local remote, installed = tostring(entry.version or ""), tostring(GA.VERSION or "0")
    if self:CompareVersions(remote, installed) ~= 1 or self.notifiedVersions[remote] or not updateNotificationsEnabled() then return false end
    self.notifiedVersions[remote] = true
    local message = localized("version.update_available",
        "A new MasterLooter version is available. Installed: %s - Latest detected: %s.", installed, remote)
    if type(GA.Print) == "function" then GA:Print(message) end
    GA.Events:Emit("GA_VERSION_UPDATE_AVAILABLE", remote, installed, entry.name)
    return true
end

function VersionCheck:GetLatestDetectedVersion()
    local latest = tostring(GA.VERSION or "0")
    for _, entry in pairs(self.participants) do
        if entry.addon == (GA.ADDON_NAME or "MasterLooter") and self:CompareVersions(entry.version, latest) == 1 then latest = entry.version end
    end
    if self.realmLatest and self:CompareVersions(self.realmLatest.version, latest) == 1 then latest = self.realmLatest.version end
    return latest
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
    VersionCheck:CheckForUpdate(entry)
    return true
end

function VersionCheck:GetPlayer(name) return self.participants[baseName(name)] end

-- Presence is deliberately short lived. A HELLO from an earlier group must
-- never be treated as proof that the player is still reachable with the addon.
function VersionCheck:HasAddon(name, maximumAge)
    local entry = self:GetPlayer(name)
    maximumAge = math.max(1, math.min(self.staleAfter, tonumber(maximumAge) or self.staleAfter))
    if not entry or not isGroupMember(entry.name) or now() - entry.lastSeen > maximumAge then return false end
    return entry.addon == (GA.ADDON_NAME or "MasterLooter"), entry
end

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

function VersionCheck:SendRealmQuery()
    if not updateNotificationsEnabled() then trace("CHANNEL_DISABLED"); return false, "DISABLED" end
    local stamp = math.floor(now() * 1000)
    local randomPart = type(math.random) == "function" and math.random(1000, 9999) or 1000
    self.realmNonce = tostring(stamp) .. "-" .. tostring(randomPart)
    self.realmQueryAt = now()
    self.realmLatest = nil
    local ok, err = sendRealmPacket("Q", tostring(GA.VERSION or "0"), self.realmNonce)
    trace(ok and "CHANNEL_QUERY" or "CHANNEL_QUERY_FAILED", self.realmNonce, err)
    return ok, err
end

function VersionCheck:StartRealmCheck(attempt)
    attempt = tonumber(attempt) or 1
    if not updateNotificationsEnabled() then trace("CHANNEL_DISABLED"); return false end
    if type(GetChannelName) ~= "function" or type(SendChatMessage) ~= "function" then
        trace("CHANNEL_UNSUPPORTED")
        return false
    end
    if getChannelID() then return self:SendRealmQuery() end
    if attempt == 1 then
        local join = JoinTemporaryChannel or JoinChannelByName
        if type(join) ~= "function" then trace("CHANNEL_JOIN_UNSUPPORTED"); return false end
        local ok, err = pcall(join, self.realmChannelName)
        trace(ok and "CHANNEL_JOIN_REQUESTED" or "CHANNEL_JOIN_FAILED", self.realmChannelName, err)
        if not ok then return false end
    end
    if attempt >= self.realmJoinAttempts then trace("CHANNEL_JOIN_TIMEOUT", self.realmChannelName); return false end
    GA.Compat:After(1, function() VersionCheck:StartRealmCheck(attempt + 1) end)
    return true
end

function VersionCheck:OnRealmMessage(message, sender, ...)
    if not updateNotificationsEnabled() or not channelMatches(...) then return false end
    local kind, version, nonce = splitRealmPacket(message)
    if not kind or baseName(sender) == baseName(UnitName and UnitName("player") or "") then return false end
    if kind == "Q" then
        if self:CompareVersions(tostring(GA.VERSION or "0"), version) ~= 1 then return true end
        local key, current = baseName(sender) .. "|" .. nonce, now()
        if current - (self.realmResponses[key] or -1000) < self.realmResponseInterval then return true end
        if current - self.realmLastResponse < self.realmGlobalResponseInterval then return true end
        local responseCount = 0
        for responseKey, timestamp in pairs(self.realmResponses) do
            if current - timestamp > 60 then self.realmResponses[responseKey] = nil else responseCount = responseCount + 1 end
        end
        if responseCount >= 100 then trace("CHANNEL_RESPONSE_LIMIT"); return true end
        self.realmResponses[key] = current
        self.realmLastResponse = current
        local delay = 0.25 + ((type(math.random) == "function" and math.random(0, 150)) or 0) / 100
        trace("CHANNEL_RESPONSE_SCHEDULED", sender, version, delay)
        GA.Compat:After(delay, function()
            if updateNotificationsEnabled() then sendRealmPacket("R", tostring(GA.VERSION or "0"), nonce) end
        end)
        return true
    end
    if nonce ~= self.realmNonce or now() - (self.realmQueryAt or -1000) > self.realmQueryLifetime then return false end
    if not self.realmLatest or self:CompareVersions(version, self.realmLatest.version) == 1 then
        self.realmLatest = { addon = GA.ADDON_NAME or "MasterLooter", version = version, name = sender, transport = "CHANNEL", lastSeen = now() }
    end
    trace("CHANNEL_RESPONSE", sender, version)
    self:CheckForUpdate(self.realmLatest)
    return true
end

function VersionCheck:OnChannelEvent(_, _, message, sender, ...)
    return self:OnRealmMessage(message, sender, ...)
end

function VersionCheck:IsRealmProtocolMessage(message, ...)
    return splitRealmPacket(message) ~= nil and channelMatches(...)
end

function VersionCheck:OnInitialize()
    GA.Comm:RegisterHandler("HELLO", function(fields, sender) VersionCheck:OnHello(fields, sender) end)
    GA.Comm:RegisterHandler("HELLO_ACK", function(fields, sender) VersionCheck:OnHelloAck(fields, sender) end)
    GA.Events:On("PLAYER_LOGIN", function()
        VersionCheck:ScheduleBroadcast()
        GA.Compat:After(3, function() VersionCheck:StartRealmCheck(1) end)
    end, self)
    GA.Events:On("PARTY_MEMBERS_CHANGED", function() VersionCheck:ScheduleBroadcast() end, self)
    GA.Events:On("RAID_ROSTER_UPDATE", function() VersionCheck:ScheduleBroadcast() end, self)
    GA.Events:RegisterGameEvent("PLAYER_LOGIN")
    GA.Events:RegisterGameEvent("PARTY_MEMBERS_CHANGED")
    GA.Events:RegisterGameEvent("RAID_ROSTER_UPDATE")
    GA.Events:On("CHAT_MSG_CHANNEL", VersionCheck.OnChannelEvent, self)
    GA.Events:RegisterGameEvent("CHAT_MSG_CHANNEL")
    if type(ChatFrame_AddMessageEventFilter) == "function" and not self.realmFilterInstalled then
        self.realmChatFilter = function(_, _, message, ...)
            return VersionCheck:IsRealmProtocolMessage(message, ...)
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", self.realmChatFilter)
        self.realmFilterInstalled = true
    end
    return true
end

GA:RegisterModule("VersionCheck", VersionCheck)
