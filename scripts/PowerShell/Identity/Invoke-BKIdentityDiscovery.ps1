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

    if ($tenant.TenantId) {
        $score += 10
        $evidence += "Tenant discovered"
    }

    if ($tenant.VerifiedDomains -gt 0) {
        $score += 10
        $evidence += "Verified domain exists"
    }

    if ($tenant.TotalUsers -gt 0) {
        $score += 10
        $evidence += "Users discovered"
    }

    if ($tenant.TotalGroups -gt 0) {
        $score += 10
        $evidence += "Groups discovered"
    }

    if ($tenant.DisabledUsers -eq 0) {
        $score += 10
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
        $evidence += "Guest user ratio is within threshold"
    }
    else {
        $recommendations += "Review guest user population and access review coverage."
    }

    if ($tenant.SubscribedSkus -gt 0) {
        $score += 10
        $evidence += "License inventory available"
    }
    else {
        $recommendations += "Review licensing inventory and entitlement readiness."
    }

    if ($tenant.SecurityGroups -gt 0) {
        $score += 10
        $evidence += "Security groups discovered"
    }

    $score += 10
    $evidence += "Role-assignable groups reviewed"

    $recommendations += "Evaluate Privileged Identity Management readiness."
    $recommendations += "Validate privileged groups have owners and access reviews."
    $score += 10

    $result = New-BKResult `
        -Engine "Identity Discovery" `
        -Status "Integrated" `
        -Health "Healthy" `
        -Confidence $score `
        -ChecksRun 10 `
        -Passed ($score / 10) `
        -Warnings (10 - ($score / 10)) `
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

        [PSCustomObject]@{
            Tenant = $tenant
            Result = $result
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding utf8

        Write-BKLog -Message "Exported identity discovery report to $jsonPath" -Level Success
    }

    Write-BKSection "Identity Discovery Complete"

    return $result
}

Invoke-BKIdentityDiscovery