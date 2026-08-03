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
    frame:SetHeight(610)
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

    self.announce = self:CreateCheckBox(frame, "Ansagen in Gruppe/Raid aktivieren", -201, "_announcementEnabled")
    self.announce:SetScript("OnClick", function(self)
        if GA.Announcements then GA.Announcements:SetOption("enabled", self:GetChecked() and true or false) end
        SettingsWindow:SetStatus("Ansageeinstellung gespeichert.", Theme.colors.green)
    end)
    self.bagShare = self:CreateCheckBox(frame, "Taschenabfragen durch Gruppenmitglieder erlauben", -232, "bagInspectorShare")
    self.bagShare:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        if GA.BagInspector and type(GA.BagInspector.SetSharing) == "function" then GA.BagInspector:SetSharing(enabled) else profile().bagInspectorShare = enabled end
        SettingsWindow:SetStatus("Taschenfreigabe gespeichert.", Theme.colors.green)
    end)
    local channelLabel = Theme:CreateLabel(frame, "Ansagekanal", 11, Theme.colors.gold); channelLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 295, -205)
    self.channelEdit = Theme:CreateEditBox(frame, 90, 22); self.channelEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 295, -222)
    local channelSave = Theme:CreateButton(frame, "Setzen", 62, 22); channelSave:SetPoint("LEFT", self.channelEdit, "RIGHT", 5, 0); channelSave:SetScript("OnClick", function()
        local ok, err = GA.Announcements:SetOption("channel", SettingsWindow.channelEdit:GetText())
        SettingsWindow:SetStatus(ok and "Ansagekanal gespeichert." or tostring(err), ok and Theme.colors.green or Theme.colors.red)
    end)

    local durationLabel = Theme:CreateLabel(frame, "Standarddauer einer Verteilung", 12)
    durationLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -270)
    local duration = Theme:CreateEditBox(frame, 55, 24, true)
    duration:SetPoint("TOPLEFT", frame, "TOPLEFT", 269, -263)
    self.durationEdit = duration
    local seconds = Theme:CreateLabel(frame, "Sekunden", 12, Theme.colors.muted)
    seconds:SetPoint("LEFT", duration, "RIGHT", 8, 0)

    local save = Theme:CreateButton(frame, "Speichern", 100, 25)
    save:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -296)
    save:SetScript("OnClick", function() SettingsWindow:SaveDuration() end)

    local links = Theme:CreateLabel(frame, "Fenster", 14, Theme.colors.gold)
    local scaleLabel = Theme:CreateLabel(frame, "UI-Skalierung (0.70-1.50)", 12)
    scaleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 155, -302)
    self.scaleEdit = Theme:CreateEditBox(frame, 55, 24)
    self.scaleEdit:SetPoint("LEFT", scaleLabel, "RIGHT", 8, 0)
    local applyScale = Theme:CreateButton(frame, "Anwenden", 82, 24)
    applyScale:SetPoint("LEFT", self.scaleEdit, "RIGHT", 7, 0)
    applyScale:SetScript("OnClick", function() SettingsWindow:ApplyScale() end)

    local profileLabel = Theme:CreateLabel(frame, "Profil", 12, Theme.colors.gold)
    profileLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -340)
    self.profileEdit = Theme:CreateEditBox(frame, 160, 24)
    self.profileEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 80, -333)
    local switchProfile = Theme:CreateButton(frame, "Wechseln", 90, 24)
    switchProfile:SetPoint("LEFT", self.profileEdit, "RIGHT", 8, 0)
    switchProfile:SetScript("OnClick", function() SettingsWindow:SwitchProfile() end)
    local resetPositions = Theme:CreateButton(frame, "Positionen zurücksetzen", 150, 24)
    resetPositions:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -365)
    resetPositions:SetScript("OnClick", function() SettingsWindow:ResetPositions() end)

    links:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -400)
    local master = Theme:CreateButton(frame, "Lootmaster", 125, 27)
    master:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -427)
    master:SetScript("OnClick", function()
        if GA.UI.MasterLooterWindow then GA.UI.MasterLooterWindow:Show() end
    end)
    local history = Theme:CreateButton(frame, "Historie", 125, 27)
    history:SetPoint("LEFT", master, "RIGHT", 10, 0)
    history:SetScript("OnClick", function()
        if GA.UI.HistoryWindow then GA.UI.HistoryWindow:Show() end
    end)
    local auction = Theme:CreateButton(frame, "GDKP-Auktion", 125, 27)
    auction:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -457)
    auction:SetScript("OnClick", function()
        if GA.UI.GDKPAuctionWindow then GA.UI.GDKPAuctionWindow:Show() end
    end)
    local raid = Theme:CreateButton(frame, "Raidverwaltung", 125, 27)
    raid:SetPoint("LEFT", auction, "RIGHT", 10, 0)
    raid:SetScript("OnClick", function()
        if GA.UI.RaidManagerWindow then GA.UI.RaidManagerWindow:Show() end
    end)
    local versions = Theme:CreateButton(frame, "Versionscheck", 125, 27)
    versions:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -487)
    versions:SetScript("OnClick", function()
        if GA.UI.VersionWindow then GA.UI.VersionWindow:Show() end
    end)
    local bags = Theme:CreateButton(frame, "Tascheninspektor", 125, 27)
    bags:SetPoint("LEFT", versions, "RIGHT", 10, 0)
    bags:SetScript("OnClick", function()
        if GA.UI.BagInspectorWindow then GA.UI.BagInspectorWindow:Show() end
    end)

    local muleLabel = Theme:CreateLabel(frame, "PackMule: Ziel / Mindestqualität", 11, Theme.colors.gold); muleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -527)
    self.muleTargetEdit = Theme:CreateEditBox(frame, 150, 22); self.muleTargetEdit:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -545)
    self.muleQualityEdit = Theme:CreateEditBox(frame, 45, 22, true); self.muleQualityEdit:SetPoint("LEFT", self.muleTargetEdit, "RIGHT", 7, 0)
    local muleSave = Theme:CreateButton(frame, "Regeln aktivieren", 130, 22); muleSave:SetPoint("LEFT", self.muleQualityEdit, "RIGHT", 7, 0); muleSave:SetScript("OnClick", function() SettingsWindow:SavePackMule() end)

    local status = Theme:CreateLabel(frame, "", 12, Theme.colors.muted)
    status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 29, 18)
    status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    status:SetJustifyH("RIGHT")
    self.status = status
    return frame
end

function SettingsWindow:SavePackMule()
    if not GA.PackMule then self:SetStatus("PackMule nicht verfügbar.", Theme.colors.red); return end
    local target, quality = self.muleTargetEdit:GetText(), tonumber(self.muleQualityEdit:GetText())
    local ok, err = GA.PackMule:SetTarget(target)
    if ok then ok, err = GA.PackMule:SetRules({ enabled = true, minimumQuality = quality }) end
    self:SetStatus(ok and "PackMule-Regeln gespeichert." or tostring(err), ok and Theme.colors.green or Theme.colors.red)
end

function SettingsWindow:ApplyScale()
    local value = tonumber(self.scaleEdit:GetText())
    if not value or value < 0.7 or value > 1.5 then self:SetStatus("Skalierung muss zwischen 0.70 und 1.50 liegen.", Theme.colors.red); return end
    profile().uiScale = value
    for _, controller in pairs(GA.UI or {}) do
        if type(controller) == "table" and controller.frame and type(controller.frame.SetScale) == "function" then controller.frame:SetScale(value) end
    end
    self:SetStatus("UI-Skalierung angewendet.", Theme.colors.green)
end

function SettingsWindow:SwitchProfile()
    local name = string.match(tostring(self.profileEdit:GetText() or ""), "^%s*(.-)%s*$")
    if name == "" or #name > 40 or string.find(name, "[%c]") then self:SetStatus("Ungültiger Profilname.", Theme.colors.red); return end
    GA.DB:SetProfile(name); self:Refresh(); self:SetStatus("Profil gewechselt. /reload für alle Fenster empfohlen.", Theme.colors.green)
end

function SettingsWindow:ResetPositions()
    local current = profile()
    for key, value in pairs(current) do
        if type(value) == "table" and (string.find(string.lower(key), "window") or value.point) then
            value.point, value.relativePoint, value.x, value.y = nil, nil, nil, nil
        end
    end
    self:SetStatus("Gespeicherte Fensterpositionen zurückgesetzt. /reload anwenden.", Theme.colors.green)
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
    duration = math.max(5, math.min(600, math.floor(duration)))
    profile().defaultRollDuration = duration
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
    local config = GA.Announcements and GA.Announcements:GetConfig() or current.announcements or {}
    self.announce:SetChecked(config.enabled ~= false)
    self.bagShare:SetChecked(current.bagInspectorShare ~= false)
    self.channelEdit:SetText(tostring(config.channel or "AUTO"))
    self.durationEdit:SetText(tostring(tonumber(current.defaultRollDuration) or 30))
    self.scaleEdit:SetText(string.format("%.2f", tonumber(current.uiScale) or 1))
    self.profileEdit:SetText(tostring(GA.DB.data.activeProfile or "Default"))
    if GA.PackMule then
        self.muleTargetEdit:SetText(tostring(GA.PackMule:GetTarget() or ""))
        self.muleQualityEdit:SetText(tostring((GA.PackMule:GetRules() or {}).minimumQuality or 2))
    end
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
