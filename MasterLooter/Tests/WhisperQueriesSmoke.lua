local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, expected, message) expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end

local now, raidMaster = 100, 1
local sent, callbacks, registered = {}, {}, {}
function GetTime() return now end
function UnitName(unit)
    if unit == "player" or unit == "raid1" then return "Lootmaster" end
    if unit == "raid2" then return "Alice" end
    if unit == "raid3" then return "Bob" end
end
function GetNumRaidMembers() return 3 end
function GetNumPartyMembers() return 0 end
function GetLootMethod() return "master", nil, raidMaster end
function GetItemInfo(id) return "Item " .. tostring(id), "|Hitem:" .. tostring(id) .. ":0:0:0|h[Item " .. tostring(id) .. "]|h" end
function SendChatMessage(message, channel, _, target) sent[#sent + 1] = { message = message, channel = channel, target = target } end

local GA = {
    modules = {},
    DB = { data = { softRes = { reservations = { ["1985"] = { alice = 2 }, ["2000"] = { bob = 1 } } } } },
    Events = {},
    PlusOnes = { Get = function(_, player) return string.lower(tostring(player)):find("alice", 1, true) and 3 or 0 end },
    Announcements = { ResolveChannel = function() return "RAID_WARNING" end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA.Events:On(event, callback) callbacks[event] = callback end
function GA.Events:RegisterGameEvent(event) registered[event] = true end
function GA.Events:Emit() end

assert(loadfile("MasterLooter/Modules/WhisperQueries.lua"))("MasterLooter", GA)
GA.WhisperQueries:OnInitialize()
same(sent[1].channel, "RAID_WARNING", "becoming raid master looter announces through raid warning")
expect(sent[1].message:find("!SR", 1, true) and sent[1].message:find("!SL", 1, true), "master-looter announcement lists both whisper commands")
expect(registered.CHAT_MSG_WHISPER, "whisper event is registered")
expect(not registered.CHAT_MSG_RAID and not registered.CHAT_MSG_PARTY, "public chat query events are not registered")

same(callbacks.CHAT_MSG_WHISPER(nil, nil, "!SR", "Alice-Realm"), nil, "event callback does not leak a return value")
same(sent[#sent].channel, "WHISPER", "soft-reserve response is private")
same(sent[#sent].target, "Alice-Realm", "soft-reserve response targets its requester")
expect(sent[#sent].message:find("Item 1985", 1, true) and sent[#sent].message:find("x2", 1, true), "soft-reserve response includes item and duplicate amount")

now = now + 1
expect(GA.WhisperQueries:HandleWhisper("  !sl  ", "Alice-Realm"), "strich-list query is case-insensitive and whitespace tolerant")
expect(sent[#sent].message:find("3", 1, true), "strich-list response includes current manual plus-one value")
same(sent[#sent].channel, "WHISPER", "strich-list response is private")

local before = #sent
now = now + 1
expect(not GA.WhisperQueries:HandleWhisper("!SR", "Outsider"), "players outside the group receive no data")
expect(not GA.WhisperQueries:HandleWhisper("!SR extra", "Alice"), "only the exact command is accepted")
same(#sent, before, "rejected queries send no response")

callbacks.RAID_ROSTER_UPDATE()
same(#sent, before, "unchanged master-looter state is not announced twice")
raidMaster = 2; callbacks.PARTY_LOOT_METHOD_CHANGED()
raidMaster = 1; callbacks.PARTY_LOOT_METHOD_CHANGED()
same(#sent, before + 1, "regaining master looter announces commands again")

print("PASS: " .. assertions .. " whisper-query assertions")
