local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. message, 2) end
end
local function contains(text, value) return string.find(text, value, 1, true) ~= nil end

local profile = { language = "enUS" }
function GetLocale() return "enUS" end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
local GA = {
    VERSION = "test", PROTOCOL_VERSION = 3, modules = {},
    DB = { data = {}, GetProfile = function() return profile end },
    Events = { On = function() end, RegisterGameEvent = function() end, Emit = function() end },
    RollSession = { GetState = function() return nil end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
local function load(path) assert(loadfile("MasterLooter/" .. path))("MasterLooter", GA) end
load("Core/Localization.lua")
load("Locales/enUS.lua")
load("Locales/deDE.lua")
load("Locales/Errors.lua")
load("Locales/UI.lua")
load("Modules/ChatRolls.lua")

GA.ChatRolls.diagnostics.status = "Roll erkannt, aber keine aktive Sitzung gefunden."
local english = GA.ChatRolls:GetDiagnosticText()
for _, forbidden in ipairs({ "Diagnose", "Protokoll:", "vorhanden", "initialisiert", "Sitzung", "Empfangene", "Letzte", "Spieler:", "Wurf:", "Bereich:", "Ergebnis:", "keine" }) do
    expect(not contains(english, forbidden), "English roll diagnostics contain no German fragment: " .. forbidden)
end
for _, required in ipairs({ "Roll diagnostics", "Protocol:", "Tracker available:", "Active session: none", "Player: none", "Result: Roll detected" }) do
    expect(contains(english, required), "English roll diagnostics render: " .. required)
end

profile.language = "deDE"
local german = GA.ChatRolls:GetDiagnosticText()
for _, required in ipairs({ "Roll-Diagnose", "Protokoll:", "Tracker vorhanden:", "Aktive Sitzung: keine", "Spieler: keine", "Ergebnis: Roll erkannt" }) do
    expect(contains(german, required), "German roll diagnostics render: " .. required)
end

print(string.format("PASS: %d non-UI localization assertions", assertions))
