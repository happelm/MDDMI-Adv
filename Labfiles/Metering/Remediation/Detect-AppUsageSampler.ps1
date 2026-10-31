<#
.SYNOPSIS
    Remediation detection script (detection only): samples which watched apps are running and keeps
    a 30-day count per app on the device. The count is the script output, so Intune collects it.

.DESCRIPTION
    Software metering light. Every run (schedule: hourly) the script checks whether the processes in
    $Watchlist are running and adds one "sample" per running app to a local state file. The output
    line sums up the last $WindowDays days, for example:

        days=30;samples=212;visio=14@2026-10-30;winproj=0;msaccess=3@2026-10-12

      samples   = number of runs (hourly checks) in the window
      visio=14  = visio.exe was running in 14 of those checks, last seen 2026-10-30
      winproj=0 = never seen running in the window

    This measures "was running at check time", not minutes of use: an app that is opened and closed
    between two checks is not seen. Use it to find apps that are never used, not to bill usage.

    Exit code is always 0 (no remediation script). Read the results with
    Get-AppUsageFromRemediation.ps1 or in the device status of the remediation (column "Pre-remediation
    detection output").

.NOTES
    Version : 0.1 draft (2026-10-31) - not yet run on a device
    Intune  : Run this script using the logged-on credentials = No (system context sees all sessions),
              Run script in 64-bit PowerShell = Yes, schedule = Hourly
    State   : C:\ProgramData\MDDMI-Adv\AppUsage\state.json (delete it to reset the counts)
    Limits  : Remediation output is truncated after 2,048 characters - keep the watchlist short (about 30 apps).
    Source  : https://learn.microsoft.com/intune/device-management/tools/deploy-remediations
#>

# Process names without .exe, lowercase. Keep the list short (output limit 2,048 characters).
$Watchlist  = @('visio', 'winproj', 'msaccess', 'notepad++', 'notepad')
$WindowDays = 30
$StateDir   = Join-Path $env:ProgramData 'MDDMI-Adv\AppUsage'
$StateFile  = Join-Path $StateDir 'state.json'

try {
    # --- Load state: one bucket per day { "2026-10-31": { "_samples": 5, "visio": 2 } } -----------
    $days = @{}
    if (Test-Path $StateFile) {
        $json = Get-Content -Path $StateFile -Raw | ConvertFrom-Json
        foreach ($d in $json.PSObject.Properties) {
            $bucket = @{}
            foreach ($p in $d.Value.PSObject.Properties) { $bucket[$p.Name] = [int]$p.Value }
            $days[$d.Name] = $bucket
        }
    }

    # --- Sample now ---------------------------------------------------------------------------
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if (-not $days.ContainsKey($today)) { $days[$today] = @{ '_samples' = 0 } }
    $days[$today]['_samples']++

    $running = @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $_.ProcessName.ToLowerInvariant() } | Sort-Object -Unique)
    foreach ($app in $Watchlist) {
        if ($running -contains $app.ToLowerInvariant()) {
            if (-not $days[$today].ContainsKey($app)) { $days[$today][$app] = 0 }
            $days[$today][$app]++
        }
    }

    # --- Drop buckets outside the window and save -----------------------------------------------
    $cutoff = (Get-Date).Date.AddDays(-($WindowDays - 1)).ToString('yyyy-MM-dd')
    foreach ($k in @($days.Keys)) { if ($k -lt $cutoff) { $days.Remove($k) } }
    if (-not (Test-Path $StateDir)) { New-Item -Path $StateDir -ItemType Directory -Force | Out-Null }
    $days | ConvertTo-Json -Depth 3 | Set-Content -Path $StateFile -Encoding UTF8

    # --- Output: one line -----------------------------------------------------------------------
    $samples = 0
    foreach ($b in $days.Values) { $samples += $b['_samples'] }
    $parts = @("days=$($days.Count)", "samples=$samples")
    foreach ($app in $Watchlist) {
        $count = 0; $last = $null
        foreach ($k in ($days.Keys | Sort-Object)) {
            if ($days[$k].ContainsKey($app)) { $count += $days[$k][$app]; $last = $k }
        }
        $parts += if ($count -gt 0) { "$app=$count@$last" } else { "$app=0" }
    }
    Write-Output ($parts -join ';')
    exit 0
}
catch {
    Write-Output "error=$($_.Exception.Message)"
    exit 0
}
