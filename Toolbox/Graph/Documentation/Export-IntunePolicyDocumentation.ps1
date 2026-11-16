<#
.SYNOPSIS
    Documents settings catalog policies: every configured setting with its readable name and value,
    plus the assignments, as one HTML page and one CSV file.

.DESCRIPTION
    The Intune admin center shows the settings of a policy on screen but has no export.
    This script reads every settings catalog policy (configurationPolicies - this includes endpoint
    security policies and other policies built on the settings catalog), resolves setting and option
    names through the setting definitions and writes:
      - <OutputFolder>\IntunePolicyDocumentation.html  one section per policy, readable
      - <OutputFolder>\IntunePolicyDocumentation.csv   one row per setting (delimiter ';', UTF-8)

    Every request is GET. Nothing is changed in the tenant. Secret values (for example passwords)
    are not returned by Graph and are shown as "(secret, not shown)".

.PARAMETER NameContains
    Only policies whose name contains this text. Default: all policies.

.PARAMETER OutputFolder
    Folder for the HTML and CSV file. Default: C:\Temp\IntuneDocumentation

.PARAMETER NoAssignments
    Skip the assignments (then the script needs no group permission).

.EXAMPLE
    .\Export-IntunePolicyDocumentation.ps1

.EXAMPLE
    .\Export-IntunePolicyDocumentation.ps1 -NameContains 'Windows' -OutputFolder 'C:\Temp\Doku'

.NOTES
    Version : 1.0.1 (2026-11-16) - fix: helper renamed, "H" is the built-in alias of Get-History
    Requires: Microsoft.Graph.Authentication 2.x, Windows PowerShell 5.1 or PowerShell 7
    Scopes  : DeviceManagementConfiguration.Read.All, Group.Read.All (for group names)
    Graph   : beta - configurationPolicies, their settings ($expand=settingDefinitions) and assignments
              exist only in Graph beta.
    Only settings catalog policies. Older template profiles (deviceConfigurations), administrative
    templates and compliance policies are not covered.
#>
param(
    [string] $NameContains,
    [string] $OutputFolder = 'C:\Temp\IntuneDocumentation',
    [switch] $NoAssignments
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
$scopes = @('DeviceManagementConfiguration.Read.All')
if (-not $NoAssignments) { $scopes += 'Group.Read.All' }
Connect-MgGraph -Scopes $scopes -NoWelcome
Write-Host "Connected to tenant $((Get-MgContext).TenantId) as $((Get-MgContext).Account)"

$beta = 'https://graph.microsoft.com/beta'

# GET with paging: follows @odata.nextLink until the last page
function Get-GraphAll ([string] $Uri) {
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType HashTable
        foreach ($item in $page.value) { $item }
        $Uri = $page.'@odata.nextLink'
    }
}

# Readable name of a chosen option (choice settings store the option ID, e.g. ..._hiderecentlyaddedapps_1)
function Get-OptionName ($Definition, [string] $ItemId) {
    if ($Definition -and $Definition.options) {
        foreach ($o in $Definition.options) { if ($o.itemId -eq $ItemId) { return [string]$o.displayName } }
    }
    return $ItemId
}

function Format-SimpleValue ($Value) {
    if ($null -eq $Value) { return '' }
    if ([string]$Value.'@odata.type' -like '*Secret*') { return '(secret, not shown)' }
    return [string]$Value.value
}

# Walks one setting instance and its children; returns one row per configured value.
# Instance types: choice, choice collection, simple, simple collection, group, group collection.
function Get-SettingRows ($Instance, [hashtable] $Definitions, [string] $Parent) {
    $id   = [string]$Instance.settingDefinitionId
    $def  = $Definitions[$id]
    $name = $id
    if ($def -and $def.displayName) { $name = ([string]$def.displayName).Trim() }
    $path = $name
    if ($Parent) { $path = "$Parent > $name" }
    $csp  = ''
    if ($def) { $csp = "$($def.baseUri)$($def.offsetUri)" }
    $type = [string]$Instance.'@odata.type'

    if ($type -like '*ChoiceSettingCollectionInstance') {
        $values = @($Instance.choiceSettingCollectionValue | ForEach-Object { Get-OptionName $def $_.value })
        [pscustomobject]@{ Setting = $path; Value = ($values -join '; '); Csp = $csp; SettingId = $id }
        foreach ($v in $Instance.choiceSettingCollectionValue) {
            foreach ($child in $v.children) { Get-SettingRows $child $Definitions $path }
        }
    }
    elseif ($type -like '*ChoiceSettingInstance') {
        [pscustomobject]@{ Setting = $path; Value = (Get-OptionName $def $Instance.choiceSettingValue.value); Csp = $csp; SettingId = $id }
        foreach ($child in $Instance.choiceSettingValue.children) { Get-SettingRows $child $Definitions $path }
    }
    elseif ($type -like '*SimpleSettingCollectionInstance') {
        $values = @($Instance.simpleSettingCollectionValue | ForEach-Object { Format-SimpleValue $_ })
        [pscustomobject]@{ Setting = $path; Value = ($values -join '; '); Csp = $csp; SettingId = $id }
    }
    elseif ($type -like '*SimpleSettingInstance') {
        [pscustomobject]@{ Setting = $path; Value = (Format-SimpleValue $Instance.simpleSettingValue); Csp = $csp; SettingId = $id }
    }
    elseif ($type -like '*GroupSettingCollectionInstance') {
        $values = @($Instance.groupSettingCollectionValue)
        for ($i = 0; $i -lt $values.Count; $i++) {
            $itemPath = $path
            if ($values.Count -gt 1) { $itemPath = "$path [$($i + 1)]" }
            foreach ($child in $values[$i].children) { Get-SettingRows $child $Definitions $itemPath }
        }
    }
    elseif ($type -like '*GroupSettingInstance') {
        foreach ($child in $Instance.groupSettingValue.children) { Get-SettingRows $child $Definitions $path }
    }
    else {
        [pscustomobject]@{ Setting = $path; Value = "(not resolved: $type)"; Csp = $csp; SettingId = $id }
    }
}

# Group and filter names, read once each
$groupNames  = @{}
$filterNames = @{}
function Get-GroupName ([string] $Id) {
    if (-not $groupNames.ContainsKey($Id)) {
        try {
            $groupNames[$Id] = [string](Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$($Id)?`$select=displayName" -OutputType HashTable).displayName
        } catch { $groupNames[$Id] = "$Id (not found)" }
    }
    $groupNames[$Id]
}
function Get-FilterName ([string] $Id) {
    if (-not $filterNames.ContainsKey($Id)) {
        try {
            $filterNames[$Id] = [string](Invoke-MgGraphRequest -Method GET -Uri "$beta/deviceManagement/assignmentFilters/$($Id)?`$select=displayName" -OutputType HashTable).displayName
        } catch { $filterNames[$Id] = $Id }
    }
    $filterNames[$Id]
}

function Get-AssignmentText ([string] $PolicyId) {
    $texts = foreach ($a in @(Get-GraphAll "$beta/deviceManagement/configurationPolicies/$PolicyId/assignments")) {
        $t = $a.target
        $odataType = [string]$t.'@odata.type'
        $text = switch -Wildcard ($odataType) {
            '*exclusionGroupAssignmentTarget'   { "Exclude: $(Get-GroupName $t.groupId)"; break }
            '*groupAssignmentTarget'            { Get-GroupName $t.groupId; break }
            '*allLicensedUsersAssignmentTarget' { 'All users'; break }
            '*allDevicesAssignmentTarget'       { 'All devices'; break }
            default                             { $odataType }
        }
        if ($t.deviceAndAppManagementAssignmentFilterId -and $t.deviceAndAppManagementAssignmentFilterType -ne 'none') {
            $text += " (filter $($t.deviceAndAppManagementAssignmentFilterType): $(Get-FilterName $t.deviceAndAppManagementAssignmentFilterId))"
        }
        $text
    }
    if (-not $texts) { return 'Not assigned' }
    return (@($texts) -join '; ')
}

# 1. Policies
$policies = @(Get-GraphAll "$beta/deviceManagement/configurationPolicies?`$select=id,name,description,platforms,technologies,lastModifiedDateTime,templateReference" |
    Where-Object { -not $NameContains -or $_.name -like "*$NameContains*" } | Sort-Object { $_.name })
Write-Host "$($policies.Count) settings catalog policies"

# 2. Settings and assignments per policy
$docs = foreach ($p in $policies) {
    Write-Host "  $($p.name)"
    $settings = @(Get-GraphAll "$beta/deviceManagement/configurationPolicies/$($p.id)/settings?`$expand=settingDefinitions")
    $definitions = @{}
    foreach ($s in $settings) { foreach ($d in $s.settingDefinitions) { $definitions[[string]$d.id] = $d } }
    $rows = @(foreach ($s in $settings) { Get-SettingRows $s.settingInstance $definitions '' })
    $assigned = 'not read'
    if (-not $NoAssignments) { $assigned = Get-AssignmentText $p.id }
    $template = ''
    if ($p.templateReference -and $p.templateReference.templateDisplayName) { $template = [string]$p.templateReference.templateDisplayName }
    [pscustomobject]@{
        Name = [string]$p.name; Description = [string]$p.description; Platform = [string]$p.platforms
        Technologies = [string]$p.technologies; Template = $template
        Modified = ([datetime]$p.lastModifiedDateTime).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
        Assigned = $assigned; Rows = $rows
    }
}

# 3. CSV: one row per setting
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
$csvFile = Join-Path $OutputFolder 'IntunePolicyDocumentation.csv'
$docs | ForEach-Object {
    $doc = $_
    foreach ($r in $doc.Rows) {
        [pscustomobject]@{ Policy = $doc.Name; Platform = $doc.Platform; Technologies = $doc.Technologies; Template = $doc.Template
                           Assigned = $doc.Assigned; Setting = $r.Setting; Value = $r.Value; CSP = $r.Csp; SettingId = $r.SettingId }
    }
} | Export-Csv -Path $csvFile -Delimiter ';' -Encoding UTF8 -NoTypeInformation

# 4. HTML: one section per policy
function ConvertTo-HtmlText ([string] $Text) { [System.Net.WebUtility]::HtmlEncode($Text) }
$sections = foreach ($doc in $docs) {
    $settingRows = ($doc.Rows | ForEach-Object { "<tr><td>$(ConvertTo-HtmlText $_.Setting)</td><td>$(ConvertTo-HtmlText $_.Value)</td><td class=""csp"">$(ConvertTo-HtmlText $_.Csp)</td></tr>" }) -join "`n"
    if (-not $settingRows) { $settingRows = '<tr><td colspan="3" class="muted">No settings configured.</td></tr>' }
    $meta = "$(ConvertTo-HtmlText $doc.Platform) &middot; $(ConvertTo-HtmlText $doc.Technologies)"
    if ($doc.Template) { $meta += " &middot; template $(ConvertTo-HtmlText $doc.Template)" }
    $meta += " &middot; modified $(ConvertTo-HtmlText $doc.Modified) &middot; $($doc.Rows.Count) settings"
    $desc = ''
    if ($doc.Description) { $desc = "<p>$(ConvertTo-HtmlText $doc.Description)</p>" }
@"
<details open><summary><span class="name">$(ConvertTo-HtmlText $doc.Name)</span><span class="meta">$meta</span></summary>
$desc<p><b>Assigned:</b> $(ConvertTo-HtmlText $doc.Assigned)</p>
<table><thead><tr><th>Setting</th><th>Value</th><th>CSP path</th></tr></thead><tbody>
$settingRows
</tbody></table></details>
"@
}
$generated = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Intune policy documentation</title>
<style>
  :root { --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink2: #52514e; --grid: #e1e0d9; --border: rgba(11,11,11,0.10); }
  @media (prefers-color-scheme: dark) { :root { --page: #0d0d0d; --surface: #1a1a19; --ink: #f0efec; --ink2: #c3c2b7; --grid: #2c2c2a; --border: rgba(255,255,255,0.10); } }
  body { margin: 0; background: var(--page); color: var(--ink); font-family: system-ui, -apple-system, "Segoe UI", sans-serif; font-size: 14px; }
  main { max-width: 1200px; margin: 0 auto; padding: 24px 16px 40px; }
  h1 { font-size: 22px; margin: 0 0 4px; } .muted, .meta, .csp { color: var(--ink2); }
  details { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 10px 16px; margin: 12px 0; }
  summary { cursor: pointer; display: flex; flex-wrap: wrap; gap: 4px 12px; align-items: baseline; }
  summary .name { font-weight: 600; font-size: 15px; } summary .meta { font-size: 12px; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid var(--grid); vertical-align: top; }
  th { color: var(--ink2); } td { overflow-wrap: anywhere; } .csp { font-family: ui-monospace, Consolas, monospace; font-size: 12px; }
</style></head><body><main>
<h1>Intune policy documentation</h1>
<p class="muted">Settings catalog policies &middot; generated $generated &middot; $($docs.Count) policies</p>
$($sections -join "`n")
</main></body></html>
"@
$htmlFile = Join-Path $OutputFolder 'IntunePolicyDocumentation.html'
$html | Out-File -FilePath $htmlFile -Encoding utf8
Write-Host "Written: $htmlFile"
Write-Host "Written: $csvFile"
Start-Process $htmlFile
