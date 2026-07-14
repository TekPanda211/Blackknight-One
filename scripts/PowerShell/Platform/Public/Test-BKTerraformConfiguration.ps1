function Test-BKTerraformConfiguration {
    <#
    .SYNOPSIS
    Validates Terraform configuration discovered by Blackknight One.

    .DESCRIPTION
    Runs Terraform formatting, initialization, and configuration validation
    against one or more Terraform project directories.

    The command performs the following checks:

    - Terraform CLI availability
    - Terraform project discovery
    - terraform fmt -check
    - terraform init -backend=false
    - terraform validate -json
    - Diagnostic normalization
    - Project and overall confidence scoring
    - Optional JSON report export

    This command does not execute terraform plan or terraform apply and does
    not intentionally access or modify a configured backend.

    .PARAMETER Path
    Root directory containing Terraform configurations.

    .PARAMETER Recurse
    Discovers and validates each directory containing Terraform files.

    .PARAMETER SkipInit
    Skips terraform init. Use only when projects are already initialized.

    .PARAMETER Upgrade
    Passes -upgrade to terraform init.

    .PARAMETER ExportJson
    Exports the normalized validation report.

    .PARAMETER OutputPath
    Destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete validation result object.

    .EXAMPLE
    Test-BKTerraformConfiguration

    .EXAMPLE
    Test-BKTerraformConfiguration `
        -Path ".\terraform" `
        -Recurse `
        -ExportJson

    .EXAMPLE
    $Result = Test-BKTerraformConfiguration `
        -Recurse `
        -PassThru
    #>

    [CmdletBinding()]
    param(
        [string]$Path = ".\terraform",

        [switch]$Recurse,

        [switch]$SkipInit,

        [switch]$Upgrade,

        [switch]$ExportJson,

        [string]$OutputPath =
            ".\reports\terraform\terraform-validation.json",

        [switch]$PassThru
    )

    $ErrorActionPreference = "Stop"

    function Invoke-BKTerraformProcess {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Executable,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList,

            [Parameter(Mandatory)]
            [string]$WorkingDirectory
        )

        $startInfo =
            [System.Diagnostics.ProcessStartInfo]::new()

        $startInfo.FileName = $Executable
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        foreach ($argument in $ArgumentList) {
            $null = $startInfo.ArgumentList.Add($argument)
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo

        try {
            $started = $process.Start()

            if (-not $started) {
                throw "Terraform process could not be started."
            }

            $standardOutput =
                $process.StandardOutput.ReadToEnd()

            $standardError =
                $process.StandardError.ReadToEnd()

            $process.WaitForExit()

            return [PSCustomObject]@{
                Executable       = $Executable
                Arguments        = @($ArgumentList)
                CommandLine      = "$Executable $($ArgumentList -join ' ')"
                WorkingDirectory = $WorkingDirectory
                ExitCode         = $process.ExitCode
                StandardOutput   = $standardOutput.Trim()
                StandardError    = $standardError.Trim()
                Succeeded        = $process.ExitCode -eq 0
            }
        }
        finally {
            $process.Dispose()
        }
    }

    function New-BKTerraformDiagnostic {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$ProjectPath,

            [Parameter(Mandatory)]
            [string]$Source,

            [Parameter(Mandatory)]
            [string]$Severity,

            [Parameter(Mandatory)]
            [string]$Summary,

            [AllowNull()]
            [string]$Detail,

            [AllowNull()]
            [string]$File,

            [AllowNull()]
            [Nullable[int]]$StartLine,

            [AllowNull()]
            [Nullable[int]]$StartColumn
        )

        [PSCustomObject]@{
            ProjectPath = $ProjectPath
            Source      = $Source
            Severity    = $Severity
            Summary     = $Summary
            Detail      = $Detail
            File        = $File
            StartLine   = $StartLine
            StartColumn = $StartColumn
        }
    }

    function Get-BKTerraformProjectHealth {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [double]$Confidence,

            [Parameter(Mandatory)]
            [int]$ErrorCount
        )

        if ($ErrorCount -gt 0) {
            return "Needs Attention"
        }

        if ($Confidence -ge 98) {
            return "Excellent"
        }

        if ($Confidence -ge 90) {
            return "Healthy"
        }

        if ($Confidence -ge 75) {
            return "Warning"
        }

        return "Needs Attention"
    }

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan
    Write-Host "          BLACKKNIGHT TERRAFORM CONFIGURATION TEST" `
        -ForegroundColor Cyan
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    try {
        $terraformCommand = Get-Command `
            -Name "terraform" `
            -ErrorAction SilentlyContinue

        if (-not $terraformCommand) {
            throw "Terraform CLI was not found in PATH."
        }

        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Terraform path was not found: $Path"
        }

        $resolvedRoot = (
            Resolve-Path `
                -LiteralPath $Path `
                -ErrorAction Stop
        ).Path

        $versionResult = Invoke-BKTerraformProcess `
            -Executable $terraformCommand.Source `
            -ArgumentList @(
                "version"
                "-json"
            ) `
            -WorkingDirectory $resolvedRoot

        $terraformVersion = "Unknown"

        if ($versionResult.Succeeded) {
            try {
                $versionObject =
                    $versionResult.StandardOutput |
                    ConvertFrom-Json `
                        -ErrorAction Stop

                $terraformVersion =
                    [string]$versionObject.terraform_version
            }
            catch {
                $terraformVersion = "Detected"
            }
        }

        $terraformFiles = @(
            Get-ChildItem `
                -LiteralPath $resolvedRoot `
                -Filter "*.tf" `
                -File `
                -Recurse:$Recurse `
                -ErrorAction Stop
        )

        if ($terraformFiles.Count -eq 0) {
            throw "No Terraform configuration files were found beneath: $resolvedRoot"
        }

        $projectDirectories = if ($Recurse) {
            @(
                $terraformFiles |
                    ForEach-Object {
                        $_.Directory.FullName
                    } |
                    Sort-Object -Unique
            )
        }
        else {
            @($resolvedRoot)
        }

        $projectResults =
            [System.Collections.Generic.List[object]]::new()

        $allDiagnostics =
            [System.Collections.Generic.List[object]]::new()

        foreach ($projectDirectory in $projectDirectories) {
            Write-Host ""
            Write-Host "Project: $projectDirectory" `
                -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"

            $projectFiles = @(
                Get-ChildItem `
                    -LiteralPath $projectDirectory `
                    -Filter "*.tf" `
                    -File `
                    -ErrorAction SilentlyContinue
            )

            if ($projectFiles.Count -eq 0) {
                continue
            }

            #
            # Formatting check
            #

            $formatResult = Invoke-BKTerraformProcess `
                -Executable $terraformCommand.Source `
                -ArgumentList @(
                    "fmt"
                    "-check"
                    "-diff"
                    "-no-color"
                ) `
                -WorkingDirectory $projectDirectory

            $formatPassed = $formatResult.Succeeded

            if (-not $formatPassed) {
                $formatDetail = @(
                    $formatResult.StandardOutput
                    $formatResult.StandardError
                ) |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    } |
                    Join-String -Separator [Environment]::NewLine

                $allDiagnostics.Add(
                    (
                        New-BKTerraformDiagnostic `
                            -ProjectPath $projectDirectory `
                            -Source "terraform fmt" `
                            -Severity "warning" `
                            -Summary "Terraform formatting check failed." `
                            -Detail $formatDetail
                    )
                )
            }

            #
            # Initialization
            #

            $initResult = $null
            $initPassed = $true

            if (-not $SkipInit) {
                $initArguments = @(
                    "init"
                    "-backend=false"
                    "-input=false"
                    "-no-color"
                )

                if ($Upgrade) {
                    $initArguments += "-upgrade"
                }

                $initResult = Invoke-BKTerraformProcess `
                    -Executable $terraformCommand.Source `
                    -ArgumentList $initArguments `
                    -WorkingDirectory $projectDirectory

                $initPassed = $initResult.Succeeded

                if (-not $initPassed) {
                    $initDetail = @(
                        $initResult.StandardOutput
                        $initResult.StandardError
                    ) |
                        Where-Object {
                            -not [string]::IsNullOrWhiteSpace($_)
                        } |
                        Join-String -Separator [Environment]::NewLine

                    $allDiagnostics.Add(
                        (
                            New-BKTerraformDiagnostic `
                                -ProjectPath $projectDirectory `
                                -Source "terraform init" `
                                -Severity "error" `
                                -Summary "Terraform initialization failed." `
                                -Detail $initDetail
                        )
                    )
                }
            }

            #
            # Configuration validation
            #

            $validationResult = $null
            $validationObject = $null
            $configurationValid = $false
            $errorCount = 0
            $warningCount = 0

            if ($initPassed) {
                $validationResult = Invoke-BKTerraformProcess `
                    -Executable $terraformCommand.Source `
                    -ArgumentList @(
                        "validate"
                        "-json"
                    ) `
                    -WorkingDirectory $projectDirectory

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $validationResult.StandardOutput
                    )
                ) {
                    try {
                        $validationObject =
                            $validationResult.StandardOutput |
                            ConvertFrom-Json `
                                -ErrorAction Stop

                        $configurationValid =
                            [bool]$validationObject.valid

                        $errorCount =
                            [int]$validationObject.error_count

                        $warningCount =
                            [int]$validationObject.warning_count

                        foreach (
                            $diagnostic in @(
                                $validationObject.diagnostics
                            )
                        ) {
                            $diagnosticFile = $null
                            $startLine = $null
                            $startColumn = $null

                            if ($diagnostic.range) {
                                $diagnosticFile =
                                    [string]$diagnostic.range.filename

                                if ($diagnostic.range.start) {
                                    $startLine =
                                        [int]$diagnostic.range.start.line

                                    $startColumn =
                                        [int]$diagnostic.range.start.column
                                }
                            }

                            $allDiagnostics.Add(
                                (
                                    New-BKTerraformDiagnostic `
                                        -ProjectPath $projectDirectory `
                                        -Source "terraform validate" `
                                        -Severity (
                                            [string]$diagnostic.severity
                                        ) `
                                        -Summary (
                                            [string]$diagnostic.summary
                                        ) `
                                        -Detail (
                                            [string]$diagnostic.detail
                                        ) `
                                        -File $diagnosticFile `
                                        -StartLine $startLine `
                                        -StartColumn $startColumn
                                )
                            )
                        }
                    }
                    catch {
                        $errorCount = 1

                        $allDiagnostics.Add(
                            (
                                New-BKTerraformDiagnostic `
                                    -ProjectPath $projectDirectory `
                                    -Source "terraform validate" `
                                    -Severity "error" `
                                    -Summary "Terraform validation output was not valid JSON." `
                                    -Detail (
                                        @(
                                            $_.Exception.Message
                                            $validationResult.StandardOutput
                                            $validationResult.StandardError
                                        ) |
                                            Where-Object {
                                                -not [string]::IsNullOrWhiteSpace($_)
                                            } |
                                            Join-String -Separator [Environment]::NewLine
                                    )
                            )
                        )
                    }
                }
                else {
                    $errorCount = 1

                    $allDiagnostics.Add(
                        (
                            New-BKTerraformDiagnostic `
                                -ProjectPath $projectDirectory `
                                -Source "terraform validate" `
                                -Severity "error" `
                                -Summary "Terraform validation returned no JSON output." `
                                -Detail $validationResult.StandardError
                        )
                    )
                }
            }
            else {
                $errorCount = 1
            }

            #
            # Project confidence
            #

            $formatPoints = if ($formatPassed) {
                20
            }
            else {
                10
            }

            $initPoints = if ($SkipInit) {
                20
            }
            elseif ($initPassed) {
                20
            }
            else {
                0
            }

            $validationPoints = if ($configurationValid) {
                50
            }
            elseif ($errorCount -eq 0) {
                25
            }
            else {
                0
            }

            $warningPoints = if ($warningCount -eq 0) {
                10
            }
            elseif ($warningCount -le 2) {
                5
            }
            else {
                0
            }

            $earnedPoints =
                $formatPoints +
                $initPoints +
                $validationPoints +
                $warningPoints

            $maximumPoints = 100

            $projectConfidence = [math]::Round(
                ($earnedPoints / $maximumPoints) * 100,
                2
            )

            $projectHealth = Get-BKTerraformProjectHealth `
                -Confidence $projectConfidence `
                -ErrorCount $errorCount

            $projectResult = [PSCustomObject]@{
                ProjectPath = $projectDirectory
                FileCount   = $projectFiles.Count

                Formatting = [PSCustomObject]@{
                    Passed         = $formatPassed
                    ExitCode       = $formatResult.ExitCode
                    StandardOutput = $formatResult.StandardOutput
                    StandardError  = $formatResult.StandardError
                }

                Initialization = [PSCustomObject]@{
                    Skipped        = [bool]$SkipInit
                    Passed         = $initPassed
                    ExitCode       = if ($initResult) {
                        $initResult.ExitCode
                    }
                    else {
                        $null
                    }
                    StandardOutput = if ($initResult) {
                        $initResult.StandardOutput
                    }
                    else {
                        $null
                    }
                    StandardError  = if ($initResult) {
                        $initResult.StandardError
                    }
                    else {
                        $null
                    }
                }

                Validation = [PSCustomObject]@{
                    Valid        = $configurationValid
                    ErrorCount   = $errorCount
                    WarningCount = $warningCount
                    ExitCode     = if ($validationResult) {
                        $validationResult.ExitCode
                    }
                    else {
                        $null
                    }
                }

                Confidence = $projectConfidence
                Health     = $projectHealth
            }

            $projectResults.Add($projectResult)

            Write-Host "Files             : $($projectFiles.Count)"
            Write-Host "Format Check      : $formatPassed"
            Write-Host "Initialization    : $initPassed"
            Write-Host "Configuration     : $configurationValid"
            Write-Host "Errors            : $errorCount"
            Write-Host "Warnings          : $warningCount"
            Write-Host "Confidence        : $projectConfidence%"
            Write-Host "Health            : $projectHealth"
        }

        #
        # Overall results
        #

        $totalProjects = $projectResults.Count

        $validProjects = @(
            $projectResults |
                Where-Object {
                    $_.Validation.Valid
                }
        ).Count

        $invalidProjects =
            $totalProjects -
            $validProjects

        $formatFailures = @(
            $projectResults |
                Where-Object {
                    -not $_.Formatting.Passed
                }
        ).Count

        $initFailures = @(
            $projectResults |
                Where-Object {
                    -not $_.Initialization.Passed
                }
        ).Count

        $totalErrors = (
            $projectResults |
                Measure-Object `
                    -Property {
                        $_.Validation.ErrorCount
                    } `
                    -Sum
        ).Sum

        $totalWarnings = (
            $projectResults |
                Measure-Object `
                    -Property {
                        $_.Validation.WarningCount
                    } `
                    -Sum
        ).Sum

        if ($null -eq $totalErrors) {
            $totalErrors = 0
        }

        if ($null -eq $totalWarnings) {
            $totalWarnings = 0
        }

        $overallConfidence = if ($totalProjects -gt 0) {
            [math]::Round(
                (
                    (
                        $projectResults |
                            Measure-Object `
                                -Property Confidence `
                                -Average
                    ).Average
                ),
                2
            )
        }
        else {
            0
        }

        $overallHealth = Get-BKTerraformProjectHealth `
            -Confidence $overallConfidence `
            -ErrorCount $totalErrors

        $recommendations =
            [System.Collections.Generic.List[string]]::new()

        if ($formatFailures -gt 0) {
            $recommendations.Add(
                "Run terraform fmt -recursive and commit the resulting formatting changes."
            )
        }

        if ($initFailures -gt 0) {
            $recommendations.Add(
                "Resolve provider, module, or initialization errors before validation."
            )
        }

        if ($invalidProjects -gt 0) {
            $recommendations.Add(
                "Resolve all Terraform validation errors before planning or applying infrastructure."
            )
        }

        if ($totalWarnings -gt 0) {
            $recommendations.Add(
                "Review Terraform validation warnings and address applicable configuration concerns."
            )
        }

        if (
            $totalErrors -eq 0 -and
            $totalWarnings -eq 0 -and
            $formatFailures -eq 0
        ) {
            $recommendations.Add(
                "Terraform configuration passed formatting and validation quality gates."
            )
        }

        $result = [PSCustomObject]@{
            Platform         = "Blackknight One"
            Engine           = "Terraform"
            Operation        = "ConfigurationValidation"
            TerraformVersion = $terraformVersion
            RootPath         = $resolvedRoot
            GeneratedAt      = (
                Get-Date
            ).ToUniversalTime().ToString("o")

            Summary = [PSCustomObject]@{
                Projects         = $totalProjects
                ValidProjects    = $validProjects
                InvalidProjects  = $invalidProjects
                FormatFailures   = $formatFailures
                InitFailures     = $initFailures
                Errors           = [int]$totalErrors
                Warnings         = [int]$totalWarnings
                Confidence       = $overallConfidence
                Health           = $overallHealth
            }

            Projects        = @($projectResults)
            Diagnostics     = @($allDiagnostics)
            Recommendations = @(
                $recommendations |
                    Sort-Object -Unique
            )
        }

        Write-Host ""
        Write-Host "Validation Summary" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Terraform Version      : $terraformVersion"
        Write-Host "Projects               : $totalProjects"
        Write-Host "Valid Projects         : $validProjects"
        Write-Host "Invalid Projects       : $invalidProjects"
        Write-Host "Format Failures        : $formatFailures"
        Write-Host "Initialization Failures: $initFailures"
        Write-Host "Errors                 : $totalErrors"
        Write-Host "Warnings               : $totalWarnings"
        Write-Host "Confidence             : $overallConfidence%"
        Write-Host "Health                 : $overallHealth"

        if ($allDiagnostics.Count -gt 0) {
            Write-Host ""
            Write-Host "Diagnostics" `
                -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"

            $allDiagnostics |
                Select-Object `
                    Severity,
                    Source,
                    Summary,
                    File,
                    StartLine |
                Format-Table -AutoSize
        }

        Write-Host ""
        Write-Host "Recommendations" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        foreach (
            $recommendation in @(
                $recommendations |
                    Sort-Object -Unique
            )
        ) {
            Write-Host "- $recommendation"
        }

        if ($ExportJson) {
            $outputDirectory = Split-Path `
                -Path $OutputPath `
                -Parent

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $outputDirectory
                ) -and
                -not (Test-Path -LiteralPath $outputDirectory)
            ) {
                New-Item `
                    -Path $outputDirectory `
                    -ItemType Directory `
                    -Force |
                    Out-Null
            }

            $result |
                ConvertTo-Json `
                    -Depth 15 |
                Set-Content `
                    -LiteralPath $OutputPath `
                    -Encoding utf8

            Write-Host ""
            Write-Host "[Success] Exported JSON report to $OutputPath" `
                -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan

        if ($PassThru) {
            return $result
        }
    }
    catch {
        if (
            Get-Command `
                -Name Write-BKLog `
                -ErrorAction SilentlyContinue
        ) {
            Write-BKLog `
                -Message $_.Exception.Message `
                -Level Error
        }
        else {
            Write-Error $_.Exception.Message
        }

        throw
    }
}