<#
.SYNOPSIS
Blackknight One Platform Services

.DESCRIPTION
Shared platform service functions used by Blackknight One engines.
These services provide common configuration, logging, result creation,
report export, and confidence calculation.
#>

$script:BlackknightVersion = "0.4.0-alpha"

function Get-BKConfiguration {
    [PSCustomObject]@{
        PlatformName = "Blackknight One"
        Version      = $script:BlackknightVersion
        OutputRoot   = ".\reports"
        Environment  = "Development"
        Timestamp    = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Write-BKLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function New-BKResult {
    param(
        [string]$Engine,
        [string]$Version = $script:BlackknightVersion,
        [string]$Status = "Framework",
        [string]$Health = "Healthy",
        [int]$Confidence = 75,
        [int]$ChecksRun = 1,
        [int]$Passed = 1,
        [int]$Warnings = 0,
        [int]$Failed = 0,
        [string[]]$Evidence = @(),
        [string[]]$Recommendations = @()
    )

    [PSCustomObject]@{
        Engine          = $Engine
        Version         = $Version
        Status          = $Status
        Health          = $Health
        Confidence      = $Confidence
        ChecksRun       = $ChecksRun
        Passed          = $Passed
        Warnings        = $Warnings
        Failed          = $Failed
        Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
        Evidence        = $Evidence
        Recommendations = $Recommendations
    }
}

function Export-BKJsonReport {
    param(
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $folder = Split-Path $Path -Parent

    if (!(Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding utf8

    Write-BKLog -Message "Exported JSON report to $Path" -Level Success
}

function Get-BKConfidenceScore {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    if (!$Results -or $Results.Count -eq 0) {
        return 0
    }

    [math]::Round(($Results.Confidence | Measure-Object -Average).Average, 2)
}