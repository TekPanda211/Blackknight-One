function Get-BKConditionalAccessPolicies {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting Conditional Access policies..." -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Policy.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $policies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop

        $policies | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                DisplayName     = $_.DisplayName
                State           = $_.State
                CreatedDateTime = $_.CreatedDateTime
                ModifiedDateTime= $_.ModifiedDateTime
                Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}