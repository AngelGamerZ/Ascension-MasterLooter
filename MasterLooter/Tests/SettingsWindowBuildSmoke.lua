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
local registeredOptionsPanel
function InterfaceOptions_AddCategory(panel) registeredOptionsPanel = panel end
local createdNames = {}
function CreateFrame(_, name)
    if name then
        if createdNames[name] then error("duplicate named frame: " .. tostring(name)) end
        createdNames[name] = true
    end
    local frame = widget(name)
    if name then
        _G[name] = frame
        for _, suffix in ipairs({ "Left", "Middle", "Right", "Text", "Button" }) do _G[name .. suffix] = widget(name .. suffix) end
    end
    return frame
end
local dropdownButtons = {}
function UIDropDownMenu_Initialize(dropdown, callback) dropdown.initialize = callback end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) dropdownButtons[#dropdownButtons + 1] = info end
function UIDropDownMenu_SetWidth(dropdown, width, padding)
    -- Exact name/child lookup contract used by FrameXML 3.3.5a.
    local name = dropdown:GetName()
    _G[name .. "Middle"]:SetWidth(width)
    if padding then dropdown:SetWidth(width + padding) else dropdown:SetWidth(width + 50) end
    _G[name .. "Text"]:SetWidth(padding and width or (width - 25))
    dropdown.width, dropdown.padding = width, padding
end
function UIDropDownMenu_SetSelectedValue(dropdown, value) dropdown.selectedValue = value end
function UIDropDownMenu_SetText(dropdown, text) dropdown.text = text end
function CloseDropDownMenus() end

local profile = { minimap = {}, defaultRollDuration = 30, language = "AUTO" }
local selectedChannel, selectedCountdown, selectedLanguage
local GA = {
    VERSION = "build-smoke", UI = {}, modules = {},
    DB = { data = { activeProfile = "Default" }, GetProfile = function() return profile end },
    Announcements = {
        GetConfig = function() return { enabled = true, channel = "AUTO", finalCountdownSeconds = 3 } end,
        GetChannelOptions = function() return { "AUTO", "RAID_WARNING", "RAID", "PARTY", "SAY", "YELL", "GUILD", "OFFICER" } end,
        SetOption = function(_, key, value)
            if key == "channel" then selectedChannel = value elseif key == "finalCountdownSeconds" then selectedCountdown = value end
            return true
        end,
    },
    Localization = {
        GetLanguageMode = function() return profile.language end,
        SetLanguage = function(_, value) profile.language, selectedLanguage = value, value; return true end,
    },
    PackMule = { GetTarget = function() return nil end, GetRules = function() return { minimumQuality = 2 } end },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:Print(message) self.lastPrint = message end
local localizedWelcomeNotes = {
    ["Neuimplementierung für Ascension WoW 3.3.5a"] = "New implementation for Ascension WoW 3.3.5a",
    ["Öffentliche /roll-Auswertung für Spieler mit und ohne Addon"] = "Public /roll tracking for players with and without the addon",
    ["Direktvergabe, Handels-Fallback, Regeln, Strichliste und GDKP"] = "Direct awards, trade fallback, rules, +1 tracking, and GDKP",
    ["Erweiterte Werkzeuge sind jederzeit über den Minimap-Button erreichbar"] = "Advanced tools are always available from the minimap button",
    ["Allgemein"] = "General",
    ["Grundlegendes Verhalten, Sichtbarkeit und aktive Konfiguration."] = "Basic behavior, visibility, and active configuration.",
    ["Rollfenster bei neuer Verteilung automatisch öffnen"] = "Automatically open the roll window for new distributions",
    ["Hinweistöne abspielen"] = "Play notification sounds",
    ["Minimap-Button anzeigen"] = "Show minimap button",
    ["Taschenabfragen durch Gruppenmitglieder erlauben"] = "Allow bag-inspection requests from group members",
    ["Sprache / Language"] = "Language",
    ["Automatisch (Client)"] = "Automatic (client)",
    ["Deutsch"] = "German",
    ["PROFIL"] = "PROFILE",
    ["Aktives Profil"] = "Active profile",
    ["Wechseln"] = "Switch",
    ["Profile verwalten"] = "Manage profiles",
}
function GA:Localize(value) return localizedWelcomeNotes[value] or value end
local semanticEnglish = {
    SETTINGS_LANGUAGE = "Language", SETTINGS_LANGUAGE_AUTO = "Automatic (client)",
    SETTINGS_LANGUAGE_GERMAN = "German", SETTINGS_LANGUAGE_ENGLISH = "English",
    SETTINGS_WINDOW_TITLE = "MasterLooter %s — Settings",
    SETTINGS_OPEN_ERROR = "Settings could not be opened: %s",
    SETTINGS_ANNOUNCEMENT_CHANNEL = "Announcement channel",
    SETTINGS_COMMAND_ANNOUNCEMENTS = "Send the SR and SL command notice when becoming loot master",
    SETTINGS_TRADE_WHISPERS = "Send automatic trade whispers to winners",
    SETTINGS_UPDATE_NOTIFICATIONS = "Show a chat message when a newer MasterLooter version is detected",
    SETTINGS_FINAL_COUNTDOWN = "Final countdown announcements",
    SETTINGS_FINAL_COUNTDOWN_ONE = "Only at 1 second",
    SETTINGS_FINAL_COUNTDOWN_LAST = "Last %d seconds: %s",
    SETTINGS_FINAL_COUNTDOWN_HELP = "Above the selected final countdown, an announcement is still sent every 10 seconds.",
    SETTINGS_FINAL_COUNTDOWN_SAVED = "Final countdown saved.",
    CHANNEL_AUTO = "Automatic",
    CHANNEL_RAID_WARNING = "Raid warning", CHANNEL_RAID = "Raid", CHANNEL_PARTY = "Group",
    CHANNEL_SAY = "Say", CHANNEL_YELL = "Yell", CHANNEL_GUILD = "Guild", CHANNEL_OFFICER = "Officer",
}
function GA:L(key, ...)
    local value = semanticEnglish[key] or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

local colors = {
    panel = { 0, 0, 0, 1 }, panelLight = { 0, 0, 0, 1 }, border = { 1, 1, 1, 1 },
    gold = { 1, 1, 0, 1 }, text = { 1, 1, 1, 1 }, muted = { 0.5, 0.5, 0.5, 1 },
    green = { 0, 1, 0, 1 }, red = { 1, 0, 0, 1 },
}
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:ApplyInset() end
function Theme:CreateLabel(parent, text) local value = parent:CreateFontString(); value:SetText(GA:Localize(text)); return value end
function Theme:CreateButton(_, text) local value = widget(); value:SetText(GA:Localize(text)); return value end
function Theme:CreateEditBox() return widget() end
function Theme:AddTitle(parent, text) local title = Theme:CreateLabel(parent, text); parent.title = title; return title, widget() end
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
same(frame.title:GetText(), "MasterLooter build-smoke — Settings", "dynamic settings title is rendered completely in English")
same(settings.languageDropdown:GetValue(), "AUTO", "language dropdown reflects automatic client selection")
same(settings.channelDropdown:GetValue(), "AUTO", "announcement dropdown reflects the saved channel")
same(settings.countdownDropdown:GetValue(), 3, "final-countdown dropdown reflects the saved range")
same(settings.languageDropdown.padding, 0, "language dropdown supplies legacy SharedXML padding")
same(settings.channelDropdown.padding, 0, "channel dropdown supplies legacy SharedXML padding")
same(settings.countdownDropdown.padding, 0, "final-countdown dropdown supplies legacy SharedXML padding")
same(settings.languageDropdown.options[1].label, "Automatic (client)", "automatic language dropdown value is English")
same(settings.languageDropdown.options[2].label, "German", "German language dropdown value is named in English")
same(settings.languageDropdown.options[3].label, "English", "English language dropdown value is English")
for _, option in ipairs(settings.channelDropdown.options) do
    expect(not string.find(option.label, "Gruppe", 1, true) and not string.find(option.label, "Warnung", 1, true) and
        not string.find(option.label, "Sagen", 1, true) and not string.find(option.label, "Schreien", 1, true),
        "announcement dropdown value is rendered in English: " .. tostring(option.label))
end
same(settings.languageDropdown:GetName(), "MasterLooterSettingsLanguageDropdown", "language dropdown has a stable 3.3.5a template name")
same(settings.channelDropdown:GetName(), "MasterLooterSettingsAnnouncementChannelDropdown", "channel dropdown has a distinct 3.3.5a template name")
same(settings.countdownDropdown:GetName(), "MasterLooterSettingsFinalCountdownDropdown", "final-countdown dropdown has a distinct 3.3.5a template name")
same(#settings.channelDropdown.options, 8, "announcement dropdown exposes all supported channels")
same(#settings.countdownDropdown.options, 10, "final-countdown dropdown exposes ranges 1 through 10")
same(settings.countdownDropdown.options[1].label, "Only at 1 second", "one-second option has a descriptive label")
same(settings.countdownDropdown.options[3].label, "Last 3 seconds: 3, 2, 1", "multi-second option shows its complete sequence")
same(settings.countdownDropdown.text, "Last 3 seconds: 3, 2, 1", "closed dropdown shows the complete saved description")
dropdownButtons = {}; settings.channelDropdown.initialize()
for _, info in ipairs(dropdownButtons) do
    info.func()
    same(selectedChannel, info.value, "each announcement callback persists its own channel: " .. tostring(info.value))
end
dropdownButtons = {}; settings.countdownDropdown.initialize()
for _, info in ipairs(dropdownButtons) do
    info.func()
    same(selectedCountdown, info.value, "each countdown callback persists its own range: " .. tostring(info.value))
end
dropdownButtons = {}; settings.languageDropdown.initialize()
for _, info in ipairs(dropdownButtons) do
    info.func()
    same(selectedLanguage, info.value, "each language callback persists its own mode: " .. tostring(info.value))
end
same(#settings:GetSections(), 5, "all navigation sections survive complete construction")
same(settings.navButtons.GENERAL:GetText(), "General", "General navigation is rendered in English")
same(settings.sectionFrames.GENERAL.heading:GetText(), "General", "General page heading is rendered in English")
same(settings.sectionFrames.GENERAL.description:GetText(), "Basic behavior, visibility, and active configuration.", "General page side note is rendered in English")
same(settings.autoOpen.label:GetText(), "Automatically open the roll window for new distributions", "General auto-open option is rendered in English")
same(settings.sound.label:GetText(), "Play notification sounds", "General sound option is rendered in English")
same(settings.minimap.label:GetText(), "Show minimap button", "General minimap option is rendered in English")
same(settings.bagShare.label:GetText(), "Allow bag-inspection requests from group members", "General bag-sharing option is rendered in English")
same(settings.updateNotifications.label:GetText(), "Show a chat message when a newer MasterLooter version is detected", "update-notification option is rendered in English")
same(settings.updateNotifications:GetChecked(), true, "update notifications are enabled by default")
same(settings.commandAnnounce.label:GetText(), "Send the SR and SL command notice when becoming loot master", "command-announcement option is rendered in English")
same(settings.tradeWhispers.label:GetText(), "Send automatic trade whispers to winners", "trade-whisper option is rendered in English")
same(settings.languageLabel:GetText(), "Language", "General language caption is rendered in English")
same(settings.profileTitle:GetText(), "PROFILE", "General profile section note is rendered in English")
same(settings.profileLabel:GetText(), "Active profile", "General active-profile caption is rendered in English")
same(settings.switchProfileButton:GetText(), "Switch", "General profile switch button is rendered in English")
same(settings.manageProfilesButton:GetText(), "Manage profiles", "General profile manager button is rendered in English")
expect(settings:Show("LOOT"), "settings can open a requested section")
same(settings.activeSection, "LOOT", "requested section becomes active")
settings:RegisterInterfaceOptions()
expect(registeredOptionsPanel == settings.optionsPanel, "MasterLooter registers its own Interface/AddOns category")
expect(not settings.optionsPanel:IsShown(), "Interface/AddOns panel stays hidden until MasterLooter is selected")
settings.optionsPanel:Show()
expect(settings.optionsPanel:IsShown(), "Interface controller can show the selected MasterLooter category")
local childFrame = widget("ChildTool"); childFrame:Hide()
GA.UI.RulesWindow = { frame = childFrame, Show = function(self) self.frame:Show(); return true end }
settings.frame:Show()
expect(settings:OpenTool("RulesWindow"), "settings launcher opens a standalone tool")
expect(childFrame.shown and childFrame.raised and childFrame.toplevel, "standalone tool is explicitly raised to top level")
expect(not settings.frame.shown, "settings launcher closes instead of covering the opened tool")

-- A client must be able to recover in-session from a partially constructed
-- window without colliding with the named legacy template children.
settings.buildComplete = false
local realSetWidth = UIDropDownMenu_SetWidth
UIDropDownMenu_SetWidth = function() error("simulated legacy SharedXML failure") end
local failedFrame, expectedBuildError = settings:EnsureFrame()
expect(failedFrame == nil and string.find(expectedBuildError or "", "simulated legacy SharedXML failure", 1, true), "settings contains a real mid-build SharedXML exception")
expect(settings.frame == nil and not settings.buildComplete, "failed partial frame is detached from the controller")
UIDropDownMenu_SetWidth = realSetWidth
local recoveredFrame, recoveryError = settings:EnsureFrame()
expect(recoveredFrame ~= nil, recoveryError or "an incomplete settings build recovers")
same(settings.buildGeneration, 3, "settings recovery advances past the failed frame generation")
same(settings.languageDropdown:GetName(), "MasterLooterSettingsLanguageDropdown3", "recovered legacy dropdown receives a collision-free name")
expect(settings:ControlsReady(), "recovered settings build recreates every required control")

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
same(#GA.UI.WelcomeWindow.noteLabels, 4, "welcome window renders every feature note")
same(GA.UI.WelcomeWindow.noteLabels[1]:GetText(), "• New implementation for Ascension WoW 3.3.5a", "welcome feature notes are localized before bullet formatting")
same(GA.UI.WelcomeWindow.noteLabels[2]:GetText(), "• Public /roll tracking for players with and without the addon", "public roll feature note is rendered in English")
same(GA.UI.WelcomeWindow.noteLabels[3]:GetText(), "• Direct awards, trade fallback, rules, +1 tracking, and GDKP", "award feature note is rendered in English")
same(GA.UI.WelcomeWindow.noteLabels[4]:GetText(), "• Advanced tools are always available from the minimap button", "minimap feature note is rendered in English")

print(string.format("PASS: %d settings-window build assertions", assertions))
