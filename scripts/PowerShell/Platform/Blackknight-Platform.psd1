@{
    #
    # Script module associated with this manifest
    #

    RootModule = "Blackknight-Platform.psm1"

    #
    # Semantic version for Blackknight One
    #

    ModuleVersion = "0.7.0"

    #
    # Stable module identifier
    #
    # Keep this GUID unchanged after the manifest is published.
    #

    GUID = "c5e932e5-6ca6-47db-a61b-2dd8de8bc2b0"

    #
    # Module ownership
    #

    Author = "Todd Crow"

    CompanyName = "BlackKnight Networking"

    Copyright = "(c) 2026 Todd Crow. All rights reserved."

    #
    # Module description
    #

    Description = @"
Blackknight One is a dashboard-driven infrastructure, identity, and security
assessment platform for Terraform and Microsoft Graph.

The platform provides interactive assessment workflows, Terraform HCL
discovery, Terraform security analysis, plan analysis, two-phase drift
confirmation, Microsoft Graph tenant discovery, standardized scoring,
findings, recommendations, and JSON reporting.
"@

    #
    # Minimum PowerShell version
    #

    PowerShellVersion = "7.4"

    #
    # Compatible PowerShell editions
    #

    CompatiblePSEditions = @(
        "Core"
    )

    #
    # Host and runtime requirements
    #
    # These remain intentionally unset because the module does not require a
    # specific PowerShell host application or .NET runtime beyond PowerShell.
    #

    PowerShellHostName = ""

    PowerShellHostVersion = ""

    DotNetFrameworkVersion = ""

    CLRVersion = ""

    ProcessorArchitecture = "None"

    #
    # Required modules
    #
    # Microsoft Graph dependencies are loaded only when Graph capabilities are
    # used. They are not declared as hard manifest dependencies so Terraform
    # and repository assessment features can run independently.
    #

    RequiredModules = @()

    RequiredAssemblies = @()

    ScriptsToProcess = @()

    TypesToProcess = @()

    FormatsToProcess = @()

    NestedModules = @()

    #
    # Exported module members
    #
    # Public functions are discovered and exported by the PSM1 loader.
    # Wildcard export prevents newly added public wrappers from being blocked
    # by a stale manifest export list.
    #

    FunctionsToExport = @(
        "*"
    )

    CmdletsToExport = @()

    VariablesToExport = @()

    AliasesToExport = @()

    DscResourcesToExport = @()

    #
    # Module members that should not be exported
    #

    PrivateData = @{
        PSData = @{
            #
            # PowerShell Gallery and repository discovery tags
            #

            Tags = @(
                "BlackknightOne"
                "Terraform"
                "HCL"
                "PowerShell"
                "MicrosoftGraph"
                "MicrosoftEntra"
                "Azure"
                "IAM"
                "Identity"
                "Security"
                "DevSecOps"
                "InfrastructureAsCode"
                "PlatformEngineering"
                "Assessment"
                "DriftDetection"
                "CloudSecurity"
            )

            #
            # Replace these two URLs if your GitHub repository uses a
            # different owner or repository name.
            #

            ProjectUri = "https://github.com/ToddCrow/blackknight-one"

            LicenseUri = "https://github.com/ToddCrow/blackknight-one/blob/main/LICENSE"

            #
            # Add a public icon URL later if the repository gains a logo.
            #

            IconUri = ""

            #
            # v0.7.0 release notes
            #

            ReleaseNotes = @"
Blackknight One v0.7.0

Added:
- Interactive Show-BKDashboard platform entry point
- Dashboard-based Terraform and Microsoft Graph workflows
- Tenant-aware Microsoft Graph connection selection
- Microsoft Graph Tenant Discovery Engine
- Microsoft Graph Assessment Engine
- Terraform HCL Discovery Engine v2
- Terraform Security Analyzer
- Terraform architecture scoring
- Terraform security scoring
- Terraform dependency discovery
- Terraform graph analysis
- Two-phase Terraform drift confirmation
- Standardized findings, recommendations, and JSON reporting

Improved:
- Dashboard-first user experience
- Terraform assessment orchestration
- Public wrapper architecture
- Assessment confidence scoring
- HCL source handling
- Security analysis reliability
- Plan and drift analysis
- Platform documentation

Fixed:
- Refresh-only drift false positives
- Empty drift severity handling
- HCL discovery parsing failures involving empty files
- Security analysis failures caused by missing HCL source
- Wrapper and engine parameter inconsistencies
- Assessment result filtering
- Module command discovery
"@

            #
            # Prerelease value must remain empty for a stable release.
            #

            Prerelease = ""

            RequireLicenseAcceptance = $false

            ExternalModuleDependencies = @(
                "Microsoft.Graph.Authentication"
            )
        }

        #
        # Blackknight-specific metadata
        #

        PlatformName = "Blackknight One"

        PlatformVersion = "0.7.0"

        ReleaseChannel = "Stable"

        PrimaryEntryPoint = "Show-BKDashboard"

        SupportedDomains = @(
            "Platform"
            "Terraform"
            "MicrosoftGraph"
            "Identity"
            "Governance"
            "Trust"
            "Correlation"
            "Operations"
            "Reporting"
        )

        AssessmentModelVersion = "1.0"

        ReportSchemaVersion = "1.0"
    }

    #
    # Help information
    #
    # Leave blank until external help content is published.
    #

    HelpInfoURI = ""

    #
    # Default command prefix
    #

    DefaultCommandPrefix = ""
}