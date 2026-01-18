# =========================
# src\Main.ps1
#
# Zweck:
# - Zentrales Hauptmenü (Console UI)
# - Dispatcher / "Router": ruft pro Menüpunkt ein eigenes Action-Skript auf
# - Lädt gemeinsame Funktionen/Variablen aus config\lib\Common.ps1
#
# Projektstruktur (Vorgabe):
#   <Projektwurzel>\
#     config\
#       lib\Common.ps1
#     logs\
#     reports\
#     src\
#       Main.ps1
#       actions\...
#     tests\
# =========================

Set-StrictMode -Version Latest
# StrictMode hilft, Tippfehler/unsaubere Variablennutzung früh zu erkennen.

$ErrorActionPreference = "Stop"
# Fehler sollen nicht stillschweigend weiterlaufen, sondern in try/catch landen.

# ------------------------------------------------------------
# 1) Projektwurzel ermitteln und Common.ps1 laden
#
# Dieses Skript liegt in:
#   <Projektwurzel>\src\Main.ps1
# $PSScriptRoot zeigt also auf:
#   <Projektwurzel>\src
#
# Projektwurzel ist damit 1 Ebene über $PSScriptRoot.
# Common.ps1 liegt in:
#   <Projektwurzel>\config\lib\Common.ps1
# ------------------------------------------------------------
$ProjektWurzel = Split-Path -Parent $PSScriptRoot
$CommonPfad    = Join-Path $ProjektWurzel "config\lib\Common.ps1"

# Wenn Common.ps1 nicht existiert, kann das Projekt nicht laufen.
if (-not (Test-Path $CommonPfad)) {
    Write-Host "FEHLER: Common.ps1 nicht gefunden unter: $CommonPfad" -ForegroundColor Red
    exit 99
}

# Dot-Sourcing:
# - Führt Common.ps1 aus
# - macht dessen Funktionen/Variablen hier verfügbar (z. B. Lese-Auswahl, Schreibe-Log, usw.)
. $CommonPfad

# ------------------------------------------------------------
# 2) Dispatcher-Funktion für Action-Skripte
#
# Aufgabe:
# - baut den Pfad zu einem Action-Skript zusammen (relativ zu src\)
# - prüft, ob die Datei existiert
# - führt sie aus
# - fängt Fehler ab und loggt sie
#
# Parameter:
# - RelativerPfadAbSrc: z. B. "actions\RetentionSettings.ps1"
# ------------------------------------------------------------
function Starte-Aktion {
    param(
        [Parameter(Mandatory)] [string] $RelativerPfadAbSrc
    )

    # $PSScriptRoot hier = <Projektwurzel>\src
    # => Aktionen liegen darunter in <Projektwurzel>\src\actions\
    $aktionsPfad = Join-Path $PSScriptRoot $RelativerPfadAbSrc

    # Wenn die Action-Datei fehlt, loggen und zurück ins Menü
    if (-not (Test-Path $aktionsPfad)) {
        Schreibe-Log -Level "ERROR" -Nachricht ("Aktion nicht gefunden: {0}" -f $aktionsPfad)
        Write-Host "Aktion nicht gefunden: $aktionsPfad" -ForegroundColor Red
        Warte-Auf-Enter
        return
    }

    # Logging: Start der Aktion
    Schreibe-Log -Level "INFO" -Nachricht ("Aktion gestartet: {0}" -f $RelativerPfadAbSrc)

    try {
        # Call-Operator:
        # Führt das Skript aus, als hätte man es direkt aufgerufen.
        & $aktionsPfad

        # Logging: Ende der Aktion (ohne Fehler)
        Schreibe-Log -Level "INFO" -Nachricht ("Aktion beendet: {0}" -f $RelativerPfadAbSrc)
    } catch {
        # Logging: Fehler in Aktion
        Schreibe-Log -Level "ERROR" -Nachricht ("FEHLER in Aktion {0}: {1}" -f $RelativerPfadAbSrc, $_.Exception.Message)

        # Benutzerfreundliche Ausgabe
        Write-Host "FEHLER in Aktion: $($_.Exception.Message)" -ForegroundColor Red
        Warte-Auf-Enter
    }
}

# ============================================================
# 3) Untermenü: Backup
#
# In diesem Menü werden 3 Action-Skripte aufgerufen:
# - actions\BackupStart.ps1
# - actions\BackupList.ps1
# - actions\BackupManage.ps1
# ============================================================
function Menue-Backup {
    while ($true) {
        Clear-Host
        Write-Host "============ Menue: Backup =================="
        Write-Host "============================================="
        Write-Host "1) Backup starten"
        Write-Host "2) Backups ansehen"
        Write-Host "3) Backups loeschen / verwalten"
        Write-Host "4) Retention anwenden (alte Backups loeschen)"
        Write-Host "============================================="
        Write-Host "B) Zurueck"
        Write-Host "X) Exit"
        Write-Host "=============================================="
        Write-Host " "

        # Lese-Auswahl verhindert ungültige Eingaben
        $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","2","3","4","B","b","X","x")

        switch ($auswahl.ToUpper()) {
            "1" { Starte-Aktion -RelativerPfadAbSrc "actions\BackupStart.ps1" }
            "2" { Starte-Aktion -RelativerPfadAbSrc "actions\BackupList.ps1" }
            "3" { Starte-Aktion -RelativerPfadAbSrc "actions\BackupManage.ps1" }
            "4" { Starte-Aktion -RelativerPfadAbSrc "actions\ApplyRetention.ps1" }


            # return beendet dieses Untermenü und springt zurück ins Hauptmenü
            "B" { return }

            # exit beendet das gesamte Skript
            "X" { exit 0 }
        }
    }
}

# ============================================================
# 4) Untermenü: Einstellungen
#
# Hier rufen wir aktuell:
# - actions\RetentionSettings.ps1
function Menue-Einstellungen {
    while ($true) {
        Clear-Host
        Write-Host "======== Menue: Einstellungen ========"
        Write-Host "======================================"
        Write-Host "1) Retention einstellen"
        Write-Host "2) Backup-Quellen & Ziel konfigurieren"
        Write-Host "======================================"
        Write-Host "B) Zurueck"
        Write-Host "X) Exit"
        Write-Host "======================================"
        Write-Host " "

        $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","2","B","b","X","x")

        switch ($auswahl.ToUpper()) {
            "1" { Starte-Aktion -RelativerPfadAbSrc "actions\RetentionSettings.ps1" }
            "2" { Starte-Aktion -RelativerPfadAbSrc "actions\BackupSettings.ps1" }
            "B" { return }
            "X" { exit 0 }
        }
    }
}

# ============================================================
# 5) Untermenü: Logs
#
# Hier rufen wir:
# - actions\ShowLogs.ps1 (simple: öffnet logs\backup.log)
# ============================================================
function Menue-Logs {
    while ($true) {
        Clear-Host
        Write-Host "=== Menue: Logs ==="
        Write-Host "==================="
        Write-Host "1) Logs anzeigen"
        Write-Host "==================="
        Write-Host "B) Zurueck"
        Write-Host "X) Exit"
        Write-Host "==================="
        Write-Host " "

        $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","B","b","X","x")

        switch ($auswahl.ToUpper()) {
            "1" { Starte-Aktion -RelativerPfadAbSrc "actions\ShowLogs.ps1" }
            "B" { return }
            "X" { exit 0 }
        }
    }
}

# ============================================================
# 6) Hauptmenü
#
# - stellt sicher, dass die Ordnerstruktur existiert
# - zeigt das Hauptmenü an
# - springt in Untermenüs
# ============================================================
function Hauptmenue {

    # Ordner (config/logs/reports) sicherstellen
    Initialisiere-Ordnerstruktur

    # Logging: Programmstart
    Schreibe-Log -Level "INFO" -Nachricht "BackupTool gestartet (Main.ps1)."

    while ($true) {
        Clear-Host
        Write-Host "========= BackupTool (Console) ==========="
        Write-Host "=========================================="
        Write-Host "PowerShell-Projektarbeit-Baris Huseyinoglu"
        Write-Host "=========================================="
        Write-Host "1) Backup"
        Write-Host "2) Einstellungen"
        Write-Host "3) Logs"
        Write-Host "X) Exit"
        Write-Host "=========================================="
        
        Write-Host " "

        $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","2","3","X","x")

        switch ($auswahl.ToUpper()) {
            "1" { Menue-Backup }
            "2" { Menue-Einstellungen }
            "3" { Menue-Logs }

            "X" {
                # Logging: Programmende
                Schreibe-Log -Level "INFO" -Nachricht "BackupTool beendet (Exit ueber Hauptmenue)."
                exit 0
            }
        }
    }
}

# ============================================================
# 7) Startpunkt / globales Fehlerhandling
#
# Falls irgendwo ein Fehler "fällt", wird er hier geloggt
# und es wird mit Exit-Code 99 beendet.
# ============================================================
try {
    Hauptmenue
} catch {
    Schreibe-Log -Level "ERROR" -Nachricht ("FATAL: Unbehandelter Fehler in Main.ps1: {0}" -f $_.Exception.Message)
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Warte-Auf-Enter
    exit 99
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUT7DTkwqDnnsGuaR5H2eKNEpz
# q/KgggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
# AQsFADApMScwJQYDVQQDDB5LbGF1c3VyLVBvd2VyU2hlbGwtQ29kZVNpZ25pbmcw
# HhcNMjYwMTE2MTAzODU1WhcNMjkwMTE2MTA0ODUyWjApMScwJQYDVQQDDB5LbGF1
# c3VyLVBvd2VyU2hlbGwtQ29kZVNpZ25pbmcwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCy4yRdttH3Yi+HV6lee2ObUiW2LeYSrYeqJA69Ia6AfnApPBNV
# U1oW6DcmquCzrSLOuT2hV12o+1hxnWs5Sh6m2KEmBaxyHntsVJJb9qcSrUzkolD5
# YaKKat8ez65an44tAacRQM2KohUUJaegLN5IEl5xAag36tXCu++Akhh+GaEuO9mq
# QLxsQMr3OsOYkOtCI2oX+GAmd5vd2uMU01QimwzOCg88gO5IchCMJ8C74Uy/sA4s
# KYtc+HIMgYENOonBxGq8qFGpNTBUzUO84RRz4K4Nq7gNYWsZ9J4oE+s2mZuRKy+2
# Upr9Hbu3dVvX+U/Tj6Na5b1efFrIIEo88koNAgMBAAGjRjBEMA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUvEKoVVkk6+3H2SCA
# PPFzN1iM5LcwDQYJKoZIhvcNAQELBQADggEBABpvHBNIesrB0bbR8WtU+rkAQFU7
# CsZr8z3gk8INm72ZaQeZU4Y856RypLEURiy+haSbn0ASlfHH0tMn8hcDuE44lGWU
# RKkb0ysCQWUDvxIvlmUHL1rR6cL4JdAQKx8oGzXBk0oSUgRWH6L2xVBfSSUbAc21
# AB3kxIatYtJdDVJET2az0pPfab54bNA9xtJF2Nqsi0vbp85G1c5rzNaj6IEkwtcD
# gNQd+aY/86H+5J56TIgq+xGUUs2cjNm5mpRUeCuzxKyyMCJgfV1CeEFBC7tTTz00
# PeEKlRTq4tkV2dzlYBD+qUu4xRFiK/7x7H3vAmJvexLiYSHdUoFeYYUBuggxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHktsYXVzdXItUG93ZXJTaGVsbC1Db2RlU2ln
# bmluZwIQYA69k19LnZtMxrPWcz/FNzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUDQ6IP1TLtNIa
# Km5XUNS9jyPPGlkwDQYJKoZIhvcNAQEBBQAEggEAD8MBdqnq42uO/bZNv3CDL0rT
# y62V9GuTBPyWmeJs5QjoSRr3Lzo2Ugb7QxTUqw7ouGQh7oS6uTn5nOHB+pXgd8Gb
# AcG8CuuHFcNdsnbIn6g4BmNMHa1M/d97y9TedkR/p9zwn5XvR8y/pvjC3Wen/PzK
# AEqSGohJOiHrQnmtp0SC+f+Rukh5SIeHzU8P8CkJ0vRHVbfHyAeqdni5reE3Dgcm
# 1q/9BHeKerDvPxoCh2WpPPVBdIU7N+DIQuI3kZRQ/7gPmNl+EBN5WJk4gg///ZsW
# yqKm7rdVnkAX/ydwxTxMmzFhCd3NcCVwRkYEVye2SxG5SIRyHiYp1bsJq4Ac8Q==
# SIG # End signature block
