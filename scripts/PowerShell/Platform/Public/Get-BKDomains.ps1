function Get-BKDomains {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting domain information..." -Level Info

    try {

        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Organization.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $organization = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1

        $domains = Get-MgDomain -All -ErrorAction Stop

        $domains | ForEach-Object {
            [PSCustomObject]@{
                Id                 = $_.Id
                IsInitial          = $_.IsInitial
                IsDefault          = $_.IsDefault
                IsVerified         = $_.IsVerified
                AuthenticationType = $_.AuthenticationType
                SupportedServices  = ($_.SupportedServices -join ", ")
                Timestamp          = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}