<#
.SYNOPSIS
Blackknight One Correlation Engine

.DESCRIPTION
Builds a normalized identity graph and evaluates correlated identity,
authentication, and authorization evidence.

Current correlation layers include:

- Microsoft Entra users
- Account state
- Authentication registration
- MFA coverage
- Passwordless readiness
- SSPR registration
- Active directory-role assignments
- Privileged identity detection
- Service-principal role assignments
- Deprecated directory-role detection
- Authorization review findings
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\correlation",
    [switch]$ExportJson
)

$PlatformModule = Join-Path `
    (Split-Path $PSScriptRoot -Parent) `
    "Platform\Blackknight-Platform.psm1"

if (Test-Path $PlatformModule) {
    Import-Module $PlatformModule -Force
}
else {
    throw "Blackknight Platform module not found at $PlatformModule"
}

function Write-BKCorrelationSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function New-BKCorrelationCheck {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,

        [Parameter(Mandatory)]
        [int]$Points,

        [Parameter(Mandatory)]
        [int]$MaximumPoints,

        [Parameter(Mandatory)]
        [string]$Details,

        [string]$Recommendation
    )

    [PSCustomObject]@{
        Name           = $Name
        Status         = $Status
        Points         = $Points
        MaximumPoints  = $MaximumPoints
        Details        = $Details
        Recommendation = $Recommendation
    }
}

function Invoke-BKCorrelation {
    Write-BKCorrelationSection "Blackknight Correlation Engine"

    try {
        Connect-BKGraph -Scopes @(
            "User.Read.All",
            "Directory.Read.All",
            "AuditLog.Read.All",
            "RoleManagement.Read.Directory"
        ) | Out-Null

        Write-BKLog `
            -Message "Collecting correlated identity data..." `
            -Level Info

        $identities = @(
            Get-BKIdentityGraph -SkipGraphConnect
        )

        Write-BKLog `
            -Message "Collecting authorization assignments..." `
            -Level Info

        $directoryRoles = @(
            Get-BKDirectoryRoles -SkipGraphConnect
        )

        $enabledUsers = @(
            $identities |
                Where-Object {
                    $_.AccountEnabled -eq $true
                }
        )

        $disabledUsers = @(
            $identities |
                Where-Object {
                    $_.AccountEnabled -ne $true
                }
        )

        $administrativeUsers = @(
            $identities |
                Where-Object {
                    $_.IsAdmin -eq $true
                }
        )

        $privilegedUsers = @(
            $identities |
                Where-Object {
                    $_.IsPrivileged -eq $true
                }
        )

        $usersWithoutMfa = @(
            $identities |
                Where-Object {
                    $_.IsMfaRegistered -eq $false
                }
        )

        $adminsWithoutMfa = @(
            $identities |
                Where-Object {
                    $_.IsAdmin -eq $true -and
                    $_.IsMfaRegistered -eq $false
                }
        )

        $privilegedUsersWithoutMfa = @(
            $identities |
                Where-Object {
                    $_.IsPrivileged -eq $true -and
                    $_.IsMfaRegistered -ne $true
                }
        )

        $passwordlessUsers = @(
            $identities |
                Where-Object {
                    $_.IsPasswordlessCapable -eq $true
                }
        )

        $usersWithoutPasswordless = @(
            $identities |
                Where-Object {
                    $_.IsPasswordlessCapable -eq $false
                }
        )

        $usersWithoutSspr = @(
            $identities |
                Where-Object {
                    $_.IsSsprRegistered -eq $false
                }
        )

        $attentionRequired = @(
            $identities |
                Where-Object {
                    $_.RequiresAttention -eq $true
                }
        )

        $servicePrincipalRoleAssignments = @(
            $directoryRoles |
                Where-Object {
                    $_.PrincipalType -eq "ServicePrincipal"
                }
        )

        $userRoleAssignments = @(
            $directoryRoles |
                Where-Object {
                    $_.PrincipalType -eq "User"
                }
        )

        $groupRoleAssignments = @(
            $directoryRoles |
                Where-Object {
                    $_.PrincipalType -eq "Group"
                }
        )

        $deprecatedRoleAssignments = @(
            $directoryRoles |
                Where-Object {
                    $_.IsDeprecated -eq $true
                }
        )

        $roleAssignmentsRequiringReview = @(
            $directoryRoles |
                Where-Object {
                    $_.RequiresReview -eq $true
                }
        )

        $highSeverityAuthorizationFindings = @(
            $directoryRoles |
                Where-Object {
                    $_.Severity -eq "High"
                }
        )

        $mediumSeverityAuthorizationFindings = @(
            $directoryRoles |
                Where-Object {
                    $_.Severity -eq "Medium"
                }
        )

        $totalUsers = $identities.Count

        $correlatedUsers = @(
            $identities |
                Where-Object {
                    $null -ne $_.IsMfaRegistered
                }
        ).Count

        $correlationCoverage = if ($totalUsers -gt 0) {
            [math]::Round(
                ($correlatedUsers / $totalUsers) * 100,
                2
            )
        }
        else {
            0
        }

        $checks = @()

        if ($totalUsers -gt 0) {
            $checks += New-BKCorrelationCheck `
                -Name "Identity Correlation" `
                -Status "PASS" `
                -Points 10 `
                -MaximumPoints 10 `
                -Details "$totalUsers identities were correlated."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "Identity Correlation" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 10 `
                -Details "No identities were available for correlation." `
                -Recommendation "Run identity discovery and verify Microsoft Graph user access."
        }

        if ($correlationCoverage -ge 95) {
            $checks += New-BKCorrelationCheck `
                -Name "Correlation Coverage" `
                -Status "PASS" `
                -Points 15 `
                -MaximumPoints 15 `
                -Details "Authentication correlation coverage is $correlationCoverage%."
        }
        elseif ($correlationCoverage -ge 75) {
            $checks += New-BKCorrelationCheck `
                -Name "Correlation Coverage" `
                -Status "WARN" `
                -Points 8 `
                -MaximumPoints 15 `
                -Details "Authentication correlation coverage is $correlationCoverage%." `
                -Recommendation "Investigate identities missing authentication registration data."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "Correlation Coverage" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 15 `
                -Details "Authentication correlation coverage is $correlationCoverage%." `
                -Recommendation "Restore authentication report coverage before relying on identity conclusions."
        }

        if ($privilegedUsersWithoutMfa.Count -eq 0) {
            $checks += New-BKCorrelationCheck `
                -Name "Privileged MFA Coverage" `
                -Status "PASS" `
                -Points 20 `
                -MaximumPoints 20 `
                -Details "No privileged users without MFA were detected."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "Privileged MFA Coverage" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 20 `
                -Details "$($privilegedUsersWithoutMfa.Count) privileged users are not registered for MFA." `
                -Recommendation "Require MFA registration for all privileged identities immediately."
        }

        if ($usersWithoutMfa.Count -eq 0) {
            $checks += New-BKCorrelationCheck `
                -Name "User MFA Coverage" `
                -Status "PASS" `
                -Points 15 `
                -MaximumPoints 15 `
                -Details "All correlated users are registered for MFA."
        }
        elseif ($usersWithoutMfa.Count -le 2) {
            $checks += New-BKCorrelationCheck `
                -Name "User MFA Coverage" `
                -Status "WARN" `
                -Points 8 `
                -MaximumPoints 15 `
                -Details "$($usersWithoutMfa.Count) users are not registered for MFA." `
                -Recommendation "Complete MFA registration for the remaining users."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "User MFA Coverage" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 15 `
                -Details "$($usersWithoutMfa.Count) users are not registered for MFA." `
                -Recommendation "Prioritize tenant-wide MFA registration."
        }

        if ($passwordlessUsers.Count -gt 0) {
            $checks += New-BKCorrelationCheck `
                -Name "Passwordless Adoption" `
                -Status "PASS" `
                -Points 10 `
                -MaximumPoints 10 `
                -Details "$($passwordlessUsers.Count) identities are passwordless capable."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "Passwordless Adoption" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 10 `
                -Details "No passwordless-capable identities were detected." `
                -Recommendation "Evaluate passkeys, FIDO2, Windows Hello for Business, and Temporary Access Pass."
        }

        if ($deprecatedRoleAssignments.Count -eq 0) {
            $checks += New-BKCorrelationCheck `
                -Name "Deprecated Role Hygiene" `
                -Status "PASS" `
                -Points 15 `
                -MaximumPoints 15 `
                -Details "No deprecated directory-role assignments were detected."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "Deprecated Role Hygiene" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 15 `
                -Details "$($deprecatedRoleAssignments.Count) deprecated directory-role assignments were detected." `
                -Recommendation "Review and remove deprecated directory-role assignments where no longer required."
        }

        if ($highSeverityAuthorizationFindings.Count -eq 0) {
            $checks += New-BKCorrelationCheck `
                -Name "High-Severity Authorization Findings" `
                -Status "PASS" `
                -Points 15 `
                -MaximumPoints 15 `
                -Details "No high-severity authorization findings were detected."
        }
        else {
            $checks += New-BKCorrelationCheck `
                -Name "High-Severity Authorization Findings" `
                -Status "FAIL" `
                -Points 0 `
                -MaximumPoints 15 `
                -Details "$($highSeverityAuthorizationFindings.Count) high-severity authorization findings were detected." `
                -Recommendation "Review high-severity directory-role findings and document required exceptions."
        }

        $score = (
            $checks |
                Measure-Object -Property Points -Sum
        ).Sum

        if ($null -eq $score) {
            $score = 0
        }

        $passed = @(
            $checks |
                Where-Object {
                    $_.Status -eq "PASS"
                }
        ).Count

        $warnings = @(
            $checks |
                Where-Object {
                    $_.Status -eq "WARN"
                }
        ).Count

        $failed = @(
            $checks |
                Where-Object {
                    $_.Status -eq "FAIL"
                }
        ).Count

        $recommendations = @(
            $checks |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_.Recommendation
                    )
                } |
                Select-Object -ExpandProperty Recommendation -Unique
        )

        $evidence = @(
            "Total identities correlated: $totalUsers"
            "Authentication correlation coverage: $correlationCoverage%"
            "Privileged users: $($privilegedUsers.Count)"
            "Privileged users without MFA: $($privilegedUsersWithoutMfa.Count)"
            "Active directory-role assignments: $($directoryRoles.Count)"
            "Service-principal role assignments: $($servicePrincipalRoleAssignments.Count)"
            "Deprecated role assignments: $($deprecatedRoleAssignments.Count)"
            "High-severity authorization findings: $($highSeverityAuthorizationFindings.Count)"
            "Identities requiring attention: $($attentionRequired.Count)"
        )

        $health = if ($failed -gt 0) {
            "Degraded"
        }
        elseif ($warnings -gt 0) {
            "Warning"
        }
        else {
            "Healthy"
        }

        $result = New-BKResult `
            -Engine "Correlation Engine" `
            -Version "0.5.0-alpha" `
            -Status "Integrated" `
            -Health $health `
            -Confidence $score `
            -ChecksRun $checks.Count `
            -Passed $passed `
            -Warnings $warnings `
            -Failed $failed `
            -Evidence $evidence `
            -Recommendations $recommendations

        Write-Host ""
        Write-Host "Identity Correlation"
        Write-Host "----------------------------------------"
        Write-Host "Total Identities              : $totalUsers"
        Write-Host "Enabled Identities            : $($enabledUsers.Count)"
        Write-Host "Disabled Identities           : $($disabledUsers.Count)"
        Write-Host "Administrative Identities     : $($administrativeUsers.Count)"
        Write-Host "Privileged Identities         : $($privilegedUsers.Count)"
        Write-Host "Correlation Coverage          : $correlationCoverage%"

        Write-Host ""
        Write-Host "Authentication Correlation"
        Write-Host "----------------------------------------"
        Write-Host "Users Without MFA             : $($usersWithoutMfa.Count)"
        Write-Host "Admins Without MFA            : $($adminsWithoutMfa.Count)"
        Write-Host "Privileged Without MFA        : $($privilegedUsersWithoutMfa.Count)"
        Write-Host "Passwordless Capable          : $($passwordlessUsers.Count)"
        Write-Host "Without Passwordless          : $($usersWithoutPasswordless.Count)"
        Write-Host "Without SSPR                  : $($usersWithoutSspr.Count)"
        Write-Host "Attention Required            : $($attentionRequired.Count)"

        Write-Host ""
        Write-Host "Authorization Correlation"
        Write-Host "----------------------------------------"
        Write-Host "Active Role Assignments       : $($directoryRoles.Count)"
        Write-Host "User Role Assignments         : $($userRoleAssignments.Count)"
        Write-Host "Group Role Assignments        : $($groupRoleAssignments.Count)"
        Write-Host "Service Principal Assignments : $($servicePrincipalRoleAssignments.Count)"
        Write-Host "Deprecated Role Assignments   : $($deprecatedRoleAssignments.Count)"
        Write-Host "Assignments Requiring Review  : $($roleAssignmentsRequiringReview.Count)"
        Write-Host "High-Severity Findings        : $($highSeverityAuthorizationFindings.Count)"
        Write-Host "Medium-Severity Findings      : $($mediumSeverityAuthorizationFindings.Count)"

        Write-Host ""
        Write-Host "Correlation Controls"
        Write-Host "----------------------------------------"

        $checks |
            Format-Table `
                Name,
                Status,
                Points,
                MaximumPoints,
                Details `
                -AutoSize

        Write-Host ""
        Write-Host "Correlation Confidence        : $score%" -ForegroundColor Green
        Write-Host "Correlation Health            : $health"
        Write-Host "Passed                        : $passed"
        Write-Host "Warnings                      : $warnings"
        Write-Host "Failed                        : $failed"

        if ($attentionRequired.Count -gt 0) {
            Write-Host ""
            Write-Host "Identities Requiring Attention" -ForegroundColor Yellow
            Write-Host "----------------------------------------"

            $attentionRequired |
                Select-Object `
                    DisplayName,
                    UserPrincipalName,
                    IsPrivileged,
                    IsMfaRegistered,
                    IsPasswordlessCapable,
                    @{
                        Name = "Reasons"
                        Expression = {
                            @($_.AttentionReasons) -join "; "
                        }
                    } |
                Format-Table -AutoSize
        }

        if ($roleAssignmentsRequiringReview.Count -gt 0) {
            Write-Host ""
            Write-Host "Authorization Assignments Requiring Review" -ForegroundColor Yellow
            Write-Host "----------------------------------------"

            $roleAssignmentsRequiringReview |
                Select-Object `
                    RoleName,
                    PrincipalName,
                    PrincipalType,
                    Severity,
                    @{
                        Name = "ReviewReasons"
                        Expression = {
                            @($_.ReviewReasons) -join "; "
                        }
                    } |
                Format-Table -AutoSize
        }

        if ($recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "Recommendations" -ForegroundColor Yellow

            foreach ($recommendation in $recommendations) {
                Write-Host "- $recommendation"
            }
        }

        if ($ExportJson) {
            if (-not (Test-Path $OutputPath)) {
                New-Item `
                    -Path $OutputPath `
                    -ItemType Directory `
                    -Force |
                    Out-Null
            }

            $report = [PSCustomObject]@{
                Platform    = "Blackknight One"
                Version     = "0.5.0-alpha"
                GeneratedAt = (
                    Get-Date
                ).ToUniversalTime().ToString("o")

                Result = $result
                Checks = $checks

                Summary = [PSCustomObject]@{
                    TotalIdentities          = $totalUsers
                    EnabledIdentities        = $enabledUsers.Count
                    DisabledIdentities       = $disabledUsers.Count
                    AdministrativeIdentities = $administrativeUsers.Count
                    PrivilegedUsers          = $privilegedUsers.Count

                    CorrelationCoverage = $correlationCoverage

                    UsersWithoutMfa            = $usersWithoutMfa.Count
                    AdminsWithoutMfa            = $adminsWithoutMfa.Count
                    PrivilegedUsersWithoutMfa  = $privilegedUsersWithoutMfa.Count
                    PasswordlessCapable        = $passwordlessUsers.Count
                    UsersWithoutPasswordless   = $usersWithoutPasswordless.Count
                    UsersWithoutSspr           = $usersWithoutSspr.Count
                    AttentionRequired          = $attentionRequired.Count

                    ActiveRoleAssignments =
                        $directoryRoles.Count

                    UserRoleAssignments =
                        $userRoleAssignments.Count

                    GroupRoleAssignments =
                        $groupRoleAssignments.Count

                    ServicePrincipalRoleAssignments =
                        $servicePrincipalRoleAssignments.Count

                    DeprecatedRoleAssignments =
                        $deprecatedRoleAssignments.Count

                    RoleAssignmentsRequiringReview =
                        $roleAssignmentsRequiringReview.Count

                    HighSeverityAuthorizationFindings =
                        $highSeverityAuthorizationFindings.Count

                    MediumSeverityAuthorizationFindings =
                        $mediumSeverityAuthorizationFindings.Count
                }

                Identities = $identities

                DirectoryRoleAssignments = $directoryRoles
            }

            $jsonPath = Join-Path `
                $OutputPath `
                "identity-graph.json"

            Export-BKJsonReport `
                -Data $report `
                -Path $jsonPath
        }

        Write-BKCorrelationSection "Correlation Engine Complete"

        return $result
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}

Invoke-BKCorrelation