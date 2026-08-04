local _, GA = ...

local Priority = {}
GA.Priority = Priority

local function playerKey(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end

function Priority:Set(item, player, value)
    local id = GA.Compat:GetItemID(item)
    if not id then return false, "Ungültiges Item" end
    local bucket = GA.DB.data.priorities[tostring(id)] or {}
    GA.DB.data.priorities[tostring(id)] = bucket
    bucket[playerKey(player)] = tonumber(value) or 0
    GA.Events:Emit("GA_PRIORITY_CHANGED", id, player, bucket[playerKey(player)])
    return true
end

function Priority:Get(item, player)
    local id = GA.Compat:GetItemID(item)
    local bucket = id and GA.DB.data.priorities[tostring(id)]
    return bucket and tonumber(bucket[playerKey(player)]) or 0
end

function Priority:Reset()
    GA.DB.data.priorities = {}
    GA.Events:Emit("GA_PRIORITY_RESET")
    return true
end

function Priority:Import(text)
    local imported, rejected = 0, 0
    for line in string.gmatch((text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            local item, player, value = string.match(line, "^%s*(%-?%d+)%s*[,;\t]%s*([^,;\t]+)%s*[,;\t]%s*(-?%d+)")
            if item and player and self:Set(item, player, value) then imported = imported + 1 else rejected = rejected + 1 end
        end
    end
    return imported, rejected
end

function Priority:OnInitialize() return true end
GA:RegisterModule("Priority", Priority)
