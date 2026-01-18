# =========================
# config\lib\Common.ps1
#
# Zweck:
# - Zentrale "Bibliothek" für das gesamte Projekt
# - Alle Skripte (Main.ps1 und Actions) laden Common.ps1 per Dot-Sourcing
# - Common.ps1 stellt bereit:
#   * Projektpfade (Projektwurzel, Ordner für config/logs/reports)
#   * Ordnerstruktur-Initialisierung
#   * Konsolen-Helper (Eingaben, Pause)
#   * Config Laden/Speichern (config\config.json)
#   * Logging in eine einzige Datei (logs\backup.log)
#
# Hintergrund:
# - Damit Sie Pfad-Logik, Config und Logging nicht in jedem Skript duplizieren müssen.
# - So bleiben Actions klein und fokussiert.
# =========================

Set-StrictMode -Version Latest
# StrictMode: hilft bei typischen Fehlern (z. B. Tippfehler bei Variablen).

$ErrorActionPreference = "Stop"
# Fehler sollen in try/catch laufen und nicht "still" ignoriert werden.
# (Logging selbst fängt Fehler intern ab, damit Logging nicht das Programm stoppt.)

# ------------------------------------------------------------
# 1) Projektwurzel ermitteln
#
# Common.ps1 liegt in:
#   <Projektwurzel>\config\lib\Common.ps1
#
# $PSScriptRoot zeigt hier auf:
#   <Projektwurzel>\config\lib
#
# Projektwurzel ist also 2 Ebenen hoeher:
#   lib -> config -> Projektwurzel
# ------------------------------------------------------------
$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# ------------------------------------------------------------
# 2) Fixe Projektordner (Vorgabe aus Ihrem Screenshot)
# ------------------------------------------------------------
$Ordner_Config  = Join-Path $ProjektWurzel "config"
$Ordner_Logs    = Join-Path $ProjektWurzel "logs"
$Ordner_Reports = Join-Path $ProjektWurzel "reports"

# Unterordner für Backup-Runs (innerhalb reports)
# (Damit bleiben wir in der vorgegebenen Struktur.)
$Ordner_Runs    = Join-Path $Ordner_Reports "runs"

# ------------------------------------------------------------
# 3) Wichtige Dateipfade
# ------------------------------------------------------------
# Konfigurationsdatei (JSON)
$Pfad_ConfigDatei = Join-Path $Ordner_Config "config.json"

# Eine einzige zentrale Logdatei (TXT)
$Pfad_LogDatei    = Join-Path $Ordner_Logs "backup.log"

# ------------------------------------------------------------
# 4) Ordnerstruktur sicherstellen
#
# Diese Funktion wird:
# - beim Programmstart aufgerufen
# - und auch von Config/Logging genutzt, um sicher zu sein,
#   dass config/logs/reports existieren.
# ------------------------------------------------------------
function Initialisiere-Ordnerstruktur {
    foreach ($ordner in @($Ordner_Config, $Ordner_Logs, $Ordner_Reports, $Ordner_Runs)) {
        if (-not (Test-Path $ordner)) {
            New-Item -ItemType Directory -Path $ordner | Out-Null
        }
    }
}

# ------------------------------------------------------------
# 5) Konsolen-Helper: sichere Menü-Eingabe
#
# Lese-Auswahl:
# - zeigt einen Prompt
# - akzeptiert nur Werte aus der Liste $ErlaubteWerte
# - sonst fragt es erneut
# ------------------------------------------------------------
function Lese-Auswahl {
    param(
        [Parameter(Mandatory)] [string]   $Aufforderung,
        [Parameter(Mandatory)] [string[]] $ErlaubteWerte
    )

    while ($true) {
        $eingabe = (Read-Host $Aufforderung).Trim()

        if ($ErlaubteWerte -contains $eingabe) {
            return $eingabe
        }

        Write-Host "Ungueltige Eingabe. Erlaubt: $($ErlaubteWerte -join ', ')" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------
# 6) Konsolen-Helper: Pause
# ------------------------------------------------------------
function Warte-Auf-Enter {
    Write-Host ""
    Read-Host "Enter druecken zum Fortfahren" | Out-Null
}

# ------------------------------------------------------------
# 7) Standard-Konfiguration erzeugen
#
# Wird genutzt, wenn config.json noch nicht existiert.
# Sie können diese Defaults jederzeit erweitern.
# ------------------------------------------------------------
function Erstelle-StandardKonfiguration {
    return [pscustomobject]@{
        Retention = [pscustomobject]@{
            DailyKeep  = 7
            WeeklyKeep = 4
        }
        Backup = [pscustomobject]@{
            # Platzhalter; kann später über Settings gepflegt werden
            Quellen  = @("C:\Data")
            ZielRoot = "D:\Backup"
        }
    }
}

# ------------------------------------------------------------
# 8) Konfiguration laden
#
# Ablauf:
# - stellt Ordnerstruktur sicher
# - wenn config.json fehlt -> Standard erzeugen + speichern
# - sonst JSON lesen + ConvertFrom-Json
# ------------------------------------------------------------
function Lade-Konfiguration {
    Initialisiere-Ordnerstruktur

    if (-not (Test-Path $Pfad_ConfigDatei)) {
        $standard = Erstelle-StandardKonfiguration
        Speichere-Konfiguration -Konfiguration $standard
        return $standard
    }

    try {
        $json = Get-Content -Path $Pfad_ConfigDatei -Raw -Encoding UTF8
        return ($json | ConvertFrom-Json)
    } catch {
        # Fehler bewusst "werfen", damit die Action/Main entscheiden kann
        throw "Konfiguration konnte nicht geladen werden (config.json fehlerhaft): $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# 9) Konfiguration speichern
#
# ConvertTo-Json -Depth 6:
# - Depth ist wichtig, damit verschachtelte Strukturen korrekt exportiert werden.
# ------------------------------------------------------------
function Speichere-Konfiguration {
    param([Parameter(Mandatory)] $Konfiguration)

    Initialisiere-Ordnerstruktur

    $Konfiguration |
        ConvertTo-Json -Depth 6 |
        Set-Content -Path $Pfad_ConfigDatei -Encoding UTF8
}

# ------------------------------------------------------------
# 10) Logging (eine Datei)
#
# Schreibe-Log:
# - sorgt dafür, dass logs\backup.log existiert
# - schreibt eine Zeile mit Zeitstempel + Level + Nachricht
#
# Wichtig:
# - Logging darf das Programm NICHT abbrechen
#   (darum try/catch im Logger selbst)
# ------------------------------------------------------------
function Schreibe-Log {
    param(
        [Parameter(Mandatory)] [string] $Nachricht,
        [ValidateSet("INFO","WARN","ERROR")] [string] $Level = "INFO"
    )

    try {
        Initialisiere-Ordnerstruktur

        # Logfile bei Bedarf anlegen
        if (-not (Test-Path $Pfad_LogDatei)) {
            Set-Content -Path $Pfad_LogDatei -Value ("== BackupTool Log gestartet: {0} ==" -f (Get-Date)) -Encoding UTF8
        }

        # Zeitstempel (lesbar, sortierbar)
        $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        # Zeile anhängen
        Add-Content -Path $Pfad_LogDatei -Value ("[{0}][{1}] {2}" -f $ts, $Level, $Nachricht) -Encoding UTF8
    } catch {
        # bewusst ignorieren: Logging soll nie "fatal" sein
    }
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUK3KU6HkE7iB+v1/TeXGVj0CI
# ku6gggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUeCCC/tULEyA5
# J+QpKocusivMhMkwDQYJKoZIhvcNAQEBBQAEggEAHj5YLviCdgb1eiRB+jDsGdh6
# i/xnyBaodTnjjmbn/LIxe9C9mJ+SccL4i0Cmby1RDLeSx6QBMlWjOjESklXBHuig
# DCirPLinV9za7dJcKBy8MNR/49eSd/76OC4YEV4bpaN9zzth6TmQol4NBZt08Tv8
# 5guOxHaOwOIyK53ED7UOEYv11pTHkZeU0HVBMt8SSHcbQkdM9aMVJZt04DQdgORR
# pssVKDcpMzq0jGgbyZ2jISbtIc0aoWSaA8yS0qGXKuk/mDvZ2iFP4NETAm7a8EMf
# +qlMcJ139x3YqR+NKS9gbL/0wzMOYUAqDZ9Qxj3LCHVLAgpYbh8Ty42hLv7gXw==
# SIG # End signature block
