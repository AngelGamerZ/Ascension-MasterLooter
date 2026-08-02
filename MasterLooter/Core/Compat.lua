local _, ns = ...

local Compat = {}
ns.Compat = Compat

local function callable(value)
    return type(value) == "function"
end

function Compat:IsInRaid()
    if callable(_G.IsInRaid) then
        return _G.IsInRaid() and true or false
    end
    return callable(_G.GetNumRaidMembers) and _G.GetNumRaidMembers() > 0 or false
end

function Compat:IsInGroup()
    if callable(_G.IsInGroup) then
        return _G.IsInGroup() and true or false
    end
    return self:IsInRaid() or (callable(_G.GetNumPartyMembers) and _G.GetNumPartyMembers() > 0) or false
end

function Compat:GetGroupSize()
    if callable(_G.GetNumGroupMembers) then
        local count = _G.GetNumGroupMembers() or 0
        return count > 0 and count or 1
    end
    if self:IsInRaid() then
        return callable(_G.GetNumRaidMembers) and (_G.GetNumRaidMembers() or 0) or 0
    end
    local party = callable(_G.GetNumPartyMembers) and (_G.GetNumPartyMembers() or 0) or 0
    return party > 0 and party + 1 or 1
end

function Compat:GetGroupChannel()
    if self:IsInRaid() then
        return "RAID"
    elseif self:IsInGroup() then
        return "PARTY"
    end
    return nil
end

function Compat:UnitFullName(unit)
    if callable(_G.UnitFullName) then
        local name, realm = _G.UnitFullName(unit)
        if name and realm and realm ~= "" then
            return name .. "-" .. realm
        end
        return name
    end
    return callable(_G.UnitName) and _G.UnitName(unit) or nil
end

function Compat:IterateGroupUnits()
    local index = 0
    local inRaid = self:IsInRaid()
    local count = self:GetGroupSize()
    return function()
        index = index + 1
        if index > count then
            return nil
        end
        if inRaid then
            return "raid" .. index
        end
        return index == 1 and "player" or "party" .. (index - 1)
    end
end

function Compat:GetItemID(item)
    if type(item) == "number" then
        return item
    elseif type(item) ~= "string" then
        return nil
    end
    return tonumber(string.match(item, "item:(%-?%d+)")) or tonumber(item)
end

function Compat:GetItemInfo(item)
    if not callable(_G.GetItemInfo) then
        return nil
    end
    return _G.GetItemInfo(item)
end

function Compat:GetItemIcon(item)
    if callable(_G.GetItemIcon) then
        return _G.GetItemIcon(item)
    end
    if callable(_G.GetItemInfo) then
        local _, _, _, _, _, _, _, _, _, texture = _G.GetItemInfo(item)
        return texture
    end
    return nil
end

function Compat:GetBagCount()
    return _G.NUM_BAG_SLOTS or 4
end

function Compat:GetContainerNumSlots(bag)
    if callable(_G.GetContainerNumSlots) then
        return _G.GetContainerNumSlots(bag) or 0
    end
    if _G.C_Container and callable(_G.C_Container.GetContainerNumSlots) then
        return _G.C_Container.GetContainerNumSlots(bag) or 0
    end
    return 0
end

function Compat:GetContainerItemLink(bag, slot)
    if callable(_G.GetContainerItemLink) then
        return _G.GetContainerItemLink(bag, slot)
    end
    if _G.C_Container and callable(_G.C_Container.GetContainerItemLink) then
        return _G.C_Container.GetContainerItemLink(bag, slot)
    end
    return nil
end

function Compat:GetContainerItemGUID(bag, slot)
    if callable(_G.GetContainerItemGUID) then
        return _G.GetContainerItemGUID(bag, slot)
    end
    if _G.C_Container and callable(_G.C_Container.GetContainerItemGUID) then
        return _G.C_Container.GetContainerItemGUID(bag, slot)
    end
    return nil
end

function Compat:GetItemCount(item, includeBank)
    if callable(_G.GetItemCount) then
        return _G.GetItemCount(item, includeBank) or 0
    end
    local total = 0
    local matches = self:FindItems(item)
    for index = 1, #matches do total = total + (matches[index].count or 1) end
    return total
end

function Compat:PickupContainerItem(bag, slot)
    if callable(_G.PickupContainerItem) then
        return _G.PickupContainerItem(bag, slot)
    end
    if _G.C_Container and callable(_G.C_Container.PickupContainerItem) then
        return _G.C_Container.PickupContainerItem(bag, slot)
    end
end

function Compat:UseContainerItem(bag, slot)
    if callable(_G.UseContainerItem) then
        return _G.UseContainerItem(bag, slot)
    end
    if _G.C_Container and callable(_G.C_Container.UseContainerItem) then
        return _G.C_Container.UseContainerItem(bag, slot)
    end
end

function Compat:GetContainerItemInfo(bag, slot)
    if callable(_G.GetContainerItemInfo) then
        local texture, count, locked, quality, readable, lootable, link = _G.GetContainerItemInfo(bag, slot)
        return {
            icon = texture,
            count = count or 0,
            locked = locked and true or false,
            quality = quality,
            readable = readable and true or false,
            lootable = lootable and true or false,
            link = link or self:GetContainerItemLink(bag, slot),
        }
    end
    if _G.C_Container and callable(_G.C_Container.GetContainerItemInfo) then
        local info = _G.C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return {
                icon = info.iconFileID,
                count = info.stackCount or 0,
                locked = info.isLocked and true or false,
                quality = info.quality,
                readable = info.isReadable and true or false,
                lootable = info.hasLoot and true or false,
                link = info.hyperlink or self:GetContainerItemLink(bag, slot),
            }
        end
    end
    return nil
end

function Compat:FindItems(item)
    local wanted = self:GetItemID(item)
    local matches = {}
    if not wanted then
        return matches
    end
    for bag = 0, self:GetBagCount() do
        for slot = 1, self:GetContainerNumSlots(bag) do
            local link = self:GetContainerItemLink(bag, slot)
            if self:GetItemID(link) == wanted then
                local info = self:GetContainerItemInfo(bag, slot) or {}
                info.bag = bag
                info.slot = slot
                info.link = link
                matches[#matches + 1] = info
            end
        end
    end
    return matches
end

function Compat:RegisterAddonMessagePrefix(prefix)
    if callable(_G.RegisterAddonMessagePrefix) then
        return _G.RegisterAddonMessagePrefix(prefix)
    end
    if _G.C_ChatInfo and callable(_G.C_ChatInfo.RegisterAddonMessagePrefix) then
        return _G.C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    end
    return false
end

function Compat:SendAddonMessage(prefix, message, channel, target)
    if type(message) ~= "string" or string.len(message) > 255 then
        return false, "Addon messages must be strings of at most 255 bytes"
    end
    if callable(_G.SendAddonMessage) then
        _G.SendAddonMessage(prefix, message, channel, target)
        return true
    end
    if _G.C_ChatInfo and callable(_G.C_ChatInfo.SendAddonMessage) then
        _G.C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
        return true
    end
    return false, "Addon message API unavailable"
end

function Compat:GetCapabilities()
    return {
        legacyGroupAPI = callable(_G.GetNumRaidMembers),
        modernGroupAPI = callable(_G.GetNumGroupMembers),
        legacyContainerAPI = callable(_G.GetContainerItemInfo),
        modernContainerAPI = _G.C_Container and callable(_G.C_Container.GetContainerItemInfo) or false,
        legacyAddonMessages = callable(_G.SendAddonMessage),
        modernAddonMessages = _G.C_ChatInfo and callable(_G.C_ChatInfo.SendAddonMessage) or false,
        itemGUID = callable(_G.GetContainerItemGUID),
    }
end

-- 3.3.5a has no C_Timer. A single hidden frame drives every timer and ticker.
local schedulerFrame = CreateFrame("Frame")
local scheduled = {}
local nextTimerID = 0

local function cancel(timer)
    if timer then
        timer.cancelled = true
    end
end

local function onUpdate()
    local now = callable(_G.GetTime) and _G.GetTime() or 0
    -- Walk backwards over the queue as it existed at frame start. A callback
    -- that schedules a zero-delay timer therefore runs on the next frame and
    -- cannot create an unbounded loop in one OnUpdate.
    for index = #scheduled, 1, -1 do
        local timer = scheduled[index]
        if timer.cancelled then
            table.remove(scheduled, index)
        elseif now >= timer.due then
            if timer.interval then
                timer.due = now + timer.interval
                timer.iterations = timer.iterations and timer.iterations - 1 or nil
                if timer.iterations and timer.iterations <= 0 then
                    timer.cancelled = true
                end
                local ok, err = pcall(timer.callback, timer)
                if not ok then ns.ReportError("timer", err) end
                if timer.cancelled then
                    table.remove(scheduled, index)
                end
            else
                table.remove(scheduled, index)
                local ok, err = pcall(timer.callback, timer)
                if not ok then ns.ReportError("timer", err) end
            end
        end
    end
    if #scheduled == 0 then
        schedulerFrame:Hide()
    end
end

schedulerFrame:SetScript("OnUpdate", onUpdate)
schedulerFrame:Hide()

function Compat:Schedule(delay, callback, interval, iterations)
    assert(type(callback) == "function", "Schedule requires a callback")
    delay = math.max(0, tonumber(delay) or 0)
    if interval ~= nil then
        interval = math.max(0.01, tonumber(interval) or delay)
    end
    nextTimerID = nextTimerID + 1
    local now = callable(_G.GetTime) and _G.GetTime() or 0
    local timer = {
        id = nextTimerID,
        due = now + delay,
        callback = callback,
        interval = interval,
        iterations = iterations and math.max(1, tonumber(iterations) or 1) or nil,
        Cancel = cancel,
        IsCancelled = function(self) return self.cancelled and true or false end,
    }
    scheduled[#scheduled + 1] = timer
    schedulerFrame:Show()
    return timer
end

function Compat:After(delay, callback)
    return self:Schedule(delay, callback)
end

function Compat:NewTicker(interval, callback, iterations)
    return self:Schedule(interval, callback, interval, iterations)
end
