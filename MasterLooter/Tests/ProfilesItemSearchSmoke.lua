local addonTable = {}
local function load(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk("MasterLooter", addonTable)
end

_G = _G or {}
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Ascension" end

load("MasterLooter/Core/Namespace.lua")
load("MasterLooter/Core/DB.lua")
local GA = addonTable
GA.modules = GA.modules or {}
GA.Events = GA.Events or { Emit = function() end }
function GA:RegisterModule(name, module) self.modules[name] = module end
load("MasterLooter/Modules/Profiles.lua")

GA.DB:Initialize()
GA.DB:GetProfile()
assert(GA.Profiles:Create("Raid") ~= nil)
assert(GA.Profiles:Copy("Default", "Farm") ~= nil)
assert(GA.Profiles:Rename("Farm", "Farmabend"))
assert(GA.Profiles:Activate("Raid"))
assert(GA.DB.data.activeProfile == "Raid")
assert(GA.DB.data.profileAssignments[GA.DB:GetCharacterKey()] == "Raid")
assert(GA.Profiles:Delete("Farmabend"))

_G.MasterLooterItemData = {
    Search = function(_, query, limit, filters)
        assert(query == "sword")
        assert(limit == 12)
        assert(filters.minimumQuality == 3)
        return { { itemID = 1, name = "Sword" } }
    end,
    GetStats = function() return { count = 42, source = "runtime" } end,
}
load("MasterLooter/Modules/ItemDataBridge.lua")
local results = GA.ItemData:Search("sword", 12, { minimumQuality = 3 })
assert(#results == 1 and results[1].itemID == 1)
assert(GA.ItemData:GetStats().count == 42)

GA.DB.data.history = { { itemID = 1 } }
GA.DB:ResetAll()
assert(#GA.DB.data.history == 0)
assert(GA.DB.data.activeProfile == "Default")

print("PASS: profile lifecycle, character assignment, item search bridge and factory reset")
