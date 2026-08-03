local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local TooltipDebugWindow = {}
GA.UI.TooltipDebugWindow = TooltipDebugWindow

function TooltipDebugWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterTooltipDebugWindow", UIParent)
    frame:SetWidth(760); frame:SetHeight(520); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Tooltip-Diagnose")
    Theme:MakeMovable(frame, "tooltipDebugWindowV1"); Theme:RestorePosition(frame, "tooltipDebugWindowV1", "CENTER", 0, 20); Theme:RegisterForEscape(frame)
    self.frame = frame

    local hint = Theme:CreateLabel(frame, "Loot aufnehmen, Fehler reproduzieren, dann Aktualisieren und Alles markieren.", 11, Theme.colors.muted)
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -47)
    local inset = CreateFrame("Frame", nil, frame); inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -70); inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 58); Theme:ApplyInset(inset)
    local scroll = CreateFrame("ScrollFrame", "MasterLooterTooltipDebugScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10); scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 10)
    local edit = CreateFrame("EditBox", nil, scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetWidth(660); edit:SetHeight(380)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 11); edit:SetTextColor(0.92, 0.92, 0.92, 1); edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit); self.edit = edit

    local refresh = Theme:CreateButton(frame, "Aktualisieren", 120, 26); refresh:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20); refresh:SetScript("OnClick", function() TooltipDebugWindow:Refresh(false) end)
    local selectAll = Theme:CreateButton(frame, "Alles markieren", 130, 26); selectAll:SetPoint("LEFT", refresh, "RIGHT", 8, 0); selectAll:SetScript("OnClick", function() edit:SetFocus(); edit:HighlightText() end)
    local clear = Theme:CreateButton(frame, "Leeren", 90, 26); clear:SetPoint("LEFT", selectAll, "RIGHT", 8, 0); clear:SetScript("OnClick", function() if GA.TooltipDebug then GA.TooltipDebug:Clear() end; TooltipDebugWindow:Refresh(false) end)
    return frame
end

function TooltipDebugWindow:Refresh(selectText)
    if not self:EnsureFrame() then return end
    self.edit:SetText(GA.TooltipDebug and GA.TooltipDebug:GetText() or "Tooltip-Diagnose ist nicht geladen.")
    if selectText then self.edit:SetFocus(); self.edit:HighlightText() end
end

function TooltipDebugWindow:Show()
    local frame = self:EnsureFrame(); if not frame then return end
    self:Refresh(true); frame:Show()
end

function TooltipDebugWindow:Hide() if self.frame then self.frame:Hide() end end
