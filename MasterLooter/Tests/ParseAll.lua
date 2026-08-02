-- Syntax-check every Lua file referenced by both addon manifests. Fengari's
-- CLI intentionally has no file-reading io library, so the manifest paths are
-- repeated here and checked against the TOCs by the release build.
local files = {
    "MasterLooter/Core/Namespace.lua", "MasterLooter/Core/Compat.lua",
    "MasterLooter/Core/Events.lua", "MasterLooter/Core/DB.lua", "MasterLooter/Core/Bootstrap.lua",
    "MasterLooter/Modules/Comm.lua", "MasterLooter/Modules/BagInspector.lua",
    "MasterLooter/Modules/RollSession.lua", "MasterLooter/Modules/ChatRolls.lua",
    "MasterLooter/Modules/Loot.lua", "MasterLooter/Modules/PackMule.lua", "MasterLooter/Modules/Trade.lua",
    "MasterLooter/Modules/Award.lua", "MasterLooter/Modules/SoftRes.lua", "MasterLooter/Modules/PlusOnes.lua",
    "MasterLooter/Modules/Priority.lua", "MasterLooter/Modules/BoostedRolls.lua",
    "MasterLooter/Modules/Ranking.lua", "MasterLooter/Modules/GDKP.lua",
    "MasterLooter/Modules/GDKPAuction.lua", "MasterLooter/Modules/RaidManager.lua",
    "MasterLooter/Modules/ItemDataBridge.lua", "MasterLooter/Modules/VersionCheck.lua",
    "MasterLooter/Modules/Announcements.lua", "MasterLooter/Modules/ImportExport.lua",
    "MasterLooter/Modules/Commands.lua", "MasterLooter/UI/Theme.lua", "MasterLooter/UI/RollDebugWindow.lua",
    "MasterLooter/UI/RollWindow.lua",
    "MasterLooter/UI/MasterLooterWindow.lua", "MasterLooter/UI/HistoryWindow.lua",
    "MasterLooter/UI/SettingsWindow.lua", "MasterLooter/UI/SoftResWindow.lua",
    "MasterLooter/UI/GDKPWindow.lua", "MasterLooter/UI/GDKPAuctionWindow.lua",
    "MasterLooter/UI/RaidManagerWindow.lua", "MasterLooter/UI/VersionWindow.lua",
    "MasterLooter/UI/BagInspectorWindow.lua", "MasterLooter/UI/LootWindow.lua",
    "MasterLooter/UI/TradeWindow.lua", "MasterLooter/UI/RulesWindow.lua",
    "MasterLooter/UI/ImportExportWindow.lua", "MasterLooter/UI/Launcher.lua",
    "MasterLooter_ItemData/ItemData.lua",
}

for _, path in ipairs(files) do
    local chunk, loadError = loadfile(path)
    assert(chunk, path .. ": " .. tostring(loadError))
end

print("PASS: parsed " .. #files .. " addon Lua files")
