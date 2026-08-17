local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local profile = { updateNotificationsEnabled = true }
local messages, events, channelMessages, filters = {}, {}, {}, {}
local clock = 100
GetTime = function() return clock end
GetChannelName = function(name) return name == "MasterLooterVersion" and 7 or 0 end
SendChatMessage = function(message, chatType, language, channelID)
    if string.find(message, "|", 1, true) then error("SendChatMessage(): Invalid escape code in chat message") end
    channelMessages[#channelMessages + 1] = { message, chatType, language, channelID }
end
UnitName = function(unit) return unit == "player" and "Tester" or nil end
ChatFrame_AddMessageEventFilter = function(event, callback) filters[event] = callback end
local GA = {
    ADDON_NAME = "MasterLooter", VERSION = "0.17.3-1-beta", PROTOCOL_VERSION = 3,
    DB = { GetProfile = function() return profile end },
    Compat = {
        IterateGroupUnits = function()
            local units, index = { "player", "party1", "party2" }, 0
            return function() index = index + 1; return units[index] end
        end,
        UnitFullName = function(_, unit)
            return ({ player = "Tester-Realm", party1 = "Newer-Realm", party2 = "Other-Realm" })[unit]
        end,
        IsInGroup = function() return true end,
        After = function(_, _, callback) callback() end,
    },
    Comm = {
        RegisterHandler = function() end,
        Send = function() return "packet" end,
    },
    Events = {
        Emit = function(_, event, ...) events[#events + 1] = { event, ... } end,
        On = function() end,
        RegisterGameEvent = function() end,
    },
}
function GA:RegisterModule(name, module) self[name] = module end
function GA:Print(message) messages[#messages + 1] = message end
function GA:L(key, ...)
    local values = {
        ["version.update_available"] = "A new MasterLooter version is available. Installed: %s - Latest detected: %s.",
    }
    return string.format(values[key] or key, ...)
end

local chunk, loadError = loadfile("MasterLooter/Modules/VersionCheck.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)
local checker = GA.VersionCheck

same(checker:CompareVersions("0.17.3-1-beta", "0.17.3-beta"), 1, "numbered beta is newer than its base beta")
same(checker:CompareVersions("v0.17.4-beta", "0.17.3-1-beta"), 1, "leading v and newer patch are supported")
same(checker:CompareVersions("0.17.3", "0.17.3-9-rc"), 1, "release is newer than a prerelease")
same(checker:CompareVersions("0.17.3-alpha", "0.17.3-beta"), -1, "alpha is older than beta")
same(checker:CompareVersions("invalid", "0.17.3-beta"), nil, "invalid versions are ignored")

checker:OnHello({ "0.17.4-beta", 3, "MasterLooter" }, "Newer-Realm")
same(#messages, 1, "newer group version creates one chat notification")
expect(string.find(messages[1], "0.17.3-1-beta", 1, true) and string.find(messages[1], "0.17.4-beta", 1, true),
    "notification contains installed and detected versions")
same(checker:GetLatestDetectedVersion(), "0.17.4-beta", "latest detected version is exposed")

checker:OnHello({ "0.17.4-beta", 3, "MasterLooter" }, "Newer-Realm")
same(#messages, 1, "the same version does not spam")
checker:OnHello({ "0.17.5-beta", 3, "MasterLooter" }, "Newer-Realm")
same(#messages, 2, "a genuinely newer detected version is announced once")

profile.updateNotificationsEnabled = false
checker:OnHello({ "0.17.6-beta", 3, "MasterLooter" }, "Newer-Realm")
same(#messages, 2, "disabled update notifications stay silent")
profile.updateNotificationsEnabled = true
checker:OnHello({ "0.17.6-beta", 3, "OtherAddon" }, "Other-Realm")
same(#messages, 2, "other addons cannot trigger a MasterLooter update notification")
checker:OnHello({ "0.17.2-beta", 3, "MasterLooter" }, "Newer-Realm")
same(#messages, 2, "older versions stay silent")

profile.updateNotificationsEnabled = true
expect(checker:SendRealmQuery(), "realm query is sent through the private version channel")
same(channelMessages[#channelMessages][2], "CHANNEL", "realm discovery uses a player-created chat channel")
same(channelMessages[#channelMessages][4], 7, "realm discovery targets the resolved channel ID")
expect(string.find(channelMessages[#channelMessages][1], "^MLV1:Q:0%.17%.3%-1%-beta:"), "query has a chat-safe private protocol envelope")
expect(not string.find(channelMessages[#channelMessages][1], "|", 1, true), "query contains no WoW chat escape introducer")
local nonce = checker.realmNonce

expect(checker:OnRealmMessage("MLV1:R:0.18.0-beta:" .. nonce, "RealmUser", "7. MasterLooterVersion", 7),
    "matching realm response is accepted")
same(#messages, 3, "newer realm version creates one localized update notice")
same(checker:GetLatestDetectedVersion(), "0.18.0-beta", "realm result participates in latest-version lookup")
expect(not checker:OnRealmMessage("MLV1:R:9.9.9:wrong", "Spoofer", "7. MasterLooterVersion", 7),
    "response without the active nonce is rejected")
same(#messages, 3, "rejected response cannot notify")
expect(not checker:OnRealmMessage("MLV1:R:9.9.9:" .. nonce, "Spoofer", "2. Trade", 2),
    "protocol text from another channel is rejected")

local beforeResponse = #channelMessages
expect(checker:OnRealmMessage("MLV1:Q:0.16.0-beta:peer-1", "OlderUser", "7. MasterLooterVersion", 7),
    "newer client accepts a valid older-client query")
same(#channelMessages, beforeResponse + 1, "newer client answers a realm query after the bounded callback")
expect(string.find(channelMessages[#channelMessages][1], "^MLV1:R:0%.17%.3%-1%-beta:peer%-1$"),
    "response carries the installed version and original nonce")

checker:OnInitialize()
expect(type(filters.CHAT_MSG_CHANNEL) == "function", "realm protocol chat filter is installed")
expect(filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "MLV1:Q:0.16.0-beta:filter-1", nil, nil,
    "7. MasterLooterVersion", nil, nil, nil, 7), "realm protocol packets are hidden from chat")
expect(not filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "ordinary player message", nil, nil,
    "7. MasterLooterVersion", nil, nil, nil, 7), "ordinary channel messages remain visible")
expect(not filters.CHAT_MSG_CHANNEL(nil, "CHAT_MSG_CHANNEL", "MLV1|Q|0.16.0-beta|legacy", nil, nil,
    "7. MasterLooterVersion", nil, nil, nil, 7), "invalid legacy pipe packet is not treated as current protocol")

profile.updateNotificationsEnabled = false
local disabledCount = #channelMessages
expect(not checker:SendRealmQuery(), "disabled update notifications also disable realm queries")
same(#channelMessages, disabledCount, "disabled update check emits no channel traffic")

print("PASS: " .. assertions .. " version-check assertions")
