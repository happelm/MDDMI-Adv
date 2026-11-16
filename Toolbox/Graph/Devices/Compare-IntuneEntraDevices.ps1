<#
.SYNOPSIS
    Compares the Intune device list with the Microsoft Entra device list and shows what doesn't match:
    devices only in Intune, managed devices only in Entra, stale objects, disabled devices and
    compliance that differs between the two.

.DESCRIPTION
    Intune and Entra ID keep separate device objects. The admin centers show two lists, but no view
    that joins them. This script joins them on the Entra device ID
    (Intune managedDevice.azureADDeviceId = Entra device.deviceId) and writes one CSV row per device.

    Status
      Matched         Device exists in Intune and in Entra ID.
      Intune only     Intune record without a matching Entra object (deleted in Entra, or the
                      platform keeps no Entra device). Conditional Access can't find a compliant
                      device object for it.
      Entra only, MDM Entra object that says it is MDM-managed, but Intune has no record (for example
                      deleted in Intune, or managed by another MDM).
      Entra only      Entra object without MDM (registered, joined or hybrid joined, not enrolled).

    Flags (column Flags, several possible)
      Stale             No Intune check-in and no Entra sign-in for more than -StaleDays days.
      Disabled in Entra Entra object is disabled, Intune still manages the device.
      Compliance differs Intune compliance state and Entra isCompliant don't agree (Intune reports
                        compliance to Entra; a difference is normal for a few minutes after a change).
      Name differs      Intune device name and Entra display name are different.

    Every request is GET. Nothing is changed in the tenant.

.PARAMETER StaleDays
    Days without Intune check-in and Entra sign-in after which a device counts as stale. Default 90.

.PARAMETER OutputFolder
    Folder for the CSV file. Default: C:\Temp

.EXAMPLE
    .\Compare-IntuneEntraDevices.ps1

.EXAMPLE
    .\Compare-IntuneEntraDevices.ps1 -StaleDays 30 -OutputFolder 'C:\Temp\Devices'

.NOTES
    Version : 1.0 (2026-11-16)
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scopes  : DeviceManagementManagedDevices.Read.All, Device.Read.All
    Graph   : v1.0 - deviceManagement/managedDevices, devices
    Entra replaces approximateLastSignInDateTime only when the stored value is more than 14 days old
    (+/- 5 days), so it is a staleness indicator, not "last seen today". Microsoft Learn: don't treat a
    value younger than 21 days as stale (Manage stale devices in Microsoft Entra ID).
#>
param(
    [int] $StaleDays = 90,
    [string] $OutputFolder = 'C:\Temp'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All', 'Device.Read.All' -NoWelcome
Write-Host "Connected to tenant $((Get-MgContext).TenantId) as $((Get-MgContext).Account)"

$graph = 'https://graph.microsoft.com/v1.0'
$empty = '00000000-0000-0000-0000-000000000000'

# GET with paging: follows @odata.nextLink until the last page
function Get-GraphAll ([string] $Uri) {
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType HashTable
        foreach ($item in $page.value) { $item }
        $Uri = $page.'@odata.nextLink'
    }
}

# Graph returns UTC time stamps; null or 0001-01-01 = never
function ConvertTo-Date ($Value) {
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if ($Value) { return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal) }
    return [datetime]::MinValue
}
function Format-Date ([datetime] $Value) {
    if ($Value.Year -gt 1) { return $Value.ToLocalTime().ToString('yyyy-MM-dd HH:mm') }
    return ''
}

# Entra trustType -> the join type as the Entra admin center shows it
$joinTypes = @{ AzureAd = 'Microsoft Entra joined'; ServerAd = 'Microsoft Entra hybrid joined'; Workplace = 'Microsoft Entra registered' }

# 1. Both lists
$intune = @(Get-GraphAll "$graph/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId,operatingSystem,osVersion,userPrincipalName,complianceState,lastSyncDateTime,managementAgent,managedDeviceOwnerType")
$entra  = @(Get-GraphAll "$graph/devices?`$select=id,deviceId,displayName,operatingSystem,trustType,accountEnabled,isManaged,isCompliant,managementType,approximateLastSignInDateTime")
Write-Host "Intune: $($intune.Count) devices, Entra ID: $($entra.Count) devices"

$entraById = @{}
foreach ($e in $entra) { if ($e.deviceId) { $entraById[[string]$e.deviceId] = $e } }
$seen = @{}
$cutoff = (Get-Date).ToUniversalTime().AddDays(-$StaleDays)

function New-Row ($I, $E, [string] $Status) {
    $sync   = [datetime]::MinValue
    $signIn = [datetime]::MinValue
    if ($I) { $sync = ConvertTo-Date $I.lastSyncDateTime }
    if ($E) { $signIn = ConvertTo-Date $E.approximateLastSignInDateTime }
    $flags = @()
    $latest = $sync
    if ($signIn -gt $latest) { $latest = $signIn }
    if ($latest -lt $cutoff) { $flags += 'Stale' }
    if ($I -and $E) {
        if ($E.accountEnabled -eq $false) { $flags += 'Disabled in Entra' }
        $intuneCompliant = ($I.complianceState -eq 'compliant')
        if ($null -ne $E.isCompliant -and [bool]$E.isCompliant -ne $intuneCompliant) { $flags += 'Compliance differs' }
        if ([string]$I.deviceName -ne [string]$E.displayName) { $flags += 'Name differs' }
    }
    $join = ''
    if ($E -and $E.trustType) { $join = $joinTypes[[string]$E.trustType]; if (-not $join) { $join = [string]$E.trustType } }
    $os = ''
    if ($I) { $os = "$($I.operatingSystem) $($I.osVersion)" } elseif ($E) { $os = [string]$E.operatingSystem }
    [pscustomobject][ordered]@{
        'Status'             = $Status
        'Flags'              = ($flags -join ', ')
        'Intune name'        = $(if ($I) { [string]$I.deviceName } else { '' })
        'Entra name'         = $(if ($E) { [string]$E.displayName } else { '' })
        'OS'                 = $os.Trim()
        'Join type'          = $join
        'Primary user'       = $(if ($I) { [string]$I.userPrincipalName } else { '' })
        'Intune last check-in' = Format-Date $sync
        'Entra last sign-in' = Format-Date $signIn
        'Intune compliance'  = $(if ($I) { [string]$I.complianceState } else { '' })
        'Entra isCompliant'  = $(if ($E -and $null -ne $E.isCompliant) { [string]$E.isCompliant } else { '' })
        'Entra enabled'      = $(if ($E) { [string]$E.accountEnabled } else { '' })
        'Management agent'   = $(if ($I) { [string]$I.managementAgent } else { [string]$E.managementType })
        'Intune device ID'   = $(if ($I) { [string]$I.id } else { '' })
        'Entra device ID'    = $(if ($E) { [string]$E.deviceId } else { [string]$I.azureADDeviceId })
    }
}

# 2. Join on the Entra device ID
$rows = New-Object System.Collections.Generic.List[object]
foreach ($i in $intune) {
    $key = [string]$i.azureADDeviceId
    $e = $null
    if ($key -and $key -ne $empty) { $e = $entraById[$key] }
    if ($e) { $seen[$key] = $true; $rows.Add((New-Row $i $e 'Matched')) }
    else    { $rows.Add((New-Row $i $null 'Intune only')) }
}
foreach ($e in $entra) {
    if ($seen.ContainsKey([string]$e.deviceId)) { continue }
    $status = 'Entra only'
    if ($e.isManaged -eq $true) { $status = 'Entra only, MDM' }
    $rows.Add((New-Row $null $e $status))
}

# 3. Summary and CSV
$order = @{ 'Intune only' = 1; 'Entra only, MDM' = 2; 'Matched' = 3; 'Entra only' = 4 }
$sorted = @($rows | Sort-Object { $order[$_.Status] }, { $_.'Flags' -eq '' }, { $_.'Intune name' + $_.'Entra name' })

Write-Host ''
$rows | Group-Object Status | Sort-Object { $order[$_.Name] } |
    ForEach-Object { [pscustomobject]@{ Status = $_.Name; Devices = $_.Count } } | Format-Table -AutoSize | Out-Host
foreach ($f in 'Stale', 'Disabled in Entra', 'Compliance differs', 'Name differs') {
    $n = @($rows | Where-Object { ($_.'Flags' -split ', ') -contains $f }).Count
    Write-Host ("{0,-20} {1}" -f $f, $n)
}

New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$csvFile = Join-Path $OutputFolder 'IntuneEntraDeviceComparison.csv'
$sorted | Export-Csv -Path $csvFile -Delimiter ';' -Encoding UTF8 -NoTypeInformation
Write-Host ''
Write-Host "Written: $csvFile"
