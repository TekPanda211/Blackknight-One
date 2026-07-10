function Get-BKDashboardData {
    <#
    .SYNOPSIS
    Builds normalized dashboard data for Blackknight One.

    .DESCRIPTION
    Reads current engine reports, platform registries, identity data,
    Trust data, correlation data, authorization findings, and validation
    results without making additional Microsoft Graph calls.
    #>

    [CmdletBinding()]
    param(
        [string]$ReportsRoot = ".\reports"
    )

    Write-BKLog `
        -Message "Building Blackknight dashboard data..." `
        -Level Info

    function Read-BKJsonFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        if (-not (Test-Path $Path)) {
            return $null
        }

        try {
            return Get-Content `
                -Path $Path `
                -Raw `
                -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-BKLog `
                -Message "Unable to read JSON report at $Path. $($_.Exception.Message)" `
                -Level Warning

            return $null
        }
    }

    function Get-BKReportResults {
        param(
            [AllowNull()]
            [object]$Report
        )

        if ($null -eq $Report) {
            return @()
        }

        if (
            $Report.PSObject.Properties.Name -contains
            "ValidationResult"
        ) {
            return @($Report.ValidationResult)
        }

        if (
            $Report.PSObject.Properties.Name -contains
            "Results"
        ) {
            return @($Report.Results)
        }

        if (
            $Report.PSObject.Properties.Name -contains
            "Result"
        ) {
            return @($Report.Result)
        }

        return @($Report)
    }

    function Get-BKAverageConfidence {
        param(
            [AllowEmptyCollection()]
            [object[]]$Results
        )

        $validResults = @(
            $Results |
                Where-Object {
                    $null -ne $_ -and
                    $_.PSObject.Properties.Name -contains
                    "Confidence" -and
                    $null -ne $_.Confidence
                }
        )

        if ($validResults.Count -eq 0) {
            return $null
        }

        return [math]::Round(
            (
                $validResults.Confidence |
                    Measure-Object -Average
            ).Average,
            2
        )
    }

    try {
        $platform = Get-BKPlatform
        $engines = @($platform.Engines)

        $identityPath = Join-Path `
            $ReportsRoot `
            "identity\identity-discovery.json"

        $trustPath = Join-Path `
            $ReportsRoot `
            "trust\trust-discovery.json"

        $governancePath = Join-Path `
            $ReportsRoot `
            "governance\governance-health.json"

        $operationsPath = Join-Path `
            $ReportsRoot `
            "operations\operations-health.json"

        $correlationPath = Join-Path `
            $ReportsRoot `
            "correlation\identity-graph.json"

        $validationPath = Join-Path `
            $ReportsRoot `
            "validation\validation-report.json"

        $identityReport = Read-BKJsonFile `
            -Path $identityPath

        $trustReport = Read-BKJsonFile `
            -Path $trustPath

        $governanceReport = Read-BKJsonFile `
            -Path $governancePath

        $operationsReport = Read-BKJsonFile `
            -Path $operationsPath

        $correlationReport = Read-BKJsonFile `
            -Path $correlationPath

        $validationReport = Read-BKJsonFile `
            -Path $validationPath

        $identityResults = @(
            Get-BKReportResults -Report $identityReport
        )

        $trustResults = @(
            Get-BKReportResults -Report $trustReport
        )

        $governanceResults = @(
            Get-BKReportResults -Report $governanceReport
        )

        $operationsResults = @(
            Get-BKReportResults -Report $operationsReport
        )

        $correlationResults = @(
            Get-BKReportResults -Report $correlationReport
        )

        $validationResults = @(
            Get-BKReportResults -Report $validationReport
        )

        $allAssessmentResults = @(
            $identityResults
            $trustResults
            $governanceResults
            $operationsResults
            $correlationResults
        ) |
            Where-Object {
                $null -ne $_ -and
                $_.PSObject.Properties.Name -contains
                "Confidence"
            }

        $identityConfidence = Get-BKAverageConfidence `
            -Results $identityResults

        $trustConfidence = Get-BKAverageConfidence `
            -Results $trustResults

        $governanceConfidence = Get-BKAverageConfidence `
            -Results $governanceResults

        $operationsConfidence = Get-BKAverageConfidence `
            -Results $operationsResults

        $correlationConfidence = Get-BKAverageConfidence `
            -Results $correlationResults

        $validationConfidence = Get-BKAverageConfidence `
            -Results $validationResults

        $overallConfidence = Get-BKAverageConfidence `
            -Results $allAssessmentResults

        $recommendations = @(
            $allAssessmentResults |
                ForEach-Object {
                    @($_.Recommendations)
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Select-Object -Unique
        )

        $warningChecks = (
            $allAssessmentResults |
                Where-Object {
                    $_.PSObject.Properties.Name -contains
                    "Warnings"
                } |
                Measure-Object `
                    -Property Warnings `
                    -Sum
        ).Sum

        $failedChecks = (
            $allAssessmentResults |
                Where-Object {
                    $_.PSObject.Properties.Name -contains
                    "Failed"
                } |
                Measure-Object `
                    -Property Failed `
                    -Sum
        ).Sum

        if ($null -eq $warningChecks) {
            $warningChecks = 0
        }

        if ($null -eq $failedChecks) {
            $failedChecks = 0
        }

        $tenantName = $null
        $tenantId = $null
        $totalUsers = $null
        $guestUsers = $null
        $totalGroups = $null
        $subscribedSkus = $null

        if (
            $identityReport -and
            $identityReport.PSObject.Properties.Name -contains
            "Tenant"
        ) {
            $tenantName =
                $identityReport.Tenant.TenantName

            $tenantId =
                $identityReport.Tenant.TenantId

            $totalUsers =
                $identityReport.Tenant.TotalUsers

            $guestUsers =
                $identityReport.Tenant.GuestUsers

            $totalGroups =
                $identityReport.Tenant.TotalGroups

            $subscribedSkus =
                $identityReport.Tenant.SubscribedSkus
        }

        $trustSnapshot = [PSCustomObject]@{
            TotalPolicies                  = $null
            EnabledPolicies                = $null
            ReportOnlyPolicies             = $null
            DisabledPolicies               = $null
            NamedLocations                 = $null
            MfaRegisteredPercent           = $null
            AdminsWithoutMfa               = $null
            PasswordlessCapablePercent     = $null
            SsprRegisteredPercent          = $null
            SystemPreferredEnabledPercent  = $null
        }

        if ($trustReport) {
            if (
                $trustReport.PSObject.Properties.Name -contains
                "ConditionalAccess" -and
                $null -ne $trustReport.ConditionalAccess
            ) {
                $trustSnapshot.TotalPolicies =
                    $trustReport.ConditionalAccess.Total

                $trustSnapshot.EnabledPolicies =
                    $trustReport.ConditionalAccess.Enabled

                $trustSnapshot.ReportOnlyPolicies =
                    $trustReport.ConditionalAccess.ReportOnly

                $trustSnapshot.DisabledPolicies =
                    $trustReport.ConditionalAccess.Disabled
            }

            if (
                $trustReport.PSObject.Properties.Name -contains
                "NamedLocations" -and
                $null -ne $trustReport.NamedLocations
            ) {
                $trustSnapshot.NamedLocations =
                    @($trustReport.NamedLocations).Count
            }

            if (
                $trustReport.PSObject.Properties.Name -contains
                "Authentication" -and
                $null -ne $trustReport.Authentication
            ) {
                $trustSnapshot.MfaRegisteredPercent =
                    $trustReport.Authentication.
                        MfaRegisteredPercent

                $trustSnapshot.AdminsWithoutMfa =
                    $trustReport.Authentication.
                        AdminsWithoutMfa

                $trustSnapshot.PasswordlessCapablePercent =
                    $trustReport.Authentication.
                        PasswordlessCapablePercent

                $trustSnapshot.SsprRegisteredPercent =
                    $trustReport.Authentication.
                        SsprRegisteredPercent

                $trustSnapshot.SystemPreferredEnabledPercent =
                    $trustReport.Authentication.
                        SystemPreferredEnabledPercent
            }
        }

        $authorizationSnapshot = [PSCustomObject]@{
            ActiveRoleAssignments             = $null
            UserRoleAssignments               = $null
            GroupRoleAssignments              = $null
            PrivilegedUsers                   = $null
            PrivilegedUsersWithoutMfa         = $null
            ServicePrincipalRoleAssignments   = $null
            DeprecatedRoleAssignments         = $null
            RoleAssignmentsRequiringReview    = $null
            HighSeverityAuthorizationFindings = $null
            MediumSeverityAuthorizationFindings = $null
        }

        $correlationSnapshot = [PSCustomObject]@{
            TotalIdentities          = $null
            EnabledIdentities        = $null
            DisabledIdentities       = $null
            AdministrativeIdentities = $null
            CorrelationCoverage      = $null
            UsersWithoutMfa          = $null
            AdminsWithoutMfa         = $null
            PasswordlessCapable      = $null
            UsersWithoutPasswordless = $null
            UsersWithoutSspr         = $null
            AttentionRequired        = $null
        }

        if (
            $correlationReport -and
            $correlationReport.PSObject.Properties.Name -contains
            "Summary" -and
            $null -ne $correlationReport.Summary
        ) {
            $summary = $correlationReport.Summary

            $correlationSnapshot.TotalIdentities =
                $summary.TotalIdentities

            $correlationSnapshot.EnabledIdentities =
                $summary.EnabledIdentities

            $correlationSnapshot.DisabledIdentities =
                $summary.DisabledIdentities

            $correlationSnapshot.AdministrativeIdentities =
                $summary.AdministrativeIdentities

            $correlationSnapshot.CorrelationCoverage =
                $summary.CorrelationCoverage

            $correlationSnapshot.UsersWithoutMfa =
                $summary.UsersWithoutMfa

            $correlationSnapshot.AdminsWithoutMfa =
                $summary.AdminsWithoutMfa

            $correlationSnapshot.PasswordlessCapable =
                $summary.PasswordlessCapable

            $correlationSnapshot.UsersWithoutPasswordless =
                $summary.UsersWithoutPasswordless

            $correlationSnapshot.UsersWithoutSspr =
                $summary.UsersWithoutSspr

            $correlationSnapshot.AttentionRequired =
                $summary.AttentionRequired

            $authorizationSnapshot.ActiveRoleAssignments =
                $summary.ActiveRoleAssignments

            $authorizationSnapshot.UserRoleAssignments =
                $summary.UserRoleAssignments

            $authorizationSnapshot.GroupRoleAssignments =
                $summary.GroupRoleAssignments

            $authorizationSnapshot.PrivilegedUsers =
                $summary.PrivilegedUsers

            $authorizationSnapshot.PrivilegedUsersWithoutMfa =
                $summary.PrivilegedUsersWithoutMfa

            $authorizationSnapshot.ServicePrincipalRoleAssignments =
                $summary.ServicePrincipalRoleAssignments

            $authorizationSnapshot.DeprecatedRoleAssignments =
                $summary.DeprecatedRoleAssignments

            $authorizationSnapshot.RoleAssignmentsRequiringReview =
                $summary.RoleAssignmentsRequiringReview

            $authorizationSnapshot.HighSeverityAuthorizationFindings =
                $summary.HighSeverityAuthorizationFindings

            $authorizationSnapshot.MediumSeverityAuthorizationFindings =
                $summary.MediumSeverityAuthorizationFindings
        }

        [PSCustomObject]@{
            Platform = [PSCustomObject]@{
                Name            = $platform.Name
                Version         = $platform.Version
                Mission         = $platform.Mission
                NorthStar       = $platform.NorthStar
                EngineCount     = $platform.EngineCount
                ServiceCount    = $platform.ServiceCount
                CapabilityCount = $platform.CapabilityCount
            }

            Tenant = [PSCustomObject]@{
                Name           = $tenantName
                TenantId       = $tenantId
                TotalUsers     = $totalUsers
                GuestUsers     = $guestUsers
                TotalGroups    = $totalGroups
                SubscribedSkus = $subscribedSkus
            }

            Confidence = [PSCustomObject]@{
                Identity    = $identityConfidence
                Trust       = $trustConfidence
                Governance  = $governanceConfidence
                Operations  = $operationsConfidence
                Correlation = $correlationConfidence
                Validation  = $validationConfidence
                Overall     = $overallConfidence
            }

            TrustSnapshot = $trustSnapshot

            CorrelationSnapshot = $correlationSnapshot

            AuthorizationSnapshot = $authorizationSnapshot

            Findings = [PSCustomObject]@{
                Warnings            = $warningChecks
                Failures            = $failedChecks
                RecommendationCount = $recommendations.Count
                Recommendations     = $recommendations
            }

            Engines = $engines

            Reports = [PSCustomObject]@{
                IdentityAvailable    = Test-Path $identityPath
                TrustAvailable       = Test-Path $trustPath
                GovernanceAvailable  = Test-Path $governancePath
                OperationsAvailable  = Test-Path $operationsPath
                CorrelationAvailable = Test-Path $correlationPath
                ValidationAvailable  = Test-Path $validationPath
            }

            GeneratedAt = (
                Get-Date
            ).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error

        throw
    }
}