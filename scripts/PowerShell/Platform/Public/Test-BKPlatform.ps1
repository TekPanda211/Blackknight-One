function Test-BKPlatform {
    <#
    .SYNOPSIS
    Runs the Blackknight One platform quality gate.

    .DESCRIPTION
    Validates repository health and operational readiness across:

    - Required repository paths
    - Configuration directories
    - Service registry
    - Engine manifests
    - Engine dependencies
    - PowerShell syntax
    - JSON syntax
    - Documentation structure
    - Report folders
    - Terraform readiness and state hygiene
    - Microsoft Graph readiness

    The quality gate produces:

    - Repository Health
    - Operational Readiness
    - Validation Confidence
    - Weighted findings
    - Hard health caps for critical and high-severity failures
    - Release recommendation

    .PARAMETER Quiet
    Suppresses formatted console output and returns the validation object.

    .PARAMETER PassThru
    Displays the report and also returns the validation object.

    .PARAMETER ExportJson
    Exports the validation report as JSON.

    .PARAMETER OutputPath
    Specifies the JSON report path.

    .EXAMPLE
    Test-BKPlatform

    .EXAMPLE
    $Validation = Test-BKPlatform -Quiet

    .EXAMPLE
    Test-BKPlatform -ExportJson

    .EXAMPLE
    Test-BKPlatform `
        -ExportJson `
        -OutputPath ".\reports\validation\quality-gate.json"
    #>

    [CmdletBinding()]
    param(
        [switch]$Quiet,

        [switch]$PassThru,

        [switch]$ExportJson,

        [string]$OutputPath =
            ".\reports\validation\platform-validation.json"
    )

    $repoRoot = (Get-Location).Path

    $results = [System.Collections.Generic.List[object]]::new()

    $severityWeights = @{
        Informational = 0
        Low           = 0.25
        Medium        = 1
        High          = 3
        Critical      = 5
    }

    function Add-BKValidationResult {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Category,

            [Parameter(Mandatory)]
            [string]$Check,

            [Parameter(Mandatory)]
            [ValidateSet(
                "PASS",
                "WARN",
                "FAIL"
            )]
            [string]$Status,

            [Parameter(Mandatory)]
            [ValidateSet(
                "Repository",
                "Operational"
            )]
            [string]$Domain,

            [ValidateSet(
                "Informational",
                "Low",
                "Medium",
                "High",
                "Critical"
            )]
            [string]$Severity = "Informational",

            [AllowNull()]
            [string]$Details,

            [AllowNull()]
            [string]$Path,

            [AllowNull()]
            [string]$Recommendation
        )

        $weight = 0

        if (
            $Status -ne "PASS" -and
            $severityWeights.ContainsKey($Severity)
        ) {
            $weight = [double]$severityWeights[$Severity]
        }

        $results.Add(
            [PSCustomObject]@{
                Category       = $Category
                Check          = $Check
                Status         = $Status
                Domain         = $Domain
                Severity       = $Severity
                Weight         = $weight
                Details        = $Details
                Path           = $Path
                Recommendation = $Recommendation
                Timestamp      = (
                    Get-Date
                ).ToUniversalTime().ToString("o")
            }
        )
    }

    function Test-BKRequiredPath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Category,

            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [string]$Path,

            [ValidateSet(
                "File",
                "Directory",
                "Any"
            )]
            [string]$PathType = "Any",

            [ValidateSet(
                "Repository",
                "Operational"
            )]
            [string]$Domain = "Repository",

            [ValidateSet(
                "Informational",
                "Low",
                "Medium",
                "High",
                "Critical"
            )]
            [string]$MissingSeverity = "High"
        )

        if (-not (Test-Path -LiteralPath $Path)) {
            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "FAIL" `
                -Domain $Domain `
                -Severity $MissingSeverity `
                -Details "Required path was not found." `
                -Path $Path `
                -Recommendation "Restore or create the required path."

            return $false
        }

        $item = Get-Item `
            -LiteralPath $Path `
            -ErrorAction SilentlyContinue

        $typeMatches = switch ($PathType) {
            "File" {
                -not $item.PSIsContainer
            }

            "Directory" {
                $item.PSIsContainer
            }

            default {
                $true
            }
        }

        if ($typeMatches) {
            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "PASS" `
                -Domain $Domain `
                -Severity "Informational" `
                -Details "Required path is present." `
                -Path $Path

            return $true
        }

        Add-BKValidationResult `
            -Category $Category `
            -Check $Name `
            -Status "FAIL" `
            -Domain $Domain `
            -Severity $MissingSeverity `
            -Details "The path exists but is not the expected type: $PathType." `
            -Path $Path `
            -Recommendation "Correct the repository path type."

        return $false
    }

    function Test-BKJsonDocument {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Category,

            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [string]$Path,

            [ValidateSet(
                "Repository",
                "Operational"
            )]
            [string]$Domain = "Repository"
        )

        if (-not (Test-Path -LiteralPath $Path)) {
            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "FAIL" `
                -Domain $Domain `
                -Severity "High" `
                -Details "JSON file was not found." `
                -Path $Path `
                -Recommendation "Restore or create the required JSON document."

            return $null
        }

        $file = Get-Item `
            -LiteralPath $Path `
            -ErrorAction SilentlyContinue

        if (
            $null -eq $file -or
            $file.Length -eq 0
        ) {
            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "FAIL" `
                -Domain $Domain `
                -Severity "High" `
                -Details "JSON file is empty." `
                -Path $Path `
                -Recommendation "Populate the file with valid JSON."

            return $null
        }

        try {
            $content = Get-Content `
                -LiteralPath $Path `
                -Raw `
                -ErrorAction Stop

            $json = $content |
                ConvertFrom-Json `
                    -ErrorAction Stop

            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "PASS" `
                -Domain $Domain `
                -Severity "Informational" `
                -Details "JSON document is valid." `
                -Path $Path

            return $json
        }
        catch {
            Add-BKValidationResult `
                -Category $Category `
                -Check $Name `
                -Status "FAIL" `
                -Domain $Domain `
                -Severity "Critical" `
                -Details $_.Exception.Message `
                -Path $Path `
                -Recommendation "Correct the JSON syntax."

            return $null
        }
    }

    function Get-BKHealthFromConfidence {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [double]$Confidence
        )

        if ($Confidence -ge 98) {
            return "Excellent"
        }

        if ($Confidence -ge 90) {
            return "Healthy"
        }

        if ($Confidence -ge 75) {
            return "Warning"
        }

        if ($Confidence -ge 50) {
            return "Needs Attention"
        }

        return "Critical"
    }

    function Get-BKHealthColor {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Health
        )

        switch ($Health) {
            "Excellent" {
                return "Green"
            }

            "Healthy" {
                return "Green"
            }

            "Warning" {
                return "Yellow"
            }

            "Needs Attention" {
                return "DarkYellow"
            }

            default {
                return "Red"
            }
        }
    }

    function Get-BKDomainSummary {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateSet(
                "Repository",
                "Operational"
            )]
            [string]$Domain
        )

        $domainResults = @(
            $results |
                Where-Object {
                    $_.Domain -eq $Domain
                }
        )

        $total = $domainResults.Count

        $passed = @(
            $domainResults |
                Where-Object {
                    $_.Status -eq "PASS"
                }
        ).Count

        $warnings = @(
            $domainResults |
                Where-Object {
                    $_.Status -eq "WARN"
                }
        ).Count

        $failed = @(
            $domainResults |
                Where-Object {
                    $_.Status -eq "FAIL"
                }
        ).Count

        $penalty = (
            $domainResults |
                Measure-Object `
                    -Property Weight `
                    -Sum
        ).Sum

        if ($null -eq $penalty) {
            $penalty = 0
        }

        $maximumPenalty = if ($total -gt 0) {
            $total * $severityWeights.Critical
        }
        else {
            0
        }

        $confidence = if ($maximumPenalty -gt 0) {
            [math]::Round(
                (
                    1 -
                    (
                        $penalty /
                        $maximumPenalty
                    )
                ) * 100,
                2
            )
        }
        else {
            100
        }

        if ($confidence -lt 0) {
            $confidence = 0
        }

        [PSCustomObject]@{
            Domain     = $Domain
            Total      = $total
            Passed     = $passed
            Warnings   = $warnings
            Failed     = $failed
            Penalty    = [math]::Round(
                $penalty,
                2
            )
            Confidence = $confidence
            Health     = Get-BKHealthFromConfidence `
                -Confidence $confidence
        }
    }

    function Set-BKHealthCaps {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [object]$Summary,

            [Parameter(Mandatory)]
            [object[]]$DomainResults
        )

        $criticalFailures = @(
            $DomainResults |
                Where-Object {
                    $_.Status -eq "FAIL" -and
                    $_.Severity -eq "Critical"
                }
        ).Count

        $highFailures = @(
            $DomainResults |
                Where-Object {
                    $_.Status -eq "FAIL" -and
                    $_.Severity -eq "High"
                }
        ).Count

        if ($criticalFailures -gt 0) {
            $Summary.Health = "Needs Attention"
        }
        elseif (
            $highFailures -gt 0 -and
            $Summary.Health -in @(
                "Excellent",
                "Healthy"
            )
        ) {
            $Summary.Health = "Warning"
        }

        return $Summary
    }

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan
        Write-Host "               BLACKKNIGHT ONE QUALITY GATE" `
            -ForegroundColor Cyan
        Write-Host "============================================================" `
            -ForegroundColor Cyan
    }

    try {
        #
        # Repository paths
        #

        $platformModule = Join-Path `
            $repoRoot `
            "scripts\PowerShell\Platform\Blackknight-Platform.psm1"

        $coreEngine = Join-Path `
            $repoRoot `
            "scripts\PowerShell\Core\Invoke-BlackKnight.ps1"

        $scriptsRoot = Join-Path `
            $repoRoot `
            "scripts\PowerShell"

        $publicRoot = Join-Path `
            $repoRoot `
            "scripts\PowerShell\Platform\Public"

        $servicesManifestPath = Join-Path `
            $repoRoot `
            "scripts\PowerShell\Platform\Services\services.json"

        $reportsRoot = Join-Path `
            $repoRoot `
            "reports"

        $docsRoot = Join-Path `
            $repoRoot `
            "docs"

        $schemasRoot = Join-Path `
            $repoRoot `
            "schemas"

        $terraformRoot = Join-Path `
            $repoRoot `
            "terraform"

        #
        # Support both config and configurations
        #

        $configurationCandidates = @(
            (Join-Path $repoRoot "config")
            (Join-Path $repoRoot "configurations")
        )

        $configurationRoots = @(
            $configurationCandidates |
                Where-Object {
                    Test-Path -LiteralPath $_
                }
        )

        if ($configurationRoots.Count -gt 0) {
            Add-BKValidationResult `
                -Category "Repository" `
                -Check "Configuration Directories" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "$($configurationRoots.Count) supported configuration directory or directories detected." `
                -Path ($configurationRoots -join "; ")
        }
        else {
            Add-BKValidationResult `
                -Category "Repository" `
                -Check "Configuration Directories" `
                -Status "WARN" `
                -Domain "Repository" `
                -Severity "Medium" `
                -Details "Neither 'config' nor 'configurations' was found." `
                -Path $repoRoot `
                -Recommendation "Create either config or configurations, or update the platform configuration paths."
        }

        if ($configurationRoots.Count -gt 1) {
            Add-BKValidationResult `
                -Category "Repository" `
                -Check "Multiple Configuration Directories" `
                -Status "WARN" `
                -Domain "Repository" `
                -Severity "Low" `
                -Details "Both config and configurations exist." `
                -Path ($configurationRoots -join "; ") `
                -Recommendation "Confirm whether both directories are intentional and document their responsibilities."
        }
        else {
            $configurationPath = if ($configurationRoots.Count -eq 1) {
                $configurationRoots[0]
            }
            else {
                $repoRoot
            }

            Add-BKValidationResult `
                -Category "Repository" `
                -Check "Multiple Configuration Directories" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "No configuration-directory ambiguity detected." `
                -Path $configurationPath
        }

        #
        # Repository foundation
        #

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Platform Module" `
            -Path $platformModule `
            -PathType File `
            -Domain Repository `
            -MissingSeverity Critical |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Core Engine" `
            -Path $coreEngine `
            -PathType File `
            -Domain Repository `
            -MissingSeverity High |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "PowerShell Root" `
            -Path $scriptsRoot `
            -PathType Directory `
            -Domain Repository `
            -MissingSeverity Critical |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Public Services Folder" `
            -Path $publicRoot `
            -PathType Directory `
            -Domain Repository `
            -MissingSeverity High |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Reports Folder" `
            -Path $reportsRoot `
            -PathType Directory `
            -Domain Operational `
            -MissingSeverity Medium |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Documentation Folder" `
            -Path $docsRoot `
            -PathType Directory `
            -Domain Repository `
            -MissingSeverity Medium |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Schema Folder" `
            -Path $schemasRoot `
            -PathType Directory `
            -Domain Repository `
            -MissingSeverity Medium |
            Out-Null

        Test-BKRequiredPath `
            -Category "Repository" `
            -Name "Terraform Folder" `
            -Path $terraformRoot `
            -PathType Directory `
            -Domain Operational `
            -MissingSeverity Medium |
            Out-Null

        #
        # Service registry
        #

        $serviceManifest = Test-BKJsonDocument `
            -Category "Registry" `
            -Name "Service Manifest JSON" `
            -Path $servicesManifestPath `
            -Domain Repository

        if (
            $serviceManifest -and
            $serviceManifest.Services
        ) {
            $services = @($serviceManifest.Services)

            Add-BKValidationResult `
                -Category "Registry" `
                -Check "Registered Services" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "$($services.Count) services registered." `
                -Path $servicesManifestPath

            $duplicateServices = @(
                $services |
                    Group-Object Name |
                    Where-Object {
                        $_.Count -gt 1
                    }
            )

            if ($duplicateServices.Count -eq 0) {
                Add-BKValidationResult `
                    -Category "Registry" `
                    -Check "Duplicate Services" `
                    -Status "PASS" `
                    -Domain "Repository" `
                    -Severity "Informational" `
                    -Details "No duplicate service registrations detected." `
                    -Path $servicesManifestPath
            }
            else {
                foreach ($duplicate in $duplicateServices) {
                    Add-BKValidationResult `
                        -Category "Registry" `
                        -Check "Duplicate Service: $($duplicate.Name)" `
                        -Status "FAIL" `
                        -Domain "Repository" `
                        -Severity "High" `
                        -Details "$($duplicate.Count) registrations detected." `
                        -Path $servicesManifestPath `
                        -Recommendation "Keep one authoritative registration for each service."
                }
            }

            foreach ($service in $services) {
                if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$service.Name
                    )
                ) {
                    Add-BKValidationResult `
                        -Category "Registry" `
                        -Check "Unnamed Service Registration" `
                        -Status "FAIL" `
                        -Domain "Repository" `
                        -Severity "High" `
                        -Details "A service entry does not define a Name." `
                        -Path $servicesManifestPath `
                        -Recommendation "Assign a valid public command name."

                    continue
                }

                $command = Get-Command `
                    -Name $service.Name `
                    -ErrorAction SilentlyContinue

                if ($command) {
                    Add-BKValidationResult `
                        -Category "Services" `
                        -Check "Service Command: $($service.Name)" `
                        -Status "PASS" `
                        -Domain "Repository" `
                        -Severity "Informational" `
                        -Details "Registered service command is available." `
                        -Path $command.Source
                }
                else {
                    Add-BKValidationResult `
                        -Category "Services" `
                        -Check "Service Command: $($service.Name)" `
                        -Status "FAIL" `
                        -Domain "Repository" `
                        -Severity "High" `
                        -Details "Registered service command is unavailable in the current module session." `
                        -Path $servicesManifestPath `
                        -Recommendation "Confirm the script is loaded and exported by the platform module."
                }

                if (
                    $service.RequiresGraph -eq $true -and
                    @($service.RequiredScopes).Count -eq 0
                ) {
                    Add-BKValidationResult `
                        -Category "Services" `
                        -Check "Graph Scope Metadata: $($service.Name)" `
                        -Status "WARN" `
                        -Domain "Operational" `
                        -Severity "Medium" `
                        -Details "The service requires Microsoft Graph but declares no scopes." `
                        -Path $servicesManifestPath `
                        -Recommendation "Declare the least-privileged Microsoft Graph scopes."
                }
                else {
                    Add-BKValidationResult `
                        -Category "Services" `
                        -Check "Graph Scope Metadata: $($service.Name)" `
                        -Status "PASS" `
                        -Domain "Operational" `
                        -Severity "Informational" `
                        -Details "Graph requirement metadata is internally consistent." `
                        -Path $servicesManifestPath
                }
            }
        }
        elseif ($serviceManifest) {
            Add-BKValidationResult `
                -Category "Registry" `
                -Check "Service Manifest Structure" `
                -Status "FAIL" `
                -Domain "Repository" `
                -Severity "Critical" `
                -Details "The service manifest does not contain a Services collection." `
                -Path $servicesManifestPath `
                -Recommendation "Add a Services array to the manifest."
        }

        #
        # Engine manifests
        #

        $engineManifestFiles = @(
            Get-ChildItem `
                -Path $scriptsRoot `
                -Filter "engine.json" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        if ($engineManifestFiles.Count -gt 0) {
            Add-BKValidationResult `
                -Category "Engines" `
                -Check "Engine Manifest Discovery" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "$($engineManifestFiles.Count) engine manifests discovered." `
                -Path $scriptsRoot
        }
        else {
            Add-BKValidationResult `
                -Category "Engines" `
                -Check "Engine Manifest Discovery" `
                -Status "FAIL" `
                -Domain "Repository" `
                -Severity "Critical" `
                -Details "No engine manifests were discovered." `
                -Path $scriptsRoot `
                -Recommendation "Add engine.json to each registered engine."
        }

        $engineNames = @()

        foreach ($manifestFile in $engineManifestFiles) {
            $engineManifest = Test-BKJsonDocument `
                -Category "Engines" `
                -Name "Engine Manifest: $($manifestFile.Directory.Name)" `
                -Path $manifestFile.FullName `
                -Domain Repository

            if (-not $engineManifest) {
                continue
            }

            $engineName = [string]$engineManifest.Name

            if ([string]::IsNullOrWhiteSpace($engineName)) {
                Add-BKValidationResult `
                    -Category "Engines" `
                    -Check "Engine Name" `
                    -Status "FAIL" `
                    -Domain "Repository" `
                    -Severity "High" `
                    -Details "Engine manifest does not define Name." `
                    -Path $manifestFile.FullName `
                    -Recommendation "Add a unique engine Name."

                continue
            }

            $engineNames += $engineName

            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$engineManifest.EntryPoint
                )
            ) {
                Add-BKValidationResult `
                    -Category "Engines" `
                    -Check "Engine Entry Point: $engineName" `
                    -Status "FAIL" `
                    -Domain "Repository" `
                    -Severity "High" `
                    -Details "The engine manifest does not define EntryPoint." `
                    -Path $manifestFile.FullName `
                    -Recommendation "Add the engine entry-point filename."
            }
            else {
                $entryPointPath = Join-Path `
                    $manifestFile.Directory.FullName `
                    $engineManifest.EntryPoint

                if (Test-Path -LiteralPath $entryPointPath) {
                    Add-BKValidationResult `
                        -Category "Engines" `
                        -Check "Engine Entry Point: $engineName" `
                        -Status "PASS" `
                        -Domain "Repository" `
                        -Severity "Informational" `
                        -Details "Engine entry point is present." `
                        -Path $entryPointPath
                }
                else {
                    Add-BKValidationResult `
                        -Category "Engines" `
                        -Check "Engine Entry Point: $engineName" `
                        -Status "FAIL" `
                        -Domain "Repository" `
                        -Severity "High" `
                        -Details "Engine entry point was not found." `
                        -Path $entryPointPath `
                        -Recommendation "Create the entry-point script or correct the manifest."
                }
            }

            foreach ($dependency in @($engineManifest.Dependencies)) {
                if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$dependency
                    )
                ) {
                    continue
                }

                $dependencyCommand = Get-Command `
                    -Name $dependency `
                    -ErrorAction SilentlyContinue

                if ($dependencyCommand) {
                    Add-BKValidationResult `
                        -Category "Engines" `
                        -Check "Dependency: $engineName -> $dependency" `
                        -Status "PASS" `
                        -Domain "Repository" `
                        -Severity "Informational" `
                        -Details "Engine dependency is available." `
                        -Path $manifestFile.FullName
                }
                else {
                    Add-BKValidationResult `
                        -Category "Engines" `
                        -Check "Dependency: $engineName -> $dependency" `
                        -Status "FAIL" `
                        -Domain "Repository" `
                        -Severity "High" `
                        -Details "Engine dependency is unavailable." `
                        -Path $manifestFile.FullName `
                        -Recommendation "Register, load, or correct the dependency name."
                }
            }
        }

        $duplicateEngineNames = @(
            $engineNames |
                Group-Object |
                Where-Object {
                    $_.Count -gt 1
                }
        )

        if ($duplicateEngineNames.Count -eq 0) {
            Add-BKValidationResult `
                -Category "Engines" `
                -Check "Duplicate Engine Names" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "No duplicate engine names detected." `
                -Path $scriptsRoot
        }
        else {
            foreach ($duplicateEngine in $duplicateEngineNames) {
                Add-BKValidationResult `
                    -Category "Engines" `
                    -Check "Duplicate Engine: $($duplicateEngine.Name)" `
                    -Status "FAIL" `
                    -Domain "Repository" `
                    -Severity "High" `
                    -Details "$($duplicateEngine.Count) engine manifests use this name." `
                    -Path $scriptsRoot `
                    -Recommendation "Assign a unique name to every engine."
            }
        }

        #
        # PowerShell quality
        #

        $powerShellFiles = @(
            Get-ChildItem `
                -Path $scriptsRoot `
                -Include "*.ps1", "*.psm1", "*.psd1" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        Add-BKValidationResult `
            -Category "PowerShell" `
            -Check "PowerShell File Discovery" `
            -Status "PASS" `
            -Domain "Repository" `
            -Severity "Informational" `
            -Details "$($powerShellFiles.Count) PowerShell files discovered." `
            -Path $scriptsRoot

        foreach ($file in $powerShellFiles) {
            if ($file.Length -eq 0) {
                Add-BKValidationResult `
                    -Category "PowerShell" `
                    -Check "Empty Script: $($file.Name)" `
                    -Status "WARN" `
                    -Domain "Repository" `
                    -Severity "Low" `
                    -Details "PowerShell file is empty." `
                    -Path $file.FullName `
                    -Recommendation "Implement the script or remove the placeholder."

                continue
            }

            $tokens = $null
            $parseErrors = $null

            [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            ) | Out-Null

            if (
                $null -eq $parseErrors -or
                $parseErrors.Count -eq 0
            ) {
                Add-BKValidationResult `
                    -Category "PowerShell" `
                    -Check "Syntax: $($file.Name)" `
                    -Status "PASS" `
                    -Domain "Repository" `
                    -Severity "Informational" `
                    -Details "No PowerShell parser errors detected." `
                    -Path $file.FullName
            }
            else {
                $errorDetails = @(
                    $parseErrors |
                        ForEach-Object {
                            "Line $($_.Extent.StartLineNumber): $($_.Message)"
                        }
                ) -join " | "

                Add-BKValidationResult `
                    -Category "PowerShell" `
                    -Check "Syntax: $($file.Name)" `
                    -Status "FAIL" `
                    -Domain "Repository" `
                    -Severity "Critical" `
                    -Details $errorDetails `
                    -Path $file.FullName `
                    -Recommendation "Correct the PowerShell syntax errors."
            }
        }

        #
        # JSON configuration and schemas
        #

        $jsonRoots = @(
            $configurationRoots
            $schemasRoot
        ) |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    [string]$_
                ) -and
                (Test-Path -LiteralPath $_)
            }

        foreach ($jsonRoot in $jsonRoots) {
            $jsonFiles = @(
                Get-ChildItem `
                    -Path $jsonRoot `
                    -Filter "*.json" `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue
            )

            foreach ($jsonFile in $jsonFiles) {
                Test-BKJsonDocument `
                    -Category "JSON" `
                    -Name "JSON Syntax: $($jsonFile.Name)" `
                    -Path $jsonFile.FullName `
                    -Domain Repository |
                    Out-Null
            }
        }

        #
        # Documentation
        #

        if (Test-Path -LiteralPath $docsRoot) {
            $markdownFiles = @(
                Get-ChildItem `
                    -Path $docsRoot `
                    -Filter "*.md" `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue
            )

            Add-BKValidationResult `
                -Category "Documentation" `
                -Check "Markdown Documentation" `
                -Status "PASS" `
                -Domain "Repository" `
                -Severity "Informational" `
                -Details "$($markdownFiles.Count) Markdown documents discovered." `
                -Path $docsRoot

            $emptyMarkdownFiles = @(
                $markdownFiles |
                    Where-Object {
                        $_.Length -eq 0
                    }
            )

            if ($emptyMarkdownFiles.Count -eq 0) {
                Add-BKValidationResult `
                    -Category "Documentation" `
                    -Check "Empty Documentation Files" `
                    -Status "PASS" `
                    -Domain "Repository" `
                    -Severity "Informational" `
                    -Details "No empty Markdown files detected." `
                    -Path $docsRoot
            }
            else {
                foreach ($emptyDocument in $emptyMarkdownFiles) {
                    Add-BKValidationResult `
                        -Category "Documentation" `
                        -Check "Empty Document: $($emptyDocument.Name)" `
                        -Status "WARN" `
                        -Domain "Repository" `
                        -Severity "Low" `
                        -Details "Markdown document is empty." `
                        -Path $emptyDocument.FullName `
                        -Recommendation "Add documentation or remove the placeholder."
                }
            }

            $requiredDocumentation = @(
                "README.md"
                "docs\README.md"
                "docs\Learn\README.md"
                "docs\Build\README.md"
                "docs\Operate\README.md"
                "docs\Learn\Getting-Started.md"
                "docs\Learn\Installation.md"
                "docs\Learn\Quick-Start.md"
                "docs\Learn\Platform-Overview.md"
                "docs\Learn\Platform-Architecture.md"
                "docs\Learn\Command-Reference.md"
            )

            foreach ($relativePath in $requiredDocumentation) {
                $documentationPath = Join-Path `
                    $repoRoot `
                    $relativePath

                Test-BKRequiredPath `
                    -Category "Documentation" `
                    -Name "Required Document: $relativePath" `
                    -Path $documentationPath `
                    -PathType File `
                    -Domain Repository `
                    -MissingSeverity Medium |
                    Out-Null
            }

            $duplicateDocumentNames = @(
                $markdownFiles |
                    Group-Object Name |
                    Where-Object {
                        $_.Count -gt 1 -and
                        $_.Name -ne "README.md"
                    }
            )

            if ($duplicateDocumentNames.Count -eq 0) {
                Add-BKValidationResult `
                    -Category "Documentation" `
                    -Check "Duplicate Documentation Filenames" `
                    -Status "PASS" `
                    -Domain "Repository" `
                    -Severity "Informational" `
                    -Details "No unintended duplicate documentation filenames detected." `
                    -Path $docsRoot
            }
            else {
                foreach ($duplicateDocument in $duplicateDocumentNames) {
                    $duplicatePaths =
                        $duplicateDocument.Group.FullName -join "; "

                    Add-BKValidationResult `
                        -Category "Documentation" `
                        -Check "Duplicate Document: $($duplicateDocument.Name)" `
                        -Status "WARN" `
                        -Domain "Repository" `
                        -Severity "Low" `
                        -Details "$($duplicateDocument.Count) documents use this filename." `
                        -Path $duplicatePaths `
                        -Recommendation "Rename the documents if their purposes differ."
                }
            }
        }

        #
        # Report structure
        #

        if (Test-Path -LiteralPath $reportsRoot) {
            $expectedReportFolders = @(
                "identity"
                "trust"
                "correlation"
                "governance"
                "operations"
                "validation"
                "terraform"
            )

            foreach ($reportFolderName in $expectedReportFolders) {
                $reportFolderPath = Join-Path `
                    $reportsRoot `
                    $reportFolderName

                if (Test-Path -LiteralPath $reportFolderPath) {
                    Add-BKValidationResult `
                        -Category "Reports" `
                        -Check "Report Folder: $reportFolderName" `
                        -Status "PASS" `
                        -Domain "Operational" `
                        -Severity "Informational" `
                        -Details "Report folder is available." `
                        -Path $reportFolderPath
                }
                else {
                    Add-BKValidationResult `
                        -Category "Reports" `
                        -Check "Report Folder: $reportFolderName" `
                        -Status "WARN" `
                        -Domain "Operational" `
                        -Severity "Low" `
                        -Details "Expected report folder is missing." `
                        -Path $reportFolderPath `
                        -Recommendation "Create the report folder before running the related engine."
                }
            }
        }

        #
        # Terraform readiness
        #

        if (Test-Path -LiteralPath $terraformRoot) {
            $terraformFiles = @(
                Get-ChildItem `
                    -Path $terraformRoot `
                    -Filter "*.tf" `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue
            )

            if ($terraformFiles.Count -gt 0) {
                Add-BKValidationResult `
                    -Category "Terraform" `
                    -Check "Terraform Configuration Discovery" `
                    -Status "PASS" `
                    -Domain "Operational" `
                    -Severity "Informational" `
                    -Details "$($terraformFiles.Count) Terraform files discovered." `
                    -Path $terraformRoot
            }
            else {
                Add-BKValidationResult `
                    -Category "Terraform" `
                    -Check "Terraform Configuration Discovery" `
                    -Status "WARN" `
                    -Domain "Operational" `
                    -Severity "Low" `
                    -Details "No Terraform configuration files were discovered." `
                    -Path $terraformRoot `
                    -Recommendation "Add Terraform configuration or remove the unused folder."
            }

            $localStateFiles = @(
                Get-ChildItem `
                    -Path $terraformRoot `
                    -Include "*.tfstate", "*.tfstate.backup" `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue
            )

            if ($localStateFiles.Count -eq 0) {
                Add-BKValidationResult `
                    -Category "Terraform" `
                    -Check "Terraform State Hygiene" `
                    -Status "PASS" `
                    -Domain "Operational" `
                    -Severity "Informational" `
                    -Details "No local Terraform state files detected in the repository." `
                    -Path $terraformRoot
            }
            else {
                foreach ($stateFile in $localStateFiles) {
                    Add-BKValidationResult `
                        -Category "Terraform" `
                        -Check "Local Terraform State" `
                        -Status "FAIL" `
                        -Domain "Operational" `
                        -Severity "Critical" `
                        -Details "Terraform state file detected in the repository." `
                        -Path $stateFile.FullName `
                        -Recommendation "Remove the state file from source control and use a secured remote backend."
                }
            }

            $terraformCommand = Get-Command `
                -Name "terraform" `
                -ErrorAction SilentlyContinue

            if ($terraformCommand) {
                $terraformVersion = $null

                try {
                    $terraformVersionData =
                        terraform version -json 2>$null |
                        ConvertFrom-Json `
                            -ErrorAction Stop

                    $terraformVersion =
                        $terraformVersionData.terraform_version
                }
                catch {
                    $terraformVersion = "Detected"
                }

                Add-BKValidationResult `
                    -Category "Terraform" `
                    -Check "Terraform CLI" `
                    -Status "PASS" `
                    -Domain "Operational" `
                    -Severity "Informational" `
                    -Details "Terraform CLI available. Version: $terraformVersion" `
                    -Path $terraformCommand.Source
            }
            else {
                Add-BKValidationResult `
                    -Category "Terraform" `
                    -Check "Terraform CLI" `
                    -Status "WARN" `
                    -Domain "Operational" `
                    -Severity "Medium" `
                    -Details "Terraform CLI is not available in PATH." `
                    -Path $terraformRoot `
                    -Recommendation "Install Terraform and ensure the executable is available in PATH."
            }
        }

        #
        # Microsoft Graph readiness
        #

        $mgContextCommand = Get-Command `
            -Name Get-MgContext `
            -ErrorAction SilentlyContinue

        if ($mgContextCommand) {
            Add-BKValidationResult `
                -Category "Microsoft Graph" `
                -Check "Microsoft Graph PowerShell SDK" `
                -Status "PASS" `
                -Domain "Operational" `
                -Severity "Informational" `
                -Details "Microsoft Graph authentication commands are available." `
                -Path $mgContextCommand.Source

            $mgContext = Get-MgContext `
                -ErrorAction SilentlyContinue

            if ($mgContext) {
                Add-BKValidationResult `
                    -Category "Microsoft Graph" `
                    -Check "Microsoft Graph Connection" `
                    -Status "PASS" `
                    -Domain "Operational" `
                    -Severity "Informational" `
                    -Details "Connected to tenant $($mgContext.TenantId) as $($mgContext.Account)." `
                    -Path $mgContext.Environment
            }
            else {
                Add-BKValidationResult `
                    -Category "Microsoft Graph" `
                    -Check "Microsoft Graph Connection" `
                    -Status "WARN" `
                    -Domain "Operational" `
                    -Severity "Low" `
                    -Details "Microsoft Graph SDK is installed, but no active connection exists." `
                    -Recommendation "Run Connect-BKGraph before performing tenant assessments."
            }
        }
        else {
            Add-BKValidationResult `
                -Category "Microsoft Graph" `
                -Check "Microsoft Graph PowerShell SDK" `
                -Status "WARN" `
                -Domain "Operational" `
                -Severity "High" `
                -Details "Microsoft Graph authentication commands are unavailable." `
                -Recommendation "Install the Microsoft Graph PowerShell SDK."
        }

        #
        # Domain summaries
        #

        $repositorySummary = Get-BKDomainSummary `
            -Domain Repository

        $operationalSummary = Get-BKDomainSummary `
            -Domain Operational

        $repositoryResults = @(
            $results |
                Where-Object {
                    $_.Domain -eq "Repository"
                }
        )

        $operationalResults = @(
            $results |
                Where-Object {
                    $_.Domain -eq "Operational"
                }
        )

        $repositorySummary = Set-BKHealthCaps `
            -Summary $repositorySummary `
            -DomainResults $repositoryResults

        $operationalSummary = Set-BKHealthCaps `
            -Summary $operationalSummary `
            -DomainResults $operationalResults

        #
        # Overall summary
        #

        $allTotal = $results.Count

        $allPassed = @(
            $results |
                Where-Object {
                    $_.Status -eq "PASS"
                }
        ).Count

        $allWarnings = @(
            $results |
                Where-Object {
                    $_.Status -eq "WARN"
                }
        ).Count

        $allFailed = @(
            $results |
                Where-Object {
                    $_.Status -eq "FAIL"
                }
        ).Count

        $allPenalty = (
            $results |
                Measure-Object `
                    -Property Weight `
                    -Sum
        ).Sum

        if ($null -eq $allPenalty) {
            $allPenalty = 0
        }

        $maximumPenalty = if ($allTotal -gt 0) {
            $allTotal * $severityWeights.Critical
        }
        else {
            0
        }

        $validationConfidence = if ($maximumPenalty -gt 0) {
            [math]::Round(
                (
                    1 -
                    (
                        $allPenalty /
                        $maximumPenalty
                    )
                ) * 100,
                2
            )
        }
        else {
            100
        }

        if ($validationConfidence -lt 0) {
            $validationConfidence = 0
        }

        $overallHealth = Get-BKHealthFromConfidence `
            -Confidence $validationConfidence

        $criticalFindings = @(
            $results |
                Where-Object {
                    $_.Status -eq "FAIL" -and
                    $_.Severity -eq "Critical"
                }
        )

        $highFindings = @(
            $results |
                Where-Object {
                    $_.Status -eq "FAIL" -and
                    $_.Severity -eq "High"
                }
        )

        if ($criticalFindings.Count -gt 0) {
            $overallHealth = "Needs Attention"
        }
        elseif (
            $highFindings.Count -gt 0 -and
            $overallHealth -in @(
                "Excellent",
                "Healthy"
            )
        ) {
            $overallHealth = "Warning"
        }

        $topFindings = @(
            $results |
                Where-Object {
                    $_.Status -ne "PASS"
                } |
                Sort-Object `
                    @{
                        Expression = "Weight"
                        Descending = $true
                    },
                    Category,
                    Check |
                Select-Object -First 10
        )

        if ($criticalFindings.Count -gt 0) {
            $releaseRecommendation =
                "Critical findings are present. Resolve them before release or production use."
        }
        elseif ($highFindings.Count -gt 0) {
            $releaseRecommendation =
                "Platform is usable for development, but high-severity findings should be resolved before release."
        }
        elseif ($allWarnings -gt 0) {
            $releaseRecommendation =
                "Platform is healthy. Review outstanding warnings as part of normal engineering hygiene."
        }
        else {
            $releaseRecommendation =
                "Platform passed all quality gates and is ready for development and assessment use."
        }

        $validationObject = [PSCustomObject]@{
            Platform    = "Blackknight One"
            GeneratedAt = (
                Get-Date
            ).ToUniversalTime().ToString("o")

            Overall = [PSCustomObject]@{
                Health          = $overallHealth
                Confidence      = $validationConfidence
                Total           = $allTotal
                Passed          = $allPassed
                Warnings        = $allWarnings
                Failed          = $allFailed
                CriticalFailure = $criticalFindings.Count
                HighFailure     = $highFindings.Count
                Penalty         = [math]::Round(
                    $allPenalty,
                    2
                )
            }

            RepositoryHealth     = $repositorySummary
            OperationalReadiness = $operationalSummary
            Recommendation       = $releaseRecommendation
            TopFindings          = $topFindings
            Results              = @($results)
        }

        #
        # Console output
        #

        if (-not $Quiet) {
            Write-Host ""
            Write-Host "Validation Summary" `
                -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"

            Write-Host "Repository Health      : " -NoNewline
            Write-Host `
                $repositorySummary.Health `
                -ForegroundColor (
                    Get-BKHealthColor `
                        -Health $repositorySummary.Health
                )

            Write-Host "Repository Confidence  : $($repositorySummary.Confidence)%"
            Write-Host "Repository Checks      : $($repositorySummary.Total)"
            Write-Host ""

            Write-Host "Operational Readiness  : " -NoNewline
            Write-Host `
                $operationalSummary.Health `
                -ForegroundColor (
                    Get-BKHealthColor `
                        -Health $operationalSummary.Health
                )

            Write-Host "Operational Confidence : $($operationalSummary.Confidence)%"
            Write-Host "Operational Checks     : $($operationalSummary.Total)"
            Write-Host ""

            Write-Host "Validation Confidence  : " -NoNewline
            Write-Host `
                "$validationConfidence%" `
                -ForegroundColor (
                    Get-BKHealthColor `
                        -Health $overallHealth
                )

            Write-Host "Overall Health         : " -NoNewline
            Write-Host `
                $overallHealth `
                -ForegroundColor (
                    Get-BKHealthColor `
                        -Health $overallHealth
                )

            Write-Host ""
            Write-Host "Passed                 : $allPassed"
            Write-Host "Warnings               : $allWarnings"
            Write-Host "Failed                 : $allFailed"
            Write-Host "Critical Failures      : $($criticalFindings.Count)"
            Write-Host "High Failures          : $($highFindings.Count)"
            Write-Host "Checks                 : $allTotal"

            if ($topFindings.Count -gt 0) {
                Write-Host ""
                Write-Host "Top Findings" `
                    -ForegroundColor Yellow
                Write-Host "------------------------------------------------------------"

                $topFindings |
                    Select-Object `
                        Severity,
                        Domain,
                        Category,
                        Check,
                        Details |
                    Format-Table -AutoSize
            }

            Write-Host ""
            Write-Host "Recommendation" `
                -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"
            Write-Host $releaseRecommendation

            Write-Host ""
            Write-Host "============================================================" `
                -ForegroundColor Cyan
        }

        #
        # JSON export
        #

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

            $validationObject |
                ConvertTo-Json `
                    -Depth 12 |
                Set-Content `
                    -LiteralPath $OutputPath `
                    -Encoding utf8

            if (-not $Quiet) {
                Write-Host ""
                Write-Host "[PASS] Validation report exported to $OutputPath" `
                    -ForegroundColor Green
            }
        }

        if (
            $PassThru -or
            $Quiet
        ) {
            return $validationObject
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