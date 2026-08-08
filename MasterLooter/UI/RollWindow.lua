local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA
GA.UI = GA.UI or {}

local Theme = GA.UI.Theme
local RollWindow = { WIDTH = 520, HEIGHT = 84 }
GA.UI.RollWindow = RollWindow

local function now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function baseName(name)
    return type(name) == "string" and string.lower(string.match(name, "^[^-]+") or name) or ""
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
    frame:SetWidth(self.WIDTH)
    frame:SetHeight(self.HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:MakeMovable(frame, "rollWidgetGargulV1")
    Theme:RestorePosition(frame, "rollWidgetGargulV1", "BOTTOM", 0, 125)
    Theme:RegisterForEscape(frame)
    self.frame = frame
    frame:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then frame:Hide() end end)

    local itemStrip = frame:CreateTexture(nil, "BACKGROUND")
    itemStrip:SetTexture(0.05, 0.22, 0.07, 0.78)
    itemStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -37)
    itemStrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

    local status = Theme:CreateLabel(frame, "Bitte wähle deine Roll-Kategorie.", 10, Theme.colors.muted)
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    status:SetWidth(228)
    status:SetJustifyH("LEFT")
    self.status = status

    local icon = CreateFrame("Button", nil, frame)
    icon:SetWidth(32)
    icon:SetHeight(32)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -42)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon)
    icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:EnableMouse(false)
    self.icon = icon

    local item = Theme:CreateLabel(frame, "Warte auf ein Item ...", 12)
    item:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1)
    item:SetPoint("RIGHT", frame, "RIGHT", -58, 0)
    item:SetHeight(16)
    item:SetJustifyV("TOP")
    item:SetWordWrap(false)
    self.item = item

    local note = Theme:CreateLabel(frame, "", 10, Theme.colors.muted)
    note:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -16)
    note:SetPoint("RIGHT", frame, "RIGHT", -58, 0)
    note:SetHeight(14)
    note:SetWordWrap(false)
    self.note = note

    local itemInteraction = CreateFrame("Button", nil, frame)
    itemInteraction:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 3)
    itemInteraction:SetWidth(224)
    itemInteraction:SetHeight(38)
    itemInteraction:RegisterForClicks("LeftButtonUp")
    itemInteraction:SetScript("OnClick", function(_, button) RollWindow:HandleItemClick(button) end)
    self.itemInteraction = itemInteraction

    local timer = Theme:CreateLabel(frame, "0:00", 12, Theme.colors.gold)
    timer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -48)
    timer:SetWidth(48)
    timer:SetJustifyH("RIGHT")
    self.timer = timer

    local buttons = {
        { key = "MS", text = "MS", x = 244, width = 86 },
        { key = "OS", text = "OS", x = 334, width = 86 },
        { key = "PASS", text = "Passen", x = 424, width = 86 },
    }
    self.buttons = {}
    for _, definition in ipairs(buttons) do
        local button = Theme:CreateButton(frame, definition.text, definition.width, 24)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", definition.x, -6)
        button:SetScript("OnClick", function() RollWindow:Submit(definition.key) end)
        if button.GetFontString and button:GetFontString() then button:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end
        self.buttons[definition.key] = button
    end

    frame:SetScript("OnUpdate", function(_, elapsed) RollWindow:OnUpdate(elapsed) end)
    return frame
end

function RollWindow:HandleItemClick(mouseButton)
    if type(self.itemLink) ~= "string" or self.itemLink == "" then return false end
    if type(HandleModifiedItemClick) == "function" then
        local ok, handled = pcall(HandleModifiedItemClick, self.itemLink, mouseButton or "LeftButton")
        return ok and handled ~= false
    end
    if type(IsControlKeyDown) == "function" and IsControlKeyDown() and type(DressUpItemLink) == "function" then
        return pcall(DressUpItemLink, self.itemLink)
    end
    return false
end

function RollWindow:SetButtonsEnabled(enabled)
    if not self.buttons then return end
    for _, button in pairs(self.buttons) do
        if enabled then button:Enable() else button:Disable() end
    end
end

function RollWindow:IsCurrentSession(subject)
    if type(subject) ~= "table" or self.sessionId == nil then return false end
    local id = value(subject, "id", "sessionId", "sessionID", "rollId")
    return id ~= nil and tostring(id) == tostring(self.sessionId)
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
    self.osRollMaximum = math.max(2, math.min(99, math.floor(tonumber(value(session, "osRollMaximum", "osMaximum")) or 99)))
    if self.buttons and self.buttons.MS then self.buttons.MS:SetText("MS (/100)") end
    if self.buttons and self.buttons.OS then self.buttons.OS:SetText("OS (/" .. tostring(self.osRollMaximum) .. ")") end
    self.endsAt = tonumber(value(session, "endsAt", "endTime", "expiresAt")) or (now() + duration)
    self.elapsed = 0

    self.item:SetText(self.itemLink or value(session, "itemName", "name") or "Unbekanntes Item")
    self.note:SetText(value(session, "note", "message") or "")
    local texture = value(session, "texture", "icon") or value(session.item, "texture", "icon")
    if not texture and self.itemLink then
        texture = select(10, GetItemInfo(self.itemLink))
    end
    self.icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    Theme:SetItemTooltip(self.itemInteraction or self.icon, self.itemLink)
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
    if choice == "PASS" then
        local ok, result = type(manager) == "table" and type(manager.Pass) == "function" and
            pcall(manager.Pass, manager, self.sessionId)
        if ok and result ~= nil and result ~= false then
            self.status:SetText("Du hast gepasst.")
            self.status:SetTextColor(unpack(Theme.colors.green))
            self:SetButtonsEnabled(false)
        else
            self.status:SetText("Passen konnte nicht gesendet werden.")
            self.status:SetTextColor(unpack(Theme.colors.red))
        end
        return
    end
    local maximum = choice == "MS" and 100 or (choice == "OS" and self.osRollMaximum)
    if not maximum or type(RandomRoll) ~= "function" then
        self.status:SetText("Die /roll-Funktion ist nicht verfügbar.")
        self.status:SetTextColor(unpack(Theme.colors.red))
        return
    end
    local ok = pcall(RandomRoll, 1, maximum)
    if ok then
        self.status:SetText("/roll " .. tostring(maximum) .. " ausgeführt – warte auf das Ergebnis.")
        self.status:SetTextColor(unpack(Theme.colors.green))
        self:SetButtonsEnabled(false)
    else
        self.status:SetText("Der öffentliche Wurf konnte nicht ausgeführt werden.")
        self.status:SetTextColor(unpack(Theme.colors.red))
    end
end

function RollWindow:EndSession(reason, subject)
    if not self.frame or not self.session then return end
    if subject and not self:IsCurrentSession(subject) then return false end
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
    return true
end

function RollWindow:Confirm(participant, session)
    if type(participant) ~= "table" or not self.frame then return end
    if session and not self:IsCurrentSession(session) then return false end
    local name = value(participant, "name", "player", "playerName")
    local me = type(UnitName) == "function" and UnitName("player") or nil
    if name and me and string.lower(string.match(name, "^[^-]+") or name) ~= string.lower(string.match(me, "^[^-]+") or me) then return end
    local choice = value(participant, "choice", "category") or "-"
    local roll = tonumber(value(participant, "roll", "value")) or 0
    self.status:SetText(choice == "PASS" and "Passen wurde bestätigt." or ("Bestätigt: " .. choice .. " (" .. roll .. ")"))
    self.status:SetTextColor(unpack(Theme.colors.green))
    self:SetButtonsEnabled(false)
    return true
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
        local state, action, participant
        if select(2, ...) == "GA_ROLL_SESSION_UPDATED" then state, action, participant = select(3, ...), select(4, ...), select(5, ...)
        elseif select(1, ...) == "GA_ROLL_SESSION_UPDATED" then state, action, participant = select(2, ...), select(3, ...), select(4, ...) end
        if action == "ROLL_ACK" then RollWindow:Confirm(participant, state) end
    end)
    registerMessage("GA_PUBLIC_ROLL_SEEN", function(...)
        local state, participant
        if select(2, ...) == "GA_PUBLIC_ROLL_SEEN" then state, participant = select(3, ...), select(4, ...)
        elseif select(1, ...) == "GA_PUBLIC_ROLL_SEEN" then state, participant = select(2, ...), select(3, ...) end
        if state and participant and tostring(value(state, "id", "sessionId")) == tostring(RollWindow.sessionId) and
            baseName(value(participant, "name", "player")) == baseName(UnitName("player")) then
            RollWindow:Confirm(participant)
        end
    end)
    registerMessage("GA_ROLL_SESSION_STOPPED", function(...)
        local state, reason = eventArguments("GA_ROLL_SESSION_STOPPED", ...)
        RollWindow:EndSession(reason, state)
    end)
    registerMessage("GA_ROLL_SESSION_ENDED", function(...)
        local state, reason = eventArguments("GA_ROLL_SESSION_ENDED", ...)
        RollWindow:EndSession(reason, state)
    end)
    registerMessage("GA_ROLL_SESSION_AWARDED", function(...)
        local data = eventArgument("GA_ROLL_SESSION_AWARDED", ...)
        local winner = type(data) == "table" and value(data, "winner", "player") or data
        RollWindow:EndSession(winner and ("Vergeben an " .. winner) or "Item wurde vergeben.", data)
    end)
    registerMessage("GA_ROLL_RESULT", function(...)
        local data = eventArgument("GA_ROLL_RESULT", ...)
        local winner = type(data) == "table" and value(data, "winner", "player") or nil
        RollWindow:EndSession(winner and ("Vergeben an " .. winner) or "Item wurde vergeben.", data)
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
