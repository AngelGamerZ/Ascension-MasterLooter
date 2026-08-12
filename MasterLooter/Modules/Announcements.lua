-- German group announcements with channel and authority safeguards.
local _, GA = ...

local Announcements = { lastSent = -1000, minimumInterval = 0.5 }
GA.Announcements = Announcements
local DEFAULTS = { enabled = true, rollStart = true, rollStop = true, countdown = true, award = true, channel = "RAID_WARNING" }
local CHANNEL_OPTIONS = { "AUTO", "RAID_WARNING", "RAID", "PARTY", "SAY", "YELL", "GUILD", "OFFICER" }
local CHANNELS = {}
for _, channel in ipairs(CHANNEL_OPTIONS) do CHANNELS[channel] = true end

local function L(key, fallback, ...)
    if type(GA.L) == "function" then return GA:L(key, ...) end
    return select("#", ...) > 0 and string.format(fallback, ...) or fallback
end

local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end

local function isOwner(state)
    return type(state) == "table" and baseName(state.owner) == baseName(UnitName("player"))
end

local function canRaidWarn()
    if not GA.Compat:IsInRaid() then return false end
    if type(UnitIsRaidOfficer) == "function" and UnitIsRaidOfficer("player") then return true end
    if type(UnitIsPartyLeader) == "function" and UnitIsPartyLeader("player") then return true end
    if type(IsRaidLeader) == "function" and IsRaidLeader() then return true end
    if type(IsRaidOfficer) == "function" and IsRaidOfficer() then return true end
    if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" and type(UnitName) == "function" then
        local player = baseName(UnitName("player"))
        for index = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(index)
            if baseName(name) == player then return (tonumber(rank) or 0) > 0 end
        end
    end
    return false
end

function Announcements:GetConfig()
    local profile = GA.DB:GetProfile()
    profile.announcements = profile.announcements or {}
    for key, value in pairs(DEFAULTS) do
        if profile.announcements[key] == nil then profile.announcements[key] = value end
    end
    if not profile.announcements.raidWarningDefaultV1 then
        profile.announcements.channel = self:NormalizeChannel(profile.announcements.channel or profile.announceChannel) or "RAID_WARNING"
        profile.announcements.raidWarningDefaultV1 = true
    end
    profile.announcements.channel = self:NormalizeChannel(profile.announcements.channel) or DEFAULTS.channel
    return profile.announcements
end

function Announcements:GetChannelOptions()
    local result = {}
    for index, channel in ipairs(CHANNEL_OPTIONS) do result[index] = channel end
    return result
end

function Announcements:NormalizeChannel(value)
    value = string.upper(tostring(value or "AUTO"))
    value = string.gsub(value, "[%s%-]+", "_")
    local aliases = {
        GROUP = "PARTY", GROUP_CHAT = "PARTY", PARTY_CHAT = "PARTY",
        RAIDWARNING = "RAID_WARNING", RW = "RAID_WARNING",
    }
    value = aliases[value] or value
    return CHANNELS[value] and value or nil
end

function Announcements:SetOption(key, value)
    if DEFAULTS[key] == nil then return false, "unknown announcement option" end
    if key == "channel" then
        value = self:NormalizeChannel(value)
        if not value then return false, "invalid announcement channel" end
    else value = value and true or false end
    self:GetConfig()[key] = value
    return true
end

function Announcements:ResolveChannel(requested)
    requested = self:NormalizeChannel(requested or self:GetConfig().channel) or "AUTO"
    local inRaid = GA.Compat:IsInRaid()
    local inGroup = GA.Compat:IsInGroup()
    if requested == "SAY" or requested == "YELL" then return requested end
    if requested == "GUILD" or requested == "OFFICER" then
        if type(IsInGuild) == "function" and not IsInGuild() then return nil end
        return requested
    end
    if requested == "AUTO" then
        if inRaid then return canRaidWarn() and "RAID_WARNING" or "RAID" end
        return inGroup and "PARTY" or nil
    end
    if requested == "RAID_WARNING" then
        if inRaid then return canRaidWarn() and "RAID_WARNING" or "RAID" end
        return inGroup and "PARTY" or nil
    end
    if requested == "RAID" then
        if inRaid then return "RAID" end
        return inGroup and "PARTY" or nil
    end
    if requested == "PARTY" then return inGroup and "PARTY" or nil end
    return nil
end

local function utf8Truncate(value, limit)
    if #value <= limit then return value end
    local last = limit
    while last > 0 and string.byte(value, last) >= 128 and string.byte(value, last) < 192 do last = last - 1 end
    return string.sub(value, 1, math.max(1, last - 1)) .. "..."
end

local function itemDescription(state)
    local link = state and state.itemLink
    if type(link) ~= "string" then return L("announcement.unknown_item", "unbekanntes Item") end
    if #link <= 100 then return link end
    local name = type(GetItemInfo) == "function" and GetItemInfo(link)
    return name and utf8Truncate(name, 80) or L("announcement.item_number", "Item #%s", tostring(GA.Compat:GetItemID(link) or "?"))
end

function Announcements:Send(message, channel)
    if not self:GetConfig().enabled then return false, "announcements disabled" end
    channel = self:ResolveChannel(channel)
    if not channel then return false, "not in a group" end
    local current = (GetTime and GetTime()) or 0
    if current - self.lastSent < self.minimumInterval then return false, "rate limited" end
    message = utf8Truncate(tostring(message or ""), 240)
    if type(SendChatMessage) ~= "function" then return false, "SendChatMessage unavailable" end
    local ok, err = pcall(SendChatMessage, message, channel)
    if not ok then
        GA.Events:Emit("GA_ANNOUNCEMENT_FAILED", message, channel, err)
        return false, tostring(err)
    end
    self.lastSent = current
    GA.Events:Emit("GA_ANNOUNCEMENT_SENT", message, channel)
    return true
end

local STOP_REASON = { TIMEOUT = "timeout", STOPPED = "stopped", CANCELLED = "cancelled", AWARDED = "awarded" }

function Announcements:OnRollStarted(state)
    local config = self:GetConfig()
    if config.rollStart and isOwner(state) then
        self:Send(L("announcement.roll_started", "Roll für %s gestartet – %d Sekunden. /roll 100 für MS. /roll %d für OS. /roll 50 für Transmog.",
            itemDescription(state), tonumber(state.duration) or 30, tonumber(state.osRollMaximum) or 99))
    end
    if isOwner(state) then
        self.activeRoll = state
        self.lastCountdownSecond = math.ceil(tonumber(state.duration) or 30)
    end
end

function Announcements:OnRollEnded(state, reason)
    local config = self:GetConfig()
    if config.rollStop and isOwner(state) and reason ~= "AWARDED" then
        local reasonKey = STOP_REASON[reason]
        self:Send(reasonKey and L("announcement." .. reasonKey, "Die Verteilung wurde beendet.") or
            L("announcement.ended_reason", "Die Verteilung wurde beendet: %s", tostring(reason or "unbekannt")))
    end
    if self.activeRoll and state and self.activeRoll.id == state.id then
        self.activeRoll, self.lastCountdownSecond = nil, nil
    end
end

local function shouldAnnounceSecond(second)
    if second < 1 then return false end
    if second <= 10 then return true end
    return second % 10 == 0
end

function Announcements:Tick()
    local state = self.activeRoll
    if not state or state.status ~= "ACTIVE" or not isOwner(state) then return end
    if not self:GetConfig().countdown then return end
    local current = (GetTime and GetTime()) or 0
    local remaining = math.max(0, math.ceil((tonumber(state.expiresAt) or current) - current))
    if remaining == self.lastCountdownSecond then return end
    self.lastCountdownSecond = remaining
    if shouldAnnounceSecond(remaining) then
        local key = remaining == 1 and "announcement.countdown.one" or "announcement.countdown.many"
        self:Send(L(key, remaining == 1 and "Noch %d Sekunde für %s." or "Noch %d Sekunden für %s.",
            remaining, itemDescription(state)))
    end
end

function Announcements:OnAward(result, state)
    local config = self:GetConfig()
    if config.award and isOwner(state) and type(result) == "table" then
        local item = result.itemLink or (state and state.itemLink) or L("announcement.default_item", "das Item")
        local description = #item <= 180 and item or itemDescription(state)
        local suffix = result.choice and result.choice ~= "" and (" (" .. result.choice ..
            ((tonumber(result.roll) or 0) > 0 and (", " .. tostring(result.roll)) or "") .. ")") or ""
        self:Send(L("announcement.award", "%s geht an %s%s.", description,
            tostring(result.winner or L("announcement.unknown_player", "unbekannt")), suffix))
    end
end

function Announcements:OnInitialize()
    self:GetConfig()
    GA.Events:On("GA_ROLL_SESSION_STARTED", function(_, _, state) Announcements:OnRollStarted(state) end, self)
    GA.Events:On("GA_ROLL_SESSION_ENDED", function(_, _, state, reason) Announcements:OnRollEnded(state, reason) end, self)
    GA.Events:On("GA_ROLL_RESULT", function(_, _, result, state) Announcements:OnAward(result, state) end, self)
    self.frame = self.frame or CreateFrame("Frame")
    local elapsed = 0
    self.frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then elapsed = 0; Announcements:Tick() end
    end)
    return true
end

GA:RegisterModule("Announcements", Announcements)
