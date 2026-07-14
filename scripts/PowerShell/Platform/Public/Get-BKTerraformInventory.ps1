function Get-BKTerraformInventory {
    <#
    .SYNOPSIS
    Inventories Terraform configuration in a Blackknight One repository.

    .DESCRIPTION
    Discovers Terraform files, projects, providers, modules, resources,
    data sources, variables, outputs, and backend declarations.

    This service performs local configuration discovery and does not make
    changes to Terraform state or infrastructure.

    .PARAMETER Path
    Root path containing Terraform configuration.

    .PARAMETER IncludeFileDetails
    Includes detailed information for every discovered Terraform file.
    #>

    [CmdletBinding()]
    param(
        [string]$Path = ".\terraform",

        [switch]$IncludeFileDetails
    )

    Write-BKLog `
        -Message "Collecting Terraform configuration inventory..." `
        -Level Info

    try {
        $resolvedPath = $null

        if (Test-Path $Path) {
            $resolvedPath = (
                Resolve-Path `
                    -Path $Path `
                    -ErrorAction Stop
            ).Path
        }
        else {
            throw "Terraform path was not found: $Path"
        }

        $terraformCommand = Get-Command `
            -Name "terraform" `
            -ErrorAction SilentlyContinue

        $terraformInstalled = $null -ne $terraformCommand
        $terraformVersion = $null

        if ($terraformInstalled) {
            try {
                $versionJson = terraform version -json 2>$null |
                    ConvertFrom-Json -ErrorAction Stop

                $terraformVersion = $versionJson.terraform_version
            }
            catch {
                try {
                    $versionText = terraform version 2>$null |
                        Select-Object -First 1

                    $terraformVersion = (
                        [string]$versionText
                    ).Replace("Terraform v", "").Trim()
                }
                catch {
                    $terraformVersion = "Unknown"
                }
            }
        }

        $terraformFiles = @(
            Get-ChildItem `
                -Path $resolvedPath `
                -Filter "*.tf" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        $variableFiles = @(
            Get-ChildItem `
                -Path $resolvedPath `
                -Filter "*.tfvars" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        $lockFiles = @(
            Get-ChildItem `
                -Path $resolvedPath `
                -Filter ".terraform.lock.hcl" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        $stateFiles = @(
            Get-ChildItem `
                -Path $resolvedPath `
                -Include "*.tfstate", "*.tfstate.backup" `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        $projectFolders = @(
            $terraformFiles |
                ForEach-Object {
                    $_.Directory.FullName
                } |
                Sort-Object -Unique
        )

        $providers = @()
        $requiredProviders = @()
        $resources = @()
        $dataSources = @()
        $modules = @()
        $variables = @()
        $outputs = @()
        $backends = @()
        $terraformBlocks = @()
        $fileDetails = @()

        foreach ($file in $terraformFiles) {
            $content = Get-Content `
                -Path $file.FullName `
                -Raw `
                -ErrorAction Stop

            $fileProviders = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*provider\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        $_.Groups[1].Value
                    }
            )

            $fileResources = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*resource\s+"([^"]+)"\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Type = $_.Groups[1].Value
                            Name = $_.Groups[2].Value
                            File = $file.FullName
                        }
                    }
            )

            $fileDataSources = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*data\s+"([^"]+)"\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Type = $_.Groups[1].Value
                            Name = $_.Groups[2].Value
                            File = $file.FullName
                        }
                    }
            )

            $fileModules = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*module\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name = $_.Groups[1].Value
                            File = $file.FullName
                        }
                    }
            )

            $fileVariables = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*variable\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name = $_.Groups[1].Value
                            File = $file.FullName
                        }
                    }
            )

            $fileOutputs = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*output\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name = $_.Groups[1].Value
                            File = $file.FullName
                        }
                    }
            )

            $fileBackends = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*backend\s+"([^"]+)"\s*\{'
                ) |
                    ForEach-Object {
                        $_.Groups[1].Value
                    }
            )

            $fileTerraformBlocks = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*terraform\s*\{'
                )
            )

            $fileRequiredProviders = @(
                [regex]::Matches(
                    $content,
                    '(?m)^\s*([A-Za-z0-9_-]+)\s*=\s*\{[\s\S]*?source\s*=\s*"([^"]+)"'
                ) |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name   = $_.Groups[1].Value
                            Source = $_.Groups[2].Value
                            File   = $file.FullName
                        }
                    }
            )

            $providers += $fileProviders
            $requiredProviders += $fileRequiredProviders
            $resources += $fileResources
            $dataSources += $fileDataSources
            $modules += $fileModules
            $variables += $fileVariables
            $outputs += $fileOutputs
            $backends += $fileBackends
            $terraformBlocks += $fileTerraformBlocks

            if ($IncludeFileDetails) {
                $relativePath = $file.FullName.Substring(
                    $resolvedPath.Length
                ).TrimStart(
                    [System.IO.Path]::DirectorySeparatorChar
                )

                $fileDetails += [PSCustomObject]@{
                    Name              = $file.Name
                    RelativePath      = $relativePath
                    FullName          = $file.FullName
                    SizeBytes         = $file.Length
                    LastWriteTimeUtc  = $file.LastWriteTimeUtc
                    Providers         = @($fileProviders)
                    ResourceCount     = $fileResources.Count
                    DataSourceCount   = $fileDataSources.Count
                    ModuleCount       = $fileModules.Count
                    VariableCount     = $fileVariables.Count
                    OutputCount       = $fileOutputs.Count
                    BackendCount      = $fileBackends.Count
                }
            }
        }

        $uniqueProviders = @(
            $providers |
                Sort-Object -Unique
        )

        $uniqueRequiredProviders = @(
            $requiredProviders |
                Sort-Object Name, Source -Unique
        )

        $resourceTypes = @(
            $resources |
                Group-Object Type |
                Sort-Object Count -Descending |
                ForEach-Object {
                    [PSCustomObject]@{
                        Type  = $_.Name
                        Count = $_.Count
                    }
                }
        )

        $containsLocalState = $stateFiles.Count -gt 0

        $warnings = @()

        if (-not $terraformInstalled) {
            $warnings += "Terraform CLI is not installed or is not available in PATH."
        }

        if ($terraformFiles.Count -eq 0) {
            $warnings += "No Terraform configuration files were discovered."
        }

        if ($containsLocalState) {
            $warnings += "Terraform state files were discovered under the scanned path."
        }

        [PSCustomObject]@{
            RootPath               = $resolvedPath

            TerraformInstalled     = $terraformInstalled
            TerraformVersion       = $terraformVersion
            TerraformExecutable    = if ($terraformCommand) {
                $terraformCommand.Source
            }
            else {
                $null
            }

            ProjectCount           = $projectFolders.Count
            ProjectFolders         = $projectFolders

            TerraformFileCount     = $terraformFiles.Count
            VariableFileCount      = $variableFiles.Count
            LockFileCount          = $lockFiles.Count
            StateFileCount         = $stateFiles.Count
            ContainsLocalState     = $containsLocalState

            ProviderCount          = $uniqueProviders.Count
            Providers              = $uniqueProviders

            RequiredProviderCount  = $uniqueRequiredProviders.Count
            RequiredProviders      = $uniqueRequiredProviders

            ResourceCount          = $resources.Count
            ResourceTypes          = $resourceTypes
            Resources              = $resources

            DataSourceCount        = $dataSources.Count
            DataSources            = $dataSources

            ModuleCount            = $modules.Count
            Modules                = $modules

            VariableCount          = $variables.Count
            Variables              = $variables

            OutputCount            = $outputs.Count
            Outputs                = $outputs

            BackendCount           = $backends.Count
            Backends               = @(
                $backends |
                    Sort-Object -Unique
            )

            TerraformBlockCount    = $terraformBlocks.Count

            WarningCount           = $warnings.Count
            Warnings               = $warnings

            Files = if ($IncludeFileDetails) {
                $fileDetails
            }
            else {
                @()
            }

            Timestamp = (
                Get-Date
            ).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error

        throw
    }
}