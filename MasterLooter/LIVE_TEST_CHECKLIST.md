# Ascension Live-Test

Der automatisierte Harness prüft die Lua- und Mehrclient-Logik außerhalb des Spiels. Vor einer öffentlichen Verteilung sollte ein kurzer Test auf dem konkreten Ascension-Realm folgen.

1. Beide Addonordner auf zwei Clients installieren und Lua-Fehleranzeige aktivieren (`/console scriptErrors 1`).
2. Gruppe bilden, Master Loot aktivieren und `/ml version` sowie das Versionsfenster prüfen.
3. Lootmaster: `/ml`, je ein echtes Item aus Tasche und geöffnetem Lootfenster auf die Item-Ablagefläche ziehen, 15 Sekunden wählen und starten.
4. Teilnehmer: kontrollieren, dass Item, Timer und MS/OS/Pass automatisch erscheinen; einmal klicken.
5. Lootmaster: prüfen, dass nur eine hostgenerierte Wurfzahl erscheint; Gewinner vergeben.
6. Mit offenem Lootfenster direkte Vergabe prüfen. Zwei identische Drops einmal ausrollen, danach in derselben Rolltabelle erst den besten und nach bestätigter Slotleerung den zweitbesten Spieler anklicken und vergeben. Danach einen absichtlich nicht direkt vergebbaren Fall testen und die Trade-Warteschlange kontrollieren.
7. Trade abschließen und prüfen, dass erst die Ascension-Erfolgsmeldung den Eintrag als zugestellt markiert.
8. SoftRes/HardRes, Priorität und Boost setzen; bei einer Vergabe `+1 = 0`, bei einer zweiten bewusst `+1 = 1` wählen und die Rangfolge mit mindestens drei Spielern prüfen.
9. Im Raid Master Looter zuweisen, die einmalige Befehlsnachricht prüfen und von einem zweiten Client `SR` sowie `SL` ausschließlich per Whisper senden; Antworten dürfen weder im Raid- noch im Gruppenchat erscheinen. Optional `#SR` und `?SL` als kompatible Aliase prüfen.
10. GDKP-Sitzung und Auktion starten; Mindestschritt, Rebid und Anti-Snipe testen; `/reload` während aktiver GDKP-Sitzung prüfen.
11. Einen nativen Gruppenloot-Wurf auslösen und prüfen, dass ausschließlich Blizzards Bedarf-/Gier-/Entzaubern-/Passen-Oberfläche erscheint.
12. Raidverwaltung und Tascheninspektor nur mit Testcharakteren verwenden; alle Aktionen bleiben explizite Buttonklicks.
13. Bei einem Ascension-Custom-Item die Suche zuerst ohne, dann mit installiertem Ascension AtlasLoot prüfen.

Bei einem Fehler bitte `MasterLooterDB`, die genaue Realm-/Season-Angabe, den Lua-Stack und den Ablauf beilegen. Servereigene Events oder Rückgabewerte können zwischen Ascension-Realms variieren.
