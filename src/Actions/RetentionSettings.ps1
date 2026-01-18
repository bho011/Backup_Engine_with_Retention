# =========================
# src\actions\RetentionSettings.ps1
#
# Zweck:
# - Anzeige und Änderung der Retention-Einstellungen in config\config.json
# - Logging aller relevanten Aktionen:
#   * Öffnen/Verlassen des Menüs
#   * Änderungen an DailyKeep / WeeklyKeep
#   * Fehleingaben und ungültige Werte
#
# Voraussetzungen:
# - Common.ps1 liegt in: <Projektwurzel>\config\lib\Common.ps1
# - Common.ps1 stellt bereit:
#   * Initialisiere-Ordnerstruktur
#   * Lade-Konfiguration / Speichere-Konfiguration
#   * Lese-Auswahl / Warte-Auf-Enter
#   * Schreibe-Log
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1) Projektwurzel ermitteln und Common.ps1 laden
#
# Dieses Action-Skript liegt in:
#   <Projektwurzel>\src\actions\RetentionSettings.ps1
#
# $PSScriptRoot zeigt also auf:
#   <Projektwurzel>\src\actions
#
# Projektwurzel ist damit 2 Ebenen höher:
#   actions -> src -> Projektwurzel
# ------------------------------------------------------------
$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$CommonPfad    = Join-Path $ProjektWurzel "config\lib\Common.ps1"

# Wenn Common.ps1 nicht gefunden wird, kann das Skript nicht funktionieren.
if (-not (Test-Path $CommonPfad)) {
    Write-Host "FEHLER: Common.ps1 nicht gefunden unter: $CommonPfad" -ForegroundColor Red
    Read-Host "Enter druecken zum Beenden" | Out-Null
    exit 99
}

# Dot-Sourcing:
# - Führt Common.ps1 aus
# - Macht alle Funktionen/Variablen daraus in diesem Skript verfügbar
. $CommonPfad

# ------------------------------------------------------------
# 2) Konfiguration laden
#
# Lade-Konfiguration:
# - legt Ordnerstruktur an, falls nötig
# - erstellt bei Bedarf eine Standard-config.json
# ------------------------------------------------------------
$konfiguration = Lade-Konfiguration

# ------------------------------------------------------------
# 3) Sicherheitsnetz: Retention-Block anlegen, falls er fehlt
#
# Falls config.json manuell verändert wurde oder unvollstaendig ist,
# kann "Retention" fehlen.
# Dann legen wir ihn mit Standardwerten an.
# ------------------------------------------------------------
if (-not $konfiguration.Retention) {

    # Loggen: Wir mussten reparieren / nachziehen
    Schreibe-Log -Level "WARN" -Nachricht "Retention-Block fehlte in config.json und wurde neu angelegt (Default 7/4)."

    # Retention-Objekt anhängen
    $konfiguration | Add-Member -MemberType NoteProperty -Name "Retention" -Value ([pscustomobject]@{
        DailyKeep  = 7
        WeeklyKeep = 4
    })

    # Direkt speichern, damit config.json wieder vollständig ist
    Speichere-Konfiguration -Konfiguration $konfiguration
}

# Loggen, dass das Menü geöffnet wurde (inkl. aktuelle Werte)
Schreibe-Log -Level "INFO" -Nachricht ("RetentionSettings geoeffnet (DailyKeep={0}, WeeklyKeep={1})." -f `
    $konfiguration.Retention.DailyKeep, $konfiguration.Retention.WeeklyKeep)

# ------------------------------------------------------------
# 4) Menü-Schleife
#
# while($true) sorgt dafür, dass das Menü jeder Aktion
# erneut angezeigt wird, bis der Benutzer "B" (Zurück) wählt.
# ------------------------------------------------------------
while ($true) {
    Clear-Host

    # Anzeige der aktuellen Werte aus der Konfiguration
    Write-Host "=== Retention Settings ==="
    Write-Host ("DailyKeep  : {0}" -f $konfiguration.Retention.DailyKeep)
    Write-Host ("WeeklyKeep : {0}" -f $konfiguration.Retention.WeeklyKeep)
    Write-Host ""

    # Menüoptionen
    Write-Host "1) DailyKeep aendern"
    Write-Host "2) WeeklyKeep aendern"
    Write-Host "3) Zuruecksetzen auf Standard (7/4)"
    Write-Host "B) Zurueck"

    # Lese-Auswahl akzeptiert nur die erlaubten Eingaben
    $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","2","3","B","b")

    # switch entscheidet anhand der Auswahl, was passieren soll
    switch ($auswahl.ToUpper()) {

        # ----------------------------------------------------
        # Option 1: DailyKeep ändern
        # ----------------------------------------------------
        "1" {
            # alten Wert merken (für Logging: alt -> neu)
            $alt = [int]$konfiguration.Retention.DailyKeep

            # neuen Wert abfragen (Text)
            $eingabe = (Read-Host "Neuer DailyKeep (0..365)").Trim()

            # Validierung 1: Eingabe muss nur aus Ziffern bestehen
            if ($eingabe -notmatch '^\d+$') {
                Schreibe-Log -Level "WARN" -Nachricht ("DailyKeep ungueltige Eingabe (keine Zahl): '{0}'" -f $eingabe)
                Write-Host "Bitte eine ganze Zahl eingeben." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue  # zurück zum Menü-Anfang
            }

            # Umwandlung in Integer
            $wert = [int]$eingabe

            # Validierung 2: Bereich prüfen
            if ($wert -lt 0 -or $wert -gt 365) {
                Schreibe-Log -Level "WARN" -Nachricht ("DailyKeep ungueltiger Bereich: {0} (erlaubt 0..365)" -f $wert)
                Write-Host "Ungueltiger Bereich. Erlaubt: 0..365" -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            # Wert übernehmen + speichern
            $konfiguration.Retention.DailyKeep = $wert
            Speichere-Konfiguration -Konfiguration $konfiguration

            # Logging: Änderung dokumentieren
            Schreibe-Log -Level "INFO" -Nachricht ("DailyKeep geaendert: {0} -> {1}" -f $alt, $wert)

            Write-Host "DailyKeep gespeichert." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # ----------------------------------------------------
        # Option 2: WeeklyKeep ändern
        # ----------------------------------------------------
        "2" {
            $alt = [int]$konfiguration.Retention.WeeklyKeep
            $eingabe = (Read-Host "Neuer WeeklyKeep (0..104)").Trim()

            if ($eingabe -notmatch '^\d+$') {
                Schreibe-Log -Level "WARN" -Nachricht ("WeeklyKeep ungueltige Eingabe (keine Zahl): '{0}'" -f $eingabe)
                Write-Host "Bitte eine ganze Zahl eingeben." -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            $wert = [int]$eingabe
            if ($wert -lt 0 -or $wert -gt 104) {
                Schreibe-Log -Level "WARN" -Nachricht ("WeeklyKeep ungueltiger Bereich: {0} (erlaubt 0..104)" -f $wert)
                Write-Host "Ungueltiger Bereich. Erlaubt: 0..104" -ForegroundColor Yellow
                Warte-Auf-Enter
                continue
            }

            $konfiguration.Retention.WeeklyKeep = $wert
            Speichere-Konfiguration -Konfiguration $konfiguration

            Schreibe-Log -Level "INFO" -Nachricht ("WeeklyKeep geaendert: {0} -> {1}" -f $alt, $wert)

            Write-Host "WeeklyKeep gespeichert." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # ----------------------------------------------------
        # Option 3: Retention auf Standardwerte zurücksetzen
        # ----------------------------------------------------
        "3" {
            # alte Werte merken
            $altD = [int]$konfiguration.Retention.DailyKeep
            $altW = [int]$konfiguration.Retention.WeeklyKeep

            # Standardwerte setzen
            $konfiguration.Retention.DailyKeep  = 7
            $konfiguration.Retention.WeeklyKeep = 4

            # speichern
            Speichere-Konfiguration -Konfiguration $konfiguration

            # loggen
            Schreibe-Log -Level "INFO" -Nachricht ("Retention reset: DailyKeep {0}->7, WeeklyKeep {1}->4" -f $altD, $altW)

            Write-Host "Retention auf Standard zurueckgesetzt (DailyKeep=7, WeeklyKeep=4)." -ForegroundColor Green
            Warte-Auf-Enter
        }

        # ----------------------------------------------------
        # B: Zurück ins Hauptmenü
        #
        # WICHTIG:
        # - return beendet dieses Action-Skript komplett
        # - Main.ps1 kann danach sauber weiterlaufen und das Men anzeigen
        # ----------------------------------------------------
        "B" {
            Schreibe-Log -Level "INFO" -Nachricht "RetentionSettings verlassen (Zurueck ins Hauptmenue)."
            return
        }
    }
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU3qJvPnM0pG2vMULKKoVrrdUy
# jl+gggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUaB5hHl1d1A6x
# oDXpG7RIp1KHiHwwDQYJKoZIhvcNAQEBBQAEggEACxU5k5nXDn7mukMQEnsK8Hni
# pwwuc93CMa0oPJmSAHjJjmY1tFlV1lYwMJnfUTmMgZQyYbeUjeRVI8Orpch1vtXt
# OmHwyQBUns65qIIPVhnNa+6IFO50dj3tP1QNyYhOUSsGC9nOB2jq0UsHeVhUqgq4
# T+3FDm/3j8plFVfda/lsMxd97MShx+WlFbDNDQsVRp23B4XPKr2alBpqKVVohNLW
# 5fDERJHoXvn+/g1KISmQeimAk1K9jTQCi60wwySphul9rXe6DeJk71HEwPVS7eoF
# MwQh5A3mRFKPfLsQy25VxmQp6EKTBCRFRyVMtHXb583nP+dmqnftCLj1RITMQA==
# SIG # End signature block
