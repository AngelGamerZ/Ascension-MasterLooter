local ADDON_NAME, ns = ...

-- The second vararg is supplied by the WoW addon loader. Keeping one shared
-- table avoids globals while still allowing every file to cooperate.
ns = ns or {}

ns.ADDON_NAME = ADDON_NAME or "MasterLooter"
ns.VERSION = "0.12.7-beta"
ns.PROTOCOL_VERSION = 3
ns.DB_SCHEMA = 1
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}
ns.errors = ns.errors or {}

-- One documented public root is useful for optional integrations and debugging.
-- Addon files should continue to use the private table passed through `...`.
_G.MasterLooter = ns

local function reportError(context, message)
    ns.errors[#ns.errors + 1] = { time = (time and time()) or 0, context = tostring(context), message = tostring(message) }
    while #ns.errors > 100 do table.remove(ns.errors, 1) end
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

    local ok, result = pcall(callback, module, ...)
    if not ok then
        reportError((module.name or "module") .. "." .. method, result)
    end
    return ok, result
end
