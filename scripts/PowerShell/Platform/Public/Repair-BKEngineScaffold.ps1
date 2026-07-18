function Repair-BKEngineScaffold {
    <#
    .SYNOPSIS
    Repairs the manifest parameter contract and public wrapper for an engine.

    .DESCRIPTION
    Reads the actual assessment entry-point command metadata, records the
    supported parameters in engine.json, and regenerates the public assessment
    wrapper without forwarding unsupported parameters. The engine implementation
    itself is not replaced.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [switch]$PassThru
    )

    $engine = @(
        Get-BKEngineRegistry -Refresh -IncludeInvalid |
            Where-Object { $_.Name -eq $Name -or $_.DisplayName -eq $Name }
    ) | Select-Object -First 1

    if ($null -eq $engine) {
        throw "Blackknight engine was not found: $Name"
    }

    $assessmentEntryPoint = [string]$engine.EntryPoints.Assessment
    if ([string]::IsNullOrWhiteSpace($assessmentEntryPoint)) {
        throw "Engine '$($engine.Name)' does not declare an Assessment entry point."
    }

    $assessmentPath = Join-Path -Path $engine.Root -ChildPath $assessmentEntryPoint
    if (-not (Test-Path -LiteralPath $assessmentPath -PathType Leaf)) {
        throw "Assessment entry point was not found: $assessmentPath"
    }

    $commandInfo = Get-Command -Name $assessmentPath -ErrorAction Stop
    $supported = @($commandInfo.Parameters.Keys)
    $commonParameters = @(
        "Verbose", "Debug", "ErrorAction", "WarningAction", "InformationAction",
        "ProgressAction", "ErrorVariable", "WarningVariable", "InformationVariable",
        "OutVariable", "OutBuffer", "PipelineVariable", "WhatIf", "Confirm"
    )
    $engineParameters = @(
        $supported |
            Where-Object { $_ -notin $commonParameters } |
            Sort-Object
    )

    $manifest = Get-Content -LiteralPath $engine.ManifestPath -Raw | ConvertFrom-Json
    $parameterContract = [ordered]@{}

    foreach ($parameterName in $engineParameters) {
        $parameterMetadata = $commandInfo.Parameters[$parameterName]
        $typeName = if ($null -ne $parameterMetadata.ParameterType) {
            $parameterMetadata.ParameterType.Name
        }
        else {
            "Object"
        }

        $parameterContract[$parameterName] = [ordered]@{
            Type = $typeName
            Required = [bool]($parameterMetadata.Attributes.Mandatory -contains $true)
        }
    }

    if ($null -eq $manifest.PSObject.Properties["OperationParameters"]) {
        $manifest | Add-Member -MemberType NoteProperty -Name "OperationParameters" -Value ([PSCustomObject]@{})
    }

    $operationParameters = [ordered]@{}
    foreach ($property in $manifest.OperationParameters.PSObject.Properties) {
        $operationParameters[$property.Name] = $property.Value
    }
    $operationParameters["Assessment"] = [PSCustomObject]$parameterContract
    $manifest.OperationParameters = [PSCustomObject]$operationParameters
    $manifest.SchemaVersion = "2.1"

    if ($null -eq $manifest.PSObject.Properties["Generator"]) {
        $manifest | Add-Member -MemberType NoteProperty -Name "Generator" -Value ([PSCustomObject]@{
            Name = "Blackknight Framework"
            Version = "0.8.2"
        })
    }
    else {
        $manifest.Generator = [PSCustomObject]@{
            Name = "Blackknight Framework"
            Version = "0.8.2"
        }
    }

    $publicRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "."))
    $wrapperCommand = "Invoke-BK$($engine.Name)Assessment"
    $wrapperPath = Join-Path -Path $publicRoot -ChildPath "$wrapperCommand.ps1"

    $parameterBlocks = [System.Collections.Generic.List[string]]::new()
    $forwardingLines = [System.Collections.Generic.List[string]]::new()

    foreach ($parameterName in $engineParameters) {
        $metadata = $commandInfo.Parameters[$parameterName]
        $type = $metadata.ParameterType
        $typeLiteral = switch ($type.FullName) {
            "System.Management.Automation.SwitchParameter" { "switch"; break }
            "System.String" { "string"; break }
            "System.String[]" { "string[]"; break }
            "System.Int32" { "int"; break }
            "System.Int64" { "long"; break }
            "System.Boolean" { "bool"; break }
            "System.Collections.Hashtable" { "hashtable"; break }
            default { "object" }
        }

        $defaultText = ""
        if ($parameterName -eq "OutputPath") {
            $lowerName = $engine.Name.ToLowerInvariant()
            $defaultText = " = `".\reports\$lowerName\$lowerName-assessment.json`""
        }

        $parameterBlocks.Add("        [Parameter()]`r`n        [$typeLiteral]`$$parameterName$defaultText")

        if ($typeLiteral -eq "switch") {
            if ($parameterName -ne "PassThru") {
                $forwardingLines.Add("        $parameterName = `$$parameterName.IsPresent")
            }
        }
        elseif ($parameterName -ne "PassThru") {
            $forwardingLines.Add("        $parameterName = `$$parameterName")
        }
    }

    $parameterText = $parameterBlocks -join ",`r`n`r`n"
    $forwardingText = $forwardingLines -join "`r`n"
    $hasPassThru = $engineParameters -contains "PassThru"
    $passThruExpression = if ($hasPassThru) { "`$PassThru.IsPresent" } else { "`$false" }

    $wrapperContent = @"
function $wrapperCommand {
    [CmdletBinding()]
    param(
$parameterText
    )

    `$parameters = @{
$forwardingText
    }

    Invoke-BKRegisteredEngine -Name "$($engine.Name)" -Operation "Assessment" -Parameters `$parameters -PassThru:$passThruExpression
}
"@

    if ($PSCmdlet.ShouldProcess($wrapperPath, "Repair engine manifest parameter contract and public wrapper")) {
        $backupPath = "$wrapperPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (Test-Path -LiteralPath $wrapperPath -PathType Leaf) {
            Copy-Item -LiteralPath $wrapperPath -Destination $backupPath -Force
        }

        $manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $engine.ManifestPath -Encoding utf8
        Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding utf8

        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($wrapperPath, [ref]$tokens, [ref]$parseErrors) | Out-Null

        if ($parseErrors.Count -gt 0) {
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                Copy-Item -LiteralPath $backupPath -Destination $wrapperPath -Force
            }
            throw ("Generated wrapper failed syntax validation: " + ($parseErrors.Message -join "; "))
        }
    }

    $result = [PSCustomObject]@{
        Name = $engine.Name
        AssessmentPath = $assessmentPath
        WrapperPath = $wrapperPath
        SupportedParameters = @($engineParameters)
        ManifestPath = $engine.ManifestPath
        SchemaVersion = "2.1"
        RepairedAt = (Get-Date).ToUniversalTime().ToString("o")
    }

    $null = Get-BKEngineRegistry -Refresh -IncludeInvalid

    if ($PassThru.IsPresent) {
        return $result
    }

    $result | Format-List | Out-Host
}

