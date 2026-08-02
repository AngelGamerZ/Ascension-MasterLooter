local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local Launcher = {}
GA.UI.Launcher = Launcher

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
            window:Show()
            if self.menu then self.menu:Hide() end
            return true
        end
    end
    GA:Print("Dieses Fenster ist noch nicht verfügbar.")
    return false
end

function Launcher:EnsureMenu()
    if self.menu then return self.menu end
    local menu = CreateFrame("Frame", "MasterLooterLauncherMenu", UIParent)
    menu:SetWidth(304); menu:SetHeight(190); menu:SetFrameStrata("DIALOG"); menu:SetFrameLevel(100); menu:Hide()
    menu:SetClampedToScreen(true)
    Theme:ApplyPanel(menu); Theme:AddTitle(menu, "MasterLooter")
    self.menu = menu
    local entries = {
        { "Loot", { "LootWindow" } }, { "SoftRes", { "SoftResWindow" } },
        { "Regeln", { "RulesWindow", "PriorityWindow" } }, { "GDKP", { "GDKPWindow" } },
        { "GDKP-Auktion", { "GDKPAuctionWindow" } }, { "Handel", { "TradeWindow" } },
        { "Raidverwaltung", { "RaidManagerWindow" } }, { "Tascheninspektor", { "BagInspectorWindow" } },
        { "Historie", { "HistoryWindow" } }, { "Versionscheck", { "VersionWindow" } },
        { "Einstellungen", { "SettingsWindow" } }, { "Import / Export", { "ImportExportWindow" } },
    }
    for index, entry in ipairs(entries) do
        local button = Theme:CreateButton(menu, entry[1], 132, 23)
        local column = math.mod(index - 1, 2)
        local row = math.floor((index - 1) / 2)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 18 + (column * 136), -34 - (row * 25))
        button:SetScript("OnClick", function() Launcher:OpenWindow(entry[2]) end)
    end
    return menu
end

function Launcher:ToggleMenu()
    local menu = self:EnsureMenu()
    if menu:IsShown() then menu:Hide(); return end
    menu:ClearAllPoints()
    local centerX, centerY = self.button:GetCenter()
    local onLeft = centerX and centerX < (UIParent:GetWidth() / 2)
    local onTop = centerY and centerY > (UIParent:GetHeight() / 2)
    if onLeft and onTop then
        menu:SetPoint("TOPLEFT", self.button, "BOTTOMRIGHT", 2, -2)
    elseif onLeft then
        menu:SetPoint("BOTTOMLEFT", self.button, "TOPRIGHT", 2, 2)
    elseif onTop then
        menu:SetPoint("TOPRIGHT", self.button, "BOTTOMLEFT", -2, -2)
    else
        menu:SetPoint("BOTTOMRIGHT", self.button, "TOPLEFT", -2, 2)
    end
    menu:Show()
end

function Launcher:EnsureButton()
    if self.button then return self.button end
    local button = CreateFrame("Button", "MasterLooterMinimapButton", Minimap)
    button:SetWidth(32); button:SetHeight(32); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "BACKGROUND"); icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY"); border:SetWidth(54); border:SetHeight(54); border:SetPoint("TOPLEFT", button, "TOPLEFT", -11, 11)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then Launcher:ToggleMenu() else Launcher:OpenWindow("MasterLooterWindow") end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("MasterLooter", 1, 0.82, 0.2)
        GameTooltip:AddLine("Linksklick: Lootmaster", 1, 1, 1); GameTooltip:AddLine("Rechtsklick: Menü", 1, 1, 1); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
