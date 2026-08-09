local assertions = 0
local function same(actual, expected, message)
    assertions = assertions + 1
    if actual ~= expected then
        error("ASSERTION FAILED: " .. tostring(message) .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")", 2)
    end
end

local clientLocale = "deDE"
function GetLocale() return clientLocale end

local profile = { language = "AUTO" }
local GA = {
    DB = { data = {}, GetProfile = function() return profile end },
    Events = { Emit = function() end },
}

local function load(path)
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    chunk("MasterLooter", GA)
end

load("MasterLooter/Core/Localization.lua")
load("MasterLooter/Locales/enUS.lua")
load("MasterLooter/Locales/deDE.lua")
load("MasterLooter/Locales/Errors.lua")

local rawCount = 0
profile.language = "enUS"
for source, english in pairs(GA.Locale.raw) do
    rawCount = rawCount + 1
    same(GA:Localize(source), english, "every German error alias resolves to English")
end
if rawCount < 100 then error("ASSERTION FAILED: module-error catalog is unexpectedly small", 2) end
profile.language = "deDE"
for english, source in pairs(GA.Locale.rawReverse) do
    same(GA:Localize(english), source, "every English error alias resolves to German")
end

local samples = {
    { "Profil nicht gefunden.", "Profile not found." },
    { "Spieler ist kein gültiger Loot-Kandidat (meist Entfernung oder Berechtigung).", "The player is not an eligible loot candidate (usually due to range or permissions)." },
    { "SoftRes-Limit für diesen Spieler überschritten", "The SoftRes limit for this player has been exceeded" },
    { "Keine aktive GDKP-Sitzung", "No active GDKP session" },
    { "Kein unterstützter BISBEARD-RollFor-Export", "Unsupported BISBEARD RollFor export" },
    { "Keine Raid-Berechtigung", "No raid permission" },
    { "Alle verfügbaren Exemplare wurden bereits vergeben", "all available copies have already been awarded" },
    { "Gewinner ist nicht in Handelsreichweite.", "The winner is not in trade range." },
    { "Spieler ist nicht in der aktuellen Gruppe", "player is not in the current group" },
}

-- A German client receives German even when the originating module still
-- returns an English literal.
for _, sample in ipairs(samples) do
    same(GA:Localize(sample[2]), sample[1], "English module error translates to German")
    same(GA:Localize(sample[1]), sample[1], "German module error stays German")
end
same(GA:Localize("Minimum bid: 250"), "Mindestgebot: 250", "dynamic minimum-bid detail translates to German")
same(GA:Localize("The JSON could not be read: byte 4"), "JSON konnte nicht gelesen werden: byte 4", "dynamic JSON detail translates to German")

profile.language = "enUS"
for _, sample in ipairs(samples) do
    same(GA:Localize(sample[1]), sample[2], "German module error translates to English")
    same(GA:Localize(sample[2]), sample[2], "English module error stays English")
end
same(GA:Localize("Mindestgebot: 250"), "Minimum bid: 250", "dynamic minimum-bid detail translates to English")
same(GA:Localize("JSON konnte nicht gelesen werden: byte 4"), "The JSON could not be read: byte 4", "dynamic JSON detail translates to English")

print(string.format("PASS: %d module-error localization assertions", assertions))
