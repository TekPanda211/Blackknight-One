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

$ErrorActionPreference = "Stop"

function Get-BKTerraformAssessmentHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Confidence,

        [Parameter(Mandatory)]
        [int]$CriticalFindings,

        [Parameter(Mandatory)]
        [int]$HighFindings
    )

    if ($CriticalFindings -gt 0) {
        return "Needs Attention"
    }

    if ($HighFindings -gt 0) {
        return "Warning"
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

function Add-BKTerraformAssessmentFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Collection,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateSet(
            "Informational",
            "Low",
            "Medium",
            "High",
            "Critical"
        )]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Details,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Resource,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Recommendation
    )

    $finding = [PSCustomObject]@{
        Source         = $Source
        Severity       = $Severity
        Title          = $Title
        Details        = $Details
        Resource       = $Resource
        Recommendation = $Recommendation
    }

    $null = $Collection.Add($finding)
}

function Get-BKCommandResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Output,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation
    )

    $result = $Output |
        Where-Object {
            $null -ne $_ -and
            $null -ne $_.PSObject -and
            $_.PSObject.Properties.Name -contains "Operation" -and
            $_.Operation -eq $Operation
        } |
        Select-Object -Last 1

    return $result
}

function Add-BKRecommendation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Collection,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Recommendation
    )

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Recommendation
        )
    ) {
        $null = $Collection.Add($Recommendation)
    }
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "          BLACKKNIGHT TERRAFORM ASSESSMENT" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    #
    # Required commands
    #

    $requiredCommands = @(
        "Get-BKTerraformInventory"
        "Test-BKTerraformConfiguration"
    )

    if (-not $SkipPlan.IsPresent) {
        $requiredCommands += "Test-BKTerraformPlan"
    }

    if (-not $SkipDrift.IsPresent) {
        $requiredCommands += "Test-BKTerraformDrift"
    }

    foreach ($commandName in $requiredCommands) {
        $command = Get-Command `
            -Name $commandName `
            -ErrorAction SilentlyContinue

        if (-not $command) {
            throw "Required Blackknight command is unavailable: $commandName"
        }
    }

    #
    # Resolve project paths
    #

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

    $findings =
        [System.Collections.Generic.List[object]]::new()

    $recommendations =
        [System.Collections.Generic.List[string]]::new()

    #
    # Phase 1: Inventory
    #

    Write-Host ""
    Write-Host "Phase 1 of 4: Terraform inventory" `
        -ForegroundColor Yellow

    $inventoryOutput = @(
        Get-BKTerraformInventory `
            -Path $resolvedPath `
            -IncludeFileDetails:$IncludeFileDetails
    )

    $inventory = $inventoryOutput |
        Where-Object {
            $null -ne $_ -and
            $null -ne $_.PSObject -and
            $_.PSObject.Properties.Name -contains "TerraformInstalled" -and
            $_.PSObject.Properties.Name -contains "TerraformFileCount"
        } |
        Select-Object -Last 1

    if ($null -eq $inventory) {
        throw "Terraform inventory did not return a valid inventory object."
    }

    if (-not $inventory.TerraformInstalled) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "Critical" `
            -Title "Terraform CLI unavailable" `
            -Details "Terraform was not found in PATH." `
            -Resource $resolvedPath `
            -Recommendation "Install Terraform and ensure the executable is available in PATH."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Install Terraform and ensure the executable is available in PATH."
    }

    if ([int]$inventory.TerraformFileCount -eq 0) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "High" `
            -Title "No Terraform configuration found" `
            -Details "No Terraform configuration files were discovered." `
            -Resource $resolvedPath `
            -Recommendation "Add Terraform configuration beneath the assessment root."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Add Terraform configuration beneath the assessment root."
    }

    if ([bool]$inventory.ContainsLocalState) {
    $trackedStateFiles = @(
        git -C $resolvedPath ls-files 2>$null |
            Where-Object {
                $_ -match '\.tfstate(\.backup)?$'
            }
    )

    if ($trackedStateFiles.Count -gt 0) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "Critical" `
            -Title "Tracked Terraform state detected" `
            -Details "$($trackedStateFiles.Count) Terraform state files are tracked by Git." `
            -Resource $resolvedPath `
            -Recommendation "Remove Terraform state files from source control and rotate any exposed credentials or secrets."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Remove Terraform state files from source control and rotate any exposed credentials or secrets."
    }
    else {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "Medium" `
            -Title "Ignored local Terraform state detected" `
            -Details "$($inventory.StateFileCount) local Terraform state files were found, but none are tracked by Git." `
            -Resource $resolvedPath `
            -Recommendation "Use a secured remote backend before shared or production deployment."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Use a secured remote backend before shared or production deployment."
    }
}

    if ([int]$inventory.BackendCount -eq 0) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "Medium" `
            -Title "No explicit Terraform backend detected" `
            -Details "No explicit Terraform backend declaration was discovered." `
            -Resource $resolvedPath `
            -Recommendation "Evaluate a secured remote backend for shared or production Terraform workloads."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Evaluate a secured remote backend for shared or production Terraform workloads."
    }

    if ([int]$inventory.LockFileCount -eq 0) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Inventory" `
            -Severity "Low" `
            -Title "Terraform dependency lock file not detected" `
            -Details "No .terraform.lock.hcl file was discovered." `
            -Resource $resolvedPath `
            -Recommendation "Run terraform init and commit the dependency lock file when appropriate."

        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation "Run terraform init and commit the dependency lock file when appropriate."
    }

    #
    # Phase 2: Configuration validation
    #

    Write-Host ""
    Write-Host "Phase 2 of 4: Terraform configuration validation" `
        -ForegroundColor Yellow

    $configurationParameters = @{
        Path     = $resolvedPath
        Recurse  = $true
        SkipInit = $SkipInit.IsPresent
        PassThru = $true
    }

    $configurationOutput = @(
        Test-BKTerraformConfiguration @configurationParameters
    )

    $configuration = Get-BKCommandResult `
        -Output $configurationOutput `
        -Operation "ConfigurationValidation"

    if ($null -eq $configuration) {
        $configuration = $configurationOutput |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.Summary -and
                $_.Summary.PSObject.Properties.Name -contains "ValidProjects"
            } |
            Select-Object -Last 1
    }

    if ($null -eq $configuration) {
        throw "Terraform configuration validation did not return a valid result object."
    }

    foreach ($diagnostic in @($configuration.Diagnostics)) {
        if ($null -eq $diagnostic) {
            continue
        }

        $diagnosticSeverity =
            ([string]$diagnostic.Severity).ToLowerInvariant()

        $severity = switch ($diagnosticSeverity) {
            "error" {
                "High"
            }

            "warning" {
                "Medium"
            }

            default {
                "Informational"
            }
        }

        $title = [string]$diagnostic.Summary

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "Terraform configuration diagnostic"
        }

        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Source "Configuration" `
            -Severity $severity `
            -Title $title `
            -Details ([string]$diagnostic.Detail) `
            -Resource ([string]$diagnostic.File) `
            -Recommendation "Correct the Terraform configuration diagnostic."
    }

    foreach ($recommendation in @($configuration.Recommendations)) {
        Add-BKRecommendation `
            -Collection $recommendations `
            -Recommendation ([string]$recommendation)
    }

    #
    # Phase 3: Plan analysis
    #

    $plan = $null

    if (-not $SkipPlan.IsPresent) {
        Write-Host ""
        Write-Host "Phase 3 of 4: Terraform plan analysis" `
            -ForegroundColor Yellow

        $planParameters = @{
            Path     = $resolvedPath
            SkipInit = $SkipInit.IsPresent
            Refresh  = $true
            PassThru = $true
        }

        if ($resolvedVariableFile) {
            $planParameters.VariableFile =
                $resolvedVariableFile
        }

        $planOutput = @(
            Test-BKTerraformPlan @planParameters
        )

        $plan = Get-BKCommandResult `
            -Output $planOutput `
            -Operation "PlanAnalysis"

        if ($null -eq $plan) {
            $plan = $planOutput |
                Where-Object {
                    $null -ne $_ -and
                    $null -ne $_.Summary -and
                    $_.Summary.PSObject.Properties.Name -contains "TotalChanges"
                } |
                Select-Object -Last 1
        }

        if ($null -eq $plan) {
            throw "Terraform plan analysis did not return a valid result object."
        }

        foreach ($change in @($plan.Changes)) {
            if ($null -eq $change) {
                continue
            }

            $planSeverity = [string]$change.Severity

            if (
                $planSeverity -notin @(
                    "Informational"
                    "Low"
                    "Medium"
                    "High"
                    "Critical"
                )
            ) {
                $planSeverity = "Informational"
            }

            $actionSummary = [string]$change.ActionSummary

            if ([string]::IsNullOrWhiteSpace($actionSummary)) {
                $actionSummary = "change"
            }

            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Source "Plan" `
                -Severity $planSeverity `
                -Title "Terraform plan change: $actionSummary" `
                -Details "Proposed change for Terraform resource type $($change.Type)." `
                -Resource ([string]$change.Address) `
                -Recommendation "Review and approve the proposed Terraform change before deployment."
        }

        foreach ($recommendation in @($plan.Recommendations)) {
            Add-BKRecommendation `
                -Collection $recommendations `
                -Recommendation ([string]$recommendation)
        }
    }
    else {
        Write-Host ""
        Write-Host "Phase 3 of 4: Terraform plan analysis skipped" `
            -ForegroundColor DarkYellow
    }

    #
    # Phase 4: Drift confirmation
    #

    $drift = $null

    if (-not $SkipDrift.IsPresent) {
        Write-Host ""
        Write-Host "Phase 4 of 4: Terraform drift confirmation" `
            -ForegroundColor Yellow

        $driftParameters = @{
            Path     = $resolvedPath
            SkipInit = $SkipInit.IsPresent
            PassThru = $true
        }

        if ($resolvedVariableFile) {
            $driftParameters.VariableFile =
                $resolvedVariableFile
        }

        $driftOutput = @(
            Test-BKTerraformDrift @driftParameters
        )

        $drift = Get-BKCommandResult `
            -Output $driftOutput `
            -Operation "DriftDetection"

        if ($null -eq $drift) {
            $drift = $driftOutput |
                Where-Object {
                    $null -ne $_ -and
                    $null -ne $_.Summary -and
                    (
                        $_.Summary.PSObject.Properties.Name -contains
                        "ActionableDriftDetected"
                    )
                } |
                Select-Object -Last 1
        }

        if ($null -eq $drift) {
            throw "Terraform drift detection did not return a valid drift result object."
        }

        foreach ($driftItem in @($drift.DriftItems)) {
            if ($null -eq $driftItem) {
                continue
            }

            $driftSeverity =
                [string]$driftItem.Severity

            if (
                $driftSeverity -notin @(
                    "Informational"
                    "Low"
                    "Medium"
                    "High"
                    "Critical"
                )
            ) {
                $driftSeverity = "Informational"
            }

            $actionSummary =
                [string]$driftItem.ActionSummary

            if ([string]::IsNullOrWhiteSpace($actionSummary)) {
                $actionSummary = "change"
            }

            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Source "Drift" `
                -Severity $driftSeverity `
                -Title "Confirmed Terraform drift: $actionSummary" `
                -Details "Confirmed drift for Terraform resource type $($driftItem.Type)." `
                -Resource ([string]$driftItem.Address) `
                -Recommendation "Reconcile the live environment with the approved Terraform configuration."
        }

        foreach ($recommendation in @($drift.Recommendations)) {
            Add-BKRecommendation `
                -Collection $recommendations `
                -Recommendation ([string]$recommendation)
        }
    }
    else {
        Write-Host ""
        Write-Host "Phase 4 of 4: Terraform drift confirmation skipped" `
            -ForegroundColor DarkYellow
    }

    #
    # Scoring
    #

    $inventoryScore = 100

    if (-not [bool]$inventory.TerraformInstalled) {
        $inventoryScore -= 35
    }

    if ([int]$inventory.TerraformFileCount -eq 0) {
        $inventoryScore -= 30
    }

    if ([bool]$inventory.ContainsLocalState) {
    $trackedStateFiles = @(
        git -C $resolvedPath ls-files 2>$null |
            Where-Object {
                $_ -match '\.tfstate(\.backup)?$'
            }
    )

    if ($trackedStateFiles.Count -gt 0) {
        $inventoryScore -= 35
    }
    else {
        $inventoryScore -= 10
    }
}

    if ([int]$inventory.BackendCount -eq 0) {
        $inventoryScore -= 10
    }

    if ([int]$inventory.LockFileCount -eq 0) {
        $inventoryScore -= 5
    }

    if ($inventoryScore -lt 0) {
        $inventoryScore = 0
    }

    $configurationScore = if (
        $null -ne $configuration.Summary -and
        $configuration.Summary.PSObject.Properties.Name -contains
        "Confidence"
    ) {
        [double]$configuration.Summary.Confidence
    }
    else {
        0
    }

    $planScore = if ($SkipPlan.IsPresent) {
        100
    }
    elseif (
        $null -ne $plan -and
        $null -ne $plan.Summary -and
        $plan.Summary.PSObject.Properties.Name -contains
        "Confidence"
    ) {
        [double]$plan.Summary.Confidence
    }
    else {
        0
    }

    $driftScore = if ($SkipDrift.IsPresent) {
        100
    }
    elseif (
        $null -ne $drift -and
        $null -ne $drift.Summary -and
        $drift.Summary.PSObject.Properties.Name -contains
        "Confidence"
    ) {
        [double]$drift.Summary.Confidence
    }
    else {
        0
    }

    $assessmentConfidence = [math]::Round(
        (
            ($inventoryScore * 0.20) +
            ($configurationScore * 0.30) +
            ($planScore * 0.25) +
            ($driftScore * 0.25)
        ),
        2
    )

    $criticalFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Critical"
            }
    )

    $highFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "High"
            }
    )

    $mediumFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Medium"
            }
    )

    $lowFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Low"
            }
    )

    $assessmentHealth =
        Get-BKTerraformAssessmentHealth `
            -Confidence $assessmentConfidence `
            -CriticalFindings $criticalFindings.Count `
            -HighFindings $highFindings.Count

    if ($criticalFindings.Count -gt 0) {
        $releaseDecision = "Blocked"
        $releaseReason =
            "Critical Terraform findings must be resolved before deployment."
    }
    elseif ($highFindings.Count -gt 0) {
        $releaseDecision = "Review Required"
        $releaseReason =
            "High-severity Terraform findings require engineering approval."
    }
    elseif ($mediumFindings.Count -gt 0) {
        $releaseDecision = "Conditional Pass"
        $releaseReason =
            "No critical blockers were detected, but medium-severity findings should be reviewed."
    }
    else {
        $releaseDecision = "Pass"
        $releaseReason =
            "Terraform passed the Blackknight One assessment gates."
    }

    $sortedFindings = @(
        $findings |
            Sort-Object `
                @{
                    Expression = {
                        switch ($_.Severity) {
                            "Critical" {
                                5
                            }

                            "High" {
                                4
                            }

                            "Medium" {
                                3
                            }

                            "Low" {
                                2
                            }

                            default {
                                1
                            }
                        }
                    }
                    Descending = $true
                },
                Source,
                Title
    )

    $confirmedDrift = if (
        $null -ne $drift -and
        $null -ne $drift.Summary
    ) {
        if (
            $drift.Summary.PSObject.Properties.Name -contains
            "ActionableDriftDetected"
        ) {
            [bool]$drift.Summary.ActionableDriftDetected
        }
        elseif (
            $drift.Summary.PSObject.Properties.Name -contains
            "ConfirmedDrift"
        ) {
            [int]$drift.Summary.ConfirmedDrift
        }
        elseif (
            $drift.Summary.PSObject.Properties.Name -contains
            "DriftDetected"
        ) {
            [bool]$drift.Summary.DriftDetected
        }
        else {
            $null
        }
    }
    else {
        $null
    }

    $configurationErrors = if (
        $null -ne $configuration.Summary -and
        $configuration.Summary.PSObject.Properties.Name -contains
        "Errors"
    ) {
        [int]$configuration.Summary.Errors
    }
    else {
        $null
    }

    $planChanges = if (
        $null -ne $plan -and
        $null -ne $plan.Summary -and
        $plan.Summary.PSObject.Properties.Name -contains
        "TotalChanges"
    ) {
        [int]$plan.Summary.TotalChanges
    }
    else {
        $null
    }

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "Terraform"
        Operation   = "FullAssessment"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Project = [PSCustomObject]@{
            Path         = $resolvedPath
            VariableFile = $resolvedVariableFile
        }

        Summary = [PSCustomObject]@{
            Status              = "Complete"
            Health              = $assessmentHealth
            Confidence          = $assessmentConfidence
            ReleaseDecision     = $releaseDecision
            ReleaseReason       = $releaseReason
            TotalFindings       = $findings.Count
            CriticalFindings    = $criticalFindings.Count
            HighFindings        = $highFindings.Count
            MediumFindings      = $mediumFindings.Count
            LowFindings         = $lowFindings.Count
            TerraformInstalled  = [bool]$inventory.TerraformInstalled
            TerraformVersion    = [string]$inventory.TerraformVersion
            Projects            = [int]$inventory.ProjectCount
            TerraformFiles      = [int]$inventory.TerraformFileCount
            Providers           = [int]$inventory.RequiredProviderCount
            Resources           = [int]$inventory.ResourceCount
            Modules             = [int]$inventory.ModuleCount
            LocalStateFiles     = [int]$inventory.StateFileCount
            ConfigurationErrors = $configurationErrors
            PlanChanges         = $planChanges
            ConfirmedDrift      = $confirmedDrift
        }

        Scores = [PSCustomObject]@{
            Inventory     = $inventoryScore
            Configuration = $configurationScore
            Plan          = $planScore
            Drift         = $driftScore
            Overall       = $assessmentConfidence
        }

        Inventory     = $inventory
        Configuration = $configuration
        Plan          = $plan
        Drift         = $drift
        Findings      = $sortedFindings

        Recommendations = @(
            $recommendations |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Sort-Object -Unique
        )
    }

    #
    # Console summary
    #

    Write-Host ""
    Write-Host "Assessment Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Project              : $resolvedPath"
    Write-Host "Terraform Files      : $($inventory.TerraformFileCount)"
    Write-Host "Managed Resources    : $($inventory.ResourceCount)"
    Write-Host "Inventory Score      : $inventoryScore%"
    Write-Host "Configuration Score  : $configurationScore%"
    Write-Host "Plan Score           : $planScore%"
    Write-Host "Drift Score          : $driftScore%"
    Write-Host "Overall Confidence   : $assessmentConfidence%"
    Write-Host "Assessment Health    : $assessmentHealth"
    Write-Host "Release Decision     : $releaseDecision"
    Write-Host ""
    Write-Host "Critical Findings    : $($criticalFindings.Count)"
    Write-Host "High Findings        : $($highFindings.Count)"
    Write-Host "Medium Findings      : $($mediumFindings.Count)"
    Write-Host "Low Findings         : $($lowFindings.Count)"

    if ($sortedFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "Assessment Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $sortedFindings |
            Select-Object `
                Severity,
                Source,
                Title,
                Resource |
            Format-Table -AutoSize |
            Out-Host
    }

    Write-Host ""
    Write-Host "Release Recommendation" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host $releaseReason

    #
    # JSON export
    #

    if ($ExportJson.IsPresent) {
        $outputDirectory = Split-Path `
            -Path $OutputPath `
            -Parent

        if (
            -not [string]::IsNullOrWhiteSpace(
                $outputDirectory
            ) -and
            -not (
                Test-Path `
                    -LiteralPath $outputDirectory
            )
        ) {
            New-Item `
                -Path $outputDirectory `
                -ItemType Directory `
                -Force |
                Out-Null
        }

        $result |
            ConvertTo-Json `
                -Depth 40 |
            Set-Content `
                -LiteralPath $OutputPath `
                -Encoding utf8

        Write-Host ""
        Write-Host `
            "[Success] Exported Terraform assessment to $OutputPath" `
            -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    if ($PassThru.IsPresent) {
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