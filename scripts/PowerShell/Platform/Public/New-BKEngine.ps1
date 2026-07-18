function New-BKEngine {
    <#
    .SYNOPSIS
    Creates a validated, manifest-driven Blackknight assessment engine scaffold.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]+$')]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [ValidatePattern('^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
        [string]$Version = "0.1.0",

        [Parameter()]
        [string[]]$RequiredScopes = @(),

        [Parameter()]
        [string[]]$Dependencies = @(),

        [Parameter()]
        [switch]$SupportsGraph,

        [Parameter()]
        [switch]$NoPublicWrapper,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    $powerShellRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\.."))
    $engineRoot = Join-Path -Path $powerShellRoot -ChildPath $Name
    $publicRoot = Join-Path -Path $powerShellRoot -ChildPath "Platform\Public"
    $assessmentCommand = "Invoke-BK${Name}Assessment"
    $discoveryCommand = "Invoke-BK${Name}Discovery"
    $analyzerCommand = "Invoke-BK${Name}Analyzer"
    $assessmentFile = "$assessmentCommand.ps1"
    $discoveryFile = "$discoveryCommand.ps1"
    $analyzerFile = "$analyzerCommand.ps1"
    $wrapperPath = Join-Path -Path $publicRoot -ChildPath $assessmentFile

    if ((Test-Path -LiteralPath $engineRoot) -and -not $Force.IsPresent) {
        throw "Engine folder already exists: $engineRoot. Use -Force to replace generated scaffold files."
    }

    if (-not $NoPublicWrapper.IsPresent -and (Test-Path -LiteralPath $wrapperPath) -and -not $Force.IsPresent) {
        throw "Public wrapper already exists: $wrapperPath. Use -Force to replace it."
    }

    if (-not $PSCmdlet.ShouldProcess($engineRoot, "Create Blackknight engine scaffold")) {
        return
    }

    foreach ($directory in @($engineRoot, (Join-Path $engineRoot "Private"), (Join-Path $engineRoot "Tests"))) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $operationParameters = [ordered]@{
        Assessment = [ordered]@{
            IncludeObjects = [ordered]@{ Type = "Switch"; Required = $false }
            ExportJson = [ordered]@{ Type = "Switch"; Required = $false }
            OutputPath = [ordered]@{ Type = "String"; Required = $false }
            PassThru = [ordered]@{ Type = "Switch"; Required = $false }
        }
        Discovery = [ordered]@{
            PassThru = [ordered]@{ Type = "Switch"; Required = $false }
        }
        Analyzer = [ordered]@{
            InputObject = [ordered]@{ Type = "Object"; Required = $false; ValueFromPipeline = $true }
            PassThru = [ordered]@{ Type = "Switch"; Required = $false }
        }
    }

    $manifest = [ordered]@{
        Name = $Name
        DisplayName = "$Name Assessment"
        Version = $Version
        SchemaVersion = "2.1"
        Category = $Category
        Description = $Description
        SupportsDashboard = $true
        SupportsJson = $true
        SupportsPassThru = $true
        SupportsGraph = $SupportsGraph.IsPresent
        EntryPoint = $assessmentFile
        EntryPoints = [ordered]@{
            Assessment = $assessmentFile
            Discovery = $discoveryFile
            Analyzer = $analyzerFile
        }
        OperationParameters = $operationParameters
        PublicCommands = if ($NoPublicWrapper.IsPresent) { @() } else { @($assessmentCommand) }
        Dependencies = @($Dependencies)
        RequiredScopes = @($RequiredScopes)
        Operations = @("Assessment", "Discovery", "Analyzer")
        Generator = [ordered]@{
            Name = "Blackknight Framework"
            Version = "0.8.2"
        }
    }

    $manifestPath = Join-Path -Path $engineRoot -ChildPath "engine.json"
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding utf8

    $assessmentContent = @"
[CmdletBinding()]
param(
    [Parameter()]
    [switch]`$IncludeObjects,

    [Parameter()]
    [switch]`$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]`$OutputPath = ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",

    [Parameter()]
    [switch]`$PassThru
)

`$ErrorActionPreference = "Stop"

try {
    `$findings = [System.Collections.Generic.List[object]]::new()

    # TODO: Collect and normalize $Name data.
    # TODO: Add findings with New-BKFinding.

    `$scoreParameters = @{
        Findings = @(`$findings)
    }
    `$score = Measure-BKScore @scoreParameters

    `$summary = [PSCustomObject]@{
        Status = "Complete"
        Health = `$score.Health
        Score = `$score.Score
        TotalFindings = `$findings.Count
    }

    `$assessmentParameters = @{
        Engine = "$Name"
        EngineVersion = "$Version"
        Category = "$Category"
        Operation = "${Name}Assessment"
        Summary = `$summary
        Scores = `$score
        Findings = @(`$findings)
        Metadata = @{
            EngineVersion = "$Version"
        }
        Confidence = 100
    }
    `$result = New-BKAssessmentResult @assessmentParameters

    if (`$IncludeObjects.IsPresent -and `$result.PSObject.Properties.Name -contains "Objects") {
        `$result.Objects = @()
    }

    if (`$ExportJson.IsPresent) {
        `$exportParameters = @{
            Path = `$OutputPath
        }
        `$result | Export-BKJson @exportParameters
    }

    if (`$PassThru.IsPresent) {
        return `$result
    }

    `$result | Write-BKAssessmentSummary
    `$result | Write-BKAssessmentFindings
    `$result | Write-BKAssessmentFooter
}
catch {
    throw ("$Name assessment failed: " + `$_.Exception.Message)
}
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $assessmentFile) -Value $assessmentContent -Encoding utf8

    $discoveryContent = @"
[CmdletBinding()]
param(
    [Parameter()]
    [switch]`$PassThru
)

`$result = [PSCustomObject]@{
    Platform = "Blackknight One"
    Engine = "$Name"
    Operation = "${Name}Discovery"
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    Objects = @()
}

if (`$PassThru.IsPresent) {
    return `$result
}

`$result
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $discoveryFile) -Value $discoveryContent -Encoding utf8

    $analyzerContent = @"
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [object]`$InputObject,

    [Parameter()]
    [switch]`$PassThru
)

begin {
    `$items = [System.Collections.Generic.List[object]]::new()
}
process {
    if (`$null -ne `$InputObject) {
        `$items.Add(`$InputObject)
    }
}
end {
    `$result = [PSCustomObject]@{
        Platform = "Blackknight One"
        Engine = "$Name"
        Operation = "${Name}Analyzer"
        Analyzed = `$items.Count
    }

    if (`$PassThru.IsPresent) {
        return `$result
    }

    `$result
}
"@
    Set-Content -LiteralPath (Join-Path $engineRoot $analyzerFile) -Value $analyzerContent -Encoding utf8

    $testContent = @"
Describe "$Name engine scaffold" {
    It "has a valid engine manifest" {
        `$manifestPath = Join-Path -Path `$PSScriptRoot -ChildPath "..\engine.json"
        `$manifest = Get-Content -LiteralPath `$manifestPath -Raw | ConvertFrom-Json

        `$manifest.Name | Should -Be "$Name"
        `$manifest.Version | Should -Be "$Version"
    }

    It "contains all declared entry points" {
        `$engineRoot = Split-Path -Path `$PSScriptRoot -Parent
        `$entryPoints = @(
            "$assessmentFile"
            "$discoveryFile"
            "$analyzerFile"
        )

        foreach (`$entryPoint in `$entryPoints) {
            `$entryPointPath = Join-Path -Path `$engineRoot -ChildPath `$entryPoint
            Test-Path -LiteralPath `$entryPointPath -PathType Leaf | Should -BeTrue
        }
    }
}
"@
    Set-Content -LiteralPath (Join-Path $engineRoot "Tests\$Name.Tests.ps1") -Value $testContent -Encoding utf8

    $readme = "# $Name Engine`n`n$Description`n`nGenerated by Blackknight Framework v0.8.2.`n"
    Set-Content -LiteralPath (Join-Path $engineRoot "README.md") -Value $readme -Encoding utf8

    if (-not $NoPublicWrapper.IsPresent) {
        $wrapperContent = @"
function $assessmentCommand {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]`$IncludeObjects,

        [Parameter()]
        [switch]`$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]`$OutputPath = ".\reports\$($Name.ToLowerInvariant())\$($Name.ToLowerInvariant())-assessment.json",

        [Parameter()]
        [switch]`$PassThru
    )

    `$parameters = @{
        IncludeObjects = `$IncludeObjects.IsPresent
        ExportJson = `$ExportJson.IsPresent
        OutputPath = `$OutputPath
    }

    Invoke-BKRegisteredEngine -Name "$Name" -Operation "Assessment" -Parameters `$parameters -PassThru:`$PassThru.IsPresent
}
"@
        Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding utf8
    }

    $generatedFiles = @(
        (Join-Path $engineRoot $assessmentFile)
        (Join-Path $engineRoot $discoveryFile)
        (Join-Path $engineRoot $analyzerFile)
        (Join-Path $engineRoot "Tests\$Name.Tests.ps1")
    )

    if (-not $NoPublicWrapper.IsPresent) {
        $generatedFiles += $wrapperPath
    }

    $parseFailures = [System.Collections.Generic.List[object]]::new()
    foreach ($generatedFile in $generatedFiles) {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($generatedFile, [ref]$tokens, [ref]$parseErrors) | Out-Null

        if ($parseErrors.Count -gt 0) {
            $parseFailures.Add([PSCustomObject]@{
                File = $generatedFile
                Errors = @($parseErrors.Message)
            })
        }
    }

    if ($parseFailures.Count -gt 0) {
        $parseFailures | Format-Table File, @{Name = "Errors"; Expression = { $_.Errors -join "; " }} -Wrap | Out-Host
        throw "Generated engine scaffold failed PowerShell syntax validation."
    }

    $validation = Test-BKEngineManifest -Manifest $manifest -ManifestPath $manifestPath
    if (-not $validation.IsValid) {
        throw ("Generated engine manifest is invalid: " + ($validation.Errors -join "; "))
    }

    $result = [PSCustomObject]@{
        Name = $Name
        Category = $Category
        Version = $Version
        EngineRoot = $engineRoot
        ManifestPath = $manifestPath
        PublicWrapperPath = if ($NoPublicWrapper.IsPresent) { $null } else { $wrapperPath }
        IsValid = $validation.IsValid
        ValidationErrors = @($validation.Errors)
        CreatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }

    Write-Host "Blackknight engine scaffold created" -ForegroundColor Green
    Write-Host ("-" * 60)
    $result | Format-List Name, Category, Version, EngineRoot, ManifestPath, IsValid | Out-Host

    $null = Get-BKEngineRegistry -Refresh -IncludeInvalid

    if ($PassThru.IsPresent) {
        return $result
    }
}

