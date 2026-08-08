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
local globalCalls, privateHides, privateShows = 0, 0, 0
GameTooltip = {
    SetOwner = function() globalCalls = globalCalls + 1 end,
    SetHyperlink = function() globalCalls = globalCalls + 1 end,
    Show = function() globalCalls = globalCalls + 1 end,
    Hide = function() globalCalls = globalCalls + 1 end,
}
local privateOwner, privateLink
local privateTooltip = {
    SetOwner = function(_, owner) privateOwner = owner end,
    GetOwner = function() return privateOwner end,
    SetHyperlink = function(_, link) privateLink = link end,
    Show = function() privateShows = privateShows + 1 end,
    Hide = function() privateHides = privateHides + 1 end,
}
CreateFrame = function(frameType, name)
    same(frameType, "GameTooltip", "MasterLooter creates a dedicated tooltip frame type")
    same(name, "MasterLooterTooltip", "private tooltip has its own global frame name")
    return privateTooltip
end

local GA = { UI = {}, modules = {} }
function GA:RegisterModule(name, module) self.modules[name] = module end
local themeChunk, themeError = loadfile("MasterLooter/UI/Theme.lua")
if not themeChunk then error(themeError) end
themeChunk("MasterLooter", GA)

expect(GA.UI.Theme:ShowItemTooltip(masterOwner, "|Hitem:1|h[Test]|h"), "private item tooltip can be shown")
same(privateOwner, masterOwner, "private tooltip records its MasterLooter owner")
same(privateLink, "|Hitem:1|h[Test]|h", "private tooltip receives the item link")
same(privateShows, 1, "private tooltip is shown exactly once")
same(globalCalls, 0, "global Blizzard tooltip is never touched")
same(GA.UI.Theme:HideOwnedTooltip(foreignOwner), false, "foreign owner cannot hide the private tooltip")
expect(GA.UI.Theme:HideOwnedTooltip(masterOwner), "MasterLooter may hide its own tooltip")
same(privateHides, 1, "owned private tooltip receives exactly one Hide call")
same(globalCalls, 0, "global Blizzard tooltip remains untouched after leave")

-- Shift changes refresh only the private tooltip and invoke the native 3.3.5a
-- comparison helper with Blizzard's shopping-tooltip set.
local shiftDown, compareCalls, comparedTooltip = false, 0, nil
IsShiftKeyDown = function() return shiftDown end
ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 = {}, {}, {}
GameTooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }
GameTooltip_ShowCompareItem = function(tooltip, shift)
    compareCalls, comparedTooltip = compareCalls + 1, tooltip
    expect(shift == true, "comparison helper receives the active Shift state")
end
local itemWidget = { scripts = {} }
function itemWidget:SetScript(name, callback) self.scripts[name] = callback end
GA.UI.Theme:SetItemTooltip(itemWidget, "|Hitem:2|h[Compare]|h")
itemWidget.scripts.OnEnter(itemWidget)
same(compareCalls, 0, "ordinary hover shows no equipment comparison")
shiftDown = true
itemWidget:UpdateTooltip()
same(compareCalls, 1, "pressing Shift while hovering refreshes the equipment comparison")
same(comparedTooltip, privateTooltip, "comparison remains attached to MasterLooter's private tooltip")
same(privateLink, "|Hitem:2|h[Compare]|h", "modifier refresh preserves the hovered item link")
shiftDown = false
itemWidget:UpdateTooltip()
same(compareCalls, 1, "releasing Shift removes comparison without creating another one")
itemWidget.scripts.OnLeave(itemWidget)
same(globalCalls, 0, "comparison support does not manipulate Blizzard's global tooltip")

print(string.format("PASS: %d tooltip-safety assertions", assertions))
