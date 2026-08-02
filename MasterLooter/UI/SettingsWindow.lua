local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme

local SettingsWindow = {}
GA.UI.SettingsWindow = SettingsWindow

local function profile()
    return GA.DB:GetProfile()
end

function SettingsWindow:CreateCheckBox(parent, labelText, y, key)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, y)
    local label = Theme:CreateLabel(parent, labelText, 12)
    label:SetPoint("LEFT", check, "RIGHT", 5, 1)
    check.label = label
    check:SetScript("OnClick", function(self)
        profile()[key] = self:GetChecked() and true or false
        SettingsWindow:SetStatus("Einstellung gespeichert.", Theme.colors.green)
    end)
    return check
end

function SettingsWindow:CreateMinimapCheckBox(parent, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 25, y)
    local label = Theme:CreateLabel(parent, "Minimap-Button anzeigen", 12)
    label:SetPoint("LEFT", check, "RIGHT", 5, 1)
    check.label = label
    check:SetScript("OnClick", function(self)
        local current = profile()
        current.minimap = current.minimap or {}
        current.minimap.hide = not (self:GetChecked() and true or false)
        if GA.UI.Launcher and type(GA.UI.Launcher.Refresh) == "function" then GA.UI.Launcher:Refresh() end
        SettingsWindow:SetStatus("Einstellung gespeichert.", Theme.colors.green)
    end)
    return check
end

function SettingsWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterSettingsWindow", UIParent)
    frame:SetWidth(455)
    frame:SetHeight(480)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "MasterLooter – Einstellungen")
    Theme:MakeMovable(frame, "settingsWindow")
    Theme:RestorePosition(frame, "settingsWindow", "CENTER", 0, 20)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local section = Theme:CreateLabel(frame, "Roll- und Vergabeverhalten", 14, Theme.colors.gold)
    section:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -48)

    self.autoOpen = self:CreateCheckBox(frame, "Rollfenster bei neuer Verteilung automatisch öffnen", -77, "autoOpenRollWindow")
    self.autoGive = self:CreateCheckBox(frame, "Gewinner automatisch über Masterloot beliefern", -108, "autoGiveAwards")
    self.sound = self:CreateCheckBox(frame, "Hinweistöne abspielen", -139, "sound")
    self.minimap = self:CreateMinimapCheckBox(frame, -170)

    local durationLabel = Theme:CreateLabel(frame, "Standarddauer einer Verteilung", 12)
    durationLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -212)
    local duration = Theme:CreateEditBox(frame, 55, 24, true)
    duration:SetPoint("TOPLEFT", frame, "TOPLEFT", 269, -205)
    self.durationEdit = duration
    local seconds = Theme:CreateLabel(frame, "Sekunden", 12, Theme.colors.muted)
    seconds:SetPoint("LEFT", duration, "RIGHT", 8, 0)

    local osLabel = Theme:CreateLabel(frame, "OS-Wurfmaximum (/roll X)", 12)
    osLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -247)
    local osMaximum = Theme:CreateEditBox(frame, 55, 24, true)
    osMaximum:SetPoint("TOPLEFT", frame, "TOPLEFT", 269, -240)
    if type(osMaximum.SetMaxLetters) == "function" then osMaximum:SetMaxLetters(2) end
    self.osMaximumEdit = osMaximum
    local osHint = Theme:CreateLabel(frame, "2–99 (MS bleibt 100)", 11, Theme.colors.muted)
    osHint:SetPoint("LEFT", osMaximum, "RIGHT", 8, 0)

    local save = Theme:CreateButton(frame, "Speichern", 100, 25)
    save:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -278)
    save:SetScript("OnClick", function() SettingsWindow:SaveDuration() end)

    local links = Theme:CreateLabel(frame, "Fenster", 14, Theme.colors.gold)
    links:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -321)
    local master = Theme:CreateButton(frame, "Lootmaster", 125, 27)
    master:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -348)
    master:SetScript("OnClick", function()
        if GA.UI.MasterLooterWindow then GA.UI.MasterLooterWindow:Show() end
    end)
    local history = Theme:CreateButton(frame, "Historie", 125, 27)
    history:SetPoint("LEFT", master, "RIGHT", 10, 0)
    history:SetScript("OnClick", function()
        if GA.UI.HistoryWindow then GA.UI.HistoryWindow:Show() end
    end)
    local auction = Theme:CreateButton(frame, "GDKP-Auktion", 125, 27)
    auction:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -378)
    auction:SetScript("OnClick", function()
        if GA.UI.GDKPAuctionWindow then GA.UI.GDKPAuctionWindow:Show() end
    end)
    local raid = Theme:CreateButton(frame, "Raidverwaltung", 125, 27)
    raid:SetPoint("LEFT", auction, "RIGHT", 10, 0)
    raid:SetScript("OnClick", function()
        if GA.UI.RaidManagerWindow then GA.UI.RaidManagerWindow:Show() end
    end)
    local versions = Theme:CreateButton(frame, "Versionscheck", 125, 27)
    versions:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -408)
    versions:SetScript("OnClick", function()
        if GA.UI.VersionWindow then GA.UI.VersionWindow:Show() end
    end)
    local bags = Theme:CreateButton(frame, "Tascheninspektor", 125, 27)
    bags:SetPoint("LEFT", versions, "RIGHT", 10, 0)
    bags:SetScript("OnClick", function()
        if GA.UI.BagInspectorWindow then GA.UI.BagInspectorWindow:Show() end
    end)

    local status = Theme:CreateLabel(frame, "", 12, Theme.colors.muted)
    status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 29, 18)
    status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    status:SetJustifyH("RIGHT")
    self.status = status
    return frame
end

function SettingsWindow:SetStatus(text, color)
    if not self.status then return end
    self.status:SetText(text or "")
    self.status:SetTextColor(unpack(color or Theme.colors.muted))
end

function SettingsWindow:SaveDuration()
    local duration = tonumber(self.durationEdit:GetText())
    if not duration then
        self:SetStatus("Bitte eine gültige Dauer eingeben.", Theme.colors.red)
        return
    end
    local osMaximum = tonumber(self.osMaximumEdit and self.osMaximumEdit:GetText())
    if not osMaximum or osMaximum ~= math.floor(osMaximum) or osMaximum < 2 or osMaximum > 99 then
        self:SetStatus("Das OS-Wurfmaximum muss zwischen 2 und 99 liegen.", Theme.colors.red)
        return
    end
    duration = math.max(5, math.min(600, math.floor(duration)))
    profile().defaultRollDuration = duration
    profile().osRollMaximum = osMaximum
    self.durationEdit:SetText(tostring(duration))
    self:SetStatus("Standarddauer gespeichert.", Theme.colors.green)
end

function SettingsWindow:Refresh()
    if not self:EnsureFrame() then return end
    local current = profile()
    self.autoOpen:SetChecked(current.autoOpenRollWindow ~= false)
    self.autoGive:SetChecked(current.autoGiveAwards ~= false)
    self.sound:SetChecked(current.sound ~= false)
    current.minimap = current.minimap or {}
    self.minimap:SetChecked(current.minimap.hide ~= true)
    self.durationEdit:SetText(tostring(tonumber(current.defaultRollDuration) or 30))
    self.osMaximumEdit:SetText(tostring(tonumber(current.osRollMaximum) or 99))
end

function SettingsWindow:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self:Refresh()
    self:SetStatus("")
    frame:Show()
end

function SettingsWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function SettingsWindow:Toggle()
    local frame = self:EnsureFrame()
    if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end

function SettingsWindow:OnInitialize()
    self:EnsureFrame()
    return true
end

GA:RegisterModule("SettingsWindow", SettingsWindow)
