# =========================
# src\actions\ApplyRetention.ps1
#
# Zweck:
# - Wendet Retention-Regeln aus config.json an
# - Löscht alte Run-Ordner im ZielRoot (Backups) und passende Reports
#
# Regeln (simpel):
# - DailyKeep: Behalte die letzten N Runs
# - WeeklyKeep: Behalte zusätzlich das neueste Backup je Woche für die letzten N Wochen
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $ProjektWurzel "config\lib\Common.ps1")

$cfg = Lade-Konfiguration

$zielRoot = [string]$cfg.Backup.ZielRoot
$dailyKeep = [int]$cfg.Retention.DailyKeep
$weeklyKeep = [int]$cfg.Retention.WeeklyKeep

Clear-Host
Write-Host "=== Retention anwenden ==="
Write-Host ("ZielRoot   : {0}" -f $zielRoot)
Write-Host ("DailyKeep  : {0}" -f $dailyKeep)
Write-Host ("WeeklyKeep : {0}" -f $weeklyKeep)
Write-Host ""

if ([string]::IsNullOrWhiteSpace($zielRoot) -or -not (Test-Path $zielRoot)) {
    Write-Host "ZielRoot existiert nicht oder ist leer konfiguriert." -ForegroundColor Yellow
    Warte-Auf-Enter
    return
}

# Runs als Array laden (robust)
$runs = @(
    Get-ChildItem -Path $zielRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending
)

if ($runs.Count -eq 0) {
    Write-Host "Keine Backups gefunden." -ForegroundColor Yellow
    Warte-Auf-Enter
    return
}

# -------------------------
# 1) DailyKeep: letzte N Runs behalten
# -------------------------
$behalten = New-Object System.Collections.Generic.HashSet[string]

$dailyN = [Math]::Max(0, $dailyKeep)
for ($i=0; $i -lt $runs.Count -and $i -lt $dailyN; $i++) {
    [void]$behalten.Add($runs[$i].Name)
}

# -------------------------
# 2) WeeklyKeep: neuester Run pro Woche für letzte X Wochen behalten
#    Woche wird über Kalenderwoche bestimmt (Year + Week)
# -------------------------
$weeklyN = [Math]::Max(0, $weeklyKeep)
$wochenMap = @{}  # key = "YYYY-WW" => runName

foreach ($r in $runs) {
    # RunName ist "yyyy-MM-dd_HH-mm-ss"
    $dt = $null
    if ([datetime]::TryParseExact($r.Name, "yyyy-MM-dd_HH-mm-ss", $null,
        [System.Globalization.DateTimeStyles]::None, [ref]$dt)) {

        $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
        $week = $cal.GetWeekOfYear($dt, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
        $key = "{0}-{1:00}" -f $dt.Year, $week

        # Da runs bereits Descending sortiert sind, ist der erste je Woche der neueste
        if (-not $wochenMap.ContainsKey($key)) {
            $wochenMap[$key] = $r.Name
        }
    }
}

# letzte X Wochen aus der Map holen (Map ist nicht sortiert -> Keys sortieren)
$keysSortiert = $wochenMap.Keys | Sort-Object -Descending
for ($i=0; $i -lt $keysSortiert.Count -and $i -lt $weeklyN; $i++) {
    $runName = $wochenMap[$keysSortiert[$i]]
    [void]$behalten.Add($runName)
}

# -------------------------
# 3) BackUp-Datei zum Löschen bestimmen
# -------------------------
$zuLoeschen = @()
foreach ($r in $runs) {
    if (-not $behalten.Contains($r.Name)) {
        $zuLoeschen += $r
    }
}

Write-Host ("Behalten: {0} Runs" -f $behalten.Count) -ForegroundColor Green
Write-Host ("Loeschen: {0} Runs" -f $zuLoeschen.Count) -ForegroundColor Yellow
Write-Host ""

if ($zuLoeschen.Count -eq 0) {
    Write-Host "Nichts zu loeschen." -ForegroundColor Green
    Warte-Auf-Enter
    return
}

Write-Host "Folgende Runs wuerden geloescht:"
foreach ($r in $zuLoeschen) { Write-Host ("- {0}" -f $r.Name) }
Write-Host ""
$confirm = (Read-Host "Tippen Sie JA um das Loeschen zu bestaetigen").Trim()

if ($confirm -ne "JA") {
    Write-Host "Abgebrochen." -ForegroundColor Yellow
    Warte-Auf-Enter
    return
}

# -------------------------
# 4) Löschen + Logging
# -------------------------
foreach ($r in $zuLoeschen) {
    $zielPfad   = $r.FullName
    $reportPfad = Join-Path $Ordner_Runs $r.Name

    try {
        Remove-Item -Path $zielPfad -Recurse -Force -ErrorAction Stop
        if (Test-Path $reportPfad) {
            Remove-Item -Path $reportPfad -Recurse -Force -ErrorAction Stop
        }

        Schreibe-Log -Level "INFO" -Nachricht ("Retention: Run geloescht: {0}" -f $r.Name)
        Write-Host ("Geloescht: {0}" -f $r.Name) -ForegroundColor Green
    } catch {
        Schreibe-Log -Level "ERROR" -Nachricht ("Retention: Loeschen fehlgeschlagen ({0}): {1}" -f $r.Name, $_.Exception.Message)
        Write-Host ("Fehler beim Loeschen {0}: {1}" -f $r.Name, $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Retention abgeschlossen." -ForegroundColor Green
Warte-Auf-Enter
return

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcB56FZoQV5QwkwHNGZ/M5rwr
# 35ugggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqeoh4V2nFjkg
# F6ZZhtodBBY4m4AwDQYJKoZIhvcNAQEBBQAEggEAX6E+OQRLySGchlHxtK+B8JtW
# 3UL7EpCMd6376u2hssCqNFDdwqJi0FZhvrRGwWmDsoTEzV7Iw7DA83JE/bwZo0uo
# 74EA5Y5N9iWu3NpS2WPFs+Tjn3PYHia/j9xTD6Pz7mRJpsLnFxn5T0yRKFygd7ND
# OySMbUDSMwctvDencf0v/1mFz07ijrtR2Sj+ZD37UhFO69nROmF/IIBGKEmOIv8Z
# v6ujBdoFvcNm1d8ccrtVKzIyfaDkEPyfCBE3pBe7GL9rPyATz5eZIlHYOm9ot/Dw
# lbIxkPbwGlRuFKRm/cxKVMFYX4x7T52DeRhronVGr1gII+qPD2Fh8AtJrvMWRg==
# SIG # End signature block
