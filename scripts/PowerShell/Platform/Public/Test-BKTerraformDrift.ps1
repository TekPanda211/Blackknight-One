function Test-BKTerraformDrift {
    <#
    .SYNOPSIS
    Detects and confirms actionable Terraform drift.

    .DESCRIPTION
    Performs Terraform drift analysis in two phases.

    Phase 1 runs a refresh-only plan to identify differences between the
    Terraform state and the current remote resource representation.

    Phase 2 runs a normal Terraform plan with refresh enabled to determine
    whether Terraform would actually modify infrastructure to restore the
    declared configuration.

    Refresh-only observations are retained for visibility but are not treated
    as actionable drift unless the normal confirmation plan also reports
    infrastructure changes.

    This command does not run terraform apply.

    .PARAMETER Path
    Specifies the Terraform project directory.

    .PARAMETER VariableFile
    Specifies an optional Terraform variable file.

    .PARAMETER RefreshPlanFile
    Specifies the filename or full path for the refresh-only saved plan.

    .PARAMETER ConfirmationPlanFile
    Specifies the filename or full path for the normal confirmation plan.

    .PARAMETER SkipInit
    Skips terraform init.

    .PARAMETER ExportJson
    Exports the normalized drift report as JSON.

    .PARAMETER OutputPath
    Specifies the JSON report destination.

    .PARAMETER KeepPlanFiles
    Retains the generated Terraform plan files.

    .PARAMETER PassThru
    Returns the complete drift-analysis object.

    .EXAMPLE
    Test-BKTerraformDrift `
        -Path ".\terraform"

    .EXAMPLE
    $DriftResult = Test-BKTerraformDrift `
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
        [ValidateNotNullOrEmpty()]
        [string]$RefreshPlanFile =
            ".bk-terraform-refresh-only.tfplan",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ConfirmationPlanFile =
            ".bk-terraform-drift-confirmation.tfplan",

        [Parameter()]
        [switch]$SkipInit,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\terraform\terraform-drift.json",

        [Parameter()]
        [switch]$KeepPlanFiles,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = "Stop"

    function Invoke-BKTerraformProcess {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Executable,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$ArgumentList,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
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
            $null = $startInfo.ArgumentList.Add(
                [string]$argument
            )
        }

        $process =
            [System.Diagnostics.Process]::new()

        $process.StartInfo = $startInfo

        try {
            if (-not $process.Start()) {
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
                CommandLine      = (
                    "$Executable $($ArgumentList -join ' ')"
                )
                WorkingDirectory = $WorkingDirectory
                ExitCode         = $process.ExitCode
                StandardOutput   = $standardOutput.Trim()
                StandardError    = $standardError.Trim()
                Succeeded        = (
                    $process.ExitCode -in @(0, 2)
                )
            }
        }
        finally {
            $process.Dispose()
        }
    }

    function Get-BKResolvedPlanPath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$PlanFile,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$WorkingDirectory
        )

        if ([System.IO.Path]::IsPathRooted($PlanFile)) {
            return [System.IO.Path]::GetFullPath(
                $PlanFile
            )
        }

        return [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $WorkingDirectory `
                    -ChildPath $PlanFile
            )
        )
    }

    function Get-BKTerraformPlanObject {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$TerraformExecutable,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$PlanFile,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$WorkingDirectory
        )

        if (
            -not (
                Test-Path `
                    -LiteralPath $PlanFile `
                    -PathType Leaf
            )
        ) {
            throw "Terraform saved plan was not found: $PlanFile"
        }

        $showResult =
            Invoke-BKTerraformProcess `
                -Executable $TerraformExecutable `
                -ArgumentList @(
                    "show"
                    "-json"
                    $PlanFile
                ) `
                -WorkingDirectory $WorkingDirectory

        if (-not $showResult.Succeeded) {
            $failureMessage = @(
                "Terraform plan JSON conversion failed."
                $showResult.StandardOutput
                $showResult.StandardError
            ) |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }

            throw (
                $failureMessage -join
                [Environment]::NewLine
            )
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $showResult.StandardOutput
            )
        ) {
            throw "Terraform show returned no JSON output."
        }

        return (
            $showResult.StandardOutput |
                ConvertFrom-Json `
                    -Depth 100 `
                    -ErrorAction Stop
        )
    }

    function Get-BKResourceTypeFromAddress {
        [CmdletBinding()]
        param(
            [AllowNull()]
            [AllowEmptyString()]
            [string]$Address
        )

        if ([string]::IsNullOrWhiteSpace($Address)) {
            return "unknown"
        }

        $addressWithoutIndexes =
            $Address -replace '\[[^\]]+\]', ''

        $addressParts =
            $addressWithoutIndexes -split '\.'

        $resourceIndex = -1

        for (
            $index = 0;
            $index -lt $addressParts.Count;
            $index++
        ) {
            if ($addressParts[$index] -eq "module") {
                $index++
                continue
            }

            $resourceIndex = $index
            break
        }

        if (
            $resourceIndex -ge 0 -and
            $resourceIndex -lt $addressParts.Count
        ) {
            return [string]$addressParts[$resourceIndex]
        }

        return "unknown"
    }

    function Test-BKTerraformSensitiveMarker {
        [CmdletBinding()]
        param(
            [AllowNull()]
            [object]$Value
        )

        if ($null -eq $Value) {
            return $false
        }

        if ($Value -is [bool]) {
            return [bool]$Value
        }

        if ($Value -is [string]) {
            return $false
        }

        if (
            $Value -is
            [System.Collections.IDictionary]
        ) {
            foreach ($key in $Value.Keys) {
                if (
                    Test-BKTerraformSensitiveMarker `
                        -Value $Value[$key]
                ) {
                    return $true
                }
            }

            return $false
        }

        if (
            $Value -is
            [System.Collections.IEnumerable]
        ) {
            foreach ($item in $Value) {
                if (
                    Test-BKTerraformSensitiveMarker `
                        -Value $item
                ) {
                    return $true
                }
            }

            return $false
        }

        if ($null -ne $Value.PSObject) {
            foreach (
                $property in
                $Value.PSObject.Properties
            ) {
                if (
                    Test-BKTerraformSensitiveMarker `
                        -Value $property.Value
                ) {
                    return $true
                }
            }
        }

        return $false
    }

    function Get-BKTerraformDriftSeverity {
        <#
        .SYNOPSIS
        Classifies confirmed Terraform drift severity.

        .DESCRIPTION
        Assigns severity based on Terraform resource type and the actions
        Terraform would perform.

        Privileged identity, role, policy, permission, credential,
        application, and service-principal resources receive elevated
        severity.

        .PARAMETER ResourceType
        Specifies the Terraform resource type.

        .PARAMETER Actions
        Specifies the Terraform actions associated with the change.
        #>

        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$ResourceType,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$Actions
        )

        if (
            [string]::IsNullOrWhiteSpace(
                $ResourceType
            )
        ) {
            $ResourceType = "unknown"
        }

        $normalizedResourceType =
            $ResourceType.ToLowerInvariant()

        $criticalPatterns = @(
            "directory_role"
            "role_assignment"
            "role_assignable"
            "conditional_access"
            "policy"
            "permission"
            "credential"
            "secret"
            "password"
            "certificate"
            "service_principal"
            "application"
            "app_role"
            "oauth2"
            "federated_identity"
        )

        $identityPatterns = @(
            "group"
            "member"
            "owner"
            "administrative_unit"
            "authentication"
            "authorization"
            "identity"
            "user"
        )

        $isCriticalResource = $false
        $isIdentityResource = $false

        foreach ($pattern in $criticalPatterns) {
            if (
                $normalizedResourceType -match
                [regex]::Escape($pattern)
            ) {
                $isCriticalResource = $true
                break
            }
        }

        foreach ($pattern in $identityPatterns) {
            if (
                $normalizedResourceType -match
                [regex]::Escape($pattern)
            ) {
                $isIdentityResource = $true
                break
            }
        }

        $normalizedActions = @(
            $Actions |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                ForEach-Object {
                    ([string]$_).ToLowerInvariant()
                }
        )

        $isReplacement = (
            $normalizedActions -contains "create" -and
            $normalizedActions -contains "delete"
        )

        $isDelete =
            $normalizedActions -contains "delete"

        $isUpdate =
            $normalizedActions -contains "update"

        $isCreate =
            $normalizedActions -contains "create"

        if ($isReplacement) {
            if ($isCriticalResource) {
                return "Critical"
            }

            return "High"
        }

        if ($isDelete) {
            if ($isCriticalResource) {
                return "Critical"
            }

            return "High"
        }

        if ($isUpdate) {
            if ($isCriticalResource) {
                return "High"
            }

            if ($isIdentityResource) {
                return "Medium"
            }

            return "Medium"
        }

        if ($isCreate) {
            if ($isCriticalResource) {
                return "High"
            }

            if ($isIdentityResource) {
                return "Medium"
            }

            return "Low"
        }

        return "Informational"
    }

    function Get-BKTerraformDriftHealth {
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

    function ConvertTo-BKTerraformChange {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [object]$ResourceChange,

            [Parameter(Mandatory)]
            [ValidateSet(
                "RefreshObservation",
                "ConfirmedDrift"
            )]
            [string]$Source
        )

        if (
            $null -eq $ResourceChange -or
            $null -eq $ResourceChange.change
        ) {
            return $null
        }

        $actions = @(
            $ResourceChange.change.actions |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }
        )

        if ($actions.Count -eq 0) {
            return $null
        }

        if (
            $actions.Count -eq 1 -and
            $actions[0] -eq "no-op"
        ) {
            return $null
        }

        $resourceAddress =
            [string]$ResourceChange.address

        $resourceType =
            [string]$ResourceChange.type

        if (
            [string]::IsNullOrWhiteSpace(
                $resourceType
            )
        ) {
            $resourceType =
                Get-BKResourceTypeFromAddress `
                    -Address $resourceAddress
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $resourceType
            )
        ) {
            $resourceType = "unknown"
        }

        $severity = if (
            $Source -eq "ConfirmedDrift"
        ) {
            Get-BKTerraformDriftSeverity `
                -ResourceType $resourceType `
                -Actions $actions
        }
        else {
            "Informational"
        }

        $beforeSensitive =
            Test-BKTerraformSensitiveMarker `
                -Value (
                    $ResourceChange.change.before_sensitive
                )

        $afterSensitive =
            Test-BKTerraformSensitiveMarker `
                -Value (
                    $ResourceChange.change.after_sensitive
                )

        return [PSCustomObject]@{
            Address         = $resourceAddress
            ModuleAddress   = (
                [string]$ResourceChange.module_address
            )
            Mode            = (
                [string]$ResourceChange.mode
            )
            Type            = $resourceType
            Name            = (
                [string]$ResourceChange.name
            )
            ProviderName    = (
                [string]$ResourceChange.provider_name
            )
            Actions         = @($actions)
            ActionSummary   = $actions -join " -> "
            Severity        = $severity
            Source          = $Source
            BeforeSensitive = $beforeSensitive
            AfterSensitive  = $afterSensitive
            Before          = (
                $ResourceChange.change.before
            )
            After           = (
                $ResourceChange.change.after
            )
        }
    }

    function Remove-BKTerraformTemporaryPlan {
        [CmdletBinding()]
        param(
            [AllowNull()]
            [AllowEmptyString()]
            [string]$PlanPath
        )

        if (
            $KeepPlanFiles.IsPresent -or
            [string]::IsNullOrWhiteSpace(
                $PlanPath
            )
        ) {
            return
        }

        if (Test-Path -LiteralPath $PlanPath) {
            Remove-Item `
                -LiteralPath $PlanPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host (
        "============================================================"
    ) -ForegroundColor Cyan

    Write-Host (
        "              BLACKKNIGHT TERRAFORM DRIFT TEST"
    ) -ForegroundColor Cyan

    Write-Host (
        "============================================================"
    ) -ForegroundColor Cyan

    $resolvedRefreshPlanFile = $null
    $resolvedConfirmationPlanFile = $null

    try {
        $terraformCommand =
            Get-Command `
                -Name "terraform" `
                -ErrorAction SilentlyContinue

        if (-not $terraformCommand) {
            throw "Terraform CLI was not found in PATH."
        }

        if (
            -not (
                Test-Path `
                    -LiteralPath $Path `
                    -PathType Container
            )
        ) {
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
            throw (
                "No Terraform configuration files were found in: " +
                $resolvedPath
            )
        }

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
                throw (
                    "Terraform variable file was not found: " +
                    $VariableFile
                )
            }

            $resolvedVariableFile = (
                Resolve-Path `
                    -LiteralPath $VariableFile `
                    -ErrorAction Stop
            ).Path
        }

        $resolvedRefreshPlanFile =
            Get-BKResolvedPlanPath `
                -PlanFile $RefreshPlanFile `
                -WorkingDirectory $resolvedPath

        $resolvedConfirmationPlanFile =
            Get-BKResolvedPlanPath `
                -PlanFile $ConfirmationPlanFile `
                -WorkingDirectory $resolvedPath

        if (-not $SkipInit) {
            Write-Host ""
            Write-Host "Initializing Terraform..." `
                -ForegroundColor Yellow

            $initResult =
                Invoke-BKTerraformProcess `
                    -Executable $terraformCommand.Source `
                    -ArgumentList @(
                        "init"
                        "-input=false"
                        "-no-color"
                    ) `
                    -WorkingDirectory $resolvedPath

            if (-not $initResult.Succeeded) {
                $initFailure = @(
                    "Terraform initialization failed."
                    $initResult.StandardOutput
                    $initResult.StandardError
                ) |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$_
                        )
                    }

                throw (
                    $initFailure -join
                    [Environment]::NewLine
                )
            }
        }

        #
        # Phase 1: Refresh-only observation
        #

        $refreshArguments = @(
            "plan"
            "-refresh-only"
            "-detailed-exitcode"
            "-input=false"
            "-no-color"
            "-out=$resolvedRefreshPlanFile"
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $resolvedVariableFile
            )
        ) {
            $refreshArguments +=
                "-var-file=$resolvedVariableFile"
        }

        Write-Host ""
        Write-Host (
            "Phase 1 of 2: Running refresh-only Terraform observation..."
        ) -ForegroundColor Yellow

        $refreshResult =
            Invoke-BKTerraformProcess `
                -Executable $terraformCommand.Source `
                -ArgumentList $refreshArguments `
                -WorkingDirectory $resolvedPath

        if ($refreshResult.ExitCode -eq 1) {
            $refreshFailure = @(
                "Terraform refresh-only plan failed."
                $refreshResult.StandardOutput
                $refreshResult.StandardError
            ) |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }

            throw (
                $refreshFailure -join
                [Environment]::NewLine
            )
        }

        $stateDifferenceObserved =
            $refreshResult.ExitCode -eq 2

        $refreshObservations =
            [System.Collections.Generic.List[object]]::new()

        if ($stateDifferenceObserved) {
            Write-Host (
                "Inspecting refresh-only plan JSON..."
            ) -ForegroundColor Yellow

            $refreshPlanObject =
                Get-BKTerraformPlanObject `
                    -TerraformExecutable (
                        $terraformCommand.Source
                    ) `
                    -PlanFile $resolvedRefreshPlanFile `
                    -WorkingDirectory $resolvedPath

            $refreshChanges = @()

            if (
                $null -ne
                $refreshPlanObject.resource_drift
            ) {
                $refreshChanges = @(
                    $refreshPlanObject.resource_drift |
                        Where-Object {
                            $null -ne $_
                        }
                )
            }
            elseif (
                $null -ne
                $refreshPlanObject.resource_changes
            ) {
                $refreshChanges = @(
                    $refreshPlanObject.resource_changes |
                        Where-Object {
                            $null -ne $_
                        }
                )
            }

            foreach ($resourceChange in $refreshChanges) {
                $observation =
                    ConvertTo-BKTerraformChange `
                        -ResourceChange $resourceChange `
                        -Source "RefreshObservation"

                if ($null -ne $observation) {
                    $null = $refreshObservations.Add(
                        $observation
                    )
                }
            }
        }

        #
        # Phase 2: Normal plan confirmation
        #

        $confirmationArguments = @(
            "plan"
            "-detailed-exitcode"
            "-refresh=true"
            "-input=false"
            "-no-color"
            "-out=$resolvedConfirmationPlanFile"
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $resolvedVariableFile
            )
        ) {
            $confirmationArguments +=
                "-var-file=$resolvedVariableFile"
        }

        Write-Host ""
        Write-Host (
            "Phase 2 of 2: Running normal Terraform confirmation plan..."
        ) -ForegroundColor Yellow

        $confirmationResult =
            Invoke-BKTerraformProcess `
                -Executable $terraformCommand.Source `
                -ArgumentList $confirmationArguments `
                -WorkingDirectory $resolvedPath

        if ($confirmationResult.ExitCode -eq 1) {
            $confirmationFailure = @(
                "Terraform confirmation plan failed."
                $confirmationResult.StandardOutput
                $confirmationResult.StandardError
            ) |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }

            throw (
                $confirmationFailure -join
                [Environment]::NewLine
            )
        }

        $actionableDriftDetected =
            $confirmationResult.ExitCode -eq 2

        $confirmedDriftItems =
            [System.Collections.Generic.List[object]]::new()

        if ($actionableDriftDetected) {
            Write-Host (
                "Inspecting confirmed Terraform changes..."
            ) -ForegroundColor Yellow

            $confirmationPlanObject =
                Get-BKTerraformPlanObject `
                    -TerraformExecutable (
                        $terraformCommand.Source
                    ) `
                    -PlanFile (
                        $resolvedConfirmationPlanFile
                    ) `
                    -WorkingDirectory $resolvedPath

            $confirmedChanges = @()

            if (
                $null -ne
                $confirmationPlanObject.resource_changes
            ) {
                $confirmedChanges = @(
                    $confirmationPlanObject.resource_changes |
                        Where-Object {
                            $null -ne $_
                        }
                )
            }

            foreach ($resourceChange in $confirmedChanges) {
                $confirmedChange =
                    ConvertTo-BKTerraformChange `
                        -ResourceChange $resourceChange `
                        -Source "ConfirmedDrift"

                if ($null -ne $confirmedChange) {
                    $null = $confirmedDriftItems.Add(
                        $confirmedChange
                    )
                }
            }

            if ($confirmedDriftItems.Count -eq 0) {
                $actionableDriftDetected = $false
            }
        }

        #
        # Confirmed drift statistics
        #

        $criticalCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Severity -eq "Critical"
                }
        ).Count

        $highCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Severity -eq "High"
                }
        ).Count

        $mediumCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Severity -eq "Medium"
                }
        ).Count

        $lowCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Severity -eq "Low"
                }
        ).Count

        $informationalCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Severity -eq "Informational"
                }
        ).Count

        $deleteCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Actions -contains "delete"
                }
        ).Count

        $updateCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Actions -contains "update"
                }
        ).Count

        $createCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Actions -contains "create"
                }
        ).Count

        $replacementCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.Actions -contains "create" -and
                    $_.Actions -contains "delete"
                }
        ).Count

        $sensitiveCount = @(
            $confirmedDriftItems |
                Where-Object {
                    $_.BeforeSensitive -or
                    $_.AfterSensitive
                }
        ).Count

        #
        # Confidence uses confirmed drift only
        #

        $penalty =
            ($criticalCount * 25) +
            ($highCount * 12) +
            ($mediumCount * 4) +
            ($lowCount * 1)

        if ($penalty -gt 100) {
            $penalty = 100
        }

        $confidence = [math]::Round(
            100 - $penalty,
            2
        )

        $health =
            Get-BKTerraformDriftHealth `
                -Confidence $confidence `
                -CriticalCount $criticalCount `
                -HighCount $highCount

        $recommendations =
            [System.Collections.Generic.List[string]]::new()

        if (-not $stateDifferenceObserved) {
            $recommendations.Add(
                "No Terraform state differences were observed."
            )
        }
        elseif (
            $stateDifferenceObserved -and
            -not $actionableDriftDetected
        ) {
            $recommendations.Add(
                "Terraform observed refresh-only state differences, but the normal confirmation plan reported no infrastructure changes. No actionable drift is present."
            )
        }

        if (
            $refreshObservations.Count -gt 0 -and
            -not $actionableDriftDetected
        ) {
            $recommendations.Add(
                "Refresh-only observations were retained as provider-normalized, computed, or state-only differences."
            )
        }

        if ($criticalCount -gt 0) {
            $recommendations.Add(
                "Resolve critical confirmed Terraform drift before release or production changes."
            )
        }

        if ($highCount -gt 0) {
            $recommendations.Add(
                "Review high-severity confirmed drift and verify whether remote changes were authorized."
            )
        }

        if ($deleteCount -gt 0) {
            $recommendations.Add(
                "Investigate confirmed resource deletions or missing remote resources."
            )
        }

        if ($replacementCount -gt 0) {
            $recommendations.Add(
                "Review confirmed replacement operations for object recreation, identity impact, and service interruption."
            )
        }

        if ($updateCount -gt 0) {
            $recommendations.Add(
                "Review confirmed remote updates and determine whether Terraform should restore the declared configuration."
            )
        }

        if ($createCount -gt 0) {
            $recommendations.Add(
                "Review confirmed resource creation actions before deployment."
            )
        }

        if ($sensitiveCount -gt 0) {
            $recommendations.Add(
                "Review sensitive confirmed changes and prevent secret values from being exposed in reports or logs."
            )
        }

        if (-not $actionableDriftDetected) {
            $recommendations.Add(
                "The Terraform configuration currently matches the infrastructure configuration."
            )
        }

        $result = [PSCustomObject]@{
            Platform    = "Blackknight One"
            Engine      = "Terraform"
            Operation   = "DriftDetection"
            GeneratedAt = (
                Get-Date
            ).ToUniversalTime().ToString("o")

            Project = [PSCustomObject]@{
                Path                 = $resolvedPath
                VariableFile         = $resolvedVariableFile
                RefreshPlanFile      = (
                    $resolvedRefreshPlanFile
                )
                ConfirmationPlanFile = (
                    $resolvedConfirmationPlanFile
                )
                SkipInit             = $SkipInit.IsPresent
            }

            Summary = [PSCustomObject]@{
                StateDifferenceObserved = (
                    $stateDifferenceObserved
                )
                RefreshObservations     = (
                    $refreshObservations.Count
                )
                ActionableDriftDetected = (
                    $actionableDriftDetected
                )
                ConfirmedDrift          = (
                    $confirmedDriftItems.Count
                )
                DriftDetected           = (
                    $actionableDriftDetected
                )
                TotalDrift              = (
                    $confirmedDriftItems.Count
                )
                Creates                 = $createCount
                Updates                 = $updateCount
                Deletes                 = $deleteCount
                Replacements            = $replacementCount
                Critical                = $criticalCount
                High                    = $highCount
                Medium                  = $mediumCount
                Low                     = $lowCount
                Informational           = (
                    $informationalCount
                )
                SensitiveChanges        = (
                    $sensitiveCount
                )
                Confidence              = $confidence
                Health                  = $health
                Penalty                 = $penalty
            }

            RefreshObservations = @(
                $refreshObservations
            )

            DriftItems = @(
                $confirmedDriftItems
            )

            Recommendations = @(
                $recommendations |
                    Sort-Object -Unique
            )

            Terraform = [PSCustomObject]@{
                RefreshOnly = [PSCustomObject]@{
                    ExitCode = (
                        $refreshResult.ExitCode
                    )
                    StandardOutput = (
                        $refreshResult.StandardOutput
                    )
                    StandardError = (
                        $refreshResult.StandardError
                    )
                }

                Confirmation = [PSCustomObject]@{
                    ExitCode = (
                        $confirmationResult.ExitCode
                    )
                    StandardOutput = (
                        $confirmationResult.StandardOutput
                    )
                    StandardError = (
                        $confirmationResult.StandardError
                    )
                }
            }
        }

        Write-Host ""
        Write-Host "Drift Summary" `
            -ForegroundColor Yellow

        Write-Host (
            "------------------------------------------------------------"
        )

        Write-Host (
            "State Difference Observed : " +
            $stateDifferenceObserved
        )

        Write-Host (
            "Refresh Observations      : " +
            $refreshObservations.Count
        )

        Write-Host (
            "Actionable Drift Detected : " +
            $actionableDriftDetected
        )

        Write-Host (
            "Confirmed Drift Items     : " +
            $confirmedDriftItems.Count
        )

        Write-Host "Creates                   : $createCount"
        Write-Host "Updates                   : $updateCount"
        Write-Host "Deletes                   : $deleteCount"
        Write-Host "Replacements              : $replacementCount"
        Write-Host "Critical Drift            : $criticalCount"
        Write-Host "High Drift                : $highCount"
        Write-Host "Medium Drift              : $mediumCount"
        Write-Host "Low Drift                 : $lowCount"
        Write-Host "Sensitive Changes         : $sensitiveCount"
        Write-Host "Drift Confidence          : $confidence%"
        Write-Host "Drift Health              : $health"

        if ($confirmedDriftItems.Count -gt 0) {
            Write-Host ""
            Write-Host "Confirmed Drift" `
                -ForegroundColor Yellow

            Write-Host (
                "------------------------------------------------------------"
            )

            $confirmedDriftItems |
    Select-Object `
        Severity,
        ActionSummary,
        Address,
        Type,
        ProviderName |
    Format-Table -AutoSize |
    Out-Host
        }

        if (
            $refreshObservations.Count -gt 0 -and
            -not $actionableDriftDetected
        ) {
            Write-Host ""
            Write-Host "State-Only Observations" `
                -ForegroundColor DarkYellow

            Write-Host (
                "------------------------------------------------------------"
            )

            $refreshObservations |
    Select-Object `
        ActionSummary,
        Address,
        Type,
        ProviderName |
    Format-Table -AutoSize |
    Out-Host
        }

        Write-Host ""
        Write-Host "Recommendations" `
            -ForegroundColor Yellow

        Write-Host (
            "------------------------------------------------------------"
        )

        foreach (
            $recommendation in @(
                $recommendations |
                    Sort-Object -Unique
            )
        ) {
            Write-Host "- $recommendation"
        }

        if ($ExportJson) {
            $outputDirectory =
                Split-Path `
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
            Write-Host (
                "[Success] Exported JSON report to $OutputPath"
            ) -ForegroundColor Green
        }

        Remove-BKTerraformTemporaryPlan `
            -PlanPath $resolvedRefreshPlanFile

        Remove-BKTerraformTemporaryPlan `
            -PlanPath $resolvedConfirmationPlanFile

        Write-Host ""
        Write-Host (
            "============================================================"
        ) -ForegroundColor Cyan

        if ($PassThru) {
            return $result
        }
    }
    catch {
        Remove-BKTerraformTemporaryPlan `
            -PlanPath $resolvedRefreshPlanFile

        Remove-BKTerraformTemporaryPlan `
            -PlanPath $resolvedConfirmationPlanFile

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