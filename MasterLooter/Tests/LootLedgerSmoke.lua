local assertions = 0
local function expect(value, message) assertions = assertions + 1; assert(value, message) end
local function same(actual, expected, message) assertions = assertions + 1; assert(actual == expected, (message or "mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected)) end

local current = 1000
time = function() return current end
date = function() return "date" end
UnitName = function(unit) return unit == "player" and "Lootmaster" or "Dead Boss" end
UnitExists = function() return true end
UnitIsDead = function() return true end
GetInstanceInfo = function() return "Test Raid", "raid", 3, "Heroisch" end

local handlers, emitted, whispers = {}, {}, {}
local GA = {
    modules = {}, UI = {}, DB = { data = {} },
    Compat = { GetItemID = function(_, link) return tonumber(string.match(link or "", "item:(%d+)")) end, FindItems = function() return {} end },
    Events = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:On(event, callback) handlers[event] = handlers[event] or {}; handlers[event][#handlers[event] + 1] = callback end
function GA.Events:Emit(event, ...) emitted[#emitted + 1] = event; for _, callback in ipairs(handlers[event] or {}) do callback(nil, event, ...) end end

assert(loadfile("MasterLooter/Modules/LootLedger.lua"))("MasterLooter", GA)
GA.LootLedger:OnInitialize()
local link = "|cff0070dd|Hitem:1985:0:0:0|h[Test Shield]|h|r"
local snapshot = { generation = 7, order = { 1 }, slots = { [1] = { slot = 1, link = link, itemID = 1985, quantity = 1 } } }
GA.LootLedger:OnLootOpened(snapshot)
same(#GA.LootLedger.entries, 1, "loot window creates one ledger entry")
local entry = GA.LootLedger.entries[1]
same(entry.status, "DROPPED", "new loot is marked dropped")
same(entry.boss, "Dead Boss", "best effort target context is retained")
same(entry.instance, "Test Raid", "instance context is retained")
GA.LootLedger:OnSlotCleared({ slot = 1 }, snapshot)
same(entry.status, "ACQUIRED", "slot clear advances lifecycle")
same(entry.statusAccuracy, "SLOT_CLEAR_RECIPIENT_UNKNOWN", "unknown recipient is explicit")
GA.LootLedger:OnAward({ itemLink = link, lootSlot = 1, winner = "Winner", choice = "MS", roll = 88 }, "GIVEN")
same(entry.status, "AWARDED", "award advances lifecycle")
same(entry.winner, "Winner", "award winner is recorded")
GA.LootLedger:OnTradeCompleted("Winner", { { itemLink = link, itemID = 1985, winner = "Winner" } })
same(entry.status, "TRADED", "confirmed trade advances lifecycle")
expect(GA.LootLedger:Export():find("Status\tItem", 1, true), "TSV export has headers")
expect(GA.LootLedger:Export():find("TRADED", 1, true), "TSV export has lifecycle state")
same(#GA.LootLedger:Query({ status = "TRADED", search = "winner" }), 1, "ledger filters status and text")
expect(GA.LootLedger:SetStatus(entry, "DISENCHANTED", { statusAccuracy = "MANUAL_EDIT" }), "manual correction works")
same(entry.status, "DISENCHANTED", "manual disenchant is visible")
expect(GA.LootLedger:Remove(entry.id), "entry can be deleted")
same(#GA.LootLedger.entries, 0, "deleted entry is removed")
local abandoned = { generation = 8, order = { 2 }, slots = { [2] = { slot = 2, link = link, itemID = 1985, quantity = 1, cleared = false } } }
GA.LootLedger:OnLootOpened(abandoned)
GA.LootLedger:OnLootClosed(abandoned)
same(GA.LootLedger.entries[1].status, "LOST", "uncleared loot is retained as lost/unknown")
same(GA.LootLedger.entries[1].statusAccuracy, "INFERRED_LOOT_WINDOW_CLOSED", "inferred loss is labelled honestly")

-- Trade-time behavior is tested independently of the live trade frame.
SendChatMessage = function(text, channel, language, target) whispers[#whispers + 1] = { text = text, channel = channel, target = target } end
GetNumRaidMembers = function() return 10 end
GetNumPartyMembers = function() return 0 end
GA.Events.RegisterGameEvent = function() end
assert(loadfile("MasterLooter/Modules/Trade.lua"))("MasterLooter", GA)
GA.Trade.pending = {
    { id = "a", itemLink = link, itemID = 1985, winner = "Winner", quantity = 1, status = "READY", tradeExpiresAt = current + 290 },
    { id = "b", itemLink = link, itemID = 1985, winner = "Other", quantity = 1, status = "DELIVERED", tradeExpiresAt = current + 100 },
}
same(#GA.Trade:GetTimeline(), 1, "timeline hides closed items by default")
same(#GA.Trade:GetTimeline({ includeClosed = true }), 2, "timeline can include completed items")
expect(GA.Trade:WarnExpiring(GA.Trade.pending[1]), "estimated expiry warning fires")
same(whispers[#whispers].channel, "WHISPER", "expiry warning whispers winner")
expect(not GA.Trade:WarnExpiring(GA.Trade.pending[1]), "same threshold is not repeated")
local sent = assert(GA.Trade:BroadcastPending())
same(sent, 1, "one open winner group is broadcast")
same(whispers[#whispers].channel, "RAID_WARNING", "raid list uses raid warning")

print("PASS: " .. assertions .. " loot-ledger/trade-time assertions")
