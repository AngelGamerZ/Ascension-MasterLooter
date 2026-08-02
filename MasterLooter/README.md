# MasterLooter

Eigenständige Loot- und Raidverwaltung für Project Ascension auf dem 3.3.5a-Client.

## Installation

1. Die Ordner `MasterLooter` und `MasterLooter_ItemData` nach `Interface/AddOns/` kopieren.
2. Im Charakterbildschirm **Veraltete Addons laden** aktivieren, falls der verwendete Ascension-Build dies verlangt.
3. Alle Gruppenmitglieder benötigen `MasterLooter`; `MasterLooter_ItemData` ist optional und wird bei einer Suche nachgeladen.
4. Im Spiel `/ml` eingeben.

## Wichtigster Ablauf

Der Lootmaster zieht ein Item direkt aus der Tasche, dem Blizzard-Lootfenster oder der MasterLooter-Lootliste auf die Item-Ablagefläche, stellt Dauer und Notiz ein und klickt **Roll starten**. Das Addon sendet eine versionierte Sitzung an Raid oder Gruppe. Auf allen Clients öffnet sich das Teilnehmerfenster mit Item, Restzeit und den Schaltflächen **Haupt-Skill**, **Neben-Skill** und **Passen**. Antworten werden der Sitzungs-ID zugeordnet und erscheinen live beim Lootmaster. **Item vergeben** veröffentlicht das Ergebnis und versucht bei geöffnetem Lootfenster die 3.3.5a-Masterloot-API zu verwenden.

Der Eingabebereich prüft diesen Ablauf unmittelbar: **Roll starten** wird erst mit einem gültigen Item und einer Rollzeit zwischen 5 und 300 Sekunden aktiv. Die Zeit lässt sich in Fünf-Sekunden-Schritten ändern, die optionale Notiz ist auf 160 Zeichen begrenzt und ein Rechtsklick entfernt das abgelegte Item. Während eine Session läuft, sind die Eingaben gesperrt; Status- und Feldfarben zeigen Fehler, Versand und Abschluss verständlich an.

## Module

- Mehrclient-Kommunikation mit Fragmentierung, Deduplizierung und Sitzungs-Synchronisierung
- Lootmaster- und Teilnehmerfenster
- Loot-Erfassung, Award-Historie, PackMule- und Trade-Warteschlangen
- SoftRes, HardRes, Prioritäten, +1 und Boosted Rolls
- GDKP-Sitzungen, Verkäufe, Pot und Cuts
- Synchronisierte GDKP-Auktionen mit Mindestschritt, Anti-Snipe und Replay-Schutz
- Native Gruppenloot-Rolls, Raidverwaltung, Versionsprüfung und Tascheninspektor
- Persistente Profile und Einstellungen
- Optionaler, zur Laufzeit lernender Ascension-Itemindex

## Befehle

- `/ml` – Lootmaster-Fenster öffnen
- `/ml roll <Itemlink> [Sekunden]` – Roll direkt starten
- `/ml sr <Spieler> <Item-ID>` – SoftRes setzen
- `/ml plus <Spieler> [Wert]` – +1 ändern
- `/ml gdkp start|sale|finish` – GDKP steuern
- `/ml auction|raid|version|bags|native` – zusätzliche Werkzeuge öffnen
- `/ml version` – Build- und Protokollversion

## Entwicklungstest

Vom Repository-Stamm:

```powershell
npx --yes --package fengari-node-cli fengari .\MasterLooter\Tests\TestHarness.lua
```

Der Harness lädt zwei voneinander isolierte Addon-Clients und prüft Kommunikation, Paketfragmentierung, Deduplizierung, `START → ROLL → RESULT`, Lootregeln und GDKP.

## Grenzen des Clients

Geschützte Aktionen bleiben absichtlich benutzergesteuert. Das Addon kann Masterloot nur vergeben, wenn das Lootfenster offen ist und der Gewinner ein gültiger Kandidat des Slots ist. Ein statischer Vollbestand aller Ascension-Custom-Items wird nicht behauptet: Das Begleitaddon lernt echte Links aus Taschen und Chat und kann eine vorhandene Ascension-AtlasLoot-Datenquelle zur Laufzeit übernehmen.
