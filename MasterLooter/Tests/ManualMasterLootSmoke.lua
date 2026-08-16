-- Native Blizzard master-loot reconciliation and single-entry closure tests.
local root = (arg and arg[1]) or "MasterLooter"
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, wanted, message) expect(actual == wanted, message .. " (wanted " .. tostring(wanted) .. ", got " .. tostring(actual) .. ")") end

local listeners, emitted, queueStatuses = {}, {}, {}
local now = 1700000000
local itemA = "|cff0070dd|Hitem:12345:0:0:0|h[Same item]|h|r"
local itemB = "|cffa335ee|Hitem:67890:0:0:0|h[Other item]|h|r"
local slots = {
    [1] = { slot = 1, link = itemA, itemID = 12345, candidates = { { index = 1, name = "Alice" }, { index = 2, name = "Bob" } } },
    [2] = { slot = 2, link = itemA, itemID = 12345, candidates = { { index = 1, name = "Alice" }, { index = 2, name = "Bob" } } },
    [3] = { slot = 3, link = itemB, itemID = 67890, candidates = { { index = 1, name = "Alice" } } },
}
local queues = {
    { id = "q1", generation = 4, slot = 1, itemLink = itemA, itemID = 12345, status = "AWAITING_AWARD" },
    { id = "q2", generation = 4, slot = 2, itemLink = itemA, itemID = 12345, status = "AWAITING_AWARD" },
    { id = "q3", generation = 4, slot = 3, itemLink = itemB, itemID = 67890, status = "AWAITING_AWARD" },
}
local GA = {
    UI = {}, modules = {},
    DB = { data = { character = {}, history = { awards = {} } }, GetProfile = function() return { tradeWhispersEnabled = false } end },
    Compat = {},
    Events = {
        On = function(_, event, callback, owner) listeners[event] = listeners[event] or {}; listeners[event][#listeners[event] + 1] = { callback, owner } end,
        Emit = function(_, event, ...)
            emitted[#emitted + 1] = { event, ... }
            for _, listener in ipairs(listeners[event] or {}) do listener[1](listener[2], event, ...) end
        end,
        RegisterGameEvent = function() end,
    },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Compat:GetItemID(value) return type(value) == "number" and value or tonumber(type(value) == "string" and string.match(value, "item:(%d+)") or nil) end
function GA.Compat:FindItems() return {} end
function GA.Compat:After(_, callback) return { callback = callback, Cancel = function(self) self.cancelled = true end } end
GA.Loot = {
    generation = 4,
    GetSlot = function(_, slot) return slots[slot] end,
    GetQueue = function() return queues end,
    SetQueueStatus = function(_, id, status, reason) queueStatuses[id] = { status, reason }; return true end,
}

time = function() return now end
GetTime = function() return now end
UnitName = function(unit) return unit == "player" and "Lootmaster" or nil end
GetLootSlotLink = function(slot) return slots[slot] and slots[slot].link end
GetMasterLootCandidate = function(index) return index == 1 and "Alice" or (index == 2 and "Bob" or nil) end
GiveMasterLoot = function() end
local secureHook
hooksecurefunc = function(name, callback) expect(name == "GiveMasterLoot", "only the native master-loot function is hooked"); secureHook = callback end

assert(loadfile(root .. "/Modules/Trade.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/Award.lua"))("MasterLooter", GA)
GA.Award:OnInitialize()
expect(type(secureHook) == "function", "secure native GiveMasterLoot hook is installed")

local function deferred(id, winner, slot, queue)
    local result = { sessionID = id, itemLink = itemA, winner = winner, lootSlot = slot, lootQueueID = queue }
    return { id = id, result = result, history = { delivery = "PENDING" }, itemLink = itemA, winner = winner,
        lootSlot = slot, lootQueueID = queue, status = "RETRY_REQUIRED", createdAt = now }
end
local first = deferred("a1", "Alice", 1, "q1")
local second = deferred("a2", "Alice", 2, "q2")
GA.Award.deferred = { first, second }
GA.Trade.pending = {
    { id = "t1", itemLink = itemA, itemID = 12345, winner = "Alice", lootSlot = 1, lootQueueID = "q1", status = "MISSING" },
    { id = "t2", itemLink = itemA, itemID = 12345, winner = "Alice", lootSlot = 2, lootQueueID = "q2", status = "MISSING" },
}

secureHook(2, 1)
expect(GA.Award.observedMasterLoot[2], "native assignment intent is recorded")
GA.Events:Emit("GA_LOOT_SLOT_CLEARED", slots[2], {})
same(second.status, "GIVEN", "queue-identical deferred award is completed")
same(second.history.delivery, "GIVEN", "native assignment updates award history")
same(first.status, "RETRY_REQUIRED", "first identical item remains open")
same(GA.Trade.pending[2].status, "DELIVERED", "matching trade task is completed")
same(GA.Trade.pending[1].status, "MISSING", "other duplicate trade task remains open")
same(queueStatuses.q2[1], "AWARDED", "matching loot queue is completed")

-- A different native recipient must never close Alice's remaining award.
secureHook(1, 2)
GA.Events:Emit("GA_LOOT_SLOT_CLEARED", slots[1], {})
same(first.status, "RETRY_REQUIRED", "wrong recipient does not complete an award")
same(GA.Trade.pending[1].status, "MISSING", "wrong recipient does not complete a trade task")

-- A mismatching cleared item invalidates the observation rather than using a
-- same-slot fallback. This protects compacted or externally modified loot.
local other = { id = "other", result = { itemLink = itemB, winner = "Alice" }, history = { delivery = "PENDING" },
    itemLink = itemB, winner = "Alice", lootSlot = 3, lootQueueID = "q3", status = "RETRY_REQUIRED" }
GA.Award.deferred[#GA.Award.deferred + 1] = other
secureHook(3, 1)
GA.Events:Emit("GA_LOOT_SLOT_CLEARED", { slot = 3, link = itemA }, {})
same(other.status, "RETRY_REQUIRED", "mismatching cleared item is not reconciled")

secureHook(3, 1)
now = now + 11
GA.Events:Emit("GA_LOOT_SLOT_CLEARED", slots[3], {})
same(other.status, "RETRY_REQUIRED", "stale native intent cannot close a later slot clear")
now = now - 11

-- Calls initiated by MasterLooter itself are marked only for the duration of
-- the protected call and are not mistaken for a native UI assignment.
GA.Award.invokingGive = { slot = 1, candidate = 1 }
secureHook(1, 1)
same(GA.Award.observedMasterLoot[1], nil, "addon-owned GiveMasterLoot call is ignored by native observer")
GA.Award.invokingGive = nil

-- Individual manual actions close only the selected entry.
local cancelled = assert(GA.Trade:Cancel("t1", "MANUAL_CANCEL"))
expect(cancelled, "one trade task can be cancelled")
same(GA.Trade.pending[1].status, "CANCELLED", "selected trade task is cancelled")
same(GA.Trade.pending[2].status, "DELIVERED", "other closed task is unchanged")
local ok = assert(GA.Award:CancelDeferred(first.id, "MANUAL_CANCEL"))
expect(ok, "one deferred award can be cancelled")
same(first.status, "CANCELLED", "selected deferred award is cancelled")
same(second.status, "GIVEN", "other deferred award is unchanged")

print("PASS: " .. assertions .. " native master-loot reconciliation assertions")
