# MasterLooter

Eigenständige Loot- und Raidverwaltung für Project Ascension auf dem 3.3.5a-Client.

## Installation

1. Die Ordner `MasterLooter` und `MasterLooter_ItemData` nach `Interface/AddOns/` kopieren.
2. Im Charakterbildschirm **Veraltete Addons laden** aktivieren, falls der verwendete Ascension-Build dies verlangt.
3. Nur Spieler mit `MasterLooter` erhalten das Rollfenster. Spieler ohne Addon können über die im Gruppenchat angekündigten `/roll`-Befehle teilnehmen. `MasterLooter_ItemData` ist optional.
4. Im Spiel `/ml` eingeben. Die eigenständige Übersicht und alle Einstellungen funktionieren auch außerhalb einer Gruppe oder Lootmaster-Sitzung.

## Wichtigster Ablauf

Der Lootmaster zieht ein Item direkt aus der Tasche, dem Blizzard-Lootfenster oder der MasterLooter-Lootliste auf die Item-Ablagefläche, stellt Dauer, OS-Wurfmaximum und Notiz ein und klickt **Roll starten**. Das Addon sendet eine versionierte Sitzung an Raid oder Gruppe. Auf allen Clients öffnet sich das Teilnehmerfenster mit Item, Restzeit und den Schaltflächen **MS**, **OS** und **Passen**. Antworten werden der Sitzungs-ID zugeordnet und erscheinen live beim Lootmaster. **Item vergeben** veröffentlicht das Ergebnis und versucht bei geöffnetem Lootfenster die 3.3.5a-Masterloot-API zu verwenden.

Die Rollbuttons führen echte öffentliche Würfe aus: `MS` verwendet immer `/roll 100`; das OS-Maximum zwischen 2 und 99 wird ausschließlich vom Lootmaster für die gestartete Sitzung vorgegeben. Der Wert wird an alle Addon-Clients übertragen und passt dort den OS-Button an. Lokale Einstellungen eines Teilnehmers haben keinen Einfluss. Die Startansage nennt beide Befehle, sodass auch Spieler ohne installiertes Addon teilnehmen können. Der Masterlooter liest deren Blizzard-Systemmeldung; pro Spieler zählt der erste zur laufenden Sitzung passende Wurf.

Der Eingabebereich prüft diesen Ablauf unmittelbar: **Roll starten** wird erst mit einem gültigen Item und einer Rollzeit zwischen 5 und 300 Sekunden aktiv. Die Zeit lässt sich in Fünf-Sekunden-Schritten ändern, die optionale Notiz ist auf 160 Zeichen begrenzt und ein Rechtsklick entfernt das abgelegte Item. Während eine Session läuft, sind die Eingaben gesperrt; Status- und Feldfarben zeigen Fehler, Versand und Abschluss verständlich an.

Teilnehmer sehen MasterLooter-Rolls nach dem Gargul-Prinzip als kompakte 520×84-Pixel-Leiste im unteren Bildschirmbereich: Status und Rollbuttons oben, Itemicon, Itemlink, Notiz und Restzeit in einer schmalen farbigen Itemzeile darunter. Die Oberfläche unterstützt ein ausdrückliches **Passen**, schließt bei Ablauf automatisch und verwendet eine versionierte Standardposition oberhalb des unteren Bildschirmrands. Der Masterlooter kündigt die verbleibende Zeit regelmäßig in Gruppe oder Raid an und zählt ab zehn Sekunden jede Sekunde herunter. Normale Bedarf-/Gier-/Entzaubern-Würfe verbleiben vollständig in der Blizzard-Oberfläche.

Das Fenster **Erfasster Loot** sammelt Lootereignisse im Hintergrund und öffnet sich ausschließlich manuell über `/ml loot` oder die Werkzeugübersicht. Crafting, Entzaubern, Behälter und normales Aufsammeln öffnen es nicht automatisch.

## Module

- Mehrclient-Kommunikation mit Fragmentierung, Deduplizierung und Sitzungs-Synchronisierung
- Lootmaster- und Teilnehmerfenster
- Loot-Erfassung, Award-Historie, PackMule- und Trade-Warteschlangen
- Automatisches Anhandeln in Reichweite und Einlegen ausstehender Gewinner-Items, manuelle Handelsannahme sowie Whisper-Erinnerung außerhalb der Reichweite
- SoftRes, HardRes, Prioritäten, +1 und Boosted Rolls
- GDKP-Sitzungen, Verkäufe, Pot und Cuts
- Synchronisierte GDKP-Auktionen mit Mindestschritt, Anti-Snipe und Replay-Schutz
- Unveränderte Blizzard-Gruppenloot-Oberfläche sowie Raidverwaltung, Versionsprüfung und Tascheninspektor
- Persistente Profile und Einstellungen
- Optionaler, zur Laufzeit lernender Ascension-Itemindex
- Persistentes Beute-Ledger mit Status- und Genauigkeitskennzeichnung
- Bis zu vier parallele GDKP-Auktionen, Gold-Ledger, Preislisten, Mutatoren und Cuts
- AutoRoll-Empfehlungen, TMB-, BISBEARD-, DFT-, ClassicPR-/CSV- und RRobin-Import sowie abgesicherter +1-/Boosted-Roll-Sync
- Optionale automatische Reservierungsübernahme aus LootReserve
- Profilverwaltung, Tastenkürzel, Willkommensfenster und vollständiger Datenreset

## Befehle

- `/ml` – Übersicht und Einstellungen öffnen
- `/ml master` – Lootmaster-Fenster öffnen
- `/lootmaster` oder `/mlmaster` – Lootmaster-Fenster ohne Umweg öffnen
- `/ml roll <Itemlink> [Sekunden]` – Roll direkt starten
- `/ml sr <Spieler> <Item-ID>` – SoftRes setzen
- `/ml plus <Spieler> [Wert]` – +1 ändern
- `/ml gdkp start|sale|finish` – GDKP steuern
- `/ml auction|raid|version|bags` – zusätzliche Werkzeuge öffnen
- `/ml version` – Build- und Protokollversion
- `/ml debug` – kopierbare Gesamtdiagnose für Module, Events, Fehler, UI, Roll, Loot, Handel, Kommunikation und Tooltip öffnen
- `/ml debug clear` – bisherige Trace-Daten leeren und eine frische Gesamtdiagnose öffnen
- `/ml tooltipdebug` – kopierbare Zeitleiste aller globalen Tooltip- und Loot-/Taschenereignisse öffnen
- `/ml sync <Spieler>` – autoritativen +1-/Boosted-Roll-Snapshot bei einem vertrauenswürdigen Spieler anfordern
- `/ml trust <Spieler>` – vertrauenswürdigen Regeldaten-Sender setzen

Am Minimap-Button öffnet Umschalt+Rechtsklick direkt das Lootmaster-Fenster. STRG+Rechtsklick auf unterstützten Blizzard-/Ascension-Lootslots oder Taschenitems übernimmt das Item in den Lootmaster; Drag-and-drop und die Ascension-Itemsuche bleiben gleichwertige Alternativen.

MasterLooter verwendet für sämtliche eigenen Itemanzeigen einen isolierten `MasterLooterTooltip`. Der globale Blizzard-/Ascension-`GameTooltip` wird von der Oberfläche weder besetzt noch geleert oder ausgeblendet. Die Diagnose beobachtet ihn ausschließlich per Nach-Hook und verändert sein Verhalten nicht.

`+1` wird grundsätzlich manuell vergeben: Ein Klick auf eine Spielerzeile wählt den Gewinner sichtbar aus. Der separate `+1`-Button derselben Zeile vergibt genau einen Strich; die Schaltfläche **Item vergeben** überträgt ausschließlich das Item. Direkte Vergaben, Selbstvergaben und abgeschlossene Handelsübergaben erzeugen niemals automatisch einen Strich. Die getrennten Itemzähler `G/MS/OS` bleiben als Vergabehistorie erhalten.

## Entwicklungstest

Vom Repository-Stamm:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\MasterLooter\Tests\Smoke.ps1
```

Der Harness lädt zwei voneinander isolierte Addon-Clients und prüft Kommunikation, Paketfragmentierung, Deduplizierung, `START → ROLL → RESULT`, Lootregeln und GDKP.

## Grenzen des Clients

Das Addon versucht die Handelsöffnung automatisch und legt vorgemerkte Items beim verifizierten Gewinner ein. Es nimmt den Handel niemals selbst an; Annahme und Abschluss bleiben beim Lootmaster. Masterloot kann nur vergeben werden, wenn das Lootfenster offen ist und der Gewinner ein gültiger Kandidat des Slots ist. Ein statischer Vollbestand aller Ascension-Custom-Items wird nicht behauptet: Das Begleitaddon lernt echte Links aus Taschen und Chat und kann eine vorhandene Ascension-AtlasLoot-Datenquelle zur Laufzeit übernehmen.
