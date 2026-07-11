function Find-BKDirectoryRoleAssignment {
    <#
    .SYNOPSIS
    Searches active Microsoft Entra directory-role assignments.

    .DESCRIPTION
    Filters normalized directory-role assignment data returned by
    Get-BKDirectoryRoles.

    Supports filtering by role name, principal name, principal type,
    severity, deprecated status, review status, and assignment scope.

    .PARAMETER Search
    Searches role name, principal name, principal ID, role definition ID,
    and review reasons.

    .PARAMETER RoleName
    Filters by role name.

    .PARAMETER PrincipalName
    Filters by principal display name.

    .PARAMETER PrincipalType
    Filters by User, Group, ServicePrincipal, or Unresolved.

    .PARAMETER Severity
    Filters by None, Informational, Medium, or High.

    .PARAMETER Deprecated
    Returns deprecated role assignments.

    .PARAMETER RequiresReview
    Returns assignments requiring review.

    .PARAMETER TenantWide
    Returns tenant-wide assignments where DirectoryScopeId is "/".

    .PARAMETER SkipGraphConnect
    Reuses an existing Microsoft Graph connection.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Search,

        [string]$RoleName,

        [string]$PrincipalName,

        [ValidateSet(
            "User",
            "Group",
            "ServicePrincipal",
            "Unresolved"
        )]
        [string]$PrincipalType,

        [ValidateSet(
            "None",
            "Informational",
            "Medium",
            "High"
        )]
        [string]$Severity,

        [switch]$Deprecated,

        [switch]$RequiresReview,

        [switch]$TenantWide,

        [switch]$SkipGraphConnect
    )

    Write-BKLog `
        -Message "Searching Microsoft Entra directory-role assignments..." `
        -Level Info

    try {
        $parameters = @{}

        if ($SkipGraphConnect) {
            $parameters.SkipGraphConnect = $true
        }

        $results = @(
            Get-BKDirectoryRoles @parameters
        )

        if (-not [string]::IsNullOrWhiteSpace($Search)) {
            $searchValue = $Search.Trim()

            $results = @(
                $results |
                    Where-Object {
                        (
                            $_.RoleName -and
                            $_.RoleName -like "*$searchValue*"
                        ) -or
                        (
                            $_.PrincipalName -and
                            $_.PrincipalName -like "*$searchValue*"
                        ) -or
                        (
                            $_.PrincipalId -and
                            $_.PrincipalId -like "*$searchValue*"
                        ) -or
                        (
                            $_.RoleDefinitionId -and
                            $_.RoleDefinitionId -like "*$searchValue*"
                        ) -or
                        (
                            @($_.ReviewReasons) -join "; " -like
                            "*$searchValue*"
                        )
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($RoleName)) {
            $results = @(
                $results |
                    Where-Object {
                        $_.RoleName -like "*$RoleName*"
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($PrincipalName)) {
            $results = @(
                $results |
                    Where-Object {
                        $_.PrincipalName -like "*$PrincipalName*"
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($PrincipalType)) {
            $results = @(
                $results |
                    Where-Object {
                        $_.PrincipalType -eq $PrincipalType
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($Severity)) {
            $results = @(
                $results |
                    Where-Object {
                        $_.Severity -eq $Severity
                    }
            )
        }

        if ($Deprecated) {
            $results = @(
                $results |
                    Where-Object {
                        $_.IsDeprecated -eq $true
                    }
            )
        }

        if ($RequiresReview) {
            $results = @(
                $results |
                    Where-Object {
                        $_.RequiresReview -eq $true
                    }
            )
        }

        if ($TenantWide) {
            $results = @(
                $results |
                    Where-Object {
                        $_.DirectoryScopeId -eq "/"
                    }
            )
        }

        return @(
            $results |
                Sort-Object `
                    @{
                        Expression = {
                            switch ($_.Severity) {
                                "High" { 1 }
                                "Medium" { 2 }
                                "Informational" { 3 }
                                default { 4 }
                            }
                        }
                    },
                    RoleName,
                    PrincipalName
        )
    }
    catch {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error

        throw
    }
}