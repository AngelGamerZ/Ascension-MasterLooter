local _, GA = ...

-- Kept in this long-established TOC file so diagnostics remain available even
-- when a client installation accidentally retains an older manifest that does
-- not know newer standalone files.
local TooltipDebug = { entries = {}, maximumEntries = 180, hooked = false }
GA.TooltipDebug = TooltipDebug

local function tooltipNow() return type(GetTime) == "function" and GetTime() or 0 end
local function tooltipFrameName(frame)
    if not frame then return "nil" end
    if type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return tostring(frame)
end

function TooltipDebug:Log(kind, detail, withStack)
    local stack = withStack and type(debugstack) == "function" and tostring(debugstack(3, 10, 10)) or nil
    if stack then stack = string.sub(string.gsub(stack, "[\r\n]+", " <- "), 1, 900) end
    self.entries[#self.entries + 1] = { at = tooltipNow(), kind = tostring(kind or "UNKNOWN"), detail = tostring(detail or ""), stack = stack }
    while #self.entries > self.maximumEntries do table.remove(self.entries, 1) end
end

function TooltipDebug:TooltipState()
    local tooltip = _G.GameTooltip
    if not tooltip then return "GameTooltip=nil" end
    local shown = type(tooltip.IsShown) == "function" and tooltip:IsShown() and "ja" or "nein"
    local owner = type(tooltip.GetOwner) == "function" and tooltipFrameName(tooltip:GetOwner()) or "unbekannt"
    local scripts = {}
    if type(tooltip.GetScript) == "function" then
        for _, scriptName in ipairs({ "OnShow", "OnHide", "OnUpdate", "OnTooltipSetItem" }) do
            local ok, handler = pcall(tooltip.GetScript, tooltip, scriptName)
            scripts[#scripts + 1] = scriptName .. "=" .. (ok and tostring(handler) or "nicht abfragbar")
        end
    end
    return "sichtbar=" .. shown .. ", Besitzer=" .. owner .. (#scripts > 0 and ", Scripts{" .. table.concat(scripts, ", ") .. "}" or "")
end

function TooltipDebug:OnTooltipAction(action) self:Log("TOOLTIP_" .. tostring(action), self:TooltipState(), true) end

function TooltipDebug:InstallHooks()
    if self.hooked then return true end
    local tooltip, secureHook = _G.GameTooltip, _G.hooksecurefunc
    if not tooltip or type(secureHook) ~= "function" then self:Log("HOOK", "GameTooltip oder hooksecurefunc nicht verfügbar"); return false end
    local installed = 0
    for _, method in ipairs({ "Hide", "Show", "SetOwner", "ClearLines", "SetHyperlink", "SetBagItem", "SetLootItem" }) do
        if type(tooltip[method]) == "function" then
            local methodName = method
            local ok = pcall(secureHook, tooltip, methodName, function() TooltipDebug:OnTooltipAction(methodName) end)
            if ok then installed = installed + 1 else self:Log("HOOK_FEHLER", methodName) end
        end
    end
    self.hooked = installed > 0; self:Log("HOOK", tostring(installed) .. " Tooltip-Methoden beobachtet"); return self.hooked
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

function TooltipDebug:GetText()
    local metadata = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("MasterLooter", "Version") or "API nicht verfügbar"
    local lines = {
        "MasterLooter Tooltip-Diagnose", "Lua-Version: " .. tostring(GA.VERSION), "TOC-Version: " .. tostring(metadata),
        "Diagnose-Hooks aktiv: " .. (self.hooked and "ja" or "nein"), "Aktueller Zustand: " .. self:TooltipState(),
        "Einträge: " .. tostring(#self.entries), "", "Geladene Addons:",
    }
    for _, addonLine in ipairs(self:GetLoadedAddons()) do lines[#lines + 1] = "- " .. addonLine end
    lines[#lines + 1] = ""; lines[#lines + 1] = "MasterLooter-Ladefehler:"
    if #(GA.errors or {}) == 0 then lines[#lines + 1] = "- keine" end
    for _, entry in ipairs(GA.errors or {}) do lines[#lines + 1] = "- " .. tostring(entry.context) .. ": " .. tostring(entry.message) end
    lines[#lines + 1] = ""; lines[#lines + 1] = "Zeitleiste:"
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = string.format("[%08.3f] %s | %s", tonumber(entry.at) or 0, entry.kind, entry.detail)
        if entry.stack and entry.stack ~= "" then lines[#lines + 1] = "  Stack: " .. entry.stack end
    end
    return table.concat(lines, "\n")
end

function TooltipDebug:Clear() self.entries = {}; self:Log("RESET", "Diagnoseprotokoll geleert") end
function TooltipDebug:OnInitialize()
    self:InstallHooks()
    for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "CURSOR_UPDATE" }) do
        GA.Events:On(event, function(_, eventName, ...)
            local first, second = ...
            TooltipDebug:Log("EVENT_" .. eventName, "arg1=" .. tostring(first) .. ", arg2=" .. tostring(second) .. " | " .. TooltipDebug:TooltipState())
        end, self, -100)
        GA.Events:RegisterGameEvent(event)
    end
    self:Log("START", "Tooltip-Diagnose initialisiert | " .. self:TooltipState()); return true
end

GA:RegisterModule("TooltipDebug", TooltipDebug)

local Commands = {}

local function trim(value) return string.match(value or "", "^%s*(.-)%s*$") end
local function split(message)
    local command, rest = string.match(trim(message), "^(%S+)%s*(.-)$")
    return string.lower(command or ""), rest or ""
end

local WINDOWS = {
    master = "MasterLooterWindow", lootmaster = "MasterLooterWindow",
    loot = "LootWindow", trade = "TradeWindow", softres = "SoftResWindow",
    rules = "RulesWindow", gdkpui = "GDKPWindow", history = "HistoryWindow",
    auction = "GDKPAuctionWindow", raid = "RaidManagerWindow", version = "VersionWindow",
    bags = "BagInspectorWindow", settings = "SettingsWindow", io = "ImportExportWindow",
}

local function showWindow(key)
    local window = GA.UI and GA.UI[WINDOWS[key]]
    if window and type(window.Show) == "function" then window:Show(); return true end
    return false
end

function Commands:Help()
    GA:Print("/ml – Übersicht & Einstellungen | /ml master oder /lootmaster – Lootmaster-Fenster")
    GA:Print("/ml roll <Itemlink> [Sekunden]")
    GA:Print("/ml sr <Spieler> <Item-ID> | /ml plus <Spieler> [Wert]")
    GA:Print("/ml gdkp start|sale|finish | /ml version | /ml rolldebug | /ml commdebug | /ml tooltipdebug")
    GA:Print("/ml master|loot|trade|softres|rules|gdkpui|auction|raid|version|bags|history|settings|io")
end

function Commands:Handle(message)
    local command, rest = split(message)
    if command == "" or command == "show" then
        if GA.UI and GA.UI.SettingsWindow then GA.UI.SettingsWindow:Show() end
    elseif WINDOWS[command] then
        if not showWindow(command) then GA:Print("Fenster ist nicht verfügbar: " .. command) end
    elseif command == "roll" then
        local link = string.match(rest, "(|c%x+|Hitem:.-|h.-|h|r)") or string.match(rest, "(|Hitem:.-|h.-|h)")
        local seconds = tonumber(string.match(rest, "(%d+)%s*$")) or 30
        local state, err = GA.RollSession:Start(link, { duration = seconds })
        if not state then GA:Print(err) end
    elseif command == "sr" then
        local player, id = string.match(rest, "^(%S+)%s+(%-?%d+)")
        if not player or not id then GA:Print("Verwendung: /ml sr <Spieler> <Item-ID>")
        else
            local ok, err = GA.SoftRes:Reserve(player, id)
            GA:Print(ok and (player .. " reserviert Item " .. id) or err)
        end
    elseif command == "plus" then
        local player, value = string.match(rest, "^(%S+)%s*(%d*)")
        if player then GA:Print(player .. ": +" .. GA.PlusOnes:Set(player, value ~= "" and value or GA.PlusOnes:Get(player) + 1)) end
    elseif command == "gdkp" then
        local sub, args = split(rest)
        if sub == "start" then GA.GDKP:Start(args ~= "" and args or nil)
        elseif sub == "sale" then
            local link = string.match(args, "(|c%x+|Hitem:.-|h.-|h|r)")
            local buyer, amount = string.match(args, "%s([^%s]+)%s+(%d+)%s*$")
            local sale, err = GA.GDKP:AddSale(link, buyer, amount); if not sale then GA:Print(err) end
        elseif sub == "finish" then GA.GDKP:Finish()
        else GA:Print("gdkp start <Name> | sale <Link> <Käufer> <Gold> | finish") end
    elseif command == "version" then GA:Print("Version " .. GA.VERSION .. ", Protokoll " .. GA.PROTOCOL_VERSION)
    elseif command == "rolldebug" then
        local window = GA.UI and GA.UI.RollDebugWindow
        if window and type(window.Show) == "function" then window:Show()
        else
            local tracker = GA.ChatRolls
            GA:Print(tracker and tracker:GetDiagnosticText() or "Rolltracker ist nicht geladen.")
        end
    elseif command == "commdebug" then
        local window = GA.UI and GA.UI.CommDebugWindow
        if window and type(window.Show) == "function" then window:Show()
        else GA:Print("Kommunikationsdiagnose ist nicht verfügbar.") end
    elseif command == "tooltipdebug" then
        local window = GA.UI and GA.UI.TooltipDebugWindow
        local opened = false
        if window and type(window.Show) == "function" then
            local ok, result = pcall(window.Show, window)
            opened = ok and result ~= false
            if not ok and GA.ReportError then GA.ReportError("tooltipdebug window", result) end
        end
        if not opened then
            local fallback = GA.UI and GA.UI.RollDebugWindow
            local text = GA.TooltipDebug and type(GA.TooltipDebug.GetText) == "function" and GA.TooltipDebug:GetText() or
                "MasterLooter Tooltip-Diagnose\nDiagnosemodul oder Fenster konnte nicht geladen werden."
            if fallback and type(fallback.ShowText) == "function" then opened = fallback:ShowText(text) end
        end
        if not opened then GA:Print("Tooltip-Diagnose konnte nicht geöffnet werden. /ml rolldebug verwenden.") end
    else self:Help() end
end

function Commands:OnInitialize()
    SLASH_MASTERLOOTER1 = "/ml"
    SLASH_MASTERLOOTER2 = "/masterlooter"
    SlashCmdList.MASTERLOOTER = function(message) Commands:Handle(message) end
    SLASH_MASTERLOOTERDIRECT1 = "/lootmaster"
    SLASH_MASTERLOOTERDIRECT2 = "/mlmaster"
    SlashCmdList.MASTERLOOTERDIRECT = function()
        if not showWindow("master") then GA:Print("Lootmaster-Fenster ist nicht verfügbar.") end
    end
    return true
end

GA:RegisterModule("Commands", Commands)
