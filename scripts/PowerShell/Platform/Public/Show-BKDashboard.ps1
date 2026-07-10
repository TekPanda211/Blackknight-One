function Show-BKDashboard {
    <#
    .SYNOPSIS
    Displays the Blackknight One operational dashboard.

    .DESCRIPTION
    Presents platform, tenant, confidence, Zero Trust, authentication,
    correlation, authorization, and recommendation data in a readable
    console view.
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

    function Get-BKMetricColor {
        param(
            [AllowNull()]
            [object]$Value,

            [double]$GoodThreshold = 85,

            [double]$WarningThreshold = 70,

            [switch]$LowerIsBetter
        )

        if ($null -eq $Value) {
            return "DarkGray"
        }

        $numericValue = [double]$Value

        if ($LowerIsBetter) {
            if ($numericValue -eq 0) {
                return "Green"
            }

            if ($numericValue -le 2) {
                return "Yellow"
            }

            return "Red"
        }

        if ($numericValue -ge $GoodThreshold) {
            return "Green"
        }

        if ($numericValue -ge $WarningThreshold) {
            return "Yellow"
        }

        return "Red"
    }

    function Write-BKDashboardRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value,

            [string]$Suffix = "",

            [string]$Color = "White"
        )

        $formattedValue = Format-BKValue `
            -Value $Value `
            -Suffix $Suffix

        Write-Host $Label.PadRight(34) -NoNewline
        Write-Host $formattedValue -ForegroundColor $Color
    }

    function Write-BKConfidenceRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value
        )

        $color = Get-BKMetricColor -Value $Value

        Write-BKDashboardRow `
            -Label $Label `
            -Value $Value `
            -Suffix "%" `
            -Color $color
    }

    function Write-BKRiskCountRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value
        )

        $color = Get-BKMetricColor `
            -Value $Value `
            -LowerIsBetter

        Write-BKDashboardRow `
            -Label $Label `
            -Value $Value `
            -Color $color
    }

    Clear-Host

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                         BLACKKNIGHT ONE" -ForegroundColor Cyan
    Write-Host "              Enterprise Identity Engineering Platform" -ForegroundColor Gray
    Write-Host "====================================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Platform" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

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
    Write-Host "--------------------------------------------------------------------"

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
    Write-Host "--------------------------------------------------------------------"

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
        -Label "Correlation" `
        -Value $dashboard.Confidence.Correlation

    Write-BKConfidenceRow `
        -Label "Validation" `
        -Value $dashboard.Confidence.Validation

    Write-Host ""
    Write-Host "Zero Trust Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Conditional Access Policies" `
        -Value $dashboard.TrustSnapshot.TotalPolicies

    Write-BKDashboardRow `
        -Label "Enabled Policies" `
        -Value $dashboard.TrustSnapshot.EnabledPolicies

    Write-BKRiskCountRow `
        -Label "Report-Only Policies" `
        -Value $dashboard.TrustSnapshot.ReportOnlyPolicies

    Write-BKRiskCountRow `
        -Label "Disabled Policies" `
        -Value $dashboard.TrustSnapshot.DisabledPolicies

    Write-BKDashboardRow `
        -Label "Named Locations" `
        -Value $dashboard.TrustSnapshot.NamedLocations

    Write-Host ""
    Write-Host "Authentication Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "MFA Registered" `
        -Value $dashboard.TrustSnapshot.MfaRegisteredPercent `
        -Suffix "%" `
        -Color (Get-BKMetricColor -Value $dashboard.TrustSnapshot.MfaRegisteredPercent)

    Write-BKRiskCountRow `
        -Label "Admins Without MFA" `
        -Value $dashboard.TrustSnapshot.AdminsWithoutMfa

    Write-BKDashboardRow `
        -Label "Passwordless Capable" `
        -Value $dashboard.TrustSnapshot.PasswordlessCapablePercent `
        -Suffix "%" `
        -Color (Get-BKMetricColor -Value $dashboard.TrustSnapshot.PasswordlessCapablePercent)

    Write-BKDashboardRow `
        -Label "SSPR Registered" `
        -Value $dashboard.TrustSnapshot.SsprRegisteredPercent `
        -Suffix "%" `
        -Color (Get-BKMetricColor -Value $dashboard.TrustSnapshot.SsprRegisteredPercent)

    Write-BKDashboardRow `
        -Label "System Preferred" `
        -Value $dashboard.TrustSnapshot.SystemPreferredEnabledPercent `
        -Suffix "%" `
        -Color (Get-BKMetricColor -Value $dashboard.TrustSnapshot.SystemPreferredEnabledPercent)

    Write-Host ""
    Write-Host "Identity Correlation Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Total Identities" `
        -Value $dashboard.CorrelationSnapshot.TotalIdentities

    Write-BKDashboardRow `
        -Label "Enabled Identities" `
        -Value $dashboard.CorrelationSnapshot.EnabledIdentities

    Write-BKRiskCountRow `
        -Label "Disabled Identities" `
        -Value $dashboard.CorrelationSnapshot.DisabledIdentities

    Write-BKDashboardRow `
        -Label "Administrative Identities" `
        -Value $dashboard.CorrelationSnapshot.AdministrativeIdentities

    Write-BKDashboardRow `
        -Label "Correlation Coverage" `
        -Value $dashboard.CorrelationSnapshot.CorrelationCoverage `
        -Suffix "%" `
        -Color (Get-BKMetricColor -Value $dashboard.CorrelationSnapshot.CorrelationCoverage)

    Write-BKRiskCountRow `
        -Label "Users Without MFA" `
        -Value $dashboard.CorrelationSnapshot.UsersWithoutMfa

    Write-BKRiskCountRow `
        -Label "Admins Without MFA" `
        -Value $dashboard.CorrelationSnapshot.AdminsWithoutMfa

    Write-BKDashboardRow `
        -Label "Passwordless Capable" `
        -Value $dashboard.CorrelationSnapshot.PasswordlessCapable

    Write-BKRiskCountRow `
        -Label "Users Without SSPR" `
        -Value $dashboard.CorrelationSnapshot.UsersWithoutSspr

    Write-BKRiskCountRow `
        -Label "Identities Requiring Attention" `
        -Value $dashboard.CorrelationSnapshot.AttentionRequired

    Write-Host ""
    Write-Host "Authorization Snapshot" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    Write-BKDashboardRow `
        -Label "Active Role Assignments" `
        -Value $dashboard.AuthorizationSnapshot.ActiveRoleAssignments

    Write-BKDashboardRow `
        -Label "User Role Assignments" `
        -Value $dashboard.AuthorizationSnapshot.UserRoleAssignments

    Write-BKDashboardRow `
        -Label "Group Role Assignments" `
        -Value $dashboard.AuthorizationSnapshot.GroupRoleAssignments

    Write-BKDashboardRow `
        -Label "Privileged Users" `
        -Value $dashboard.AuthorizationSnapshot.PrivilegedUsers

    Write-BKRiskCountRow `
        -Label "Privileged Users Without MFA" `
        -Value $dashboard.AuthorizationSnapshot.PrivilegedUsersWithoutMfa

    Write-BKDashboardRow `
        -Label "Service Principal Assignments" `
        -Value $dashboard.AuthorizationSnapshot.ServicePrincipalRoleAssignments

    Write-BKRiskCountRow `
        -Label "Deprecated Role Assignments" `
        -Value $dashboard.AuthorizationSnapshot.DeprecatedRoleAssignments

    Write-BKRiskCountRow `
        -Label "Assignments Requiring Review" `
        -Value $dashboard.AuthorizationSnapshot.RoleAssignmentsRequiringReview

    Write-BKRiskCountRow `
        -Label "High-Severity Findings" `
        -Value $dashboard.AuthorizationSnapshot.HighSeverityAuthorizationFindings

    Write-BKRiskCountRow `
        -Label "Medium-Severity Findings" `
        -Value $dashboard.AuthorizationSnapshot.MediumSeverityAuthorizationFindings

    Write-Host ""
    Write-Host "Overall Platform Confidence" -ForegroundColor Green
    Write-Host "===================================================================="

    $overallValue = Format-BKValue `
        -Value $dashboard.Confidence.Overall `
        -Suffix "%"

    $overallColor = Get-BKMetricColor `
        -Value $dashboard.Confidence.Overall

    Write-Host "".PadRight(27) -NoNewline
    Write-Host $overallValue -ForegroundColor $overallColor

    Write-Host "===================================================================="

    Write-Host ""
    Write-Host "Findings" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    Write-BKRiskCountRow `
        -Label "Warnings" `
        -Value $dashboard.Findings.Warnings

    Write-BKRiskCountRow `
        -Label "Failures" `
        -Value $dashboard.Findings.Failures

    Write-BKDashboardRow `
        -Label "Recommendations" `
        -Value $dashboard.Findings.RecommendationCount

    if ($dashboard.Findings.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Top Recommendations" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------"

        $dashboard.Findings.Recommendations |
            Select-Object -First $RecommendationLimit |
            ForEach-Object {
                Write-Host "- $_"
            }
    }

    Write-Host ""
    Write-Host "Report Availability" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------"

    $reportProperties = $dashboard.Reports.PSObject.Properties

    foreach ($reportProperty in $reportProperties) {
        $status = if ($reportProperty.Value) {
            "Available"
        }
        else {
            "Missing"
        }

        $color = if ($reportProperty.Value) {
            "Green"
        }
        else {
            "Red"
        }

        $label = $reportProperty.Name -replace "Available$", ""

        Write-BKDashboardRow `
            -Label $label `
            -Value $status `
            -Color $color
    }

    Write-Host ""
    Write-Host "Generated: $($dashboard.GeneratedAt)" -ForegroundColor DarkGray
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
}