-- Exercises the visible two-click reset workflows without a running client.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "different") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

unpack = unpack or table.unpack
local function control(text)
    local value = { text = text or "", enabled = true }
    function value:SetText(newText) self.text = tostring(newText or "") end
    function value:GetText() return self.text end
    function value:SetTextColor() end
    function value:Enable() self.enabled = true end
    function value:Disable() self.enabled = false end
    return value
end

local calls = {}
local GA = {
    UI = { Theme = { colors = { red = { 1, 0, 0 }, green = { 0, 1, 0 }, muted = { 1, 1, 1 } } } },
    Compat = {}, modules = {},
    Trade = {
        ClearPending = function() calls.trade = (calls.trade or 0) + 1; return 3 end,
        MarkDelivered = function(_, id) calls.delivered = id; return true, { id = id, winner = "Alice", itemLink = "item:1" } end,
        Cancel = function(_, id) calls.cancelled = id; return true, { id = id, winner = "Alice", itemLink = "item:1" } end,
    },
    Award = {
        ClearDeferred = function() calls.award = (calls.award or 0) + 1; return 2 end,
        CloseMatchingTradeEntry = function(_, entry, delivered) calls.awardClosed = { entry.id, delivered } end,
    },
    SoftRes = { Reset = function() calls.softRes = (calls.softRes or 0) + 1 end },
    Priority = { Reset = function() calls.priority = (calls.priority or 0) + 1 end },
    PlusOnes = { ResetAll = function() calls.plusOnes = (calls.plusOnes or 0) + 1 end },
    BoostedRolls = { Reset = function() calls.boost = (calls.boost or 0) + 1 end },
    GDKP = { Reset = function(_, clearHistory) calls.gdkp = clearHistory and true or false end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end

assert(loadfile("MasterLooter/UI/TradeWindow.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/UI/RulesWindow.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/UI/GDKPWindow.lua"))("MasterLooter", GA)

local trade = GA.UI.TradeWindow
trade.clearButton, trade.selectedLabel = control("Alles leeren"), control()
trade.prepare, trade.place, trade.take, trade.delivered, trade.cancel = control(), control(), control(), control(), control()
trade.Refresh = function() end
expect(not trade:RequestClear(), "first trade reset click only arms confirmation")
same(calls.trade, nil, "first trade reset click does not delete data")
expect(trade:RequestClear(), "second trade reset click confirms deletion")
same(calls.trade, 1, "confirmed trade reset clears trade queue")
same(calls.award, 1, "confirmed trade reset clears deferred awards")
expect(string.find(trade.selectedLabel:GetText(), "5", 1, true), "trade reset reports removed entry count")
trade.selected, trade.selectedEntry = { winner = "Alice" }, { id = "trade-one", winner = "Alice", itemLink = "item:1" }
expect(trade:CloseSelected(true), "selected trade entry can be marked delivered")
same(calls.delivered, "trade-one", "delivered action targets only the selected trade entry")
same(calls.awardClosed[1], "trade-one", "matching deferred award receives the same identity")
same(calls.awardClosed[2], true, "matching deferred award is marked delivered")
trade.selected, trade.selectedEntry = { winner = "Alice" }, { id = "trade-two", winner = "Alice", itemLink = "item:1" }
expect(trade:CloseSelected(false), "selected trade entry can be cancelled")
same(calls.cancelled, "trade-two", "cancel action targets only the selected trade entry")
same(calls.awardClosed[2], false, "matching deferred award is cancelled")

local rules = GA.UI.RulesWindow
rules.resetButton, rules.status = control("Alles zurücksetzen"), control()
rules.itemInput, rules.itemSummary = control("item:1"), control()
rules.Refresh = function() end
expect(not rules:RequestReset(), "first rules reset click only arms confirmation")
same(calls.plusOnes, nil, "first rules reset click preserves rule data")
expect(rules:RequestReset(), "second rules reset click confirms deletion")
same(calls.softRes, 1, "rules reset clears SoftRes")
same(calls.priority, 1, "rules reset clears priorities")
same(calls.plusOnes, 1, "rules reset clears +1 and ledger")
same(calls.boost, 1, "rules reset clears roll bonuses")
same(rules.itemInput:GetText(), "", "rules reset clears selected item input")

local gdkp = GA.UI.GDKPWindow
gdkp.resetButton, gdkp.saleResult = control("Alles zurücksetzen"), control()
gdkp.sessionName, gdkp.itemInput, gdkp.buyerInput, gdkp.amountInput = control("Raid"), control("item:1"), control("Alice"), control("100")
gdkp.cutPlayerEdit, gdkp.cutWeightEdit = control("Alice"), control("2")
gdkp.Refresh = function() end
expect(not gdkp:RequestReset(), "first GDKP reset click only arms confirmation")
same(calls.gdkp, nil, "first GDKP reset click preserves session")
expect(gdkp:RequestReset(), "second GDKP reset click confirms deletion")
expect(calls.gdkp, "confirmed GDKP reset includes history")
same(gdkp.sessionName:GetText(), "", "GDKP reset clears visible form")
same(gdkp.cutWeightEdit:GetText(), "1", "GDKP reset restores default cut weight")

print("PASS: " .. assertions .. " reset-window assertions")
