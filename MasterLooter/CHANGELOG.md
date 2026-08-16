# Changelog

## 0.17.3-beta
- Added persistent controls for loot-master command announcements and automatic trade whispers
- Fixed pending trade reminders after manual Blizzard master-loot assignments
- Added per-item actions to mark a trade task as delivered or cancel it
- Fixed mixed-language dynamic window titles and status messages

## 0.17.2-beta
- Fixed minimap tooltip startup when the localization helper is unavailable
- Added Transmog rolls using `/roll 50`
- Added the Transmog button, announcements, tracking, and loot-master display
- Added mark-first ranking followed by MS, OS, and Transmog
- Reserved `/roll 50` for Transmog to prevent ambiguous OS rolls

## 0.17.1-beta
- Fixed settings startup caused by legacy dropdown menus
- Fixed mixed German and English interface text
- Fixed overlapping and clipped English window text
- Fixed BISBeard Soft Reserve imports and overview
- Fixed the minimap tooltip error

## 0.17.0-beta

- Added complete German and English localization for the interface, dynamic status text, tooltips, key bindings, and minimap actions
- Added automatic client-language detection with English fallback for unsupported client locales
- Added a profile-specific language selector for Automatic, Deutsch, and English with a clean UI reload after changes
- Localized roll announcements, countdowns, awards, SR/SL replies, trade whispers, broadcast messages, and slash-command output
- Added bidirectional translations for more than 150 actionable errors from loot, awards, rolls, SoftRes, GDKP, imports, raid management, and trades
- Replaced the free-text announcement channel field with a native dropdown
- Added Automatic, Raid Warning, Raid, Group, Say, Yell, Guild, and Officer channel choices with safe group and permission fallbacks
- Preserved technical identifiers, player names, item links, and import/export payloads without translation
- Added dedicated localization, announcement-channel, UI-coverage, and module-error regression suites
- Reworked the GitHub front page for players with a clearer feature overview, installation guide, usage flow, and screenshot placeholders

## 0.16.8-beta

- Item im Teilnehmer-Rollfenster als vollständige interaktive Hover- und Klickfläche umgesetzt
- Shift während des Hoverns aktualisiert den Tooltip dynamisch und öffnet die nativen 3.3.5a-Ausrüstungsvergleiche
- Loslassen von Shift entfernt die Vergleichsfenster wieder, ohne den Itemtooltip zu verlieren
- STRG-Klick wird über Blizzards `HandleModifiedItemClick` an die native Itemvorschau weitergereicht
- Weitere Blizzard-Modifikatorklicks wie das Einfügen eines Itemlinks in einen aktiven Chat werden über denselben Standardpfad unterstützt
- Fallback auf `DressUpItemLink` ergänzt, falls ein Ascension-Client den allgemeinen Handler nicht bereitstellt
- Private MasterLooter-Tooltips bleiben isoliert; globale oder fremde Tooltips werden nicht versteckt oder überschrieben
- UI- und Tooltip-Simulationen prüfen Hyperlink, Maustaste, Shift-Aktualisierung, Vergleichsaufruf und Tooltip-Isolation

## 0.16.7-beta

- Wartepflicht zwischen mehreren identischen Vergaben vollständig entfernt
- Der nächste Gewinner kann sofort nach dem ersten Vergabeklick aus derselben Rolltabelle ausgewählt werden
- Bereits gestartete native Vergaben reservieren ihren Lootslot lokal, ohne die gesamte Oberfläche zu sperren
- Die nächste Vergabe überspringt jeden noch in Bearbeitung befindlichen identischen Slot und verwendet direkt das nächste Exemplar
- Mehrere native Vergaben können unabhängig voneinander auf ihre jeweilige Serverbestätigung warten
- Nachfolgende Items und RollSessions werden nicht mehr durch eine alte `awardPending`-Sperre blockiert
- Integrationsprüfung vergibt zwei identische Items auf Slot 1 und Slot 2, bevor irgendeine Slotleerung gemeldet wird
- UI-Simulation bestätigt die sofortige Auswahl und Vergabe des zweiten Spielers ohne Lootfenster-Rückmeldung

## 0.16.6-beta

- Hängende Spielerauswahl nach der ersten von mehreren identischen Vergaben korrigiert
- Die UI wartet nicht mehr ausschließlich auf dieselbe numerische Lootslot-ID, da Ascension Slots beim Entfernen umnummerieren kann
- Jede Vergabe erhält bei bestätigter nativer Slotleerung ein eigenes `lootConfirmed`-Merkmal
- Die Auswahl des nächsten Gewinners wird über Sitzungs-ID, Vergabenummer und bestätigte Zustellung wieder freigegeben
- Eine fremde Slotleerung oder eine andere Sitzung kann die Sperre weiterhin nicht aufheben
- Bereits synchron bestätigte Vergaben zeigen sofort die Aufforderung zur Auswahl des nächsten Gewinners
- UI-Regressionstest simuliert eine abweichende Ascension-Slotnummer und prüft die anschließende Auswahl des zweiten Spielers

## 0.16.5-beta

- Mehrfachvergabe identischer Items gegen unvollständige Ascension-Loot-Snapshots abgesichert
- Die Anzahl identischer Exemplare wird zusätzlich direkt über die aktuell sichtbaren nativen Lootslots ermittelt
- Die RollSession übernimmt die native Zählung selbst und verlässt sich nicht mehr ausschließlich auf die UI-Option
- Wurde eine Sitzung zu früh nach einem Exemplar geschlossen, wird sie nach bestätigter Zustellung kontrolliert wieder geöffnet, sofern dasselbe Item noch im Blizzard-Lootfenster liegt
- Ursprüngliche Teilnehmer, Würfe und Sitzungs-ID bleiben bei der Wiederöffnung unverändert erhalten
- Eine unbestätigte erste Vergabe kann die Sitzung nicht vorzeitig für weitere Gewinner freigeben
- Regressionstest simuliert ausdrücklich eine auf ein Exemplar unterschätzte Sitzung und vergibt das zweite Exemplar ohne neuen Roll

## 0.16.4-beta

- Ascension-sichere Whisper-Befehle von `!SR` und `!SL` auf die alphanumerischen Primärbefehle `SR` und `SL` umgestellt
- Raid-Warning des Master Looters nennt jetzt ausschließlich die zuverlässig übertragbaren Primärbefehle
- `#SR`, `?SR`, `!SR`, `MLSR`, `ML SR` sowie die entsprechenden SL-Formen bleiben als exakte Aliase verfügbar, sofern Ascension sie zustellt
- Alle Befehle werden intern auf `SR` oder `SL` normalisiert und teilen dadurch Datenschutz- und Rate-Limit-Prüfungen
- Whisper-Simulation um Primärbefehle, Sonderzeichen-Aliase und ausgeschriebene ML-Aliase erweitert

## 0.16.3-beta

- Eine Rollrunde kann jetzt mehrere identische Exemplare im selben Lootfenster nacheinander vergeben
- Die Anzahl identischer Lootslots wird beim Start erfasst und als Zahl der möglichen Einzelvergaben gespeichert
- Nach der ersten Vergabe bleiben alle ursprünglichen Würfe im Lootmaster-Fenster erhalten
- Bereits bedachte Spieler werden in der Rolltabelle als vergeben markiert und können in derselben Runde nicht doppelt ausgewählt werden
- Die nächste Gewinnerauswahl wird erst nach der nativen Bestätigung der vorherigen Slotleerung freigeschaltet
- Das zweite und jedes weitere Exemplar wird automatisch aus dem verbleibenden identischen Blizzard-Lootslot vergeben
- Historie, Handelsfallback und Zustellidentitäten unterscheiden jede Einzelvergabe derselben Rollrunde
- Integrations- und UI-Simulationen prüfen zwei getrennte Gewinner aus einer einzigen Rollrunde

## 0.16.2-beta

- Vergabe mehrerer identischer Drops aus dem Lootmaster-Fenster korrigiert
- Nachrückende Ascension-Lootslots übernehmen nicht mehr fälschlich den Status eines zuvor geleerten Slots
- Nach jeder Slotleerung wird das native Lootfenster auf den folgenden Frames erneut eingelesen
- Abgeschlossene, entfernte oder abgebrochene Warteschlangeneinträge werden bei wiederverwendeten Slotnummern nicht erneut benutzt
- Jeder weitere identische Drop erhält eine eigene Warteschlangen- und Vergabe-ID
- Regressionstest simuliert zwei identische Items, bei denen das zweite Item nach der ersten Vergabe auf dieselbe Slotnummer nachrückt

## 0.16.1-beta

- Private Whisper-Abfrage `!SR` für die eigenen SoftRes ergänzt
- Private Whisper-Abfrage `!SL` für den eigenen manuellen Strichstand ergänzt
- Abfragen antworten ausschließlich Gruppen- oder Raidmitgliedern und nur vom aktiven Master Looter
- Beim Erhalt des Master-Looter-Status wird im Raid einmalig eine Nachricht mit beiden Befehlen veröffentlicht
- Die Befehlsnachricht verwendet nach Möglichkeit Raid Warning und fällt ohne Berechtigung auf Raidchat zurück
- Lange SoftRes-Listen werden auf mehrere sichere Whisper-Nachrichten verteilt
- Eigenständige Simulationen für Statuswechsel, Datenschutz, Realm-Namen, Mehrfachreservierungen und exakte Befehle ergänzt

## 0.16.0-beta

- BISBEARD-RollFor-Exporte als Base64-JSON-Import für SoftRes und HardRes ergänzt
- Mehrfachreservierungen aus BISBEARD werden pro Spieler und Item korrekt zusammengefasst
- DFT-, ClassicPR-/CSV- und RRobin-Prioritätsimporte im zentralen Importfenster ergänzt
- Optionale LootReserve-Anbindung übernimmt laufende Reservierungen automatisch über den öffentlichen `RESERVES`-Listener
- Fremddaten werden durch begrenzte, nicht ausführbare Base64- und JSON-Parser verarbeitet
- Importauswahl verbreitert und formatbezogene Validierung sowie verständliche Fehlermeldungen ergänzt
- Neue Smoke-Tests prüfen leere und befüllte BISBEARD-Daten, Duplikate, HardRes, ungültige Eingaben und alle weiteren Importadapter

## 0.15.3-beta

- Masterloot-Vergabe exakt auf die originale Blizzard-3.3.5a-API-Signatur umgestellt
- Kandidaten werden wie im Blizzard-Lootmenü über `GetMasterLootCandidate(candidateIndex)` ermittelt
- Die eigentliche Vergabe verwendet unverändert die native Funktion `GiveMasterLoot(lootSlot, candidateIndex)`
- Falscher Zwei-Parameter-Aufruf von `GetMasterLootCandidate` entfernt, durch den auf 3.3.5a wiederholt derselbe Kandidat gelesen wurde
- Regressionstest lehnt jeden zusätzlichen Kandidatenparameter ab und prüft Lootslot sowie Kandidatenindex der nativen Vergabe getrennt

## 0.15.2-beta

- Masterloot-Kandidaten werden über alle 40 möglichen 3.3.5a-Indizes gesucht, auch wenn dazwischen leere Plätze liegen
- Spieler, die im Blizzard-Lootmenü auswählbar sind, werden dadurch nicht mehr fälschlich als außerhalb der Reichweite oder unberechtigt behandelt
- Kandidatenvergleich toleriert Realmzusätze, umgebende Leerzeichen und WoW-Farbcodes
- Die Gesamtdiagnose protokolliert bei einer weiterhin fehlenden Zuordnung alle tatsächlich gefundenen Kandidatenindizes
- Regressionstest bildet eine lückenhafte Kandidatenliste nach, bei der Blizzard den Gewinner an Index 3 anbietet

## 0.15.1-beta

- MasterLooter-Panel unter `Interface → AddOns` beim Erstellen ausdrücklich verborgen
- Die MasterLooter-Seite wird nur noch angezeigt, wenn in der Addon-Liste tatsächlich `MasterLooter` ausgewählt wurde
- Andere Addon-Kategorien und deren Einstellungen werden nicht mehr vom MasterLooter-Panel überdeckt
- Regressionstest simuliert Registrierung, initiale Unsichtbarkeit und anschließende Auswahl durch das Interface-Menü

## 0.15.0-beta

- Erweiterter GDKP-Bereich mit bis zu vier parallelen Auktionen, Bieterzuständen, Anti-Snipe, Taschenwarteschlange und Reload-Wiederherstellung
- GDKP-Ledger, Goldtransaktionen, Teilnehmer, gewichtete Cuts, Management-Cut, Mutatoren, Preislisten und versionierter Im-/Export ergänzt
- Neues persistentes Beute-Ledger verfolgt Drops bestmöglich von `DROPPED` über Aufnahme und Vergabe bis Handel, Entzauberung oder ungeklärtem Verlust
- Handelsassistent zeigt die geschätzte Zwei-Stunden-Frist, filtert offene/problematische Aufgaben und warnt bei 30, 10 und 5 Minuten; Handelsabschluss bleibt manuell
- AutoRoll-Regeln, TMB-Prioritätsdaten, SoftRes-Limits und -Verbrauch, PackMule-Ausnahmen sowie begründete Regelvorschauen ergänzt
- Abgesicherter Raid-Sync für +1 und Boosted Rolls mit vertrauenswürdigen Sendern, Revision, Prüfsumme, Replay- und Konfliktschutz
- Vollständige Profilverwaltung mit Erstellen, Kopieren, Umbenennen, Löschen und charakterspezifischer Zuordnung
- Ascension-Itemsuche nach Name/ID, Qualität und Itemlevel auf dem laufzeitlernenden Itemindex ergänzt
- Willkommens-/Neuigkeitenfenster, globale Tastenkürzel und zweistufig bestätigter Komplett-Reset ergänzt
- Neue Simulationspakete prüfen GDKP, Regel-Sync, Ledger/Handelszeit, Profile, Itemsuche und den Legacy-UI-Aufbau

## 0.14.1-beta

- Ascension-fehlerhaftes `InputBoxTemplate` durch eigene, vollständig sichtbare 3.3.5a-Eingabefelder ersetzt
- Aus den Einstellungen gestartete Werkzeuge werden zuverlässig in den Vordergrund gebracht; der Launcher schließt sich anschließend automatisch
- Regeln/Strichliste und GDKP sind nun echte Top-Level-Fenster
- Handelsassistent erhält einen zweistufig bestätigten Button zum Leeren aller Handelsaufgaben und offenen Vergaben
- Regeln/Strichliste erhält einen zweistufig bestätigten Komplett-Reset für SoftRes, HardRes, Prioritäten, +1, Roll-Boni und erhaltene Items
- GDKP erhält einen zweistufig bestätigten Komplett-Reset für aktive Sitzung, Formular und GDKP-Historie
- Zusätzliche Simulationen prüfen die tatsächlichen Eingabefeld-Templates, Fensterebenen, Reset-Abläufe und 56 Geometriebedingungen der Verwaltungsfenster

## 0.14.0-beta

- Fehlgeschlagene Direktvergaben aus einem offenen Lootfenster nehmen automatisch den exakten Lootslot für den Lootmaster auf
- Gewinner werden beim Handels-Fallback sofort per Whisper informiert, auch wenn sie MasterLooter nicht installiert haben
- Ein Handelseintrag entsteht weiterhin erst nach der bestätigten Slotleerung; der Handel wird niemals automatisch angenommen oder abgeschlossen
- Der optionale Handelsassistent öffnet sich bei einer Vergabe nicht mehr ungefragt
- Lootmaster-Fenster auf ein kompakteres Layout mit getrennten Status-, Navigations- und Tabellenbereichen überarbeitet
- OS-Bereich eindeutig als `OS /ROLL` beschriftet und Spalten für Bilanz und manuelles `+1` getrennt
- Gewinner werden ausschließlich per Klick ausgewählt; `+1` verändert die Auswahl nicht und neue Sitzungen übernehmen keinen alten Gewinner
- Neuer 3.3.5a-UI-Simulator prüft Geometrie, Überlappungen, Eingaben, Gewinnerauswahl, Warteschlange und Vergabezustände

## 0.13.8-beta

- Direkte ElvUI-Lootauswahl benötigt nicht mehr, dass das optionale Fenster „Erfasster Loot“ zuvor geöffnet wurde
- `Select` setzt die Hintergrundauswahl auch ohne `selectedLabel`, `useButton` und `muleButton`
- Statusmeldungen werden gespeichert und nur dann gerendert, wenn das Statusfeld bereits existiert
- STRG+Rechtsklick kann dadurch unmittelbar nach dem Login den Lootslot übernehmen und das eigentliche Lootmaster-Fenster öffnen
- Regressionstest deckt den kompletten Hintergrundpfad ohne erzeugten LootWindow-Frame ab

## 0.13.7-beta

- Tatsächlich verwendete ElvUI-Lootzeilen `ElvLootSlot1` bis `ElvLootSlot40` werden direkt eingebunden
- Zusätzlich werden die von `ElvLootFrame.slots` bereitgestellten Slotbuttons übernommen
- Breite `EnumerateFrames`-Suche entfernt; kein 10.000-Frame-Limit und keine unnötige Vollsuche mehr
- Need-, Greed- und andere Gruppenwurf-Buttons werden nicht mehr fälschlich als Lootfenster-Items erkannt
- Live-verwendeter ElvUI-`OnClick`-Pfad mit `GetLootSlotLink(self:GetID())` wird vor dem ursprünglichen Itemlink-Klick abgefangen
- Diagnose kennzeichnet diese Hooks ausdrücklich als `ELVUI_LOOT_SLOT` beziehungsweise `ELVUI_LOOT_FRAME_SLOTS`

## 0.13.6-beta

- Dynamische Framesuche gegen unbenannte Frames abgesichert, die bei einer nicht unterstützten `OnClick`-Abfrage selbst einen Lua-Fehler werfen
- Sämtliche `GetScript`- und `SetScript`-Zugriffe der Lootbutton-Erkennung laufen nun geschützt
- Nicht anklickbare Frames werden übersprungen, ohne die weitere Suche nach dem tatsächlichen Ascension-Lootbutton abzubrechen
- `RegisterForClicks` wird ebenfalls geschützt ausgeführt
- Regressionstest bildet die gemeldete Fehlermeldung `<unnamed> doesn't have a "OnClick" script` exakt nach

## 0.13.5-beta

- Sichtbare Lootbuttons von AscensionUI und anderen angepassten Lootframes werden zur Laufzeit erkannt, auch wenn sie unbenannt sind
- Lootbutton-Erkennung läuft bei `LOOT_OPENED` sofort sowie nochmals nach 0 und 0,2 Sekunden
- Überschriebene `OnClick`-Hooks werden bei der nächsten Erkennung wiederhergestellt, ohne Tooltip-Skripte anzufassen
- `/ml debug` zeigt Scananzahl, erkannte und aktive Lootbutton-Hooks, Framequelle, Slot und den letzten erreichten Klick
- Abgelehnte STRG+Rechtsklicks werden mit Ursache protokolliert
- `/ml debug clear` bestätigt den Reset sichtbar im Chat
- Bereits abgelaufene Handelsaufgaben überfluten einen frisch geleerten Gesamt-Trace nicht mehr

## 0.13.4-beta

- STRG+Rechtsklick im nativen 3.3.5a-Lootfenster direkt auf `LootButton1` bis `LootButton4` abgefangen
- Modifizierte Klicks werden nun vor dem originalen FrameXML-Handler verarbeitet, der sie sonst als Itemlink-Klick behandelt
- Alte 3.3.5a-Übergabe der Maustaste über das globale `arg1` wird zusätzlich unterstützt
- Konkrete Lootbuttons werden bei jedem Öffnen des Lootfensters erneut erkannt und eingebunden
- Solo-Nutzung und normaler Lootmodus benötigen für das Öffnen des Lootmaster-Fensters keinen aktiven Masterloot
- Originale `OnEnter`-, `OnLeave`- und Tooltip-Handler der Lootbuttons bleiben unverändert

## 0.13.3-beta

- STRG+Rechtsklick für native 3.3.5a-/Ascension-Taschenitems und Lootslots wiederhergestellt
- Klickintegration verändert keine `OnEnter`-, `OnLeave`- oder Tooltip-Handler und verwendet keine globale Mausabfrage
- Behandelte STRG+Rechtsklicks benutzen beziehungsweise looten das ausgewählte Item nicht versehentlich
- Die exakte Lootslot-, Warteschlangen- und Lootgeneration-ID wird bis zum Rollergebnis erhalten
- Bei identischen Items im selben Lootfenster vergibt `GiveMasterLoot` dadurch den tatsächlich ausgewählten Slot
- Gewinner werden weiterhin automatisch angehandelt und vorgemerkte Items automatisch eingelegt
- Automatische Handelsannahme vollständig entfernt; der Lootmaster muss jeden Handel selbst annehmen und abschließen
- Build-Sperre ergänzt, die jede Verwendung von `AcceptTrade` im ausgelieferten Addon ablehnt

## 0.13.2-beta

- Sämtliche beobachtenden Hooks auf Methoden des globalen `GameTooltip` entfernt
- MasterLooter nimmt im normalen Betrieb nicht mehr an der von ElvUI, MoveAnything, AdiBags und weiteren Addons veränderten Tooltip-Aufrufkette teil
- Loot-, Taschen- und Cursordiagnose zeichnet nur noch die Ereignisargumente auf und liest den globalen Tooltip dabei nicht aus
- Der Zustand des globalen Tooltips wird ausschließlich beim ausdrücklichen Öffnen der Diagnose passiv abgefragt
- Diagnose um Alpha, effektives Alpha, Skalierung, Zeilenzahl und sämtliche Verankerungspunkte erweitert
- Eigene MasterLooter-Itemanzeigen verwenden weiterhin ausschließlich den getrennten `MasterLooterTooltip`

## 0.13.1-beta

- Gewinner mit handelsbereitem Item werden in Reichweite automatisch über ihre Gruppen- oder Raideinheit angehandelt
- Beim verifizierten Gewinner werden ausschließlich die vorgemerkten Items automatisch eingelegt und der Handel automatisch angenommen
- Vor jedem automatischen Annehmen werden Handelspartner, Item-IDs, Mengen und belegte Slots erneut vollständig abgeglichen
- Zusätzliches eigenes Handelsgut, eigenes oder fremdes Gold sowie Gegenstände des Gewinners sperren die automatische Bestätigung
- Ändert sich ein bereits angenommener Handel, wird die Annahme verworfen und erst nach einer erneuten erfolgreichen Prüfung wiederholt
- Falsche oder nicht verifizierbare Partner erhalten weder Items noch eine automatische Handelsbestätigung
- Automatische Handelsöffnung, Sperrgründe, Annahme und Clientfehler werden in `/ml debug` protokolliert

## 0.13.0-beta

- Spielerzeilen im Lootmaster als direkte, sichtbar markierte Gewinnerauswahl umgesetzt
- Eigener `+1`-Button neben jeder Spielerzeile; ein Klick vergibt genau einen Strich
- Zahlenfeld unter der Tabelle vollständig entfernt
- Itemvergabe und Strichvergabe technisch und visuell vollständig getrennt
- Neue kopierbare Gesamtdiagnose über `/ml debug` und Einstellungen > Daten & Diagnose
- Zentraler Ringpuffer für Modulstart, WoW- und interne Events, Fehler sowie Benutzeraktionen
- Bericht enthält Module, Fehler, Roll-, Loot-, Trade-, UI-, Kommunikations- und Tooltip-Zustände
- Diagnose bleibt bei Fehlern einzelner Teilsysteme funktionsfähig; `/ml debug clear` startet einen frischen Trace

## 0.12.9-beta

- Ascension-Laufzeitfehler durch fehlendes `math.mod` in der Restzeitanzeige behoben
- Weitere `math.mod`-Verwendungen in Import/Export und Tascheninspektor ebenfalls ersetzt
- Build sperrt die auf diesem Client nicht vorhandene Funktion dauerhaft
- Gemischte Installationen mit altem separatem TooltipDebug lösen keine doppelte Modulregistrierung mehr aus
- Diagnose-Fallback zeigt Lua- und TOC-Version nun auch dann, wenn das Diagnosemodul fehlt

## 0.12.8-beta

- Rollstart, Countdown, Ende und Vergabe verwenden im Raid standardmäßig `RAID_WARNING`
- Raidleader- und Assistentenstatus wird über mehrere 3.3.5a-kompatible APIs sowie den Raid-Rang erkannt
- Ohne Raidwarning-Berechtigung sicherer Fallback auf `RAID`
- In normalen Gruppen automatische Ausgabe über `PARTY`, da dort kein Raidwarning-Kanal existiert
- Bestehende Profile werden einmalig auf die neue Raidwarning-Vorgabe umgestellt

## 0.12.7-beta

- Tooltip-Diagnose vollständig in bereits etablierte TOC-Dateien integriert
- Keine neuen Modul- oder Fensterdateien mehr zum Laden der Diagnose erforderlich
- `/ml tooltipdebug` verwendet garantiert das bestehende kopierbare Diagnosefenster
- Dump zeigt Lua- und TOC-Version getrennt, um unvollständige Installationen sofort sichtbar zu machen

## 0.12.6-beta

- Tooltip-Diagnose mit garantiertem Fallback über das bestehende Roll-Diagnosefenster abgesichert
- Fehler im dedizierten Diagnosefenster werden abgefangen und im MasterLooter-Fehlerprotokoll erfasst
- Diagnose um geladene Addons, MasterLooter-Ladefehler und globale Tooltip-Skripthandler erweitert
- Unbedingten Vollscan aller Taschen durch `MasterLooter_ItemData` bei jedem `BAG_UPDATE` entfernt
- ItemData lernt den vorhandenen Bestand weiterhin beim Start und neue Beute über deren Chat-Itemlinks

## 0.12.5-beta

- MasterLooter-Oberfläche vollständig vom globalen Blizzard-/Ascension-`GameTooltip` getrennt
- Eigener `MasterLooterTooltip` für Itemlinks, Verlauf, Handel, Lootliste, Tascheninspektor und Minimap-Hinweise
- Kopierbare Tooltip-Diagnose unter `/ml tooltipdebug` und in Einstellungen > Daten & Diagnose ergänzt
- Diagnose protokolliert globale Tooltip-Aktionen mit Besitzer, Zeit und Aufrufpfad sowie Loot-, Taschen-, Itemlock- und Cursorereignisse
- Regressionstests erzwingen, dass kein MasterLooter-UI-Fenster den globalen Tooltip verwendet

## 0.12.4-beta

- STRG+Rechtsklick für Inventar- und Lootitems vollständig entfernt
- Globale Mausabfrage, Fokusprüfung sowie Taschen- und Lootbutton-Erkennung aus dem Laufzeitcode entfernt
- MasterLooter führt nach der Beuteaufnahme keinen Code mehr über fokussierte Blizzard-/Ascension-Itembuttons aus
- Statische Smoke-Test-Sperre verhindert die versehentliche Wiedereinführung der globalen Eingabeintegration

## 0.12.3-beta

- Verstecktes Loot-Verwaltungsfenster wird bei der Beuteaufnahme weder erzeugt noch visuell aktualisiert
- MasterLooter blendet einen Item-Tooltip nur noch aus, wenn das betreffende eigene UI-Element aktuell dessen Besitzer ist
- Inventar- und Loot-Tooltips von Blizzard beziehungsweise Ascension bleiben beim Entfernen eines Lootslots unangetastet
- Neuer Regressionstest simuliert den Besitzerwechsel des globalen Tooltips während der Beuteaufnahme

## 0.12.2-beta

- Sämtliche Hooks auf Blizzard-/Ascension-Inventar- und Lootbuttons vollständig entfernt
- Auch der globale Containerfunktions-Hook wurde entfernt, damit Itemaufnahme und Tooltip-Lebenszyklus vollständig außerhalb von MasterLooter bleiben
- STRG+Rechtsklick wird nun unabhängig über `GetMouseFocus`, `IsMouseButtonDown` und den Flankenwechsel der rechten Maustaste erkannt
- Keine fremden `OnClick`-, `OnEnter`-, `OnMouseDown`-, Drag-, Tooltip- oder Maustastenregistrierungen werden gelesen, ersetzt oder ergänzt
- Loot- und Taschenitems werden erst anhand des aktuell fokussierten UI-Elements aufgelöst und anschließend an MasterLooter übergeben

## 0.12.1-beta

- Erneuten Ausfall von Inventar- und Loot-Tooltips durch vollständiges Entfernen aller ersetzenden Taschen-/Lootbutton-Hooks behoben
- Inventar verwendet ausschließlich WoWs sicheren globalen `hooksecurefunc`-Nach-Hook
- Lootfenster verwendet nur einen ergänzenden `OnMouseDown`-Beobachter; vorhandene `OnClick`-, `OnEnter`- und Maustastenregistrierungen bleiben unangetastet
- STRG+Rechtsklick erkennt zusätzlich Ascension-Felder `lootSlot` und `slotIndex` sowie paginierte Blizzard-Lootslots
- Direkter Live-Fallback auf `GetLootSlotLink` entfernt die Abhängigkeit vom Zeitpunkt des Hintergrund-Snapshots
- Regressionstests schützen die originalen Klick- und Tooltip-Funktionsobjekte vor Änderungen

## 0.12.0-beta

- Automatische `+1`-Buchung für MS, OS, Selbstvergabe und bestätigte Handelsübergaben vollständig entfernt
- Lootmaster erhält bei der Gewinnervergabe ein manuelles `+1`-Zahlenfeld von 0 bis 99
- Das Feld steht bei jeder Auswahl und neuen Sitzung sicher auf `0`; ohne bewusste Eingabe entsteht kein Strich
- Nach erfolgreicher Vergabe wird nur der ausdrücklich eingegebene Wert gebucht und das Feld wieder auf `0` gesetzt
- Erhaltene Itemzahlen `G/MS/OS` bleiben als getrennte, reine Vergabehistorie erhalten und verändern das `+1`-Ranking nicht
- Frühere automatische Profilregeln werden beim Laden dauerhaft deaktiviert und können über die Oberfläche nicht reaktiviert werden

## 0.11.3-beta

- Inventar-Tooltips nach der Taschenintegration wiederhergestellt
- MasterLooter ersetzt keine vorhandenen Taschen-`OnClick`-Handler mehr
- Globaler Blizzard-Containerhandler und registrierte Maustasten bleiben vollständig unangetastet
- STRG+Rechtsklick wird ausschließlich über einen ergänzenden `HookScript` verarbeitet
- Regressionstest stellt sicher, dass vorhandene `OnEnter`-Tooltip-Handler unverändert bleiben

## 0.11.2-beta

- STRG+Rechtsklick auf Items in den 3.3.5a-Taschen öffnet das Lootmaster-Fenster und übernimmt das Item direkt
- Standard-Containerbuttons werden beim Login, bei Taschenänderungen und beim Öffnen des Lootmasters erneut erkannt
- Globaler Blizzard-Containerhandler dient als zusätzlicher Fallback für dynamisch erstellte Taschenbuttons
- Direkte manuelle Zugänge über `/ml master`, `/lootmaster`, `/mlmaster` und Umschalt+Rechtsklick am Minimap-Button ergänzt
- Normale Taschen-Klicks werden unverändert an WoW beziehungsweise das jeweilige Taschen-Addon weitergereicht

## 0.11.1-beta

- Absturz beim Öffnen der neuen Einstellungen auf Ascension behoben
- Nicht verfügbare Lua-Funktion `math.mod` durch den 3.3.5a-kompatiblen Modulo-Operator ersetzt
- Unvollständig aufgebaute Einstellungsfenster werden erkannt und nicht mehr anschließend über fehlende Bedienelemente aktualisiert
- Vollständiger UI-Aufbau, Aktualisierung und Tabwechsel werden nun in einem eigenen 3.3.5a-nahen Smoke-Test ausgeführt

## 0.11.0-beta

- Angeheftetes Minimap-Menü vollständig durch eine eigenständige, Gargul-inspirierte Einstellungsoberfläche ersetzt
- Breites 800×600-Hauptfenster mit dauerhafter Seitennavigation für Übersicht, Allgemein, Loot & Rollen, PackMule sowie Daten & Diagnose
- Sämtliche Werkzeuge sind über die Übersicht auch ohne Gruppe, Lootfenster oder aktive Lootmaster-Sitzung erreichbar
- `/ml` öffnet nun die Übersicht und Einstellungen; `/ml master` öffnet gezielt die eigentliche Lootmaster-Verteilung
- Gargul-ähnliche Minimap-Direktaktionen: Links Übersicht, Rechts Import/Export, Mitte Historie und Umschalt+Links SoftRes
- Eintrag in WoWs Addon-Optionen ergänzt, der die vollständige MasterLooter-Oberfläche öffnet
- Navigation und Direktaktionen durch zusätzliche Regressionstests abgesichert

## 0.10.2-beta

- Gewinner können auch nach Ablauf oder manuellem Schließen der Rollzeit zuverlässig vergeben werden
- Ein bereits in der eigenen Tasche vorhandenes Item wird bei Selbstvergabe direkt als zugestellt verbucht und erzeugt keinen Selbsthandel
- Selbstvergabe aktualisiert Strichliste und +1-Regeln wie jede andere bestätigte Übergabe
- OS-Wurfbereich kompakter und eindeutig als `/roll 2–99` neben dem festen MS-Bereich `/roll 100` dargestellt
- Seitennavigation aus dem Tabellenkopf verschoben, damit die Spalte `G/MS/OS · +1` vollständig sichtbar bleibt
- Vergabefehler zeigen künftig den tatsächlichen internen Ablehnungsgrund
- Smoke-Runner erkennt nun auch Lua-Fehler, bei denen der verwendete Interpreter fälschlich Exitcode 0 zurückgibt

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
