local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme

local HistoryWindow = { page = 1, pageSize = 10, mode = "AWARDS" }
GA.UI.HistoryWindow = HistoryWindow

local function historyTable(mode)
    if mode == "LEDGER" and GA.PlusOnes and GA.PlusOnes.GetLedgerHistory then return GA.PlusOnes:GetLedgerHistory() end
    local history = GA.DB and GA.DB.data and GA.DB.data.history or nil
    if not history then return {} end
    if mode == "GDKP" then return history.gdkp or {} end
    return history.awards or {}
end

local function formatDate(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 or type(date) ~= "function" then return "–" end
    return date("%d.%m.%Y %H:%M", timestamp)
end

function HistoryWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterHistoryWindow", UIParent)
    frame:SetWidth(700)
    frame:SetHeight(455)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "MasterLooter – Historie")
    Theme:MakeMovable(frame, "historyWindow")
    Theme:RestorePosition(frame, "historyWindow", "CENTER", 0, 10)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local awards = Theme:CreateButton(frame, "Vergaben", 105, 25)
    awards:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -43)
    awards:SetScript("OnClick", function() HistoryWindow:SetMode("AWARDS") end)
    self.awardsButton = awards
    local gdkp = Theme:CreateButton(frame, "GDKP", 105, 25)
    gdkp:SetPoint("LEFT", awards, "RIGHT", 6, 0)
    gdkp:SetScript("OnClick", function() HistoryWindow:SetMode("GDKP") end)
    self.gdkpButton = gdkp
    local ledger = Theme:CreateButton(frame, "Strichliste", 105, 25)
    ledger:SetPoint("LEFT", gdkp, "RIGHT", 6, 0)
    ledger:SetScript("OnClick", function() HistoryWindow:SetMode("LEDGER") end)
    self.ledgerButton = ledger
    local refresh = Theme:CreateButton(frame, "Aktualisieren", 105, 25)
    refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -43)
    refresh:SetScript("OnClick", function() HistoryWindow:Refresh() end)

    local tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78)
    tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 57)
    Theme:ApplyInset(tableFrame)
    self.tableFrame = tableFrame

    self.headers = {}
    local headerDefinitions = {
        { "Datum", 10, 130 }, { "Item / Sitzung", 145, 280 },
        { "Spieler / Pot", 430, 155 }, { "Wahl / Verkäufe", 590, 85 },
    }
    for index, definition in ipairs(headerDefinitions) do
        local label = Theme:CreateLabel(tableFrame, definition[1], 12, Theme.colors.gold)
        label:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", definition[2], -10)
        label:SetWidth(definition[3])
        self.headers[index] = label
    end

    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, tableFrame)
        row:SetHeight(29)
        row:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 7, -31 - ((index - 1) * 29))
        row:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -7, -31 - ((index - 1) * 29))
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.date = Theme:CreateLabel(row, "", 12)
        row.date:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.date:SetWidth(130)
        row.item = Theme:CreateLabel(row, "", 12)
        row.item:SetPoint("LEFT", row, "LEFT", 139, 0)
        row.item:SetWidth(280)
        row.player = Theme:CreateLabel(row, "", 12)
        row.player:SetPoint("LEFT", row, "LEFT", 424, 0)
        row.player:SetWidth(155)
        row.detail = Theme:CreateLabel(row, "", 12)
        row.detail:SetPoint("LEFT", row, "LEFT", 584, 0)
        row.detail:SetWidth(62)
        row:SetScript("OnEnter", function(self)
            if not self.itemLink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end)
        self.rows[index] = row
    end

    local previous = Theme:CreateButton(frame, "Zurück", 85, 25)
    previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    previous:SetScript("OnClick", function()
        HistoryWindow.page = math.max(1, HistoryWindow.page - 1)
        HistoryWindow:Refresh()
    end)
    self.previousButton = previous
    local nextButton = Theme:CreateButton(frame, "Weiter", 85, 25)
    nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
    nextButton:SetScript("OnClick", function()
        HistoryWindow.page = math.min(HistoryWindow.totalPages or 1, HistoryWindow.page + 1)
        HistoryWindow:Refresh()
    end)
    self.nextButton = nextButton
    local pageLabel = Theme:CreateLabel(frame, "Seite 1 / 1", 12, Theme.colors.muted)
    pageLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 26)
    pageLabel:SetJustifyH("CENTER")
    self.pageLabel = pageLabel

    return frame
end

function HistoryWindow:SetMode(mode)
    self.mode = (mode == "GDKP" or mode == "LEDGER") and mode or "AWARDS"
    self.page = 1
    self:Refresh()
end

function HistoryWindow:Refresh()
    if not self:EnsureFrame() then return end
    local source = historyTable(self.mode)
    local total = #source
    self.totalPages = math.max(1, math.ceil(total / self.pageSize))
    self.page = math.max(1, math.min(self.page, self.totalPages))
    local newest = total - ((self.page - 1) * self.pageSize)

    for rowIndex, row in ipairs(self.rows) do
        local entry = source[newest - rowIndex + 1]
        if type(entry) == "table" then
            row.itemLink = nil
            if self.mode == "GDKP" then
                row.date:SetText(formatDate(entry.finishedAt or entry.startedAt))
                row.item:SetText(entry.name or "GDKP-Sitzung")
                row.player:SetText(tostring(tonumber(entry.pot) or 0) .. " Gold")
                row.detail:SetText(tostring(#(entry.sales or {})) .. " Verkäufe")
            elseif self.mode == "LEDGER" then
                row.date:SetText(formatDate(entry.time))
                row.item:SetText(entry.itemLink or entry.reason or entry.action or "Änderung")
                row.itemLink = entry.itemLink
                row.player:SetText(entry.player or "–")
                local amount = tonumber(entry.amount) or 0
                row.detail:SetText((amount > 0 and "+" or "") .. tostring(amount) .. (entry.choice and " " .. entry.choice or ""))
            else
                row.date:SetText(formatDate(entry.time))
                row.item:SetText(entry.itemLink or "Unbekanntes Item")
                row.itemLink = entry.itemLink
                row.player:SetText(entry.winner or "–")
                local detail = entry.choice or "–"
                if tonumber(entry.roll) and tonumber(entry.roll) > 0 then detail = detail .. " (" .. entry.roll .. ")" end
                row.detail:SetText(detail)
            end
            row:Show()
        else
            row.itemLink = nil
            row:Hide()
        end
    end

    self.pageLabel:SetText("Seite " .. self.page .. " / " .. self.totalPages .. "  (" .. total .. " Einträge)")
    if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.page < self.totalPages then self.nextButton:Enable() else self.nextButton:Disable() end
    self.awardsButton:Enable(); self.gdkpButton:Enable(); self.ledgerButton:Enable()
    if self.mode == "AWARDS" then self.awardsButton:Disable()
    elseif self.mode == "GDKP" then self.gdkpButton:Disable()
    else self.ledgerButton:Disable() end
end

function HistoryWindow:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self:Refresh()
    frame:Show()
end

function HistoryWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function HistoryWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function HistoryWindow:OnInitialize()
    self:EnsureFrame()
    GA.Events:On("GA_AWARD_RECORDED", function() HistoryWindow:Refresh() end, self)
    GA.Events:On("GA_GDKP_FINISHED", function() HistoryWindow:Refresh() end, self)
    GA.Events:On("GA_ITEM_LEDGER_CHANGED", function() HistoryWindow:Refresh() end, self)
    GA.Events:On("GA_PLUSONE_CHANGED", function() HistoryWindow:Refresh() end, self)
    return true
end

GA:RegisterModule("HistoryWindow", HistoryWindow)
