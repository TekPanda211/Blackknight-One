function Get-BKNamedLocations {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting Conditional Access named locations..." -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Policy.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $locations = Get-MgIdentityConditionalAccessNamedLocation -All -ErrorAction Stop

        $locations | ForEach-Object {
            [PSCustomObject]@{
                Id          = $_.Id
                DisplayName = $_.DisplayName
                CreatedDate = $_.CreatedDateTime
                ModifiedDate= $_.ModifiedDateTime
                Type        = $_.AdditionalProperties.'@odata.type'
                Timestamp   = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}