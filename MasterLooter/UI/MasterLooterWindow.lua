local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA
GA.UI = GA.UI or {}

local Theme = GA.UI.Theme
local MasterLooterWindow = { page = 1 }
GA.UI.MasterLooterWindow = MasterLooterWindow

local ROWS = 8

local function field(source, ...)
    if type(source) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if source[key] ~= nil then return source[key] end
    end
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
            table.insert(result, {
                player = field(roll, "player", "name", "playerName") or (type(key) == "string" and key) or "?",
                choice = field(roll, "choice", "category", "type") or "-",
                roll = tonumber(field(roll, "roll", "value", "number")) or 0,
                effectiveRoll = tonumber(field(roll, "effectiveRoll")) or tonumber(field(roll, "roll", "value", "number")) or 0,
                raw = roll,
            })
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

function MasterLooterWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterMainWindow", UIParent)
    frame:SetWidth(520)
    frame:SetHeight(465)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    local title, close = Theme:AddTitle(frame, "MasterLooter – Lootmaster")
    Theme:MakeMovable(frame, "masterLooterWindow")
    Theme:RestorePosition(frame, "masterLooterWindow", "CENTER", 0, 20)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local itemLabel = Theme:CreateLabel(frame, "Item", 12, Theme.colors.muted)
    itemLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -48)
    local item = CreateFrame("Button", nil, frame)
    item:SetWidth(365); item:SetHeight(30)
    item:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -42)
    item:EnableMouse(true); item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Theme:ApplyInset(item)
    local itemIcon = item:CreateTexture(nil, "ARTWORK")
    itemIcon:SetWidth(22); itemIcon:SetHeight(22); itemIcon:SetPoint("LEFT", item, "LEFT", 5, 0)
    itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    local itemText = Theme:CreateLabel(item, "Item hier ablegen (Tasche oder Lootfenster)", 11, Theme.colors.muted)
    itemText:SetPoint("LEFT", itemIcon, "RIGHT", 7, 0); itemText:SetPoint("RIGHT", item, "RIGHT", -7, 0)
    itemText:SetJustifyH("LEFT")
    item:SetScript("OnReceiveDrag", function() MasterLooterWindow:AcceptCursorItem() end)
    item:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then MasterLooterWindow:SetItem(nil) else MasterLooterWindow:AcceptCursorItem() end
    end)
    item:SetScript("OnEnter", function(self)
        if not MasterLooterWindow.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(MasterLooterWindow.itemLink); GameTooltip:Show()
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.itemDrop = item; self.itemIcon = itemIcon; self.itemText = itemText

    local durationLabel = Theme:CreateLabel(frame, "Dauer", 12, Theme.colors.muted)
    durationLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -80)
    local duration = Theme:CreateEditBox(frame, 50, 24, true)
    duration:SetPoint("TOPLEFT", frame, "TOPLEFT", 105, -74)
    local profile = GA.DB and GA.DB:GetProfile()
    duration:SetText(tostring((profile and profile.defaultRollDuration) or 30))
    self.durationEdit = duration
    local seconds = Theme:CreateLabel(frame, "Sekunden", 12, Theme.colors.muted)
    seconds:SetPoint("LEFT", duration, "RIGHT", 7, 0)

    local noteLabel = Theme:CreateLabel(frame, "Notiz", 12, Theme.colors.muted)
    noteLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 235, -80)
    local note = Theme:CreateEditBox(frame, 235, 24)
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 285, -74)
    self.noteEdit = note

    local start = Theme:CreateButton(frame, "Roll starten", 115, 28)
    start:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -111)
    start:SetScript("OnClick", function() MasterLooterWindow:StartSession() end)
    self.startButton = start
    local stop = Theme:CreateButton(frame, "Stoppen", 90, 28)
    stop:SetPoint("LEFT", start, "RIGHT", 8, 0)
    stop:SetScript("OnClick", function() MasterLooterWindow:StopSession() end)
    stop:Disable()
    self.stopButton = stop

    local status = Theme:CreateLabel(frame, "Bereit.", 12, Theme.colors.muted)
    status:SetPoint("LEFT", stop, "RIGHT", 12, 0)
    status:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    status:SetJustifyH("RIGHT")
    self.status = status

    local tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -154)
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
    self.awardButton = award

    self:HookLootButtons()
    return frame
end

function MasterLooterWindow:SetItem(itemLink)
    self.itemLink = type(itemLink) == "string" and itemLink or nil
    if not self.itemText or not self.itemIcon then return end
    if not self.itemLink then
        self.itemText:SetText("Item hier ablegen (Tasche oder Lootfenster)")
        self.itemText:SetTextColor(unpack(Theme.colors.muted))
        self.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        return
    end
    self.itemText:SetText(self.itemLink)
    self.itemText:SetTextColor(unpack(Theme.colors.text))
    local texture = type(GetItemInfo) == "function" and select(10, GetItemInfo(self.itemLink))
    self.itemIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
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
    self:SetStatus("Item übernommen.", Theme.colors.green)
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
    local itemLink = self.itemLink
    local duration = tonumber(self.durationEdit:GetText()) or 30
    local note = self.noteEdit:GetText()
    if not itemLink or not string.find(itemLink, "|Hitem:") then
        self:SetStatus("Bitte ein Item aus Tasche oder Lootfenster ablegen.", Theme.colors.red)
        return
    end
    if GA.SoftRes and GA.SoftRes:IsHardReserved(itemLink) then
        self:SetStatus("Dieses Item ist als Hard-Reserve markiert.", Theme.colors.red)
        return
    end
    duration = math.max(5, math.min(300, duration))
    self.durationEdit:SetText(tostring(duration))
    local manager = GA.RollSession
    local method = manager and (manager.StartSession or manager.Start)
    if type(method) ~= "function" then
        self:SetStatus("RollSession ist nicht verfügbar.", Theme.colors.red)
        return
    end
    local ok, result, errorMessage = pcall(method, manager, itemLink, {
        duration = duration,
        note = note,
        choices = { "MS", "OS", "PASS" },
    })
    if not ok or result == nil or result == false then
        self:SetStatus(errorMessage or "Session konnte nicht gestartet werden.", Theme.colors.red)
        return
    end
    self:UpdateSession(result)
    self.startButton:Disable()
    self.stopButton:Enable()
    self:SetStatus("Session läuft.", Theme.colors.green)
end

function MasterLooterWindow:StopSession()
    local manager = GA.RollSession
    local method = manager and (manager.StopSession or manager.Stop)
    if type(method) ~= "function" then return end
    local ok, result = pcall(method, manager, self.sessionId)
    if ok and result == true then
        self.startButton:Enable()
        self.stopButton:Disable()
        self:SetStatus("Session beendet.")
    else
        self:SetStatus("Session konnte nicht beendet werden.", Theme.colors.red)
    end
end

function MasterLooterWindow:UpdateSession(session)
    if type(session) ~= "table" then return end
    self:EnsureFrame()
    self.session = session
    self.sessionId = field(session, "id", "sessionId", "rollId")
    local link = field(session, "itemLink", "link") or field(session.item, "link", "itemLink")
    if link then self:SetItem(link) end
    self.rolls = getRolls(session)
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
        MasterLooterWindow:UpdateSession(eventArgument("GA_ROLL_SESSION_UPDATED", ...))
    end
    registerMessage("GA_ROLL_SESSION_UPDATED", update)
    local stopped = function()
        if not MasterLooterWindow.frame then return end
        MasterLooterWindow.startButton:Enable()
        MasterLooterWindow.stopButton:Disable()
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
