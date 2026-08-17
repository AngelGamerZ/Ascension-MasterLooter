local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end
local function contains(value, needle)
    return string.find(tostring(value or ""), needle, 1, true) ~= nil
end

local now = 100
local sentPackets, chatMessages, emitted = {}, {}, {}
function GetTime() return now end
function time() return 1700000000 + now end
function UnitName(unit) return unit == "player" and "Lootmaster" or nil end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function UnitIsPartyLeader() return false end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
function SendChatMessage(message, channel)
    chatMessages[#chatMessages + 1] = { message = message, channel = channel }
end

local profile = {
    announcements = { enabled = true, rollStart = true, rollStop = true, countdown = true,
        award = true, channel = "SAY", raidWarningDefaultV1 = true },
}
local GA = {
    modules = {},
    DB = { data = { character = {} }, GetProfile = function() return profile end },
    Compat = {
        IsInRaid = function() return false end,
        IsInGroup = function() return false end,
        GetItemID = function() return nil end,
    },
    Events = {
        Emit = function(_, event, ...) emitted[#emitted + 1] = { event, ... } end,
        On = function() end,
    },
    Comm = {
        Send = function(_, messageType, fields, channel, target)
            sentPackets[#sentPackets + 1] = { type = messageType, fields = fields, channel = channel, target = target }
            return "packet-" .. tostring(#sentPackets)
        end,
    },
}
function GA:RegisterModule(name, module) self.modules[name] = module end

local rollChunk, rollError = loadfile("MasterLooter/Modules/RollSession.lua")
if not rollChunk then error(rollError) end
rollChunk("MasterLooter", GA)
local announcementChunk, announcementError = loadfile("MasterLooter/Modules/Announcements.lua")
if not announcementChunk then error(announcementError) end
announcementChunk("MasterLooter", GA)

local RollSession, Announcements = GA.RollSession, GA.Announcements
local item = "|cffa335ee|Hitem:9000001:0:0:0:0:0:0:0|h[Test Item]|h|r"

local function hasChoice(state, wanted)
    for _, choice in ipairs(state.choices or {}) do if choice == wanted then return true end end
    return false
end

-- Missing choice data is the compatibility contract for sessions created by
-- older MasterLooter versions: every established category remains available.
local legacy = assert(RollSession:Start(item, { duration = 30, osRollMaximum = 42 }))
expect(hasChoice(legacy, "MS") and hasChoice(legacy, "OS") and hasChoice(legacy, "TRANSMOG") and hasChoice(legacy, "PASS"),
    "legacy sessions without explicit choices retain every roll action")
RollSession:Stop(legacy.id, "TEST")

local combinations = {
    { choices = { "MS", "PASS" }, os = false, transmog = false },
    { choices = { "MS", "OS", "PASS" }, os = true, transmog = false },
    { choices = { "MS", "TRANSMOG", "PASS" }, os = false, transmog = true },
    { choices = { "MS", "OS", "TRANSMOG", "PASS" }, os = true, transmog = true },
}
for index, combination in ipairs(combinations) do
    local state = assert(RollSession:Start(item, {
        duration = 30, osRollMaximum = 42, choices = combination.choices,
    }))
    same(hasChoice(state, "MS"), true, "MS remains enabled for combination " .. index)
    same(hasChoice(state, "PASS"), true, "Pass remains enabled for combination " .. index)
    same(hasChoice(state, "OS"), combination.os, "OS state for combination " .. index)
    same(hasChoice(state, "TRANSMOG"), combination.transmog, "Transmog state for combination " .. index)
    same(RollSession:GetChoiceForMaximum(state, 100), "MS", "public /roll 100 remains MS")
    same(RollSession:GetChoiceForMaximum(state, 42), combination.os and "OS" or nil,
        "public OS classification follows the host choice")
    same(RollSession:GetChoiceForMaximum(state, 50), combination.transmog and "TRANSMOG" or nil,
        "public Transmog classification follows the host choice")

    local osSubmission = RollSession:SubmitRoll(state.id, "OS")
    same(osSubmission ~= nil, combination.os, "addon OS submissions follow the host choice")
    -- Use a fresh session because a local addon choice is allowed only once in
    -- normal operation and must not obscure the Transmog validation.
    RollSession:Stop(state.id, "TEST")
    state = assert(RollSession:Start(item, {
        duration = 30, osRollMaximum = 42, choices = combination.choices,
    }))
    local transmogSubmission = RollSession:SubmitRoll(state.id, "TRANSMOG")
    same(transmogSubmission ~= nil, combination.transmog, "addon Transmog submissions follow the host choice")

    chatMessages = {}
    Announcements.lastSent = -1000
    Announcements:OnRollStarted(state)
    same(#chatMessages, 1, "roll start emits one instruction message for combination " .. index)
    local message = chatMessages[1].message
    expect(contains(message, "/roll 100") and contains(message, "MS"), "start announcement always names MS")
    same(contains(message, "/roll 42"), combination.os, "start announcement follows the OS choice")
    same(contains(message, "/roll 50"), combination.transmog, "start announcement follows the Transmog choice")
    RollSession:Stop(state.id, "TEST")
end

-- Disabled public categories must be rejected, including players without the
-- addon whose rolls arrive exclusively through Blizzard system chat.
local restricted = assert(RollSession:Start(item, {
    duration = 30, osRollMaximum = 42, choices = { "MS", "PASS" },
}))
local publicOS, publicOSError = RollSession:RecordPublicRoll("Raider", 31, 1, 42, restricted.id)
expect(publicOS == nil and type(publicOSError) == "string", "disabled public OS rolls are rejected")
local publicTransmog, publicTransmogError = RollSession:RecordPublicRoll("Raider", 31, 1, 50, restricted.id)
expect(publicTransmog == nil and type(publicTransmogError) == "string", "disabled public Transmog rolls are rejected")

print(string.format("PASS: %d configurable roll-choice assertions", assertions))
