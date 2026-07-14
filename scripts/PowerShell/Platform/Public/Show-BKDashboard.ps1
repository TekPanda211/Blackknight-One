function Show-BKDashboard {
    <#
    .SYNOPSIS
    Opens the interactive Blackknight One command dashboard.

    .DESCRIPTION
    Provides a menu-driven launcher for the primary Blackknight One engines
    and platform services.

    The dashboard includes nine options:

    1. Terraform Assessment
    2. Microsoft Graph Connection and Tenant Discovery
    3. Identity Assessment
    4. Trust Assessment
    5. Governance Assessment
    6. Correlation Assessment
    7. Operations Assessment
    8. Platform Validation
    9. Command Inventory

    The dashboard remains open after each operation until the user chooses
    to quit.

    .PARAMETER TerraformPath
    Specifies the default Terraform project directory.

    .PARAMETER ReportRoot
    Specifies the root folder used for generated reports.

    .PARAMETER ExportReports
    Automatically requests JSON export from commands that support it.

    .PARAMETER NoClear
    Prevents the dashboard from clearing the console between menu displays.

    .EXAMPLE
    Show-BKDashboard

    .EXAMPLE
    Show-BKDashboard `
        -TerraformPath ".\terraform" `
        -ExportReports

    .EXAMPLE
    Show-BKDashboard -NoClear
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TerraformPath = ".\terraform",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ReportRoot = ".\reports",

        [Parameter()]
        [switch]$ExportReports,

        [Parameter()]
        [switch]$NoClear
    )

    $ErrorActionPreference = "Stop"

    function Write-BKDashboardHeader {
        [CmdletBinding()]
        param()

        if (-not $NoClear.IsPresent) {
            Clear-Host
        }

        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan
        Write-Host "                    BLACKKNIGHT ONE" `
            -ForegroundColor Cyan
        Write-Host "              ENTERPRISE ASSESSMENT PLATFORM" `
            -ForegroundColor Cyan
        Write-Host "============================================================" `
            -ForegroundColor Cyan
        Write-Host ""
    }

    function Write-BKDashboardMenu {
        [CmdletBinding()]
        param()

        Write-Host "Select an assessment or platform operation:" `
            -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  [1] Terraform Assessment"
        Write-Host "  [2] Microsoft Graph Connection and Tenant Discovery"
        Write-Host "  [3] Identity Assessment"
        Write-Host "  [4] Trust Assessment"
        Write-Host "  [5] Governance Assessment"
        Write-Host "  [6] Correlation Assessment"
        Write-Host "  [7] Operations Assessment"
        Write-Host "  [8] Platform Validation"
        Write-Host "  [9] Command Inventory"
        Write-Host ""
        Write-Host "  [Q] Quit"
        Write-Host ""
    }

    function Wait-BKDashboard {
        [CmdletBinding()]
        param()

        Write-Host ""
        $null = Read-Host "Press Enter to return to the dashboard"
    }

    function Test-BKDashboardCommand {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )

        return $null -ne (
            Get-Command `
                -Name $Name `
                -ErrorAction SilentlyContinue
        )
    }

    function Get-BKDashboardRepoRoot {
        [CmdletBinding()]
        param()

        $currentPath = (Get-Location).Path
        $candidate = Get-Item `
            -LiteralPath $currentPath `
            -ErrorAction Stop

        while ($null -ne $candidate) {
            $modulePath = Join-Path `
                -Path $candidate.FullName `
                -ChildPath "scripts\PowerShell\Platform\Blackknight-Platform.psm1"

            if (Test-Path -LiteralPath $modulePath -PathType Leaf) {
                return $candidate.FullName
            }

            $candidate = $candidate.Parent
        }

        return (Get-Location).Path
    }

    function Resolve-BKDashboardPath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$BasePath
        )

        if ([System.IO.Path]::IsPathRooted($Path)) {
            return [System.IO.Path]::GetFullPath($Path)
        }

        return [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $BasePath `
                    -ChildPath $Path
            )
        )
    }

    function Invoke-BKDashboardScript {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string[]]$CandidatePaths,

            [Parameter()]
            [hashtable]$Parameters = @{},

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$DisplayName
        )

        $scriptPath = $CandidatePaths |
            Where-Object {
                Test-Path `
                    -LiteralPath $_ `
                    -PathType Leaf
            } |
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            Write-Host ""
            Write-Host "[NOT AVAILABLE] $DisplayName" `
                -ForegroundColor DarkYellow
            Write-Host "No registered command or engine script was found."
            Write-Host ""
            Write-Host "Checked paths:"

            foreach ($candidatePath in $CandidatePaths) {
                Write-Host "  $candidatePath"
            }

            return $null
        }

        Write-Verbose "Invoking engine script: $scriptPath"

        return & $scriptPath @Parameters
    }

    function Invoke-BKDashboardTerraform {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Terraform Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        if (
            -not (
                Test-Path `
                    -LiteralPath $resolvedTerraformPath `
                    -PathType Container
            )
        ) {
            Write-Host ""
            Write-Host "[ERROR] Terraform directory was not found:" `
                -ForegroundColor Red
            Write-Host $resolvedTerraformPath

            return
        }

        $parameters = @{
            Path     = $resolvedTerraformPath
            PassThru = $true
        }

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
            $parameters.OutputPath = Join-Path `
                -Path $resolvedReportRoot `
                -ChildPath "terraform\terraform-assessment.json"
        }
        else {
            $exportChoice = Read-Host `
                "Export the Terraform assessment to JSON? [Y/N]"

            if ($exportChoice -match '^(Y|YES)$') {
                $parameters.ExportJson = $true
                $parameters.OutputPath = Join-Path `
                    -Path $resolvedReportRoot `
                    -ChildPath "terraform\terraform-assessment.json"
            }
        }

        if (Test-BKDashboardCommand -Name "Invoke-BKTerraformAssessment") {
            $result = Invoke-BKTerraformAssessment @parameters
        }
        else {
            $result = Invoke-BKDashboardScript `
                -CandidatePaths @(
                    (
                        Join-Path `
                            -Path $repoRoot `
                            -ChildPath "scripts\PowerShell\Terraform\Invoke-BKTerraformAssessment.ps1"
                    )
                ) `
                -Parameters $parameters `
                -DisplayName "Terraform Assessment"
        }

        if ($null -ne $result -and $null -ne $result.Summary) {
            Write-Host ""
            Write-Host "Terraform Executive Result" `
                -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"

            $result.Summary |
                Format-List |
                Out-Host
        }
    }

    function Invoke-BKDashboardGraph {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Microsoft Graph Connection and Tenant Discovery" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host ""

    if (
        -not (
            Test-BKDashboardCommand `
                -Name "Connect-MgGraph"
        )
    ) {
        Write-Host `
            "[NOT AVAILABLE] Connect-MgGraph is not installed or loaded." `
            -ForegroundColor DarkYellow

        return
    }

    #
    # Display the current connection
    #

    $currentContext = $null

    if (
        Test-BKDashboardCommand `
            -Name "Get-MgContext"
    ) {
        $currentContext = Get-MgContext `
            -ErrorAction SilentlyContinue
    }

    if ($null -ne $currentContext) {
        Write-Host "Current Microsoft Graph connection:" `
            -ForegroundColor Cyan

        $currentContext |
            Select-Object `
                Account,
                TenantId,
                Environment,
                AuthType |
            Format-List |
            Out-Host

        $disconnectChoice = Read-Host `
            "Disconnect the current Microsoft Graph session? [Y/N]"

        if (
            $disconnectChoice -match
            '^(Y|YES)$'
        ) {
            if (
                Test-BKDashboardCommand `
                    -Name "Disconnect-MgGraph"
            ) {
                Disconnect-MgGraph |
                    Out-Null

                Write-Host ""
                Write-Host `
                    "Current Microsoft Graph session disconnected." `
                    -ForegroundColor Green
            }
        }
    }

    #
    # Select the Microsoft Graph environment
    #

    $availableEnvironments = @()

    if (
        Test-BKDashboardCommand `
            -Name "Get-MgEnvironment"
    ) {
        $availableEnvironments = @(
            Get-MgEnvironment |
                Sort-Object Name
        )
    }

    $selectedEnvironment = "Global"

    if ($availableEnvironments.Count -gt 0) {
        Write-Host ""
        Write-Host "Available Microsoft Graph environments:" `
            -ForegroundColor Cyan
        Write-Host ""

        for (
            $index = 0;
            $index -lt $availableEnvironments.Count;
            $index++
        ) {
            Write-Host (
                "  [{0}] {1}" -f
                ($index + 1),
                $availableEnvironments[$index].Name
            )
        }

        Write-Host ""
        Write-Host (
            "Press Enter to use the Global public cloud."
        )

        $environmentSelection = Read-Host `
            "Select Microsoft Graph environment"

        if (
            -not [string]::IsNullOrWhiteSpace(
                $environmentSelection
            )
        ) {
            $environmentNumber = 0

            if (
                [int]::TryParse(
                    $environmentSelection,
                    [ref]$environmentNumber
                ) -and
                $environmentNumber -ge 1 -and
                $environmentNumber -le
                $availableEnvironments.Count
            ) {
                $selectedEnvironment =
                    $availableEnvironments[
                        $environmentNumber - 1
                    ].Name
            }
            else {
                Write-Host ""
                Write-Host (
                    "Invalid environment selection. Using Global."
                ) -ForegroundColor DarkYellow
            }
        }
    }

    #
    # Ask which tenant to connect to
    #

    Write-Host ""
    Write-Host "Target tenant" `
        -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    Write-Host (
        "Enter the Microsoft Entra tenant ID you want to assess."
    )
    Write-Host (
        "Example: 00000000-0000-0000-0000-000000000000"
    )
    Write-Host ""
    Write-Host (
        "Press Enter without a tenant ID to use the tenant selected " +
        "during sign-in."
    )

    $tenantId = Read-Host "Tenant ID"

    if (
        -not [string]::IsNullOrWhiteSpace(
            $tenantId
        ) -and
        $tenantId -notmatch
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    ) {
        Write-Host ""
        Write-Host (
            "[ERROR] The tenant ID is not a valid GUID."
        ) -ForegroundColor Red

        return
    }

    #
    # Build the connection parameters
    #

    $connectionParameters = @{
        Environment  = $selectedEnvironment
        ContextScope = "Process"
        NoWelcome    = $true
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $tenantId
        )
    ) {
        $connectionParameters.TenantId =
            $tenantId
    }

    #
    # Prefer the Blackknight wrapper when it supports tenant selection.
    #

    $connectedWithBlackknight = $false

    if (
        Test-BKDashboardCommand `
            -Name "Connect-BKGraph"
    ) {
        $bkGraphCommand = Get-Command `
            -Name "Connect-BKGraph" `
            -ErrorAction SilentlyContinue

        $supportsTenantId =
            $bkGraphCommand.Parameters.ContainsKey(
                "TenantId"
            )

        $supportsEnvironment =
            $bkGraphCommand.Parameters.ContainsKey(
                "Environment"
            )

        if (
            $supportsTenantId -and
            $supportsEnvironment
        ) {
            $bkConnectionParameters = @{
                Environment = $selectedEnvironment
            }

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $tenantId
                )
            ) {
                $bkConnectionParameters.TenantId =
                    $tenantId
            }

            Write-Host ""
            Write-Host (
                "Connecting through Connect-BKGraph..."
            ) -ForegroundColor Yellow

            Connect-BKGraph @bkConnectionParameters

            $connectedWithBlackknight = $true
        }
    }

    if (-not $connectedWithBlackknight) {
        Write-Host ""
        Write-Host (
            "Connecting directly through Microsoft Graph PowerShell..."
        ) -ForegroundColor Yellow

        Connect-MgGraph @connectionParameters
    }

    #
    # Verify the actual connected tenant
    #

    $graphContext = Get-MgContext `
        -ErrorAction SilentlyContinue

    if ($null -eq $graphContext) {
        Write-Host ""
        Write-Host (
            "[ERROR] Microsoft Graph did not return an active context."
        ) -ForegroundColor Red

        return
    }

    Write-Host ""
    Write-Host "Connected Microsoft Graph context" `
        -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"

    $graphContext |
        Select-Object `
            Account,
            TenantId,
            Environment,
            AuthType,
            ContextScope,
            Scopes |
        Format-List |
        Out-Host

    if (
        -not [string]::IsNullOrWhiteSpace(
            $tenantId
        ) -and
        $graphContext.TenantId -ne $tenantId
    ) {
        Write-Host ""
        Write-Host (
            "[WARNING] The connected tenant does not match the " +
            "tenant ID you requested."
        ) -ForegroundColor Red

        Write-Host "Requested tenant : $tenantId"
        Write-Host "Connected tenant : $($graphContext.TenantId)"
        Write-Host ""
        Write-Host (
            "Tenant discovery has been stopped to prevent assessing " +
            "the wrong environment."
        ) -ForegroundColor Red

        return
    }

    #
    # Confirm before collecting tenant information
    #

    Write-Host ""
    $continueChoice = Read-Host `
        "Run tenant discovery against this tenant? [Y/N]"

    if (
        $continueChoice -notmatch
        '^(Y|YES)$'
    ) {
        Write-Host ""
        Write-Host "Tenant discovery cancelled." `
            -ForegroundColor DarkYellow

        return
    }

    if (
        Test-BKDashboardCommand `
            -Name "Get-BKTenant"
    ) {
        Write-Host ""
        Write-Host "Tenant Discovery" `
            -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"

        Get-BKTenant |
            Out-Host
    }
    elseif (
        Test-BKDashboardCommand `
            -Name "Get-BKOrganization"
    ) {
        Write-Host ""
        Write-Host "Organization Discovery" `
            -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"

        Get-BKOrganization |
            Out-Host
    }
    else {
        Write-Host ""
        Write-Host (
            "Microsoft Graph connection completed, but no Blackknight " +
            "tenant-discovery command is currently available."
        ) -ForegroundColor DarkYellow
    }
}

    function Invoke-BKDashboardIdentity {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Identity Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKIdentityAssessment"
        ) {
            Invoke-BKIdentityAssessment @parameters |
                Out-Host

            return
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKIdentityDiscovery"
        ) {
            Invoke-BKIdentityDiscovery @parameters |
                Out-Host

            return
        }

        Invoke-BKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Identity\Invoke-BKIdentityAssessment.ps1"
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Identity\Invoke-BKIdentityDiscovery.ps1"
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Identity Assessment" |
            Out-Host
    }

    function Invoke-BKDashboardTrust {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Trust Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKTrustAssessment"
        ) {
            Invoke-BKTrustAssessment @parameters |
                Out-Host

            return
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKTrustDiscovery"
        ) {
            Invoke-BKTrustDiscovery @parameters |
                Out-Host

            return
        }

        Invoke-BKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Trust\Invoke-BKTrustAssessment.ps1"
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Trust\Invoke-BKTrustDiscovery.ps1"
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Trust Assessment" |
            Out-Host
    }

    function Invoke-BKDashboardGovernance {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Governance Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKGovernanceAssessment"
        ) {
            Invoke-BKGovernanceAssessment @parameters |
                Out-Host

            return
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKIdentityGovernanceAssessment"
        ) {
            Invoke-BKIdentityGovernanceAssessment @parameters |
                Out-Host

            return
        }

        Invoke-BKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Governance\Invoke-BKGovernanceAssessment.ps1"
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Governance\Invoke-BKIdentityGovernanceAssessment.ps1"
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Governance Assessment" |
            Out-Host
    }

    function Invoke-BKDashboardCorrelation {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Correlation Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKCorrelationAssessment"
        ) {
            Invoke-BKCorrelationAssessment @parameters |
                Out-Host

            return
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKCorrelation"
        ) {
            Invoke-BKCorrelation @parameters |
                Out-Host

            return
        }

        Invoke-BKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Correlation\Invoke-BKCorrelationAssessment.ps1"
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Correlation\Invoke-BKCorrelation.ps1"
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Correlation Assessment" |
            Out-Host
    }

    function Invoke-BKDashboardOperations {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Operations Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKOperationsAssessment"
        ) {
            Invoke-BKOperationsAssessment @parameters |
                Out-Host

            return
        }

        if (
            Test-BKDashboardCommand `
                -Name "Invoke-BKOperationsDiscovery"
        ) {
            Invoke-BKOperationsDiscovery @parameters |
                Out-Host

            return
        }

        Invoke-BKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Operations\Invoke-BKOperationsAssessment.ps1"
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath "scripts\PowerShell\Operations\Invoke-BKOperationsDiscovery.ps1"
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Operations Assessment" |
            Out-Host
    }

    function Invoke-BKDashboardPlatformValidation {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Platform Validation" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        if (-not (Test-BKDashboardCommand -Name "Test-BKPlatform")) {
            Write-Host ""
            Write-Host "[NOT AVAILABLE] Test-BKPlatform is not loaded." `
                -ForegroundColor DarkYellow
            return
        }

        $parameters = @{
            PassThru = $true
        }

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
            $parameters.OutputPath = Join-Path `
                -Path $resolvedReportRoot `
                -ChildPath "validation\platform-validation.json"
        }

        $validation = Test-BKPlatform @parameters

        if ($null -ne $validation) {
            Write-Host ""
            Write-Host "Platform Validation Object" `
                -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"

            $validation.Overall |
                Format-List |
                Out-Host
        }
    }

    function Show-BKDashboardCommands {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Blackknight One Command Inventory" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $moduleCommands = @(
            Get-Command `
                -Module "Blackknight-Platform" `
                -ErrorAction SilentlyContinue
        )

        if ($moduleCommands.Count -eq 0) {
            $moduleCommands = @(
                Get-Command `
                    -Name "*-BK*" `
                    -ErrorAction SilentlyContinue
            )
        }

        if ($moduleCommands.Count -eq 0) {
            Write-Host "No Blackknight commands are loaded." `
                -ForegroundColor DarkYellow
            return
        }

        $moduleCommands |
            Sort-Object Name |
            Select-Object `
                Name,
                CommandType,
                Source |
            Format-Table -AutoSize |
            Out-Host

        Write-Host ""
        Write-Host "Total commands: $($moduleCommands.Count)"
    }

    $repoRoot = Get-BKDashboardRepoRoot

    $resolvedTerraformPath = Resolve-BKDashboardPath `
        -Path $TerraformPath `
        -BasePath $repoRoot

    $resolvedReportRoot = Resolve-BKDashboardPath `
        -Path $ReportRoot `
        -BasePath $repoRoot

    $exitDashboard = $false

    while (-not $exitDashboard) {
        Write-BKDashboardHeader
        Write-BKDashboardMenu

        $selection = Read-Host "Enter selection"

        try {
            switch (($selection.Trim()).ToUpperInvariant()) {
                "1" {
                    Invoke-BKDashboardTerraform
                    Wait-BKDashboard
                }

                "2" {
                    Invoke-BKDashboardGraph
                    Wait-BKDashboard
                }

                "3" {
                    Invoke-BKDashboardIdentity
                    Wait-BKDashboard
                }

                "4" {
                    Invoke-BKDashboardTrust
                    Wait-BKDashboard
                }

                "5" {
                    Invoke-BKDashboardGovernance
                    Wait-BKDashboard
                }

                "6" {
                    Invoke-BKDashboardCorrelation
                    Wait-BKDashboard
                }

                "7" {
                    Invoke-BKDashboardOperations
                    Wait-BKDashboard
                }

                "8" {
                    Invoke-BKDashboardPlatformValidation
                    Wait-BKDashboard
                }

                "9" {
                    Show-BKDashboardCommands
                    Wait-BKDashboard
                }

                "Q" {
                    $exitDashboard = $true
                }

                "QUIT" {
                    $exitDashboard = $true
                }

                "EXIT" {
                    $exitDashboard = $true
                }

                default {
                    Write-Host ""
                    Write-Host (
                        "[INVALID SELECTION] Enter a number from 1 through 9, " +
                        "or Q to quit."
                    ) -ForegroundColor Red

                    Start-Sleep -Seconds 2
                }
            }
        }
        catch {
            Write-Host ""
            Write-Host "Operation failed:" `
                -ForegroundColor Red
            Write-Host $_.Exception.Message `
                -ForegroundColor Red

            if (
                Test-BKDashboardCommand `
                    -Name "Write-BKLog"
            ) {
                Write-BKLog `
                    -Message (
                        "Dashboard operation failed: " +
                        $_.Exception.Message
                    ) `
                    -Level Error
            }

            Wait-BKDashboard
        }
    }

    Write-BKDashboardHeader
    Write-Host "Blackknight One dashboard closed." `
        -ForegroundColor Cyan
    Write-Host ""
}