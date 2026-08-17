local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local clientLocale = "deDE"
function GetLocale() return clientLocale end
function UnitName() return "Lootmaster" end
function GetNumRaidMembers() return 0 end
function CreateFrame()
    return { SetScript = function() end }
end

local profile = { language = "AUTO", announcements = { channel = "AUTO", raidWarningDefaultV1 = true } }
local emitted = {}
local groupState = { grouped = false, raid = false, officer = false, guild = false }
local GA = {
    modules = {}, UI = {},
    DB = { data = {}, GetProfile = function() return profile end },
    Events = {
        Emit = function(_, event, ...) emitted[#emitted + 1] = { event, ... } end,
        On = function() end,
    },
    Compat = {
        IsInGroup = function() return groupState.grouped end,
        IsInRaid = function() return groupState.raid end,
    },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function UnitIsRaidOfficer() return groupState.officer end
function UnitIsPartyLeader() return false end
function IsInGuild() return groupState.guild end

local localeChunk, localeError = loadfile("MasterLooter/Core/Localization.lua")
if not localeChunk then error(localeError) end
localeChunk("MasterLooter", GA)
for _, path in ipairs({ "MasterLooter/Locales/enUS.lua", "MasterLooter/Locales/deDE.lua" }) do
    local catalogChunk, catalogError = loadfile(path)
    if not catalogChunk then error(catalogError) end
    catalogChunk("MasterLooter", GA)
end

local translations = GA.Localization.TRANSLATIONS
expect(type(translations) == "table", "translation catalog is exposed for completeness checks")
expect(type(translations.enUS) == "table" and type(translations.deDE) == "table", "English and German catalogs exist")
for key, english in pairs(translations.enUS) do
    expect(type(english) == "string" and english ~= "", "English translation is populated: " .. tostring(key))
    expect(type(translations.deDE[key]) == "string" and translations.deDE[key] ~= "", "German translation exists: " .. tostring(key))
end
for key in pairs(translations.deDE) do
    expect(translations.enUS[key] ~= nil, "German catalog has no orphan key: " .. tostring(key))
end

same(GA.Localization:GetLanguageMode(), "AUTO", "language starts in automatic mode")
same(GA.Localization:GetLanguage(), "deDE", "automatic mode follows a supported German client")
same(GA:L("language.name.english"), "Englisch", "German locale resolves a translated key")

clientLocale = "frFR"
same(GA.Localization:GetLanguage(), "enUS", "an unsupported client locale falls back to English")
same(GA:L("language.name.german"), "German", "fallback locale resolves English text")

expect(GA.Localization:SetLanguage("deDE"), "German override is accepted")
same(profile.language, "deDE", "German override is persisted in the active profile")
same(GA.Localization:GetLanguage(), "deDE", "German override ignores an unsupported client locale")
same(emitted[#emitted][1], "GA_LOCALE_CHANGED", "changing language emits a refresh event")

expect(GA.Localization:SetLanguage("enUS"), "English override is accepted")
same(GA.Localization:GetLanguage(), "enUS", "English override becomes active immediately")
expect(GA.Localization:SetLanguage("AUTO"), "automatic language selection can be restored")
same(GA.Localization:GetLanguage(), "enUS", "restored automatic mode still falls back safely")
local savedMode = profile.language
expect(not GA.Localization:SetLanguage("frFR"), "unsupported language overrides are rejected")
same(profile.language, savedMode, "a rejected language does not corrupt the saved choice")
same(GA:L("test.missing.translation"), "test.missing.translation", "missing keys have a readable key fallback")

local announcementChunk, announcementError = loadfile("MasterLooter/Modules/Announcements.lua")
if not announcementChunk then error(announcementError) end
announcementChunk("MasterLooter", GA)
local Announcements = GA.Announcements

same(Announcements:GetConfig().finalCountdownSeconds, 10, "final countdown defaults to the legacy 10-to-1 sequence")
expect(Announcements:SetOption("finalCountdownSeconds", 3), "a valid final-countdown range is persisted")
same(profile.announcements.finalCountdownSeconds, 3, "saved final-countdown range uses the numeric value")
expect(not Announcements:SetOption("finalCountdownSeconds", 0), "a final-countdown range below 1 is rejected")
expect(not Announcements:SetOption("finalCountdownSeconds", 11), "a final-countdown range above 10 is rejected")
same(profile.announcements.finalCountdownSeconds, 3, "invalid final-countdown input preserves the previous value")

local expectedOptions = { "AUTO", "RAID_WARNING", "RAID", "PARTY", "SAY", "YELL", "GUILD", "OFFICER" }
local options = Announcements:GetChannelOptions()
same(#options, #expectedOptions, "channel selector exposes every supported option")
for index, expected in ipairs(expectedOptions) do
    same(options[index], expected, "channel option " .. tostring(index))
end
options[1] = "BROKEN"
same(Announcements:GetChannelOptions()[1], "AUTO", "callers cannot mutate the channel option registry")

same(Announcements:NormalizeChannel("raid warning"), "RAID_WARNING", "spaced raid-warning input normalizes")
same(Announcements:NormalizeChannel("rw"), "RAID_WARNING", "RW alias normalizes")
same(Announcements:NormalizeChannel("group"), "PARTY", "group alias normalizes")
same(Announcements:NormalizeChannel("yell"), "YELL", "case-insensitive channel normalizes")
same(Announcements:NormalizeChannel("guild"), "GUILD", "guild channel normalizes")
same(Announcements:NormalizeChannel("officer"), "OFFICER", "officer channel normalizes")
same(Announcements:NormalizeChannel("trade"), nil, "unsupported announcement channel is rejected")

expect(Announcements:SetOption("channel", "say"), "a valid channel is persisted")
same(profile.announcements.channel, "SAY", "saved channel uses its canonical value")
local savedChannel = profile.announcements.channel
expect(not Announcements:SetOption("channel", "TRADE"), "an invalid channel cannot be persisted")
same(profile.announcements.channel, savedChannel, "invalid input preserves the previous channel")

same(Announcements:ResolveChannel("SAY"), "SAY", "say remains available outside a group")
same(Announcements:ResolveChannel("YELL"), "YELL", "yell remains available outside a group")
same(Announcements:ResolveChannel("GUILD"), nil, "guild chat is unavailable outside a guild")
same(Announcements:ResolveChannel("OFFICER"), nil, "officer chat is unavailable outside a guild")
groupState.guild = true
same(Announcements:ResolveChannel("GUILD"), "GUILD", "guild chat is retained for guild members")
same(Announcements:ResolveChannel("OFFICER"), "OFFICER", "officer chat is retained for guild members")
same(Announcements:ResolveChannel("AUTO"), nil, "automatic group chat is disabled while solo")
groupState.grouped = true
same(Announcements:ResolveChannel("AUTO"), "PARTY", "automatic mode chooses party chat in a group")
same(Announcements:ResolveChannel("RAID"), "PARTY", "raid selection safely degrades in a party")
groupState.raid = true
same(Announcements:ResolveChannel("AUTO"), "RAID", "automatic mode chooses raid chat without warning permission")
same(Announcements:ResolveChannel("RAID_WARNING"), "RAID", "raid warning degrades without permission")
groupState.officer = true
same(Announcements:ResolveChannel("AUTO"), "RAID_WARNING", "automatic mode prefers raid warning with permission")
same(Announcements:ResolveChannel("RAID_WARNING"), "RAID_WARNING", "raid warning is retained with permission")

local now, countdownMessages = 50, {}
GetTime = function() return now end
Announcements.Send = function(_, message) countdownMessages[#countdownMessages + 1] = message; return true end
Announcements.activeRoll = { id = "countdown", owner = "Lootmaster", status = "ACTIVE", expiresAt = 100, itemLink = "[Test item]" }
Announcements.lastCountdownSecond = nil
for _, remaining in ipairs({ 50, 49, 40, 11, 10, 9, 3, 2, 1, 0 }) do
    now = 100 - remaining
    Announcements:Tick()
end
same(#countdownMessages, 6, "range 3 announces 50, 40, 10 and the final 3-to-1 sequence only")
expect(string.find(countdownMessages[1], "50", 1, true), "first ten-second interval is announced")
expect(string.find(countdownMessages[3], "10", 1, true), "10 seconds remains an interval announcement")
expect(string.find(countdownMessages[4], "3", 1, true) and string.find(countdownMessages[6], "1", 1, true),
    "selected final countdown is announced completely")

print(string.format("PASS: %d localization and announcement-channel assertions", assertions))
