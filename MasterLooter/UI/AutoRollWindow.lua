local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local AutoRollWindow = { page = 1, pageSize = 8, rows = {} }
GA.UI.AutoRollWindow = AutoRollWindow

local CHOICE_OPTIONS = {
    { value = "MS", key = "autoroll.choice.ms" },
    { value = "OS", key = "autoroll.choice.os" },
    { value = "TRANSMOG", key = "autoroll.choice.transmog" },
    { value = "PASS", key = "autoroll.choice.pass" },
}
local MATCH_OPTIONS = {
    { value = "EXACT", key = "autoroll.match.exact" },
    { value = "FAMILY", key = "autoroll.match.family" },
    { value = "NAME", key = "autoroll.match.name" },
}

local function L(key, ...)
    if type(GA.L) == "function" then return GA:L(key, ...) end
    return tostring(key or "")
end

local function trace(action, detail)
    if type(GA.Trace) == "function" then GA:Trace("AUTOROLL_UI", action, detail) end
end

local function createDropdown(parent, name, width, definitions)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown.options = definitions
    function dropdown:SetValue(value)
        self.selectedValue = value
        if type(UIDropDownMenu_SetSelectedValue) == "function" then UIDropDownMenu_SetSelectedValue(self, value) end
        local text = tostring(value or "")
        for _, option in ipairs(self.options) do
            if option.value == value then text = L(option.key); break end
        end
        if type(UIDropDownMenu_SetText) == "function" then UIDropDownMenu_SetText(self, text) end
    end
    function dropdown:GetValue() return self.selectedValue end
    if type(UIDropDownMenu_SetWidth) == "function" then UIDropDownMenu_SetWidth(dropdown, width, 0) else dropdown:SetWidth(width) end
    if type(UIDropDownMenu_Initialize) == "function" then
        UIDropDownMenu_Initialize(dropdown, function()
            for _, option in ipairs(dropdown.options) do
                local current = option
                local info = type(UIDropDownMenu_CreateInfo) == "function" and UIDropDownMenu_CreateInfo() or {}
                info.text, info.value = L(current.key), current.value
                info.checked = dropdown.selectedValue == current.value
                info.func = function()
                    dropdown:SetValue(current.value)
                    if type(CloseDropDownMenus) == "function" then CloseDropDownMenus() end
                end
                if type(UIDropDownMenu_AddButton) == "function" then UIDropDownMenu_AddButton(info) end
            end
        end)
    end
    return dropdown
end

local function ruleItemText(rule)
    local id = tonumber(rule and rule.itemID)
    if not id then return L("autoroll.item.unknown") end
    local name, link
    if GA.Compat and type(GA.Compat.GetItemInfo) == "function" then name, link = GA.Compat:GetItemInfo(id) end
    return link or name or string.format(L("autoroll.item.id"), id)
end

local function ruleItemLink(rule)
    if type(rule) ~= "table" then return nil end
    if type(rule.itemLink) == "string" and string.find(rule.itemLink, "|Hitem:", 1, true) then return rule.itemLink end
    if GA.Compat and type(GA.Compat.GetItemInfo) == "function" then return select(2, GA.Compat:GetItemInfo(rule.itemID)) end
end

function AutoRollWindow:SetStatus(text, color)
    if not self.status then return end
    self.status:SetText(text or "")
    self.status:SetTextColor(unpack(color or Theme.colors.muted))
end

function AutoRollWindow:AcceptItem(item)
    local link = item
    if not link and Theme and type(Theme.TakeDraggedItem) == "function" then link = Theme:TakeDraggedItem() end
    if not link and type(GetCursorInfo) == "function" then
        local cursorType, id, cursorLink = GetCursorInfo()
        if cursorType == "item" then
            link = cursorLink
            if not link and type(GetItemInfo) == "function" then link = select(2, GetItemInfo(id)) end
            link = link or id
            if type(ClearCursor) == "function" then ClearCursor() end
        end
    end
    local id = GA.Compat and GA.Compat:GetItemID(link)
    if not id then self:SetStatus(L("autoroll.error.invalid_item"), Theme.colors.red); return false end
    self.itemEdit:SetText(type(link) == "string" and link or tostring(id))
    self:SetStatus(string.format(L("autoroll.item.accepted"), id), Theme.colors.green)
    return true
end

function AutoRollWindow:AddRule()
    local module = GA.AutoRoll
    if not module or type(module.Add) ~= "function" then self:SetStatus(L("autoroll.error.unavailable"), Theme.colors.red); return false end
    local item = self.itemEdit:GetText()
    local id = GA.Compat and GA.Compat:GetItemID(item)
    if not id then self:SetStatus(L("autoroll.error.invalid_item"), Theme.colors.red); return false end
    local delay = tonumber(self.delayEdit:GetText())
    if not delay or delay < 0 or delay > 10 then self:SetStatus(L("autoroll.error.delay"), Theme.colors.red); return false end
    local rule, err = module:Add({
        item = item, itemLink = string.find(item, "|Hitem:", 1, true) and item or nil,
        choice = self.choiceDropdown:GetValue() or "MS",
        matchMode = self.matchDropdown:GetValue() or "EXACT",
        delay = delay, enabled = true,
    })
    if not rule then self:SetStatus(tostring(err or L("autoroll.error.add")), Theme.colors.red); return false end
    self.itemEdit:SetText("")
    self.page = 1
    local provider = GA.ItemData and type(GA.ItemData.GetLoadedProvider) == "function" and GA.ItemData:GetLoadedProvider() or nil
    self:SetStatus((not provider or provider.importing) and L("autoroll.rule.added_indexing") or L("autoroll.rule.added"), Theme.colors.green)
    trace("RULE_ADDED", tostring(rule.id) .. "/" .. tostring(id))
    self:Refresh()
    return true
end

function AutoRollWindow:SetRuleEnabled(rule, enabled)
    local module = GA.AutoRoll
    local ok
    if module and type(module.SetRuleEnabled) == "function" then ok = module:SetRuleEnabled(rule.id, enabled)
    elseif type(rule) == "table" then rule.enabled, ok = enabled and true or false, true end
    if ok and GA.Events and type(GA.Events.Emit) == "function" then GA.Events:Emit("GA_AUTOROLL_CHANGED", rule, "UPDATED") end
    trace("RULE_TOGGLE", tostring(rule and rule.id) .. "/" .. tostring(enabled))
    return ok
end

function AutoRollWindow:RemoveRule(rule)
    if not rule or not GA.AutoRoll or type(GA.AutoRoll.Remove) ~= "function" then return false end
    local removed = GA.AutoRoll:Remove(rule.id)
    if removed then
        self:SetStatus(L("autoroll.rule.removed"), Theme.colors.green)
        trace("RULE_REMOVED", tostring(rule.id))
        self:Refresh()
    end
    return removed
end

function AutoRollWindow:SetGlobalEnabled(enabled)
    local module = GA.AutoRoll
    local ok
    if module and type(module.SetEnabled) == "function" then ok = module:SetEnabled(enabled)
    elseif module and type(module.GetStore) == "function" then module:GetStore().enabled, ok = enabled and true or false, true end
    self:SetStatus(ok == false and L("autoroll.error.setting") or L("autoroll.setting.saved"), ok == false and Theme.colors.red or Theme.colors.green)
    trace("GLOBAL_TOGGLE", tostring(enabled))
    return ok ~= false
end

function AutoRollWindow:SaveDefaultDelay()
    local delay = tonumber(self.defaultDelayEdit:GetText())
    if not delay or delay < 0 or delay > 10 then self:SetStatus(L("autoroll.error.delay"), Theme.colors.red); return false end
    local module = GA.AutoRoll
    local ok
    if module and type(module.SetDefaultDelay) == "function" then ok = module:SetDefaultDelay(delay)
    elseif module and type(module.GetStore) == "function" then module:GetStore().defaultDelay, ok = delay, true end
    self.delayEdit:SetText(tostring(delay))
    self:SetStatus(ok == false and L("autoroll.error.setting") or L("autoroll.setting.saved"), ok == false and Theme.colors.red or Theme.colors.green)
    return ok ~= false
end

function AutoRollWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterAutoRollWindow", UIParent)
    frame:SetWidth(760); frame:SetHeight(590); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, L("autoroll.title")); Theme:MakeMovable(frame, "autoRollWindow")
    Theme:RestorePosition(frame, "autoRollWindow", "CENTER", 0, 10); Theme:RegisterForEscape(frame); self.frame = frame

    local enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enabled:SetWidth(24); enabled:SetHeight(24); enabled:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    local enabledLabel = Theme:CreateLabel(frame, L("autoroll.enabled"), 12); enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 5, 1)
    enabled:SetScript("OnClick", function(button) AutoRollWindow:SetGlobalEnabled(button:GetChecked() and true or false) end)
    self.enabledCheck, self.enabledLabel = enabled, enabledLabel

    local defaultLabel = Theme:CreateLabel(frame, L("autoroll.default_delay"), 11, Theme.colors.gold); defaultLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -178, -51)
    local defaultDelay = Theme:CreateEditBox(frame, 42, 23, true); defaultDelay:SetPoint("LEFT", defaultLabel, "RIGHT", 8, 0); self.defaultDelayEdit = defaultDelay
    local defaultSave = Theme:CreateButton(frame, L("autoroll.save"), 76, 23); defaultSave:SetPoint("LEFT", defaultDelay, "RIGHT", 7, 0); defaultSave:SetScript("OnClick", function() AutoRollWindow:SaveDefaultDelay() end)

    local addPanel = CreateFrame("Frame", nil, frame); addPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -82); addPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -82); addPanel:SetHeight(105); Theme:ApplyInset(addPanel); self.addPanel = addPanel
    local itemLabel = Theme:CreateLabel(addPanel, L("autoroll.item"), 11, Theme.colors.gold); itemLabel:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 12, -10)
    local itemEdit = Theme:CreateEditBox(addPanel, 295, 24); itemEdit:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 12, -29); itemEdit:SetScript("OnReceiveDrag", function() AutoRollWindow:AcceptItem() end); self.itemEdit = itemEdit
    local hint = Theme:CreateLabel(addPanel, L("autoroll.item_hint"), 10, Theme.colors.muted); hint:SetPoint("TOPLEFT", itemEdit, "BOTTOMLEFT", 2, -3); hint:SetWidth(295)

    local choiceLabel = Theme:CreateLabel(addPanel, L("autoroll.choice"), 11, Theme.colors.gold); choiceLabel:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 326, -10)
    local choice = createDropdown(addPanel, "MasterLooterAutoRollChoiceDropdown", 105, CHOICE_OPTIONS); choice:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 307, -23); choice:SetValue("MS"); self.choiceDropdown = choice
    local matchLabel = Theme:CreateLabel(addPanel, L("autoroll.match"), 11, Theme.colors.gold); matchLabel:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 466, -10)
    local match = createDropdown(addPanel, "MasterLooterAutoRollMatchDropdown", 150, MATCH_OPTIONS); match:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 447, -23); match:SetValue("EXACT"); self.matchDropdown = match
    local delayLabel = Theme:CreateLabel(addPanel, L("autoroll.delay"), 11, Theme.colors.gold); delayLabel:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 637, -10)
    local delay = Theme:CreateEditBox(addPanel, 43, 24, true); delay:SetPoint("TOPLEFT", addPanel, "TOPLEFT", 637, -29); delay:SetText("3"); self.delayEdit = delay
    local add = Theme:CreateButton(addPanel, L("autoroll.add"), 120, 24); add:SetPoint("BOTTOMRIGHT", addPanel, "BOTTOMRIGHT", -12, 9); add:SetScript("OnClick", function() AutoRollWindow:AddRule() end); self.addButton = add

    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -199); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 54); Theme:ApplyInset(list); self.list = list
    local headers = {
        { L("autoroll.header.active"), 12, 48 }, { L("autoroll.header.item"), 63, 276 },
        { L("autoroll.header.match"), 346, 137 }, { L("autoroll.header.choice"), 488, 92 },
        { L("autoroll.header.delay"), 585, 67 },
    }
    for _, definition in ipairs(headers) do
        local label = Theme:CreateLabel(list, definition[1], 10, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", definition[2], -9); label:SetWidth(definition[3])
    end
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -31 - ((index - 1) * 36)); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -31 - ((index - 1) * 36)); row:SetHeight(32)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.enabled:SetWidth(22); row.enabled:SetHeight(22); row.enabled:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.enabled:SetScript("OnClick", function(button) if row.rule then AutoRollWindow:SetRuleEnabled(row.rule, button:GetChecked() and true or false) end end)
        row.item = Theme:CreateLabel(row, "", 11); row.item:SetPoint("LEFT", row, "LEFT", 38, 0); row.item:SetWidth(276)
        row.match = Theme:CreateLabel(row, "", 10, Theme.colors.muted); row.match:SetPoint("LEFT", row, "LEFT", 321, 0); row.match:SetWidth(137)
        row.choice = Theme:CreateLabel(row, "", 11); row.choice:SetPoint("LEFT", row, "LEFT", 463, 0); row.choice:SetWidth(92)
        row.delay = Theme:CreateLabel(row, "", 10, Theme.colors.muted); row.delay:SetPoint("LEFT", row, "LEFT", 560, 0); row.delay:SetWidth(67)
        row.remove = Theme:CreateButton(row, L("autoroll.delete"), 66, 22); row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0); row.remove:SetScript("OnClick", function() if row.rule then AutoRollWindow:RemoveRule(row.rule) end end)
        self.rows[index] = row
    end
    local previous = Theme:CreateButton(frame, "<", 30, 22); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22); previous:SetScript("OnClick", function() AutoRollWindow.page = math.max(1, AutoRollWindow.page - 1); AutoRollWindow:Refresh() end); self.previousButton = previous
    local page = Theme:CreateLabel(frame, "1/1", 11, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 7, 0); page:SetWidth(48); page:SetJustifyH("CENTER"); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 30, 22); nextButton:SetPoint("LEFT", page, "RIGHT", 7, 0); nextButton:SetScript("OnClick", function() AutoRollWindow.page = math.min(AutoRollWindow.totalPages or 1, AutoRollWindow.page + 1); AutoRollWindow:Refresh() end); self.nextButton = nextButton
    local status = Theme:CreateLabel(frame, L("autoroll.ready"), 10, Theme.colors.muted); status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 158, 26); status:SetPoint("RIGHT", frame, "RIGHT", -20, 0); self.status = status

    if type(hooksecurefunc) == "function" and type(ChatEdit_InsertLink) == "function" and not GA.UI.autoRollLinkHooked then
        GA.UI.autoRollLinkHooked = true
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if AutoRollWindow.itemEdit and type(AutoRollWindow.itemEdit.HasFocus) == "function" and AutoRollWindow.itemEdit:HasFocus() then AutoRollWindow:AcceptItem(link) end
        end)
    end
    return frame
end

function AutoRollWindow:Refresh()
    if not self.frame then return false end
    local module = GA.AutoRoll
    local rules = module and type(module.GetRules) == "function" and module:GetRules() or {}
    local enabled = true
    if module and type(module.IsEnabled) == "function" then enabled = module:IsEnabled()
    elseif module and type(module.GetStore) == "function" then enabled = module:GetStore().enabled ~= false end
    self.enabledCheck:SetChecked(enabled)
    local defaultDelay = module and type(module.GetDefaultDelay) == "function" and module:GetDefaultDelay() or (module and type(module.GetStore) == "function" and module:GetStore().defaultDelay) or 3
    self.defaultDelayEdit:SetText(tostring(tonumber(defaultDelay) or 3))
    if self.itemEdit:GetText() == "" then self.delayEdit:SetText(tostring(tonumber(defaultDelay) or 3)) end
    self.totalPages = math.max(1, math.ceil(#rules / self.pageSize)); self.page = math.max(1, math.min(self.page or 1, self.totalPages))
    local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local rule = rules[offset + index]
        if rule then
            row.rule = rule; row.enabled:SetChecked(rule.enabled ~= false); row.item:SetText(ruleItemText(rule))
            row.match:SetText(L("autoroll.match." .. string.lower(tostring(rule.matchMode or "EXACT"))))
            row.choice:SetText(L("autoroll.choice." .. string.lower(tostring(rule.choice or "MS"))))
            row.delay:SetText(string.format(L("autoroll.delay.short"), tonumber(rule.delay) or tonumber(defaultDelay) or 3))
            if Theme and type(Theme.SetItemTooltip) == "function" then Theme:SetItemTooltip(row, ruleItemLink(rule)) end
            row:Show()
        else row.rule = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. "/" .. self.totalPages)
    if self.page > 1 then self.previousButton:Enable() else self.previousButton:Disable() end
    if self.page < self.totalPages then self.nextButton:Enable() else self.nextButton:Disable() end
    return true
end

function AutoRollWindow:Show(item)
    local frame = self:EnsureFrame(); if not frame then return false end
    if item then self:AcceptItem(item) end
    self:Refresh(); frame:Show(); if type(frame.Raise) == "function" then frame:Raise() end
    return true
end
function AutoRollWindow:Hide() if self.frame then self.frame:Hide() end end
function AutoRollWindow:Toggle()
    local frame = self:EnsureFrame(); if not frame then return false end
    if frame:IsShown() then self:Hide() else return self:Show() end
    return true
end
function AutoRollWindow:OnInitialize()
    if self.initialized then return true end
    if GA.Events and type(GA.Events.On) == "function" then GA.Events:On("GA_AUTOROLL_CHANGED", function() if AutoRollWindow.frame and AutoRollWindow.frame:IsShown() then AutoRollWindow:Refresh() end end, self) end
    self.initialized = true
    return true
end

GA:RegisterModule("AutoRollWindow", AutoRollWindow)
