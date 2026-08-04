-- Verifies the Ascension-safe edit-box implementation without relying on the
-- client-specific InputBoxTemplate draw order.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "different") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

unpack = unpack or table.unpack
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
ChatFontNormal = {}
UISpecialFrames = {}

local created = {}
local function widget(kind, template)
    local object = { kind = kind, template = template, scripts = {} }
    function object:SetWidth(value) self.width = value end
    function object:SetHeight(value) self.height = value end
    function object:SetBackdrop(value) self.backdrop = value end
    function object:SetBackdropColor() end
    function object:SetBackdropBorderColor() end
    function object:SetAutoFocus(value) self.autoFocus = value end
    function object:SetTextInsets(left, right, top, bottom) self.insets = { left, right, top, bottom } end
    function object:SetScript(event, callback) self.scripts[event] = callback end
    function object:SetNumeric(value) self.numeric = value end
    function object:SetFontObject(value) self.fontObject = value end
    function object:SetFont(...) self.font = { ... } end
    function object:SetTextColor(...) self.textColor = { ... } end
    function object:ClearFocus() self.focusCleared = true end
    return object
end

function CreateFrame(kind, _, _, template)
    local object = widget(kind, template)
    created[#created + 1] = object
    return object
end

local GA = { UI = {}, RegisterModule = function() end }
assert(loadfile("MasterLooter/UI/Theme.lua"))("MasterLooter", GA)
local edit = GA.UI.Theme:CreateEditBox(widget("Frame"), 180, 24, true)
same(edit.template, nil, "edit box does not use the broken Ascension InputBoxTemplate")
expect(edit.backdrop ~= nil, "edit box draws its own inset background")
same(edit.width, 180, "edit box keeps requested width")
same(edit.height, 24, "edit box keeps requested height")
same(edit.insets[1], 7, "edit text starts inside the custom border")
same(edit.insets[2], 7, "edit text ends inside the custom border")
same(edit.fontObject, ChatFontNormal, "edit box receives an explicit readable font")
expect(edit.textColor ~= nil, "edit text receives an explicit visible color")
expect(edit.numeric, "numeric edit boxes remain numeric")

print("PASS: " .. assertions .. " Ascension edit-box assertions")
