-- Geometry simulation for the three administrative windows involved in the
-- reported clipping/layering/reset issues.
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end end
unpack = unpack or table.unpack

local factors = {
    TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, .5 },
    CENTER = { .5, .5 }, RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local function widget(kind, parent)
    local value = { kind = kind, parent = parent, points = {}, children = {}, shown = true, enabled = true, text = "" }
    if parent and parent.children then parent.children[#parent.children + 1] = value end
    function value:SetWidth(v) self.width = v end
    function value:SetHeight(v) self.height = v end
    function value:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "string" then x, y, relativePoint, relative = relativePoint, x, relative, self.parent end
        self.points[#self.points + 1] = { point, type(relative) == "table" and relative or self.parent, relativePoint or point, tonumber(x) or 0, tonumber(y) or 0 }
    end
    function value:SetAllPoints(relative) self:SetPoint("TOPLEFT", relative or self.parent, "TOPLEFT"); self:SetPoint("BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT") end
    function value:ClearAllPoints() self.points = {} end
    function value:CreateFontString() return widget("FontString", self) end
    function value:CreateTexture() return widget("Texture", self) end
    function value:SetScript(event, callback) self[event] = callback end
    function value:SetText(text) self.text = tostring(text or "") end
    function value:GetText() return self.text end
    function value:SetTextColor() end
    function value:SetJustifyH() end
    function value:SetWordWrap() end
    function value:SetChecked(v) self.checked = v end
    function value:SetBackdrop() end
    function value:SetBackdropColor() end
    function value:SetBackdropBorderColor() end
    function value:SetFrameStrata(v) self.strata = v end
    function value:SetToplevel(v) self.toplevel = v end
    function value:SetMovable() end
    function value:SetClampedToScreen() end
    function value:EnableMouse() end
    function value:RegisterForDrag() end
    function value:RegisterForClicks() end
    function value:SetHighlightTexture() end
    function value:SetAutoFocus() end
    function value:SetTextInsets() end
    function value:SetNumeric() end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:IsShown() return self.shown end
    function value:Enable() self.enabled = true end
    function value:Disable() self.enabled = false end
    function value:Raise() self.raised = true end
    function value:GetName() return nil end
    return value
end

UIParent = widget("Frame"); UIParent.width, UIParent.height = 1920, 1080
UISpecialFrames = {}
function CreateFrame(kind, _, parent) return widget(kind, parent or UIParent) end

local function axis(object, dimension, visiting)
    if object == UIParent then return 0, dimension == 1 and UIParent.width or UIParent.height end
    visiting = visiting or {}; if visiting[object] then error("anchor cycle") end; visiting[object] = true
    local equations = {}
    for _, point in ipairs(object.points) do
        local start, size = axis(point[2] or object.parent or UIParent, dimension, visiting)
        equations[#equations + 1] = { factor = factors[point[1]][dimension], target = start + factors[point[3]][dimension] * size + point[dimension == 1 and 4 or 5] }
    end
    local size
    if dimension == 1 then size = object.width else size = object.height end
    if not size then
        for left = 1, #equations do for right = left + 1, #equations do
            local delta = equations[right].factor - equations[left].factor
            if delta ~= 0 then size = (equations[right].target - equations[left].target) / delta; break end
        end if size then break end end
    end
    size = size or 0
    local start = equations[1] and equations[1].target - equations[1].factor * size or 0
    visiting[object] = nil
    return start, size
end
local function rect(object)
    local x, w = axis(object, 1); local y, h = axis(object, 2)
    return { left = x, right = x + w, bottom = y, top = y + h }
end
local function inside(child, parent, message)
    local a, b = rect(child), rect(parent)
    expect(a.left >= b.left and a.right <= b.right and a.bottom >= b.bottom and a.top <= b.top,
        message .. string.format(" child=%.1f/%.1f/%.1f/%.1f parent=%.1f/%.1f/%.1f/%.1f", a.left, a.right, a.bottom, a.top, b.left, b.right, b.bottom, b.top))
end
local function horizontal(left, right, message) expect(rect(left).right <= rect(right).left, message) end
local function vertical(lower, upper, message) expect(rect(lower).top <= rect(upper).bottom, message) end

local GA = { UI = {}, modules = {}, Compat = {}, Events = { On = function() end, RegisterGameEvent = function() end } }
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:Localize(text)
    if text == "+1 wird nur über den Zeilenbutton im Lootmaster gebucht" then
        return "+1 is added only through the row button in the loot master window"
    end
    return text
end
local colors = { gold = { 1, 1, 0 }, text = { 1, 1, 1 }, muted = { .5, .5, .5 }, green = { 0, 1, 0 }, red = { 1, 0, 0 } }
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:ApplyInset() end
function Theme:CreateLabel(parent, text, size) local v = parent:CreateFontString(); v:SetText(GA:Localize(text)); v.width = math.max(1, #tostring(v:GetText() or "") * ((size or 11) * .55)); v.height = (size or 11) + 3; return v end
function Theme:CreateButton(parent, text, width, height) local v = widget("Button", parent); v.width, v.height = width, height; v:SetText(text); return v end
function Theme:CreateEditBox(parent, width, height) local v = widget("EditBox", parent); v.width, v.height = width, height; return v end
function Theme:AddTitle() end
function Theme:MakeMovable() end
function Theme:RestorePosition(frame) frame:SetPoint("CENTER", UIParent, "CENTER") end
function Theme:RegisterForEscape() end
function Theme:SetItemTooltip() end

assert(loadfile("MasterLooter/UI/TradeWindow.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/UI/RulesWindow.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/UI/GDKPWindow.lua"))("MasterLooter", GA)
assert(loadfile("MasterLooter/UI/LootLedgerWindow.lua"))("MasterLooter", GA)
local trade, rules, gdkp, lootLedger = GA.UI.TradeWindow, GA.UI.RulesWindow, GA.UI.GDKPWindow, GA.UI.LootLedgerWindow
trade:EnsureFrame(); rules:EnsureFrame(); gdkp:EnsureFrame(); lootLedger:EnsureFrame()

for _, window in ipairs({ trade, rules, gdkp }) do expect(window.frame.toplevel, "administrative window is top-level"); inside(window.resetButton or window.clearButton, window.frame, "reset control stays inside its window") end
horizontal(rules.itemSummary, rules.resetButton, "rules summary does not run underneath reset button")
horizontal(rules.resetButton, rules.refreshButton, "rules reset and refresh buttons are separate")
vertical(rules.hardCheck, rules.manualPlusOne, "English +1 note stays above the loot-rule controls")
expect(rules.manualPlusOne:GetText() == "+1 is added only through the row button in the loot master window", "rules side note is rendered in English")
horizontal(gdkp.playersLabel, gdkp.resetButton, "GDKP player count does not run underneath reset button")
vertical(trade.clearButton, trade.list, "trade reset button does not cover the task list")
for _, row in ipairs(rules.rows) do
    for _, edit in ipairs({ row.softRes, row.priority, row.plusOne, row.boost }) do inside(edit, row, "rules edit box stays inside its row") end
end
for _, edit in ipairs({ gdkp.sessionName, gdkp.itemInput, gdkp.buyerInput, gdkp.amountInput, gdkp.cutPlayerEdit, gdkp.cutWeightEdit }) do inside(edit, gdkp.frame, "GDKP edit box stays visible") end
for _, control in ipairs({ lootLedger.search, lootLedger.filter, lootLedger.stateButton, lootLedger.deleteButton, lootLedger.list }) do inside(control, lootLedger.frame, "loot-ledger control stays visible") end
for _, row in ipairs(lootLedger.rows) do inside(row, lootLedger.list, "loot-ledger row stays inside list") end

print("PASS: " .. assertions .. " administrative-window geometry assertions")
