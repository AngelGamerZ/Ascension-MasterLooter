-- German group announcements with channel and authority safeguards.
local _, GA = ...

local Announcements = { lastSent = -1000, minimumInterval = 0.5 }
GA.Announcements = Announcements
local DEFAULTS = { enabled = true, rollStart = true, rollStop = true, countdown = true, award = true, channel = "AUTO" }

local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
end

local function isOwner(state)
    return type(state) == "table" and baseName(state.owner) == baseName(UnitName("player"))
end

local function canRaidWarn()
    if not GA.Compat:IsInRaid() then return false end
    if type(UnitIsRaidOfficer) == "function" and UnitIsRaidOfficer("player") then return true end
    return type(UnitIsPartyLeader) == "function" and UnitIsPartyLeader("player") or false
end

function Announcements:GetConfig()
    local profile = GA.DB:GetProfile()
    profile.announcements = profile.announcements or {}
    for key, value in pairs(DEFAULTS) do
        if profile.announcements[key] == nil then profile.announcements[key] = value end
    end
    return profile.announcements
end

function Announcements:SetOption(key, value)
    if DEFAULTS[key] == nil then return false, "unknown announcement option" end
    if key == "channel" then
        value = string.upper(tostring(value or "AUTO"))
        if value ~= "AUTO" and value ~= "RAID" and value ~= "PARTY" and value ~= "RAID_WARNING" then
            return false, "invalid announcement channel"
        end
    else value = value and true or false end
    self:GetConfig()[key] = value
    return true
end

function Announcements:ResolveChannel(requested)
    if not GA.Compat:IsInGroup() then return nil end
    requested = string.upper(requested or self:GetConfig().channel or "AUTO")
    if GA.Compat:IsInRaid() then
        if requested == "RAID_WARNING" and canRaidWarn() then return "RAID_WARNING" end
        return "RAID"
    end
    return "PARTY"
end

local function utf8Truncate(value, limit)
    if #value <= limit then return value end
    local last = limit
    while last > 0 and string.byte(value, last) >= 128 and string.byte(value, last) < 192 do last = last - 1 end
    return string.sub(value, 1, math.max(1, last - 1)) .. "..."
end

local function itemDescription(state)
    local link = state and state.itemLink
    if type(link) ~= "string" then return "unbekanntes Item" end
    if #link <= 180 then return link end
    local name = type(GetItemInfo) == "function" and GetItemInfo(link)
    return name or ("Item #" .. tostring(GA.Compat:GetItemID(link) or "?"))
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

local STOP_REASON = {
    TIMEOUT = "Die Rollzeit ist abgelaufen.", STOPPED = "Die Verteilung wurde beendet.",
    CANCELLED = "Die Verteilung wurde abgebrochen.", AWARDED = "Die Verteilung ist abgeschlossen.",
}

function Announcements:OnRollStarted(state)
    local config = self:GetConfig()
    if config.rollStart and isOwner(state) then
        self:Send("Roll für " .. itemDescription(state) .. " gestartet - " .. tostring(state.duration or 30) ..
            " Sekunden. Bitte im MasterLooter-Fenster wählen.")
    end
    if isOwner(state) then
        self.activeRoll = state
        self.lastCountdownSecond = math.ceil(tonumber(state.duration) or 30)
    end
end

function Announcements:OnRollEnded(state, reason)
    local config = self:GetConfig()
    if config.rollStop and isOwner(state) and reason ~= "AWARDED" then
        self:Send(STOP_REASON[reason] or ("Die Verteilung wurde beendet: " .. tostring(reason or "unbekannt")))
    end
    if self.activeRoll and state and self.activeRoll.id == state.id then
        self.activeRoll, self.lastCountdownSecond = nil, nil
    end
end

local function shouldAnnounceSecond(second)
    if second < 1 then return false end
    if second <= 10 then return true end
    if second == 15 or second == 20 then return true end
    return second >= 30 and math.mod(second, 30) == 0
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
        self:Send("Noch " .. tostring(remaining) .. " Sekunde" .. (remaining == 1 and "" or "n") ..
            " für " .. itemDescription(state) .. ".")
    end
end

function Announcements:OnAward(result, state)
    local config = self:GetConfig()
    if config.award and isOwner(state) and type(result) == "table" then
        local item = result.itemLink or (state and state.itemLink) or "das Item"
        local description = #item <= 180 and item or itemDescription(state)
        local suffix = result.choice and result.choice ~= "" and (" (" .. result.choice ..
            ((tonumber(result.roll) or 0) > 0 and (", " .. tostring(result.roll)) or "") .. ")") or ""
        self:Send(description .. " geht an " .. tostring(result.winner or "unbekannt") .. suffix .. ".")
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
