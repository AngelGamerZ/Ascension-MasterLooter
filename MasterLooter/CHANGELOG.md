# Changelog

## 0.9.6-beta

- Rolltracking auf öffentliche Blizzard-`/roll`-Ergebnisse umgestellt
- `MS` verwendet immer `/roll 100`; `OS` verwendet ein konfigurierbares Maximum zwischen 2 und 99
- Spieler ohne MasterLooter können mit den angekündigten Befehlen vollständig an MS-/OS-Würfen teilnehmen
- Deutsche und englische `CHAT_MSG_SYSTEM`-Wurfmeldungen werden ausgewertet
- Der erste gültige Wurf pro Spieler wird übernommen; falsche Bereiche und Wiederholungswürfe werden ignoriert
- Startansage enthält die aktuellen MS-/OS-Befehle
- Bei mehr als zehn verbleibenden Sekunden erfolgt alle zehn Sekunden eine Erinnerung, danach jede Sekunde
- Netzwerkprotokoll auf Version 3 erweitert und OS-Maximum zwischen Clients synchronisiert

## 0.9.5-beta

- Sichtbare Rolloptionen von `Haupt-Skill` und `Neben-Skill` auf die üblichen Kurzformen `MS` und `OS` geändert
- Rückmeldungen beim Masterlooter verwenden ebenfalls durchgehend `MS` und `OS`

## 0.9.4-beta

- Beide Rollfenster auf 560×124 Pixel reduziert und standardmäßig weiter nach oben auf `BOTTOM +105` gesetzt
- Neue Positionsversion überschreibt die zu tiefe Beta-Standardposition
- Teilnehmerfenster schließen beim Ablauf der Rollzeit automatisch
- Der Host beendet die Sitzung bei null verbindlich für alle verbundenen Clients
- Gruppen-/Raidankündigungen bei 30-Sekunden-Intervallen, 20, 15 und ab 10 jede Sekunde
- Eingehende MS-, OS- und Pass-Antworten erscheinen unmittelbar mit Spielername und Wurf beim Masterlooter
- Gültige Würfe bleiben beim Host erhalten, selbst wenn der Bestätigungs-Whisper vorübergehend scheitert

## 0.9.3-beta

- MasterLooter- und native Gruppenloot-Rollfenster auf kompakte 720×124 Pixel reduziert
- Beide Fenster öffnen mit einer neuen Positions-ID garantiert im unteren Bildschirmviertel
- Kleinere Item-Icons, Schriften und Aktionsbuttons für freie Sicht auf das Spielgeschehen
- Natives Gruppenloot erlaubt `Passen` jetzt immer ausdrücklich und aktiviert den Button korrekt
- Der verteilte MasterLooter-Pass-Pfad wird vollständig bis zur Host-Bestätigung getestet

## 0.9.2-beta

- Teilnehmerfenster als breite, flache Leiste im unteren Bildschirmdrittel neu gestaltet
- Item, Notiz, Restzeit, Rollaktionen und Status visuell klar getrennt
- Countdown wird beim Öffnen sofort korrekt angezeigt
- Zeitsynchronisation verwendet exakte Restsekunden und lokale monotone `GetTime()`-Deadlines
- Späte Synchronisation verlängert den Countdown nicht mehr künstlich auf fünf Sekunden
- Lootmaster-Eingaben mit klarer Ablagefläche, validierter Rollzeit, ±5-Schritten und optionaler Notiz verbessert
- Start-, Fehler-, Versand-, Aktiv- und Abschlusszustände liefern direktes visuelles Feedback
- Eingaben werden während einer laufenden Session gesperrt und danach zuverlässig reaktiviert

## 0.9.1-beta

- Das Lootmaster-Fenster verwendet jetzt eine echte Item-Ablagefläche mit Icon, Itemname und Tooltip statt eines sichtbaren Itemlink-Textfelds
- Drag-and-drop aus Taschen, dem Blizzard-Lootfenster und der MasterLooter-Lootliste
- Rechtsklick auf die Ablagefläche entfernt die aktuelle Auswahl
- Dokumentation und Ingame-Testcheckliste für den neuen Ablauf aktualisiert

## 0.9.0-beta

- Eigenständiger Core für Interface 30300 mit Legacy-Kompatibilität, Profilen und Migrationen
- Versioniertes Mehrclient-Protokoll mit Fragmentierung, Quoten, Dedupe, Sync und Senderprüfung
- Autoritative Roll-Sitzungen: automatische Teilnehmerfenster, MS/OS/Pass, hostgenerierte Wurfzahlen und Award
- Loot-, PackMule- und bestätigte Trade-Warteschlangen
- SoftRes/HardRes, Prioritäten, +1, Boosted Rolls und deterministische Rangfolge
- GDKP-Ledger und synchronisierte, manipulationsgeschützte Auktionen mit Anti-Snipe
- Native Gruppenloot-Unterstützung, Raidverwaltung, Versionscheck und Tascheninspektor
- Historie, Import/Export, Einstellungen, Minimap-Launcher und klassische 3.3.5a-Oberflächen
- Optionaler Ascension-Itemindex mit Runtime-Learning und AtlasLoot-Integration
- Zwei isolierte Clients im Test-Harness, Manipulations-/Fehlerpfade und Lua-5.1-Parsing
