local _, GA = ...

-- GiveMasterLoot is only invoked from an explicit award/take button. Failed
-- direct awards remain recoverable across reloads instead of pretending the
-- item is already in the loot master's bags.
local Award = { pending = {}, deferred = {}, nextID = 0, confirmTimeout = 2 }
GA.Award = Award

local function stamp() return (time and time()) or 0 end
local function baseName(name) return type(name) == "string" and (string.match(name, "^[^-]+") or name) or nil end
local function sameName(left, right)
    left, right = baseName(left), baseName(right)
    return left and right and string.lower(left) == string.lower(right)
end
local function itemID(link) return GA.Compat:GetItemID(link) end

function Award:FindLootSlot(link, preferredSlot)
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return nil end
    preferredSlot = tonumber(preferredSlot)
    if preferredSlot and GetLootSlotLink(preferredSlot) and itemID(GetLootSlotLink(preferredSlot)) == itemID(link) then
        return preferredSlot, GetLootSlotLink(preferredSlot)
    end
    local wanted, fallback = itemID(link), nil
    for slot = 1, (GetNumLootItems() or 0) do
        local slotLink = GetLootSlotLink(slot)
        if slotLink == link then return slot, slotLink end
        if not fallback and itemID(slotLink) == wanted then fallback = slot end
    end
    return fallback, fallback and GetLootSlotLink(fallback) or nil
end

function Award:FindCandidate(slot, player)
    if type(GetMasterLootCandidate) ~= "function" then return nil end
    local wanted = string.lower(baseName(player) or "")
    for index = 1, 40 do
        local candidate = GetMasterLootCandidate(slot, index)
        if not candidate then break end
        if string.lower(baseName(candidate) or "") == wanted then return index, candidate end
    end
end

function Award:BeginGive(result, session, options)
    options = options or {}
    local link, player = result.itemLink or (session and session.itemLink), options.player or result.winner
    if type(GiveMasterLoot) ~= "function" then return nil, "Masterloot-API nicht verfügbar." end
    local slot, slotLink = self:FindLootSlot(link, options.slot or result.lootSlot)
    if not slot then return nil, "Item ist nicht im geöffneten Lootfenster." end
    local candidate = self:FindCandidate(slot, player)
    if not candidate then return nil, "Spieler ist kein gültiger Loot-Kandidat (meist Entfernung oder Berechtigung)." end
    local attempt = {
        result = result, session = session, slot = slot, candidate = candidate, mode = options.mode or "DIRECT",
        deferredID = options.deferredID, lootQueueID = result.lootQueueID,
        itemLink = slotLink or link, itemID = itemID(slotLink or link), startedAt = (GetTime and GetTime()) or 0,
    }
    self.pending[slot] = attempt
    local ok, err = pcall(GiveMasterLoot, slot, candidate)
    if not ok then self.pending[slot] = nil; return nil, tostring(err) end
    attempt.timer = GA.Compat:After(self.confirmTimeout, function() Award:Timeout(slot, attempt) end)
    return attempt
end

function Award:Record(result, session, delivery)
    if type(result) ~= "table" then return nil end
    local history = GA.DB.data.history.awards
    local record = {
        sessionID = result.sessionID, itemLink = result.itemLink or (session and session.itemLink),
        winner = result.winner, choice = result.choice, roll = result.roll, note = result.note,
        time = result.awardedAt or stamp(), delivery = delivery or "RECORDED",
    }
    history[#history + 1] = record
    while #history > 2000 do table.remove(history, 1) end
    return record
end

function Award:SetDelivery(attempt, delivery)
    if not attempt then return end
    if attempt.timer and type(attempt.timer.Cancel) == "function" then attempt.timer:Cancel() end
    if attempt.history then attempt.history.delivery = delivery end
    GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", attempt.result, delivery, attempt.history)
    GA.Events:Emit("GA_AWARD_RECORDED", attempt.result, delivery)
end

function Award:GetDeferred(includeClosed)
    if includeClosed then return self.deferred end
    local result = {}
    for index = 1, #self.deferred do
        local entry = self.deferred[index]
        if entry.status == "TAKE_SELF_REQUIRED" or entry.status == "RETRY_REQUIRED" then result[#result + 1] = entry end
    end
    return result
end

function Award:GetDeferredByID(id)
    for index = 1, #self.deferred do if self.deferred[index].id == id then return self.deferred[index] end end
end

function Award:Defer(result, session, reason)
    self.nextID = self.nextID + 1
    local queued = GA.Loot and GA.Loot:FindQueued(result.itemLink, { QUEUED = true, ROLLING = true })
    if queued then
        result.lootQueueID, result.lootSlot = queued.id, queued.slot
        GA.Loot:SetQueueStatus(queued.id, "AWAITING_AWARD", reason)
    end
    local entry = {
        id = tostring(stamp()) .. "-award-" .. tostring(self.nextID), result = result,
        itemLink = result.itemLink or (session and session.itemLink), winner = result.winner,
        lootSlot = result.lootSlot, lootQueueID = result.lootQueueID,
        status = "TAKE_SELF_REQUIRED", reason = reason, createdAt = stamp(),
    }
    self.deferred[#self.deferred + 1] = entry
    GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "ADDED")
    return entry
end

function Award:TakeForTrade(id)
    local entry = self:GetDeferredByID(id)
    if not entry then return nil, "Offene Vergabe nicht gefunden." end
    if entry.status ~= "TAKE_SELF_REQUIRED" and entry.status ~= "RETRY_REQUIRED" then return nil, "Vergabe wartet nicht auf Abholung." end
    local player = type(UnitName) == "function" and UnitName("player") or nil
    if not player then return nil, "Eigener Spielername ist nicht verfügbar." end
    local attempt, err = self:BeginGive(entry.result, nil, {
        player = player, slot = entry.lootSlot, mode = "SELF_TRADE", deferredID = entry.id,
    })
    if not attempt then entry.status, entry.reason, entry.updatedAt = "RETRY_REQUIRED", err, stamp(); GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "FAILED"); return nil, err end
    entry.status, entry.updatedAt = "TAKING_SELF", stamp()
    attempt.history = entry.history
    GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "TAKING_SELF")
    return attempt
end

function Award:Confirm(slot)
    slot = tonumber(slot)
    local attempt = slot and self.pending[slot]
    if not attempt then return false end
    self.pending[slot] = nil
    if attempt.mode == "SELF_TRADE" then
        local entry = self:GetDeferredByID(attempt.deferredID)
        if entry then
            entry.status, entry.updatedAt = "TRADE_PENDING", stamp()
            attempt.result.acquiredAt = stamp()
            GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "TAKEN_SELF")
        end
        self:SetDelivery(attempt, "PENDING")
    else
        self:SetDelivery(attempt, "GIVEN")
    end
    if attempt.lootQueueID and GA.Loot then GA.Loot:SetQueueStatus(attempt.lootQueueID, attempt.mode == "SELF_TRADE" and "TRADE_PENDING" or "AWARDED") end
    return true
end

function Award:Timeout(slot, expected)
    local attempt = self.pending[slot]
    if not attempt or attempt ~= expected then return false end
    self.pending[slot] = nil
    if attempt.mode == "SELF_TRADE" then
        local entry = self:GetDeferredByID(attempt.deferredID)
        if entry then entry.status, entry.reason, entry.updatedAt = "RETRY_REQUIRED", "Lootslot-Leerung wurde nicht bestätigt.", stamp(); GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "TIMEOUT") end
    else
        -- GiveMasterLoot was accepted by the client but no slot-clear arrived.
        -- Preserve the established recoverable trade fallback; the bag scan
        -- remains the source of truth and will show MISSING if the server did
        -- in fact deliver directly to the winner.
        self:SetDelivery(attempt, "PENDING")
    end
    return true
end

function Award:OnResult(result, session)
    if type(result) ~= "table" then return end
    local message, attempt = "RECORDED", nil
    local profile, owner = GA.DB:GetProfile(), session and session.owner
    local localName = type(UnitName) == "function" and UnitName("player") or nil
    local isOwner = not owner or sameName(owner, localName)
    local queued = GA.Loot and GA.Loot:FindQueued(result.itemLink, { QUEUED = true, ROLLING = true })
    if queued then result.lootQueueID, result.lootSlot = queued.id, queued.slot end
    if not isOwner then
        message = "REMOTE"
    elseif profile.autoGiveAwards ~= false and result.itemLink and result.winner then
        local err
        attempt, err = self:BeginGive(result, session)
        if attempt then
            message = "GIVING"
        else
            -- If the item is visibly still in this loot window, never create a
            -- misleading bag/trade entry. Without an open loot source this may
            -- be a recovered/already-looted award, so retain the legacy pending
            -- trade fallback and let the bag scan prove whether it exists.
            local inOpenLoot = GA.Loot and GA.Loot.open and GA.Loot:FindSlot(result.itemLink)
            if inOpenLoot then message = "ACTION_REQUIRED"; self:Defer(result, session, err) else message = "PENDING" end
        end
    end
    local record = self:Record(result, session, message)
    if attempt then attempt.history = record end
    if message == "ACTION_REQUIRED" then
        local deferred = self.deferred[#self.deferred]
        if deferred then deferred.history = record end
    end
    GA.Events:Emit("GA_AWARD_RECORDED", result, message)
end

function Award:OnInitialize()
    GA.DB.data.character.award = GA.DB.data.character.award or { deferred = {}, nextID = 0 }
    self.store = GA.DB.data.character.award
    self.deferred = type(self.store.deferred) == "table" and self.store.deferred or {}
    self.nextID = tonumber(self.store.nextID) or 0
    self.store.deferred = self.deferred
    -- TAKING_SELF cannot be proven after a reload; make the user verify/retry.
    for index = 1, #self.deferred do
        if self.deferred[index].status == "TAKING_SELF" then self.deferred[index].status = "RETRY_REQUIRED" end
    end
    GA.Events:On("GA_ROLL_RESULT", function(_, _, result, session) Award:OnResult(result, session) end, self)
    GA.Events:On("LOOT_SLOT_CLEARED", function(_, _, slot) Award:Confirm(slot) end, self)
    GA.Events:RegisterGameEvent("LOOT_SLOT_CLEARED")
    return true
end

function Award:OnSave()
    if self.store then self.store.deferred, self.store.nextID = self.deferred, self.nextID end
end

GA:RegisterModule("Award", Award)
