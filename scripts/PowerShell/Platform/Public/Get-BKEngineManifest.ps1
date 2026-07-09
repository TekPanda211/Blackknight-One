function Get-BKEngineManifest {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting engine manifests..." -Level Info

    $repoRoot = (Get-Location).Path
    $config = Get-BKPlatformConfiguration
    $engineRoot = Join-Path $repoRoot $config.EngineRoot

    $manifestFiles = Get-ChildItem -Path $engineRoot -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue

    foreach ($manifestFile in $manifestFiles) {
        try {
            $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
            $engineFolder = Split-Path $manifestFile.FullName -Parent
            $entryPoint = Join-Path $engineFolder $manifest.EntryPoint

            [PSCustomObject]@{
                Name             = $manifest.Name
                DisplayName      = $manifest.DisplayName
                Version          = $manifest.Version
                Status           = $manifest.Status
                Enabled          = $manifest.Enabled
                Category         = $manifest.Category
                EntryPoint       = $entryPoint
                ProducesReport   = $manifest.ProducesReport
                ReportName       = $manifest.ReportName
                ConfidenceModel  = $manifest.ConfidenceModel
                Dependencies     = ($manifest.Dependencies -join ", ")
                DependencyCount  = ($manifest.Dependencies | Measure-Object).Count
                Capabilities     = ($manifest.Capabilities -join ", ")
                CapabilityCount  = ($manifest.Capabilities | Measure-Object).Count
                Description      = $manifest.Description
                ManifestPath     = $manifestFile.FullName
                Timestamp        = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
        catch {
            Write-BKLog -Message "Failed to read engine manifest: $($manifestFile.FullName)" -Level Error
            throw
        }
    }
}