function Invoke-BKAssessmentCore {
    [CmdletBinding()]
    param(
        [string[]]$Engine,
        [object]$Context,
        [switch]$ContinueOnError,
        [switch]$SkipCorrelation,
        [switch]$SkipRisk,
        [switch]$PassThru
    )

    if (-not $Context) { $Context = New-BKAssessmentContextCore }
    $Context.Status = 'Running'
    $registry = @(Get-BKEngineRegistry -Refresh)
    if ($Engine) { $registry = @($registry | Where-Object { $_.Name -in $Engine }) }
    else { $registry = @($registry | Where-Object { $_.IsValid -and $_.Operations.Assessment }) }

    foreach ($item in $registry) {
        try {
            $result = Invoke-BKRegisteredEngine -Name $item.Name -Operation Assessment -PassThru
            if ($null -ne $result) { [void](Add-BKAssessmentResult -Context $Context -Result $result) }
        }
        catch {
            $errorRecord = [PSCustomObject]@{ Engine=$item.Name; Message=$_.Exception.Message; At=[DateTimeOffset]::UtcNow }
            [void]$Context.Errors.Add($errorRecord)
            if (-not $ContinueOnError) { $Context.Status='Failed'; throw }
        }
    }

    if (-not $SkipCorrelation) { [void](Invoke-BKCorrelationCore -Context $Context) }
    $risk = if (-not $SkipRisk) { Invoke-BKRiskAssessmentCore -Context $Context } else { $null }
    $Context.CompletedAt = [DateTimeOffset]::UtcNow
    $Context.Status = if ($Context.Errors.Count -gt 0) { 'CompletedWithErrors' } else { 'Complete' }

    $output = [PSCustomObject]@{
        PSTypeName   = 'Blackknight.PlatformAssessment'
        Context      = $Context
        Tenant       = $Context.Tenant
        Results      = @($Context.Results)
        Correlations = @($Context.Correlations)
        Risk         = $risk
        Errors       = @($Context.Errors)
    }
    if ($PassThru) { return $output }
    $output
}

