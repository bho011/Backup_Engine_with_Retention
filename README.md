# BackupTool – PowerShell Automatisierung (Klausurprojekt)

## Kurzkonzept (Architektur / Ablauf)
Dieses Projekt implementiert ein einfaches, **Backup-Engine** in PowerShell mit **Menüführung**, Konfiguration via JSON, Logging sowie **Retention-Regeln**. Die Umsetzung orientiert sich an einer sauberen Trennung von **Code (src)** und **Konfiguration (config)** und nutzt für den Kopiervorgang bewusst **Robocopy** als Windows-Bordmittel.

- Main.ps1 stellt Menüs bereit und ruft Action-Skripte über einen Dispatcher auf (Try/Catch + Logging).
- Common.ps1 kapselt Pfadlogik, Config-Laden/Speichern (JSON) und Logging (eine zentrale Logdatei).
- BackupStart erzeugt pro Lauf eine RunId (Zeitstempel), erstellt Zielordner unter Backup.ZielRoot\RunId
  und schreibt Robocopy-Details nach reports\runs\RunId\robocopy.log.
- ApplyRetention berechnet zu behaltende Runs (DailyKeep + „neuester Run pro Kalenderwoche“ für WeeklyKeep)
  und löscht bestätigte Runs inkl. Reports.


## Projektstruktur

<Projektwurzel>\
- scr\
  - Main.ps1
  - actions\
    - BackupStart.ps1
    - BackupList.ps1
    - BackupManage.ps1
    - BackupSettings.ps1
    - RetentionSettings.ps1
    - ApplyRetention.ps1
    - ShowLogs.ps1
- config\
  - config.json
  - lib\
    - Common.ps1
- logs\
  - backup.log
- reports\
  - runs\
    - <RunId>\
      - robocopy.log
- tests\
  - ...


	
## Voraussetzungen
- Windows (Robocopy ist Bestandteil von Windows)
- Windows PowerShell 5.1 oder PowerShell 7.x (absichtlich verzicht auf Powershell-7 exclusives)
- Schreibrechte auf das Zielverzeichnis (Backup.ZielRoot)

## Start
Aus der Projektwurzel:

 - .\scr\Main.ps1

**Hinweis:**
Die Skripte sind digital signiert. Empfohlen ist eine ExecutionPolicy wie `AllSigned`.
`-ExecutionPolicy Bypass` sollte nur zu Test-/Fehleranalysezwecken genutzt werden.

# Als Administrator:
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope LocalMachine
# Als Akueller Benutzer:
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope CurrentUser



## Code Signing (Signierte Skripte)
- Alle *.ps1 Dateien sind digital signiert.
- Empfohlen: ExecutionPolicy `AllSigned` (oder strengere Unternehmensvorgaben per GPO).
- Das Zertifikat (Publisher) muss auf dem Zielsystem als vertrauenswürdig hinterlegt sein,
  sonst wird die Ausführung trotz Signatur blockiert bzw. es erscheint eine Sicherheitsabfrage.


## Ausführung von beliebigem Ort (Working Directory unabhängig)
---
**Voraussetzung: Die Ordner- bzw. Dateistruktur bleibt unverändert ("src\", "src\actions\", "config\", "logs\", "reports\").**
**Wichtig ist das die Ordnerstrucktur, ganz besonders .\Common.PS1 nicht gelöscht ode verändert werden darf, dazu später mehr**

Das Projekt kann von jedem beliebigen Ort aus gestartet werden. Der Grund, alle internen Pfade werden relativ zum Speicherort der Skripte (über "$PSScriptRoot") und daraus abgeleitet relativ zur Projektwurzel aufgelöst – nicht relativ zum aktuellen Arbeitsverzeichnis der PowerShell.



**Warum das funktionier**  
- "Main.ps1" lädt "Common.ps1" nicht über "pwd", sondern über den Skriptpfad / Projektwurzel-Logik.  
- Die Actions sind so gebaut, dass sie "Common.ps1" ebenfalls über den Skriptstandort erreichen (und nicht über das aktuelle Verzeichnis). 

---

> „Damit ist die Ausführung zuverlässig über Autostart/Task Scheduler möglich, ohne dass ein bestimmtes Startverzeichnis vorausgesetzt wird.“

---

## Konfiguration (config\config.json)

Die wichtigsten Einstellungen werden in config\config.json gespeichert:
Backup.Quellen (Array): Pfade, die gesichert werden sollen (z. B. C:\Data)
Backup.ZielRoot (String): Zielbasis für Backups (z. B. D:\Backup)
Retention.DailyKeep (Int): Anzahl der letzten Runs, die behalten werden
Retention.WeeklyKeep (Int): Anzahl der letzten Wochen-Snapshots (neuester Run je Woche)

**Standarts** sind

Beispiel:
	{
	"Retention": { "DailyKeep": 7, "WeeklyKeep": 4 },
	"Backup": {
		"Quellen": ["C:\\Data", "C:\\Baris\\Huseyinoglu\\Projektarbeit"],
		"ZielRoot": "D:\\Backup"
	}
	}


# Dokumentation – 3 Teilprojekte
## Teilprojekt 1: Backup-Engine ausfü.

Dieses Teilprojekt implementiert den operativen Backup-Workflow. Das Backup wird über Robocopy aus den in der config.json definierten Quellen in einen versionierten Run-Ordner (Zeitstempel) im ZielRoot geschrieben. Dadurch entstehen nachvollziehbare Backup-Stände, ohne dass alte Daten überschrieben werden. Zusätzlich werden ExitCodes erfasst, um den Erfolg des Kopiervorgangs bewerten zu koennen. Die Bedienung erfolgt über das Backup-Untermenü im Hauptmenü.

**BEACHTE: Standardmäßig sind Quell- & Zielverzeichnis auf "C:Dateien und D:Backup" eingestellt, änderung der Quell- & Zielordner muss unbedingt über Einstellungen erfolgen**

### Abnahmebedingungen:

	- Backup starten (src\actions\BackupStart.ps1): Führt Robocopy pro Quelle aus und legt pro Lauf einen neuen Run-Ordner an.
			- **Wichtigger Hinweis:** in den zusammenhang ist, dass man die Quelle einstellen muss bevor man den Backup beginnt, es wird zwar geprüft ob die Quelle exisitiert und es wird ein fehler angezeigt, jedoch gehört es zur Vorraussetzung/Validierung, die Quelle einzustellen, der Zielordner wird erzeugt wenn es das Speichermedium existiert! 

	- Backups ansehen (src\actions\BackupList.ps1): Listet vorhandene Run-Ordner im ZielRoot übersichtlich auf.

	- Backups loeschen/verwalten (src\actions\BackupManage.ps1): Loescht ausgewählte Runs inkl. zugehoeriger Reportdaten.

## Teilprojekt 2: Retention, Einstellungen und Konfiguration.

Dieses Teilprojekt kapselt alle konfigurierbaren Parameter zentral in einer JSON-Datei, damit das Skript flexibel bleibt und ohne Codeänderung anpassbar ist. Die Einstellungen werden über ein eigenes Menü gepflegt und anschliessend persistiert in config\config.json abgelegt. Dazu gehoeren sowohl Retention-Regeln (Daily/Weekly) als auch Backup-Quellen und ZielRoot. Alle Änderungen werden validiert (z. B. Zahlenbereiche) und nachvollziehbar protokolliert. Die Trennung von Code (src\actions) und Konfiguration (config) erhoeht Wartbarkeit und Übersicht.

### Abnahmebedingungen:

	- Retention Settings (src\actions\RetentionSettings.ps1): Ändern von DailyKeep/WeeklyKeep inkl. Validierung und Logging.
		
		- Retention-Settings-Standardwerte gesetzt, wiederherstellung ist einfach über das Menü aus der JSON möglich.

	- Backup Settings (src\actions\BackupSettings.ps1): Pflegt Backup.Quellen und Backup.ZielRoot in der JSON.

	- Retention anwenden/ autom auswerten der zu löschenden Backups (src\actions\ApplyRetention.ps1): Entfernt alte Runs regelbasiert (DailyKeep + WeeklyKeep) inkl. Sicherheitsabfrage.

## Teilprojekt 3: Benutzerführung (Consolen-Menü) Logging und Fehlerbehandlung. 

Dieses Teilprojekt sorgt für Nachvollziehbarkeit und Betriebssicherheit. Alle zentralen Ereignisse (Start/Ende von Aktionen, Konfig-Änderungen, Fehler) werden in einer einfachen Logdatei **logs\backup.log** dokumentiert. Gleichzeitig sorgt ein zentraler Dispatcher in Main.ps1 für ein einheitliches Fehlerhandling, damit einzelne Actions das Gesamtskript nicht unkontrolliert abbrechen. Der Menüaufbau ist konsistent (Zurück/Exit), wodurch die Bedienung auch ohne GUI klar und benutzerfreundlich bleibt. Zusätzliche Detailinformationen werden pro Run von robocopy in **reports\runs\RunId** abgelegt werden.

### Abnahmebedingungen:

	- Common Library (config\lib\Common.ps1): Gemeinsame Pfade, Ordner-Initialisierung, Config-Handling, Logging-Funktion.

	- Logs anzeigen (src\actions\ShowLogs.ps1): Oeffnet logs\backup.log in Notepad für schnelle Auswertung.

	- Main/Dispatcher (src\Main.ps1): Zentrales Menü, Action-Aufruf, Try/Catch und Exit-Codes.

# Bedienung (Menüübersicht)

## Backup-Engine

	- Backup starten

	- Backups ansehen

	- Backups loeschen / verwalten

	- Retention anwenden

## Einstellungen

	- Retention einstellen
		- Anzeige Retention Einstellungen
		- DailyKeep ändern 
		- WeeklyKeep ändern
		- Zurücksetzten auf Standard

	- Backup-Quellen und Ziel konfigurieren
		- Anzeige Backup Settings (Ziel ud Quelle)
		- Quelle hinzufügen
		- Quelle entfernen
		- ZielRoot setzen
		- Quick-Check (zeigt, ob Pfade existieren)

## Logs

	- Logdatei anzeigen (logs\backup.log)

## Annahmen & Grenzen
- Dieses Tool erstellt Backup-Runs (Snapshot-Ordner pro Lauf); es gibt keine Restore-Funktion.
- Es wird Robocopy verwendet; ExitCodes werden protokolliert, aber nicht „fachlich interpretiert“.
- Die Ordnerstruktur (scr/, scr/actions/, config/, config/lib/, logs/, reports/) muss unverändert bleiben.


# Hinweise / Randbedingungen
---
	Implementierung ist auf Windows PowerShell 5.1 ausgerichtet (keine ?? Operatoren) und verwendet keine PowerShell-7-exklusiven Sprachfeatures; unter Windows läuft sie in der Regel auch mit PowerShell 7.
	Robocopy ExitCodes sind bitmaskenbasiert; für die Klausur wird der ExitCode protokolliert und bei Bedarf ausgewertet.
	Bei ‚Zugriff verweigert‘ beim Löschen: Explorer/Notepad schließen (Dateisperren). Löschen ist über das Skript empfohlen, weil dabei auch der passende Report-Ordner mit entfernt wird.
---