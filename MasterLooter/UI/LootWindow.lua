local _, GA = ...

GA.UI = GA.UI or {}
local Theme = GA.UI.Theme

local LootWindow = { page = 1, pageSize = 8, hookedButtons = {} }
GA.UI.LootWindow = LootWindow

local function snapshotFromEvent(...)
    if select(2, ...) == "GA_LOOT_OPENED" or select(2, ...) == "GA_LOOT_UPDATED" or select(2, ...) == "GA_LOOT_CLOSED" then
        return select(3, ...)
    end
    return select(1, ...)
end

function LootWindow:EnsureFrame()
    if self.frame then return self.frame end
    if not Theme then return nil end
    local frame = CreateFrame("Frame", "MasterLooterLootWindow", UIParent)
    frame:SetWidth(560); frame:SetHeight(420); frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true); frame:Hide()
    Theme:ApplyPanel(frame); Theme:AddTitle(frame, "MasterLooter – Erfasster Loot")
    Theme:MakeMovable(frame, "lootWindow"); Theme:RestorePosition(frame, "lootWindow", "CENTER", -120, 30)
    Theme:RegisterForEscape(frame); self.frame = frame

    local status = Theme:CreateLabel(frame, "Kein Lootfenster geöffnet.", 12, Theme.colors.muted)
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -45); status:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    self.status = status
    local refresh = Theme:CreateButton(frame, "Aktualisieren", 105, 24)
    refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -39)
    refresh:SetScript("OnClick", function() LootWindow:Refresh(GA.Loot:GetSnapshot()) end)

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -76); list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 105)
    Theme:ApplyInset(list); self.list = list
    for _, data in ipairs({ { "Slot", 10 }, { "Item", 65 }, { "Anzahl", 390 }, { "Status", 455 } }) do
        local label = Theme:CreateLabel(list, data[1], 12, Theme.colors.gold); label:SetPoint("TOPLEFT", list, "TOPLEFT", data[2], -10)
    end
    self.rows = {}
    for index = 1, self.pageSize do
        local row = CreateFrame("Button", nil, list); row:SetHeight(29)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -31 - (index - 1) * 29); row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -7, -31 - (index - 1) * 29)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.slot = Theme:CreateLabel(row, "", 12); row.slot:SetPoint("LEFT", row, "LEFT", 4, 0); row.slot:SetWidth(50)
        row.item = Theme:CreateLabel(row, "", 12); row.item:SetPoint("LEFT", row, "LEFT", 59, 0); row.item:SetWidth(315)
        row.quantity = Theme:CreateLabel(row, "", 12); row.quantity:SetPoint("LEFT", row, "LEFT", 384, 0); row.quantity:SetWidth(55)
        row.state = Theme:CreateLabel(row, "", 12); row.state:SetPoint("LEFT", row, "LEFT", 449, 0); row.state:SetWidth(55)
        row:SetScript("OnClick", function(_, button)
            LootWindow:Select(row.record)
            if button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then LootWindow:UseSelected() end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:RegisterForDrag("LeftButton")
        row:SetScript("OnDragStart", function(self)
            if self.record and self.record.link then Theme:BeginItemDrag(self.record.link) end
        end)
        row:SetScript("OnEnter", function(self) if self.record and self.record.link then Theme:ShowItemTooltip(self, self.record.link) end end)
        row:SetScript("OnLeave", function(self) Theme:HideOwnedTooltip(self) end)
        self.rows[index] = row
    end

    local previous = Theme:CreateButton(frame, "<", 35, 23); previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 72)
    previous:SetScript("OnClick", function() LootWindow.page = math.max(1, LootWindow.page - 1); LootWindow:Refresh() end); self.previous = previous
    local page = Theme:CreateLabel(frame, "1 / 1", 12, Theme.colors.muted); page:SetPoint("LEFT", previous, "RIGHT", 8, 0); self.pageLabel = page
    local nextButton = Theme:CreateButton(frame, ">", 35, 23); nextButton:SetPoint("LEFT", page, "RIGHT", 8, 0)
    nextButton:SetScript("OnClick", function() LootWindow.page = math.min(LootWindow.totalPages or 1, LootWindow.page + 1); LootWindow:Refresh() end); self.next = nextButton

    local selected = Theme:CreateLabel(frame, "Auswahl: –", 12); selected:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 45); selected:SetWidth(330); self.selectedLabel = selected
    local use = Theme:CreateButton(frame, "In Lootmaster", 125, 27); use:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 14)
    use:SetScript("OnClick", function() LootWindow:UseSelected() end); use:Disable(); self.useButton = use
    local mule = Theme:CreateButton(frame, "Für PackMule", 125, 27); mule:SetPoint("LEFT", use, "RIGHT", 8, 0)
    mule:SetScript("OnClick", function() LootWindow:AddToPackMule() end); mule:Disable(); self.muleButton = mule
    local target = Theme:CreateEditBox(frame, 130, 24); target:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 16); self.targetEdit = target
    local targetLabel = Theme:CreateLabel(frame, "PackMule-Ziel", 12, Theme.colors.muted); targetLabel:SetPoint("BOTTOM", target, "TOP", 0, 3)
    target:SetScript("OnEnterPressed", function(self) GA.PackMule:SetTarget(self:GetText()); self:ClearFocus(); LootWindow:SetStatus("PackMule-Ziel gespeichert.", Theme.colors.green) end)
    return frame
end

function LootWindow:SetStatus(text, color)
    self.status:SetText(text or ""); self.status:SetTextColor(unpack(color or Theme.colors.muted))
end

function LootWindow:Select(record)
    if not record or record.cleared then return end
    self.selected = record; self.selectedLabel:SetText("Auswahl: " .. (record.link or record.name or ("Slot " .. record.slot)))
    self.useButton:Enable(); self.muleButton:Enable()
end

function LootWindow:Refresh(snapshot)
    self.snapshot = snapshot or self.snapshot or (GA.Loot and GA.Loot:GetSnapshot()) or { order = {}, slots = {} }
    if not self.frame or (type(self.frame.IsShown) == "function" and not self.frame:IsShown()) then return end
    local order = self.snapshot.order or {}; self.totalPages = math.max(1, math.ceil(#order / self.pageSize)); self.page = math.min(self.page, self.totalPages)
    local offset = (self.page - 1) * self.pageSize
    for index, row in ipairs(self.rows) do
        local slot = order[offset + index]; local record = slot and self.snapshot.slots[slot]
        if record then
            row.record = record; row.slot:SetText(tostring(record.slot)); row.item:SetText(record.link or record.name or "Unbekannt")
            row.quantity:SetText(tostring(record.quantity or 1)); row.state:SetText(record.cleared and "Entfernt" or (record.locked and "Gesperrt" or "Bereit")); row:Show()
        else row.record = nil; row:Hide() end
    end
    self.pageLabel:SetText(self.page .. " / " .. self.totalPages)
    if self.page > 1 then self.previous:Enable() else self.previous:Disable() end
    if self.page < self.totalPages then self.next:Enable() else self.next:Disable() end
    self:SetStatus(self.snapshot.open and (#order .. " Lootslots erfasst.") or "Lootfenster geschlossen.")
    if GA.PackMule and GA.PackMule:GetTarget() then self.targetEdit:SetText(GA.PackMule:GetTarget()) end
end

function LootWindow:UseSelected()
    if not self.selected or not self.selected.link then return end
    local queued, err = GA.Loot:QueueSlot(self.selected, "LOOT_SELECTION")
    if not queued then self:SetStatus(err, Theme.colors.red); return end
    local window = GA.UI.MasterLooterWindow; if not window then return end
    window.sourceLoot = { queueID = queued.id, generation = queued.generation, slot = queued.slot, itemLink = queued.itemLink }
    window:Show(); if type(window.SetItem) == "function" then window:SetItem(self.selected.link) end
    self:SetStatus("Item in das Lootmaster-Fenster übernommen.", Theme.colors.green)
end

function LootWindow:GetButtonSlot(button)
    if not button then return nil end
    local explicit = tonumber(button.slot) or tonumber(button.lootSlot) or tonumber(button.slotIndex)
    local slot = explicit or (type(button.GetID) == "function" and tonumber(button:GetID()))
    if slot and not explicit and _G.LootFrame and tonumber(_G.LootFrame.page) and _G.LootFrame.page > 1 then
        slot = slot + ((_G.LootFrame.page - 1) * (tonumber(_G.LOOTFRAME_NUMBUTTONS) or 4))
    end
    return slot
end

function LootWindow:OpenLootItem(button, mouseButton)
    mouseButton = mouseButton or _G.arg1
    if mouseButton ~= "RightButton" or type(IsControlKeyDown) ~= "function" or not IsControlKeyDown() then return false end
    local slot = self:GetButtonSlot(button)
    local record = slot and GA.Loot:GetSlot(slot)
    if slot and (not record or record.cleared or not record.link) and type(GetLootSlotLink) == "function" then
        local link = GetLootSlotLink(slot)
        if link then
            local quantity = 1
            if type(GetLootSlotInfo) == "function" then local _, _, count = GetLootSlotInfo(slot); quantity = tonumber(count) or 1 end
            record = { slot = slot, link = link, itemID = GA.Compat:GetItemID(link), quantity = quantity,
                capturedAt = type(GetTime) == "function" and GetTime() or 0 }
        end
    end
    if not record or record.cleared or not record.link then return false end
    self:Select(record)
    self:UseSelected()
    if GA.Trace then GA:Trace("INPUT", "CTRL_RIGHTCLICK_LOOT", slot, record.link) end
    return true
end

function LootWindow:InstallLootButtonHooks()
    self.nativeButtonHooks = self.nativeButtonHooks or {}
    local installed = false
    local count = math.max(tonumber(_G.LOOTFRAME_NUMBUTTONS) or 4, 4)
    local function install(button)
        if not button or self.nativeButtonHooks[button] or type(button.GetScript) ~= "function" or
            type(button.SetScript) ~= "function" then return end
        local original = button:GetScript("OnClick")
        if type(original) ~= "function" then return end
        local wrapper = function(self, mouseButton, ...)
            if LootWindow:OpenLootItem(self, mouseButton or _G.arg1) then return true end
            return original(self, mouseButton, ...)
        end
        self.nativeButtonHooks[button] = { original = original, wrapper = wrapper }
        button:SetScript("OnClick", wrapper)
        if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        installed = true
    end
    for index = 1, count do
        install(_G["LootButton" .. index])
        install(_G["LootFrameItem" .. index])
    end
    return installed
end

function LootWindow:InstallLootClickHooks()
    self.nativeClickHooks = self.nativeClickHooks or {}
    local installed = false
    local function createWrapper(original)
        return function(button, mouseButton, ...)
            if LootWindow:OpenLootItem(button, mouseButton) then return true end
            return original(button, mouseButton, ...)
        end
    end
    for _, functionName in ipairs({ "LootFrameItem_OnClick", "LootButton_OnClick" }) do
        local original = _G[functionName]
        if type(original) == "function" and not self.nativeClickHooks[functionName] then
            local wrapper = createWrapper(original)
            self.nativeClickHooks[functionName] = { original = original, wrapper = wrapper }
            _G[functionName] = wrapper
            installed = true
        end
    end
    return installed
end

function LootWindow:RemoveLootClickHooks()
    for functionName, hook in pairs(self.nativeClickHooks or {}) do
        if _G[functionName] == hook.wrapper then _G[functionName] = hook.original end
    end
    self.nativeClickHooks = {}
    for button, hook in pairs(self.nativeButtonHooks or {}) do
        if type(button.GetScript) == "function" and type(button.SetScript) == "function" and
            button:GetScript("OnClick") == hook.wrapper then button:SetScript("OnClick", hook.original) end
    end
    self.nativeButtonHooks = {}
end

function LootWindow:AddToPackMule()
    if not self.selected or not self.selected.link then return end
    local target = self.targetEdit:GetText(); if target and target ~= "" then GA.PackMule:SetTarget(target) end
    local entry, err = GA.PackMule:Add(self.selected.link, self.selected.quantity, "LOOT_SLOT_" .. tostring(self.selected.slot))
    if entry then self:SetStatus("Für PackMule vorgemerkt.", Theme.colors.green) else self:SetStatus(err, Theme.colors.red) end
end

function LootWindow:Show() local frame = self:EnsureFrame(); if frame then self:Refresh(); frame:Show() end end
function LootWindow:Hide() if self.frame then self.frame:Hide() end end
function LootWindow:Toggle() local frame = self:EnsureFrame(); if frame:IsShown() then self:Hide() else self:Show() end end
function LootWindow:OnInitialize()
    -- Capture every loot source in the background. Opening this management
    -- window is an explicit user action via /ml loot or the launcher menu.
    GA.Events:On("GA_LOOT_OPENED", function(...)
        LootWindow:InstallLootClickHooks()
        LootWindow:InstallLootButtonHooks()
        LootWindow:Refresh(snapshotFromEvent(...))
    end, self)
    GA.Events:On("GA_LOOT_UPDATED", function(...) LootWindow:Refresh(snapshotFromEvent(...)) end, self)
    GA.Events:On("GA_LOOT_CLOSED", function(...) LootWindow:Refresh(snapshotFromEvent(...)) end, self)
    GA.Events:On("GA_PACKMULE_TARGET_CHANGED", function(_, _, target) if LootWindow.targetEdit then LootWindow.targetEdit:SetText(target or "") end end, self)
    self:InstallLootClickHooks()
    self:InstallLootButtonHooks()
    return true
end

function LootWindow:OnEnable()
    self:InstallLootClickHooks()
    self:InstallLootButtonHooks()
end

LootWindow.OnDisable = LootWindow.RemoveLootClickHooks

GA:RegisterModule("LootWindow", LootWindow)
