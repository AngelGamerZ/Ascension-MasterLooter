-- MasterLooter communication transport (WoW 3.3.5a / Lua 5.1).
-- This is intentionally self-contained: no serializer or addon library is required.

local addonName, GA = ...
GA = GA or _G.MasterLooter
if not GA then
    GA = {}
    _G.MasterLooter = GA
end

local Comm = GA.Comm or {}
GA.Comm = Comm

Comm.PREFIX = "MLOOT335" -- WoW 3.3.5a limits addon prefixes to 16 bytes.
Comm.PROTOCOL_VERSION = 1
Comm.MAX_CHUNK_BYTES = 210
Comm.MAX_PARTS = 64
Comm.MAX_PAYLOAD_BYTES = Comm.MAX_CHUNK_BYTES * Comm.MAX_PARTS
Comm.MAX_PACKET_ID_BYTES = 64
Comm.MAX_ACTIVE_PACKETS = 64
Comm.MAX_ACTIVE_PER_SENDER = 8
Comm.MAX_BUFFERED_PER_SENDER = 32768
Comm.MAX_SEEN_PACKETS = 512
Comm.MAX_SEEN_PER_SENDER = 64
Comm.FRAGMENT_TIMEOUT = 15
Comm.DEDUPE_TIMEOUT = 90
Comm.handlers = Comm.handlers or {}
Comm.fragments = Comm.fragments or {}
Comm.seen = Comm.seen or {}
Comm.counter = Comm.counter or 0

local floor = math.floor
local tinsert = table.insert
local concat = table.concat
local sub = string.sub
local byte = string.byte
local GetTimeSafe = GetTime or function() return os.time() end

local function emit(event, ...)
    local events = GA.Events
    if not events then return end
    if type(events.Fire) == "function" then
        events:Fire(event, ...)
    elseif type(events.Emit) == "function" then
        events:Emit(event, ...)
    elseif type(events.Trigger) == "function" then
        events:Trigger(event, ...)
    end
end

-- Netstrings are binary/UTF-8 safe and do not reserve a delimiter byte in values.
local function pack(values)
    local result = {}
    for i = 1, #values do
        local value = values[i]
        if value == nil then value = "" else value = tostring(value) end
        result[#result + 1] = tostring(#value)
        result[#result + 1] = "#"
        result[#result + 1] = value
    end
    return concat(result)
end

local function unpackNetstrings(payload)
    local values, cursor, size = {}, 1, #payload
    while cursor <= size do
        local marker = string.find(payload, "#", cursor, true)
        if not marker then return nil, "missing length marker" end
        local lengthText = sub(payload, cursor, marker - 1)
        if lengthText == "" or string.find(lengthText, "[^0-9]") then
            return nil, "invalid field length"
        end
        local length = tonumber(lengthText)
        if not length or length > 65535 then return nil, "field too large" end
        local first, last = marker + 1, marker + length
        if last > size then return nil, "truncated field" end
        values[#values + 1] = sub(payload, first, last)
        cursor = last + 1
    end
    return values
end

local function normalizedName(name)
    if type(name) ~= "string" then return "unknown" end
    return string.lower((string.match(name, "^[^-]+") or name))
end

local function localName()
    return (UnitName and UnitName("player")) or "player"
end

local function makePacketID()
    Comm.counter = Comm.counter + 1
    local now = floor(GetTimeSafe() * 1000)
    local name = string.gsub(normalizedName(localName()), "[^A-Za-z0-9]", "")
    if name == "" then name = "player" end
    return name .. "." .. tostring(now) .. "." .. tostring(Comm.counter)
end

local function defaultChannel(target)
    if target then return "WHISPER" end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

function Comm:RegisterHandler(messageType, callback)
    if type(messageType) ~= "string" or type(callback) ~= "function" then return false end
    self.handlers[messageType] = self.handlers[messageType] or {}
    tinsert(self.handlers[messageType], callback)
    return true
end

function Comm:UnregisterHandler(messageType, callback)
    local handlers = self.handlers[messageType]
    if not handlers then return end
    for i = #handlers, 1, -1 do
        if handlers[i] == callback then table.remove(handlers, i) end
    end
end

function Comm:Send(messageType, fields, channel, target)
    if type(messageType) ~= "string" or messageType == "" then return nil, "invalid message type" end
    if not SendAddonMessage then return nil, "SendAddonMessage is unavailable" end
    channel = channel or defaultChannel(target)
    if not channel and UnitName then
        channel, target = "WHISPER", UnitName("player")
    end
    if not channel then return nil, "not in a group" end

    fields = fields or {}
    local values = { messageType }
    for i = 1, #fields do values[#values + 1] = fields[i] end
    local payload = pack(values)
    if #payload > self.MAX_PAYLOAD_BYTES then return nil, "encoded payload exceeds transport limit" end
    local packetID = makePacketID()
    local total = math.max(1, math.ceil(#payload / self.MAX_CHUNK_BYTES))
    if total > self.MAX_PARTS then return nil, "encoded payload has too many fragments" end

    for part = 1, total do
        local first = ((part - 1) * self.MAX_CHUNK_BYTES) + 1
        local chunk = sub(payload, first, first + self.MAX_CHUNK_BYTES - 1)
        local frame = tostring(self.PROTOCOL_VERSION) .. "|" .. packetID .. "|" ..
            tostring(part) .. "|" .. tostring(total) .. "|" .. chunk
        if #frame > 255 then return nil, "encoded frame exceeds 255 bytes" end
        local ok, sendError = pcall(SendAddonMessage, self.PREFIX, frame, channel, target)
        if not ok then return nil, tostring(sendError) end
    end
    return packetID
end

local function dispatch(sender, packetID, payload, channel)
    local values, err = unpackNetstrings(payload)
    if not values or not values[1] or values[1] == "" then
        emit("GA_COMM_ERROR", err or "missing message type", sender)
        return
    end
    local messageType = table.remove(values, 1)
    local handlers = Comm.handlers[messageType]
    if handlers then
        for i = 1, #handlers do
            local ok, callbackError = pcall(handlers[i], values, sender, channel, packetID)
            if not ok then emit("GA_COMM_ERROR", callbackError, sender, messageType) end
        end
    end
    emit("GA_COMM_MESSAGE", messageType, values, sender, channel)
end

function Comm:OnAddonMessage(prefix, frame, channel, sender)
    if prefix ~= self.PREFIX or type(frame) ~= "string" or #frame > 255 then return end
    local version, packetID, partText, totalText, chunk =
        string.match(frame, "^([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
    if tonumber(version) ~= self.PROTOCOL_VERSION or not packetID or #packetID == 0 or
        #packetID > self.MAX_PACKET_ID_BYTES or string.find(packetID, "[^A-Za-z0-9%._%-]") then return end
    local part, total = tonumber(partText), tonumber(totalText)
    if not part or not total or part ~= floor(part) or total ~= floor(total) or part < 1 or total < 1 or
        part > total or total > self.MAX_PARTS or #chunk > self.MAX_CHUNK_BYTES then return end

    local senderKey = normalizedName(sender)
    local key = senderKey .. "\031" .. packetID
    if self.seen[key] then return end
    local entry = self.fragments[key]
    if not entry then
        local globalCount, senderCount, senderBytes = 0, 0, 0
        for _, buffered in pairs(self.fragments) do
            globalCount = globalCount + 1
            if buffered.senderKey == senderKey then
                senderCount = senderCount + 1
                senderBytes = senderBytes + (buffered.bytes or 0)
            end
        end
        if globalCount >= self.MAX_ACTIVE_PACKETS or senderCount >= self.MAX_ACTIVE_PER_SENDER or
            senderBytes + #chunk > self.MAX_BUFFERED_PER_SENDER then return end
        entry = { parts = {}, count = 0, bytes = 0, total = total, touched = GetTimeSafe(), senderKey = senderKey }
        self.fragments[key] = entry
    elseif entry.total ~= total then
        self.fragments[key] = nil
        return
    end
    entry.touched = GetTimeSafe()
    if not entry.parts[part] then
        local senderBytes = 0
        for _, buffered in pairs(self.fragments) do
            if buffered.senderKey == senderKey then senderBytes = senderBytes + (buffered.bytes or 0) end
        end
        if entry.bytes + #chunk > self.MAX_PAYLOAD_BYTES or
            senderBytes + #chunk > self.MAX_BUFFERED_PER_SENDER then
            self.fragments[key] = nil
            return
        end
        entry.parts[part] = chunk
        entry.count = entry.count + 1
        entry.bytes = entry.bytes + #chunk
    end
    if entry.count ~= total then return end

    local assembled = {}
    for i = 1, total do
        if not entry.parts[i] then return end
        assembled[i] = entry.parts[i]
    end
    self.fragments[key] = nil
    local seenCount, senderSeen, oldestKey, oldestTime, oldestSenderKey, oldestSenderTime = 0, 0
    for seenKey, record in pairs(self.seen) do
        local seenTime = type(record) == "table" and record.time or record
        local seenSender = type(record) == "table" and record.senderKey or nil
        seenCount = seenCount + 1
        if not oldestTime or seenTime < oldestTime then oldestTime, oldestKey = seenTime, seenKey end
        if seenSender == senderKey then
            senderSeen = senderSeen + 1
            if not oldestSenderTime or seenTime < oldestSenderTime then oldestSenderTime, oldestSenderKey = seenTime, seenKey end
        end
    end
    if senderSeen >= self.MAX_SEEN_PER_SENDER and oldestSenderKey then self.seen[oldestSenderKey] = nil
    elseif seenCount >= self.MAX_SEEN_PACKETS and oldestKey then self.seen[oldestKey] = nil end
    self.seen[key] = { time = GetTimeSafe(), senderKey = senderKey }
    dispatch(sender, packetID, concat(assembled), channel)
end

function Comm:Cleanup()
    local now = GetTimeSafe()
    for key, entry in pairs(self.fragments) do
        if now - entry.touched > self.FRAGMENT_TIMEOUT then self.fragments[key] = nil end
    end
    for key, record in pairs(self.seen) do
        local timestamp = type(record) == "table" and record.time or record
        if now - timestamp > self.DEDUPE_TIMEOUT then self.seen[key] = nil end
    end
end

function Comm:Initialize()
    if self.initialized then return true end
    if RegisterAddonMessagePrefix then pcall(RegisterAddonMessagePrefix, self.PREFIX) end
    if not CreateFrame then return false end
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            Comm:OnAddonMessage(...)
        elseif event == "PLAYER_LOGIN" and RegisterAddonMessagePrefix then
            pcall(RegisterAddonMessagePrefix, Comm.PREFIX)
        end
    end)
    local elapsedTotal = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 5 then elapsedTotal = 0; Comm:Cleanup() end
    end)
    self.initialized = true
    emit("GA_COMM_READY", self)
    return true
end

Comm.Pack = pack
Comm.Unpack = unpackNetstrings

if type(GA.RegisterModule) == "function" then GA:RegisterModule("Comm", Comm) end
Comm:Initialize()
