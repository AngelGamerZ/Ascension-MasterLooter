local _, GA = ...

-- Paste-only adapters for public loot-list formats. Imported text is parsed as
-- data and never passed to loadstring or another executable decoder.
local ExternalImports = { MAX_BYTES = 2097152 }
GA.ExternalImports = ExternalImports

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function utf8(code)
    if code < 128 then return string.char(code) end
    if code < 2048 then return string.char(192 + math.floor(code / 64), 128 + (code % 64)) end
    return string.char(224 + math.floor(code / 4096), 128 + (math.floor(code / 64) % 64), 128 + (code % 64))
end

local function decodeJSON(text)
    local position, length, null = 1, #text, {}
    local parseValue
    local function fail(message) error(message .. " at byte " .. tostring(position), 0) end
    local function skip()
        while position <= length and string.find(" \t\r\n", string.sub(text, position, position), 1, true) do position = position + 1 end
    end
    local function parseString()
        if string.sub(text, position, position) ~= '"' then fail("Expected string") end
        position = position + 1
        local parts, start = {}, position
        while position <= length do
            local character = string.sub(text, position, position)
            if character == '"' then
                parts[#parts + 1] = string.sub(text, start, position - 1); position = position + 1
                return table.concat(parts)
            elseif character == "\\" then
                parts[#parts + 1] = string.sub(text, start, position - 1); position = position + 1
                local escaped = string.sub(text, position, position)
                local replacements = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if replacements[escaped] then parts[#parts + 1] = replacements[escaped]; position = position + 1
                elseif escaped == "u" then
                    local hex = string.sub(text, position + 1, position + 4)
                    local code = tonumber(hex, 16); if not code or #hex ~= 4 then fail("Invalid unicode escape") end
                    parts[#parts + 1] = utf8(code); position = position + 5
                else fail("Invalid escape") end
                start = position
            else
                if string.byte(character) < 32 then fail("Control character in string") end
                position = position + 1
            end
        end
        fail("Unterminated string")
    end
    local function parseArray()
        local result = {}; position = position + 1; skip()
        if string.sub(text, position, position) == "]" then position = position + 1; return result end
        while true do
            result[#result + 1] = parseValue(); skip()
            local character = string.sub(text, position, position); position = position + 1
            if character == "]" then return result end
            if character ~= "," then fail("Expected comma or closing bracket") end
            skip()
        end
    end
    local function parseObject()
        local result = {}; position = position + 1; skip()
        if string.sub(text, position, position) == "}" then position = position + 1; return result end
        while true do
            local key = parseString(); skip()
            if string.sub(text, position, position) ~= ":" then fail("Expected colon") end
            position = position + 1; skip(); result[key] = parseValue(); skip()
            local character = string.sub(text, position, position); position = position + 1
            if character == "}" then return result end
            if character ~= "," then fail("Expected comma or closing brace") end
            skip()
        end
    end
    function parseValue()
        skip(); local character = string.sub(text, position, position)
        if character == '"' then return parseString()
        elseif character == "{" then return parseObject()
        elseif character == "[" then return parseArray()
        elseif string.sub(text, position, position + 3) == "true" then position = position + 4; return true
        elseif string.sub(text, position, position + 4) == "false" then position = position + 5; return false
        elseif string.sub(text, position, position + 3) == "null" then position = position + 4; return null end
        local token = string.match(string.sub(text, position), "^-?%d+%.?%d*[eE]?[+-]?%d*")
        local number = token and tonumber(token)
        if not number then fail("Invalid value") end
        position = position + #token; return number
    end
    local value = parseValue(); skip()
    if position <= length then fail("Trailing data") end
    return value
end

local function decodeBase64(text)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}; for index = 1, #alphabet do values[string.sub(alphabet, index, index)] = index - 1 end
    text = trim(text):gsub("%s", ""):gsub("-", "+"):gsub("_", "/")
    if text == "" or #text % 4 == 1 or string.find(text, "[^%w%+%/%=]") then return nil, "Ungültige Base64-Daten" end
    while #text % 4 ~= 0 do text = text .. "=" end
    local output = {}
    for position = 1, #text, 4 do
        local a, b = values[string.sub(text, position, position)], values[string.sub(text, position + 1, position + 1)]
        local c, d = values[string.sub(text, position + 2, position + 2)], values[string.sub(text, position + 3, position + 3)]
        if a == nil or b == nil then return nil, "Ungültige Base64-Daten" end
        local packed = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        output[#output + 1] = string.char(math.floor(packed / 65536) % 256)
        if c ~= nil then output[#output + 1] = string.char(math.floor(packed / 256) % 256) end
        if d ~= nil then output[#output + 1] = string.char(packed % 256) end
    end
    return table.concat(output)
end

local function parseJSON(text)
    if type(text) ~= "string" or #text == 0 or #text > ExternalImports.MAX_BYTES then return nil, "Import ist leer oder zu groß" end
    local ok, value = pcall(decodeJSON, text)
    if not ok then return nil, "JSON konnte nicht gelesen werden: " .. tostring(value) end
    if type(value) ~= "table" then return nil, "JSON enthält kein Objekt" end
    return value
end

function ExternalImports:DecodeBisBeard(text)
    if type(text) ~= "string" or #text > self.MAX_BYTES then return nil, "BISBEARD-Export ist ungültig oder zu groß" end
    local decoded, decodeError = decodeBase64(text)
    if not decoded then return nil, decodeError end
    local data, jsonError = parseJSON(decoded)
    if not data then return nil, jsonError end
    if type(data.metadata) ~= "table" or data.metadata.origin ~= "raidres" or type(data.softreserves) ~= "table" or type(data.hardreserves) ~= "table" then
        return nil, "Kein unterstützter BISBEARD-RollFor-Export"
    end
    return data
end

function ExternalImports:ValidateBisBeard(text)
    local data, message = self:DecodeBisBeard(text)
    return data ~= nil, data and "BISBEARD-RollFor-Export erkannt." or message
end

function ExternalImports:ImportBisBeard(text)
    local data, message = self:DecodeBisBeard(text)
    if not data then return false, message end
    local imported, rejected = 0, 0
    for _, member in ipairs(data.softreserves) do
        local counts = {}
        for _, item in ipairs(type(member) == "table" and member.items or {}) do
            local id = type(item) == "table" and tonumber(item.id or item.itemId) or tonumber(item)
            if id and id > 0 then counts[id] = (counts[id] or 0) + 1 else rejected = rejected + 1 end
        end
        for id, amount in pairs(counts) do
            if type(member.name) == "string" and member.name ~= "" and GA.SoftRes:Reserve(member.name, id, amount, "BISBEARD") then imported = imported + 1
            else rejected = rejected + 1 end
        end
    end
    for _, item in ipairs(data.hardreserves) do
        local id = type(item) == "table" and tonumber(item.id or item.itemId) or tonumber(item)
        if id and id > 0 and GA.SoftRes:SetHardReserved(id, true) then imported = imported + 1 else rejected = rejected + 1 end
    end
    GA.Events:Emit("GA_EXTERNAL_IMPORT_COMPLETED", "BISBEARD", imported, rejected)
    return imported, rejected
end

local function setPriority(item, player, value)
    item, player, value = tonumber(item), trim(player), tonumber(value)
    return item and item > 0 and player ~= "" and value and GA.Priority:Set(item, player, value)
end

function ExternalImports:ImportRRobin(text)
    local data, message = parseJSON(trim(text))
    if not data then return false, message end
    if type(data.reserves) ~= "table" then return false, "Kein unterstützter RRobin-Export" end
    local imported, rejected = 0, 0
    for _, entry in ipairs(data.reserves) do
        if type(entry) == "table" and setPriority(entry.itemid or entry.itemId, entry.character or entry.player, entry.priority) then imported = imported + 1 else rejected = rejected + 1 end
    end
    return imported, rejected
end

function ExternalImports:ValidateRRobin(text)
    local data, message = parseJSON(trim(text))
    return data and type(data.reserves) == "table", data and "RRobin-Export erkannt." or message
end

function ExternalImports:ImportDFT(text)
    local imported, rejected = 0, 0
    text = tostring(text or ""):gsub('"', "")
    for block in string.gmatch(text .. ";", "([^;]*);") do
        local first, remainder = string.match(block, "^%s*([^\r\n]+)[\r\n]+(.*)$")
        local item = first and tonumber(string.match(first, "(%d+)%s*%^?"))
        local found = 0
        if item and remainder then
            for line in string.gmatch(remainder .. "\n", "([^\r\n]+)[\r\n]") do
                if not string.find(line, "Free Roll", 1, true) then
                    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    local player, priority = string.match(line, "([^|:]+)%s*[|:]%s*(-?%d+%.?%d*)%s*$")
                    player = player and trim(player:gsub("^.-:%s*", ""))
                    if setPriority(item, player, priority) then imported, found = imported + 1, found + 1 else rejected = rejected + 1 end
                end
            end
        end
        if trim(block) ~= "" and found == 0 then rejected = rejected + 1 end
    end
    if imported == 0 then return false, "Kein unterstützter DFT-Export" end
    return imported, rejected
end

function ExternalImports:ValidateDFT(text)
    return string.match(tostring(text or ""), "%d+%^.-[\r\n]") ~= nil,
        string.match(tostring(text or ""), "%d+%^.-[\r\n]") and "DFT-Export erkannt." or "Kein unterstützter DFT-Export"
end

function ExternalImports:ImportClassicPR(text)
    local imported, rejected = 0, 0
    for line in string.gmatch(tostring(text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        line = trim(line)
        if line ~= "" and not string.match(line, "^%a+%s*:") then
            local fields = {}; for field in string.gmatch(line .. ",", "([^,]*),") do fields[#fields + 1] = trim(field) end
            local item = tonumber(fields[1])
            if item and #fields > 1 then
                local order = 1
                for index = 2, #fields do
                    local names, explicit = string.match(fields[index], "^(.-)%[([%d%.]+)%]$")
                    names, order = names or fields[index], tonumber(explicit) or order
                    for player in string.gmatch(names .. "|", "([^|]+)|") do
                        if setPriority(item, player, 100000 - order) then imported = imported + 1 else rejected = rejected + 1 end
                    end
                    order = order + 1
                end
            else rejected = rejected + 1 end
        end
    end
    if imported == 0 then return false, "Kein unterstützter ClassicPR-/CSV-Export" end
    return imported, rejected
end

function ExternalImports:ValidateClassicPR(text)
    local valid = string.match(trim(text), "^%d+%s*,") ~= nil
    return valid, valid and "ClassicPR-/CSV-Export erkannt." or "Kein unterstützter ClassicPR-/CSV-Export"
end

function ExternalImports:ImportLootReserveData(reserves)
    if type(reserves) ~= "table" then return false, "LootReserve-Daten fehlen" end
    local imported, rejected = 0, 0
    for player, items in pairs(reserves) do
        local counts = {}
        if type(items) == "table" then
            for _, item in pairs(items) do
                local value = type(item) == "table" and (item.itemID or item.itemId or item.id or item.link) or item
                local id = GA.Compat:GetItemID(value)
                if id and id > 0 then counts[id] = (counts[id] or 0) + 1 else rejected = rejected + 1 end
            end
        else rejected = rejected + 1 end
        for id, amount in pairs(counts) do
            if GA.SoftRes:Reserve(player, id, amount, "LootReserve") then imported = imported + 1 else rejected = rejected + 1 end
        end
    end
    GA.Events:Emit("GA_EXTERNAL_IMPORT_COMPLETED", "LootReserve", imported, rejected)
    return imported, rejected
end

function ExternalImports:ConnectLootReserve()
    if self.lootReserveConnected then return true end
    local addon = _G.LootReserve
    if type(addon) ~= "table" or type(addon.RegisterListener) ~= "function" then return false end
    local ok, registered = pcall(addon.RegisterListener, addon, "RESERVES", "MasterLooter", function(reserves)
        local success, message = pcall(ExternalImports.ImportLootReserveData, ExternalImports, reserves)
        if not success and GA.ReportError then GA.ReportError("LootReserve import", message) end
    end)
    if not ok or registered == false then
        if GA.ReportError then GA.ReportError("LootReserve connection", registered) end
        return false
    end
    self.lootReserveConnected = true
    if type(addon.PromptListener) == "function" then pcall(addon.PromptListener, addon, "RESERVES", "MasterLooter") end
    return true
end

function ExternalImports:OnInitialize()
    if GA.Events and type(GA.Events.On) == "function" then
        GA.Events:On("ADDON_LOADED", function(_, _, addonName)
            if addonName == "LootReserve" then ExternalImports:ConnectLootReserve() end
        end, self)
    end
    self:ConnectLootReserve()
    return true
end
GA:RegisterModule("ExternalImports", ExternalImports)
