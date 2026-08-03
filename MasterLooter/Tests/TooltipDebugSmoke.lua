local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end

local hooks, listeners, registrations, hookCalls = {}, {}, {}, 0
local tooltip = { shown = true, owner = { GetName = function() return "ContainerFrame1Item1" end } }
function tooltip:IsShown() return self.shown end
function tooltip:GetOwner() return self.owner end
for _, method in ipairs({ "Hide", "Show", "SetOwner", "ClearLines", "SetHyperlink", "SetBagItem", "SetLootItem" }) do tooltip[method] = function() end end
GameTooltip = tooltip
GetTime = function() return 42.25 end
debugstack = function() return "FrameXML\\GameTooltip.lua:123 <- test" end
hooksecurefunc = function(object, method, callback)
    hookCalls = hookCalls + 1
    hooks[method] = callback
end

local registeredModules = {}
local GA = {
    VERSION = "test",
    UI = {}, errors = {}, modules = { TooltipDebug = {} },
    TooltipDebug = { entries = {}, maximumEntries = 180, hooked = false },
    Events = {
        On = function(_, event, callback) listeners[event] = callback end,
        RegisterGameEvent = function(_, event) registrations[event] = true end,
    },
    RegisterModule = function(_, name) registeredModules[#registeredModules + 1] = name end,
}
SlashCmdList = {}
local chunk = assert(loadfile("MasterLooter/Modules/Commands.lua"))
chunk("MasterLooter", GA)
expect(registeredModules[1] == "Commands" and registeredModules[2] == nil, "mixed installs do not register TooltipDebug twice")
expect(GA.TooltipDebug:OnInitialize(), "tooltip diagnostics initialize")
expect(hookCalls == 0, "passive diagnostics never hook the global tooltip")
expect(registrations.LOOT_SLOT_CLEARED and registrations.BAG_UPDATE, "loot and bag events are observed")
listeners.LOOT_SLOT_CLEARED(nil, "LOOT_SLOT_CLEARED", 1)
local text = GA.TooltipDebug:GetText()
expect(string.find(text, "keine GameTooltip-Hooks", 1, true), "report identifies passive diagnostic mode")
expect(string.find(text, "EVENT_LOOT_SLOT_CLEARED", 1, true), "loot event is included in the timeline")
expect(string.find(text, "Alpha=", 1, true), "explicit report includes visibility geometry")

print(string.format("PASS: %d tooltip-debug assertions", assertions))
