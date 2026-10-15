-- AutoRoll variant matching regression coverage for WotLK item families.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. message, 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

function UnitName(unit) if unit == "player" then return "Tester" end end
function time() return 1700002000 end

local cached = {
    [1001] = { "Helm of Wrath", "|Hitem:1001:0:0:0|h[Helm of Wrath]|h", 4, 100, 60, "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Helm_Wrath" },
    [1002] = { "Helm of Wrath", "|Hitem:1002:0:0:0|h[Helm of Wrath]|h", 4, 115, 60, "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Helm_Wrath" },
    [1003] = { "Helm of Wrath", "|Hitem:1003:0:0:0|h[Helm of Wrath]|h", 4, 130, 60, "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Helm_Wrath" },
    [1102] = { "Helm of Wrath", "|Hitem:1102:0:0:0|h[Helm of Wrath]|h", 4, 115, 60, "Armor", "Plate", 1, "INVTYPE_CHEST", "Icons\\Chest_Wrath" },
    [1202] = { "Helm of Wrath", "|Hitem:1202:0:0:0|h[Helm of Wrath]|h", 4, 115, 60, "Weapon", "Axe", 1, "INVTYPE_WEAPON", "Icons\\Axe_Wrath" },
    [2001] = { "Umhang der Pruefung", "|Hitem:2001:0:0:0|h[Umhang der Pruefung]|h", 3, 90, 60, "Armor", "Cloth", 1, "INVTYPE_CLOAK", "Icons\\Cape_Test" },
    [2002] = { "Umhang der Pruefung", "|Hitem:2002:0:0:0|h[Umhang der Pruefung]|h", 4, 110, 60, "Armor", "Cloth", 1, "INVTYPE_CLOAK", "Icons\\Cape_Test" },
}
local itemInfoThrows = false
function GetItemInfo(subject)
    if itemInfoThrows then error("item cache failed") end
    local id = tonumber(subject) or tonumber(tostring(subject or ""):match("item:(%d+)"))
    local row = cached[id]
    if not row then return nil end
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[10]
end

local familyEntries = {
    [1001] = { itemID = 1001, familyID = 1001, difficulty = 3 },
    [1002] = { itemID = 1002, familyID = 1001, difficulty = 4 },
    [1003] = { itemID = 1003, familyID = 1001, difficulty = 5 },
}
local families = { [1001] = { [3] = 1001, [4] = 1002, [5] = 1003 } }
local providerThrows = false
local emitted = {}
local GA = {
    DB = { data = { autoRoll = {} } }, Events = {}, modules = {},
    Compat = { GetItemID = function(_, value)
        if value == "*" then return 0 end
        return tonumber(tostring(value or ""):match("item:(%d+)")) or tonumber(value)
    end },
    ItemData = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:Emit(event, ...) emitted[#emitted + 1] = { event, ... } end
function GA.ItemData:Get(id)
    if providerThrows then error("provider failed") end
    return familyEntries[tonumber(id)]
end
function GA.ItemData:GetFamily(id)
    if providerThrows then error("provider failed") end
    local entry = familyEntries[tonumber(id)]
    return entry and families[entry.familyID] or nil
end

assert(loadfile("MasterLooter/Modules/AutoRoll.lua"))("MasterLooter", GA)
local AutoRoll = GA.AutoRoll
expect(AutoRoll:OnInitialize(), "AutoRoll initializes")

local function reset(store)
    GA.DB.data.autoRoll = store or {}
    return AutoRoll:GetStore()
end

-- Exact rules are ID based and never confuse equal names.
reset()
local exact = assert(AutoRoll:Add({ item = 1001, choice = "MS", matchMode = "EXACT", reason = "exact" }))
same(AutoRoll:Preview(1001).ruleID, exact.id, "exact rule matches its item ID")
expect(not AutoRoll:Preview(1002).matched, "exact rule rejects a different variant ID with the same name")

-- ItemData families win over learned/name matching and include all difficulties.
reset()
local family = assert(AutoRoll:Add({ item = 1001, choice = "OS", matchMode = "FAMILY", reason = "family" }))
local familyHeroic = AutoRoll:Preview(1002)
expect(familyHeroic.matched, "family rule matches Heroic ID")
same(familyHeroic.matchKind, "FAMILY", "provider family is reported")
same(familyHeroic.choice, "OS", "family preserves configured choice")
same(AutoRoll:Preview(1003).ruleID, family.id, "family matches another known difficulty")

-- With no family table, a conservative fingerprint learns same-name variants.
familyEntries, families = {}, {}
reset()
local learned = assert(AutoRoll:Add({ item = 2001, choice = "TRANSMOG", matchMode = "FAMILY" }))
local learnedResult = AutoRoll:Preview(2002)
expect(learnedResult.matched, "matching name/type/slot/icon learns a variant")
same(learnedResult.matchKind, "LEARNED_FAMILY", "learned match is distinguishable")
expect(AutoRoll:GetStore().learnedVariants["2001"]["2002"], "learned relation is persisted")

-- Same names alone do not create unsafe family matches.
reset()
assert(AutoRoll:Add({ item = 1001, choice = "MS", matchMode = "FAMILY" }))
expect(not AutoRoll:Preview(1102).matched, "different slot and icon reject same-name item")
expect(not AutoRoll:Preview(1202).matched, "different type and slot reject same-name item")

-- NAME is the explicit broad fallback and is never implicit.
reset()
local nameRule = assert(AutoRoll:Add({ item = 1001, choice = "PASS", matchMode = "NAME", priority = 999 }))
same(AutoRoll:Preview(1102).ruleID, nameRule.id, "explicit NAME rule accepts equal name despite different slot")
same(AutoRoll:Preview(1202).choice, "PASS", "explicit NAME fallback preserves action")

-- Specificity is deterministic before user priority, then priority/id break ties.
reset()
local broad = assert(AutoRoll:Add({ item = 1001, choice = "PASS", matchMode = "NAME", priority = 9999 }))
local specific = assert(AutoRoll:Add({ item = 1002, choice = "MS", matchMode = "EXACT", priority = -9999 }))
same(AutoRoll:Preview(1002).ruleID, specific.id, "exact rule outranks higher-priority NAME rule")
local first = assert(AutoRoll:Add({ item = 1003, choice = "OS", matchMode = "EXACT", priority = 5 }))
local second = assert(AutoRoll:Add({ item = 1003, choice = "TRANSMOG", matchMode = "EXACT", priority = 7 }))
same(AutoRoll:Preview(1003).ruleID, second.id, "priority resolves equal-specificity conflict")
expect(broad.id < first.id, "fixture keeps stable rule ordering")

-- Legacy SavedVariables remain exact rules instead of unexpectedly broadening.
local legacyStore = reset({ nextID = 7, rules = {
    { id = 7, itemID = 1001, choice = "MS", enabled = true, priority = 0, player = "", class = "", keyword = "", reason = "legacy" },
} })
AutoRoll:OnInitialize()
same(legacyStore.rules[1].matchMode, "EXACT", "legacy rule migrates to exact matching")
same(AutoRoll:Preview(1001).choice, "MS", "legacy exact rule remains usable")
expect(not AutoRoll:Preview(1002).matched, "legacy rule does not silently affect variants")
expect(type(legacyStore.learnedVariants) == "table", "legacy store gains learned-variant table")

-- Missing cache data remains safe: exact works; family cannot guess from a name alone.
cached[9001], cached[9002] = nil, nil
reset()
assert(AutoRoll:Add({ item = 9001, choice = "OS", matchMode = "FAMILY" }))
same(AutoRoll:Preview(9001).choice, "OS", "uncached exact ID still works")
expect(not AutoRoll:Preview(9002, { itemName = "Unknown Twin" }).matched, "uncached different ID is not guessed")

-- Disabled rules and invalid input are inert and safely rejected.
reset()
local disabled = assert(AutoRoll:Add({ item = 1001, choice = "MS", enabled = false }))
expect(not AutoRoll:Preview(1001).matched, "disabled rule is ignored")
expect(not AutoRoll:Add({ item = 1001, choice = "NEED" }), "invalid choice is rejected")
expect(not AutoRoll:Add({ item = 1001, choice = "MS", matchMode = "FUZZY" }), "invalid match mode is rejected")
expect(not AutoRoll:Add({ item = 9001, choice = "MS", matchMode = "NAME" }), "uncached NAME rule without a name is rejected")

-- Provider failures must degrade to cached client data rather than break a roll event.
reset()
providerThrows = true
local okAdd, providerRule = pcall(AutoRoll.Add, AutoRoll, { item = 1001, choice = "MS", matchMode = "FAMILY" })
expect(okAdd and providerRule, "ItemData Get failure is contained")
local okPreview, providerPreview = pcall(AutoRoll.Preview, AutoRoll, 1002)
expect(okPreview and type(providerPreview) == "table", "ItemData family failure is contained")
providerThrows = false

reset()
itemInfoThrows = true
local okCacheAdd, cacheRule = pcall(AutoRoll.Add, AutoRoll, { item = 1001, choice = "MS", matchMode = "EXACT" })
expect(okCacheAdd and cacheRule, "GetItemInfo failure is contained while adding an exact rule")
local okCachePreview, cachePreview = pcall(AutoRoll.Preview, AutoRoll, 1001)
expect(okCachePreview and cachePreview and cachePreview.choice == "MS", "GetItemInfo failure cannot block exact-ID matching")
itemInfoThrows = false

-- Extended export round-trips matching identity while the old seven-column format stays valid.
reset()
local exportedRule = assert(AutoRoll:Add({ item = 2001, choice = "OS", matchMode = "FAMILY", priority = 8 }))
local exported = AutoRoll:Export()
expect(string.find(exported, "Matchmodus", 1, true), "extended export declares match mode")
reset()
local imported, rejected = AutoRoll:Import(exported)
same(imported, 1, "extended export imports")
same(rejected, 0, "extended export rejects no valid rows")
same(AutoRoll:GetRules()[1].matchMode, "FAMILY", "match mode survives export/import")
reset()
local legacyImported, legacyRejected = AutoRoll:Import("ItemID\tWahl\tPrioritaet\tSpieler\tKlasse\tSuchtext\tGrund\n1001\tMS\t3\t\t\t\tAlt")
same(legacyImported, 1, "legacy seven-column export still imports")
same(legacyRejected, 0, "legacy export has no rejection")
same(AutoRoll:GetRules()[1].matchMode, "EXACT", "legacy import defaults to exact")

print("PASS: " .. assertions .. " AutoRoll variant-matching assertions")
