function Get-BKOrganization {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting organization information..." -Level Info

    try {

        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Organization.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $organization = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1

        [PSCustomObject]@{
            DisplayName = $organization.DisplayName
            Id          = $organization.Id
            TenantType  = $organization.TenantType
            City        = $organization.City
            State       = $organization.State
            Country     = $organization.Country
            CreatedDate = $organization.CreatedDateTime
            Timestamp   = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}