-- Focused tests for automatic trade preparation and reminder safety.
local root = (arg and arg[1]) or "MasterLooter"
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, wanted, message) expect(actual == wanted, message .. " (wanted " .. tostring(wanted) .. ", got " .. tostring(actual) .. ")") end

local listeners = {}
local GA = {
    modules = {},
    DB = { data = { character = {} } },
    Events = {
        On = function(_, event, callback, owner) listeners[event] = listeners[event] or {}; listeners[event][#listeners[event] + 1] = { callback, owner } end,
        Emit = function(_, event, ...)
            for _, listener in ipairs(listeners[event] or {}) do listener[1](listener[2], event, ...) end
        end,
        RegisterGameEvent = function() end,
    },
    Compat = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Compat:GetItemID(link) return tonumber(type(link) == "string" and string.match(link, "item:(%d+)") or link) end

local bags, pickups, clicks, whispers, cursor, tradeSlots, targetTradeSlots = {}, {}, {}, {}, nil, {}, {}
function GA.Compat:FindItems(item)
    local wanted, result = self:GetItemID(item), {}
    for _, location in ipairs(bags) do if self:GetItemID(location.link) == wanted then result[#result + 1] = location end end
    return result
end
function GA.Compat:PickupContainerItem(bag, slot)
    pickups[#pickups + 1] = tostring(bag) .. ":" .. tostring(slot)
    for _, location in ipairs(bags) do if location.bag == bag and location.slot == slot then cursor = location.link end end
end
function GA.Compat:After(delay, callback) if delay < 1 then callback() end; return { callback = callback } end

local now, target, inRange = 1700000000, nil, false
time = function() return now end
UnitExists = function(unit) return unit == "player" or unit == "party1" or unit == "party2" or unit == "party3" or (unit == "target" and target ~= nil) end
UnitName = function(unit) if unit == "player" then return "Lootmaster" elseif unit == "party1" then return "Alice" elseif unit == "party2" then return "Charlie" elseif unit == "party3" then return "Dave" elseif unit == "target" then return target end end
UnitIsConnected = function() return true end
CheckInteractDistance = function(unit) return inRange and (unit == "party1" or unit == "party2" or unit == "party3" or unit == "target") end
SendChatMessage = function(message, channel, _, player) whispers[#whispers + 1] = { message, channel, player } end
ClickTradeButton = function(slot) clicks[#clicks + 1] = slot; tradeSlots[slot], cursor = cursor, nil end
GetTradePlayerItemLink = function(slot) return tradeSlots[slot] end
GetTradePlayerItemInfo = function() return nil, nil, 1 end
ClearCursor = function() cursor = nil end
TradeFrameRecipientNameText = { GetText = function() return target end }
local accepts, initiations, playerMoney, targetMoney = 0, {}, 0, 0
AcceptTrade = function() accepts = accepts + 1 end
InitiateTrade = function(unit) initiations[#initiations + 1] = unit end
GetPlayerTradeMoney = function() return playerMoney end
GetTargetTradeMoney = function() return targetMoney end
GetTradeTargetItemLink = function(slot) return targetTradeSlots[slot] end

assert(loadfile(root .. "/Modules/Trade.lua"))("MasterLooter", GA)
GA.Trade:OnInitialize()

local function award(session, item, winner)
    return assert(GA.Trade:QueueAward({ sessionID = session, itemLink = "|Hitem:" .. item .. ":0:0:0|h[Test " .. item .. "]|h", winner = winner }, "SMOKE"))
end

-- An out-of-range addonless winner receives a direct, rate-limited whisper.
bags = { { bag = 0, slot = 1, link = "|Hitem:1001:0:0:0|h[Test 1001]|h", count = 1, locked = false } }
local first = award("s1", 1001, "Alice")
same(first.rangeStatus, "OUT_OF_RANGE", "group-unit range is recorded")
same(#whispers, 1, "first pending delivery whispers winner")
same(whispers[1][2], "WHISPER", "delivery reminder uses whisper channel")
expect(string.find(whispers[1][1], "handle Lootmaster an", 1, true), "reminder names the lootmaster")
bags[2] = { bag = 0, slot = 2, link = "|Hitem:1002:0:0:0|h[Test 1002]|h", count = 1, locked = false }
award("s2", 1002, "Alice")
same(#whispers, 1, "multiple awards do not create a whisper burst")

-- Entering range is tracked without an unsolicited whisper; leaving range later
-- may send one final reminder, after which the hard limit wins.
now, inRange = now + GA.Trade.REMINDER_COOLDOWN + 1, true
GA.Trade:RefreshWinnerStatuses(true)
same(#whispers, 1, "entering range does not whisper")
same(#initiations, 1, "winner entering trade range is automatically contacted")
same(initiations[1], "party1", "automatic trade uses the winner's group unit")
same(GA.Trade.deliveryStatus, "AUTO_OPENING", "automatic trade opening is visible in state")
now, inRange = now + GA.Trade.REMINDER_COOLDOWN + 1, false
GA.Trade.state, GA.Trade.partner = "IDLE", nil
GA.Trade:RefreshWinnerStatuses(true)
same(#whispers, 2, "winner reminder hard limit prevents loops")
now = now + GA.Trade.REMINDER_COOLDOWN + 1
GA.Trade:RefreshWinnerStatuses(true)
same(#whispers, 2, "unchanged out-of-range state does not loop")

-- The matching trade partner causes automatic placement and safe acceptance.
inRange, target, tradeSlots, targetTradeSlots = true, "Alice", {}, {}
bags = {
    { bag = 0, slot = 1, link = first.itemLink, count = 1, locked = false },
    { bag = 0, slot = 2, link = "|Hitem:1002:0:0:0|h[Test 1002]|h", count = 1, locked = false },
}
GA.Trade:OnTradeShow()
same(GA.Trade.partner, "Alice", "trade partner is detected")
same(GA.Trade.autoPlaced, 2, "all matching available awards are automatically placed")
same(#pickups, 2, "automatic placement touches each reserved bag slot once")
same(#clicks, 2, "automatic placement uses two distinct trade slots")
same(accepts, 1, "exact verified winner trade is accepted automatically")
same(GA.Trade.deliveryStatus, "AUTO_ACCEPTED", "automatic acceptance is visible in state")
GA.Trade:OnTradeAcceptUpdate(1, 0)
same(accepts, 1, "repeated accept events do not accept the same offer twice")
targetTradeSlots[1] = "|Hitem:9000:0:0:0|h[Late counter item]|h"
GA.Trade:OnTradeAcceptUpdate(0, 0)
same(accepts, 1, "a changed unsafe offer cancels unattended re-acceptance")
targetTradeSlots[1] = nil
GA.Trade:OnTradeAcceptUpdate(0, 0)
same(accepts, 2, "safe offer is revalidated and reaccepted after the change is removed")

-- Re-entry in the same open trade cannot duplicate already placed stacks.
local before = #pickups
local repeated = assert(GA.Trade:PlacePreparedGroup("Alice"))
same(#repeated, 0, "repeated placement skips entries already placed in this trade")
same(#pickups, before, "repeated placement does not pick up duplicate stacks")

-- One physical stack can back only one award, even for identical items.
GA.Trade.pending, GA.Trade.preparedGroup, GA.Trade.placedThisTrade, tradeSlots = {}, nil, {}, {}
local duplicateA = award("d1", 2001, "Alice")
award("d2", 2001, "Alice")
bags = { { bag = 1, slot = 1, link = duplicateA.itemLink, count = 1, locked = false } }
pickups, clicks = {}, {}
GA.Trade.state, GA.Trade.partner = "OPEN", "Alice"
GA.Trade:PrepareGroup("Alice")
local duplicatePlaced = assert(GA.Trade:PlacePreparedGroup("Alice"))
same(#duplicatePlaced, 1, "one bag stack is never offered twice")
same(#pickups, 1, "duplicate award protection touches the stack once")

-- A trade has only six non-enchantment item slots; overflow remains pending.
GA.Trade.pending, GA.Trade.preparedGroup, GA.Trade.placedThisTrade, tradeSlots = {}, nil, {}, {}
bags, pickups, clicks = {}, {}, {}
for index = 1, 7 do
    local entry = award("m" .. index, 3000 + index, "Alice")
    bags[index] = { bag = 2, slot = index, link = entry.itemLink, count = 1, locked = false }
end
GA.Trade.state, GA.Trade.partner = "OPEN", "Alice"
GA.Trade:PrepareGroup("Alice")
local capped = assert(GA.Trade:PlacePreparedGroup("Alice"))
same(#capped, 6, "automatic trade placement is capped at six items")
same(#clicks, 6, "only six trade slots are clicked")

-- An unrelated player never receives queued items.
GA.Trade.preparedGroup = { winner = "Alice", entries = GA.Trade:GetPending("Alice") }
target, pickups, clicks, tradeSlots = "Mallory", {}, {}, {}
local acceptBaseline = accepts
GA.Trade:OnTradeShow()
same(GA.Trade.state, "WRONG_PARTNER", "unrelated trade partner is rejected")
same(#pickups, 0, "wrong partner cannot trigger bag pickup")
same(#clicks, 0, "wrong partner cannot fill a trade slot")
same(accepts, acceptBaseline, "wrong partner is never accepted")

-- Existing player offers are preserved; automatic placement starts at the
-- first genuinely free trade slot.
GA.Trade.pending, GA.Trade.preparedGroup, GA.Trade.placedThisTrade = {}, nil, {}
local occupiedAward = award("o1", 4001, "Alice")
bags = { { bag = 3, slot = 1, link = occupiedAward.itemLink, count = 1, locked = false } }
target, pickups, clicks, targetTradeSlots = "Alice", {}, {}, {}
tradeSlots = { [1] = "|Hitem:9999:0:0:0|h[Existing offer]|h" }
acceptBaseline = accepts
GA.Trade:OnTradeShow()
same(clicks[1], 2, "occupied first trade slot is skipped")
same(tradeSlots[1], "|Hitem:9999:0:0:0|h[Existing offer]|h", "existing trade item is not overwritten")
same(accepts, acceptBaseline, "unexpected own trade item blocks automatic acceptance")
expect(string.find(GA.Trade.deliveryStatus or "", "AUTO_ACCEPT_BLOCKED", 1, true), "blocked acceptance is exposed in state")

-- Target-only identity is insufficient for automatic item movement.
TradeFrameRecipientNameText = nil
GA.Trade.pending, GA.Trade.preparedGroup, GA.Trade.placedThisTrade = {}, nil, {}
local unverified = award("u1", 5001, "Alice")
bags = { { bag = 4, slot = 1, link = unverified.itemLink, count = 1, locked = false } }
target, pickups, clicks, tradeSlots = "Alice", {}, {}, {}
acceptBaseline = accepts
GA.Trade:OnTradeShow()
same(GA.Trade.state, "UNVERIFIED_PARTNER", "target fallback is not trusted for automatic placement")
same(#pickups, 0, "unverified partner cannot move bag items")
same(accepts, acceptBaseline, "unverified partner is never accepted")

-- Cancellation restores transient placement state for a safe retry.
TradeFrameRecipientNameText = { GetText = function() return target end }
tradeSlots, targetTradeSlots = {}, {}
GA.Trade:OnTradeShow()
same(unverified.status, "PLACED", "verified trade marks the item placed")
same(accepts, acceptBaseline + 1, "verified retry is accepted automatically")
GA.Trade:OnTradeCancelled()
same(unverified.status, "PENDING", "cancelled trade restores pending status")
same(GA.Trade.placedThisTrade, nil, "cancelled trade clears transient placement tracking")

-- Anything contributed by the winner blocks unattended acceptance. The same
-- applies to money on either side, even when the reserved item itself matches.
local function guardedTrade(item, configure)
    GA.Trade.pending, GA.Trade.preparedGroup, GA.Trade.placedThisTrade = {}, nil, {}
    GA.Trade.state, GA.Trade.partner, GA.Trade.autoInitiations = "IDLE", nil, {}
    tradeSlots, targetTradeSlots, playerMoney, targetMoney = {}, {}, 0, 0
    local entry = award("guard-" .. item, item, "Alice")
    bags = { { bag = 4, slot = item % 10 + 1, link = entry.itemLink, count = 1, locked = false } }
    if configure then configure() end
    target, inRange = "Alice", true
    local beforeAccept = accepts
    GA.Trade:OnTradeShow()
    return beforeAccept
end

acceptBaseline = guardedTrade(5101, function() targetTradeSlots[1] = "|Hitem:9001:0:0:0|h[Counter item]|h" end)
same(accepts, acceptBaseline, "winner-provided item blocks automatic acceptance")
expect(string.find(GA.Trade.deliveryStatus or "", "target item offered", 1, true), "counter-item block reason is retained")

acceptBaseline = guardedTrade(5102, function() playerMoney = 1 end)
same(accepts, acceptBaseline, "own offered money blocks automatic acceptance")
expect(string.find(GA.Trade.deliveryStatus or "", "player money offered", 1, true), "own-money block reason is retained")

acceptBaseline = guardedTrade(5103, function() targetMoney = 1 end)
same(accepts, acceptBaseline, "winner money blocks automatic acceptance")
expect(string.find(GA.Trade.deliveryStatus or "", "target money offered", 1, true), "winner-money block reason is retained")
playerMoney, targetMoney, targetTradeSlots = 0, 0, {}

-- A notification is delayed until the awarded item is actually visible in the
-- lootmaster's bags, preventing phantom delivery messages after a failed take.
GA.Trade.pending, GA.Trade.preparedGroup, bags, inRange = {}, nil, {}, false
GA.Trade.state, GA.Trade.partner = "IDLE", nil
local whisperBaseline = #whispers
local delayed = award("p1", 6001, "Charlie")
same(delayed.status, "MISSING", "not-yet-looted item is not marked ready")
same(#whispers, whisperBaseline, "missing bag item produces no winner whisper")
bags = { { bag = 0, slot = 5, link = delayed.itemLink, count = 1, locked = false } }
GA.Trade:RefreshWinnerStatuses(true)
same(delayed.status, "READY", "bag update/poll makes the delivery ready")
same(#whispers, whisperBaseline + 1, "ready out-of-range delivery is then whispered")

-- Known MasterLooter peers in range receive one advisory handshake request;
-- addonless players continue to rely on the ordinary trade/whisper flow.
local requests = 0
GA.TradeCoordination = {
    HasAddon = function(_, name) return name == "Dave" end,
    Request = function(_, name, count) requests = requests + 1; return { winner = name, itemCount = count } end,
}
GA.Trade.pending, bags, inRange = {}, {}, true
GA.Trade.state, GA.Trade.partner, GA.Trade.autoInitiations = "IDLE", nil, {}
local coordinated = "|Hitem:7001:0:0:0|h[Coordinated]|h"
bags[1] = { bag = 0, slot = 6, link = coordinated, count = 1, locked = false }
award("c1", 7001, "Dave")
same(requests, 1, "known in-range addon peer receives a handshake request")
same(initiations[#initiations], "party3", "addon peer is also automatically contacted for trade")
bags[2] = { bag = 0, slot = 7, link = "|Hitem:7002:0:0:0|h[Coordinated 2]|h", count = 1, locked = false }
award("c2", 7002, "Dave")
same(requests, 1, "handshake requests are rate-limited per winner")

print("PASS: " .. assertions .. " trade automation smoke assertions")
