local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA
GA.UI = GA.UI or {}

local Theme = GA.UI.Theme
local MasterLooterWindow = {
    page = 1, WIDTH = 520, HEIGHT = 450, VISIBLE_ROWS = 6,
    LAYOUT_VERSION = 5, OS_EDIT_X = 282, PAGINATION_Y = -171,
    TABLE_TOP = -205, ROW_HEIGHT = 25,
}
GA.UI.MasterLooterWindow = MasterLooterWindow

local ROWS = MasterLooterWindow.VISIBLE_ROWS

local function baseName(name)
    if type(name) ~= "string" then return "" end
    return string.lower((string.match(name, "^[^-]+") or name))
end

local function field(source, ...)
    if type(source) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if source[key] ~= nil then return source[key] end
    end
    return nil
end

local function registerMessage(event, callback)
    local buses = { GA.Events, GA.EventBus, GA }
    for _, bus in ipairs(buses) do
        if type(bus) == "table" then
            for _, method in ipairs({ "RegisterCallback", "RegisterMessage", "On", "Subscribe" }) do
                if type(bus[method]) == "function" then
                    local ok = pcall(bus[method], bus, event, callback)
                    if ok then return true end
                end
            end
        end
    end
    return false
end

local function eventArgument(expected, ...)
    if select(2, ...) == expected then return select(3, ...) end
    if select(1, ...) == expected then return select(2, ...) end
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "table" then return candidate end
    end
end

local function getRolls(session)
    local rolls = field(session, "participants", "rolls", "responses", "entries") or {}
    local awardedPlayers = field(session, "awardedPlayers") or {}
    local result = {}
    for key, roll in pairs(rolls) do
        if type(roll) == "table" then
            local choice = field(roll, "choice", "category", "type")
            if choice then table.insert(result, {
                player = field(roll, "player", "name", "playerName") or (type(key) == "string" and key) or "?",
                choice = choice,
                roll = tonumber(field(roll, "roll", "value", "number")) or 0,
                effectiveRoll = tonumber(field(roll, "effectiveRoll")) or tonumber(field(roll, "roll", "value", "number")) or 0,
                awarded = awardedPlayers[baseName(field(roll, "player", "name", "playerName") or (type(key) == "string" and key) or "?")] ~= nil,
                raw = roll,
            }) end
        else
            table.insert(result, { player = tostring(key), choice = tostring(roll), roll = 0, raw = roll })
        end
    end
    local priority = { MS = 3, OS = 2, PASS = 1 }
    table.sort(result, function(a, b)
        if GA.Ranking and type(a.raw) == "table" and type(b.raw) == "table" and a.choice ~= "PASS" and b.choice ~= "PASS" then
            return GA.Ranking:Compare(session, a.raw, b.raw)
        end
        local pa, pb = priority[a.choice] or 0, priority[b.choice] or 0
        if pa ~= pb then return pa > pb end
        if a.roll ~= b.roll then return a.roll > b.roll end
        return a.player < b.player
    end)
    for _, entry in ipairs(result) do
        if type(entry.raw) == "table" then
            entry.effectiveRoll = tonumber(entry.raw.effectiveRoll) or entry.roll
            entry.itemCounts = entry.raw.itemCounts or (GA.PlusOnes and GA.PlusOnes:GetStats(entry.player))
            entry.plusOne = tonumber(entry.raw.plusOne) or (GA.PlusOnes and GA.PlusOnes:Get(entry.player)) or 0
        end
    end
    return result
end

local function rollSignature(rolls)
    local parts = {}
    for index, roll in ipairs(rolls or {}) do
        parts[index] = table.concat({ tostring(roll.player), tostring(roll.choice), tostring(roll.roll), tostring(roll.awarded) }, "\031")
    end
    return table.concat(parts, "\030")
end

function MasterLooterWindow:BuildRollList(session)
    return getRolls(session)
end

local function sessionUpdateArguments(...)
    if select(2, ...) == "GA_ROLL_SESSION_UPDATED" then return select(3, ...), select(4, ...), select(5, ...) end
    if select(1, ...) == "GA_ROLL_SESSION_UPDATED" then return select(2, ...), select(3, ...), select(4, ...) end
    local state, action, participant
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if not state and type(candidate) == "table" and candidate.participants then state = candidate
        elseif state and not action and type(candidate) == "string" then action = candidate
        elseif state and action and type(candidate) == "table" then participant = candidate; break end
    end
    return state, action, participant
end

function MasterLooterWindow:ShowParticipantResponse(action, participant)
    if type(participant) ~= "table" or (action ~= "ROLL" and action ~= "PASS") then return end
    local name = field(participant, "name", "player", "playerName") or "Unbekannt"
    local choice = field(participant, "choice", "category") or action
    local labels = { MS = "MS", OS = "OS", PASS = "Passen" }
    local roll = tonumber(field(participant, "roll", "value")) or 0
    local suffix = choice ~= "PASS" and roll > 0 and (" – " .. tostring(roll)) or ""
    self:SetStatus(name .. ": " .. (labels[choice] or tostring(choice)) .. suffix, Theme.colors.green)
end

function MasterLooterWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterMainWindow", UIParent)
    frame:SetWidth(self.WIDTH)
    frame:SetHeight(self.HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    local title, close = Theme:AddTitle(frame, "MasterLooter – Lootmaster")
    Theme:MakeMovable(frame, "masterLooterGargulV1")
    Theme:RestorePosition(frame, "masterLooterGargulV1", "CENTER", 0, 20)
    Theme:RegisterForEscape(frame)
    self.frame = frame
    frame:SetScript("OnUpdate", function(_, elapsed) MasterLooterWindow:OnUpdate(elapsed) end)

    local itemLabel = Theme:CreateLabel(frame, "ITEM", 11, Theme.colors.muted)
    itemLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -54)
    local item = CreateFrame("Button", nil, frame)
    item:SetWidth(214); item:SetHeight(34)
    item:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -44)
    item:EnableMouse(true); item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Theme:ApplyInset(item)
    local itemIcon = item:CreateTexture(nil, "ARTWORK")
    itemIcon:SetWidth(28); itemIcon:SetHeight(28); itemIcon:SetPoint("LEFT", item, "LEFT", 6, 0)
    itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    local itemText = Theme:CreateLabel(item, "Item hier ablegen", 12, Theme.colors.muted)
    itemText:SetPoint("LEFT", itemIcon, "RIGHT", 9, 0); itemText:SetPoint("RIGHT", item, "RIGHT", -7, 0)
    itemText:SetJustifyH("LEFT")
    item:SetScript("OnReceiveDrag", function() MasterLooterWindow:AcceptCursorItem() end)
    item:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            MasterLooterWindow:SetItem(nil)
            MasterLooterWindow:SetStatus("Item entfernt. Ziehe ein neues Item auf die Ablagefläche.", Theme.colors.muted)
        elseif not MasterLooterWindow:AcceptCursorItem() then
            MasterLooterWindow:RefreshInputState(true)
        end
    end)
    item:SetScript("OnEnter", function(self)
        if not MasterLooterWindow.itemLink then return end
        Theme:ShowItemTooltip(self, MasterLooterWindow.itemLink)
    end)
    item:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self); MasterLooterWindow:RefreshInputState(false) end)
    self.itemDrop = item; self.itemIcon = itemIcon; self.itemText = itemText

    local itemHelp = Theme:CreateLabel(frame, "Ziehen · Rechtsklick entfernt", 10, Theme.colors.muted)
    itemHelp:SetPoint("TOPLEFT", item, "BOTTOMLEFT", 2, -2)
    itemHelp:SetPoint("RIGHT", item, "RIGHT", 0, 0)
    self.itemHelp = itemHelp

    local durationLabel = Theme:CreateLabel(frame, "TIMER", 11, Theme.colors.muted)
    durationLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -142)
    local minus = Theme:CreateButton(frame, "-", 26, 24)
    minus:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -136)
    local duration = Theme:CreateEditBox(frame, 46, 24, true)
    duration:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    if type(duration.SetMaxLetters) == "function" then duration:SetMaxLetters(3) end
    local profile = GA.DB and GA.DB:GetProfile()
    local initialDuration = tonumber(profile and profile.defaultRollDuration) or 30
    initialDuration = math.max(5, math.min(300, math.floor(initialDuration + 0.5)))
    duration:SetText(tostring(initialDuration))
    self.durationEdit = duration
    local plus = Theme:CreateButton(frame, "+", 26, 24)
    plus:SetPoint("LEFT", duration, "RIGHT", 4, 0)
    self.durationMinus, self.durationPlus = minus, plus
    local seconds = Theme:CreateLabel(frame, "Sek.", 11, Theme.colors.muted)
    seconds:SetPoint("LEFT", plus, "RIGHT", 7, 0)
    minus:SetScript("OnClick", function() MasterLooterWindow:AdjustDuration(-5) end)
    plus:SetScript("OnClick", function() MasterLooterWindow:AdjustDuration(5) end)
    duration:SetScript("OnTextChanged", function(_, userInput) MasterLooterWindow:RefreshInputState(userInput and true or false) end)
    duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); MasterLooterWindow:RefreshInputState(true) end)
    duration:SetScript("OnEditFocusLost", function() MasterLooterWindow:NormalizeDuration() end)

    local osLabel = Theme:CreateLabel(frame, "OS /ROLL", 11, Theme.colors.muted)
    osLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 220, -142)
    local osMaximum = Theme:CreateEditBox(frame, 42, 24, true)
    osMaximum:SetPoint("TOPLEFT", frame, "TOPLEFT", self.OS_EDIT_X, -136)
    if type(osMaximum.SetMaxLetters) == "function" then osMaximum:SetMaxLetters(2) end
    osMaximum:SetText(tostring(math.max(2, math.min(99, math.floor(tonumber(profile and profile.osRollMaximum) or 99)))))
    self.osMaximumEdit = osMaximum
    local osHint = Theme:CreateLabel(frame, "· MS /roll 100", 10, Theme.colors.muted)
    osHint:SetPoint("LEFT", osMaximum, "RIGHT", 8, 0)
    osMaximum:SetScript("OnTextChanged", function(_, userInput) MasterLooterWindow:RefreshInputState(userInput and true or false) end)
    osMaximum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); MasterLooterWindow:RefreshInputState(true) end)
    osMaximum:SetScript("OnEditFocusLost", function() MasterLooterWindow:NormalizeOSMaximum() end)

    local noteLabel = Theme:CreateLabel(frame, "NOTE", 11, Theme.colors.muted)
    noteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -109)
    local note = Theme:CreateEditBox(frame, 428, 24)
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -103)
    if type(note.SetMaxLetters) == "function" then note:SetMaxLetters(160) end
    self.noteEdit = note

    local start = Theme:CreateButton(frame, "Roll starten", 108, 28)
    start:SetPoint("TOPLEFT", frame, "TOPLEFT", 292, -47)
    start:SetScript("OnClick", function() MasterLooterWindow:StartSession() end)
    self.startButton = start
    if start.GetFontString and start:GetFontString() then start:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end
    local stop = Theme:CreateButton(frame, "Stoppen", 88, 28)
    stop:SetPoint("LEFT", start, "RIGHT", 8, 0)
    stop:SetScript("OnClick", function() MasterLooterWindow:StopSession() end)
    stop:Disable()
    self.stopButton = stop
    if stop.GetFontString and stop:GetFontString() then stop:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end

    local status = Theme:CreateLabel(frame, "Lege zuerst ein Item auf die Ablagefläche.", 12, Theme.colors.muted)
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -174)
    status:SetPoint("RIGHT", frame, "RIGHT", -120, 0)
    status:SetHeight(27)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    self.status = status

    local tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, self.TABLE_TOP)
    tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 57)
    Theme:ApplyInset(tableFrame)
    self.tableFrame = tableFrame

    local headers = {
        { text = "Spieler", x = 12 }, { text = "Wahl", x = 188 }, { text = "Wurf", x = 241 },
        { text = "Bilanz G/MS/OS", x = 288 }, { text = "+1", x = 438 },
    }
    for _, header in ipairs(headers) do
        local label = Theme:CreateLabel(tableFrame, header.text, 12, Theme.colors.gold)
        label:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", header.x, -10)
    end

    local previous = Theme:CreateButton(frame, "<", 24, 19)
    previous:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -82, self.PAGINATION_Y)
    previous:SetScript("OnClick", function()
        MasterLooterWindow.page = math.max(1, MasterLooterWindow.page - 1)
        MasterLooterWindow:RefreshRows()
    end)
    self.previousButton = previous
    local pageLabel = Theme:CreateLabel(frame, "1/1", 11, Theme.colors.muted)
    pageLabel:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    pageLabel:SetWidth(34)
    pageLabel:SetJustifyH("CENTER")
    self.pageLabel = pageLabel
    local nextButton = Theme:CreateButton(frame, ">", 24, 19)
    nextButton:SetPoint("LEFT", pageLabel, "RIGHT", 4, 0)
    nextButton:SetScript("OnClick", function()
        MasterLooterWindow.page = math.min(MasterLooterWindow.totalPages or 1, MasterLooterWindow.page + 1)
        MasterLooterWindow:RefreshRows()
    end)
    self.nextButton = nextButton

    self.rows = {}
    for index = 1, ROWS do
        local row = CreateFrame("Button", nil, tableFrame)
        row:SetHeight(self.ROW_HEIGHT)
        row:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 8, -28 - ((index - 1) * self.ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -8, -28 - ((index - 1) * self.ROW_HEIGHT))
        row:RegisterForClicks("LeftButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.player = Theme:CreateLabel(row, "", 11)
        row.player:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.player:SetWidth(166)
        row.choice = Theme:CreateLabel(row, "", 11)
        row.choice:SetPoint("LEFT", row, "LEFT", 181, 0)
        row.choice:SetWidth(46)
        row.roll = Theme:CreateLabel(row, "", 11)
        row.roll:SetPoint("LEFT", row, "LEFT", 234, 0)
        row.roll:SetWidth(50)
        row.items = Theme:CreateLabel(row, "", 11, Theme.colors.muted)
        row.items:SetPoint("LEFT", row, "LEFT", 281, 0)
        row.items:SetWidth(137)
        row.items:SetJustifyH("LEFT")
        row.plusOne = Theme:CreateButton(row, "+1", 36, 21)
        row.plusOne:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.plusOne:SetScript("OnClick", function() MasterLooterWindow:AddPlusOne(row.absoluteIndex) end)
        row.plusOne:SetScript("OnEnter", function(self)
            Theme:ShowTextTooltip(self, { "+1 manuell buchen", "Verändert nicht den ausgewählten Gewinner." }, "ANCHOR_RIGHT")
        end)
        row.plusOne:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end)
        row:SetScript("OnClick", function() MasterLooterWindow:SelectRow(row.absoluteIndex) end)
        row:SetScript("OnEnter", function(self)
            Theme:ShowTextTooltip(self, { "Gewinner auswählen", "Klicken, um diesen Spieler für die Vergabe zu markieren." }, "ANCHOR_LEFT")
        end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end)
        self.rows[index] = row
    end

    local winnerLabel = Theme:CreateLabel(frame, "Gewinner: – bitte Spieler anklicken", 12)
    winnerLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 24)
    winnerLabel:SetWidth(355)
    self.winnerLabel = winnerLabel
    local award = Theme:CreateButton(frame, "Item vergeben", 125, 28)
    award:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 17)
    award:SetScript("OnClick", function() MasterLooterWindow:AwardSelected() end)
    award:Disable()
    if award.GetFontString and award:GetFontString() then award:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end
    self.awardButton = award

    start:Disable()
    self:RefreshInputState(false)
    return frame
end

function MasterLooterWindow:GetInputIssue()
    if type(self.itemLink) ~= "string" or not string.find(self.itemLink, "|Hitem:", 1, true) then
        return "ITEM", "Bitte ein Item aus Tasche oder Lootfenster auf die Ablagefläche ziehen."
    end
    if GA.SoftRes and GA.SoftRes:IsHardReserved(self.itemLink) then
        return "ITEM", "Dieses Item ist als Hard-Reserve markiert und kann nicht ausgerollt werden."
    end
    local duration = tonumber(self.durationEdit and self.durationEdit:GetText())
    if not duration or duration ~= math.floor(duration) or duration < 5 or duration > 300 then
        return "DURATION", "Die Rollzeit muss eine ganze Zahl zwischen 5 und 300 Sekunden sein."
    end
    local osMaximum = tonumber(self.osMaximumEdit and self.osMaximumEdit:GetText())
    if not osMaximum or osMaximum ~= math.floor(osMaximum) or osMaximum < 2 or osMaximum > 99 then
        return "OS_MAXIMUM", "Der Lootmaster muss für OS eine ganze Zahl zwischen 2 und 99 festlegen."
    end
    return nil, nil, duration, osMaximum
end

function MasterLooterWindow:RefreshInputState(showFeedback)
    if not self.startButton or not self.durationEdit then return false end
    local issue, message = self:GetInputIssue()
    local enabled = not issue and not self.sessionActive and not self.sessionStarting
    if enabled then self.startButton:Enable() else self.startButton:Disable() end
    if self.itemDrop and type(self.itemDrop.SetBackdropBorderColor) == "function" then
        if issue == "ITEM" and showFeedback then self.itemDrop:SetBackdropBorderColor(unpack(Theme.colors.red))
        elseif self.itemLink and not issue then self.itemDrop:SetBackdropBorderColor(unpack(Theme.colors.green))
        else self.itemDrop:SetBackdropBorderColor(0.30, 0.30, 0.34, 1) end
    end
    if type(self.durationEdit.SetTextColor) == "function" then
        self.durationEdit:SetTextColor(unpack(issue == "DURATION" and Theme.colors.red or Theme.colors.text))
    end
    if self.osMaximumEdit and type(self.osMaximumEdit.SetTextColor) == "function" then
        self.osMaximumEdit:SetTextColor(unpack(issue == "OS_MAXIMUM" and Theme.colors.red or Theme.colors.text))
    end
    if showFeedback then
        if issue then self:SetStatus(message, Theme.colors.red)
        elseif not self.sessionActive then self:SetStatus("Bereit. Der Roll kann gestartet werden.", Theme.colors.green) end
    end
    return enabled, message
end

function MasterLooterWindow:NormalizeDuration()
    if not self.durationEdit then return end
    local duration = tonumber(self.durationEdit:GetText())
    if not duration then
        local profile = GA.DB and GA.DB:GetProfile()
        duration = (profile and profile.defaultRollDuration) or 30
    end
    duration = math.max(5, math.min(300, math.floor(duration + 0.5)))
    self.durationEdit:SetText(tostring(duration))
    self:RefreshInputState(false)
end

function MasterLooterWindow:AdjustDuration(delta)
    local duration = tonumber(self.durationEdit and self.durationEdit:GetText()) or 30
    duration = math.max(5, math.min(300, math.floor(duration + (tonumber(delta) or 0))))
    self.durationEdit:SetText(tostring(duration))
    self:RefreshInputState(true)
end

function MasterLooterWindow:NormalizeOSMaximum()
    if not self.osMaximumEdit then return end
    local profile = GA.DB and GA.DB:GetProfile()
    local maximum = tonumber(self.osMaximumEdit:GetText()) or tonumber(profile and profile.osRollMaximum) or 99
    maximum = math.max(2, math.min(99, math.floor(maximum + 0.5)))
    self.osMaximumEdit:SetText(tostring(maximum))
    self:RefreshInputState(false)
end

function MasterLooterWindow:SetSessionActive(active)
    self.sessionActive, self.sessionStarting = active and true or false, false
    if not self.startButton then return end
    if active then
        self.startButton:Disable(); self.stopButton:Enable()
        if self.durationMinus then self.durationMinus:Disable() end
        if self.durationPlus then self.durationPlus:Disable() end
        if self.durationEdit.Disable then self.durationEdit:Disable() end
        if self.osMaximumEdit and self.osMaximumEdit.Disable then self.osMaximumEdit:Disable() end
        if self.noteEdit.Disable then self.noteEdit:Disable() end
        if self.itemDrop then self.itemDrop:EnableMouse(false) end
    else
        if self.awardButton then self.awardButton:Disable() end
        self.stopButton:Disable()
        if self.durationMinus then self.durationMinus:Enable() end
        if self.durationPlus then self.durationPlus:Enable() end
        if self.durationEdit.Enable then self.durationEdit:Enable() end
        if self.osMaximumEdit and self.osMaximumEdit.Enable then self.osMaximumEdit:Enable() end
        if self.noteEdit.Enable then self.noteEdit:Enable() end
        if self.itemDrop then self.itemDrop:EnableMouse(true) end
        self:RefreshInputState(false)
    end
end

function MasterLooterWindow:SetItem(itemLink)
    self.itemLink = type(itemLink) == "string" and itemLink or nil
    if not self.itemLink then self.sourceLoot, self.sourceInventory = nil, nil end
    if not self.itemText or not self.itemIcon then return end
    if not self.itemLink then
        self.itemText:SetText("Item hier ablegen")
        self.itemText:SetTextColor(unpack(Theme.colors.muted))
        self.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        if self.itemHelp then self.itemHelp:SetText("Aus Tasche oder Lootfenster ziehen · Rechtsklick entfernt") end
        self:RefreshInputState(false)
        return
    end
    self.itemText:SetText(self.itemLink)
    self.itemText:SetTextColor(unpack(Theme.colors.text))
    local texture = type(GetItemInfo) == "function" and select(10, GetItemInfo(self.itemLink))
    self.itemIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if self.itemHelp then self.itemHelp:SetText("Ausgewählt · Rechtsklick entfernt · Tooltip beim Darüberfahren") end
    self:RefreshInputState(true)
end

function MasterLooterWindow:AcceptCursorItem()
    local itemLink = Theme:TakeDraggedItem()
    if not itemLink and type(GetCursorInfo) == "function" then
        local cursorType, itemId, cursorLink = GetCursorInfo()
        if cursorType == "item" then
            itemLink = cursorLink
            if not itemLink and type(GetItemInfo) == "function" then itemLink = select(2, GetItemInfo(itemId)) end
        end
    end
    if not itemLink then return false end
    self.sourceLoot = nil
    self.sourceInventory = { itemLink = itemLink }
    self:SetItem(itemLink)
    if type(ClearCursor) == "function" then ClearCursor() end
    self:SetStatus("Item übernommen. Dauer prüfen und Roll starten.", Theme.colors.green)
    return true
end

function MasterLooterWindow:GetContainerItem(button)
    if not button then return nil end
    local parent = type(button.GetParent) == "function" and button:GetParent() or nil
    local bag = tonumber(button.bagID) or tonumber(button.bag) or
        (parent and type(parent.GetID) == "function" and tonumber(parent:GetID()))
    local slot = tonumber(button.slot) or (type(button.GetID) == "function" and tonumber(button:GetID()))
    if bag == nil or not slot or not GA.Compat or type(GA.Compat.GetContainerItemLink) ~= "function" then return nil end
    return GA.Compat:GetContainerItemLink(bag, slot), bag, slot
end

function MasterLooterWindow:OpenContainerItem(button, mouseButton)
    if mouseButton ~= "RightButton" or type(IsControlKeyDown) ~= "function" or not IsControlKeyDown() then return false end
    local itemLink, bag, slot = self:GetContainerItem(button)
    if type(itemLink) ~= "string" or not string.find(itemLink, "|Hitem:", 1, true) then return false end
    self.sourceLoot = nil
    self.sourceInventory = { bag = bag, slot = slot, itemLink = itemLink }
    self:Show(); self:SetItem(itemLink)
    self:SetStatus("Item aus der Tasche übernommen. Dauer prüfen und Roll starten.", Theme.colors.green)
    if GA.Trace then GA:Trace("INPUT", "CTRL_RIGHTCLICK_BAG", bag, slot, itemLink) end
    return true
end

function MasterLooterWindow:InstallContainerClickHook()
    if self.containerClickWrapper then return true end
    local original = _G.ContainerFrameItemButton_OnModifiedClick
    if type(original) ~= "function" then return false end
    local wrapper = function(button, mouseButton, ...)
        if MasterLooterWindow:OpenContainerItem(button, mouseButton) then return true end
        return original(button, mouseButton, ...)
    end
    self.originalContainerClick, self.containerClickWrapper = original, wrapper
    _G.ContainerFrameItemButton_OnModifiedClick = wrapper
    return true
end

function MasterLooterWindow:RemoveContainerClickHook()
    if self.containerClickWrapper and _G.ContainerFrameItemButton_OnModifiedClick == self.containerClickWrapper then
        _G.ContainerFrameItemButton_OnModifiedClick = self.originalContainerClick
    end
    self.originalContainerClick, self.containerClickWrapper = nil, nil
end

function MasterLooterWindow:SetStatus(text, color)
    self.status:SetText(text or "")
    self.status:SetTextColor(unpack(color or Theme.colors.muted))
end

function MasterLooterWindow:StartSession()
    local issue, validationMessage, duration, osMaximum = self:GetInputIssue()
    if issue then self:RefreshInputState(true); return end
    local itemLink = self.itemLink
    local note = self.noteEdit:GetText()
    self.durationEdit:SetText(tostring(duration))
    local manager = GA.RollSession
    local method = manager and (manager.StartSession or manager.Start)
    if type(method) ~= "function" then
        self:SetStatus("RollSession ist nicht verfügbar.", Theme.colors.red)
        return
    end
    self.sessionStarting = true
    self:RefreshInputState(false)
    self:SetStatus("Session wird an die Gruppe gesendet …", Theme.colors.gold)
    local profile = GA.DB and GA.DB:GetProfile()
    local awardLimit = 1
    if self.sourceLoot and GA.Loot and type(GA.Loot.CountAvailable) == "function" then
        awardLimit = math.max(1, GA.Loot:CountAvailable(itemLink))
    end
    local ok, result, errorMessage = pcall(method, manager, itemLink, {
        duration = duration,
        note = note,
        choices = { "MS", "OS", "PASS" },
        osRollMaximum = osMaximum,
        lootQueueID = self.sourceLoot and self.sourceLoot.queueID,
        lootSlot = self.sourceLoot and self.sourceLoot.slot,
        lootGeneration = self.sourceLoot and self.sourceLoot.generation,
        awardLimit = awardLimit,
    })
    if not ok or result == nil or result == false then
        self.sessionStarting = false
        self:RefreshInputState(false)
        self:SetStatus((not ok and result) or errorMessage or "Session konnte nicht gestartet werden.", Theme.colors.red)
        return
    end
    if profile then
        profile.defaultRollDuration = duration
        profile.osRollMaximum = osMaximum
    end
    if self.sourceLoot and self.sourceLoot.queueID and GA.Loot and type(GA.Loot.SetQueueStatus) == "function" then
        GA.Loot:SetQueueStatus(self.sourceLoot.queueID, "ROLLING", result.id)
    end
    self:UpdateSession(result)
    self:SetSessionActive(true)
    self:SetStatus("Session läuft. Antworten erscheinen unten in der Liste.", Theme.colors.green)
end

function MasterLooterWindow:StopSession()
    local manager = GA.RollSession
    local method = manager and (manager.StopSession or manager.Stop)
    if type(method) ~= "function" then self:SetStatus("RollSession ist nicht verfügbar.", Theme.colors.red); return end
    self.stopButton:Disable()
    self:SetStatus("Session wird beendet …", Theme.colors.gold)
    local ok, result, errorMessage = pcall(method, manager, self.sessionId)
    if ok and result == true then
        self:SetSessionActive(false)
        self:SetStatus("Session beendet. Das Item bleibt für einen erneuten Roll ausgewählt.", Theme.colors.muted)
    else
        self:SetSessionActive(true)
        self:SetStatus((not ok and result) or errorMessage or "Session konnte nicht beendet werden.", Theme.colors.red)
    end
end

function MasterLooterWindow:UpdateSession(session)
    if type(session) ~= "table" then return end
    self:EnsureFrame()
    local previousSessionId = self.sessionId
    local nextSessionId = field(session, "id", "sessionId", "rollId")
    local selectedPlayer = previousSessionId == nextSessionId and self.selected and self.selected.player or nil
    self.session = session
    self.sessionId = nextSessionId
    if self.osMaximumEdit and session.osRollMaximum then
        self.osMaximumEdit:SetText(tostring(session.osRollMaximum))
    end
    local link = field(session, "itemLink", "link") or field(session.item, "link", "itemLink")
    if link then self:SetItem(link) end
    self:SetSessionActive(session.status == nil or session.status == "ACTIVE")
    self.rolls = getRolls(session)
    self.rollSignature = rollSignature(self.rolls)
    self.selected = nil
    self.page = math.min(self.page or 1, math.max(1, math.ceil(#self.rolls / ROWS)))
    self:RestoreSelection(selectedPlayer)
end


function MasterLooterWindow:OnUpdate(elapsed)
    if not self.sessionActive or not self.frame or not self.frame:IsShown() then return end
    self.pollElapsed = (self.pollElapsed or 0) + (tonumber(elapsed) or 0)
    if self.pollElapsed < 0.25 then return end
    self.pollElapsed = 0
    local manager = GA.RollSession
    local state = manager and type(manager.GetState) == "function" and manager:GetState(self.sessionId)
    if not state then return end
    local rolls = getRolls(state)
    local signature = rollSignature(rolls)
    if signature == self.rollSignature then return end
    local selectedPlayer = self.selected and self.selected.player
    self.session, self.rolls, self.rollSignature = state, rolls, signature
    self.selected = nil
    self:RestoreSelection(selectedPlayer)
end

function MasterLooterWindow:RefreshRows()
    self.rolls = self.rolls or {}
    self.totalPages = math.max(1, math.ceil(#self.rolls / ROWS))
    self.page = math.max(1, math.min(self.page or 1, self.totalPages))
    local offset = (self.page - 1) * ROWS
    for index, row in ipairs(self.rows) do
        local absoluteIndex = offset + index
        local roll = self.rolls[absoluteIndex]
        if roll then
            row.absoluteIndex = absoluteIndex
            row.data = roll
            row.player:SetText(roll.player .. (roll.awarded and " |cff66cc66[vergeben]|r" or ""))
            row.choice:SetText(roll.choice)
            if roll.effectiveRoll and roll.effectiveRoll ~= roll.roll then
                row.roll:SetText(tostring(roll.roll) .. "→" .. tostring(roll.effectiveRoll))
            else
                row.roll:SetText(roll.roll > 0 and tostring(roll.roll) or "–")
            end
            local counts = roll.itemCounts or {}
            row.items:SetText(string.format("%d/%d/%d · +%d", tonumber(counts.total) or 0,
                tonumber(counts.MS) or 0, tonumber(counts.OS) or 0, tonumber(roll.plusOne) or 0))
            if roll.awarded then
                if type(row.UnlockHighlight) == "function" then row:UnlockHighlight() end
                row.player:SetTextColor(unpack(Theme.colors.muted))
            elseif self.selected == roll then
                if type(row.LockHighlight) == "function" then row:LockHighlight() end
                row.player:SetTextColor(unpack(Theme.colors.gold))
            else
                if type(row.UnlockHighlight) == "function" then row:UnlockHighlight() end
                row.player:SetTextColor(unpack(Theme.colors.text))
            end
            row:Show()
        else
            row.absoluteIndex = nil
            row.data = nil
            if type(row.UnlockHighlight) == "function" then row:UnlockHighlight() end
            row:Hide()
        end
    end
    self.pageLabel:SetText(self.page .. "/" .. self.totalPages)
    if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.page < self.totalPages then self.nextButton:Enable() else self.nextButton:Disable() end
end

function MasterLooterWindow:ClearSelection()
    self.selected = nil
    if self.winnerLabel then self.winnerLabel:SetText("Gewinner: – bitte Spieler anklicken") end
    if self.awardButton and type(self.awardButton.Disable) == "function" then self.awardButton:Disable() end
end

function MasterLooterWindow:RestoreSelection(player)
    self:ClearSelection()
    if player then
        for index, roll in ipairs(self.rolls or {}) do
            if roll.player == player and roll.choice ~= "PASS" and not roll.awarded and not self.awardPending then
                self.selected = roll
                if self.winnerLabel then self.winnerLabel:SetText("Gewinner: " .. roll.player .. " (" .. roll.choice .. ")") end
                if self.awardButton and type(self.awardButton.Enable) == "function" then self.awardButton:Enable() end
                self.page = math.floor((index - 1) / ROWS) + 1
                break
            end
        end
    end
    self:RefreshRows()
end

function MasterLooterWindow:SelectRow(index)
    local selected = index and self.rolls and self.rolls[index]
    if not selected then return end
    if self.awardPending then
        self:SetStatus("Die vorherige Vergabe wird noch vom Lootfenster bestätigt.", Theme.colors.gold)
        return
    end
    if selected.awarded then
        self:SetStatus(selected.player .. " hat aus dieser Rollrunde bereits ein Exemplar erhalten.", Theme.colors.muted)
        return
    end
    self.selected = selected
    if self.winnerLabel then self.winnerLabel:SetText("Gewinner: " .. selected.player .. " (" .. selected.choice .. ")") end
    if self.awardButton then
        if selected.choice == "PASS" and type(self.awardButton.Disable) == "function" then self.awardButton:Disable()
        elseif selected.choice ~= "PASS" and type(self.awardButton.Enable) == "function" then self.awardButton:Enable() end
    end
    self:RefreshRows()
    if GA.Trace then GA:Trace("UI", "WINNER_SELECTED", selected.player, selected.choice, selected.roll) end
end

function MasterLooterWindow:AddPlusOne(index)
    local target = index and self.rolls and self.rolls[index]
    if not target or not target.player then return nil, "Spieler ist nicht verfügbar." end
    if not GA.PlusOnes or type(GA.PlusOnes.Add) ~= "function" then
        self:SetStatus("+1-System ist nicht verfügbar.", Theme.colors.red)
        return nil, "+1-System ist nicht verfügbar."
    end
    local value, err = GA.PlusOnes:Add(target.player, 1, "LOOTMASTER_ROW_BUTTON:" .. tostring(self.sessionId or ""))
    if value == nil then
        self:SetStatus("+1 für " .. target.player .. " konnte nicht gebucht werden: " .. tostring(err or "unbekannter Fehler"), Theme.colors.red)
        return nil, err
    end
    target.plusOne = value
    self:RefreshRows()
    self:SetStatus(target.player .. " hat jetzt +" .. tostring(value) .. ".", Theme.colors.green)
    if GA.Trace then GA:Trace("ACTION", "PLUS_ONE_CLICK", target.player, value, self.sessionId) end
    return value
end

function MasterLooterWindow:AwardSelected()
    if not self.selected or self.selected.awarded or self.awardPending then return end
    local target = self.selected
    local manager = GA.RollSession
    local method = manager and (manager.Award or manager.AwardItem or manager.SelectWinner)
    if type(method) ~= "function" then
        self:SetStatus("Award-Funktion ist nicht verfügbar.", Theme.colors.red)
        return
    end
    local ok, result, errorMessage = pcall(method, manager, self.sessionId, target.player, target.choice, target.roll)
    if ok and result ~= nil and result ~= false then
        local remaining = tonumber(result.awardsRemaining) or 0
        self.awardPending = remaining > 0 and not result.lootConfirmed
        self.pendingAwardSlot = self.awardPending and tonumber(result.lootSlot) or nil
        self.pendingAwardSessionID = self.awardPending and result.sessionID or nil
        self.pendingAwardIndex = self.awardPending and tonumber(result.awardIndex) or nil
        local state = manager and type(manager.GetState) == "function" and manager:GetState(self.sessionId) or self.session
        if state then self:UpdateSession(state) end
        self:ClearSelection()
        self:RefreshRows()
        if remaining > 0 then
            if result.lootConfirmed then
                self:SetStatus("Exemplar " .. tostring(result.awardIndex or 1) .. "/" .. tostring(result.awardLimit or 1) ..
                    " an " .. target.player .. " vergeben. Nächsten Gewinner anklicken.", Theme.colors.green)
            else
                self:SetStatus("Exemplar " .. tostring(result.awardIndex or 1) .. "/" .. tostring(result.awardLimit or 1) ..
                    " an " .. target.player .. " vergeben. Warte auf Loot-Bestätigung.", Theme.colors.gold)
            end
        else
            self:SetStatus("Vergabe an " .. target.player .. " gestartet. Alle Exemplare sind vergeben.", Theme.colors.green)
            self.sourceLoot, self.sourceInventory = nil, nil
        end
        if GA.Trace then GA:Trace("ACTION", "ITEM_AWARDED_BY_CLICK", target.player, target.choice, self.sessionId, result.awardIndex, result.awardLimit) end
        self.awardButton:Disable()
    else
        local reason = ok and errorMessage or result
        self:SetStatus("Item konnte nicht vergeben werden" .. (reason and (": " .. tostring(reason)) or "."), Theme.colors.red)
    end
end

function MasterLooterWindow:UnlockNextAward()
    if not self.awardPending then return false end
    self.awardPending, self.pendingAwardSlot, self.pendingAwardSessionID, self.pendingAwardIndex = false, nil, nil, nil
    local manager = GA.RollSession
    local state = manager and type(manager.GetState) == "function" and manager:GetState(self.sessionId) or self.session
    if state then self:UpdateSession(state) end
    self:ClearSelection()
    local awarded = state and state.awards and #state.awards or 0
    local limit = state and tonumber(state.awardLimit) or awarded + 1
    self:SetStatus(tostring(awarded) .. "/" .. tostring(limit) ..
        " Exemplaren vergeben. Bitte den nächsten Gewinner anklicken.", Theme.colors.green)
    return true
end

function MasterLooterWindow:OnLootSlotCleared(record)
    if not self.awardPending then return false end
    local clearedSlot = type(record) == "table" and tonumber(record.slot) or tonumber(record)
    if self.pendingAwardSlot and clearedSlot and self.pendingAwardSlot ~= clearedSlot then return false end
    return self:UnlockNextAward()
end

function MasterLooterWindow:OnAwardDeliveryChanged(result, delivery)
    if not self.awardPending or type(result) ~= "table" or not result.lootConfirmed then return false end
    if delivery ~= "GIVEN" and delivery ~= "PENDING" then return false end
    if self.pendingAwardSessionID and tostring(result.sessionID) ~= tostring(self.pendingAwardSessionID) then return false end
    if self.pendingAwardIndex and tonumber(result.awardIndex) ~= self.pendingAwardIndex then return false end
    return self:UnlockNextAward()
end

function MasterLooterWindow:Show()
    local frame = self:EnsureFrame()
    if frame then frame:Show() end
end

function MasterLooterWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function MasterLooterWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function MasterLooterWindow:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:EnsureFrame()
    self:InstallContainerClickHook()
    registerMessage("GA_ROLL_SESSION_STARTED", function(...)
        MasterLooterWindow:UpdateSession(eventArgument("GA_ROLL_SESSION_STARTED", ...))
    end)
    local update = function(...)
        local state, action, participant = sessionUpdateArguments(...)
        MasterLooterWindow:UpdateSession(state)
        MasterLooterWindow:ShowParticipantResponse(action, participant)
    end
    registerMessage("GA_ROLL_SESSION_UPDATED", update)
    local stopped = function(...)
        if not MasterLooterWindow.frame then return end
        local state = eventArgument("GA_ROLL_SESSION_ENDED", ...)
        MasterLooterWindow:SetSessionActive(false)
        MasterLooterWindow:RefreshInputState(false)
        if state and state.status == "STOPPED" and MasterLooterWindow.selected and MasterLooterWindow.selected.choice ~= "PASS" then
            MasterLooterWindow.awardButton:Enable()
        end
        MasterLooterWindow:SetStatus("Roll geschlossen. Ein Gewinner kann weiterhin vergeben werden.", Theme.colors.muted)
    end
    registerMessage("GA_ROLL_SESSION_STOPPED", stopped)
    registerMessage("GA_ROLL_SESSION_ENDED", stopped)
    registerMessage("GA_ROLL_RESULT", function(...)
        local result = eventArgument("GA_ROLL_RESULT", ...)
        local state = result and GA.RollSession and type(GA.RollSession.GetState) == "function" and GA.RollSession:GetState(result.sessionID)
        if state then MasterLooterWindow:UpdateSession(state) end
    end)
    registerMessage("GA_LOOT_SLOT_CLEARED", function(...)
        MasterLooterWindow:OnLootSlotCleared(eventArgument("GA_LOOT_SLOT_CLEARED", ...))
    end)
    registerMessage("GA_AWARD_DELIVERY_CHANGED", function(...)
        local result, delivery
        if select(2, ...) == "GA_AWARD_DELIVERY_CHANGED" then result, delivery = select(3, ...), select(4, ...)
        elseif select(1, ...) == "GA_AWARD_DELIVERY_CHANGED" then result, delivery = select(2, ...), select(3, ...) end
        MasterLooterWindow:OnAwardDeliveryChanged(result, delivery)
    end)
end


MasterLooterWindow.OnInitialize = MasterLooterWindow.Initialize
function MasterLooterWindow:OnEnable()
    self:Initialize()
    self:InstallContainerClickHook()
end
MasterLooterWindow.OnDisable = MasterLooterWindow.RemoveContainerClickHook
if type(GA.RegisterModule) == "function" then
    GA:RegisterModule("MasterLooterWindow", MasterLooterWindow)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then MasterLooterWindow:Initialize() end
end)
