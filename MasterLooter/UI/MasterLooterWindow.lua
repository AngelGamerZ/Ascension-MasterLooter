local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA
GA.UI = GA.UI or {}

local Theme = GA.UI.Theme
local MasterLooterWindow = { page = 1, WIDTH = 540, HEIGHT = 470, VISIBLE_ROWS = 6 }
GA.UI.MasterLooterWindow = MasterLooterWindow

local ROWS = MasterLooterWindow.VISIBLE_ROWS

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
    local result = {}
    for key, roll in pairs(rolls) do
        if type(roll) == "table" then
            local choice = field(roll, "choice", "category", "type")
            if choice then table.insert(result, {
                player = field(roll, "player", "name", "playerName") or (type(key) == "string" and key) or "?",
                choice = choice,
                roll = tonumber(field(roll, "roll", "value", "number")) or 0,
                effectiveRoll = tonumber(field(roll, "effectiveRoll")) or tonumber(field(roll, "roll", "value", "number")) or 0,
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
        if type(entry.raw) == "table" then entry.effectiveRoll = tonumber(entry.raw.effectiveRoll) or entry.roll end
    end
    return result
end

local function rollSignature(rolls)
    local parts = {}
    for index, roll in ipairs(rolls or {}) do
        parts[index] = table.concat({ tostring(roll.player), tostring(roll.choice), tostring(roll.roll) }, "\031")
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
    item:SetWidth(230); item:SetHeight(36)
    item:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -45)
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(MasterLooterWindow.itemLink); GameTooltip:Show()
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide(); MasterLooterWindow:RefreshInputState(false) end)
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
    osLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 245, -142)
    local osMaximum = Theme:CreateEditBox(frame, 46, 24, true)
    osMaximum:SetPoint("TOPLEFT", frame, "TOPLEFT", 315, -136)
    if type(osMaximum.SetMaxLetters) == "function" then osMaximum:SetMaxLetters(2) end
    osMaximum:SetText(tostring(math.max(2, math.min(99, math.floor(tonumber(profile and profile.osRollMaximum) or 99)))))
    self.osMaximumEdit = osMaximum
    local osHint = Theme:CreateLabel(frame, "2–99 · MS bleibt 100", 11, Theme.colors.muted)
    osHint:SetPoint("LEFT", osMaximum, "RIGHT", 7, 0)
    osMaximum:SetScript("OnTextChanged", function(_, userInput) MasterLooterWindow:RefreshInputState(userInput and true or false) end)
    osMaximum:SetScript("OnEnterPressed", function(self) self:ClearFocus(); MasterLooterWindow:RefreshInputState(true) end)
    osMaximum:SetScript("OnEditFocusLost", function() MasterLooterWindow:NormalizeOSMaximum() end)

    local noteLabel = Theme:CreateLabel(frame, "NOTE", 11, Theme.colors.muted)
    noteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -109)
    local note = Theme:CreateEditBox(frame, 448, 24)
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -103)
    if type(note.SetMaxLetters) == "function" then note:SetMaxLetters(160) end
    self.noteEdit = note

    local start = Theme:CreateButton(frame, "Roll starten", 115, 28)
    start:SetPoint("TOPLEFT", frame, "TOPLEFT", 307, -49)
    start:SetScript("OnClick", function() MasterLooterWindow:StartSession() end)
    self.startButton = start
    if start.GetFontString and start:GetFontString() then start:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end
    local stop = Theme:CreateButton(frame, "Stoppen", 90, 28)
    stop:SetPoint("LEFT", start, "RIGHT", 8, 0)
    stop:SetScript("OnClick", function() MasterLooterWindow:StopSession() end)
    stop:Disable()
    self.stopButton = stop
    if stop.GetFontString and stop:GetFontString() then stop:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end

    local status = Theme:CreateLabel(frame, "Lege zuerst ein Item auf die Ablagefläche.", 12, Theme.colors.muted)
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -174)
    status:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    status:SetJustifyH("LEFT")
    self.status = status

    local tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -194)
    tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 61)
    Theme:ApplyInset(tableFrame)
    self.tableFrame = tableFrame

    local headers = {
        { text = "Spieler", x = 12 }, { text = "Wahl", x = 257 }, { text = "Wurf", x = 342 },
    }
    for _, header in ipairs(headers) do
        local label = Theme:CreateLabel(tableFrame, header.text, 12, Theme.colors.gold)
        label:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", header.x, -10)
    end

    local previous = Theme:CreateButton(tableFrame, "<", 28, 20)
    previous:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -72, -5)
    previous:SetScript("OnClick", function()
        MasterLooterWindow.page = math.max(1, MasterLooterWindow.page - 1)
        MasterLooterWindow:RefreshRows()
    end)
    self.previousButton = previous
    local pageLabel = Theme:CreateLabel(tableFrame, "1/1", 12, Theme.colors.muted)
    pageLabel:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    pageLabel:SetWidth(34)
    pageLabel:SetJustifyH("CENTER")
    self.pageLabel = pageLabel
    local nextButton = Theme:CreateButton(tableFrame, ">", 28, 20)
    nextButton:SetPoint("LEFT", pageLabel, "RIGHT", 4, 0)
    nextButton:SetScript("OnClick", function()
        MasterLooterWindow.page = math.min(MasterLooterWindow.totalPages or 1, MasterLooterWindow.page + 1)
        MasterLooterWindow:RefreshRows()
    end)
    self.nextButton = nextButton

    self.rows = {}
    for index = 1, ROWS do
        local row = CreateFrame("Button", nil, tableFrame)
        row:SetHeight(29)
        row:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 8, -29 - ((index - 1) * 29))
        row:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -8, -29 - ((index - 1) * 29))
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.player = Theme:CreateLabel(row, "", 12)
        row.player:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.choice = Theme:CreateLabel(row, "", 12)
        row.choice:SetPoint("LEFT", row, "LEFT", 250, 0)
        row.roll = Theme:CreateLabel(row, "", 12)
        row.roll:SetPoint("LEFT", row, "LEFT", 375, 0)
        row:SetScript("OnClick", function() MasterLooterWindow:SelectRow(row.absoluteIndex) end)
        self.rows[index] = row
    end

    local winnerLabel = Theme:CreateLabel(frame, "Gewinner: –", 12)
    winnerLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 24)
    self.winnerLabel = winnerLabel
    local award = Theme:CreateButton(frame, "Item vergeben", 125, 28)
    award:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 17)
    award:SetScript("OnClick", function() MasterLooterWindow:AwardSelected() end)
    award:Disable()
    if award.GetFontString and award:GetFontString() then award:GetFontString():SetTextColor(unpack(Theme.colors.gold)) end
    self.awardButton = award

    start:Disable()
    self:HookLootButtons()
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
    self:SetItem(itemLink)
    if type(ClearCursor) == "function" then ClearCursor() end
    self:SetStatus("Item übernommen. Dauer prüfen und Roll starten.", Theme.colors.green)
    return true
end

function MasterLooterWindow:HookLootButtons()
    if self.lootButtonsHooked then return end
    local count = tonumber(_G.LOOTFRAME_NUMBUTTONS) or 4
    local hooked = false
    for index = 1, count do
        local fallbackIndex = index
        local button = _G["LootButton" .. index]
        if button and type(button.HookScript) == "function" then
            button:RegisterForDrag("LeftButton")
            button:HookScript("OnDragStart", function(self)
                local slot = tonumber(self.slot) or (type(self.GetID) == "function" and self:GetID()) or fallbackIndex
                if not self.slot and _G.LootFrame and tonumber(_G.LootFrame.page) and _G.LootFrame.page > 1 then
                    slot = slot + ((_G.LootFrame.page - 1) * count)
                end
                local link = type(GetLootSlotLink) == "function" and GetLootSlotLink(slot)
                if link then Theme:BeginItemDrag(link) end
            end)
            hooked = true
        end
    end
    self.lootButtonsHooked = hooked
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
    local ok, result, errorMessage = pcall(method, manager, itemLink, {
        duration = duration,
        note = note,
        choices = { "MS", "OS", "PASS" },
        osRollMaximum = osMaximum,
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
    self.session = session
    self.sessionId = field(session, "id", "sessionId", "rollId")
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
    self:RefreshRows()
    for index, roll in ipairs(self.rolls) do
        if roll.choice ~= "PASS" then
            self:SelectRow(index)
            break
        end
    end
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
    self.session, self.rolls, self.rollSignature = state, rolls, signature
    self.selected = nil
    self:RefreshRows()
    for index, roll in ipairs(rolls) do
        if roll.choice ~= "PASS" then self:SelectRow(index); break end
    end
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
            row.player:SetText(roll.player)
            row.choice:SetText(roll.choice)
            if roll.effectiveRoll and roll.effectiveRoll ~= roll.roll then
                row.roll:SetText(tostring(roll.roll) .. "→" .. tostring(roll.effectiveRoll))
            else
                row.roll:SetText(roll.roll > 0 and tostring(roll.roll) or "–")
            end
            row:Show()
        else
            row.absoluteIndex = nil
            row.data = nil
            row:Hide()
        end
    end
    self.pageLabel:SetText(self.page .. "/" .. self.totalPages)
    if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.page < self.totalPages then self.nextButton:Enable() else self.nextButton:Disable() end
end

function MasterLooterWindow:SelectRow(index)
    local selected = index and self.rolls and self.rolls[index]
    if not selected then return end
    self.selected = selected
    self.winnerLabel:SetText("Gewinner: " .. selected.player .. " (" .. selected.choice .. ")")
    if selected.choice == "PASS" then self.awardButton:Disable() else self.awardButton:Enable() end
end

function MasterLooterWindow:AwardSelected()
    if not self.selected then return end
    local manager = GA.RollSession
    local method = manager and (manager.Award or manager.AwardItem or manager.SelectWinner)
    if type(method) ~= "function" then
        self:SetStatus("Award-Funktion ist nicht verfügbar.", Theme.colors.red)
        return
    end
    local ok, result = pcall(method, manager, self.sessionId, self.selected.player, self.selected.choice, self.selected.roll)
    if ok and result ~= nil and result ~= false then
        self:SetStatus("Vergeben an " .. self.selected.player .. ".", Theme.colors.green)
        self.awardButton:Disable()
    else
        self:SetStatus("Item konnte nicht vergeben werden.", Theme.colors.red)
    end
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
    registerMessage("GA_ROLL_SESSION_STARTED", function(...)
        MasterLooterWindow:UpdateSession(eventArgument("GA_ROLL_SESSION_STARTED", ...))
    end)
    registerMessage("GA_LOOT_OPENED", function() MasterLooterWindow:HookLootButtons() end)
    local update = function(...)
        local state, action, participant = sessionUpdateArguments(...)
        MasterLooterWindow:UpdateSession(state)
        MasterLooterWindow:ShowParticipantResponse(action, participant)
    end
    registerMessage("GA_ROLL_SESSION_UPDATED", update)
    local stopped = function()
        if not MasterLooterWindow.frame then return end
        MasterLooterWindow:SetSessionActive(false)
        MasterLooterWindow:RefreshInputState(false)
        MasterLooterWindow:SetStatus("Session beendet. Das Item bleibt für einen erneuten Roll ausgewählt.", Theme.colors.muted)
    end
    registerMessage("GA_ROLL_SESSION_STOPPED", stopped)
    registerMessage("GA_ROLL_SESSION_ENDED", stopped)
    registerMessage("GA_ROLL_RESULT", stopped)
end


MasterLooterWindow.OnInitialize = MasterLooterWindow.Initialize
MasterLooterWindow.OnEnable = MasterLooterWindow.Initialize
if type(GA.RegisterModule) == "function" then
    GA:RegisterModule("MasterLooterWindow", MasterLooterWindow)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() MasterLooterWindow:Initialize() end)
