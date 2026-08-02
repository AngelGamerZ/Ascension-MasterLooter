local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA
GA.UI = GA.UI or {}

local Theme = GA.UI.Theme
local RollWindow = {}
GA.UI.RollWindow = RollWindow

local function now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function value(source, ...)
    if type(source) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if source[key] ~= nil then return source[key] end
    end
end

local function registerMessage(event, callback)
    local buses = { GA.Events, GA.EventBus, GA }
    for _, bus in ipairs(buses) do
        if type(bus) == "table" then
            local methods = { "RegisterCallback", "RegisterMessage", "On", "Subscribe" }
            for _, method in ipairs(methods) do
                if type(bus[method]) == "function" then
                    local ok = pcall(bus[method], bus, event, callback)
                    if ok then return true end
                end
            end
        end
    end
    return false
end

local function eventArgument(expected, ...)
    if select(2, ...) == expected then return select(3, ...) end
    if select(1, ...) == expected then return select(2, ...) end
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "table" then return candidate end
    end
    return select(2, ...) or select(1, ...)
end

local function eventArguments(expected, ...)
    if select(2, ...) == expected then return select(3, ...), select(4, ...) end
    if select(1, ...) == expected then return select(2, ...), select(3, ...) end
    return eventArgument(expected, ...), nil
end

function RollWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterRollWindow", UIParent)
    frame:SetWidth(560)
    frame:SetHeight(124)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "Beuteverteilung")
    Theme:MakeMovable(frame, "rollWindowCompactV3")
    Theme:RestorePosition(frame, "rollWindowCompactV3", "BOTTOM", 0, 105)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local icon = CreateFrame("Button", nil, frame)
    icon:SetWidth(32)
    icon:SetHeight(32)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -37)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.icon = icon

    local item = Theme:CreateLabel(frame, "Warte auf ein Item ...", 12)
    item:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    item:SetPoint("RIGHT", frame, "RIGHT", -80, 0)
    item:SetHeight(16)
    item:SetJustifyV("TOP")
    item:SetWordWrap(false)
    self.item = item

    local note = Theme:CreateLabel(frame, "", 10, Theme.colors.muted)
    note:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -18)
    note:SetPoint("RIGHT", frame, "RIGHT", -80, 0)
    note:SetHeight(14)
    note:SetWordWrap(false)
    self.note = note

    local timerCaption = Theme:CreateLabel(frame, "Verbleibend", 11, Theme.colors.muted)
    timerCaption:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -36)
    timerCaption:SetWidth(65)
    timerCaption:SetJustifyH("RIGHT")
    local timer = Theme:CreateLabel(frame, "0:00", 12, Theme.colors.gold)
    timer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -53)
    timer:SetWidth(65)
    timer:SetJustifyH("RIGHT")
    self.timer = timer

    local buttons = {
        { key = "MS", text = "MS", x = 18 },
        { key = "OS", text = "OS", x = 112 },
        { key = "PASS", text = "Passen", x = 206 },
    }
    self.buttons = {}
    for _, definition in ipairs(buttons) do
        local button = Theme:CreateButton(frame, definition.text, 90, 24)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", definition.x, 13)
        button:SetScript("OnClick", function() RollWindow:Submit(definition.key) end)
        self.buttons[definition.key] = button
    end

    local status = Theme:CreateLabel(frame, "", 12, Theme.colors.muted)
    status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 306, 18)
    status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    status:SetJustifyH("RIGHT")
    self.status = status

    frame:SetScript("OnUpdate", function(_, elapsed) RollWindow:OnUpdate(elapsed) end)
    return frame
end

function RollWindow:SetButtonsEnabled(enabled)
    if not self.buttons then return end
    for _, button in pairs(self.buttons) do
        if enabled then button:Enable() else button:Disable() end
    end
end

function RollWindow:ShowSession(session)
    if type(session) ~= "table" then return end
    local profile = GA.DB and GA.DB:GetProfile()
    local frame = self:EnsureFrame()
    if not frame then return end

    self.session = session
    self.sessionId = value(session, "id", "sessionId", "rollId")
    self.itemLink = value(session, "itemLink", "link") or value(session.item, "link", "itemLink")
    local duration = tonumber(value(session, "duration", "seconds", "timeout")) or 30
    self.endsAt = tonumber(value(session, "endsAt", "endTime", "expiresAt")) or (now() + duration)
    self.elapsed = 0

    self.item:SetText(self.itemLink or value(session, "itemName", "name") or "Unbekanntes Item")
    self.note:SetText(value(session, "note", "message") or "")
    local texture = value(session, "texture", "icon") or value(session.item, "texture", "icon")
    if not texture and self.itemLink then
        texture = select(10, GetItemInfo(self.itemLink))
    end
    self.icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    Theme:SetItemTooltip(self.icon, self.itemLink)
    self.status:SetText("Bitte wähle deine Roll-Kategorie.")
    self.status:SetTextColor(unpack(Theme.colors.muted))
    self:SetButtonsEnabled(true)
    self:UpdateTimer()
    if profile and profile.autoOpenRollWindow == false then return end
    frame:Show()
    if profile and profile.sound and type(PlaySound) == "function" then pcall(PlaySound, "igQuestListOpen") end
end

function RollWindow:Submit(choice)
    if not self.session then return end
    local manager = GA.RollSession
    local ok, result
    if type(manager) == "table" then
        if choice == "PASS" and type(manager.Pass) == "function" then
            ok, result = pcall(manager.Pass, manager, self.sessionId)
        elseif type(manager.SubmitRoll) == "function" then
            ok, result = pcall(manager.SubmitRoll, manager, self.sessionId, choice)
        end
    end

    if ok and result ~= nil and result ~= false then
        self.status:SetText(choice == "PASS" and "Du hast gepasst." or ("Gesendet: " .. choice))
        self.status:SetTextColor(unpack(Theme.colors.green))
        self:SetButtonsEnabled(false)
    else
        self.status:SetText("Antwort konnte nicht gesendet werden.")
        self.status:SetTextColor(unpack(Theme.colors.red))
    end
end

function RollWindow:EndSession(reason)
    if not self.frame or not self.session then return end
    self.endsAt = nil
    self:SetButtonsEnabled(false)
    local messages = {
        AWARDED = "Item wurde vergeben.",
        STOPPED = "Die Verteilung wurde gestoppt.",
        EXPIRED = "Zeit abgelaufen.",
        TIMEOUT = "Zeit abgelaufen.",
        TIMEOUT_LOCAL = "Zeit abgelaufen.",
    }
    self.status:SetText(messages[reason] or (type(reason) == "string" and reason) or "Die Verteilung wurde beendet.")
    self.status:SetTextColor(unpack(Theme.colors.muted))
    if reason == "TIMEOUT" or reason == "TIMEOUT_LOCAL" or reason == "EXPIRED" then self.frame:Hide() end
end

function RollWindow:Confirm(participant)
    if type(participant) ~= "table" or not self.frame then return end
    local name = value(participant, "name", "player", "playerName")
    local me = type(UnitName) == "function" and UnitName("player") or nil
    if name and me and string.lower(string.match(name, "^[^-]+") or name) ~= string.lower(string.match(me, "^[^-]+") or me) then return end
    local choice = value(participant, "choice", "category") or "-"
    local roll = tonumber(value(participant, "roll", "value")) or 0
    self.status:SetText(choice == "PASS" and "Passen wurde bestätigt." or ("Bestätigt: " .. choice .. " (" .. roll .. ")"))
    self.status:SetTextColor(unpack(Theme.colors.green))
    self:SetButtonsEnabled(false)
end


function RollWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function RollWindow:Show()
    local frame = self:EnsureFrame()
    if frame and self.session then frame:Show() end
end

function RollWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function RollWindow:UpdateTimer()
    if not self.endsAt then return end
    local remaining = self.endsAt - now()
    self.timer:SetText(Theme:FormatTime(remaining))
    if remaining <= 0 then
        self.endsAt = nil
        self:SetButtonsEnabled(false)
        self.status:SetText("Zeit abgelaufen.")
        self.status:SetTextColor(unpack(Theme.colors.red))
        self.frame:Hide()
    end
end

function RollWindow:OnUpdate(elapsed)
    if not self.endsAt or not self.frame:IsShown() then return end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.1 then return end
    self.elapsed = 0
    self:UpdateTimer()
end

function RollWindow:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:EnsureFrame()
    registerMessage("GA_ROLL_SESSION_STARTED", function(...)
        RollWindow:ShowSession(eventArgument("GA_ROLL_SESSION_STARTED", ...))
    end)
    registerMessage("GA_ROLL_SESSION_UPDATED", function(...)
        local action, participant
        if select(2, ...) == "GA_ROLL_SESSION_UPDATED" then action, participant = select(4, ...), select(5, ...)
        elseif select(1, ...) == "GA_ROLL_SESSION_UPDATED" then action, participant = select(3, ...), select(4, ...) end
        if action == "ROLL_ACK" then RollWindow:Confirm(participant) end
    end)
    registerMessage("GA_ROLL_SESSION_STOPPED", function(...)
        local _, reason = eventArguments("GA_ROLL_SESSION_STOPPED", ...)
        RollWindow:EndSession(reason)
    end)
    registerMessage("GA_ROLL_SESSION_ENDED", function(...)
        local _, reason = eventArguments("GA_ROLL_SESSION_ENDED", ...)
        RollWindow:EndSession(reason)
    end)
    registerMessage("GA_ROLL_SESSION_AWARDED", function(...)
        local data = eventArgument("GA_ROLL_SESSION_AWARDED", ...)
        local winner = type(data) == "table" and value(data, "winner", "player") or data
        RollWindow:EndSession(winner and ("Vergeben an " .. winner) or "Item wurde vergeben.")
    end)
    registerMessage("GA_ROLL_RESULT", function(...)
        local data = eventArgument("GA_ROLL_RESULT", ...)
        local winner = type(data) == "table" and value(data, "winner", "player") or nil
        RollWindow:EndSession(winner and ("Vergeben an " .. winner) or "Item wurde vergeben.")
    end)
end


RollWindow.OnInitialize = RollWindow.Initialize
RollWindow.OnEnable = RollWindow.Initialize
if type(GA.RegisterModule) == "function" then
    GA:RegisterModule("RollWindow", RollWindow)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() RollWindow:Initialize() end)
