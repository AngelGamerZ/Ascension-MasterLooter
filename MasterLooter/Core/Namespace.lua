local ADDON_NAME, ns = ...

-- The second vararg is supplied by the WoW addon loader. Keeping one shared
-- table avoids globals while still allowing every file to cooperate.
ns = ns or {}

ns.ADDON_NAME = ADDON_NAME or "MasterLooter"
ns.VERSION = "0.17.2-beta"
ns.PROTOCOL_VERSION = 3
ns.DB_SCHEMA = 1
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}
ns.errors = ns.errors or {}
ns.debugTrace = ns.debugTrace or {}
ns.debugSequence = tonumber(ns.debugSequence) or 0
ns.debugMode = ns.debugMode ~= false

-- One documented public root is useful for optional integrations and debugging.
-- Addon files should continue to use the private table passed through `...`.
_G.MasterLooter = ns

local function traceValue(value)
    local valueType = type(value)
    if valueType == "string" then
        value = string.gsub(value, "[\r\n\t]+", " ")
        return string.sub(value, 1, 180)
    end
    if valueType ~= "table" then return tostring(value) end
    local fields = {}
    for _, key in ipairs({ "id", "sessionID", "name", "player", "winner", "status", "choice", "action", "itemLink" }) do
        if value[key] ~= nil then fields[#fields + 1] = key .. "=" .. traceValue(value[key]) end
    end
    return #fields > 0 and ("{" .. table.concat(fields, ",") .. "}") or tostring(value)
end

function ns:Trace(category, action, ...)
    local arguments, argumentCount = { ... }, select("#", ...)
    local ok = pcall(function()
        self.debugSequence = (tonumber(self.debugSequence) or 0) + 1
        local details = {}
        for index = 1, math.min(argumentCount, 6) do details[#details + 1] = traceValue(arguments[index]) end
        self.debugTrace[#self.debugTrace + 1] = {
            sequence = self.debugSequence,
            at = type(GetTime) == "function" and GetTime() or 0,
            category = tostring(category or "GENERAL"), action = tostring(action or ""),
            detail = table.concat(details, " | "),
        }
        local maximum = self.debugMode and 2000 or 500
        while #self.debugTrace > maximum do table.remove(self.debugTrace, 1) end
    end)
    return ok
end

function ns:GetDebugTrace() return self.debugTrace end
function ns:ClearDebugTrace() self.debugTrace = {}; self:Trace("SYSTEM", "TRACE_CLEARED") end
function ns:IsDebugMode() return self.debugMode and true or false end
function ns:SetDebugMode(enabled, persist)
    self.debugMode = enabled and true or false
    if persist ~= false and self.DB and self.DB.data and type(self.DB.GetProfile) == "function" then
        local ok, profile = pcall(self.DB.GetProfile, self.DB)
        if ok and type(profile) == "table" then profile.debugMode = self.debugMode end
    end
    self:Trace("SYSTEM", "DEBUG_MODE", self.debugMode and "ON" or "OFF")
    return self.debugMode
end

local function reportError(context, message)
    if type(ns.Localize) == "function" then message = ns:Localize(message) end
    local stack
    if ns.debugMode and type(debugstack) == "function" then
        local ok, value = pcall(debugstack, 3, 16, 16)
        if ok and value then stack = string.sub(tostring(value), 1, 3000) end
    end
    ns.errors[#ns.errors + 1] = { time = (time and time()) or 0, context = tostring(context), message = tostring(message), stack = stack }
    while #ns.errors > 100 do table.remove(ns.errors, 1) end
    ns:Trace("ERROR", context, message)
    local text = string.format("|cffff4040MasterLooter|r [%s]: %s", tostring(context), tostring(message))
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif print then
        print(text)
    end
end

function ns:GetErrors()
    return self.errors
end

ns.ReportError = reportError

function ns:Print(message)
    if type(self.Localize) == "function" then message = self:Localize(message) end
    local text = "|cff33ff99MasterLooter|r: " .. tostring(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif print then
        print(text)
    end
end

function ns:RegisterModule(name, module)
    assert(type(name) == "string" and name ~= "", "RegisterModule requires a name")
    assert(type(module) == "table", "RegisterModule requires a module table")
    assert(not self.modules[name], "Module already registered: " .. name)

    module.name = name
    module.addon = self
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = module
    self:Trace("MODULE", "REGISTER", name)
    return module
end

function ns:GetModule(name, silent)
    local module = self.modules[name]
    if not module and not silent then
        error("Unknown module: " .. tostring(name), 2)
    end
    return module
end

function ns:CallModuleMethod(module, method, ...)
    local callback = module and module[method]
    if type(callback) ~= "function" then
        return true
    end

    self:Trace("MODULE", method .. "_BEGIN", module.name or "module")
    local ok, result = pcall(callback, module, ...)
    if not ok then
        reportError((module.name or "module") .. "." .. method, result)
    else
        self:Trace("MODULE", method .. "_OK", module.name or "module")
    end
    return ok, result
end
