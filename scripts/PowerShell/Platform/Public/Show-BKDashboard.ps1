function Show-BKDashboard {
    <#
    .SYNOPSIS
    Displays the manifest-driven Blackknight One engine dashboard.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][switch]$Once,
        [Parameter()][switch]$PassThru
    )

    function Write-BKDashboardResult {
        [CmdletBinding()]
        param([Parameter(Mandatory)][object]$Result)

        $engineName = if ($Result.EngineInfo.Name) { $Result.EngineInfo.Name } elseif ($Result.Engine) { $Result.Engine } else { "Unknown" }
        $health = if ($Result.Scores.Health) { $Result.Scores.Health } elseif ($Result.Health) { $Result.Health } elseif ($Result.Summary.Health) { $Result.Summary.Health } else { "Unknown" }
        $score = if ($null -ne $Result.Scores.Score) { $Result.Scores.Score } elseif ($null -ne $Result.Score) { $Result.Score } elseif ($null -ne $Result.Confidence) { $Result.Confidence } else { $null }
        $findings = @($Result.Findings | Where-Object { $null -ne $_ })
        $recommendations = @($Result.Recommendations | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

        Write-Host ""
        Write-Host "Assessment Summary" -ForegroundColor Cyan
        Write-Host ("-" * 60)
        Write-Host ("Engine     : {0}" -f $engineName)
        Write-Host ("Status     : {0}" -f $(if ($Result.Status) { $Result.Status } else { "Complete" }))
        Write-Host ("Health     : {0}" -f $health)
        if ($null -ne $score) { Write-Host ("Score       : {0}%" -f $score) }
        if ($null -ne $Result.Confidence) { Write-Host ("Confidence  : {0}%" -f $Result.Confidence) }

        if ($null -ne $Result.Summary) {
            Write-Host ""
            $Result.Summary | Format-List | Out-Host
        }

        Write-Host ""
        Write-Host ("Findings: {0}" -f $findings.Count) -ForegroundColor Cyan
        if ($findings.Count -gt 0) {
            $findings |
                Select-Object Severity, Category, Title, Resource, Recommendation |
                Format-Table -Wrap -AutoSize |
                Out-Host
        }

        if ($recommendations.Count -gt 0) {
            Write-Host "Recommendations" -ForegroundColor Yellow
            foreach ($recommendation in $recommendations) {
                Write-Host ("- {0}" -f $recommendation)
            }
        }

        Write-Host ("-" * 60)
        if ($Result.GeneratedAt) { Write-Host ("Generated: {0}" -f $Result.GeneratedAt) }
        Write-Host ""
    }

    do {
        Clear-Host
        Write-Host "Blackknight One" -ForegroundColor Cyan
        Write-Host "Manifest-Driven Assessment Platform"
        Write-Host ("=" * 60)

        $engines = @(
            Get-BKEngine -Refresh |
                Where-Object { $_.SupportsDashboard -and $_.IsValid } |
                Sort-Object Category, DisplayName
        )

        if ($engines.Count -eq 0) {
            Write-Warning "No valid dashboard-enabled engines were discovered."
            return
        }

        $index = 1
        foreach ($engine in $engines) {
            Write-Host ("[{0}] {1} ({2})" -f $index, $engine.DisplayName, $engine.Category)
            $index++
        }
        Write-Host "[R] Refresh registry"
        Write-Host "[Q] Quit"
        Write-Host ""

        $selection = Read-Host "Select an engine"
        if ($selection -match '^[Qq]$') { return }
        if ($selection -match '^[Rr]$') { continue }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-Warning "Invalid selection."
            Start-Sleep -Seconds 1
            continue
        }
        if ($selectedIndex -lt 1 -or $selectedIndex -gt $engines.Count) {
            Write-Warning "Selection is outside the available range."
            Start-Sleep -Seconds 1
            continue
        }

        $selectedEngine = $engines[$selectedIndex - 1]
        Clear-Host
        Write-BKAssessmentHeader -Title $selectedEngine.DisplayName -Subtitle $selectedEngine.Description

        try {
            $result = Invoke-BKRegisteredEngine -Name $selectedEngine.Name -Operation Assessment -PassThru
            if ($PassThru.IsPresent) { return $result }
            if ($null -ne $result) { Write-BKDashboardResult -Result $result }
        }
        catch {
            Write-Error $_
        }

        if (-not $Once.IsPresent) {
            $null = Read-Host "Press Enter to return to the dashboard"
        }
    } while (-not $Once.IsPresent)
}


