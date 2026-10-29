#Requires -Version 5.1
<#
.SYNOPSIS
    Exports an Intune report with the Microsoft Graph exportJobs API and saves it as CSV (ready for Excel).

.DESCRIPTION
    The Intune reports that run on the Intune reporting infrastructure are exported in three steps:
      1. POST /deviceManagement/reports/exportJobs with reportName, select, filter and format.
      2. GET the job until status is "completed".
      3. Download the ZIP from the job's url (a time-limited SAS link) and extract the CSV.

    This script runs the three steps for a preset from ReportPresets.json or for any reportName.
    The CSV is converted to the list separator of the current culture so that Excel opens it with columns
    (in German Windows: semicolon). The original file from Intune is kept as *_raw.csv.

    Always pass the columns explicitly (preset or -Select): Microsoft recommends not to build automation
    on the default columns of a report.

.PARAMETER Preset
    Name of a preset in ReportPresets.json. -ListPresets shows them.

.PARAMETER ReportName
    Any reportName from the Learn list (instead of -Preset). Use -Select to choose the columns.

.PARAMETER Select
    Columns. With -Preset it replaces the preset's columns.

.PARAMETER Filter
    Report filter, e.g. "(OwnerType eq '1')". With -Preset it replaces the preset's filter.

.PARAMETER PolicyId
    Replaces {PolicyId} in the preset filter (RemediationResults, FeatureUpdateDeviceState).

.PARAMETER ApplicationId
    Replaces {ApplicationId} in the preset filter (AppInstallStatusByDevice).

.PARAMETER LocalizationType
    ReplaceLocalizableValues (default here: readable values such as "Windows" instead of codes) or
    LocalizedValuesAsAdditionalColumn (code column plus *_loc column). The reports Devices and
    DevicesWithInventory ignore this parameter.

.PARAMETER OutputFolder
    Folder for the CSV files. Default: .\ReportExports next to the current location.

.PARAMETER Delimiter
    Delimiter of the converted CSV. Default: list separator of the current culture.

.PARAMETER TimeoutMinutes
    How long to wait for the export job. Default 10.

.PARAMETER ListPresets
    Show the presets and exit.

.PARAMETER PassThru
    Return the rows as objects.

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER SkipTenantConfirmation
    Do not ask to confirm the connected tenant.

.EXAMPLE
    .\Export-IntuneReport.ps1 -ListPresets

.EXAMPLE
    .\Export-IntuneReport.ps1 -Preset Devices

.EXAMPLE
    .\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId 00000000-0000-0000-0000-000000000000

.EXAMPLE
    .\Export-IntuneReport.ps1 -ReportName DeviceCompliance -Select DeviceName,ComplianceState,UPN -Filter "(ComplianceState eq '2')"

.NOTES
    Version : 1.0 (2026-10-29)
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scope   : DeviceManagementConfiguration.ReadWrite.All (creating an export job needs a ReadWrite scope
              according to the Graph reference; the job itself changes nothing in the tenant)
    Throttling (Learn): up to 8 export requests per user per minute, 100 per tenant per minute.
    Sources : https://learn.microsoft.com/intune/device-management/reports/export-graph-apis
              https://learn.microsoft.com/intune/device-management/reports/ref-graph-available-reports
#>
[CmdletBinding(DefaultParameterSetName = 'Preset')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Preset', Position = 0)]
    [string]$Preset,

    [Parameter(Mandatory = $true, ParameterSetName = 'Report')]
    [string]$ReportName,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [string[]]$Select,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [string]$Filter,

    [Parameter(ParameterSetName = 'Preset')]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$PolicyId,

    [Parameter(ParameterSetName = 'Preset')]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$ApplicationId,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [ValidateSet('ReplaceLocalizableValues', 'LocalizedValuesAsAdditionalColumn')]
    [string]$LocalizationType = 'ReplaceLocalizableValues',

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [string]$OutputFolder = (Join-Path (Get-Location).Path 'ReportExports'),

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [string]$Delimiter = (Get-Culture).TextInfo.ListSeparator,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [int]$TimeoutMinutes = 10,

    [Parameter(Mandatory = $true, ParameterSetName = 'List')]
    [switch]$ListPresets,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [switch]$PassThru,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [string]$TenantId,

    [Parameter(ParameterSetName = 'Preset')]
    [Parameter(ParameterSetName = 'Report')]
    [switch]$SkipTenantConfirmation
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$GraphBase = 'https://graph.microsoft.com/beta'
$presetFile = Join-Path $PSScriptRoot 'ReportPresets.json'

function Write-Step {
    param([string]$Message)
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

# --- 1. Request definition -----------------------------------------------------------------
$presets = @()
if (Test-Path $presetFile) { $presets = @((Get-Content -Path $presetFile -Raw | ConvertFrom-Json).presets) }

if ($ListPresets) {
    $presets | Format-Table @{ n = 'Preset'; e = { $_.name } }, @{ n = 'reportName'; e = { $_.reportName } }, @{ n = 'Description'; e = { $_.description } } -AutoSize -Wrap | Out-Host
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Preset') {
    $p = $presets | Where-Object { $_.name -eq $Preset } | Select-Object -First 1
    if (-not $p) { throw "Preset '$Preset' not found in $presetFile. Use -ListPresets." }
    $name     = $Preset
    $report   = [string]$p.reportName
    $columns  = if ($Select) { $Select } else { @($p.select) }
    $reportFilter = if ($PSBoundParameters.ContainsKey('Filter')) { $Filter } else { [string]$p.filter }
    if ($reportFilter -match '\{PolicyId\}') {
        if (-not $PolicyId) { throw "Preset '$Preset' needs -PolicyId." }
        $reportFilter = $reportFilter.Replace('{PolicyId}', $PolicyId)
    }
    if ($reportFilter -match '\{ApplicationId\}') {
        if (-not $ApplicationId) { throw "Preset '$Preset' needs -ApplicationId." }
        $reportFilter = $reportFilter.Replace('{ApplicationId}', $ApplicationId)
    }
}
else {
    $name    = $ReportName
    $report  = $ReportName
    $columns = $Select
    $reportFilter = $Filter
    if (-not $columns) { Write-Warning 'No -Select given: the report returns its default columns, which can change. Pass the columns for anything you automate.' }
}

$body = [ordered]@{
    reportName       = $report
    format           = 'csv'
    localizationType = $LocalizationType
}
if ($columns) { $body.select = @($columns) }
if ($reportFilter) { $body.filter = $reportFilter }

# --- 2. Sign-in ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
$connect = @{ Scopes = @('DeviceManagementConfiguration.ReadWrite.All'); NoWelcome = $true }
if ($TenantId) { $connect.TenantId = $TenantId }
Connect-MgGraph @connect
$ctx = Get-MgContext
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"
if (-not $SkipTenantConfirmation) {
    $answer = Read-Host "Export report '$report' from this tenant? [y/N]"
    if ($answer -notmatch '^(y|yes)$') { Write-Warning 'Aborted.'; return }
}

# --- 3. Export job ----------------------------------------------------------------------------
Write-Step "Requesting export job for $report"
Write-Verbose ($body | ConvertTo-Json -Depth 5)
$job = Invoke-MgGraphRequest -Method POST -Uri "$GraphBase/deviceManagement/reports/exportJobs" -Body ($body | ConvertTo-Json -Depth 5) -ContentType 'application/json' -OutputType PSObject
$jobUri = "$GraphBase/deviceManagement/reports/exportJobs('$($job.id)')"

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
do {
    Start-Sleep -Seconds 5
    $job = Invoke-MgGraphRequest -Method GET -Uri $jobUri -OutputType PSObject
    Write-Host "  status: $($job.status)" -ForegroundColor DarkGray
    if ($job.status -eq 'failed') { throw "Export job failed: $($job.id)" }
} while ($job.status -ne 'completed' -and (Get-Date) -lt $deadline)
if ($job.status -ne 'completed') { throw "Export job did not complete within $TimeoutMinutes minutes (last status: $($job.status))." }

# --- 4. Download and convert ------------------------------------------------------------------
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$zipPath = Join-Path $OutputFolder "$name`_$stamp.zip"
$tmp     = Join-Path $OutputFolder "_extract_$stamp"

Write-Step 'Downloading'
# The url is a SAS link to Azure Storage: no Graph token is sent
Invoke-WebRequest -Uri $job.url -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
$extracted = Get-ChildItem -Path $tmp -File | Select-Object -First 1
if (-not $extracted) { throw "The ZIP from Intune contains no file ($zipPath)." }

$rawPath = Join-Path $OutputFolder "$name`_$stamp`_raw.csv"
$csvPath = Join-Path $OutputFolder "$name`_$stamp.csv"
Move-Item -Path $extracted.FullName -Destination $rawPath -Force
Remove-Item -Path $tmp -Recurse -Force
Remove-Item -Path $zipPath -Force

$rows = @(Import-Csv -Path $rawPath)
# UTF-8 with BOM so that Excel shows umlauts correctly (PS 5.1: UTF8 = with BOM; PS 7: utf8BOM)
$enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }
$rows | Export-Csv -Path $csvPath -Delimiter $Delimiter -NoTypeInformation -Encoding $enc

Write-Host ''
Write-Host "Rows   : $($rows.Count)" -ForegroundColor Green
Write-Host "Excel  : $csvPath" -ForegroundColor Green
Write-Host "Raw    : $rawPath" -ForegroundColor DarkGray

if ($PassThru) { $rows }
