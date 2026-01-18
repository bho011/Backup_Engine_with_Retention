﻿# =========================
# src\actions\BackupManage.ps1
# - Listet Backups (Run-Ordner) und löscht ausgewählten Run
# - Löscht zusätzlich den passenden Report-Ordner: reports\runs\<RunId>
# - Robust: Get-ChildItem wird zu @(...), damit .Count sicher ist
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $ProjektWurzel "config\lib\Common.ps1")

function Lese-IndexOderB {
    param([Parameter(Mandatory)][int]$MaxIndex)

    while ($true) {
        $eingabe = (Read-Host ("Index (0..{0}) oder B fuer Zurueck" -f $MaxIndex)).Trim()
        if ($eingabe -match '^[Bb]$') { return $null }

        if ($eingabe -match '^\d+$') {
            $idx = [int]$eingabe
            if ($idx -ge 0 -and $idx -le $MaxIndex) { return $idx }
        }

        Write-Host "Ungueltige Eingabe." -ForegroundColor Yellow
    }
}

$cfg = Lade-Konfiguration
$zielRoot = [string]$cfg.Backup.ZielRoot

while ($true) {
    Clear-Host
    Write-Host "=== Backups loeschen / verwalten ==="
    Write-Host ("ZielRoot: {0}" -f $zielRoot)
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($zielRoot) -or -not (Test-Path $zielRoot)) {
        Write-Host "ZielRoot existiert nicht oder ist leer konfiguriert." -ForegroundColor Yellow
        Warte-Auf-Enter
        return
    }

    # Wichtig: @(...) macht immer ein Array (auch bei 0 oder 1 Treffer)
    $ordner = @(
        Get-ChildItem -Path $zielRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    )

    if ($ordner.Count -eq 0) {
        Write-Host "Keine Backups gefunden." -ForegroundColor Yellow
        Warte-Auf-Enter
        return
    }

    for ($i = 0; $i -lt $ordner.Count; $i++) {
        Write-Host ("[{0}] {1}" -f $i, $ordner[$i].Name)
    }

    Write-Host ""
    Write-Host "1) Backup loeschen (per Index)"
    Write-Host "B) Zurueck"

    $auswahl = Lese-Auswahl -Aufforderung "Auswahl" -ErlaubteWerte @("1","B","b")

    if ($auswahl.ToUpper() -eq "B") { return }

    $idx = Lese-IndexOderB -MaxIndex ($ordner.Count - 1)
    if ($null -eq $idx) { continue }

    $runName    = $ordner[$idx].Name
    $zielPfad   = $ordner[$idx].FullName
    $reportPfad = Join-Path $Ordner_Runs $runName

    Write-Host ""
    Write-Host ("Wirklich loeschen? {0}" -f $runName) -ForegroundColor Yellow
    $confirm = (Read-Host "Tippen Sie JA zum Bestaetigen").Trim()

    if ($confirm -ne "JA") {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 400
        continue
    }

    try {
        Remove-Item -Path $zielPfad -Recurse -Force -ErrorAction Stop

        if (Test-Path $reportPfad) {
            Remove-Item -Path $reportPfad -Recurse -Force -ErrorAction Stop
        }

        Write-Host "Backup geloescht." -ForegroundColor Green
        Schreibe-Log -Level "INFO" -Nachricht ("Backup geloescht: {0}" -f $runName)
    } catch {
        Schreibe-Log -Level "ERROR" -Nachricht ("Loeschen fehlgeschlagen ({0}): {1}" -f $runName, $_.Exception.Message)
        Write-Host ("Loeschen fehlgeschlagen: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host "Hinweis: Wenn Dateien noch gesperrt sind (Explorer/Robocopy), zuerst schliessen und erneut versuchen." -ForegroundColor Yellow
    }

    Warte-Auf-Enter
}

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMgWY93dfFQ72xoRrLzvwHtZ8
# ZSSgggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUxAQYMj5dMRYI
# H170alcisaFBmJEwDQYJKoZIhvcNAQEBBQAEggEAXYdDETlE+U6bTPpFOQujE6N1
# 83B9ZYxjDwVCqPXJr7firLpmXJBREmkof+AziJrIuhjdwkfqms6TmCs5a51PbNhy
# pblqqQgKBqbBjpojRkGZKJpbe0PvZiSGPVZRDdOSZjKIU15llrk/YaqQJ8qI/sBV
# yJsZyv6EReUaQs94Eo5hVDO5l7isclsObJotyv9oORdtj5zLUlULdifq7fX09Imi
# MqFbie44iLu6+z1HsiPlINqW+tqgyDeL2ba9c7BddbA/SM6DGQXl7s0tF6BgWsdn
# oisWHsZMqYBfwoiPjoUwkQ89+U+m2AVa7h9kWbQf95p+nmE/EcVYqf4qnl1kag==
# SIG # End signature block
