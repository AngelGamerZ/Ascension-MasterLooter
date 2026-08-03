-- Verifies that MasterLooter never hides a tooltip owned by Blizzard or
-- another addon while hidden loot rows are refreshed or removed.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

unpack = unpack or table.unpack
UISpecialFrames = {}
local foreignOwner, masterOwner = {}, {}
local tooltipOwner, hides = foreignOwner, 0
GameTooltip = {
    GetOwner = function() return tooltipOwner end,
    Hide = function() hides = hides + 1 end,
}

local GA = { UI = {}, modules = {} }
function GA:RegisterModule(name, module) self.modules[name] = module end
local themeChunk, themeError = loadfile("MasterLooter/UI/Theme.lua")
if not themeChunk then error(themeError) end
themeChunk("MasterLooter", GA)

same(GA.UI.Theme:HideOwnedTooltip(masterOwner), false, "foreign Blizzard tooltip is not hidden")
same(hides, 0, "foreign tooltip receives no Hide call")
tooltipOwner = masterOwner
expect(GA.UI.Theme:HideOwnedTooltip(masterOwner), "MasterLooter may hide its own tooltip")
same(hides, 1, "owned tooltip receives exactly one Hide call")

print(string.format("PASS: %d tooltip-safety assertions", assertions))
