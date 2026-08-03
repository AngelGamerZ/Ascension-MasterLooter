local _, GA = ...

local TooltipDebug = { entries = {}, maximumEntries = 180, hooked = false }
GA.TooltipDebug = TooltipDebug

local function now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function frameName(frame)
    if not frame then return "nil" end
    if type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return tostring(frame)
end

local function cleanStack(stack)
    stack = tostring(stack or "")
    stack = string.gsub(stack, "[\r\n]+", " <- ")
    return string.sub(stack, 1, 900)
end

function TooltipDebug:Log(kind, detail, withStack)
    local entry = {
        at = now(),
        kind = tostring(kind or "UNKNOWN"),
        detail = tostring(detail or ""),
        stack = withStack and type(debugstack) == "function" and cleanStack(debugstack(3, 10, 10)) or nil,
    }
    self.entries[#self.entries + 1] = entry
    while #self.entries > self.maximumEntries do table.remove(self.entries, 1) end
    return entry
end

function TooltipDebug:TooltipState()
    local tooltip = _G.GameTooltip
    if not tooltip then return "GameTooltip=nil" end
    local shown = type(tooltip.IsShown) == "function" and tooltip:IsShown() and "ja" or "nein"
    local owner = type(tooltip.GetOwner) == "function" and frameName(tooltip:GetOwner()) or "unbekannt"
    local scripts = {}
    if type(tooltip.GetScript) == "function" then
        for _, scriptName in ipairs({ "OnShow", "OnHide", "OnUpdate", "OnTooltipSetItem" }) do
            local ok, handler = pcall(tooltip.GetScript, tooltip, scriptName)
            scripts[#scripts + 1] = scriptName .. "=" .. (ok and tostring(handler) or "nicht abfragbar")
        end
    end
    return "sichtbar=" .. shown .. ", Besitzer=" .. owner .. (#scripts > 0 and ", Scripts{" .. table.concat(scripts, ", ") .. "}" or "")
end

function TooltipDebug:GetLoadedAddons()
    local result = {}
    if type(GetNumAddOns) ~= "function" or type(GetAddOnInfo) ~= "function" then return { "Addon-API nicht verfügbar" } end
    for index = 1, GetNumAddOns() do
        local name, title, _, enabled, loadable, reason = GetAddOnInfo(index)
        local loaded = type(IsAddOnLoaded) == "function" and IsAddOnLoaded(index)
        if loaded or name == "MasterLooter" or name == "MasterLooter_ItemData" then
            result[#result + 1] = string.format("%s | geladen=%s, aktiviert=%s, ladbar=%s, Grund=%s", tostring(name or title), tostring(loaded and true or false), tostring(enabled), tostring(loadable), tostring(reason))
        end
    end
    return result
end

function TooltipDebug:OnTooltipAction(action)
    self:Log("TOOLTIP_" .. tostring(action), self:TooltipState(), true)
end

function TooltipDebug:InstallHooks()
    if self.hooked then return true end
    local tooltip, secureHook = _G.GameTooltip, _G.hooksecurefunc
    if not tooltip or type(secureHook) ~= "function" then
        self:Log("HOOK", "GameTooltip oder hooksecurefunc nicht verfügbar")
        return false
    end
    local installed = 0
    for _, method in ipairs({ "Hide", "Show", "SetOwner", "ClearLines", "SetHyperlink", "SetBagItem", "SetLootItem" }) do
        if type(tooltip[method]) == "function" then
            local methodName = method
            local ok = pcall(secureHook, tooltip, methodName, function() TooltipDebug:OnTooltipAction(methodName) end)
            if ok then installed = installed + 1 else self:Log("HOOK_FEHLER", method) end
        end
    end
    self.hooked = installed > 0
    self:Log("HOOK", tostring(installed) .. " Tooltip-Methoden beobachtet")
    return self.hooked
end

function TooltipDebug:GetText()
    local lines = {
        "MasterLooter Tooltip-Diagnose",
        "Version: " .. tostring(GA.VERSION),
        "Globale Tooltip-Nutzung durch MasterLooter-UI: nein (eigener MasterLooterTooltip)",
        "Diagnose-Hooks aktiv: " .. (self.hooked and "ja" or "nein"),
        "Aktueller Zustand: " .. self:TooltipState(),
        "Einträge: " .. tostring(#self.entries),
        "",
        "Geladene Addons:",
    }
    for _, addonLine in ipairs(self:GetLoadedAddons()) do lines[#lines + 1] = "- " .. addonLine end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "MasterLooter-Ladefehler:"
    if #(GA.errors or {}) == 0 then lines[#lines + 1] = "- keine" end
    for _, errorEntry in ipairs(GA.errors or {}) do
        lines[#lines + 1] = "- " .. tostring(errorEntry.context) .. ": " .. tostring(errorEntry.message)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Zeitleiste:"
    for index = 1, #self.entries do
        local entry = self.entries[index]
        lines[#lines + 1] = string.format("[%08.3f] %s | %s", tonumber(entry.at) or 0, entry.kind, entry.detail)
        if entry.stack and entry.stack ~= "" then lines[#lines + 1] = "  Stack: " .. entry.stack end
    end
    return table.concat(lines, "\n")
end

function TooltipDebug:Clear()
    self.entries = {}
    self:Log("RESET", "Diagnoseprotokoll geleert")
end

function TooltipDebug:OnInitialize()
    self:InstallHooks()
    for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "CURSOR_UPDATE" }) do
        GA.Events:On(event, function(_, eventName, ...)
            local first, second = ...
            TooltipDebug:Log("EVENT_" .. eventName, "arg1=" .. tostring(first) .. ", arg2=" .. tostring(second) .. " | " .. TooltipDebug:TooltipState())
        end, self, -100)
        GA.Events:RegisterGameEvent(event)
    end
    self:Log("START", "Tooltip-Diagnose initialisiert | " .. self:TooltipState())
    return true
end

GA:RegisterModule("TooltipDebug", TooltipDebug)
