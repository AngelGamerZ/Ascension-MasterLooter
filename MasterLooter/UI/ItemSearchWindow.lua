local _, GA = ...
GA.UI = GA.UI or {}
local Theme, ItemSearchWindow = GA.UI.Theme, { rows = {}, pageSize = 10, results = {} }
GA.UI.ItemSearchWindow = ItemSearchWindow

function ItemSearchWindow:EnsureFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "MasterLooterItemSearchWindow", UIParent)
    frame:SetWidth(720); frame:SetHeight(520); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "Ascension-Itemsuche"); Theme:MakeMovable(frame, "itemSearchWindow"); Theme:RestorePosition(frame, "itemSearchWindow", "CENTER", 0, 0); Theme:RegisterForEscape(frame); self.frame = frame
    local search = Theme:CreateEditBox(frame, 330, 25); search:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -52); search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ItemSearchWindow:Search() end); self.searchEdit = search
    local quality = Theme:CreateEditBox(frame, 48, 25, true); quality:SetPoint("LEFT", search, "RIGHT", 8, 0); quality:SetText("0"); self.qualityEdit = quality
    local level = Theme:CreateEditBox(frame, 58, 25, true); level:SetPoint("LEFT", quality, "RIGHT", 8, 0); level:SetText("0"); self.levelEdit = level
    local button = Theme:CreateButton(frame, "Suchen", 88, 25); button:SetPoint("LEFT", level, "RIGHT", 8, 0); button:SetScript("OnClick", function() ItemSearchWindow:Search() end)
    local hints = Theme:CreateLabel(frame, "Name/ID   ·   Qualität ab   ·   Itemlevel ab", 10, Theme.colors.muted); hints:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 2, -3)
    local list = CreateFrame("Frame", nil, frame); list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -100); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 60); Theme:ApplyInset(list); self.list = list
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(32); row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -10 - (index - 1) * 33); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -10 - (index - 1) * 33); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.name = Theme:CreateLabel(row, "", 11); row.name:SetPoint("LEFT", row, "LEFT", 6, 0); row.name:SetWidth(430); row.meta = Theme:CreateLabel(row, "", 10, Theme.colors.muted); row.meta:SetPoint("RIGHT", row, "RIGHT", -6, 0); row.meta:SetWidth(210); row.meta:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function() ItemSearchWindow:Use(row.entry) end); row:SetScript("OnEnter", function(self) if self.entry and self.entry.link then Theme:ShowItemTooltip(self, self.entry.link) end end); row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end); self.rows[index] = row
    end
    local status = Theme:CreateLabel(frame, "Der Index lernt echte Ascension-Items aus Client, Taschen, Chat und AtlasLoot.", 11, Theme.colors.muted); status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 22); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0); self.status = status
    return frame
end
function ItemSearchWindow:Search()
    local query = self.searchEdit:GetText(); self.results = GA.ItemData:Search(query, self.pageSize, { minimumQuality = tonumber(self.qualityEdit:GetText()) or 0, minimumLevel = tonumber(self.levelEdit:GetText()) or 0 })
    for index, row in ipairs(self.rows) do local entry = self.results[index]; if entry then row.entry = entry; row.name:SetText(entry.link or ("[" .. tostring(entry.name or entry.itemID) .. "]")); row.meta:SetText("ID " .. tostring(entry.itemID) .. " · iLvl " .. tostring(entry.itemLevel or "?") .. (entry.familyID and (" · Familie " .. tostring(entry.familyID)) or "")); row:Show() else row.entry = nil; row:Hide() end end
    local stats = GA.ItemData:GetStats(); self.status:SetText(tostring(#self.results) .. " Treffer · Index " .. tostring(stats.items or 0) .. " Items / " .. tostring(stats.verified or 0) .. " verifiziert")
end
function ItemSearchWindow:Use(entry)
    if not entry then return end
    local link = entry.link
    if not link and type(GetItemInfo) == "function" then link = select(2, GetItemInfo(entry.itemID)) end
    if link and GA.UI.MasterLooterWindow then GA.UI.MasterLooterWindow:Show(); GA.UI.MasterLooterWindow:SetItem(link); self.status:SetText("Item in den Lootmaster übernommen.") else self.status:SetText("Itemlink ist im Client noch nicht geladen.") end
end
function ItemSearchWindow:Show() local frame = self:EnsureFrame(); local stats = GA.ItemData:GetStats(); self.status:SetText("Index: " .. tostring(stats.items or 0) .. " Items. Suche nach Name oder ID."); frame:Show(); frame:Raise(); return true end
function ItemSearchWindow:Hide() if self.frame then self.frame:Hide() end end
function ItemSearchWindow:OnInitialize() self:EnsureFrame(); return true end
GA:RegisterModule("ItemSearchWindow", ItemSearchWindow)
