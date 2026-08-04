# Funktionsstatus 0.15.0-beta

MasterLooter ist eine eigenständige Neuimplementierung für Project Ascension auf Basis des WoW-3.3.5a-Clients. Die Beta deckt den vollständigen geplanten Kernablauf von der Itemauswahl bis zur bestätigten Vergabe ab.

## Roll- und Lootablauf

- Synchronisierte MS-/OS-/Passen-Sitzungen mit öffentlichem `/roll`; Spieler ohne Addon können vollständig teilnehmen.
- Vom Lootmaster vorgegebener OS-Bereich, wiederholte Zeitansagen und Sekundencountdown ab zehn Sekunden.
- Kompakte Teilnehmer- und Lootmaster-Fenster mit Warteschlangenwechsel ohne gesperrte Folgesitzung.
- Itemübernahme per Drag-and-drop sowie STRG+Rechtsklick aus nativen Blizzard- und den von Ascension ausgelieferten ElvUI-Lootslots; das Öffnen aus dem Lootfenster funktioniert auch solo und ohne aktiven Masterloot.
- Persistente Lootslot-Warteschlange und Wiederherstellung eigener aktiver Rolls nach einem Reload.

## Vergabe und Handel

- Direkte Masterloot-Vergabe wird erst nach `LOOT_SLOT_CLEARED` als zugestellt verbucht.
- Ist ein Gewinner zu weit entfernt oder kein gültiger Kandidat, nimmt die bereits ausdrücklich gestartete Vergabe den exakten Lootslot automatisch für den Lootmaster auf.
- Der Gewinner erhält sofort eine Whisper-Erklärung zum Handels-Fallback, auch ohne installiertes Addon. Erst nach bestätigter Slotleerung entsteht ein Handelseintrag.
- Handelsaufgaben sind je Gewinner gruppiert, prüfen Taschenbestand, Partner, Slots, Stapel und eine geschätzte Zwei-Stunden-Frist.
- Weitere Erinnerungen außerhalb der Reichweite bleiben nach bestätigtem Taschenfund rate-limitiert.
- In Reichweite handelt MasterLooter den Gewinner automatisch über dessen Gruppen- oder Raideinheit an.
- Öffnet der richtige Gewinner den Handel, werden bis zu sechs vorgesehene Items seriell automatisch in freie Slots gelegt – unabhängig davon, ob der Empfänger das Addon besitzt.
- Zwei MasterLooter-Clients koordinieren eine anstehende Übergabe zusätzlich per sicherem Addon-Handshake.
- Vorgemerkte Items werden beim verifizierten Gewinner automatisch eingelegt; das Annehmen und Abschließen des Handels bleibt immer eine bewusste manuelle Aktion des Lootmasters.

## Regeln und Historie

- SoftRes, HardRes, Prioritäten, Boosted Rolls und separates +1-Ranking.
- Strichliste mit Gesamt-, MS-, OS- und sonstigen Vergaben sowie Audit-Historie.
- +1 wird niemals automatisch durch eine Vergabe oder einen Handel erhöht. Der Lootmaster vergibt einen Strich ausschließlich bewusst über den separaten `+1`-Button der Spielerzeile.
- Doppelte Zustellereignisse werden über Sitzungs- beziehungsweise Handels-IDs nicht doppelt gebucht.
- CSV-/TSV-Export für Vergaben, Prioritäten und Strichliste sowie validierter Import mit automatischer Sicherung und Wiederherstellung.

## GDKP und Verwaltung

- GDKP-Sitzungen, Verkäufe, Pot, gewichtete Anteile und Zahlungsstatus `OPEN`, `PAID` und `HELD`.
- Persistente sequentielle Auktionswarteschlange, Mindestgebot, Schrittweite, Anti-Snipe und sichere Owner-Wiederherstellung.
- Raidübersicht, Umwandlung, Bereitschaftscheck, Befördern, Degradieren und Entfernen über explizite Schaltflächen.
- PackMule-Regeln für Qualität, Bindung, mehrere Ziele, Disenchanter und Round-Robin; das tatsächliche Bewegen bleibt klickgebunden.
- Taschenfreigabe und Tascheninspektor zwischen Spielern mit installiertem Addon.

## Betrieb und Diagnose

- Kopierbare Roll- und Kommunikationsdiagnose, begrenztes internes Fehlerprotokoll und Kommunikations-Trace.
- Profile mit charakterspezifischer Zuordnung, UI-Skalierung, Positionsreset, Ansagekanal und PackMule-Einstellungen.
- Optionaler Itemdaten-Begleiter lernt echte Ascension-Links und trennt Beobachtungen nach Realm, Locale und Client-Interface.
- AutoRoll-Regeln geben sichere MS-/OS-/Passen-Empfehlungen; der eigentliche `/roll` bleibt ein bewusster Klick.
- TMB-Prioritäten, SoftRes-Limits sowie +1-/Boosted-Roll-Snapshots lassen sich importieren beziehungsweise kontrolliert im Raid synchronisieren.
- Das persistente Beute-Ledger zeigt Drop, Aufnahme, Vergabe, Handel, Entzauberung und ungeklärte Zustände mit Genauigkeitskennzeichnung.
- GDKP unterstützt parallele Auktionen, Gold-Ledger, Teilnehmer/Cuts, Mutatoren, Preislisten sowie versionierten Im-/Export.
- Willkommensfenster, Tastenkürzel, Ascension-Itemsuche und zweistufig bestätigter Komplett-Reset.

## Technische Grenzen

- WoW-geschützte Aktionen können und sollen nicht ohne Hardwareklick automatisiert werden.
- Taschen anderer Spieler sind ohne MasterLooter auf deren Client nicht auslesbar; öffentliche `/roll`-Teilnahme funktioniert trotzdem ohne Addon.
- Handelsfähigkeit und Ablaufzeit sind auf 3.3.5a nur abschätzbar. Der tatsächliche Serverzustand und die sichtbare Tasche bleiben maßgeblich.
- Der Itemindex ist laufzeitlernend und keine Behauptung eines vollständigen, statischen Datenbank-Snapshots aller Ascension-Seasons.
- Automatisierte Tests ersetzen keinen Mehrclient-Livetest auf dem jeweils verwendeten Ascension-Realm.
