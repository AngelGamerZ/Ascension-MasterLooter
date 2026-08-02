local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local VersionWindow = { page = 1, pageSize = 10, participants = {} }
GA.UI.VersionWindow = VersionWindow

local function ageText(lastSeen)
    local age = math.max(0, math.floor(((GetTime and GetTime()) or 0) - (tonumber(lastSeen) or 0)))
    if age < 60 then return age .. "s" end
    if age < 3600 then return math.floor(age / 60) .. "m" end
    return math.floor(age / 3600) .. "h"
end

function VersionWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterVersionWindow", UIParent)
    frame:SetWidth(630); frame:SetHeight(450); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Versionsprüfung")
    Theme:MakeMovable(frame, "versionWindow"); Theme:RestorePosition(frame, "versionWindow", "CENTER", 0, 10); Theme:RegisterForEscape(frame); self.frame = frame
    local refresh = Theme:CreateButton(frame, "Aktualisieren", 110, 25); refresh:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -44); refresh:SetScript("OnClick", function() VersionWindow:Refresh() end)
    local check = Theme:CreateButton(frame, "Gruppe prüfen", 110, 25); check:SetPoint("LEFT", refresh, "RIGHT", 8, 0); check:SetScript("OnClick", function() VersionWindow:Check() end)
    local status = Theme:CreateLabel(frame, "Noch keine Prüfung durchgeführt.", 11, Theme.colors.muted); status:SetPoint("LEFT", check, "RIGHT", 12, 0); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.status = status
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -82); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 59); Theme:ApplyInset(list)
    local headers = { { "Spieler", 12 }, { "Version", 255 }, { "Protokoll", 390 }, { "Zuletzt gesehen", 485 } }
    for _, definition in ipairs(headers) do local label = Theme:CreateLabel(list, definition[1], 11, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", definition[2], -10) end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Frame", nil, list); row:SetHeight(25); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -31 - ((index - 1) * 26)); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -31 - ((index - 1) * 26))
        row.player = Theme:CreateLabel(row, "", 11); row.player:SetPoint("LEFT", row, "LEFT", 5, 0); row.player:SetWidth(230)
        row.version = Theme:CreateLabel(row, "", 11); row.version:SetPoint("LEFT", row, "LEFT", 248, 0); row.version:SetWidth(125)
        row.protocol = Theme:CreateLabel(row, "", 11); row.protocol:SetPoint("LEFT", row, "LEFT", 383, 0); row.protocol:SetWidth(85)
        row.seen = Theme:CreateLabel(row, "", 11); row.seen:SetPoint("LEFT", row, "LEFT", 478, 0); row.seen:SetWidth(100)
        self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20); previous:SetScript("OnClick", function() VersionWindow.page = math.max(1, VersionWindow.page - 1); VersionWindow:Render() end); self.previous = previous
    local page = Theme:CreateLabel(frame, "1 / 1", 11, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); page:SetWidth(85); page:SetJustifyH("CENTER"); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0); nextButton:SetScript("OnClick", function() VersionWindow.page = math.min(VersionWindow.totalPages or 1, VersionWindow.page + 1); VersionWindow:Render() end); self.next = nextButton
    return frame
end

function VersionWindow:Render(participants)
    if not self:EnsureFrame() then return end
    if type(participants) == "table" then
        self.participants = {}
        for _, entry in pairs(participants) do if type(entry) == "table" then self.participants[#self.participants + 1] = entry end end
        table.sort(self.participants, function(left, right) return string.lower(tostring(left.name or "")) < string.lower(tostring(right.name or "")) end)
    end
    self.totalPages = math.max(1, math.ceil(#self.participants / self.pageSize)); self.page = math.max(1, math.min(self.page, self.totalPages)); local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local entry = self.participants[offset + index]
        if entry then row.player:SetText(entry.name or "?"); row.version:SetText(entry.version or "?"); row.protocol:SetText(tostring(entry.protocol or "?")); row.seen:SetText(ageText(entry.lastSeen)); row:Show() else row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages .. "  (" .. #self.participants .. ")")
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
end

function VersionWindow:Refresh()
    local manager = GA.VersionCheck; if not manager or type(manager.GetParticipants) ~= "function" then self.status:SetText("VersionCheck nicht verfügbar."); self.status:SetTextColor(unpack(Theme.colors.red)); return end
    local ok, participants = pcall(manager.GetParticipants, manager, true)
    if ok then self:Render(participants); self.status:SetText("Liste aktualisiert."); self.status:SetTextColor(unpack(Theme.colors.green)) end
end

function VersionWindow:Check()
    local manager = GA.VersionCheck; if not manager or type(manager.Broadcast) ~= "function" then return end
    local ok, sent, err = pcall(manager.Broadcast, manager, true)
    if ok and sent then self.status:SetText("Prüfung gesendet – Antworten werden live ergänzt."); self.status:SetTextColor(unpack(Theme.colors.green))
    else self.status:SetText(tostring(err or sent or "Prüfung fehlgeschlagen.")); self.status:SetTextColor(unpack(Theme.colors.red)) end
end

function VersionWindow:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show() end end
function VersionWindow:Hide() if self.frame then self.frame:Hide() end end
function VersionWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function VersionWindow:OnInitialize()
    self:EnsureFrame(); GA.Events:On("GA_VERSION_LIST_UPDATED", function(_, _, participants) VersionWindow:Render(participants) end, self); return true
end
GA:RegisterModule("VersionWindow", VersionWindow)
