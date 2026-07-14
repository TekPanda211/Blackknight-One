function Invoke-BKTerraformAssessment {
    <#
    .SYNOPSIS
    Runs the complete Blackknight One Terraform assessment.

    .DESCRIPTION
    Provides the public Blackknight One command for invoking the Terraform
    Engineering Engine.

    The public wrapper validates user-supplied paths, locates the Terraform
    engine entry point, forwards supported parameters, and returns the
    assessment result when PassThru is specified.

    This command does not run terraform apply.

    .PARAMETER Path
    Specifies the Terraform project directory.

    .PARAMETER VariableFile
    Specifies an optional Terraform variable file.

    .PARAMETER SkipInit
    Skips Terraform initialization.

    .PARAMETER SkipPlan
    Skips Terraform plan analysis.

    .PARAMETER SkipDrift
    Skips Terraform drift detection.

    .PARAMETER IncludeFileDetails
    Includes detailed Terraform file inventory information.

    .PARAMETER ExportJson
    Exports the assessment report as JSON.

    .PARAMETER OutputPath
    Specifies the JSON report destination.

    .PARAMETER PassThru
    Returns the complete Terraform assessment object.

    .EXAMPLE
    Invoke-BKTerraformAssessment

    .EXAMPLE
    $Assessment = Invoke-BKTerraformAssessment `
        -Path ".\terraform" `
        -ExportJson `
        -PassThru
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = ".\terraform",

        [Parameter()]
        [string]$VariableFile,

        [Parameter()]
        [switch]$SkipInit,

        [Parameter()]
        [switch]$SkipPlan,

        [Parameter()]
        [switch]$SkipDrift,

        [Parameter()]
        [switch]$IncludeFileDetails,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\terraform\terraform-assessment.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath "..\..\Terraform\Invoke-BKTerraformAssessment.ps1"

    $engineScript = [System.IO.Path]::GetFullPath(
        $engineScript
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $engineScript `
                -PathType Leaf
        )
    ) {
        throw "Terraform assessment engine was not found: $engineScript"
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Container
        )
    ) {
        throw "Terraform project directory was not found: $Path"
    }

    $resolvedPath = (
        Resolve-Path `
            -LiteralPath $Path `
            -ErrorAction Stop
    ).Path

    $resolvedVariableFile = $null

    if (
        -not [string]::IsNullOrWhiteSpace(
            $VariableFile
        )
    ) {
        if (
            -not (
                Test-Path `
                    -LiteralPath $VariableFile `
                    -PathType Leaf
            )
        ) {
            throw "Terraform variable file was not found: $VariableFile"
        }

        $resolvedVariableFile = (
            Resolve-Path `
                -LiteralPath $VariableFile `
                -ErrorAction Stop
        ).Path
    }

    $invokeParameters = @{
        Path               = $resolvedPath
        SkipInit           = $SkipInit.IsPresent
        SkipPlan           = $SkipPlan.IsPresent
        SkipDrift          = $SkipDrift.IsPresent
        IncludeFileDetails = $IncludeFileDetails.IsPresent
        ExportJson         = $ExportJson.IsPresent
        OutputPath         = $OutputPath
        PassThru           = $PassThru.IsPresent
    }

    if ($resolvedVariableFile) {
        $invokeParameters.VariableFile =
            $resolvedVariableFile
    }

    Write-Verbose "Terraform assessment wrapper started."
    Write-Verbose "Terraform engine: $engineScript"
    Write-Verbose "Terraform project: $resolvedPath"
    Write-Verbose "Skip initialization: $($SkipInit.IsPresent)"
    Write-Verbose "Skip plan analysis: $($SkipPlan.IsPresent)"
    Write-Verbose "Skip drift detection: $($SkipDrift.IsPresent)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    try {
        $result =
            & $engineScript @invokeParameters

        if ($PassThru) {
            return $result
        }
    }
    catch {
        $message =
            "Terraform assessment failed: $($_.Exception.Message)"

        if (
            Get-Command `
                -Name Write-BKLog `
                -ErrorAction SilentlyContinue
        ) {
            Write-BKLog `
                -Message $message `
                -Level Error
        }

        throw $message
    }
}