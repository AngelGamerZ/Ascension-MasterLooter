-- Standalone 3.3.5a UI simulation for the loot-master window.
-- It deliberately exercises construction, geometry and state transitions
-- without requiring a running WoW client.
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    if not value then error("ASSERTION FAILED: " .. tostring(message), 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, (message or "values differ") ..
        " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local created, sequence = {}, 0
local pointFactor = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function widget(kind, name, parent)
    sequence = sequence + 1
    local object = {
        kind = kind or "Frame", name = name, parent = parent, shown = true,
        enabled = true, mouseEnabled = true, text = "", width = nil, height = nil,
        points = {}, scripts = {}, children = {}, sequence = sequence,
    }
    created[#created + 1] = object
    if parent and parent.children then parent.children[#parent.children + 1] = object end
    function object:GetName() return self.name end
    function object:GetParent() return self.parent end
    function object:SetWidth(value) self.width = tonumber(value) end
    function object:SetHeight(value) self.height = tonumber(value) end
    function object:GetWidth() return self.width or 0 end
    function object:GetHeight() return self.height or 0 end
    function object:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "string" then x, y, relativePoint, relative = relativePoint, x, relative, self.parent end
        relative = type(relative) == "table" and relative or self.parent
        relativePoint = relativePoint or point
        self.points[#self.points + 1] = { point, relative, relativePoint, tonumber(x) or 0, tonumber(y) or 0 }
    end
    function object:ClearAllPoints() self.points = {} end
    function object:SetAllPoints(relative)
        relative = relative or self.parent
        self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
    end
    function object:SetScript(event, callback) self.scripts[event] = callback end
    function object:GetScript(event) return self.scripts[event] end
    function object:RegisterEvent() end
    function object:RegisterForClicks() end
    function object:RegisterForDrag() end
    function object:SetFrameStrata() end
    function object:SetToplevel() end
    function object:SetClampedToScreen() end
    function object:SetBackdrop() end
    function object:SetBackdropColor() end
    function object:SetBackdropBorderColor(...) self.borderColor = { ... } end
    function object:SetHighlightTexture() end
    function object:SetTexture(value) self.texture = value end
    function object:SetTexCoord() end
    function object:SetJustifyH() end
    function object:SetJustifyV() end
    function object:SetWordWrap() end
    function object:SetTextColor(...) self.textColor = { ... } end
    function object:SetAutoFocus() end
    function object:SetTextInsets() end
    function object:SetNumeric() end
    function object:SetMaxLetters(value) self.maxLetters = value end
    function object:SetMovable() end
    function object:EnableMouse(value) self.mouseEnabled = value ~= false end
    function object:SetText(value) self.text = tostring(value or "") end
    function object:GetText() return self.text end
    function object:ClearFocus() self.focused = false end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:IsShown() return self.shown end
    function object:Enable() self.enabled = true end
    function object:Disable() self.enabled = false end
    function object:LockHighlight() self.highlighted = true end
    function object:UnlockHighlight() self.highlighted = false end
    function object:GetFontString() return self.fontString end
    function object:CreateFontString()
        return widget("FontString", nil, self)
    end
    function object:CreateTexture()
        return widget("Texture", nil, self)
    end
    return object
end

local function anchoredAxis(object, axis, stack)
    stack = stack or {}
    if stack[object] then error("cyclic UI anchor") end
    stack[object] = true
    if object == UIParent then stack[object] = nil; return 0, axis == 1 and 1920 or 1080 end
    local equations = {}
    for _, anchor in ipairs(object.points) do
        local point, relative, relativePoint, x, y = unpack(anchor)
        local relativeStart, relativeSize = anchoredAxis(relative or object.parent or UIParent, axis, stack)
        local ownFactor = pointFactor[point][axis]
        local relativeFactor = pointFactor[relativePoint][axis]
        equations[#equations + 1] = {
            factor = ownFactor,
            target = relativeStart + relativeFactor * relativeSize + (axis == 1 and x or y),
        }
    end
    local size
    if axis == 1 then size = object.width else size = object.height end
    if not size then
        for first = 1, #equations do
            for second = first + 1, #equations do
                local delta = equations[second].factor - equations[first].factor
                if delta ~= 0 then
                    size = (equations[second].target - equations[first].target) / delta
                    break
                end
            end
            if size then break end
        end
    end
    size = size or 0
    local start
    if equations[1] then start = equations[1].target - equations[1].factor * size
    else
        local parentStart = anchoredAxis(object.parent or UIParent, axis, stack)
        start = parentStart
    end
    stack[object] = nil
    return start, size
end

local function rect(object)
    local left, width = anchoredAxis(object, 1)
    local bottom, height = anchoredAxis(object, 2)
    return { left = left, right = left + width, bottom = bottom, top = bottom + height, width = width, height = height }
end

local function inside(inner, outer, message)
    local child, parent = rect(inner), rect(outer)
    expect(child.left >= parent.left - 0.01 and child.right <= parent.right + 0.01 and
        child.bottom >= parent.bottom - 0.01 and child.top <= parent.top + 0.01,
        message .. string.format(" (child %.1f/%.1f/%.1f/%.1f; parent %.1f/%.1f/%.1f/%.1f)",
            child.left, child.right, child.bottom, child.top, parent.left, parent.right, parent.bottom, parent.top))
end

local function separated(leftObject, rightObject, message)
    local left, right = rect(leftObject), rect(rightObject)
    expect(left.right <= right.left + 0.01, message .. " (" .. tostring(left.right) .. " > " .. tostring(right.left) .. ")")
end

UIParent = widget("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080
UISpecialFrames = {}
unpack = unpack or table.unpack
function CreateFrame(kind, name, parent) return widget(kind, name, parent or UIParent) end
function GetItemInfo() return nil, nil, nil, nil, nil, nil, nil, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark" end
function ClearCursor() end

local callbacks = {}
local profile = { defaultRollDuration = 30, osRollMaximum = 99, autoGiveAwards = true }
local GA = {
    UI = {}, modules = {},
    DB = { GetProfile = function() return profile end },
    Events = {
        On = function(_, event, callback)
            callbacks[event] = callbacks[event] or {}
            callbacks[event][#callbacks[event] + 1] = callback
        end,
    },
    Compat = {},
    PlusOnes = {
        values = {},
        Get = function(self, player) return self.values[player] or 0 end,
        GetStats = function() return { total = 0, MS = 0, OS = 0 } end,
        Add = function(self, player, amount) self.values[player] = (self.values[player] or 0) + amount; return self.values[player] end,
    },
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:Trace() end
function GA:Localize(text)
    local english = {
        ["Ziehen · Rechtsklick entfernt"] = "Drag · right-click removes",
        ["Aus Tasche oder Lootfenster ziehen · Rechtsklick entfernt"] = "Drag from bags or loot window · right-click removes",
        ["Ausgewählt · Rechtsklick entfernt · Tooltip beim Darüberfahren"] = "Selected · right-click removes · hover for tooltip",
    }
    return english[text] or text
end

local colors = {
    panel = { 0, 0, 0, 1 }, panelLight = { 0, 0, 0, 1 }, border = { 1, 1, 1, 1 },
    gold = { 1, 1, 0, 1 }, text = { 1, 1, 1, 1 }, muted = { 0.5, 0.5, 0.5, 1 },
    green = { 0, 1, 0, 1 }, red = { 1, 0, 0, 1 },
}
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:ApplyInset() end
function Theme:CreateLabel(parent, text, fontSize)
    local value = parent:CreateFontString()
    local nativeSetText = value.SetText
    value.SetText = function(self, nextText) nativeSetText(self, GA:Localize(nextText)) end
    value:SetText(text)
    value.width = math.max(1, string.len(tostring(value:GetText() or "")) * ((fontSize or 12) * 0.55))
    value.height = (fontSize or 12) + 3
    return value
end
function Theme:CreateButton(parent, text, width, height)
    local value = widget("Button", nil, parent)
    value.width, value.height = width, height
    value:SetText(text)
    value.fontString = widget("FontString", nil, value)
    return value
end
function Theme:CreateEditBox(parent, width, height)
    local value = widget("EditBox", nil, parent)
    value.width, value.height = width, height
    return value
end
function Theme:AddTitle() end
function Theme:MakeMovable() end
function Theme:RestorePosition(frame, _, point, x, y) frame:SetPoint(point or "CENTER", UIParent, point or "CENTER", x or 0, y or 0) end
function Theme:RegisterForEscape() end
function Theme:ShowItemTooltip() end
function Theme:HideOwnedTooltip() end
function Theme:SetItemTooltip(widget, link)
    widget.itemLink = link
    widget:SetScript("OnEnter", function() end)
    widget:SetScript("OnLeave", function() end)
end
function Theme:ShowTextTooltip() end
function Theme:TakeDraggedItem() return nil end
function Theme:FormatTime(seconds) return tostring(seconds or 0) end

local chunk, loadError = loadfile("MasterLooter/UI/MasterLooterWindow.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)
local window = GA.UI.MasterLooterWindow
local frame = window:EnsureFrame()
expect(frame ~= nil, "loot-master frame builds on the simulated 3.3.5a UI")
expect(window.WIDTH <= 600 and window.HEIGHT <= 500 and window.WIDTH > window.HEIGHT,
    "loot-master window stays compact and landscape-oriented")

-- Geometry regression: the old screenshot showed clipped/overlapping inputs and
-- pagination controls. Check the interactive controls against their containers.
for _, control in ipairs({ window.itemDrop, window.startButton, window.stopButton, window.durationEdit,
    window.osMaximumEdit, window.noteEdit, window.tableFrame, window.awardButton }) do
    inside(control, frame, "interactive control stays inside the main window")
end
separated(window.itemDrop, window.startButton, "item drop target does not overlap the start button")
separated(window.startButton, window.stopButton, "start and stop buttons do not overlap")
separated(window.durationEdit, window.osMaximumEdit, "timer and OS maximum inputs remain visually separate")
inside(window.itemHelp, frame, "English item help remains inside the loot-master window")
expect(rect(window.itemHelp).width >= 420, "item help reserves the full row width for English text")
inside(window.previousButton, frame, "previous-page button is visible")
inside(window.nextButton, frame, "next-page button is visible")
for _, row in ipairs(window.rows) do
    inside(row, window.tableFrame, "roll row stays inside the table")
    inside(row.plusOne, row, "+1 button stays inside its player row")
end

-- Initial and input-validation states.
expect(not window.startButton.enabled, "roll start is disabled without an item")
expect(not window.awardButton.enabled, "award is disabled without a selected winner")
local item = "|cffa335ee|Hitem:1985:0:0:0|h[Kam's Buckler]|h|r"
window:SetItem(item)
expect(window.startButton.enabled, "a valid item enables roll start")
same(window.itemHelp:GetText(), "Selected · right-click removes · hover for tooltip", "selected-item help is completely rendered in English")
window.osMaximumEdit:SetText("1")
window:RefreshInputState(true)
expect(not window.startButton.enabled, "invalid OS maximum disables roll start")
window:NormalizeOSMaximum()
same(window.osMaximumEdit:GetText(), "2", "OS maximum is clamped to the documented minimum")
expect(window.startButton.enabled, "normalized OS maximum restores roll start")
window.osMaximumEdit:SetText("50")
window:RefreshInputState(true)
expect(not window.startButton.enabled, "OS /roll 50 is reserved for Transmog")
window:NormalizeOSMaximum()
same(window.osMaximumEdit:GetText(), "49", "reserved OS range normalizes to 49")
expect(window.startButton.enabled, "safe OS maximum restores roll start")

local rollChunk, rollLoadError = loadfile("MasterLooter/UI/RollWindow.lua")
if not rollChunk then error(rollLoadError) end
rollChunk("MasterLooter", GA)
local rollWindow = GA.UI.RollWindow
local rollFrame = rollWindow:EnsureFrame()
expect(rollFrame ~= nil, "participant roll window builds with Transmog support")
expect(rollWindow.buttons.MS and rollWindow.buttons.OS and rollWindow.buttons.TRANSMOG and rollWindow.buttons.PASS,
    "participant roll window exposes all four actions")
for _, button in pairs(rollWindow.buttons) do inside(button, rollFrame, "participant roll action stays inside the compact window") end
rollWindow:ShowSession({ id = "legacy-ui", itemLink = item, duration = 30, expiresAt = 30, osRollMaximum = 99,
    choices = { "MS", "OS", "PASS" } })
expect(not rollWindow.buttons.TRANSMOG.enabled, "a legacy host cannot expose a non-functional Transmog action")
rollWindow:ShowSession({ id = "transmog-ui", itemLink = item, duration = 30, expiresAt = 30, osRollMaximum = 99,
    choices = { "MS", "OS", "TRANSMOG", "PASS" } })
expect(rollWindow.buttons.TRANSMOG.enabled, "a Transmog-capable host enables the new action")
same(rollWindow.buttons.TRANSMOG:GetText(), "Transmog (/50)", "Transmog button shows its public roll range")
local randomMinimum, randomMaximum
RandomRoll = function(minimum, maximum) randomMinimum, randomMaximum = minimum, maximum end
rollWindow:Submit("TRANSMOG")
same(randomMinimum, 1, "Transmog button starts a Blizzard roll at one")
same(randomMaximum, 50, "Transmog button executes /roll 50")

window:UpdateSession({ id = "transmog-master", itemLink = item, status = "ACTIVE", participants = {
    stylist = { name = "Stylist", choice = "TRANSMOG", roll = 44 },
} })
same(window.rows[1].choice:GetText(), "Transmog", "loot-master table displays the Transmog category in full")

-- Winner selection, pagination and manual +1.
local participants = {}
for index = 1, 8 do
    participants["Player" .. index] = {
        name = "Player" .. index, choice = index == 8 and "PASS" or (index % 2 == 0 and "OS" or "MS"),
        roll = 100 - index,
    }
end
window:UpdateSession({ id = "session-one", itemLink = item, status = "ACTIVE", participants = participants })
same(window.totalPages, 2, "more than six responses create a second page")
expect(window.selected == nil, "a roll response is not silently preselected as winner")
expect(not window.awardButton.enabled, "award waits for an explicit player click")
window:SelectRow(1)
expect(window.selected ~= nil and window.selected.choice ~= "PASS", "click selects an eligible response")
expect(window.awardButton.enabled, "clicked eligible winner enables award")
local selectedName = window.selected.player
same(window:AddPlusOne(1), 1, "row +1 button records exactly one manual mark")
same(GA.PlusOnes.values[selectedName], 1, "manual +1 is associated with the selected player")
same(window.selected.player, selectedName, "+1 does not silently change the selected winner")
window:UpdateSession({ id = "session-one", itemLink = item, status = "ACTIVE", participants = participants })
same(window.selected.player, selectedName, "same-session roll updates preserve an explicit winner click")

local passIndex
for index, response in ipairs(window.rolls) do if response.choice == "PASS" then passIndex = index; break end end
window:SelectRow(passIndex)
expect(not window.awardButton.enabled, "a passing player cannot be awarded")
window.page = 2
window:RefreshRows()
same(window.pageLabel:GetText(), "2/2", "pagination reaches the queued second page")

-- A new queued item/session resets stale page and winner state, even when the
-- same player also rolled on the next item.
local repeatedPlayer = window.selected.player
window:UpdateSession({ id = "session-two", itemLink = item, status = "ACTIVE", participants = {
    [repeatedPlayer] = { name = repeatedPlayer, choice = "OS", roll = 42 },
} })
same(window.page, 1, "next queued item cannot remain on an empty old page")
expect(window.selected == nil, "next queued item cannot inherit the previous winner")
expect(not window.awardButton.enabled, "next queued item requires its own winner click")
window:SelectRow(1)
same(window.selected.player, repeatedPlayer, "next item winner can be selected explicitly")
expect(window.awardButton.enabled, "next queued item becomes awardable after selection")

-- Failed direct delivery is a recoverable UI state: keep the selected source
-- and show the real reason instead of silently clearing it.
window.sourceLoot = { slot = 3, generation = 9 }
GA.RollSession = { Award = function() return nil, "Gewinner ist nicht in Vergabereichweite." end }
window:AwardSelected()
expect(string.find(window.status:GetText(), "nicht in Vergabereichweite", 1, true),
    "failed direct award exposes its actionable reason")
expect(window.sourceLoot and window.sourceLoot.slot == 3, "failed direct award keeps the loot source recoverable")

GA.RollSession.Award = function() return { winner = "NextWinner" } end
window:AwardSelected()
expect(string.find(window.status:GetText(), "Vergabe an " .. repeatedPlayer .. " gestartet", 1, true),
    "successful award reports the asynchronous delivery workflow truthfully")
expect(window.sourceLoot == nil, "successful award clears the consumed loot source")
expect(not window.awardButton.enabled, "successful award cannot be submitted twice")

-- Two identical drops use one roll table and two deliberate winner clicks.
local multiState = { id = "multi-copy-session", itemLink = item, status = "STOPPED", awardLimit = 2,
    awards = {}, awardedPlayers = {}, participants = {
        markus = { name = "Markus", choice = "MS", roll = 100 },
        gragu = { name = "Gragu", choice = "MS", roll = 98 },
    } }
GA.RollSession = {
    GetState = function() return multiState end,
    Award = function(_, _, player, choice, roll)
        local index = #multiState.awards + 1
        local result = { sessionID = multiState.id, winner = player, choice = choice, roll = roll,
            awardIndex = index, awardLimit = 2, awardsRemaining = 2 - index, lootSlot = index == 1 and 1 or 2 }
        multiState.awards[index] = result
        multiState.awardedPlayers[string.lower(player)] = result
        multiState.status = result.awardsRemaining > 0 and "STOPPED" or "AWARDED"
        return result
    end,
}
window.sourceLoot = { slot = 1, generation = 10, itemLink = item }
window:UpdateSession(multiState)
window:SelectRow(1)
local firstWinner = window.selected.player
window:AwardSelected()
expect(not window.awardPending, "first identical copy never locks subsequent player selection")
expect(window.sourceLoot ~= nil, "first copy keeps the original roll workflow open")
expect(window.rolls[1].awarded or window.rolls[2].awarded, "first winner is marked as already awarded")
local nextIndex
for index, response in ipairs(window.rolls) do if response.player ~= firstWinner then nextIndex = index; break end end
window:SelectRow(nextIndex)
expect(window.selected and window.selected.player ~= firstWinner,
    "the next-best player is selectable immediately without a loot-window acknowledgement")
expect(window.awardButton.enabled, "immediately selected second winner can be awarded")
window:AwardSelected()
same(#multiState.awards, 2, "two separate clicks award both copies from one roll session")
expect(window.sourceLoot == nil, "the source clears only after every identical copy is awarded")

-- The participant roll widget exposes the item strip as a real Blizzard-style
-- modified-click target instead of a passive font string.
local modifiedClicks, modifiedLink, modifiedButton = 0, nil, nil
IsControlKeyDown = function() return true end
HandleModifiedItemClick = function(link, button)
    modifiedClicks, modifiedLink, modifiedButton = modifiedClicks + 1, link, button
    return true
end
chunk, loadError = loadfile("MasterLooter/UI/RollWindow.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)
local participantWindow = GA.UI.RollWindow
participantWindow:EnsureFrame()
expect(participantWindow.itemInteraction ~= nil, "participant item has a dedicated hover and click surface")
participantWindow.itemLink = item
participantWindow.itemInteraction.scripts.OnClick(participantWindow.itemInteraction, "LeftButton")
same(modifiedClicks, 1, "CTRL-click uses Blizzard's modified-item-click handler")
same(modifiedLink, item, "modified click preserves the complete item hyperlink")
same(modifiedButton, "LeftButton", "modified click forwards the native mouse button")

-- Trade assistant regression: pending work may refresh its data, but must not
-- force a second modal window into the loot master's face.
GA.Trade = {
    GetGrouped = function() return {} end,
    GetGroups = function() return {} end,
    GetState = function() return { status = "IDLE" } end,
}
GA.Award = { GetDeferred = function() return {} end }
chunk, loadError = loadfile("MasterLooter/UI/TradeWindow.lua")
if not chunk then error(loadError) end
chunk("MasterLooter", GA)
local tradeWindow = GA.UI.TradeWindow
tradeWindow:OnInitialize()
expect(not tradeWindow.frame:IsShown(), "trade assistant starts hidden")
for _, callback in ipairs(callbacks.GA_AWARD_PENDING_CHANGED or {}) do
    callback(nil, nil, {}, "ADDED")
end
expect(not tradeWindow.frame:IsShown(), "a deferred award does not automatically open the trade assistant")

print(string.format("PASS: %d loot-master UI simulation assertions", assertions))
