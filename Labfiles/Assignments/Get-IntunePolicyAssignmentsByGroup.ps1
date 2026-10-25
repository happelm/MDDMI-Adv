<#
.SYNOPSIS
    Reverse lookup: list every Intune object that is assigned to a given Entra ID group.

.DESCRIPTION
    Intune shows assignments per object, not per group. This script builds the inverse view:
    for one group it lists every Intune object that includes or excludes the group, directly,
    through a parent group (nested membership) or through a policy set. Optionally it also lists
    objects assigned to the virtual targets "All users" / "All devices".

    Covered object types (Microsoft Graph beta, read-only):
      Configuration : device configuration profiles (incl. Windows update rings, iOS/macOS update
                      profiles), settings catalog + endpoint security + baselines + EPM + Autopilot
                      device preparation (configurationPolicies), administrative templates
                      (groupPolicyConfigurations), legacy endpoint security intents, BIOS configurations
      Compliance    : compliance policies, settings catalog compliance policies (e.g. Linux)
      Scripts       : Windows platform scripts, Remediations, macOS shell scripts, macOS custom attributes
      Updates       : Windows feature, quality (expedite), quality update policies (hotpatch), driver updates
      Apps          : app assignments (intent + settings type), app configuration (managed devices and
                      managed apps), app protection (iOS, Android, Windows), policy sets
      Enrollment    : enrollment configurations (ESP, platform restrictions, device limit, WHfB,
                      Windows Backup and Restore, co-management settings), Autopilot deployment
                      profiles, Apple user-initiated enrollment profiles, terms and conditions,
                      Company Portal branding profiles
      RBAC          : Intune role assignments (group as admin members or as scope group),
                      scope tag auto-assignment to groups

    Every request is GET. Nothing is changed in the tenant.

.PARAMETER GroupName
    Display name of the Entra ID group. Fails if the name is not unique; use -GroupId then.

.PARAMETER GroupId
    Object ID of the Entra ID group.

.PARAMETER Category
    One or more of: Configuration, Compliance, Scripts, Updates, Apps, Enrollment, RBAC, All (default).

.PARAMETER DirectOnly
    Skip parent groups. By default assignments to groups that contain this group (transitively) are listed too.

.PARAMETER IncludeAllUsersAllDevices
    Also list objects assigned to "All users" / "All devices". Only targets that can apply to the group's
    member types are shown (user members -> All users, device members -> All devices).

.PARAMETER ExportCsv
    Export the result to CSV (delimiter ';', UTF-8) in -OutputFolder.

.PARAMETER OutputFolder
    Folder for the CSV export. Default: current folder.

.PARAMETER SkipTenantConfirmation
    Do not ask to confirm the connected tenant.

.PARAMETER PassThru
    Return the result objects to the pipeline.

.EXAMPLE
    .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName "student1devices"

.EXAMPLE
    .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName "student1users" -Category Apps,Compliance -IncludeAllUsersAllDevices -ExportCsv

.EXAMPLE
    $r = .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupId 00000000-0000-0000-0000-000000000000 -PassThru -SkipTenantConfirmation

.NOTES
    Version : 2.0 (2026-10-19)
    Requires: Microsoft.Graph.Authentication 2.x (Invoke-MgGraphRequest with -SkipHttpErrorCheck)
              Windows PowerShell 5.1 or PowerShell 7
    Scopes  : DeviceManagementConfiguration.Read.All, DeviceManagementApps.Read.All,
              DeviceManagementScripts.Read.All, DeviceManagementServiceConfig.Read.All,
              DeviceManagementRBAC.Read.All, GroupMember.Read.All
    Intune RBAC still applies: objects outside the admin's scope tags are not returned by Graph.
    Most Intune endpoints used here exist only in Graph beta.
#>

[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
    [string]$GroupName,

    [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$GroupId,

    [ValidateSet('All', 'Configuration', 'Compliance', 'Scripts', 'Updates', 'Apps', 'Enrollment', 'RBAC')]
    [string[]]$Category = @('All'),

    [switch]$DirectOnly,

    [Alias('IncludeAllDevicesPolicies')]
    [switch]$IncludeAllUsersAllDevices,

    [switch]$ExportCsv,

    [string]$OutputFolder = (Get-Location).Path,

    [switch]$SkipTenantConfirmation,

    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$GraphBeta = 'https://graph.microsoft.com/beta'
$GraphV1 = 'https://graph.microsoft.com/v1.0'

$RequiredScopes = @(
    'DeviceManagementConfiguration.Read.All',
    'DeviceManagementApps.Read.All',
    'DeviceManagementScripts.Read.All',
    'DeviceManagementServiceConfig.Read.All',
    'DeviceManagementRBAC.Read.All',
    'GroupMember.Read.All'
)

#region Module and connection
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host 'Installing Microsoft.Graph.Authentication (CurrentUser)...' -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Authentication

$cmd = Get-Command Invoke-MgGraphRequest
if (-not $cmd.Parameters.ContainsKey('SkipHttpErrorCheck') -or -not $cmd.Parameters.ContainsKey('StatusCodeVariable')) {
    throw 'Invoke-MgGraphRequest is too old (no -SkipHttpErrorCheck / -StatusCodeVariable). Run: Update-Module Microsoft.Graph.Authentication'
}

$context = Get-MgContext
$missingScopes = @()
if ($context) { $missingScopes = @($RequiredScopes | Where-Object { $context.Scopes -notcontains $_ }) }
if (-not $context -or $missingScopes.Count -gt 0) {
    if ($context) { Write-Host "Reconnecting, missing scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow }
    Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
    $context = Get-MgContext
}
Write-Host "Connected as $($context.Account) to tenant $($context.TenantId)" -ForegroundColor Green
if (-not $SkipTenantConfirmation) {
    $answer = Read-Host 'Is this the right tenant? [y/N]'
    if ($answer -notmatch '^(y|yes|j|ja)$') { Write-Host 'Aborted.' -ForegroundColor Yellow; return }
}
#endregion

#region Graph helpers
function Invoke-Graph {
    # GET/POST with status code handling and retry on 429/503/504.
    # The Graph SDK already retries throttled requests; this loop catches what is left after its retries.
    param(
        [string]$Uri,
        [string]$Method = 'GET',
        [string]$Body,
        [int]$MaxRetries = 4
    )
    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        $sc = $null; $rh = $null
        $p = @{
            Method                  = $Method
            Uri                     = $Uri
            OutputType              = 'HashTable'
            SkipHttpErrorCheck      = $true
            StatusCodeVariable      = 'sc'
            ResponseHeadersVariable = 'rh'
        }
        if ($Body) { $p.Body = $Body; $p.ContentType = 'application/json' }
        $resp = Invoke-MgGraphRequest @p
        $status = [int]$sc
        if (($status -in @(429, 503, 504)) -and ($attempt -lt $MaxRetries)) {
            $wait = [math]::Pow(2, $attempt + 1) * 5
            if ($rh -and $rh['Retry-After']) {
                $ra = @($rh['Retry-After'])[0]
                $sec = 0
                if ([int]::TryParse("$ra", [ref]$sec)) { $wait = $sec }
            }
            Write-Host "    HTTP $status - waiting $wait s (retry $($attempt + 1)/$MaxRetries)" -ForegroundColor DarkYellow
            Start-Sleep -Seconds $wait
            continue
        }
        $msg = $null
        if ($status -ge 400 -and $resp -and $resp.error) { $msg = $resp.error.message }
        return @{ Status = $status; Body = $resp; Message = $msg }
    }
}

function Get-GraphCollection {
    # Follows @odata.nextLink. Returns Status, Items, Message.
    param([string]$Uri)
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        $r = Invoke-Graph -Uri $next
        if ($r.Status -ne 200) { return @{ Status = $r.Status; Items = $items; Message = $r.Message } }
        foreach ($v in @($r.Body.value)) { if ($null -ne $v) { $items.Add($v) } }
        $next = $r.Body.'@odata.nextLink'
    }
    return @{ Status = 200; Items = $items; Message = $null }
}

function Invoke-GraphBatchGet {
    # GET many relative URLs via JSON batching (20 per batch). Throttled sub-requests are retried here,
    # because SDK retry handlers do not retry requests inside a batch.
    # Returns hashtable: url -> @{ Status; Body }
    param([string[]]$RelativeUrls, [string]$BaseUri = $GraphBeta)
    $results = @{}
    $pending = New-Object System.Collections.Generic.List[string]
    foreach ($u in $RelativeUrls) { $pending.Add($u) }
    $round = 0
    while ($pending.Count -gt 0 -and $round -lt 5) {
        $round++
        $retry = New-Object System.Collections.Generic.List[string]
        $maxWait = 0
        $pendingArr = $pending.ToArray()
        for ($i = 0; $i -lt $pendingArr.Count; $i += 20) {
            $chunk = @($pendingArr[$i..([math]::Min($i + 19, $pendingArr.Count - 1))])
            $requests = @()
            for ($j = 0; $j -lt $chunk.Count; $j++) { $requests += @{ id = "$j"; method = 'GET'; url = $chunk[$j] } }
            $body = @{ requests = $requests } | ConvertTo-Json -Depth 5
            $r = Invoke-Graph -Uri "$BaseUri/`$batch" -Method POST -Body $body
            if ($r.Status -ne 200) {
                foreach ($u in $chunk) { $results[$u] = @{ Status = $r.Status; Body = $null } }
                continue
            }
            foreach ($sub in @($r.Body.responses)) {
                $url = $chunk[[int]$sub.id]
                if ([int]$sub.status -eq 429) {
                    $retry.Add($url)
                    $ra = 10
                    if ($sub.headers -and $sub.headers['Retry-After']) { [void][int]::TryParse("$($sub.headers['Retry-After'])", [ref]$ra) }
                    if ($ra -gt $maxWait) { $maxWait = $ra }
                }
                else {
                    $results[$url] = @{ Status = [int]$sub.status; Body = $sub.body }
                }
            }
        }
        $pending = $retry
        if ($pending.Count -gt 0) {
            Write-Host "    Batch: $($pending.Count) throttled sub-requests, waiting $maxWait s" -ForegroundColor DarkYellow
            Start-Sleep -Seconds $maxWait
        }
    }
    foreach ($u in $pending) { $results[$u] = @{ Status = 429; Body = $null } }
    return $results
}

function Get-ShortType([string]$ODataType) {
    if (-not $ODataType) { return $null }
    return ($ODataType -replace '^#microsoft\.graph\.', '')
}
#endregion

#region Group
Write-Host "`nResolving group..." -ForegroundColor Cyan
$groupSelect = 'id,displayName,description,membershipRule,groupTypes,securityEnabled'
if ($PSCmdlet.ParameterSetName -eq 'ById') {
    $r = Invoke-Graph -Uri "$GraphV1/groups/$GroupId`?`$select=$groupSelect"
    if ($r.Status -ne 200) { throw "Group $GroupId not found or not readable (HTTP $($r.Status)): $($r.Message)" }
    $group = $r.Body
}
else {
    $escaped = $GroupName -replace "'", "''"
    $uri = "$GraphV1/groups?`$filter=displayName eq '$([uri]::EscapeDataString($escaped))'&`$select=$groupSelect"
    $r = Get-GraphCollection -Uri $uri
    if ($r.Status -ne 200) { throw "Group lookup failed (HTTP $($r.Status)): $($r.Message)" }
    if ($r.Items.Count -eq 0) { throw "Group '$GroupName' not found." }
    if ($r.Items.Count -gt 1) {
        $r.Items | ForEach-Object { Write-Host "  $($_.id)  $($_.displayName)" -ForegroundColor Yellow }
        throw "Group name '$GroupName' is not unique. Run again with -GroupId."
    }
    $group = $r.Items[0]
}

# Member types decide which virtual targets (All users / All devices) can reach the group
$countHeaders = @{ ConsistencyLevel = 'eventual' }
$userCount = 0; $deviceCount = 0
try {
    $userCount = [int](Invoke-MgGraphRequest -Method GET -Uri "$GraphV1/groups/$($group.id)/transitiveMembers/microsoft.graph.user/`$count" -Headers $countHeaders)
    $deviceCount = [int](Invoke-MgGraphRequest -Method GET -Uri "$GraphV1/groups/$($group.id)/transitiveMembers/microsoft.graph.device/`$count" -Headers $countHeaders)
}
catch { Write-Host "  Could not count members: $($_.Exception.Message)" -ForegroundColor DarkYellow }

$membership = if ($group.membershipRule) { 'Dynamic' } else { 'Assigned' }
Write-Host "  $($group.displayName)  ($($group.id))" -ForegroundColor Green
Write-Host "  Membership: $membership   Members (transitive): $userCount users, $deviceCount devices" -ForegroundColor Gray
if ($group.membershipRule) { Write-Host "  Rule: $($group.membershipRule)" -ForegroundColor Gray }
if ($userCount -gt 0 -and $deviceCount -gt 0) {
    Write-Host '  Note: group contains users AND devices. Microsoft recommends against mixed groups for Intune assignments.' -ForegroundColor DarkYellow
}

# Target set: the group itself plus all groups it is (transitively) a member of
$targetGroups = @{}
$targetGroups[$group.id] = 'Direct'
if (-not $DirectOnly) {
    $r = Get-GraphCollection -Uri "$GraphV1/groups/$($group.id)/transitiveMemberOf/microsoft.graph.group?`$select=id,displayName"
    if ($r.Status -eq 200) {
        foreach ($pg in $r.Items) { $targetGroups[$pg.id] = "Parent group: $($pg.displayName)" }
        Write-Host "  Parent groups (transitive): $($r.Items.Count)" -ForegroundColor Gray
    }
    else {
        Write-Host "  Could not read parent groups (HTTP $($r.Status)) - direct assignments only" -ForegroundColor DarkYellow
    }
}

$showAllUsers = $IncludeAllUsersAllDevices -and $userCount -gt 0
$showAllDevices = $IncludeAllUsersAllDevices -and $deviceCount -gt 0
if ($IncludeAllUsersAllDevices -and ($userCount + $deviceCount) -eq 0) {
    # Empty group or counting failed: show both rather than hide something
    $showAllUsers = $true; $showAllDevices = $true
}
#endregion

#region Lookups (filters, scope tags, policy sets)
Write-Host "`nLoading lookups..." -ForegroundColor Cyan
$filterLookup = @{}
$r = Get-GraphCollection -Uri "$GraphBeta/deviceManagement/assignmentFilters?`$select=id,displayName,platform"
foreach ($f in $r.Items) { $filterLookup[$f.id] = $f.displayName }
Write-Host "  Assignment filters: $($filterLookup.Count)" -ForegroundColor Gray

$scopeTagLookup = @{}
$scopeTagResult = Get-GraphCollection -Uri "$GraphBeta/deviceManagement/roleScopeTags?`$select=id,displayName"
foreach ($t in $scopeTagResult.Items) { $scopeTagLookup["$($t.id)"] = $t.displayName }
Write-Host "  Scope tags: $($scopeTagLookup.Count)" -ForegroundColor Gray

$policySetLookup = @{}
$policySetResult = Get-GraphCollection -Uri "$GraphBeta/deviceAppManagement/policySets?`$select=id,displayName"
foreach ($ps in $policySetResult.Items) { $policySetLookup[$ps.id] = $ps.displayName }
Write-Host "  Policy sets: $($policySetLookup.Count)" -ForegroundColor Gray
#endregion

#region Object catalog
# Path       : collection below /beta
# Name       : name property
# Select     : properties besides id/name (dropped automatically if the endpoint rejects them)
# Expand     : $true if $expand=assignments works (verified 2026-10-19), otherwise assignments via $batch
# Filter     : optional $filter
$catalog = @(
    @{ Cat = 'Configuration'; Label = 'Device configuration';           Path = '/deviceManagement/deviceConfigurations';           Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Configuration'; Label = 'Settings catalog';               Path = '/deviceManagement/configurationPolicies';          Name = 'name';        Select = 'roleScopeTagIds,platforms,technologies,templateReference'; Expand = $true; Template = $true }
    @{ Cat = 'Configuration'; Label = 'Administrative templates';       Path = '/deviceManagement/groupPolicyConfigurations';      Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Configuration'; Label = 'Endpoint security (legacy intent)'; Path = '/deviceManagement/intents';                    Name = 'displayName'; Select = 'roleScopeTagIds,templateId'; Expand = $true }
    @{ Cat = 'Configuration'; Label = 'BIOS configuration';             Path = '/deviceManagement/hardwareConfigurations';         Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Compliance';    Label = 'Compliance policy';              Path = '/deviceManagement/deviceCompliancePolicies';       Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Compliance';    Label = 'Compliance (settings catalog)';  Path = '/deviceManagement/compliancePolicies';             Name = 'name';        Select = 'roleScopeTagIds,platforms'; Expand = $true }
    @{ Cat = 'Scripts';       Label = 'Platform script (Windows)';      Path = '/deviceManagement/deviceManagementScripts';        Name = 'displayName'; Select = 'roleScopeTagIds,runAsAccount'; Expand = $true }
    @{ Cat = 'Scripts';       Label = 'Remediation';                    Path = '/deviceManagement/deviceHealthScripts';            Name = 'displayName'; Select = 'roleScopeTagIds,isGlobalScript'; Expand = $true }
    @{ Cat = 'Scripts';       Label = 'Shell script (macOS)';           Path = '/deviceManagement/deviceShellScripts';             Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Scripts';       Label = 'Custom attribute (macOS)';       Path = '/deviceManagement/deviceCustomAttributeShellScripts'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Updates';       Label = 'Feature update (Windows)';       Path = '/deviceManagement/windowsFeatureUpdateProfiles';   Name = 'displayName'; Select = 'roleScopeTagIds,featureUpdateVersion'; Expand = $true }
    @{ Cat = 'Updates';       Label = 'Quality update expedite (Windows)'; Path = '/deviceManagement/windowsQualityUpdateProfiles'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Updates';       Label = 'Quality update policy (Windows)'; Path = '/deviceManagement/windowsQualityUpdatePolicies';  Name = 'displayName'; Select = 'roleScopeTagIds,hotpatchEnabled'; Expand = $true }
    @{ Cat = 'Updates';       Label = 'Driver update (Windows)';        Path = '/deviceManagement/windowsDriverUpdateProfiles';    Name = 'displayName'; Select = 'roleScopeTagIds,approvalType'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'App';                            Path = '/deviceAppManagement/mobileApps';                  Name = 'displayName'; Select = 'roleScopeTagIds,publisher'; Expand = $true; Filter = 'isAssigned eq true' }
    @{ Cat = 'Apps';          Label = 'App configuration (managed devices)'; Path = '/deviceAppManagement/mobileAppConfigurations'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'App configuration (managed apps)'; Path = '/deviceAppManagement/targetedManagedAppConfigurations'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'App protection (iOS)';           Path = '/deviceAppManagement/iosManagedAppProtections';    Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'App protection (Android)';       Path = '/deviceAppManagement/androidManagedAppProtections'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'App protection (Windows)';       Path = '/deviceAppManagement/windowsManagedAppProtections'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Apps';          Label = 'Policy set';                     Path = '/deviceAppManagement/policySets';                  Name = 'displayName'; Select = '';                Expand = $false }
    @{ Cat = 'Enrollment';    Label = 'Enrollment configuration';       Path = '/deviceManagement/deviceEnrollmentConfigurations'; Name = 'displayName'; Select = 'roleScopeTagIds,priority'; Expand = $true }
    @{ Cat = 'Enrollment';    Label = 'Autopilot deployment profile';   Path = '/deviceManagement/windowsAutopilotDeploymentProfiles'; Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $true }
    @{ Cat = 'Enrollment';    Label = 'Apple user-initiated enrollment'; Path = '/deviceManagement/appleUserInitiatedEnrollmentProfiles'; Name = 'displayName'; Select = 'priority'; Expand = $true }
    @{ Cat = 'Enrollment';    Label = 'Terms and conditions';           Path = '/deviceManagement/termsAndConditions';             Name = 'displayName'; Select = 'roleScopeTagIds'; Expand = $false }
    @{ Cat = 'Enrollment';    Label = 'Company Portal branding';        Path = '/deviceManagement/intuneBrandingProfiles';         Name = 'profileName'; Select = 'roleScopeTagIds,isDefaultProfile'; Expand = $true }
)

$templateFamilyLabel = @{
    'none'                                         = 'Settings catalog'
    'endpointSecurityAntivirus'                    = 'Endpoint security - Antivirus'
    'endpointSecurityDiskEncryption'               = 'Endpoint security - Disk encryption'
    'endpointSecurityFirewall'                     = 'Endpoint security - Firewall'
    'endpointSecurityEndpointDetectionAndResponse' = 'Endpoint security - EDR'
    'endpointSecurityAttackSurfaceReduction'       = 'Endpoint security - ASR'
    'endpointSecurityAccountProtection'            = 'Endpoint security - Account protection'
    'endpointSecurityApplicationControl'           = 'Endpoint security - App Control'
    'endpointSecurityEndpointPrivilegeManagement'  = 'Endpoint security - EPM'
    'enrollmentConfiguration'                      = 'Enrollment configuration'
    'appQuietTime'                                 = 'App quiet time'
    'baseline'                                     = 'Security baseline'
    'deviceConfigurationScripts'                   = 'Device configuration script'
    'deviceConfigurationPolicies'                  = 'Device configuration policy'
    'windowsOsRecoveryPolicies'                    = 'Windows OS recovery'
    'companyPortal'                                = 'Company Portal'
}

$enrollmentTypeLabel = @{
    'windows10EnrollmentCompletionPageConfiguration'          = 'Enrollment Status Page'
    'deviceEnrollmentPlatformRestrictionsConfiguration'       = 'Platform restrictions (default)'
    'deviceEnrollmentPlatformRestrictionConfiguration'        = 'Platform restriction'
    'deviceEnrollmentLimitConfiguration'                      = 'Device limit'
    'deviceEnrollmentWindowsHelloForBusinessConfiguration'    = 'Windows Hello for Business'
    'windowsRestoreDeviceEnrollmentConfiguration'             = 'Windows Backup and Restore'
    'deviceComanagementAuthorityConfiguration'                = 'Co-management settings'
    'deviceEnrollmentNotificationConfiguration'               = 'Enrollment notification'
}

$selected = $catalog
if ($Category -notcontains 'All') { $selected = @($catalog | Where-Object { $Category -contains $_.Cat }) }
$doRbac = ($Category -contains 'All') -or ($Category -contains 'RBAC')
#endregion

#region Assignment evaluation
$results = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]

function Get-ObjectTypeLabel($def, $obj) {
    $odataType = Get-ShortType $obj.'@odata.type'
    if ($def.Template -and $obj.templateReference) {
        $fam = "$($obj.templateReference.templateFamily)"
        $lbl = $templateFamilyLabel[$fam]
        if (-not $lbl) { $lbl = $fam }
        if ($fam -ne 'none' -and $obj.templateReference.templateDisplayName) { $lbl = "$lbl ($($obj.templateReference.templateDisplayName))" }
        return $lbl
    }
    if ($def.Path -like '*deviceEnrollmentConfigurations' -and $odataType) {
        $lbl = $enrollmentTypeLabel[$odataType]
        if ($lbl) { return "Enrollment - $lbl" }
        return "Enrollment - $odataType"
    }
    if ($odataType -and $def.Path -match 'deviceConfigurations|mobileApps|mobileAppConfigurations|windowsAutopilotDeploymentProfiles|deviceCompliancePolicies') {
        return "$($def.Label) ($odataType)"
    }
    return $def.Label
}

function Get-Details($def, $obj, $assignment) {
    $d = @()
    if ($null -ne $obj.priority -and $def.Path -match 'Enrollment') { $d += "Priority $($obj.priority)" }
    if ($obj.platforms) { $d += "Platform $($obj.platforms)" }
    if ($obj.featureUpdateVersion) { $d += "Version $($obj.featureUpdateVersion)" }
    if ($null -ne $obj.hotpatchEnabled) { $d += "Hotpatch $($obj.hotpatchEnabled)" }
    if ($obj.runAsAccount) { $d += "Run as $($obj.runAsAccount)" }
    if ($assignment.runSchedule) {
        $sched = (Get-ShortType $assignment.runSchedule.'@odata.type') -replace '^deviceHealthScript', '' -replace 'Schedule$', ''
        $d += "Schedule $sched/$($assignment.runSchedule.interval)"
        $d += "Remediate $($assignment.runRemediationScript)"
    }
    if ($assignment.settings -and $assignment.settings.'@odata.type') {
        $d += "Settings $(Get-ShortType $assignment.settings.'@odata.type')"
    }
    return ($d -join '; ')
}

function Add-Matches($def, $obj, $assignments) {
    foreach ($a in @($assignments)) {
        if (-not $a -or -not $a.target) { continue }
        $t = $a.target
        $tt = Get-ShortType $t.'@odata.type'
        $mode = $null; $targetName = $null; $via = $null

        switch ($tt) {
            'groupAssignmentTarget' {
                if ($targetGroups.ContainsKey($t.groupId)) { $mode = 'Include'; $via = $targetGroups[$t.groupId] }
            }
            'exclusionGroupAssignmentTarget' {
                if ($targetGroups.ContainsKey($t.groupId)) { $mode = 'Exclude'; $via = $targetGroups[$t.groupId] }
            }
            'allLicensedUsersAssignmentTarget' {
                if ($showAllUsers) { $mode = 'Include'; $via = 'All users' }
            }
            'allDevicesAssignmentTarget' {
                if ($showAllDevices) { $mode = 'Include'; $via = 'All devices' }
            }
        }
        if (-not $mode) { continue }

        if ($a.source -eq 'policySets' -and $a.sourceId) {
            $psName = $policySetLookup[$a.sourceId]
            if (-not $psName) { $psName = $a.sourceId }
            $via = "$via (via policy set: $psName)"
        }

        $filterId = $t.deviceAndAppManagementAssignmentFilterId
        $filterMode = $t.deviceAndAppManagementAssignmentFilterType
        $filterName = $null
        if ($filterId -and $filterId -ne '00000000-0000-0000-0000-000000000000') {
            $filterName = $filterLookup[$filterId]
            if (-not $filterName) { $filterName = $filterId }
        }
        else { $filterMode = $null }

        $tags = $null
        if ($obj.roleScopeTagIds) {
            $tags = (@($obj.roleScopeTagIds) | ForEach-Object { $n = $scopeTagLookup["$_"]; if ($n) { $n } else { $_ } }) -join ', '
        }

        $results.Add([PSCustomObject]@{
                Category   = $def.Cat
                ObjectType = Get-ObjectTypeLabel $def $obj
                Name       = $obj.($def.Name)
                Mode       = $mode
                Via        = $via
                Intent     = $a.intent
                Filter     = $filterName
                FilterMode = $filterMode
                ScopeTags  = $tags
                Details    = Get-Details $def $obj $a
                ObjectId   = $obj.id
            })
    }
}
#endregion

#region Query
Write-Host "`nQuerying Intune objects..." -ForegroundColor Cyan
foreach ($def in $selected) {
    $baseSelect = "id,$($def.Name)"
    $qs = @()
    if ($def.Select) { $qs += "`$select=$baseSelect,$($def.Select)" } else { $qs += "`$select=$baseSelect" }
    if ($def.Expand) { $qs += '$expand=assignments' }
    if ($def.Filter) { $qs += "`$filter=$([uri]::EscapeDataString($def.Filter))" }
    $uri = "$GraphBeta$($def.Path)?" + ($qs -join '&')

    $r = Get-GraphCollection -Uri $uri
    if ($r.Status -eq 400 -and $def.Select) {
        # A property in $select does not exist on this endpoint (e.g. after an API change): retry minimal
        $qs[0] = "`$select=$baseSelect"
        $r = Get-GraphCollection -Uri ("$GraphBeta$($def.Path)?" + ($qs -join '&'))
    }
    $needBatch = -not $def.Expand
    if ($r.Status -eq 400 -and $def.Expand) {
        # $expand rejected: list objects, then read assignments per object via $batch
        $qs = @($qs | Where-Object { $_ -ne '$expand=assignments' })
        $r = Get-GraphCollection -Uri ("$GraphBeta$($def.Path)?" + ($qs -join '&'))
        $needBatch = $true
    }
    if ($r.Status -ne 200) {
        $reason = switch ($r.Status) { 403 { 'Forbidden (Graph scope or Intune RBAC)' } 404 { 'Endpoint not found' } default { "HTTP $($r.Status)" } }
        $skipped.Add([PSCustomObject]@{ ObjectType = $def.Label; Reason = $reason; Message = $r.Message })
        Write-Host ("  {0,-40} skipped: {1}" -f $def.Label, $reason) -ForegroundColor DarkYellow
        continue
    }

    $objects = $r.Items
    if ($needBatch -and $objects.Count -gt 0) {
        $urls = @($objects | ForEach-Object { "$($def.Path)/$($_.id)/assignments" })
        $batch = Invoke-GraphBatchGet -RelativeUrls $urls
        foreach ($o in $objects) {
            $br = $batch["$($def.Path)/$($o.id)/assignments"]
            if ($br -and $br.Status -eq 200) { Add-Matches $def $o $br.Body.value }
            elseif ($br) { $skipped.Add([PSCustomObject]@{ ObjectType = $def.Label; Reason = "Assignments of '$($o.($def.Name))': HTTP $($br.Status)"; Message = $null }) }
        }
    }
    else {
        foreach ($o in $objects) { Add-Matches $def $o $o.assignments }
    }
    Write-Host ("  {0,-40} {1,5} objects" -f $def.Label, $objects.Count) -ForegroundColor Gray
}

if ($doRbac) {
    # Intune role assignments: group as admin members or as scope group.
    # Note: $expand=roleDefinition on the list returns null, so matching assignments are read one by one.
    $r = Get-GraphCollection -Uri "$GraphBeta/deviceManagement/roleAssignments?`$select=id,displayName,members,scopeMembers,scopeType"
    if ($r.Status -ne 200) {
        $skipped.Add([PSCustomObject]@{ ObjectType = 'Intune role assignment'; Reason = "HTTP $($r.Status)"; Message = $r.Message })
        Write-Host ("  {0,-40} skipped: HTTP {1}" -f 'Intune role assignment', $r.Status) -ForegroundColor DarkYellow
    }
    else {
        foreach ($ra in $r.Items) {
            $hits = @()
            foreach ($m in @($ra.members)) { if ($targetGroups.ContainsKey($m)) { $hits += @{ Mode = 'Admin group (members)'; Via = $targetGroups[$m] } } }
            foreach ($m in @($ra.scopeMembers)) { if ($targetGroups.ContainsKey($m)) { $hits += @{ Mode = 'Scope group'; Via = $targetGroups[$m] } } }
            if ($hits.Count -eq 0) { continue }
            $roleName = $null; $tags = $null
            $full = Invoke-Graph -Uri "$GraphBeta/deviceManagement/roleAssignments/$($ra.id)?`$expand=roleDefinition"
            if ($full.Status -eq 200) {
                $roleName = $full.Body.roleDefinition.displayName
                if ($full.Body.roleScopeTagIds) {
                    $tags = (@($full.Body.roleScopeTagIds) | ForEach-Object { $n = $scopeTagLookup["$_"]; if ($n) { $n } else { $_ } }) -join ', '
                }
            }
            foreach ($h in $hits) {
                $results.Add([PSCustomObject]@{
                        Category   = 'RBAC'
                        ObjectType = 'Intune role assignment'
                        Name       = "$roleName / $($ra.displayName)"
                        Mode       = $h.Mode
                        Via        = $h.Via
                        Intent     = $null
                        Filter     = $null
                        FilterMode = $null
                        ScopeTags  = $tags
                        Details    = "Scope type $($ra.scopeType)"
                        ObjectId   = $ra.id
                    })
            }
        }
        Write-Host ("  {0,-40} {1,5} objects" -f 'Intune role assignment', $r.Items.Count) -ForegroundColor Gray
    }

    # Scope tags assigned to groups (devices in the group get the tag automatically)
    if ($scopeTagResult.Status -eq 200 -and $scopeTagResult.Items.Count -gt 0) {
        $urls = @($scopeTagResult.Items | ForEach-Object { "/deviceManagement/roleScopeTags/$($_.id)/assignments" })
        $batch = Invoke-GraphBatchGet -RelativeUrls $urls
        foreach ($tag in $scopeTagResult.Items) {
            $br = $batch["/deviceManagement/roleScopeTags/$($tag.id)/assignments"]
            if (-not $br -or $br.Status -ne 200) { continue }
            foreach ($a in @($br.Body.value)) {
                if ($a.target -and $targetGroups.ContainsKey($a.target.groupId)) {
                    $results.Add([PSCustomObject]@{
                            Category   = 'RBAC'
                            ObjectType = 'Scope tag (group assignment)'
                            Name       = $tag.displayName
                            Mode       = 'Include'
                            Via        = $targetGroups[$a.target.groupId]
                            Intent     = $null
                            Filter     = $null
                            FilterMode = $null
                            ScopeTags  = $null
                            Details    = "Scope tag id $($tag.id)"
                            ObjectId   = $tag.id
                        })
                }
            }
        }
        Write-Host ("  {0,-40} {1,5} objects" -f 'Scope tag', $scopeTagResult.Items.Count) -ForegroundColor Gray
    }
}
#endregion

#region Output
$sorted = @($results | Sort-Object Category, ObjectType, Name)
$include = @($sorted | Where-Object { $_.Mode -ne 'Exclude' -and $_.Via -notmatch '^All (users|devices)' })
$exclude = @($sorted | Where-Object { $_.Mode -eq 'Exclude' })
$virtual = @($sorted | Where-Object { $_.Via -match '^All (users|devices)' })

Write-Host ''
Write-Host '==================================================================' -ForegroundColor Cyan
Write-Host " Assignments for '$($group.displayName)'" -ForegroundColor Cyan
Write-Host '==================================================================' -ForegroundColor Cyan

Write-Host "`nIncluded (direct, parent group, RBAC):" -ForegroundColor Green
if ($include.Count) { $include | Format-Table Category, ObjectType, Name, Mode, Via, Intent, Filter, FilterMode -AutoSize -Wrap | Out-Host }
else { Write-Host '  (none)' -ForegroundColor DarkGray }

Write-Host 'Excluded:' -ForegroundColor Red
if ($exclude.Count) { $exclude | Format-Table Category, ObjectType, Name, Via, Intent, Filter, FilterMode -AutoSize -Wrap | Out-Host }
else { Write-Host '  (none)' -ForegroundColor DarkGray }

if ($IncludeAllUsersAllDevices) {
    Write-Host 'Via All users / All devices:' -ForegroundColor Yellow
    if ($virtual.Count) { $virtual | Format-Table Category, ObjectType, Name, Via, Intent, Filter, FilterMode -AutoSize -Wrap | Out-Host }
    else { Write-Host '  (none)' -ForegroundColor DarkGray }
}

Write-Host '------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host "Included: $($include.Count)   Excluded: $($exclude.Count)   All users/devices: $($virtual.Count)" -ForegroundColor Cyan
if ($skipped.Count) {
    Write-Host "NOT checked ($($skipped.Count)) - result is incomplete for these types:" -ForegroundColor DarkYellow
    $skipped | Format-Table ObjectType, Reason -AutoSize | Out-Host
}
Write-Host 'Note: objects outside your Intune scope tags are invisible to Graph and therefore missing here.' -ForegroundColor DarkGray

if ($ExportCsv) {
    $safe = $group.displayName -replace '[^\w\-]', '_'
    $path = Join-Path $OutputFolder ("IntuneAssignments_{0}_{1}.csv" -f $safe, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $sorted | Export-Csv -Path $path -NoTypeInformation -Delimiter ';' -Encoding UTF8
    Write-Host "Exported: $path" -ForegroundColor Green
}

if ($PassThru) { return $sorted }
#endregion
