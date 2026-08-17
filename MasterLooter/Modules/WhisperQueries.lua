local _, GA = ...

-- Player self-service queries. These commands intentionally listen only to
-- CHAT_MSG_WHISPER and only answer current group members while this client is
-- the active master looter.
local WhisperQueries = { lastRequest = {}, wasMasterLooter = false }
GA.WhisperQueries = WhisperQueries

local function L(key, fallback, ...)
    if type(GA.L) == "function" then return GA:L(key, ...) end
    return select("#", ...) > 0 and string.format(fallback, ...) or fallback
end

local COMMANDS = {
    SR = "SR", ["#SR"] = "SR", ["?SR"] = "SR", ["!SR"] = "SR", MLSR = "SR", ["ML SR"] = "SR",
    SL = "SL", ["#SL"] = "SL", ["?SL"] = "SL", ["!SL"] = "SL", MLSL = "SL", ["ML SL"] = "SL",
}

local function baseName(name)
    return string.lower(string.match(tostring(name or ""), "^[^-]+") or "")
end

local function playerName()
    return type(UnitName) == "function" and UnitName("player") or nil
end

local function samePlayer(left, right)
    local a, b = baseName(left), baseName(right)
    return a ~= "" and a == b
end

function WhisperQueries:IsGroupMember(name)
    if samePlayer(name, playerName()) then return true end
    if type(GetNumRaidMembers) == "function" and type(UnitName) == "function" then
        for index = 1, (GetNumRaidMembers() or 0) do
            if samePlayer(name, UnitName("raid" .. index)) then return true end
        end
    end
    if type(GetNumPartyMembers) == "function" and type(UnitName) == "function" then
        for index = 1, (GetNumPartyMembers() or 0) do
            if samePlayer(name, UnitName("party" .. index)) then return true end
        end
    end
    return false
end

function WhisperQueries:GetMasterLooterName()
    if type(GetLootMethod) ~= "function" then return nil end
    local method, partyIndex, raidIndex = GetLootMethod()
    if method ~= "master" then return nil end
    if raidIndex ~= nil then
        if raidIndex == 0 then return playerName() end
        return type(UnitName) == "function" and UnitName("raid" .. raidIndex) or nil
    end
    if partyIndex ~= nil then
        if partyIndex == 0 then return playerName() end
        return type(UnitName) == "function" and UnitName("party" .. partyIndex) or nil
    end
    return nil
end

function WhisperQueries:IsActiveMasterLooter()
    return samePlayer(self:GetMasterLooterName(), playerName())
end

function WhisperQueries:SendWhisper(target, message)
    if type(SendChatMessage) ~= "function" or baseName(target) == "" then return false end
    message = tostring(message or "")
    if #message > 240 then message = string.sub(message, 1, 237) .. "..." end
    local ok = pcall(SendChatMessage, message, "WHISPER", nil, target)
    if ok then GA.Events:Emit("GA_WHISPER_QUERY_REPLIED", target, message) end
    return ok
end

local function itemLabel(itemID)
    if type(GetItemInfo) == "function" then
        local name, link = GetItemInfo(tonumber(itemID) or itemID)
        if type(link) == "string" and link ~= "" then return link end
        if type(name) == "string" and name ~= "" then return "[" .. name .. "]" end
    end
    return L("whisper.item_number", "[Item #%s]", tostring(itemID))
end

function WhisperQueries:GetSoftResEntries(player)
    local result, playerID = {}, baseName(player)
    local reservations = GA.DB and GA.DB.data and GA.DB.data.softRes and GA.DB.data.softRes.reservations or {}
    for itemID, bucket in pairs(reservations) do
        local amount = type(bucket) == "table" and tonumber(bucket[playerID]) or 0
        if amount and amount > 0 then result[#result + 1] = { itemID = itemID, amount = math.floor(amount) } end
    end
    table.sort(result, function(left, right) return (tonumber(left.itemID) or 0) < (tonumber(right.itemID) or 0) end)
    return result
end

function WhisperQueries:ReplySoftRes(sender)
    local entries = self:GetSoftResEntries(sender)
    if #entries == 0 then return self:SendWhisper(sender, L("whisper.softres.none", "MasterLooter: Du hast aktuell keine SoftRes.")) end
    local prefix = L("whisper.softres.header", "MasterLooter: Deine SoftRes: ")
    local line = prefix
    for index, entry in ipairs(entries) do
        local value = itemLabel(entry.itemID) .. (entry.amount > 1 and (" x" .. tostring(entry.amount)) or "")
        local separator = line == prefix and "" or ", "
        if #line + #separator + #value > 235 then
            self:SendWhisper(sender, line); line = L("whisper.softres.more", "MasterLooter: Weitere SoftRes: ") .. value
        else line = line .. separator .. value end
    end
    return self:SendWhisper(sender, line)
end

function WhisperQueries:ReplyStreakList(sender)
    local value = GA.PlusOnes and type(GA.PlusOnes.Get) == "function" and GA.PlusOnes:Get(sender) or 0
    return self:SendWhisper(sender, L("whisper.plusones", "MasterLooter: Dein aktueller Strichstand: %d.", tonumber(value) or 0))
end

function WhisperQueries:HandleWhisper(message, sender)
    local received = string.upper(tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local command = COMMANDS[received]
    if not command then return false end
    if not self:IsActiveMasterLooter() or not self:IsGroupMember(sender) then return false end
    local current = type(GetTime) == "function" and GetTime() or 0
    local requestKey = baseName(sender) .. ":" .. command
    if current - (tonumber(self.lastRequest[requestKey]) or -1000) < 0.5 then return false end
    self.lastRequest[requestKey] = current
    if command == "SR" then self:ReplySoftRes(sender) else self:ReplyStreakList(sender) end
    GA.Events:Emit("GA_WHISPER_QUERY_RECEIVED", command, sender)
    return true
end

function WhisperQueries:AnnounceCommands()
    if type(SendChatMessage) ~= "function" then return false end
    local profile = GA.DB and type(GA.DB.GetProfile) == "function" and GA.DB:GetProfile() or nil
    if profile and profile.commandAnnouncementsEnabled == false then return false end
    local channel = "RAID"
    if GA.Announcements and type(GA.Announcements.ResolveChannel) == "function" then
        channel = GA.Announcements:ResolveChannel() or channel
    end
    local message = L("whisper.commands", "MasterLooter aktiv. Per Whisper: SR = eigene SoftRes prüfen, SL = eigenen Strichstand prüfen.")
    local ok = pcall(SendChatMessage, message, channel)
    if ok then GA.Events:Emit("GA_WHISPER_COMMANDS_ANNOUNCED", channel) end
    return ok
end

function WhisperQueries:RefreshMasterLooterState()
    local inRaid = type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0
    local inParty = type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0
    local active = (inRaid or inParty) and self:IsActiveMasterLooter() or false
    if active and not self.wasMasterLooter then self:AnnounceCommands() end
    self.wasMasterLooter = active
    return active
end

function WhisperQueries:OnInitialize()
    GA.Events:On("CHAT_MSG_WHISPER", function(_, _, message, sender) WhisperQueries:HandleWhisper(message, sender) end, self)
    for _, event in ipairs({ "PARTY_LOOT_METHOD_CHANGED", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        GA.Events:On(event, function() WhisperQueries:RefreshMasterLooterState() end, self)
        GA.Events:RegisterGameEvent(event)
    end
    GA.Events:RegisterGameEvent("CHAT_MSG_WHISPER")
    self:RefreshMasterLooterState()
    return true
end

GA:RegisterModule("WhisperQueries", WhisperQueries)
