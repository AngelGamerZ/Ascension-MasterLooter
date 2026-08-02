-- Award delivery assistant for 3.3.5a. This module observes and verifies trades;
-- it deliberately never picks up an item, places it in trade, or accepts a trade.
local _, GA = ...

local Trade = { pending = {}, nextID = 0, state = "IDLE", offered = {}, bothAccepted = false }
GA.Trade = Trade

local function timestamp()
    return (time and time()) or 0
end

local function baseName(name)
    return type(name) == "string" and (string.match(name, "^[^-]+") or name) or nil
end

local function sameName(left, right)
    left, right = baseName(left), baseName(right)
    return left and right and string.lower(left) == string.lower(right)
end

local function emitState(reason)
    GA.Events:Emit("GA_TRADE_STATE_CHANGED", Trade:GetState(), reason)
end

local function newID()
    Trade.nextID = Trade.nextID + 1
    return tostring(timestamp()) .. "-" .. tostring(Trade.nextID)
end

function Trade:GetState()
    return {
        status = self.state, partner = self.partner, prepared = self.prepared,
        offered = self.offered, bothAccepted = self.bothAccepted,
    }
end

function Trade:GetPending(player)
    if not player then return self.pending end
    local result = {}
    for index = 1, #self.pending do
        if sameName(self.pending[index].winner, player) then result[#result + 1] = self.pending[index] end
    end
    return result
end

function Trade:Get(id)
    for index = 1, #self.pending do
        if self.pending[index].id == id then return self.pending[index], index end
    end
end

function Trade:QueueAward(result, source)
    if type(result) ~= "table" or type(result.itemLink) ~= "string" or type(result.winner) ~= "string" then
        return nil, "award requires itemLink and winner"
    end
    local entry = {
        id = newID(), itemLink = result.itemLink, itemID = GA.Compat:GetItemID(result.itemLink),
        winner = result.winner, quantity = math.max(1, math.floor(tonumber(result.quantity) or 1)),
        choice = result.choice, roll = result.roll, note = result.note,
        status = "PENDING", source = source or "AWARD", createdAt = timestamp(), updatedAt = timestamp(),
    }
    self.pending[#self.pending + 1] = entry
    GA.Events:Emit("GA_TRADE_PENDING_ADDED", entry)
    return entry
end

function Trade:Remove(id)
    local entry, index = self:Get(id)
    if not entry then return false end
    table.remove(self.pending, index)
    GA.Events:Emit("GA_TRADE_PENDING_REMOVED", entry)
    return true
end

function Trade:FindInBags(idOrItem)
    local entry = type(idOrItem) == "string" and self:Get(idOrItem) or nil
    local item = entry and entry.itemID or idOrItem
    return GA.Compat:FindItems(item)
end

function Trade:Prepare(id)
    local entry = self:Get(id)
    if not entry then return nil, "unknown pending award" end
    if entry.status == "DELIVERED" or entry.status == "CANCELLED" then return nil, "award is closed" end
    local locations = GA.Compat:FindItems(entry.itemID)
    if #locations == 0 then
        entry.status, entry.updatedAt = "MISSING", timestamp()
        GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
        return nil, "item is not in the player's bags"
    end
    self.prepared = entry
    entry.status, entry.locations, entry.updatedAt = "READY", locations, timestamp()
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    emitState("PREPARED")
    return entry, locations
end

function Trade:MarkDelivered(id, reason)
    local entry = self:Get(id)
    if not entry then return false, "unknown pending award" end
    entry.status, entry.updatedAt, entry.deliveredAt = "DELIVERED", timestamp(), timestamp()
    entry.deliveryReason = reason or "CONFIRMED_TRADE"
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    return true, entry
end

function Trade:MarkFailed(id, reason)
    local entry = self:Get(id)
    if not entry then return false, "unknown pending award" end
    entry.status, entry.updatedAt = "MISSING", timestamp()
    entry.deliveryReason = reason or "MANUAL_FAILURE"
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    return true, entry
end

local function tradePartner()
    if TradeFrameRecipientNameText and TradeFrameRecipientNameText.GetText then
        local recipient = TradeFrameRecipientNameText:GetText()
        if recipient and recipient ~= "" then return recipient end
    end
    if UnitExists and UnitExists("target") and (not UnitIsPlayer or UnitIsPlayer("target")) then
        return UnitName("target")
    end
end

function Trade:ScanOfferedItems()
    local offered = {}
    if type(GetTradePlayerItemLink) == "function" then
        for slot = 1, 6 do
            local link = GetTradePlayerItemLink(slot)
            if link then
                local quantity = 1
                if type(GetTradePlayerItemInfo) == "function" then
                    local _, _, count = GetTradePlayerItemInfo(slot)
                    quantity = math.max(1, tonumber(count) or 1)
                end
                offered[#offered + 1] = {
                    slot = slot, link = link, itemID = GA.Compat:GetItemID(link), quantity = quantity,
                }
            end
        end
    end
    self.offered = offered
    return offered
end

function Trade:OnTradeShow()
    self.partner, self.state, self.bothAccepted = tradePartner(), "OPEN", false
    self:ScanOfferedItems()
    if self.prepared and self.partner and not sameName(self.prepared.winner, self.partner) then
        self.state = "WRONG_PARTNER"
    end
    emitState("TRADE_SHOW")
end

function Trade:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    self:ScanOfferedItems()
    self.bothAccepted = playerAccepted == 1 and targetAccepted == 1
    self.state = self.bothAccepted and "WAITING_COMPLETE" or "OPEN"
    emitState("ACCEPT_UPDATE")
end

function Trade:Complete(reason)
    local delivered = {}
    local available = {}
    for index = 1, #self.offered do
        local item = self.offered[index]
        available[index] = { link = item.link, itemID = item.itemID, remaining = item.quantity }
    end
    local deliveredIDs = {}
    local function consume(entry, exact)
        local total = 0
        for index = 1, #available do
            local item = available[index]
            if (exact and item.link == entry.itemLink) or (not exact and item.itemID == entry.itemID) then
                total = total + item.remaining
            end
        end
        if total < entry.quantity then return false end
        local needed = entry.quantity
        for index = 1, #available do
            local item = available[index]
            if needed > 0 and ((exact and item.link == entry.itemLink) or (not exact and item.itemID == entry.itemID)) then
                local used = math.min(needed, item.remaining)
                item.remaining, needed = item.remaining - used, needed - used
            end
        end
        return true
    end
    local function deliverMatches(exact)
        for index = 1, #Trade.pending do
            local entry = Trade.pending[index]
            if not deliveredIDs[entry.id] and entry.status ~= "DELIVERED" and sameName(entry.winner, Trade.partner) and
                consume(entry, exact) then
                Trade:MarkDelivered(entry.id, reason)
                deliveredIDs[entry.id] = true
                delivered[#delivered + 1] = entry
            end
        end
    end
    deliverMatches(true) -- Preserve Ascension variants whenever the complete hyperlink is available.
    deliverMatches(false) -- Legacy fallback for links whose formatting differs between bag/trade APIs.
    self.state = "COMPLETED"
    emitState(reason or "TRADE_COMPLETE")
    GA.Events:Emit("GA_TRADE_COMPLETED", self.partner, delivered)
    self.prepared = nil
end

function Trade:OnTradeClosed()
    if self.state == "COMPLETED" then
        self.partner, self.offered, self.bothAccepted = nil, {}, false
        return
    elseif self.state == "WAITING_COMPLETE" and self.bothAccepted then
        self.state = "AWAITING_CONFIRMATION"
        emitState("TRADE_CLOSED_AFTER_ACCEPT")
        GA.Compat:After(1, function()
            if Trade.state == "AWAITING_CONFIRMATION" then
                Trade.state = "UNCONFIRMED"
                emitState("NO_TRADE_COMPLETE_MESSAGE")
            end
        end)
    else
        self.state = "CANCELLED"
        emitState("TRADE_CLOSED")
        self.partner, self.offered, self.bothAccepted = nil, {}, false
    end
end

function Trade:OnTradeCancelled()
    self.state, self.bothAccepted = "CANCELLED", false
    emitState("TRADE_CANCELLED")
    self.partner, self.offered = nil, {}
end

function Trade:OnUIInfoMessage(first, second)
    local message = type(second) == "string" and second or first
    if type(message) ~= "string" then return end
    if (ERR_TRADE_COMPLETE and message == ERR_TRADE_COMPLETE) or message == "Trade complete." then
        if self.state == "WAITING_COMPLETE" or self.state == "AWAITING_CONFIRMATION" or self.state == "UNCONFIRMED" then
            self:Complete("TRADE_COMPLETE_MESSAGE")
            self.partner, self.offered, self.bothAccepted = nil, {}, false
        end
    end
end

function Trade:OnInitialize()
    GA.DB.data.character.trade = GA.DB.data.character.trade or { pending = {}, nextID = 0 }
    self.store = GA.DB.data.character.trade
    self.pending, self.nextID = self.store.pending or {}, tonumber(self.store.nextID) or 0
    self.store.pending = self.pending
    GA.Events:On("GA_AWARD_RECORDED", function(_, _, result, delivery)
        if delivery == "PENDING" then Trade:QueueAward(result, "AWARD") end
    end, self)
    GA.Events:On("TRADE_SHOW", function() Trade:OnTradeShow() end, self)
    GA.Events:On("TRADE_ACCEPT_UPDATE", function(_, _, ours, theirs) Trade:OnTradeAcceptUpdate(ours, theirs) end, self)
    GA.Events:On("TRADE_CLOSED", function() Trade:OnTradeClosed() end, self)
    GA.Events:On("TRADE_REQUEST_CANCEL", function() Trade:OnTradeCancelled() end, self)
    GA.Events:On("UI_INFO_MESSAGE", function(_, _, first, second) Trade:OnUIInfoMessage(first, second) end, self)
    GA.Events:RegisterGameEvent("TRADE_SHOW")
    GA.Events:RegisterGameEvent("TRADE_ACCEPT_UPDATE")
    GA.Events:RegisterGameEvent("TRADE_CLOSED")
    GA.Events:RegisterGameEvent("TRADE_REQUEST_CANCEL")
    GA.Events:RegisterGameEvent("UI_INFO_MESSAGE")
    return true
end

function Trade:OnSave()
    if self.store then self.store.pending, self.store.nextID = self.pending, self.nextID end
end

GA:RegisterModule("Trade", Trade)
