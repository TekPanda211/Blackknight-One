function Test-BKTerraformPlan {
    <#
    .SYNOPSIS
    Creates and analyzes a Terraform execution plan.

    .DESCRIPTION
    Runs Terraform initialization, creates a saved execution plan, converts
    the plan to JSON, analyzes proposed resource changes, assigns severity,
    calculates confidence, generates recommendations, and optionally exports
    a normalized Blackknight One report.

    This command does not run terraform apply.

    .PARAMETER Path
    Terraform project directory.

    .PARAMETER VariableFile
    Optional Terraform variable file.

    .PARAMETER PlanFile
    Path for the temporary or saved Terraform plan.

    .PARAMETER SkipInit
    Skips terraform init.

    .PARAMETER Refresh
    Enables state refresh during plan creation. Disabled by default.

    .PARAMETER Destroy
    Creates and evaluates a destroy plan.

    .PARAMETER ExportJson
    Exports the normalized analysis report.

    .PARAMETER OutputPath
    Destination path for the JSON report.

    .PARAMETER KeepPlanFile
    Retains the generated Terraform plan file.

    .PARAMETER PassThru
    Returns the complete analysis object.

    .EXAMPLE
    Test-BKTerraformPlan `
        -Path ".\terraform\entra" `
        -ExportJson `
        -PassThru
    #>

    [CmdletBinding()]
    param(
        [string]$Path = ".\terraform",

        [string]$VariableFile,

        [string]$PlanFile = ".bk-terraform-plan.tfplan",

        [switch]$SkipInit,

        [switch]$Refresh,

        [switch]$Destroy,

        [switch]$ExportJson,

        [string]$OutputPath =
            ".\reports\terraform\terraform-plan-analysis.json",

        [switch]$KeepPlanFile,

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

        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
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
            if (-not $process.Start()) {
                throw "Terraform process could not be started."
            }

            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()

            $process.WaitForExit()

            [PSCustomObject]@{
                Executable       = $Executable
                Arguments        = @($ArgumentList)
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

    function Get-BKPlanSeverity {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string[]]$Actions,

            [Parameter(Mandatory)]
            [string]$ResourceType
        )

        $privilegedPatterns = @(
            "role",
            "administrator",
            "conditional_access",
            "policy",
            "permission",
            "credential",
            "secret",
            "key",
            "service_principal",
            "application"
        )

        $isPrivileged = $false

        foreach ($pattern in $privilegedPatterns) {
            if ($ResourceType -match $pattern) {
                $isPrivileged = $true
                break
            }
        }

        if ($Actions -contains "delete") {
            if ($isPrivileged) {
                return "Critical"
            }

            return "High"
        }

        if (
            $Actions -contains "create" -and
            $Actions -contains "delete"
        ) {
            if ($isPrivileged) {
                return "Critical"
            }

            return "High"
        }

        if ($Actions -contains "update") {
            if ($isPrivileged) {
                return "High"
            }

            return "Medium"
        }

        if ($Actions -contains "create") {
            if ($isPrivileged) {
                return "Medium"
            }

            return "Low"
        }

        return "Informational"
    }

    function Get-BKPlanHealth {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [double]$Confidence,

            [Parameter(Mandatory)]
            [int]$CriticalCount,

            [Parameter(Mandatory)]
            [int]$HighCount
        )

        if ($CriticalCount -gt 0) {
            return "Needs Attention"
        }

        if ($HighCount -gt 0) {
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

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan
    Write-Host "            BLACKKNIGHT TERRAFORM PLAN ANALYSIS" `
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
            throw "Terraform project path was not found: $Path"
        }

        $resolvedPath = (
            Resolve-Path `
                -LiteralPath $Path `
                -ErrorAction Stop
        ).Path

        $terraformFiles = @(
            Get-ChildItem `
                -LiteralPath $resolvedPath `
                -Filter "*.tf" `
                -File `
                -ErrorAction SilentlyContinue
        )

        if ($terraformFiles.Count -eq 0) {
            throw "No Terraform configuration files were found in: $resolvedPath"
        }

        if (
            -not [string]::IsNullOrWhiteSpace($VariableFile) -and
            -not (Test-Path -LiteralPath $VariableFile)
        ) {
            throw "Terraform variable file was not found: $VariableFile"
        }

        $resolvedPlanFile = if (
            [System.IO.Path]::IsPathRooted($PlanFile)
        ) {
            $PlanFile
        }
        else {
            Join-Path $resolvedPath $PlanFile
        }

        if (-not $SkipInit) {
            Write-Host ""
            Write-Host "Initializing Terraform..." `
                -ForegroundColor Yellow

            $initResult = Invoke-BKTerraformProcess `
                -Executable $terraformCommand.Source `
                -ArgumentList @(
                    "init"
                    "-input=false"
                    "-no-color"
                ) `
                -WorkingDirectory $resolvedPath

            if (-not $initResult.Succeeded) {
                throw @(
                    "Terraform initialization failed."
                    $initResult.StandardOutput
                    $initResult.StandardError
                ) -join [Environment]::NewLine
            }
        }

        $planArguments = @(
            "plan"
            "-input=false"
            "-no-color"
            "-out=$resolvedPlanFile"
        )

        if (-not $Refresh) {
            $planArguments += "-refresh=false"
        }

        if ($Destroy) {
            $planArguments += "-destroy"
        }

        if (-not [string]::IsNullOrWhiteSpace($VariableFile)) {
            $resolvedVariableFile = (
                Resolve-Path `
                    -LiteralPath $VariableFile `
                    -ErrorAction Stop
            ).Path

            $planArguments += "-var-file=$resolvedVariableFile"
        }

        Write-Host ""
        Write-Host "Creating Terraform execution plan..." `
            -ForegroundColor Yellow

        $planResult = Invoke-BKTerraformProcess `
            -Executable $terraformCommand.Source `
            -ArgumentList $planArguments `
            -WorkingDirectory $resolvedPath

        if (-not $planResult.Succeeded) {
            throw @(
                "Terraform plan failed."
                $planResult.StandardOutput
                $planResult.StandardError
            ) -join [Environment]::NewLine
        }

        Write-Host "Converting Terraform plan to JSON..." `
            -ForegroundColor Yellow

        $showResult = Invoke-BKTerraformProcess `
            -Executable $terraformCommand.Source `
            -ArgumentList @(
                "show"
                "-json"
                $resolvedPlanFile
            ) `
            -WorkingDirectory $resolvedPath

        if (-not $showResult.Succeeded) {
            throw @(
                "Terraform plan JSON conversion failed."
                $showResult.StandardOutput
                $showResult.StandardError
            ) -join [Environment]::NewLine
        }

        $planObject = $showResult.StandardOutput |
            ConvertFrom-Json `
                -Depth 100 `
                -ErrorAction Stop

        $changes = [System.Collections.Generic.List[object]]::new()
        $recommendations = [System.Collections.Generic.List[string]]::new()

        foreach (
            $resourceChange in @(
                $planObject.resource_changes
            )
        ) {
            $actions = @(
                $resourceChange.change.actions
            )

            if (
                $actions.Count -eq 1 -and
                $actions[0] -eq "no-op"
            ) {
                continue
            }

            $severity = Get-BKPlanSeverity `
                -Actions $actions `
                -ResourceType ([string]$resourceChange.type)

            $beforeSensitive = @(
                $resourceChange.change.before_sensitive
            )

            $afterSensitive = @(
                $resourceChange.change.after_sensitive
            )

            $changes.Add(
                [PSCustomObject]@{
                    Address         = [string]$resourceChange.address
                    ModuleAddress   = [string]$resourceChange.module_address
                    Mode            = [string]$resourceChange.mode
                    Type            = [string]$resourceChange.type
                    Name            = [string]$resourceChange.name
                    ProviderName    = [string]$resourceChange.provider_name
                    Actions         = $actions
                    ActionSummary   = $actions -join " -> "
                    Severity        = $severity
                    BeforeSensitive = $beforeSensitive.Count -gt 0
                    AfterSensitive  = $afterSensitive.Count -gt 0
                    Before          = $resourceChange.change.before
                    After           = $resourceChange.change.after
                }
            )
        }

        $createCount = @(
            $changes |
                Where-Object {
                    $_.Actions -contains "create" -and
                    $_.Actions -notcontains "delete"
                }
        ).Count

        $updateCount = @(
            $changes |
                Where-Object {
                    $_.Actions -contains "update"
                }
        ).Count

        $deleteCount = @(
            $changes |
                Where-Object {
                    $_.Actions -contains "delete" -and
                    $_.Actions -notcontains "create"
                }
        ).Count

        $replaceCount = @(
            $changes |
                Where-Object {
                    $_.Actions -contains "create" -and
                    $_.Actions -contains "delete"
                }
        ).Count

        $criticalCount = @(
            $changes |
                Where-Object Severity -eq "Critical"
        ).Count

        $highCount = @(
            $changes |
                Where-Object Severity -eq "High"
        ).Count

        $mediumCount = @(
            $changes |
                Where-Object Severity -eq "Medium"
        ).Count

        $lowCount = @(
            $changes |
                Where-Object Severity -eq "Low"
        ).Count

        $sensitiveChangeCount = @(
            $changes |
                Where-Object {
                    $_.BeforeSensitive -or
                    $_.AfterSensitive
                }
        ).Count

        $penalty =
            ($criticalCount * 20) +
            ($highCount * 10) +
            ($mediumCount * 3) +
            ($lowCount * 1)

        if ($penalty -gt 100) {
            $penalty = 100
        }

        $confidence = [math]::Round(
            100 - $penalty,
            2
        )

        $health = Get-BKPlanHealth `
            -Confidence $confidence `
            -CriticalCount $criticalCount `
            -HighCount $highCount

        if ($criticalCount -gt 0) {
            $recommendations.Add(
                "Review all critical Terraform changes before approval or deployment."
            )
        }

        if ($deleteCount -gt 0) {
            $recommendations.Add(
                "Confirm all resource deletions are intentional and recoverable."
            )
        }

        if ($replaceCount -gt 0) {
            $recommendations.Add(
                "Review replacement operations for downtime, object recreation, and identity-impact risk."
            )
        }

        if ($highCount -gt 0) {
            $recommendations.Add(
                "Require peer review for high-severity Terraform changes."
            )
        }

        if ($sensitiveChangeCount -gt 0) {
            $recommendations.Add(
                "Review sensitive-value handling and confirm secrets are not exposed in logs or source control."
            )
        }

        if ($changes.Count -eq 0) {
            $recommendations.Add(
                "Terraform reported no infrastructure changes."
            )
        }

        $result = [PSCustomObject]@{
            Platform    = "Blackknight One"
            Engine      = "Terraform"
            Operation   = "PlanAnalysis"
            GeneratedAt = (
                Get-Date
            ).ToUniversalTime().ToString("o")

            Project = [PSCustomObject]@{
                Path         = $resolvedPath
                PlanFile     = $resolvedPlanFile
                VariableFile = $VariableFile
                Refresh      = [bool]$Refresh
                DestroyPlan  = [bool]$Destroy
            }

            Summary = [PSCustomObject]@{
                TotalChanges     = $changes.Count
                Creates          = $createCount
                Updates          = $updateCount
                Deletes          = $deleteCount
                Replacements     = $replaceCount
                Critical         = $criticalCount
                High             = $highCount
                Medium           = $mediumCount
                Low              = $lowCount
                SensitiveChanges = $sensitiveChangeCount
                Confidence       = $confidence
                Health           = $health
            }

            Changes         = @($changes)
            Recommendations = @(
                $recommendations |
                    Sort-Object -Unique
            )
        }

        Write-Host ""
        Write-Host "Plan Summary" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Total Changes      : $($changes.Count)"
        Write-Host "Creates            : $createCount"
        Write-Host "Updates            : $updateCount"
        Write-Host "Deletes            : $deleteCount"
        Write-Host "Replacements       : $replaceCount"
        Write-Host "Critical Changes   : $criticalCount"
        Write-Host "High Changes       : $highCount"
        Write-Host "Medium Changes     : $mediumCount"
        Write-Host "Low Changes        : $lowCount"
        Write-Host "Sensitive Changes  : $sensitiveChangeCount"
        Write-Host "Plan Confidence    : $confidence%"
        Write-Host "Plan Health        : $health"

        if ($changes.Count -gt 0) {
            Write-Host ""
            Write-Host "Proposed Changes" `
                -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"

            $changes |
                Select-Object `
                    Severity,
                    ActionSummary,
                    Address,
                    Type,
                    ProviderName |
                Format-Table -AutoSize
        }

        if ($recommendations.Count -gt 0) {
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
                    -Depth 30 |
                Set-Content `
                    -LiteralPath $OutputPath `
                    -Encoding utf8

            Write-Host ""
            Write-Host "[Success] Exported JSON report to $OutputPath" `
                -ForegroundColor Green
        }

        if (
            -not $KeepPlanFile -and
            (Test-Path -LiteralPath $resolvedPlanFile)
        ) {
            Remove-Item `
                -LiteralPath $resolvedPlanFile `
                -Force `
                -ErrorAction SilentlyContinue
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