param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path)

$ErrorActionPreference = "Stop"
$tests = @(
    "MasterLooter/Tests/TestHarness.lua",
    "MasterLooter/Tests/RulesLedgerSmoke.lua",
    "MasterLooter/Tests/RulesSyncSmoke.lua",
    "MasterLooter/Tests/ExternalImportSmoke.lua",
    "MasterLooter/Tests/WhisperQueriesSmoke.lua",
    "MasterLooter/Tests/LocalizationChannelsSmoke.lua",
    "MasterLooter/Tests/ErrorLocalizationSmoke.lua",
    "MasterLooter/Tests/NonUILocalizationSmoke.lua",
    "MasterLooter/Tests/UILocalizationSmoke.lua",
    "MasterLooter/Tests/AdminGDKPSmoke.lua",
    "MasterLooter/Tests/GDKPAdvancedSmoke.lua",
    "MasterLooter/Tests/LootTradeSmoke.lua",
    "MasterLooter/Tests/LootLedgerSmoke.lua",
    "MasterLooter/Tests/TradeAutomationSmoke.lua",
    "MasterLooter/Tests/TradeHandshakeSmoke.lua",
    "MasterLooter/Tests/MasterLooterWindowSmoke.lua",
    "MasterLooter/Tests/ThemeEditBoxSmoke.lua",
    "MasterLooter/Tests/ResetWindowsSmoke.lua",
    "MasterLooter/Tests/AdminWindowLayoutSmoke.lua",
    "MasterLooter/Tests/SettingsWindowBuildSmoke.lua",
    "MasterLooter/Tests/LauncherFallbackSmoke.lua",
    "MasterLooter/Tests/ProfilesItemSearchSmoke.lua",
    "MasterLooter/Tests/TooltipSafetySmoke.lua",
    "MasterLooter/Tests/TooltipDebugSmoke.lua",
    "MasterLooter/Tests/ParseAll.lua"
)

Push-Location -LiteralPath $RepositoryRoot
try {
    foreach ($test in $tests) {
        if (-not (Test-Path -LiteralPath $test)) { throw "Smoke-Test fehlt: $test" }
        $output = @(& npx --yes --package fengari-node-cli fengari ".\$($test -replace '/', '\')" 2>&1)
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Host $_ }
        $passed = $output | Where-Object { "$_" -match '^PASS:' } | Select-Object -First 1
        if ($exitCode -ne 0 -or -not $passed) { throw "Smoke test failed: $test" }
    }

    & "MasterLooter/Tests/EnglishLocalizationAudit.ps1" -AddonRoot (Resolve-Path "MasterLooter").Path

    $tocVersions = @{}
    foreach ($toc in @("MasterLooter/MasterLooter.toc", "MasterLooter_ItemData/MasterLooter_ItemData.toc")) {
        $content = Get-Content -LiteralPath $toc
        $version = ($content | Where-Object { $_ -like "## Version:*" } | Select-Object -First 1) -replace '^## Version:\s*', ''
        if (-not $version) { throw "Version field missing: $toc" }
        $tocVersions[$toc] = $version
        $base = Split-Path -Parent $toc
        foreach ($line in $content) {
            if ($line -match '^##' -or [string]::IsNullOrWhiteSpace($line)) { continue }
            $file = Join-Path $base ($line -replace '\\', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $file)) { throw "TOC references missing file: $file" }
        }
    }
    if ($tocVersions.Values | Select-Object -Unique | Measure-Object | Select-Object -ExpandProperty Count | Where-Object { $_ -ne 1 }) {
        throw "TOC versions do not match"
    }

    $forbidden = rg -n --glob '*.lua' --glob '!**/Core/Compat.lua' 'C_Timer|C_Container|C_AddOns|ScrollBox|BackdropTemplate|math\.mod' MasterLooter MasterLooter_ItemData
    if ($LASTEXITCODE -eq 0) { throw "API incompatible with 3.3.5a found:`n$forbidden" }
    if ($LASTEXITCODE -gt 1) { throw "API scan could not run" }

    $anonymousDropdown = rg -n --glob '*.lua' --glob '!**/Tests/**' 'CreateFrame\([^\r\n]*,\s*nil\s*,[^\r\n]*UIDropDownMenuTemplate' MasterLooter
    if ($LASTEXITCODE -eq 0) { throw "3.3.5a UIDropDownMenuTemplate frames must be named:`n$anonymousDropdown" }
    if ($LASTEXITCODE -gt 1) { throw "Legacy dropdown naming scan could not run" }

    $forbiddenLuaSyntax = rg -n --glob '*.lua' --glob '!**/Tests/**' '\btable\.(pack|unpack)\b|\brawlen\b|\b_ENV\b|::[A-Za-z_][A-Za-z0-9_]*::|\bgoto\s+[A-Za-z_]' MasterLooter MasterLooter_ItemData
    if ($LASTEXITCODE -eq 0) { throw "Lua feature newer than the 3.3.5a Lua 5.1 runtime found:`n$forbiddenLuaSyntax" }
    if ($LASTEXITCODE -gt 1) { throw "Lua 5.1 compatibility scan could not run" }

    $directModernAPI = rg -n --glob '*.lua' --glob '!**/Tests/**' --glob '!**/Core/Compat.lua' '_G\.(GetNumGroupMembers|IsInGroup|IsInRaid)|\bC_[A-Za-z0-9_]+\.' MasterLooter MasterLooter_ItemData
    if ($LASTEXITCODE -eq 0) { throw "Modern API bypasses the 3.3.5a compatibility layer:`n$directModernAPI" }
    if ($LASTEXITCODE -gt 1) { throw "Direct modern API scan could not run" }

    foreach ($uiFile in Get-ChildItem -LiteralPath "MasterLooter/UI" -Filter "*.lua") {
        $source = Get-Content -LiteralPath $uiFile.FullName -Raw
        if ($source -match '\bTheme:' -and $uiFile.Name -ne 'Theme.lua' -and $source -notmatch 'local\s+Theme\b[^\r\n]*=\s*GA\.UI\.Theme') {
            throw "UI file uses an unresolved global Theme value: $($uiFile.FullName)"
        }
    }

    $forbiddenGlobalInput = rg -n --glob '*.lua' --glob '!**/Tests/**' 'GetMouseFocus|IsMouseButtonDown|HandleGlobalModifiedClick|PollGlobalInput' MasterLooter
    if ($LASTEXITCODE -eq 0) { throw "Forbidden global inventory/loot input integration found:`n$forbiddenGlobalInput" }
    if ($LASTEXITCODE -gt 1) { throw "Global input integration scan could not run" }

    $forbiddenTradeAccept = rg -n --glob '*.lua' --glob '!**/Tests/**' 'AcceptTrade' MasterLooter
    if ($LASTEXITCODE -eq 0) { throw "Trade acceptance must remain manual:`n$forbiddenTradeAccept" }
    if ($LASTEXITCODE -gt 1) { throw "Trade acceptance scan could not run" }

    $globalTooltipUI = rg -n --glob '*.lua' --glob '!Theme.lua' 'GameTooltip[\.:]' MasterLooter/UI
    if ($LASTEXITCODE -eq 0) { throw "MasterLooter UI must use its private tooltip instead of GameTooltip:`n$globalTooltipUI" }
    if ($LASTEXITCODE -gt 1) { throw "Global tooltip isolation scan could not run" }

    $itemDataBagEvent = rg -n 'RegisterEvent\("BAG_UPDATE"\)|event\s*==\s*"BAG_UPDATE"' MasterLooter_ItemData
    if ($LASTEXITCODE -eq 0) { throw "ItemData must not scan all bags during live BAG_UPDATE:`n$itemDataBagEvent" }
    if ($LASTEXITCODE -gt 1) { throw "ItemData BAG_UPDATE scan could not run" }

    git diff --check
    if ($LASTEXITCODE -ne 0) { throw "git diff --check found invalid changes" }
    Write-Host "PASS: smoke, manifest, 3.3.5a API and diff checks"
}
finally {
    Pop-Location
}
