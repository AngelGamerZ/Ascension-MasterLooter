local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local SoftResWindow = { currentItem = nil, rows = {}, page = 1 }
GA.UI.SoftResWindow = SoftResWindow

local function sortedReservations(reservations)
    local result = {}
    for player, amount in pairs(reservations or {}) do
        result[#result + 1] = { player = player, amount = tonumber(amount) or 1 }
    end
    table.sort(result, function(a, b)
        if a.amount == b.amount then return a.player < b.player end
        return a.amount > b.amount
    end)
    return result
end

local function allReservations()
    return GA.SoftRes and type(GA.SoftRes.GetAllReservations) == "function" and GA.SoftRes:GetAllReservations() or {}
end

function SoftResWindow:DescribeOverviewEntry(entry)
    local name, link = GA.Compat:GetItemInfo(entry.itemID)
    return tostring(entry.player), tostring(entry.className or ""), tostring(link or name or ("Item " .. tostring(entry.itemID))), tostring(entry.amount or 1)
end

function SoftResWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterSoftResWindow", UIParent)
    frame:SetWidth(620)
    frame:SetHeight(500)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "Soft Reserve")
    Theme:MakeMovable(frame, "softResWindow")
    Theme:RestorePosition(frame, "softResWindow", "CENTER", 0, 0)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local importTitle = Theme:CreateLabel(frame, "CSV-/TSV-Import: Spieler, Item-ID, Anzahl", 12, Theme.colors.gold)
    importTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -46)

    local importPanel = CreateFrame("Frame", nil, frame)
    importPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -66)
    importPanel:SetWidth(584)
    importPanel:SetHeight(135)
    Theme:ApplyInset(importPanel)

    local scroll = CreateFrame("ScrollFrame", nil, importPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", importPanel, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", importPanel, "BOTTOMRIGHT", -28, 8)
    local input = CreateFrame("EditBox", nil, scroll)
    input:SetWidth(530)
    input:SetHeight(115)
    input:SetMultiLine(true)
    input:SetAutoFocus(false)
    input:SetFontObject(ChatFontNormal)
    input:SetTextInsets(4, 4, 4, 4)
    input:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    input:SetScript("OnTextChanged", function(edit)
        scroll:UpdateScrollChildRect()
        local _, lines = string.gsub(edit:GetText() or "", "\n", "")
        local height = math.max(115, (lines + 1) * 15 + 12)
        edit:SetHeight(height)
    end)
    scroll:SetScrollChild(input)
    self.importInput = input

    local importButton = Theme:CreateButton(frame, "Importieren", 110, 24)
    importButton:SetPoint("TOPLEFT", importPanel, "BOTTOMLEFT", 0, -8)
    importButton:SetScript("OnClick", function() SoftResWindow:Import() end)
    local clearButton = Theme:CreateButton(frame, "Leeren", 80, 24)
    clearButton:SetPoint("LEFT", importButton, "RIGHT", 6, 0)
    clearButton:SetScript("OnClick", function()
        input:SetText("")
        SoftResWindow.importResult:SetText("")
    end)
    local result = Theme:CreateLabel(frame, "", 11, Theme.colors.muted)
    result:SetPoint("LEFT", clearButton, "RIGHT", 12, 0)
    result:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    self.importResult = result

    local searchTitle = Theme:CreateLabel(frame, "Reservierungen nach Item suchen", 12, Theme.colors.gold)
    searchTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -244)
    local search = Theme:CreateEditBox(frame, 330, 24)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -266)
    search:SetScript("OnEnterPressed", function(edit)
        edit:ClearFocus()
        SoftResWindow:Search(edit:GetText())
    end)
    self.searchInput = search
    local searchButton = Theme:CreateButton(frame, "Suchen", 90, 24)
    searchButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
    searchButton:SetScript("OnClick", function() SoftResWindow:Search(search:GetText()) end)

    local hard = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hard:SetPoint("LEFT", searchButton, "RIGHT", 10, 0)
    hard:SetWidth(24)
    hard:SetHeight(24)
    local hardLabel = Theme:CreateLabel(frame, "Hard Reserve", 11)
    hardLabel:SetPoint("LEFT", hard, "RIGHT", 1, 0)
    hard:SetScript("OnClick", function(button)
        if SoftResWindow.currentItem and GA.SoftRes then
            GA.SoftRes:SetHardReserved(SoftResWindow.currentItem, button:GetChecked())
            SoftResWindow:Refresh()
        else
            button:SetChecked(false)
        end
    end)
    self.hardCheck = hard

    local itemLabel = Theme:CreateLabel(frame, "Noch kein Item ausgewählt.", 12)
    itemLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -304)
    itemLabel:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    self.itemLabel = itemLabel

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -328)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    Theme:ApplyInset(list)
    local playerHead = Theme:CreateLabel(list, "Spieler", 11, Theme.colors.gold)
    playerHead:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -9)
    local classHead = Theme:CreateLabel(list, "Klasse", 11, Theme.colors.gold)
    classHead:SetPoint("TOPLEFT", list, "TOPLEFT", 158, -9)
    local itemHead = Theme:CreateLabel(list, "Item", 11, Theme.colors.gold)
    itemHead:SetPoint("TOPLEFT", list, "TOPLEFT", 274, -9)
    local amountHead = Theme:CreateLabel(list, "Anzahl", 11, Theme.colors.gold)
    amountHead:SetPoint("TOPRIGHT", list, "TOPRIGHT", -14, -9)
    local previous = Theme:CreateButton(list, "<", 28, 20)
    previous:SetPoint("TOPRIGHT", list, "TOPRIGHT", -108, -4)
    previous:SetScript("OnClick", function()
        SoftResWindow.page = math.max(1, SoftResWindow.page - 1)
        SoftResWindow:Refresh()
    end)
    self.previousButton = previous
    local pageLabel = Theme:CreateLabel(list, "1/1", 11, Theme.colors.muted)
    pageLabel:SetPoint("LEFT", previous, "RIGHT", 3, 0)
    pageLabel:SetWidth(30)
    pageLabel:SetJustifyH("CENTER")
    self.pageLabel = pageLabel
    local nextButton = Theme:CreateButton(list, ">", 28, 20)
    nextButton:SetPoint("LEFT", pageLabel, "RIGHT", 3, 0)
    nextButton:SetScript("OnClick", function()
        SoftResWindow.page = math.min(SoftResWindow.totalPages or 1, SoftResWindow.page + 1)
        SoftResWindow:Refresh()
    end)
    self.nextButton = nextButton
    for index = 1, 7 do
        local row = CreateFrame("Frame", nil, list)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -28 - ((index - 1) * 19))
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -28 - ((index - 1) * 19))
        row:SetHeight(18)
        row.player = Theme:CreateLabel(row, "", 11)
        row.player:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.player:SetWidth(138)
        row.player:SetJustifyH("LEFT")
        row.class = Theme:CreateLabel(row, "", 11)
        row.class:SetPoint("LEFT", row, "LEFT", 148, 0)
        row.class:SetWidth(108)
        row.class:SetJustifyH("LEFT")
        row.item = Theme:CreateLabel(row, "", 11)
        row.item:SetPoint("LEFT", row, "LEFT", 264, 0)
        row.item:SetWidth(168)
        row.item:SetJustifyH("LEFT")
        row.amount = Theme:CreateLabel(row, "", 11)
        row.amount:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.amount:SetJustifyH("RIGHT")
        self.rows[index] = row
    end
    return frame
end

function SoftResWindow:Import()
    if not GA.SoftRes then return end
    local imported, rejected = GA.SoftRes:Import(self.importInput:GetText() or "")
    self.importResult:SetText(string.format("%d importiert, %d abgelehnt", imported or 0, rejected or 0))
    self.importResult:SetTextColor(unpack((rejected or 0) > 0 and Theme.colors.red or Theme.colors.green))
    self:Refresh()
end

function SoftResWindow:Search(item)
    local id = GA.Compat and GA.Compat:GetItemID(item)
    if not id then
        self.currentItem = nil
        self.itemLabel:SetText("Ungültige Item-ID oder kein Itemlink.")
        self.itemLabel:SetTextColor(unpack(Theme.colors.red))
        self:Refresh()
        return
    end
    self.currentItem = id
    self.page = 1
    self:Refresh()
end

function SoftResWindow:Refresh()
    if not self.frame then return end
    local reservations = self.currentItem and GA.SoftRes and GA.SoftRes:GetReservations(self.currentItem) or nil
    local entries = self.currentItem and sortedReservations(reservations) or allReservations()
    self.totalPages = math.max(1, math.ceil(#entries / #self.rows))
    self.page = math.max(1, math.min(self.page or 1, self.totalPages))
    local offset = (self.page - 1) * #self.rows
    if self.currentItem then
        local name, link = GA.Compat:GetItemInfo(self.currentItem)
        self.itemLabel:SetText((link or name or ("Item " .. tostring(self.currentItem))) ..
            string.format(" — %d Reservierung(en)", #entries))
        self.itemLabel:SetTextColor(unpack(Theme.colors.text))
        self.hardCheck:SetChecked(GA.SoftRes:IsHardReserved(self.currentItem))
        self.hardCheck:Enable()
    else
        self.itemLabel:SetText(string.format("Alle Reservierungen — %d Eintrag/Einträge", #entries))
        self.itemLabel:SetTextColor(unpack(Theme.colors.text))
        self.hardCheck:SetChecked(false)
        self.hardCheck:Disable()
    end
    for index = 1, #self.rows do
        local row, entry = self.rows[index], entries[offset + index]
        if entry then
            if self.currentItem then
                row.player:SetText(entry.player)
                row.class:SetText("")
                row.item:SetText("")
            else
                local player, className, itemText = self:DescribeOverviewEntry(entry)
                row.player:SetText(player)
                row.class:SetText(className)
                row.item:SetText(itemText)
            end
            row.amount:SetText(tostring(entry.amount))
            row:Show()
        else
            row:Hide()
        end
    end
    self.pageLabel:SetText(self.page .. "/" .. self.totalPages)
    if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.page < self.totalPages then self.nextButton:Enable() else self.nextButton:Disable() end
end

function SoftResWindow:Show(item)
    local frame = self:EnsureFrame()
    if not frame then return end
    if item then self.searchInput:SetText(tostring(item)); self:Search(item) else self:Refresh() end
    frame:Show()
    frame:Raise()
end

function SoftResWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function SoftResWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function SoftResWindow:Initialize()
    if self.initialized then return true end
    self:EnsureFrame()
    GA.Events:On("GA_SOFTRES_CHANGED", function(_, event, itemID)
        if not SoftResWindow.currentItem or SoftResWindow.currentItem == tonumber(itemID) then SoftResWindow:Refresh() end
    end, self)
    GA.Events:On("GA_EXTERNAL_IMPORT_COMPLETED", function(_, event, format)
        if format == "BISBEARD" then SoftResWindow.currentItem = nil; SoftResWindow.page = 1; SoftResWindow:Refresh() end
    end, self)
    self.initialized = true
    return true
end

SoftResWindow.OnInitialize = SoftResWindow.Initialize
SoftResWindow.OnEnable = SoftResWindow.Initialize
GA:RegisterModule("SoftResWindow", SoftResWindow)
