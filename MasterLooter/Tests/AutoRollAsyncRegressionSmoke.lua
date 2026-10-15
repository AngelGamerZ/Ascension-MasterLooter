-- Independent regression coverage for AutoRoll while the optional item provider
-- is unloaded, late-loaded, and only partially indexed.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. message, 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

unpack = unpack or table.unpack

local scheduled, loadCalls, emitted = {}, 0, {}
local providerEntries, providerFamilies = {}, {}
local itemInfo = {
    [4101] = { "Crown of Delay", "|Hitem:4101:0:0:0|h[Crown of Delay]|h", "Armor", "Plate", "INVTYPE_HEAD", "Icons\\Crown_Delay" },
    [4102] = { "Crown of Delay", "|Hitem:4102:0:0:0|h[Crown of Delay]|h", "Armor", "Plate", "INVTYPE_HEAD", "Icons\\Crown_Delay" },
    [4201] = { "Twin Name", "|Hitem:4201:0:0:0|h[Twin Name]|h", "Armor", "Cloth", "INVTYPE_CLOAK", "Icons\\Twin_A" },
    [4202] = { "Twin Name", "|Hitem:4202:0:0:0|h[Twin Name]|h", "Weapon", "Axe", "INVTYPE_WEAPON", "Icons\\Twin_B" },
}

function UnitName(unit) if unit == "player" then return "AsyncTester" end end
function GetItemInfo(subject)
    local id = tonumber(subject) or tonumber(tostring(subject or ""):match("item:(%d+)"))
    local row = itemInfo[id]
    if not row then return nil end
    return row[1], row[2], 4, 100, 60, row[3], row[4], 1, row[5], row[6]
end

local GA = { modules = {}, DB = { data = { autoRoll = {} } }, Events = {}, Compat = {} }
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:Emit(event, ...) emitted[#emitted + 1] = { event, ... } end
function GA.Compat:GetItemID(value)
    if value == "*" then return 0 end
    return tonumber(tostring(value or ""):match("item:(%d+)")) or tonumber(value)
end
function GA.Compat:After(delay, callback)
    local timer = { delay = delay, callback = callback }
    scheduled[#scheduled + 1] = timer
    return timer
end

function LoadAddOn(name)
    loadCalls = loadCalls + 1
    expect(name == "MasterLooter_ItemData", "late load requests only the optional item provider")
    _G.MasterLooterItemData = {
        Get = function(_, id) return providerEntries[tonumber(id)] end,
        GetFamily = function(_, id)
            local entry = providerEntries[tonumber(id)]
            return providerFamilies[entry and entry.familyID or tonumber(id)]
        end,
    }
    return true
end

assert(loadfile("MasterLooter/Modules/ItemDataBridge.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/Modules/AutoRoll.lua"))("MasterLooter", GA)
GA.AutoRoll:OnInitialize()

-- Cold-cache rule creation is immediate. It may schedule work, but cannot load
-- or enumerate the provider on the edit-box click stack.
local familyRule = assert(GA.AutoRoll:Add({ item = 4101, choice = "MS", matchMode = "FAMILY" }))
same(loadCalls, 0, "cold-cache Add never synchronously loads ItemData")
same(#scheduled, 1, "cold-cache Add schedules exactly one provider load")
same(GA.AutoRoll:Preview(4101).ruleID, familyRule.id, "exact ID remains usable before provider load")
same(loadCalls, 0, "cold-cache Preview also remains non-loading")
same(emitted[1][1], "GA_AUTOROLL_CHANGED", "rule addition still emits its UI refresh event")

-- A second Add while loading is queued must not create another loader or block.
local exactRule = assert(GA.AutoRoll:Add({ item = 4201, choice = "OS", matchMode = "EXACT" }))
same(#scheduled, 1, "multiple rules coalesce the pending provider load")
same(loadCalls, 0, "second Add remains immediate")
same(GA.AutoRoll:Preview(4201).ruleID, exactRule.id, "exact matching works with a pending provider")

-- The explicit NAME mode remains broad by choice, while FAMILY stays guarded
-- against unrelated items with the same localized name.
expect(not GA.AutoRoll:Preview(4202).matched, "FAMILY/EXACT rules do not confuse unrelated equal names")
local nameRule = assert(GA.AutoRoll:Add({ item = 4201, choice = "PASS", matchMode = "NAME", priority = 20 }))
same(GA.AutoRoll:Preview(4202).ruleID, nameRule.id, "explicit NAME matching works before ItemData is ready")

-- Load the provider, then expose only the base item and a partially assembled
-- family. The family table itself is sufficient; the target entry need not yet
-- exist, which is the real state seen between import frames.
scheduled[1].callback()
same(loadCalls, 1, "deferred callback performs the late provider load")
providerEntries[4101] = { itemID = 4101, familyID = 4101, difficulty = 3 }
providerFamilies[4101] = { [3] = 4101, [4] = 4102 }
itemInfo[4102] = nil
local partial = GA.AutoRoll:Preview(4102)
expect(partial.matched, "partially indexed provider family matches a listed target ID")
same(partial.ruleID, familyRule.id, "late provider enriches the already-saved FAMILY rule")
same(partial.matchKind, "FAMILY", "partial provider match is identified as a family match")

-- Once the target entry arrives, identity-based family resolution remains
-- stable and does not schedule or load anything again.
providerEntries[4102] = { itemID = 4102, familyID = 4101, difficulty = 4 }
local completed = GA.AutoRoll:Preview(4102)
same(completed.ruleID, familyRule.id, "completed family keeps matching the existing rule")
same(#scheduled, 1, "matching never schedules redundant provider loads")
same(loadCalls, 1, "matching never reloads an existing provider")

print("PASS: " .. assertions .. " asynchronous AutoRoll regression assertions")
