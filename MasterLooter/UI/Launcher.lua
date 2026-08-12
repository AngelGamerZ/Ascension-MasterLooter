local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local Launcher = {}
GA.UI.Launcher = Launcher

local FALLBACK = {
    ["command.feature_unavailable"] = "This window is not available yet.",
    ["launcher.left"] = "Left-click: Overview & settings",
    ["launcher.right"] = "Right-click: Import / Export",
    ["launcher.middle"] = "Middle-click: History",
    ["launcher.shift_left"] = "Shift + left-click: SoftRes",
    ["launcher.shift_right"] = "Shift + right-click: Loot master",
    ["binding.settings"] = "Open settings",
    ["binding.lootmaster"] = "Open loot master",
    ["binding.history"] = "Open history",
    ["binding.trade"] = "Open trade assistant",
}

-- The minimap button may be skinned or queried while addon initialization is
-- still settling. Never require the convenience GA:L method to exist here;
-- use the localization service directly when available and English otherwise.
local function L(key)
    if type(GA.L) == "function" then
        local ok, value = pcall(GA.L, GA, key)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    local service = GA.Localization or GA.Locale
    if type(service) == "table" and type(service.Get) == "function" then
        local ok, value = pcall(service.Get, service, key)
        if ok and type(value) == "string" and value ~= "" and value ~= key then return value end
    end
    return FALLBACK[key] or tostring(key or "")
end

Launcher.ACTIONS = {
    CLICK = "SettingsWindow",
    RIGHTCLICK = "ImportExportWindow",
    MIDDLECLICK = "HistoryWindow",
    SHIFT_CLICK = "SoftResWindow",
    SHIFT_RIGHTCLICK = "MasterLooterWindow",
}

local function minimapSettings()
    local profile = GA.DB:GetProfile()
    profile.minimap = profile.minimap or { hide = false, angle = 220 }
    return profile.minimap
end

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    return y >= 0 and (math.pi / 2) or (-math.pi / 2)
end

function Launcher:UpdatePosition(angle)
    if not self.button then return end
    local settings = minimapSettings()
    settings.angle = tonumber(angle) or tonumber(settings.angle) or 220
    local radians = math.rad(settings.angle)
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * 80, math.sin(radians) * 80)
end

function Launcher:OpenWindow(names)
    if type(names) == "string" then names = { names } end
    for _, name in ipairs(names or {}) do
        local window = GA.UI[name]
        if window and type(window.Show) == "function" then
            local ok, result = pcall(window.Show, window)
            if ok and result ~= false then return true end
            if GA.ReportError then GA.ReportError("Launcher.OpenWindow." .. tostring(name), ok and "Window reported an open failure." or result) end
        end
    end
    if type(GA.Print) == "function" then GA:Print(L("command.feature_unavailable")) end
    return false
end

function Launcher:GetClickAction(mouseButton, shiftDown)
    if shiftDown and mouseButton == "RightButton" then return self.ACTIONS.SHIFT_RIGHTCLICK end
    if shiftDown and mouseButton == "LeftButton" then return self.ACTIONS.SHIFT_CLICK end
    if mouseButton == "RightButton" then return self.ACTIONS.RIGHTCLICK end
    if mouseButton == "MiddleButton" then return self.ACTIONS.MIDDLECLICK end
    return self.ACTIONS.CLICK
end

function Launcher:HandleClick(mouseButton, shiftDown)
    return self:OpenWindow(self:GetClickAction(mouseButton, shiftDown))
end

function Launcher:ShowTooltip(owner)
    if not Theme or type(Theme.ShowTextTooltip) ~= "function" then return false end
    return Theme:ShowTextTooltip(owner, {
        { "MasterLooter", 1, 0.82, 0.2 },
        L("launcher.left"),
        L("launcher.right"),
        L("launcher.middle"),
        L("launcher.shift_left"),
        L("launcher.shift_right"),
    }, "ANCHOR_LEFT")
end

function Launcher:EnsureButton()
    if self.button then return self.button end
    local button = CreateFrame("Button", "MasterLooterMinimapButton", Minimap)
    button:SetWidth(32); button:SetHeight(32); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp"); button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "BACKGROUND"); icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY"); border:SetWidth(54); border:SetHeight(54); border:SetPoint("TOPLEFT", button, "TOPLEFT", -11, 11)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton)
        Launcher:HandleClick(mouseButton, type(IsShiftKeyDown) == "function" and IsShiftKeyDown())
    end)
    button:SetScript("OnEnter", function(self) Launcher:ShowTooltip(self) end)
    button:SetScript("OnLeave", function(self) if GA.UI.Theme then GA.UI.Theme:HideOwnedTooltip(self) end end)
    button:SetScript("OnDragStart", function(self) self.dragging = true; self:SetScript("OnUpdate", function() Launcher:OnDrag() end) end)
    button:SetScript("OnDragStop", function(self) self.dragging = nil; self:SetScript("OnUpdate", nil) end)
    self.button = button; self:UpdatePosition()
    return button
end

function Launcher:OnDrag()
    local scale = Minimap:GetEffectiveScale(); local cursorX, cursorY = GetCursorPosition(); cursorX, cursorY = cursorX / scale, cursorY / scale
    local centerX, centerY = Minimap:GetCenter(); self:UpdatePosition(math.deg(atan2(cursorY - centerY, cursorX - centerX)))
end

function Launcher:Refresh()
    local button = self:EnsureButton()
    self:UpdatePosition()
    if minimapSettings().hide then button:Hide() else button:Show() end
end

function Launcher:SetHidden(hidden)
    minimapSettings().hide = hidden and true or false
    self:Refresh()
end

function Launcher:OnInitialize() self:EnsureButton(); self:Refresh(); return true end
GA:RegisterModule("Launcher", Launcher)

BINDING_HEADER_MASTERLOOTER = "MasterLooter"
BINDING_NAME_MASTERLOOTER_SETTINGS = L("binding.settings")
BINDING_NAME_MASTERLOOTER_LOOTMASTER = L("binding.lootmaster")
BINDING_NAME_MASTERLOOTER_HISTORY = L("binding.history")
BINDING_NAME_MASTERLOOTER_TRADE = L("binding.trade")
function MasterLooter_ToggleSettings() if GA.UI.SettingsWindow then GA.UI.SettingsWindow:Toggle() end end
function MasterLooter_ToggleLootmaster() if GA.UI.MasterLooterWindow then GA.UI.MasterLooterWindow:Toggle() end end
function MasterLooter_ToggleHistory() if GA.UI.HistoryWindow then GA.UI.HistoryWindow:Toggle() end end
function MasterLooter_ToggleTrade() if GA.UI.TradeWindow then GA.UI.TradeWindow:Toggle() end end
