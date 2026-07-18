function Invoke-BKRegisteredEngine {
    <#
    .SYNOPSIS
    Invokes a registered Blackknight engine through the public platform API.

    .DESCRIPTION
    Separates dispatcher parameters from engine-operation parameters and routes
    execution through the internal Shared Framework engine runtime.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Operation = 'Assessment',

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [switch]$PassThru
    )

    Invoke-BKEngine `
        -Name $Name `
        -Operation $Operation `
        -Parameters $Parameters `
        -PassThru:$PassThru.IsPresent
}
