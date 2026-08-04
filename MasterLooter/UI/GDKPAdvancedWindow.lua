local _, GA = ...
GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local Window = { rows = {} }
GA.UI.GDKPAdvancedWindow = Window

local function addLabel(parent, text, x, y)
    local value = Theme:CreateLabel(parent, text, 10, Theme.colors.gold)
    value:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); return value
end
local function addEdit(parent, width, x, y, numeric)
    local value = Theme:CreateEditBox(parent, width, 23, numeric)
    value:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); return value
end
function Window:SetResult(text, ok)
    self.result:SetText(tostring(text or "")); self.result:SetTextColor(unpack(ok and Theme.colors.green or Theme.colors.red))
end

function Window:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterGDKPAdvancedWindow", UIParent)
    frame:SetWidth(760); frame:SetHeight(600); frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "GDKP – Verwaltung und Ledger")
    Theme:MakeMovable(frame, "gdkpAdvancedWindow"); Theme:RestorePosition(frame, "gdkpAdvancedWindow", "CENTER", 0, 0); Theme:RegisterForEscape(frame)
    self.frame = frame

    addLabel(frame, "Management-Cut %", 20, -48); self.cutPercent = addEdit(frame, 80, 20, -66, true); self.cutPercent:SetText("0")
    addLabel(frame, "Fixbetrag", 112, -48); self.cutFixed = addEdit(frame, 90, 112, -66, true); self.cutFixed:SetText("0")
    local cutButton = Theme:CreateButton(frame, "Cut speichern", 110, 23); cutButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 214, -66)
    cutButton:SetScript("OnClick", function() local ok, err = GA.GDKP:SetManagementCut(Window.cutPercent:GetText(), Window.cutFixed:GetText()); Window:SetResult(ok and "Management-Cut gespeichert." or err, ok); Window:Refresh() end)
    addLabel(frame, "Mutator / %", 340, -48); self.mutatorName = addEdit(frame, 105, 340, -66); self.mutatorPercent = addEdit(frame, 60, 451, -66, true)
    local mutatorButton = Theme:CreateButton(frame, "Setzen", 75, 23); mutatorButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 517, -66)
    mutatorButton:SetScript("OnClick", function() local ok, err = GA.GDKP:SetMutator(Window.mutatorName:GetText(), Window.mutatorPercent:GetText()); Window:SetResult(ok and "Mutator gespeichert." or err, ok); Window:Refresh() end)

    addLabel(frame, "Goldtransaktion: Spieler", 20, -103); self.txPlayer = addEdit(frame, 150, 20, -121)
    addLabel(frame, "Betrag", 180, -103); self.txAmount = addEdit(frame, 85, 180, -121, true)
    addLabel(frame, "IN / OUT", 275, -103); self.txKind = addEdit(frame, 70, 275, -121); self.txKind:SetText("IN")
    addLabel(frame, "Notiz", 355, -103); self.txNote = addEdit(frame, 210, 355, -121)
    local txButton = Theme:CreateButton(frame, "Buchen", 80, 23); txButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 575, -121)
    txButton:SetScript("OnClick", function() local row, err = GA.GDKP:AddTransaction(Window.txPlayer:GetText(), Window.txAmount:GetText(), Window.txKind:GetText(), Window.txNote:GetText()); Window:SetResult(row and "Transaktion gebucht." or err, row ~= nil); Window:Refresh() end)

    addLabel(frame, "Preisliste: Itemlink", 20, -158); self.priceItem = addEdit(frame, 290, 20, -176)
    addLabel(frame, "Minimum", 320, -158); self.priceMin = addEdit(frame, 85, 320, -176, true)
    addLabel(frame, "Schritt", 415, -158); self.priceStep = addEdit(frame, 75, 415, -176, true)
    local priceButton = Theme:CreateButton(frame, "Preis speichern", 115, 23); priceButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 500, -176)
    priceButton:SetScript("OnClick", function() local ok, err = GA.GDKP:SetPrice(Window.priceItem:GetText(), Window.priceMin:GetText(), Window.priceStep:GetText()); Window:SetResult(ok and "Preis gespeichert." or err, ok) end)
    local bagButton = Theme:CreateButton(frame, "Taschen → Queue", 120, 23); bagButton:SetPoint("LEFT", priceButton, "RIGHT", 7, 0)
    bagButton:SetScript("OnClick", function() local count, err = GA.GDKPMultiAuction:EnqueueInventory(Window.priceMin:GetText(), Window.priceStep:GetText(), 30, 2); Window:SetResult(err or (tostring(count) .. " Item(s) eingereiht."), not err) end)

    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -218); list:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -218); list:SetHeight(190); Theme:ApplyInset(list)
    addLabel(list, "ID", 10, -9); addLabel(list, "Art", 80, -9); addLabel(list, "Spieler / Item / Notiz", 180, -9); addLabel(list, "Betrag", 620, -9)
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, list); row:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -27 - (index - 1) * 19); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -27 - (index - 1) * 19); row:SetHeight(18)
        row.id = Theme:CreateLabel(row, "", 10); row.id:SetPoint("LEFT", row, "LEFT", 2, 0); row.id:SetWidth(65)
        row.kind = Theme:CreateLabel(row, "", 10); row.kind:SetPoint("LEFT", row, "LEFT", 70, 0); row.kind:SetWidth(95)
        row.detail = Theme:CreateLabel(row, "", 10); row.detail:SetPoint("LEFT", row, "LEFT", 170, 0); row.detail:SetWidth(420); row.detail:SetWordWrap(false)
        row.amount = Theme:CreateLabel(row, "", 10, Theme.colors.gold); row.amount:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        self.rows[index] = row
    end

    addLabel(frame, "Ledger bearbeiten: ID", 20, -421); self.ledgerID = addEdit(frame, 65, 20, -439, true)
    addLabel(frame, "Notiz", 95, -421); self.ledgerNote = addEdit(frame, 250, 95, -439)
    local saveLedger = Theme:CreateButton(frame, "Notiz speichern", 115, 23); saveLedger:SetPoint("TOPLEFT", frame, "TOPLEFT", 355, -439)
    saveLedger:SetScript("OnClick", function() local ok, err = GA.GDKP:EditLedger(Window.ledgerID:GetText(), { note = Window.ledgerNote:GetText() }); Window:SetResult(ok and "Ledger geändert." or err, ok); Window:Refresh() end)
    local deleteLedger = Theme:CreateButton(frame, "Eintrag löschen", 110, 23); deleteLedger:SetPoint("LEFT", saveLedger, "RIGHT", 7, 0)
    deleteLedger:SetScript("OnClick", function() local ok, err = GA.GDKP:DeleteLedger(Window.ledgerID:GetText()); Window:SetResult(ok and "Ledger-Eintrag gelöscht." or err, ok); Window:Refresh() end)

    addLabel(frame, "Import / Export (MLGDKP v1)", 20, -476); self.exchange = Theme:CreateEditBox(frame, 575, 58); self.exchange:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -494)
    if self.exchange.SetMultiLine then self.exchange:SetMultiLine(true) end
    local exportButton = Theme:CreateButton(frame, "Export", 90, 24); exportButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 605, -494)
    exportButton:SetScript("OnClick", function() local text, err = GA.GDKP:Export(); if text then Window.exchange:SetText(text); Window.exchange:HighlightText() end; Window:SetResult(text and "Export erstellt." or err, text ~= nil) end)
    local importButton = Theme:CreateButton(frame, "Import", 90, 24); importButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 605, -526)
    importButton:SetScript("OnClick", function() local ok, err = GA.GDKP:Import(Window.exchange:GetText(), false); Window:SetResult(ok and "Import abgeschlossen." or err, ok); Window:Refresh() end)
    self.result = Theme:CreateLabel(frame, "", 10, Theme.colors.muted); self.result:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 16); self.result:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    return frame
end

function Window:Refresh()
    if not self.frame then return end
    local session = GA.GDKP and GA.GDKP.active; local ledger = session and session.ledger or {}
    for index, row in ipairs(self.rows) do local entry = ledger[#ledger - index + 1]
        if entry then row.id:SetText(tostring(entry.id)); row.kind:SetText(entry.kind or "?"); row.detail:SetText(entry.player or entry.itemLink or entry.reason or entry.note or ""); row.amount:SetText(tostring(entry.amount or 0) .. "g"); row:Show() else row:Hide() end
    end
    if session and session.managementCut then self.cutPercent:SetText(tostring(session.managementCut.percent or 0)); self.cutFixed:SetText(tostring(session.managementCut.fixed or 0)) end
end
function Window:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show(); frame:Raise() end end
function Window:Hide() if self.frame then self.frame:Hide() end end
function Window:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function Window:OnInitialize() self:EnsureFrame(); GA.Events:On("GA_GDKP_LEDGER_CHANGED", function() Window:Refresh() end, self); GA.Events:On("GA_GDKP_DISTRIBUTION_CHANGED", function() Window:Refresh() end, self); return true end
GA:RegisterModule("GDKPAdvancedWindow", Window)
