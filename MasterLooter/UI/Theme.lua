local addonName, GA = ...

GA = GA or _G.MasterLooter or {}
_G.MasterLooter = GA

GA.UI = GA.UI or {}
GA.UI.Theme = GA.UI.Theme or {}

local Theme = GA.UI.Theme

Theme.colors = {
    panel = { 0.055, 0.065, 0.085, 0.96 },
    panelLight = { 0.10, 0.12, 0.16, 0.98 },
    border = { 0.38, 0.31, 0.17, 1 },
    gold = { 1.00, 0.82, 0.20, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    muted = { 0.62, 0.65, 0.70, 1 },
    green = { 0.20, 0.80, 0.30, 1 },
    red = { 0.85, 0.18, 0.18, 1 },
}

local PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}

local INSET_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function Theme:ApplyPanel(frame)
    frame:SetBackdrop(PANEL_BACKDROP)
    frame:SetBackdropColor(unpack(self.colors.panel))
    frame:SetBackdropBorderColor(unpack(self.colors.border))
end

function Theme:ApplyInset(frame)
    frame:SetBackdrop(INSET_BACKDROP)
    frame:SetBackdropColor(unpack(self.colors.panelLight))
    frame:SetBackdropBorderColor(0.30, 0.30, 0.34, 1)
end

function Theme:CreateLabel(parent, text, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", size and size >= 14 and "GameFontNormalLarge" or "GameFontNormal")
    local nativeSetText = label.SetText
    label.SetText = function(self, value)
        return nativeSetText(self, type(GA.Localize) == "function" and GA:Localize(value or "") or (value or ""))
    end
    label:SetText(text or "")
    label:SetTextColor(unpack(color or self.colors.text))
    label:SetJustifyH("LEFT")
    return label
end

function Theme:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 90)
    button:SetHeight(height or 24)
    local nativeSetText = button.SetText
    button.SetText = function(self, value)
        return nativeSetText(self, type(GA.Localize) == "function" and GA:Localize(value or "") or (value or ""))
    end
    button:SetText(text or "")
    return button
end

function Theme:CreateEditBox(parent, width, height, numeric)
    -- Ascension's 3.3.5a InputBoxTemplate can render its middle texture above
    -- the edit text.  That leaves only the first and last characters visible.
    -- A self-contained inset avoids client-template draw-order differences.
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetWidth(width or 120)
    edit:SetHeight(height or 22)
    self:ApplyInset(edit)
    if type(edit.SetFontObject) == "function" and _G.ChatFontNormal then
        edit:SetFontObject(_G.ChatFontNormal)
    elseif type(edit.SetFont) == "function" and _G.STANDARD_TEXT_FONT then
        edit:SetFont(_G.STANDARD_TEXT_FONT, 12, "")
    end
    if type(edit.SetTextColor) == "function" then edit:SetTextColor(unpack(self.colors.text)) end
    edit:SetAutoFocus(false)
    edit:SetTextInsets(7, 7, 0, 0)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if numeric then
        edit:SetNumeric(true)
    end
    return edit
end

function Theme:AddTitle(frame, text)
    local title = self:CreateLabel(frame, text, 14, self.colors.gold)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -14)
    title:SetJustifyH("CENTER")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    return title, close
end

local function fallbackPositionStore()
    if type(_G.MasterLooterDB) ~= "table" then
        _G.MasterLooterDB = {}
    end
    local db = _G.MasterLooterDB
    db.ui = db.ui or {}
    db.ui.positions = db.ui.positions or {}
    return db.ui.positions
end

local function profilePosition(key)
    if type(GA.DB) == "table" and type(GA.DB.GetProfile) == "function" then
        local ok, profile = pcall(GA.DB.GetProfile, GA.DB)
        if ok and type(profile) == "table" then
            profile[key] = profile[key] or {}
            return profile[key]
        end
    end
    local store = fallbackPositionStore()
    store[key] = store[key] or {}
    return store[key]
end

function Theme:SavePosition(frame, key)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    local saved = profilePosition(key)
    saved.point = point
    saved.relativePoint = relativePoint
    saved.x = math.floor((x or 0) + 0.5)
    saved.y = math.floor((y or 0) + 0.5)
end

function Theme:RestorePosition(frame, key, defaultPoint, defaultX, defaultY)
    local saved = profilePosition(key)
    frame:ClearAllPoints()
    if saved and saved.point and saved.relativePoint then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint(defaultPoint or "CENTER", UIParent, defaultPoint or "CENTER", defaultX or 0, defaultY or 0)
    end
end

function Theme:MakeMovable(frame, key)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Theme:SavePosition(self, key)
    end)
end

function Theme:RegisterForEscape(frame)
    local name = frame:GetName()
    if not name then return end
    for _, registered in ipairs(UISpecialFrames) do
        if registered == name then return end
    end
    table.insert(UISpecialFrames, name)
end

function Theme:SetItemTooltip(widget, itemLink)
    widget.itemLink = itemLink
    widget:SetScript("OnEnter", function(self)
        self.itemTooltipShift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and true or false
        Theme:ShowItemTooltip(self, self.itemLink)
    end)
    widget:SetScript("OnLeave", function(self)
        self.itemTooltipShift = nil
        Theme:HideOwnedTooltip(self)
    end)
    widget.UpdateTooltip = function(self)
        local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and true or false
        if self.itemTooltipShift == shift then return end
        self.itemTooltipShift = shift
        Theme:HideOwnedTooltip(self)
        Theme:ShowItemTooltip(self, self.itemLink)
    end
end

function Theme:GetTooltip()
    if self.tooltip then return self.tooltip end
    local tooltip = _G.MasterLooterTooltip
    if not tooltip and type(CreateFrame) == "function" then
        local ok, created = pcall(CreateFrame, "GameTooltip", "MasterLooterTooltip", UIParent, "GameTooltipTemplate")
        if ok then tooltip = created end
    end
    self.tooltip = tooltip
    return tooltip
end

function Theme:ShowItemTooltip(owner, itemLink, anchor)
    if not owner or type(itemLink) ~= "string" or itemLink == "" then return false end
    local tooltip = self:GetTooltip()
    if not tooltip then return false end
    tooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tooltip:SetHyperlink(itemLink)
    tooltip:Show()
    local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and true or false
    if shift and type(GameTooltip_ShowCompareItem) == "function" then
        if type(tooltip.shoppingTooltips) ~= "table" then
            local source = _G.GameTooltip and _G.GameTooltip.shoppingTooltips
            if type(source) == "table" then
                tooltip.shoppingTooltips = source
            elseif _G.ShoppingTooltip1 and _G.ShoppingTooltip2 and _G.ShoppingTooltip3 then
                tooltip.shoppingTooltips = { _G.ShoppingTooltip1, _G.ShoppingTooltip2, _G.ShoppingTooltip3 }
            end
        end
        if type(tooltip.shoppingTooltips) == "table" and #tooltip.shoppingTooltips >= 3 then
            pcall(GameTooltip_ShowCompareItem, tooltip, true)
        end
    end
    return true
end

function Theme:ShowTextTooltip(owner, lines, anchor)
    if not owner then return false end
    local tooltip = self:GetTooltip()
    if not tooltip then return false end
    tooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
    for index = 1, #(lines or {}) do
        local line = lines[index]
        if type(line) == "table" then
            tooltip:AddLine(tostring(type(GA.Localize) == "function" and GA:Localize(line[1] or "") or (line[1] or "")), line[2] or 1, line[3] or 1, line[4] or 1)
        else
            tooltip:AddLine(tostring(type(GA.Localize) == "function" and GA:Localize(line) or line), 1, 1, 1)
        end
    end
    tooltip:Show()
    return true
end

function Theme:HideOwnedTooltip(owner)
    local tooltip = self.tooltip
    if not tooltip or type(tooltip.Hide) ~= "function" then return false end
    if type(tooltip.GetOwner) == "function" and tooltip:GetOwner() ~= owner then return false end
    tooltip:Hide()
    return true
end

function Theme:BeginItemDrag(itemLink)
    if type(itemLink) ~= "string" or not string.find(itemLink, "|Hitem:", 1, true) then return false end
    GA.UI.draggedItem = {
        link = itemLink,
        startedAt = type(GetTime) == "function" and GetTime() or 0,
    }
    if type(SetCursor) == "function" then pcall(SetCursor, "INSPECT_CURSOR") end
    return true
end

function Theme:TakeDraggedItem()
    local payload = GA.UI.draggedItem
    GA.UI.draggedItem = nil
    if type(payload) ~= "table" or type(payload.link) ~= "string" then return nil end
    if payload.startedAt and payload.startedAt > 0 and type(GetTime) == "function" and GetTime() - payload.startedAt > 10 then
        return nil
    end
    return payload.link
end

function Theme:FormatTime(seconds)
    seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
