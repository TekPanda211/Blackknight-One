function Get-BKIdentityGraph {
    <#
    .SYNOPSIS
    Builds a normalized identity graph for Blackknight One.

    .DESCRIPTION
    Correlates Microsoft Entra user inventory with authentication
    registration data using the user object ID and user principal name.

    This initial version correlates:
    - User identity
    - Account state
    - User type
    - Department and job title
    - Administrative status
    - MFA registration and capability
    - Passwordless capability
    - SSPR registration and capability
    - Registered authentication methods
    - Preferred authentication methods
    #>

    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Building Blackknight identity graph..." -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "User.Read.All",
                "Directory.Read.All",
                "AuditLog.Read.All"
            ) | Out-Null
        }

        $users = @(
            Get-BKUsers -SkipGraphConnect
        )

        $authenticationDetails = @(
            Get-MgReportAuthenticationMethodUserRegistrationDetail `
                -All `
                -ErrorAction Stop
        )

        $authenticationById = @{}
        $authenticationByUpn = @{}

        foreach ($authenticationRecord in $authenticationDetails) {
            if (
                $authenticationRecord.Id -and
                -not $authenticationById.ContainsKey(
                    [string]$authenticationRecord.Id
                )
            ) {
                $authenticationById[
                    [string]$authenticationRecord.Id
                ] = $authenticationRecord
            }

            if ($authenticationRecord.UserPrincipalName) {
                $normalizedUpn =
                    $authenticationRecord.UserPrincipalName.ToLowerInvariant()

                if (-not $authenticationByUpn.ContainsKey($normalizedUpn)) {
                    $authenticationByUpn[$normalizedUpn] =
                        $authenticationRecord
                }
            }
        }

        $identityGraph = foreach ($user in $users) {
            $authentication = $null

            if (
                $user.Id -and
                $authenticationById.ContainsKey([string]$user.Id)
            ) {
                $authentication =
                    $authenticationById[[string]$user.Id]
            }
            elseif ($user.UserPrincipalName) {
                $normalizedUpn =
                    $user.UserPrincipalName.ToLowerInvariant()

                if ($authenticationByUpn.ContainsKey($normalizedUpn)) {
                    $authentication =
                        $authenticationByUpn[$normalizedUpn]
                }
            }

            $registeredMethods = if ($authentication) {
                @($authentication.MethodsRegistered)
            }
            else {
                @()
            }

            $systemPreferredMethods = if ($authentication) {
                @($authentication.SystemPreferredAuthenticationMethods)
            }
            else {
                @()
            }

            $attentionReasons = @()

            if ($user.AccountEnabled -ne $true) {
                $attentionReasons += "Account disabled"
            }

            if (
                $authentication -and
                $authentication.IsMfaRegistered -ne $true
            ) {
                $attentionReasons += "MFA not registered"
            }

            if (
                $authentication -and
                $authentication.IsAdmin -eq $true -and
                $authentication.IsMfaRegistered -ne $true
            ) {
                $attentionReasons += "Administrative user without MFA"
            }

            if (
                $authentication -and
                $authentication.IsPasswordlessCapable -ne $true
            ) {
                $attentionReasons += "Not passwordless capable"
            }

            if (
                $authentication -and
                $authentication.IsSsprRegistered -ne $true
            ) {
                $attentionReasons += "SSPR not registered"
            }

            if (-not $authentication) {
                $attentionReasons += "Authentication report data unavailable"
            }

            [PSCustomObject]@{
                Id = $user.Id
                DisplayName = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                UserType = $user.UserType
                AccountEnabled = $user.AccountEnabled
                Department = $user.Department
                JobTitle = $user.JobTitle
                CompanyName = $user.CompanyName
                EmployeeId = $user.EmployeeId
                CreatedDate = $user.CreatedDate

                IsAdmin = if ($authentication) {
                    $authentication.IsAdmin
                }
                else {
                    $null
                }

                IsMfaRegistered = if ($authentication) {
                    $authentication.IsMfaRegistered
                }
                else {
                    $null
                }

                IsMfaCapable = if ($authentication) {
                    $authentication.IsMfaCapable
                }
                else {
                    $null
                }

                IsPasswordlessCapable = if ($authentication) {
                    $authentication.IsPasswordlessCapable
                }
                else {
                    $null
                }

                IsSsprRegistered = if ($authentication) {
                    $authentication.IsSsprRegistered
                }
                else {
                    $null
                }

                IsSsprCapable = if ($authentication) {
                    $authentication.IsSsprCapable
                }
                else {
                    $null
                }

                IsSsprEnabled = if ($authentication) {
                    $authentication.IsSsprEnabled
                }
                else {
                    $null
                }

                IsSystemPreferredAuthenticationMethodEnabled =
                    if ($authentication) {
                        $authentication.
                            IsSystemPreferredAuthenticationMethodEnabled
                    }
                    else {
                        $null
                    }

                RegisteredMethods = $registeredMethods

                PreferredSecondaryMethod = if ($authentication) {
                    $authentication.
                        UserPreferredMethodForSecondaryAuthentication
                }
                else {
                    $null
                }

                SystemPreferredMethods = $systemPreferredMethods

                AuthenticationLastUpdated = if ($authentication) {
                    $authentication.LastUpdatedDateTime
                }
                else {
                    $null
                }

                RequiresAttention = $attentionReasons.Count -gt 0
                AttentionReasons = $attentionReasons

                Timestamp = (Get-Date).
                    ToUniversalTime().
                    ToString("o")
            }
        }

        return @($identityGraph)
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}