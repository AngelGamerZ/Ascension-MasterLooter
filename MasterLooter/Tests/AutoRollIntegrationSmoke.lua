-- Black-box coverage for the real participant AutoRoll -> /roll integration.
local assertions = 0
local function expect(value, message) assertions = assertions + 1; if not value then error("ASSERTION FAILED: " .. message, 2) end end
local function same(actual, expected, message) expect(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
unpack = unpack or table.unpack

local clock, timers, rolls, passes, traces = 100, {}, {}, {}, {}
function GetTime() return clock end
function UnitName(unit) if unit == "player" then return "Tester" end end
function UnitClass(unit) if unit == "player" then return "Warrior", "WARRIOR" end end
function GetItemInfo(subject)
    local id = tonumber(tostring(subject or ""):match("item:(%d+)")) or tonumber(subject) or 1985
    return "Test Item", "|Hitem:" .. id .. ":0:0:0|h[Test Item]|h", 4, 100, 60, "Armor", "Plate", 1, "INVTYPE_HEAD", "Icons\\Test"
end
function RandomRoll(minimum, maximum) rolls[#rolls + 1] = { minimum, maximum } end
function PlaySound() end

local function widget(name, parent)
    local object = { name = name, parent = parent, shown = true, enabled = true, text = "", width = 0, height = 0, scripts = {}, points = {} }
    function object:SetWidth(value) self.width = value end
    function object:GetWidth() return self.width end
    function object:SetHeight(value) self.height = value end
    function object:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function object:ClearAllPoints() self.points = {} end
    function object:SetAllPoints() end
    function object:SetFrameStrata() end
    function object:SetToplevel() end
    function object:SetScript(event, callback) self.scripts[event] = callback end
    function object:RegisterEvent() end
    function object:RegisterForClicks() end
    function object:EnableMouse() end
    function object:CreateTexture() return widget(nil, self) end
    function object:SetTexture() end
    function object:SetText(value) self.text = tostring(value or "") end
    function object:GetText() return self.text end
    function object:SetTextColor() end
    function object:SetJustifyH() end
    function object:SetJustifyV() end
    function object:SetWordWrap() end
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:IsShown() return self.shown end
    function object:Enable() self.enabled = true end
    function object:Disable() self.enabled = false end
    function object:GetFontString() return nil end
    return object
end

UIParent, UISpecialFrames = widget("UIParent"), {}
function CreateFrame(_, name, parent) return widget(name, parent or UIParent) end

local listeners = {}
local profile = { autoOpenRollWindow = true, sound = false }
local plan = { matched = true, choice = "MS", ruleID = 1, matchKind = "EXACT" }
local rules = { { id = 1, delay = 3 } }
local autoEnabled, previewThrows = true, false
local GA = {
    UI = {}, modules = {}, Events = {},
    DB = { GetProfile = function() return profile end },
    Compat = {}, RollSession = {}, AutoRoll = {},
}
function GA:RegisterModule(name, module) self.modules[name] = module end
function GA:L(key) return key end
function GA:Trace(...) traces[#traces + 1] = { ... } end
function GA.Events:On(event, callback) listeners[event] = listeners[event] or {}; listeners[event][#listeners[event] + 1] = callback end
function GA.Events:Emit(event, ...)
    for _, callback in ipairs(listeners[event] or {}) do callback(nil, event, ...) end
end
function GA.Compat:After(delay, callback)
    local timer = { delay = delay, callback = callback, cancelled = false }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
function GA.AutoRoll:IsEnabled() return autoEnabled end
function GA.AutoRoll:Preview()
    if previewThrows then error("provider/matcher failed") end
    local result = {}; for key, value in pairs(plan) do result[key] = value end; return result
end
function GA.AutoRoll:GetRules() return rules end
function GA.AutoRoll:GetDefaultDelay() return 3 end
function GA.RollSession:Pass(sessionID) passes[#passes + 1] = sessionID; return { choice = "PASS" } end

local colors = { muted = { .5, .5, .5 }, gold = { 1, .8, 0 }, green = { 0, 1, 0 }, red = { 1, 0, 0 } }
GA.UI.Theme = { colors = colors }
local Theme = GA.UI.Theme
function Theme:ApplyPanel() end
function Theme:MakeMovable() end
function Theme:RestorePosition() end
function Theme:RegisterForEscape() end
function Theme:CreateLabel(parent, text) local result = widget(nil, parent); result:SetText(text); return result end
function Theme:CreateButton(parent, text, width, height) local result = widget(nil, parent); result:SetText(text); result:SetWidth(width); result:SetHeight(height); return result end
function Theme:SetItemTooltip() end
function Theme:FormatTime(seconds) return tostring(math.max(0, math.floor(seconds))) end

assert(loadfile("MasterLooter/UI/RollWindow.lua"))("MasterLooter", GA)
local window = GA.UI.RollWindow
window:Initialize()

local function session(id, choices, osMaximum, duration)
    return { id = id, itemLink = "|Hitem:1985:0:0:0|h[Test Item]|h", choices = choices or { "MS", "OS", "TRANSMOG", "PASS" },
        osRollMaximum = osMaximum or 37, duration = duration or 30, endsAt = clock + (duration or 30) }
end
local function runTimer(timer)
    if timer and not timer.cancelled then clock = clock + timer.delay; timer.callback() end
end
local function runAllTimers()
    local snapshot = timers; timers = {}
    for _, timer in ipairs(snapshot) do runTimer(timer) end
end
local function resetRuntime()
    window:CancelAutoRoll("TEST")
    window.session, window.sessionId, window.submittedSessionId, window.endsAt = nil, nil, nil, nil
    timers, rolls, passes = {}, {}, {}
    plan = { matched = true, choice = "MS", ruleID = 1, matchKind = "EXACT" }
    rules = { { id = 1, delay = 3 } }
    autoEnabled, previewThrows, profile.autoOpenRollWindow = true, false, true
    clock = clock + 100
end

-- Delay is visible/cancellable and executes the actual public MS range once.
resetRuntime(); window:ShowSession(session("delay"))
expect(window.autoRollPending, "matching session schedules AutoRoll")
same(timers[1].delay, 3, "configured delay reaches compatibility timer")
expect(window.autoCancelButton:IsShown(), "cancel control is visible during delay")
expect(not window.status:IsShown(), "normal status yields space to AutoRoll countdown")
runAllTimers()
same(#rolls, 1, "scheduled AutoRoll submits once")
same(rolls[1][1], 1, "public roll minimum is one")
same(rolls[1][2], 100, "MS uses /roll 100")
same(window.submittedSessionId, "delay", "successful AutoRoll marks session submitted")

-- User cancellation prevents a later callback even when a legacy timer still fires.
resetRuntime(); window:ShowSession(session("cancel")); local cancelledTimer = timers[1]
expect(window:CancelAutoRoll("USER", true), "user can cancel pending AutoRoll")
expect(cancelledTimer.cancelled, "cancel handle is invoked when available")
local cancellationText = window.status:GetText()
cancelledTimer.callback()
same(#rolls, 0, "cancelled stale callback cannot roll")
expect(cancellationText ~= "" and window.status:IsShown(), "cancellation is reported")

-- A manual choice wins and suppresses the previously planned action.
resetRuntime(); window:ShowSession(session("manual")); local planned = timers[1]
expect(window:Submit("OS"), "manual OS roll succeeds")
same(rolls[1][2], 37, "manual override uses synchronized OS maximum")
planned.callback()
same(#rolls, 1, "planned MS cannot run after manual override")

-- New sessions invalidate old callbacks; only the current session may act.
resetRuntime(); window:ShowSession(session("old")); local oldTimer = timers[1]
plan.choice = "TRANSMOG"; window:ShowSession(session("new")); local newTimer = timers[2]
expect(oldTimer.cancelled, "new session cancels previous timer")
oldTimer.callback(); same(#rolls, 0, "old session callback is stale")
runTimer(newTimer); same(rolls[1][2], 50, "new session executes Transmog as /roll 50")

-- Duplicate START for the same session keeps exactly one timer and one roll.
resetRuntime(); local duplicate = session("duplicate")
GA.Events:Emit("GA_ROLL_SESSION_STARTED", duplicate)
GA.Events:Emit("GA_ROLL_SESSION_STARTED", duplicate)
same(#timers, 1, "duplicate session event does not schedule twice")
runAllTimers(); same(#rolls, 1, "duplicate event produces one public roll")
GA.Events:Emit("GA_ROLL_SESSION_STARTED", duplicate)
same(#timers, 0, "already submitted duplicate event does not show another countdown")

-- Session end, confirmation and local timeout all invalidate pending automation.
resetRuntime(); local ended = session("ended"); window:ShowSession(ended); local endedTimer = timers[1]
window:EndSession("STOPPED", ended); endedTimer.callback(); same(#rolls, 0, "ended session cannot AutoRoll")
resetRuntime(); local confirmed = session("confirmed"); window:ShowSession(confirmed); local confirmedTimer = timers[1]
window:Confirm({ name = "Tester", choice = "MS", roll = 88 }, confirmed); confirmedTimer.callback(); same(#rolls, 0, "observed own roll cancels automation")
resetRuntime(); local timeout = session("timeout", nil, 37, 1); rules[1].delay = 10; window:ShowSession(timeout); local timeoutTimer = timers[1]
clock = timeout.endsAt; window:UpdateTimer(); timeoutTimer.callback(); same(#rolls, 0, "local timeout cancels pending AutoRoll")

-- Lootmaster-disabled categories and global disable never schedule or roll.
resetRuntime(); plan.choice = "OS"; window:ShowSession(session("choice-disabled", { "MS", "PASS" }))
expect(not window.autoRollPending and #timers == 0, "disabled OS category rejects OS AutoRoll rule")
expect(window.status:GetText() ~= "" and window.status:IsShown(), "disabled category explains rejection")
resetRuntime(); autoEnabled = false; window:ShowSession(session("global-disabled"))
expect(not window.autoRollPending and #timers == 0, "global AutoRoll disable is honored")

-- PASS uses RollSession transport, not RandomRoll.
resetRuntime(); plan.choice = "PASS"; window:ShowSession(session("pass")); runAllTimers()
same(#passes, 1, "AutoRoll PASS calls session Pass")
same(passes[1], "pass", "PASS targets current session")
same(#rolls, 0, "PASS never calls RandomRoll")

-- A configured hidden roll window is still shown while the safety countdown is cancellable.
resetRuntime(); profile.autoOpenRollWindow = false; window:ShowSession(session("safety-visible"))
expect(window.frame:IsShown() and window.autoCancelButton:IsShown(), "pending AutoRoll remains visible and cancellable when auto-open is disabled")

-- Matcher/provider errors and missing timer APIs degrade safely.
resetRuntime(); previewThrows = true; window:ShowSession(session("preview-error"))
expect(not window.autoRollPending and #timers == 0 and #rolls == 0, "Preview exception cannot break session or roll")
resetRuntime(); local after = GA.Compat.After; GA.Compat.After = nil; window:ShowSession(session("no-timer")); GA.Compat.After = after
expect(not window.autoRollPending and #rolls == 0, "missing timer API never causes immediate unsafe roll")

-- Failed/missing public /roll does not lock the session against a later manual retry.
resetRuntime(); local randomRoll = RandomRoll; RandomRoll = nil; window:ShowSession(session("no-random")); runAllTimers()
expect(window.submittedSessionId == nil, "missing RandomRoll is not recorded as submitted")
RandomRoll = randomRoll; expect(window:Submit("MS"), "manual retry works after missing RandomRoll")
same(rolls[1][2], 100, "retry retains MS range")

print("PASS: " .. assertions .. " AutoRoll participant-integration assertions")
