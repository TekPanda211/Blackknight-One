function Get-BKLicensing {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting licensing information..." -Level Info

    try {

        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Organization.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $organization = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1

        $skus = Get-MgSubscribedSku -All -ErrorAction Stop

        $skus | ForEach-Object {
            [PSCustomObject]@{
                SkuId             = $_.SkuId
                SkuPartNumber     = $_.SkuPartNumber
                ConsumedUnits     = $_.ConsumedUnits
                EnabledUnits      = $_.PrepaidUnits.Enabled
                SuspendedUnits    = $_.PrepaidUnits.Suspended
                WarningUnits      = $_.PrepaidUnits.Warning
                AppliesTo         = $_.AppliesTo
                Timestamp         = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}