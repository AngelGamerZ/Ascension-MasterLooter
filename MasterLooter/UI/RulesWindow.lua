local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local RulesWindow = { rows = {}, players = {}, offset = 0, currentItem = nil }
GA.UI.RulesWindow = RulesWindow

local function playerKey(name)
    return string.lower(string.match(tostring(name or ""), "^[^-]+") or "")
end

local function parseInteger(text, minimum, maximum, label)
    local value = tonumber(text)
    if not value or value ~= math.floor(value) then
        return nil, label .. " muss eine ganze Zahl sein."
    end
    if value < minimum or value > maximum then
        return nil, string.format("%s muss zwischen %d und %d liegen.", label, minimum, maximum)
    end
    return value
end

local function moduleValue(module, method, ...)
    if module and type(module[method]) == "function" then
        return module[method](module, ...)
    end
    return 0
end

function RulesWindow:CollectPlayers()
    local result, seen = {}, {}
    if GA.Compat and type(GA.Compat.IterateGroupUnits) == "function" then
        for unit in GA.Compat:IterateGroupUnits() do
            local name = GA.Compat:UnitFullName(unit)
            if not name and UnitName then name = UnitName(unit) end
            local key = playerKey(name)
            if name and key ~= "" and not seen[key] then
                seen[key] = true
                result[#result + 1] = { name = name, unit = unit }
            end
        end
    end
    if #result == 0 and UnitName then
        local name = UnitName("player")
        if name then result[1] = { name = name, unit = "player" } end
    end
    self.players = result
    local maximumOffset = math.max(0, #result - #self.rows)
    self.offset = math.min(self.offset, maximumOffset)
    return result
end

function RulesWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterRulesWindow", UIParent)
    frame:SetWidth(950)
    frame:SetHeight(570)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "Loot-Regeln und Spielerwerte")
    Theme:MakeMovable(frame, "rulesWindow")
    Theme:RestorePosition(frame, "rulesWindow", "CENTER", 0, 0)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local itemCaption = Theme:CreateLabel(frame, "Itemlink oder Item-ID", 11, Theme.colors.gold)
    itemCaption:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
    local itemInput = Theme:CreateEditBox(frame, 370, 24)
    itemInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68)
    itemInput:SetScript("OnEnterPressed", function(edit)
        edit:ClearFocus()
        RulesWindow:SelectItem(edit:GetText())
    end)
    self.itemInput = itemInput
    local selectButton = Theme:CreateButton(frame, "Item laden", 100, 24)
    selectButton:SetPoint("LEFT", itemInput, "RIGHT", 8, 0)
    selectButton:SetScript("OnClick", function() RulesWindow:SelectItem(itemInput:GetText()) end)

    local hardCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    hardCheck:SetPoint("LEFT", selectButton, "RIGHT", 14, 0)
    hardCheck:SetWidth(24)
    hardCheck:SetHeight(24)
    local hardLabel = Theme:CreateLabel(frame, "Hard Reserve", 11)
    hardLabel:SetPoint("LEFT", hardCheck, "RIGHT", 1, 0)
    hardCheck:SetScript("OnClick", function(button)
        if not RulesWindow.currentItem or not GA.SoftRes then
            button:SetChecked(false)
            RulesWindow:SetStatus("Zuerst ein gültiges Item laden.", true)
            return
        end
        local reserved = button:GetChecked() and true or false
        GA.SoftRes:SetHardReserved(RulesWindow.currentItem, reserved)
        GA.Events:Emit("GA_HARDRES_CHANGED", RulesWindow.currentItem, reserved)
        RulesWindow:SetStatus(button:GetChecked() and "Hard Reserve aktiviert." or "Hard Reserve entfernt.")
        RulesWindow:Refresh(false)
    end)
    self.hardCheck = hardCheck

    local manualPlusOne = Theme:CreateLabel(frame, "+1 wird nur über den Zeilenbutton im Lootmaster gebucht", 11, Theme.colors.muted)
    manualPlusOne:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -73)

    local refreshButton = Theme:CreateButton(frame, "Gruppe neu laden", 125, 24)
    refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -108)
    refreshButton:SetScript("OnClick", function() RulesWindow:Refresh(true) end)

    local itemSummary = Theme:CreateLabel(frame, "Kein Item ausgewählt.", 12)
    itemSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -112)
    itemSummary:SetPoint("RIGHT", refreshButton, "LEFT", -10, 0)
    self.itemSummary = itemSummary

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -142)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 58)
    Theme:ApplyInset(list)
    self.list = list

    local headers = {
        { text = "Spieler", x = 12 },
        { text = "SoftRes", x = 205 },
        { text = "Priorität", x = 296 },
        { text = "+1", x = 402 },
        { text = "Roll-Bonus", x = 490 },
        { text = "Erhalten G/MS/OS", x = 580 },
    }
    for index = 1, #headers do
        local label = Theme:CreateLabel(list, headers[index].text, 11, Theme.colors.gold)
        label:SetPoint("TOPLEFT", list, "TOPLEFT", headers[index].x, -10)
    end

    for index = 1, 10 do
        local row = CreateFrame("Frame", nil, list)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -32 - ((index - 1) * 31))
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -10, -32 - ((index - 1) * 31))
        row:SetHeight(27)
        row.player = Theme:CreateLabel(row, "", 11)
        row.player:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.player:SetWidth(180)
        row.player:SetWordWrap(false)
        row.softRes = Theme:CreateEditBox(row, 64, 22)
        row.softRes:SetPoint("LEFT", row, "LEFT", 187, 0)
        row.priority = Theme:CreateEditBox(row, 72, 22)
        row.priority:SetPoint("LEFT", row, "LEFT", 278, 0)
        row.plusOne = Theme:CreateEditBox(row, 62, 22)
        row.plusOne:SetPoint("LEFT", row, "LEFT", 384, 0)
        row.boost = Theme:CreateEditBox(row, 72, 22)
        row.boost:SetPoint("LEFT", row, "LEFT", 472, 0)
        row.counts = Theme:CreateLabel(row, "", 11)
        row.counts:SetPoint("LEFT", row, "LEFT", 562, 0)
        row.counts:SetWidth(104)
        row.minus = Theme:CreateButton(row, "−", 26, 22)
        row.minus:SetPoint("LEFT", row, "LEFT", 674, 0)
        row.minus:SetScript("OnClick", function()
            if row.playerName then GA.PlusOnes:Add(row.playerName, -1, "RULES_UI"); RulesWindow:Refresh(false) end
        end)
        row.plus = Theme:CreateButton(row, "+", 26, 22)
        row.plus:SetPoint("LEFT", row, "LEFT", 704, 0)
        row.plus:SetScript("OnClick", function()
            if row.playerName then GA.PlusOnes:Add(row.playerName, 1, "RULES_UI"); RulesWindow:Refresh(false) end
        end)
        row.save = Theme:CreateButton(row, "Speichern", 90, 22)
        row.save:SetPoint("LEFT", row, "LEFT", 740, 0)
        row.save:SetScript("OnClick", function() RulesWindow:SaveRow(row) end)
        row.resetStats = Theme:CreateButton(row, "Zähler 0", 64, 22)
        row.resetStats:SetPoint("LEFT", row, "LEFT", 838, 0)
        row.resetStats:SetScript("OnClick", function()
            if row.playerName then GA.PlusOnes:ResetStats(row.playerName, "RULES_UI"); RulesWindow:Refresh(false) end
        end)
        self.rows[index] = row
    end

    local hint = Theme:CreateLabel(frame,
        "SoftRes 0–99 · Priorität −99999–99999 · +1 0–9999 · Roll-Bonus −100–100", 10, Theme.colors.muted)
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22)
    self.status = hint

    local previous = Theme:CreateButton(frame, "<", 32, 22)
    previous:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -58, 17)
    previous:SetScript("OnClick", function()
        RulesWindow.offset = math.max(0, RulesWindow.offset - #RulesWindow.rows)
        RulesWindow:Refresh(false)
    end)
    self.previousButton = previous
    local nextButton = Theme:CreateButton(frame, ">", 32, 22)
    nextButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    nextButton:SetScript("OnClick", function()
        if RulesWindow.offset + #RulesWindow.rows < #RulesWindow.players then
            RulesWindow.offset = RulesWindow.offset + #RulesWindow.rows
            RulesWindow:Refresh(false)
        end
    end)
    self.nextButton = nextButton
    return frame
end

function RulesWindow:SetStatus(message, isError)
    if not self.status then return end
    self.status:SetText(message or "")
    self.status:SetTextColor(unpack(isError and Theme.colors.red or Theme.colors.green))
end

function RulesWindow:SelectItem(item)
    local id = GA.Compat and GA.Compat:GetItemID(item)
    if not id or id <= 0 then
        self.currentItem = nil
        self.itemSummary:SetText("Ungültige Item-ID oder kein Itemlink.")
        self.itemSummary:SetTextColor(unpack(Theme.colors.red))
        self:SetStatus("Das Item konnte nicht geladen werden.", true)
        self:Refresh(false)
        return false
    end
    self.currentItem = id
    self:SetStatus("Itemregeln geladen.")
    self:Refresh(false)
    return true
end

function RulesWindow:SaveRow(row)
    if not row or not row.playerName then return end
    if not self.currentItem then
        self:SetStatus("Zuerst ein gültiges Item laden.", true)
        return
    end
    local softRes, err = parseInteger(row.softRes:GetText(), 0, 99, "SoftRes")
    if not softRes then self:SetStatus(err, true); return end
    local priority
    priority, err = parseInteger(row.priority:GetText(), -99999, 99999, "Priorität")
    if not priority then self:SetStatus(err, true); return end
    local plusOne
    plusOne, err = parseInteger(row.plusOne:GetText(), 0, 9999, "+1")
    if not plusOne then self:SetStatus(err, true); return end
    local boost
    boost, err = parseInteger(row.boost:GetText(), -100, 100, "Roll-Bonus")
    if not boost then self:SetStatus(err, true); return end

    local player = row.playerName
    if softRes == 0 then
        GA.SoftRes:Remove(player, self.currentItem)
    else
        local ok, reserveError = GA.SoftRes:Reserve(player, self.currentItem, softRes)
        if not ok then self:SetStatus(reserveError or "SoftRes konnte nicht gespeichert werden.", true); return end
    end
    GA.Priority:Set(self.currentItem, player, priority)
    GA.PlusOnes:Set(player, plusOne, "RULES_UI")
    GA.BoostedRolls:Set(player, boost)
    self:SetStatus("Werte für " .. player .. " gespeichert.")
    self:Refresh(false)
end

function RulesWindow:Refresh(rebuildPlayers)
    if not self.frame then return end
    if rebuildPlayers or #self.players == 0 then self:CollectPlayers() end
    local reservations = self.currentItem and moduleValue(GA.SoftRes, "GetReservations", self.currentItem) or nil
    if type(reservations) ~= "table" then reservations = nil end
    local reservationPlayers, reservationTotal = 0, 0
    for _, amount in pairs(reservations or {}) do
        reservationPlayers = reservationPlayers + 1
        reservationTotal = reservationTotal + (tonumber(amount) or 1)
    end
    if self.currentItem then
        local name, link = GA.Compat:GetItemInfo(self.currentItem)
        self.itemSummary:SetText(string.format("%s · %d Spieler / %d SoftRes",
            link or name or ("Item " .. tostring(self.currentItem)), reservationPlayers, reservationTotal))
        self.itemSummary:SetTextColor(unpack(Theme.colors.text))
        self.hardCheck:SetChecked(moduleValue(GA.SoftRes, "IsHardReserved", self.currentItem) and true or false)
        self.hardCheck:Enable()
    else
        self.hardCheck:SetChecked(false)
        self.hardCheck:Disable()
    end

    for index = 1, #self.rows do
        local row = self.rows[index]
        local player = self.players[self.offset + index]
        if player then
            row.playerName = player.name
            row.player:SetText(player.name)
            row.softRes:SetText(tostring((reservations and reservations[playerKey(player.name)]) or 0))
            row.priority:SetText(tostring(self.currentItem and moduleValue(GA.Priority, "Get", self.currentItem, player.name) or 0))
            row.plusOne:SetText(tostring(moduleValue(GA.PlusOnes, "Get", player.name)))
            row.boost:SetText(tostring(moduleValue(GA.BoostedRolls, "Get", player.name)))
            local stats = GA.PlusOnes.GetStats and GA.PlusOnes:GetStats(player.name) or { total = 0, MS = 0, OS = 0 }
            row.counts:SetText(string.format("%d / %d / %d", stats.total, stats.MS, stats.OS))
            if self.currentItem then row.save:Enable() else row.save:Disable() end
            row:Show()
        else
            row.playerName = nil
            row:Hide()
        end
    end
    if self.offset > 0 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.offset + #self.rows < #self.players then self.nextButton:Enable() else self.nextButton:Disable() end
end

function RulesWindow:Show(item)
    local frame = self:EnsureFrame()
    if not frame then return end
    if item then
        self.itemInput:SetText(tostring(item))
        self:SelectItem(item)
    else
        self:Refresh(true)
    end
    frame:Show()
    frame:Raise()
end

function RulesWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function RulesWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function RulesWindow:Initialize()
    if self.initialized then return true end
    self:EnsureFrame()
    local refreshEvents = {
        "GA_SOFTRES_CHANGED", "GA_PRIORITY_CHANGED", "GA_PLUSONE_CHANGED",
        "GA_PLUSONE_RESET", "GA_BOOST_CHANGED", "GA_HARDRES_CHANGED",
        "GA_ITEM_LEDGER_CHANGED", "GA_LEDGER_RULE_CHANGED",
    }
    for index = 1, #refreshEvents do
        GA.Events:On(refreshEvents[index], function() RulesWindow:Refresh(false) end, self)
    end
    local rosterEvents = { "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PLAYER_ENTERING_WORLD" }
    for index = 1, #rosterEvents do
        local event = rosterEvents[index]
        GA.Events:On(event, function() RulesWindow:Refresh(true) end, self)
        GA.Events:RegisterGameEvent(event)
    end
    self.initialized = true
    self:Refresh(true)
    return true
end

RulesWindow.OnInitialize = RulesWindow.Initialize
RulesWindow.OnEnable = RulesWindow.Initialize
GA:RegisterModule("RulesWindow", RulesWindow)
