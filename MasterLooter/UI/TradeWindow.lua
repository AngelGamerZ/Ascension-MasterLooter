local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local TradeWindow = { page = 1, pageSize = 8 }
GA.UI.TradeWindow = TradeWindow

function TradeWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterTradeWindow", UIParent)
    frame:SetWidth(650); frame:SetHeight(430); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Handelsassistent")
    Theme:MakeMovable(frame, "tradeWindow"); Theme:RestorePosition(frame, "tradeWindow", "CENTER", 120, 20); Theme:RegisterForEscape(frame); self.frame = frame
    local state = Theme:CreateLabel(frame, "Handel: IDLE", 12, Theme.colors.muted); state:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -46); state:SetWidth(400); self.stateLabel = state
    local refresh = Theme:CreateButton(frame, "Taschen prüfen", 115, 24); refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -40)
    refresh:SetScript("OnClick", function() TradeWindow:PrepareSelected() end)

    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -77); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 108)
    Theme:ApplyInset(list); self.list = list
    for _, data in ipairs({ { "Item", 10 }, { "Ziel", 320 }, { "Status", 455 }, { "Tasche / Slot", 535 } }) do local label = Theme:CreateLabel(list, data[1], 12, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", data[2], -10) end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(29); row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -31 - (index - 1) * 29); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -31 - (index - 1) * 29)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.item = Theme:CreateLabel(row, "", 12); row.item:SetPoint("LEFT", row, "LEFT", 4, 0); row.item:SetWidth(300)
        row.target = Theme:CreateLabel(row, "", 12); row.target:SetPoint("LEFT", row, "LEFT", 314, 0); row.target:SetWidth(125)
        row.state = Theme:CreateLabel(row, "", 12); row.state:SetPoint("LEFT", row, "LEFT", 449, 0); row.state:SetWidth(66)
        row.location = Theme:CreateLabel(row, "", 12); row.location:SetPoint("LEFT", row, "LEFT", 519, 0); row.location:SetWidth(68)
        row:SetScript("OnClick", function() TradeWindow:Select(row.entry) end)
        row:SetScript("OnEnter", function(self) if self.entry and self.entry.itemLink then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.itemLink); GameTooltip:Show() end end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end); self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 74); self.previous = previous
    previous:SetScript("OnClick", function() TradeWindow.page = math.max(1, TradeWindow.page - 1); TradeWindow:Refresh() end)
    local page = Theme:CreateLabel(frame, "1 / 1", 12, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0); self.next = nextButton
    nextButton:SetScript("OnClick", function() TradeWindow.page = math.min(TradeWindow.totalPages or 1, TradeWindow.page + 1); TradeWindow:Refresh() end)
    local selected = Theme:CreateLabel(frame, "Auswahl: –", 12); selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 47); selected:SetWidth(570); self.selectedLabel = selected
    local prepare = Theme:CreateButton(frame, "Taschenposition", 125, 27); prepare:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 15); prepare:SetScript("OnClick", function() TradeWindow:PrepareSelected() end); prepare:Disable(); self.prepare = prepare
    local delivered = Theme:CreateButton(frame, "Als erledigt", 110, 27); delivered:SetPoint("LEFT", prepare, "RIGHT", 8, 0); delivered:SetScript("OnClick", function() TradeWindow:MarkDelivered() end); delivered:Disable(); self.delivered = delivered
    local failed = Theme:CreateButton(frame, "Fehlgeschlagen", 120, 27); failed:SetPoint("LEFT", delivered, "RIGHT", 8, 0); failed:SetScript("OnClick", function() TradeWindow:MarkFailed() end); failed:Disable(); self.failed = failed
    local note = Theme:CreateLabel(frame, "Nur Statusverwaltung – keine automatische Handelsaktion.", 12, Theme.colors.muted); note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 22); note:SetWidth(235); note:SetJustifyH("RIGHT")
    return frame
end

local function locationText(entry)
    local location = entry and entry.locations and entry.locations[1]
    if not location then return "–" end
    return tostring(location.bag or location.bagID or "?") .. " / " .. tostring(location.slot or location.slotID or "?")
end

function TradeWindow:Refresh()
    if not self:EnsureFrame() then return end
    local pending = (GA.Trade and GA.Trade:GetPending()) or {}; self.totalPages = math.max(1, math.ceil(#pending / self.pageSize)); self.page = math.min(self.page, self.totalPages); local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local entry = pending[offset + index]
        if entry then row.entry = entry; row.item:SetText(entry.itemLink or "Unbekannt"); row.target:SetText(entry.winner or "–"); row.state:SetText(entry.status or "–"); row.location:SetText(locationText(entry)); row:Show() else row.entry = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages); if self.page > 1 then self.previous:Enable() else self.previous:Disable() end; if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
    local state = GA.Trade and GA.Trade:GetState() or {}; self.stateLabel:SetText("Handel: " .. tostring(state.status or "IDLE") .. (state.partner and (" mit " .. state.partner) or ""))
end

function TradeWindow:Select(entry)
    if not entry then return end; self.selected = entry; self.selectedLabel:SetText("Auswahl: " .. (entry.itemLink or "Item") .. " → " .. tostring(entry.winner or "–")); self.prepare:Enable(); self.delivered:Enable(); self.failed:Enable()
end
function TradeWindow:PrepareSelected()
    if not self.selected then return end; local entry, err = GA.Trade:Prepare(self.selected.id); if not entry then self.selectedLabel:SetText(err or "Item nicht gefunden.") end; self:Refresh()
end
function TradeWindow:MarkDelivered()
    if not self.selected then return end; GA.Trade:MarkDelivered(self.selected.id, "MANUAL_UI"); self:Refresh()
end
function TradeWindow:MarkFailed()
    if not self.selected then return end
    if type(GA.Trade.MarkFailed) == "function" then GA.Trade:MarkFailed(self.selected.id, "MANUAL_UI")
    else self.selected.status = "MISSING"; self.selected.updatedAt = (time and time()) or 0; self.selected.deliveryReason = "MANUAL_UI"; GA.Events:Emit("GA_TRADE_PENDING_UPDATED", self.selected) end
    self:Refresh()
end
function TradeWindow:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show() end end
function TradeWindow:Hide() if self.frame then self.frame:Hide() end end
function TradeWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function TradeWindow:OnInitialize()
    self:EnsureFrame(); local refresh = function() TradeWindow:Refresh() end
    for _, event in ipairs({ "GA_TRADE_PENDING_ADDED", "GA_TRADE_PENDING_UPDATED", "GA_TRADE_PENDING_REMOVED", "GA_TRADE_STATE_CHANGED", "GA_TRADE_COMPLETED" }) do GA.Events:On(event, refresh, self) end
    return true
end

GA:RegisterModule("TradeWindow", TradeWindow)
