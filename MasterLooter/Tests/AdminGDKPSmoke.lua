-- Standalone smoke/edge tests for administrative and GDKP modules.
-- Run: lua MasterLooter/Tests/AdminGDKPSmoke.lua
local root = (arg and arg[1]) or "MasterLooter"
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end end
local function same(actual, expected, message) expect(actual == expected, (message or "different") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual)) end

local now = 100
GetTime = function() return now end
time = function() return 1700000000 + now end
date = function() return "2026-08-03" end
UnitName = function() return "Leader" end
GetItemInfo = function() return "Item", "|Hitem:123|h[Item]|h", 4 end
local protected = {}
ConvertToRaid = function() protected.convert = true end
DoReadyCheck = function() protected.ready = true end
UninviteUnit = function(name) protected.removed = name end
CreateFrame = function()
    return { SetScript = function(self, key, fn) self[key] = fn end }
end

local events = { handlers = {} }
function events:Emit() end
function events:On() end
function events:RegisterGameEvent() end
local profile = {}
local GA = {
    DB = { data = { character = {}, history = { gdkp = {} } }, GetProfile = function() return profile end },
    Events = events,
    Compat = {
        GetItemID = function(_, link) return tonumber(string.match(tostring(link), "item:(%d+)")) end,
        IsInRaid = function() return false end, IsInGroup = function() return true end,
        After = function(_, _, callback) callback() end,
        GetItemCount = function() return 1 end,
    },
    Comm = { handlers = {}, RegisterHandler = function(self, name, fn) self.handlers[name] = fn end,
        Send = function() return true end },
    RollSession = { IsAuthority = function() return true end },
    RegisterModule = function() end,
}
GA.Compat.IterateGroupUnits = function() return function() return nil end end

assert(loadfile(root .. "/Modules/GDKP.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/GDKPAuction.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/PackMule.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/RaidManager.lua"))("MasterLooter", GA)
assert(loadfile(root .. "/Modules/BagInspector.lua"))("MasterLooter", GA)

GA.GDKP:OnInitialize()
local session = GA.GDKP:Start("Smoke")
expect(session ~= nil, "GDKP starts")
expect(GA.GDKP:AddSale("|Hitem:123|h[Item]|h", "Alice", 1000), "sale accepted")
expect(GA.GDKP:AddPlayer("Bob"), "player accepted")
expect(GA.GDKP:SetCutWeight("Alice", 2), "weighted cut accepted")
expect(GA.GDKP:SetCutWeight("Bob", 1), "default second cut accepted")
local distribution = GA.GDKP:GetDistribution()
same(#distribution, 2, "distribution count")
same(distribution[1].amount, 666, "weighted cut floor")
expect(GA.GDKP:SetPaymentStatus("Alice", "PAID"), "payment status accepted")
expect(not GA.GDKP:SetPaymentStatus("Alice", "INVALID"), "invalid payment rejected")
expect(not GA.GDKP:SetCutWeight("Alice", -1), "negative cut rejected")
GA.DB.data.history.gdkp[1] = { name = "Old" }
expect(GA.GDKP:Reset(true), "GDKP full reset succeeds")
same(GA.GDKP.active, nil, "GDKP reset removes the active session")
same(#GA.DB.data.history.gdkp, 0, "GDKP full reset clears persisted history")
same(GA.GDKP.store.active, nil, "GDKP reset persists the empty active state")

GA.GDKPAuction.Start = function(self, link, minimum, increment, duration)
    self.active = { status = "ACTIVE", itemLink = link, minimum = minimum, increment = increment, duration = duration }
    return self.active
end
GA.GDKPAuction.queue = {}; GA.GDKPAuction.store = {}
local started = GA.GDKPAuction:Enqueue("|Hitem:123|h[Item]|h", 100, 10, 30)
expect(started and GA.GDKPAuction.active, "empty queue starts immediately")
local queued = GA.GDKPAuction:Enqueue("|Hitem:123|h[Item]|h", 200, 20, 40)
expect(queued and #GA.GDKPAuction.queue == 1, "active auction queues next item")
expect(not GA.GDKPAuction:Enqueue("bad", 1, 1, 30), "invalid queue item rejected")

GA.PackMule.store = {}; GA.PackMule.target = "Mule"
expect(GA.PackMule:SetRules({ enabled = true, minimumQuality = 3, targets = { "One", "Two" }, includeBoE = true }), "rules accepted")
same(GA.PackMule:EvaluateItem("|Hitem:123|h[Item]|h", "BOE"), "One", "round robin first")
same(GA.PackMule:EvaluateItem("|Hitem:123|h[Item]|h", "BOE"), "Two", "round robin second")
expect(not GA.PackMule:SetRules({ minimumQuality = 99 }), "bad quality rejected")

GA.RaidManager.CanManage = function() return true end
expect(GA.RaidManager:ConvertToRaid() and protected.convert, "convert is click-callable")
expect(GA.RaidManager:ReadyCheck() and protected.ready, "ready check is click-callable")
expect(not GA.RaidManager:Remove("Leader"), "self removal blocked")
expect(GA.RaidManager:Remove("Alice") and protected.removed == "Alice", "member removal works")

same(GA.BagInspector:SetSharing(false), false, "bag sharing disabled")
same(GA.BagInspector:IsSharing(), false, "privacy setting retained")

print("PASS: " .. assertions .. " administrative/GDKP smoke assertions")
