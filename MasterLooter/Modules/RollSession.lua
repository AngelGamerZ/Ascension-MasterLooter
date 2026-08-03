-- Distributed roll-session state machine for Ascension WoW 3.3.5a.

local addonName, GA = ...
GA = GA or _G.MasterLooter
if not GA then
    GA = {}
    _G.MasterLooter = GA
end

local RollSession = GA.RollSession or {}
GA.RollSession = RollSession

RollSession.PROTOCOL = 3
RollSession.sessions = RollSession.sessions or {}
RollSession.activeID = RollSession.activeID
RollSession.counter = RollSession.counter or 0
RollSession.handlersBound = RollSession.handlersBound or false
RollSession.DEFAULT_DURATION = 30
RollSession.DEFAULT_OS_ROLL_MAXIMUM = 99
RollSession.CLIENT_TIMEOUT_GRACE = 8
RollSession.SYNC_INTERVAL = 5
RollSession.SESSION_TTL = 900
RollSession.ACK_RETRY_INTERVAL = 2
RollSession.MAX_ACK_ATTEMPTS = 3
RollSession.syncRequests = RollSession.syncRequests or {}

local floor = math.floor
local concat = table.concat
local GetTimeSafe = GetTime or function() return os.time() end
local TimeSafe = time or os.time

local function emit(event, ...)
    local events = GA.Events
    if not events then return end
    if type(events.Fire) == "function" then events:Fire(event, ...)
    elseif type(events.Emit) == "function" then events:Emit(event, ...)
    elseif type(events.Trigger) == "function" then events:Trigger(event, ...) end
end

local function baseName(name)
    if type(name) ~= "string" then return "" end
    return string.lower((string.match(name, "^[^-]+") or name))
end

local function playerName()
    return (UnitName and UnitName("player")) or "player"
end

local function samePlayer(a, b) return baseName(a) ~= "" and baseName(a) == baseName(b) end

local function unitName(unit)
    return UnitName and UnitName(unit) or nil
end

local function resolvedUnitName(unit)
    local name = unitName(unit)
    if not name and GetUnitName then
        local ok, value = pcall(GetUnitName, unit, true)
        if ok then name = value end
    end
    if not name and UnitFullName then
        local ok, value = pcall(UnitFullName, unit)
        if ok then name = value end
    end
    return name
end

local function groupUnitForName(name)
    local raids = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, raids do
        local unit = "raid" .. i
        local rosterName = GetRaidRosterInfo and GetRaidRosterInfo(i) or nil
        if samePlayer(name, rosterName) or samePlayer(name, resolvedUnitName(unit)) then return unit end
    end
    local parties = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, parties do
        local unit = "party" .. i
        if samePlayer(name, resolvedUnitName(unit)) then return unit end
    end
    if samePlayer(name, playerName()) then return "player" end
    return nil
end

local function isGroupMember(name)
    if samePlayer(name, playerName()) then return true end
    return groupUnitForName(name) ~= nil
end

local function isGrouped()
    return (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) or
        (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) or false
end

local function currentLootMasterName()
    if not GetLootMethod then return nil end
    local method, partyID, raidID = GetLootMethod()
    if method ~= "master" then return nil end
    if raidID ~= nil then
        if raidID == 0 then return playerName() end
        return unitName("raid" .. raidID)
    end
    if partyID ~= nil then
        if partyID == 0 then return playerName() end
        return unitName("party" .. partyID)
    end
    return nil
end

local function isLeader(name)
    if samePlayer(name, playerName()) then
        if GetNumRaidMembers and GetNumRaidMembers() > 0 then
            local unit = groupUnitForName(name)
            if unit and GetRaidRosterInfo then
                local index = tonumber(string.match(unit, "raid(%d+)"))
                if index then
                    local _, rank = GetRaidRosterInfo(index)
                    return rank == 2
                end
            end
        end
        return UnitIsPartyLeader and UnitIsPartyLeader("player") or false
    end
    local unit = groupUnitForName(name)
    if not unit then return false end
    local raidIndex = tonumber(string.match(unit, "raid(%d+)"))
    if raidIndex and GetRaidRosterInfo then
        local _, rank = GetRaidRosterInfo(raidIndex)
        return rank == 2
    end
    return UnitIsPartyLeader and UnitIsPartyLeader(unit) or false
end

function RollSession:IsAuthority(name)
    name = name or playerName()
    local lootMaster = currentLootMasterName()
    if lootMaster and samePlayer(name, lootMaster) then return true end
    if isLeader(name) then return true end
    -- Solo mode is useful for configuration/testing and cannot affect other players.
    local grouped = (GetNumRaidMembers and GetNumRaidMembers() > 0) or
        (GetNumPartyMembers and GetNumPartyMembers() > 0)
    return not grouped and samePlayer(name, playerName())
end

local function encodeList(values)
    if GA.Comm and GA.Comm.Pack then return GA.Comm.Pack(values) end
    return concat(values, ",")
end

local function decodeList(value)
    if GA.Comm and GA.Comm.Unpack then
        local result = GA.Comm.Unpack(value or "")
        if result then return result end
    end
    local result = {}
    for entry in string.gmatch(value or "", "[^,]+") do result[#result + 1] = entry end
    return result
end

local function defaultChoices()
    return { "MS", "OS", "PASS" }
end

local function sanitizeChoices(choices)
    local result, seen = {}, {}
    if type(choices) ~= "table" then choices = defaultChoices() end
    for i = 1, #choices do
        local choice = tostring(choices[i] or "")
        if choice ~= "" and #choice <= 24 and not seen[choice] then
            result[#result + 1], seen[choice] = choice, true
        end
    end
    if #result == 0 then return defaultChoices() end
    return result
end

local function sanitizeOSMaximum(value)
    value = floor(tonumber(value) or RollSession.DEFAULT_OS_ROLL_MAXIMUM)
    return math.max(2, math.min(99, value))
end

local function hasChoice(state, choice)
    for i = 1, #state.choices do if state.choices[i] == choice then return true end end
    return false
end

local function makeID()
    RollSession.counter = RollSession.counter + 1
    local compactName = string.gsub(baseName(playerName()), "[^a-z0-9]", "")
    return compactName .. "-" .. tostring(TimeSafe()) .. "-" .. tostring(RollSession.counter)
end

local function nextSequence(state)
    state.sequence = (state.sequence or 0) + 1
    return state.sequence
end

local function send(messageType, fields, channel, target)
    if not GA.Comm then return nil, "communication module unavailable" end
    return GA.Comm:Send(messageType, fields, channel, target)
end

local function resolveState(sessionID)
    sessionID = sessionID or RollSession.activeID
    return sessionID and RollSession.sessions[sessionID] or nil
end

local function copyPersistent(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(key) ~= "function" and type(child) ~= "function" and type(child) ~= "userdata" and type(child) ~= "thread" then
            result[copyPersistent(key, seen)] = copyPersistent(child, seen)
        end
    end
    seen[value] = nil
    return result
end

function RollSession:PersistActive()
    local data = GA.DB and GA.DB.data
    if not data then return false end
    data.character = data.character or {}
    data.character.rollSession = data.character.rollSession or {}
    local store = data.character.rollSession
    local state = resolveState()
    if not state or state.status ~= "ACTIVE" or not samePlayer(state.owner, playerName()) then
        store.active = nil
        return true
    end
    local snapshot = copyPersistent(state)
    snapshot.remainingAtSave = math.max(0, (tonumber(state.expiresAt) or GetTimeSafe()) - GetTimeSafe())
    snapshot.savedAt = TimeSafe()
    store.active = snapshot
    return true
end

function RollSession:RestoreActive()
    if self.restoredPersistent then return false end
    self.restoredPersistent = true
    local store = GA.DB and GA.DB.data and GA.DB.data.character and GA.DB.data.character.rollSession
    local saved = store and store.active
    if type(saved) ~= "table" or saved.status ~= "ACTIVE" or type(saved.itemLink) ~= "string" or
        not samePlayer(saved.owner, playerName()) or not self:IsAuthority(playerName()) then
        if store then store.active = nil end
        return false
    end
    local elapsedWall = math.max(0, TimeSafe() - (tonumber(saved.savedAt) or TimeSafe()))
    local remaining = (tonumber(saved.remainingAtSave) or 0) - elapsedWall
    if remaining <= 0 or remaining > 600 then store.active = nil; return false end
    local state = copyPersistent(saved)
    state.savedAt, state.remainingAtSave = nil, nil
    state.receivedAt, state.expiresAt, state.timeSource = GetTimeSafe(), GetTimeSafe() + remaining, "RESTORED"
    state.participants, state.participantSequences, state.rollAssignments = state.participants or {},
        state.participantSequences or {}, state.rollAssignments or {}
    self.sessions[state.id], self.activeID = state, state.id
    local seq = nextSequence(state)
    state.authoritySequence = seq
    send("START", { self.PROTOCOL, state.id, seq, state.itemLink, state.createdAt or TimeSafe(), remaining,
        encodeList(state.choices or defaultChoices()), state.note or "", state.osRollMaximum or self.DEFAULT_OS_ROLL_MAXIMUM })
    emit("GA_ROLL_SESSION_STARTED", state, "RESTORED")
    self:PersistActive()
    return state
end

function RollSession:GetState(sessionID)
    return resolveState(sessionID)
end

function RollSession:Start(itemLink, options)
    if not self:IsAuthority(playerName()) then return nil, "only the loot master or group leader may start a roll" end
    if type(itemLink) ~= "string" or itemLink == "" then return nil, "itemLink is required" end
    options = options or {}
    local duration = tonumber(options.duration) or self.DEFAULT_DURATION
    duration = math.max(5, math.min(600, floor(duration)))
    local osRollMaximum = sanitizeOSMaximum(options.osRollMaximum)
    local now = GetTimeSafe()
    local state = {
        id = makeID(), itemLink = itemLink, owner = playerName(), createdAt = TimeSafe(),
        receivedAt = now, duration = duration, expiresAt = now + duration, timeSource = "GetTime", status = "ACTIVE",
        osRollMaximum = osRollMaximum,
        choices = sanitizeChoices(options.choices), note = tostring(options.note or ""),
        participants = {}, participantSequences = {}, rollAssignments = {}, sequence = 0,
    }
    self.sessions[state.id] = state
    self.activeID = state.id
    local seq = nextSequence(state)
    state.authoritySequence = seq
    local packet, err = send("START", { self.PROTOCOL, state.id, seq, state.itemLink,
        state.createdAt, state.duration, encodeList(state.choices), state.note, state.osRollMaximum })
    if not packet then self.sessions[state.id] = nil; self.activeID = nil; return nil, err end
    emit("GA_ROLL_SESSION_STARTED", state, "LOCAL")
    self:PersistActive()
    return state
end

function RollSession:Stop(sessionID, reason)
    local state = resolveState(sessionID)
    if not state then return false, "unknown session" end
    if not self:IsAuthority(playerName()) or not samePlayer(state.owner, playerName()) then
        return false, "only the session authority may stop a roll"
    end
    if state.status ~= "ACTIVE" then return false, "session is not active" end
    reason = tostring(reason or "STOPPED")
    local previousSequence, previousAuthoritySequence = state.sequence, state.authoritySequence
    local seq = nextSequence(state)
    state.authoritySequence = seq
    local packet, err = send("STOP", { self.PROTOCOL, state.id, seq, reason })
    if not packet then
        state.sequence, state.authoritySequence = previousSequence, previousAuthoritySequence
        return false, err
    end
    state.status, state.endedAt = "STOPPED", GetTimeSafe()
    if self.activeID == state.id then self.activeID = nil end
    emit("GA_ROLL_SESSION_ENDED", state, reason)
    self:PersistActive()
    return true
end

function RollSession:SubmitRoll(sessionID, choice, rollValue, note)
    local state = resolveState(sessionID)
    if not state or state.status ~= "ACTIVE" then return nil, "no active session" end
    choice = tostring(choice or "MS")
    if not hasChoice(state, choice) or choice == "PASS" then
        if choice == "PASS" then return self:Pass(state.id, note) end
        return nil, "invalid roll choice"
    end
    -- rollValue is deliberately ignored: only the session host generates rolls.
    local name = playerName()
    local previous = state.participants[baseName(name)]
    local previousLocalSequence = state.localResponseSequence or 0
    local seq = previousLocalSequence + 1
    state.localResponseSequence = seq
    local participant = { name = name, choice = choice, roll = previous and previous.roll or 0,
        note = string.sub(tostring(note or ""), 1, 512), passed = false, pending = true,
        sequence = seq, updatedAt = GetTimeSafe(), lastSentAt = GetTimeSafe(), sendAttempts = 1 }
    state.participants[baseName(name)] = participant
    local packet, err = send("ROLL", { self.PROTOCOL, state.id, seq, choice, participant.note })
    if not packet then
        state.localResponseSequence = previousLocalSequence
        state.participants[baseName(name)] = previous
        return nil, err
    end
    local confirmed = state.participants[baseName(name)]
    if confirmed and confirmed ~= participant and confirmed.sequence == seq and not confirmed.pending then return confirmed end
    emit("GA_ROLL_SESSION_UPDATED", state, "ROLL_PENDING", participant)
    return participant
end

function RollSession:Pass(sessionID, note)
    local state = resolveState(sessionID)
    if not state or state.status ~= "ACTIVE" then return nil, "no active session" end
    local name = playerName()
    local previous = state.participants[baseName(name)]
    local previousLocalSequence = state.localResponseSequence or 0
    local seq = previousLocalSequence + 1
    state.localResponseSequence = seq
    local participant = { name = name, choice = "PASS", roll = 0, note = tostring(note or ""),
        passed = true, pending = true, sequence = seq, updatedAt = GetTimeSafe(),
        lastSentAt = GetTimeSafe(), sendAttempts = 1 }
    participant.note = string.sub(participant.note, 1, 512)
    state.participants[baseName(name)] = participant
    local packet, err = send("ROLL", { self.PROTOCOL, state.id, seq, "PASS", participant.note })
    if not packet then
        state.localResponseSequence = previousLocalSequence
        state.participants[baseName(name)] = previous
        return nil, err
    end
    local confirmed = state.participants[baseName(name)]
    if confirmed and confirmed ~= participant and confirmed.sequence == seq and not confirmed.pending then return confirmed end
    emit("GA_ROLL_SESSION_UPDATED", state, "PASS_PENDING", participant)
    return participant
end

function RollSession:GetChoiceForMaximum(sessionID, maximum)
    local state = type(sessionID) == "table" and sessionID or resolveState(sessionID)
    maximum = tonumber(maximum)
    if not state or not maximum then return nil end
    if maximum == 100 then return "MS" end
    if maximum == sanitizeOSMaximum(state.osRollMaximum) then return "OS" end
    return nil
end

function RollSession:RecordPublicRoll(player, roll, minimum, maximum, sessionID)
    local state = resolveState(sessionID)
    if not state or state.status ~= "ACTIVE" then return nil, "no active session" end
    if not samePlayer(state.owner, playerName()) or not self:IsAuthority(playerName()) then
        return nil, "only the session authority records public rolls"
    end
    roll, minimum, maximum = tonumber(roll), tonumber(minimum), tonumber(maximum)
    local choice = self:GetChoiceForMaximum(state, maximum)
    if not choice or minimum ~= 1 or not roll or roll < minimum or roll > maximum or roll ~= floor(roll) then
        return nil, "roll range does not match this session"
    end
    local key = baseName(player)
    if key == "" then return nil, "invalid player" end
    -- Some Ascension builds report the party size correctly while returning nil
    -- for UnitName/GetUnitName/UnitFullName on party tokens. A public /roll is
    -- therefore allowed as a group fallback, but only on the active authority's
    -- own session. Solo and inactive-session messages remain rejected above.
    if not isGroupMember(player) and not isGrouped() then return nil, "player is not in the group" end
    local existing = state.participants[key]
    if existing and existing.choice then return nil, "player already rolled" end
    local participant = {
        name = player, choice = choice, roll = floor(roll), passed = false, pending = false,
        publicRoll = true, minimum = minimum, maximum = maximum,
        sequence = (existing and existing.sequence or 0) + 1,
        updatedAt = GetTimeSafe(), acknowledged = true,
    }
    state.participants[key] = participant
    state.participantSequences[key] = participant.sequence
    state.rollAssignments[key] = participant.roll
    emit("GA_ROLL_SESSION_UPDATED", state, "ROLL", participant)
    self:PersistActive()
    return participant
end

function RollSession:ObservePublicRoll(player, roll, minimum, maximum, sessionID)
    local state = resolveState(sessionID)
    if not state or state.status ~= "ACTIVE" then return nil, "no active session" end
    if samePlayer(state.owner, playerName()) and self:IsAuthority(playerName()) then
        return self:RecordPublicRoll(player, roll, minimum, maximum, state.id)
    end
    -- A participant may relay only the result carrying their own character
    -- name. The authority validates the sender and the roll range again.
    if not samePlayer(player, playerName()) then return nil, "not the local player's roll" end
    roll, minimum, maximum = tonumber(roll), tonumber(minimum), tonumber(maximum)
    if minimum ~= 1 or not roll or not maximum or not self:GetChoiceForMaximum(state, maximum) then
        return nil, "roll range does not match this session"
    end
    return send("PUBLIC_ROLL", { self.PROTOCOL, state.id, roll, minimum, maximum })
end

function RollSession:Award(sessionID, winner, choice, roll, note)
    local state = resolveState(sessionID)
    if not state then return nil, "unknown session" end
    if state.status ~= "ACTIVE" then return nil, "session is not active" end
    if not self:IsAuthority(playerName()) or not samePlayer(state.owner, playerName()) then
        return nil, "only the session authority may award an item"
    end
    if type(winner) ~= "string" or winner == "" then return nil, "winner is required" end
    local existing = state.participants[baseName(winner)]
    local result = { sessionID = state.id, winner = winner, choice = choice or (existing and existing.choice) or "",
        roll = tonumber(roll) or (existing and existing.roll) or 0, note = tostring(note or ""),
        itemLink = state.itemLink, awardedAt = TimeSafe() }
    local previousSequence, previousAuthoritySequence = state.sequence, state.authoritySequence
    local seq = nextSequence(state)
    state.authoritySequence = seq
    local packet, err = send("RESULT", { self.PROTOCOL, state.id, seq, result.winner, result.choice,
        result.roll, result.note, result.awardedAt })
    if not packet then
        state.sequence, state.authoritySequence = previousSequence, previousAuthoritySequence
        return nil, err
    end
    state.result, state.status, state.endedAt = result, "AWARDED", GetTimeSafe()
    if self.activeID == state.id then self.activeID = nil end
    emit("GA_ROLL_RESULT", result, state)
    emit("GA_ROLL_SESSION_ENDED", state, "AWARDED")
    self:PersistActive()
    return result
end

function RollSession:RequestSync(sessionID)
    local current, key = GetTimeSafe(), tostring(sessionID or "*")
    self.localSyncRequests = self.localSyncRequests or {}
    if current - (self.localSyncRequests[key] or -1000) < self.SYNC_INTERVAL then return nil, "sync rate limited" end
    local packet, err = send("SYNC", { self.PROTOCOL, "REQ", sessionID or "" })
    if packet then self.localSyncRequests[key] = current end
    return packet, err
end

local function validVersion(fields) return tonumber(fields[1]) == RollSession.PROTOCOL end
local function validSequence(value)
    value = tonumber(value)
    return value and value >= 1 and value <= 1000000000 and value == floor(value) and value or nil
end

local function normalizedDuration(value, isSync)
    value = tonumber(value)
    if not value then return nil end
    if isSync then
        -- SYNC carries remaining monotonic seconds, not the original duration.
        -- It must not be rounded up to the five-second START minimum.
        return math.max(0, math.min(600, value))
    end
    return math.max(5, math.min(600, floor(value)))
end

local function receiveStart(fields, sender, source)
    if not validVersion(fields) or not RollSession:IsAuthority(sender) then return end
    local id, seq = fields[2], validSequence(fields[3])
    local itemLink, createdAt = fields[4], tonumber(fields[5])
    local isSync = source == "SYNC"
    local duration = normalizedDuration(fields[6], isSync)
    if not id or id == "" or #id > 96 or not seq or not itemLink or itemLink == "" or #itemLink > 8192 then return end
    if not duration then duration = isSync and 0 or RollSession.DEFAULT_DURATION end
    if isSync and duration <= 0 then return end
    local existing = RollSession.sessions[id]
    if existing and (existing.authoritySequence or 0) >= seq then return end
    local now = GetTimeSafe()
    local state = existing or { id = id, participants = {}, participantSequences = {}, rollAssignments = {} }
    state.itemLink, state.owner, state.createdAt = itemLink, sender, createdAt or TimeSafe()
    state.receivedAt, state.duration, state.expiresAt = now, duration, now + duration
    state.timeSource, state.syncedAt = "GetTime", isSync and now or nil
    state.osRollMaximum = sanitizeOSMaximum(fields[9])
    state.status, state.choices, state.note = "ACTIVE", sanitizeChoices(decodeList(fields[7])), fields[8] or ""
    state.authoritySequence = seq
    RollSession.sessions[id], RollSession.activeID = state, id
    emit(existing and "GA_ROLL_SESSION_UPDATED" or "GA_ROLL_SESSION_STARTED", state, source or "REMOTE")
    send("ACK", { RollSession.PROTOCOL, id, 1 }, "WHISPER", sender)
end

local function receiveAck(fields, sender)
    if not validVersion(fields) or not isGroupMember(sender) then return end
    local state = resolveState(fields[2])
    if not state or not samePlayer(state.owner, playerName()) then return end
    local key = baseName(sender)
    local participant = state.participants[key] or { name = sender }
    participant.acknowledged, participant.acknowledgedAt = true, GetTimeSafe()
    state.participants[key] = participant
    emit("GA_ROLL_SESSION_UPDATED", state, "ACK", participant)
end

local function sendRollAck(state, participant, target)
    return send("ROLL_ACK", { RollSession.PROTOCOL, state.id, participant.sequence, participant.choice,
        participant.roll, participant.note or "" }, "WHISPER", target)
end

local function receiveRoll(fields, sender)
    if not validVersion(fields) or not isGroupMember(sender) then return end
    local state, seq = resolveState(fields[2]), validSequence(fields[3])
    if not state or state.status ~= "ACTIVE" or not seq then return end
    if not samePlayer(state.owner, playerName()) then return end -- rolls are authoritative only on the host
    local key, choice = baseName(sender), tostring(fields[4] or "")
    local lastSequence = state.participantSequences[key] or 0
    if lastSequence > seq then return end
    if lastSequence == seq then
        local existing = state.participants[key]
        if existing and existing.sequence == seq then sendRollAck(state, existing, sender) end
        return
    end
    if choice ~= "PASS" and not hasChoice(state, choice) then return end
    state.rollAssignments = state.rollAssignments or {}
    local roll = 0
    if choice ~= "PASS" then
        roll = state.rollAssignments[key] or math.random(1, 100)
        state.rollAssignments[key] = roll
    end
    local note = string.sub(tostring(fields[5] or ""), 1, 512)
    local participant = { name = sender, choice = choice, roll = roll, note = note,
        passed = choice == "PASS", pending = false, authoritativeRoll = state.rollAssignments[key],
        sequence = seq, updatedAt = GetTimeSafe(), acknowledged = true }
    state.participantSequences[key] = seq
    state.participants[key] = participant
    emit("GA_ROLL_SESSION_UPDATED", state, choice == "PASS" and "PASS" or "ROLL", participant)
    RollSession:PersistActive()
    -- The host response is authoritative as soon as the ROLL packet is valid.
    -- A failed whisper ACK must not make the roll disappear from the lootmaster UI;
    -- the participant retry will request the same ACK again without rerolling.
    sendRollAck(state, participant, sender)
end

local function receiveRollAck(fields, sender)
    if not validVersion(fields) or not RollSession:IsAuthority(sender) then return end
    local state, seq = resolveState(fields[2]), validSequence(fields[3])
    if not state or state.status ~= "ACTIVE" or not seq or not samePlayer(state.owner, sender) then return end
    local key, choice, roll = baseName(playerName()), tostring(fields[4] or ""), tonumber(fields[5])
    local existing = state.participants[key]
    if existing and existing.sequence > seq then return end
    if choice ~= "PASS" and (not hasChoice(state, choice) or not roll or roll < 1 or roll > 100) then return end
    local participant = { name = playerName(), choice = choice, roll = choice == "PASS" and 0 or floor(roll),
        note = string.sub(tostring(fields[6] or ""), 1, 512), passed = choice == "PASS", pending = false,
        sequence = seq, updatedAt = GetTimeSafe(), acknowledged = true }
    state.participants[key] = participant
    emit("GA_ROLL_SESSION_UPDATED", state, "ROLL_ACK", participant)
end

local function receivePublicRoll(fields, sender)
    if not validVersion(fields) or (not isGroupMember(sender) and not isGrouped()) then return end
    local state = resolveState(fields[2])
    if not state or state.status ~= "ACTIVE" or not samePlayer(state.owner, playerName()) then return end
    RollSession:RecordPublicRoll(sender, fields[3], fields[4], fields[5], state.id)
end

local function receiveStop(fields, sender)
    if not validVersion(fields) or not RollSession:IsAuthority(sender) then return end
    local state, seq = resolveState(fields[2]), validSequence(fields[3])
    if not state or not samePlayer(state.owner, sender) or not seq or (state.authoritySequence or 0) >= seq then return end
    state.authoritySequence, state.status, state.endedAt = seq, "STOPPED", GetTimeSafe()
    if RollSession.activeID == state.id then RollSession.activeID = nil end
    emit("GA_ROLL_SESSION_ENDED", state, fields[4] or "STOPPED")
end

local function receiveResult(fields, sender)
    if not validVersion(fields) or not RollSession:IsAuthority(sender) then return end
    local state, seq = resolveState(fields[2]), validSequence(fields[3])
    if not state or not samePlayer(state.owner, sender) or not seq or (state.authoritySequence or 0) >= seq then return end
    state.authoritySequence, state.status, state.endedAt = seq, "AWARDED", GetTimeSafe()
    local result = { sessionID = state.id, winner = fields[4], choice = fields[5],
        roll = tonumber(fields[6]) or 0, note = fields[7] or "", awardedAt = tonumber(fields[8]) or TimeSafe(),
        itemLink = state.itemLink }
    state.result = result
    if RollSession.activeID == state.id then RollSession.activeID = nil end
    emit("GA_ROLL_RESULT", result, state)
    emit("GA_ROLL_SESSION_ENDED", state, "AWARDED")
end

local function receiveSync(fields, sender)
    if not validVersion(fields) or not isGroupMember(sender) then return end
    local mode, id = fields[2], fields[3]
    if mode == "REQ" then
        if not RollSession:IsAuthority(playerName()) then return end
        -- Group addon messages echo to their sender. The authority already owns
        -- the canonical deadline and must never resynchronize against itself.
        if samePlayer(sender, playerName()) then return end
        local throttleKey = baseName(sender) .. "\031" .. tostring(id or "")
        local current = GetTimeSafe()
        if current - (RollSession.syncRequests[throttleKey] or -1000) < RollSession.SYNC_INTERVAL then return end
        RollSession.syncRequests[throttleKey] = current
        local state = resolveState(id ~= "" and id or nil)
        if not state or state.status ~= "ACTIVE" or not samePlayer(state.owner, playerName()) then return end
        local remaining = state.expiresAt - current
        if remaining <= 0 then return end
        local previousSequence, previousAuthoritySequence = state.sequence, state.authoritySequence
        local seq = nextSequence(state)
        state.authoritySequence = seq
        local packet = send("SYNC", { RollSession.PROTOCOL, "STATE", state.id, seq, state.itemLink,
            state.createdAt, remaining, encodeList(state.choices), state.note, state.osRollMaximum }, "WHISPER", sender)
        if not packet then state.sequence, state.authoritySequence = previousSequence, previousAuthoritySequence end
    elseif mode == "STATE" then
        -- Convert STATE to START's field layout and pass through identical validation/state creation.
        receiveStart({ fields[1], fields[3], fields[4], fields[5], fields[6], fields[7], fields[8], fields[9], fields[10] }, sender, "SYNC")
    end
end

function RollSession:BindCommunication()
    if self.handlersBound or not GA.Comm or type(GA.Comm.RegisterHandler) ~= "function" then return false end
    GA.Comm:RegisterHandler("START", receiveStart)
    GA.Comm:RegisterHandler("ACK", receiveAck)
    GA.Comm:RegisterHandler("ROLL", receiveRoll)
    GA.Comm:RegisterHandler("ROLL_ACK", receiveRollAck)
    GA.Comm:RegisterHandler("PUBLIC_ROLL", receivePublicRoll)
    GA.Comm:RegisterHandler("STOP", receiveStop)
    GA.Comm:RegisterHandler("RESULT", receiveResult)
    GA.Comm:RegisterHandler("SYNC", receiveSync)
    self.handlersBound = true
    return true
end

function RollSession:Tick()
    local now = GetTimeSafe()
    for id, state in pairs(self.sessions) do
        if state.status == "ACTIVE" and now >= state.expiresAt then
            if samePlayer(state.owner, playerName()) and self:IsAuthority(playerName()) then
                self:Stop(state.id, "TIMEOUT")
            elseif now >= state.expiresAt + self.CLIENT_TIMEOUT_GRACE then
                state.status, state.endedAt = "EXPIRED", now
                if self.activeID == state.id then self.activeID = nil end
                emit("GA_ROLL_SESSION_ENDED", state, "TIMEOUT_LOCAL")
            end
        end
        if state.status == "ACTIVE" and not samePlayer(state.owner, playerName()) then
            local participant = state.participants[baseName(playerName())]
            if participant and participant.pending and now - (participant.lastSentAt or 0) >= self.ACK_RETRY_INTERVAL then
                if (participant.sendAttempts or 1) < self.MAX_ACK_ATTEMPTS then
                    local packet = send("ROLL", { self.PROTOCOL, state.id, participant.sequence,
                        participant.choice, participant.note or "" })
                    participant.lastSentAt = now
                    if packet then participant.sendAttempts = (participant.sendAttempts or 1) + 1 end
                else
                    participant.pending, participant.failed = false, true
                    emit("GA_ROLL_SESSION_UPDATED", state, "ROLL_FAILED", participant)
                end
            end
        end
        local reference = state.endedAt or state.receivedAt or state.createdAt or now
        if state.status ~= "ACTIVE" and now - reference > self.SESSION_TTL then self.sessions[id] = nil end
    end
    for key, timestamp in pairs(self.syncRequests) do
        if now - timestamp > self.SESSION_TTL then self.syncRequests[key] = nil end
    end
end

function RollSession:Initialize()
    if self.initialized then return true end
    self:BindCommunication()
    if CreateFrame then
        self.frame = self.frame or CreateFrame("Frame")
        self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        self.frame:RegisterEvent("RAID_ROSTER_UPDATE")
        self.frame:SetScript("OnEvent", function(_, event)
            RollSession:BindCommunication()
            if event ~= "PLAYER_ENTERING_WORLD" then RollSession:RequestSync() end
        end)
        local elapsedTotal = 0
        self.frame:SetScript("OnUpdate", function(_, elapsed)
            elapsedTotal = elapsedTotal + elapsed
            if elapsedTotal >= 1 then
                elapsedTotal = 0
                RollSession:BindCommunication()
                RollSession:Tick()
            end
        end)
    end
    self.initialized = true
    if GA.Events then
        GA.Events:On("PLAYER_LOGIN", function() RollSession:RestoreActive() end, self, -100)
    end
    return true
end

function RollSession:OnSave()
    self:PersistActive()
end

-- Lower-case aliases make the API pleasant for both existing and new UI code.
RollSession.start = RollSession.Start
RollSession.stop = RollSession.Stop
RollSession.submitRoll = RollSession.SubmitRoll
RollSession.pass = RollSession.Pass
RollSession.award = RollSession.Award
RollSession.getState = RollSession.GetState

if type(GA.RegisterModule) == "function" then GA:RegisterModule("RollSession", RollSession) end
RollSession:Initialize()
