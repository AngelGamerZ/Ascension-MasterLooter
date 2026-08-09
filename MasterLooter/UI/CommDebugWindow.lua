local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local CommDebugWindow = {}
GA.UI.CommDebugWindow = CommDebugWindow

function CommDebugWindow:GetText()
    local lines = { "MasterLooter Kommunikationsdiagnose", "Version: " .. tostring(GA.VERSION), "" }
    lines[#lines + 1] = GA.Comm and GA.Comm:ExportTrace() or "Keine Kommunikationsdaten verfügbar."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Fehlerprotokoll"
    local errors = GA.GetErrors and GA:GetErrors() or {}
    if #errors == 0 then lines[#lines + 1] = "Keine internen Fehler erfasst." end
    for index = 1, #errors do
        local entry = errors[index]
        lines[#lines + 1] = table.concat({ tostring(entry.time or 0), tostring(entry.context or "?"),
            tostring(entry.message or ""):gsub("[\r\n\t]", " ") }, "\t")
    end
    local text = table.concat(lines, "\n")
    return type(GA.Localize) == "function" and GA:Localize(text) or text
end

function CommDebugWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterCommDebugWindow", UIParent)
    frame:SetWidth(760); frame:SetHeight(500); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Kommunikationsdiagnose")
    Theme:MakeMovable(frame, "commDebugWindowV1"); Theme:RestorePosition(frame, "commDebugWindowV1", "CENTER", 0, 20)
    Theme:RegisterForEscape(frame); self.frame = frame
    local hint = Theme:CreateLabel(frame, "Strg+A und Strg+C kopieren den vollständigen Trace.", 11, Theme.colors.muted)
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -47)
    local inset = CreateFrame("Frame", nil, frame)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -70); inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 58)
    Theme:ApplyInset(inset)
    local scroll = CreateFrame("ScrollFrame", "MasterLooterCommDebugScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10); scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -30, 10)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetWidth(665); edit:SetHeight(355)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 11); edit:SetTextColor(0.92, 0.92, 0.92, 1)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit); self.edit = edit
    local refresh = Theme:CreateButton(frame, "Aktualisieren", 120, 26)
    refresh:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    refresh:SetScript("OnClick", function() CommDebugWindow:Refresh(false) end)
    local selectAll = Theme:CreateButton(frame, "Alles markieren", 130, 26)
    selectAll:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    selectAll:SetScript("OnClick", function() edit:SetFocus(); edit:HighlightText() end)
    local clear = Theme:CreateButton(frame, "Trace leeren", 110, 26)
    clear:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
    clear:SetScript("OnClick", function() if GA.Comm then GA.Comm:ClearTrace() end; CommDebugWindow:Refresh(false) end)
    return frame
end

function CommDebugWindow:Refresh(selectText)
    if not self:EnsureFrame() then return end
    self.edit:SetText(self:GetText())
    if selectText then self.edit:SetFocus(); self.edit:HighlightText() end
end

function CommDebugWindow:Show()
    local frame = self:EnsureFrame(); if not frame then return end
    self:Refresh(true); frame:Show()
end

function CommDebugWindow:Hide() if self.frame then self.frame:Hide() end end
function CommDebugWindow:Toggle()
    local frame = self:EnsureFrame(); if not frame then return end
    if frame:IsShown() then self:Hide() else self:Show() end
end
