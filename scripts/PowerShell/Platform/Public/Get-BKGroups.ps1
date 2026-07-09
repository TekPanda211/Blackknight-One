function Get-BKGroups {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting groups information..." -Level Info

    try {

        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Organization.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $organization = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1

        $groups = Get-MgGroup -All -Property `
            Id,
            DisplayName,
            Description,
            SecurityEnabled,
            MailEnabled,
            MailNickname,
            GroupTypes,
            Visibility,
            CreatedDateTime,
            AssignableToRole

        $groups | ForEach-Object {
            [PSCustomObject]@{
                Id                 = $_.Id
                DisplayName        = $_.DisplayName
                Description        = $_.Description
                SecurityEnabled    = $_.SecurityEnabled
                MailEnabled        = $_.MailEnabled
                MailNickname       = $_.MailNickname
                GroupTypes         = ($_.GroupTypes -join ", ")
                Visibility         = $_.Visibility
                CreatedDate        = $_.CreatedDateTime
                AssignableToRole   = $_.AssignableToRole
                Timestamp          = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}