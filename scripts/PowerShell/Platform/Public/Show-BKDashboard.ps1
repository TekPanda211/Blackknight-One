function Show-BKDashboard {
    <#
    .SYNOPSIS
    Displays the Blackknight One operational dashboard.

    .DESCRIPTION
    Presents normalized platform, tenant, confidence, Zero Trust,
    authentication, and recommendation data in a readable console view.
    #>

    [CmdletBinding()]
    param(
        [ValidateRange(1, 20)]
        [int]$RecommendationLimit = 5
    )

    $dashboard = Get-BKDashboardData

    function Format-BKValue {
        param(
            [AllowNull()]
            [object]$Value,

            [string]$Suffix = ""
        )

        if (
            $null -eq $Value -or
            [string]::IsNullOrWhiteSpace([string]$Value)
        ) {
            return "Not Available"
        }

        return "$Value$Suffix"
    }

    function Write-BKDashboardRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value,

            [string]$Suffix = ""
        )

        $formattedValue = Format-BKValue `
            -Value $Value `
            -Suffix $Suffix

        Write-Host (
            $Label.PadRight(29) +
            $formattedValue
        )
    }

    function Get-BKConfidenceColor {
        param(
            [AllowNull()]
            [object]$Value
        )

        if ($null -eq $Value) {
            return "DarkGray"
        }

        $numericValue = [double]$Value

        if ($numericValue -ge 85) {
            return "Green"
        }

        if ($numericValue -ge 70) {
            return "Yellow"
        }

        return "Red"
    }

    function Write-BKConfidenceRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value
        )

        $formattedValue = Format-BKValue `
            -Value $Value `
            -Suffix "%"

        $color = Get-BKConfidenceColor -Value $Value

        Write-Host $Label.PadRight(29) -NoNewline
        Write-Host $formattedValue -ForegroundColor $color
    }

    Clear-Host

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "                     BLACKKNIGHT ONE" -ForegroundColor Cyan
    Write-Host "          Enterprise Identity Engineering Platform" -ForegroundColor Gray
    Write-Host "==============================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Platform" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Version" `
        -Value $dashboard.Platform.Version

    Write-BKDashboardRow `
        -Label "Registered Engines" `
        -Value $dashboard.Platform.EngineCount

    Write-BKDashboardRow `
        -Label "Platform Services" `
        -Value $dashboard.Platform.ServiceCount

    Write-BKDashboardRow `
        -Label "Capabilities" `
        -Value $dashboard.Platform.CapabilityCount

    Write-Host ""
    Write-Host "Tenant" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Tenant" `
        -Value $dashboard.Tenant.Name

    Write-BKDashboardRow `
        -Label "Tenant ID" `
        -Value $dashboard.Tenant.TenantId

    Write-BKDashboardRow `
        -Label "Users" `
        -Value $dashboard.Tenant.TotalUsers

    Write-BKDashboardRow `
        -Label "Groups" `
        -Value $dashboard.Tenant.TotalGroups

    Write-BKDashboardRow `
        -Label "Guests" `
        -Value $dashboard.Tenant.GuestUsers

    Write-BKDashboardRow `
        -Label "Subscribed SKUs" `
        -Value $dashboard.Tenant.SubscribedSkus

    Write-Host ""
    Write-Host "Confidence" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"

    Write-BKConfidenceRow `
        -Label "Identity" `
        -Value $dashboard.Confidence.Identity

    Write-BKConfidenceRow `
        -Label "Trust" `
        -Value $dashboard.Confidence.Trust

    Write-BKConfidenceRow `
        -Label "Governance" `
        -Value $dashboard.Confidence.Governance

    Write-BKConfidenceRow `
        -Label "Operations" `
        -Value $dashboard.Confidence.Operations

    Write-BKConfidenceRow `
        -Label "Validation" `
        -Value $dashboard.Confidence.Validation

    Write-Host ""
    Write-Host "Zero Trust Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Conditional Access Policies" `
        -Value $dashboard.TrustSnapshot.TotalPolicies

    Write-BKDashboardRow `
        -Label "Enabled Policies" `
        -Value $dashboard.TrustSnapshot.EnabledPolicies

    Write-BKDashboardRow `
        -Label "Report-Only Policies" `
        -Value $dashboard.TrustSnapshot.ReportOnlyPolicies

    Write-BKDashboardRow `
        -Label "Disabled Policies" `
        -Value $dashboard.TrustSnapshot.DisabledPolicies

    Write-BKDashboardRow `
        -Label "Named Locations" `
        -Value $dashboard.TrustSnapshot.NamedLocations

    Write-Host ""
    Write-Host "Authentication Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "MFA Registered" `
        -Value $dashboard.TrustSnapshot.MfaRegisteredPercent `
        -Suffix "%"

    Write-BKDashboardRow `
        -Label "Admins Without MFA" `
        -Value $dashboard.TrustSnapshot.AdminsWithoutMfa

    Write-BKDashboardRow `
        -Label "Passwordless Capable" `
        -Value $dashboard.TrustSnapshot.PasswordlessCapablePercent `
        -Suffix "%"

    Write-BKDashboardRow `
        -Label "SSPR Registered" `
        -Value $dashboard.TrustSnapshot.SsprRegisteredPercent `
        -Suffix "%"

    Write-BKDashboardRow `
        -Label "System Preferred" `
        -Value $dashboard.TrustSnapshot.SystemPreferredEnabledPercent `
        -Suffix "%"

    Write-Host ""
    Write-Host "Overall Platform Confidence" -ForegroundColor Green
    Write-Host "=============================================================="

    $overallValue = Format-BKValue `
        -Value $dashboard.Confidence.Overall `
        -Suffix "%"

    $overallColor = Get-BKConfidenceColor `
        -Value $dashboard.Confidence.Overall

    Write-Host "".PadRight(24) -NoNewline
    Write-Host $overallValue -ForegroundColor $overallColor

    Write-Host "=============================================================="

    if ($dashboard.Findings.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Top Recommendations" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        $dashboard.Findings.Recommendations |
            Select-Object -First $RecommendationLimit |
            ForEach-Object {
                Write-Host "- $_"
            }
    }

    Write-Host ""
    Write-Host "Generated: $($dashboard.GeneratedAt)" -ForegroundColor DarkGray
    Write-Host ""
}