local _, GA = ...

local SoftRes = {}
GA.SoftRes = SoftRes

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

function SoftRes:GetReservations(item)
    local id = GA.Compat:GetItemID(item)
    return id and GA.DB.data.softRes.reservations[tostring(id)] or nil
end

function SoftRes:Reserve(player, item, amount)
    local id = GA.Compat:GetItemID(item)
    if not id then return false, "Ungültiges Item" end
    local reservations = GA.DB.data.softRes.reservations
    local bucket = reservations[tostring(id)] or {}
    reservations[tostring(id)] = bucket
    bucket[key(player)] = math.max(1, math.floor(tonumber(amount) or 1))
    GA.Events:Emit("GA_SOFTRES_CHANGED", id, player, bucket[key(player)])
    return true
end

function SoftRes:Remove(player, item)
    local id = GA.Compat:GetItemID(item)
    local bucket = id and self:GetReservations(id)
    if not bucket then return false end
    bucket[key(player)] = nil
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

function SoftRes:Import(text)
    local imported, rejected = 0, 0
    for line in string.gmatch((text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            local player, item, amount = string.match(line, "^%s*([^,;\t]+)%s*[,;\t]%s*(%-?%d+)%s*[,;\t]?%s*(%d*)")
            if player and item and self:Reserve(player, item, tonumber(amount) or 1) then imported = imported + 1 else rejected = rejected + 1 end
        end
    end
    return imported, rejected
end

function SoftRes:OnInitialize() return true end
GA:RegisterModule("SoftRes", SoftRes)
