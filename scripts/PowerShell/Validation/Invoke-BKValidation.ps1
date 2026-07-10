<#
.SYNOPSIS
Blackknight One Validation Engine

.DESCRIPTION
Validates available Blackknight One engine reports and produces an
evidence-based platform validation result.

This initial version validates report availability, result structure,
confidence values, evidence, and recommendations.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\validation",
    [switch]$ExportJson
)

$PlatformModule = Join-Path `
    (Split-Path $PSScriptRoot -Parent) `
    "Platform\Blackknight-Platform.psm1"

if (Test-Path $PlatformModule) {
    Import-Module $PlatformModule -Force
}
else {
    throw "Blackknight Platform module not found at $PlatformModule"
}

function Write-BKValidationSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Get-BKNormalizedResults {
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )

    $normalized = @()

    if ($null -eq $Data) {
        return $normalized
    }

    if ($Data.PSObject.Properties.Name -contains "Results") {
        $normalized += @($Data.Results)
    }
    elseif ($Data.PSObject.Properties.Name -contains "Result") {
        $normalized += @($Data.Result)
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and
            $Data -isnot [string] -and
            $Data -isnot [System.Management.Automation.PSCustomObject]) {
        $normalized += @($Data)
    }
    else {
        $normalized += @($Data)
    }

    return $normalized
}

function Invoke-BKValidation {
    Write-BKValidationSection "Blackknight Validation Engine"

    $engines = @(Get-BKEngineManifest | Where-Object {
        $_.Enabled -eq $true -and $_.Name -ne "Validation"
    })

    $validationItems = @()
    $engineResults = @()
    $recommendations = @()

    foreach ($engine in $engines) {
        $reportPath = Join-Path ".\reports\$($engine.Name.ToLower())" $engine.ReportName

        if (-not $engine.ProducesReport) {
            $validationItems += [PSCustomObject]@{
                Engine  = $engine.DisplayName
                Check   = "Report Required"
                Status  = "SKIPPED"
                Details = "Engine does not declare a report."
            }

            continue
        }

        if (-not (Test-Path $reportPath)) {
            $validationItems += [PSCustomObject]@{
                Engine  = $engine.DisplayName
                Check   = "Report Available"
                Status  = "FAIL"
                Details = "Report not found: $reportPath"
            }

            $recommendations += "Run $($engine.DisplayName) with JSON export enabled."
            continue
        }

        try {
            $reportData = Get-Content $reportPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $results = @(Get-BKNormalizedResults -Data $reportData)

            $validationItems += [PSCustomObject]@{
                Engine  = $engine.DisplayName
                Check   = "Report Parse"
                Status  = "PASS"
                Details = $reportPath
            }

            foreach ($result in $results) {
                if ($null -eq $result) {
                    continue
                }

                $requiredProperties = @(
                    "Engine",
                    "Version",
                    "Status",
                    "Health",
                    "Confidence",
                    "ChecksRun",
                    "Passed",
                    "Warnings",
                    "Failed",
                    "Timestamp",
                    "Evidence",
                    "Recommendations"
                )

                $missingProperties = @(
                    $requiredProperties | Where-Object {
                        $_ -notin $result.PSObject.Properties.Name
                    }
                )

                if ($missingProperties.Count -eq 0) {
                    $validationItems += [PSCustomObject]@{
                        Engine  = $result.Engine
                        Check   = "Result Schema"
                        Status  = "PASS"
                        Details = "Required result properties present."
                    }
                }
                else {
                    $validationItems += [PSCustomObject]@{
                        Engine  = $result.Engine
                        Check   = "Result Schema"
                        Status  = "FAIL"
                        Details = "Missing: $($missingProperties -join ', ')"
                    }

                    $recommendations += "Correct the result schema for $($result.Engine)."
                }

                $confidenceValid = (
                    $null -ne $result.Confidence -and
                    [double]$result.Confidence -ge 0 -and
                    [double]$result.Confidence -le 100
                )

                $validationItems += [PSCustomObject]@{
                    Engine  = $result.Engine
                    Check   = "Confidence Range"
                    Status  = if ($confidenceValid) { "PASS" } else { "FAIL" }
                    Details = "Confidence: $($result.Confidence)"
                }

                if (-not $confidenceValid) {
                    $recommendations += "Correct the confidence value for $($result.Engine)."
                }

                $hasEvidence = @($result.Evidence).Count -gt 0

                $validationItems += [PSCustomObject]@{
                    Engine  = $result.Engine
                    Check   = "Evidence Present"
                    Status  = if ($hasEvidence) { "PASS" } else { "WARN" }
                    Details = "Evidence items: $(@($result.Evidence).Count)"
                }

                if (-not $hasEvidence) {
                    $recommendations += "Add validation evidence for $($result.Engine)."
                }

                $engineResults += $result
            }
        }
        catch {
            $validationItems += [PSCustomObject]@{
                Engine  = $engine.DisplayName
                Check   = "Report Parse"
                Status  = "FAIL"
                Details = $_.Exception.Message
            }

            $recommendations += "Repair the JSON report for $($engine.DisplayName)."
        }
    }

    $passedChecks = @($validationItems | Where-Object {
        $_.Status -eq "PASS"
    }).Count

    $warningChecks = @($validationItems | Where-Object {
        $_.Status -eq "WARN"
    }).Count

    $failedChecks = @($validationItems | Where-Object {
        $_.Status -eq "FAIL"
    }).Count

    $checksRun = $passedChecks + $warningChecks + $failedChecks

    $validationConfidence = if ($checksRun -gt 0) {
        [math]::Round(($passedChecks / $checksRun) * 100, 2)
    }
    else {
        0
    }

    $engineConfidence = if ($engineResults.Count -gt 0) {
        [math]::Round(
            ($engineResults.Confidence | Measure-Object -Average).Average,
            2
        )
    }
    else {
        0
    }

    $health = if ($failedChecks -gt 0) {
        "Degraded"
    }
    elseif ($warningChecks -gt 0) {
        "Warning"
    }
    else {
        "Healthy"
    }

    $evidence = @(
        "Registered engines evaluated: $($engines.Count)"
        "Engine result objects evaluated: $($engineResults.Count)"
        "Validation checks executed: $checksRun"
        "Validation checks passed: $passedChecks"
        "Validation warnings: $warningChecks"
        "Validation failures: $failedChecks"
        "Average engine confidence: $engineConfidence%"
    )

    $result = New-BKResult `
        -Engine "Validation Engine" `
        -Version "0.5.0-alpha" `
        -Status "Integrated" `
        -Health $health `
        -Confidence $validationConfidence `
        -ChecksRun $checksRun `
        -Passed $passedChecks `
        -Warnings $warningChecks `
        -Failed $failedChecks `
        -Evidence $evidence `
        -Recommendations @($recommendations | Select-Object -Unique)

    Write-Host ""
    Write-Host "Registered Engines       : $($engines.Count)"
    Write-Host "Results Evaluated        : $($engineResults.Count)"
    Write-Host "Checks Run               : $checksRun"
    Write-Host "Passed                   : $passedChecks"
    Write-Host "Warnings                 : $warningChecks"
    Write-Host "Failed                   : $failedChecks"
    Write-Host "Engine Confidence        : $engineConfidence%"
    Write-Host "Validation Confidence    : $validationConfidence%"
    Write-Host "Validation Health        : $health"

    Write-Host ""
    $validationItems |
        Format-Table Engine, Check, Status, Details -AutoSize

    if ($recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Recommendations" -ForegroundColor Yellow

        foreach ($recommendation in @($recommendations | Select-Object -Unique)) {
            Write-Host "- $recommendation"
        }
    }

    if ($ExportJson) {
        $report = [PSCustomObject]@{
            Platform          = "Blackknight One"
            Version           = "0.5.0-alpha"
            GeneratedAt       = (Get-Date).ToUniversalTime().ToString("o")
            ValidationResult  = $result
            EngineConfidence  = $engineConfidence
            ValidationDetails = $validationItems
            ResultsEvaluated  = $engineResults
        }

        $jsonPath = Join-Path $OutputPath "validation-report.json"
        Export-BKJsonReport -Data $report -Path $jsonPath
    }

    Write-BKValidationSection "Validation Engine Complete"
}

Invoke-BKValidation