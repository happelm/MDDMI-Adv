<#
.SYNOPSIS
    Creates or updates the service connection point (SCP) for Microsoft Entra hybrid join in the
    current Active Directory forest, for example when devices are synced with Microsoft Entra Cloud Sync.

.DESCRIPTION
    Microsoft Entra Connect Sync writes the SCP in its wizard. Microsoft Entra Cloud Sync does not,
    so the SCP has to be created separately before device sync can produce hybrid joined devices.

    The SCP is the object
      CN=62a0ff2e-97b9-4513-943f-0d221bd30080,CN=Device Registration Configuration,CN=Services,<configuration naming context>
    with two keywords values: azureADName:<verified domain> and azureADId:<tenant ID>.

    This script is based on ConfigureSCP.ps1 from Microsoft Learn and adds:
      - Read before write: shows the current keywords and stops if nothing needs to change.
      - Protection: an SCP that points to a different tenant is only overwritten with -Force.
      - -WhatIf / -Confirm support.
      - Optional lookup of tenant ID and domain from Microsoft Graph when -TenantId or -Domain is omitted
        (sign-in with User.Read). Rule from Learn: a federated domain for federated environments,
        otherwise the initial *.onmicrosoft.com domain.

    Run it once per forest that contains domain-joined computers, as a member of Enterprise Admins of that forest.

.PARAMETER Domain
    Verified domain used for device authentication. Federated environments: a federated domain.
    Otherwise: the initial *.onmicrosoft.com domain. If omitted, it is read from Microsoft Graph.

.PARAMETER TenantId
    Microsoft Entra tenant ID (GUID). If omitted, it is read from Microsoft Graph.

.PARAMETER Force
    Overwrite an SCP that currently points to a different tenant.

.PARAMETER SkipTenantConfirmation
    Do not ask to confirm the tenant read from Microsoft Graph.

.EXAMPLE
    .\Set-HybridJoinSCP.ps1 -WhatIf
    Signs in to Microsoft Graph, reads tenant ID and domain, shows the current SCP and what would change.

.EXAMPLE
    .\Set-HybridJoinSCP.ps1
    Same as above, then creates or updates the SCP after confirmation.

.EXAMPLE
    .\Set-HybridJoinSCP.ps1 -Domain contoso.onmicrosoft.com -TenantId 00000000-0000-0000-0000-000000000000
    No Graph sign-in. Uses the given values.

.NOTES
    Version : 1.0 (2026-10-25)
    Requires: Windows PowerShell 5.1 or PowerShell 7 on a domain-joined Windows machine (System.DirectoryServices).
              Enterprise Admins of the current forest.
              Microsoft.Graph.Authentication only when -Domain or -TenantId is omitted (scope User.Read).
    Sources : https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/device-sync#configure-a-service-connection-point
              https://learn.microsoft.com/entra/identity/devices/hybrid-join-manual#configure-a-service-connection-point
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Domain,
    [guid]$TenantId,
    [switch]$Force,
    [switch]$SkipTenantConfirmation
)

$ErrorActionPreference = 'Stop'
$ScpName = '62a0ff2e-97b9-4513-943f-0d221bd30080'
$Ldap    = 'LDAP://'

# --- 1. Tenant ID and domain --------------------------------------------------------------
if (-not $Domain -or -not $TenantId) {
    Write-Host 'Tenant ID or domain not given: reading them from Microsoft Graph.' -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Module Microsoft.Graph.Authentication not found. Install it (Install-Module Microsoft.Graph.Authentication -Scope CurrentUser) or pass -Domain and -TenantId.'
    }
    Import-Module Microsoft.Graph.Authentication
    Connect-MgGraph -Scopes 'User.Read' -NoWelcome
    $ctx = Get-MgContext

    $org = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName,verifiedDomains').value | Select-Object -First 1
    if (-not $org) { throw 'GET /organization returned nothing.' }

    if (-not $SkipTenantConfirmation) {
        Write-Host ("Tenant : {0} ({1})" -f $org.displayName, $org.id)
        Write-Host ("Account: {0}" -f $ctx.Account)
        $answer = Read-Host 'Is this the right tenant? (y/N)'
        if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; return }
    }

    if (-not $TenantId) { $TenantId = [guid]$org.id }
    elseif ($TenantId -ne [guid]$org.id) {
        throw "-TenantId $TenantId does not match the signed-in tenant $($org.id)."
    }

    $federated = @($org.verifiedDomains | Where-Object { $_.type -eq 'Federated' })
    $initial   = $org.verifiedDomains | Where-Object { $_.isInitial } | Select-Object -First 1

    if ($Domain) {
        $match = $org.verifiedDomains | Where-Object { $_.name -eq $Domain.Trim() }
        if (-not $match) { throw "$Domain is not a verified domain of tenant $($org.id)." }
        if ($federated.Count -gt 0 -and $match.type -ne 'Federated') {
            Write-Warning "The tenant has federated domains ($($federated.name -join ', ')), but $Domain is managed. Learn: use a federated domain for federated environments."
        }
    }
    elseif ($federated.Count -eq 1) {
        $Domain = $federated[0].name
        Write-Host "Federated domain found, using it: $Domain"
    }
    elseif ($federated.Count -gt 1) {
        throw "Several federated domains found ($($federated.name -join ', ')). Pick one with -Domain."
    }
    else {
        $Domain = $initial.name
        Write-Host "No federated domain, using the initial domain: $Domain"
    }
}

$Domain = $Domain.Trim()
$targetKeywords = @("azureADName:$Domain", "azureADId:$($TenantId.ToString())")

# --- 2. Read the current SCP ---------------------------------------------------------------
$rootDse    = New-Object System.DirectoryServices.DirectoryEntry($Ldap + 'RootDSE')
$configNC   = $rootDse.Properties['configurationNamingContext'][0].ToString()
$servicesDN = "CN=Services,$configNC"
$drcDN      = "CN=Device Registration Configuration,$servicesDN"
$scpDN      = "CN=$ScpName,$drcDN"

$drcExists = [System.DirectoryServices.DirectoryEntry]::Exists($Ldap + $drcDN)
$scpExists = $drcExists -and [System.DirectoryServices.DirectoryEntry]::Exists($Ldap + $scpDN)

Write-Host ''
Write-Host "Forest configuration NC: $configNC"
Write-Host "SCP: $scpDN"

$current = @()
if ($scpExists) {
    $deScp   = New-Object System.DirectoryServices.DirectoryEntry($Ldap + $scpDN)
    $current = @($deScp.Properties['keywords'] | ForEach-Object { [string]$_ })
    Write-Host 'Current keywords:'
    if ($current.Count -eq 0) { Write-Host '  (none)' } else { $current | ForEach-Object { Write-Host "  $_" } }
}
else {
    Write-Host 'Current keywords: SCP does not exist.'
}
Write-Host 'Target keywords:'
$targetKeywords | ForEach-Object { Write-Host "  $_" }

# Compare case-insensitively, order does not matter
$currentSet = @($current | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object)
$targetSet  = @($targetKeywords | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object)
if ($scpExists -and $currentSet.Count -gt 0 -and -not (Compare-Object $currentSet $targetSet)) {
    Write-Host ''
    Write-Host 'The SCP already has the target values. Nothing to do.' -ForegroundColor Green
    return
}

$currentId = $current | Where-Object { $_ -match '^azureADId:' } | ForEach-Object { ($_ -split ':', 2)[1].Trim() }
if ($currentId -and ($currentId -ne $TenantId.ToString()) -and -not $Force) {
    Write-Host ''
    Write-Warning "The SCP points to a different tenant ($currentId). Devices in this forest would register there. Record the values above and run again with -Force to overwrite."
    return
}

# --- 3. Write -----------------------------------------------------------------------------
$action = if ($scpExists) { 'Replace keywords of the existing SCP' } else { 'Create the SCP' }
if (-not $PSCmdlet.ShouldProcess($scpDN, $action)) { return }

try {
    if ($drcExists) {
        $deDrc = New-Object System.DirectoryServices.DirectoryEntry($Ldap + $drcDN)
    }
    else {
        $deServices = New-Object System.DirectoryServices.DirectoryEntry($Ldap + $servicesDN)
        $deDrc = $deServices.Children.Add('CN=Device Registration Configuration', 'container')
        $deDrc.CommitChanges()
        Write-Host 'Created container: Device Registration Configuration'
    }

    if ($scpExists) {
        $deScp = New-Object System.DirectoryServices.DirectoryEntry($Ldap + $scpDN)
        $deScp.Properties['keywords'].Clear()
    }
    else {
        $deScp = $deDrc.Children.Add("CN=$ScpName", 'serviceConnectionPoint')
    }

    foreach ($k in $targetKeywords) { [void]$deScp.Properties['keywords'].Add($k) }
    $deScp.CommitChanges()

    # Read back
    $check = New-Object System.DirectoryServices.DirectoryEntry($Ldap + $scpDN)
    Write-Host ''
    Write-Host 'Done. Keywords now:' -ForegroundColor Green
    $check.Properties['keywords'] | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
    Write-Host 'Next: enable device sync in the Cloud Sync configuration (Entra admin center > Entra ID > Entra Connect > Cloud sync > Properties > Basics).'
}
catch [System.UnauthorizedAccessException] {
    throw "Access denied. Run as a member of Enterprise Admins of this forest. $($_.Exception.Message)"
}
catch {
    if ($_.Exception.HResult -eq -2147024891) {
        throw "Access denied. Run as a member of Enterprise Admins of this forest. $($_.Exception.Message)"
    }
    throw
}
