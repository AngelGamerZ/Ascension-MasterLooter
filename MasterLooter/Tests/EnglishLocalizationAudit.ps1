param([string]$AddonRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path)

$ErrorActionPreference = "Stop"

function Convert-LuaLiteral([string]$Value) {
    return $Value.Replace('\"', '"').Replace('\\', '\').Replace('\n', "`n").Replace('\r', "`r").Replace('\t', "`t")
}

function Get-RawCatalogText([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw
    # canonicalReverse has the opposite direction and must not be mistaken for
    # another German->English raw catalog by the static parser.
    return ($text -split 'for source, english in pairs\(raw\)', 2)[0]
}
$catalogText = @(
    Get-RawCatalogText (Join-Path $AddonRoot "Locales/UI.lua")
    Get-RawCatalogText (Join-Path $AddonRoot "Locales/Errors.lua")
) -join "`n"
$phraseText = (@(
    Get-Content -LiteralPath (Join-Path $AddonRoot "Locales/UI.lua") -Raw
    Get-Content -LiteralPath (Join-Path $AddonRoot "Locales/Errors.lua") -Raw
) | ForEach-Object { [regex]::Match($_, '(?s)GA\.Locale:RegisterPhrases\(\{(.*)\}\)\s*$').Groups[1].Value }) -join "`n"

$exact = @{}
$reverseExact = @{}
$catalogKeys = @{}
$exactPattern = [regex]'\["((?:\\.|[^"\\])*)"\]\s*=\s*"((?:\\.|[^"\\])*)"'
foreach ($match in $exactPattern.Matches($catalogText)) {
    $source = Convert-LuaLiteral $match.Groups[1].Value
    $english = Convert-LuaLiteral $match.Groups[2].Value
    if ($catalogKeys.ContainsKey($source) -and $exact[$source] -ne $english) {
        throw "Conflicting localization source key: $source => $($exact[$source]) / $english"
    }
    $catalogKeys[$source] = $true
    $exact[$source] = $english
    $reverseExact[$english] = $source
}

$phrases = [Collections.Generic.List[object]]::new()
$phrasePattern = [regex]'\{\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*\}'
foreach ($match in $phrasePattern.Matches($phraseText)) {
    $phrases.Add(@((Convert-LuaLiteral $match.Groups[1].Value), (Convert-LuaLiteral $match.Groups[2].Value)))
}

$germanWords = @(
    'abbrechen','abgeschlossen','aktualisieren','allgemein','anwenden','anzahl','ausgewählt','auswahl',
    'bedienelemente','bereit','betrag','bieten','bieter','buchen','daten','dauer','eintrag','einstellungen',
    'erfasst','fehler','fenster','frist','gebot','gelöscht','gespeichert','gewinner','gruppe','handel',
    'historie','keine','keiner','klicken','lootfenster','löschen','nachricht','nicht','noch','notiz',
    'offen','öffnen','profil','prüfung','regeln','rollen','schließen','sekunden','speichern','spieler',
    'standarddauer','starten','stoppen','strichliste','suche','taschen','übernommen','verfügbar','vergeben',
    'verteilung','verwaltung','wählen','wird','wurden','zahlung','zielspieler','zuerst','zurück',
    'aktiv','aktive','automatisch','dein','deine','eigene','eingereiht','erkannt','ergebnis','familie','geht','grund',
    'importiert','installiert','kopierbare','quelle','regel','reservierung','strichstand','taste','weitere','ziel','abgelehnt','unbekannt',
    'menge','tasche','gehandelt','entzaubert','verloren','alle','aufgenommen','gefallen','zeit','leiter','assistent','mitglied',
    'rang','passen','raidverwaltung','neuigkeiten','versionscheck','gesamtdiagnose','kommunikationsdiagnose','roll-diagnose',
    'tooltip-diagnose','ansagekanal','raid-warnung','sagen','schreien','offizier','gilde','mindestgebot',
    # Grammar words and UI verbs matter as much as nouns.  The old noun-heavy
    # list missed complete labels such as "Taschenabfragen durch
    # Gruppenmitglieder erlauben" even though every word was user-facing.
    'aber','als','also','andere','anderen','auch','auf','aus','bei','beim','bereits','bis','bitte','damit','dann',
    'das','dein','deine','deinen','deiner','dem','den','der','des','die','dies','diese','dieser','dieses','durch',
    'eigenen','ein','eine','einem','einen','einer','eines','erlauben','erlaubt','gegen','hat','hier','im','kann',
    'konnte','mit','muss','mÃ¼ssen','nach','nur','oder','ohne','sich','sind','soll','Ã¼ber','um','und','vom','von','vor',
    'wenn','werden','zu','zum','zur','abfragen','abfrage','anzeigen','angezeigt','ausfÃ¼hren','ausgefÃ¼hrt','Ã¶ffentlich',
    'gruppenmitglieder','gruppenmitglied','gÃ¼ltig','ungÃ¼ltig','geÃ¶ffnet','geschlossen','geladen','gelÃ¶scht','gewÃ¤hlt',
    'empfÃ¤nger','sitzung','profilname','quellprofil','zielprofil','handelsreichweite','handelsfenster','handelsfrist',
    'taschenstack','zurÃ¼cksetzen','zurÃ¼ckgesetzt','verÃ¶ffentlichen','vertrauenswÃ¼rdig','auÃŸerhalb','bereichs'
)
$germanPattern = '(?i)([äöüß]|\b(?:' + (($germanWords | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b)'

function Test-German([string]$Value) { return $Value -match $germanPattern }
function Get-English([string]$Value) {
    if ($exact.ContainsKey($Value)) { return $exact[$Value] }
    $translated = $Value
    foreach ($pair in $phrases) { $translated = $translated.Replace($pair[0], $pair[1]) }
    return $translated
}
function Get-German([string]$Value) {
    if ($reverseExact.ContainsKey($Value)) { return $reverseExact[$Value] }
    $translated = $Value
    foreach ($pair in $phrases) { $translated = $translated.Replace($pair[1], $pair[0]) }
    return $translated
}

$tocPath = Join-Path $AddonRoot "MasterLooter.toc"
$toc = Get-Content -LiteralPath $tocPath
$productionFiles = @($toc | Where-Object { $_ -match '\.(?:lua|xml)\s*$' -and $_ -notmatch '^\s*##' } | ForEach-Object {
    Join-Path $AddonRoot ($_.Trim().Replace('\', [IO.Path]::DirectorySeparatorChar))
}) + @($tocPath)
$literalPattern = [regex]'(?s)(?:"((?:\\.|[^"\\])*)"|''((?:\\.|[^''\\])*)'')'
$failures = [Collections.Generic.List[string]]::new()
$englishErrorFailures = [Collections.Generic.List[string]]::new()
$englishUiFailures = [Collections.Generic.List[string]]::new()
$seen = @{}
$identityUiText = @{
    "MasterLooter" = $true; "SoftRes" = $true; "Hard Reserve" = $true; "GDKP" = $true; "PackMule" = $true
    "Import / Export" = $true; "Profile" = $true; "Item" = $true; "Items" = $true; "MS" = $true; "OS" = $true
    "PASS" = $true; "+1" = $true; "Roll" = $true; "Raid" = $true; "Status" = $true; "IDLE" = $true
}

foreach ($path in $productionFiles) {
    if ($path -like '*\Locales\*') { continue }
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        foreach ($match in $literalPattern.Matches($line)) {
            $encoded = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
            $source = Convert-LuaLiteral $encoded
            if (-not (Test-German $source)) { continue }
            $translated = Get-English $source
            if (Test-German $translated) {
                $identity = "$source`0$translated"
                if (-not $seen.ContainsKey($identity)) {
                    $seen[$identity] = $true
                    $relative = $path.Replace($AddonRoot + [IO.Path]::DirectorySeparatorChar, '')
                    $failures.Add("${relative}:$lineNumber | $source => $translated")
                }
            }
        }
        # Module failures are ultimately displayed by windows and commands.
        # English-originating return messages therefore need the reverse
        # mapping as well; checking only German source strings left deDE holes.
        if ($line -match '\breturn\s+(?:nil|false)\s*,') {
            foreach ($match in $literalPattern.Matches($line)) {
                $encoded = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                $source = Convert-LuaLiteral $encoded
                if ($source -notmatch '[A-Za-z]' -or $source -notmatch '\s' -or (Test-German $source) -or $exact.ContainsKey($source)) { continue }
                if ((Get-German $source) -eq $source) {
                    $relative = $path.Replace($AddonRoot + [IO.Path]::DirectorySeparatorChar, '')
                    $englishErrorFailures.Add("${relative}:$lineNumber | $source")
                }
            }
        }
        if ($line -match 'Theme:(?:CreateLabel|CreateButton|AddTitle)|:SetText\s*\(') {
            foreach ($match in $literalPattern.Matches($line)) {
                $encoded = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                $source = Convert-LuaLiteral $encoded
                if ($source -notmatch '[A-Za-z]' -or $source -notmatch '\s' -or (Test-German $source) -or $exact.ContainsKey($source) -or $identityUiText.ContainsKey($source) -or (Get-English $source) -ne $source) { continue }
                $technical = $source.Trim()
                if ($technical -match '^(?:MS \(/100\)|OS \(/|/roll|MasterLooter|Item |Items\)|Status:|Gold$|Pot:|Cut:|Queue:|Multi:|Slot |ID |iLvl |Index:|%d[/ ]|[0-9])') { continue }
                if ($technical -match '(?:MS /roll 100$|^Item$|Multi:|^Slot$|^ID$|iLvl|^Items /)') { continue }
                if ((Get-German $source) -eq $source) {
                    $relative = $path.Replace($AddonRoot + [IO.Path]::DirectorySeparatorChar, '')
                    $englishUiFailures.Add("${relative}:$lineNumber | $source")
                }
            }
        }
    }
}

if ($failures.Count -gt 0) {
    throw "English localization leaves German production literals:`n$($failures -join "`n")"
}
if ($englishErrorFailures.Count -gt 0) {
    throw "German localization leaves English module error literals:`n$($englishErrorFailures -join "`n")"
}
if ($englishUiFailures.Count -gt 0) {
    throw "German localization leaves English visible UI literals:`n$($englishUiFailures -join "`n")"
}

# This is the complete visible inventory of Settings -> General.  Keep it
# explicit: a future label can no longer slip through merely because its words
# were absent from the language heuristic.
$settingsGeneralRaw = @(
    "Allgemein", "Grundlegendes Verhalten, Sichtbarkeit und aktive Konfiguration.",
    "Rollfenster bei neuer Verteilung automatisch öffnen", "Hinweistöne abspielen", "Minimap-Button anzeigen",
    "Taschenabfragen durch Gruppenmitglieder erlauben", "Taschenfreigabe gespeichert.",
    "PROFIL", "Aktives Profil", "Wechseln", "Profile verwalten"
)
foreach ($text in $settingsGeneralRaw) {
    if (-not $exact.ContainsKey($text) -or $exact[$text] -eq $text -or (Test-German $exact[$text])) {
        throw "Settings -> General is not fully translated: $text"
    }
}
$enLocale = Get-Content -LiteralPath (Join-Path $AddonRoot "Locales/enUS.lua") -Raw
$deLocale = Get-Content -LiteralPath (Join-Path $AddonRoot "Locales/deDE.lua") -Raw
foreach ($key in @("SETTINGS_LANGUAGE", "SETTINGS_LANGUAGE_AUTO", "SETTINGS_LANGUAGE_GERMAN", "SETTINGS_LANGUAGE_ENGLISH", "LANGUAGE_INVALID", "LANGUAGE_SAVED")) {
    if ($enLocale -notmatch ("(?m)^\s*" + [regex]::Escape($key) + "\s*=") -or $deLocale -notmatch ("(?m)^\s*" + [regex]::Escape($key) + "\s*=")) {
        throw "Settings -> General language key is incomplete: $key"
    }
}

Write-Host "PASS: $($productionFiles.Count) production files contain no untranslated German literals"
