local _, GA = ...

local Award = { pending = {}, confirmTimeout = 2 }
GA.Award = Award

local function baseName(name)
    return type(name) == "string" and string.match(name, "^[^-]+") or name
end

local function sameName(left, right)
    left, right = baseName(left), baseName(right)
    return left and right and string.lower(left) == string.lower(right)
end

local function itemID(link) return GA.Compat:GetItemID(link) end

function Award:FindLootSlot(link)
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then return nil end
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

function Award:BeginGive(result, session)
    local link, player = result.itemLink or (session and session.itemLink), result.winner
    if type(GiveMasterLoot) ~= "function" then return nil, "Masterloot-API nicht verfügbar" end
    local slot, slotLink = self:FindLootSlot(link)
    if not slot then return nil, "Item ist nicht im geöffneten Lootfenster" end
    local candidate = self:FindCandidate(slot, player)
    if not candidate then return nil, "Spieler ist kein gültiger Loot-Kandidat" end

    local attempt = {
        result = result, session = session, slot = slot, candidate = candidate,
        itemLink = slotLink or link, itemID = itemID(slotLink or link),
        startedAt = type(GetTime) == "function" and GetTime() or 0,
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
        sessionID = result.sessionID,
        itemLink = result.itemLink or (session and session.itemLink),
        winner = result.winner, choice = result.choice, roll = result.roll, note = result.note,
        time = result.awardedAt or (type(time) == "function" and time()) or 0,
        delivery = delivery or "RECORDED",
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
    -- Trade and PackMule consume PENDING here; GIVEN is harmless to them and
    -- refreshes history listeners without adding a second history row.
    GA.Events:Emit("GA_AWARD_RECORDED", attempt.result, delivery)
end

function Award:Confirm(slot)
    slot = tonumber(slot)
    local attempt = slot and self.pending[slot]
    if not attempt then return false end
    self.pending[slot] = nil
    self:SetDelivery(attempt, "GIVEN")
    return true
end

function Award:Timeout(slot, expected)
    local attempt = self.pending[slot]
    if not attempt or attempt ~= expected then return false end
    self.pending[slot] = nil
    self:SetDelivery(attempt, "PENDING")
    return true
end

function Award:OnResult(result, session)
    local message, attempt = "RECORDED", nil
    local profile = GA.DB:GetProfile()
    local owner = session and session.owner
    local localName = type(UnitName) == "function" and UnitName("player") or nil
    local isOwner = not owner or sameName(owner, localName)
    if not isOwner then
        message = "REMOTE"
    elseif profile.autoGiveAwards ~= false and result and result.itemLink and result.winner then
        attempt = self:BeginGive(result, session)
        message = attempt and "GIVING" or "PENDING"
    end
    local record = self:Record(result, session, message)
    if attempt then attempt.history = record end
    GA.Events:Emit("GA_AWARD_RECORDED", result, message)
end

function Award:OnInitialize()
    GA.Events:On("GA_ROLL_RESULT", function(_, _, result, session) Award:OnResult(result, session) end, self)
    GA.Events:On("LOOT_SLOT_CLEARED", function(_, _, slot) Award:Confirm(slot) end, self)
    GA.Events:RegisterGameEvent("LOOT_SLOT_CLEARED")
    return true
end

GA:RegisterModule("Award", Award)
