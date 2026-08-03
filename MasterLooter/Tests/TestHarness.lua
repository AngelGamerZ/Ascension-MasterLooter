-- Standalone Lua 5.1 integration harness for MasterLooter.
-- Run from the repository root with: lua MasterLooter/Tests/TestHarness.lua
-- This file is deliberately excluded from MasterLooter.toc.

local hostGlobal = _G
local clients = {}
local transmissions = {}
local assertions = 0

local function expect(condition, message)
    assertions = assertions + 1
    if not condition then error("ASSERTION FAILED: " .. tostring(message), 2) end
end

local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local root = (arg and arg[1]) or "MasterLooter"

local function makeFrame(client)
    local frame = { events = {}, scripts = {}, shown = true }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:GetScript(script) return self.scripts[script] end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    client.frames[#client.frames + 1] = frame
    return frame
end

local function fire(client, event, ...)
    -- Snapshot because handlers are allowed to create frames during dispatch.
    local frames = {}
    for index = 1, #client.frames do frames[index] = client.frames[index] end
    for index = 1, #frames do
        local frame = frames[index]
        local callback = frame.events[event] and frame.scripts.OnEvent
        if callback then callback(frame, event, ...) end
    end
end

local function advance(client, seconds)
    client.now = client.now + seconds
    local frames = {}
    for index = 1, #client.frames do frames[index] = client.frames[index] end
    for index = 1, #frames do
        local frame, callback = frames[index], frames[index].scripts.OnUpdate
        if callback and frame.shown then callback(frame, seconds) end
    end
end

local function deliver(prefix, payload, channel, sender, target)
    transmissions[#transmissions + 1] = {
        prefix = prefix, payload = payload, channel = channel,
        sender = sender.name, target = target,
    }
    for index = 1, #clients do
        local recipient = clients[index]
        local wanted = channel ~= "WHISPER" or
            string.lower(recipient.name) == string.lower(tostring(target or ""))
        if wanted then fire(recipient, "CHAT_MSG_ADDON", prefix, payload, channel, sender.name) end
    end
end

local function makeClient(name, savedDB)
    local client = { name = name, now = 100, frames = {}, prefixes = {}, chatMessages = {}, chatFilters = {} }
    local env = { _G = false }
    env._G = env
    setmetatable(env, { __index = hostGlobal })
    client.env = env
    env.MasterLooterDB = savedDB
    env.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"

    env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    env.SlashCmdList = {}
    env.CreateFrame = function() return makeFrame(client) end
    env.GetTime = function() return client.now end
    env.time = function() return 1700000000 + math.floor(client.now) end
    env.UnitName = function(unit)
        if unit == "player" then return client.name end
        if unit == "raid1" then return "Alice" end
        if unit == "raid2" then return "Bob" end
        if unit == "target" then return client.target end
        return nil
    end
    env.UnitFullName = function(unit) return env.UnitName(unit), "Ascension" end
    env.GetNumRaidMembers = function() return 2 end
    env.GetNumPartyMembers = function() return 0 end
    env.GetRaidRosterInfo = function(index)
        if index == 1 then return "Alice", 2 end
        if index == 2 then return "Bob", 0 end
    end
    env.UnitIsPartyLeader = function(unit) return unit == "raid1" end
    env.GetLootMethod = function() return "master", nil, 1 end
    env.UnitExists = function(unit) return unit == "target" and client.target ~= nil end
    env.UnitIsPlayer = function(unit) return unit == "target" and client.target ~= nil end
    env.RegisterAddonMessagePrefix = function(prefix)
        client.prefixes[prefix] = true
        return true
    end
    env.SendAddonMessage = function(prefix, payload, channel, target)
        deliver(prefix, payload, channel, client, target)
    end
    env.SendChatMessage = function(message, channel)
        client.chatMessages[#client.chatMessages + 1] = { message = message, channel = channel }
    end
    env.ChatFrame_AddMessageEventFilter = function(event, callback)
        client.chatFilters[event] = client.chatFilters[event] or {}
        client.chatFilters[event][#client.chatFilters[event] + 1] = callback
    end

    clients[#clients + 1] = client
    return client
end

local function loadFile(client, relativePath, loadedAddon, namespace)
    local path = root .. "/" .. relativePath
    -- Lua 5.1 ignores loadfile's extra arguments and uses setfenv; accepting
    -- the 5.2+ form also lets contributors run the same harness with Fengari.
    local chunk, loadError = loadfile(path, "t", client.env)
    if not chunk then error("Unable to load " .. path .. ": " .. tostring(loadError)) end
    if setfenv then setfenv(chunk, client.env) end
    return chunk(loadedAddon or "MasterLooter", namespace or client.namespace)
end

local function loadAddon(client)
    client.namespace = {}
    loadFile(client, "Core/Namespace.lua")
    -- Namespace.lua uses the supplied table in place, so retain the same root.
    loadFile(client, "Core/Compat.lua")
    loadFile(client, "Core/Events.lua")
    loadFile(client, "Core/DB.lua")
    loadFile(client, "Core/Bootstrap.lua")
    loadFile(client, "Modules/Comm.lua")
    loadFile(client, "Modules/BagInspector.lua")
    loadFile(client, "Modules/RollSession.lua")
    loadFile(client, "Modules/ChatRolls.lua")
    loadFile(client, "Modules/Trade.lua")
    loadFile(client, "Modules/Award.lua")
    loadFile(client, "Modules/SoftRes.lua")
    loadFile(client, "Modules/PlusOnes.lua")
    loadFile(client, "Modules/Priority.lua")
    loadFile(client, "Modules/BoostedRolls.lua")
    loadFile(client, "Modules/Ranking.lua")
    loadFile(client, "Modules/GDKP.lua")
    loadFile(client, "Modules/GDKPAuction.lua")
    loadFile(client, "Modules/ImportExport.lua")
    loadFile(client, "Modules/VersionCheck.lua")
    loadFile(client, "Modules/Announcements.lua")
    loadFile(client, "Modules/Commands.lua")
    fire(client, "ADDON_LOADED", "MasterLooter")
    fire(client, "PLAYER_LOGIN")
    return client.namespace
end

local function countPacketFrames(packetID)
    local count = 0
    for index = 1, #transmissions do
        local packet = transmissions[index]
        local id = string.match(packet.payload, "^[^|]+|([^|]+)|")
        if id == packetID then count = count + 1 end
    end
    return count
end

local alice = makeClient("Alice")
local bob = makeClient("Bob")
local aliceGA = loadAddon(alice)
local bobGA = loadAddon(bob)

expect(alice.prefixes[aliceGA.Comm.PREFIX], "Alice registers the communication prefix")
expect(bob.prefixes[bobGA.Comm.PREFIX], "Bob registers the communication prefix")

-- Communication fragmentation and duplicate-frame suppression.
local received, receivedPayload = 0, nil
bobGA.Comm:RegisterHandler("HARNESS", function(fields, sender)
    received = received + 1
    receivedPayload = fields[1]
    same(sender, "Alice", "fragmented sender")
end)
local largePayload = string.rep("Ascension-MasterLooter-", 40)
local packetID, sendError = aliceGA.Comm:Send("HARNESS", { largePayload }, "RAID")
expect(packetID ~= nil, sendError or "fragmented message returns a packet id")
expect(countPacketFrames(packetID) >= 3, "large message is split into at least three frames")
same(received, 1, "all fragments dispatch exactly once")
same(receivedPayload, largePayload, "fragmentation round-trips the full payload")

for index = 1, #transmissions do
    local packet = transmissions[index]
    local id = string.match(packet.payload, "^[^|]+|([^|]+)|")
    if id == packetID then
        fire(bob, "CHAT_MSG_ADDON", packet.prefix, packet.payload, packet.channel, packet.sender)
    end
end
same(received, 1, "replayed frames are deduplicated")
local oversizedPacket, oversizedError = aliceGA.Comm:Send("HARNESS",
    { string.rep("x", aliceGA.Comm.MAX_PAYLOAD_BYTES + 1) }, "RAID")
same(oversizedPacket, nil, "transport rejects payloads larger than 64 fragments")
expect(type(oversizedError) == "string", "oversized transport failure is reported")

-- Full distributed roll lifecycle: master starts, raider rolls, master awards.
local itemLink = "|cffa335ee|Hitem:9000001:0:0:0:0:0:0:0|h[Ascension Test Item]|h|r"
local session, startError = aliceGA.RollSession:Start(itemLink, { duration = 30, note = "MS first" })
expect(session ~= nil, startError or "loot master starts a session")
local bobState = bobGA.RollSession:GetState(session.id)
expect(bobState ~= nil, "remote client receives START")
same(bobState.itemLink, itemLink, "remote START preserves the item link")
same(bobState.owner, "Alice", "remote START records the loot master")

local participant, rollError = bobGA.RollSession:SubmitRoll(session.id, "MS", 87, "upgrade")
expect(participant ~= nil, rollError or "remote client submits a roll")
local authoritative = aliceGA.RollSession:GetState(session.id)
expect(authoritative.participants.bob ~= nil, "loot master receives ROLL")
expect(authoritative.participants.bob.roll >= 1 and authoritative.participants.bob.roll <= 100,
    "loot master generates the authoritative roll value")
same(participant.roll, authoritative.participants.bob.roll, "ROLL_ACK confirms the host-generated roll")
same(authoritative.participants.bob.choice, "MS", "loot master records roll category")
local firstRoll = authoritative.participants.bob.roll
local repeated = bobGA.RollSession:SubmitRoll(session.id, "MS", 1, "retry")
same(repeated.roll, firstRoll, "category resubmission cannot reroll or inject a client roll")
same(authoritative.participants.bob.roll, firstRoll, "host retains one roll assignment per participant")

local result, awardError = aliceGA.RollSession:Award(session.id, "Bob")
expect(result ~= nil, awardError or "loot master awards the item")
bobState = bobGA.RollSession:GetState(session.id)
same(bobState.status, "AWARDED", "remote client receives RESULT")
same(bobState.result.winner, "Bob", "remote RESULT records winner")
same(bobState.result.roll, firstRoll, "award inherits authoritative roll")
same(bobGA.RollSession.activeID, nil, "remote active session closes after RESULT")
same(#aliceGA.Trade.pending, 1, "loot master queues an undelivered award for trade")
same(aliceGA.Trade.pending[1].winner, "Bob", "trade queue keeps the award winner")
same(#bobGA.Trade.pending, 0, "remote raider does not queue someone else's award")
same(bobGA.DB.data.history.awards[1].delivery, "REMOTE", "remote award history has no delivery authority")

-- Failed network sends roll back local state instead of reporting false success.
local rollbackSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
local originalAliceSend = alice.env.SendAddonMessage
alice.env.SendAddonMessage = function() error("simulated transport failure") end
local stopped, stopError = aliceGA.RollSession:Stop(rollbackSession.id, "TEST")
same(stopped, false, "failed STOP is reported")
expect(type(stopError) == "string", "failed STOP exposes its transport error")
same(rollbackSession.status, "ACTIVE", "failed STOP keeps the session active")
local failedAward = aliceGA.RollSession:Award(rollbackSession.id, "Bob")
same(failedAward, nil, "failed RESULT is reported")
same(rollbackSession.status, "ACTIVE", "failed RESULT keeps the session active")
alice.env.SendAddonMessage = originalAliceSend
expect(aliceGA.RollSession:Stop(rollbackSession.id, "TEST"), "rollback test session stops after transport recovery")

local submitSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
local originalBobSend = bob.env.SendAddonMessage
bob.env.SendAddonMessage = function() error("simulated transport failure") end
local failedRoll, failedRollError = bobGA.RollSession:SubmitRoll(submitSession.id, "MS")
same(failedRoll, nil, "failed ROLL is reported")
expect(type(failedRollError) == "string", "failed ROLL exposes its transport error")
same(bobGA.RollSession:GetState(submitSession.id).participants.bob, nil, "failed ROLL restores participant state")
bob.env.SendAddonMessage = originalBobSend
expect(aliceGA.RollSession:Stop(submitSession.id, "TEST"), "submit rollback session stops")

local ackFailureSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
local originalAckSend = alice.env.SendAddonMessage
alice.env.SendAddonMessage = function() error("simulated ACK transport failure") end
local pendingAckRoll = bobGA.RollSession:SubmitRoll(ackFailureSession.id, "OS")
expect(pendingAckRoll and pendingAckRoll.pending, "participant remains pending while the host ACK is unavailable")
local hostRecordedRoll = aliceGA.RollSession:GetState(ackFailureSession.id).participants.bob
expect(hostRecordedRoll ~= nil, "host keeps a valid roll even when its ACK whisper fails")
same(hostRecordedRoll.choice, "OS", "host UI state retains the choice across ACK failure")
alice.env.SendAddonMessage = originalAckSend
advance(bob, bobGA.RollSession.ACK_RETRY_INTERVAL)
expect(not bobGA.RollSession:GetState(ackFailureSession.id).participants.bob.pending,
    "participant retry receives the cached authoritative ACK")
expect(aliceGA.RollSession:Stop(ackFailureSession.id, "TEST"), "ACK failure test session stops")

local passSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
local passed, passError = bobGA.RollSession:Pass(passSession.id)
expect(passed ~= nil, passError or "remote client explicitly passes")
local hostPass = aliceGA.RollSession:GetState(passSession.id).participants.bob
same(hostPass.choice, "PASS", "loot master receives the pass choice")
same(hostPass.roll, 0, "passing never creates a roll value")
expect(hostPass.passed, "pass participant is marked as passed")
expect(not passed.pending, "pass acknowledgement clears the participant pending state")
expect(aliceGA.RollSession:Stop(passSession.id, "TEST"), "pass test session stops")

-- Public Blizzard /roll messages allow group members without the addon to participate.
bobGA.DB:GetProfile().osRollMaximum = 17
local originalRaidCount, originalPartyCount = alice.env.GetNumRaidMembers, alice.env.GetNumPartyMembers
local originalUnitFullName = alice.env.UnitFullName
alice.env.GetNumRaidMembers = function() return 0 end
alice.env.GetNumPartyMembers = function() return 1 end
alice.env.UnitFullName = function(unit)
    if unit == "party1" then return "Flexdeineex", "Ascension" end
    return originalUnitFullName(unit)
end
local publicMSSession = aliceGA.RollSession:Start(itemLink, { duration = 30, osRollMaximum = 42 })
same(bobGA.RollSession:GetState(publicMSSession.id).osRollMaximum, 42, "START synchronizes the configured OS maximum")
same(bobGA.DB:GetProfile().osRollMaximum, 17, "a participant's local preference cannot override the loot master's session")
fire(alice, "CHAT_MSG_SYSTEM", "Flexdeineex rolls 37 (1 - 100)")
local publicMS = aliceGA.RollSession:GetState(publicMSSession.id).participants.flexdeineex
same(publicMS.choice, "MS", "/roll 100 is classified as MS")
same(publicMS.roll, 37, "public MS preserves the exact Ascension system-message result")
expect(publicMS.publicRoll, "public MS is marked as a chat-tracked roll")
expect(aliceGA.RollSession:Stop(publicMSSession.id, "TEST"), "public MS session stops")

-- Ascension can expose a valid party size while all party-name APIs return nil.
-- Public system rolls must still reach the authoritative loot-master session.
alice.env.UnitFullName = function() return nil end
local unresolvedPartySession = aliceGA.RollSession:Start(itemLink, { duration = 30, osRollMaximum = 42 })
expect(unresolvedPartySession ~= nil, "a roll starts while Ascension party-name APIs are unresolved")
fire(alice, "CHAT_MSG_SYSTEM", "|cff00ff00|Hplayer:Hiddenparty|h[Hiddenparty]|h|r rolls 54 (1 - 100)")
same(aliceGA.RollSession:GetState(unresolvedPartySession.id).participants.hiddenparty.roll, 54,
    "a grouped public roll survives missing Ascension party-name API results")
expect(aliceGA.RollSession:Stop(unresolvedPartySession.id, "TEST"), "unresolved-party public roll session stops")
alice.env.GetNumRaidMembers, alice.env.GetNumPartyMembers = originalRaidCount, originalPartyCount
alice.env.UnitFullName = originalUnitFullName

local publicOSSession = aliceGA.RollSession:Start(itemLink, { duration = 30, osRollMaximum = 42 })
fire(alice, "CHAT_MSG_SYSTEM", "Bob rolls 31 (1-99)")
same(aliceGA.RollSession:GetState(publicOSSession.id).participants.bob.choice, nil,
    "a roll with the wrong maximum is ignored")
fire(alice, "CHAT_MSG_SYSTEM", "Bob würfelt. Ergebnis: 31 (1-42)")
local publicOS = aliceGA.RollSession:GetState(publicOSSession.id).participants.bob
same(publicOS.choice, "OS", "configured /roll X is classified as OS")
same(publicOS.maximum, 42, "public OS records its configured range")
fire(alice, "CHAT_MSG_SYSTEM", "Bob rolls 41 (1-42)")
same(aliceGA.RollSession:GetState(publicOSSession.id).participants.bob.roll, 31,
    "a second public roll cannot replace the first accepted result")
expect(aliceGA.RollSession:Stop(publicOSSession.id, "TEST"), "public OS session stops")

-- Gargul's chat-filter path is required on clients that display a system line
-- without dispatching the regular event to every addon frame. The roller has
-- no addon involvement in this scenario; only the loot master's filter runs.
local filterSession = aliceGA.RollSession:Start(itemLink, { duration = 30, osRollMaximum = 42 })
expect(#alice.chatFilters.CHAT_MSG_SYSTEM > 0, "the loot master installs a CHAT_MSG_SYSTEM display filter")
alice.chatFilters.CHAT_MSG_SYSTEM[1](nil, "CHAT_MSG_SYSTEM", "Noaddon rolls 64 (1 - 100)")
local filterRoll = aliceGA.RollSession:GetState(filterSession.id).participants.noaddon
same(filterRoll.roll, 64, "the loot master's chat filter captures a player without the addon")
same(filterRoll.choice, "MS", "the chat-filter-only result is classified as MS")
expect(aliceGA.RollSession:Stop(filterSession.id, "TEST"), "chat-filter public-roll session stops")

-- If Ascension only delivers the system line to the rolling client, that
-- client relays its own exact public result to the session authority.
local relayedSession = aliceGA.RollSession:Start(itemLink, { duration = 30, osRollMaximum = 42 })
fire(bob, "CHAT_MSG_SYSTEM", "Bob rolls 73 (1 - 100)")
local relayedRoll = aliceGA.RollSession:GetState(relayedSession.id).participants.bob
same(relayedRoll.roll, 73, "the rolling client relays its public result to the loot master")
same(relayedRoll.choice, "MS", "the authority classifies a relayed /roll 100 as MS")
expect(aliceGA.RollSession:Stop(relayedSession.id, "TEST"), "relayed public-roll session stops")

-- Roll deadlines are local monotonic GetTime values, never transmitted wall-clock timestamps.
alice.now, bob.now = 5000, 20
local clockSession = aliceGA.RollSession:Start(itemLink, { duration = 20 })
expect(clockSession ~= nil, "clock-skew session starts")
local remoteClockSession = bobGA.RollSession:GetState(clockSession.id)
same(clockSession.expiresAt, 5020, "host deadline uses host-local GetTime")
same(remoteClockSession.expiresAt, 40, "participant deadline uses participant-local GetTime")
expect(clockSession.createdAt > clockSession.expiresAt, "wall-clock creation time is metadata, not a UI deadline")
local hostDeadline = clockSession.expiresAt
expect(aliceGA.RollSession:RequestSync(clockSession.id) ~= nil, "host may broadcast a sync request")
same(clockSession.expiresAt, hostDeadline, "self-echoed sync never rewrites the host deadline")
alice.now, bob.now = 5018.75, 123.5
expect(bobGA.RollSession:RequestSync(clockSession.id) ~= nil, "participant requests late-session sync")
remoteClockSession = bobGA.RollSession:GetState(clockSession.id)
expect(math.abs((remoteClockSession.expiresAt - bob.now) - 1.25) < 0.001,
    "late sync preserves the exact remaining time instead of extending to five seconds")
same(remoteClockSession.timeSource, "GetTime", "synced deadline documents its monotonic clock source")
expect(aliceGA.RollSession:Stop(clockSession.id, "TEST"), "clock-skew session stops cleanly")
alice.now, bob.now = 6000, 6000 -- keep subsequent integration scenarios on one forward-moving clock

-- The authority posts periodic countdowns and closes the session for every client at zero.
local chatStart = #alice.chatMessages
local countdownSession = aliceGA.RollSession:Start(itemLink, { duration = 60, osRollMaximum = 42 })
for _ = 1, 60 do advance(alice, 1) end
same(countdownSession.status, "STOPPED", "host closes the roll session when its deadline expires")
same(bobGA.RollSession:GetState(countdownSession.id).status, "STOPPED", "timeout closes the remote roll session")
local intervalSeen, countdownSeen, finalSecondSeen, timeoutSeen, instructionsSeen = false, false, false, false, false
for index = chatStart + 1, #alice.chatMessages do
    local message = alice.chatMessages[index].message
    if string.find(message, "/roll 100 für MS. /roll 42 für OS.", 1, true) then instructionsSeen = true end
    if string.find(message, "Noch 50 Sekunden", 1, true) then intervalSeen = true end
    if string.find(message, "Noch 10 Sekunden", 1, true) then countdownSeen = true end
    if string.find(message, "Noch 1 Sekunde", 1, true) then finalSecondSeen = true end
    if string.find(message, "abgelaufen", 1, true) then timeoutSeen = true end
end
expect(instructionsSeen, "roll start announcement names the public MS and configured OS commands")
expect(intervalSeen, "a 60-second roll posts ten-second interval reminders")
expect(countdownSeen, "group announcements begin a per-second countdown at ten")
expect(finalSecondSeen, "group announcements include the final second")
expect(timeoutSeen, "group announcements report the timeout")
bob.now = alice.now

-- A pending award follows through the observed 3.3.5 trade lifecycle.
alice.target = "Bob"
alice.env.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
alice.env.GetContainerItemLink = function(bag, slot) return bag == 0 and slot == 1 and itemLink or nil end
alice.env.GetContainerItemInfo = function(bag, slot)
    if bag == 0 and slot == 1 then return "icon", 1, false, 4, false, false, itemLink end
end
alice.env.GetTradePlayerItemLink = function(slot) return slot == 1 and itemLink or nil end
alice.env.GetTradePlayerItemInfo = function(slot) if slot == 1 then return "Ascension Test Item", "icon", 1, 4 end end
local pendingAward = aliceGA.Trade.pending[1]
expect(aliceGA.Trade:Prepare(pendingAward.id) ~= nil, "pending award resolves to a bag slot")
fire(alice, "TRADE_SHOW")
fire(alice, "TRADE_ACCEPT_UPDATE", 1, 1)
fire(alice, "UI_INFO_MESSAGE", "Trade complete.")
same(pendingAward.status, "DELIVERED", "successful trade completes the pending award")

-- Bag inspection uses the real fragmented Comm transport and group validation.
local bagUpdates = 0
bobGA.Events:On("GA_BAGINSPECT_UPDATED", function(_, _, player) if player == "Alice" then bagUpdates = bagUpdates + 1 end end)
local bagRequest, bagError = bobGA.BagInspector:Request("Alice")
expect(bagRequest ~= nil, bagError or "group member bag request is sent")
local bagSnapshot = bobGA.BagInspector:GetSnapshot("Alice-Ascension")
expect(bagSnapshot ~= nil, "bag response creates a remote snapshot")
same(#bagSnapshot.entries, 1, "bag response contains the captured item")
same(bagSnapshot.entries[1].link, itemLink, "bag response preserves the full item link")
same(bagSnapshot.entries[1].quantity, 1, "bag response preserves quantity")
same(bagUpdates, 1, "bag response emits the update event")
expect(bobGA.BagInspector:Request("Alice") == nil, "repeated bag request is rate limited")
expect(bobGA.BagInspector:Request("NotInRaid") == nil, "non-group bag request is rejected")
expect(#bobGA.BagInspector:GetPlayers() >= 2, "bag inspector exposes the current group roster")

fire(alice, "TRADE_CLOSED")
same(aliceGA.Trade.state, "COMPLETED", "TRADE_CLOSED does not downgrade a confirmed completion")

-- Masterloot remains GIVING until the exact loot slot is confirmed.
alice.env.GetNumLootItems = function() return 1 end
alice.env.GetLootSlotLink = function(slot) return slot == 1 and itemLink or nil end
alice.env.GetMasterLootCandidate = function(slot, index) return slot == 1 and index == 1 and "Bob" or nil end
alice.env.GiveMasterLoot = function(slot, candidate) alice.lastGive = { slot = slot, candidate = candidate } end
local confirmedSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
local confirmedResult = aliceGA.RollSession:Award(confirmedSession.id, "Bob", "MS", 91)
expect(confirmedResult ~= nil, "confirmed masterloot award starts")
same(alice.lastGive.slot, 1, "masterloot uses the bound loot slot")
same(aliceGA.DB.data.history.awards[#aliceGA.DB.data.history.awards].delivery, "GIVING", "masterloot starts in GIVING state")
fire(alice, "LOOT_SLOT_CLEARED", 1)
same(aliceGA.DB.data.history.awards[#aliceGA.DB.data.history.awards].delivery, "GIVEN", "slot clear confirms masterloot delivery")

local timeoutSession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
expect(aliceGA.RollSession:Award(timeoutSession.id, "Bob", "MS", 92) ~= nil, "unconfirmed masterloot award starts")
same(aliceGA.DB.data.history.awards[#aliceGA.DB.data.history.awards].delivery, "GIVING", "unconfirmed award waits for the server")
advance(alice, aliceGA.Award.confirmTimeout + 0.1)
same(aliceGA.DB.data.history.awards[#aliceGA.DB.data.history.awards].delivery, "PENDING", "masterloot timeout falls back to pending trade")
same(aliceGA.Trade.pending[#aliceGA.Trade.pending].winner, "Bob", "timeout creates the correct trade entry")

-- A closed roll remains awardable, and an inventory item awarded to the loot
-- master is complete immediately instead of creating an impossible self-trade.
alice.env.GetNumLootItems = function() return 0 end
alice.env.GetLootSlotLink = function() return nil end
local selfTradeCount, selfLedgerBefore = #aliceGA.Trade.pending, aliceGA.PlusOnes:GetStats("Alice").total
local selfInventorySession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
expect(aliceGA.RollSession:Stop(selfInventorySession.id, "TIMEOUT"), "inventory roll closes before winner selection")
local selfInventoryResult, selfInventoryError = aliceGA.RollSession:Award(selfInventorySession.id, "Alice", "MS", 77)
expect(selfInventoryResult ~= nil, selfInventoryError or "a closed roll can still award its winner")
same(aliceGA.DB.data.history.awards[#aliceGA.DB.data.history.awards].delivery, "GIVEN", "self-owned inventory item is recorded as delivered")
same(#aliceGA.Trade.pending, selfTradeCount, "self-owned inventory item never creates a self-trade")
same(aliceGA.PlusOnes:GetStats("Alice").total, selfLedgerBefore + 1, "self inventory award reaches the item ledger")

-- Persistent rule modules combine deterministically for master-looter ranking.
expect(aliceGA.SoftRes:Reserve("Bob", itemLink), "soft reserve accepts an item link")
expect(aliceGA.SoftRes:IsReserved("Bob-Ascension", itemLink), "soft reserve normalizes realm names")
expect(aliceGA.Priority:Set(itemLink, "Bob", 5), "priority accepts an item link")
same(aliceGA.PlusOnes:Set("Bob", 2), 2, "+1 value persists")
same(aliceGA.BoostedRolls:Set("Bob", 10), 10, "boosted roll value persists")
local hardReserveEvents = 0
aliceGA.Events:On("GA_HARDRES_CHANGED", function() hardReserveEvents = hardReserveEvents + 1 end)
expect(aliceGA.SoftRes:SetHardReserved(itemLink, true), "hard reserve accepts an item link")
same(hardReserveEvents, 1, "hard reserve emits its central change event")
local rankingSession = { itemLink = itemLink, participants = {
    bob = { name = "Bob", choice = "MS", roll = 40 },
    charlie = { name = "Charlie", choice = "MS", roll = 99 },
} }
local ranked = aliceGA.Ranking:GetSorted(rankingSession)
same(ranked[1].name, "Bob", "soft reserve and priority rank before raw roll")
same(ranked[1].effectiveRoll, 50, "boosted roll is reflected in effective score")

local gdkp = aliceGA.GDKP:Start("Harness Raid")
expect(gdkp ~= nil, "GDKP session starts")
expect(aliceGA.GDKP:AddSale(itemLink, "Bob", 1000) ~= nil, "GDKP sale is recorded")
same(aliceGA.GDKP:GetCut(), 1000, "GDKP cut uses unique participant count")
expect(aliceGA.GDKP:Finish() ~= nil, "GDKP session is persisted to history")
aliceGA.GDKP:Start("Auction Harness")
local auction = aliceGA.GDKPAuction:Start(itemLink, 100, 50, 30)
expect(auction ~= nil, "loot master starts a synchronized GDKP auction")
expect(bobGA.GDKPAuction:Bid(100), "participant sends the minimum bid")
same(aliceGA.GDKPAuction.active.currentBid, 100, "auction host validates the bid")
same(bobGA.GDKPAuction.active.currentBidder, "Bob", "auction update reaches the participant")
same(#aliceGA.GDKPAuction.active.bids, 1, "host records the bid once despite sender echo")
bobGA.Comm:Send("AUC_BID", { auction.id, 1, 100 }, "WHISPER", "Alice")
same(#aliceGA.GDKPAuction.active.bids, 1, "replayed bid sequence is ignored")
same(bobGA.GDKPAuction:Bid(100), nil, "rebid must increase by the configured increment")
expect(bobGA.GDKPAuction:Bid(150), "monotone rebid is accepted")

local aliceAuctionSend = alice.env.SendAddonMessage
alice.env.SendAddonMessage = function() error("simulated auction update failure") end
expect(bobGA.GDKPAuction:Bid(200), "bid request reaches the host even if its update fails")
same(aliceGA.GDKPAuction.active.currentBid, 150, "failed AUC_UPDATE restores current bid")
same(aliceGA.GDKPAuction.active.currentBidder, "Bob", "failed AUC_UPDATE restores bidder")
same(#aliceGA.GDKPAuction.active.bids, 2, "failed AUC_UPDATE removes speculative history")
alice.env.SendAddonMessage = aliceAuctionSend
expect(bobGA.GDKPAuction:Bid(250), "higher bid works after update rollback")
alice.env.SendAddonMessage = function(prefix, payload, channel, target)
    if string.find(payload, "AUC_UPDATE", 1, true) then error("simulated host self-update failure") end
    deliver(prefix, payload, channel, alice, target)
end
expect(aliceGA.GDKPAuction:Bid(300), "host self-bid request is locally received")
same(aliceGA.GDKPAuction.active.currentBid, 250, "failed host self-update restores current bid")
same(aliceGA.GDKPAuction.active.localBidSequence, 0, "failed host self-update restores local bid sequence")
alice.env.SendAddonMessage = aliceAuctionSend
expect(aliceGA.GDKPAuction:Bid(300), "auction host may bid through self-whisper")
same(#aliceGA.GDKPAuction.active.bids, 4, "host self-echo does not duplicate its bid")
same(#bobGA.GDKPAuction.active.bids, 4, "remote bid history stays sequence-aligned")

alice.now, bob.now = auction.endsAt - 5, auction.endsAt - 5
local previousEnd = auction.endsAt
expect(bobGA.GDKPAuction:Bid(350), "late monotone bid is accepted")
same(auction.endsAt, previousEnd + 5, "anti-snipe extends back to the configured window")
expect(auction.endsAt <= auction.hardEndsAt, "anti-snipe extension respects its hard cap")
expect(aliceGA.GDKPAuction:Stop("TEST") ~= nil, "auction host closes the auction")
same(bobGA.GDKPAuction.active.status, "ENDED", "auction end reaches the participant")
same(aliceGA.GDKP.active.sales[1].amount, 350, "winning auction becomes a GDKP sale")
expect(aliceGA.GDKP:AddSale(nil, nil, 0) == nil, "GDKP rejects malformed sales without throwing")
local activeProfile = aliceGA.DB:GetProfile()
activeProfile.sound = false
activeProfile.defaultRollDuration = nil -- simulate a profile saved by an older build
fire(alice, "PLAYER_LOGOUT")
local reloaded = makeClient("Reloaded", alice.env.MasterLooterDB)
local reloadedGA = loadAddon(reloaded)
same(reloadedGA.GDKP.active.name, "Auction Harness", "active GDKP session survives reload")
same(reloadedGA.GDKP.active.sales[1].amount, 350, "active GDKP sales survive reload")
same(reloadedGA.DB:GetProfile().sound, false, "existing profile values survive default merging")
same(reloadedGA.DB:GetProfile().defaultRollDuration, 30, "existing profiles receive newly introduced defaults")
expect(reloadedGA.GDKP:Finish() ~= nil, "restored GDKP session can be finished")
same(reloadedGA.GDKP:GetCut(10), 0, "GetCut is safe without an active session")
local exportText, exported = aliceGA.ImportExport:Export({ awards = false, gdkp = false })
expect(exported >= 4, "rules export contains configured records")
local validation = aliceGA.ImportExport:Validate(exportText)
expect(validation.valid, "deterministic rules export validates")
local backupCount = #aliceGA.ImportExport:GetBackups()
local imported, importError = aliceGA.ImportExport:Import(exportText, { merge = true })
expect(imported ~= nil, importError or "validated data can be imported")
same(#aliceGA.ImportExport:GetBackups(), backupCount + 1, "imports create an automatic rollback backup")
expect(aliceGA.ImportExport:RestoreBackup(1), "the newest import backup can be restored")
local awardsCSV = aliceGA.ImportExport:ExportCSV("awards")
expect(type(awardsCSV) == "string" and string.find(awardsCSV, "time,item", 1, true), "award history exports as CSV")
expect(#aliceGA.Comm:GetTrace() > 0, "communication diagnostics retain bounded traffic entries")
expect(string.find(aliceGA.Comm:ExportTrace(), "OUT", 1, true), "communication trace has a copyable export")

local recoverySession = aliceGA.RollSession:Start(itemLink, { duration = 30 })
expect(recoverySession ~= nil, "a recovery test session starts")
aliceGA.RollSession:PersistActive()
same(aliceGA.DB.data.character.rollSession.active.id, recoverySession.id, "the active host session is persisted")
expect(aliceGA.RollSession:Stop(recoverySession.id, "RECOVERY_TEST"), "the recovery test session stops")
same(aliceGA.DB.data.character.rollSession.active, nil, "stopped sessions are removed from recovery storage")

-- Optional item-data addon learns and searches actual runtime item links.
local itemNamespace = {}
alice.env.GetItemInfo = function(item)
    local id = tonumber(tostring(item):match("item:(%-?%d+)")) or tonumber(item)
    if id == 9000001 then
        return "Ascension Test Item", itemLink, 4, 80, 80, "Armor", "Plate", 1, "INVTYPE_CHEST", "test-icon"
    end
end
loadFile(alice, "../MasterLooter_ItemData/ItemData.lua", "MasterLooter_ItemData", itemNamespace)
fire(alice, "ADDON_LOADED", "MasterLooter_ItemData")
expect(itemNamespace:LearnLink(itemLink), "item-data addon learns a runtime link")
local learned = itemNamespace:Get(9000001)
same(learned.name, "Ascension Test Item", "learned item keeps its runtime name")
same(itemNamespace:Search("ascension test", 5)[1].itemID, 9000001, "item search returns learned custom ID")
same(alice.env.MasterLooterItemDB.schema, 2, "item data uses the contextual schema")
expect(itemNamespace:GetContext() ~= nil, "item data exposes its realm/locale/interface context")

-- Delayed events from a completed queue item must never disable the next item's buttons.
aliceGA.UI = aliceGA.UI or {}
aliceGA.UI.Theme = { colors = { muted = { 0.5, 0.5, 0.5, 1 }, green = { 0, 1, 0, 1 } } }
alice.env.unpack = alice.env.unpack or table.unpack
loadFile(alice, "UI/RollWindow.lua")
local rollWindow = aliceGA.UI.RollWindow
same(rollWindow.WIDTH, 520, "the Gargul-style participant widget stays compact")
same(rollWindow.HEIGHT, 84, "the participant widget remains a shallow bar instead of a dialog")
rollWindow.frame = { Hide = function() end }
rollWindow.session, rollWindow.sessionId = {}, "queue-item-2"
rollWindow.status = { SetText = function() end, SetTextColor = function() end }
rollWindow.SetButtonsEnabled = function(self, enabled) self.lastButtonsEnabled = enabled end
same(rollWindow:EndSession("AWARDED", { id = "queue-item-1" }), false,
    "a delayed end event from the first queue item is ignored")
same(rollWindow.lastButtonsEnabled, nil, "the second queue item's buttons stay enabled after a stale end event")
same(rollWindow:Confirm({ name = "Alice", choice = "MS", roll = 88 }, { id = "queue-item-1" }), false,
    "a delayed roll acknowledgement from the first queue item is ignored")
same(rollWindow.lastButtonsEnabled, nil, "a stale acknowledgement cannot gray the second queue item's buttons")
expect(rollWindow:EndSession("STOPPED", { id = "queue-item-2" }),
    "the current queue item's own end event is still applied")
same(rollWindow.lastButtonsEnabled, false, "the current queue item disables its buttons when it actually ends")

loadFile(alice, "UI/MasterLooterWindow.lua")
same(aliceGA.UI.MasterLooterWindow.WIDTH, 540, "the Gargul-style loot-master window keeps its compact width")
same(aliceGA.UI.MasterLooterWindow.HEIGHT, 470, "the loot-master controls and roll table fit one compact window")
same(aliceGA.UI.MasterLooterWindow.VISIBLE_ROWS, 6, "the loot-master table uses a dense visible roll list")
same(aliceGA.UI.MasterLooterWindow.LAYOUT_VERSION, 2, "the non-overlapping loot-master layout is active")
same(aliceGA.UI.MasterLooterWindow.OS_EDIT_X, 275, "the OS input is separated from its label")
same(aliceGA.UI.MasterLooterWindow.PAGINATION_Y, -170, "pagination sits above rather than over the table headers")
local displayedRolls = aliceGA.UI.MasterLooterWindow:BuildRollList({ participants = {
    driomodo = { name = "Driomodo", choice = "MS", roll = 13 },
} })
same(#displayedRolls, 1, "a public roll with no optional effectiveRoll reaches the loot-master table")
same(displayedRolls[1].effectiveRoll, 13, "a missing optional effectiveRoll falls back to the public result")

-- Loot capture stays in the background until the user explicitly opens its window.
loadFile(alice, "UI/LootWindow.lua")
local lootWindow, lootRefreshes, lootShows = aliceGA.UI.LootWindow, 0, 0
lootWindow.frame = { Show = function() lootShows = lootShows + 1 end }
lootWindow.EnsureFrame = function(self) return self.frame end
lootWindow.Refresh = function() lootRefreshes = lootRefreshes + 1 end
lootWindow:OnInitialize()
aliceGA.Events:Emit("GA_LOOT_OPENED", { open = true, order = {}, slots = {} })
same(lootRefreshes, 1, "opening any loot source refreshes the captured snapshot in the background")
same(lootShows, 0, "crafting, disenchanting and ordinary loot never auto-open the captured-loot window")
lootWindow:Show()
same(lootShows, 1, "the captured-loot window remains available through an explicit user action")

-- Gargul-style navigation uses one independent settings hub instead of an
-- attached minimap popup. It remains available without loot or group state.
loadFile(alice, "UI/SettingsWindow.lua")
local settingsWindow = aliceGA.UI.SettingsWindow
same(settingsWindow.WIDTH, 800, "the standalone settings hub uses Gargul's broad window format")
same(settingsWindow.HEIGHT, 600, "the standalone settings hub has room for persistent navigation")
same(#settingsWindow:GetSections(), 5, "the settings hub exposes all top-level categories")
same(settingsWindow:GetSections()[1].id, "HOME", "the settings hub opens on its overview")
same(settingsWindow:GetSections()[3].id, "LOOT", "loot settings remain available outside the loot-master dialog")

loadFile(alice, "UI/Launcher.lua")
local launcher = aliceGA.UI.Launcher
same(launcher:GetClickAction("LeftButton", false), "SettingsWindow", "minimap left-click opens the independent settings hub")
same(launcher:GetClickAction("RightButton", false), "ImportExportWindow", "minimap right-click opens import and export directly")
same(launcher:GetClickAction("MiddleButton", false), "HistoryWindow", "minimap middle-click opens history directly")
same(launcher:GetClickAction("LeftButton", true), "SoftResWindow", "shift-left-click opens SoftRes directly")
same(launcher:GetClickAction("RightButton", true), "ImportExportWindow", "shift-right-click remains a direct data action")

local commands = aliceGA:GetModule("Commands")
local settingsShows, masterShows = 0, 0
aliceGA.UI.SettingsWindow.Show = function() settingsShows = settingsShows + 1 end
aliceGA.UI.MasterLooterWindow.Show = function() masterShows = masterShows + 1 end
commands:Handle("")
same(settingsShows, 1, "/ml opens the independent overview")
same(masterShows, 0, "/ml no longer forces the loot-master dialog open")
commands:Handle("master")
same(masterShows, 1, "/ml master still opens the loot-master workflow directly")

print(string.format("PASS: %d assertions; two clients; Comm; rolls; rules; GDKP; items", assertions))
