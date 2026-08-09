local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local clientLocale = "enUS"
function GetLocale() return clientLocale end

local profile = { language = "AUTO" }
local GA = {
    UI = {},
    DB = { data = {}, GetProfile = function() return profile end },
}

local function load(path)
    local chunk, loadError = loadfile(path)
    if not chunk then error(loadError) end
    chunk("MasterLooter", GA)
end

load("MasterLooter/Core/Localization.lua")
load("MasterLooter/Locales/enUS.lua")
load("MasterLooter/Locales/deDE.lua")
load("MasterLooter/Locales/UI.lua")

local rawCount = 0
for _ in pairs(GA.Locale.raw) do rawCount = rawCount + 1 end
expect(rawCount >= 350, "the user-facing legacy UI catalog remains comprehensive")

local englishSamples = {
    ["MasterLooter – Lootmaster"] = "MasterLooter — Loot Master",
    ["Item hier ablegen"] = "Drop item here",
    ["Regeln & Strichliste öffnen"] = "Open rules and +1 list",
    ["GDKP – Verwaltung und Ledger"] = "GDKP — management and ledger",
    ["Tascheninspektor"] = "Bag inspector",
    ["Raid-Verwaltung"] = "Raid management",
    ["Versionsprüfung"] = "Version check",
    ["Minimap-Button anzeigen"] = "Show minimap button",
    ["Strg+A und Strg+C kopieren den vollständigen Trace."] = "Ctrl+A and Ctrl+C copy the complete trace.",
}
for source, translated in pairs(englishSamples) do
    same(GA:Localize(source), translated, "English UI translation for " .. source)
end
same(GA:Localize("Gewinner: Alice (MS)"), "Winner: Alice (MS)", "dynamic German UI status translates to English")
same(GA:Localize("Seite 2 / 5  (40 Einträge)"), "Page 2 / 5  (40 entries)", "dynamic page status translates to English")
local englishDiagnostic = GA:Localize("MasterLooter – Gesamtdiagnose\nLua-Version: 0.17.0-beta\nAktive Sitzung: keine\nsichtbar=ja")
expect(string.find(englishDiagnostic, "Full diagnostics", 1, true) and string.find(englishDiagnostic, "Lua version:", 1, true) and
    string.find(englishDiagnostic, "Active session: none", 1, true) and string.find(englishDiagnostic, "visible=yes", 1, true),
    "copyable diagnostic reports are localized to English")

profile.language = "deDE"
GA.Locale.pendingMode = nil
for german, english in pairs(englishSamples) do
    same(GA:Localize(english), german, "English source literal translates back to German")
end
same(GA:Localize("Winner: Alice (MS)"), "Gewinner: Alice (MS)", "dynamic English UI status translates to German")
same(GA:Localize("Page 2 / 5  (40 entries)"), "Seite 2 / 5  (40 Einträge)", "dynamic page status translates to German")
same(GA:Localize("Confirm"), "Bestätigen", "ambiguous reverse aliases prefer polished German wording")
same(GA:Localize("Import"), "Importieren", "noun and verb alias collisions resolve deterministically")
local germanDiagnostic = GA:Localize("MasterLooter — Full diagnostics\nLua version: 0.17.0-beta\nActive session: none\nvisible=yes")
expect(string.find(germanDiagnostic, "Gesamtdiagnose", 1, true) and string.find(germanDiagnostic, "Lua-Version:", 1, true) and
    string.find(germanDiagnostic, "Aktive Sitzung: keine", 1, true) and string.find(germanDiagnostic, "sichtbar=ja", 1, true),
    "copyable diagnostic reports are localized back to German")

profile.language = "AUTO"
clientLocale = "frFR"
same(GA:Localize("Item hier ablegen"), "Drop item here", "unsupported clients use the English UI fallback")
same(GA:Localize("GA_ROLL_SESSION_STARTED"), "GA_ROLL_SESSION_STARTED", "technical tokens are not translated")
same(GA:Localize("Alice"), "Alice", "player names are not translated")
same(GA:Localize("|cff0070dd|Hitem:1985:0:0:0|h[Kam's Buckler]|h|r"),
    "|cff0070dd|Hitem:1985:0:0:0|h[Kam's Buckler]|h|r", "item links are not translated")

print(string.format("PASS: %d UI localization coverage assertions", assertions))
