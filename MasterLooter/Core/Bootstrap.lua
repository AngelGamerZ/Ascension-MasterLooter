local ADDON_NAME, ns = ...

local Bootstrap = { loaded = false, loggedIn = false }
ns.Bootstrap = Bootstrap

local function initializeModules()
    for index = 1, #ns.moduleOrder do
        local module = ns.moduleOrder[index]
        if not module.initialized then
            local ok = ns:CallModuleMethod(module, "OnInitialize", ns.DB.data)
            module.initialized = ok and true or false
        end
    end
end

local function enableModules()
    for index = 1, #ns.moduleOrder do
        local module = ns.moduleOrder[index]
        if module.initialized and not module.enabled then
            local ok = ns:CallModuleMethod(module, "OnEnable")
            module.enabled = ok and true or false
        end
    end
end

function Bootstrap:Initialize()
    if self.loaded then return end
    self.loaded = true
    if ns.Trace then ns:Trace("BOOT", "INITIALIZE_BEGIN", ADDON_NAME) end
    ns.DB:Initialize(_G.MasterLooterDB)
    local profile = ns.DB:GetProfile()
    if ns.SetDebugMode then ns:SetDebugMode(profile.debugMode ~= false, false) end
    initializeModules()
    if ns.Trace then ns:Trace("BOOT", "INITIALIZE_OK", #ns.moduleOrder) end
end

function Bootstrap:Enable()
    if self.loggedIn then return end
    self.loggedIn = true
    if ns.Trace then ns:Trace("BOOT", "ENABLE_BEGIN") end
    self:Initialize()
    enableModules()
    if ns.Trace then ns:Trace("BOOT", "ENABLE_OK") end
end

function Bootstrap:Disable()
    for index = #ns.moduleOrder, 1, -1 do
        local module = ns.moduleOrder[index]
        if module.enabled then
            ns:CallModuleMethod(module, "OnDisable")
            module.enabled = false
        end
    end
    self.loggedIn = false
end

ns.Events:On("ADDON_LOADED", function(_, _, loadedAddon)
    if loadedAddon == ADDON_NAME then
        Bootstrap:Initialize()
    end
end, Bootstrap, 100)

ns.Events:On("PLAYER_LOGIN", function()
    Bootstrap:Enable()
end, Bootstrap, 100)

ns.Events:On("PLAYER_LOGOUT", function()
    for index = 1, #ns.moduleOrder do
        ns:CallModuleMethod(ns.moduleOrder[index], "OnSave", ns.DB.data)
    end
end, Bootstrap, 100)

ns.Events:RegisterGameEvent("ADDON_LOADED")
ns.Events:RegisterGameEvent("PLAYER_LOGIN")
ns.Events:RegisterGameEvent("PLAYER_LOGOUT")
