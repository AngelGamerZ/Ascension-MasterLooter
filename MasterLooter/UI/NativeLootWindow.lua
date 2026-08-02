local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local NativeLootWindow = { active = {}, index = 1 }
GA.UI.NativeLootWindow = NativeLootWindow

local CHOICES = {
    { key = "NEED", text = "Bedarf" },
    { key = "GREED", text = "Gier" },
    { key = "DE", text = "Entzaubern" },
    { key = "PASS", text = "Passen" },
}

local function field(source, ...)
    if type(source) ~= "table" then return nil end
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if source[key] ~= nil then return source[key] end
    end
end

local function normalizeActive(source)
    if type(source) == "table" and field(source, "rollID", "id", "rollId") ~= nil then source = { source }
    elseif type(source) == "table" then source = field(source, "active", "rolls", "sessions") or source end
    local result = {}
    for key, state in pairs(type(source) == "table" and source or {}) do
        if type(state) == "table" then
            state.rollID = field(state, "rollID", "id", "rollId") or key
            result[#result + 1] = state
        end
    end
    table.sort(result, function(left, right)
        local leftEnd = tonumber(field(left, "expiresAt", "endsAt")) or math.huge
        local rightEnd = tonumber(field(right, "expiresAt", "endsAt")) or math.huge
        if leftEnd ~= rightEnd then return leftEnd < rightEnd end
        return tostring(left.rollID) < tostring(right.rollID)
    end)
    return result
end

local function isAllowed(state, choice)
    local allowed = field(state, "allowedChoices", "choices", "allowed")
    if type(allowed) == "table" then
        if allowed[choice] ~= nil then return allowed[choice] and true or false end
        for _, value in ipairs(allowed) do if string.upper(tostring(value)) == choice then return true end end
        return false
    end
    local flags = {
        NEED = { "canNeed", "needAllowed" }, GREED = { "canGreed", "greedAllowed" },
        DE = { "canDisenchant", "canDE", "disenchantAllowed" }, PASS = { "canPass", "passAllowed" },
    }
    local value = field(state, unpack(flags[choice]))
    return value == true or value == 1
end

function NativeLootWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterNativeLootWindow", UIParent)
    frame:SetWidth(455); frame:SetHeight(250); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Gruppenloot")
    Theme:MakeMovable(frame, "nativeLootWindow"); Theme:RestorePosition(frame, "nativeLootWindow", "CENTER", 0, 125); Theme:RegisterForEscape(frame); self.frame = frame

    local previous = Theme:CreateButton(frame, "<", 30, 21); previous:SetPoint("TOPLEFT", frame, "TOPLEFT", 19, -39); previous:SetScript("OnClick", function() NativeLootWindow:Previous() end); self.previousButton = previous
    local page = Theme:CreateLabel(frame, "0 / 0", 11, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 5, 0); page:SetWidth(55); page:SetJustifyH("CENTER"); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 30, 21); nextButton:SetPoint("LEFT", page, "RIGHT", 5, 0); nextButton:SetScript("OnClick", function() NativeLootWindow:Next() end); self.nextButton = nextButton
    local timer = Theme:CreateLabel(frame, "0:00", 14, Theme.colors.gold); timer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -42); timer:SetWidth(70); timer:SetJustifyH("RIGHT"); self.timerLabel = timer

    local icon = CreateFrame("Button", nil, frame); icon:SetWidth(52); icon:SetHeight(52); icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    icon.texture = icon:CreateTexture(nil, "ARTWORK"); icon.texture:SetAllPoints(icon); icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); self.icon = icon
    local item = Theme:CreateLabel(frame, "Kein aktiver Roll.", 14); item:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4); item:SetPoint("RIGHT", frame, "RIGHT", -22, 0); item:SetHeight(42); item:SetJustifyV("TOP"); self.itemLabel = item
    local status = Theme:CreateLabel(frame, "", 11, Theme.colors.muted); status:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -39); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.statusLabel = status

    self.buttons = {}
    for index, choice in ipairs(CHOICES) do
        local button = Theme:CreateButton(frame, choice.text, 98, 28)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22 + ((index - 1) * 105), 48)
        button:SetScript("OnClick", function() NativeLootWindow:Submit(choice.key) end)
        button:Disable(); self.buttons[choice.key] = button
    end
    local hint = Theme:CreateLabel(frame, "Nicht erlaubte Optionen bleiben deaktiviert.", 11, Theme.colors.muted); hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 21); hint:SetPoint("RIGHT", frame, "RIGHT", -22, 0); hint:SetJustifyH("CENTER")
    frame:SetScript("OnUpdate", function(_, elapsed) NativeLootWindow:OnUpdate(elapsed) end)
    return frame
end

function NativeLootWindow:GetCurrent()
    return self.active[self.index]
end

function NativeLootWindow:RefreshActive(preferredRollID, fallbackState)
    if not self:EnsureFrame() then return end
    local manager = GA.NativeLootRoll
    local source = {}
    if manager and type(manager.GetActive) == "function" then
        local ok, active = pcall(manager.GetActive, manager)
        if ok and type(active) == "table" then source = active end
    end
    self.active = normalizeActive(source)
    if #self.active == 0 and type(fallbackState) == "table" then self.active = normalizeActive(fallbackState) end
    if preferredRollID then
        for index, state in ipairs(self.active) do if tostring(state.rollID) == tostring(preferredRollID) then self.index = index; break end end
    end
    self.index = math.max(1, math.min(self.index or 1, math.max(1, #self.active)))
    self:Render()
end

function NativeLootWindow:Render()
    local state = self:GetCurrent()
    self.pageLabel:SetText(state and (self.index .. " / " .. #self.active) or "0 / 0")
    if self.index > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.index < #self.active then self.nextButton:Enable() else self.nextButton:Disable() end
    if not state then
        self.itemLabel:SetText("Kein aktiver Roll."); self.statusLabel:SetText(""); self.timerLabel:SetText("0:00"); self.icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); Theme:SetItemTooltip(self.icon, nil)
        for _, button in pairs(self.buttons) do button:Disable() end
        return
    end
    local itemLink = field(state, "itemLink", "link")
    self.itemLabel:SetText(itemLink or field(state, "itemName", "name") or "Unbekanntes Item")
    local texture = field(state, "texture", "icon"); if not texture and itemLink then texture = select(10, GetItemInfo(itemLink)) end
    self.icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark"); Theme:SetItemTooltip(self.icon, itemLink)
    self.endsAt = tonumber(field(state, "expiresAt", "endsAt", "endTime"))
    local selected = field(state, "choice", "selectedChoice", "myChoice")
    self.statusLabel:SetText(selected and ("Auswahl: " .. tostring(selected)) or "Bitte auswählen.")
    self.statusLabel:SetTextColor(unpack(Theme.colors.muted))
    for _, choice in ipairs(CHOICES) do
        local button = self.buttons[choice.key]
        if not selected and isAllowed(state, choice.key) then button:Enable() else button:Disable() end
    end
end

function NativeLootWindow:Previous()
    if self.index > 1 then self.index = self.index - 1; self:Render() end
end

function NativeLootWindow:Next()
    if self.index < #self.active then self.index = self.index + 1; self:Render() end
end

function NativeLootWindow:Submit(choice)
    local state = self:GetCurrent(); if not state or not isAllowed(state, choice) then return end
    local manager = GA.NativeLootRoll; if not manager or type(manager.Roll) ~= "function" then return end
    local ok, result, err = pcall(manager.Roll, manager, state.rollID, choice)
    if ok and result ~= false and result ~= nil then
        state.choice = choice; self.statusLabel:SetText("Auswahl gesendet: " .. choice); for _, button in pairs(self.buttons) do button:Disable() end
    else self.statusLabel:SetText(tostring(err or result or "Auswahl fehlgeschlagen.")); self.statusLabel:SetTextColor(unpack(Theme.colors.red)) end
end

function NativeLootWindow:OnUpdate(elapsed)
    if not self.endsAt or not self.frame:IsShown() then return end
    self.elapsed = (self.elapsed or 0) + elapsed; if self.elapsed < 0.1 then return end; self.elapsed = 0
    local remaining = self.endsAt - GetTime(); self.timerLabel:SetText(Theme:FormatTime(remaining))
    if remaining <= 0 then self.endsAt = nil; self:RefreshActive() end
end

function NativeLootWindow:Show() local frame = self:EnsureFrame(); if frame then self:RefreshActive(); frame:Show() end end
function NativeLootWindow:Hide() if self.frame then self.frame:Hide() end end
function NativeLootWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function NativeLootWindow:OnInitialize()
    self:EnsureFrame()
    GA.Events:On("GA_NATIVE_ROLL_STARTED", function(_, _, state) NativeLootWindow:RefreshActive(state and field(state, "rollID", "id", "rollId"), state); NativeLootWindow.frame:Show() end, self)
    GA.Events:On("GA_NATIVE_ROLL_UPDATED", function(_, _, state) NativeLootWindow:RefreshActive(state and field(state, "rollID", "id", "rollId"), state) end, self)
    GA.Events:On("GA_NATIVE_ROLL_ENDED", function() NativeLootWindow:RefreshActive() end, self)
    return true
end

GA:RegisterModule("NativeLootWindow", NativeLootWindow)
