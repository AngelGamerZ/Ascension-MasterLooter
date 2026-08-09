local _, GA = ...

-- Kept in this long-established TOC file so diagnostics remain available even
-- when a client installation accidentally retains an older manifest that does
-- not know newer standalone files.
local TooltipDebug = GA.TooltipDebug or { entries = {}, maximumEntries = 180, hooked = false, passive = true }
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
    local alpha = type(tooltip.GetAlpha) == "function" and tooltip:GetAlpha() or "?"
    local effectiveAlpha = type(tooltip.GetEffectiveAlpha) == "function" and tooltip:GetEffectiveAlpha() or "?"
    local scale = type(tooltip.GetScale) == "function" and tooltip:GetScale() or "?"
    local effectiveScale = type(tooltip.GetEffectiveScale) == "function" and tooltip:GetEffectiveScale() or "?"
    local lineCount = type(tooltip.NumLines) == "function" and tooltip:NumLines() or "?"
    local points = {}
    if type(tooltip.GetNumPoints) == "function" and type(tooltip.GetPoint) == "function" then
        for index = 1, math.min(tonumber(tooltip:GetNumPoints()) or 0, 4) do
            local point, relative, relativePoint, x, y = tooltip:GetPoint(index)
            points[#points + 1] = table.concat({ tostring(point), tooltipFrameName(relative), tostring(relativePoint), tostring(x), tostring(y) }, ":")
        end
    end
    local scripts = {}
    if type(tooltip.GetScript) == "function" then
        for _, scriptName in ipairs({ "OnShow", "OnHide", "OnUpdate", "OnTooltipSetItem" }) do
            local ok, handler = pcall(tooltip.GetScript, tooltip, scriptName)
            scripts[#scripts + 1] = scriptName .. "=" .. (ok and tostring(handler) or "nicht abfragbar")
        end
    end
    return "sichtbar=" .. shown .. ", Besitzer=" .. owner .. ", Alpha=" .. tostring(alpha) .. "/" .. tostring(effectiveAlpha) ..
        ", Skalierung=" .. tostring(scale) .. "/" .. tostring(effectiveScale) .. ", Zeilen=" .. tostring(lineCount) ..
        (#points > 0 and ", Punkte{" .. table.concat(points, ", ") .. "}" or ", Punkte=keine") ..
        (#scripts > 0 and ", Scripts{" .. table.concat(scripts, ", ") .. "}" or "")
end

function TooltipDebug:OnTooltipAction(action) self:Log("TOOLTIP_" .. tostring(action), self:TooltipState(), true) end

function TooltipDebug:InstallHooks()
    -- Ascension tooltip methods are commonly chained by several addons. Stay
    -- completely outside that chain; inspect GameTooltip only when the user
    -- explicitly opens the diagnostic report.
    self.hooked, self.passive = false, true
    self:Log("MODUS", "passiv; keine GameTooltip-Methoden gehookt")
    return true
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
        "Diagnose-Modus: " .. (self.passive and "passiv; keine GameTooltip-Hooks" or "unbekannt"), "Aktueller Zustand: " .. self:TooltipState(),
        "Einträge: " .. tostring(#self.entries), "", "Geladene Addons:",
    }
    if metadata and tostring(metadata) ~= "API nicht verfügbar" and tostring(metadata) ~= tostring(GA.VERSION) then
        table.insert(lines, 4, "INSTALLATIONSWARNUNG: Lua- und TOC-Version unterscheiden sich; Addonordner vollständig ersetzen.")
    end
    for _, addonLine in ipairs(self:GetLoadedAddons()) do lines[#lines + 1] = "- " .. addonLine end
    lines[#lines + 1] = ""; lines[#lines + 1] = "MasterLooter-Ladefehler:"
    if #(GA.errors or {}) == 0 then lines[#lines + 1] = "- keine" end
    for _, entry in ipairs(GA.errors or {}) do lines[#lines + 1] = "- " .. tostring(entry.context) .. ": " .. tostring(entry.message) end
    lines[#lines + 1] = ""; lines[#lines + 1] = "Zeitleiste:"
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = string.format("[%08.3f] %s | %s", tonumber(entry.at) or 0, entry.kind, entry.detail)
        if entry.stack and entry.stack ~= "" then lines[#lines + 1] = "  Stack: " .. entry.stack end
    end
    local text = table.concat(lines, "\n")
    return type(GA.Localize) == "function" and GA:Localize(text) or text
end

function TooltipDebug:Clear() self.entries = {}; self:Log("RESET", "Diagnoseprotokoll geleert") end
function TooltipDebug:OnInitialize()
    self:InstallHooks()
    for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "CURSOR_UPDATE" }) do
        GA.Events:On(event, function(_, eventName, ...)
            local first, second = ...
            TooltipDebug:Log("EVENT_" .. eventName, "arg1=" .. tostring(first) .. ", arg2=" .. tostring(second))
        end, self, -100)
        GA.Events:RegisterGameEvent(event)
    end
    self:Log("START", "Passive Tooltip-Diagnose initialisiert"); return true
end

if not (GA.modules and GA.modules.TooltipDebug) then GA:RegisterModule("TooltipDebug", TooltipDebug) end

local Commands = {}

local function safeCount(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do count = count + 1 end
    return count
end

local function diagnosticCall(callback, fallback)
    local ok, result = pcall(callback)
    if ok then return result, nil end
    return fallback, tostring(result)
end

local function clientBuildText()
    if type(GetBuildInfo) ~= "function" then return "API nicht verfügbar" end
    local ok, version, build, date, toc = pcall(GetBuildInfo)
    if not ok then return "FEHLER: " .. tostring(version) end
    return table.concat({ tostring(version or "?"), tostring(build or "?"), tostring(date or "?"), "TOC " .. tostring(toc or "?") }, " | ")
end

function GA:GetFullDiagnosticText()
    local tocVersion = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("MasterLooter", "Version") or "API nicht verfügbar"
    local lines = {
        "MasterLooter – Gesamtdiagnose",
        "Lua-Version: " .. tostring(self.VERSION),
        "TOC-Version: " .. tostring(tocVersion),
        "Protokoll: " .. tostring(self.PROTOCOL_VERSION),
        "Realm: " .. tostring(type(GetRealmName) == "function" and GetRealmName() or "unbekannt"),
        "Locale: " .. tostring(type(GetLocale) == "function" and GetLocale() or "unbekannt"),
        "Lua: " .. tostring(_VERSION or "unbekannt"),
        "Client: " .. clientBuildText(),
        "Debug-Modus: " .. (self:IsDebugMode() and "AN (2000 Trace-Einträge + Fehlerstacks)" or "AUS (500 Trace-Einträge)"),
        "Zeit: " .. tostring(type(GetTime) == "function" and GetTime() or 0),
        "",
        "MODULE",
    }
    if tocVersion and tostring(tocVersion) ~= "API nicht verfügbar" and tostring(tocVersion) ~= tostring(self.VERSION) then
        table.insert(lines, 5, "INSTALLATIONSWARNUNG: Gemischte Addonversion; MasterLooter-Ordner vollständig löschen und frisch installieren.")
    end
    for index, module in ipairs(self.moduleOrder or {}) do
        lines[#lines + 1] = string.format("%02d %s | initialisiert=%s, aktiviert=%s", index,
            tostring(module.name or "?"), tostring(module.initialized and true or false), tostring(module.enabled and true or false))
    end

    lines[#lines + 1] = ""; lines[#lines + 1] = "FEHLER"
    if #(self.errors or {}) == 0 then lines[#lines + 1] = "keine" end
    for _, entry in ipairs(self.errors or {}) do
        lines[#lines + 1] = table.concat({ tostring(entry.time or 0), tostring(entry.context or "?"), tostring(entry.message or ""):gsub("[\r\n\t]", " ") }, " | ")
        if entry.stack and entry.stack ~= "" then lines[#lines + 1] = "Stack: " .. tostring(entry.stack):gsub("[\r\n]+", " <- ") end
    end

    lines[#lines + 1] = ""; lines[#lines + 1] = "KOMPATIBILITÄT"
    local capabilities = self.Compat and type(self.Compat.GetCapabilities) == "function" and self.Compat:GetCapabilities() or {}
    for _, key in ipairs({ "legacyGroupAPI", "modernGroupAPI", "legacyContainerAPI", "modernContainerAPI", "legacyAddonMessages", "modernAddonMessages", "itemGUID" }) do
        lines[#lines + 1] = tostring(key) .. "=" .. tostring(capabilities[key] and true or false)
    end
    local settings = self.UI and self.UI.SettingsWindow
    lines[#lines + 1] = "Settings: Frame=" .. tostring(settings and settings.frame ~= nil) .. ", vollständig=" .. tostring(settings and settings.buildComplete and true or false) ..
        ", Generation=" .. tostring(settings and settings.buildGeneration or 0) .. ", Fehler=" .. tostring(settings and settings.buildError or "keiner")

    lines[#lines + 1] = ""; lines[#lines + 1] = "ZUSTAND"
    local rollState, rollError = diagnosticCall(function()
        return self.RollSession and type(self.RollSession.GetState) == "function" and self.RollSession:GetState() or nil
    end, nil)
    lines[#lines + 1] = "Roll: " .. (rollState and table.concat({ "id=" .. tostring(rollState.id), "status=" .. tostring(rollState.status),
        "owner=" .. tostring(rollState.owner), "participants=" .. tostring(safeCount(rollState.participants)) }, ", ") or (rollError and ("FEHLER: " .. rollError) or "keine aktive Sitzung"))
    local lootSnapshot, lootError = diagnosticCall(function()
        return self.Loot and type(self.Loot.GetSnapshot) == "function" and self.Loot:GetSnapshot() or nil
    end, nil)
    local lootQueue, lootQueueError = diagnosticCall(function() return self.Loot and self.Loot.GetQueue and self.Loot:GetQueue(true) or {} end, {})
    lines[#lines + 1] = "Loot: " .. (lootSnapshot and ("offen=" .. tostring(lootSnapshot.open) .. ", Slots=" .. tostring(#(lootSnapshot.order or {})) ..
        ", Queue=" .. tostring(#lootQueue) .. (lootQueueError and (", QueueFehler=" .. lootQueueError) or "")) or (lootError and ("FEHLER: " .. lootError) or "nicht verfügbar"))
    local pending, tradeError = diagnosticCall(function() return self.Trade and type(self.Trade.GetPending) == "function" and self.Trade:GetPending() or {} end, {})
    lines[#lines + 1] = "Handel: Status=" .. tostring(self.Trade and self.Trade.state or "nicht verfügbar") .. ", offen=" .. tostring(#pending) ..
        (tradeError and (", FEHLER=" .. tradeError) or "")
    lines[#lines + 1] = "Comm: Trace=" .. tostring(self.Comm and self.Comm.trace and #self.Comm.trace or 0) ..
        ", Fragmente=" .. tostring(self.Comm and safeCount(self.Comm.fragments) or 0)

    lines[#lines + 1] = ""; lines[#lines + 1] = "LOOT-KLICK"
    local lootClickText, lootClickError = diagnosticCall(function()
        local window = self.UI and self.UI.LootWindow
        return window and type(window.GetHookDiagnosticText) == "function" and window:GetHookDiagnosticText() or "nicht verfügbar"
    end, "nicht verfügbar")
    lines[#lines + 1] = lootClickText .. (lootClickError and ("\nFEHLER: " .. lootClickError) or "")

    lines[#lines + 1] = ""; lines[#lines + 1] = "UI"
    local uiNames = {}
    for name in pairs(self.UI or {}) do uiNames[#uiNames + 1] = name end
    table.sort(uiNames)
    for _, name in ipairs(uiNames) do
        local controller = self.UI[name]
        if type(controller) == "table" then
            local shown, uiError = diagnosticCall(function()
                return controller.frame and type(controller.frame.IsShown) == "function" and controller.frame:IsShown() or false
            end, false)
            lines[#lines + 1] = tostring(name) .. " | vorhanden=ja, Frame=" .. tostring(controller.frame ~= nil) .. ", sichtbar=" .. tostring(shown and true or false) ..
                (uiError and (", FEHLER=" .. uiError) or "")
        end
    end

    lines[#lines + 1] = ""; lines[#lines + 1] = "KOMMUNIKATION"
    local commText, commError = diagnosticCall(function()
        return self.Comm and type(self.Comm.ExportTrace) == "function" and self.Comm:ExportTrace() or "nicht verfügbar"
    end, "nicht verfügbar")
    lines[#lines + 1] = commText .. (commError and ("\nFEHLER: " .. commError) or "")

    lines[#lines + 1] = ""; lines[#lines + 1] = "TOOLTIP"
    local tooltipText, tooltipError = diagnosticCall(function()
        return self.TooltipDebug and type(self.TooltipDebug.GetText) == "function" and self.TooltipDebug:GetText() or "nicht verfügbar"
    end, "nicht verfügbar")
    lines[#lines + 1] = tooltipText .. (tooltipError and ("\nFEHLER: " .. tooltipError) or "")

    lines[#lines + 1] = ""; lines[#lines + 1] = "GESAMT-TRACE"
    for _, entry in ipairs(self.debugTrace or {}) do
        lines[#lines + 1] = string.format("#%d [%08.3f] %s/%s | %s", tonumber(entry.sequence) or 0, tonumber(entry.at) or 0,
            tostring(entry.category or "?"), tostring(entry.action or "?"), tostring(entry.detail or ""))
    end
    local text = table.concat(lines, "\n")
    return type(self.Localize) == "function" and self:Localize(text) or text
end

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
    GA:Print(GA:L("command.help.overview"))
    GA:Print(GA:L("command.help.roll"))
    GA:Print(GA:L("command.help.rules"))
    GA:Print(GA:L("command.help.trust"))
    GA:Print(GA:L("command.help.debug"))
    GA:Print(GA:L("command.help.windows"))
end

function Commands:Handle(message)
    local command, rest = split(message)
    if command == "" or command == "show" then
        if GA.UI and GA.UI.SettingsWindow then GA.UI.SettingsWindow:Show() end
    elseif WINDOWS[command] then
        if not showWindow(command) then GA:Print(GA:L("command.window_unavailable", command)) end
    elseif command == "roll" then
        local link = string.match(rest, "(|c%x+|Hitem:.-|h.-|h|r)") or string.match(rest, "(|Hitem:.-|h.-|h)")
        local seconds = tonumber(string.match(rest, "(%d+)%s*$")) or 30
        local state, err = GA.RollSession:Start(link, { duration = seconds })
        if not state then GA:Print(err) end
    elseif command == "sr" then
        local player, id = string.match(rest, "^(%S+)%s+(%-?%d+)")
        if not player or not id then GA:Print(GA:L("command.usage.sr"))
        else
            local ok, err = GA.SoftRes:Reserve(player, id)
            GA:Print(ok and GA:L("command.sr_added", player, id) or err)
        end
    elseif command == "plus" then
        local player, value = string.match(rest, "^(%S+)%s*(%d*)")
        if player then GA:Print(player .. ": +" .. GA.PlusOnes:Set(player, value ~= "" and value or GA.PlusOnes:Get(player) + 1)) end
    elseif command == "sync" then
        local player = string.match(rest or "", "^(%S+)")
        local packet, err = GA.RuleSync and GA.RuleSync:Request(player)
        GA:Print(packet and GA:L("command.rules_requested", player) or tostring(err or GA:L("command.rules_unavailable")))
    elseif command == "trust" then
        local player, state = string.match(rest or "", "^(%S+)%s+(%S+)")
        state = string.lower(state or "")
        if not player or (state ~= "on" and state ~= "off") then GA:Print(GA:L("command.usage.trust"))
        else
            local ok, err = GA.RuleSync and GA.RuleSync:SetTrusted(player, state == "on")
            GA:Print(ok and GA:L(state == "on" and "command.trusted" or "command.untrusted", player) or tostring(err))
        end
    elseif command == "gdkp" then
        local sub, args = split(rest)
        if sub == "start" then GA.GDKP:Start(args ~= "" and args or nil)
        elseif sub == "sale" then
            local link = string.match(args, "(|c%x+|Hitem:.-|h.-|h|r)")
            local buyer, amount = string.match(args, "%s([^%s]+)%s+(%d+)%s*$")
            local sale, err = GA.GDKP:AddSale(link, buyer, amount); if not sale then GA:Print(err) end
        elseif sub == "finish" then GA.GDKP:Finish()
        else GA:Print(GA:L("command.gdkp_usage")) end
    elseif command == "version" then GA:Print(GA:L("command.version", GA.VERSION, GA.PROTOCOL_VERSION))
    elseif command == "rolldebug" then
        local window = GA.UI and GA.UI.RollDebugWindow
        if window and type(window.Show) == "function" then window:Show()
        else
            local tracker = GA.ChatRolls
            GA:Print(tracker and tracker:GetDiagnosticText() or GA:L("command.rolltracker_missing"))
        end
    elseif command == "commdebug" then
        local window = GA.UI and GA.UI.CommDebugWindow
        if window and type(window.Show) == "function" then window:Show()
        else GA:Print(GA:L("command.comm_debug_missing")) end
    elseif command == "debug" then
        local debugAction = string.lower(trim(rest or ""))
        if debugAction == "on" then
            GA:SetDebugMode(true); GA:Print(GA:L("command.debug_enabled")); return
        elseif debugAction == "off" then
            GA:SetDebugMode(false); GA:Print(GA:L("command.debug_disabled")); return
        elseif debugAction == "status" then
            GA:Print(GA:L(GA:IsDebugMode() and "command.debug_status_on" or "command.debug_status_off")); return
        elseif debugAction == "clear" then
            if GA.ClearDebugTrace then GA:ClearDebugTrace() end
            if GA.Comm and type(GA.Comm.ClearTrace) == "function" then GA.Comm:ClearTrace() end
            if GA.TooltipDebug and type(GA.TooltipDebug.Clear) == "function" then GA.TooltipDebug:Clear() end
            GA:Print(GA:L("command.debug_cleared"))
        end
        local window = GA.UI and GA.UI.AddonDebugWindow
        if window and type(window.Show) == "function" then window:Show()
        else
            local fallback = GA.UI and GA.UI.RollDebugWindow
            if fallback and type(fallback.ShowText) == "function" then fallback:ShowText(GA:GetFullDiagnosticText())
            else GA:Print(GA:L("command.debug_open_failed")) end
        end
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
            local tocVersion = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("MasterLooter", "Version") or "API nicht verfügbar"
            local text = GA.TooltipDebug and type(GA.TooltipDebug.GetText) == "function" and GA.TooltipDebug:GetText() or
                ("MasterLooter Tooltip-Diagnose\nDiagnosemodul oder Fenster konnte nicht geladen werden.\nLua-Version: " .. tostring(GA.VERSION) .. "\nTOC-Version: " .. tostring(tocVersion))
            if fallback and type(fallback.ShowText) == "function" then opened = fallback:ShowText(text) end
        end
        if not opened then GA:Print(GA:L("command.tooltip_debug_failed")) end
    else self:Help() end
end

function Commands:OnInitialize()
    SLASH_MASTERLOOTER1 = "/ml"
    SLASH_MASTERLOOTER2 = "/masterlooter"
    SlashCmdList.MASTERLOOTER = function(message) Commands:Handle(message) end
    SLASH_MASTERLOOTERDIRECT1 = "/lootmaster"
    SLASH_MASTERLOOTERDIRECT2 = "/mlmaster"
    SlashCmdList.MASTERLOOTERDIRECT = function()
        if not showWindow("master") then GA:Print(GA:L("command.master_window_missing")) end
    end
    return true
end

GA:RegisterModule("Commands", Commands)
