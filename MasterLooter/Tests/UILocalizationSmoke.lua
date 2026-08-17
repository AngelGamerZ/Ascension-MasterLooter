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
load("MasterLooter/Locales/Errors.lua")

local rawCount = 0
for _ in pairs(GA.Locale.raw) do rawCount = rawCount + 1 end
expect(rawCount >= 350, "the user-facing legacy UI catalog remains comprehensive")
for source, english in pairs(GA.Locale.raw) do
    if source ~= english then
        expect(GA:Localize(source) ~= source, "every registered German production literal has an active English translation: " .. source)
    end
end

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
same(GA:Localize("MasterLooter 0.17.3-1-beta – Einstellungen"), "MasterLooter 0.17.3-1-beta — Settings",
    "dynamic versioned settings title translates completely to English")
same(GA:Localize("Einstellungen konnten nicht geöffnet werden: Theme-Modul ist nicht verfügbar."),
    "Settings could not be opened: Theme module is unavailable.", "dynamic settings errors contain no German remainder")
same(GA:Localize("Beendet – Gewinner: Alice"), "Ended — winner: Alice", "dynamic auction winner status is not partially translated")
same(GA:L("PROFILE_DELETE_CONFIRM", "Raid"), "Click again to delete Raid.",
    "dynamic profile deletion prompt uses one complete localized format")
same(GA:Localize("Seite 2 / 5  (40 Einträge)"), "Page 2 / 5  (40 entries)", "dynamic page status translates to English")
same(GA:Localize("Letzter Klick: keiner"), "Last click: none", "diagnostic none value does not corrupt word endings")
local englishDiagnostic = GA:Localize("MasterLooter – Gesamtdiagnose\nLua-Version: 0.17.1-beta\nAktive Sitzung: keine\nsichtbar=ja")
expect(string.find(englishDiagnostic, "Full diagnostics", 1, true) and string.find(englishDiagnostic, "Lua version:", 1, true) and
    string.find(englishDiagnostic, "Active session: none", 1, true) and string.find(englishDiagnostic, "visible=yes", 1, true),
    "copyable diagnostic reports are localized to English")
same(GA:Localize("KOMPATIBILITÄT\nDebug-Modus: AN (2000 Trace-Einträge + Fehlerstacks)\nSettings: vollständig=true, Generation=2, Fehler=keiner"),
    "COMPATIBILITY\nDebug mode: ON (2,000 trace entries + error stacks)\nSettings: complete=true, generation=2, error=none",
    "full compatibility and debug-mode diagnostics are localized to English")
same(GA:Localize("Scans=4, letzter Grund=LOOT_OPENED, erkannt=2, installiert=2, aktiv=2, Frames=18"),
    "Scans=4, last reason=LOOT_OPENED, detected=2, installed=2, active=2, frames=18",
    "loot-hook diagnostics contain no German field labels")
same(GA:Localize("3 importiert, 1 abgelehnt"), "3 imported, 1 rejected", "dynamic SoftRes import result is translated")
same(GA:Localize("4 Item(s) eingereiht."), "4 item(s) queued.", "dynamic GDKP queue result is translated")
same(GA:Localize("Roll erkannt, aber keine aktive Sitzung gefunden."), "Roll detected, but no active session was found.",
    "roll diagnostics translate complete sentences without mixed-language fragments")
local protectedItem = "|cff0070dd|Hitem:1985:0:0:0|h[Band für Helden]|h|r"
same(GA:Localize("Aktion nötig: " .. protectedItem .. " für Alice"), "Action required: " .. protectedItem .. " for Alice",
    "dynamic translation protects item-link display names")
same(GA:Localize("\nFEHLER\n\nZUSTAND\n\nLOOT-KLICK\nLoot-Klickdiagnose\n\nKOMMUNIKATION\n\nGESAMT-TRACE\n"),
    "\nERRORS\n\nSTATE\n\nLOOT CLICK\nLoot click diagnostics\n\nCOMMUNICATION\n\nFULL TRACE\n",
    "all whole-addon diagnostic section headings are English")
same(GA:Localize("Tracker initialisiert: true\nDirekter Eventframe: true\nSitzungsstatus: keiner\nEmpfangene Systemereignisse: 4\nErgebnis: keine Diagnose"),
    "Tracker initialized: true\nDirect event frame: true\nSession status: none\nReceived system events: 4\nResult: no diagnostic result",
    "the complete roll-diagnostic field set is English")

profile.language = "deDE"
GA.Locale.pendingMode = nil
same(GA:L("SETTINGS_WINDOW_TITLE", "0.17.3-1-beta"), "MasterLooter 0.17.3-1-beta – Einstellungen",
    "German settings title preserves version punctuation")
same(GA:L("PROFILE_DELETE_CONFIRM", "Raid"), "Noch einmal klicken, um Raid zu löschen.",
    "German profile deletion prompt uses one complete localized format")
same(GA:Localize("MasterLooter 0.17.3-1-beta · WoW 3.3.5a"), "MasterLooter 0.17.3-1-beta · WoW 3.3.5a",
    "German reverse localization never rewrites version punctuation")
for german, english in pairs(englishSamples) do
    same(GA:Localize(english), german, "English source literal translates back to German")
end
same(GA:Localize("Winner: Alice (MS)"), "Gewinner: Alice (MS)", "dynamic English UI status translates to German")
same(GA:Localize("Page 2 / 5  (40 entries)"), "Seite 2 / 5  (40 Einträge)", "dynamic page status translates to German")
same(GA:Localize("Confirm"), "Bestätigen", "ambiguous reverse aliases prefer polished German wording")
same(GA:Localize("Import"), "Importieren", "noun and verb alias collisions resolve deterministically")
local germanDiagnostic = GA:Localize("MasterLooter — Full diagnostics\nLua version: 0.17.1-beta\nActive session: none\nvisible=yes")
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
