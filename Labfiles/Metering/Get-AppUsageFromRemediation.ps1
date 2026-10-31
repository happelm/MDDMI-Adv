#Requires -Version 5.1
<#
.SYNOPSIS
    Collects the output of the remediation "Detect-AppUsageSampler.ps1" from all devices and builds a
    table: one row per device, one column per watched app.

.DESCRIPTION
    Reads the device run states of a remediation (Graph beta: deviceHealthScripts/{id}/deviceRunStates),
    parses the output line of the sampler (days=..;samples=..;visio=14@2026-10-30;...) and exports a CSV.

    Columns per app: <app> (number of hourly checks where the app was running) and <app>_LastSeen.
    A device with 0 for an app never had it running at check time in the window (default 30 days).

.PARAMETER RemediationName
    Display name of the remediation in Intune.

.PARAMETER RemediationId
    ID of the remediation (instead of the name, from the browser address bar).

.PARAMETER OutputFolder
    Folder for the CSV. Default: .\AppUsage next to the current location.

.PARAMETER Delimiter
    CSV delimiter. Default: list separator of the current culture.

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER PassThru
    Return the rows as objects.

.EXAMPLE
    .\Get-AppUsageFromRemediation.ps1 -RemediationName 'App usage sampler'

.EXAMPLE
    .\Get-AppUsageFromRemediation.ps1 -RemediationId 00000000-0000-0000-0000-000000000000 -PassThru | Out-GridView

.NOTES
    Version : 0.1 draft (2026-10-31) - not yet run against a tenant
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scopes  : DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All (read-only)
    API     : beta only (deviceHealthScriptDeviceState, property preRemediationDetectionScriptOutput,
              relationship managedDevice)
    Source  : https://learn.microsoft.com/graph/api/resources/intune-devices-devicehealthscriptdevicestate?view=graph-rest-beta
#>
[CmdletBinding(DefaultParameterSetName = 'Name')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Name', Position = 0)]
    [string]$RemediationName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$RemediationId,

    [string]$OutputFolder = (Join-Path (Get-Location).Path 'AppUsage'),
    [string]$Delimiter = (Get-Culture).TextInfo.ListSeparator,
    [string]$TenantId,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$GraphBase = 'https://graph.microsoft.com/beta'

function Write-Step {
    param([string]$Message)
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

function Get-GraphAll {
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        foreach ($i in @($page.value)) { $items.Add($i) }
        $Uri = $page.'@odata.nextLink'
    }
    , $items
}

# --- 1. Sign-in ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
$connect = @{ Scopes = @('DeviceManagementConfiguration.Read.All', 'DeviceManagementManagedDevices.Read.All'); NoWelcome = $true }
if ($TenantId) { $connect.TenantId = $TenantId }
Connect-MgGraph @connect
$ctx = Get-MgContext
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"

# --- 2. Find the remediation --------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Name') {
    $escaped = $RemediationName.Replace("'", "''")
    $found = Get-GraphAll -Uri ("$GraphBase/deviceManagement/deviceHealthScripts?`$filter=displayName eq '{0}'&`$select=id,displayName" -f $escaped)
    if ($found.Count -eq 0) { throw "Remediation '$RemediationName' not found." }
    if ($found.Count -gt 1) { throw "More than one remediation is named '$RemediationName'. Use -RemediationId." }
    $RemediationId = $found[0].id
}
Write-Step "Remediation $RemediationId"

# --- 3. Device run states ---------------------------------------------------------------------
$states = Get-GraphAll -Uri "$GraphBase/deviceManagement/deviceHealthScripts/$RemediationId/deviceRunStates?`$expand=managedDevice"
Write-Step "$($states.Count) device run states"

# --- 4. Parse the output line -----------------------------------------------------------------
$rows = foreach ($s in $states) {
    $out = [string]$s.preRemediationDetectionScriptOutput
    $row = [ordered]@{
        DeviceName = $s.managedDevice.deviceName
        User       = $s.managedDevice.userPrincipalName
        LastRun    = $s.lastStateUpdateDateTime
        Days       = $null
        Samples    = $null
        Error      = $null
    }
    foreach ($pair in ($out -split ';')) {
        if ($pair -notmatch '^(?<k>[^=]+)=(?<v>.*)$') { continue }
        $k = $Matches.k; $v = $Matches.v
        switch ($k) {
            'days'    { $row.Days = [int]$v }
            'samples' { $row.Samples = [int]$v }
            'error'   { $row.Error = $v }
            default {
                $count, $last = $v -split '@', 2
                $row[$k] = [int]$count
                $row["$($k)_LastSeen"] = $last
            }
        }
    }
    if (-not $out) { $row.Error = 'no output yet' }
    [pscustomobject]$row
}

# All rows get the same columns (Export-Csv takes the columns of the first row)
$columns = New-Object System.Collections.Generic.List[string]
foreach ($r in $rows) { foreach ($p in $r.PSObject.Properties.Name) { if (-not $columns.Contains($p)) { $columns.Add($p) } } }
$rows = @($rows | Select-Object -Property $columns | Sort-Object DeviceName)

# --- 5. Export --------------------------------------------------------------------------------
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }
$csvPath = Join-Path $OutputFolder ("RemediationAppUsage_{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$rows | Export-Csv -Path $csvPath -Delimiter $Delimiter -NoTypeInformation -Encoding $enc

$rows | Format-Table -AutoSize | Out-Host
Write-Host "CSV : $csvPath" -ForegroundColor Green

if ($PassThru) { $rows }
