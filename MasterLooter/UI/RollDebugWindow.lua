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
    local title = Theme:AddTitle(frame, "MasterLooter – Roll-Diagnose")
    self.title = title
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
    refresh:SetScript("OnClick", function() RollDebugWindow:RefreshCurrent(false) end)

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
    if self.title then self.title:SetText("MasterLooter – Roll-Diagnose") end
    self.edit:SetText(self:GetText())
    if selectText then
        self.edit:SetFocus()
        self.edit:HighlightText()
    end
end

function RollDebugWindow:RefreshCurrent(selectText)
    if type(self.currentProvider) == "function" then
        local ok, text = pcall(self.currentProvider)
        return self:ShowText(ok and text or ("Diagnose konnte nicht aktualisiert werden:\n" .. tostring(text)), self.currentTitle, selectText)
    end
    return self:Refresh(selectText)
end

function RollDebugWindow:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self.currentProvider, self.currentTitle = nil, nil
    self:Refresh(true)
    frame:Show()
end

function RollDebugWindow:Hide()
    if self.frame then self.frame:Hide() end
end

function RollDebugWindow:ShowText(text, title, selectText)
    local frame = self:EnsureFrame()
    if not frame then return false end
    if self.title then self.title:SetText(title or "MasterLooter – Diagnose") end
    self.edit:SetText(tostring(text or ""))
    if selectText ~= false then self.edit:SetFocus(); self.edit:HighlightText() end
    frame:Show()
    return true
end


function RollDebugWindow:ShowDynamic(provider, title)
    self.currentProvider, self.currentTitle = provider, title
    return self:RefreshCurrent(true)
end

-- This fallback lives in a long-established UI file. It keeps tooltip
-- diagnostics copyable even if the dedicated window file cannot load on a
-- customized 3.3.5a client.
if not GA.UI.TooltipDebugWindow then
    GA.UI.TooltipDebugWindow = {
        Show = function()
            local text
            if GA.TooltipDebug and type(GA.TooltipDebug.GetText) == "function" then
                text = GA.TooltipDebug:GetText()
            else
                local tocVersion = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("MasterLooter", "Version") or "API nicht verfügbar"
                local errors = {
                    "MasterLooter Tooltip-Diagnose", "TooltipDebug-Modul nicht geladen.",
                    "Lua-Version: " .. tostring(GA.VERSION), "TOC-Version: " .. tostring(tocVersion), "", "MasterLooter-Ladefehler:",
                }
                for _, entry in ipairs(GA.errors or {}) do
                    errors[#errors + 1] = tostring(entry.context) .. ": " .. tostring(entry.message)
                end
                text = table.concat(errors, "\n")
            end
            return RollDebugWindow:ShowDynamic(function()
                return GA.TooltipDebug and type(GA.TooltipDebug.GetText) == "function" and GA.TooltipDebug:GetText() or text
            end, "MasterLooter – Tooltip-Diagnose")
        end,
        Hide = function() RollDebugWindow:Hide() end,
    }
end

GA.UI.AddonDebugWindow = GA.UI.AddonDebugWindow or {
    Show = function()
        local text = type(GA.GetFullDiagnosticText) == "function" and GA:GetFullDiagnosticText() or
            ("MasterLooter – Gesamtdiagnose\nNicht verfügbar.\nVersion: " .. tostring(GA.VERSION))
        return RollDebugWindow:ShowDynamic(function()
            return type(GA.GetFullDiagnosticText) == "function" and GA:GetFullDiagnosticText() or text
        end, "MasterLooter – Gesamtdiagnose")
    end,
    Hide = function() RollDebugWindow:Hide() end,
}
