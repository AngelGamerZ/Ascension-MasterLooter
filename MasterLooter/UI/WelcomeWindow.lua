local _, GA = ...
GA.UI = GA.UI or {}
local Theme, WelcomeWindow = GA.UI.Theme, {}
GA.UI.WelcomeWindow = WelcomeWindow

local NOTES = {
    "Neuimplementierung für Ascension WoW 3.3.5a",
    "Öffentliche /roll-Auswertung für Spieler mit und ohne Addon",
    "Direktvergabe, Handels-Fallback, Regeln, Strichliste und GDKP",
    "Erweiterte Werkzeuge sind jederzeit über den Minimap-Button erreichbar",
}
function WelcomeWindow:EnsureFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "MasterLooterWelcomeWindow", UIParent); frame:SetWidth(620); frame:SetHeight(420); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter " .. tostring(GA.VERSION)); Theme:MakeMovable(frame, "welcomeWindow"); Theme:RestorePosition(frame, "welcomeWindow", "CENTER", 0, 0); Theme:RegisterForEscape(frame); self.frame = frame
    local heading = Theme:CreateLabel(frame, "Willkommen bei MasterLooter", 14, Theme.colors.gold); heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -58)
    local text = Theme:CreateLabel(frame, "Dieses Addon wurde speziell für Project Ascension und den 3.3.5a-Client entwickelt.", 12); text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14); text:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    local previous = text
    self.noteLabels = {}
    for _, note in ipairs(NOTES) do
        local localizedNote = type(GA.Localize) == "function" and GA:Localize(note) or note
        local line = Theme:CreateLabel(frame, "• " .. localizedNote, 11, Theme.colors.muted)
        line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
        line:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
        self.noteLabels[#self.noteLabels + 1] = line
        previous = line
    end
    local settings = Theme:CreateButton(frame, "Einstellungen öffnen", 170, 28); settings:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 28); settings:SetScript("OnClick", function() WelcomeWindow:Hide(); if GA.UI.SettingsWindow then GA.UI.SettingsWindow:Show() end end)
    local close = Theme:CreateButton(frame, "Verstanden", 110, 28); close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 28); close:SetScript("OnClick", function() WelcomeWindow:Hide() end)
    return frame
end
function WelcomeWindow:Show() local frame = self:EnsureFrame(); frame:Show(); frame:Raise(); local profile = GA.DB:GetProfile(); profile.welcomeVersion = GA.VERSION; return true end
function WelcomeWindow:Hide() if self.frame then self.frame:Hide() end end
function WelcomeWindow:OnInitialize()
    self:EnsureFrame(); local profile = GA.DB:GetProfile()
    if profile.welcomeVersion ~= GA.VERSION and profile.showChangelog ~= false and GA.Compat and type(GA.Compat.After) == "function" then GA.Compat:After(2, function() WelcomeWindow:Show() end) end
    return true
end
GA:RegisterModule("WelcomeWindow", WelcomeWindow)
