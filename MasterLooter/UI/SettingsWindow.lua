local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme

local SettingsWindow = {
    WIDTH = 800, HEIGHT = 600, DEFAULT_SECTION = "HOME",
    SECTIONS = {
        { id = "HOME", label = "Übersicht" },
        { id = "GENERAL", label = "Allgemein" },
        { id = "LOOT", label = "Loot & Rollen" },
        { id = "PACKMULE", label = "PackMule" },
        { id = "DATA", label = "Daten & Diagnose" },
    },
}
GA.UI.SettingsWindow = SettingsWindow

local function profile() return GA.DB:GetProfile() end

local function openWindow(name)
    return SettingsWindow:OpenTool(name)
end

function SettingsWindow:OpenTool(name)
    local window = GA.UI and GA.UI[name]
    if not window or type(window.Show) ~= "function" then
        if GA.Print then GA:Print("Fenster ist nicht verfügbar: " .. tostring(name)) end
        return false
    end
    local opened = window:Show()
    if opened == false then return false end
    local child = window.frame
    if child then
        if type(child.SetToplevel) == "function" then child:SetToplevel(true) end
        if type(child.Raise) == "function" then child:Raise() end
    end
    -- The settings hub is a launcher, not a modal cover. Closing it here also
    -- works on clients where equal DIALOG strata ignore Raise().
    self:Hide()
    return true
end

function SettingsWindow:GetSections() return self.SECTIONS end

function SettingsWindow:ControlsReady()
    return self.autoOpen and self.autoGive and self.sound and self.minimap and self.bagShare and
        self.announce and self.channelEdit and self.durationEdit and self.scaleEdit and self.profileEdit and
        self.muleTargetEdit and self.muleQualityEdit and self.status
end

function SettingsWindow:CreateCheckBox(parent, labelText, y, key)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24); check:SetHeight(24); check:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    local label = Theme:CreateLabel(parent, labelText, 12); label:SetPoint("LEFT", check, "RIGHT", 5, 1)
    check.label = label
    check:SetScript("OnClick", function(self)
        profile()[key] = self:GetChecked() and true or false
        SettingsWindow:SetStatus("Einstellung gespeichert.", Theme.colors.green)
    end)
    return check
end

function SettingsWindow:CreateMinimapCheckBox(parent, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetWidth(24); check:SetHeight(24); check:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    local label = Theme:CreateLabel(parent, "Minimap-Button anzeigen", 12); label:SetPoint("LEFT", check, "RIGHT", 5, 1)
    check.label = label
    check:SetScript("OnClick", function(self)
        local current = profile(); current.minimap = current.minimap or {}
        current.minimap.hide = not (self:GetChecked() and true or false)
        if GA.UI.Launcher and type(GA.UI.Launcher.Refresh) == "function" then GA.UI.Launcher:Refresh() end
        SettingsWindow:SetStatus("Einstellung gespeichert.", Theme.colors.green)
    end)
    return check
end

function SettingsWindow:CreateSection(id, title, description)
    local section = CreateFrame("Frame", nil, self.content)
    section:SetAllPoints(self.content); section:Hide()
    local heading = Theme:CreateLabel(section, title, 14, Theme.colors.gold)
    heading:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -18)
    local text = Theme:CreateLabel(section, description or "", 11, Theme.colors.muted)
    text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8); text:SetPoint("RIGHT", section, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    self.sectionFrames[id] = section
    return section
end

function SettingsWindow:CreateToolButton(parent, text, window, column, row)
    local button = Theme:CreateButton(parent, text, 160, 30)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + ((column - 1) * 174), -112 - ((row - 1) * 38))
    button:SetScript("OnClick", function() openWindow(window) end)
    return button
end

function SettingsWindow:BuildHome()
    local section = self:CreateSection("HOME", "MasterLooter", "Alle Werkzeuge sind jederzeit erreichbar – auch ohne Gruppe, Lootfenster oder aktive Verteilung.")
    local hint = Theme:CreateLabel(section, "VERTEILUNG UND VERWALTUNG", 11, Theme.colors.muted)
    hint:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -86)
    local tools = {
        { "Lootmaster", "MasterLooterWindow" }, { "Erfasster Loot", "LootWindow" }, { "Handel", "TradeWindow" },
        { "SoftRes", "SoftResWindow" }, { "Regeln & Strichliste", "RulesWindow" }, { "Historie", "HistoryWindow" },
        { "GDKP", "GDKPWindow" }, { "GDKP-Auktion", "GDKPAuctionWindow" }, { "Raidverwaltung", "RaidManagerWindow" },
        { "Tascheninspektor", "BagInspectorWindow" }, { "Import / Export", "ImportExportWindow" }, { "Versionscheck", "VersionWindow" },
        { "Ascension-Itemsuche", "ItemSearchWindow" }, { "Profile", "ProfileWindow" }, { "Neuigkeiten", "WelcomeWindow" },
    }
    for index, tool in ipairs(tools) do
        local column = ((index - 1) % 3) + 1
        local row = math.floor((index - 1) / 3) + 1
        self:CreateToolButton(section, tool[1], tool[2], column, row)
    end
    local info = Theme:CreateLabel(section, "Minimap: Linksklick öffnet diese Übersicht · Rechtsklick öffnet Import/Export · Mittelklick öffnet die Historie", 11, Theme.colors.muted)
    info:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 20, 24); info:SetPoint("RIGHT", section, "RIGHT", -20, 0)
end

function SettingsWindow:BuildGeneral()
    local section = self:CreateSection("GENERAL", "Allgemein", "Grundlegendes Verhalten, Sichtbarkeit und aktive Konfiguration.")
    self.autoOpen = self:CreateCheckBox(section, "Rollfenster bei neuer Verteilung automatisch öffnen", -92, "autoOpenRollWindow")
    self.sound = self:CreateCheckBox(section, "Hinweistöne abspielen", -126, "sound")
    self.minimap = self:CreateMinimapCheckBox(section, -160)
    self.bagShare = self:CreateCheckBox(section, "Taschenabfragen durch Gruppenmitglieder erlauben", -194, "bagInspectorShare")
    self.bagShare:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() and true or false
        if GA.BagInspector and type(GA.BagInspector.SetSharing) == "function" then GA.BagInspector:SetSharing(enabled) else profile().bagInspectorShare = enabled end
        SettingsWindow:SetStatus("Taschenfreigabe gespeichert.", Theme.colors.green)
    end)

    local profileTitle = Theme:CreateLabel(section, "PROFIL", 11, Theme.colors.muted); profileTitle:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -252)
    local profileLabel = Theme:CreateLabel(section, "Aktives Profil", 12); profileLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -282)
    self.profileEdit = Theme:CreateEditBox(section, 190, 24); self.profileEdit:SetPoint("LEFT", profileLabel, "RIGHT", 20, 0)
    local switchProfile = Theme:CreateButton(section, "Wechseln", 90, 24); switchProfile:SetPoint("LEFT", self.profileEdit, "RIGHT", 8, 0)
    switchProfile:SetScript("OnClick", function() SettingsWindow:SwitchProfile() end)
    local manageProfiles = Theme:CreateButton(section, "Profile verwalten", 145, 24); manageProfiles:SetPoint("LEFT", switchProfile, "RIGHT", 8, 0)
    manageProfiles:SetScript("OnClick", function() openWindow("ProfileWindow") end)
end

function SettingsWindow:BuildLoot()
    local section = self:CreateSection("LOOT", "Loot & Rollen", "Standards für Verteilungen, Vergaben und Gruppenansagen.")
    self.autoGive = self:CreateCheckBox(section, "Gewinner automatisch über Masterloot beliefern", -92, "autoGiveAwards")
    self.announce = self:CreateCheckBox(section, "Ansagen in Gruppe/Raid aktivieren", -126, "_announcementEnabled")
    self.announce:SetScript("OnClick", function(self)
        if GA.Announcements then GA.Announcements:SetOption("enabled", self:GetChecked() and true or false) end
        SettingsWindow:SetStatus("Ansageeinstellung gespeichert.", Theme.colors.green)
    end)
    local channelLabel = Theme:CreateLabel(section, "Ansagekanal", 12); channelLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -178)
    self.channelEdit = Theme:CreateEditBox(section, 110, 24); self.channelEdit:SetPoint("LEFT", channelLabel, "RIGHT", 24, 0)
    local channelSave = Theme:CreateButton(section, "Setzen", 70, 24); channelSave:SetPoint("LEFT", self.channelEdit, "RIGHT", 8, 0)
    channelSave:SetScript("OnClick", function()
        local ok, err = GA.Announcements:SetOption("channel", SettingsWindow.channelEdit:GetText())
        SettingsWindow:SetStatus(ok and "Ansagekanal gespeichert." or tostring(err), ok and Theme.colors.green or Theme.colors.red)
    end)
    local durationLabel = Theme:CreateLabel(section, "Standarddauer", 12); durationLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -222)
    self.durationEdit = Theme:CreateEditBox(section, 60, 24, true); self.durationEdit:SetPoint("LEFT", durationLabel, "RIGHT", 24, 0)
    local seconds = Theme:CreateLabel(section, "Sekunden", 12, Theme.colors.muted); seconds:SetPoint("LEFT", self.durationEdit, "RIGHT", 8, 0)
    local save = Theme:CreateButton(section, "Speichern", 100, 25); save:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -260)
    save:SetScript("OnClick", function() SettingsWindow:SaveDuration() end)
    local note = Theme:CreateLabel(section, "Der OS-Bereich wird für jede Verteilung autoritativ im Lootmaster-Fenster festgelegt. MS bleibt immer /roll 100.", 11, Theme.colors.muted)
    note:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -316); note:SetPoint("RIGHT", section, "RIGHT", -20, 0)
end

function SettingsWindow:BuildPackMule()
    local section = self:CreateSection("PACKMULE", "PackMule", "Regeln für den vorgesehenen Empfänger automatisch zu sammelnder Beute.")
    local targetLabel = Theme:CreateLabel(section, "Zielspieler", 12); targetLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -96)
    self.muleTargetEdit = Theme:CreateEditBox(section, 190, 24); self.muleTargetEdit:SetPoint("LEFT", targetLabel, "RIGHT", 28, 0)
    local qualityLabel = Theme:CreateLabel(section, "Mindestqualität (0–7)", 12); qualityLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -140)
    self.muleQualityEdit = Theme:CreateEditBox(section, 55, 24, true); self.muleQualityEdit:SetPoint("LEFT", qualityLabel, "RIGHT", 28, 0)
    local save = Theme:CreateButton(section, "Regeln aktivieren", 145, 26); save:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -184)
    save:SetScript("OnClick", function() SettingsWindow:SavePackMule() end)
    local rules = Theme:CreateButton(section, "Regeln & Strichliste öffnen", 190, 26); rules:SetPoint("LEFT", save, "RIGHT", 10, 0)
    rules:SetScript("OnClick", function() openWindow("RulesWindow") end)
end

function SettingsWindow:BuildData()
    local section = self:CreateSection("DATA", "Daten & Diagnose", "Import, Export, Versionsinformationen und kopierbare Diagnoseprotokolle.")
    local tools = {
        { "Gesamtdiagnose", "AddonDebugWindow" }, { "Import / Export", "ImportExportWindow" }, { "Historie", "HistoryWindow" },
        { "Versionscheck", "VersionWindow" }, { "Roll-Diagnose", "RollDebugWindow" }, { "Kommunikationsdiagnose", "CommDebugWindow" },
        { "Tooltip-Diagnose", "TooltipDebugWindow" }, { "Tascheninspektor", "BagInspectorWindow" },
    }
    for index, tool in ipairs(tools) do
        self:CreateToolButton(section, tool[1], tool[2], ((index - 1) % 3) + 1, math.floor((index - 1) / 3) + 1)
    end
    local uiTitle = Theme:CreateLabel(section, "OBERFLÄCHE", 11, Theme.colors.muted); uiTitle:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -226)
    local scaleLabel = Theme:CreateLabel(section, "UI-Skalierung (0.70–1.50)", 12); scaleLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -258)
    self.scaleEdit = Theme:CreateEditBox(section, 60, 24); self.scaleEdit:SetPoint("LEFT", scaleLabel, "RIGHT", 18, 0)
    local apply = Theme:CreateButton(section, "Anwenden", 90, 24); apply:SetPoint("LEFT", self.scaleEdit, "RIGHT", 8, 0)
    apply:SetScript("OnClick", function() SettingsWindow:ApplyScale() end)
    local reset = Theme:CreateButton(section, "Fensterpositionen zurücksetzen", 210, 26); reset:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -306)
    reset:SetScript("OnClick", function() SettingsWindow:ResetPositions() end)
    local factory = Theme:CreateButton(section, "Gesamtes Addon zurücksetzen", 210, 26); factory:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -344); factory:SetScript("OnClick", function() SettingsWindow:RequestFactoryReset() end); self.factoryResetButton = factory
end

function SettingsWindow:EnsureFrame()
    if self.frame and self.buildComplete and self:ControlsReady() then return self.frame end
    if self.frame then return nil, self.buildError or "Einstellungsfenster ist unvollständig aufgebaut." end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterSettingsWindow", UIParent)
    frame:SetWidth(self.WIDTH); frame:SetHeight(self.HEIGHT); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter " .. tostring(GA.VERSION or "") .. " – Einstellungen")
    Theme:MakeMovable(frame, "settingsHubV2"); Theme:RestorePosition(frame, "settingsHubV2", "CENTER", 0, 15); Theme:RegisterForEscape(frame)
    self.frame = frame

    local sidebar = CreateFrame("Frame", nil, frame); sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -43); sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 48); sidebar:SetWidth(170); Theme:ApplyInset(sidebar)
    local content = CreateFrame("Frame", nil, frame); content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 14, 0); content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 48); Theme:ApplyInset(content)
    self.sidebar, self.content, self.sectionFrames, self.navButtons = sidebar, content, {}, {}

    local navTitle = Theme:CreateLabel(sidebar, "BEREICHE", 11, Theme.colors.muted); navTitle:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 13, -15)
    for index, entry in ipairs(self.SECTIONS) do
        local button = Theme:CreateButton(sidebar, entry.label, 144, 28); button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 13, -38 - ((index - 1) * 32))
        button:SetScript("OnClick", function() SettingsWindow:ShowSection(entry.id) end); self.navButtons[entry.id] = button
    end

    self:BuildHome(); self:BuildGeneral(); self:BuildLoot(); self:BuildPackMule(); self:BuildData()
    local status = Theme:CreateLabel(frame, "", 11, Theme.colors.muted); status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20); status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20); status:SetJustifyH("RIGHT"); self.status = status
    self.buildComplete = self:ControlsReady() and true or false
    if not self.buildComplete then self.buildError = "Bedienelemente konnten nicht vollständig erstellt werden."; return nil, self.buildError end
    return frame
end

function SettingsWindow:ShowSection(id)
    id = self.sectionFrames and self.sectionFrames[id] and id or self.DEFAULT_SECTION
    self.activeSection = id; profile().settingsSection = id
    for sectionID, frame in pairs(self.sectionFrames or {}) do if sectionID == id then frame:Show() else frame:Hide() end end
    for sectionID, button in pairs(self.navButtons or {}) do if sectionID == id then button:Disable() else button:Enable() end end
    self:SetStatus("")
    return id
end

function SettingsWindow:SetStatus(text, color)
    if not self.status then return end
    self.status:SetText(text or ""); self.status:SetTextColor(unpack(color or Theme.colors.muted))
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
    for _, controller in pairs(GA.UI or {}) do if type(controller) == "table" and controller.frame and type(controller.frame.SetScale) == "function" then controller.frame:SetScale(value) end end
    self:SetStatus("UI-Skalierung angewendet.", Theme.colors.green)
end

function SettingsWindow:SwitchProfile()
    local name = string.match(tostring(self.profileEdit:GetText() or ""), "^%s*(.-)%s*$")
    if name == "" or #name > 40 or string.find(name, "[%c]") then self:SetStatus("Ungültiger Profilname.", Theme.colors.red); return end
    GA.DB:SetProfile(name); self:Refresh(); self:SetStatus("Profil gewechselt. /reload für alle Fenster empfohlen.", Theme.colors.green)
end

function SettingsWindow:ResetPositions()
    local current = profile()
    for key, value in pairs(current) do if type(value) == "table" and (string.find(string.lower(key), "window") or value.point) then value.point, value.relativePoint, value.x, value.y = nil, nil, nil, nil end end
    self:SetStatus("Gespeicherte Fensterpositionen zurückgesetzt. /reload anwenden.", Theme.colors.green)
end

function SettingsWindow:RequestFactoryReset()
    if not self.factoryResetArmed then
        self.factoryResetArmed = true; self.factoryResetButton:SetText("Wirklich alles löschen")
        self:SetStatus("Noch einmal klicken: Profile, Regeln, Historie, GDKP und alle Einstellungen werden gelöscht.", Theme.colors.red)
        if GA.Compat and type(GA.Compat.After) == "function" then GA.Compat:After(8, function() if SettingsWindow.factoryResetArmed then SettingsWindow.factoryResetArmed = false; SettingsWindow.factoryResetButton:SetText("Gesamtes Addon zurücksetzen"); SettingsWindow:SetStatus("Zurücksetzen abgebrochen.") end end) end
        return false
    end
    self.factoryResetArmed = false; self.factoryResetButton:SetText("Gesamtes Addon zurücksetzen")
    GA.DB:ResetAll(); self:SetStatus("Daten zurückgesetzt. Oberfläche wird neu geladen.", Theme.colors.green)
    if type(ReloadUI) == "function" then ReloadUI() end
    return true
end

function SettingsWindow:SaveDuration()
    local duration = tonumber(self.durationEdit:GetText())
    if not duration then self:SetStatus("Bitte eine gültige Dauer eingeben.", Theme.colors.red); return end
    duration = math.max(5, math.min(600, math.floor(duration))); profile().defaultRollDuration = duration
    self.durationEdit:SetText(tostring(duration)); self:SetStatus("Standarddauer gespeichert.", Theme.colors.green)
end

function SettingsWindow:Refresh()
    if not self:EnsureFrame() or not self:ControlsReady() then return false end
    local current = profile(); current.minimap = current.minimap or {}
    self.autoOpen:SetChecked(current.autoOpenRollWindow ~= false); self.autoGive:SetChecked(current.autoGiveAwards ~= false)
    self.sound:SetChecked(current.sound ~= false); self.minimap:SetChecked(current.minimap.hide ~= true)
    local config = GA.Announcements and GA.Announcements:GetConfig() or current.announcements or {}
    self.announce:SetChecked(config.enabled ~= false); self.bagShare:SetChecked(current.bagInspectorShare ~= false)
    self.channelEdit:SetText(tostring(config.channel or "AUTO")); self.durationEdit:SetText(tostring(tonumber(current.defaultRollDuration) or 30))
    self.scaleEdit:SetText(string.format("%.2f", tonumber(current.uiScale) or 1)); self.profileEdit:SetText(tostring(GA.DB.data.activeProfile or "Default"))
    if GA.PackMule then self.muleTargetEdit:SetText(tostring(GA.PackMule:GetTarget() or "")); self.muleQualityEdit:SetText(tostring((GA.PackMule:GetRules() or {}).minimumQuality or 2)) end
    return true
end

function SettingsWindow:Show(section)
    local frame, err = self:EnsureFrame()
    if not frame then if GA.Print then GA:Print("Einstellungen konnten nicht geöffnet werden: " .. tostring(err or "unbekannter Fehler")) end; return false end
    if not self:Refresh() then return false end
    self:ShowSection(section or profile().settingsSection or self.DEFAULT_SECTION); frame:Show(); return true
end
function SettingsWindow:Hide() if self.frame then self.frame:Hide() end end
function SettingsWindow:Toggle(section) local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show(section) end end

function SettingsWindow:RegisterInterfaceOptions()
    if self.optionsPanel or type(InterfaceOptions_AddCategory) ~= "function" then return end
    local parent = InterfaceOptionsFramePanelContainer or UIParent
    local panel = CreateFrame("Frame", "MasterLooterInterfaceOptionsPanel", parent); panel.name = "MasterLooter"
    panel:SetAllPoints(parent)
    -- Frames are visible immediately after CreateFrame on 3.3.5a.  The
    -- Interface Options controller only shows a registered panel when its
    -- category is selected, so keep ours hidden until that happens.  Without
    -- this explicit hide it covers every other Interface/AddOns page.
    panel:Hide()
    local title = Theme:CreateLabel(panel, "MasterLooter " .. tostring(GA.VERSION or ""), 14, Theme.colors.gold); title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    local text = Theme:CreateLabel(panel, "Die vollständigen Einstellungen und Werkzeuge öffnen sich in einer eigenen, übersichtlichen Oberfläche.", 12); text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    local open = Theme:CreateButton(panel, "MasterLooter öffnen", 190, 26); open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    open:SetScript("OnClick", function() if type(HideUIPanel) == "function" and InterfaceOptionsFrame then HideUIPanel(InterfaceOptionsFrame) end; SettingsWindow:Show() end)
    InterfaceOptions_AddCategory(panel); self.optionsPanel = panel
end

function SettingsWindow:OnInitialize()
    self:RegisterInterfaceOptions(); return true
end

GA:RegisterModule("SettingsWindow", SettingsWindow)
