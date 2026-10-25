<#
.SYNOPSIS
    Bulk rename Intune objects (policies, profiles, scripts, apps) by prefix or regular expression,
    with preview, CSV log and undo.

.DESCRIPTION
    Renaming many Intune objects in the portal means opening every object. This script reads the
    selected object types from Microsoft Graph (beta), computes the new names, shows them, and
    renames after confirmation. Every rename is written to a CSV log; -UndoCsv reverts a run.

    Modes:
      Prefix : -OldPrefix '[Pilot] ' -NewPrefix '[Prod] '   (literal, objects that do not start with
               -OldPrefix are skipped). -NewPrefix '' removes the prefix.
      Regex  : -Find '^Win10 - ' -Replace 'WIN - '         (.NET regex, -Replace may use $1 etc.).
               Objects whose name does not match are skipped.
      Undo   : -UndoCsv .\Rename-IntunePolicies-<timestamp>.csv   (renames back every row with Result = Renamed)

    Object types (-ObjectType, default All):
      ConfigurationPolicies   deviceManagement/configurationPolicies (settings catalog, endpoint security, baselines)
      CompliancePolicies      deviceManagement/compliancePolicies (settings catalog compliance, e.g. Linux)
      DeviceConfigurations    deviceManagement/deviceConfigurations (templates)
      DeviceCompliance        deviceManagement/deviceCompliancePolicies
      AdministrativeTemplates deviceManagement/groupPolicyConfigurations
      PlatformScripts         deviceManagement/deviceManagementScripts (Windows)
      Remediations            deviceManagement/deviceHealthScripts
      ShellScripts            deviceManagement/deviceShellScripts (macOS)
      CustomAttributes        deviceManagement/deviceCustomAttributeShellScripts (macOS)
      Apps                    deviceAppManagement/mobileApps

.PARAMETER OldPrefix
    Literal prefix to replace. Case-insensitive unless -CaseSensitive is set.

.PARAMETER NewPrefix
    Replacement for -OldPrefix. Empty string removes the prefix.

.PARAMETER Find
    Regular expression matched against the current name.

.PARAMETER Replace
    Replacement string for -Find (.NET regex replacement syntax).

.PARAMETER UndoCsv
    CSV log of an earlier run. Renames every row with Result = Renamed back to OldName.

.PARAMETER ObjectType
    One or more object types (see description), or All (default).

.PARAMETER CaseSensitive
    Match -OldPrefix / -Find case-sensitively.

.PARAMETER LogFolder
    Folder for the CSV log. Default: current folder.

.PARAMETER Force
    Rename without the y/N question after the preview. -WhatIf still only previews.

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER SkipTenantConfirmation
    Do not ask to confirm the connected tenant.

.EXAMPLE
    .\Rename-IntunePolicies.ps1 -OldPrefix '[intune-my-macs]' -NewPrefix '{intune-my-macs}' -WhatIf
    Preview only: lists what would be renamed, changes nothing.

.EXAMPLE
    .\Rename-IntunePolicies.ps1 -Find '^Win10 - (.+)$' -Replace 'WIN - $1' -ObjectType DeviceConfigurations,ConfigurationPolicies

.EXAMPLE
    .\Rename-IntunePolicies.ps1 -OldPrefix 'etc1-' -NewPrefix '' -ObjectType PlatformScripts,Remediations

.EXAMPLE
    .\Rename-IntunePolicies.ps1 -UndoCsv .\Rename-IntunePolicies-20261025-091500.csv

.NOTES
    Version : 1.0 (2026-10-25)
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scopes  : only those of the selected types: DeviceManagementConfiguration.ReadWrite.All,
              DeviceManagementScripts.ReadWrite.All, DeviceManagementApps.ReadWrite.All
    Intune RBAC still applies: objects outside the admin's scope tags are not returned and cannot be renamed.
    The read (GET) part was checked against a tenant; the rename (PATCH) bodies follow Graph beta and must be
    tested in a lab tenant first. Run with -WhatIf first.
#>

[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Prefix')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Prefix')]
    [ValidateNotNullOrEmpty()]
    [string]$OldPrefix,

    [Parameter(Mandatory = $true, ParameterSetName = 'Prefix')]
    [AllowEmptyString()]
    [string]$NewPrefix,

    [Parameter(Mandatory = $true, ParameterSetName = 'Regex')]
    [ValidateNotNullOrEmpty()]
    [string]$Find,

    [Parameter(Mandatory = $true, ParameterSetName = 'Regex')]
    [AllowEmptyString()]
    [string]$Replace,

    [Parameter(Mandatory = $true, ParameterSetName = 'Undo')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$UndoCsv,

    [Parameter(ParameterSetName = 'Prefix')]
    [Parameter(ParameterSetName = 'Regex')]
    [ValidateSet('All', 'ConfigurationPolicies', 'CompliancePolicies', 'DeviceConfigurations', 'DeviceCompliance',
                 'AdministrativeTemplates', 'PlatformScripts', 'Remediations', 'ShellScripts', 'CustomAttributes', 'Apps')]
    [string[]]$ObjectType = 'All',

    [Parameter(ParameterSetName = 'Prefix')]
    [Parameter(ParameterSetName = 'Regex')]
    [switch]$CaseSensitive,

    [string]$LogFolder = (Get-Location).Path,
    [switch]$Force,
    [string]$TenantId,
    [switch]$SkipTenantConfirmation
)

$ErrorActionPreference = 'Stop'
$GraphBase = 'https://graph.microsoft.com/beta'
$Mode = $PSCmdlet.ParameterSetName

# Name = property that holds the display name; ODataType = PATCH must carry @odata.type (derived types)
$TypeTable = [ordered]@{
    ConfigurationPolicies   = @{ Path = '/deviceManagement/configurationPolicies';             Name = 'name';        ODataType = $false; Scope = 'DeviceManagementConfiguration.ReadWrite.All' }
    CompliancePolicies      = @{ Path = '/deviceManagement/compliancePolicies';                Name = 'name';        ODataType = $false; Scope = 'DeviceManagementConfiguration.ReadWrite.All' }
    DeviceConfigurations    = @{ Path = '/deviceManagement/deviceConfigurations';              Name = 'displayName'; ODataType = $true;  Scope = 'DeviceManagementConfiguration.ReadWrite.All' }
    DeviceCompliance        = @{ Path = '/deviceManagement/deviceCompliancePolicies';          Name = 'displayName'; ODataType = $true;  Scope = 'DeviceManagementConfiguration.ReadWrite.All' }
    AdministrativeTemplates = @{ Path = '/deviceManagement/groupPolicyConfigurations';         Name = 'displayName'; ODataType = $false; Scope = 'DeviceManagementConfiguration.ReadWrite.All' }
    PlatformScripts         = @{ Path = '/deviceManagement/deviceManagementScripts';           Name = 'displayName'; ODataType = $false; Scope = 'DeviceManagementScripts.ReadWrite.All' }
    Remediations            = @{ Path = '/deviceManagement/deviceHealthScripts';               Name = 'displayName'; ODataType = $false; Scope = 'DeviceManagementScripts.ReadWrite.All' }
    ShellScripts            = @{ Path = '/deviceManagement/deviceShellScripts';                Name = 'displayName'; ODataType = $false; Scope = 'DeviceManagementScripts.ReadWrite.All' }
    CustomAttributes        = @{ Path = '/deviceManagement/deviceCustomAttributeShellScripts'; Name = 'displayName'; ODataType = $false; Scope = 'DeviceManagementScripts.ReadWrite.All' }
    Apps                    = @{ Path = '/deviceAppManagement/mobileApps';                     Name = 'displayName'; ODataType = $true;  Scope = 'DeviceManagementApps.ReadWrite.All' }
}

function Get-GraphCollection {
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    while ($Uri) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        foreach ($v in $resp.value) { $items.Add($v) }
        $Uri = $resp.'@odata.nextLink'
    }
    return $items
}

function Get-NewName {
    param([string]$Name)
    $cmp = if ($CaseSensitive) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
    if ($Mode -eq 'Prefix') {
        if (-not $Name.StartsWith($OldPrefix, $cmp)) { return $null }
        return $NewPrefix + $Name.Substring($OldPrefix.Length)
    }
    $opts = if ($CaseSensitive) { [Text.RegularExpressions.RegexOptions]::None } else { [Text.RegularExpressions.RegexOptions]::IgnoreCase }
    if (-not [regex]::IsMatch($Name, $Find, $opts)) { return $null }
    return [regex]::Replace($Name, $Find, $Replace, $opts)
}

function Invoke-Rename {
    param($Item, [string]$TargetName)
    $t = $TypeTable[$Item.Type]
    $body = @{ $t.Name = $TargetName }
    if ($t.ODataType) {
        if (-not $Item.ODataType) { throw 'Missing @odata.type for a derived type.' }
        $body['@odata.type'] = $Item.ODataType
    }
    Invoke-MgGraphRequest -Method PATCH -Uri "$GraphBase$($t.Path)/$($Item.Id)" -Body ($body | ConvertTo-Json -Compress) -ContentType 'application/json' | Out-Null
}

# --- 1. Work list -------------------------------------------------------------------------
if ($Mode -eq 'Undo') {
    $undoRows = @(Import-Csv -LiteralPath $UndoCsv -Delimiter ';' | Where-Object { $_.Result -eq 'Renamed' })
    if ($undoRows.Count -eq 0) { Write-Host 'No rows with Result = Renamed in the CSV. Nothing to undo.'; return }
    $types = @($undoRows.Type | Sort-Object -Unique)
}
else {
    $types = if ($ObjectType -contains 'All') { @($TypeTable.Keys) } else { $ObjectType }
}

# --- 2. Sign-in ---------------------------------------------------------------------------
Import-Module Microsoft.Graph.Authentication
$scopes = @($types | ForEach-Object { $TypeTable[$_].Scope } | Sort-Object -Unique)
$connect = @{ Scopes = $scopes; NoWelcome = $true }
if ($TenantId) { $connect.TenantId = $TenantId }
Connect-MgGraph @connect
$ctx = Get-MgContext
if (-not $SkipTenantConfirmation) {
    Write-Host ("Tenant : {0}" -f $ctx.TenantId)
    Write-Host ("Account: {0}" -f $ctx.Account)
    $answer = Read-Host 'Is this the right tenant? (y/N)'
    if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; return }
}

# --- 3. Collect candidates ------------------------------------------------------------------
$plan = New-Object System.Collections.Generic.List[object]

if ($Mode -eq 'Undo') {
    foreach ($r in $undoRows) {
        $plan.Add([PSCustomObject]@{ Type = $r.Type; Id = $r.Id; ODataType = $r.ODataType; OldName = $r.NewName; NewName = $r.OldName })
    }
}
else {
    foreach ($type in $types) {
        $t = $TypeTable[$type]
        Write-Host "Reading $type ..." -ForegroundColor Gray
        try {
            $items = Get-GraphCollection -Uri "$GraphBase$($t.Path)?`$select=id,$($t.Name)"
        }
        catch {
            Write-Warning "$type could not be read: $($_.Exception.Message)"
            continue
        }
        foreach ($i in $items) {
            $name = [string]$i.($t.Name)
            if (-not $name) { continue }
            $new = Get-NewName -Name $name
            if ($null -eq $new -or $new -ceq $name) { continue }
            $plan.Add([PSCustomObject]@{ Type = $type; Id = $i.id; ODataType = $i.'@odata.type'; OldName = $name; NewName = $new })
        }
    }
}

if ($plan.Count -eq 0) { Write-Host 'No objects to rename.' -ForegroundColor Yellow; return }

Write-Host ''
$plan | Format-Table Type, OldName, NewName -AutoSize | Out-Host

$empty = @($plan | Where-Object { [string]::IsNullOrWhiteSpace($_.NewName) })
if ($empty.Count -gt 0) { throw "$($empty.Count) new name(s) would be empty. Change -NewPrefix / -Replace." }
$dupes = @($plan | Group-Object Type, NewName | Where-Object Count -gt 1)
foreach ($d in $dupes) { Write-Warning "Several objects would get the same name: $($d.Name)" }

if ($WhatIfPreference) { Write-Host "WhatIf: $($plan.Count) object(s) would be renamed. Nothing changed."; return }
if (-not $Force) {
    $answer = Read-Host "Rename $($plan.Count) object(s)? (y/N)"
    if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; return }
}

# --- 4. Rename and log ----------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
$prefix = if ($Mode -eq 'Undo') { 'Rename-IntunePolicies-Undo' } else { 'Rename-IntunePolicies' }
$logFile = Join-Path $LogFolder ("{0}-{1}.csv" -f $prefix, (Get-Date -Format 'yyyyMMdd-HHmmss'))
$log = New-Object System.Collections.Generic.List[object]

foreach ($p in $plan) {
    $row = [PSCustomObject]@{ Type = $p.Type; Id = $p.Id; ODataType = $p.ODataType; OldName = $p.OldName; NewName = $p.NewName; Result = ''; Error = '' }
    try {
        Invoke-Rename -Item $p -TargetName $p.NewName
        $row.Result = 'Renamed'
        Write-Host "  OK    $($p.OldName) -> $($p.NewName)" -ForegroundColor Green
    }
    catch {
        $row.Result = 'Failed'
        $row.Error = $_.Exception.Message
        Write-Host "  FAIL  $($p.OldName): $($_.Exception.Message)" -ForegroundColor Red
    }
    $log.Add($row)
}

$log | Export-Csv -LiteralPath $logFile -Delimiter ';' -NoTypeInformation -Encoding UTF8
$ok = @($log | Where-Object Result -eq 'Renamed').Count
Write-Host ''
Write-Host "Renamed: $ok   Failed: $($log.Count - $ok)"
Write-Host "Log: $logFile"
if ($Mode -ne 'Undo' -and $ok -gt 0) { Write-Host "Undo: .\Rename-IntunePolicies.ps1 -UndoCsv `"$logFile`"" }
