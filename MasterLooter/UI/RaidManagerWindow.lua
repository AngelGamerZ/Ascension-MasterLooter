local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local RaidManagerWindow = { page = 1, pageSize = 10, roster = {} }
GA.UI.RaidManagerWindow = RaidManagerWindow

local function field(source, ...)
    if type(source) ~= "table" then return nil end
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if source[key] ~= nil then return source[key] end
    end
end

local function normalizeRoster(source)
    source = field(source, "roster", "players", "members") or source
    local result = {}
    for key, player in pairs(type(source) == "table" and source or {}) do
        if type(player) == "table" then
            result[#result + 1] = {
                name = field(player, "name", "player", "playerName") or (type(key) == "string" and key) or "?",
                group = tonumber(field(player, "group", "subgroup", "raidGroup")) or 1,
                rank = field(player, "rank", "raidRank", "role") or 0,
                online = field(player, "online", "isOnline") ~= false and field(player, "online", "isOnline") ~= 0,
                class = field(player, "class", "classFile"),
                raw = player,
            }
        elseif type(player) == "string" then
            result[#result + 1] = { name = player, group = 1, rank = 0, online = true }
        end
    end
    table.sort(result, function(left, right)
        if left.group ~= right.group then return left.group < right.group end
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

local function rankText(rank)
    if type(rank) == "string" then return rank end
    rank = tonumber(rank) or 0
    if rank >= 2 then return "Leiter" end
    if rank == 1 then return "Assistent" end
    return "Mitglied"
end

function RaidManagerWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterRaidManagerWindow", UIParent)
    frame:SetWidth(700); frame:SetHeight(540); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Raid-Verwaltung")
    Theme:MakeMovable(frame, "raidManagerWindow"); Theme:RestorePosition(frame, "raidManagerWindow", "CENTER", 0, 10); Theme:RegisterForEscape(frame)
    self.frame = frame

    local inviteLabel = Theme:CreateLabel(frame, "Spieler einladen", 11, Theme.colors.gold); inviteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -47)
    local invite = Theme:CreateEditBox(frame, 245, 24); invite:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -65); self.inviteEdit = invite
    local inviteButton = Theme:CreateButton(frame, "Einladen", 100, 25); inviteButton:SetPoint("LEFT", invite, "RIGHT", 8, 0); inviteButton:SetScript("OnClick", function() RaidManagerWindow:Invite() end)
    invite:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RaidManagerWindow:Invite() end)
    local refresh = Theme:CreateButton(frame, "Roster laden", 110, 25); refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -65); refresh:SetScript("OnClick", function() RaidManagerWindow:RequestRefresh() end)

    local status = Theme:CreateLabel(frame, "Bereit.", 11, Theme.colors.muted); status:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -101); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.status = status
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -126); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 112); Theme:ApplyInset(list); self.list = list
    local headers = { { "Name", 12 }, { "Gruppe", 330 }, { "Rang", 415 }, { "Online", 545 } }
    for _, definition in ipairs(headers) do local label = Theme:CreateLabel(list, definition[1], 11, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", definition[2], -10) end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(25); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -31 - ((index - 1) * 26)); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -31 - ((index - 1) * 26)); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.name = Theme:CreateLabel(row, "", 11); row.name:SetPoint("LEFT", row, "LEFT", 5, 0); row.name:SetWidth(305)
        row.group = Theme:CreateLabel(row, "", 11); row.group:SetPoint("LEFT", row, "LEFT", 323, 0); row.group:SetWidth(70)
        row.rank = Theme:CreateLabel(row, "", 11); row.rank:SetPoint("LEFT", row, "LEFT", 408, 0); row.rank:SetWidth(115)
        row.online = Theme:CreateLabel(row, "", 11); row.online:SetPoint("LEFT", row, "LEFT", 538, 0); row.online:SetWidth(70)
        row:SetScript("OnClick", function() RaidManagerWindow:Select(row.entry) end)
        self.rows[index] = row
    end

    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 78); previous:SetScript("OnClick", function() RaidManagerWindow.page = math.max(1, RaidManagerWindow.page - 1); RaidManagerWindow:Render() end); self.previous = previous
    local pageLabel = Theme:CreateLabel(frame, "1 / 1", 11, Theme.colors.muted); pageLabel:SetPoint("LEFT", previous, "RIGHT", 8, 0); pageLabel:SetWidth(55); pageLabel:SetJustifyH("CENTER"); self.pageLabel = pageLabel
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", pageLabel, "RIGHT", 8, 0); nextButton:SetScript("OnClick", function() RaidManagerWindow.page = math.min(RaidManagerWindow.totalPages or 1, RaidManagerWindow.page + 1); RaidManagerWindow:Render() end); self.next = nextButton
    local selected = Theme:CreateLabel(frame, "Auswahl: –", 11); selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 52); selected:SetWidth(400); self.selectedLabel = selected

    local groupLabel = Theme:CreateLabel(frame, "Zielgruppe", 11, Theme.colors.gold); groupLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 23)
    local group = Theme:CreateEditBox(frame, 42, 24, true); group:SetPoint("LEFT", groupLabel, "RIGHT", 8, 0); group:SetText("1"); self.groupEdit = group
    local move = Theme:CreateButton(frame, "Verschieben", 105, 25); move:SetPoint("LEFT", group, "RIGHT", 8, 0); move:SetScript("OnClick", function() RaidManagerWindow:Move() end); move:Disable(); self.moveButton = move
    local promote = Theme:CreateButton(frame, "Befördern", 100, 25); promote:SetPoint("LEFT", move, "RIGHT", 8, 0); promote:SetScript("OnClick", function() RaidManagerWindow:Promote() end); promote:Disable(); self.promoteButton = promote
    local demote = Theme:CreateButton(frame, "Degradieren", 100, 25); demote:SetPoint("LEFT", promote, "RIGHT", 8, 0); demote:SetScript("OnClick", function() RaidManagerWindow:Demote() end); demote:Disable(); self.demoteButton = demote
    return frame
end

function RaidManagerWindow:SetStatus(text, isError)
    self.status:SetText(text or ""); self.status:SetTextColor(unpack(isError and Theme.colors.red or Theme.colors.green))
end

function RaidManagerWindow:Select(entry)
    if not entry then return end
    self.selected = entry; self.selectedLabel:SetText("Auswahl: " .. entry.name .. " (Gruppe " .. entry.group .. ")"); self.groupEdit:SetText(tostring(entry.group))
    self.moveButton:Enable(); self.promoteButton:Enable(); self.demoteButton:Enable()
end

function RaidManagerWindow:Render(roster)
    if not self:EnsureFrame() then return end
    if roster ~= nil then self.roster = normalizeRoster(roster) end
    self.totalPages = math.max(1, math.ceil(#self.roster / self.pageSize)); self.page = math.max(1, math.min(self.page, self.totalPages)); local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local entry = self.roster[offset + index]
        if entry then
            row.entry = entry; row.name:SetText(entry.name); row.group:SetText(tostring(entry.group)); row.rank:SetText(rankText(entry.rank)); row.online:SetText(entry.online and "Ja" or "Nein")
            row.online:SetTextColor(unpack(entry.online and Theme.colors.green or Theme.colors.muted)); row:Show()
        else row.entry = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages .. "  (" .. #self.roster .. ")")
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
end

function RaidManagerWindow:RequestRefresh()
    local manager = GA.RaidManager; if not manager then self:SetStatus("RaidManager nicht verfügbar.", true); return end
    local roster
    if type(manager.Refresh) == "function" then local ok, result, err = pcall(manager.Refresh, manager); if not ok or result == false then self:SetStatus(tostring(err or result or "Aktualisierung fehlgeschlagen."), true); return end; if type(result) == "table" then roster = result end end
    if not roster and type(manager.GetRoster) == "function" then local ok, result = pcall(manager.GetRoster, manager); if ok then roster = result end end
    self:Render(roster or {}); self:SetStatus("Roster aktualisiert.")
end

function RaidManagerWindow:Invite()
    local name = self.inviteEdit:GetText(); if not name or name == "" then self:SetStatus("Bitte einen Spielernamen eingeben.", true); return end
    local manager = GA.RaidManager; local method = manager and manager.Invite; if type(method) ~= "function" then self:SetStatus("Einladen ist nicht verfügbar.", true); return end
    local ok, result, err = pcall(method, manager, name); if ok and result ~= false and result ~= nil then self:SetStatus("Einladung an " .. name .. " gesendet."); self.inviteEdit:SetText("") else self:SetStatus(tostring(err or result or "Einladung fehlgeschlagen."), true) end
end

function RaidManagerWindow:Move()
    if not self.selected then return end
    local group = tonumber(self.groupEdit:GetText()); if not group or group < 1 or group > 8 or group ~= math.floor(group) then self:SetStatus("Zielgruppe muss zwischen 1 und 8 liegen.", true); return end
    self:CallPlayerAction("Move", self.selected.name, group)
end

function RaidManagerWindow:Promote() if self.selected then self:CallPlayerAction("Promote", self.selected.name) end end
function RaidManagerWindow:Demote() if self.selected then self:CallPlayerAction("Demote", self.selected.name) end end
function RaidManagerWindow:CallPlayerAction(methodName, player, value)
    local manager = GA.RaidManager; local method = manager and manager[methodName]; if type(method) ~= "function" then self:SetStatus(methodName .. " ist nicht verfügbar.", true); return end
    local ok, result, err = pcall(method, manager, player, value)
    if ok and result ~= false and result ~= nil then self:SetStatus("Aktion für " .. player .. " ausgeführt.") else self:SetStatus(tostring(err or result or "Aktion fehlgeschlagen."), true) end
end

function RaidManagerWindow:Show()
    local frame = self:EnsureFrame(); if not frame then return end
    local manager = GA.RaidManager; if manager and type(manager.GetRoster) == "function" then local ok, roster = pcall(manager.GetRoster, manager); if ok then self:Render(roster) end end
    frame:Show()
end
function RaidManagerWindow:Hide() if self.frame then self.frame:Hide() end end
function RaidManagerWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function RaidManagerWindow:OnInitialize()
    self:EnsureFrame()
    GA.Events:On("GA_RAID_ROSTER_UPDATED", function(_, _, roster) RaidManagerWindow:Render(roster) end, self)
    return true
end

GA:RegisterModule("RaidManagerWindow", RaidManagerWindow)
