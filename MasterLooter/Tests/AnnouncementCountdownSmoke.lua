local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local now, messages = 0, {}
function GetTime() return now end
function UnitName() return "Lootmaster" end
function GetNumRaidMembers() return 0 end
function UnitIsRaidOfficer() return false end
function UnitIsPartyLeader() return false end
function CreateFrame() return { SetScript = function() end } end
function SendChatMessage(message, channel)
    messages[#messages + 1] = { message = message, channel = channel }
end

local profile = { announcements = {
    enabled = true, rollStart = true, rollStop = true, countdown = true, award = true,
    channel = "SAY", raidWarningDefaultV1 = true,
} }
local GA = {
    modules = {},
    DB = { GetProfile = function() return profile end },
    Compat = {
        IsInRaid = function() return false end,
        IsInGroup = function() return false end,
        GetItemID = function() return nil end,
    },
    Events = { Emit = function() end, On = function() end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end

local chunk, loadError = loadfile("MasterLooter/Modules/Announcements.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)
local Announcements = GA.Announcements

same(Announcements:GetConfig().finalCountdownSeconds, 10,
    "legacy profiles default to the established ten-second final countdown")
expect(Announcements:SetOption("finalCountdownSeconds", 3), "a final countdown length can be persisted")
same(profile.announcements.finalCountdownSeconds, 3, "the final countdown length is stored in the profile")
expect(Announcements:SetOption("finalCountdownSeconds", "7"), "numeric dropdown values are accepted")
same(profile.announcements.finalCountdownSeconds, 7, "numeric dropdown values are normalized")
local beforeInvalid = profile.announcements.finalCountdownSeconds
expect(not Announcements:SetOption("finalCountdownSeconds", 0), "values below the dropdown range are rejected")
same(profile.announcements.finalCountdownSeconds, beforeInvalid, "a rejected lower value preserves the profile")
expect(not Announcements:SetOption("finalCountdownSeconds", 99), "values above the dropdown range are rejected")
same(profile.announcements.finalCountdownSeconds, beforeInvalid, "a rejected upper value preserves the profile")
expect(not Announcements:SetOption("finalCountdownSeconds", "invalid"), "non-numeric countdown values are rejected")
same(profile.announcements.finalCountdownSeconds, beforeInvalid, "invalid input preserves the saved countdown")

local item = "|cffa335ee|Hitem:9000001:0:0:0:0:0:0:0|h[Test Item]|h|r"
local function announcedSeconds(finalSeconds)
    profile.announcements.finalCountdownSeconds = finalSeconds
    messages, now = {}, 0
    Announcements.lastSent = -1000
    local state = {
        id = "countdown-" .. tostring(finalSeconds), itemLink = item, owner = "Lootmaster",
        duration = 60, expiresAt = 60, status = "ACTIVE", osRollMaximum = 42,
        choices = { "MS", "OS", "TRANSMOG", "PASS" },
    }
    Announcements:OnRollStarted(state)
    messages = {} -- The start instruction is not part of the countdown sample.
    local result = {}
    for remaining = 59, 1, -1 do
        now = 60 - remaining
        local previousCount = #messages
        Announcements:Tick()
        if #messages > previousCount then result[#result + 1] = remaining end
    end
    return result
end

local function sameSequence(actual, expected, message)
    same(#actual, #expected, message .. " length")
    for index, value in ipairs(expected) do same(actual[index], value, message .. " entry " .. index) end
end

sameSequence(announcedSeconds(1), { 50, 40, 30, 20, 10, 1 },
    "one-second mode retains ten-second milestones and only announces the final second")
profile.announcements.enabled = false -- legacy value from the former global switch
sameSequence(announcedSeconds(1), { 50, 40, 30, 20, 10, 1 },
    "the loot-master notice toggle cannot disable roll countdown announcements")
profile.announcements.enabled = true
sameSequence(announcedSeconds(3), { 50, 40, 30, 20, 10, 3, 2, 1 },
    "three-second mode adds exactly the selected closing sequence")
sameSequence(announcedSeconds(10), { 50, 40, 30, 20, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 },
    "ten-second mode preserves the established closing countdown")

print(string.format("PASS: %d configurable announcement-countdown assertions", assertions))
