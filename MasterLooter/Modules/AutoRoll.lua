-- Declarative roll recommendations. This module never rolls or clicks protected
-- UI by itself; it only explains which button a player may choose.
local _, GA = ...

local AutoRoll = { MAX_RULES = 500 }
GA.AutoRoll = AutoRoll

local VALID_CHOICE = { MS = true, OS = true, TRANSMOG = true, PASS = true }
local VALID_MODE = { EXACT = true, FAMILY = true, NAME = true }

local function clean(value, maximum)
    value = tostring(value or ""):gsub("[%c]", " ")
    return string.sub(value, 1, maximum or 160)
end

local function normalize(value)
    value = tostring(value or ""):lower()
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return value
end

local function itemID(value)
    if value == "*" or value == nil or value == "" then return 0 end
    return GA.Compat:GetItemID(value)
end

local function itemNameFromLink(value)
    return type(value) == "string" and value:match("%[([^%]]+)%]") or nil
end

local function copyIdentity(source)
    source = type(source) == "table" and source or {}
    return {
        name = clean(source.name, 160),
        normalizedName = normalize(source.normalizedName ~= "" and source.normalizedName or source.name),
        itemType = clean(source.itemType or source.className, 80),
        itemSubType = clean(source.itemSubType or source.subclassName, 80),
        equipLoc = clean(source.equipLoc or source.inventoryType, 80),
        icon = clean(source.icon, 200),
        familyID = tonumber(source.familyID),
        difficulty = tonumber(source.difficulty) or clean(source.difficulty, 40),
    }
end

local function cachedItemData(method, fallbackMethod, ...)
    if not GA.ItemData then return nil end
    local callback = type(GA.ItemData[method]) == "function" and GA.ItemData[method] or
        (type(GA.ItemData[fallbackMethod]) == "function" and GA.ItemData[fallbackMethod] or nil)
    if not callback then return nil end
    local ok, result = pcall(callback, GA.ItemData, ...)
    if ok then return result end
    if GA.Trace then GA:Trace("AUTOROLL", "ITEMDATA_CACHE_ERROR", method, result) end
    return nil
end

function AutoRoll:ResolveIdentity(item, context)
    context = type(context) == "table" and context or {}
    local id = itemID(item)
    local supplied = context.identity or context.itemIdentity or context
    local identity = copyIdentity({
        name = supplied.itemName or supplied.name or itemNameFromLink(item),
        normalizedName = supplied.normalizedName,
        itemType = supplied.itemType or supplied.className,
        itemSubType = supplied.itemSubType or supplied.subclassName,
        equipLoc = supplied.equipLoc or supplied.inventoryType,
        icon = supplied.icon or supplied.texture,
        familyID = supplied.familyID,
        difficulty = supplied.difficulty,
    })
    local entry = id and cachedItemData("Peek", "Get", id) or nil
    if type(entry) == "table" then
        local stored = copyIdentity(entry)
        for key, value in pairs(stored) do
            if identity[key] == nil or identity[key] == "" then identity[key] = value end
        end
    end
    if id and type(GetItemInfo) == "function" then
        local ok, name, link, _, _, _, itemTypeName, itemSubTypeName, _, equipLoc, icon = pcall(GetItemInfo, item or id)
        if ok then
            identity.name = identity.name ~= "" and identity.name or clean(name or itemNameFromLink(link), 160)
            identity.itemType = identity.itemType ~= "" and identity.itemType or clean(itemTypeName, 80)
            identity.itemSubType = identity.itemSubType ~= "" and identity.itemSubType or clean(itemSubTypeName, 80)
            identity.equipLoc = identity.equipLoc ~= "" and identity.equipLoc or clean(equipLoc, 80)
            identity.icon = identity.icon ~= "" and identity.icon or clean(icon, 200)
        elseif GA.Trace then
            GA:Trace("AUTOROLL", "GET_ITEM_INFO_ERROR", id, name)
        end
    end
    identity.normalizedName = normalize(identity.name ~= "" and identity.name or identity.normalizedName)
    return id, identity
end

local function mergeIdentity(target, source)
    target = type(target) == "table" and target or {}
    source = type(source) == "table" and source or {}
    for _, key in ipairs({ "name", "normalizedName", "itemType", "itemSubType", "equipLoc", "icon", "familyID", "difficulty" }) do
        if (target[key] == nil or target[key] == "") and source[key] ~= nil and source[key] ~= "" then target[key] = source[key] end
    end
    return target
end

local function sameKnownField(left, right, key)
    local a, b = normalize(left[key]), normalize(right[key])
    if a == "" or b == "" then return nil end
    return a == b
end

-- Learned families require the same name plus at least two stable matching
-- characteristics. A plain name match is reserved for explicit NAME rules.
local function safeFingerprintMatch(left, right)
    if normalize(left.normalizedName or left.name) == "" or
        normalize(left.normalizedName or left.name) ~= normalize(right.normalizedName or right.name) then return false end
    local comparable = 0
    for _, key in ipairs({ "itemType", "equipLoc", "icon" }) do
        local same = sameKnownField(left, right, key)
        if same == false then return false end
        if same == true then comparable = comparable + 1 end
    end
    return comparable >= 2
end

function AutoRoll:GetStore()
    GA.DB.data.autoRoll = type(GA.DB.data.autoRoll) == "table" and GA.DB.data.autoRoll or { nextID = 0, rules = {} }
    local store = GA.DB.data.autoRoll
    store.rules = type(store.rules) == "table" and store.rules or {}
    store.learnedVariants = type(store.learnedVariants) == "table" and store.learnedVariants or {}
    if store.enabled == nil then store.enabled = true end
    store.defaultDelay = math.max(0, math.min(10, tonumber(store.defaultDelay) or 3))
    return store
end

function AutoRoll:IsEnabled() return self:GetStore().enabled ~= false end
function AutoRoll:SetEnabled(enabled)
    self:GetStore().enabled = enabled and true or false
    if GA.Events and type(GA.Events.Emit) == "function" then GA.Events:Emit("GA_AUTOROLL_CHANGED", nil, "SETTING") end
    return true
end
function AutoRoll:GetDefaultDelay() return self:GetStore().defaultDelay end
function AutoRoll:SetDefaultDelay(delay)
    delay = tonumber(delay)
    if not delay or delay < 0 or delay > 10 then return false, "Die Verzögerung muss zwischen 0 und 10 Sekunden liegen" end
    self:GetStore().defaultDelay = delay
    if GA.Events and type(GA.Events.Emit) == "function" then GA.Events:Emit("GA_AUTOROLL_CHANGED", nil, "SETTING") end
    return true
end
function AutoRoll:SetRuleEnabled(id, enabled)
    for _, rule in ipairs(self:GetRules()) do
        if tonumber(rule.id) == tonumber(id) then
            rule.enabled = enabled and true or false
            if GA.Events and type(GA.Events.Emit) == "function" then GA.Events:Emit("GA_AUTOROLL_CHANGED", rule, "UPDATED") end
            return true
        end
    end
    return false
end

function AutoRoll:MigrateRule(rule)
    if type(rule) ~= "table" then return rule end
    rule.itemID = tonumber(rule.itemID) or 0
    rule.matchMode = string.upper(tostring(rule.matchMode or rule.mode or ""))
    if not VALID_MODE[rule.matchMode] then rule.matchMode = "EXACT" end
    rule.identity = mergeIdentity(type(rule.identity) == "table" and rule.identity or {}, {
        name = rule.itemName, normalizedName = rule.normalizedName, itemType = rule.itemType,
        itemSubType = rule.itemSubType, equipLoc = rule.equipLoc, icon = rule.icon,
        familyID = rule.familyID, difficulty = rule.difficulty,
    })
    if rule.identity.normalizedName == nil or rule.identity.normalizedName == "" then rule.identity.normalizedName = normalize(rule.identity.name) end
    rule.priority = math.max(-9999, math.min(9999, math.floor(tonumber(rule.priority) or 0)))
    rule.delay = math.max(0, math.min(10, tonumber(rule.delay) or self:GetDefaultDelay()))
    rule.player, rule.class = clean(rule.player, 64):lower(), clean(rule.class, 20):upper()
    rule.keyword, rule.reason = clean(rule.keyword, 80):lower(), clean(rule.reason, 160)
    return rule
end

function AutoRoll:Add(rule)
    if type(rule) ~= "table" then return nil, "Regel fehlt" end
    local choice = string.upper(tostring(rule.choice or ""))
    local id, identity = self:ResolveIdentity(rule.item, rule)
    local mode = string.upper(tostring(rule.matchMode or rule.mode or "EXACT"))
    if not VALID_CHOICE[choice] then return nil, "Wahl muss MS, OS, TRANSMOG oder PASS sein" end
    if id == nil then return nil, "Ungültiges Item" end
    if not VALID_MODE[mode] then return nil, "Ungültiger AutoRoll-Matchmodus" end
    if mode == "NAME" and identity.normalizedName == "" then return nil, "Itemname für Namensregel fehlt" end
    local store = self:GetStore()
    if #store.rules >= self.MAX_RULES then return nil, "Zu viele AutoRoll-Regeln" end
    store.nextID = (tonumber(store.nextID) or 0) + 1
    local itemLink = type(rule.item) == "string" and string.find(rule.item, "|Hitem:", 1, true) and rule.item or rule.itemLink
    local entry = {
        id = store.nextID, itemID = id, itemLink = clean(itemLink, 500), choice = choice,
        enabled = rule.enabled ~= false, matchMode = mode, identity = identity,
        delay = math.max(0, math.min(10, tonumber(rule.delay) or self:GetDefaultDelay())),
        priority = math.max(-9999, math.min(9999, math.floor(tonumber(rule.priority) or 0))),
        player = clean(rule.player, 64):lower(), class = clean(rule.class, 20):upper(),
        keyword = clean(rule.keyword, 80):lower(), reason = clean(rule.reason ~= "" and rule.reason or "Manuelle Regel", 160),
    }
    store.rules[#store.rules + 1] = entry
    GA.Events:Emit("GA_AUTOROLL_CHANGED", entry, "ADDED")
    if GA.ItemData and type(GA.ItemData.LoadAsync) == "function" then GA.ItemData:LoadAsync() end
    return entry
end

function AutoRoll:Remove(id)
    local rules = self:GetStore().rules
    for index = 1, #rules do
        if tonumber(rules[index].id) == tonumber(id) then
            local removed = table.remove(rules, index)
            GA.Events:Emit("GA_AUTOROLL_CHANGED", removed, "REMOVED")
            return true
        end
    end
    return false
end

function AutoRoll:GetRules()
    local rules = self:GetStore().rules
    for _, rule in ipairs(rules) do self:MigrateRule(rule) end
    return rules
end

function AutoRoll:IsKnownFamily(rule, id, identity)
    local sourceFamily, targetFamily = tonumber(rule.identity.familyID), tonumber(identity.familyID)
    if sourceFamily and targetFamily then return sourceFamily == targetFamily end
    if GA.ItemData then
        local family = cachedItemData("PeekFamily", "GetFamily", rule.itemID)
        if type(family) == "table" then
            for _, memberID in pairs(family) do if tonumber(memberID) == tonumber(id) then return true end end
        end
    end
    return false
end

function AutoRoll:IsLearnedVariant(rule, id)
    local learned = self:GetStore().learnedVariants[tostring(rule.itemID)]
    return type(learned) == "table" and learned[tostring(id)] and true or false
end

function AutoRoll:LearnVariant(rule, id, identity)
    local store = self:GetStore()
    local key = tostring(rule.itemID)
    store.learnedVariants[key] = type(store.learnedVariants[key]) == "table" and store.learnedVariants[key] or {}
    store.learnedVariants[key][tostring(id)] = { learnedAt = type(time) == "function" and time() or 0,
        name = identity.name, difficulty = identity.difficulty }
end

function AutoRoll:MatchRule(rule, id, identity)
    local wanted = tonumber(rule.itemID) or 0
    if wanted == 0 then return true, 0, "WILDCARD" end
    if wanted == id then return true, 400, "EXACT" end
    if rule.matchMode == "EXACT" then return false end
    if rule.matchMode == "NAME" then
        if rule.identity.normalizedName ~= "" and rule.identity.normalizedName == identity.normalizedName then return true, 100, "NAME" end
        return false
    end
    if self:IsKnownFamily(rule, id, identity) then return true, 300, "FAMILY" end
    if self:IsLearnedVariant(rule, id) then return true, 250, "LEARNED_FAMILY" end
    if safeFingerprintMatch(rule.identity, identity) then
        self:LearnVariant(rule, id, identity)
        return true, 200, "LEARNED_FAMILY"
    end
    return false
end

function AutoRoll:Preview(item, context)
    context = context or {}
    local id, identity = self:ResolveIdentity(item, context)
    if not id then return { matched = false, choice = nil, reason = "Ungültiges Item" } end
    local player = tostring(context.player or (UnitName and UnitName("player")) or ""):lower():match("^[^-]+") or ""
    local class = tostring(context.class or ""):upper()
    local text = tostring(context.itemName or identity.name or item or ""):lower()
    local matches = {}
    for _, rule in ipairs(self:GetRules()) do
        local _, refreshed = self:ResolveIdentity(rule.itemLink ~= "" and rule.itemLink or rule.itemID, rule.identity)
        rule.identity = mergeIdentity(rule.identity, refreshed)
        local matched, rank, matchKind = self:MatchRule(rule, id, identity)
        if rule.enabled ~= false and matched and (rule.player == "" or rule.player == player) and
            (rule.class == "" or rule.class == class) and
            (rule.keyword == "" or string.find(text, rule.keyword, 1, true)) then
            matches[#matches + 1] = { rule = rule, rank = rank, matchKind = matchKind }
        end
    end
    table.sort(matches, function(left, right)
        if left.rank ~= right.rank then return left.rank > right.rank end
        if left.rule.priority ~= right.rule.priority then return left.rule.priority > right.rule.priority end
        return tonumber(left.rule.id) < tonumber(right.rule.id)
    end)
    local match = matches[1]
    if not match then return { matched = false, choice = nil, reason = "Keine passende Regel", itemID = id, identity = identity } end
    local rule = match.rule
    return { matched = true, choice = rule.choice, reason = rule.reason, itemID = id, ruleID = rule.id,
        candidates = #matches, matchMode = rule.matchMode, matchKind = match.matchKind, identity = identity }
end

local EXPORT_HEADER = "ItemID\tWahl\tPriorität\tSpieler\tKlasse\tSuchtext\tGrund\tMatchmodus\tItemlink\tItemname\tItemtyp\tAusrüstung\tIcon\tFamilie\tSchwierigkeit\tVerzögerung"

function AutoRoll:Export()
    local lines = { EXPORT_HEADER }
    for _, rule in ipairs(self:GetRules()) do
        local identity = rule.identity or {}
        lines[#lines + 1] = table.concat({ rule.itemID == 0 and "*" or rule.itemID, rule.choice, rule.priority,
            rule.player, rule.class, rule.keyword, rule.reason, rule.matchMode, rule.itemLink or "", identity.name or "",
            identity.itemType or "", identity.equipLoc or "", identity.icon or "", identity.familyID or "", identity.difficulty or "",
            tonumber(rule.delay) or self:GetDefaultDelay() }, "\t")
    end
    return table.concat(lines, "\n")
end

local function splitTabs(line)
    local fields, start = {}, 1
    while true do
        local position = string.find(line, "\t", start, true)
        if not position then fields[#fields + 1] = string.sub(line, start); return fields end
        fields[#fields + 1], start = string.sub(line, start, position - 1), position + 1
    end
end

function AutoRoll:Import(text)
    local imported, rejected, first = 0, 0, true
    for line in string.gmatch((text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            if first and string.find(string.lower(line), "itemid", 1, true) then first = false
            else
                first = false
                local field = splitTabs(line)
                local sourceItem = field[9] and field[9] ~= "" and field[9] or field[1]
                local added = field[1] and self:Add({ item = sourceItem, itemLink = field[9], choice = field[2], priority = field[3],
                    player = field[4], class = field[5], keyword = field[6], reason = field[7], matchMode = field[8] or "EXACT",
                    itemName = field[10], itemType = field[11], equipLoc = field[12], icon = field[13],
                    familyID = field[14], difficulty = field[15], delay = field[16] })
                if added then imported = imported + 1 else rejected = rejected + 1 end
            end
        end
    end
    return imported, rejected
end

function AutoRoll:OnInitialize()
    local store = self:GetStore()
    for _, rule in ipairs(store.rules) do self:MigrateRule(rule) end
    return true
end
GA:RegisterModule("AutoRoll", AutoRoll)
