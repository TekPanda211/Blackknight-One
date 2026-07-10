function Show-BKAuthenticationMethodsSummary {
    <#
    .SYNOPSIS
    Displays a readable Microsoft Entra authentication methods summary.

    .DESCRIPTION
    Uses Get-BKAuthenticationMethodsSummary to display MFA, passwordless,
    SSPR, registered methods, preferred methods, and users requiring attention.

    .PARAMETER IncludeUsers
    Displays user-level authentication registration details.

    .PARAMETER AttentionOnly
    Displays only users requiring attention, including users without MFA
    and users without passwordless capability.
    #>

    [CmdletBinding()]
    param(
        [switch]$IncludeUsers,
        [switch]$AttentionOnly
    )

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "        Blackknight Authentication Methods Summary" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan

    try {
        $summary = Get-BKAuthenticationMethodsSummary -IncludeUsers

        function Format-BKPercentage {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value) {
                return "Not Available"
            }

            return "$Value%"
        }

        function Get-BKMetricColor {
            param(
                [AllowNull()]
                [object]$Value
            )

            if ($null -eq $Value) {
                return "DarkGray"
            }

            $numericValue = [double]$Value

            if ($numericValue -ge 90) {
                return "Green"
            }

            if ($numericValue -ge 70) {
                return "Yellow"
            }

            return "Red"
        }

        function Write-BKMetricRow {
            param(
                [Parameter(Mandatory)]
                [string]$Label,

                [AllowNull()]
                [object]$Value,

                [switch]$Percentage
            )

            $displayValue = if ($Percentage) {
                Format-BKPercentage -Value $Value
            }
            elseif ($null -eq $Value) {
                "Not Available"
            }
            else {
                [string]$Value
            }

            Write-Host $Label.PadRight(34) -NoNewline

            if ($Percentage) {
                Write-Host $displayValue `
                    -ForegroundColor (Get-BKMetricColor -Value $Value)
            }
            else {
                Write-Host $displayValue
            }
        }

        Write-Host ""
        Write-Host "Directory Population" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        Write-BKMetricRow -Label "Total Users" -Value $summary.TotalUsers
        Write-BKMetricRow -Label "Member Users" -Value $summary.MemberUsers
        Write-BKMetricRow -Label "Guest Users" -Value $summary.GuestUsers
        Write-BKMetricRow -Label "Administrative Users" -Value $summary.AdminUsers

        Write-Host ""
        Write-Host "Authentication Readiness" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        Write-BKMetricRow `
            -Label "MFA Registered" `
            -Value $summary.MfaRegisteredPercent `
            -Percentage

        Write-BKMetricRow `
            -Label "MFA Capable" `
            -Value $summary.MfaCapablePercent `
            -Percentage

        Write-BKMetricRow `
            -Label "Passwordless Capable" `
            -Value $summary.PasswordlessCapablePercent `
            -Percentage

        Write-BKMetricRow `
            -Label "SSPR Registered" `
            -Value $summary.SsprRegisteredPercent `
            -Percentage

        Write-BKMetricRow `
            -Label "SSPR Capable" `
            -Value $summary.SsprCapablePercent `
            -Percentage

        Write-BKMetricRow `
            -Label "SSPR Enabled" `
            -Value $summary.SsprEnabledPercent `
            -Percentage

        Write-BKMetricRow `
            -Label "System-Preferred Authentication" `
            -Value $summary.SystemPreferredEnabledPercent `
            -Percentage

        Write-Host ""
        Write-Host "Attention Required" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        Write-BKMetricRow `
            -Label "Users Without MFA" `
            -Value $summary.UsersWithoutMfa

        Write-BKMetricRow `
            -Label "Admins Without MFA" `
            -Value $summary.AdminsWithoutMfa

        Write-BKMetricRow `
            -Label "Users Without Passwordless" `
            -Value $summary.UsersWithoutPasswordless

        Write-Host ""
        Write-Host "Registered Authentication Methods" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        if (@($summary.RegisteredMethods).Count -gt 0) {
            $summary.RegisteredMethods |
                Select-Object Method, Count, Percent |
                Format-Table -AutoSize
        }
        else {
            Write-Host "No registered authentication methods were reported." `
                -ForegroundColor DarkGray
        }

        Write-Host "Preferred Secondary Methods" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        if (@($summary.PreferredSecondaryMethods).Count -gt 0) {
            $summary.PreferredSecondaryMethods |
                Select-Object Method, Count, Percent |
                Format-Table -AutoSize
        }
        else {
            Write-Host "No preferred secondary methods were reported." `
                -ForegroundColor DarkGray
        }

        Write-Host "System-Preferred Methods" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------"

        if (@($summary.SystemPreferredAuthenticationMethods).Count -gt 0) {
            $summary.SystemPreferredAuthenticationMethods |
                Select-Object Method, Count, Percent |
                Format-Table -AutoSize
        }
        else {
            Write-Host "No system-preferred methods were reported." `
                -ForegroundColor DarkGray
        }

        if ($AttentionOnly -or $IncludeUsers) {
            Write-Host ""
            Write-Host "Users Without MFA" -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------------"

            if (@($summary.UsersWithoutMfaDetails).Count -gt 0) {
                $summary.UsersWithoutMfaDetails |
                    Select-Object `
                        UserDisplayName,
                        UserPrincipalName,
                        UserType,
                        IsAdmin,
                        @{
                            Name = "MethodsRegistered"
                            Expression = {
                                @($_.MethodsRegistered) -join ", "
                            }
                        } |
                    Format-Table -AutoSize
            }
            else {
                Write-Host "All reported users are registered for MFA." `
                    -ForegroundColor Green
            }

            Write-Host ""
            Write-Host "Administrative Users Without MFA" -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------------"

            if (@($summary.AdminsWithoutMfaDetails).Count -gt 0) {
                $summary.AdminsWithoutMfaDetails |
                    Select-Object `
                        UserDisplayName,
                        UserPrincipalName,
                        UserType,
                        @{
                            Name = "MethodsRegistered"
                            Expression = {
                                @($_.MethodsRegistered) -join ", "
                            }
                        } |
                    Format-Table -AutoSize
            }
            else {
                Write-Host "All reported administrative users are registered for MFA." `
                    -ForegroundColor Green
            }
        }

        if ($IncludeUsers -and -not $AttentionOnly) {
            Write-Host ""
            Write-Host "User Authentication Registration Details" -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------------"

            $summary.UserDetails |
                Select-Object `
                    UserDisplayName,
                    UserPrincipalName,
                    UserType,
                    IsAdmin,
                    IsMfaRegistered,
                    IsPasswordlessCapable,
                    IsSsprRegistered,
                    @{
                        Name = "MethodsRegistered"
                        Expression = {
                            @($_.MethodsRegistered) -join ", "
                        }
                    },
                    UserPreferredMethodForSecondaryAuthentication |
                Format-Table -AutoSize
        }

        Write-Host ""
        Write-Host "Generated: $($summary.Timestamp)" -ForegroundColor DarkGray
        Write-Host "==============================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}