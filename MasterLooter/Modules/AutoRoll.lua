-- Declarative roll recommendations. This module never rolls or clicks protected
-- UI by itself; it only explains which button a player may choose.
local _, GA = ...

local AutoRoll = { MAX_RULES = 500 }
GA.AutoRoll = AutoRoll

local VALID_CHOICE = { MS = true, OS = true, TRANSMOG = true, PASS = true }
local function clean(value, maximum)
    value = tostring(value or ""):gsub("[%c]", " ")
    return string.sub(value, 1, maximum or 160)
end
local function itemID(value)
    if value == "*" or value == nil or value == "" then return 0 end
    return GA.Compat:GetItemID(value)
end

function AutoRoll:GetStore()
    GA.DB.data.autoRoll = type(GA.DB.data.autoRoll) == "table" and GA.DB.data.autoRoll or { nextID = 0, rules = {} }
    GA.DB.data.autoRoll.rules = type(GA.DB.data.autoRoll.rules) == "table" and GA.DB.data.autoRoll.rules or {}
    return GA.DB.data.autoRoll
end

function AutoRoll:Add(rule)
    if type(rule) ~= "table" then return nil, "Regel fehlt" end
    local choice = string.upper(tostring(rule.choice or ""))
    local id = itemID(rule.item)
    if not VALID_CHOICE[choice] then return nil, "Wahl muss MS, OS, TRANSMOG oder PASS sein" end
    if id == nil then return nil, "Ungültiges Item" end
    local store = self:GetStore()
    if #store.rules >= self.MAX_RULES then return nil, "Zu viele AutoRoll-Regeln" end
    store.nextID = (tonumber(store.nextID) or 0) + 1
    local entry = {
        id = store.nextID, itemID = id, choice = choice, enabled = rule.enabled ~= false,
        priority = math.max(-9999, math.min(9999, math.floor(tonumber(rule.priority) or 0))),
        player = clean(rule.player, 64):lower(), class = clean(rule.class, 20):upper(),
        keyword = clean(rule.keyword, 80):lower(), reason = clean(rule.reason ~= "" and rule.reason or "Manuelle Regel", 160),
    }
    store.rules[#store.rules + 1] = entry
    GA.Events:Emit("GA_AUTOROLL_CHANGED", entry, "ADDED")
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

function AutoRoll:GetRules() return self:GetStore().rules end

function AutoRoll:Preview(item, context)
    context = context or {}
    local id = itemID(item)
    if not id then return { matched = false, choice = nil, reason = "Ungültiges Item" } end
    local player = tostring(context.player or (UnitName and UnitName("player")) or ""):lower():match("^[^-]+") or ""
    local class = tostring(context.class or ""):upper()
    local text = tostring(context.itemName or item or ""):lower()
    local matches = {}
    for _, rule in ipairs(self:GetRules()) do
        if rule.enabled ~= false and (tonumber(rule.itemID) == 0 or tonumber(rule.itemID) == id) and
            (rule.player == "" or rule.player == player) and (rule.class == "" or rule.class == class) and
            (rule.keyword == "" or string.find(text, rule.keyword, 1, true)) then
            matches[#matches + 1] = rule
        end
    end
    table.sort(matches, function(left, right)
        local leftExact, rightExact = tonumber(left.itemID) == id and 1 or 0, tonumber(right.itemID) == id and 1 or 0
        if leftExact ~= rightExact then return leftExact > rightExact end
        if left.priority ~= right.priority then return left.priority > right.priority end
        return tonumber(left.id) < tonumber(right.id)
    end)
    local rule = matches[1]
    if not rule then return { matched = false, choice = nil, reason = "Keine passende Regel", itemID = id } end
    return { matched = true, choice = rule.choice, reason = rule.reason, itemID = id, ruleID = rule.id, candidates = #matches }
end

function AutoRoll:Export()
    local lines = { "ItemID\tWahl\tPriorität\tSpieler\tKlasse\tSuchtext\tGrund" }
    for _, rule in ipairs(self:GetRules()) do
        lines[#lines + 1] = table.concat({ rule.itemID == 0 and "*" or rule.itemID, rule.choice, rule.priority,
            rule.player, rule.class, rule.keyword, rule.reason }, "\t")
    end
    return table.concat(lines, "\n")
end

function AutoRoll:Import(text)
    local imported, rejected, first = 0, 0, true
    for line in string.gmatch((text or "") .. "\n", "([^\r\n]*)[\r\n]") do
        if line ~= "" then
            if first and string.find(string.lower(line), "itemid", 1, true) then first = false
            else
                first = false
                local item, choice, priority, player, class, keyword, reason = string.match(line,
                    "^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
                local added = item and self:Add({ item = item, choice = choice, priority = priority, player = player,
                    class = class, keyword = keyword, reason = reason })
                if added then imported = imported + 1 else rejected = rejected + 1 end
            end
        end
    end
    return imported, rejected
end

function AutoRoll:OnInitialize() self:GetStore(); return true end
GA:RegisterModule("AutoRoll", AutoRoll)
