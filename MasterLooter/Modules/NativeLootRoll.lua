local _, GA = ...

local NativeLootRoll = { active = {} }
GA.NativeLootRoll = NativeLootRoll

local ROLL_TYPES = { PASS = 0, NEED = 1, GREED = 2, DE = 3 }

local function now() return type(GetTime) == "function" and GetTime() or 0 end
local function enabled(value) return value == true or value == 1 end

local function readRoll(rollID, rollTime)
    if type(GetLootRollItemInfo) ~= "function" then return nil end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant,
        reasonNeed, reasonGreed, reasonDisenchant = GetLootRollItemInfo(rollID)
    local link = type(GetLootRollItemLink) == "function" and GetLootRollItemLink(rollID) or nil
    if not name and not link then return nil end
    local milliseconds = tonumber(rollTime)
    if not milliseconds and type(GetLootRollTimeLeft) == "function" then milliseconds = GetLootRollTimeLeft(rollID) end
    milliseconds = math.max(0, milliseconds or 0)
    local timeout = milliseconds / 1000
    return {
        rollID = tonumber(rollID) or rollID, link = link, itemID = GA.Compat:GetItemID(link),
        texture = texture, name = name, count = math.max(1, tonumber(count) or 1), quality = quality,
        bindOnPickUp = enabled(bindOnPickUp),
        canNeed = enabled(canNeed), canGreed = enabled(canGreed), canDE = enabled(canDisenchant), canPass = true,
        reasonNeed = reasonNeed, reasonGreed = reasonGreed, reasonDE = reasonDisenchant,
        timeout = timeout, startedAt = now(), expiresAt = now() + timeout, status = "ACTIVE",
    }
end

function NativeLootRoll:GetActive()
    local result = {}
    for _, roll in pairs(self.active) do
        if roll.status == "ACTIVE" then result[#result + 1] = roll end
    end
    table.sort(result, function(left, right)
        local leftExpiry, rightExpiry = tonumber(left.expiresAt) or 0, tonumber(right.expiresAt) or 0
        if leftExpiry ~= rightExpiry then return leftExpiry < rightExpiry end
        return tostring(left.rollID) < tostring(right.rollID)
    end)
    return result
end

function NativeLootRoll:OnStart(rollID, rollTime)
    rollID = tonumber(rollID) or rollID
    if rollID == nil then return nil end
    local roll = readRoll(rollID, rollTime)
    if not roll then return nil end
    self.active[rollID] = roll
    if roll.timeout > 0 then
        roll.timer = GA.Compat:After(roll.timeout + 1, function()
            if NativeLootRoll.active[rollID] == roll then NativeLootRoll:End(rollID, "TIMEOUT") end
        end)
    end
    GA.Events:Emit("GA_NATIVE_ROLL_STARTED", roll)
    return roll
end

function NativeLootRoll:End(rollID, reason)
    rollID = tonumber(rollID) or rollID
    local roll = self.active[rollID]
    if not roll then return false end
    self.active[rollID] = nil
    if roll.timer and type(roll.timer.Cancel) == "function" then roll.timer:Cancel() end
    roll.status, roll.endedAt, roll.endReason = "ENDED", now(), reason or "CANCELLED"
    GA.Events:Emit("GA_NATIVE_ROLL_ENDED", roll, roll.endReason)
    return true, roll
end

function NativeLootRoll:Refresh(rollID)
    rollID = tonumber(rollID) or rollID
    local existing = self.active[rollID]
    if not existing then return nil end
    local updated = readRoll(rollID, math.max(0, (existing.expiresAt - now()) * 1000))
    if not updated then return existing end
    existing.link, existing.itemID, existing.texture, existing.name = updated.link, updated.itemID, updated.texture, updated.name
    existing.count, existing.quality = updated.count, updated.quality
    existing.canNeed, existing.canGreed, existing.canDE = updated.canNeed, updated.canGreed, updated.canDE
    existing.reasonNeed, existing.reasonGreed, existing.reasonDE = updated.reasonNeed, updated.reasonGreed, updated.reasonDE
    GA.Events:Emit("GA_NATIVE_ROLL_UPDATED", existing, "REFRESH")
    return existing
end

function NativeLootRoll:Roll(rollID, choice)
    rollID, choice = tonumber(rollID) or rollID, string.upper(tostring(choice or ""))
    local roll, rollType = self.active[rollID], ROLL_TYPES[choice]
    if not roll or roll.status ~= "ACTIVE" then return false, "unknown or inactive loot roll" end
    if roll.selected then return false, "a choice was already submitted" end
    if rollType == nil then return false, "choice must be NEED, GREED, DE, or PASS" end
    if choice == "NEED" and not roll.canNeed then return false, roll.reasonNeed or "need is unavailable" end
    if choice == "GREED" and not roll.canGreed then return false, roll.reasonGreed or "greed is unavailable" end
    if choice == "DE" and not roll.canDE then return false, roll.reasonDE or "disenchant is unavailable" end
    if type(RollOnLoot) ~= "function" then return false, "RollOnLoot is unavailable" end
    local ok, err = pcall(RollOnLoot, rollID, rollType)
    if not ok then return false, tostring(err) end
    roll.selected, roll.rollType, roll.selectedAt = choice, rollType, now()
    GA.Events:Emit("GA_NATIVE_ROLL_UPDATED", roll, "CHOICE")
    return true, roll
end

function NativeLootRoll:OnInitialize()
    GA.Events:On("START_LOOT_ROLL", function(_, _, rollID, rollTime) NativeLootRoll:OnStart(rollID, rollTime) end, self)
    GA.Events:On("CANCEL_LOOT_ROLL", function(_, _, rollID) NativeLootRoll:End(rollID, "CANCELLED") end, self)
    GA.Events:RegisterGameEvent("START_LOOT_ROLL")
    GA.Events:RegisterGameEvent("CANCEL_LOOT_ROLL")
    -- LOOT_HISTORY_ROLL_CHANGED is not a guaranteed 3.3.5a event and is
    -- intentionally not registered. Ascension builds may call Refresh through
    -- an integration layer when they expose a confirmed equivalent.
    return true
end

GA:RegisterModule("NativeLootRoll", NativeLootRoll)
