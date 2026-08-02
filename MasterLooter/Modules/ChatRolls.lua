-- Tracks Blizzard /roll results so players without MasterLooter can participate.
local _, GA = ...

local ChatRolls = { diagnostics = { received = 0, status = "Noch keine Systemmeldung empfangen." } }
GA.ChatRolls = ChatRolls

local function createFormatPattern(format)
    if type(format) ~= "string" or format == "" then return nil end
    format = string.gsub(format, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    -- Protect positional placeholders so the later non-positional pass cannot
    -- reinterpret the "%d" part of an inserted numeric capture.
    format = string.gsub(format, "%%%d+%$s", "MASTERLOOTER_STRING_CAPTURE")
    format = string.gsub(format, "%%%d+%$d", "MASTERLOOTER_NUMBER_CAPTURE")
    format = string.gsub(format, "%%s", "(.-)")
    format = string.gsub(format, "%%d", "(%%d+)")
    format = string.gsub(format, "MASTERLOOTER_STRING_CAPTURE", "(.-)")
    format = string.gsub(format, "MASTERLOOTER_NUMBER_CAPTURE", "(%%d+)")
    return "^" .. format .. "$"
end

local localizedRollPattern = createFormatPattern(_G and _G.RANDOM_ROLL_RESULT)

local function visibleMessage(message)
    message = string.gsub(message, "\226\128\147", "-")
    message = string.gsub(message, "\226\128\148", "-")
    message = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "")
    message = string.gsub(message, "|r", "")
    message = string.gsub(message, "|H[^|]+|h%[([^%]]+)%]|h", "%1")
    return message
end

local function parseSystemRoll(message)
    if type(message) ~= "string" then return nil end
    if localizedRollPattern then
        local player, roll, minimum, maximum = string.match(message, localizedRollPattern)
        roll, minimum, maximum = tonumber(roll), tonumber(minimum), tonumber(maximum)
        if player and roll and minimum and maximum then
            return player, roll, minimum, maximum
        end
    end
    message = visibleMessage(message)
    local roll, minimum, maximum = string.match(message, "(%d+)%s*%(%s*(%d+)%s*%-%s*(%d+)%s*%)")
    if not roll then
        minimum, maximum, roll = string.match(message, "%(%s*(%d+)%s*%-%s*(%d+)%s*%)%D+(%d+)")
    end
    roll, minimum, maximum = tonumber(roll), tonumber(minimum), tonumber(maximum)
    if not roll or not minimum or not maximum then return nil end
    local player = string.match(message, "^%s*([^%s]+)")
    if not player then return nil end
    player = string.gsub(player, "^[%[]+", "")
    player = string.gsub(player, "[%],;:]+$", "")
    return player, roll, minimum, maximum
end

function ChatRolls:OnSystemMessage(...)
    local player, roll, minimum, maximum
    local diagnostics = self.diagnostics
    diagnostics.received = (diagnostics.received or 0) + 1
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "string" then diagnostics.raw = candidate end
        player, roll, minimum, maximum = parseSystemRoll(candidate)
        if player then break end
    end
    if not player and _G and type(_G.arg1) == "string" then
        diagnostics.raw = _G.arg1
        player, roll, minimum, maximum = parseSystemRoll(_G.arg1)
    end
    if not player then diagnostics.status = "Systemmeldung empfangen, aber nicht als /roll erkannt."; return nil end
    diagnostics.player, diagnostics.roll = player, roll
    diagnostics.minimum, diagnostics.maximum = minimum, maximum
    local manager = GA.RollSession
    local state = manager and manager:GetState()
    diagnostics.session = state and state.id or nil
    local choice = state and manager:GetChoiceForMaximum(state, maximum)
    if not state then diagnostics.status = "Roll erkannt, aber keine aktive Sitzung gefunden."; return nil end
    if not choice or minimum ~= 1 then diagnostics.status = "Roll erkannt, aber der Bereich passt nicht zu MS/OS."; return nil end
    local participant = {
        name = player, choice = choice, roll = roll, minimum = minimum, maximum = maximum,
        publicRoll = true, pending = false,
    }
    GA.Events:Emit("GA_PUBLIC_ROLL_SEEN", state, participant)
    local method = manager.ObservePublicRoll or manager.RecordPublicRoll
    local recorded, recordError = method(manager, player, roll, minimum, maximum, state.id)
    if recorded then
        diagnostics.status = "Erfasst: " .. player .. " " .. choice .. " " .. roll
    elseif recordError == "player already rolled" then
        diagnostics.status = "Bereits erfasst: " .. player
    else
        diagnostics.status = "Nicht übernommen: " .. tostring(recordError or "unbekannter Grund")
    end
    return recorded or participant
end

function ChatRolls:GetDiagnostics()
    return self.diagnostics
end

function ChatRolls:GetDiagnosticText()
    local diagnostics = self.diagnostics or {}
    local state = GA.RollSession and GA.RollSession:GetState()
    return table.concat({
        "MasterLooter Roll-Diagnose",
        "Version: " .. tostring(GA.VERSION),
        "Protokoll: " .. tostring(GA.PROTOCOL_VERSION),
        "Tracker vorhanden: ja",
        "Tracker initialisiert: " .. tostring(self.captureInitialized == true),
        "Direkter Eventframe: " .. tostring(self.frame ~= nil),
        "Chatfilter: " .. tostring(self.chatFilter ~= nil),
        "Chat-Handler-Hook: " .. tostring(self.handlerHooked == true),
        "Aktive Sitzung: " .. tostring(state and state.id or "keine"),
        "Sitzungsstatus: " .. tostring(state and state.status or "keiner"),
        "Empfangene Systemereignisse: " .. tostring(diagnostics.received or 0),
        "Letzte Meldung: " .. tostring(diagnostics.raw or "keine"),
        "Spieler: " .. tostring(diagnostics.player or "keiner"),
        "Wurf: " .. tostring(diagnostics.roll or "keiner"),
        "Bereich: " .. tostring(diagnostics.minimum or "?") .. "-" .. tostring(diagnostics.maximum or "?"),
        "Ergebnis: " .. tostring(diagnostics.status or "keine Diagnose"),
    }, "\n")
end

function ChatRolls:OnInitialize()
    if self.captureInitialized then return true end
    -- Keep independent capture paths for this critical game event. Gargul also
    -- uses the chat-message filter path; Ascension builds can display a system
    -- line even when an addon's regular event dispatch does not receive it.
    if type(CreateFrame) == "function" then
        self.frame = self.frame or CreateFrame("Frame")
        self.frame:RegisterEvent("CHAT_MSG_SYSTEM")
        self.frame:SetScript("OnEvent", function(_, _, ...) ChatRolls:OnSystemMessage(...) end)
    end
    if GA.Events then
        GA.Events:On("CHAT_MSG_SYSTEM", function(_, _, ...) ChatRolls:OnSystemMessage(...) end, self)
        GA.Events:RegisterGameEvent("CHAT_MSG_SYSTEM")
    end
    if type(ChatFrame_AddMessageEventFilter) == "function" and not self.chatFilter then
        self.chatFilter = function(_, _, message, ...)
            ChatRolls:OnSystemMessage(message, ...)
            return false
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", self.chatFilter)
    end
    if type(hooksecurefunc) == "function" and type(ChatFrame_MessageEventHandler) == "function" and not self.handlerHooked then
        local ok = pcall(hooksecurefunc, "ChatFrame_MessageEventHandler", function(_, event, ...)
            if event == "CHAT_MSG_SYSTEM" then ChatRolls:OnSystemMessage(...) end
        end)
        self.handlerHooked = ok and true or false
    end
    self.captureInitialized = true
    return true
end

GA:RegisterModule("ChatRolls", ChatRolls)
local initialized, initializeError = pcall(ChatRolls.OnInitialize, ChatRolls)
if not initialized and type(GA.ReportError) == "function" then GA.ReportError("ChatRolls", initializeError) end
