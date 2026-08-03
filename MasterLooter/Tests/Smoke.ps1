param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path)

$ErrorActionPreference = "Stop"
$tests = @(
    "MasterLooter/Tests/TestHarness.lua",
    "MasterLooter/Tests/RulesLedgerSmoke.lua",
    "MasterLooter/Tests/AdminGDKPSmoke.lua",
    "MasterLooter/Tests/LootTradeSmoke.lua",
    "MasterLooter/Tests/TradeAutomationSmoke.lua",
    "MasterLooter/Tests/TradeHandshakeSmoke.lua",
    "MasterLooter/Tests/SettingsWindowBuildSmoke.lua",
    "MasterLooter/Tests/TooltipSafetySmoke.lua",
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

    $forbidden = rg -n --glob '*.lua' --glob '!**/Core/Compat.lua' 'C_Timer|C_Container|C_AddOns|ScrollBox|BackdropTemplate' MasterLooter MasterLooter_ItemData
    if ($LASTEXITCODE -eq 0) { throw "API incompatible with 3.3.5a found:`n$forbidden" }
    if ($LASTEXITCODE -gt 1) { throw "API scan could not run" }

    git diff --check
    if ($LASTEXITCODE -ne 0) { throw "git diff --check found invalid changes" }
    Write-Host "PASS: smoke, manifest, 3.3.5a API and diff checks"
}
finally {
    Pop-Location
}
