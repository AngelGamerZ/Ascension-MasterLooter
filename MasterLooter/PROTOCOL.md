# Netzwerkprotokoll v2

Prefix: `MLOOT335`

Jede Nutzlast besteht aus längenkodierten Feldern. Sie wird in höchstens 210 Byte große Teile zerlegt; der Rahmen enthält Protokollversion, Paket-ID, Teilnummer und Gesamtzahl. Empfänger setzen Teile auch bei abweichender Reihenfolge zusammen, verwerfen Wiederholungen und räumen unvollständige Pakete nach einem Timeout auf.

## Roll-Nachrichten

- `START`: Protokoll, Sitzung, Sequenz, Itemlink, Erstellzeit, Dauer, Kategorien, Notiz
- `ACK`: Protokoll, Sitzung, Sequenz
- `ROLL`: Protokoll, Sitzung, Spieler-Sequenz, Kategorie und Notiz; der Client liefert keine Wurfzahl
- `ROLL_ACK`: Protokoll, Sitzung, Spieler-Sequenz, Kategorie, einmalig vom Lootmaster erzeugter Wurf und Notiz
- `STOP`: Protokoll, Sitzung, Autoritäts-Sequenz, Grund
- `RESULT`: Protokoll, Sitzung, Autoritäts-Sequenz, Gewinner, Kategorie, Wurf, Notiz, Zeit
- `SYNC`: Anforderung oder aktiver Sitzungszustand für spätes Einloggen/Reload

Nur der vom lokalen 3.3.5a-Gruppenzustand bestätigte Lootmaster beziehungsweise Gruppenleiter darf `START`, `STOP` und `RESULT` autoritativ auslösen. Veraltete Sequenzen und Nachrichten unbekannter Sitzungen werden ignoriert.

Wurfzahlen entstehen ausschließlich auf dem autoritativen Client. Eine spätere Kategorienänderung verwendet dieselbe bereits zugewiesene Zahl; wiederholtes Senden ermöglicht daher keinen neuen Wurf.
