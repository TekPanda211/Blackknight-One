function Test-BKPlatform {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Blackknight Platform Validation"
    Write-Host "========================================" -ForegroundColor Cyan

    $results = @()
    $repoRoot = (Get-Location).Path

    function New-TestResult {
        param(
            [string]$Check,
            [bool]$Passed,
            [string]$Details
        )

        [PSCustomObject]@{
            Check   = $Check
            Status  = if ($Passed) { "PASS" } else { "FAIL" }
            Details = $Details
        }
    }

    $platformModule = Join-Path $repoRoot "scripts\PowerShell\Platform\Blackknight-Platform.psm1"
    $coreEngine     = Join-Path $repoRoot "scripts\PowerShell\Core\Invoke-BlackKnight.ps1"
    $configFolder   = Join-Path $repoRoot "config"
    $reportsFolder  = Join-Path $repoRoot "reports"

    $results += New-TestResult -Check "Platform Module" -Passed (Test-Path $platformModule) -Details $platformModule
    $results += New-TestResult -Check "Core Engine" -Passed (Test-Path $coreEngine) -Details $coreEngine
    $results += New-TestResult -Check "Config Folder" -Passed (Test-Path $configFolder) -Details $configFolder
    $results += New-TestResult -Check "Reports Folder" -Passed (Test-Path $reportsFolder) -Details $reportsFolder

    $requiredFunctions = @(
        "Connect-BKGraph",
        "Get-BKCapabilities",
        "Get-BKOrganization",
        "Get-BKDomains",
        "Get-BKUsers",
        "Get-BKGroups",
        "Get-BKLicensing",
        "Get-BKTenant",
        "New-BKResult",
        "Export-BKJsonReport",
        "Get-BKConfidenceScore",
        "Write-BKLog",
        "Get-BKServiceManifest",
        "Get-BKPlatformConfiguration",
        "Get-BKPlatformInventory",
        "Test-BKPlatform"
    )

    foreach ($functionName in $requiredFunctions) {
        $command = Get-Command $functionName -ErrorAction SilentlyContinue
        $results += New-TestResult -Check "Function: $functionName" -Passed ($null -ne $command) -Details "Required platform function"
    }

    $serviceManifest = Join-Path $repoRoot "scripts\PowerShell\Platform\Services\services.json"

    $results += New-TestResult -Check "Service Manifest" -Passed (Test-Path $serviceManifest) -Details $serviceManifest

    if (Test-Path $serviceManifest) {
        try {
            $manifest = Get-Content $serviceManifest -Raw | ConvertFrom-Json

            foreach ($service in $manifest.Services) {
                $command = Get-Command $service.Name -ErrorAction SilentlyContinue

                $results += New-TestResult `
                    -Check "Service: $($service.Name)" `
                    -Passed ($null -ne $command) `
                    -Details "$($service.Category) | $($service.Status)"
            }
        }
        catch {
            $results += New-TestResult `
                -Check "Service Manifest Parse" `
                -Passed $false `
                -Details $_.Exception.Message
        }
    }

    $engineManifests = Get-ChildItem -Path (Join-Path $repoRoot "scripts\PowerShell") -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue

    $results += New-TestResult `
        -Check "Engine Manifests" `
        -Passed ($engineManifests.Count -gt 0) `
        -Details "$($engineManifests.Count) manifest(s) found"

    foreach ($manifestFile in $engineManifests) {
        try {
            $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
            $engineFolder = Split-Path $manifestFile.FullName -Parent
            $entryPoint = Join-Path $engineFolder $manifest.EntryPoint

            $results += New-TestResult `
                -Check "Engine: $($manifest.DisplayName)" `
                -Passed (Test-Path $entryPoint) `
                -Details $entryPoint
        }
        catch {
            $results += New-TestResult `
                -Check "Engine Manifest Parse" `
                -Passed $false `
                -Details $manifestFile.FullName
        }
    }

    $psFiles = Get-ChildItem -Path (Join-Path $repoRoot "scripts\PowerShell") -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $psFiles) {
        $parseErrors = $null
        [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$parseErrors) | Out-Null

        $results += New-TestResult `
            -Check "Syntax: $($file.Name)" `
            -Passed ($parseErrors.Count -eq 0) `
            -Details $file.FullName
    }

    $results | Format-Table -AutoSize

    $failed = $results | Where-Object { $_.Status -eq "FAIL" }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($failed.Count -eq 0) {
        Write-Host "Blackknight Platform Ready" -ForegroundColor Green
        Write-Host "Validation Confidence: 100%"
    }
    else {
        Write-Host "Blackknight Platform Validation Failed" -ForegroundColor Red
        Write-Host "Failures: $($failed.Count)"
    }

    Write-Host "========================================" -ForegroundColor Cyan

    return $results
}