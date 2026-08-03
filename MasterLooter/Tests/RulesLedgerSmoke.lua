-- Focused smoke and edge-case coverage for +1/item-ledger/ranking integration.
-- Run from repository root with Fengari or Lua 5.1:
--   fengari MasterLooter/Tests/RulesLedgerSmoke.lua

local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

function wipe(tableValue) for k in pairs(tableValue) do tableValue[k] = nil end end
function time() return 1700000000 end

local listeners = {}
local GA = {
    DB = {
        data = { plusOnes = {}, itemLedger = {}, softRes = { reservations = {} }, priorities = {}, boostedRolls = {} },
        profile = {},
    },
    Events = {}, modules = {},
    Compat = { GetItemID = function(_, item) return tonumber(tostring(item):match("item:(%d+)")) or tonumber(item) end },
    SoftRes = { IsReserved = function() return false end },
    Priority = { Get = function() return 0 end },
    BoostedRolls = { Apply = function(_, _, roll) return tonumber(roll) or 0 end },
}
function GA.DB:GetProfile() return self.profile end
function GA.Events:On(event, callback, owner)
    listeners[event] = listeners[event] or {}
    listeners[event][#listeners[event] + 1] = { callback, owner }
end
function GA.Events:Emit(event, ...)
    for _, listener in ipairs(listeners[event] or {}) do listener[1](listener[2], event, ...) end
end
function GA:RegisterModule(name, module) self.modules[name] = module end

assert(loadfile("MasterLooter/Modules/PlusOnes.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/Modules/Ranking.lua"))("MasterLooter", GA)
GA.PlusOnes:OnInitialize()

local ms = { sessionID = "session-1", winner = "Alice-Realm", choice = "MS", itemLink = "item:100" }
GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", ms, "GIVEN")
local stats = GA.PlusOnes:GetStats("Alice")
same(stats.total, 1, "confirmed award increments total")
same(stats.MS, 1, "confirmed MS increments MS count")
same(stats.OS, 0, "confirmed MS leaves OS count")
same(GA.PlusOnes:Get("Alice"), 1, "MS auto +1 defaults on")

GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", ms, "GIVEN")
same(GA.PlusOnes:GetStats("Alice").total, 1, "duplicate session is idempotent")
same(GA.PlusOnes:Get("Alice"), 1, "duplicate session does not add +1")
GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", { sessionID = "pending", winner = "Alice", choice = "MS" }, "PENDING")
same(GA.PlusOnes:GetStats("Alice").total, 1, "unconfirmed award is not counted")

local os = { sessionID = "session-2", winner = "Alice", choice = "OS", itemLink = "item:101" }
GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", os, "GIVEN")
stats = GA.PlusOnes:GetStats("Alice")
same(stats.total, 2, "OS contributes to received total")
same(stats.OS, 1, "OS has separate count")
same(GA.PlusOnes:Get("Alice"), 1, "OS auto +1 defaults off")

expect(GA.PlusOnes:SetAutoRule("OS", true), "OS rule can be enabled")
GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", { sessionID = "session-3", winner = "Alice", choice = "OS", itemLink = "item:102" }, "GIVEN")
same(GA.PlusOnes:Get("Alice"), 2, "enabled OS rule adds +1")

local trade = { id = "trade-1", winner = "Bob", choice = "MS", itemLink = "item:103", status = "DELIVERED" }
GA.Events:Emit("GA_TRADE_PENDING_UPDATED", trade)
GA.Events:Emit("GA_TRADE_PENDING_UPDATED", trade)
same(GA.PlusOnes:GetStats("Bob").total, 1, "confirmed trade is idempotent by trade id")
same(GA.PlusOnes:Get("Bob"), 1, "confirmed MS trade applies +1")
GA.Events:Emit("GA_TRADE_PENDING_UPDATED", { winner = "Mallory", choice = "MS", status = "DELIVERED" })
same(GA.PlusOnes:GetStats("Mallory").total, 0, "trade without stable id is ignored")

GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", { sessionID = "session-other", winner = "Cara", choice = "TRANSMOG", itemLink = "item:104" }, "GIVEN")
same(GA.PlusOnes:GetStats("Cara").OTHER, 1, "unknown award type is tracked as OTHER")
same(GA.PlusOnes:Get("Cara"), 0, "OTHER does not affect +1 by default")

same(GA.PlusOnes:Add("Bob", -99, "TEST"), 0, "+1 never becomes negative")
same(GA.PlusOnes:Add("Bob", 3, "TEST"), 3, "manual correction works")
same(GA.PlusOnes:ResetPlayer("Bob", "TEST"), 0, "manual player reset works")
expect(#GA.PlusOnes:GetLedgerHistory() >= 7, "ledger keeps award and correction history")
expect(GA.PlusOnes:ExportLedger():find("Spieler\tGesamt\tMS\tOS"), "ledger exports tabular header")
expect(GA.PlusOnes:ExportLedger():find("alice\t3\t1\t2"), "ledger export contains split counts")

local ok, reason = GA.PlusOnes:RecordConfirmed({ winner = "" }, "bad")
expect(not ok and reason, "invalid award is rejected")
ok, reason = GA.PlusOnes:RecordConfirmed({ winner = "Eve", choice = "MS" }, nil)
expect(not ok and reason, "award without stable identity is rejected")
expect(not GA.PlusOnes:SetAutoRule("GREED", true), "unknown auto rule is rejected")

GA.DB.data.itemLedger.players["corrupt"] = "broken"
local corruptStats = GA.PlusOnes:GetStats("Corrupt")
same(corruptStats.total, 0, "malformed player ledger degrades safely")

local session = { itemLink = "item:100", participants = {
    alice = { name = "Alice", choice = "MS", roll = 50 },
    bob = { name = "Bob", choice = "MS", roll = 60 },
} }
local ranked = GA.Ranking:GetSorted(session)
same(ranked[1].name, "Bob", "lower +1 outranks higher +1")
expect(type(session.participants.alice.itemCounts) == "table", "ranking exposes item counts to UI")
same(session.participants.alice.itemCounts.total, 3, "ranking exposes correct received total")

GA.PlusOnes:ResetStats("Alice", "TEST")
same(GA.PlusOnes:GetStats("Alice").total, 0, "manual statistic reset works")
same(GA.PlusOnes:Get("Alice"), 2, "statistic reset does not alter ranking +1")
GA.PlusOnes:Reset("TEST")
same(GA.PlusOnes:Get("Alice"), 0, "global +1 reset works")

print("PASS: " .. assertions .. " rules/ledger smoke assertions")
