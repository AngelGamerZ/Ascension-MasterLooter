local _, GA = ...

local BagInspector = {
    PROTOCOL = 1, MAX_ENTRIES = 200, MAX_BATCH_BYTES = 8000,
    REQUEST_COOLDOWN = 5, RESPONSE_COOLDOWN = 5,
    snapshots = {}, pending = {}, incoming = {}, requestTimes = {}, responseTimes = {}, counter = 0,
}
GA.BagInspector = BagInspector

local function now() return type(GetTime) == "function" and GetTime() or 0 end
local function timestamp() return type(time) == "function" and time() or 0 end
local function key(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end
local function localName() return type(UnitName) == "function" and UnitName("player") or "player" end

local function groupNames()
    local names = {}
    for unit in GA.Compat:IterateGroupUnits() do
        local name = GA.Compat:UnitFullName(unit) or (type(UnitName) == "function" and UnitName(unit))
        if name then names[key(name)] = name end
    end
    return names
end

local function isGroupMember(name) return groupNames()[key(name)] ~= nil end

local function config()
    local profile = GA.DB:GetProfile()
    if profile.bagInspectorShare == nil then profile.bagInspectorShare = true end
    return profile
end

local function validRequestID(value)
    return type(value) == "string" and #value > 0 and #value <= 80 and not string.find(value, "[^%w%-%._]")
end

function BagInspector:GetPlayers()
    local names, result = groupNames(), {}
    for normalized, name in pairs(names) do
        local snapshot = self.snapshots[normalized]
        result[#result + 1] = { name = name, available = snapshot ~= nil,
            updatedAt = snapshot and snapshot.capturedAt or nil }
    end
    table.sort(result, function(left, right) return key(left.name) < key(right.name) end)
    return result
end

function BagInspector:GetSnapshot(player)
    return self.snapshots[key(player)]
end

function BagInspector:CaptureLocal()
    local entries = {}
    for bag = 0, GA.Compat:GetBagCount() do
        for slot = 1, GA.Compat:GetContainerNumSlots(bag) do
            local link = GA.Compat:GetContainerItemLink(bag, slot)
            if link then
                local info = GA.Compat:GetContainerItemInfo(bag, slot) or {}
                entries[#entries + 1] = { link = link, quantity = math.max(1, tonumber(info.count) or 1),
                    bag = bag, slot = slot }
                if #entries >= self.MAX_ENTRIES then break end
            end
        end
        if #entries >= self.MAX_ENTRIES then break end
    end
    local snapshot = { player = localName(), capturedAt = timestamp(), entries = entries, localSnapshot = true }
    self.snapshots[key(snapshot.player)] = snapshot
    GA.Events:Emit("GA_BAGINSPECT_UPDATED", snapshot.player, snapshot)
    GA.Events:Emit("GA_BAGINSPECT_PLAYERS", self:GetPlayers())
    return snapshot
end

function BagInspector:Request(player)
    if not isGroupMember(player) then return nil, "player is not in the current group" end
    local normalized, current = key(player), now()
    if normalized == key(localName()) then return self:CaptureLocal() end
    if current - (self.requestTimes[normalized] or -1000) < self.REQUEST_COOLDOWN then
        return nil, "request is rate limited"
    end
    self.counter = self.counter + 1
    local requestID = key(localName()) .. "." .. tostring(math.floor(current * 1000)) .. "." .. tostring(self.counter)
    self.requestTimes[normalized] = current
    self.pending[requestID] = { player = normalized, requestedAt = current }
    GA.Compat:After(15, function()
        if BagInspector.pending[requestID] then
            BagInspector.pending[requestID], BagInspector.incoming[requestID] = nil, nil
        end
    end)
    local packet, err = GA.Comm:Send("BREQ", { self.PROTOCOL, requestID }, "WHISPER", player)
    if not packet then self.pending[requestID] = nil; return nil, err end
    return requestID
end

local function encodeBatches(entries)
    local batches, fields = {}, {}
    local function flush()
        if #fields > 0 then batches[#batches + 1] = GA.Comm.Pack(fields); fields = {} end
    end
    for index = 1, #entries do
        local entry = entries[index]
        local candidate = { tostring(entry.bag), tostring(entry.slot), tostring(entry.quantity), entry.link }
        local trial = {}
        for field = 1, #fields do trial[field] = fields[field] end
        for field = 1, #candidate do trial[#trial + 1] = candidate[field] end
        if #fields > 0 and #GA.Comm.Pack(trial) > BagInspector.MAX_BATCH_BYTES then flush() end
        for field = 1, #candidate do fields[#fields + 1] = candidate[field] end
    end
    flush()
    if #batches == 0 then batches[1] = "" end
    return batches
end

function BagInspector:OnRequest(fields, sender)
    local version, requestID = tonumber(fields[1]), fields[2]
    if version ~= self.PROTOCOL or not validRequestID(requestID) or not isGroupMember(sender) then return end
    if config().bagInspectorShare == false then return end
    local normalized, current = key(sender), now()
    if current - (self.responseTimes[normalized] or -1000) < self.RESPONSE_COOLDOWN then return end
    self.responseTimes[normalized] = current
    local snapshot, batches = self:CaptureLocal()
    batches = encodeBatches(snapshot.entries)
    for index = 1, #batches do
        GA.Comm:Send("BRESP", { self.PROTOCOL, requestID, index, #batches, snapshot.capturedAt, batches[index] },
            "WHISPER", sender)
    end
end

local function decodeEntries(payload)
    if payload == "" then return {} end
    local fields = GA.Comm.Unpack(payload)
    if not fields or #fields % 4 ~= 0 then return nil end
    local entries = {}
    for index = 1, #fields, 4 do
        local bag, slot, quantity, link = tonumber(fields[index]), tonumber(fields[index + 1]),
            tonumber(fields[index + 2]), fields[index + 3]
        if not bag or bag ~= math.floor(bag) or bag < 0 or bag > 20 or
            not slot or slot ~= math.floor(slot) or slot < 1 or slot > 100 or
            not quantity or quantity ~= math.floor(quantity) or quantity < 1 or quantity > 2147483647 or type(link) ~= "string" or
            #link > 1000 or not GA.Compat:GetItemID(link) then return nil end
        entries[#entries + 1] = { bag = bag, slot = slot, quantity = quantity, link = link }
    end
    return entries
end

function BagInspector:OnResponse(fields, sender)
    local version, requestID, batch, total = tonumber(fields[1]), fields[2], tonumber(fields[3]), tonumber(fields[4])
    local capturedAt, payload = tonumber(fields[5]), fields[6]
    local request = self.pending[requestID]
    if version ~= self.PROTOCOL or not request or request.player ~= key(sender) or not isGroupMember(sender) or
        not batch or not total or batch < 1 or total < 1 or batch > total or total > 50 then return end
    local entries = decodeEntries(payload or "")
    if not entries then return end
    local incoming = self.incoming[requestID]
    if not incoming then
        incoming = { player = sender, capturedAt = capturedAt or 0, total = total, batches = {}, count = 0, entries = {} }
        self.incoming[requestID] = incoming
    elseif incoming.total ~= total or key(incoming.player) ~= key(sender) then return end
    if incoming.batches[batch] then return end
    if #incoming.entries + #entries > self.MAX_ENTRIES then self.incoming[requestID] = nil; self.pending[requestID] = nil; return end
    incoming.batches[batch], incoming.count = true, incoming.count + 1
    for index = 1, #entries do incoming.entries[#incoming.entries + 1] = entries[index] end
    if incoming.count ~= incoming.total then return end
    table.sort(incoming.entries, function(left, right)
        return left.bag == right.bag and left.slot < right.slot or left.bag < right.bag
    end)
    local snapshot = { player = sender, capturedAt = incoming.capturedAt, receivedAt = timestamp(), entries = incoming.entries }
    self.snapshots[key(sender)] = snapshot
    self.incoming[requestID], self.pending[requestID] = nil, nil
    GA.Events:Emit("GA_BAGINSPECT_UPDATED", sender, snapshot)
    GA.Events:Emit("GA_BAGINSPECT_PLAYERS", self:GetPlayers())
end

function BagInspector:RefreshRoster()
    local names = groupNames()
    for player in pairs(self.snapshots) do if not names[player] then self.snapshots[player] = nil end end
    for requestID, request in pairs(self.pending) do
        if not names[request.player] then self.pending[requestID], self.incoming[requestID] = nil, nil end
    end
    GA.Events:Emit("GA_BAGINSPECT_PLAYERS", self:GetPlayers())
end

function BagInspector:OnInitialize()
    config()
    GA.Comm:RegisterHandler("BREQ", function(fields, sender) BagInspector:OnRequest(fields, sender) end)
    GA.Comm:RegisterHandler("BRESP", function(fields, sender) BagInspector:OnResponse(fields, sender) end)
    for _, event in ipairs({ "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        GA.Events:On(event, function() BagInspector:RefreshRoster() end, self)
        GA.Events:RegisterGameEvent(event)
    end
    return true
end

GA:RegisterModule("BagInspector", BagInspector)
