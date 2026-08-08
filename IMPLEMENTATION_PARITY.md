# MasterLooter 0.16.5-beta – Funktionsparität

Diese Matrix bildet den Clean-Room-Funktionskatalog aus `REVERSE_ENGINEERING_REPORT.md` auf die eigenständige Ascension-3.3.5a-Implementierung ab. „Mit Clientgrenze“ bedeutet, dass der Ablauf vollständig modelliert ist, der alte Client oder der Server aber keine verbindliche API für den letzten Schritt bereitstellt.

| Bereich | Status | Umsetzung in MasterLooter |
|---|---|---|
| Loot-Erkennung und Lifecycle-Ledger | umgesetzt, mit Clientgrenze | Persistente Zustände `DROPPED`, `ACQUIRED`, `AWARDED`, `TRADED`, `DISENCHANTED`, `LOST`; Instanz/Boss bestmöglich; abgeleitete Zustände werden als Schätzung markiert |
| Roll-Off / Roll-Tracking | umgesetzt | Öffentliche `/roll 100`- und `/roll X`-Würfe, Addon- und Nicht-Addon-Spieler, Gruppen/Raid-Erfassung, Warteschlange, Countdown, MS/OS/Passen |
| Awarded Loot / Strichliste | umgesetzt | Direkte Vergabe, bestätigte Zustellung, manuelle Gewinnerwahl, getrennte G/MS/OS-Zähler und ausschließlich manueller `+1`-Button |
| PackMule | umgesetzt, klickgebunden | Qualitäts-/Bindungs-/Ziel-/Disenchanter-/Round-Robin-Regeln, Ausnahmen und nebenwirkungsfreie Vorschau mit Begründung |
| Handel und Frist | umgesetzt, mit Clientgrenze | Automatisches Anhandeln und Einlegen, Whisper-Fallback, geschätzte Zwei-Stunden-Leiste und Warnungen; Annahme/Abschluss bleiben bewusst manuell |
| SoftRes / HardRes | umgesetzt | Reservierungen, Limits, Notizen, Verbrauch, BISBEARD-Import, LootReserve-Anbindung und Rankingintegration |
| TMB / Prioritäten | umgesetzt | TMB, DFT, ClassicPR/CSV und RRobin mit Paste-Import sowie Prioritätsanzeige im Ranking |
| Plus Ones | umgesetzt | Manuelle Pflege, Auditdaten und abgesicherter Snapshot-Sync |
| Boosted Rolls | umgesetzt | Punktelogik, Rankingintegration und abgesicherter Snapshot-Sync |
| AutoRoll | umgesetzt, sicherer 3.3.5a-Ablauf | Priorisierte Regeln liefern MS-/OS-/Passen-Empfehlungen; der geschützte öffentliche Wurf erfolgt erst per Nutzerklick |
| GDKP-Sitzung und Ledger | umgesetzt | Verkäufe, Pot, Goldtransaktionen, Zahlungsstatus, Korrekturen, Teilnehmer und Persistenz |
| GDKP-Einzelauktion | umgesetzt | Mindestgebot, Schrittweite, Anti-Snipe, Replay-Schutz und Warteschlange |
| GDKP-Multi-Auction | umgesetzt | Bis zu vier parallele Auktionen, unabhängige Sequenzen/Bieter, Taschenqueue und Reload-Wiederherstellung |
| GDKP-Pot und Cuts | umgesetzt | Gewichtete Cuts, Management-Cut, Mutatoren, Cut-Texte, Preislisten sowie versionierter Im-/Export |
| Raidverwaltung | umgesetzt | Übersicht, Bereitschaftscheck, Gruppenaktionen, Befördern, Degradieren und Entfernen |
| Version, Identität und Diagnose | umgesetzt | Versionsabgleich, Roll-/Kommunikations-/Tooltip- und Gesamtdiagnose mit kopierbarem Trace |
| Itemindex und Suche | umgesetzt, laufzeitlernend | Realm-/Locale-/Interface-getrennter Cache, Client-/Chat-/Taschenlernen, optionale AtlasLoot-Übernahme, Suche nach Name/ID/Qualität/Itemlevel |
| Profile und Datenverwaltung | umgesetzt | Erstellen, kopieren, umbenennen, löschen, charakterspezifisch zuweisen und zweistufig bestätigter Komplett-Reset |
| Navigation und Einstieg | umgesetzt | Minimap-Aktionen, `/ml`-Werkzeugübersicht, eigenständige Top-Level-Fenster, Willkommens-/Neuigkeitenfenster und WoW-Tastenkürzel |
| Kommunikation und Regel-Sync | umgesetzt | Fragmentierung/Deduplizierung sowie vertrauensgeprüfte, versionierte Regel-Snapshots mit Prüfsumme, Replay- und Konfliktschutz |

## Bewusste Abweichungen

- Es wird kein Gargul-Code, Gargul-Asset und kein Gargul-Protokoll kopiert. MasterLooter besitzt ein eigenes, versioniertes Protokoll.
- Eine automatische Handelsannahme ist absichtlich ausgeschlossen. Der Gewinner wird geprüft und die Items werden eingelegt; beide Parteien bestätigen den Abschluss selbst.
- 3.3.5a meldet weder eine verlässliche serverseitige Resthandelszeit noch für jedes Lootereignis einen eindeutigen Empfänger. Die Oberfläche kennzeichnet Schätzungen statt falsche Gewissheit anzuzeigen.
- Die Ascension-Webdatenbank wird nicht gescrapt. Der Itemindex lernt echte Clientdaten und übernimmt vorhandene AtlasLoot-Daten, damit Custom-Seasons und Itemvarianten nicht durch einen veralteten Snapshot verfälscht werden.
- Geschützte Aktionen wie `/roll`, Masterloot und bestimmte Gruppenaktionen bleiben an einen Hardwareklick gebunden.

## Noch erforderliche Abnahme außerhalb der Simulation

Der Codeumfang ist implementiert. Vor einem stabilen Release müssen Multi-Auction, Regel-Sync, Masterloot-Kandidaten, ElvUI-/Ascension-Lootslots und der vollständige Handelsablauf mit mindestens zwei echten Clients auf dem Zielrealm geprüft werden. Diese Live-Abnahme ist keine fehlende Funktion, sondern kann von einem Lua-Testharness nicht wahrheitsgemäß simuliert werden.
