-- Tracks Blizzard /roll results so players without MasterLooter can participate.
local _, GA = ...

local ChatRolls = {}
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
    for index = 1, select("#", ...) do
        player, roll, minimum, maximum = parseSystemRoll(select(index, ...))
        if player then break end
    end
    if not player then return nil end
    local manager = GA.RollSession
    local state = manager and manager:GetState()
    local choice = state and manager:GetChoiceForMaximum(state, maximum)
    if not choice or minimum ~= 1 then return nil end
    local participant = {
        name = player, choice = choice, roll = roll, minimum = minimum, maximum = maximum,
        publicRoll = true, pending = false,
    }
    GA.Events:Emit("GA_PUBLIC_ROLL_SEEN", state, participant)
    local recorded = manager:RecordPublicRoll(player, roll, minimum, maximum, state.id)
    return recorded or participant
end

function ChatRolls:OnInitialize()
    GA.Events:On("CHAT_MSG_SYSTEM", function(_, _, ...) ChatRolls:OnSystemMessage(...) end, self)
    GA.Events:RegisterGameEvent("CHAT_MSG_SYSTEM")
    return true
end

GA:RegisterModule("ChatRolls", ChatRolls)
