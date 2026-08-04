-- Executes the complete settings-frame construction against a small 3.3.5a UI
-- surface. This catches missing legacy Lua functions before an in-game build.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local function widget(name)
    local object = { name = name, shown = true, text = "" }
    local noOp = function() end
    for _, method in ipairs({
        "SetWidth", "SetHeight", "SetFrameStrata", "SetToplevel", "SetClampedToScreen", "SetBackdrop",
        "SetBackdropColor", "SetBackdropBorderColor", "SetPoint", "SetAllPoints", "SetJustifyH", "SetTextColor",
        "SetAutoFocus", "SetTextInsets", "SetNumeric", "SetMovable", "EnableMouse", "RegisterForDrag",
        "RegisterForClicks", "SetScale", "ClearAllPoints", "SetHighlightTexture", "SetTexture", "SetTexCoord",
    }) do object[method] = noOp end
    function object:GetName() return self.name end
    function object:SetToplevel(value) self.toplevel = value end
    function object:Raise() self.raised = true end
    function object:SetScript(event, callback) self[event] = callback end
    function object:CreateFontString() return widget() end
    function object:CreateTexture() return widget() end
    function object:SetText(value) self.text = tostring(value or "") end
    function object:GetText() return self.text end
    function object:SetChecked(value) self.checked = value end
    function object:GetChecked() return self.checked end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:IsShown() return self.shown end
    function object:Enable() self.enabled = true end
    function object:Disable() self.enabled = false end
    return object
end

UIParent = widget("UIParent")
UISpecialFrames = {}
unpack = unpack or table.unpack
InterfaceOptionsFramePanelContainer = widget("InterfaceOptionsFramePanelContainer")
function InterfaceOptions_AddCategory() end
function CreateFrame(_, name) return widget(name) end

local profile = { minimap = {}, defaultRollDuration = 30 }
local GA = {
    VERSION = "build-smoke", UI = {}, modules = {},
    DB = { data = { activeProfile = "Default" }, GetProfile = function() return profile end },
    Announcements = { GetConfig = function() return { enabled = true, channel = "AUTO" } end },
    PackMule = { GetTarget = function() return nil end, GetRules = function() return { minimumQuality = 2 } end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:Print(message) self.lastPrint = message end

local colors = {
    panel = { 0, 0, 0, 1 }, panelLight = { 0, 0, 0, 1 }, border = { 1, 1, 1, 1 },
    gold = { 1, 1, 0, 1 }, text = { 1, 1, 1, 1 }, muted = { 0.5, 0.5, 0.5, 1 },
    green = { 0, 1, 0, 1 }, red = { 1, 0, 0, 1 },
}
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:ApplyInset() end
function Theme:CreateLabel(parent, text) local value = parent:CreateFontString(); value:SetText(text); return value end
function Theme:CreateButton(_, text) local value = widget(); value:SetText(text); return value end
function Theme:CreateEditBox() return widget() end
function Theme:AddTitle() end
function Theme:MakeMovable() end
function Theme:RestorePosition() end
function Theme:RegisterForEscape() end

local chunk, loadError = loadfile("MasterLooter/UI/SettingsWindow.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)

local settings = GA.UI.SettingsWindow
local frame, buildError = settings:EnsureFrame()
expect(frame ~= nil, buildError or "complete settings frame builds")
expect(settings:ControlsReady(), "all controls required by Refresh exist")
expect(settings.buildComplete, "settings construction is marked complete")
expect(settings:Refresh(), "a complete settings frame refreshes safely")
same(#settings:GetSections(), 5, "all navigation sections survive complete construction")
expect(settings:Show("LOOT"), "settings can open a requested section")
same(settings.activeSection, "LOOT", "requested section becomes active")
local childFrame = widget("ChildTool"); childFrame:Hide()
GA.UI.RulesWindow = { frame = childFrame, Show = function(self) self.frame:Show(); return true end }
settings.frame:Show()
expect(settings:OpenTool("RulesWindow"), "settings launcher opens a standalone tool")
expect(childFrame.shown and childFrame.raised and childFrame.toplevel, "standalone tool is explicitly raised to top level")
expect(not settings.frame.shown, "settings launcher closes instead of covering the opened tool")

GA.Events = { On = function() end }
GA.Profiles = {
    List = function() return { "Default", "Raid" } end,
    GetActive = function() return "Default" end,
}
GA.ItemData = {
    Search = function() return { { itemID = 1, name = "Test", link = "|Hitem:1|h[Test]|h", quality = 3 } } end,
    GetStats = function() return { items = 1, verified = 1 } end,
}
Theme.ShowItemTooltip = function() end
Theme.HideOwnedTooltip = function() end
for _, path in ipairs({
    "MasterLooter/UI/ProfileWindow.lua",
    "MasterLooter/UI/ItemSearchWindow.lua",
    "MasterLooter/UI/WelcomeWindow.lua",
}) do
    local toolChunk, toolError = loadfile(path)
    if not toolChunk then error(toolError) end
    toolChunk("MasterLooter", GA)
end
expect(GA.UI.ProfileWindow:EnsureFrame() ~= nil, "profile manager builds against legacy UI")
expect(#GA.UI.ProfileWindow.rows == 8, "profile manager renders its full visible page")
expect(GA.UI.ItemSearchWindow:EnsureFrame() ~= nil, "item search builds against legacy UI")
GA.UI.ItemSearchWindow:Search()
expect(GA.UI.ItemSearchWindow.rows[1].shown, "item search renders provider results")
expect(GA.UI.WelcomeWindow:EnsureFrame() ~= nil, "welcome window builds against legacy UI")

print(string.format("PASS: %d settings-window build assertions", assertions))
