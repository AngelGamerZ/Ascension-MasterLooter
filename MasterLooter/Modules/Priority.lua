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

function Priority:GetDisplay(item, player)
    local value = self:Get(item, player)
    if value > 0 then return "+" .. tostring(value), "Priorität vor Gleichstand" end
    if value < 0 then return tostring(value), "Nachrangige Priorität" end
    return "0", "Keine besondere Priorität"
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

-- TMB paste compatibility: accepts common tab/comma exports with columns such
-- as Character/Player, Item/ItemId and Priority/Prio. Item links are accepted.
function Priority:ImportTMB(text)
    local imported, rejected, columns = 0, 0, nil
    local function normalized(value) return string.lower(tostring(value or "")):gsub("[^%w]", "") end
    for line in string.gmatch((text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            local fields = {}
            local separator = string.find(line, "\t", 1, true) and "\t" or ","
            local pattern = separator == "\t" and "([^\t]*)\t?" or "([^,]*),?"
            for value in string.gmatch(line .. separator, pattern) do fields[#fields + 1] = value end
            if not columns then
                local found = {}
                for index, value in ipairs(fields) do
                    local header = normalized(value)
                    if header == "character" or header == "player" or header == "name" then found.player = index
                    elseif header == "item" or header == "itemid" or header == "wowheadid" then found.item = index
                    elseif header == "priority" or header == "prio" or header == "order" then found.priority = index
                    elseif header == "note" or header == "reason" then found.note = index end
                end
                if found.player and found.item then columns = found
                else columns = { player = 1, item = 2, priority = 3 }; -- first row is data
                    local id = GA.Compat:GetItemID(fields[columns.item])
                    if id and fields[columns.player] and self:Set(id, fields[columns.player], tonumber(fields[columns.priority]) or 0) then
                        imported = imported + 1
                    else rejected = rejected + 1 end
                end
            else
                local id, player = GA.Compat:GetItemID(fields[columns.item]), fields[columns.player]
                local value = tonumber(fields[columns.priority]) or 0
                if id and player and player ~= "" and self:Set(id, player, value) then imported = imported + 1 else rejected = rejected + 1 end
            end
        end
    end
    return imported, rejected
end

function Priority:ExportTMB()
    local lines = { "Character\tItemId\tPriority\tNote" }
    local items = {}
    for item in pairs(GA.DB.data.priorities or {}) do items[#items + 1] = item end
    table.sort(items, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for _, item in ipairs(items) do
        local players = {}
        for player in pairs(GA.DB.data.priorities[item] or {}) do players[#players + 1] = player end
        table.sort(players)
        for _, player in ipairs(players) do
            lines[#lines + 1] = table.concat({ player, item, GA.DB.data.priorities[item][player], "MasterLooter" }, "\t")
        end
    end
    return table.concat(lines, "\n")
end

function Priority:OnInitialize() return true end
GA:RegisterModule("Priority", Priority)
