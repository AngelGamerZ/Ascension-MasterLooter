-- Award delivery assistant for 3.3.5a. A verified open trade can be filled
-- automatically; opening and final acceptance remain user-controlled.
local _, GA = ...

local Trade = {
    pending = {}, nextID = 0, state = "IDLE", offered = {}, bothAccepted = false,
    TRADE_SECONDS = 7200, REMINDER_COOLDOWN = 180, REMINDER_LIMIT = 2,
}
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
        deliveryStatus = self.deliveryStatus, autoPlaced = self.autoPlaced,
    }
end

function Trade:FindGroupUnit(player)
    if type(UnitExists) ~= "function" or type(UnitName) ~= "function" then return nil end
    local units = { "player" }
    for index = 1, 4 do units[#units + 1] = "party" .. index end
    for index = 1, 40 do units[#units + 1] = "raid" .. index end
    for _, unit in ipairs(units) do
        if UnitExists(unit) and sameName(UnitName(unit), player) then return unit end
    end
end

function Trade:GetWinnerRangeStatus(player)
    local unit = self:FindGroupUnit(player)
    if not unit then return "UNKNOWN", nil end
    if unit == "player" then return "SELF", unit end
    if type(UnitIsConnected) == "function" and not UnitIsConnected(unit) then return "OFFLINE", unit end
    if type(CheckInteractDistance) == "function" then
        return CheckInteractDistance(unit, 2) and "IN_RANGE" or "OUT_OF_RANGE", unit
    end
    if type(UnitInRange) == "function" then
        local inRange = UnitInRange(unit)
        if inRange ~= nil then return inRange and "GROUP_RANGE" or "OUT_OF_RANGE", unit end
    end
    return "UNKNOWN", unit
end

function Trade:RemindWinner(entry, force)
    if type(entry) ~= "table" or type(entry.winner) ~= "string" or sameName(entry.winner, UnitName and UnitName("player")) then return false end
    if entry.status ~= "READY" then return false end
    local status = self:GetWinnerRangeStatus(entry.winner)
    entry.rangeStatus, entry.rangeCheckedAt = status, timestamp()
    if status ~= "OUT_OF_RANGE" then return false end
    if self.state == "OPEN" and sameName(self.partner, entry.winner) then return false end
    self.reminders = self.reminders or {}
    local key = string.lower(baseName(entry.winner) or entry.winner)
    local reminder = self.reminders[key] or { count = 0, last = 0 }
    local count = math.max(tonumber(entry.reminderCount) or 0, tonumber(reminder.count) or 0)
    local last = math.max(tonumber(entry.lastReminderAt) or 0, tonumber(reminder.last) or 0)
    if not force and (count >= self.REMINDER_LIMIT or timestamp() - last < self.REMINDER_COOLDOWN) then return false end
    if type(SendChatMessage) ~= "function" then return false end
    local message = "MasterLooter: Du hast " .. tostring(entry.itemLink or "ein Item") .. " gewonnen. Bitte handle " ..
        tostring((UnitName and UnitName("player")) or "den Lootmaster") .. " an, um es zu erhalten."
    local ok = pcall(SendChatMessage, message, "WHISPER", nil, entry.winner)
    if not ok then return false end
    entry.reminderCount, entry.lastReminderAt = count + 1, timestamp()
    self.reminders[key] = { count = entry.reminderCount, last = entry.lastReminderAt }
    entry.updatedAt = timestamp()
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    return true
end

function Trade:CoordinateWinner(entry)
    if type(entry) ~= "table" or entry.status ~= "READY" or
        (entry.rangeStatus ~= "IN_RANGE" and entry.rangeStatus ~= "GROUP_RANGE") then return false end
    local coordination = GA.TradeCoordination
    if not coordination or type(coordination.HasAddon) ~= "function" or type(coordination.Request) ~= "function" then return false end
    local hasAddon = coordination:HasAddon(entry.winner)
    if not hasAddon then return false end
    self.coordinationRequests = self.coordinationRequests or {}
    local key = string.lower(baseName(entry.winner) or entry.winner)
    if timestamp() - (tonumber(self.coordinationRequests[key]) or 0) < 60 then return false end
    local count = 0
    for _, pending in ipairs(self:GetPending(entry.winner)) do if pending.status == "READY" then count = count + 1 end end
    local ok, request = pcall(coordination.Request, coordination, entry.winner, math.min(6, math.max(1, count)))
    if not ok or not request then return false end
    self.coordinationRequests[key] = timestamp()
    return true
end

function Trade:ScheduleRangePoll()
    if self.rangePollActive or type(GA.Compat.After) ~= "function" or #self:GetPending() == 0 then return end
    self.rangePollActive = true
    self.rangePollAttempts = tonumber(self.rangePollAttempts) or 0
    GA.Compat:After(10, function()
        Trade.rangePollActive = false
        Trade.rangePollAttempts = Trade.rangePollAttempts + 1
        Trade:RefreshWinnerStatuses(true)
        if #Trade:GetPending() > 0 and Trade.rangePollAttempts < 60 then Trade:ScheduleRangePoll() end
    end)
end

function Trade:RefreshWinnerStatuses(remind)
    local seen = {}
    for _, entry in ipairs(self:GetPending()) do
        local key = string.lower(baseName(entry.winner) or entry.winner or "?")
        local old = entry.rangeStatus
        if not (self.state == "OPEN" and self.placedThisTrade and self.placedThisTrade[entry.id]) then self:Assess(entry) end
        entry.rangeStatus = self:GetWinnerRangeStatus(entry.winner)
        entry.rangeCheckedAt = timestamp()
        if remind and not seen[key] and (old ~= entry.rangeStatus or not entry.lastReminderAt) then
            self:RemindWinner(entry)
            seen[key] = true
        end
        if not seen["coord:" .. key] then
            self:CoordinateWinner(entry)
            seen["coord:" .. key] = true
        end
    end
end

function Trade:GetPending(player)
    local result = {}
    for index = 1, #self.pending do
        local entry = self.pending[index]
        if entry.status ~= "DELIVERED" and entry.status ~= "CANCELLED" and (not player or sameName(entry.winner, player)) then
            result[#result + 1] = entry
        end
    end
    return result
end

function Trade:GetGroups()
    local groups, order = {}, {}
    for _, entry in ipairs(self:GetPending()) do
        local key = string.lower(baseName(entry.winner) or entry.winner or "?")
        local group = groups[key]
        if not group then
            group = { key = key, winner = entry.winner, entries = {}, quantity = 0, ready = 0, missing = 0 }
            groups[key], order[#order + 1] = group, group
        end
        group.entries[#group.entries + 1] = entry
        group.quantity = group.quantity + (entry.quantity or 1)
        if entry.status == "READY" then group.ready = group.ready + 1 end
        if entry.status == "MISSING" or entry.status == "EXPIRED" then group.missing = group.missing + 1 end
        if entry.tradeExpiresAt and (not group.tradeExpiresAt or entry.tradeExpiresAt < group.tradeExpiresAt) then group.tradeExpiresAt = entry.tradeExpiresAt end
    end
    table.sort(order, function(a, b) return string.lower(a.winner or "") < string.lower(b.winner or "") end)
    return order
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
    for index = 1, #self.pending do
        local existing = self.pending[index]
        if result.sessionID and existing.sessionID == result.sessionID and sameName(existing.winner, result.winner) and existing.itemLink == result.itemLink then
            return existing
        end
    end
    local acquiredAt = tonumber(result.acquiredAt) or timestamp()
    local entry = {
        id = newID(), itemLink = result.itemLink, itemID = GA.Compat:GetItemID(result.itemLink),
        sessionID = result.sessionID,
        winner = result.winner, quantity = math.max(1, math.floor(tonumber(result.quantity) or 1)),
        choice = result.choice, roll = result.roll, note = result.note,
        status = "PENDING", source = source or "AWARD", createdAt = timestamp(), acquiredAt = acquiredAt,
        tradeExpiresAt = acquiredAt + self.TRADE_SECONDS, updatedAt = timestamp(),
    }
    self.pending[#self.pending + 1] = entry
    GA.Events:Emit("GA_TRADE_PENDING_ADDED", entry)
    self:Assess(entry)
    self:RemindWinner(entry)
    self:CoordinateWinner(entry)
    self.rangePollAttempts = 0
    self:ScheduleRangePoll()
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

function Trade:Assess(entry)
    if type(entry) ~= "table" then return nil, "unknown pending award" end
    local current = timestamp()
    local locations = GA.Compat:FindItems(entry.itemID)
    entry.locations, entry.updatedAt = locations, current
    if entry.tradeExpiresAt and current >= entry.tradeExpiresAt then
        entry.status, entry.tradeability = "EXPIRED", "ESTIMATED_EXPIRED"
    elseif #locations == 0 then
        entry.status, entry.tradeability = "MISSING", "NOT_IN_BAGS"
    else
        entry.status, entry.tradeability = "READY", "UNVERIFIED"
    end
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    return entry, locations
end

function Trade:Prepare(id)
    local entry = self:Get(id)
    if not entry then return nil, "unknown pending award" end
    if entry.status == "DELIVERED" or entry.status == "CANCELLED" then return nil, "award is closed" end
    local assessed, locations = self:Assess(entry)
    if not assessed or assessed.status ~= "READY" then return nil, assessed and (assessed.status == "EXPIRED" and "Geschätzte Handelsfrist ist abgelaufen." or "Item ist nicht in den Taschen.") or "Itemprüfung fehlgeschlagen." end
    self.prepared = entry
    entry.status, entry.locations, entry.updatedAt = "READY", locations, timestamp()
    GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
    emitState("PREPARED")
    return entry, locations
end

function Trade:PrepareGroup(winner)
    local ready, errors, used = {}, {}, {}
    for _, entry in ipairs(self:GetPending(winner)) do
        local assessed, locations = self:Assess(entry)
        local chosen
        if assessed and assessed.status == "READY" then
            for _, location in ipairs(locations) do
                local key = tostring(location.bag) .. ":" .. tostring(location.slot)
                if not used[key] then chosen, used[key] = location, true; break end
            end
        end
        if chosen then
            entry.locations, entry.status = { chosen }, "READY"
            ready[#ready + 1] = entry
        else
            entry.status = assessed and assessed.status == "READY" and "MISSING" or (assessed and assessed.status or "MISSING")
            errors[#errors + 1] = entry.status == "EXPIRED" and "Geschätzte Handelsfrist ist abgelaufen." or "Kein freier passender Taschenstack."
            GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
        end
    end
    self.preparedGroup = { winner = winner, entries = ready }
    emitState("GROUP_PREPARED")
    return ready, errors
end

function Trade:BeginTrade(winner)
    if type(winner) ~= "string" or winner == "" then return nil, "Kein Gewinner ausgewählt." end
    if type(UnitExists) ~= "function" or not UnitExists("target") or not sameName(UnitName("target"), winner) then
        return nil, "Gewinner muss als Ziel ausgewählt sein."
    end
    if type(CheckInteractDistance) == "function" and not CheckInteractDistance("target", 2) then
        return nil, "Gewinner ist nicht in Handelsreichweite."
    end
    if type(InitiateTrade) ~= "function" then return nil, "Handels-API ist nicht verfügbar." end
    local ok, err = pcall(InitiateTrade, "target")
    if not ok then return nil, tostring(err) end
    self.state, self.partner = "OPENING", winner
    emitState("USER_INITIATED_TRADE")
    return true
end

-- User-clicked convenience only: places exact bag stacks in the already open
-- trade window. It never opens, accepts or confirms the trade.
function Trade:PlacePreparedGroup(winner, limit)
    if self.state ~= "OPEN" then return nil, "Handelsfenster ist nicht geöffnet." end
    if not self.partner or not sameName(self.partner, winner) then return nil, "Falscher Handelspartner." end
    if type(ClickTradeButton) ~= "function" then return nil, "Trade-Slot-API ist nicht verfügbar." end
    local entries = self.preparedGroup and sameName(self.preparedGroup.winner, winner) and self.preparedGroup.entries or self:PrepareGroup(winner)
    if type(entries) ~= "table" or #entries == 0 then return nil, "Keine handelsbereiten Items." end
    self.placedThisTrade = self.placedThisTrade or {}
    local placed, occupied = {}, {}
    for _, offered in ipairs(self:ScanOfferedItems()) do occupied[offered.slot] = true end
    local function nextTradeSlot()
        for slot = 1, 6 do if not occupied[slot] then return slot end end
    end
    for index = 1, #entries do
        if limit and #placed >= limit then break end
        local entry = entries[index]
        local location = entry.locations and entry.locations[1]
        local tradeSlot = nextTradeSlot()
        if tradeSlot and location and entry.status == "READY" and not self.placedThisTrade[entry.id] then
            if (tonumber(location.count) or 1) > (tonumber(entry.quantity) or 1) then
                entry.status, entry.tradeability = "SPLIT_REQUIRED", "STACK_TOO_LARGE"
            elseif location.locked then
                entry.status = "LOCKED"
            else
                local picked = pcall(GA.Compat.PickupContainerItem, GA.Compat, location.bag, location.slot)
                local clicked = picked and pcall(ClickTradeButton, tradeSlot)
                if picked and clicked then
                    local verified = nil
                    if type(GetTradePlayerItemLink) == "function" then
                        local offeredLink = GetTradePlayerItemLink(tradeSlot)
                        verified = offeredLink and (offeredLink == entry.itemLink or GA.Compat:GetItemID(offeredLink) == entry.itemID) or false
                    end
                    if verified == false then
                        if type(ClearCursor) == "function" then pcall(ClearCursor) end
                        entry.status, entry.tradeability = "PLACE_FAILED", "TRADE_SLOT_NOT_VERIFIED"
                    else
                        entry.status = verified and "PLACED" or "PLACEMENT_REQUESTED"
                        entry.tradeability, entry.updatedAt = verified and "VERIFIED_IN_TRADE" or "CLIENT_CALL_SUCCEEDED", timestamp()
                        self.placedThisTrade[entry.id], occupied[tradeSlot] = true, true
                        placed[#placed + 1] = entry
                    end
                else
                    entry.status, entry.tradeability = "PLACE_FAILED", "CLIENT_REJECTED"
                end
            end
            GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
        end
    end
    self:ScanOfferedItems()
    emitState("ITEMS_PLACED_BY_USER")
    return placed
end

function Trade:AutoPlacePreparedGroup(winner)
    if self.state ~= "OPEN" or not self.partnerVerified or not sameName(self.partner, winner) then return nil end
    self.autoPlacementToken = (tonumber(self.autoPlacementToken) or 0) + 1
    local token = self.autoPlacementToken
    self.autoPlaced, self.deliveryStatus = 0, "AUTO_PREPARING"
    local function step()
        if Trade.autoPlacementToken ~= token or Trade.state ~= "OPEN" or not Trade.partnerVerified or
            not sameName(Trade.partner, winner) then return end
        local placed = Trade:PlacePreparedGroup(winner, 1)
        if type(placed) == "table" and #placed > 0 then
            Trade.autoPlaced = Trade.autoPlaced + 1
            emitState("AUTO_ITEM_PLACED")
        end
        if Trade.autoPlaced >= 6 then
            Trade.deliveryStatus = "WAITING_MANUAL_ACCEPT"
            emitState("AUTO_PLACEMENT_COMPLETE")
            return
        end
        local hasRemaining = false
        for _, entry in ipairs((Trade.preparedGroup and Trade.preparedGroup.entries) or {}) do
            if entry.status == "READY" and not Trade.placedThisTrade[entry.id] then hasRemaining = true; break end
        end
        if hasRemaining and type(GA.Compat.After) == "function" then
            GA.Compat:After(0.15, step)
        else
            Trade.deliveryStatus = Trade.autoPlaced > 0 and "WAITING_MANUAL_ACCEPT" or "NOTHING_PLACED"
            emitState("AUTO_PLACEMENT_COMPLETE")
        end
    end
    step()
    return true
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
        if recipient and recipient ~= "" then return recipient, true end
    end
    if UnitExists and UnitExists("target") and (not UnitIsPlayer or UnitIsPlayer("target")) then
        return UnitName("target"), false
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
    self.partner, self.partnerVerified = tradePartner()
    self.state, self.bothAccepted = "OPEN", false
    self.placedThisTrade, self.autoPlaced = {}, 0
    self:ScanOfferedItems()
    local pending = self.partner and self:GetPending(self.partner) or {}
    if self.partnerVerified and self.partner and #pending > 0 then
        self.deliveryStatus = "AUTO_PREPARING"
        self:PrepareGroup(self.partner)
        self:AutoPlacePreparedGroup(self.partner)
    elseif not self.partnerVerified then
        self.state, self.deliveryStatus = "UNVERIFIED_PARTNER", "NO_AUTOMATIC_PLACEMENT"
    elseif (self.prepared and self.partner and not sameName(self.prepared.winner, self.partner)) or
        (self.preparedGroup and self.partner and not sameName(self.preparedGroup.winner, self.partner)) then
        self.state = "WRONG_PARTNER"
        self.deliveryStatus = "WRONG_PARTNER"
    else
        self.deliveryStatus = "NO_PENDING_ITEMS"
    end
    emitState("TRADE_SHOW_AUTO_PREPARED")
end

function Trade:ResetTransientPlacements()
    self.autoPlacementToken = (tonumber(self.autoPlacementToken) or 0) + 1
    for _, entry in ipairs(self.pending) do
        if entry.status == "PLACED" or entry.status == "PLACEMENT_REQUESTED" or entry.status == "PLACE_FAILED" then
            entry.status, entry.tradeability, entry.updatedAt = "PENDING", nil, timestamp()
            GA.Events:Emit("GA_TRADE_PENDING_UPDATED", entry)
        end
    end
    self.placedThisTrade, self.autoPlaced = nil, 0
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
        self.partner, self.offered, self.bothAccepted, self.placedThisTrade, self.preparedGroup = nil, {}, false, nil, nil
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
        self:ResetTransientPlacements()
        self.state = "CANCELLED"
        emitState("TRADE_CLOSED")
        self.partner, self.offered, self.bothAccepted, self.placedThisTrade = nil, {}, false, nil
    end
end

function Trade:OnTradeCancelled()
    self:ResetTransientPlacements()
    self.state, self.bothAccepted = "CANCELLED", false
    emitState("TRADE_CANCELLED")
    self.partner, self.offered, self.placedThisTrade = nil, {}, nil
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
    self.reminders = {}
    self.store.pending = self.pending
    for index = 1, #self.pending do
        local entry = self.pending[index]
        if entry.status == "PLACED" or entry.status == "PLACEMENT_REQUESTED" or entry.status == "PLACE_FAILED" or entry.status == "READY" or entry.status == "LOCKED" then entry.status = "PENDING" end
        entry.tradeExpiresAt = entry.tradeExpiresAt or ((entry.acquiredAt or entry.createdAt or timestamp()) + self.TRADE_SECONDS)
        if entry.winner and entry.lastReminderAt then
            local key = string.lower(baseName(entry.winner) or entry.winner)
            local old = self.reminders[key] or { count = 0, last = 0 }
            self.reminders[key] = {
                count = math.max(old.count, tonumber(entry.reminderCount) or 0),
                last = math.max(old.last, tonumber(entry.lastReminderAt) or 0),
            }
        end
    end
    GA.Events:On("GA_AWARD_RECORDED", function(_, _, result, delivery)
        if delivery == "PENDING" then Trade:QueueAward(result, "AWARD") end
    end, self)
    GA.Events:On("TRADE_SHOW", function() Trade:OnTradeShow() end, self)
    GA.Events:On("TRADE_ACCEPT_UPDATE", function(_, _, ours, theirs) Trade:OnTradeAcceptUpdate(ours, theirs) end, self)
    GA.Events:On("TRADE_CLOSED", function() Trade:OnTradeClosed() end, self)
    GA.Events:On("TRADE_REQUEST_CANCEL", function() Trade:OnTradeCancelled() end, self)
    GA.Events:On("UI_INFO_MESSAGE", function(_, _, first, second) Trade:OnUIInfoMessage(first, second) end, self)
    GA.Events:On("PARTY_MEMBERS_CHANGED", function() Trade:RefreshWinnerStatuses(true) end, self)
    GA.Events:On("RAID_ROSTER_UPDATE", function() Trade:RefreshWinnerStatuses(true) end, self)
    GA.Events:On("PLAYER_TARGET_CHANGED", function() Trade:RefreshWinnerStatuses(false) end, self)
    GA.Events:On("BAG_UPDATE", function() Trade:RefreshWinnerStatuses(true) end, self)
    GA.Events:RegisterGameEvent("TRADE_SHOW")
    GA.Events:RegisterGameEvent("TRADE_ACCEPT_UPDATE")
    GA.Events:RegisterGameEvent("TRADE_CLOSED")
    GA.Events:RegisterGameEvent("TRADE_REQUEST_CANCEL")
    GA.Events:RegisterGameEvent("UI_INFO_MESSAGE")
    GA.Events:RegisterGameEvent("PARTY_MEMBERS_CHANGED")
    GA.Events:RegisterGameEvent("RAID_ROSTER_UPDATE")
    GA.Events:RegisterGameEvent("PLAYER_TARGET_CHANGED")
    GA.Events:RegisterGameEvent("BAG_UPDATE")
    self:RefreshWinnerStatuses(false)
    self:ScheduleRangePoll()
    return true
end

function Trade:OnSave()
    if self.store then self.store.pending, self.store.nextID = self.pending, self.nextID end
end

GA:RegisterModule("Trade", Trade)
