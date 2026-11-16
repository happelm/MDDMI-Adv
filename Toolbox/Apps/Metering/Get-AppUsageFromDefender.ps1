#Requires -Version 5.1
<#
.SYNOPSIS
    Software metering with Microsoft Defender for Endpoint: counts launches of licensed apps with an
    advanced hunting query through Microsoft Graph and compares them with the number of licenses.

.DESCRIPTION
    Defender for Endpoint records every process start in the advanced hunting table DeviceProcessEvents.
    This script builds a KQL query for the apps in LicensedApps.json, runs it with
    POST /security/runHuntingQuery and exports:

      Summary (default)  one row per licensed app: launches, devices, users, last launch, licenses not used
      -PerDevice         one row per device and app: launches, last launch
      -IncludeUserNames  adds the user (UPN) to the per-device rows

    By default the result contains no user names: users are only counted. Per-person usage data is
    subject to data protection rules and, in many companies, to the works council. Use -IncludeUserNames
    only when that is cleared.

    The query counts process starts. There is no process end, so it measures launches, not minutes of use.
    A program that starts copies of itself (for example a browser) is counted once per start of the
    first process only (starts whose parent has the same file name are left out).

.PARAMETER LicenseFile
    JSON with the licensed apps. Default: LicensedApps.json next to the script.

.PARAMETER Days
    Look-back in days, 1-30. Advanced hunting keeps 30 days of Defender data. Default 30.

.PARAMETER PerDevice
    Export one row per device and app instead of the summary.

.PARAMETER IncludeUserNames
    With -PerDevice: add the user principal name. Off by default (see DESCRIPTION).

.PARAMETER ShowQuery
    Print the KQL query and exit, for example to paste it into the Defender portal.

.PARAMETER OutputFolder
    Folder for the CSV. Default: .\AppUsage next to the current location.

.PARAMETER Delimiter
    CSV delimiter. Default: list separator of the current culture (Excel opens the file with columns).

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER PassThru
    Return the rows as objects.

.EXAMPLE
    .\Get-AppUsageFromDefender.ps1

.EXAMPLE
    .\Get-AppUsageFromDefender.ps1 -Days 14 -PerDevice

.EXAMPLE
    .\Get-AppUsageFromDefender.ps1 -ShowQuery

.NOTES
    Version : 0.2 draft (2026-11-02) - not yet run against a tenant
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scope   : ThreatHunting.Read.All (read-only)
    Needs   : Devices onboarded to Microsoft Defender for Endpoint (DeviceProcessEvents is populated only by MDE).
              Microsoft 365 E5 includes Defender for Endpoint Plan 2.
    Limits  : 30 days of data, 100,000 rows and 10 minutes per query (advanced hunting quotas).
    Sources : https://learn.microsoft.com/graph/api/security-security-runhuntingquery?view=graph-rest-1.0
              https://learn.microsoft.com/defender-xdr/advanced-hunting-deviceprocessevents-table
              https://learn.microsoft.com/defender-xdr/advanced-hunting-overview#quotas-and-usage-parameters
#>
[CmdletBinding()]
param(
    [string]$LicenseFile = (Join-Path $PSScriptRoot 'LicensedApps.json'),
    [ValidateRange(1, 30)]
    [int]$Days = 30,
    [switch]$PerDevice,
    [switch]$IncludeUserNames,
    [switch]$ShowQuery,
    [string]$OutputFolder = (Join-Path (Get-Location).Path 'AppUsage'),
    [string]$Delimiter = (Get-Culture).TextInfo.ListSeparator,
    [string]$TenantId,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

if ($IncludeUserNames -and -not $PerDevice) { throw '-IncludeUserNames works only with -PerDevice.' }

# --- 1. Licensed apps -----------------------------------------------------------------------
if (-not (Test-Path $LicenseFile)) { throw "License file not found: $LicenseFile" }
$licensed = @((Get-Content -Path $LicenseFile -Raw | ConvertFrom-Json).apps)
if ($licensed.Count -eq 0) { throw "No apps in $LicenseFile." }
foreach ($l in $licensed) {
    if ([string]$l.appName -notmatch '^[^\\/:*?"<>|'']+\.exe$') { throw "Invalid appName '$($l.appName)' in $LicenseFile. Use a file name such as 'visio.exe'." }
}
$appList = ($licensed | ForEach-Object { '"{0}"' -f ([string]$_.appName).ToLowerInvariant() }) -join ', '

# --- 2. KQL query ----------------------------------------------------------------------------
$base = @"
let Watchlist = dynamic([$appList]);
DeviceProcessEvents
| where Timestamp > ago($($Days)d)
| extend App = tolower(FileName)
| where App in (Watchlist)
| where tolower(InitiatingProcessFileName) != App
"@

if ($PerDevice) {
    $by = if ($IncludeUserNames) { 'DeviceName, AccountUpn, App' } else { 'DeviceName, App' }
    $query = $base + @"

| summarize Launches = count(), LastLaunch = max(Timestamp) by $by
| order by App asc, LastLaunch desc
"@
}
else {
    $query = $base + @"

| summarize Launches = count(), Devices = dcount(DeviceId), Users = dcount(AccountObjectId), LastLaunch = max(Timestamp) by App
"@
}

if ($ShowQuery) { $query; return }

# --- 3. Sign-in ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
$connect = @{ Scopes = @('ThreatHunting.Read.All'); NoWelcome = $true }
if ($TenantId) { $connect.TenantId = $TenantId }
Connect-MgGraph @connect
$ctx = Get-MgContext
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"

# --- 4. Run the hunting query -------------------------------------------------------------------
Write-Step "Running advanced hunting query ($Days days, $($licensed.Count) apps)"
Write-Verbose $query
$body = @{ Query = $query; Timespan = "P$($Days)D" } | ConvertTo-Json
$response = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/security/runHuntingQuery' -Body $body -ContentType 'application/json; charset=utf-8' -OutputType PSObject
$hits = @($response.results)
Write-Step "$($hits.Count) result rows"

# --- 5. Build the rows ------------------------------------------------------------------------
# Property access in PowerShell ignores case, so 'Launches' and 'launches' both work.
if ($PerDevice) {
    $rows = foreach ($h in $hits) {
        $row = [ordered]@{ DeviceName = $h.DeviceName }
        if ($IncludeUserNames) { $row.User = $h.AccountUpn }
        $row.App        = $h.App
        $row.Launches   = [int]$h.Launches
        $row.LastLaunch = $h.LastLaunch
        [pscustomobject]$row
    }
    $file = 'DefenderAppUsageByDevice'
}
else {
    $rows = foreach ($l in $licensed) {
        $name = ([string]$l.appName).ToLowerInvariant()
        $h = $hits | Where-Object { [string]$_.App -eq $name } | Select-Object -First 1
        $lic = [int]$l.licenses
        $users = if ($h) { [int]$h.Users } else { 0 }
        [pscustomobject]@{
            LicensedApp     = $l.name
            AppName         = $name
            Launches        = if ($h) { [int]$h.Launches } else { 0 }
            Devices         = if ($h) { [int]$h.Devices } else { 0 }
            Users           = $users
            LastLaunch      = if ($h) { $h.LastLaunch } else { $null }
            Licenses        = $lic
            LicensesNotUsed = if ($lic -gt 0) { [math]::Max(0, $lic - $users) } else { $null }
        }
    }
    $file = 'DefenderAppUsage'
}

# --- 6. Export --------------------------------------------------------------------------------
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }
$csvPath = Join-Path $OutputFolder ("{0}_{1}d_{2}.csv" -f $file, $Days, (Get-Date -Format 'yyyyMMdd-HHmmss'))
$rows | Export-Csv -Path $csvPath -Delimiter $Delimiter -NoTypeInformation -Encoding $enc

$rows | Format-Table -AutoSize | Out-Host
Write-Host "CSV : $csvPath" -ForegroundColor Green
if (-not $PerDevice) {
    Write-Host 'Users = distinct accounts that launched the app. 0 launches = not started on any onboarded device in the period.' -ForegroundColor Yellow
}

if ($PassThru) { $rows }
