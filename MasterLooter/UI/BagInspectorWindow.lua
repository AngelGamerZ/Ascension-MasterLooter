local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local BagInspectorWindow = { page = 1, pageSize = 8, items = {}, players = {}, playerIndex = 0 }
GA.UI.BagInspectorWindow = BagInspectorWindow

local function normalizeItems(snapshot)
    local source = type(snapshot) == "table" and (snapshot.items or snapshot.contents or snapshot.slots or snapshot) or {}
    local result = {}
    for key, item in pairs(source) do
        if type(item) == "table" then
            result[#result + 1] = {
                link = item.itemLink or item.link,
                quantity = tonumber(item.quantity or item.count or item.stackCount) or 1,
                bag = tonumber(item.bag or item.bagID) or 0,
                slot = tonumber(item.slot or item.slotID) or (type(key) == "number" and key) or 0,
            }
        end
    end
    table.sort(result, function(left, right) if left.bag ~= right.bag then return left.bag < right.bag end return left.slot < right.slot end)
    return result
end

local function normalizePlayers(source)
    local result = {}
    for key, player in pairs(type(source) == "table" and source or {}) do
        local name = type(player) == "table" and (player.name or player.player) or player
        if type(name) ~= "string" and type(key) == "string" then name = key end
        if type(name) == "string" and name ~= "" then result[#result + 1] = name end
    end
    table.sort(result, function(left, right) return string.lower(left) < string.lower(right) end)
    return result
end

function BagInspectorWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterBagInspectorWindow", UIParent)
    frame:SetWidth(650); frame:SetHeight(475); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Tascheninspektor")
    Theme:MakeMovable(frame, "bagInspectorWindow"); Theme:RestorePosition(frame, "bagInspectorWindow", "CENTER", 0, 10); Theme:RegisterForEscape(frame); self.frame = frame
    local targetLabel = Theme:CreateLabel(frame, "Zielspieler", 11, Theme.colors.gold); targetLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -47)
    local target = Theme:CreateEditBox(frame, 230, 24); target:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -65); self.targetEdit = target
    local choose = Theme:CreateButton(frame, "Nächster Spieler", 125, 25); choose:SetPoint("LEFT", target, "RIGHT", 8, 0); choose:SetScript("OnClick", function() BagInspectorWindow:NextPlayer() end)
    local request = Theme:CreateButton(frame, "Anfragen", 105, 25); request:SetPoint("LEFT", choose, "RIGHT", 8, 0); request:SetScript("OnClick", function() BagInspectorWindow:Request() end)
    target:SetScript("OnEnterPressed", function(self) self:ClearFocus(); BagInspectorWindow:Request() end)
    local status = Theme:CreateLabel(frame, "Kein Snapshot geladen.", 11, Theme.colors.muted); status:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -101); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.status = status
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -126); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 75); Theme:ApplyInset(list)
    local headers = { { "Item", 12 }, { "Menge", 420 }, { "Tasche", 500 }, { "Slot", 565 } }
    for _, definition in ipairs(headers) do local label = Theme:CreateLabel(list, definition[1], 11, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", definition[2], -10) end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(29); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -31 - ((index - 1) * 30)); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -31 - ((index - 1) * 30)); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.item = Theme:CreateLabel(row, "", 11); row.item:SetPoint("LEFT", row, "LEFT", 5, 0); row.item:SetWidth(395)
        row.quantity = Theme:CreateLabel(row, "", 11); row.quantity:SetPoint("LEFT", row, "LEFT", 413, 0); row.quantity:SetWidth(65)
        row.bag = Theme:CreateLabel(row, "", 11); row.bag:SetPoint("LEFT", row, "LEFT", 493, 0); row.bag:SetWidth(50)
        row.slot = Theme:CreateLabel(row, "", 11); row.slot:SetPoint("LEFT", row, "LEFT", 558, 0); row.slot:SetWidth(45)
        row:SetScript("OnEnter", function(self) if self.entry and self.entry.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.link); GameTooltip:Show() end end); row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 28); previous:SetScript("OnClick", function() BagInspectorWindow.page = math.max(1, BagInspectorWindow.page - 1); BagInspectorWindow:Render() end); self.previous = previous
    local page = Theme:CreateLabel(frame, "1 / 1", 11, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); page:SetWidth(90); page:SetJustifyH("CENTER"); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0); nextButton:SetScript("OnClick", function() BagInspectorWindow.page = math.min(BagInspectorWindow.totalPages or 1, BagInspectorWindow.page + 1); BagInspectorWindow:Render() end); self.next = nextButton
    return frame
end

function BagInspectorWindow:Render(snapshot, player)
    if not self:EnsureFrame() then return end
    if snapshot ~= nil then self.items = normalizeItems(snapshot); self.page = 1 end
    if player then self.targetEdit:SetText(player) end
    self.totalPages = math.max(1, math.ceil(#self.items / self.pageSize)); self.page = math.max(1, math.min(self.page, self.totalPages)); local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local entry = self.items[offset + index]
        if entry then row.entry = entry; row.item:SetText(entry.link or "Unbekanntes Item"); row.quantity:SetText(tostring(entry.quantity)); row.bag:SetText(tostring(entry.bag)); row.slot:SetText(tostring(entry.slot)); row:Show() else row.entry = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages .. "  (" .. #self.items .. ")")
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
end

function BagInspectorWindow:RefreshPlayers(players)
    if not self:EnsureFrame() then return end
    self.players = normalizePlayers(players or (GA.BagInspector and GA.BagInspector:GetPlayers()) or {})
    if #self.players > 0 and self.targetEdit:GetText() == "" then self.playerIndex = 1; self.targetEdit:SetText(self.players[1]) end
end

function BagInspectorWindow:NextPlayer()
    if #self.players == 0 then self:RefreshPlayers() end
    if #self.players == 0 then self.status:SetText("Keine Spieler-Snapshots bekannt."); return end
    self.playerIndex = math.mod(self.playerIndex, #self.players) + 1; self.targetEdit:SetText(self.players[self.playerIndex])
    local manager = GA.BagInspector; if manager and type(manager.GetSnapshot) == "function" then local snapshot = manager:GetSnapshot(self.players[self.playerIndex]); if snapshot then self:Render(snapshot, self.players[self.playerIndex]) end end
end

function BagInspectorWindow:Request()
    local player = self.targetEdit:GetText(); if not player or player == "" then self.status:SetText("Bitte einen Zielspieler eingeben."); self.status:SetTextColor(unpack(Theme.colors.red)); return end
    local manager = GA.BagInspector; if not manager or type(manager.Request) ~= "function" then self.status:SetText("BagInspector nicht verfügbar."); self.status:SetTextColor(unpack(Theme.colors.red)); return end
    local ok, result, err = pcall(manager.Request, manager, player)
    if ok and result ~= false and result ~= nil then self.status:SetText("Anfrage an " .. player .. " gesendet."); self.status:SetTextColor(unpack(Theme.colors.green))
    else self.status:SetText(tostring(err or result or "Anfrage fehlgeschlagen.")); self.status:SetTextColor(unpack(Theme.colors.red)) end
end

function BagInspectorWindow:Show()
    local frame = self:EnsureFrame(); if not frame then return end; self:RefreshPlayers()
    local player = self.targetEdit:GetText(); if player ~= "" and GA.BagInspector and type(GA.BagInspector.GetSnapshot) == "function" then local snapshot = GA.BagInspector:GetSnapshot(player); if snapshot then self:Render(snapshot, player) end end
    frame:Show()
end
function BagInspectorWindow:Hide() if self.frame then self.frame:Hide() end end
function BagInspectorWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function BagInspectorWindow:OnInitialize()
    self:EnsureFrame()
    GA.Events:On("GA_BAGINSPECT_UPDATED", function(_, _, first, second) local player, snapshot = type(first) == "string" and first or second, type(first) == "table" and first or second; BagInspectorWindow:Render(snapshot, player) end, self)
    GA.Events:On("GA_BAGINSPECT_PLAYERS", function(_, _, players) BagInspectorWindow:RefreshPlayers(players) end, self)
    return true
end
GA:RegisterModule("BagInspectorWindow", BagInspectorWindow)
