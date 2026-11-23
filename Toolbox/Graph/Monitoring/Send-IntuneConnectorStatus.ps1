<#
.SYNOPSIS
    Azure Automation runbook: reads the status of Intune connectors and tokens from Microsoft Graph
    and writes one row per connector to the Log Analytics table IntuneConnectorStatus_CL.

.DESCRIPTION
    Tested by the trainer 2026-11-23 (Automation account, ingestion, alert mails per connector).

    Deployed by the Intune alert builder (Toolbox/Builders/intune-alert-builder.html, section 6) together with
    the custom table, the data collection rule, a daily schedule and an alert rule. The runbook runs as the
    system-assigned managed identity of the Automation account.

    Connectors checked (Graph beta, endpoints read in a course tenant 2026-11):
      Apple MDM push certificate  deviceManagement/applePushNotificationCertificate
      Apple VPP tokens            deviceAppManagement/vppTokens
      Apple ADE (DEP) tokens      deviceManagement/depOnboardingSettings
      Managed Google Play         deviceManagement/androidManagedStoreAccountEnterpriseSettings
      Mobile Threat Defense       deviceManagement/mobileThreatDefenseConnectors (Defender for Endpoint and partners)
      Windows Autopilot sync      deviceManagement/windowsAutopilotSettings
    Connectors that are not set up are skipped.

    Status follows Intune admin center -> Tenant administration -> Connector status (Learn):
      Unhealthy = expired, or last sync 3 or more days ago
      Warning   = expires within 30 days (Intune itself warns 7 days ahead, -ExpiryWarningDays), or last sync more than 1 day ago

    Needs:
      - Graph application permissions for the managed identity: DeviceManagementServiceConfig.Read.All,
        DeviceManagementConfiguration.Read.All (the builder generates the grant commands).
      - Role Monitoring Metrics Publisher on the data collection rule (set by the template).

.PARAMETER DcrEndpoint
    Logs ingestion endpoint of the data collection rule, for example https://<name>.<region>-1.ingest.monitor.azure.com

.PARAMETER DcrImmutableId
    Immutable ID of the data collection rule (dcr-...).

.PARAMETER NoUpload
    Only write the rows to the job output, send nothing to Log Analytics.

.NOTES
    Runbook type PowerShell (Windows PowerShell 5.1), no modules needed.
    Sources: Learn - Using a system-assigned managed identity for an Azure Automation account;
    Logs Ingestion API in Azure Monitor; Microsoft Graph Intune API reference.
#>
param(
    [Parameter(Mandatory = $true)][string]$DcrEndpoint,
    [Parameter(Mandatory = $true)][string]$DcrImmutableId,
    [string]$StreamName = 'Custom-IntuneConnectorStatus',
    [int]$ExpiryWarningDays = 30,
    [int]$SyncWarningDays = 1,
    [int]$SyncUnhealthyDays = 3,
    [switch]$NoUpload
)

$ErrorActionPreference = 'Stop'

function Get-MiToken {
    param([string]$Resource)
    if (-not $env:IDENTITY_ENDPOINT) { throw 'No managed identity endpoint. Run this script as an Azure Automation runbook with a system-assigned identity.' }
    $headers = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
    $headers.Add('X-IDENTITY-HEADER', $env:IDENTITY_HEADER)
    $headers.Add('Metadata', 'True')
    (Invoke-RestMethod -Uri ($env:IDENTITY_ENDPOINT + '?resource=' + $Resource) -Method Get -Headers $headers).access_token
}

$graphHeaders = @{ Authorization = 'Bearer ' + (Get-MiToken -Resource 'https://graph.microsoft.com/') }

function Get-Graph {
    # Returns the object, the value array of a collection, or $null when the object does not exist (404).
    param([string]$Path)
    $uri = 'https://graph.microsoft.com/beta/' + $Path
    try {
        $r = Invoke-RestMethod -Uri $uri -Headers $graphHeaders -Method Get
    } catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 404) { return $null }
        throw "GET $uri failed ($code): $($_.Exception.Message) $($_.ErrorDetails.Message)"
    }
    if ($r.PSObject.Properties.Name -contains 'value') {
        $all = @($r.value)
        while ($r.'@odata.nextLink') { $r = Invoke-RestMethod -Uri $r.'@odata.nextLink' -Headers $graphHeaders -Method Get; $all += @($r.value) }
        return $all
    }
    $r
}

$now = (Get-Date).ToUniversalTime()
$rows = New-Object System.Collections.Generic.List[object]

function ConvertTo-Utc {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq '') { return $null }
    $d = [datetime]$Value
    if ($d.Year -lt 2000) { return $null }   # Graph returns 0001-01-01 for "never"
    $d.ToUniversalTime()
}

function Add-Row {
    # Rates expiry and last sync with the Learn thresholds; $Unhealthy/$Warning add reasons from state fields.
    param([string]$Connector, [string]$Name, $Expires, $LastSync, [string[]]$Unhealthy = @(), [string[]]$Warning = @())
    $exp = ConvertTo-Utc $Expires
    $sync = ConvertTo-Utc $LastSync
    $bad = @($Unhealthy | Where-Object { $_ })
    $warn = @($Warning | Where-Object { $_ })
    if ($exp) {
        if ($exp -le $now) { $bad += 'expired ' + $exp.ToString('yyyy-MM-dd') }
        elseif ($exp -le $now.AddDays($ExpiryWarningDays)) { $warn += 'expires ' + $exp.ToString('yyyy-MM-dd') }
    }
    if ($sync) {
        $age = ($now - $sync).TotalDays
        if ($age -ge $SyncUnhealthyDays) { $bad += 'last sync ' + [math]::Floor($age) + ' days ago' }
        elseif ($age -gt $SyncWarningDays) { $warn += 'last sync ' + [math]::Floor($age) + ' days ago' }
    }
    $status = if ($bad.Count) { 'Unhealthy' } elseif ($warn.Count) { 'Warning' } else { 'Healthy' }
    $row = [ordered]@{
        TimeGenerated = $now.ToString('o')
        Connector     = $Connector
        Name          = $Name
        Status        = $status
        Reason        = (@($bad) + @($warn)) -join '; '
    }
    if ($exp) { $row.ExpirationDateTime = $exp.ToString('o') }
    if ($sync) { $row.LastSyncDateTime = $sync.ToString('o') }
    $rows.Add([pscustomobject]$row)
}

# Apple MDM push certificate (one per tenant, 404 or empty when not set up)
$apns = Get-Graph 'deviceManagement/applePushNotificationCertificate'
if ($apns -and $apns.expirationDateTime) {
    Add-Row -Connector 'Apple MDM push certificate' -Name "$($apns.appleIdentifier)" -Expires $apns.expirationDateTime
}

# Apple VPP tokens
foreach ($t in @(Get-Graph 'deviceAppManagement/vppTokens')) {
    if (-not $t) { continue }
    $u = @(); $w = @()
    if ($t.state -and $t.state -ne 'valid') { $u += 'state ' + $t.state }
    if ($t.lastSyncStatus -eq 'failed') { $w += 'last sync failed' }
    $name = if ($t.displayName) { $t.displayName } else { $t.organizationName }
    Add-Row -Connector 'Apple VPP token' -Name "$name" -Expires $t.expirationDateTime -LastSync $t.lastSyncDateTime -Unhealthy $u -Warning $w
}

# Apple ADE (DEP) tokens
foreach ($t in @(Get-Graph 'deviceManagement/depOnboardingSettings')) {
    if (-not $t) { continue }
    $name = if ($t.tokenName) { $t.tokenName } else { $t.appleIdentifier }
    Add-Row -Connector 'Apple ADE token' -Name "$name" -Expires $t.tokenExpirationDateTime -LastSync $t.lastSuccessfulSyncDateTime
}

# Managed Google Play (skipped when not bound)
$mgp = Get-Graph 'deviceManagement/androidManagedStoreAccountEnterpriseSettings'
if ($mgp -and $mgp.bindStatus -and $mgp.bindStatus -ne 'notBound') {
    $u = @(); $w = @()
    if ($mgp.bindStatus -ne 'boundAndValidated') { $u += 'bind status ' + $mgp.bindStatus }
    if ($mgp.lastAppSyncStatus -and $mgp.lastAppSyncStatus -notin @('success', 'none')) { $w += 'app sync ' + $mgp.lastAppSyncStatus }
    Add-Row -Connector 'Managed Google Play' -Name "$($mgp.ownerUserPrincipalName)" -Unhealthy $u -Warning $w
}

# Mobile Threat Defense connectors (only the ones that are set up). Graph returns only the partner id.
# fc780465-... = Microsoft Defender for Endpoint (shown as 'Microsoft Defender for Endpoint Connector' in Connector status, course tenant 2026-11).
$MtdNames = @{ 'fc780465-2017-40d4-a0c5-307022471b92' = 'Microsoft Defender for Endpoint' }
foreach ($c in @(Get-Graph 'deviceManagement/mobileThreatDefenseConnectors')) {
    if (-not $c) { continue }
    if ($c.partnerState -in @('unavailable', 'available', 'notSetUp')) { continue }
    $u = @()
    if ($c.partnerState -ne 'enabled') { $u += 'partner state ' + $c.partnerState }
    $name = if ($MtdNames.ContainsKey($c.id)) { $MtdNames[$c.id] } else { $c.id }
    Add-Row -Connector 'Mobile Threat Defense' -Name "$name" -LastSync $c.lastHeartbeatDateTime -Unhealthy $u
}

# Windows Autopilot device sync (one per tenant)
$ap = Get-Graph 'deviceManagement/windowsAutopilotSettings'
if ($ap -and $ap.lastSyncDateTime) {
    $w = @()
    if ($ap.syncStatus -eq 'failed') { $w += 'last sync failed' }
    Add-Row -Connector 'Windows Autopilot' -Name 'Device sync' -LastSync $ap.lastSyncDateTime -Warning $w
}

$rows | Format-Table Connector, Name, Status, Reason -AutoSize | Out-String -Width 300 | Write-Output

if (-not $rows.Count) { Write-Output 'No connector is set up in this tenant - nothing to send.'; return }
if ($NoUpload) { return }

# Logs Ingestion API: POST {endpoint}/dataCollectionRules/{immutableId}/streams/{stream}?api-version=2023-01-01
$monHeaders = @{ Authorization = 'Bearer ' + (Get-MiToken -Resource 'https://monitor.azure.com/') }
$body = ConvertTo-Json -InputObject @($rows.ToArray()) -Depth 3
$uri = $DcrEndpoint.TrimEnd('/') + '/dataCollectionRules/' + $DcrImmutableId + '/streams/' + $StreamName + '?api-version=2023-01-01'
Invoke-RestMethod -Uri $uri -Method Post -Headers $monHeaders -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
Write-Output "Sent $($rows.Count) rows to $StreamName."
