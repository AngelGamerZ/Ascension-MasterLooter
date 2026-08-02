# Netzwerkprotokoll v3

Prefix: `MLOOT335`

Jede Nutzlast besteht aus längenkodierten Feldern. Sie wird in höchstens 210 Byte große Teile zerlegt; der Rahmen enthält Protokollversion, Paket-ID, Teilnummer und Gesamtzahl. Empfänger setzen Teile auch bei abweichender Reihenfolge zusammen, verwerfen Wiederholungen und räumen unvollständige Pakete nach einem Timeout auf.

## Roll-Nachrichten

- `START`: Protokoll, Sitzung, Sequenz, Itemlink, Erstellzeit, Dauer, Kategorien, Notiz, OS-Wurfmaximum
- `ACK`: Protokoll, Sitzung, Sequenz
- `ROLL`: Protokoll, Sitzung, Spieler-Sequenz, Kategorie und Notiz; der Client liefert keine Wurfzahl
- `ROLL_ACK`: Protokoll, Sitzung, Spieler-Sequenz, Kategorie, einmalig vom Lootmaster erzeugter Wurf und Notiz
- `STOP`: Protokoll, Sitzung, Autoritäts-Sequenz, Grund
- `RESULT`: Protokoll, Sitzung, Autoritäts-Sequenz, Gewinner, Kategorie, Wurf, Notiz, Zeit
- `SYNC`: Anforderung oder aktiver Sitzungszustand für spätes Einloggen/Reload

Nur der vom lokalen 3.3.5a-Gruppenzustand bestätigte Lootmaster beziehungsweise Gruppenleiter darf `START`, `STOP` und `RESULT` autoritativ auslösen. Veraltete Sequenzen und Nachrichten unbekannter Sitzungen werden ignoriert.

MS und OS verwenden öffentliche Blizzard-Würfe. `MS` entspricht immer `/roll 100`; `OS` entspricht `/roll X` mit dem vom Host übertragenen Maximum zwischen 2 und 99. Der Host wertet vertrauenswürdige `CHAT_MSG_SYSTEM`-Wurfmeldungen aus und akzeptiert pro Spieler nur den ersten passenden Bereich. Dadurch können Gruppenmitglieder ohne Addon teilnehmen. Die älteren `ROLL`- und `ROLL_ACK`-Nachrichten bleiben für Protokollkompatibilität und bestätigte Addon-Antworten erhalten; die Oberfläche erzeugt Wurfzahlen jedoch ausschließlich über `RandomRoll`.
