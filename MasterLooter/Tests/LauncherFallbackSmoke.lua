local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local tooltipLines
local GA = {
    UI = { Theme = {
        ShowTextTooltip = function(_, owner, lines, anchor)
            tooltipLines = lines
            return owner ~= nil and anchor == "ANCHOR_LEFT"
        end,
    } },
    modules = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end

-- This deliberately loads Launcher without GA:L, GA.Locale, or GA.Localization,
-- reproducing the 0.17.1 minimap-hover failure and the earlier binding path.
local chunk, loadError = loadfile("MasterLooter/UI/Launcher.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)

local launcher = GA.UI.Launcher
expect(launcher:ShowTooltip({}), "minimap tooltip opens without GA:L")
same(tooltipLines[2], "Left-click: Overview & settings", "tooltip uses the safe English fallback")
same(tooltipLines[6], "Shift + right-click: Loot master", "all launcher tooltip actions receive fallback text")
same(BINDING_NAME_MASTERLOOTER_SETTINGS, "Open settings", "binding labels also survive missing localization helpers")
same(BINDING_NAME_MASTERLOOTER_TRADE, "Open trade assistant", "all binding fallbacks are initialized")

GA.Localization = { Get = function(_, key) return key == "launcher.left" and "Localized left" or key end }
GA.L = nil
expect(launcher:ShowTooltip({}), "minimap tooltip uses the localization service when GA:L is absent")
same(tooltipLines[2], "Localized left", "service fallback is preferred over hard-coded English")

print(string.format("PASS: %d launcher-fallback assertions", assertions))
