local _, GA = ...

local SoftRes = {}
GA.SoftRes = SoftRes

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

local function playerIdentity(name)
    local wanted = key(name)
    if wanted == "" or type(UnitName) ~= "function" then return tostring(name or ""), nil, nil end
    local units = { "player" }
    if GA.Compat and type(GA.Compat.IterateGroupUnits) == "function" then
        for unit in GA.Compat:IterateGroupUnits() do units[#units + 1] = unit end
    end
    for _, unit in ipairs(units) do
        local unitName = UnitName(unit)
        if key(unitName) == wanted then
            local className, classFile
            if type(UnitClass) == "function" then className, classFile = UnitClass(unit) end
            return tostring(unitName or name), className, classFile
        end
    end
    return tostring(name or ""), nil, nil
end

local function ensureExtendedStore()
    local store = GA.DB.data.softRes
    store.details = type(store.details) == "table" and store.details or {}
    store.maxPerPlayer = math.max(0, math.floor(tonumber(store.maxPerPlayer) or 0))
    return store
end

function SoftRes:SetLimit(maximum)
    maximum = tonumber(maximum)
    if not maximum or maximum < 0 or maximum > 100 then return false, "Limit muss zwischen 0 und 100 liegen" end
    ensureExtendedStore().maxPerPlayer = math.floor(maximum)
    GA.Events:Emit("GA_SOFTRES_LIMIT_CHANGED", maximum)
    return true
end

function SoftRes:GetPlayerTotal(player)
    local total, playerID = 0, key(player)
    for _, bucket in pairs(GA.DB.data.softRes.reservations or {}) do total = total + (tonumber(bucket[playerID]) or 0) end
    return total
end

function SoftRes:GetReservations(item)
    local id = GA.Compat:GetItemID(item)
    return id and GA.DB.data.softRes.reservations[tostring(id)] or nil
end

function SoftRes:GetAllReservations()
    local store, result = ensureExtendedStore(), {}
    for itemID, bucket in pairs(store.reservations or {}) do
        local id = tonumber(itemID)
        for playerID, amount in pairs(type(bucket) == "table" and bucket or {}) do
            local detail = store.details[itemID] and store.details[itemID][playerID] or {}
            result[#result + 1] = {
                itemID = id, player = detail.player or playerID, amount = tonumber(amount) or 1,
                note = detail.note or "", className = detail.className, classFile = detail.classFile,
            }
        end
    end
    table.sort(result, function(a, b)
        if tostring(a.player) ~= tostring(b.player) then return tostring(a.player) < tostring(b.player) end
        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)
    return result
end

function SoftRes:Reserve(player, item, amount, note)
    local id = GA.Compat:GetItemID(item)
    if not id then return false, "Ungültiges Item" end
    local store, playerID = ensureExtendedStore(), key(player)
    if playerID == "" then return false, "Spielername fehlt" end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local existing = self:GetReservations(id)
    local previous = existing and tonumber(existing[playerID]) or 0
    if store.maxPerPlayer > 0 and self:GetPlayerTotal(player) - previous + amount > store.maxPerPlayer then
        return false, "SoftRes-Limit für diesen Spieler überschritten"
    end
    local reservations = GA.DB.data.softRes.reservations
    local bucket = reservations[tostring(id)] or {}
    reservations[tostring(id)] = bucket
    bucket[playerID] = amount
    store.details[tostring(id)] = store.details[tostring(id)] or {}
    local displayName, className, classFile = playerIdentity(player)
    store.details[tostring(id)][playerID] = {
        player = displayName, className = className, classFile = classFile,
        note = tostring(note or ""):gsub("[%c]", " "):sub(1, 160), updatedAt = (time and time()) or 0,
    }
    GA.Events:Emit("GA_SOFTRES_CHANGED", id, player, bucket[playerID])
    return true
end

function SoftRes:GetEntry(player, item)
    local id, playerID = GA.Compat:GetItemID(item), key(player)
    local bucket = id and self:GetReservations(id)
    local detail = id and ensureExtendedStore().details[tostring(id)] and ensureExtendedStore().details[tostring(id)][playerID] or {}
    return { player = player, itemID = id, amount = tonumber(bucket and bucket[playerID]) or 0, note = detail and detail.note or "" }
end

function SoftRes:Consume(player, item, amount)
    local entry = self:GetEntry(player, item)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if entry.amount < amount then return false, "Nicht genügend SoftRes vorhanden" end
    local remaining = entry.amount - amount
    if remaining == 0 then self:Remove(player, item) else self:Reserve(player, item, remaining, entry.note) end
    GA.Events:Emit("GA_SOFTRES_CONSUMED", entry.itemID, player, amount, remaining)
    return true, remaining
end

function SoftRes:Remove(player, item)
    local id = GA.Compat:GetItemID(item)
    local bucket = id and self:GetReservations(id)
    if not bucket then return false end
    local playerID = key(player)
    bucket[playerID] = nil
    local details = ensureExtendedStore().details[tostring(id)]
    if details then details[playerID] = nil end
    GA.Events:Emit("GA_SOFTRES_CHANGED", id, player, 0)
    return true
end

function SoftRes:IsReserved(player, item)
    local bucket = self:GetReservations(item)
    return bucket and (bucket[key(player)] or 0) > 0 or false
end

function SoftRes:SetHardReserved(item, reserved)
    local id = GA.Compat:GetItemID(item)
    if not id then return false end
    local value = reserved and true or false
    GA.DB.data.softRes.hardReserved[tostring(id)] = value and true or nil
    GA.Events:Emit("GA_HARDRES_CHANGED", id, value)
    return true
end

function SoftRes:IsHardReserved(item)
    local id = GA.Compat:GetItemID(item)
    return id and GA.DB.data.softRes.hardReserved[tostring(id)] and true or false
end

function SoftRes:Reset()
    local store = GA.DB.data.softRes
    store.reservations, store.hardReserved, store.details = {}, {}, {}
    GA.Events:Emit("GA_SOFTRES_RESET")
    GA.Events:Emit("GA_HARDRES_CHANGED", nil, false)
    return true
end

function SoftRes:Import(text)
    text = tostring(text or "")
    -- The dedicated Soft Reserve window is also a valid entry point for the
    -- BISBeard/RollFor share string. Both import screens therefore write to
    -- this module's single reservation store.
    if GA.ExternalImports and type(GA.ExternalImports.ValidateBisBeard) == "function" then
        local valid = GA.ExternalImports:ValidateBisBeard(text)
        if valid then return GA.ExternalImports:ImportBisBeard(text) end
    end
    local imported, rejected = 0, 0
    for line in string.gmatch(text .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            local player, item, amount = string.match(line, "^%s*([^,;\t]+)%s*[,;\t]%s*(%-?%d+)%s*[,;\t]?%s*(%d*)")
            if player and item and self:Reserve(player, item, tonumber(amount) or 1) then imported = imported + 1 else rejected = rejected + 1 end
        end
    end
    return imported, rejected
end

function SoftRes:OnInitialize() ensureExtendedStore(); return true end
GA:RegisterModule("SoftRes", SoftRes)
