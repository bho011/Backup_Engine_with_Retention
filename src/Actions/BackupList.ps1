# =========================
# src\actions\BackupList.ps1
#
# Zweck:
# - Listet Run-Ordner im ZielRoot auf (robust mit @(...))
# - Liefert zusaetzlich eine Objektliste zur Weiterverarbeitung
# - Optional: Export als CSV in reports\backup-list-latest.csv
#
# Hinweis:
# - Das Script bleibt weiterhin interaktiv (Console), gibt aber am Ende auch Objekte zurueck.
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $ProjektWurzel "config\lib\Common.ps1")

$cfg = Lade-Konfiguration
$zielRoot = [string]$cfg.Backup.ZielRoot

Clear-Host
Write-Host "=== Backups ansehen ==="
Write-Host ("ZielRoot: {0}" -f $zielRoot)
Write-Host ""

if ([string]::IsNullOrWhiteSpace($zielRoot) -or -not (Test-Path $zielRoot)) {
    Write-Host "ZielRoot existiert nicht oder ist leer konfiguriert." -ForegroundColor Yellow
    Warte-Auf-Enter
    return
}

$ordner = @(
    Get-ChildItem -Path $zielRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending
)

if ($ordner.Count -eq 0) {
    Write-Host "Keine Backups gefunden." -ForegroundColor Yellow
    Warte-Auf-Enter
    return
}

# Objektliste aufbauen (klausurfreundlich: Daten sind auswertbar)
$liste = @()
for ($i = 0; $i -lt $ordner.Count; $i++) {
    $liste += [pscustomobject]@{
        Index        = $i
        RunId        = $ordner[$i].Name
        CreationTime = $ordner[$i].CreationTime
        Path         = $ordner[$i].FullName
    }
}

# Weiterhin Console-Ausgabe
foreach ($item in $liste) {
    Write-Host ("[{0}] {1}   ({2})" -f $item.Index, $item.RunId, $item.CreationTime)
}

Write-Host ""
$export = Lese-Auswahl -Aufforderung "CSV-Export in reports erstellen? (J/N)" -ErlaubteWerte @("J","j","N","n")
if ($export.ToUpper() -eq "J") {
    try {
        Initialisiere-Ordnerstruktur
        $csvPfad = Join-Path $Ordner_Reports "backup-list-latest.csv"
        $liste | Export-Csv -Path $csvPfad -NoTypeInformation -Encoding UTF8 -Delimiter ';'
        Write-Host ("CSV gespeichert: {0}" -f $csvPfad) -ForegroundColor Green
        Schreibe-Log -Level "INFO" -Nachricht ("BackupList: CSV-Export erstellt: {0}" -f $csvPfad)
    } catch {
        Schreibe-Log -Level "ERROR" -Nachricht ("BackupList: CSV-Export fehlgeschlagen: {0}" -f $_.Exception.Message)
        Write-Host ("CSV-Export fehlgeschlagen: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

Warte-Auf-Enter
return $liste

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbepsXt959VR2KTMpIijahFKE
# 5xegggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUBRoP8VwI2suq
# PPIkCrpEUfQk75kwDQYJKoZIhvcNAQEBBQAEggEAGyfzgThEDdhOxQ43zuiEyT2l
# IxG9iXko3Ch4zq2NmmA6iujOmjwPrAXrvT4TD5O8A8Fh6RgUTTb9Xi/iRN2n1Iut
# fRebThATaCcV7pjbzNOw3Hfyu9EZ6hfxWs1qCUBay6UPktcz2CiTW+ITWGj6Sb12
# oZVwJpj5qvpoPcclwT6zBMWnWs+C/HnddVFChm89/p9ZDYJyOBTRr7/gMjbHHUjJ
# npURlgat13dbFT0JWobV+Wvs0PJAVAYfaM8UR8Dtm8CefqMVzIaIxoNFfXuE/GNl
# rExDix0n9PcCLRKG+TrqWVW//KAm0ZfHyOYFwJByVKCAwk/HRyQhmDhlxpa+PA==
# SIG # End signature block
