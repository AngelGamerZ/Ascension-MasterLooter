local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local GDKPAuctionWindow = { bids = {} }
GA.UI.GDKPAuctionWindow = GDKPAuctionWindow

local function field(source, ...)
    if type(source) ~= "table" then return nil end
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if source[key] ~= nil then return source[key] end
    end
end

local function eventState(expected, ...)
    if select(2, ...) == expected then return select(3, ...), select(4, ...) end
    if select(1, ...) == expected then return select(2, ...), select(3, ...) end
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "table" then return candidate end
    end
end

local function shortName(name)
    return type(name) == "string" and (string.match(name, "^[^-]+") or name) or nil
end

local function samePlayer(left, right)
    left, right = shortName(left), shortName(right)
    return left and right and string.lower(left) == string.lower(right)
end

local function sortedBids(state)
    local source = field(state, "bids", "history", "bidHistory") or {}
    local result = {}
    for key, bid in pairs(source) do
        if type(bid) == "table" then
            result[#result + 1] = {
                player = field(bid, "player", "bidder", "name") or (type(key) == "string" and key) or "?",
                amount = tonumber(field(bid, "amount", "bid", "value")) or 0,
                time = tonumber(field(bid, "time", "createdAt", "receivedAt")) or 0,
                sequence = tonumber(field(bid, "sequence", "index")) or 0,
            }
        end
    end
    table.sort(result, function(left, right)
        if left.sequence ~= right.sequence then return left.sequence > right.sequence end
        if left.time ~= right.time then return left.time > right.time end
        return left.amount > right.amount
    end)
    return result
end

function GDKPAuctionWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterGDKPAuctionWindow", UIParent)
    frame:SetWidth(600); frame:SetHeight(520); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "GDKP-Auktion")
    Theme:MakeMovable(frame, "gdkpAuctionWindow"); Theme:RestorePosition(frame, "gdkpAuctionWindow", "CENTER", 0, 25); Theme:RegisterForEscape(frame)
    self.frame = frame

    local itemLabel = Theme:CreateLabel(frame, "Itemlink", 11, Theme.colors.gold); itemLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -46)
    local item = Theme:CreateEditBox(frame, 285, 24); item:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64); self.itemEdit = item
    item:SetScript("OnReceiveDrag", function() GDKPAuctionWindow:AcceptCursorItem() end)
    local start = Theme:CreateButton(frame, "Start", 75, 25); start:SetPoint("LEFT", item, "RIGHT", 8, 0); start:SetScript("OnClick", function() GDKPAuctionWindow:StartAuction() end); self.startButton = start
    local enqueue = Theme:CreateButton(frame, "Queue", 75, 25); enqueue:SetPoint("LEFT", start, "RIGHT", 5, 0); enqueue:SetScript("OnClick", function() GDKPAuctionWindow:QueueAuction() end); self.queueButton = enqueue
    local parallel = Theme:CreateButton(frame, "Multi", 65, 25); parallel:SetPoint("LEFT", enqueue, "RIGHT", 5, 0); parallel:SetScript("OnClick", function() GDKPAuctionWindow:StartParallelAuction() end); self.parallelButton = parallel
    self.queueLabel = Theme:CreateLabel(frame, "Queue: 0", 11, Theme.colors.muted); self.queueLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -101)

    local definitions = {
        { label = "Mindestgebot", x = 22, width = 100, default = "100" },
        { label = "Schritt", x = 155, width = 80, default = "10" },
        { label = "Dauer", x = 270, width = 80, default = "30" },
    }
    self.authorityInputs = {}
    for _, definition in ipairs(definitions) do
        local label = Theme:CreateLabel(frame, definition.label, 11, Theme.colors.gold); label:SetPoint("TOPLEFT", frame, "TOPLEFT", definition.x, -101)
        local edit = Theme:CreateEditBox(frame, definition.width, 24, true); edit:SetPoint("TOPLEFT", frame, "TOPLEFT", definition.x, -119); edit:SetText(definition.default)
        self.authorityInputs[#self.authorityInputs + 1] = edit
    end
    self.minBidEdit, self.incrementEdit, self.durationEdit = self.authorityInputs[1], self.authorityInputs[2], self.authorityInputs[3]
    local stop = Theme:CreateButton(frame, "Stoppen", 105, 25); stop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -117); stop:SetScript("OnClick", function() GDKPAuctionWindow:StopAuction() end); stop:Disable(); self.stopButton = stop

    local current = CreateFrame("Frame", nil, frame); current:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -157); current:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -157); current:SetHeight(76); Theme:ApplyInset(current)
    local currentBid = Theme:CreateLabel(current, "Aktuelles Gebot: –", 14, Theme.colors.gold); currentBid:SetPoint("TOPLEFT", current, "TOPLEFT", 15, -14); self.currentBidLabel = currentBid
    local bidder = Theme:CreateLabel(current, "Bieter: –", 12); bidder:SetPoint("TOPLEFT", current, "TOPLEFT", 15, -43); self.bidderLabel = bidder
    local timer = Theme:CreateLabel(current, "0:00", 14, Theme.colors.gold); timer:SetPoint("RIGHT", current, "RIGHT", -18, 0); timer:SetWidth(70); timer:SetJustifyH("RIGHT"); self.timerLabel = timer

    local bidLabel = Theme:CreateLabel(frame, "Dein Gebot", 11, Theme.colors.gold); bidLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -250)
    local bid = Theme:CreateEditBox(frame, 150, 26, true); bid:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -268); self.bidEdit = bid
    local bidButton = Theme:CreateButton(frame, "Bieten", 105, 27); bidButton:SetPoint("LEFT", bid, "RIGHT", 9, 0); bidButton:SetScript("OnClick", function() GDKPAuctionWindow:Bid() end); bidButton:Disable(); self.bidButton = bidButton
    bid:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GDKPAuctionWindow:Bid() end)
    local result = Theme:CreateLabel(frame, "Keine aktive Auktion.", 11, Theme.colors.muted); result:SetPoint("LEFT", bidButton, "RIGHT", 12, 0); result:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.resultLabel = result

    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -313); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 22); Theme:ApplyInset(list)
    local playerHeader = Theme:CreateLabel(list, "Letzte Gebote", 11, Theme.colors.gold); playerHeader:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -9)
    local amountHeader = Theme:CreateLabel(list, "Betrag", 11, Theme.colors.gold); amountHeader:SetPoint("TOPRIGHT", list, "TOPRIGHT", -15, -9)
    self.rows = {}
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, list); row:SetHeight(18); row:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -28 - ((index - 1) * 19)); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -28 - ((index - 1) * 19))
        row.player = Theme:CreateLabel(row, "", 11); row.player:SetPoint("LEFT", row, "LEFT", 2, 0); row.player:SetWidth(380)
        row.amount = Theme:CreateLabel(row, "", 11, Theme.colors.gold); row.amount:SetPoint("RIGHT", row, "RIGHT", -4, 0); row.amount:SetJustifyH("RIGHT")
        self.rows[index] = row
    end
    frame:SetScript("OnUpdate", function(_, elapsed) GDKPAuctionWindow:OnUpdate(elapsed) end)

    if hooksecurefunc and type(ChatEdit_InsertLink) == "function" and not GA.UI.gdkpAuctionLinkHooked then
        GA.UI.gdkpAuctionLinkHooked = true
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if GDKPAuctionWindow.itemEdit and GDKPAuctionWindow.itemEdit:HasFocus() then GDKPAuctionWindow.itemEdit:SetText(link or "") end
        end)
    end
    return frame
end

function GDKPAuctionWindow:QueueAuction()
    local itemLink, minimum, increment, duration = self.itemEdit:GetText(), tonumber(self.minBidEdit:GetText()), tonumber(self.incrementEdit:GetText()), tonumber(self.durationEdit:GetText())
    local manager = GA.GDKPAuction
    if not manager or type(manager.Enqueue) ~= "function" then self:SetResult("Auktionsqueue nicht verfügbar.", Theme.colors.red); return end
    local ok, result, err = pcall(manager.Enqueue, manager, itemLink, minimum, increment, duration)
    if ok and result then self.itemEdit:SetText(""); self:RefreshQueue(); self:SetResult("Item gestartet oder eingereiht.", Theme.colors.green)
    else self:SetResult(tostring(err or result or "Einreihen fehlgeschlagen."), Theme.colors.red) end
end

function GDKPAuctionWindow:RefreshQueue()
    local queue = GA.GDKPAuction and GA.GDKPAuction.GetQueue and GA.GDKPAuction:GetQueue() or {}
    local multi, active = GA.GDKPMultiAuction and GA.GDKPMultiAuction:GetAuctions() or {}, 0
    for _, state in ipairs(multi) do if state.status == "ACTIVE" then active = active + 1 end end
    if self.queueLabel then self.queueLabel:SetText("Queue: " .. tostring(#queue) .. " · Multi: " .. tostring(active)) end
end

function GDKPAuctionWindow:StartParallelAuction()
    local manager = GA.GDKPMultiAuction
    if not manager then self:SetResult("Multi-Auktionen nicht verfügbar.", Theme.colors.red); return end
    local state, err = manager:Start(self.itemEdit:GetText(), tonumber(self.minBidEdit:GetText()), tonumber(self.incrementEdit:GetText()), tonumber(self.durationEdit:GetText()))
    if state then self:UpdateState(state); self:SetResult("Parallele Auktion gestartet.", Theme.colors.green) else self:SetResult(err, Theme.colors.red) end
end

function GDKPAuctionWindow:AcceptCursorItem()
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType ~= "item" then return end
    itemLink = itemLink or select(2, GetItemInfo(itemID))
    if itemLink then self.itemEdit:SetText(itemLink) end
    ClearCursor()
end

function GDKPAuctionWindow:SetResult(text, color)
    self.resultLabel:SetText(text or ""); self.resultLabel:SetTextColor(unpack(color or Theme.colors.muted))
end

function GDKPAuctionWindow:StartAuction()
    local itemLink = self.itemEdit:GetText(); local minBid = tonumber(self.minBidEdit:GetText()); local increment = tonumber(self.incrementEdit:GetText()); local duration = tonumber(self.durationEdit:GetText())
    if not string.find(itemLink or "", "|Hitem:") or not minBid or not increment or not duration then self:SetResult("Item und gültige Zahlen sind erforderlich.", Theme.colors.red); return end
    minBid, increment, duration = math.max(0, math.floor(minBid)), math.max(1, math.floor(increment)), math.max(5, math.min(600, math.floor(duration)))
    local manager = GA.GDKPAuction; if not manager or type(manager.Start) ~= "function" then self:SetResult("Auktionsmodul nicht verfügbar.", Theme.colors.red); return end
    local ok, state, err = pcall(manager.Start, manager, itemLink, minBid, increment, duration)
    if ok and state then self:UpdateState(state); self:SetResult("Auktion gestartet.", Theme.colors.green) else self:SetResult(tostring(err or state or "Start fehlgeschlagen."), Theme.colors.red) end
end

function GDKPAuctionWindow:StopAuction()
    local parallel = self.state and GA.GDKPMultiAuction and GA.GDKPMultiAuction:Get(self.state.id)
    local manager = parallel and GA.GDKPMultiAuction or GA.GDKPAuction; if not manager or type(manager.Stop) ~= "function" then return end
    local ok, result, err
    if parallel then ok, result, err = pcall(manager.Stop, manager, self.state.id) else ok, result, err = pcall(manager.Stop, manager) end
    if ok and result ~= false and result ~= nil then self:SetResult("Auktion beendet.") else self:SetResult(tostring(err or result or "Stop fehlgeschlagen."), Theme.colors.red) end
end

function GDKPAuctionWindow:Bid()
    local amount = tonumber(self.bidEdit:GetText())
    if not amount then self:SetResult("Bitte einen gültigen Betrag eingeben.", Theme.colors.red); return end
    local parallel = self.state and GA.GDKPMultiAuction and GA.GDKPMultiAuction:Get(self.state.id)
    local manager = parallel and GA.GDKPMultiAuction or GA.GDKPAuction; if not manager or type(manager.Bid) ~= "function" then self:SetResult("Auktionsmodul nicht verfügbar.", Theme.colors.red); return end
    local ok, result, err
    if parallel then ok, result, err = pcall(manager.Bid, manager, self.state.id, math.floor(amount)) else ok, result, err = pcall(manager.Bid, manager, math.floor(amount)) end
    if ok and result then self:SetResult("Gebot gesendet: " .. math.floor(amount) .. "g", Theme.colors.green) else self:SetResult(tostring(err or result or "Gebot abgelehnt."), Theme.colors.red) end
end

function GDKPAuctionWindow:UpdateState(state)
    if type(state) ~= "table" then return end
    self:EnsureFrame(); self.state = state
    self:RefreshQueue()
    local itemLink = field(state, "itemLink", "link"); if itemLink then self.itemEdit:SetText(itemLink) end
    local minBid = tonumber(field(state, "minBid", "minimumBid"))
    local increment = tonumber(field(state, "increment", "bidIncrement"))
    local duration = tonumber(field(state, "duration", "seconds"))
    if minBid then self.minBidEdit:SetText(tostring(minBid)) end
    if increment then self.incrementEdit:SetText(tostring(increment)) end
    if duration then self.durationEdit:SetText(tostring(duration)) end
    local currentBid = tonumber(field(state, "currentBid", "highestBid", "bid")) or 0
    local bidder = field(state, "currentBidder", "highestBidder", "bidder")
    self.currentBidLabel:SetText("Aktuelles Gebot: " .. currentBid .. "g")
    self.bidderLabel:SetText("Bieter: " .. tostring(bidder or "–"))
    self.endsAt = tonumber(field(state, "expiresAt", "endsAt", "endTime"))
    self.bids = sortedBids(state)
    for index, row in ipairs(self.rows) do
        local entry = self.bids[index]
        if entry then row.player:SetText(entry.player); row.amount:SetText(entry.amount .. "g"); row:Show() else row:Hide() end
    end
    if not self.bidEdit:HasFocus() then self.bidEdit:SetText(tostring(currentBid > 0 and (currentBid + (increment or 1)) or (minBid or 0))) end
    local status = string.upper(tostring(field(state, "status") or "ACTIVE")); local active = status == "ACTIVE" or status == "RUNNING"
    local owner = field(state, "owner", "authority", "auctioneer"); local me = UnitName and UnitName("player")
    local authority = not owner or samePlayer(owner, me)
    if active then self.bidButton:Enable() else self.bidButton:Disable() end
    if active and authority then self.stopButton:Enable() else self.stopButton:Disable() end
    if active then self.startButton:Disable() else self.startButton:Enable() end
end

function GDKPAuctionWindow:EndState(state, reason)
    if type(state) == "table" then self:UpdateState(state) end
    self.endsAt = nil; self.bidButton:Disable(); self.stopButton:Disable(); self.startButton:Enable()
    local winner = state and field(state, "winner", "currentBidder", "highestBidder")
    self:SetResult(winner and ("Beendet – Gewinner: " .. winner) or (type(reason) == "string" and reason or "Auktion beendet."), Theme.colors.gold)
end

function GDKPAuctionWindow:OnUpdate(elapsed)
    if not self.endsAt or not self.frame:IsShown() then return end
    self.elapsed = (self.elapsed or 0) + elapsed; if self.elapsed < 0.1 then return end; self.elapsed = 0
    local remaining = self.endsAt - GetTime(); self.timerLabel:SetText(Theme:FormatTime(remaining))
    if remaining <= 0 then self.endsAt = nil; self.bidButton:Disable(); self.stopButton:Disable() end
end

function GDKPAuctionWindow:Show()
    local frame = self:EnsureFrame(); if not frame then return end
    if GA.GDKPAuction and type(GA.GDKPAuction.GetState) == "function" then local state = GA.GDKPAuction:GetState(); if state then self:UpdateState(state) end end
    frame:Show()
end
function GDKPAuctionWindow:Hide() if self.frame then self.frame:Hide() end end
function GDKPAuctionWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function GDKPAuctionWindow:OnInitialize()
    self:EnsureFrame()
    GA.Events:On("GA_GDKP_AUCTION_STARTED", function(...) local state = eventState("GA_GDKP_AUCTION_STARTED", ...); GDKPAuctionWindow:UpdateState(state); GDKPAuctionWindow.frame:Show() end, self)
    GA.Events:On("GA_GDKP_AUCTION_UPDATED", function(...) GDKPAuctionWindow:UpdateState(eventState("GA_GDKP_AUCTION_UPDATED", ...)) end, self)
    GA.Events:On("GA_GDKP_AUCTION_ENDED", function(...) local state, reason = eventState("GA_GDKP_AUCTION_ENDED", ...); GDKPAuctionWindow:EndState(state, reason) end, self)
    GA.Events:On("GA_GDKP_AUCTION_QUEUE_CHANGED", function() GDKPAuctionWindow:RefreshQueue() end, self)
    GA.Events:On("GA_GDKP_MULTI_CHANGED", function(_, _, state, action)
        GDKPAuctionWindow:RefreshQueue()
        if state and action ~= "REMOVE" then GDKPAuctionWindow:UpdateState(state) end
    end, self)
    return true
end

GA:RegisterModule("GDKPAuctionWindow", GDKPAuctionWindow)
