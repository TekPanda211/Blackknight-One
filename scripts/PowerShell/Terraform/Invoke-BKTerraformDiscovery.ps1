[CmdletBinding()]
param(
    [string]$Path = ".\terraform",

    [switch]$IncludeFileDetails,

    [switch]$ExportJson,

    [string]$OutputPath =
        ".\reports\terraform\terraform-discovery.json"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Blackknight Terraform Discovery" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    if (-not (Get-Command Get-BKTerraformInventory -ErrorAction SilentlyContinue)) {
        throw "Get-BKTerraformInventory is not available. Import the Blackknight-Platform module first."
    }

    Write-BKLog `
        -Message "Starting Terraform discovery..." `
        -Level Info

    $inventory = Get-BKTerraformInventory `
        -Path $Path `
        -IncludeFileDetails:$IncludeFileDetails

    $controls = [System.Collections.Generic.List[object]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()

    function Add-BKTerraformControl {
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [ValidateSet("PASS", "WARN", "FAIL")]
            [string]$Status,

            [Parameter(Mandatory)]
            [int]$Points,

            [Parameter(Mandatory)]
            [int]$MaximumPoints,

            [Parameter(Mandatory)]
            [string]$Details,

            [string]$Recommendation
        )

        $controls.Add(
            [PSCustomObject]@{
                Name          = $Name
                Status        = $Status
                Points        = $Points
                MaximumPoints = $MaximumPoints
                Details       = $Details
            }
        )

        if (
            -not [string]::IsNullOrWhiteSpace($Recommendation) -and
            $Status -ne "PASS"
        ) {
            $recommendations.Add($Recommendation)
        }
    }

    #
    # Terraform CLI
    #

    if ($inventory.TerraformInstalled) {
        Add-BKTerraformControl `
            -Name "Terraform CLI" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "Terraform CLI version $($inventory.TerraformVersion) is available."
    }
    else {
        Add-BKTerraformControl `
            -Name "Terraform CLI" `
            -Status "FAIL" `
            -Points 0 `
            -MaximumPoints 10 `
            -Details "Terraform CLI was not found in PATH." `
            -Recommendation "Install Terraform and ensure the executable is available in PATH."
    }

    #
    # Configuration discovery
    #

    if ($inventory.TerraformFileCount -gt 0) {
        Add-BKTerraformControl `
            -Name "Terraform Configuration" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.TerraformFileCount) Terraform files were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Terraform Configuration" `
            -Status "FAIL" `
            -Points 0 `
            -MaximumPoints 10 `
            -Details "No Terraform configuration files were discovered." `
            -Recommendation "Add Terraform configuration files beneath the configured Terraform root."
    }

    #
    # Project discovery
    #

    if ($inventory.ProjectCount -gt 0) {
        Add-BKTerraformControl `
            -Name "Terraform Projects" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.ProjectCount) Terraform project folders were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Terraform Projects" `
            -Status "WARN" `
            -Points 5 `
            -MaximumPoints 10 `
            -Details "No Terraform project folders were identified." `
            -Recommendation "Review the Terraform directory layout and organize configurations into clear project boundaries."
    }

    #
    # Provider declarations
    #

    if (
        $inventory.ProviderCount -gt 0 -or
        $inventory.RequiredProviderCount -gt 0
    ) {
        Add-BKTerraformControl `
            -Name "Provider Discovery" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.RequiredProviderCount) required provider declarations and $($inventory.ProviderCount) provider blocks were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Provider Discovery" `
            -Status "WARN" `
            -Points 5 `
            -MaximumPoints 10 `
            -Details "No provider declarations were discovered." `
            -Recommendation "Define required providers and explicit provider configuration."
    }

    #
    # Infrastructure resources
    #

    if ($inventory.ResourceCount -gt 0) {
        Add-BKTerraformControl `
            -Name "Resource Inventory" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.ResourceCount) managed resources were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Resource Inventory" `
            -Status "WARN" `
            -Points 5 `
            -MaximumPoints 10 `
            -Details "No managed Terraform resources were discovered." `
            -Recommendation "Confirm whether this project is intended to contain managed resources."
    }

    #
    # State hygiene
    #

    if ($inventory.ContainsLocalState) {
        Add-BKTerraformControl `
            -Name "Terraform State Hygiene" `
            -Status "FAIL" `
            -Points 0 `
            -MaximumPoints 20 `
            -Details "$($inventory.StateFileCount) local Terraform state files were discovered." `
            -Recommendation "Remove Terraform state files from source control and use a secured remote backend."
    }
    else {
        Add-BKTerraformControl `
            -Name "Terraform State Hygiene" `
            -Status "PASS" `
            -Points 20 `
            -MaximumPoints 20 `
            -Details "No local Terraform state files were discovered."
    }

    #
    # Backend configuration
    #

    if ($inventory.BackendCount -gt 0) {
        Add-BKTerraformControl `
            -Name "Backend Configuration" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.BackendCount) backend declarations were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Backend Configuration" `
            -Status "WARN" `
            -Points 5 `
            -MaximumPoints 10 `
            -Details "No explicit Terraform backend declaration was discovered." `
            -Recommendation "Evaluate a secured remote backend for shared or production Terraform workloads."
    }

    #
    # Lock file
    #

    if ($inventory.LockFileCount -gt 0) {
        Add-BKTerraformControl `
            -Name "Provider Dependency Lock" `
            -Status "PASS" `
            -Points 10 `
            -MaximumPoints 10 `
            -Details "$($inventory.LockFileCount) Terraform dependency lock files were discovered."
    }
    else {
        Add-BKTerraformControl `
            -Name "Provider Dependency Lock" `
            -Status "WARN" `
            -Points 5 `
            -MaximumPoints 10 `
            -Details "No .terraform.lock.hcl file was discovered." `
            -Recommendation "Run terraform init and commit the dependency lock file where appropriate."
    }

    #
    # Calculate confidence
    #

    $earnedPoints = (
        $controls |
            Measure-Object `
                -Property Points `
                -Sum
    ).Sum

    $maximumPoints = (
        $controls |
            Measure-Object `
                -Property MaximumPoints `
                -Sum
    ).Sum

    if ($null -eq $earnedPoints) {
        $earnedPoints = 0
    }

    if ($null -eq $maximumPoints) {
        $maximumPoints = 0
    }

    $confidence = if ($maximumPoints -gt 0) {
        [math]::Round(
            ($earnedPoints / $maximumPoints) * 100,
            2
        )
    }
    else {
        0
    }

    $failed = @(
        $controls |
            Where-Object Status -eq "FAIL"
    ).Count

    $warnings = @(
        $controls |
            Where-Object Status -eq "WARN"
    ).Count

    $passed = @(
        $controls |
            Where-Object Status -eq "PASS"
    ).Count

    $health = if ($failed -gt 0) {
        "Needs Attention"
    }
    elseif ($confidence -ge 90) {
        "Healthy"
    }
    elseif ($confidence -ge 75) {
        "Degraded"
    }
    else {
        "Needs Attention"
    }

    $result = [PSCustomObject]@{
        Platform = "Blackknight One"

        Engine = [PSCustomObject]@{
            Name        = "Terraform"
            DisplayName = "Terraform Engineering Engine"
            Version     = "0.7.0"
            Status      = $health
        }

        Summary = [PSCustomObject]@{
            RootPath              = $inventory.RootPath
            TerraformInstalled    = $inventory.TerraformInstalled
            TerraformVersion      = $inventory.TerraformVersion
            ProjectCount          = $inventory.ProjectCount
            TerraformFileCount    = $inventory.TerraformFileCount
            ProviderCount         = $inventory.ProviderCount
            RequiredProviderCount = $inventory.RequiredProviderCount
            ResourceCount         = $inventory.ResourceCount
            DataSourceCount       = $inventory.DataSourceCount
            ModuleCount           = $inventory.ModuleCount
            VariableCount         = $inventory.VariableCount
            OutputCount           = $inventory.OutputCount
            BackendCount          = $inventory.BackendCount
            LockFileCount         = $inventory.LockFileCount
            StateFileCount        = $inventory.StateFileCount
        }

        Confidence = [PSCustomObject]@{
            Score         = $confidence
            Health        = $health
            Points        = $earnedPoints
            MaximumPoints = $maximumPoints
            Passed        = $passed
            Warnings      = $warnings
            Failed        = $failed
        }

        Controls        = @($controls)
        Recommendations = @(
            $recommendations |
                Sort-Object -Unique
        )
        Inventory       = $inventory
        Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
    }

    Write-Host ""
    Write-Host "Terraform Environment" -ForegroundColor Yellow
    Write-Host "----------------------------------------"
    Write-Host "Terraform Installed     : $($inventory.TerraformInstalled)"
    Write-Host "Terraform Version       : $($inventory.TerraformVersion)"
    Write-Host "Projects                : $($inventory.ProjectCount)"
    Write-Host "Terraform Files         : $($inventory.TerraformFileCount)"
    Write-Host "Providers               : $($inventory.RequiredProviderCount)"
    Write-Host "Resources               : $($inventory.ResourceCount)"
    Write-Host "Modules                 : $($inventory.ModuleCount)"
    Write-Host "Backends                : $($inventory.BackendCount)"
    Write-Host "State Files             : $($inventory.StateFileCount)"

    Write-Host ""
    Write-Host "Terraform Controls" -ForegroundColor Yellow
    Write-Host "----------------------------------------"

    $controls |
        Format-Table `
            Name,
            Status,
            Points,
            MaximumPoints,
            Details `
            -AutoSize

    Write-Host ""
    Write-Host "Terraform Confidence    : $confidence%"
    Write-Host "Terraform Health        : $health"
    Write-Host "Passed                  : $passed"
    Write-Host "Warnings                : $warnings"
    Write-Host "Failed                  : $failed"

    if ($recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "Recommendations" -ForegroundColor Yellow

        foreach ($recommendation in (
            $recommendations |
                Sort-Object -Unique
        )) {
            Write-Host "- $recommendation"
        }
    }

    if ($ExportJson) {
        $outputDirectory = Split-Path `
            -Path $OutputPath `
            -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($outputDirectory) -and
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

    return $result
}
catch {
    if (Get-Command Write-BKLog -ErrorAction SilentlyContinue) {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error
    }

    throw
}
