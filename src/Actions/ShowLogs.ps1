# =========================
# src\actions\ShowLogs.ps1
#
# Zweck:
# - "Logs anzeigen" aus dem Menü
# - bewust simpel und stabil gehalten:
#   * genau eine Logdatei: <Projektwurzel>\logs\backup.log
#   * wenn die Datei noch nicht existiert, wird sie angelegt
#   * danach wird sie in Notepad geöffnet
#
# Abhängigkeiten:
# - Common.ps1 liegt in: <Projektwurzel>\config\lib\Common.ps1
# - Common.ps1 liefert:
#   * Initialisiere-Ordnerstruktur
#   * Schreibe-Log
#   * $Pfad_LogDatei (Pfad zur zentralen Logdatei)
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1) Projektwurzel ermitteln und Common.ps1 laden
#
# Dieses Skript liegt in:
#   <Projektwurzel>\src\actions\ShowLogs.ps1
#
# $PSScriptRoot zeigt also auf:
#   <Projektwurzel>\src\actions
#
# Projektwurzel ist damit 2 Ebenen höher:
#   actions -> src -> Projektwurzel
# ------------------------------------------------------------
$ProjektWurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$CommonPfad    = Join-Path $ProjektWurzel "config\lib\Common.ps1"

# Wenn Common.ps1 fehlt, kann das Skript nicht arbeiten
if (-not (Test-Path $CommonPfad)) {
    Write-Host "FEHLER: Common.ps1 nicht gefunden unter: $CommonPfad" -ForegroundColor Red
    Read-Host "Enter druecken zum Beenden" | Out-Null
    exit 99
}

# Dot-Sourcing:
# - führt Common.ps1 aus
# - Funktionen/Variablen werden hier verfügbar
. $CommonPfad

# ------------------------------------------------------------
# 2) Ordnerstruktur sicherstellen
# (legt config/logs/reports ggf. an)
# ------------------------------------------------------------
Initialisiere-Ordnerstruktur

# ------------------------------------------------------------
# 3) Logdatei sicherstellen
# $Pfad_LogDatei kommt aus Common.ps1 und zeigt auf:
#   <Projektwurzel>\logs\backup.log
# ------------------------------------------------------------
if (-not (Test-Path $Pfad_LogDatei)) {
    # Wir legen die Datei an, damit Notepad immer etwas öffnen kann
    Set-Content -Path $Pfad_LogDatei -Value ("== BackupTool Log gestartet: {0} ==" -f (Get-Date)) -Encoding UTF8
}

# Optional: ins Log schreiben, dass es über das Menü geöffnet wurde
Schreibe-Log -Level "INFO" -Nachricht "Logs wurden ueber das Menue geoeffnet."

# ------------------------------------------------------------
# 4) Logdatei im Editor öffnen
# Start-Process oeffnet Notepad mit der Datei als Argument.
# ------------------------------------------------------------
try {
    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$Pfad_LogDatei`""
} catch {
    # Falls Notepad nicht startet oder Pfadproblem:
    Schreibe-Log -Level "ERROR" -Nachricht ("Konnte Logdatei nicht oeffnen: {0}" -f $_.Exception.Message)
    Write-Host "Fehler: Konnte Logdatei nicht oeffnen. $($_.Exception.Message)" -ForegroundColor Red
    Warte-Auf-Enter
}

# ------------------------------------------------------------
# 5) Zurück ins Hauptmenü
# return beendet dieses Action-Skript.
# ------------------------------------------------------------
return

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBZZDCqbkjYZfbHQ6oPpTYKGy
# aiigggMmMIIDIjCCAgqgAwIBAgIQYA69k19LnZtMxrPWcz/FNzANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUuQ+Grom7/PQu
# F3pZUA2jULH/r7kwDQYJKoZIhvcNAQEBBQAEggEAfRreCnVC1EWbe0+PM53upb/2
# cNU03kBWVVttkG8onTZjl86k9rzXK65OPfh4++pypROsRUseRfNChaLIoQWLt/yq
# D5eKLE05M6sdZc6q4ub1s4CuKFbr3uRQ5TibVcYtHd+51esnuTaRPEisG3h0TFOD
# Npcxwv/CBe+LdYyXmYtdVeACetjUxfXGK5o8EcmXHQJjuv0zQZJhT0ucU9BEC1pn
# U92l7g63jJue0G4t1cKH6ntEdNxZfD/dMbB8XGyN0Q6SZ5I/TsPFVphvyYi1Kl6x
# 92E3fnl50p4MNVKkoYveNHmUd6kArhTzBF97iba4DtrLSkVV0LvOsHBt/HZ7iA==
# SIG # End signature block
