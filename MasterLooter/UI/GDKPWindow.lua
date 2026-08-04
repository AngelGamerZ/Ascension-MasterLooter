local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local GDKPWindow = { rows = {}, offset = 0, lastFinished = nil }
GA.UI.GDKPWindow = GDKPWindow

local function playerCount(session)
    local count = 0
    for _ in pairs(session and session.players or {}) do count = count + 1 end
    return count
end

local function money(value)
    return tostring(math.floor(tonumber(value) or 0)) .. "g"
end

function GDKPWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterGDKPWindow", UIParent)
    frame:SetWidth(700)
    frame:SetHeight(545)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "GDKP-Sitzung")
    Theme:MakeMovable(frame, "gdkpWindow")
    Theme:RestorePosition(frame, "gdkpWindow", "CENTER", 0, 0)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local sessionLabel = Theme:CreateLabel(frame, "Sitzungsname", 11, Theme.colors.gold)
    sessionLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
    local sessionName = Theme:CreateEditBox(frame, 245, 24)
    sessionName:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68)
    self.sessionName = sessionName
    local start = Theme:CreateButton(frame, "Start", 90, 24)
    start:SetPoint("LEFT", sessionName, "RIGHT", 8, 0)
    start:SetScript("OnClick", function() GDKPWindow:StartSession() end)
    self.startButton = start
    local finish = Theme:CreateButton(frame, "Abschließen", 110, 24)
    finish:SetPoint("LEFT", start, "RIGHT", 8, 0)
    finish:SetScript("OnClick", function() GDKPWindow:FinishSession() end)
    self.finishButton = finish

    local status = Theme:CreateLabel(frame, "Keine aktive Sitzung", 11, Theme.colors.muted)
    status:SetPoint("LEFT", finish, "RIGHT", 12, 0)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    self.statusLabel = status

    local pot = Theme:CreateLabel(frame, "Pot: 0g", 14, Theme.colors.gold)
    pot:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -110)
    self.potLabel = pot
    local cut = Theme:CreateLabel(frame, "Cut: 0g", 14, Theme.colors.green)
    cut:SetPoint("LEFT", pot, "RIGHT", 80, 0)
    self.cutLabel = cut
    local players = Theme:CreateLabel(frame, "Spieler: 0", 11)
    players:SetPoint("LEFT", cut, "RIGHT", 80, 0)
    self.playersLabel = players
    local reset = Theme:CreateButton(frame, "Alles zurücksetzen", 140, 24)
    reset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -98)
    reset:SetScript("OnClick", function() GDKPWindow:RequestReset() end)
    self.resetButton = reset
    players:SetPoint("RIGHT", reset, "LEFT", -10, 0)

    local itemLabel = Theme:CreateLabel(frame, "Itemlink / Item-ID", 11, Theme.colors.gold)
    itemLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -148)
    local buyerLabel = Theme:CreateLabel(frame, "Käufer", 11, Theme.colors.gold)
    buyerLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 320, -148)
    local amountLabel = Theme:CreateLabel(frame, "Betrag", 11, Theme.colors.gold)
    amountLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 475, -148)
    local item = Theme:CreateEditBox(frame, 285, 24)
    item:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -168)
    self.itemInput = item
    local buyer = Theme:CreateEditBox(frame, 140, 24)
    buyer:SetPoint("LEFT", item, "RIGHT", 15, 0)
    self.buyerInput = buyer
    local amount = Theme:CreateEditBox(frame, 90, 24, true)
    amount:SetPoint("LEFT", buyer, "RIGHT", 15, 0)
    self.amountInput = amount
    local sale = Theme:CreateButton(frame, "Verkauf", 90, 24)
    sale:SetPoint("LEFT", amount, "RIGHT", 10, 0)
    sale:SetScript("OnClick", function() GDKPWindow:AddSale() end)
    self.saleButton = sale
    local saleResult = Theme:CreateLabel(frame, "", 11)
    saleResult:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -202)
    saleResult:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    self.saleResult = saleResult

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -230)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 82)
    Theme:ApplyInset(list)
    self.list = list
    local headers = {
        { "Item", 12 }, { "Käufer", 378 }, { "Betrag", 552 },
    }
    for index = 1, #headers do
        local label = Theme:CreateLabel(list, headers[index][1], 11, Theme.colors.gold)
        label:SetPoint("TOPLEFT", list, "TOPLEFT", headers[index][2], -9)
    end
    for index = 1, 10 do
        local row = CreateFrame("Frame", nil, list)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -28 - ((index - 1) * 19))
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -28 - ((index - 1) * 19))
        row:SetHeight(18)
        row.item = Theme:CreateLabel(row, "", 11)
        row.item:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.item:SetWidth(350)
        row.item:SetWordWrap(false)
        row.buyer = Theme:CreateLabel(row, "", 11)
        row.buyer:SetPoint("LEFT", row, "LEFT", 368, 0)
        row.buyer:SetWidth(160)
        row.amount = Theme:CreateLabel(row, "", 11, Theme.colors.gold)
        row.amount:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.amount:SetJustifyH("RIGHT")
        self.rows[index] = row
    end

    local previous = Theme:CreateButton(frame, "<", 32, 22)
    previous:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -58, 16)
    previous:SetScript("OnClick", function()
        GDKPWindow.offset = math.max(0, GDKPWindow.offset - #GDKPWindow.rows)
        GDKPWindow:Refresh()
    end)
    self.previousButton = previous
    local nextButton = Theme:CreateButton(frame, ">", 32, 22)
    nextButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    nextButton:SetScript("OnClick", function()
        local session = GA.GDKP.active or GDKPWindow.lastFinished
        local sales = session and session.sales or {}
        if GDKPWindow.offset + #GDKPWindow.rows < #sales then
            GDKPWindow.offset = GDKPWindow.offset + #GDKPWindow.rows
            GDKPWindow:Refresh()
        end
    end)
    self.nextButton = nextButton

    local cutPlayer = Theme:CreateEditBox(frame, 150, 22); cutPlayer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20); self.cutPlayerEdit = cutPlayer
    local cutWeight = Theme:CreateEditBox(frame, 52, 22); cutWeight:SetPoint("LEFT", cutPlayer, "RIGHT", 7, 0); cutWeight:SetText("1"); self.cutWeightEdit = cutWeight
    local setWeight = Theme:CreateButton(frame, "Cut setzen", 92, 23); setWeight:SetPoint("LEFT", cutWeight, "RIGHT", 7, 0); setWeight:SetScript("OnClick", function() GDKPWindow:SetCutWeight() end)
    local paid = Theme:CreateButton(frame, "Bezahlt", 85, 23); paid:SetPoint("LEFT", setWeight, "RIGHT", 8, 0); paid:SetScript("OnClick", function() GDKPWindow:SetPayment("PAID") end)
    local open = Theme:CreateButton(frame, "Offen", 75, 23); open:SetPoint("LEFT", paid, "RIGHT", 6, 0); open:SetScript("OnClick", function() GDKPWindow:SetPayment("OPEN") end)
    local cutHelp = Theme:CreateLabel(frame, "Spieler / Cut-Gewicht / Zahlungsstatus", 10, Theme.colors.muted); cutHelp:SetPoint("BOTTOMLEFT", cutPlayer, "TOPLEFT", 0, 3)
    return frame
end

function GDKPWindow:RequestReset()
    if not self.resetArmed then
        self.resetArmed = true
        self.resetButton:SetText("Wirklich löschen")
        self.saleResult:SetText("Noch einmal klicken: aktive Sitzung und GDKP-Historie werden gelöscht.")
        self.saleResult:SetTextColor(unpack(Theme.colors.red))
        if GA.Compat and type(GA.Compat.After) == "function" then
            GA.Compat:After(6, function()
                if GDKPWindow.resetArmed then
                    GDKPWindow.resetArmed = false
                    GDKPWindow.resetButton:SetText("Alles zurücksetzen")
                    GDKPWindow:Refresh()
                end
            end)
        end
        return false
    end
    self.resetArmed = false
    self.resetButton:SetText("Alles zurücksetzen")
    if GA.GDKP and type(GA.GDKP.Reset) == "function" then GA.GDKP:Reset(true) end
    self.lastFinished, self.offset = nil, 0
    self.sessionName:SetText(""); self.itemInput:SetText(""); self.buyerInput:SetText(""); self.amountInput:SetText("")
    self.cutPlayerEdit:SetText(""); self.cutWeightEdit:SetText("1")
    self:Refresh()
    self.saleResult:SetText("GDKP-Sitzung und Historie wurden zurückgesetzt.")
    self.saleResult:SetTextColor(unpack(Theme.colors.green))
    return true
end

function GDKPWindow:SetCutWeight()
    local ok, err = GA.GDKP:SetCutWeight(self.cutPlayerEdit:GetText(), tonumber(self.cutWeightEdit:GetText()))
    self.saleResult:SetText(ok and "Cut-Gewicht gespeichert." or tostring(err)); self.saleResult:SetTextColor(unpack(ok and Theme.colors.green or Theme.colors.red)); self:Refresh()
end

function GDKPWindow:SetPayment(status)
    local ok, err = GA.GDKP:SetPaymentStatus(self.cutPlayerEdit:GetText(), status)
    self.saleResult:SetText(ok and ("Zahlungsstatus: " .. status) or tostring(err)); self.saleResult:SetTextColor(unpack(ok and Theme.colors.green or Theme.colors.red)); self:Refresh()
end

function GDKPWindow:StartSession()
    local name = self.sessionName:GetText()
    if name == "" then name = nil end
    local session, err = GA.GDKP:Start(name)
    if not session then
        self.statusLabel:SetText(err or "Sitzung konnte nicht gestartet werden.")
        self.statusLabel:SetTextColor(unpack(Theme.colors.red))
        return
    end
    self.lastFinished, self.offset = nil, 0
    self:Refresh()
end

function GDKPWindow:AddSale()
    local item, buyer = self.itemInput:GetText(), self.buyerInput:GetText()
    local amount = tonumber(self.amountInput:GetText())
    if item == "" or buyer == "" or not amount or amount <= 0 then
        self.saleResult:SetText("Item, Käufer und ein positiver Betrag sind erforderlich.")
        self.saleResult:SetTextColor(unpack(Theme.colors.red))
        return
    end
    local sale, err = GA.GDKP:AddSale(item, buyer, amount)
    if not sale then
        self.saleResult:SetText(err or "Verkauf konnte nicht gespeichert werden.")
        self.saleResult:SetTextColor(unpack(Theme.colors.red))
        return
    end
    self.saleResult:SetText("Verkauf gespeichert: " .. buyer .. " — " .. money(amount))
    self.saleResult:SetTextColor(unpack(Theme.colors.green))
    self.itemInput:SetText("")
    self.amountInput:SetText("")
    self.offset = math.max(0, #GA.GDKP.active.sales - #self.rows)
    self:Refresh()
end

function GDKPWindow:FinishSession()
    local finished = GA.GDKP:Finish()
    if finished then self.lastFinished = finished end
    self.offset = 0
    self:Refresh()
end

function GDKPWindow:Refresh(session)
    if not self.frame then return end
    local active = GA.GDKP and GA.GDKP.active
    session = session or active or self.lastFinished
    local count = playerCount(session)
    local pot = session and session.pot or 0
    local cut = session and count > 0 and math.floor(pot / count) or 0
    self.potLabel:SetText("Pot: " .. money(pot))
    self.cutLabel:SetText("Cut: " .. money(cut))
    self.playersLabel:SetText("Spieler: " .. tostring(count))
    if active then
        self.statusLabel:SetText("Aktiv: " .. tostring(active.name or "GDKP"))
        self.statusLabel:SetTextColor(unpack(Theme.colors.green))
        self.startButton:Disable()
        self.finishButton:Enable()
        self.saleButton:Enable()
    elseif self.lastFinished then
        self.statusLabel:SetText("Abgeschlossen: " .. tostring(self.lastFinished.name or "GDKP"))
        self.statusLabel:SetTextColor(unpack(Theme.colors.gold))
        self.startButton:Enable()
        self.finishButton:Disable()
        self.saleButton:Disable()
    else
        self.statusLabel:SetText("Keine aktive Sitzung")
        self.statusLabel:SetTextColor(unpack(Theme.colors.muted))
        self.startButton:Enable()
        self.finishButton:Disable()
        self.saleButton:Disable()
    end
    local sales = session and session.sales or {}
    local maximumOffset = math.max(0, #sales - #self.rows)
    self.offset = math.min(self.offset, maximumOffset)
    for index = 1, #self.rows do
        local row, sale = self.rows[index], sales[self.offset + index]
        if sale then
            row.item:SetText(sale.itemLink or "?")
            row.buyer:SetText(sale.buyer or "?")
            row.amount:SetText(money(sale.amount))
            Theme:SetItemTooltip(row, sale.itemLink)
            row:Show()
        else
            row:Hide()
        end
    end
    if self.offset > 0 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.offset + #self.rows < #sales then self.nextButton:Enable() else self.nextButton:Disable() end
end

function GDKPWindow:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self:Refresh()
    frame:Show()
    frame:Raise()
end

function GDKPWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function GDKPWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function GDKPWindow:Initialize()
    if self.initialized then return true end
    self:EnsureFrame()
    GA.Events:On("GA_GDKP_STARTED", function(_, event, session)
        GDKPWindow.lastFinished = nil
        GDKPWindow:Refresh(session)
    end, self)
    GA.Events:On("GA_GDKP_SALE", function(_, event, sale, session)
        GDKPWindow:Refresh(session)
    end, self)
    GA.Events:On("GA_GDKP_FINISHED", function(_, event, session)
        GDKPWindow.lastFinished = session
        GDKPWindow:Refresh(session)
    end, self)
    GA.Events:On("GA_GDKP_RESET", function() GDKPWindow.lastFinished = nil; GDKPWindow.offset = 0; GDKPWindow:Refresh() end, self)
    GA.Events:On("GA_GDKP_DISTRIBUTION_CHANGED", function(_, _, session) GDKPWindow:Refresh(session) end, self)
    self.initialized = true
    self:Refresh()
    return true
end

GDKPWindow.OnInitialize = GDKPWindow.Initialize
GDKPWindow.OnEnable = GDKPWindow.Initialize
GA:RegisterModule("GDKPWindow", GDKPWindow)
