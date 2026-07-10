<#
.SYNOPSIS
Blackknight One Identity Discovery

.DESCRIPTION
Runs the first Blackknight One identity confidence assessment using Microsoft Graph tenant discovery data.
#>

param(
    [string]$OutputPath = ".\reports\identity",
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

function Invoke-BKIdentityDiscovery {
    Write-BKSection "Blackknight Identity Discovery"

    $tenant = Get-BKTenant

    $score = 0
    $evidence = @()
    $recommendations = @()
    $checksRun = 10
    $passed = 0

    if ($tenant.TenantId) {
        $score += 10
        $passed++
        $evidence += "Tenant discovered"
    }

    if ($tenant.VerifiedDomains -gt 0) {
        $score += 10
        $passed++
        $evidence += "Verified domain exists"
    }

    if ($tenant.TotalUsers -gt 0) {
        $score += 10
        $passed++
        $evidence += "Users discovered"
    }

    if ($tenant.TotalGroups -gt 0) {
        $score += 10
        $passed++
        $evidence += "Groups discovered"
    }

    if ($tenant.DisabledUsers -eq 0) {
        $score += 10
        $passed++
        $evidence += "No disabled users detected"
    }
    else {
        $recommendations += "Review disabled users for licensing, access, and cleanup."
    }

    $guestRatio = 0
    if ($tenant.TotalUsers -gt 0) {
        $guestRatio = [math]::Round(($tenant.GuestUsers / $tenant.TotalUsers) * 100, 2)
    }

    if ($guestRatio -le 20) {
        $score += 10
        $passed++
        $evidence += "Guest user ratio is within threshold"
    }
    else {
        $recommendations += "Review guest user population and access review coverage."
    }

    if ($tenant.SubscribedSkus -gt 0) {
        $score += 10
        $passed++
        $evidence += "License inventory available"
    }
    else {
        $recommendations += "Review licensing inventory and entitlement readiness."
    }

    if ($tenant.SecurityGroups -gt 0) {
        $score += 10
        $passed++
        $evidence += "Security groups discovered"
    }

    if ($tenant.RoleAssignableGroups -gt 0) {
        $score += 10
        $passed++
        $evidence += "Role-assignable groups discovered"
    }
    else {
        $recommendations += "No role-assignable groups detected. Validate privileged access design and PIM readiness."
    }

    if ($recommendations.Count -gt 0) {
        $score += 5
        $passed += 0.5
        $evidence += "Recommendations generated"
    }
    else {
        $score += 10
        $passed++
        $evidence += "No recommendations generated"
    }

    $warnings = $checksRun - [math]::Floor($passed)

    $result = New-BKResult `
        -Engine "Identity Discovery" `
        -Status "Integrated" `
        -Health "Healthy" `
        -Confidence $score `
        -ChecksRun $checksRun `
        -Passed ([math]::Floor($passed)) `
        -Warnings $warnings `
        -Failed 0 `
        -Evidence $evidence `
        -Recommendations $recommendations

    Write-Host ""
    Write-Host "Tenant Name              : $($tenant.TenantName)"
    Write-Host "Tenant ID                : $($tenant.TenantId)"
    Write-Host "Verified Domains         : $($tenant.VerifiedDomains)"
    Write-Host "Total Users              : $($tenant.TotalUsers)"
    Write-Host "Enabled Users            : $($tenant.EnabledUsers)"
    Write-Host "Disabled Users           : $($tenant.DisabledUsers)"
    Write-Host "Guest Users              : $($tenant.GuestUsers)"
    Write-Host "Guest Ratio              : $guestRatio%"
    Write-Host "Total Groups             : $($tenant.TotalGroups)"
    Write-Host "Security Groups          : $($tenant.SecurityGroups)"
    Write-Host "Role Assignable Groups   : $($tenant.RoleAssignableGroups)"
    Write-Host "Subscribed SKUs          : $($tenant.SubscribedSkus)"
    Write-Host ""
    Write-Host "Identity Confidence      : $score%" -ForegroundColor Green

    if ($recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Recommendations" -ForegroundColor Yellow
        foreach ($recommendation in $recommendations) {
            Write-Host "- $recommendation"
        }
    }

    if (!(Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    if ($ExportJson) {
    $jsonPath = Join-Path $OutputPath "identity-discovery.json"

    $report = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Version     = "0.5.0-alpha"
        GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
        Tenant      = $tenant
        Result      = $result
    }

    Export-BKJsonReport -Data $report -Path $jsonPath
}

    Write-BKSection "Identity Discovery Complete"
}

Invoke-BKIdentityDiscovery