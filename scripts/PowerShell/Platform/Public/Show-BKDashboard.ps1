function Show-BKDashboard {

    [CmdletBinding()]
    param()

    $dashboard = Get-BKDashboardData

function Format-BKConfidence {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return "Not Available"
    }

    return "$Value%"
}

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "                 BLACKKNIGHT ONE" -ForegroundColor Cyan
    Write-Host "      Enterprise Identity Engineering Platform" -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Platform" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------"

    Write-Host ("Version".PadRight(25) + $dashboard.Platform.Version)
    Write-Host ("Registered Engines".PadRight(25) + $dashboard.Platform.EngineCount)
    Write-Host ("Platform Services".PadRight(25) + $dashboard.Platform.ServiceCount)
    Write-Host ("Capabilities".PadRight(25) + $dashboard.Platform.CapabilityCount)

    Write-Host ""

    Write-Host "Tenant" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------"

    Write-Host ("Tenant".PadRight(25) + $dashboard.Tenant.Name)
    Write-Host ("Users".PadRight(25) + $dashboard.Tenant.TotalUsers)
    Write-Host ("Groups".PadRight(25) + $dashboard.Tenant.TotalGroups)
    Write-Host ("Guests".PadRight(25) + $dashboard.Tenant.GuestUsers)

    Write-Host ""

    Write-Host "Confidence" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------"

    Write-Host ("Identity".PadRight(25) + (Format-BKConfidence $dashboard.Confidence.Identity))
Write-Host ("Trust".PadRight(25) + (Format-BKConfidence $dashboard.Confidence.Trust))
Write-Host ("Governance".PadRight(25) + (Format-BKConfidence $dashboard.Confidence.Governance))
Write-Host ("Operations".PadRight(25) + (Format-BKConfidence $dashboard.Confidence.Operations))
Write-Host ("Validation".PadRight(25) + (Format-BKConfidence $dashboard.Confidence.Validation))

    Write-Host ""

    Write-Host "Overall Platform Confidence" -ForegroundColor Green
    Write-Host "=========================================================="

    Write-Host ("".PadRight(20) + "$($dashboard.Confidence.Overall)%") -ForegroundColor Green

    Write-Host "=========================================================="

    Write-Host ""

    if ($dashboard.Findings.Recommendations.Count -gt 0) {

        Write-Host "Top Recommendations" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------"

        $dashboard.Findings.Recommendations |
            Select-Object -First 5 |
            ForEach-Object {

                Write-Host "• $_"
            }

        Write-Host ""
    }

}