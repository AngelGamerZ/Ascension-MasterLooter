local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end

local hooks, listeners, registrations = {}, {}, {}
local tooltip = { shown = true, owner = { GetName = function() return "ContainerFrame1Item1" end } }
function tooltip:IsShown() return self.shown end
function tooltip:GetOwner() return self.owner end
for _, method in ipairs({ "Hide", "Show", "SetOwner", "ClearLines", "SetHyperlink", "SetBagItem", "SetLootItem" }) do tooltip[method] = function() end end
GameTooltip = tooltip
GetTime = function() return 42.25 end
debugstack = function() return "FrameXML\\GameTooltip.lua:123 <- test" end
hooksecurefunc = function(object, method, callback)
    expect(object == tooltip, "debug hook only observes the global tooltip")
    hooks[method] = callback
end

local GA = {
    VERSION = "test",
    UI = {}, errors = {},
    Events = {
        On = function(_, event, callback) listeners[event] = callback end,
        RegisterGameEvent = function(_, event) registrations[event] = true end,
    },
    RegisterModule = function() end,
}
SlashCmdList = {}
local chunk = assert(loadfile("MasterLooter/Modules/Commands.lua"))
chunk("MasterLooter", GA)
expect(GA.TooltipDebug:OnInitialize(), "tooltip diagnostics initialize")
expect(type(hooks.Hide) == "function", "GameTooltip Hide is observed")
expect(registrations.LOOT_SLOT_CLEARED and registrations.BAG_UPDATE, "loot and bag events are observed")
hooks.Hide()
listeners.LOOT_SLOT_CLEARED(nil, "LOOT_SLOT_CLEARED", 1)
local text = GA.TooltipDebug:GetText()
expect(string.find(text, "TOOLTIP_Hide", 1, true), "Hide action is included in copyable diagnostics")
expect(string.find(text, "GameTooltip.lua:123", 1, true), "Hide caller stack is included")
expect(string.find(text, "EVENT_LOOT_SLOT_CLEARED", 1, true), "loot event is included in the timeline")

print(string.format("PASS: %d tooltip-debug assertions", assertions))
