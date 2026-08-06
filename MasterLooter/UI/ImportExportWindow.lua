local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme
local ImportExportWindow = { moduleIndex = 1, modules = {
    { key = "softres", label = "SoftRes", direct = "SoftRes" },
    { key = "priority", label = "Prioritäten", direct = "Priority" },
    { key = "plusones", label = "PlusOnes", direct = "PlusOnes" },
    { key = "boosts", label = "Boosts", direct = "BoostedRolls" },
    { key = "tmbpriority", label = "TMB-Prioritäten", direct = "Priority", exportMethod = "ExportTMB", importMethod = "ImportTMB" },
    { key = "bisbeard", label = "BISBEARD SoftRes", direct = "ExternalImports", importMethod = "ImportBisBeard", validateMethod = "ValidateBisBeard", importOnly = true },
    { key = "dftpriority", label = "DFT-Prioritäten", direct = "ExternalImports", importMethod = "ImportDFT", validateMethod = "ValidateDFT", importOnly = true },
    { key = "classicpr", label = "ClassicPR / CSV", direct = "ExternalImports", importMethod = "ImportClassicPR", validateMethod = "ValidateClassicPR", importOnly = true },
    { key = "rrobin", label = "RRobin-Prioritäten", direct = "ExternalImports", importMethod = "ImportRRobin", validateMethod = "ValidateRRobin", importOnly = true },
    { key = "autoroll", label = "AutoRoll-Regeln", direct = "AutoRoll", directOnly = true },
    { key = "awards", label = "Vergaben", direct = "Award" },
    { key = "gdkp", label = "GDKP", direct = "GDKP" },
} }
GA.UI.ImportExportWindow = ImportExportWindow

local function callManager(method, moduleName, text)
    local definition
    for _, candidate in ipairs(ImportExportWindow.modules) do if candidate.key == moduleName then definition = candidate; break end end
    if definition and (definition.directOnly or definition.exportMethod or definition.importMethod) then
        local module = GA[definition.direct]
        if method == "Export" and definition.importOnly then return false, "Dieses Fremdformat kann nur importiert werden." end
        local actual = method == "Export" and (definition.exportMethod or "Export") or
            method == "Import" and (definition.importMethod or "Import") or
            method == "Validate" and (definition.validateMethod or "Validate") or method
        if method == "Validate" and not definition.validateMethod then return true, type(text) == "string" and text ~= "", "Paste wird beim Import zeilenweise geprüft." end
        if type(module) == "table" and type(module[actual]) == "function" then
            return pcall(module[actual], module, text)
        end
        return false, "Modul unterstützt " .. method .. " nicht."
    end
    local manager = GA.ImportExport
    if type(manager) == "table" and type(manager[method]) == "function" then
        local optionKeys = { softres = "softRes", priority = "priority", plusones = "plusOnes", boosts = "boosts", awards = "awards", gdkp = "gdkp" }
        local types = { softres = { SR = true, HR = true }, priority = { PR = true }, plusones = { P1 = true },
            boosts = { BR = true }, awards = { AW = true }, gdkp = { GK = true, GS = true, GJ = true, GP = true } }
        if method == "Export" then
            local options = { softRes = false, priority = false, plusOnes = false, boosts = false, awards = false, gdkp = false }
            options[optionKeys[moduleName]] = true
            return pcall(manager.Export, manager, options)
        elseif method == "Validate" then
            local ok, report = pcall(manager.Validate, manager, text)
            if not ok then return false, report end
            local allowed, wrong = types[moduleName] or {}, nil
            for recordType in pairs(report.byType or {}) do if not allowed[recordType] then wrong = recordType; break end end
            local valid = report.valid and not wrong
            local detail = wrong and ("Datensatz " .. wrong .. " gehört nicht zu diesem Modul") or
                (valid and "Validierung erfolgreich." or table.concat(report.errors or {}, "; "))
            return true, valid, detail
        elseif method == "Import" then
            local ok, report = pcall(manager.Import, manager, text, { strict = true })
            if not ok then return false, report end
            return true, report.imported or 0, report.rejected or 0
        end
    end
    local module
    for _, definition in ipairs(ImportExportWindow.modules) do
        if definition.key == moduleName then module = GA[definition.direct]; break end
    end
    if type(module) == "table" and type(module[method]) == "function" then
        if text == nil then return pcall(module[method], module) end
        return pcall(module[method], module, text)
    end
    return false, "Modul unterstützt " .. method .. " nicht."
end

function ImportExportWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterImportExportWindow", UIParent)
    frame:SetWidth(620); frame:SetHeight(480); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Import / Export")
    Theme:MakeMovable(frame, "importExportWindow"); Theme:RestorePosition(frame, "importExportWindow", "CENTER", 0, 10); Theme:RegisterForEscape(frame); self.frame = frame
    local moduleLabel = Theme:CreateLabel(frame, "Modul", 12, Theme.colors.muted); moduleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -48)
    local moduleButton = Theme:CreateButton(frame, self.modules[self.moduleIndex].label, 175, 25); moduleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 84, -42)
    moduleButton:SetScript("OnClick", function() ImportExportWindow:NextModule() end); self.moduleButton = moduleButton
    local hint = Theme:CreateLabel(frame, "Klicken, um das nächste Modul auszuwählen", 12, Theme.colors.muted); hint:SetPoint("LEFT", moduleButton, "RIGHT", 10, 0)

    local scroll = CreateFrame("ScrollFrame", "MasterLooterImportExportScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -82); scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -45, 91)
    local background = CreateFrame("Frame", nil, frame); background:SetPoint("TOPLEFT", scroll, "TOPLEFT", -4, 4); background:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 27, -4); Theme:ApplyInset(background); background:SetFrameLevel(scroll:GetFrameLevel() - 1)
    local edit = CreateFrame("EditBox", nil, scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal); edit:SetWidth(535); edit:SetHeight(300); edit:SetTextInsets(5, 5, 5, 5)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        local _, lines = string.gsub(self:GetText() or "", "\n", "")
        self:SetHeight(math.max(300, (lines + 1) * 15 + 12))
        scroll:UpdateScrollChildRect()
    end)
    edit:SetScript("OnCursorChanged", function(self, x, y, width, height) if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, x, y, width, height) end end)
    edit:SetScript("OnUpdate", function(self, elapsed) if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, scroll) end end)
    scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel", function(self, delta) self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - (delta * 30)))) end)
    scroll:SetScrollChild(edit); self.edit = edit

    local export = Theme:CreateButton(frame, "Exportieren", 110, 27); export:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 48); export:SetScript("OnClick", function() ImportExportWindow:Export() end)
    local validate = Theme:CreateButton(frame, "Prüfen", 95, 27); validate:SetPoint("LEFT", export, "RIGHT", 8, 0); validate:SetScript("OnClick", function() ImportExportWindow:Validate() end)
    local import = Theme:CreateButton(frame, "Importieren", 110, 27); import:SetPoint("LEFT", validate, "RIGHT", 8, 0); import:SetScript("OnClick", function() ImportExportWindow:Import() end)
    local clear = Theme:CreateButton(frame, "Leeren", 90, 27); clear:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 48); clear:SetScript("OnClick", function() edit:SetText(""); ImportExportWindow:SetResult("") end)
    local result = Theme:CreateLabel(frame, "", 12, Theme.colors.muted); result:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 19); result:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 19); result:SetJustifyH("LEFT"); self.result = result
    return frame
end

function ImportExportWindow:CurrentModule() return self.modules[self.moduleIndex].key end
function ImportExportWindow:NextModule()
    self.moduleIndex = (self.moduleIndex % #self.modules) + 1; self.moduleButton:SetText(self.modules[self.moduleIndex].label); self:SetResult("")
end
function ImportExportWindow:SetResult(text, color)
    self.result:SetText(text or ""); self.result:SetTextColor(unpack(color or Theme.colors.muted))
end
function ImportExportWindow:Export()
    local ok, result, detail = callManager("Export", self:CurrentModule())
    if ok and type(result) == "string" then self.edit:SetText(result); self.edit:HighlightText(); self:SetResult("Export erstellt.", Theme.colors.green)
    else self:SetResult(tostring(detail or result or "Export fehlgeschlagen."), Theme.colors.red) end
end
function ImportExportWindow:Validate()
    if not GA.ImportExport or type(GA.ImportExport.Validate) ~= "function" then
        self:SetResult(self.edit:GetText() ~= "" and "Text vorhanden; die Modulprüfung erfolgt beim Import." or "Das Textfeld ist leer.", self.edit:GetText() ~= "" and Theme.colors.green or Theme.colors.red); return self.edit:GetText() ~= ""
    end
    local ok, valid, detail = callManager("Validate", self:CurrentModule(), self.edit:GetText())
    if ok and valid then self:SetResult(type(detail) == "string" and detail or "Validierung erfolgreich.", Theme.colors.green); return true end
    self:SetResult(tostring(detail or valid or "Validierung fehlgeschlagen."), Theme.colors.red); return false
end
function ImportExportWindow:Import()
    if self.edit:GetText() == "" then self:SetResult("Das Textfeld ist leer.", Theme.colors.red); return end
    if GA.ImportExport and type(GA.ImportExport.Validate) == "function" and not self:Validate() then return end
    local ok, result, detail = callManager("Import", self:CurrentModule(), self.edit:GetText())
    if ok and result ~= false and result ~= nil then
        local message = type(result) == "number" and (tostring(result) .. " importiert" .. (type(detail) == "number" and (", " .. detail .. " abgelehnt") or "")) or "Import erfolgreich."
        self:SetResult(message, Theme.colors.green)
    else self:SetResult(tostring(detail or result or "Import fehlgeschlagen."), Theme.colors.red) end
end
function ImportExportWindow:Show() local frame = self:EnsureFrame(); if frame then frame:Show() end end
function ImportExportWindow:Hide() if self.frame then self.frame:Hide() end end
function ImportExportWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function ImportExportWindow:OnInitialize() self:EnsureFrame(); return true end
GA:RegisterModule("ImportExportWindow", ImportExportWindow)
