function Get-BKAuthenticationMethodsSummary {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect,
        [switch]$IncludeUsers
    )

    Write-BKLog -Message "Collecting authentication methods registration summary..." -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "AuditLog.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop

        $totalUsers = ($details | Measure-Object).Count
        $adminUsers = ($details | Where-Object { $_.IsAdmin -eq $true } | Measure-Object).Count
        $memberUsers = ($details | Where-Object { $_.UserType -eq "member" -or $_.UserType -eq "Member" } | Measure-Object).Count
        $guestUsers = ($details | Where-Object { $_.UserType -eq "guest" -or $_.UserType -eq "Guest" } | Measure-Object).Count

        $mfaRegistered = ($details | Where-Object { $_.IsMfaRegistered -eq $true } | Measure-Object).Count
        $mfaCapable = ($details | Where-Object { $_.IsMfaCapable -eq $true } | Measure-Object).Count
        $passwordlessCapable = ($details | Where-Object { $_.IsPasswordlessCapable -eq $true } | Measure-Object).Count
        $ssprRegistered = ($details | Where-Object { $_.IsSsprRegistered -eq $true } | Measure-Object).Count
        $ssprCapable = ($details | Where-Object { $_.IsSsprCapable -eq $true } | Measure-Object).Count
        $ssprEnabled = ($details | Where-Object { $_.IsSsprEnabled -eq $true } | Measure-Object).Count
        $systemPreferredEnabled = ($details | Where-Object { $_.IsSystemPreferredAuthenticationMethodEnabled -eq $true } | Measure-Object).Count

        function Get-BKPercent {
            param(
                [int]$Value,
                [int]$Total
            )

            if ($Total -gt 0) {
                return [math]::Round(($Value / $Total) * 100, 2)
            }

            return 0
        }

        $registeredMethods = $details |
            ForEach-Object { $_.MethodsRegistered } |
            Where-Object { $_ } |
            Group-Object |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Method  = $_.Name
                    Count   = $_.Count
                    Percent = Get-BKPercent -Value $_.Count -Total $totalUsers
                }
            }

        $preferredMethods = $details |
            Where-Object { $_.UserPreferredMethodForSecondaryAuthentication } |
            Group-Object UserPreferredMethodForSecondaryAuthentication |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Method  = $_.Name
                    Count   = $_.Count
                    Percent = Get-BKPercent -Value $_.Count -Total $totalUsers
                }
            }

        $systemPreferredMethods = $details |
            ForEach-Object { $_.SystemPreferredAuthenticationMethods } |
            Where-Object { $_ } |
            Group-Object |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Method  = $_.Name
                    Count   = $_.Count
                    Percent = Get-BKPercent -Value $_.Count -Total $totalUsers
                }
            }

        $usersWithoutMfa = $details |
            Where-Object { $_.IsMfaRegistered -ne $true } |
            Select-Object UserPrincipalName, UserDisplayName, UserType, IsAdmin, IsMfaRegistered, IsMfaCapable, MethodsRegistered

        $adminsWithoutMfa = $details |
            Where-Object { $_.IsAdmin -eq $true -and $_.IsMfaRegistered -ne $true } |
            Select-Object UserPrincipalName, UserDisplayName, UserType, IsAdmin, IsMfaRegistered, IsMfaCapable, MethodsRegistered

        $usersWithoutPasswordless = $details |
            Where-Object { $_.IsPasswordlessCapable -ne $true } |
            Select-Object UserPrincipalName, UserDisplayName, UserType, IsAdmin, IsPasswordlessCapable, MethodsRegistered

        $summary = [PSCustomObject]@{
            TotalUsers                         = $totalUsers
            MemberUsers                        = $memberUsers
            GuestUsers                         = $guestUsers
            AdminUsers                         = $adminUsers

            MfaRegistered                      = $mfaRegistered
            MfaRegisteredPercent               = Get-BKPercent -Value $mfaRegistered -Total $totalUsers
            MfaCapable                         = $mfaCapable
            MfaCapablePercent                  = Get-BKPercent -Value $mfaCapable -Total $totalUsers

            PasswordlessCapable                = $passwordlessCapable
            PasswordlessCapablePercent         = Get-BKPercent -Value $passwordlessCapable -Total $totalUsers

            SsprRegistered                     = $ssprRegistered
            SsprRegisteredPercent              = Get-BKPercent -Value $ssprRegistered -Total $totalUsers
            SsprCapable                        = $ssprCapable
            SsprCapablePercent                 = Get-BKPercent -Value $ssprCapable -Total $totalUsers
            SsprEnabled                        = $ssprEnabled
            SsprEnabledPercent                 = Get-BKPercent -Value $ssprEnabled -Total $totalUsers

            SystemPreferredEnabled             = $systemPreferredEnabled
            SystemPreferredEnabledPercent      = Get-BKPercent -Value $systemPreferredEnabled -Total $totalUsers

            UsersWithoutMfa                    = ($usersWithoutMfa | Measure-Object).Count
            AdminsWithoutMfa                   = ($adminsWithoutMfa | Measure-Object).Count
            UsersWithoutPasswordless           = ($usersWithoutPasswordless | Measure-Object).Count

            RegisteredMethods                  = $registeredMethods
            PreferredSecondaryMethods          = $preferredMethods
            SystemPreferredAuthenticationMethods = $systemPreferredMethods

            Timestamp                          = (Get-Date).ToUniversalTime().ToString("o")
        }

        if ($IncludeUsers) {
            $summary | Add-Member -MemberType NoteProperty -Name UserDetails -Value ($details | Select-Object `
                UserPrincipalName,
                UserDisplayName,
                UserType,
                IsAdmin,
                IsMfaRegistered,
                IsMfaCapable,
                IsPasswordlessCapable,
                IsSsprRegistered,
                IsSsprCapable,
                IsSsprEnabled,
                IsSystemPreferredAuthenticationMethodEnabled,
                MethodsRegistered,
                UserPreferredMethodForSecondaryAuthentication,
                SystemPreferredAuthenticationMethods,
                LastUpdatedDateTime
            )

            $summary | Add-Member -MemberType NoteProperty -Name UsersWithoutMfaDetails -Value $usersWithoutMfa
            $summary | Add-Member -MemberType NoteProperty -Name AdminsWithoutMfaDetails -Value $adminsWithoutMfa
            $summary | Add-Member -MemberType NoteProperty -Name UsersWithoutPasswordlessDetails -Value $usersWithoutPasswordless
        }

        return $summary
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}