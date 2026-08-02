# Changelog

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
