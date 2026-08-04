local _, GA = ...

local GDKP = { active = nil }
GA.GDKP = GDKP

local function timestamp() return type(time) == "function" and time() or 0 end
local function trim(value) return string.match(tostring(value or ""), "^%s*(.-)%s*$") end
local function validPlayer(player)
    return type(player) == "string" and player ~= "" and #player <= 64 and not string.find(player, "[%c]")
end
local function persist(self) if self.store then self.store.active = self.active end end
local function playerKey(player) return string.lower(string.match(tostring(player or ""), "^[^-]+") or "") end
local function integer(value, minimum, maximum)
    value = tonumber(value)
    return value and value == math.floor(value) and value >= minimum and value <= maximum and value or nil
end
local function ensureAdvanced(active)
    active.ledger = type(active.ledger) == "table" and active.ledger or {}
    active.transactions = type(active.transactions) == "table" and active.transactions or {}
    active.priceList = type(active.priceList) == "table" and active.priceList or {}
    active.managementCut = type(active.managementCut) == "table" and active.managementCut or { percent = 0, fixed = 0 }
    active.mutators = type(active.mutators) == "table" and active.mutators or {}
    active.notes = type(active.notes) == "table" and active.notes or {}
    active.nextLedgerID = tonumber(active.nextLedgerID) or 1
end
local function addLedger(active, kind, amount, data)
    ensureAdvanced(active)
    local row = { id = active.nextLedgerID, kind = kind, amount = amount or 0, time = timestamp() }
    active.nextLedgerID = active.nextLedgerID + 1
    for key, value in pairs(data or {}) do row[key] = value end
    active.ledger[#active.ledger + 1] = row
    return row
end

function GDKP:Start(name)
    if self.active then return nil, "Es läuft bereits eine GDKP-Sitzung" end
    if name ~= nil then
        name = trim(name)
        if name == "" or #name > 100 or string.find(name, "[%c]") then return nil, "Ungültiger Sitzungsname" end
    end
    self.active = {
        name = name or (type(date) == "function" and date("%Y-%m-%d") or "GDKP"),
        startedAt = timestamp(), pot = 0, sales = {}, adjustments = {}, players = {},
        cutWeights = {}, payments = {},
    }
    ensureAdvanced(self.active)
    persist(self)
    GA.Events:Emit("GA_GDKP_STARTED", self.active)
    return self.active
end

function GDKP:AddPlayer(player)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    player = type(player) == "string" and trim(player) or player
    if not validPlayer(player) then return false, "Ungültiger Spielername" end
    self.active.players[playerKey(player)] = player
    persist(self)
    return true
end

function GDKP:RemovePlayer(player)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    local normalized = playerKey(player)
    if not self.active.players[normalized] then return false, "Spieler ist nicht in der Sitzung" end
    self.active.players[normalized], self.active.cutWeights[normalized], self.active.payments[normalized] = nil, nil, nil
    persist(self); GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active); return true
end

function GDKP:SetCutWeight(player, weight)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    player = type(player) == "string" and trim(player) or player
    if not validPlayer(player) then return false, "Ungültiger Spielername" end
    weight = tonumber(weight)
    if not weight or weight < 0 or weight > 100 then return false, "Cut-Gewicht muss zwischen 0 und 100 liegen" end
    self:AddPlayer(player)
    self.active.cutWeights[playerKey(player)] = weight
    persist(self)
    GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active)
    return true
end

function GDKP:GetDistribution()
    return self:CalculateCuts()
end

function GDKP:SetPaymentStatus(player, status)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    status = string.upper(tostring(status or ""))
    if status ~= "OPEN" and status ~= "PAID" and status ~= "HELD" then return false, "Ungültiger Zahlungsstatus" end
    local normalized = playerKey(player)
    if not self.active.players[normalized] then return false, "Spieler ist nicht in der Sitzung" end
    self.active.payments[normalized] = status
    persist(self)
    GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active)
    return true
end

function GDKP:AddSale(itemLink, buyer, amount)
    if not self.active then return nil, "Keine aktive GDKP-Sitzung" end
    local id = type(itemLink) == "string" and GA.Compat:GetItemID(itemLink) or nil
    if not id or id <= 0 then return nil, "Ungültiges Item" end
    buyer = type(buyer) == "string" and trim(buyer) or buyer
    if not validPlayer(buyer) then return nil, "Ungültiger Käufer" end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount <= 0 or amount > 2147483647 then
        return nil, "Betrag muss eine positive ganze Zahl sein"
    end
    local sale = { itemLink = itemLink, buyer = buyer, amount = amount, time = timestamp() }
    self.active.sales[#self.active.sales + 1] = sale
    self.active.pot = self.active.pot + amount
    self:AddPlayer(buyer)
    sale.ledgerID = addLedger(self.active, "SALE", amount, { itemLink = itemLink, player = buyer }).id
    persist(self)
    GA.Events:Emit("GA_GDKP_SALE", sale, self.active)
    return sale
end

function GDKP:EditSale(index, buyer, amount)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    index, buyer, amount = integer(index, 1, #self.active.sales), trim(buyer), integer(amount, 1, 2147483647)
    if not index or not validPlayer(buyer) or not amount then return false, "Ungültige Verkaufsänderung" end
    local sale = self.active.sales[index]; local difference = amount - sale.amount
    sale.buyer, sale.amount, sale.editedAt = buyer, amount, timestamp(); self.active.pot = math.max(0, self.active.pot + difference)
    self:AddPlayer(buyer); ensureAdvanced(self.active)
    for _, row in ipairs(self.active.ledger) do if row.id == sale.ledgerID then row.player, row.amount, row.editedAt = buyer, amount, timestamp(); break end end
    persist(self); GA.Events:Emit("GA_GDKP_SALE", sale, self.active); return true
end

function GDKP:RemoveSale(index)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    index = integer(index, 1, #self.active.sales); if not index then return false, "Verkauf nicht gefunden" end
    local sale = table.remove(self.active.sales, index); self.active.pot = math.max(0, self.active.pot - sale.amount)
    if sale.ledgerID then for ledgerIndex, row in ipairs(self.active.ledger) do if row.id == sale.ledgerID then table.remove(self.active.ledger, ledgerIndex); break end end end
    persist(self); GA.Events:Emit("GA_GDKP_LEDGER_CHANGED", self.active); return true
end

function GDKP:Adjust(amount, reason)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount < -2147483647 or amount > 2147483647 then
        return false, "Ungültiger Anpassungsbetrag"
    end
    reason = tostring(reason or "")
    if #reason > 500 or string.find(reason, "[%c]") then return false, "Ungültiger Grund" end
    self.active.adjustments[#self.active.adjustments + 1] = { amount = amount, reason = reason, time = timestamp() }
    self.active.pot = math.max(0, self.active.pot + amount)
    addLedger(self.active, "ADJUSTMENT", amount, { reason = reason })
    persist(self)
    return true
end

function GDKP:SetManagementCut(percent, fixed)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    percent, fixed = tonumber(percent), integer(fixed or 0, 0, 2147483647)
    if not percent or percent < 0 or percent > 100 or not fixed then return false, "Management-Cut ist ungültig" end
    ensureAdvanced(self.active)
    self.active.managementCut = { percent = percent, fixed = fixed }
    persist(self); GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active); return true
end

function GDKP:SetMutator(name, percent)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    name, percent = trim(name), tonumber(percent)
    if name == "" or #name > 64 or string.find(name, "[%c]") or not percent or percent < -100 or percent > 1000 then
        return false, "Ungültiger Mutator"
    end
    ensureAdvanced(self.active); self.active.mutators[name] = percent
    persist(self); GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active); return true
end

function GDKP:RemoveMutator(name)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    ensureAdvanced(self.active); self.active.mutators[tostring(name or "")] = nil
    persist(self); GA.Events:Emit("GA_GDKP_DISTRIBUTION_CHANGED", self.active); return true
end

function GDKP:AddTransaction(player, amount, kind, note)
    if not self.active then return nil, "Keine aktive GDKP-Sitzung" end
    player, amount, kind, note = trim(player), integer(amount, -2147483647, 2147483647), string.upper(trim(kind)), trim(note)
    if not validPlayer(player) or not amount or (kind ~= "IN" and kind ~= "OUT") or #note > 256 or string.find(note, "[%c]") then
        return nil, "Ungültige Goldtransaktion"
    end
    self:AddPlayer(player); ensureAdvanced(self.active)
    local signed = kind == "IN" and math.abs(amount) or -math.abs(amount)
    local row = { player = player, amount = signed, kind = kind, note = note, time = timestamp() }
    self.active.transactions[#self.active.transactions + 1] = row
    row.ledgerID = addLedger(self.active, "GOLD_" .. kind, signed, { player = player, note = note }).id
    persist(self); GA.Events:Emit("GA_GDKP_LEDGER_CHANGED", self.active); return row
end

function GDKP:EditLedger(id, changes)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    id = tonumber(id); changes = type(changes) == "table" and changes or {}
    ensureAdvanced(self.active)
    for _, row in ipairs(self.active.ledger) do
        if row.id == id then
            if changes.note ~= nil then
                local note = trim(changes.note); if #note > 256 or string.find(note, "[%c]") then return false, "Ungültige Notiz" end
                row.note = note
            end
            if changes.player ~= nil then if not validPlayer(trim(changes.player)) then return false, "Ungültiger Spieler" end; row.player = trim(changes.player) end
            row.editedAt = timestamp(); persist(self); GA.Events:Emit("GA_GDKP_LEDGER_CHANGED", self.active); return true
        end
    end
    return false, "Ledger-Eintrag nicht gefunden"
end

function GDKP:DeleteLedger(id)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    ensureAdvanced(self.active); id = tonumber(id)
    for index, row in ipairs(self.active.ledger) do
        if row.id == id then table.remove(self.active.ledger, index); persist(self); GA.Events:Emit("GA_GDKP_LEDGER_CHANGED", self.active); return true end
    end
    return false, "Ledger-Eintrag nicht gefunden"
end

function GDKP:SetPrice(item, minimum, increment)
    if not self.active then return false, "Keine aktive GDKP-Sitzung" end
    local itemID = GA.Compat:GetItemID(item); minimum, increment = integer(minimum, 0, 2147483647), integer(increment or 1, 1, 2147483647)
    if not itemID or not minimum or not increment then return false, "Ungültiger Preislisteneintrag" end
    ensureAdvanced(self.active); self.active.priceList[tostring(itemID)] = { minimum = minimum, increment = increment, itemLink = item }
    persist(self); return true
end

function GDKP:GetPrice(item)
    if not self.active then return nil end
    ensureAdvanced(self.active); local itemID = GA.Compat:GetItemID(item)
    return itemID and self.active.priceList[tostring(itemID)] or nil
end

function GDKP:CalculateCuts()
    if not self.active then return {} end
    ensureAdvanced(self.active)
    local cut = self.active.managementCut
    local management = math.min(self.active.pot, math.floor(self.active.pot * (cut.percent or 0) / 100) + (cut.fixed or 0))
    local distributable, totalWeight, result = self.active.pot - management, 0, {}
    for key in pairs(self.active.players) do totalWeight = totalWeight + (tonumber(self.active.cutWeights[key]) or 1) end
    local multiplier = 1
    for _, percent in pairs(self.active.mutators) do multiplier = multiplier * (1 + percent / 100) end
    distributable = math.max(0, math.floor(distributable * multiplier))
    for key, player in pairs(self.active.players) do
        local weight = tonumber(self.active.cutWeights[key]) or 1
        result[#result + 1] = { player = player, weight = weight, amount = totalWeight > 0 and math.floor(distributable * weight / totalWeight) or 0, status = self.active.payments[key] or "OPEN" }
    end
    table.sort(result, function(a, b) return playerKey(a.player) < playerKey(b.player) end)
    return result, management, distributable
end

function GDKP:BuildCutWhispers()
    local cuts = self:CalculateCuts(); local messages = {}
    for _, row in ipairs(cuts) do
        messages[#messages + 1] = { player = row.player, text = "MasterLooter GDKP: Dein Cut beträgt " .. tostring(row.amount) .. "g (Status: " .. tostring(row.status) .. ")." }
    end
    return messages
end

local function escape(value) return (tostring(value or ""):gsub("%%", "%%25"):gsub("\t", "%%09"):gsub("\n", "%%0A")) end
local function unescape(value) return (tostring(value or ""):gsub("%%0A", "\n"):gsub("%%09", "\t"):gsub("%%25", "%%")) end
function GDKP:Export()
    if not self.active then return nil, "Keine aktive GDKP-Sitzung" end
    ensureAdvanced(self.active); local lines = { "MLGDKP\t1\t" .. escape(self.active.name) }
    for key, player in pairs(self.active.players) do lines[#lines + 1] = table.concat({ "P", escape(player), tostring(self.active.cutWeights[key] or 1), self.active.payments[key] or "OPEN" }, "\t") end
    for itemID, price in pairs(self.active.priceList) do lines[#lines + 1] = table.concat({ "R", itemID, price.minimum, price.increment, escape(price.itemLink) }, "\t") end
    for _, sale in ipairs(self.active.sales) do lines[#lines + 1] = table.concat({ "S", escape(sale.itemLink), escape(sale.buyer), sale.amount }, "\t") end
    return table.concat(lines, "\n")
end

function GDKP:Import(text, replace)
    if type(text) ~= "string" or #text > 1048576 then return false, "Import ist ungültig oder zu groß" end
    local rows = {}; for line in string.gmatch(text, "[^\r\n]+") do local fields = {}; for field in string.gmatch(line .. "\t", "([^\t]*)\t") do fields[#fields + 1] = field end; rows[#rows + 1] = fields end
    if not rows[1] or rows[1][1] ~= "MLGDKP" or rows[1][2] ~= "1" then return false, "Unbekanntes GDKP-Format" end
    if replace and self.active then self.active = nil end
    if not self.active then local started, err = self:Start(unescape(rows[1][3])); if not started then return false, err end end
    for index = 2, #rows do local f = rows[index]
        if f[1] == "P" then local ok, err = self:AddPlayer(unescape(f[2])); if not ok then return false, err end; self:SetCutWeight(unescape(f[2]), tonumber(f[3]) or 1); self:SetPaymentStatus(unescape(f[2]), f[4] or "OPEN")
        elseif f[1] == "R" then local ok, err = self:SetPrice(unescape(f[5]), tonumber(f[3]), tonumber(f[4])); if not ok then return false, err end
        elseif f[1] == "S" then local sale, err = self:AddSale(unescape(f[2]), unescape(f[3]), tonumber(f[4])); if not sale then return false, err end end
    end
    persist(self); return true
end

function GDKP:GetCut(count)
    if not self.active then return 0 end
    if count == nil then
        count = 0
        for _ in pairs(self.active.players) do count = count + 1 end
    end
    count = tonumber(count) or 0
    return count > 0 and math.floor(self.active.pot / count) or 0
end

function GDKP:Finish()
    if not self.active then return nil end
    local finished = self.active
    finished.finishedAt = timestamp()
    GA.DB.data.history.gdkp[#GA.DB.data.history.gdkp + 1] = finished
    self.active = nil
    persist(self)
    GA.Events:Emit("GA_GDKP_FINISHED", finished)
    return finished
end

function GDKP:Reset(clearHistory)
    self.active = nil
    persist(self)
    if clearHistory and GA.DB.data.history and type(GA.DB.data.history.gdkp) == "table" then
        for index = #GA.DB.data.history.gdkp, 1, -1 do table.remove(GA.DB.data.history.gdkp, index) end
    end
    GA.Events:Emit("GA_GDKP_RESET", clearHistory and true or false)
    return true
end

function GDKP:OnInitialize()
    GA.DB.data.character.gdkp = GA.DB.data.character.gdkp or { active = nil }
    self.store = GA.DB.data.character.gdkp
    self.active = type(self.store.active) == "table" and self.store.active or nil
    if self.active then
        ensureAdvanced(self.active)
        self.active.sales = type(self.active.sales) == "table" and self.active.sales or {}
        self.active.adjustments = type(self.active.adjustments) == "table" and self.active.adjustments or {}
        self.active.players = type(self.active.players) == "table" and self.active.players or {}
        self.active.cutWeights = type(self.active.cutWeights) == "table" and self.active.cutWeights or {}
        self.active.payments = type(self.active.payments) == "table" and self.active.payments or {}
        self.active.pot = math.max(0, tonumber(self.active.pot) or 0)
    end
    persist(self)
    return true
end

function GDKP:OnSave() persist(self) end

GA:RegisterModule("GDKP", GDKP)
