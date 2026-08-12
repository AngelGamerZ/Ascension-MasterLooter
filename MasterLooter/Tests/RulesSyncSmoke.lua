-- Rule engine, TMB paste and trusted synchronization smoke coverage.
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, expected, message)
    expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

function time() return 1700001000 end
function UnitName(unit)
    if unit == "player" then return "Lootmaster" end
    if unit == "raid1" then return "Lootmaster" end
    if unit == "raid2" then return "Officer" end
    if unit == "raid3" then return "Raider" end
end
function GetNumRaidMembers() return 3 end
function GetRaidRosterInfo(index)
    local names, ranks = { "Lootmaster", "Officer", "Raider" }, { 2, 1, 0 }
    return names[index], ranks[index]
end
function GetNumPartyMembers() return 0 end
function GetItemInfo() return "Test Item", nil, 4 end

local listeners, sent, handlers = {}, {}, {}
local GA = {
    modules = {}, UI = {},
    DB = { data = {
        autoRoll = {}, plusOnes = {}, boostedRolls = {}, priorities = {},
        softRes = { reservations = {}, hardReserved = {} }, character = {},
    } },
    Events = {},
    Compat = {
        GetItemID = function(_, value)
            return tonumber(tostring(value or ""):match("item:(%d+)")) or tonumber(value)
        end,
    },
    Comm = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:On(event, callback, owner)
    listeners[event] = listeners[event] or {}; listeners[event][#listeners[event] + 1] = { callback, owner }
end
function GA.Events:Emit(event, ...)
    for _, entry in ipairs(listeners[event] or {}) do entry[1](entry[2], event, ...) end
end
function GA.Events:RegisterGameEvent() end
function GA.Comm:RegisterHandler(kind, callback) handlers[kind] = callback end
function GA.Comm:Send(kind, fields, channel, target)
    sent[#sent + 1] = { kind = kind, fields = fields, channel = channel, target = target }
    return "packet-" .. #sent
end

local function load(path) assert(loadfile("MasterLooter/" .. path))("MasterLooter", GA) end
load("Modules/AutoRoll.lua")
load("Modules/SoftRes.lua")
load("Modules/Priority.lua")
load("Modules/BoostedRolls.lua")
load("Modules/PackMule.lua")
load("Modules/RuleSync.lua")
GA.AutoRoll:OnInitialize(); GA.SoftRes:OnInitialize(); GA.RuleSync:OnInitialize()

-- AutoRoll is recommendation-only and chooses exact/specific rules predictably.
local wildcard = assert(GA.AutoRoll:Add({ item = "*", choice = "PASS", priority = 1, reason = "Standard passen" }))
local exact = assert(GA.AutoRoll:Add({ item = 1985, choice = "MS", priority = 0, reason = "Schild für Main-Spec" }))
local transmogRule = assert(GA.AutoRoll:Add({ item = 3000, choice = "TRANSMOG", priority = 0, reason = "Style" }))
local preview = GA.AutoRoll:Preview("|Hitem:1985:0:0:0|h[Kam's Buckler]|h", { player = "Lootmaster" })
expect(preview.matched, "AutoRoll matches a configured item")
same(preview.choice, "MS", "exact item rule outranks wildcard")
same(preview.reason, "Schild für Main-Spec", "preview explains the selected rule")
same(GA.AutoRoll:Preview(9999).choice, "PASS", "wildcard rule covers unmatched items")
same(GA.AutoRoll:Preview(3000).choice, "TRANSMOG", "AutoRoll accepts the Transmog category")
expect(not GA.AutoRoll:Add({ item = 1, choice = "NEED" }), "unknown roll action is rejected")
local autoPaste = GA.AutoRoll:Export()
expect(string.find(autoPaste, "ItemID\tWahl", 1, true), "AutoRoll exports a paste header")
GA.DB.data.autoRoll = {}
local importedAuto, rejectedAuto = GA.AutoRoll:Import(autoPaste)
same(importedAuto, 3, "AutoRoll paste round-trips all rules")
same(rejectedAuto, 0, "valid AutoRoll paste has no rejected rows")
same(GA.AutoRoll:Preview(1985).choice, "MS", "imported AutoRoll rule remains usable")

-- TMB-compatible priority paste and a UI-ready display reason.
local tmb = "Character\tItemId\tPriority\tNote\nAlice\t1985\t12\tTank bis\nBob\t|Hitem:1985:0:0:0|h[Kam's Buckler]|h\t4\tOffspec"
local importedTMB, rejectedTMB = GA.Priority:ImportTMB(tmb)
same(importedTMB, 2, "TMB header paste imports both players")
same(rejectedTMB, 0, "valid TMB paste rejects nothing")
same(GA.Priority:Get(1985, "Alice-Realm"), 12, "TMB priority normalizes realm names")
local priorityText, priorityReason = GA.Priority:GetDisplay(1985, "Alice")
same(priorityText, "+12", "positive priority has compact display text")
expect(priorityReason ~= "", "priority display includes an explanation")
expect(string.find(GA.Priority:ExportTMB(), "Alice", 1, true) or string.find(GA.Priority:ExportTMB(), "alice", 1, true),
    "TMB export contains imported player")

-- Extended SoftRes supports notes, limits and explicit consumption.
expect(GA.SoftRes:SetLimit(2), "SoftRes per-player limit is configurable")
expect(GA.SoftRes:Reserve("Alice", 1985, 2, "Best in slot"), "reservation within limit succeeds")
same(GA.SoftRes:GetEntry("Alice", 1985).note, "Best in slot", "SoftRes note is retained")
expect(not GA.SoftRes:Reserve("Alice", 2000, 1), "reservation beyond global player limit is rejected")
local consumed, remaining = GA.SoftRes:Consume("Alice", 1985, 1)
expect(consumed, "SoftRes can be consumed explicitly")
same(remaining, 1, "SoftRes consumption reports remaining amount")
expect(GA.SoftRes:Reserve("Alice", 2000, 1), "freed SoftRes capacity can be reused")

-- PackMule previews do not advance round-robin and ignores explain exclusions.
GA.PackMule.store = {}; GA.PackMule.target = "Mule"
GA.PackMule:SetRules({ enabled = true, minimumQuality = 3, includeBoE = true, targets = { "MuleA", "MuleB" } })
local mulePreview = GA.PackMule:PreviewItem("|Hitem:1985:0:0:0|h[Test]|h", "BOE")
expect(mulePreview.accepted and mulePreview.target == "MuleA", "PackMule preview shows next target")
same(GA.PackMule:GetRules().roundRobinIndex, 0, "preview does not consume round-robin state")
same(GA.PackMule:EvaluateItem("|Hitem:1985:0:0:0|h[Test]|h", "BOE"), "MuleA", "evaluation commits first target")
same(GA.PackMule:EvaluateItem("|Hitem:1985:0:0:0|h[Test]|h", "BOE"), "MuleB", "next evaluation rotates target")
expect(GA.PackMule:SetIgnored(1985, true, "Für normale Verteilung"), "item can be ignored")
local ignored = GA.PackMule:PreviewItem("|Hitem:1985:0:0:0|h[Test]|h", "BOE")
same(ignored.reasonCode, "IGNORED", "ignored item has a stable reason code")
same(ignored.reason, "Für normale Verteilung", "ignore preview exposes configured reason")

-- Trusted synchronization: untrusted data, replays and same-revision conflicts
-- are rejected; a trusted officer snapshot applies atomically.
GA.DB.data.plusOnes, GA.DB.data.boostedRolls = { alice = 2 }, { alice = 5 }
local payload = GA.RuleSync:BuildPayload()
local packet = assert(GA.RuleSync:SendSnapshot("WHISPER", "Officer"))
same(sent[#sent].kind, "RS_SNAP", "rule snapshot uses dedicated message type")
same(sent[#sent].channel, "WHISPER", "targeted sync uses whisper transport")
local fields = sent[#sent].fields
expect(not GA.RuleSync:ReceiveSnapshot(fields, "Raider"), "ordinary raider cannot overwrite rules")
GA.DB.data.plusOnes, GA.DB.data.boostedRolls = {}, {}
local applied, count = GA.RuleSync:ReceiveSnapshot(fields, "Officer")
expect(applied, "trusted raid officer snapshot is accepted")
same(count, 2, "atomic snapshot reports applied entry count")
same(GA.DB.data.plusOnes.alice, 2, "trusted snapshot restores +1")
same(GA.DB.data.boostedRolls.alice, 5, "trusted snapshot restores roll bonus")
expect(not GA.RuleSync:ReceiveSnapshot(fields, "Officer"), "same snapshot replay is ignored")
local conflictFields = { fields[1], fields[2], fields[3], fields[4] .. "\nP\tbob\t1" }
-- checksum mismatch is rejected before it can masquerade as a revision conflict.
expect(not GA.RuleSync:ReceiveSnapshot(conflictFields, "Officer"), "tampered payload is rejected")
expect(GA.RuleSync:SetTrusted("TrustedAlt", true), "explicit trusted sender can be configured")
expect(GA.RuleSync:IsTrusted("TrustedAlt-Realm"), "explicit trust normalizes realm names")
assert(GA.RuleSync:Request("Officer"))
same(sent[#sent].kind, "RS_REQ", "manual sync query uses request message")
same(sent[#sent].target, "Officer", "sync query targets selected authority")
handlers.RS_REQ({ tostring(GA.RuleSync.PROTOCOL), "nonce" }, "Raider")
same(sent[#sent].kind, "RS_SNAP", "trusted local authority answers whisper queries")
same(sent[#sent].target, "Raider", "query response returns only to requester")
local beforeForeignRequest = #sent
handlers.RS_REQ({ tostring(GA.RuleSync.PROTOCOL), "nonce" }, "Stranger")
same(#sent, beforeForeignRequest, "snapshot requests from outside the roster are ignored")

print("PASS: " .. assertions .. " rules/sync smoke assertions")
