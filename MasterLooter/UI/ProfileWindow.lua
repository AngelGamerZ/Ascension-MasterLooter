local _, GA = ...
GA.UI = GA.UI or {}
local Theme, ProfileWindow = GA.UI.Theme, { selected = nil, rows = {}, page = 1, pageSize = 8 }
GA.UI.ProfileWindow = ProfileWindow

local function L(key, fallback, ...)
    if type(GA.L) == "function" then
        local ok, value = pcall(GA.L, GA, key, ...)
        if ok and type(value) == "string" and value ~= "" and value ~= key then return value end
    end
    local ok, value = pcall(string.format, fallback, ...)
    return ok and value or fallback
end

function ProfileWindow:EnsureFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "MasterLooterProfileWindow", UIParent)
    frame:SetWidth(520); frame:SetHeight(460); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Profile verwalten"); Theme:MakeMovable(frame, "profileWindow"); Theme:RestorePosition(frame, "profileWindow", "CENTER", 0, 0); Theme:RegisterForEscape(frame); self.frame = frame
    local input = Theme:CreateEditBox(frame, 240, 24); input:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -52); self.nameEdit = input
    local create = Theme:CreateButton(frame, "Neu", 70, 24); create:SetPoint("LEFT", input, "RIGHT", 8, 0); create:SetScript("OnClick", function() ProfileWindow:Create() end)
    local copy = Theme:CreateButton(frame, "Kopieren", 88, 24); copy:SetPoint("LEFT", create, "RIGHT", 8, 0); copy:SetScript("OnClick", function() ProfileWindow:Copy() end)
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -88); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 96); Theme:ApplyInset(list); self.list = list
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(30); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -10 - (index - 1) * 31); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -10 - (index - 1) * 31); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.label = Theme:CreateLabel(row, "", 12); row.label:SetPoint("LEFT", row, "LEFT", 8, 0); row:SetScript("OnClick", function() ProfileWindow:Select(row.name) end); self.rows[index] = row
    end
    local activate = Theme:CreateButton(frame, "Aktivieren", 95, 26); activate:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 50); activate:SetScript("OnClick", function() ProfileWindow:Activate() end)
    local rename = Theme:CreateButton(frame, "Umbenennen", 105, 26); rename:SetPoint("LEFT", activate, "RIGHT", 8, 0); rename:SetScript("OnClick", function() ProfileWindow:Rename() end)
    local remove = Theme:CreateButton(frame, "Löschen", 90, 26); remove:SetPoint("LEFT", rename, "RIGHT", 8, 0); remove:SetScript("OnClick", function() ProfileWindow:Delete() end); self.deleteButton = remove
    local status = Theme:CreateLabel(frame, "", 11, Theme.colors.muted); status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.status = status
    return frame
end
function ProfileWindow:SetStatus(text, errorState) self.status:SetText(text or ""); self.status:SetTextColor(unpack(errorState and Theme.colors.red or Theme.colors.green)) end
function ProfileWindow:Refresh()
    self.names = GA.Profiles:List(); local active = GA.Profiles:GetActive()
    for index, row in ipairs(self.rows) do local name = self.names[index]; if name then row.name = name; row.label:SetText(name .. (name == active and "  |cff33ff99(aktiv)|r" or "")); row:Show() else row.name = nil; row:Hide() end end
end
function ProfileWindow:Select(name) self.selected = name; self.nameEdit:SetText(name or ""); self:SetStatus("Ausgewählt: " .. tostring(name or "–")) end
function ProfileWindow:Create() local value, err = GA.Profiles:Create(self.nameEdit:GetText()); self:SetStatus(value and "Profil erstellt." or err, not value); self:Refresh() end
function ProfileWindow:Copy() if not self.selected then return self:SetStatus("Zuerst ein Profil wählen.", true) end local value, err = GA.Profiles:Copy(self.selected, self.nameEdit:GetText()); self:SetStatus(value and "Profil kopiert." or err, not value); self:Refresh() end
function ProfileWindow:Activate() if not self.selected then return self:SetStatus("Zuerst ein Profil wählen.", true) end local ok, err = GA.Profiles:Activate(self.selected); self:SetStatus(ok and "Profil aktiviert; /reload empfohlen." or err, not ok); self:Refresh() end
function ProfileWindow:Rename() if not self.selected then return self:SetStatus("Zuerst ein Profil wählen.", true) end local ok, err = GA.Profiles:Rename(self.selected, self.nameEdit:GetText()); if ok then self.selected = self.nameEdit:GetText() end; self:SetStatus(ok and "Profil umbenannt." or err, not ok); self:Refresh() end
function ProfileWindow:Delete()
    if not self.selected then return self:SetStatus("Zuerst ein Profil wählen.", true) end
    if self.deleteArmed ~= self.selected then self.deleteArmed = self.selected; self.deleteButton:SetText("Bestätigen"); return self:SetStatus(L("PROFILE_DELETE_CONFIRM", "Noch einmal klicken, um %s zu löschen.", self.selected), true) end
    local ok, err = GA.Profiles:Delete(self.selected); self.deleteArmed, self.selected = nil, nil; self.deleteButton:SetText("Löschen"); self:SetStatus(ok and "Profil gelöscht." or err, not ok); self:Refresh()
end
function ProfileWindow:Show() local frame = self:EnsureFrame(); self:Refresh(); frame:Show(); frame:Raise(); return true end
function ProfileWindow:Hide() if self.frame then self.frame:Hide() end end
function ProfileWindow:OnInitialize() self:EnsureFrame(); GA.Events:On("GA_PROFILE_LIST_CHANGED", function() ProfileWindow:Refresh() end, self); return true end
GA:RegisterModule("ProfileWindow", ProfileWindow)
