function Get-BKUsers {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting user information..." -Level Info

    try {

        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "Organization.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $organization = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1

        $users = Get-MgUser -All -Property `
            Id,
            DisplayName,
            UserPrincipalName,
            UserType,
            AccountEnabled,
            Department,
            JobTitle,
            CompanyName,
            EmployeeId,
            CreatedDateTime

        $users | ForEach-Object {

            [PSCustomObject]@{
                Id               = $_.Id
                DisplayName      = $_.DisplayName
                UserPrincipalName= $_.UserPrincipalName
                UserType         = $_.UserType
                AccountEnabled   = $_.AccountEnabled
                Department       = $_.Department
                JobTitle         = $_.JobTitle
                CompanyName      = $_.CompanyName
                EmployeeId       = $_.EmployeeId
                CreatedDate      = $_.CreatedDateTime
                Timestamp        = (Get-Date).ToUniversalTime().ToString("o")
            }

        }

    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}