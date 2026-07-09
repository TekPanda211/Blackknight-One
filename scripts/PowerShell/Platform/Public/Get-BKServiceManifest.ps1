function Get-BKServiceManifest {
    [CmdletBinding()]
    param()

    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $manifestPath = Join-Path $moduleRoot "Services\services.json"

    if (!(Test-Path $manifestPath)) {
        throw "Blackknight service manifest not found at $manifestPath"
    }

    Get-Content $manifestPath -Raw | ConvertFrom-Json
}