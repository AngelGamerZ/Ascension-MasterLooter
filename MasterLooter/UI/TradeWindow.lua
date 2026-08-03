local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local TradeWindow = { page = 1, pageSize = 8 }
GA.UI.TradeWindow = TradeWindow

local function remainingText(expires)
    if not expires then return "unbekannt" end
    local left = expires - ((time and time()) or 0)
    if left <= 0 then return "abgelaufen?" end
    return math.floor(left / 3600) .. "h " .. math.floor((left % 3600) / 60) .. "m"
end

function TradeWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterTradeWindow", UIParent)
    frame:SetWidth(650); frame:SetHeight(430); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Handelsassistent")
    Theme:MakeMovable(frame, "tradeWindowV2"); Theme:RestorePosition(frame, "tradeWindowV2", "CENTER", 120, 20); Theme:RegisterForEscape(frame); self.frame = frame
    local state = Theme:CreateLabel(frame, "Handel: IDLE", 12, Theme.colors.muted); state:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -46); state:SetWidth(400); self.stateLabel = state
    local refresh = Theme:CreateButton(frame, "Handel öffnen", 115, 24); refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -40); refresh:SetScript("OnClick", function() TradeWindow:OpenSelectedTrade() end)
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -77); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 108)
    Theme:ApplyInset(list); self.list = list
    for _, data in ipairs({ { "Gewinner", 10 }, { "Items", 210 }, { "Bereit", 385 }, { "Frist (ca.)", 500 } }) do
        local label = Theme:CreateLabel(list, data[1], 12, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", data[2], -10)
    end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(29); row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -31 - (index - 1) * 29); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -31 - (index - 1) * 29)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.winner = Theme:CreateLabel(row, "", 12); row.winner:SetPoint("LEFT", row, "LEFT", 4, 0); row.winner:SetWidth(190)
        row.items = Theme:CreateLabel(row, "", 12); row.items:SetPoint("LEFT", row, "LEFT", 204, 0); row.items:SetWidth(165)
        row.ready = Theme:CreateLabel(row, "", 12); row.ready:SetPoint("LEFT", row, "LEFT", 379, 0); row.ready:SetWidth(105)
        row.deadline = Theme:CreateLabel(row, "", 12); row.deadline:SetPoint("LEFT", row, "LEFT", 494, 0); row.deadline:SetWidth(95)
        row:SetScript("OnClick", function() TradeWindow:Select(row.group) end)
        row:SetScript("OnEnter", function(self) local entry = self.group and self.group.entries[1]; if entry and entry.itemLink then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(entry.itemLink); GameTooltip:Show() end end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end); self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 74); self.previous = previous
    previous:SetScript("OnClick", function() TradeWindow.page = math.max(1, TradeWindow.page - 1); TradeWindow:Refresh() end)
    local page = Theme:CreateLabel(frame, "1 / 1", 12, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0); self.next = nextButton
    nextButton:SetScript("OnClick", function() TradeWindow.page = math.min(TradeWindow.totalPages or 1, TradeWindow.page + 1); TradeWindow:Refresh() end)
    local selected = Theme:CreateLabel(frame, "Auswahl: –", 12); selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 47); selected:SetWidth(590); self.selectedLabel = selected
    local take = Theme:CreateButton(frame, "An mich nehmen", 125, 27); take:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 15); take:SetScript("OnClick", function() TradeWindow:TakePendingAward() end); take:Disable(); self.take = take
    local prepare = Theme:CreateButton(frame, "Taschen prüfen", 115, 27); prepare:SetPoint("LEFT", take, "RIGHT", 8, 0); prepare:SetScript("OnClick", function() TradeWindow:PrepareSelected() end); prepare:Disable(); self.prepare = prepare
    local place = Theme:CreateButton(frame, "Items einlegen", 115, 27); place:SetPoint("LEFT", prepare, "RIGHT", 8, 0); place:SetScript("OnClick", function() TradeWindow:PlaceSelected() end); place:Disable(); self.place = place
    local note = Theme:CreateLabel(frame, "Items werden beim richtigen Partner automatisch eingelegt; Bestätigung bleibt manuell.", 12, Theme.colors.muted); note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 22); note:SetWidth(260); note:SetJustifyH("RIGHT")
    return frame
end

function TradeWindow:Refresh()
    if not self:EnsureFrame() then return end
    local groups = (GA.Trade and GA.Trade:GetGroups()) or {}
    self.totalPages = math.max(1, math.ceil(#groups / self.pageSize)); self.page = math.min(self.page, self.totalPages)
    local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local group = groups[offset + index]
        if group then
            row.group = group; row.winner:SetText(group.winner or "Unbekannt"); row.items:SetText(tostring(#group.entries) .. " Einträge / " .. tostring(group.quantity))
            row.ready:SetText(tostring(group.ready) .. " bereit" .. (group.missing > 0 and (", " .. group.missing .. " fehlt") or "")); row.deadline:SetText(remainingText(group.tradeExpiresAt)); row:Show()
        else row.group = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages); if self.page > 1 then self.previous:Enable() else self.previous:Disable() end; if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
    local state = GA.Trade and GA.Trade:GetState() or {}; self.stateLabel:SetText("Handel: " .. tostring(state.status or "IDLE") .. (state.partner and (" mit " .. state.partner) or "") .. (state.autoPlaced and state.autoPlaced > 0 and (" – " .. state.autoPlaced .. " automatisch eingelegt") or ""))
    local deferred = GA.Award and GA.Award:GetDeferred() or {}; self.pendingAward = deferred[1]
    if self.pendingAward then self.take:Enable(); self.selectedLabel:SetText("Aktion nötig: " .. (self.pendingAward.itemLink or "Item") .. " für " .. tostring(self.pendingAward.winner)) else self.take:Disable() end
end

function TradeWindow:Select(group)
    if not group then return end
    self.selected = group; self.selectedLabel:SetText("Auswahl: " .. tostring(group.winner or "–") .. " (" .. tostring(#group.entries) .. " Items)"); self.prepare:Enable(); self.place:Enable()
end

function TradeWindow:PrepareSelected()
    if not self.selected then return end
    local ready, errors = GA.Trade:PrepareGroup(self.selected.winner)
    self.selectedLabel:SetText(tostring(#ready) .. " Items bereit" .. (#errors > 0 and (", " .. #errors .. " nicht bereit") or "")); self:Refresh()
end

function TradeWindow:PlaceSelected()
    if not self.selected then return end
    local placed, err = GA.Trade:PlacePreparedGroup(self.selected.winner)
    self.selectedLabel:SetText(placed and (tostring(#placed) .. " Items eingelegt; Handel manuell bestätigen.") or tostring(err)); self:Refresh()
end

function TradeWindow:OpenSelectedTrade()
    if not self.selected then self.selectedLabel:SetText("Zuerst einen Gewinner auswählen."); return end
    local opened, err = GA.Trade:BeginTrade(self.selected.winner)
    self.selectedLabel:SetText(opened and "Handel wird geöffnet; passende Items werden automatisch eingelegt." or tostring(err)); self:Refresh()
end

function TradeWindow:TakePendingAward()
    if not self.pendingAward then return end
    local attempt, err = GA.Award:TakeForTrade(self.pendingAward.id)
    self.selectedLabel:SetText(attempt and "Item wird an dich vergeben; Lootfenster offen lassen." or tostring(err)); self:Refresh()
end

function TradeWindow:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show() end end
function TradeWindow:Hide() if self.frame then self.frame:Hide() end end
function TradeWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function TradeWindow:OnInitialize()
    self:EnsureFrame(); local refresh = function() TradeWindow:Refresh() end
    for _, event in ipairs({ "GA_TRADE_PENDING_ADDED", "GA_TRADE_PENDING_UPDATED", "GA_TRADE_PENDING_REMOVED", "GA_TRADE_STATE_CHANGED", "GA_TRADE_COMPLETED" }) do GA.Events:On(event, refresh, self) end
    GA.Events:On("GA_AWARD_PENDING_CHANGED", function(_, _, _, reason)
        if reason == "ADDED" then TradeWindow:Show() else TradeWindow:Refresh() end
    end, self)
    return true
end

GA:RegisterModule("TradeWindow", TradeWindow)
