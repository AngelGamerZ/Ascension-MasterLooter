-- Persistent dropped-loot lifecycle for the legacy 3.3.5a API.
-- The client cannot expose an authoritative two-hour trade timer or loot
-- recipient for every slot clear. Unproven values are therefore marked as
-- estimated/unknown instead of being presented as server facts.
local _, GA = ...

local LootLedger = { nextID = 0, entries = {}, bySource = {}, MAX_ENTRIES = 5000 }
GA.LootLedger = LootLedger

local function wallTime() return (time and time()) or 0 end
local function playerName() return type(UnitName) == "function" and UnitName("player") or nil end
local function sourceKey(generation, slot) return tostring(generation or "?") .. ":" .. tostring(slot or "?") end
local function lower(value) return string.lower(tostring(value or "")) end

local function instanceContext()
    if type(GetInstanceInfo) ~= "function" then return nil, nil, nil end
    local name, kind, difficulty, difficultyName = GetInstanceInfo()
    return name, kind, difficultyName or difficulty
end

local function targetContext()
    if type(UnitExists) ~= "function" or type(UnitName) ~= "function" or not UnitExists("target") then return nil end
    if type(UnitIsDead) == "function" and not UnitIsDead("target") then return nil end
    return UnitName("target")
end

function LootLedger:NewID()
    self.nextID = (tonumber(self.nextID) or 0) + 1
    return tostring(wallTime()) .. "-ledger-" .. tostring(self.nextID)
end

function LootLedger:Reindex()
    self.bySource = {}
    for _, entry in ipairs(self.entries) do
        if entry.sourceKey then self.bySource[entry.sourceKey] = entry end
    end
end

function LootLedger:Trim()
    while #self.entries > self.MAX_ENTRIES do table.remove(self.entries, 1) end
    self:Reindex()
end

function LootLedger:RecordDrop(record, snapshot)
    if type(record) ~= "table" or not record.link then return nil end
    local key = sourceKey(snapshot and snapshot.generation, record.slot)
    if self.bySource[key] then return self.bySource[key] end
    local instance, instanceType, difficulty = instanceContext()
    local entry = {
        id = self:NewID(), sourceKey = key, generation = snapshot and snapshot.generation, lootSlot = record.slot,
        itemLink = record.link, itemID = record.itemID, quantity = tonumber(record.quantity) or 1,
        status = "DROPPED", droppedAt = wallTime(), updatedAt = wallTime(),
        instance = instance, instanceType = instanceType, difficulty = difficulty,
        boss = targetContext(), contextAccuracy = "BEST_EFFORT_335A",
        statusAccuracy = "OBSERVED_LOOT_WINDOW",
    }
    self.entries[#self.entries + 1] = entry
    self.bySource[key] = entry
    self:Trim()
    GA.Events:Emit("GA_LOOT_LEDGER_CHANGED", entry, "ADDED")
    return entry
end

function LootLedger:FindByResult(result)
    if type(result) ~= "table" then return nil end
    if result.sessionID then
        for index = #self.entries, 1, -1 do
            if self.entries[index].sessionID == result.sessionID then return self.entries[index] end
        end
    end
    if result.lootSlot and GA.Loot then
        local exact = self.bySource[sourceKey(GA.Loot.generation, result.lootSlot)]
        if exact then return exact end
    end
    local wanted = GA.Compat:GetItemID(result.itemLink)
    for index = #self.entries, 1, -1 do
        local entry = self.entries[index]
        if entry.itemID == wanted and entry.status ~= "TRADED" and entry.status ~= "DISENCHANTED" and
            entry.status ~= "LOST" then return entry end
    end
end

function LootLedger:SetStatus(idOrEntry, status, fields, reason)
    local entry = type(idOrEntry) == "table" and idOrEntry or self:Get(idOrEntry)
    if not entry or type(status) ~= "string" or status == "" then return nil, "Unbekannter Ledger-Eintrag." end
    entry.status, entry.updatedAt, entry.reason = status, wallTime(), reason or entry.reason
    for key, value in pairs(type(fields) == "table" and fields or {}) do entry[key] = value end
    GA.Events:Emit("GA_LOOT_LEDGER_CHANGED", entry, status)
    return entry
end

function LootLedger:Get(id)
    for _, entry in ipairs(self.entries) do if entry.id == id then return entry end end
end

function LootLedger:Remove(id)
    for index, entry in ipairs(self.entries) do
        if entry.id == id then
            table.remove(self.entries, index)
            self:Reindex()
            GA.Events:Emit("GA_LOOT_LEDGER_CHANGED", entry, "DELETED")
            return true
        end
    end
    return false
end

function LootLedger:Query(filters)
    filters = filters or {}
    local result, search = {}, lower(filters.search)
    for _, entry in ipairs(self.entries) do
        local matchesStatus = not filters.status or filters.status == "ALL" or entry.status == filters.status
        local haystack = lower(entry.itemLink) .. " " .. lower(entry.winner) .. " " .. lower(entry.instance) .. " " .. lower(entry.boss)
        if matchesStatus and (search == "" or string.find(haystack, search, 1, true)) then result[#result + 1] = entry end
    end
    table.sort(result, function(a, b) return (tonumber(a.droppedAt) or 0) > (tonumber(b.droppedAt) or 0) end)
    return result
end

function LootLedger:Export(filters)
    local lines = { "ID\tZeit\tStatus\tItem\tAnzahl\tSpieler\tBoss\tInstanz\tGenauigkeit\tGrund" }
    for _, entry in ipairs(self:Query(filters)) do
        lines[#lines + 1] = table.concat({
            entry.id or "", tostring(entry.droppedAt or ""), entry.status or "", entry.itemLink or "",
            tostring(entry.quantity or 1), entry.winner or entry.recipient or "", entry.boss or "",
            entry.instance or "", entry.statusAccuracy or "", entry.reason or "",
        }, "\t")
    end
    return table.concat(lines, "\n")
end

function LootLedger:OnLootOpened(snapshot)
    for _, slot in ipairs((snapshot and snapshot.order) or {}) do self:RecordDrop(snapshot.slots[slot], snapshot) end
end

function LootLedger:OnSlotCleared(record, snapshot)
    local entry = self.bySource[sourceKey(snapshot and snapshot.generation, record and record.slot)]
    if entry and entry.status == "DROPPED" then
        self:SetStatus(entry, "ACQUIRED", { recipient = playerName(), acquiredAt = wallTime(), statusAccuracy = "SLOT_CLEAR_RECIPIENT_UNKNOWN" },
            "Lootslot geleert; 3.3.5a meldet den Empfaenger nicht zuverlaessig.")
    end
end

function LootLedger:OnLootClosed(snapshot)
    for _, slot in ipairs((snapshot and snapshot.order) or {}) do
        local entry = self.bySource[sourceKey(snapshot.generation, slot)]
        local record = snapshot.slots and snapshot.slots[slot]
        if entry and entry.status == "DROPPED" and record and not record.cleared then
            self:SetStatus(entry, "LOST", { statusAccuracy = "INFERRED_LOOT_WINDOW_CLOSED" },
                "Lootfenster geschlossen; der serverseitige Ausgang ist unbekannt.")
        end
    end
end

function LootLedger:OnAward(result, delivery)
    local entry = self:FindByResult(result)
    if not entry then return end
    local status = delivery == "GIVEN" and "AWARDED" or (delivery == "PENDING" and "ACQUIRED" or "AWARDED")
    self:SetStatus(entry, status, {
        sessionID = result.sessionID, winner = result.winner, choice = result.choice, roll = result.roll, awardedAt = wallTime(),
        statusAccuracy = delivery == "GIVEN" and "CONFIRMED_SLOT_CLEAR" or "AWARD_RECORDED",
    }, delivery)
end

function LootLedger:OnTradeCompleted(partner, delivered)
    for _, delivery in ipairs(delivered or {}) do
        local entry = self:FindByResult(delivery)
        if entry then self:SetStatus(entry, "TRADED", { winner = partner or delivery.winner, tradedAt = wallTime(), statusAccuracy = "CONFIRMED_TRADE_MESSAGE" }, "Handel bestaetigt") end
    end
end

function LootLedger:OnInitialize()
    GA.DB.data.lootLedger = GA.DB.data.lootLedger or { entries = {}, nextID = 0 }
    self.store = GA.DB.data.lootLedger
    self.entries = type(self.store.entries) == "table" and self.store.entries or {}
    self.nextID = tonumber(self.store.nextID) or 0
    self.store.entries = self.entries
    self:Reindex()
    GA.Events:On("GA_LOOT_OPENED", function(_, _, snapshot) LootLedger:OnLootOpened(snapshot) end, self)
    GA.Events:On("GA_LOOT_SLOT_CLEARED", function(_, _, record, snapshot) LootLedger:OnSlotCleared(record, snapshot) end, self)
    GA.Events:On("GA_LOOT_CLOSED", function(_, _, snapshot) LootLedger:OnLootClosed(snapshot) end, self)
    GA.Events:On("GA_AWARD_RECORDED", function(_, _, result, delivery) LootLedger:OnAward(result, delivery) end, self)
    GA.Events:On("GA_AWARD_DELIVERY_CHANGED", function(_, _, result, delivery) LootLedger:OnAward(result, delivery) end, self)
    GA.Events:On("GA_TRADE_COMPLETED", function(_, _, partner, delivered) LootLedger:OnTradeCompleted(partner, delivered) end, self)
    return true
end

function LootLedger:OnSave()
    if self.store then self.store.entries, self.store.nextID = self.entries, self.nextID end
end

GA:RegisterModule("LootLedger", LootLedger)
