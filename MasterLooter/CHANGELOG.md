# Changelog

## 0.10.1-beta

- Ausstehende Gewinner werden erst nach bestätigtem Taschenfund als handelsbereit behandelt
- Spieler außerhalb der Handelsreichweite erhalten eine begrenzte automatische Whisper-Erinnerung
- MasterLooter-Clients koordinieren Übergaben über einen validierten, deduplizierten und zeitlich begrenzten Handshake
- Beim eindeutig erkannten Handelspartner werden passende Items automatisch und seriell in freie Handelsslots gelegt
- Bestehende Angebote, falsche Partner, gesperrte oder zu große Stapel, mehr als sechs Items und Handelsabbrüche werden sicher behandelt
- Spieler ohne Addon können den Lootmaster anhandeln und erhalten ihre vorgesehenen Items ebenfalls automatisch eingelegt
- Das endgültige Annehmen des Handels bleibt auf beiden Seiten eine manuelle Bestätigung

## 0.10.0-beta

- Persistente Lootslot-Warteschlange und STRG+Rechtsklick-Übernahme aus Blizzard-, XLoot- und ElvUI-Lootfenstern
- Sicherer Vergabeablauf für entfernte Gewinner: direkte Vergabe, bewusstes An-sich-Nehmen und erst danach bestätigte Handelswarteschlange
- Handelsassistent mit Gruppierung je Gewinner, Taschenabgleich, Fristanzeige, Reload-Wiederherstellung und Schutz vor falschem Partner oder Stapelfehlern
- Strichliste mit Gesamt-/MS-/OS-Zählern, separatem +1, konfigurierbarer automatischer Buchung und Audit-Historie
- Persistente GDKP-Auktionswarteschlange, gewichtete Anteile und Zahlungsstatus
- PackMule-Regeln für Qualität, Bindung, Disenchanter und Round-Robin-Ziele
- Wiederherstellung eigener aktiver Roll- und Auktionssitzungen nach Reload
- Kopierbare Kommunikationsdiagnose, begrenztes Fehlerprotokoll, CSV-/TSV-Exporte und automatische Import-Sicherungen
- Realm-, Locale- und Client-kontextbezogener Laufzeitindex für Ascension-Items
- Erweiterte Einstellungen für Profile, Skalierung, Fensterpositionen, Ansagen, Taschenfreigabe und PackMule
- Automatisierte Integrations-, Negativ-, Grenzfall-, Manifest- und 3.3.5a-Kompatibilitätstests

## 0.9.17-beta

- Absturz der Lootmaster-Tabelle behoben, wenn ein korrekt erfasster öffentlicher Wurf noch keinen optionalen `effectiveRoll`-Wert besitzt
- Fehlender `effectiveRoll` verwendet nun zuverlässig den tatsächlichen öffentlichen Wurf als Anzeige- und Sortierwert
- Roll-Diagnose behält die letzte echte Rollmeldung und ihr Ergebnis, statt sie durch spätere allgemeine System- oder UI-Fehlermeldungen zu überschreiben
- Letzte ignorierte Systemmeldung wird separat im kopierbaren Diagnosefenster angezeigt
- Regressionstest für den gemeldeten Datensatz `Driomodo`, MS, Wurf 13, Bereich 1–100 ergänzt

## 0.9.16-beta

- Rolltracker initialisiert seine lokalen Chat-Erfassungswege bereits beim Laden der Moduldatei und nicht erst über den späteren Bootstrap-Durchlauf
- Potenziell problematische Unicode-Zeichen aus dem Lua-Quelltext entfernt; Halbgeviert- und Geviertstriche werden bytebasiert normalisiert
- `/ml rolldebug` öffnet ein verschiebbares Diagnosefenster mit mehrzeiligem, markierbarem Text für Strg+A und Strg+C
- Diagnosefenster zeigt Version, Trackerkomponenten, Sitzung, Ereigniszähler, Rohmeldung, erkannte Werte und Übernahmeergebnis
- Eigene Meldung erklärt ausdrücklich, wenn `Modules\\ChatRolls.lua` auf dem Client überhaupt nicht geladen wurde

## 0.9.15-beta

- Zusätzlicher Hook auf WoWs niedrigen `ChatFrame_MessageEventHandler`, um sichtbare Systemwürfe auch bei abweichender Ascension-Eventweitergabe lokal beim Lootmaster zu erfassen
- Altes 3.3.5-Eventformat über das globale `arg1` wird als weiterer Fallback unterstützt
- Rollparser akzeptiert neben Bindestrichen auch Halbgeviert- und Geviertstriche sowie eine alternative Reihenfolge von Rollbereich und Ergebnis
- `/ml rolldebug` zeigt geladene Version, Trackerstatus, aktive Sitzung, letzten empfangenen Rohtext und den genauen Erfassungs- oder Ablehnungsgrund

## 0.9.14-beta

- Garguls lokales Erfassungsprinzip ergänzt: Der Lootmaster verarbeitet sichtbare Würfe zusätzlich über `ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM")`
- Spieler ohne MasterLooter werden ausschließlich aus der beim Lootmaster angezeigten Systemmeldung erfasst und benötigen weiterhin keinerlei Addon-Kommunikation
- Direkter Eventframe, zentraler Eventbus und Chat-Ausgabefilter arbeiten redundant; doppelt empfangene Meldungen bleiben durch die bestehende Erstwurfregel folgenlos
- Regressionstest simuliert einen Spieler ohne Addon, dessen Wurf nur im Chat-Ausgabefilter des Lootmasters ankommt
- Ingame-Versionsanzeige und Versionsabgleich auf `0.9.14-beta` beziehungsweise Rollprotokoll 3 aktualisiert

## 0.9.13-beta

- Eigenes öffentliches `/roll`-Ergebnis wird vom Teilnehmer-Addon zusätzlich an den Lootmaster übermittelt, falls Ascension die Systemmeldung nicht an dessen Client verteilt
- Der Lootmaster validiert Absender, aktive Sitzung und Rollbereich erneut; fremde Würfe können nicht stellvertretend übertragen werden
- `CHAT_MSG_SYSTEM` wird für die kritische Rollerfassung über einen eigenen Eventframe empfangen
- Die Lootmaster-Tabelle gleicht sich während einer sichtbaren aktiven Sitzung zusätzlich alle 250 Millisekunden mit dem autoritativen Sitzungszustand ab
- Regressionstest für einen Wurf, dessen Systemmeldung ausschließlich beim würfelnden Gruppenmitglied ankommt

## 0.9.12-beta

- Öffentliche `/roll`-Ergebnisse werden in Ascension-Gruppen auch dann erfasst, wenn die Partygröße verfügbar ist, die Namen über `UnitName`, `GetUnitName` und `UnitFullName` aber fehlen
- Farbige und verlinkte Spielernamen in Ascension-Systemmeldungen werden vor der Auswertung bereinigt
- Regressionstest für eine aktive Gruppe mit nicht auflösbaren `partyX`-Namen ergänzt

## 0.9.11-beta

- Lootmaster-Fenster nach dem kompakten Gargul-Aufbau neu gegliedert: Item und Start/Stop oben, breite Notizzeile, Timer und autoritativer OS-Bereich darunter
- Rolltabelle auf sechs dichte sichtbare Zeilen reduziert und das gesamte Lootmaster-Fenster auf 540×470 Pixel verkleinert
- Teilnehmerfenster als flaches 520×84-Pixel-Widget mit Rollaktionen oben und grüner Item-, Notiz- und Timerleiste darunter gestaltet
- Neue Positionsversionen setzen beide überarbeiteten Fenster einmalig auf passende Standardpositionen zurück
- Layoutabmessungen und sichtbare Tabellenzeilen durch Regressionstests abgesichert

## 0.9.10-beta

- **Erfasster Loot** aktualisiert sich bei Lootereignissen nur noch im Hintergrund und öffnet ausschließlich manuell über `/ml loot` oder das Minimap-Menü
- Das zusätzliche MasterLooter-Gruppenlootfenster samt nativer Roll-Überlagerung entfernt
- Bedarf, Gier, Entzaubern und Passen bei normalem Gruppenloot verbleiben vollständig bei der Blizzard-Oberfläche
- Crafting, Entzaubern, Behälter und normales Aufsammeln öffnen kein MasterLooter-Lootfenster mehr

## 0.9.9-beta

- Verspätete Ende-, Ergebnis- und Bestätigungsereignisse werden nur noch auf das Rollfenster ihrer eigenen Sitzungs-ID angewendet
- Ein Ereignis des ersten Warteschlangen-Items kann die Buttons des bereits gestarteten zweiten Items nicht mehr deaktivieren
- Regressionstest für zwei aufeinanderfolgende Warteschlangen-Items ergänzt

## 0.9.8-beta

- Ascension-Systemmeldungen mit Leerzeichen im Bereich wie `Flexdeineex rolls 37 (1 - 100)` als Regressionstest ergänzt
- Raidmitglieder werden zusätzlich über `GetRaidRosterInfo` aufgelöst; Gruppenmitglieder verwenden Fallbacks über `GetUnitName` und `UnitFullName`, falls `UnitName("partyX")` auf Ascension keinen Namen liefert
- `CHAT_MSG_SYSTEM` wird robuster aus den tatsächlich gelieferten Eventargumenten ausgelesen

## 0.9.7-beta

- OS-Wurfmaximum aus den allgemeinen Einstellungen direkt in das Lootmaster-Fenster verschoben
- Der beim Sitzungsstart festgelegte OS-Wert wird autoritativ an alle Addon-Clients übertragen; lokale Teilnehmerwerte werden ignoriert
- Teilnehmerbuttons zeigen den empfangenen Bereich als `MS (/100)` und `OS (/X)` an
- Startansage nennt die Befehle ausdrücklich als `/roll 100 für MS. /roll X für OS.`

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
