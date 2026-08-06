local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, expected, message) expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end

function time() return 1700000000 end
local listeners = {}
local GA = {
    modules = {}, UI = {},
    DB = { data = { priorities = {}, softRes = { reservations = {}, hardReserved = {} } } },
    Events = {},
    Compat = { GetItemID = function(_, value) return tonumber(tostring(value or ""):match("item:(%d+)")) or tonumber(value) end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:Emit(event, ...) listeners[#listeners + 1] = { event, ... } end
function GA.Events:On() end
local function load(path) assert(loadfile("MasterLooter/" .. path))("MasterLooter", GA) end
load("Modules/SoftRes.lua"); load("Modules/Priority.lua"); load("Modules/ExternalImports.lua")
GA.SoftRes:OnInitialize()

local emptyExport = "eyJtZXRhZGF0YSI6eyJpZCI6ImNCemJJbiIsImluc3RhbmNlIjowLCJpbnN0YW5jZXMiOlsiWnVsJ0d1cnViIl0sIm9yaWdpbiI6InJhaWRyZXMifSwic29mdHJlc2VydmVzIjpbXSwiaGFyZHJlc2VydmVzIjpbXX0="
local valid, detail = GA.ExternalImports:ValidateBisBeard(emptyExport)
expect(valid and detail ~= "", "provided BISBEARD export validates")
local imported, rejected = GA.ExternalImports:ImportBisBeard(emptyExport)
same(imported, 0, "empty BISBEARD raid imports cleanly"); same(rejected, 0, "empty BISBEARD raid rejects nothing")

local populated = "eyJtZXRhZGF0YSI6eyJpZCI6InRlc3QiLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkFsaWNlIiwiaXRlbXMiOlt7ImlkIjoxOTg1LCJxdWFsaXR5IjozfSx7ImlkIjoxOTg1LCJxdWFsaXR5IjozfSx7ImlkIjoyMDAwLCJxdWFsaXR5Ijo0fV19XSwiaGFyZHJlc2VydmVzIjpbeyJpZCI6MzAwMCwicXVhbGl0eSI6NH1dfQ=="
imported, rejected = GA.ExternalImports:ImportBisBeard(populated)
same(imported, 3, "BISBEARD imports two soft-reserve item rows and one hard reserve")
same(rejected, 0, "valid BISBEARD rows are accepted")
same(GA.SoftRes:GetEntry("Alice-Realm", 1985).amount, 2, "duplicate BISBEARD picks retain their amount")
expect(GA.SoftRes:IsHardReserved(3000), "BISBEARD hard reserve is imported")
local bad, badMessage = GA.ExternalImports:ImportBisBeard("not base64!")
expect(bad == false and type(badMessage) == "string", "invalid BISBEARD paste fails safely")

local rrobin = '{"reserves":[{"character":"Bob","itemid":1985,"priority":7}]}'
imported, rejected = GA.ExternalImports:ImportRRobin(rrobin)
same(imported, 1, "RRobin JSON imports"); same(rejected, 0, "RRobin JSON rejects nothing"); same(GA.Priority:Get(1985, "Bob"), 7, "RRobin priority is retained")

local dft = '"1985^Kam Buckler\nPriority: Alice|10\nPriority: Bob|5;"'
imported, rejected = GA.ExternalImports:ImportDFT(dft)
same(imported, 2, "DFT block imports both players"); same(GA.Priority:Get(1985, "Alice"), 10, "DFT priority is retained")

local classic = "1985,Alice[1],Bob|Cara[2]\nMain:Alice,Bob"
imported, rejected = GA.ExternalImports:ImportClassicPR(classic)
same(imported, 3, "ClassicPR CSV imports tied players")
expect(GA.Priority:Get(1985, "Alice") > GA.Priority:Get(1985, "Bob"), "ClassicPR rank one sorts before rank two")

local registered, prompted
LootReserve = {
    RegisterListener = function(_, event, id, callback) registered = { event, id, callback }; return true end,
    PromptListener = function(_, event, id) prompted = { event, id } end,
}
expect(GA.ExternalImports:ConnectLootReserve(), "LootReserve listener connects when the addon is available")
same(registered[1], "RESERVES", "LootReserve RESERVES listener is used")
same(prompted[2], "MasterLooter", "LootReserve is prompted with a stable listener id")
registered[3]({ Dora = { 4000, 4000, "|Hitem:4001:0:0:0|h[Test]|h" } })
same(GA.SoftRes:GetEntry("Dora", 4000).amount, 2, "LootReserve duplicate picks retain their amount")
same(GA.SoftRes:GetEntry("Dora", 4001).amount, 1, "LootReserve item links are accepted")

print("PASS: " .. assertions .. " external import smoke assertions")
