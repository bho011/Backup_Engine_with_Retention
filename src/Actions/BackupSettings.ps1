# =========================
# src\actions\BackupSettings.ps1
#
# Zweck:
# - Konfiguration der Backup-Quellen und des Zielpfades über ein Menü
# - Speichert alles in config\config.json unter: Backup.Quellen / Backup.ZielRoot
# - Loggt änderungen und Fehleingaben in logs\backup.log
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Common.ps1 laden (2 Ebenen hoch: actions -> src -> Projektwurzel) ---
$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$CommonPfad    = Join-Path $ProjektWurzel "config\lib\Common.ps1"

if (-not (Test-Path $CommonPfad)) {
    Write-Host "FEHLER: Common.ps1 nicht gefunden unter: $CommonPfad" -ForegroundColor Red
    Read-Host "Enter druecken zum Beenden" | Out-Null
    exit 99
}

. $CommonPfad

# ------------------------------------------------------------
# Konfiguration laden + sicherstellen, dass Backup-Block existiert
# ------------------------------------------------------------
$konfiguration = Lade-Konfiguration

if (-not $konfiguration.Backup) {
    Schreibe-Log -Level "WARN" -Nachricht "Backup-Block fehlte in config.json und wurde neu angelegt."
    $konfiguration | Add-Member -MemberType NoteProperty -Name "Backup" -Value ([pscustomobject]@{
        Quellen  = @()
        ZielRoot = ""
    })
    Speichere-Konfiguration -Konfiguration $konfiguration
}

# Quellen immer als Array behandeln
$quellen = @()
if ($konfiguration.Backup.Quellen) { $quellen = @($konfiguration.Backup.Quellen) }

# ------------------------------------------------------------
# Hilfsfunktion: Konfiguration speichern und lokalen Quellen-Cache aktualisieren
# ------------------------------------------------------------
function Speichere-BackupKonfiguration {
    param(
        [Parameter(Mandatory)][string[]]$NeueQuellen,
        [Parameter(Mandatory)][string]  $NeuesZielRoot
    )

    # in Config schreiben
    $konfiguration.Backup.Quellen  = $NeueQuellen
    $konfiguration.Backup.ZielRoot = $NeuesZielRoot

    Speichere-Konfiguration -Konfiguration $konfiguration

    # lokalen Cache aktualisieren
    $script:quellen = @($NeueQuellen)
}

# ------------------------------------------------------------
# Hilfsfunktion: Quellenliste anzeigen
# ------------------------------------------------------------
function Zeige-QuellenListe {
    if ($quellen.Count -eq 0) {
        Write-Host "Quellen: (keine)" -ForegroundColor Yellow
        return
    }

    Write-Host "Quellen:"
    for ($i = 0; $i -lt $quellen.Count; $i++) {
        $pfad = $quellen[$i]
        $exists = Test-Path $pfad
        $marker = if ($exists) { "OK" } else { "FEHLT" }
        $farbe  = if ($exists) { "Green" } else { "Red" }
        Write-Host ("[{0}] {1}  ({2})" -f $i, $pfad, $marker) -ForegroundColor $farbe
    }
}

# ------------------------------------------------------------
# Hilfsfunktion: Index abfragen (für Entfernen)
# ------------------------------------------------------------
function Lese-IndexOderB {
    param([Parameter(Mandatory)][int]$MaxIndex)

    while ($true) {
        $eingabe = (Read-Host ("Index eingeben (0..{0}) oder B fuer Zurueck" -f $MaxIndex)).Trim()
        if ($eingabe -match '^[Bb]$') { return $null }

        if ($eingabe -match '^\d+$') {
            $idx = [int]$eingabe
            if ($idx -ge 0 -and $idx -le $MaxIndex) { return $idx }
        }

        Write-Host "Ungueltige Eingabe." -ForegroundColor Yellow
    }
}

Schreibe-Log -Level "INFO" -Nachricht "BackupSettings geoeffnet."

# ------------------------------------------------------------
# Menü-Schleife
# ------------------------------------------------------------
while ($true) {
    Clear-Host
    Write-Host "=== Backup Settings ==="
    Write-Host ("ZielRoot: {0}" -f $konfiguration.Backup.ZielRoot)
    Write-Host ""
    Zeige-QuellenListe
    Write-Host ""

    Write-Host "1) Quelle hinzufuegen"
    Write-Host "2) Quelle entfernen"
    Write-Host "3) ZielRoot setzen"
    Write-Host "4) Quick-Check (zeigt, ob Pfade existieren)"
    Write-Host "B) Zurueck"

    $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","2","3","4","B","b")

    switch ($auswahl.ToUpper()) {

        # -------------------------
        # 1) Quelle hinzufügen
        # -------------------------
        "1" {
            $neuerPfad = (Read-Host "Pfad zur Quelle (z.B. C:\Data)").Trim()

            if ([string]::IsNullOrWhiteSpace($neuerPfad)) {
                Schreibe-Log -Level "WARN" -Nachricht "BackupSettings: Quelle hinzufuegen abgebrochen (leer)."
                Write-Host "Leerer Pfad. Abbruch." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            # Duplikate verhindern
            if ($quellen -contains $neuerPfad) {
                Schreibe-Log -Level "WARN" -Nachricht ("BackupSettings: Quelle bereits vorhanden: {0}" -f $neuerPfad)
                Write-Host "Quelle ist bereits in der Liste." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            # Hinweis: wir erlauben das Speichern auch wenn Pfad fehlt,
            # aber markieren es später als FEHLT. (Sie können hier auch hart blocken.)
            $exists = Test-Path $neuerPfad
            if (-not $exists) {
                Schreibe-Log -Level "WARN" -Nachricht ("BackupSettings: Quelle existiert nicht (trotzdem gespeichert): {0}" -f $neuerPfad)
                Write-Host "Hinweis: Pfad existiert aktuell nicht (wird trotzdem gespeichert)." -ForegroundColor Yellow
            } else {
                Schreibe-Log -Level "INFO" -Nachricht ("BackupSettings: Quelle hinzugefuegt: {0}" -f $neuerPfad)
            }

            $neu = @($quellen + $neuerPfad)
            Speichere-BackupKonfiguration -NeueQuellen $neu -NeuesZielRoot ([string]$konfiguration.Backup.ZielRoot)

            Write-Host "Quelle gespeichert." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # -------------------------
        # 2) Quelle entfernen
        # -------------------------
        "2" {
            if ($quellen.Count -eq 0) {
                Write-Host "Keine Quellen zum Entfernen vorhanden." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            $idx = Lese-IndexOderB -MaxIndex ($quellen.Count - 1)
            if ($null -eq $idx) { continue }

            $entfernt = $quellen[$idx]
            $neu = @()
            for ($i=0; $i -lt $quellen.Count; $i++) {
                if ($i -ne $idx) { $neu += $quellen[$i] }
            }

            Speichere-BackupKonfiguration -NeueQuellen $neu -NeuesZielRoot ([string]$konfiguration.Backup.ZielRoot)

            Schreibe-Log -Level "INFO" -Nachricht ("BackupSettings: Quelle entfernt: {0}" -f $entfernt)
            Write-Host "Quelle entfernt." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # -------------------------
        # 3) ZielRoot setzen
        # -------------------------
        "3" {
            $alt = [string]$konfiguration.Backup.ZielRoot
            $neuZiel = (Read-Host "Neuer ZielRoot (z.B. D:\Backup)").Trim()

            if ([string]::IsNullOrWhiteSpace($neuZiel)) {
                Schreibe-Log -Level "WARN" -Nachricht "BackupSettings: ZielRoot setzen abgebrochen (leer)."
                Write-Host "Leerer Pfad. Abbruch." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            # Wir speichern das Ziel. Existenz prüefen wir später in BackupStart (Datentrger vorhanden usw.)
            Speichere-BackupKonfiguration -NeueQuellen $quellen -NeuesZielRoot $neuZiel

            Schreibe-Log -Level "INFO" -Nachricht ("BackupSettings: ZielRoot geaendert: {0} -> {1}" -f $alt, $neuZiel)
            Write-Host "ZielRoot gespeichert." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # -------------------------
        # 4) Quick-Check
        # -------------------------
        "4" {
            Clear-Host
            Write-Host "=== Quick-Check ==="
            Write-Host ("ZielRoot: {0}" -f $konfiguration.Backup.ZielRoot)
            Write-Host ""

            if ($quellen.Count -eq 0) {
                Write-Host "Keine Quellen definiert." -ForegroundColor Yellow
            } else {
                for ($i=0; $i -lt $quellen.Count; $i++) {
                    $pfad = $quellen[$i]
                    if (Test-Path $pfad) {
                        Write-Host ("[{0}] OK    {1}" -f $i, $pfad) -ForegroundColor Green
                    } else {
                        Write-Host ("[{0}] FEHLT {1}" -f $i, $pfad) -ForegroundColor Red
                    }
                }
            }

            Write-Host ""
            Warte-Auf-Enter
        }

        # -------------------------
        # B) Zurück
        # -------------------------
        "B" {
            Schreibe-Log -Level "INFO" -Nachricht "BackupSettings verlassen (Zurueck ins Hauptmenue)."
            return
        }
    }
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUArTkHFmWe9dyeGdkB7O2A5dZ
# n4ugggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUtirBhK3n5L5u
# 8R9vb7ckrgxpd8YwDQYJKoZIhvcNAQEBBQAEggEAalJGV8QEBAzuyweYlUQ9zGkT
# SRcxqJ+Q0uP08qbUyvhBZZRAi74HFtW5zImWjiEFdPZskPStDM5B3XxhLkiM6sLs
# dJYeFiivnOe1djvNYWJjIKmK/8LSi98jD0B3c20kgcuW5ZM5WiF7W38fPpKCvYw0
# udnGnUnuwTvwsVS/6Trej4JKRhy38C9z9VCAP0evD9cfBT32QENyJ7SEyGHFFqkv
# 3gbt8zgmSYgmSUrDFbTMzpD803brLtj0yY6pZeaqnA60GLjmHBcp7g+Iwod2S4wJ
# mFz4f+2ee3oj/FisJa/0vHPWmQBrpyfkDK4QHw5hmiSWvvzwHxK7tqDWe1/ICQ==
# SIG # End signature block
