local assertions = 0
local function check(value, message) assertions = assertions + 1; assert(value, message) end

local clock, wall, selfName = 10, 1000, "Lootboss"
local group = { lootboss = true, winner = true, stranger = false }
local sent, emitted, handlers = {}, {}, {}
GetTime = function() return clock end
time = function() return wall end
UnitName = function(unit) if unit == "player" then return selfName end end

local GA = {
    ADDON_NAME = "MasterLooter", PROTOCOL_VERSION = 3, modules = {},
    Compat = {
        IsInGroup = function() return true end,
        IterateGroupUnits = function()
            local units, index = { "player", "party1", "party2" }, 0
            return function() index = index + 1; return units[index] end
        end,
        UnitFullName = function(_, unit)
            if unit == "player" then return selfName end
            return unit == "party1" and "Winner" or "Lootboss"
        end,
    },
    RollSession = { IsAuthority = function(_, name) return string.lower(name or "") == "lootboss" end },
    Comm = {
        RegisterHandler = function(_, kind, callback) handlers[kind] = callback end,
        Send = function(_, kind, fields, channel, target)
            sent[#sent + 1] = { kind = kind, fields = fields, channel = channel, target = target }
            return "packet"
        end,
    },
    Events = {
        On = function() end,
        Emit = function(_, event, value, extra) emitted[#emitted + 1] = { event, value, extra } end,
    },
}
function GA:RegisterModule(name, module) self.modules[name] = module end

local chunk = assert(loadfile("MasterLooter/Modules/TradeCoordination.lua"))
chunk("MasterLooter", GA)
GA.TradeCoordination:OnInitialize()
check(type(handlers.TRADE_REQUEST) == "function" and type(handlers.TRADE_READY) == "function", "handlers missing")

local request, known = GA.TradeCoordination:Request("Winner", 2)
check(request and request.status == "SENT" and known == false, "request failed")
check(sent[1].kind == "TRADE_REQUEST" and sent[1].channel == "WHISPER" and sent[1].target == "Winner", "request routing")
check(sent[1].fields[5] == 2, "item count missing")

handlers.TRADE_READY({ 1, request.id, "Winner", "Lootboss" }, "Winner", "WHISPER")
check(request.status == "READY", "ready not accepted")
check(GA.TradeCoordination:HasAddon("Winner") == true, "presence not cached")
local readyEvents = 0
for _, event in ipairs(emitted) do if event[1] == "GA_TRADE_PEER_READY" then readyEvents = readyEvents + 1 end end
check(readyEvents == 1, "ready event missing")
handlers.TRADE_READY({ 1, request.id, "Winner", "Lootboss" }, "Winner", "WHISPER")
for _, event in ipairs(emitted) do end
local afterDuplicate = 0
for _, event in ipairs(emitted) do if event[1] == "GA_TRADE_PEER_READY" then afterDuplicate = afterDuplicate + 1 end end
check(afterDuplicate == 1, "duplicate ready accepted")

-- A winner accepts only a whispered request from the current loot authority.
selfName = "Winner"
local remoteID = "lootboss.trade.1.1"
handlers.TRADE_REQUEST({ 1, remoteID, "Lootboss", "Winner", 3, wall + 60 }, "Lootboss", "WHISPER")
check(GA.TradeCoordination.inbound[remoteID] ~= nil, "valid incoming request rejected")
check(sent[#sent].kind == "TRADE_READY" and sent[#sent].target == "Lootboss", "ack routing")
local requestEvents = 0
for _, event in ipairs(emitted) do if event[1] == "GA_TRADE_REQUEST" then requestEvents = requestEvents + 1 end end
check(requestEvents == 1, "request event missing")
handlers.TRADE_REQUEST({ 1, remoteID, "Lootboss", "Winner", 3, wall + 60 }, "Lootboss", "WHISPER")
check(#sent == 2, "duplicate request acknowledged twice")

handlers.TRADE_REQUEST({ 1, "evil.trade.1", "Stranger", "Winner", 1, wall + 60 }, "Stranger", "WHISPER")
handlers.TRADE_REQUEST({ 1, "winner.trade.1", "Winner", "Winner", 1, wall + 60 }, "Winner", "WHISPER")
handlers.TRADE_REQUEST({ 1, "lootboss.trade.2", "Lootboss", "Winner", 7, wall + 60 }, "Lootboss", "WHISPER")
handlers.TRADE_REQUEST({ 1, "lootboss.trade.3", "Lootboss", "Winner", 1, wall + 1000 }, "Lootboss", "WHISPER")
check(#sent == 2 and requestEvents == 1, "invalid request accepted")

clock = clock + 301
check(GA.TradeCoordination:HasAddon("Lootboss") == false, "stale presence retained")

print("PASS: " .. assertions .. " trade-handshake assertions")
