local root = (arg and arg[1]) or "MasterLooter"
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end end
local function same(actual, expected, message) expect(actual == expected, (message or "different") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual)) end
local clock = 100
GetTime = function() return clock end; time = function() return 1700000000 + clock end; date = function() return "2026-08-04" end
UnitName = function() return "Leader" end
CreateFrame = function() return { SetScript = function(self, name, handler) self[name] = handler end } end
local bagLinks = { [0] = { "|Hitem:123|h[One]|h", "|Hitem:124|h[Two]|h" } }
GetContainerNumSlots = function(bag) return bagLinks[bag] and #bagLinks[bag] or 0 end
GetContainerItemLink = function(bag, slot) return bagLinks[bag] and bagLinks[bag][slot] end
GetItemInfo = function(link) return "Item", link, 4 end
local handlers = {}
local GA = {
    DB = { data = { character = {}, history = { gdkp = {} } } }, Events = { Emit = function() end },
    Compat = { GetItemID = function(_, link) return tonumber(string.match(tostring(link), "item:(%d+)")) end,
        IterateGroupUnits = function() return function() return nil end end, UnitFullName = function(_, unit) return unit end },
    Comm = { RegisterHandler = function(_, name, handler) handlers[name] = handler end, Send = function() return true end },
    RollSession = { IsAuthority = function() return true end }, RegisterModule = function() end,
}
assert(loadfile(root .. "/Modules/GDKP.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/GDKPAuction.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/GDKPMultiAuction.lua"))("MasterLooter", GA)
GA.GDKP:OnInitialize(); local session = assert(GA.GDKP:Start("Advanced"))
expect(GA.GDKP:AddPlayer("Alice"), "participant added"); expect(GA.GDKP:SetCutWeight("Alice", 2), "weight stored")
expect(GA.GDKP:SetManagementCut(10, 50), "management cut stored"); expect(GA.GDKP:SetMutator("Bonus", 10), "mutator stored")
expect(GA.GDKP:AddSale("|Hitem:123|h[One]|h", "Alice", 1000), "sale recorded")
local cuts, management, distributable = GA.GDKP:CalculateCuts()
same(management, 150, "percentage plus fixed management cut"); same(distributable, 935, "mutator applies after management cut"); same(cuts[1].amount, 935, "participant cut")
local tx = GA.GDKP:AddTransaction("Alice", 250, "IN", "Deposit"); expect(tx and tx.amount == 250, "incoming gold transaction")
expect(not GA.GDKP:AddTransaction("Alice", 1, "BAD", ""), "invalid transaction rejected"); same(#session.ledger, 2, "ledger rows")
expect(GA.GDKP:EditLedger(tx.ledgerID, { note = "Paid cash" }), "ledger editable"); expect(GA.GDKP:DeleteLedger(tx.ledgerID), "ledger deletable"); same(#session.ledger, 1, "ledger delete")
expect(GA.GDKP:SetPrice("|Hitem:123|h[One]|h", 500, 50), "price stored"); same(GA.GDKP:GetPrice("|Hitem:123|h[One]|h").minimum, 500, "price lookup")
local exported = assert(GA.GDKP:Export()); expect(string.find(exported, "MLGDKP\t1", 1, true), "export header")
GA.GDKP:Reset(false); expect(GA.GDKP:Import(exported, true), "roundtrip import"); same(GA.GDKP.active.sales[1].amount, 1000, "sale roundtrip"); same(GA.GDKP:GetPrice("|Hitem:123|h[One]|h").increment, 50, "price roundtrip")
GA.GDKPAuction.queue, GA.GDKPAuction.store, GA.GDKPAuction.active = {}, {}, { status = "ACTIVE" }
local added = GA.GDKPMultiAuction:EnqueueInventory(100, 10, 30, 3); same(added, 2, "bag items found"); same(#GA.GDKPAuction.queue, 2, "bag items queued")
GA.GDKPMultiAuction:OnInitialize(); local first = assert(GA.GDKPMultiAuction:Start("|Hitem:123|h[One]|h", 100, 10, 30)); local second = assert(GA.GDKPMultiAuction:Start("|Hitem:124|h[Two]|h", 200, 20, 40))
same(#GA.GDKPMultiAuction:GetAuctions(), 2, "parallel auctions"); expect(GA.GDKPMultiAuction:Bid(first.id, 100), "targeted bid")
same(GA.GDKPMultiAuction:GetBidderState(first.id, "Leader").status, "ACTIVE", "bidder state"); expect(GA.GDKPMultiAuction:Stop(first.id, "MANUAL"), "independent stop")
same(first.status, "ENDED", "first ended"); same(second.status, "ACTIVE", "second active"); expect(GA.GDKPMultiAuction:Remove(first.id), "ended removable"); expect(not GA.GDKPMultiAuction:Remove(second.id), "active protected")
print("PASS: " .. assertions .. " advanced GDKP assertions")
