-- Persistent pack-mule ledger. It records intent; it never moves protected items.
local _, GA = ...

local PackMule = { queue = {}, nextID = 0 }
GA.PackMule = PackMule

local VALID_STATUS = {
    PENDING = true, AVAILABLE = true, TRADING = true, DELIVERED = true,
    MISSING = true, CANCELLED = true,
}

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

local function newID(self)
    self.nextID = self.nextID + 1
    return tostring(timestamp()) .. "-" .. tostring(self.nextID)
end

function PackMule:SetTarget(name)
    name = baseName(name)
    if type(name) ~= "string" or name == "" then return false, "target character is required" end
    self.target = name
    if self.store then self.store.target = name end
    GA.Events:Emit("GA_PACKMULE_TARGET_CHANGED", name)
    return true
end

function PackMule:GetTarget()
    return self.target
end

function PackMule:GetRules()
    self.rules = self.rules or { enabled = false, minimumQuality = 2, includeBoE = true, includeBoP = false,
        targets = {}, disenchanters = {}, ignores = {}, roundRobinIndex = 0 }
    self.rules.ignores = type(self.rules.ignores) == "table" and self.rules.ignores or {}
    return self.rules
end

function PackMule:SetIgnored(item, ignored, reason)
    local id = GA.Compat:GetItemID(item)
    if not id then return false, "invalid item" end
    local ignores = self:GetRules().ignores
    ignores[tostring(id)] = ignored and { reason = tostring(reason or "Manuell ignoriert"):gsub("[%c]", " "):sub(1, 120) } or nil
    GA.Events:Emit("GA_PACKMULE_IGNORE_CHANGED", id, ignored and true or false)
    return true
end

function PackMule:IsIgnored(item)
    local id = GA.Compat:GetItemID(item)
    local entry = id and self:GetRules().ignores[tostring(id)]
    return entry and true or false, type(entry) == "table" and entry.reason or nil
end

function PackMule:SetRules(rules)
    if type(rules) ~= "table" then return false, "rules table required" end
    local current = self:GetRules()
    if rules.enabled ~= nil then current.enabled = rules.enabled and true or false end
    if rules.minimumQuality ~= nil then
        local quality = tonumber(rules.minimumQuality)
        if not quality or quality < 0 or quality > 7 then return false, "invalid minimum quality" end
        current.minimumQuality = math.floor(quality)
    end
    if rules.includeBoE ~= nil then current.includeBoE = rules.includeBoE and true or false end
    if rules.includeBoP ~= nil then current.includeBoP = rules.includeBoP and true or false end
    if type(rules.targets) == "table" then current.targets = rules.targets end
    if type(rules.disenchanters) == "table" then current.disenchanters = rules.disenchanters end
    if self.store then self.store.rules = current end
    GA.Events:Emit("GA_PACKMULE_RULES_CHANGED", current)
    return true
end

function PackMule:ChooseTarget(forDisenchant)
    local rules = self:GetRules()
    local targets = forDisenchant and rules.disenchanters or rules.targets
    if type(targets) ~= "table" or #targets == 0 then return self.target end
    rules.roundRobinIndex = ((tonumber(rules.roundRobinIndex) or 0) % #targets) + 1
    return baseName(targets[rules.roundRobinIndex])
end

function PackMule:PreviewItem(itemLink, bindType, forDisenchant)
    local rules = self:GetRules()
    local result = { itemLink = itemLink, bindType = bindType, forDisenchant = forDisenchant and true or false }
    if not rules.enabled or type(itemLink) ~= "string" then result.reasonCode, result.reason = "DISABLED", "Regeln deaktiviert oder Item ungültig"; return result end
    local ignored, ignoreReason = self:IsIgnored(itemLink)
    if ignored then result.reasonCode, result.reason = "IGNORED", ignoreReason or "Item wird ignoriert"; return result end
    local quality
    if type(GetItemInfo) == "function" then local _, _, itemQuality = GetItemInfo(itemLink); quality = itemQuality end
    result.quality = quality
    if quality == nil then result.reasonCode, result.reason = "ITEM_DATA", "Itemdaten noch nicht verfügbar"; return result end
    if quality < (tonumber(rules.minimumQuality) or 2) then result.reasonCode, result.reason = "QUALITY", "Unter Mindestqualität"; return result end
    if bindType == "BOE" and not rules.includeBoE or bindType == "BOP" and not rules.includeBoP then result.reasonCode, result.reason = "BINDING", "Bindungsart ausgeschlossen"; return result end
    local targets = forDisenchant and rules.disenchanters or rules.targets
    local target = self.target
    if type(targets) == "table" and #targets > 0 then
        local nextIndex = ((tonumber(rules.roundRobinIndex) or 0) % #targets) + 1
        target = baseName(targets[nextIndex])
    end
    if not target then result.reasonCode, result.reason = "NO_TARGET", "Kein Ziel konfiguriert"; return result end
    result.accepted, result.target, result.reasonCode, result.reason = true, target, "MATCH", "Regel passt; Ziel: " .. target
    return result
end

function PackMule:EvaluateItem(itemLink, bindType, forDisenchant)
    local preview = self:PreviewItem(itemLink, bindType, forDisenchant)
    if preview.accepted then preview.target = self:ChooseTarget(forDisenchant); preview.reason = "Regel passt; Ziel: " .. tostring(preview.target) end
    return preview.accepted and preview.target or nil, preview.reason, preview
end

function PackMule:Add(itemLink, quantity, source, note)
    if not self.target then return nil, "pack-mule target is not configured" end
    if type(itemLink) ~= "string" or not GA.Compat:GetItemID(itemLink) then
        return nil, "valid item link is required"
    end
    local entry = {
        id = newID(self), itemLink = itemLink, itemID = GA.Compat:GetItemID(itemLink),
        quantity = math.max(1, math.floor(tonumber(quantity) or 1)), target = self.target,
        source = source or "MANUAL", note = tostring(note or ""), status = "PENDING",
        createdAt = timestamp(), updatedAt = timestamp(),
    }
    self.queue[#self.queue + 1] = entry
    GA.Events:Emit("GA_PACKMULE_ITEM_ADDED", entry)
    return entry
end

function PackMule:Get(id)
    for index = 1, #self.queue do
        if self.queue[index].id == id then return self.queue[index], index end
    end
end

function PackMule:SetStatus(id, status, detail)
    if not VALID_STATUS[status] then return false, "invalid status" end
    local entry = self:Get(id)
    if not entry then return false, "unknown queue entry" end
    entry.status, entry.detail, entry.updatedAt = status, detail, timestamp()
    if status == "DELIVERED" then entry.deliveredAt = timestamp() end
    GA.Events:Emit("GA_PACKMULE_ITEM_UPDATED", entry)
    return true, entry
end

function PackMule:Remove(id)
    local entry, index = self:Get(id)
    if not entry then return false end
    table.remove(self.queue, index)
    GA.Events:Emit("GA_PACKMULE_ITEM_REMOVED", entry)
    return true
end

function PackMule:Clear(includeDelivered)
    for index = #self.queue, 1, -1 do
        local entry = self.queue[index]
        if includeDelivered or entry.status == "DELIVERED" or entry.status == "CANCELLED" then
            table.remove(self.queue, index)
        end
    end
    GA.Events:Emit("GA_PACKMULE_QUEUE_CHANGED", self.queue)
end

function PackMule:GetQueue(status)
    if not status then return self.queue end
    local result = {}
    for index = 1, #self.queue do
        if self.queue[index].status == status then result[#result + 1] = self.queue[index] end
    end
    return result
end

function PackMule:RefreshAvailability()
    local remaining = {}
    for index = 1, #self.queue do
        local entry = self.queue[index]
        if entry.status == "PENDING" or entry.status == "AVAILABLE" or entry.status == "MISSING" then
            if remaining[entry.itemID] == nil then
                remaining[entry.itemID] = GA.Compat:GetItemCount(entry.itemID, false)
            end
            local count = remaining[entry.itemID]
            local status = count >= entry.quantity and "AVAILABLE" or "MISSING"
            if entry.status ~= status then self:SetStatus(entry.id, status, "BAG_SCAN") end
            entry.availableCount = count
            if status == "AVAILABLE" then remaining[entry.itemID] = count - entry.quantity end
        end
    end
    return self.queue
end

function PackMule:Export(includeCompleted)
    local lines = { "MasterLooter PackMule", "Target: " .. tostring(self.target or "-") }
    for index = 1, #self.queue do
        local entry = self.queue[index]
        if includeCompleted or (entry.status ~= "DELIVERED" and entry.status ~= "CANCELLED") then
            lines[#lines + 1] = tostring(entry.quantity) .. "x " .. entry.itemLink .. " [" .. entry.status .. "]" ..
                (entry.note ~= "" and (" - " .. entry.note) or "")
        end
    end
    local export = table.concat(lines, "\n")
    GA.Events:Emit("GA_PACKMULE_EXPORTED", export)
    return export
end

function PackMule:QueueAward(result, delivery)
    if delivery ~= "PENDING" or type(result) ~= "table" or not sameName(result.winner, self.target) then return nil end
    for index = 1, #self.queue do
        if result.sessionID and self.queue[index].sessionID == result.sessionID then return self.queue[index] end
    end
    local entry = self:Add(result.itemLink, result.quantity or 1, "AWARD", result.note)
    if entry then entry.sessionID, entry.winner = result.sessionID, result.winner end
    return entry
end

function PackMule:OnTradeCompleted(partner, delivered)
    if not sameName(partner, self.target) or type(delivered) ~= "table" then return end
    local counts = {}
    for index = 1, #delivered do
        local entry = delivered[index]
        counts[entry.itemID] = (counts[entry.itemID] or 0) + (entry.quantity or 1)
    end
    for index = 1, #self.queue do
        local entry = self.queue[index]
        local count = counts[entry.itemID] or 0
        if entry.status ~= "DELIVERED" and count >= entry.quantity then
            self:SetStatus(entry.id, "DELIVERED", "TRADE")
            counts[entry.itemID] = count - entry.quantity
        end
    end
end

function PackMule:OnInitialize()
    GA.DB.data.character.packMule = GA.DB.data.character.packMule or { target = nil, queue = {}, nextID = 0 }
    self.store = GA.DB.data.character.packMule
    self.target = self.store.target
    self.queue = self.store.queue or {}
    self.nextID = tonumber(self.store.nextID) or 0
    self.rules = type(self.store.rules) == "table" and self.store.rules or nil
    self.store.rules = self:GetRules()
    self.store.queue = self.queue
    GA.Events:On("BAG_UPDATE", function() PackMule:RefreshAvailability() end, self)
    GA.Events:On("GA_AWARD_RECORDED", function(_, _, result, delivery)
        PackMule:QueueAward(result, delivery)
    end, self)
    GA.Events:On("GA_TRADE_COMPLETED", function(_, _, partner, delivered)
        PackMule:OnTradeCompleted(partner, delivered)
    end, self)
    GA.Events:RegisterGameEvent("BAG_UPDATE")
    return true
end

function PackMule:OnSave()
    if not self.store then return end
    self.store.target, self.store.queue, self.store.nextID, self.store.rules = self.target, self.queue, self.nextID, self:GetRules()
end

GA:RegisterModule("PackMule", PackMule)
