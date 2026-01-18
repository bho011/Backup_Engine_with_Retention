# =========================
# src\actions\BackupStart.ps1 (SIMPLE + ROBUST)
# - PS 5.1 kompatibel
# - Keine Grössenmessung / kein Progress (stabil)
# - Versionierung über RunId-Ordner im ZielRoot
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Common.ps1 laden
$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$CommonPfad    = Join-Path $ProjektWurzel "config\lib\Common.ps1"

if (-not (Test-Path $CommonPfad)) {
    Write-Host "FEHLER: Common.ps1 nicht gefunden unter: $CommonPfad" -ForegroundColor Red
    Read-Host "Enter druecken zum Beenden" | Out-Null
    exit 99
}
. $CommonPfad

# Konfiguration laden
$cfg = Lade-Konfiguration

# Quellen: IMMER Array (auch wenn nur 1 Eintrag in JSON steht)
$quellen = @()
if ($cfg.Backup -and $cfg.Backup.Quellen) { $quellen = @($cfg.Backup.Quellen) }

# ZielRoot
$zielRoot = $null
if ($cfg.Backup -and $cfg.Backup.ZielRoot) { $zielRoot = [string]$cfg.Backup.ZielRoot }

# Validierung
if ($quellen.Count -eq 0) {
    Schreibe-Log -Level "ERROR" -Nachricht "BackupStart: Keine Quellen definiert (Backup.Quellen)."
    Write-Host "Keine Quellen definiert. Bitte in Einstellungen -> Backup-Quellen konfigurieren." -ForegroundColor Red
    Warte-Auf-Enter
    return
}

if ([string]::IsNullOrWhiteSpace($zielRoot)) {
    Schreibe-Log -Level "ERROR" -Nachricht "BackupStart: Kein ZielRoot definiert (Backup.ZielRoot)."
    Write-Host "Kein ZielRoot definiert. Bitte in Einstellungen -> Backup-Ziel konfigurieren." -ForegroundColor Red
    Warte-Auf-Enter
    return
}

# Zielmedium pruefen (z. B. "D:\")
$zielQualifier = Split-Path -Path $zielRoot -Qualifier
if (-not [string]::IsNullOrWhiteSpace($zielQualifier) -and -not (Test-Path $zielQualifier)) {
    Schreibe-Log -Level "ERROR" -Nachricht ("BackupStart: Zieldatentraeger nicht gefunden: {0}" -f $zielQualifier)
    Write-Host "Zieldatentraeger nicht gefunden: $zielQualifier" -ForegroundColor Red
    Warte-Auf-Enter
    return
}

# ZielRoot anlegen, falls nötig
if (-not (Test-Path $zielRoot)) {
    New-Item -ItemType Directory -Path $zielRoot | Out-Null
}

# Run-Ordner anlegen
Initialisiere-Ordnerstruktur

$runId       = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$zielRun     = Join-Path $zielRoot $runId
$reportRun   = Join-Path $Ordner_Runs $runId
$roboLogPfad = Join-Path $reportRun "robocopy.log"

New-Item -ItemType Directory -Path $zielRun   -Force | Out-Null
New-Item -ItemType Directory -Path $reportRun -Force | Out-Null

Schreibe-Log -Level "INFO" -Nachricht ("BackupStart: RunId={0}, ZielRun={1}" -f $runId, $zielRun)

# Robocopy pro Quelle
$exitCodes = @()
$idx = 0

foreach ($quelle in $quellen) {
    $idx++

    if (-not (Test-Path $quelle)) {
        Schreibe-Log -Level "ERROR" -Nachricht ("BackupStart: Quelle nicht gefunden: {0}" -f $quelle)
        Write-Host "Quelle nicht gefunden: $quelle" -ForegroundColor Red
        Warte-Auf-Enter
        return
    }

    # Ziel-Unterordner je Quelle
    $leaf = Split-Path -Path $quelle -Leaf
    if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "Quelle$idx" }

    $zielTeil = Join-Path $zielRun $leaf
    New-Item -ItemType Directory -Path $zielTeil -Force | Out-Null

    Write-Host ("Robocopy: {0} -> {1}" -f $quelle, $zielTeil)

    Schreibe-Log -Level "INFO" -Nachricht ("Robocopy Start: {0} -> {1}" -f $quelle, $zielTeil)

    # Argumentliste (sauber, ohne String-Join)
    $argumente = @(
        $quelle,
        $zielTeil,
        "/E",
        "/R:2",
        "/W:2",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/NP",
        "/LOG+:$roboLogPfad"
    )

    # Robocopy starten und warten
    $p = Start-Process -FilePath "robocopy.exe" -ArgumentList $argumente -NoNewWindow -Wait -PassThru
    $exitCodes += $p.ExitCode

    Schreibe-Log -Level "INFO" -Nachricht ("Robocopy Ende: ExitCode={0}" -f $p.ExitCode)
}

Write-Host ""
Write-Host "Backup fertig." -ForegroundColor Green
Write-Host ("RunId: {0}" -f $runId)
Write-Host ("Ziel:  {0}" -f $zielRun)
Write-Host ("Log:   {0}" -f $roboLogPfad)
Write-Host ("ExitCodes: {0}" -f ($exitCodes -join ", "))

Schreibe-Log -Level "INFO" -Nachricht ("BackupEnde: RunId={0}, ExitCodes={1}" -f $runId, ($exitCodes -join ","))

Warte-Auf-Enter
return

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUijx9xZlAXhKHgcVBH0sfdhxa
# lFigggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU4IOkXhHGcG8/
# Ok0Gcbl8XOUAp8owDQYJKoZIhvcNAQEBBQAEggEAXmkFC5uRVhqgFQfa+5JP+ifG
# 9OurJ9dsUTsE1bnpafrIW2c3P1aTbvg5C4E0y8Kk0tJu3RpxsuLd0pNKQAcN4/Vz
# skGPEtv3yOcmFhnH35dpDIJzlaKnTlDMMpXC5xEoaXIp9Gr0ap5oMa+Khup7NWlp
# nZQrQmwFEIFbB4DXCaVzA3i8XbzBgyoiKlylHedViDraZWrswHjCnhrgkJJZIy/d
# ObHnSSLa18jLlon3jCI/e93GsRXJUBToWh/kVsapszvD5srH0teEdbFnS1id3Ao8
# KX42i054WraUIbnct4Q3A+UgQKXn1fzRJI2+cXHsFy+U3Noj0kkgvtd7G6dU7g==
# SIG # End signature block
