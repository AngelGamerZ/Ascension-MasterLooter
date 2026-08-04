-- Focused smoke and out-of-parameter tests for loot, award and trade recovery.
local root = (arg and arg[1]) or "MasterLooter"
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, wanted, message) expect(actual == wanted, message .. " (wanted " .. tostring(wanted) .. ", got " .. tostring(actual) .. ")") end

local listeners, emitted = {}, {}
local GA = {
    UI = {}, modules = {},
    DB = { data = { character = {}, history = { awards = {} } }, GetProfile = function() return { autoGiveAwards = true } end },
    Events = {
        On = function(_, event, callback, owner) listeners[event] = listeners[event] or {}; listeners[event][#listeners[event] + 1] = { callback, owner } end,
        Emit = function(_, event, ...)
            emitted[#emitted + 1] = { event, ... }
            for _, listener in ipairs(listeners[event] or {}) do listener[1](listener[2], event, ...) end
        end,
        RegisterGameEvent = function() end,
    },
    Compat = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Compat:GetItemID(link) return type(link) == "number" and link or tonumber(type(link) == "string" and string.match(link, "item:(%d+)") or nil) end
local bagItems = {}
function GA.Compat:FindItems(item)
    local wanted, result = self:GetItemID(item), {}
    for _, location in ipairs(bagItems) do if self:GetItemID(location.link) == wanted then result[#result + 1] = location end end
    return result
end
function GA.Compat:After(_, callback) return { callback = callback, Cancel = function(self) self.cancelled = true end } end
local pickups = {}
function GA.Compat:PickupContainerItem(bag, slot) pickups[#pickups + 1] = { bag, slot } end

local now, lootLink = 1700000000, "|cff0070dd|Hitem:12345:0:0:0|h[Testbeute]|h|r"
time = function() return now end
GetTime = function() return now end
UnitName = function(unit) if unit == "player" then return "Lootmaster" elseif unit == "target" then return "Alice" end end
GetNumLootItems = function() return lootLink and 1 or 0 end
GetLootSlotLink = function(slot) return slot == 1 and lootLink or nil end
GetLootSlotInfo = function(slot) if slot == 1 and lootLink then return "icon", "Testbeute", 1, 4, false, false end end
LootSlotHasItem = function(slot) return slot == 1 and lootLink ~= nil end
local candidates = { "Lootmaster" }
GetMasterLootCandidate = function(slot, index) return slot == 1 and candidates[index] or nil end
local gives = {}
GiveMasterLoot = function(slot, candidate) gives[#gives + 1] = { slot, candidate } end

local function loadModule(path) assert(loadfile(root .. "/" .. path))("MasterLooter", GA) end
loadModule("Modules/Loot.lua")
loadModule("Modules/Trade.lua")
loadModule("Modules/Award.lua")
GA.Loot:OnInitialize(); GA.Trade:OnInitialize(); GA.Award:OnInitialize()

GA.Loot:OnLootOpened(false)
local record = GA.Loot:GetSlot(1)
expect(record and record.itemID == 12345, "loot slot is captured")
local queued = assert(GA.Loot:QueueSlot(1, "SMOKE"))
same(assert(GA.Loot:QueueSlot(1)).id, queued.id, "same loot slot is not queued twice")
same(#GA.Loot:GetQueue(), 1, "active loot queue contains one entry")

-- Winner is unavailable, therefore no fake bag/trade entry may be created.
candidates = { "Lootmaster" }
local result = { sessionID = "s1", itemLink = lootLink, winner = "Alice", choice = "MS", roll = 88 }
GA.Award:OnResult(result, { owner = "Lootmaster", itemLink = lootLink })
same(#GA.Award:GetDeferred(), 1, "out-of-range winner creates recoverable award")
same(#GA.Trade:GetPending(), 0, "trade is not queued while item remains in loot")
same(GA.Award:GetDeferred()[1].status, "TAKE_SELF_REQUIRED", "explicit self-take is required")

-- The explicit button action gives the item to the loot master; slot clear then
-- advances it to the persisted trade queue.
local attempt = assert(GA.Award:TakeForTrade(GA.Award:GetDeferred()[1].id))
same(attempt.mode, "SELF_TRADE", "self-take attempt is distinguished")
same(#gives, 1, "self-take invokes GiveMasterLoot once")
GA.Award:Confirm(1)
same(#GA.Trade:GetPending(), 1, "confirmed self-take creates trade entry")
same(GA.Award:GetDeferred(true)[1].status, "TRADE_PENDING", "deferred award advances after slot clear")

-- Bag assessment and winner grouping.
bagItems = { { bag = 0, slot = 3, link = lootLink, count = 1, locked = false } }
local ready = GA.Trade:PrepareGroup("Alice")
same(#ready, 1, "winner group prepares all available items")
local groups = GA.Trade:GetGroups()
same(#groups, 1, "pending trade entries are grouped by winner")
same(groups[1].winner, "Alice", "group preserves winner")

-- The manual fallback requires an open matching trade and only invokes
-- pickup/click from this explicit placement method.
local tradeClicks = {}
ClickTradeButton = function(slot) tradeClicks[#tradeClicks + 1] = slot end
UnitExists = function(unit) return unit == "target" end
local inRange, initiated = false, 0
CheckInteractDistance = function() return inRange end
InitiateTrade = function() initiated = initiated + 1 end
local opened, openError = GA.Trade:BeginTrade("Alice")
expect(not opened and string.find(openError, "reichweite"), "out-of-range target blocks explicit trade open")
same(initiated, 0, "range check never auto-opens trade")
inRange = true; expect(GA.Trade:BeginTrade("Alice"), "in-range selected winner can be opened by click")
same(initiated, 1, "explicit action initiates exactly one trade")
GA.Trade.state, GA.Trade.partner = "OPEN", "Bob"
local placed, wrong = GA.Trade:PlacePreparedGroup("Alice")
expect(not placed and string.find(wrong, "Falscher"), "wrong partner blocks item placement")
same(#pickups, 0, "wrong partner does not touch bags")
GA.Trade.partner = "Alice"
placed = assert(GA.Trade:PlacePreparedGroup("Alice"))
same(#placed, 1, "matching open trade accepts explicit placement")
same(#pickups, 1, "explicit placement picks up bag item")
same(#tradeClicks, 1, "explicit placement clicks one trade slot")

-- Oversized stacks are never placed wholesale and estimated expiry is surfaced.
local second = assert(GA.Trade:QueueAward({ sessionID = "s2", itemLink = lootLink, winner = "Alice", quantity = 1 }, "SMOKE"))
bagItems = { { bag = 0, slot = 4, link = lootLink, count = 2, locked = false } }
GA.Trade:Prepare(second.id); GA.Trade.preparedGroup = { winner = "Alice", entries = { second } }
local before = #pickups
placed = assert(GA.Trade:PlacePreparedGroup("Alice"))
same(#placed, 0, "larger stack requires manual split")
same(#pickups, before, "larger stack is not picked up")
same(second.status, "SPLIT_REQUIRED", "split requirement is explicit")
second.tradeExpiresAt = now - 1
GA.Trade:Assess(second)
same(second.status, "EXPIRED", "estimated expired trade window is flagged")

-- Reload recovery normalizes transient states but retains durable work.
local first = GA.Trade:GetPending("Alice")[1]
first.status = "PLACED"
GA.Trade:OnInitialize()
same(first.status, "PENDING", "transient placed state recovers to pending")
expect(first.tradeExpiresAt ~= nil, "trade deadline survives/rebuilds on reload")

-- Two identical items in distinct stacks are reserved once each for one winner.
local third = assert(GA.Trade:QueueAward({ sessionID = "s3", itemLink = lootLink, winner = "Charlie", quantity = 1 }, "SMOKE"))
local fourth = assert(GA.Trade:QueueAward({ sessionID = "s4", itemLink = lootLink, winner = "Charlie", quantity = 1 }, "SMOKE"))
bagItems = {
    { bag = 1, slot = 1, link = lootLink, count = 1, locked = false },
    { bag = 1, slot = 2, link = lootLink, count = 1, locked = false },
}
local charlieReady = GA.Trade:PrepareGroup("Charlie")
same(#charlieReady, 2, "identical awards reserve two distinct stacks")
expect(third.locations[1].slot ~= fourth.locations[1].slot, "one bag stack cannot be placed twice")

-- Persisted loot generation prevents a slot number reused after reload from
-- colliding with an older queue entry.
local oldQueueID, oldGeneration = queued.id, GA.Loot.generation
GA.Loot:OnSave(); GA.Loot.generation = 0; GA.Loot:OnInitialize()
same(GA.Loot.generation, oldGeneration, "loot generation recovers from saved data")
GA.Loot:OnLootOpened(false)
local afterReload = assert(GA.Loot:QueueSlot(1, "AFTER_RELOAD"))
expect(afterReload.id ~= oldQueueID, "reused loot slot receives a fresh queue identity")

loadModule("UI/LootWindow.lua")
local control, selected, used, ordinaryLootClicks = true, nil, false, 0
IsControlKeyDown = function() return control end
local tooltipEnter, tooltipLeave = function() end, function() end
local lootButton = { id = 1, scripts = { OnEnter = tooltipEnter, OnLeave = tooltipLeave } }
function lootButton:GetID() return self.id end
function lootButton:GetScript(name) return self.scripts[name] end
GA.UI.LootWindow.Select = function(_, value) selected = value end
GA.UI.LootWindow.UseSelected = function() used = true end
expect(GA.UI.LootWindow:OpenLootItem(lootButton, "RightButton"), "CTRL-right-click captures the live loot slot")
expect(selected and selected.slot == 1 and used, "captured loot opens the loot-master workflow")
same(lootButton:GetScript("OnEnter"), tooltipEnter, "loot tooltip OnEnter remains untouched")
same(lootButton:GetScript("OnLeave"), tooltipLeave, "loot tooltip OnLeave remains untouched")
same(GA.UI.LootWindow:GetButtonSlot({ lootSlot = 7 }), 7, "Ascension lootSlot metadata resolves directly")
LootFrame = { page = 2 }; LOOTFRAME_NUMBUTTONS = 4
same(GA.UI.LootWindow:GetButtonSlot(lootButton), 5, "paged loot buttons resolve their absolute slot")
LootFrame = { page = 1 }
LootFrameItem_OnClick = function() ordinaryLootClicks = ordinaryLootClicks + 1 end
expect(GA.UI.LootWindow:InstallLootClickHooks(), "native loot click wrapper installs")
LootFrameItem_OnClick(lootButton, "RightButton")
same(ordinaryLootClicks, 0, "handled CTRL-right-click does not loot the item")
control = false; LootFrameItem_OnClick(lootButton, "LeftButton")
same(ordinaryLootClicks, 1, "ordinary loot clicks keep the original handler")

-- The real 3.3.5a XML path may expose the clicked mouse button only through
-- global arg1 and dispatch a script already stored on LootButton1.
local directOriginalClicks, registeredClicks = 0, nil
local directLootButton = { id = 1, scripts = {} }
function directLootButton:GetID() return self.id end
function directLootButton:GetScript(name) return self.scripts[name] end
function directLootButton:SetScript(name, handler) self.scripts[name] = handler end
function directLootButton:RegisterForClicks(...) registeredClicks = { ... } end
directLootButton.scripts.OnClick = function() directOriginalClicks = directOriginalClicks + 1 end
LootButton1, LOOTFRAME_NUMBUTTONS = directLootButton, 1
GA.UI.LootWindow.nativeButtonHooks = {}
control, arg1, selected, used = true, "RightButton", nil, false
expect(GA.UI.LootWindow:InstallLootButtonHooks(), "concrete 3.3.5a loot button wrapper installs")
directLootButton:GetScript("OnClick")(directLootButton, nil)
same(directOriginalClicks, 0, "arg1 CTRL-right-click does not invoke native looting")
expect(selected and selected.slot == 1 and used, "arg1 CTRL-right-click opens the loot-master workflow while solo")
same(registeredClicks[2], "RightButtonUp", "native loot button explicitly accepts right-button clicks")
control, arg1 = false, "LeftButton"
directLootButton:GetScript("OnClick")(directLootButton, nil)
same(directOriginalClicks, 1, "ordinary direct loot-button clicks retain native behavior")
GA.UI.LootWindow:RemoveLootClickHooks()
GA.UI.LootWindow:OnEnable()
expect(GA.UI.LootWindow.nativeClickHooks.LootFrameItem_OnClick ~= nil,
    "loot click wrapper is restored after re-enabling the module")

print("PASS: " .. assertions .. " loot/trade smoke assertions")
