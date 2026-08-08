-- Legacy loot-window model for WoW 3.3.5a.
local _, GA = ...

local Loot = { slots = {}, order = {}, history = {}, queue = {}, open = false, generation = 0, nextQueueID = 0 }
GA.Loot = Loot

local function now()
    return (GetTime and GetTime()) or 0
end

local function copyArray(source)
    local result = {}
    for index = 1, #source do result[index] = source[index] end
    return result
end

local function readCandidates()
    local candidates = {}
    if type(GetMasterLootCandidate) ~= "function" then return candidates end
    for index = 1, 40 do
        -- Blizzard 3.3.5a exposes GetMasterLootCandidate(candidateIndex).
        -- The loot slot is passed later to GiveMasterLoot, not to this query.
        local name = GetMasterLootCandidate(index)
        -- 3.3.5a candidate indices can contain gaps (for example raid slots
        -- that are not eligible for this item). A nil entry therefore does
        -- not mean that every following candidate is absent.
        if name then candidates[#candidates + 1] = { index = index, name = name } end
    end
    return candidates
end

local function readSlot(slot)
    if type(GetLootSlotInfo) ~= "function" then return nil end
    local texture, name, quantity, quality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
    local link = type(GetLootSlotLink) == "function" and GetLootSlotLink(slot) or nil
    local hasItem = type(LootSlotHasItem) ~= "function" or LootSlotHasItem(slot)
    if not name and not link and not hasItem then return nil end
    return {
        slot = slot,
        link = link,
        itemID = GA.Compat:GetItemID(link),
        name = name,
        texture = texture,
        quantity = tonumber(quantity) or 1,
        quality = quality,
        locked = locked and true or false,
        isQuestItem = isQuestItem and true or false,
        questID = questID,
        isActive = isActive and true or false,
        candidates = readCandidates(),
        capturedAt = now(),
        cleared = false,
    }
end

function Loot:GetSnapshot()
    return {
        open = self.open,
        generation = self.generation,
        openedAt = self.openedAt,
        closedAt = self.closedAt,
        autoLoot = self.autoLoot,
        slots = self.slots,
        order = copyArray(self.order),
    }
end

function Loot:GetSlot(slot)
    return self.slots[tonumber(slot)]
end

local function queueID(self)
    self.nextQueueID = (tonumber(self.nextQueueID) or 0) + 1
    return tostring((time and time()) or 0) .. "-loot-" .. tostring(self.nextQueueID)
end

function Loot:GetQueue(includeClosed)
    if includeClosed then return self.queue end
    local result = {}
    for index = 1, #self.queue do
        local entry = self.queue[index]
        if entry.status ~= "AWARDED" and entry.status ~= "CANCELLED" and entry.status ~= "REMOVED" then result[#result + 1] = entry end
    end
    return result
end

function Loot:GetQueued(id)
    for index = 1, #self.queue do
        if self.queue[index].id == id then return self.queue[index], index end
    end
end

function Loot:QueueSlot(slot, source)
    local record = type(slot) == "table" and slot or self:GetSlot(slot)
    if not record or record.cleared or not record.link then return nil, "Lootslot ist nicht verfügbar." end
    local reusable = { QUEUED = true, ROLLING = true, AWAITING_AWARD = true, TAKING_SELF = true }
    for index = 1, #self.queue do
        local existing = self.queue[index]
        if existing.generation == self.generation and existing.slot == record.slot and existing.itemID == record.itemID and reusable[existing.status] then
            return existing
        end
    end
    local entry = {
        id = queueID(self), generation = self.generation, slot = record.slot,
        itemLink = record.link, itemID = record.itemID, quantity = record.quantity or 1,
        status = "QUEUED", source = source or "LOOT_WINDOW", createdAt = (time and time()) or 0,
    }
    self.queue[#self.queue + 1] = entry
    GA.Events:Emit("GA_LOOT_QUEUE_CHANGED", entry, "ADDED")
    return entry
end

function Loot:FindQueued(item, statuses)
    local wanted = GA.Compat:GetItemID(item)
    for index = 1, #self.queue do
        local entry = self.queue[index]
        local allowed = not statuses or statuses[entry.status]
        if allowed and entry.itemID == wanted then return entry end
    end
end

function Loot:SetQueueStatus(id, status, reason)
    local entry = self:GetQueued(id)
    if not entry then return nil, "Unbekannter Warteschlangeneintrag." end
    entry.status, entry.reason, entry.updatedAt = status, reason, (time and time()) or 0
    GA.Events:Emit("GA_LOOT_QUEUE_CHANGED", entry, status)
    return entry
end

function Loot:FindSlot(item)
    local wanted = GA.Compat:GetItemID(item)
    if not wanted then return nil end
    for index = 1, #self.order do
        local record = self.slots[self.order[index]]
        if record and not record.cleared and record.itemID == wanted then return record end
    end
end

function Loot:Refresh(reason, silent)
    if type(GetNumLootItems) ~= "function" then return self:GetSnapshot() end
    local count = GetNumLootItems() or 0
    local newOrder, newSlots = {}, {}
    for slot = 1, count do
        local record = readSlot(slot)
        if record then
            -- A cleared slot number may immediately be reused when the client
            -- compacts the remaining loot. A currently readable native slot
            -- is always live, even if this numeric position was just cleared.
            newSlots[slot] = record
            newOrder[#newOrder + 1] = slot
        end
    end
    self.slots, self.order = newSlots, newOrder
    local snapshot = self:GetSnapshot()
    if not silent then GA.Events:Emit("GA_LOOT_UPDATED", snapshot, reason or "REFRESH") end
    return snapshot
end

function Loot:OnLootOpened(autoLoot)
    self.generation = self.generation + 1
    if self.store then self.store.generation = self.generation end
    self.slots, self.order = {}, {}
    self.open, self.openedAt, self.closedAt = true, now(), nil
    self.autoLoot = autoLoot and true or false
    self:Refresh("OPEN", true)
    local snapshot = self:GetSnapshot()
    GA.Events:Emit("GA_LOOT_OPENED", snapshot)
end

function Loot:OnSlotCleared(slot)
    slot = tonumber(slot)
    if not slot then return end
    local record = self.slots[slot] or { slot = slot, capturedAt = now() }
    record.cleared, record.clearedAt = true, now()
    self.slots[slot] = record
    self.history[#self.history + 1] = record
    while #self.history > 100 do table.remove(self.history, 1) end
    for index = 1, #self.queue do
        local entry = self.queue[index]
        if entry.generation == self.generation and entry.slot == slot and entry.status == "QUEUED" then
            entry.status, entry.updatedAt = "REMOVED", (time and time()) or 0
        end
    end
    local snapshot = self:GetSnapshot()
    GA.Events:Emit("GA_LOOT_SLOT_CLEARED", record, snapshot)
    GA.Events:Emit("GA_LOOT_UPDATED", snapshot, "SLOT_CLEARED", record)
    -- Ascension clients can compact equal drops onto the cleared numeric slot.
    -- Refresh on following frames so the next copy receives a fresh queue ID.
    if GA.Compat and type(GA.Compat.After) == "function" then
        local generation = self.generation
        local refresh = function()
            if Loot.open and Loot.generation == generation then Loot:Refresh("POST_SLOT_CLEAR") end
        end
        GA.Compat:After(0, refresh)
        GA.Compat:After(0.15, refresh)
    end
end

function Loot:OnLootClosed()
    if not self.open then return end
    self.open, self.closedAt = false, now()
    GA.Events:Emit("GA_LOOT_CLOSED", self:GetSnapshot())
end

function Loot:OnInitialize()
    GA.DB.data.character.loot = GA.DB.data.character.loot or { queue = {}, nextQueueID = 0, generation = 0 }
    self.store = GA.DB.data.character.loot
    self.queue = type(self.store.queue) == "table" and self.store.queue or {}
    self.nextQueueID = tonumber(self.store.nextQueueID) or 0
    self.generation = tonumber(self.store.generation) or 0
    self.store.queue = self.queue
    GA.Events:On("LOOT_OPENED", function(_, _, autoLoot) Loot:OnLootOpened(autoLoot) end, self)
    GA.Events:On("LOOT_SLOT_CLEARED", function(_, _, slot) Loot:OnSlotCleared(slot) end, self)
    GA.Events:On("LOOT_CLOSED", function() Loot:OnLootClosed() end, self)
    GA.Events:RegisterGameEvent("LOOT_OPENED")
    GA.Events:RegisterGameEvent("LOOT_SLOT_CLEARED")
    GA.Events:RegisterGameEvent("LOOT_CLOSED")
    return true
end

function Loot:OnSave()
    if self.store then self.store.queue, self.store.nextQueueID, self.store.generation = self.queue, self.nextQueueID, self.generation end
end

GA:RegisterModule("Loot", Loot)
