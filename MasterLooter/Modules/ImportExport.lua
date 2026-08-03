-- Deterministic, non-executable interchange format for MasterLooter data.
local _, GA = ...

local ImportExport = { FORMAT = "MASTERLOOTER_EXPORT", VERSION = 1, MAX_BYTES = 2097152, MAX_LINES = 50000 }
GA.ImportExport = ImportExport

local function encode(value)
    return (string.gsub(tostring(value == nil and "" or value), "([^%w%-%._~ |%[%]:])", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

local function decode(value)
    local result, cursor = {}, 1
    while cursor <= #value do
        local character = string.sub(value, cursor, cursor)
        if character == "%" then
            local hex = string.sub(value, cursor + 1, cursor + 2)
            if #hex ~= 2 or string.find(hex, "[^0-9A-Fa-f]") then return nil, "invalid percent escape" end
            result[#result + 1], cursor = string.char(tonumber(hex, 16)), cursor + 3
        else result[#result + 1], cursor = character, cursor + 1 end
    end
    return table.concat(result)
end

local function split(line)
    local fields = {}
    for field in string.gmatch(line .. "\t", "(.-)\t") do
        local decoded, err = decode(field)
        if not decoded then return nil, err end
        fields[#fields + 1] = decoded
    end
    return fields
end

local function sortedKeys(source, numeric)
    local keys = {}
    for key in pairs(source or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(left, right)
        if numeric then
            local ln, rn = tonumber(left), tonumber(right)
            if ln and rn and ln ~= rn then return ln < rn end
        end
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function addLine(lines, ...)
    local values = { ... }
    for index = 1, #values do values[index] = encode(values[index]) end
    lines[#lines + 1] = table.concat(values, "\t")
end

local function selected(options, key) return not options or options[key] ~= false end

local function csv(value)
    value = tostring(value == nil and "" or value)
    if string.find(value, '[,"\r\n]') then value = '"' .. string.gsub(value, '"', '""') .. '"' end
    return value
end

function ImportExport:Export(options)
    local data, lines = GA.DB.data, { self.FORMAT .. "\t" .. tostring(self.VERSION) }
    if selected(options, "softRes") then
        for _, item in ipairs(sortedKeys(data.softRes.reservations, true)) do
            for _, player in ipairs(sortedKeys(data.softRes.reservations[item])) do
                addLine(lines, "SR", item, player, data.softRes.reservations[item][player])
            end
        end
        for _, item in ipairs(sortedKeys(data.softRes.hardReserved, true)) do
            if data.softRes.hardReserved[item] then addLine(lines, "HR", item, 1) end
        end
    end
    if selected(options, "priority") then
        for _, item in ipairs(sortedKeys(data.priorities, true)) do
            for _, player in ipairs(sortedKeys(data.priorities[item])) do
                addLine(lines, "PR", item, player, data.priorities[item][player])
            end
        end
    end
    if selected(options, "plusOnes") then
        for _, player in ipairs(sortedKeys(data.plusOnes)) do addLine(lines, "P1", player, data.plusOnes[player]) end
    end
    if selected(options, "boosts") then
        for _, player in ipairs(sortedKeys(data.boostedRolls)) do addLine(lines, "BR", player, data.boostedRolls[player]) end
    end
    if selected(options, "awards") then
        for index = 1, #data.history.awards do
            local award = data.history.awards[index]
            addLine(lines, "AW", award.time or 0, award.itemLink or "", award.winner or "", award.choice or "",
                award.roll or 0, award.note or "", award.delivery or "RECORDED")
        end
    end
    if selected(options, "gdkp") then
        for sessionIndex = 1, #data.history.gdkp do
            local session = data.history.gdkp[sessionIndex]
            addLine(lines, "GK", sessionIndex, session.name or "", session.startedAt or 0, session.finishedAt or 0, session.pot or 0)
            for saleIndex = 1, #(session.sales or {}) do
                local sale = session.sales[saleIndex]
                addLine(lines, "GS", sessionIndex, saleIndex, sale.itemLink or "", sale.buyer or "", sale.amount or 0, sale.time or 0)
            end
            for adjustmentIndex = 1, #(session.adjustments or {}) do
                local adjustment = session.adjustments[adjustmentIndex]
                addLine(lines, "GJ", sessionIndex, adjustmentIndex, adjustment.amount or 0,
                    adjustment.reason or "", adjustment.time or 0)
            end
            for _, key in ipairs(sortedKeys(session.players)) do addLine(lines, "GP", sessionIndex, key, session.players[key]) end
        end
    end
    local text = table.concat(lines, "\n")
    GA.Events:Emit("GA_DATA_EXPORTED", #lines - 1, #text)
    return text, #lines - 1
end

function ImportExport:ExportCSV(kind)
    kind = string.lower(tostring(kind or "awards"))
    local lines = {}
    if kind == "awards" then
        lines[1] = "time,item,winner,choice,roll,note,delivery"
        for index = 1, #(GA.DB.data.history.awards or {}) do
            local entry = GA.DB.data.history.awards[index]
            lines[#lines + 1] = table.concat({ csv(entry.time), csv(entry.itemLink), csv(entry.winner),
                csv(entry.choice), csv(entry.roll), csv(entry.note), csv(entry.delivery) }, ",")
        end
    elseif kind == "plusones" then
        lines[1] = "player,plusOne"
        for _, player in ipairs(sortedKeys(GA.DB.data.plusOnes)) do
            lines[#lines + 1] = csv(player) .. "," .. csv(GA.DB.data.plusOnes[player])
        end
    elseif kind == "ledger" then
        lines[1] = "player,total,MS,OS,other,plusOne"
        local players = GA.DB.data.itemLedger and GA.DB.data.itemLedger.players or {}
        for _, player in ipairs(sortedKeys(players)) do
            local stats = GA.PlusOnes and GA.PlusOnes:GetStats(player) or players[player] or {}
            lines[#lines + 1] = table.concat({ csv(player), csv(stats.total), csv(stats.MS), csv(stats.OS),
                csv(stats.OTHER), csv(GA.PlusOnes and GA.PlusOnes:Get(player) or 0) }, ",")
        end
    elseif kind == "priorities" then
        lines[1] = "itemID,player,priority"
        for _, item in ipairs(sortedKeys(GA.DB.data.priorities, true)) do
            for _, player in ipairs(sortedKeys(GA.DB.data.priorities[item])) do
                lines[#lines + 1] = table.concat({ csv(item), csv(player), csv(GA.DB.data.priorities[item][player]) }, ",")
            end
        end
    else return nil, "unknown CSV export kind" end
    return table.concat(lines, "\r\n")
end

function ImportExport:CreateBackup(label)
    local data = GA.DB.data
    data.importBackups = data.importBackups or {}
    local text = self:Export()
    local backup = { time = (time and time()) or 0, label = tostring(label or "Import"), text = text }
    data.importBackups[#data.importBackups + 1] = backup
    while #data.importBackups > 10 do table.remove(data.importBackups, 1) end
    return backup
end

function ImportExport:GetBackups()
    return GA.DB.data.importBackups or {}
end

function ImportExport:RestoreBackup(index)
    local backups = self:GetBackups()
    local backup = backups[tonumber(index) or #backups]
    if not backup then return nil, "unknown backup" end
    return self:Import(backup.text, { strict = true, replace = true, noBackup = true })
end

local function validInteger(value, minimum, maximum)
    local number = tonumber(value)
    return number and number == math.floor(number) and number >= minimum and number <= maximum and number or nil
end

local function validName(value) return type(value) == "string" and #value > 0 and #value <= 64 and not string.find(value, "[%c]") end
local EXPECTED = { SR = 4, HR = 3, PR = 4, P1 = 3, BR = 3, AW = 8, GK = 6, GS = 7, GJ = 6, GP = 4 }

local function validateRecord(fields, sessions)
    local kind = fields[1]
    if not EXPECTED[kind] then return false, "unknown record type" end
    if #fields ~= EXPECTED[kind] then return false, "wrong field count" end
    if kind == "SR" then
        return validInteger(fields[2], 1, 99999999) and validName(fields[3]) and validInteger(fields[4], 1, 100) and true or false,
            "invalid soft-reservation"
    elseif kind == "HR" then
        return validInteger(fields[2], 1, 99999999) and (fields[3] == "0" or fields[3] == "1") and true or false,
            "invalid hard-reservation"
    elseif kind == "PR" then
        return validInteger(fields[2], 1, 99999999) and validName(fields[3]) and validInteger(fields[4], -1000000, 1000000) and true or false,
            "invalid priority"
    elseif kind == "P1" then
        return validName(fields[2]) and validInteger(fields[3], 0, 1000000) and true or false, "invalid plus-one"
    elseif kind == "BR" then
        return validName(fields[2]) and validInteger(fields[3], -100, 100) and true or false, "invalid boost"
    elseif kind == "AW" then
        return validInteger(fields[2], 0, 9999999999) and GA.Compat:GetItemID(fields[3]) and validName(fields[4]) and
            validInteger(fields[6], 0, 100) and #fields[7] <= 1000 and #fields[8] <= 32 and true or false,
            "invalid award"
    elseif kind == "GK" then
        local index = validInteger(fields[2], 1, 100000)
        return index and sessions[index] and #fields[3] <= 200 and validInteger(fields[4], 0, 9999999999) and
            validInteger(fields[5], 0, 9999999999) and validInteger(fields[6], 0, 2147483647) and true or false,
            "invalid GDKP session"
    elseif kind == "GS" then
        local index = validInteger(fields[2], 1, 100000)
        return index and sessions[index] and validInteger(fields[3], 1, 100000) and GA.Compat:GetItemID(fields[4]) and
            validName(fields[5]) and validInteger(fields[6], 0, 2147483647) and validInteger(fields[7], 0, 9999999999) and true or false,
            "invalid GDKP sale"
    elseif kind == "GJ" then
        local index = validInteger(fields[2], 1, 100000)
        return index and sessions[index] and validInteger(fields[3], 1, 100000) and validInteger(fields[4], -2147483647, 2147483647) and
            #fields[5] <= 1000 and validInteger(fields[6], 0, 9999999999) and true or false,
            "invalid GDKP adjustment"
    elseif kind == "GP" then
        local index = validInteger(fields[2], 1, 100000)
        return index and sessions[index] and validName(fields[3]) and validName(fields[4]) and true or false,
            "invalid GDKP player"
    end
end

function ImportExport:Parse(text)
    local report = { imported = 0, rejected = 0, errors = {}, records = {}, byType = {} }
    if type(text) ~= "string" or #text > self.MAX_BYTES then
        report.rejected, report.errors[1] = 1, "Input fehlt oder ist größer als 2 MiB"
        return report
    end
    local lineNumber, headerSeen, sessions = 0, false, {}
    local raw = {}
    local normalized = string.gsub(string.gsub(text, "\r\n", "\n"), "\r", "\n")
    for line in string.gmatch(normalized .. "\n", "([^\n]*)\n") do
        lineNumber = lineNumber + 1
        if lineNumber > self.MAX_LINES then report.rejected = report.rejected + 1; report.errors[#report.errors + 1] = "Zu viele Zeilen"; break end
        if lineNumber == 1 then
            headerSeen = line == self.FORMAT .. "\t" .. tostring(self.VERSION)
            if not headerSeen then report.rejected = 1; report.errors[1] = "Ungültiger Header oder Formatversion"; return report end
        elseif line ~= "" then
            local fields, err = split(line)
            raw[#raw + 1] = { line = lineNumber, fields = fields, error = err }
        end
    end
    if not headerSeen then report.rejected = 1; report.errors[1] = "Leerer Import"; return report end
    -- Establish only structurally valid session parents before checking child records.
    for index = 1, #raw do
        local candidate, fields = raw[index], raw[index].fields
        if fields and fields[1] == "GK" and not candidate.error then
            local sessionIndex = validInteger(fields[2], 1, 100000)
            local provisional = sessionIndex and { [sessionIndex] = true } or {}
            local valid = validateRecord(fields, provisional)
            if not valid then candidate.error = "invalid GDKP session"
            elseif sessions[sessionIndex] then candidate.error = "duplicate GDKP session index"
            else sessions[sessionIndex] = true end
        end
    end
    local childIndexes = { GS = {}, GJ = {} }
    for index = 1, #raw do
        local candidate = raw[index]
        local valid, err
        if candidate.fields and not candidate.error then valid, err = validateRecord(candidate.fields, sessions) end
        if valid and (candidate.fields[1] == "GS" or candidate.fields[1] == "GJ") then
            local kind, sessionIndex, childIndex = candidate.fields[1], tonumber(candidate.fields[2]), tonumber(candidate.fields[3])
            childIndexes[kind][sessionIndex] = childIndexes[kind][sessionIndex] or {}
            if childIndexes[kind][sessionIndex][childIndex] then
                valid, err = false, "duplicate child index"
            else childIndexes[kind][sessionIndex][childIndex] = true end
        end
        if valid then
            report.records[#report.records + 1] = candidate.fields
            report.byType[candidate.fields[1]] = (report.byType[candidate.fields[1]] or 0) + 1
        else
            report.rejected = report.rejected + 1
            if #report.errors < 50 then report.errors[#report.errors + 1] = "Zeile " .. candidate.line .. ": " .. tostring(candidate.error or err) end
        end
    end
    report.accepted = #report.records
    report.valid = report.rejected == 0
    return report
end

function ImportExport:Validate(text)
    local report = self:Parse(text)
    report.records = nil
    return report
end

local function clear(source) for key in pairs(source) do source[key] = nil end end

function ImportExport:Import(text, options)
    local report = self:Parse(text)
    local records = report.records
    if not records or (options and options.strict and report.rejected > 0) then report.records = nil; return report end
    if not (options and options.noBackup) then self:CreateBackup(options and options.replace and "Vor Ersetzen" or "Vor Import") end
    local data = GA.DB.data
    if options and options.replace then
        clear(data.softRes.reservations); clear(data.softRes.hardReserved); clear(data.priorities)
        clear(data.plusOnes); clear(data.boostedRolls); clear(data.history.awards); clear(data.history.gdkp)
    end
    local sessions = {}
    -- Parents are created first, so valid imports do not depend on record ordering.
    for index = 1, #records do
        local fields = records[index]
        if fields[1] == "GK" then
            sessions[tonumber(fields[2])] = { name = fields[3], startedAt = tonumber(fields[4]), finishedAt = tonumber(fields[5]),
                pot = tonumber(fields[6]), sales = {}, adjustments = {}, players = {}, _sales = {}, _adjustments = {} }
        end
    end
    for index = 1, #records do
        local fields, kind = records[index], records[index][1]
        if kind == "SR" then GA.SoftRes:Reserve(fields[3], fields[2], fields[4])
        elseif kind == "HR" then GA.SoftRes:SetHardReserved(fields[2], fields[3] == "1")
        elseif kind == "PR" then GA.Priority:Set(fields[2], fields[3], fields[4])
        elseif kind == "P1" then GA.PlusOnes:Set(fields[2], fields[3])
        elseif kind == "BR" then GA.BoostedRolls:Set(fields[2], fields[3])
        elseif kind == "AW" then
            data.history.awards[#data.history.awards + 1] = { time = tonumber(fields[2]), itemLink = fields[3], winner = fields[4],
                choice = fields[5], roll = tonumber(fields[6]), note = fields[7], delivery = fields[8] }
        elseif kind == "GK" then
            -- Created in the parent pass above.
        elseif kind == "GS" then
            local session = sessions[tonumber(fields[2])]
            session._sales[tonumber(fields[3])] = { itemLink = fields[4], buyer = fields[5], amount = tonumber(fields[6]), time = tonumber(fields[7]) }
        elseif kind == "GJ" then
            local session = sessions[tonumber(fields[2])]
            session._adjustments[tonumber(fields[3])] = { amount = tonumber(fields[4]), reason = fields[5], time = tonumber(fields[6]) }
        elseif kind == "GP" then sessions[tonumber(fields[2])].players[fields[3]] = fields[4] end
        report.imported = report.imported + 1
    end
    for _, index in ipairs(sortedKeys(sessions, true)) do
        local session = sessions[index]
        for _, child in ipairs(sortedKeys(session._sales, true)) do session.sales[#session.sales + 1] = session._sales[child] end
        for _, child in ipairs(sortedKeys(session._adjustments, true)) do session.adjustments[#session.adjustments + 1] = session._adjustments[child] end
        session._sales, session._adjustments = nil, nil
        data.history.gdkp[#data.history.gdkp + 1] = session
    end
    report.records = nil
    GA.Events:Emit("GA_DATA_IMPORTED", report)
    return report
end

function ImportExport:OnInitialize() return true end
GA:RegisterModule("ImportExport", ImportExport)
