local _, GA = ...

-- GiveMasterLoot is only invoked from an explicit award/take button. Failed
-- direct awards remain recoverable across reloads instead of pretending the
-- item is already in the loot master's bags.
local Award = { pending = {}, deferred = {}, observedMasterLoot = {}, nextID = 0, confirmTimeout = 2 }
GA.Award = Award

local function stamp() return (time and time()) or 0 end
local function baseName(name)
    if type(name) ~= "string" then return nil end
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.match(name, "^%s*(.-)%s*$") or name
    return string.match(name, "^[^-]+") or name
end
local function sameName(left, right)
    left, right = baseName(left), baseName(right)
    return left and right and string.lower(left) == string.lower(right)
end
local function itemID(link) return GA.Compat:GetItemID(link) end

local function resolveCandidate(slot, candidateIndex)
    candidateIndex = tonumber(candidateIndex)
    if not candidateIndex then return nil end
    if type(GetMasterLootCandidate) == "function" then
        local candidate = GetMasterLootCandidate(candidateIndex)
        if candidate then return candidate end
    end
    local record = GA.Loot and GA.Loot:GetSlot(slot)
    for _, candidate in ipairs((record and record.candidates) or {}) do
        if tonumber(candidate.index) == candidateIndex then return candidate.name end
    end
end

local function findResultQueue(result)
    if not GA.Loot then return nil end
    -- An explicit queue identity belongs to one exact loot slot. If that
    -- record vanished, retain result.lootSlot instead of matching a duplicate
    -- item link from another slot.
    if result.lootQueueID then return GA.Loot:GetQueued(result.lootQueueID) end
    return GA.Loot:FindQueued(result.itemLink, { QUEUED = true, ROLLING = true })
end

function Award:FindLootSlot(link, preferredSlot)
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return nil end
    preferredSlot = tonumber(preferredSlot)
    if preferredSlot then
        local preferredLink = GetLootSlotLink(preferredSlot)
        if preferredLink and itemID(preferredLink) == itemID(link) then return preferredSlot, preferredLink end
        return nil
    end
    local wanted, fallback = itemID(link), nil
    for slot = 1, (GetNumLootItems() or 0) do
        if not self.pending[slot] then
            local slotLink = GetLootSlotLink(slot)
            if slotLink == link then return slot, slotLink end
            if not fallback and itemID(slotLink) == wanted then fallback = slot end
        end
    end
    return fallback, fallback and GetLootSlotLink(fallback) or nil
end

function Award:FindCandidate(slot, player)
    if type(GetMasterLootCandidate) ~= "function" then return nil end
    local wanted = string.lower(baseName(player) or "")
    local seen = {}
    for index = 1, 40 do
        -- Native 3.3.5a signature: GetMasterLootCandidate(candidateIndex).
        -- GiveMasterLoot receives the loot slot separately below.
        local candidate = GetMasterLootCandidate(index)
        if candidate then
            seen[#seen + 1] = tostring(index) .. ":" .. candidate
            if string.lower(baseName(candidate) or "") == wanted then return index, candidate end
        end
    end
    if GA.Trace then GA:Trace("AWARD", "CANDIDATE_NOT_FOUND", slot, player, table.concat(seen, ", ")) end
end

-- Blizzard's own master-loot menu calls the same protected API as the addon.
-- A secure post-hook records that intent without replacing or tainting the
-- native function. LOOT_SLOT_CLEARED remains the server confirmation.
function Award:ObserveMasterLoot(slot, candidateIndex)
    slot = tonumber(slot)
    if not slot or self.invokingGive then return false end
    local winner = resolveCandidate(slot, candidateIndex)
    local record = GA.Loot and GA.Loot:GetSlot(slot)
    local link = (record and record.link) or (type(GetLootSlotLink) == "function" and GetLootSlotLink(slot))
    if not winner or not link then return false end
    local queued
    if GA.Loot and type(GA.Loot.GetQueue) == "function" then
        for _, entry in ipairs(GA.Loot:GetQueue()) do
            if entry.generation == GA.Loot.generation and entry.slot == slot then queued = entry; break end
        end
    end
    self.observedMasterLoot[slot] = {
        slot = slot, candidate = tonumber(candidateIndex), winner = winner,
        itemLink = link, itemID = itemID(link), lootQueueID = queued and queued.id,
        observedAt = (GetTime and GetTime()) or 0,
    }
    if GA.Trace then GA:Trace("AWARD", "NATIVE_MASTER_LOOT_OBSERVED", slot, winner, link) end
    return true
end

local function openDeferred(entry)
    return entry and entry.status ~= "GIVEN" and entry.status ~= "CANCELLED"
end

function Award:FindDeferredForMasterLoot(observation)
    if type(observation) ~= "table" then return nil end
    local best, bestScore
    for _, entry in ipairs(self.deferred) do
        if openDeferred(entry) and sameName(entry.winner, observation.winner) and
            itemID(entry.itemLink) == observation.itemID then
            local score = 0
            if observation.lootQueueID and entry.lootQueueID == observation.lootQueueID then score = score + 100 end
            if tonumber(entry.lootSlot) == tonumber(observation.slot) then score = score + 10 end
            if entry.itemLink == observation.itemLink then score = score + 1 end
            if not best or score > bestScore then best, bestScore = entry, score end
        end
    end
    return best
end

function Award:ReconcileMasterLoot(slot, record)
    slot = tonumber(slot)
    local observation = slot and self.observedMasterLoot[slot]
    if not observation then return false end
    self.observedMasterLoot[slot] = nil
    local current = (GetTime and GetTime()) or 0
    if current > 0 and (tonumber(observation.observedAt) or 0) > 0 and current - observation.observedAt > 10 then
        if GA.Trace then GA:Trace("AWARD", "NATIVE_MASTER_LOOT_EXPIRED", slot, observation.winner) end
        return false
    end
    local clearedID = record and itemID(record.link)
    if clearedID and observation.itemID and clearedID ~= observation.itemID then
        if GA.Trace then GA:Trace("AWARD", "NATIVE_MASTER_LOOT_MISMATCH", slot, observation.itemID, clearedID) end
        return false
    end

    local deferred = self:FindDeferredForMasterLoot(observation)
    if deferred then
        deferred.status, deferred.reason, deferred.updatedAt = "GIVEN", "NATIVE_MASTER_LOOT", stamp()
        if deferred.result then deferred.result.delivery = "GIVEN" end
        if deferred.history then deferred.history.delivery = "GIVEN" end
        if deferred.lootQueueID and GA.Loot then GA.Loot:SetQueueStatus(deferred.lootQueueID, "AWARDED", "NATIVE_MASTER_LOOT") end
        GA.Events:Emit("GA_AWARD_PENDING_CHANGED", deferred, "GIVEN")
        GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", deferred.result, "GIVEN", deferred.history)
    end
    local reconciledTrade
    if GA.Trade and type(GA.Trade.ReconcileMasterLootAward) == "function" then
        reconciledTrade = GA.Trade:ReconcileMasterLootAward(observation)
    end
    if GA.Trace then GA:Trace("AWARD", "NATIVE_MASTER_LOOT_CONFIRMED", slot, observation.winner, observation.itemLink, deferred and deferred.id, reconciledTrade and reconciledTrade.id) end
    return true, observation, deferred, reconciledTrade
end

function Award:BeginGive(result, session, options)
    options = options or {}
    local link, player = result.itemLink or (session and session.itemLink), options.player or result.winner
    if type(GiveMasterLoot) ~= "function" then return nil, "Masterloot-API nicht verfügbar." end
    local preferredSlot = tonumber(options.slot or result.lootSlot)
    if preferredSlot and self.pending[preferredSlot] then
        preferredSlot, result.lootSlot, result.lootQueueID = nil, nil, nil
    end
    local slot, slotLink = self:FindLootSlot(link, preferredSlot)
    if not slot then return nil, "Item ist nicht im geöffneten Lootfenster." end
    result.lootSlot = slot
    if not result.lootQueueID and GA.Loot and type(GA.Loot.QueueSlot) == "function" then
        local queued = GA.Loot:QueueSlot(slot, "MULTI_AWARD")
        if queued then
            result.lootQueueID, result.lootGeneration = queued.id, queued.generation
        end
    end
    local candidate = self:FindCandidate(slot, player)
    if not candidate then return nil, "Spieler ist kein gültiger Loot-Kandidat (meist Entfernung oder Berechtigung)." end
    local attempt = {
        result = result, session = session, slot = slot, candidate = candidate, mode = options.mode or "DIRECT",
        deferredID = options.deferredID, lootQueueID = result.lootQueueID,
        itemLink = slotLink or link, itemID = itemID(slotLink or link), startedAt = (GetTime and GetTime()) or 0,
    }
    self.pending[slot] = attempt
    self.invokingGive = { slot = slot, candidate = candidate }
    local ok, err = pcall(GiveMasterLoot, slot, candidate)
    self.invokingGive = nil
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
        awardIndex = result.awardIndex, awardLimit = result.awardLimit,
        time = result.awardedAt or stamp(), delivery = delivery or "RECORDED",
    }
    history[#history + 1] = record
    while #history > 2000 do table.remove(history, 1) end
    return record
end

function Award:SetDelivery(attempt, delivery)
    if not attempt then return end
    if attempt.result then attempt.result.delivery = delivery end
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

function Award:CancelDeferred(id, reason)
    local entry = self:GetDeferredByID(id)
    if not entry or not openDeferred(entry) then return false, "Offene Vergabe nicht gefunden." end
    entry.status, entry.reason, entry.updatedAt = "CANCELLED", reason or "MANUAL_CANCEL", stamp()
    if entry.result then entry.result.delivery = "CANCELLED" end
    if entry.history then entry.history.delivery = "CANCELLED" end
    if entry.lootQueueID and GA.Loot then GA.Loot:SetQueueStatus(entry.lootQueueID, "CANCELLED", entry.reason) end
    GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "CANCELLED")
    GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", entry.result, "CANCELLED", entry.history)
    return true, entry
end

function Award:CloseMatchingTradeEntry(tradeEntry, delivered, reason)
    if type(tradeEntry) ~= "table" then return false end
    local observation = {
        winner = tradeEntry.winner, itemLink = tradeEntry.itemLink, itemID = itemID(tradeEntry.itemLink),
        lootQueueID = tradeEntry.lootQueueID, slot = tradeEntry.lootSlot,
    }
    local entry = self:FindDeferredForMasterLoot(observation)
    if not entry then return false end
    if delivered then
        entry.status, entry.reason, entry.updatedAt = "GIVEN", reason or "MANUAL_CONFIRMATION", stamp()
        if entry.result then entry.result.delivery = "GIVEN" end
        if entry.history then entry.history.delivery = "GIVEN" end
        if entry.lootQueueID and GA.Loot then GA.Loot:SetQueueStatus(entry.lootQueueID, "AWARDED", entry.reason) end
        GA.Events:Emit("GA_AWARD_PENDING_CHANGED", entry, "GIVEN")
        GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", entry.result, "GIVEN", entry.history)
        return true, entry
    end
    return self:CancelDeferred(entry.id, reason)
end

function Award:ClearDeferred()
    local count = #self.deferred
    for slot, attempt in pairs(self.pending) do
        if attempt and attempt.timer and type(attempt.timer.Cancel) == "function" then attempt.timer:Cancel() end
        self.pending[slot] = nil
    end
    for index = #self.deferred, 1, -1 do self.deferred[index] = nil end
    if self.store then self.store.deferred = self.deferred end
    GA.Events:Emit("GA_AWARD_PENDING_CHANGED", nil, "CLEARED")
    return count
end

function Award:Defer(result, session, reason)
    self.nextID = self.nextID + 1
    local queued = findResultQueue(result)
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
    if attempt.result then attempt.result.lootConfirmed = true end
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
    local message, attempt, confirmedInventory = "RECORDED", nil, false
    local profile, owner = GA.DB:GetProfile(), session and session.owner
    local localName = type(UnitName) == "function" and UnitName("player") or nil
    local isOwner = not owner or sameName(owner, localName)
    local queued = findResultQueue(result)
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
            if inOpenLoot then
                message = "ACTION_REQUIRED"
                local deferred = self:Defer(result, session, err)
                -- Awarding is already an explicit user action. If the winner
                -- is not a valid loot candidate (usually range), immediately
                -- take the exact slot for the loot master and continue through
                -- the confirmed trade fallback without opening another window.
                attempt = self:TakeForTrade(deferred.id)
                if attempt then
                    message = "TAKING_SELF"
                    if GA.Trade and type(GA.Trade.NotifyAwardFallback) == "function" then
                        GA.Trade:NotifyAwardFallback(result)
                    end
                end
            elseif sameName(result.winner, localName) and GA.Compat and type(GA.Compat.FindItems) == "function" and
                #(GA.Compat:FindItems(result.itemLink) or {}) > 0 then
                -- Inventory items can be rolled after they were looted. The
                -- local winner already owns this item; never queue a trade to self.
                message, confirmedInventory = "GIVEN", true
            elseif sameName(result.winner, localName) then
                message = "MISSING"
            else
                message = "PENDING"
            end
        end
    end
    local record = self:Record(result, session, message)
    if attempt then attempt.history = record end
    if message == "ACTION_REQUIRED" or message == "TAKING_SELF" then
        local deferred = self.deferred[#self.deferred]
        if deferred then deferred.history = record end
    end
    if confirmedInventory then GA.Events:Emit("GA_AWARD_DELIVERY_CHANGED", result, "GIVEN", record) end
    GA.Events:Emit("GA_AWARD_RECORDED", result, message)
end

function Award:OnInitialize()
    GA.DB.data.character.award = GA.DB.data.character.award or { deferred = {}, nextID = 0 }
    self.store = GA.DB.data.character.award
    self.deferred = type(self.store.deferred) == "table" and self.store.deferred or {}
    self.nextID = tonumber(self.store.nextID) or 0
    self.store.deferred = self.deferred
    self.observedMasterLoot = {}
    -- TAKING_SELF cannot be proven after a reload; make the user verify/retry.
    for index = 1, #self.deferred do
        if self.deferred[index].status == "TAKING_SELF" then self.deferred[index].status = "RETRY_REQUIRED" end
    end
    GA.Events:On("GA_ROLL_RESULT", function(_, _, result, session) Award:OnResult(result, session) end, self)
    GA.Events:On("GA_LOOT_SLOT_CLEARED", function(_, _, record) Award:ReconcileMasterLoot(record and record.slot, record) end, self)
    GA.Events:On("LOOT_SLOT_CLEARED", function(_, _, slot) Award:Confirm(slot) end, self)
    GA.Events:RegisterGameEvent("LOOT_SLOT_CLEARED")
    if not self.masterLootHooked and type(hooksecurefunc) == "function" and type(GiveMasterLoot) == "function" then
        hooksecurefunc("GiveMasterLoot", function(slot, candidateIndex) Award:ObserveMasterLoot(slot, candidateIndex) end)
        self.masterLootHooked = true
    end
    return true
end

function Award:OnSave()
    if self.store then self.store.deferred, self.store.nextID = self.deferred, self.nextID end
end

GA:RegisterModule("Award", Award)
