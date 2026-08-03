local _, GA = ...

-- +1 is a ranking rule.  The item ledger below is deliberately separate: it
-- records what a player actually received without silently changing ranking.
local PlusOnes = {}
GA.PlusOnes = PlusOnes

local function key(name) return string.lower(string.match(tostring(name or ""), "^[^-]+") or "") end
local function now() return (type(time) == "function" and time()) or 0 end

local function ensureStore()
    local data = GA.DB.data
    data.plusOnes = type(data.plusOnes) == "table" and data.plusOnes or {}
    data.itemLedger = type(data.itemLedger) == "table" and data.itemLedger or {}
    local store = data.itemLedger
    store.players = type(store.players) == "table" and store.players or {}
    store.processed = type(store.processed) == "table" and store.processed or {}
    store.history = type(store.history) == "table" and store.history or {}
    return store
end

local function appendHistory(action, player, amount, reason, sessionID, choice, itemLink)
    local history = ensureStore().history
    history[#history + 1] = {
        time = now(), action = action, player = player, amount = tonumber(amount) or 0,
        reason = reason, sessionID = sessionID, choice = choice, itemLink = itemLink,
    }
    while #history > 2000 do table.remove(history, 1) end
end

function PlusOnes:Get(player) return tonumber(ensureStore() and GA.DB.data.plusOnes[key(player)]) or 0 end

function PlusOnes:Set(player, value, reason)
    local playerID = key(player)
    if playerID == "" then return nil, "Spielername fehlt" end
    local old = self:Get(player)
    value = math.max(0, math.floor(tonumber(value) or 0))
    GA.DB.data.plusOnes[playerID] = value ~= 0 and value or nil
    if reason and value ~= old then appendHistory("PLUSONE_SET", player, value - old, reason) end
    GA.Events:Emit("GA_PLUSONE_CHANGED", player, value, old, reason)
    return value
end

function PlusOnes:Add(player, amount, reason)
    amount = math.floor(tonumber(amount) or 1)
    return self:Set(player, self:Get(player) + amount, reason or "MANUAL")
end

function PlusOnes:ResetPlayer(player, reason)
    return self:Set(player, 0, reason or "MANUAL_RESET")
end

function PlusOnes:Reset(reason)
    local old = GA.DB.data.plusOnes or {}
    for player, value in pairs(old) do
        if tonumber(value) and tonumber(value) ~= 0 then appendHistory("PLUSONE_RESET", player, -tonumber(value), reason or "MANUAL_RESET_ALL") end
    end
    wipe(old)
    GA.Events:Emit("GA_PLUSONE_RESET", reason)
end

function PlusOnes:GetStats(player)
    local stats = ensureStore().players[key(player)] or {}
    return { total = tonumber(stats.total) or 0, MS = tonumber(stats.MS) or 0, OS = tonumber(stats.OS) or 0, OTHER = tonumber(stats.OTHER) or 0 }
end

function PlusOnes:GetLedgerHistory() return ensureStore().history end

function PlusOnes:GetAutoRules()
    local profile = GA.DB:GetProfile()
    return { MS = profile.autoPlusOneMS ~= false, OS = profile.autoPlusOneOS == true, OTHER = profile.autoPlusOneOther == true }
end

function PlusOnes:SetAutoRule(choice, enabled)
    choice = string.upper(tostring(choice or ""))
    if choice ~= "MS" and choice ~= "OS" and choice ~= "OTHER" then return false, "Unbekannte Vergabeart" end
    GA.DB:GetProfile()["autoPlusOne" .. (choice == "OTHER" and "Other" or choice)] = enabled and true or false
    GA.Events:Emit("GA_LEDGER_RULE_CHANGED", choice, enabled and true or false)
    return true
end

function PlusOnes:RecordConfirmed(result, identity, reason)
    if type(result) ~= "table" or key(result.winner) == "" then return false, "Ungültige Vergabe" end
    identity = tostring(identity or result.sessionID or "")
    if identity == "" then return false, "Vergabe-ID fehlt" end
    local store = ensureStore()
    if store.processed[identity] then return false, "Bereits verbucht" end

    local choice = string.upper(tostring(result.choice or "OTHER"))
    if choice ~= "MS" and choice ~= "OS" then choice = "OTHER" end
    local playerID = key(result.winner)
    local stats = store.players[playerID] or { total = 0, MS = 0, OS = 0, OTHER = 0 }
    store.players[playerID] = stats
    stats.total = (tonumber(stats.total) or 0) + 1
    stats[choice] = (tonumber(stats[choice]) or 0) + 1
    store.processed[identity] = { player = playerID, time = now(), choice = choice, itemLink = result.itemLink }
    appendHistory("ITEM_AWARDED", result.winner, 1, reason or "CONFIRMED", identity, choice, result.itemLink)

    local rules = self:GetAutoRules()
    if rules[choice] then self:Add(result.winner, 1, "AUTO_" .. choice) end
    GA.Events:Emit("GA_ITEM_LEDGER_CHANGED", result.winner, self:GetStats(result.winner), identity, choice)
    return true
end

function PlusOnes:ResetStats(player, reason)
    local store, playerID = ensureStore(), key(player)
    if playerID == "" then return false end
    local before = self:GetStats(player)
    store.players[playerID] = nil
    appendHistory("ITEM_STATS_RESET", player, -before.total, reason or "MANUAL_RESET")
    GA.Events:Emit("GA_ITEM_LEDGER_CHANGED", player, self:GetStats(player), nil, "RESET")
    return true
end

function PlusOnes:ExportLedger()
    local lines = { "Spieler\tGesamt\tMS\tOS\tSonstige\tPlus1" }
    local players = {}
    for player in pairs(ensureStore().players) do players[#players + 1] = player end
    table.sort(players)
    for _, player in ipairs(players) do
        local stats = self:GetStats(player)
        lines[#lines + 1] = table.concat({ player, stats.total, stats.MS, stats.OS, stats.OTHER, self:Get(player) }, "\t")
    end
    return table.concat(lines, "\n")
end

function PlusOnes:Compare(a, b)
    local av, bv = self:Get(a), self:Get(b)
    if av ~= bv then return av < bv end
    return string.lower(a) < string.lower(b)
end

function PlusOnes:OnInitialize()
    ensureStore()
    GA.Events:On("GA_AWARD_DELIVERY_CHANGED", function(_, _, result, delivery)
        if delivery == "GIVEN" then PlusOnes:RecordConfirmed(result, result and result.sessionID, "DIRECT_LOOT") end
    end, self)
    GA.Events:On("GA_TRADE_PENDING_UPDATED", function(_, _, entry)
        if type(entry) == "table" and entry.status == "DELIVERED" and entry.id then
            PlusOnes:RecordConfirmed(entry, "trade:" .. tostring(entry.id), "CONFIRMED_TRADE")
        end
    end, self)
    return true
end
GA:RegisterModule("PlusOnes", PlusOnes)
