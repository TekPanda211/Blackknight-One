function Test-BKRuntime {
    <#
    .SYNOPSIS
    Validates the Blackknight engine runtime, registry, and public dispatcher.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ThrowOnFailure
    )

    $checks = [System.Collections.Generic.List[object]]::new()

    function Add-Check {
        param(
            [string]$Name,
            [bool]$Passed,
            [string]$Message
        )

        $checks.Add([PSCustomObject]@{
            Name    = $Name
            Passed  = $Passed
            Message = $Message
        }) | Out-Null
    }

    $internalRuntime = Get-Command Invoke-BKEngine -ErrorAction SilentlyContinue
    Add-Check -Name 'Internal engine runtime loaded' -Passed ($null -ne $internalRuntime) -Message $(
        if ($internalRuntime) { 'Invoke-BKEngine is available inside the module runtime.' }
        else { 'Invoke-BKEngine was not loaded from the Shared Framework.' }
    )

    $publicDispatcher = Get-Command Invoke-BKRegisteredEngine -ErrorAction SilentlyContinue
    Add-Check -Name 'Public dispatcher exported' -Passed ($null -ne $publicDispatcher) -Message $(
        if ($publicDispatcher) { 'Invoke-BKRegisteredEngine is available.' }
        else { 'Invoke-BKRegisteredEngine is missing.' }
    )

    try {
        $engines = @(Get-BKEngine -Refresh)
        Add-Check -Name 'Engine registry loaded' -Passed ($engines.Count -gt 0) -Message "Discovered $($engines.Count) engine(s)."

        foreach ($engine in $engines) {
            Add-Check `
                -Name "Engine manifest: $($engine.Name)" `
                -Passed ([bool]$engine.IsValid) `
                -Message $(if ($engine.IsValid) { 'Valid' } else { ($engine.ValidationErrors -join '; ') })
        }
    }
    catch {
        Add-Check -Name 'Engine registry loaded' -Passed $false -Message $_.Exception.Message
    }

    $failed = @($checks | Where-Object { -not $_.Passed })
    $result = [PSCustomObject]@{
        PSTypeName   = 'Blackknight.RuntimeValidationResult'
        Passed       = ($failed.Count -eq 0)
        TotalChecks  = $checks.Count
        PassedChecks = @($checks | Where-Object Passed).Count
        FailedChecks = $failed.Count
        Checks       = @($checks)
        GeneratedAt  = [DateTimeOffset]::UtcNow
    }

    if ($ThrowOnFailure -and -not $result.Passed) {
        throw ('Blackknight runtime validation failed: ' + (($failed | ForEach-Object { "$($_.Name): $($_.Message)" }) -join ' | '))
    }

    return $result
}
