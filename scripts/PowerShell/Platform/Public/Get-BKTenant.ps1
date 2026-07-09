function Get-BKTenant {

    [CmdletBinding()]
    param()

    Write-BKLog -Message "Building tenant summary..." -Level Info

    try {

        Connect-BKGraph -Scopes @(
            "Organization.Read.All",
            "Directory.Read.All",
            "Domain.Read.All",
            "User.Read.All",
            "Group.Read.All"
        ) | Out-Null

        $organization = Get-BKOrganization -SkipGraphConnect
        $domains      = Get-BKDomains -SkipGraphConnect
        $users        = Get-BKUsers -SkipGraphConnect
        $groups       = Get-BKGroups -SkipGraphConnect
        $licensing    = Get-BKLicensing -SkipGraphConnect

        $enabledUsers        = $users | Where-Object { $_.AccountEnabled }
        $disabledUsers       = $users | Where-Object { -not $_.AccountEnabled }
        $guestUsers          = $users | Where-Object { $_.UserType -eq "Guest" }

        $securityGroups      = $groups | Where-Object { $_.SecurityEnabled }
        $roleAssignableGroups = $groups | Where-Object { $_.AssignableToRole }

        [PSCustomObject]@{
            TenantName           = $organization.DisplayName
            TenantId             = $organization.Id
            VerifiedDomains      = ($domains | Where-Object { $_.IsVerified }).Count
            InitialDomain        = ($domains | Where-Object { $_.IsInitial }).Id
            TotalUsers           = $users.Count
            EnabledUsers         = $enabledUsers.Count
            DisabledUsers        = $disabledUsers.Count
            GuestUsers           = $guestUsers.Count
            TotalGroups          = $groups.Count
            SecurityGroups       = $securityGroups.Count
            RoleAssignableGroups = $roleAssignableGroups.Count
            SubscribedSkus       = $licensing.Count
            Timestamp            = (Get-Date).ToUniversalTime().ToString("o")
        }

    }
    catch {

        Write-BKLog -Message $_.Exception.Message -Level Error
        throw

    }

}