function Get-BKCapabilities {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting Blackknight platform capabilities..." -Level Info

    $engines = Get-BKEngineManifest

    foreach ($engine in $engines) {
        foreach ($capability in ($engine.Capabilities -split ", ")) {
            [PSCustomObject]@{
                Engine          = $engine.DisplayName
                Category        = $engine.Category
                EngineStatus    = $engine.Status
                Capability      = $capability
                ConfidenceModel = $engine.ConfidenceModel
                ProducesReport  = $engine.ProducesReport
                Version         = $engine.Version
                Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
}