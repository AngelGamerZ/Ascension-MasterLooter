local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local RollDebugWindow = {}
GA.UI.RollDebugWindow = RollDebugWindow

function RollDebugWindow:GetText()
    local tracker = GA.ChatRolls
    if tracker and type(tracker.GetDiagnosticText) == "function" then
        return tracker:GetDiagnosticText()
    end
    local state = GA.RollSession and GA.RollSession:GetState()
    return table.concat({
        "MasterLooter Roll-Diagnose",
        "Version: " .. tostring(GA.VERSION),
        "Tracker vorhanden: nein",
        "Aktive Sitzung: " .. tostring(state and state.id or "keine"),
        "Hinweis: Modules\\ChatRolls.lua wurde nicht geladen.",
    }, "\n")
end

function RollDebugWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end

    local frame = CreateFrame("Frame", "MasterLooterRollDebugWindow", UIParent)
    frame:SetWidth(650)
    frame:SetHeight(420)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    Theme:ApplyPanel(frame)
    Theme:AddTitle(frame, "MasterLooter – Roll-Diagnose")
    Theme:MakeMovable(frame, "rollDebugWindowV1")
    Theme:RestorePosition(frame, "rollDebugWindowV1", "CENTER", 0, 20)
    Theme:RegisterForEscape(frame)
    self.frame = frame

    local hint = Theme:CreateLabel(frame, "Text anklicken, dann Strg+A und Strg+C zum Kopieren.", 11, Theme.colors.muted)
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -47)

    local inset = CreateFrame("Frame", nil, frame)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -70)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 58)
    Theme:ApplyInset(inset)

    local scroll = CreateFrame("ScrollFrame", "MasterLooterRollDebugScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 10)
    self.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetWidth(560)
    edit:SetHeight(285)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 12)
    edit:SetTextColor(0.92, 0.92, 0.92, 1)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    self.edit = edit

    local refresh = Theme:CreateButton(frame, "Aktualisieren", 120, 26)
    refresh:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    refresh:SetScript("OnClick", function() RollDebugWindow:Refresh(false) end)

    local selectAll = Theme:CreateButton(frame, "Alles markieren", 130, 26)
    selectAll:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    return frame
end

function RollDebugWindow:Refresh(selectText)
    if not self:EnsureFrame() then return end
    self.edit:SetText(self:GetText())
    if selectText then
        self.edit:SetFocus()
        self.edit:HighlightText()
    end
end

function RollDebugWindow:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self:Refresh(true)
    frame:Show()
end

function RollDebugWindow:Hide()
    if self.frame then self.frame:Hide() end
end
