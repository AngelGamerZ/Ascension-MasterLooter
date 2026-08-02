-- Legacy loot-window model for WoW 3.3.5a.
local _, GA = ...

local Loot = { slots = {}, order = {}, history = {}, open = false, generation = 0 }
GA.Loot = Loot

local function now()
    return (GetTime and GetTime()) or 0
end

local function copyArray(source)
    local result = {}
    for index = 1, #source do result[index] = source[index] end
    return result
end

local function readCandidates(slot)
    local candidates = {}
    if type(GetMasterLootCandidate) ~= "function" then return candidates end
    for index = 1, 40 do
        local name = GetMasterLootCandidate(slot, index)
        if not name then break end
        candidates[#candidates + 1] = { index = index, name = name }
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
        candidates = readCandidates(slot),
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
    local newOrder = {}
    for slot = 1, count do
        local record = readSlot(slot)
        if record then
            local previous = self.slots[slot]
            if previous and previous.cleared then record.cleared = true end
            self.slots[slot] = record
            newOrder[#newOrder + 1] = slot
        end
    end
    self.order = newOrder
    local snapshot = self:GetSnapshot()
    if not silent then GA.Events:Emit("GA_LOOT_UPDATED", snapshot, reason or "REFRESH") end
    return snapshot
end

function Loot:OnLootOpened(autoLoot)
    self.generation = self.generation + 1
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
    local snapshot = self:GetSnapshot()
    GA.Events:Emit("GA_LOOT_SLOT_CLEARED", record, snapshot)
    GA.Events:Emit("GA_LOOT_UPDATED", snapshot, "SLOT_CLEARED", record)
end

function Loot:OnLootClosed()
    if not self.open then return end
    self.open, self.closedAt = false, now()
    GA.Events:Emit("GA_LOOT_CLOSED", self:GetSnapshot())
end

function Loot:OnInitialize()
    GA.Events:On("LOOT_OPENED", function(_, _, autoLoot) Loot:OnLootOpened(autoLoot) end, self)
    GA.Events:On("LOOT_SLOT_CLEARED", function(_, _, slot) Loot:OnSlotCleared(slot) end, self)
    GA.Events:On("LOOT_CLOSED", function() Loot:OnLootClosed() end, self)
    GA.Events:RegisterGameEvent("LOOT_OPENED")
    GA.Events:RegisterGameEvent("LOOT_SLOT_CLEARED")
    GA.Events:RegisterGameEvent("LOOT_CLOSED")
    return true
end

GA:RegisterModule("Loot", Loot)
