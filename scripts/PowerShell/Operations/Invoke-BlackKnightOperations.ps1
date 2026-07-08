<#
.SYNOPSIS
Blackknight One Operations Engine

.DESCRIPTION
Runs operational identity workflow checks for workforce lifecycle, partner operations,
license operations, identity requests, and incident response.

This version uses shared Blackknight One Platform Services.
#>

param(
    [string]$OutputPath = ".\reports\operations",
    [switch]$ExportJson
)

$PlatformModule = Join-Path (Split-Path $PSScriptRoot -Parent) "Platform\Blackknight-Platform.psm1"

if (Test-Path $PlatformModule) {
    Import-Module $PlatformModule -Force
}
else {
    throw "Blackknight Platform module not found at $PlatformModule"
}

function Write-BKSection {
    param([string]$Title)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Invoke-WorkforceLifecycleHealth {
    Write-BKSection "Workforce Lifecycle Engine"

    New-BKResult `
        -Engine "Workforce Lifecycle" `
        -Evidence @("Workforce lifecycle framework created") `
        -Recommendations @("Add Microsoft Graph user lifecycle validation")
}

function Invoke-PartnerOperationsHealth {
    Write-BKSection "Partner Operations Engine"

    New-BKResult `
        -Engine "Partner Operations" `
        -Evidence @("Partner operations framework created") `
        -Recommendations @("Add GDAP relationship inventory")
}

function Invoke-LicenseOperationsHealth {
    Write-BKSection "License Operations Engine"

    New-BKResult `
        -Engine "License Operations" `
        -Evidence @("License operations framework created") `
        -Recommendations @("Add Microsoft Graph subscribed SKU inventory")
}

function Invoke-IdentityRequestHealth {
    Write-BKSection "Identity Requests Engine"

    New-BKResult `
        -Engine "Identity Requests" `
        -Evidence @("Identity request framework created") `
        -Recommendations @("Add access request evidence model")
}

function Invoke-IncidentResponseHealth {
    Write-BKSection "Incident Response Engine"

    New-BKResult `
        -Engine "Incident Response" `
        -Evidence @("Incident response framework created") `
        -Recommendations @("Add emergency termination validation workflow")
}

function Invoke-BlackKnightOperations {
    Write-BKSection "Blackknight One Operations Engine"

    if (!(Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $results = @()
    $results += Invoke-WorkforceLifecycleHealth
    $results += Invoke-PartnerOperationsHealth
    $results += Invoke-LicenseOperationsHealth
    $results += Invoke-IdentityRequestHealth
    $results += Invoke-IncidentResponseHealth

    $results | Format-Table Engine, Version, Status, Health, Confidence, ChecksRun, Passed, Warnings, Failed, Timestamp -AutoSize

    if ($ExportJson) {
        $jsonPath = Join-Path $OutputPath "operations-health.json"
        Export-BKJsonReport -Data $results -Path $jsonPath
    }

    Write-BKSection "Operations Engine Complete"
}

Invoke-BlackKnightOperations