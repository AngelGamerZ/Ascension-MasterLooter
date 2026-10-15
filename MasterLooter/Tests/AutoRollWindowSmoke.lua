local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end end
local function same(actual, expected, message) expect(actual == expected, tostring(message) .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
unpack = unpack or table.unpack

local function widget(name, parent)
    local value = { name = name, parent = parent, shown = true, enabledState = true, text = "", scripts = {} }
    for _, method in ipairs({ "SetWidth", "SetHeight", "SetFrameStrata", "SetToplevel", "SetMovable", "SetClampedToScreen", "EnableMouse", "RegisterForDrag", "RegisterForClicks", "SetPoint", "SetAllPoints", "SetHighlightTexture", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetJustifyH", "SetNumeric", "SetAutoFocus", "SetTextInsets" }) do value[method] = function() end end
    function value:GetName() return self.name end
    function value:SetScript(event, callback) self.scripts[event] = callback end
    function value:CreateFontString() return widget(nil, self) end
    function value:SetText(text) self.text = tostring(text or "") end
    function value:GetText() return self.text end
    function value:SetChecked(checked) self.checked = checked end
    function value:GetChecked() return self.checked end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:IsShown() return self.shown end
    function value:Enable() self.enabledState = true end
    function value:Disable() self.enabledState = false end
    function value:Raise() self.raised = true end
    function value:HasFocus() return self.focused == true end
    return value
end

UIParent, UISpecialFrames = widget("UIParent"), {}
local createdNames = {}
function CreateFrame(_, name, parent)
    if name then expect(not createdNames[name], "named dropdown/frame is unique: " .. name); createdNames[name] = true end
    return widget(name, parent or UIParent)
end
local dropdownButtons = {}
function UIDropDownMenu_SetWidth(dropdown, width, padding) dropdown.width, dropdown.padding = width, padding end
function UIDropDownMenu_SetSelectedValue(dropdown, value) dropdown.selectedValue = value end
function UIDropDownMenu_SetText(dropdown, text) dropdown.displayText = text end
function UIDropDownMenu_Initialize(dropdown, callback) dropdown.initialize = callback end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) dropdownButtons[#dropdownButtons + 1] = info end
function CloseDropDownMenus() end
function ChatEdit_InsertLink() end
local linkHook
function hooksecurefunc(name, callback) expect(name == "ChatEdit_InsertLink", "only Shift-click item insertion is hooked"); linkHook = callback end
local cursor = { "item", 3000, "|cff0070dd|Hitem:3000:0:0:0|h[Heroic Test]|h|r" }
function GetCursorInfo() return unpack(cursor) end
function ClearCursor() cursor.cleared = true end
function GetItemInfo(id)
    id = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
    return id == 3000 and "Heroic Test" or "Kam's Buckler", id == 3000 and cursor[3] or "|cff0070dd|Hitem:1985:0:0:0|h[Kam's Buckler]|h|r"
end

local rules, nextID, emitted = {}, 0, 0
local store = { enabled = true, defaultDelay = 3 }
local GA = {
    UI = {}, modules = {},
    Compat = {
        GetItemID = function(_, item) if type(item) == "number" then return item end return tonumber(tostring(item):match("item:(%-?%d+)")) or tonumber(item) end,
        GetItemInfo = function(_, item) return GetItemInfo(item) end,
    },
    Events = { On = function() end, Emit = function() emitted = emitted + 1 end },
    AutoRoll = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:L(key, ...)
    local values = {
        ["autoroll.title"] = "AutoRoll rules", ["autoroll.choice.ms"] = "MS", ["autoroll.choice.os"] = "OS",
        ["autoroll.choice.transmog"] = "Transmog", ["autoroll.choice.pass"] = "Pass",
        ["autoroll.match.exact"] = "Only this item ID", ["autoroll.match.family"] = "All item versions", ["autoroll.match.name"] = "Same item name",
        ["autoroll.item.id"] = "Item ID %d", ["autoroll.item.accepted"] = "Item ID %d accepted.", ["autoroll.delay.short"] = "%.1f sec",
    }
    local value = values[key] or key
    return select("#", ...) > 0 and string.format(value, ...) or value
end
function GA.AutoRoll:GetStore() return store end
function GA.AutoRoll:GetRules() return rules end
function GA.AutoRoll:IsEnabled() return store.enabled end
function GA.AutoRoll:SetEnabled(value) store.enabled = value; return true end
function GA.AutoRoll:GetDefaultDelay() return store.defaultDelay end
function GA.AutoRoll:SetDefaultDelay(value) store.defaultDelay = value; return true end
function GA.AutoRoll:Add(rule) nextID = nextID + 1; rule.id, rule.itemID = nextID, GA.Compat:GetItemID(rule.item); rules[#rules + 1] = rule; return rule end
function GA.AutoRoll:Remove(id) for index, rule in ipairs(rules) do if rule.id == id then table.remove(rules, index); return true end end return false end
function GA.AutoRoll:SetRuleEnabled(id, value) for _, rule in ipairs(rules) do if rule.id == id then rule.enabled = value; return true end end return false end

local colors = { gold = { 1, 1, 0 }, text = { 1, 1, 1 }, muted = { .5, .5, .5 }, green = { 0, 1, 0 }, red = { 1, 0, 0 } }
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:ApplyInset() end
function Theme:AddTitle(frame, title) frame.title = title end
function Theme:MakeMovable() end
function Theme:RestorePosition() end
function Theme:RegisterForEscape() end
function Theme:CreateLabel(parent, text) local value = widget(nil, parent); value:SetText(text); return value end
function Theme:CreateButton(parent, text) local value = widget(nil, parent); value:SetText(text); return value end
function Theme:CreateEditBox(parent) return widget(nil, parent) end
function Theme:SetItemTooltip(widgetValue, link) widgetValue.tooltipLink = link end
function Theme:TakeDraggedItem() return nil end

assert(loadfile("MasterLooter/UI/AutoRollWindow.lua"))("MasterLooter", GA)
local window = GA.UI.AutoRollWindow
expect(window:Show(), "AutoRoll window opens")
same(window.frame.title, "AutoRoll rules", "window title is localized")
same(window.choiceDropdown:GetName(), "MasterLooterAutoRollChoiceDropdown", "choice dropdown has stable 3.3.5a name")
same(window.matchDropdown:GetName(), "MasterLooterAutoRollMatchDropdown", "match dropdown has stable 3.3.5a name")
same(window.choiceDropdown.padding, 0, "choice dropdown passes explicit legacy padding")
same(window.matchDropdown.padding, 0, "match dropdown passes explicit legacy padding")
same(window.choiceDropdown:GetValue(), "MS", "MS is the default action")
same(window.matchDropdown:GetValue(), "EXACT", "exact ID is the safe default match mode")

window.itemEdit:SetText("1985"); window.choiceDropdown:SetValue("OS"); window.matchDropdown:SetValue("FAMILY"); window.delayEdit:SetText("2.5")
expect(window:AddRule(), "manual item ID creates a rule")
same(rules[1].itemID, 1985, "manual item ID is preserved")
same(rules[1].choice, "OS", "selected action is preserved")
same(rules[1].matchMode, "FAMILY", "all-versions match mode is preserved")
same(rules[1].delay, 2.5, "per-rule delay is preserved")
same(window.rows[1].match:GetText(), "All item versions", "rule list explains family matching")
expect(window.rows[1].tooltipLink and window.rows[1].tooltipLink:find("item:1985", 1, true), "rule row exposes native item tooltip data")

window.itemEdit:SetText("invalid"); expect(not window:AddRule(), "invalid item text is rejected")
window.itemEdit:SetText("1985"); window.delayEdit:SetText("11"); expect(not window:AddRule(), "delay above ten seconds is rejected")
expect(window:AcceptItem(), "dragged cursor item is accepted")
expect(cursor.cleared, "accepted cursor item is cleared")
expect(window.itemEdit:GetText():find("item:3000", 1, true), "drag retains the concrete item link")

window.itemEdit.focused = true; linkHook("|cff0070dd|Hitem:4000:0:0:0|h[Shift Test]|h|r")
expect(window.itemEdit:GetText():find("item:4000", 1, true), "Shift-click inserts the concrete item link into the focused field")
window.enabledCheck.checked = false; window.enabledCheck.scripts.OnClick(window.enabledCheck); expect(not store.enabled, "global AutoRoll checkbox disables AutoRoll")
window.defaultDelayEdit:SetText("4"); expect(window:SaveDefaultDelay(), "default delay is saved"); same(store.defaultDelay, 4, "saved default delay reaches module")
window.rows[1].enabled.checked = false; window.rows[1].enabled.scripts.OnClick(window.rows[1].enabled); expect(rules[1].enabled == false, "individual rule checkbox disables one rule")
window.rows[1].remove.scripts.OnClick(); same(#rules, 0, "delete button removes one rule")
expect(emitted > 0, "rule toggle emits a refresh event")

print("PASS: " .. assertions .. " AutoRoll-window assertions")
