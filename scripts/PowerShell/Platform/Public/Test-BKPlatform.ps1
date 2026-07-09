function Test-BKPlatform {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Blackknight Platform Validation"
    Write-Host "========================================" -ForegroundColor Cyan

    $results = @()

    function Add-TestResult {
        param(
            [string]$Check,
            [bool]$Passed,
            [string]$Details
        )

        $results += [PSCustomObject]@{
            Check   = $Check
            Status  = if ($Passed) { "PASS" } else { "FAIL" }
            Details = $Details
        }
    }

    $repoRoot = (Get-Location).Path

    $platformModule = Join-Path $repoRoot "scripts\PowerShell\Platform\Blackknight-Platform.psm1"
    $coreEngine     = Join-Path $repoRoot "scripts\PowerShell\Core\Invoke-BlackKnight.ps1"
    $configFolder   = Join-Path $repoRoot "config"
    $reportsFolder  = Join-Path $repoRoot "reports"

    Add-TestResult -Check "Platform Module" -Passed (Test-Path $platformModule) -Details $platformModule
    Add-TestResult -Check "Core Engine" -Passed (Test-Path $coreEngine) -Details $coreEngine
    Add-TestResult -Check "Config Folder" -Passed (Test-Path $configFolder) -Details $configFolder
    Add-TestResult -Check "Reports Folder" -Passed (Test-Path $reportsFolder) -Details $reportsFolder

    $requiredFunctions = @(
        "Connect-BKGraph",
        "Get-BKOrganization",
        "Get-BKDomains",
        "Get-BKUsers",
        "Get-BKGroups",
        "Get-BKLicensing",
        "Get-BKTenant",
        "New-BKResult",
        "Export-BKJsonReport",
        "Get-BKConfidenceScore",
        "Write-BKLog"
    )

    foreach ($functionName in $requiredFunctions) {
        $command = Get-Command $functionName -ErrorAction SilentlyContinue
        Add-TestResult -Check "Function: $functionName" -Passed ($null -ne $command) -Details "Required platform function"
    }

    $engineManifests = Get-ChildItem -Path (Join-Path $repoRoot "scripts\PowerShell") -Filter "engine.json" -Recurse -ErrorAction SilentlyContinue

    Add-TestResult -Check "Engine Manifests" -Passed ($engineManifests.Count -gt 0) -Details "$($engineManifests.Count) manifest(s) found"

    foreach ($manifestFile in $engineManifests) {
        try {
            $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
            $engineFolder = Split-Path $manifestFile.FullName -Parent
            $entryPoint = Join-Path $engineFolder $manifest.EntryPoint

            Add-TestResult -Check "Engine: $($manifest.DisplayName)" -Passed (Test-Path $entryPoint) -Details $entryPoint
        }
        catch {
            Add-TestResult -Check "Engine Manifest Parse" -Passed $false -Details $manifestFile.FullName
        }
    }

    $psFiles = Get-ChildItem -Path (Join-Path $repoRoot "scripts\PowerShell") -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $psFiles) {
        try {
            [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null) | Out-Null
            Add-TestResult -Check "Syntax: $($file.Name)" -Passed $true -Details $file.FullName
        }
        catch {
            Add-TestResult -Check "Syntax: $($file.Name)" -Passed $false -Details $_.Exception.Message
        }
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