-- Regression coverage for non-blocking AutoRoll item-data initialization.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. message, 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

unpack = unpack or table.unpack
local scheduled, loadCalls = {}, 0
local GA = {
    modules = {}, DB = { data = { autoRoll = {} } }, Events = {}, Compat = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:Emit() end
function GA.Compat:GetItemID(value) return tonumber(tostring(value or ""):match("item:(%d+)")) or tonumber(value) end
function GA.Compat:After(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end
function GetItemInfo(id)
    id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
    return "Async Item", "|Hitem:" .. tostring(id) .. ":0:0:0|h[Async Item]|h", 4, 100, 60,
        "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Async"
end
function LoadAddOn(name)
    loadCalls = loadCalls + 1
    expect(name == "MasterLooter_ItemData", "only the optional item index is requested")
    _G.MasterLooterItemData = { Get = function() return nil end, GetFamily = function() return nil end }
    return true
end

assert(loadfile("MasterLooter/Modules/ItemDataBridge.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/Modules/AutoRoll.lua"))("MasterLooter", GA)
GA.AutoRoll:OnInitialize()
expect(GA.AutoRoll:Add({ item = 5001, choice = "MS", matchMode = "FAMILY" }), "rule is stored immediately")
same(loadCalls, 0, "saving a rule never calls LoadAddOn on the click stack")
same(#scheduled, 1, "optional index load is deferred to a later frame")
GA.ItemData:LoadAsync()
same(#scheduled, 1, "repeated load requests share one pending callback")
expect(GA.ItemData:Peek(5001) == nil, "cache peek never forces the optional addon to load")
scheduled[1].callback()
same(loadCalls, 1, "deferred callback loads the optional index once")
GA.ItemData:LoadAsync()
same(#scheduled, 1, "loaded provider is not scheduled again")

-- A failed optional-addon load clears the latch and remains retryable.
_G.MasterLooterItemData = nil
function LoadAddOn() loadCalls = loadCalls + 1; return nil, "missing" end
GA.ItemData:LoadAsync()
same(#scheduled, 2, "a new request can be scheduled after the provider disappears")
scheduled[2].callback()
GA.ItemData:LoadAsync()
same(#scheduled, 3, "a failed deferred load can be retried")

-- The provider itself must also bound AtlasLoot work per frame.
_G.MasterLooterItemData, _G.MasterLooterItemDB = nil, nil
local frames, itemInfoCalls, instantCalls, bagScans = {}, 0, 0, 0
function CreateFrame()
    local frame = { shown = true, scripts = {} }
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    frames[#frames + 1] = frame
    return frame
end
function GetRealmName() return "AsyncRealm" end
function GetLocale() return "enUS" end
function GetBuildInfo() return "3.3.5", "", "", 30300 end
function time() return 1700003000 end
function GetContainerNumSlots() bagScans = bagScans + 1; return 0 end
function GetItemInfo(id)
    itemInfoCalls = itemInfoCalls + 1
    return "Item " .. tostring(id), "|Hitem:" .. tostring(id) .. ":0:0:0|h[Item]|h", 4, 100, 60,
        "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Async"
end
function GetItemInfoInstant()
    instantCalls = instantCalls + 1
    error("broken custom-client backport")
end
ItemIDsDatabase = {}
for base = 1, 80 do
    local id = 6000 + base
    ItemIDsDatabase[id] = { [4] = 7000 + base, [5] = 8000 + base }
end
local itemNamespace = {}
assert(loadfile("MasterLooter_ItemData/ItemData.lua"))("MasterLooter_ItemData", itemNamespace)
itemNamespace:Initialize()
same(itemInfoCalls, 0, "provider initialization performs no synchronous item scan")
same(bagScans, 0, "bag learning waits until the background index is complete")
expect(itemNamespace.importing, "large AtlasLoot index starts in background mode")
local initialState = itemNamespace.importState
expect(itemNamespace:BeginAtlasLootImport(), "reentrant import request is accepted")
expect(itemNamespace.importState == initialState, "reentrant request does not reset in-progress iteration")
local worker = itemNamespace.worker
worker.scripts.OnUpdate()
expect(itemInfoCalls > 0 and itemInfoCalls <= 25, "one frame processes a bounded item-data batch")
expect(instantCalls > 0, "partial GetItemInfoInstant backport is exercised")
expect(itemNamespace.importing, "large import yields after its first batch")
local framesUsed = 1
while itemNamespace.importing and framesUsed < 100 do worker.scripts.OnUpdate(); framesUsed = framesUsed + 1 end
expect(not itemNamespace.importing, "background import eventually completes")
expect(framesUsed > 1, "large index is distributed over multiple frames")
expect(itemNamespace:GetFamily(6001)[4] == 7001, "completed background import exposes item variants")
expect(bagScans > 0, "bag learning runs after the index without blocking rule creation")

print("PASS: " .. assertions .. " asynchronous item-data assertions")
