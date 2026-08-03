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

-- No implicit trade open/accept exists: placing requires an open matching trade
-- and only invokes pickup/click from this explicit method.
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
expect(AcceptTrade == nil, "smoke environment confirms no auto-accept dependency")

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

-- CTRL-right click is observed without replacing Blizzard click or tooltip scripts.
local originalClicks, control = 0, true
local clickRecord = GA.Loot:GetSlot(1)
IsControlKeyDown = function() return control end
local tooltipHandler = function() end
local button = { scripts = { OnEnter = tooltipHandler }, hooks = {}, id = 1, name = "LootButton1" }
function button:GetID() return self.id end
function button:GetName() return self.name end
function button:GetScript(name) return self.scripts[name] end
function button:SetScript(name, callback) self.scripts[name] = callback end
function button:HookScript(name, callback) self.hooks[name] = callback end
local originalClickHandler = function() originalClicks = originalClicks + 1 end
button.scripts.OnClick = originalClickHandler
LootButton1 = button
loadModule("UI/LootWindow.lua")
local selected, used
GA.UI.LootWindow.Select = function(_, value) selected = value end
GA.UI.LootWindow.UseSelected = function() used = true end
expect(GA.UI.LootWindow:IsLootButton(button), "legacy loot button is recognized without modifying it")
GA.UI.LootWindow:HandleBlizzardLootClick(button, "RightButton")
expect(selected == clickRecord and used, "CTRL-right click captures loot slot")
same(button:GetScript("OnClick"), originalClickHandler, "Blizzard loot click handler is not replaced")
same(button:GetScript("OnEnter"), tooltipHandler, "loot tooltip handler remains untouched")
control = false; button.scripts.OnClick(button, "LeftButton")
same(originalClicks, 1, "ordinary loot click remains unchanged")
same(GA.UI.LootWindow:GetButtonSlot({ lootSlot = 7 }), 7, "Ascension lootSlot metadata resolves directly")
LootFrame = { page = 2 }; LOOTFRAME_NUMBUTTONS = 4
same(GA.UI.LootWindow:GetButtonSlot(button), 5, "paged legacy loot buttons resolve their absolute slot")

print("PASS: " .. assertions .. " loot/trade smoke assertions")
