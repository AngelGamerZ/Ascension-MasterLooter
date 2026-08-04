local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local Window = { page = 1, pageSize = 9, status = "ALL", statuses = { "ALL", "DROPPED", "ACQUIRED", "AWARDED", "TRADED", "DISENCHANTED", "LOST" } }
GA.UI.LootLedgerWindow = Window

local labels = {
    ALL = "Alle", DROPPED = "Gefallen", ACQUIRED = "Aufgenommen", AWARDED = "Vergeben",
    TRADED = "Gehandelt", DISENCHANTED = "Entzaubert", LOST = "Verloren",
}

local function shortDate(stamp)
    return type(date) == "function" and tonumber(stamp) and date("%d.%m. %H:%M", stamp) or "-"
end

function Window:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterLootLedgerWindow", UIParent)
    frame:SetWidth(760); frame:SetHeight(500); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter - Beute-Ledger")
    Theme:MakeMovable(frame, "lootLedgerWindow"); Theme:RestorePosition(frame, "lootLedgerWindow", "CENTER", 0, 20); Theme:RegisterForEscape(frame)
    self.frame = frame

    local search = Theme:CreateEditBox(frame, 230, 24)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -43); self.search = search
    if search.SetScript then search:SetScript("OnTextChanged", function() Window.page = 1; Window:Refresh() end) end
    local filter = Theme:CreateButton(frame, "Status: Alle", 145, 24)
    filter:SetPoint("LEFT", search, "RIGHT", 8, 0); self.filter = filter
    filter:SetScript("OnClick", function()
        local nextIndex = 1
        for index, value in ipairs(Window.statuses) do if value == Window.status then nextIndex = (index % #Window.statuses) + 1 end end
        Window.status = Window.statuses[nextIndex]; Window.page = 1; Window:Refresh()
    end)
    local export = Theme:CreateButton(frame, "Export", 90, 24)
    export:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -43); export:SetScript("OnClick", function() Window:ShowExport() end)

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 78); Theme:ApplyInset(list); self.list = list
    for _, data in ipairs({ { "Zeit", 10 }, { "Status", 105 }, { "Item", 205 }, { "Spieler", 430 }, { "Boss / Instanz", 550 } }) do
        local label = Theme:CreateLabel(list, data[1], 12, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", data[2], -10)
    end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(31); row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -31 - (index - 1) * 31); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -31 - (index - 1) * 31)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.when = Theme:CreateLabel(row, "", 11); row.when:SetPoint("LEFT", row, "LEFT", 3, 0); row.when:SetWidth(92)
        row.state = Theme:CreateLabel(row, "", 11); row.state:SetPoint("LEFT", row, "LEFT", 98, 0); row.state:SetWidth(95)
        row.item = Theme:CreateLabel(row, "", 11); row.item:SetPoint("LEFT", row, "LEFT", 198, 0); row.item:SetWidth(220)
        row.player = Theme:CreateLabel(row, "", 11); row.player:SetPoint("LEFT", row, "LEFT", 423, 0); row.player:SetWidth(115)
        row.context = Theme:CreateLabel(row, "", 11); row.context:SetPoint("LEFT", row, "LEFT", 543, 0); row.context:SetWidth(165)
        row:SetScript("OnClick", function() Window:Select(row.entry) end)
        row:SetScript("OnEnter", function(self) if self.entry and self.entry.itemLink then Theme:ShowItemTooltip(self, self.entry.itemLink) end end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end)
        self.rows[index] = row
    end

    local previous = Theme:CreateButton(frame, "<", 35, 24); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 43)
    previous:SetScript("OnClick", function() Window.page = math.max(1, Window.page - 1); Window:Refresh() end); self.previous = previous
    local page = Theme:CreateLabel(frame, "1 / 1", 12, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 24); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0)
    nextButton:SetScript("OnClick", function() Window.page = math.min(Window.totalPages or 1, Window.page + 1); Window:Refresh() end); self.next = nextButton
    local state = Theme:CreateButton(frame, "Status aendern", 120, 24); state:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -150, 43)
    state:SetScript("OnClick", function() Window:CycleSelectedStatus() end); state:Disable(); self.stateButton = state
    local remove = Theme:CreateButton(frame, "Loeschen", 115, 24); remove:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 43)
    remove:SetScript("OnClick", function() Window:DeleteSelected() end); remove:Disable(); self.deleteButton = remove
    local note = Theme:CreateLabel(frame, "Boss, Empfaenger und Handelsfrist sind unter 3.3.5a teilweise nur bestmoegliche Schaetzungen.", 11, Theme.colors.muted)
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18); note:SetWidth(710)
    return frame
end

function Window:Filters()
    return { status = self.status, search = self.search and self.search:GetText() or "" }
end

function Window:Refresh()
    if not self:EnsureFrame() then return end
    local entries = GA.LootLedger and GA.LootLedger:Query(self:Filters()) or {}
    self.totalPages = math.max(1, math.ceil(#entries / self.pageSize)); self.page = math.max(1, math.min(self.page, self.totalPages))
    local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local entry = entries[offset + index]; row.entry = entry
        if entry then
            row.when:SetText(shortDate(entry.droppedAt)); row.state:SetText(labels[entry.status] or entry.status or "-")
            row.item:SetText(entry.itemLink or "Unbekannt"); row.player:SetText(entry.winner or entry.recipient or "-")
            row.context:SetText(entry.boss or entry.instance or "-"); row:Show()
        else row:Hide() end
    end
    self.filter:SetText("Status: " .. (labels[self.status] or self.status))
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages .. " (" .. #entries .. ")")
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
end

function Window:Select(entry)
    self.selected = entry
    if entry then self.stateButton:Enable(); self.deleteButton:Enable() else self.stateButton:Disable(); self.deleteButton:Disable() end
end

function Window:CycleSelectedStatus()
    if not self.selected or not GA.LootLedger then return end
    local states = { "DROPPED", "ACQUIRED", "AWARDED", "TRADED", "DISENCHANTED", "LOST" }
    local nextState = states[1]
    for index, value in ipairs(states) do if value == self.selected.status then nextState = states[(index % #states) + 1] end end
    GA.LootLedger:SetStatus(self.selected, nextState, { statusAccuracy = "MANUAL_EDIT" }, "Manuell bearbeitet")
    self:Refresh()
end

function Window:DeleteSelected()
    if not self.selected then return end
    if self.deleteArmed ~= self.selected.id then
        self.deleteArmed = self.selected.id; self.deleteButton:SetText("Bestaetigen")
        if GA.Compat and GA.Compat.After then GA.Compat:After(6, function() Window.deleteArmed = nil; if Window.deleteButton then Window.deleteButton:SetText("Loeschen") end end) end
        return
    end
    GA.LootLedger:Remove(self.selected.id); self.selected, self.deleteArmed = nil, nil
    self.deleteButton:SetText("Loeschen"); self.deleteButton:Disable(); self.stateButton:Disable(); self:Refresh()
end

function Window:ShowExport()
    if not self.exportFrame then
        local panel = CreateFrame("Frame", nil, self.frame); panel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 35, -80); panel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -35, 35); panel:SetFrameLevel(self.frame:GetFrameLevel() + 10); Theme:ApplyPanel(panel)
        local edit = Theme:CreateEditBox(panel, 650, 330); edit:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -15); edit:SetMultiLine(true); edit:SetMaxLetters(0); self.exportEdit = edit
        local close = Theme:CreateButton(panel, "Schliessen", 100, 24); close:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -15, 12); close:SetScript("OnClick", function() panel:Hide() end)
        self.exportFrame = panel
    end
    self.exportEdit:SetText(GA.LootLedger and GA.LootLedger:Export(self:Filters()) or ""); self.exportEdit:HighlightText(); self.exportFrame:Show()
end

function Window:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show(); if frame.Raise then frame:Raise() end end end
function Window:Hide() if self.frame then self.frame:Hide() end end
function Window:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function Window:OnInitialize()
    self:EnsureFrame(); GA.Events:On("GA_LOOT_LEDGER_CHANGED", function() Window:Refresh() end, self); return true
end

GA:RegisterModule("LootLedgerWindow", Window)
