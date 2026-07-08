<#
.SYNOPSIS
Blackknight One Governance Engine

.DESCRIPTION
Runs Identity Governance framework checks for Access Packages,
Entitlement Management, Administrative Units, Dynamic Groups,
Access Reviews, Lifecycle Workflows, and GDAP-inspired governance.

This version uses shared Blackknight One Platform Services for
standard result creation and JSON report export.
#>

param(
    [string]$OutputPath = ".\reports\governance",
    [switch]$ExportJson
)

$PlatformModule = Join-Path (Split-Path $PSScriptRoot -Parent) "Platform\Blackknight-Platform.psm1"

if (Test-Path $PlatformModule) {
    Import-Module $PlatformModule -Force
}
else {
    throw "Blackknight Platform module not found at $PlatformModule"
}

function Write-BKSection {
    param([string]$Title)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Invoke-AccessPackageFramework {
    Write-BKSection "Access Package Framework"

    New-BKResult `
        -Engine "Access Packages" `
        -Evidence @(
            "Access Package framework documented",
            "Access Package standard created",
            "Access Package Terraform model defined"
        ) `
        -Recommendations @(
            "Add Microsoft Graph discovery for catalogs and access packages",
            "Validate assignment policies, approvals, expiration, and reviews"
        )
}

function Invoke-EntitlementManagementFramework {
    Write-BKSection "Entitlement Management Framework"

    New-BKResult `
        -Engine "Entitlement Management" `
        -Evidence @(
            "Governance catalog defined",
            "Governed access workflow documented",
            "Request, approve, assign, validate, review, expire, report pattern established"
        ) `
        -Recommendations @(
            "Add catalog discovery",
            "Add assignment policy validation"
        )
}

function Invoke-AdministrativeUnitFramework {
    Write-BKSection "Administrative Unit Framework"

    New-BKResult `
        -Engine "Administrative Units" `
        -Evidence @(
            "Administrative Units identified as governance capability",
            "Scoped administration model documented"
        ) `
        -Recommendations @(
            "Add Terraform Administrative Unit model",
            "Add Microsoft Graph Administrative Unit discovery"
        )
}

function Invoke-DynamicGroupFramework {
    Write-BKSection "Dynamic Group Framework"

    New-BKResult `
        -Engine "Dynamic Groups" `
        -Evidence @(
            "Dynamic Groups identified for attribute-based access",
            "Department-based membership model planned"
        ) `
        -Recommendations @(
            "Add dynamic membership rule examples",
            "Validate department, employee type, and location attributes"
        )
}

function Invoke-AccessReviewFramework {
    Write-BKSection "Access Review Framework"

    New-BKResult `
        -Engine "Access Reviews" `
        -Evidence @(
            "Access Reviews included in governance model",
            "Privileged, guest, contractor, and application access review use cases documented"
        ) `
        -Recommendations @(
            "Add Access Review discovery",
            "Add overdue review detection"
        )
}

function Invoke-GDAPGovernanceFramework {
    Write-BKSection "GDAP-Inspired Governance Framework"

    New-BKResult `
        -Engine "GDAP-Inspired Governance" `
        -Evidence @(
            "Delegated access governance model documented",
            "Group-based delegated access review pattern defined"
        ) `
        -Recommendations @(
            "Add delegated role inventory",
            "Add stale delegated access detection",
            "Add GDAP expiration reporting"
        )
}

function Invoke-BlackKnightGovernance {
    Write-BKSection "Blackknight One Governance Engine"

    if (!(Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $results = @()
    $results += Invoke-AccessPackageFramework
    $results += Invoke-EntitlementManagementFramework
    $results += Invoke-AdministrativeUnitFramework
    $results += Invoke-DynamicGroupFramework
    $results += Invoke-AccessReviewFramework
    $results += Invoke-GDAPGovernanceFramework

    $results | Format-Table Engine, Version, Status, Health, Confidence, ChecksRun, Passed, Warnings, Failed, Timestamp -AutoSize

    if ($ExportJson) {
        $jsonPath = Join-Path $OutputPath "governance-health.json"
        Export-BKJsonReport -Data $results -Path $jsonPath
    }

    Write-BKSection "Governance Engine Complete"
}

Invoke-BlackKnightGovernance