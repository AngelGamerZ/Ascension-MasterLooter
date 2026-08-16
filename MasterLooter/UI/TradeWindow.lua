local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local TradeWindow = { page = 1, pageSize = 8, filterMode = "ALL", expandedHeight = 500 }
GA.UI.TradeWindow = TradeWindow

local function remainingText(expires)
    if not expires then return "unbekannt" end
    local left = expires - ((time and time()) or 0)
    if left <= 0 then return "abgelaufen?" end
    return math.floor(left / 3600) .. "h " .. math.floor((left % 3600) / 60) .. "m"
end

local function progressText(expires)
    if not expires then return "[????????] unbekannt" end
    local left = math.max(0, expires - ((time and time()) or 0))
    local filled = math.max(0, math.min(8, math.ceil((left / 7200) * 8)))
    return "[" .. string.rep("=", filled) .. string.rep(".", 8 - filled) .. "] " .. remainingText(expires)
end

function TradeWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterTradeWindow", UIParent)
    frame:SetWidth(650); frame:SetHeight(self.expandedHeight); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Handelsassistent")
    Theme:MakeMovable(frame, "tradeWindowV2"); Theme:RestorePosition(frame, "tradeWindowV2", "CENTER", 120, 20); Theme:RegisterForEscape(frame); self.frame = frame
    local state = Theme:CreateLabel(frame, "Handel: IDLE", 12, Theme.colors.muted); state:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -46); state:SetWidth(400); self.stateLabel = state
    local refresh = Theme:CreateButton(frame, "Handel öffnen", 115, 24); refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -62, -40); refresh:SetScript("OnClick", function() TradeWindow:OpenSelectedTrade() end)
    local minimize = Theme:CreateButton(frame, "_", 32, 24); minimize:SetPoint("LEFT", refresh, "RIGHT", 6, 0); minimize:SetScript("OnClick", function() TradeWindow:SetMinimized(not TradeWindow.minimized) end); self.minimize = minimize
    local filter = Theme:CreateButton(frame, "Filter: Offen", 115, 23); filter:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -73); filter:SetScript("OnClick", function() TradeWindow:CycleFilter() end); self.filterButton = filter
    local broadcast = Theme:CreateButton(frame, "Liste posten", 110, 23); broadcast:SetPoint("LEFT", filter, "RIGHT", 8, 0); broadcast:SetScript("OnClick", function() TradeWindow:Broadcast() end); self.broadcastButton = broadcast
    local estimate = Theme:CreateLabel(frame, "Fristen sind lokale 3.3.5a-Schätzungen", 11, Theme.colors.muted); estimate:SetPoint("LEFT", broadcast, "RIGHT", 10, 0); estimate:SetWidth(320); self.estimateLabel = estimate
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -105); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 128)
    Theme:ApplyInset(list); self.list = list
    for _, data in ipairs({ { "Gewinner", 10 }, { "Items", 190 }, { "Bereit", 340 }, { "Restzeit (geschätzt)", 440 } }) do
        local label = Theme:CreateLabel(list, data[1], 12, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", data[2], -10)
    end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(29); row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -31 - (index - 1) * 29); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -31 - (index - 1) * 29)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.winner = Theme:CreateLabel(row, "", 12); row.winner:SetPoint("LEFT", row, "LEFT", 4, 0); row.winner:SetWidth(190)
        row.items = Theme:CreateLabel(row, "", 12); row.items:SetPoint("LEFT", row, "LEFT", 184, 0); row.items:SetWidth(140)
        row.ready = Theme:CreateLabel(row, "", 12); row.ready:SetPoint("LEFT", row, "LEFT", 334, 0); row.ready:SetWidth(90)
        row.deadline = Theme:CreateLabel(row, "", 11); row.deadline:SetPoint("LEFT", row, "LEFT", 434, 0); row.deadline:SetWidth(165)
        row:SetScript("OnClick", function() TradeWindow:Select(row.group) end)
        row:SetScript("OnEnter", function(self) local entry = self.group and self.group.entries[1]; if entry and entry.itemLink then Theme:ShowItemTooltip(self, entry.itemLink) end end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end); self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 94); self.previous = previous
    previous:SetScript("OnClick", function() TradeWindow.page = math.max(1, TradeWindow.page - 1); TradeWindow:Refresh() end)
    local page = Theme:CreateLabel(frame, "1 / 1", 12, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0); self.next = nextButton
    nextButton:SetScript("OnClick", function() TradeWindow.page = math.min(TradeWindow.totalPages or 1, TradeWindow.page + 1); TradeWindow:Refresh() end)
    local clear = Theme:CreateButton(frame, "Alles leeren", 115, 23); clear:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 90); self.clearButton = clear
    clear:SetScript("OnClick", function() TradeWindow:RequestClear() end)
    local selected = Theme:CreateLabel(frame, "Auswahl: –", 12); selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 63); selected:SetWidth(590); self.selectedLabel = selected
    local take = Theme:CreateButton(frame, "An mich nehmen", 125, 27); take:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 29); take:SetScript("OnClick", function() TradeWindow:TakePendingAward() end); take:Disable(); self.take = take
    local prepare = Theme:CreateButton(frame, "Taschen prüfen", 115, 27); prepare:SetPoint("LEFT", take, "RIGHT", 8, 0); prepare:SetScript("OnClick", function() TradeWindow:PrepareSelected() end); prepare:Disable(); self.prepare = prepare
    local place = Theme:CreateButton(frame, "Items einlegen", 115, 27); place:SetPoint("LEFT", prepare, "RIGHT", 8, 0); place:SetScript("OnClick", function() TradeWindow:PlaceSelected() end); place:Disable(); self.place = place
    local delivered = Theme:CreateButton(frame, "Als vergeben", 95, 27); delivered:SetPoint("LEFT", place, "RIGHT", 8, 0); delivered:SetScript("OnClick", function() TradeWindow:CloseSelected(true) end); delivered:Disable(); self.delivered = delivered
    local cancel = Theme:CreateButton(frame, "Abbrechen", 95, 27); cancel:SetPoint("LEFT", delivered, "RIGHT", 8, 0); cancel:SetScript("OnClick", function() TradeWindow:CloseSelected(false) end); cancel:Disable(); self.cancel = cancel
    local note = Theme:CreateLabel(frame, "Items werden eingelegt; den Handel immer selbst annehmen.", 11, Theme.colors.muted); note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 8); note:SetWidth(590); note:SetJustifyH("RIGHT")
    frame:SetScript("OnUpdate", function(_, elapsed) TradeWindow.updateElapsed = (TradeWindow.updateElapsed or 0) + (elapsed or 0); if TradeWindow.updateElapsed >= 1 then TradeWindow.updateElapsed = 0; TradeWindow:Refresh() end end)
    return frame
end

function TradeWindow:SetMinimized(minimized)
    self.minimized = minimized and true or false
    for _, control in ipairs({ self.list, self.previous, self.pageLabel, self.next, self.clearButton, self.selectedLabel, self.take, self.prepare, self.place, self.delivered, self.cancel, self.filterButton, self.broadcastButton, self.estimateLabel }) do
        if control then if self.minimized then control:Hide() else control:Show() end end
    end
    self.frame:SetHeight(self.minimized and 105 or self.expandedHeight)
    self.minimize:SetText(self.minimized and "+" or "_")
end

function TradeWindow:CycleFilter()
    self.filterMode = self.filterMode == "ALL" and "READY" or (self.filterMode == "READY" and "PROBLEMS" or "ALL")
    self.page = 1; self:Refresh()
end

function TradeWindow:Broadcast()
    local sent, err = GA.Trade and GA.Trade:BroadcastPending()
    self.selectedLabel:SetText(sent and (tostring(sent) .. " Handelsgruppen gepostet.") or tostring(err)); self:Refresh()
end

function TradeWindow:RequestClear()
    if not self.clearArmed then
        self.clearArmed = true
        self.clearButton:SetText("Wirklich leeren")
        self.selectedLabel:SetText("Noch einmal klicken: alle offenen Vergaben und Handelsaufgaben werden entfernt.")
        if GA.Compat and type(GA.Compat.After) == "function" then
            GA.Compat:After(6, function()
                if TradeWindow.clearArmed then
                    TradeWindow.clearArmed = false
                    TradeWindow.clearButton:SetText("Alles leeren")
                    TradeWindow:Refresh()
                end
            end)
        end
        return false
    end
    self.clearArmed = false
    self.clearButton:SetText("Alles leeren")
    local trades = GA.Trade and type(GA.Trade.ClearPending) == "function" and GA.Trade:ClearPending() or 0
    local awards = GA.Award and type(GA.Award.ClearDeferred) == "function" and GA.Award:ClearDeferred() or 0
    self.selected, self.pendingAward, self.page = nil, nil, 1
    self.prepare:Disable(); self.place:Disable(); self.take:Disable(); self.delivered:Disable(); self.cancel:Disable()
    self:Refresh()
    self.selectedLabel:SetText(tostring((tonumber(trades) or 0) + (tonumber(awards) or 0)) .. " offene Einträge gelöscht.")
    return true
end

function TradeWindow:Refresh()
    if not self:EnsureFrame() then return end
    local source, groups = (GA.Trade and GA.Trade:GetGroups()) or {}, {}
    for _, group in ipairs(source) do
        local show = self.filterMode == "ALL" or (self.filterMode == "READY" and group.ready > 0) or
            (self.filterMode == "PROBLEMS" and group.missing > 0)
        if show then groups[#groups + 1] = group end
    end
    self.totalPages = math.max(1, math.ceil(#groups / self.pageSize)); self.page = math.min(self.page, self.totalPages)
    local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local group = groups[offset + index]
        if group then
            row.group = group; row.winner:SetText(group.winner or "Unbekannt"); row.items:SetText(tostring(#group.entries) .. " Einträge / " .. tostring(group.quantity))
            row.ready:SetText(tostring(group.ready) .. " bereit" .. (group.missing > 0 and (", " .. group.missing .. " fehlt") or "")); row.deadline:SetText(progressText(group.tradeExpiresAt)); row:Show()
        else row.group = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages); if self.page > 1 then self.previous:Enable() else self.previous:Disable() end; if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
    self.filterButton:SetText(self.filterMode == "READY" and "Filter: Bereit" or (self.filterMode == "PROBLEMS" and "Filter: Probleme" or "Filter: Offen"))
    local state = GA.Trade and GA.Trade:GetState() or {}; self.stateLabel:SetText("Handel: " .. tostring(state.status or "IDLE") .. (state.partner and (" mit " .. state.partner) or "") .. (state.autoPlaced and state.autoPlaced > 0 and (" – " .. state.autoPlaced .. " automatisch eingelegt") or ""))
    local deferred = GA.Award and GA.Award:GetDeferred() or {}; self.pendingAward = deferred[1]
    if self.pendingAward then self.take:Enable(); self.selectedLabel:SetText("Aktion nötig: " .. (self.pendingAward.itemLink or "Item") .. " für " .. tostring(self.pendingAward.winner)) else self.take:Disable() end
end

function TradeWindow:Select(group)
    if not group then return end
    self.selected = group
    local index = 1
    if self.selectedEntry then
        for current, entry in ipairs(group.entries) do
            if entry.id == self.selectedEntry.id then index = current < #group.entries and current + 1 or 1; break end
        end
    end
    self.selectedEntry = group.entries[index]
    self.selectedLabel:SetText("Auswahl: " .. tostring(group.winner or "–") .. " – " .. tostring(self.selectedEntry and self.selectedEntry.itemLink or "Item") ..
        (#group.entries > 1 and (" (" .. tostring(index) .. "/" .. tostring(#group.entries) .. "; erneut klicken zum Wechseln)") or ""))
    self.prepare:Enable(); self.place:Enable(); self.delivered:Enable(); self.cancel:Enable()
end

function TradeWindow:CloseSelected(delivered)
    local entry = self.selectedEntry
    if not entry or not GA.Trade then self.selectedLabel:SetText("Zuerst einen offenen Eintrag auswählen."); return false end
    local ok, closed
    if delivered and type(GA.Trade.MarkDelivered) == "function" then
        ok, closed = GA.Trade:MarkDelivered(entry.id, "MANUAL_CONFIRMATION")
    elseif not delivered and type(GA.Trade.Cancel) == "function" then
        ok, closed = GA.Trade:Cancel(entry.id, "MANUAL_CANCEL")
    end
    if ok and GA.Award and type(GA.Award.CloseMatchingTradeEntry) == "function" then
        GA.Award:CloseMatchingTradeEntry(closed or entry, delivered, delivered and "MANUAL_CONFIRMATION" or "MANUAL_CANCEL")
    end
    self.selected, self.selectedEntry = nil, nil
    self.prepare:Disable(); self.place:Disable(); self.delivered:Disable(); self.cancel:Disable()
    self:Refresh()
    self.selectedLabel:SetText(ok and (delivered and "Eintrag als vergeben markiert." or "Eintrag abgebrochen.") or tostring(closed or "Eintrag konnte nicht geschlossen werden."))
    return ok and true or false
end

function TradeWindow:PrepareSelected()
    if not self.selected then return end
    local ready, errors = GA.Trade:PrepareGroup(self.selected.winner)
    self.selectedLabel:SetText(tostring(#ready) .. " Items bereit" .. (#errors > 0 and (", " .. #errors .. " nicht bereit") or "")); self:Refresh()
end

function TradeWindow:PlaceSelected()
    if not self.selected then return end
    local placed, err = GA.Trade:PlacePreparedGroup(self.selected.winner)
    self.selectedLabel:SetText(placed and (tostring(#placed) .. " Items eingelegt; Handel bitte manuell annehmen.") or tostring(err)); self:Refresh()
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

function TradeWindow:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show(); if type(frame.Raise) == "function" then frame:Raise() end; return true end return false end
function TradeWindow:Hide() if self.frame then self.frame:Hide() end end
function TradeWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function TradeWindow:OnInitialize()
    self:EnsureFrame(); local refresh = function() TradeWindow:Refresh() end
    for _, event in ipairs({ "GA_TRADE_PENDING_ADDED", "GA_TRADE_PENDING_UPDATED", "GA_TRADE_PENDING_REMOVED", "GA_TRADE_STATE_CHANGED", "GA_TRADE_COMPLETED" }) do GA.Events:On(event, refresh, self) end
    GA.Events:On("GA_AWARD_PENDING_CHANGED", function(_, _, _, reason)
        -- Pending delivery work updates an already open assistant, but never
        -- forces this optional management window into the player's view.
        TradeWindow:Refresh()
    end, self)
    return true
end

GA:RegisterModule("TradeWindow", TradeWindow)
