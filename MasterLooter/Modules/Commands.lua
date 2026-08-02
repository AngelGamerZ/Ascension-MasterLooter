local _, GA = ...

local Commands = {}

local function trim(value) return string.match(value or "", "^%s*(.-)%s*$") end
local function split(message)
    local command, rest = string.match(trim(message), "^(%S+)%s*(.-)$")
    return string.lower(command or ""), rest or ""
end

local WINDOWS = {
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
    GA:Print("/ml – Lootmaster-Fenster | /ml roll <Itemlink> [Sekunden]")
    GA:Print("/ml sr <Spieler> <Item-ID> | /ml plus <Spieler> [Wert]")
    GA:Print("/ml gdkp start|sale|finish | /ml version")
    GA:Print("/ml loot|trade|softres|rules|gdkpui|auction|raid|version|bags|history|settings|io")
end

function Commands:Handle(message)
    local command, rest = split(message)
    if command == "" or command == "show" then
        if GA.UI and GA.UI.MasterLooterWindow then GA.UI.MasterLooterWindow:Show() end
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
    else self:Help() end
end

function Commands:OnInitialize()
    SLASH_MASTERLOOTER1 = "/ml"
    SLASH_MASTERLOOTER2 = "/masterlooter"
    SlashCmdList.MASTERLOOTER = function(message) Commands:Handle(message) end
    return true
end

GA:RegisterModule("Commands", Commands)
