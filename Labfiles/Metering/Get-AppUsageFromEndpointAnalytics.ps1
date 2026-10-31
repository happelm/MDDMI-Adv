#Requires -Version 5.1
<#
.SYNOPSIS
    Compares a list of licensed apps with the app usage that Endpoint analytics measured in the last 14 days.

.DESCRIPTION
    Endpoint analytics (Application reliability) reports per desktop app, for the whole tenant and the last 14 days:
      - activeDeviceCount : enrolled devices that launched the app at least once
      - appUsageDuration  : total usage time in minutes (engagement time: interactive + keep-alive)
    This script reads that table with Graph v1.0 and matches it against LicensedApps.json.

    Result per licensed app:
      Used        - the app is in the report
      NotInReport - the app is not in the report: not used, OR below the report threshold
                    (an app is listed only with more than 5 active devices or more than 2% of enrolled devices,
                    whichever is larger), OR the devices don't send Endpoint analytics data.
    "NotInReport" is a hint to check, not proof that nobody uses the app.

    The full table is exported as well (all apps, sorted by usage).

.PARAMETER LicenseFile
    JSON with the licensed apps. Default: LicensedApps.json next to the script.

.PARAMETER OutputFolder
    Folder for the CSV files. Default: .\AppUsage next to the current location.

.PARAMETER Delimiter
    CSV delimiter. Default: list separator of the current culture (Excel opens the file with columns).

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER PassThru
    Return the license rows as objects.

.EXAMPLE
    .\Get-AppUsageFromEndpointAnalytics.ps1

.EXAMPLE
    .\Get-AppUsageFromEndpointAnalytics.ps1 -LicenseFile .\MyApps.json -PassThru | Format-Table

.NOTES
    Version : 0.1 draft (2026-10-31) - not yet run against a tenant
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scope   : DeviceManagementManagedDevices.Read.All (read-only)
    Data    : Endpoint analytics must be enabled and devices must send data (Intune data collection policy).
    Sources : https://learn.microsoft.com/intune/endpoint-analytics/app-reliability
              https://learn.microsoft.com/graph/api/intune-devices-userexperienceanalyticsapphealthapplicationperformance-list?view=graph-rest-1.0
#>
[CmdletBinding()]
param(
    [string]$LicenseFile = (Join-Path $PSScriptRoot 'LicensedApps.json'),
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

# --- 1. Licensed apps -----------------------------------------------------------------------
if (-not (Test-Path $LicenseFile)) { throw "License file not found: $LicenseFile" }
$licensed = @((Get-Content -Path $LicenseFile -Raw | ConvertFrom-Json).apps)
if ($licensed.Count -eq 0) { throw "No apps in $LicenseFile." }

# --- 2. Sign-in ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
$connect = @{ Scopes = @('DeviceManagementManagedDevices.Read.All'); NoWelcome = $true }
if ($TenantId) { $connect.TenantId = $TenantId }
Connect-MgGraph @connect
$ctx = Get-MgContext
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"

# --- 3. Endpoint analytics app table (with paging) ----------------------------------------------
Write-Step 'Reading Endpoint analytics app performance (last 14 days)'
$uri = 'https://graph.microsoft.com/v1.0/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformance'
$apps = New-Object System.Collections.Generic.List[object]
while ($uri) {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    foreach ($a in @($page.value)) { $apps.Add($a) }
    $uri = $page.'@odata.nextLink'
}
Write-Step "$($apps.Count) apps in the report"
if ($apps.Count -eq 0) {
    Write-Warning 'The report is empty. Check that Endpoint analytics is enabled and devices send data (data can take up to 24 h after a restart).'
}

# --- 4. Match -------------------------------------------------------------------------------
$result = foreach ($l in $licensed) {
    $hit = $apps | Where-Object { $_.appName -ieq $l.appName } | Select-Object -First 1
    $lic = [int]$l.licenses
    if ($hit) {
        [pscustomobject]@{
            LicensedApp       = $l.name
            AppName           = $l.appName
            Status            = 'Used'
            ActiveDevices14d  = [int]$hit.activeDeviceCount
            UsageHours14d     = [math]::Round([int]$hit.appUsageDuration / 60, 1)
            Licenses          = $lic
            LicensesNotActive = if ($lic -gt 0) { [math]::Max(0, $lic - [int]$hit.activeDeviceCount) } else { $null }
            Publisher         = $hit.appPublisher
        }
    }
    else {
        [pscustomobject]@{
            LicensedApp       = $l.name
            AppName           = $l.appName
            Status            = 'NotInReport'
            ActiveDevices14d  = 0
            UsageHours14d     = 0
            Licenses          = $lic
            LicensesNotActive = if ($lic -gt 0) { $lic } else { $null }
            Publisher         = $null
        }
    }
}

$all = $apps | Sort-Object { [int]$_.appUsageDuration } -Descending | ForEach-Object {
    [pscustomobject]@{
        AppName          = $_.appName
        DisplayName      = $_.appDisplayName
        Publisher        = $_.appPublisher
        ActiveDevices14d = [int]$_.activeDeviceCount
        UsageHours14d    = [math]::Round([int]$_.appUsageDuration / 60, 1)
        Crashes14d       = [int]$_.appCrashCount
        Hangs14d         = [int]$_.appHangCount
    }
}

# --- 5. Export --------------------------------------------------------------------------------
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }
$licPath = Join-Path $OutputFolder "LicensedAppUsage_$stamp.csv"
$allPath = Join-Path $OutputFolder "AllAppUsage_$stamp.csv"
$result | Export-Csv -Path $licPath -Delimiter $Delimiter -NoTypeInformation -Encoding $enc
$all    | Export-Csv -Path $allPath -Delimiter $Delimiter -NoTypeInformation -Encoding $enc

$result | Format-Table LicensedApp, Status, ActiveDevices14d, UsageHours14d, Licenses, LicensesNotActive -AutoSize | Out-Host
Write-Host "Licensed apps : $licPath" -ForegroundColor Green
Write-Host "All apps      : $allPath" -ForegroundColor Green
Write-Host 'NotInReport = not used OR below the report threshold (>5 devices or >2%). Check before you cancel licenses.' -ForegroundColor Yellow

if ($PassThru) { $result }
