<#
.SYNOPSIS
Blackknight One Core Engine

.DESCRIPTION
The Core Engine is the entry point for Blackknight One.

It discovers enabled engines, executes them, and prepares the platform for unified reporting.
#>

[CmdletBinding()]
param()

$BlackKnightVersion = "0.4.0-alpha"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        Blackknight One" -ForegroundColor Cyan
Write-Host " Enterprise Identity Engineering Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version    : $BlackKnightVersion"
Write-Host "Mission    : Build • Coach • Mentor"
Write-Host "North Star : One Source of Truth"
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

$EngineManifests = Get-ChildItem -Path $Root -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue

if (!$EngineManifests) {
    Write-Warning "No engine manifests found."
}
else {
    foreach ($ManifestFile in $EngineManifests) {
        $Manifest = Get-Content $ManifestFile.FullName -Raw | ConvertFrom-Json

        if ($Manifest.Enabled -ne $true) {
            Write-Host "[-] Skipping disabled engine: $($Manifest.DisplayName)" -ForegroundColor Yellow
            continue
        }

        $EngineFolder = Split-Path $ManifestFile.FullName -Parent
        $EntryPoint = Join-Path $EngineFolder $Manifest.EntryPoint

        if (Test-Path $EntryPoint) {
            Write-Host "[+] Loading $($Manifest.DisplayName)..." -ForegroundColor Green
            & $EntryPoint
        }
        else {
            Write-Warning "Entry point not found for $($Manifest.DisplayName): $EntryPoint"
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Blackknight Core Complete" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan