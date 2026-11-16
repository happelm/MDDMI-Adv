#Requires -Version 5.1
<#
.SYNOPSIS
    Creates an Intune endpoint security "Windows Firewall Rules" policy from a JSON rule file
    via Microsoft Graph (beta).

.DESCRIPTION
    Firewall rule policies are Settings Catalog policies (deviceManagement/configurationPolicies)
    based on the template "Microsoft Defender Firewall Rules"
    (templateId 19c8aa67-f286-4861-9aa0-f23541d31680_1). Each rule is one entry of a group
    setting collection with child settings (name, direction, action, profiles, ports, ...).
    Only the FIRST rule carries the template references (settingInstanceTemplateReference /
    settingValueTemplateReference), all further rules do not.

    The script
      1. reads and validates the rule file (limits and formats of the Firewall CSP:
         max. 150 rules per policy, ports only as numbers or ranges - no keywords such as RPC),
      2. builds the request body (-OutputJsonOnly writes it to the console and stops),
      3. signs in interactively - the tenant comes from the admin's sign-in - and asks for
         confirmation of tenant and account,
      4. creates the policy and optionally assigns it to a group.

    Rule file format (see DomainProfileRules.json):
      policyName, policyDescription, rules[]
      rule: name, description, direction (in|out), action (allow|block), profiles (1=Domain,
            2=Private, 4=Public), protocol (0-255; 6=TCP, 17=UDP, 1=ICMPv4, 58=ICMPv6),
            localPortRanges[], remotePortRanges[], localAddressRanges[], remoteAddressRanges[],
            icmpTypesAndCodes[], appFilePath, appServiceName, enabled (default true)
      The token %MANAGEMENT% in remoteAddressRanges is replaced by -ManagementAddress.

    Docs:
      https://learn.microsoft.com/intune/device-configuration/endpoint-security/firewall
      https://learn.microsoft.com/windows/client-management/mdm/firewall-csp

.PARAMETER RuleFile
    Path to the JSON rule file. Default: DomainProfileRules.json next to the script.

.PARAMETER ManagementAddress
    Replaces %MANAGEMENT% in remoteAddressRanges: IPs, subnets (10.0.0.0/24), ranges
    (10.0.0.1-10.0.0.50) or keywords (LocalSubnet, Intranet, ...). Default: LocalSubnet.

.PARAMETER PolicyName
    Overrides policyName from the rule file.

.PARAMETER AssignmentGroupName
    Display name of an Entra group. If set, the policy is assigned to it (include).

.PARAMETER TenantId
    Optional. Tenant ID or verified domain to sign in to. If omitted, the tenant comes from
    the account you sign in with.

.PARAMETER OutputJsonOnly
    Writes the request body as JSON and stops. No sign-in, nothing is created.

.PARAMETER SkipTenantConfirmation
    Do not ask for confirmation of tenant and account after sign-in.

.PARAMETER Force
    Create the policy even if a policy with the same name exists.

.EXAMPLE
    .\New-IntuneFirewallRulePolicy.ps1 -OutputJsonOnly

.EXAMPLE
    .\New-IntuneFirewallRulePolicy.ps1 -ManagementAddress '10.10.0.0/24'

.EXAMPLE
    .\New-IntuneFirewallRulePolicy.ps1 -AssignmentGroupName 'Hybrid joined devices'

.NOTES
    Requires module Microsoft.Graph.Authentication (installed for CurrentUser if missing).
    Delegated scopes: DeviceManagementConfiguration.ReadWrite.All
                      Group.Read.All (only with -AssignmentGroupName)
    Signed-in account needs an Intune role that can create endpoint security policies
    (for example Intune Administrator or Endpoint Security Manager).
#>
[CmdletBinding()]
param(
    [string]$RuleFile,
    [string[]]$ManagementAddress = @('LocalSubnet'),
    [string]$PolicyName,
    [string]$AssignmentGroupName,
    [string]$TenantId,
    [switch]$OutputJsonOnly,
    [switch]$SkipTenantConfirmation,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $RuleFile) { $RuleFile = Join-Path $PSScriptRoot 'DomainProfileRules.json' }

$GraphBase = 'https://graph.microsoft.com/beta'

#region Template constants -------------------------------------------------------
# Read from GET /beta/deviceManagement/configurationPolicyTemplates('19c8aa67-..._1')/settingTemplates
$TemplateId              = '19c8aa67-f286-4861-9aa0-f23541d31680_1'
$DefBase                 = 'vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}'
$GroupInstanceTemplateId = '76c7a8be-67d2-44bf-81a5-38c94926b1a1'
$GroupValueTemplateId    = 'f9b8c103-a33f-4aac-a89a-b575b51e1ef5'

# settingInstanceTemplateId (i) and settingValueTemplateId (v) per child setting
$Tpl = @{
    name                = @{ i = '116a696a-3270-493e-9938-c336cf05ea98'; v = '12994a33-6185-4c3d-a0e8-69316f6293ea' }
    description         = @{ i = '6c85987f-3adb-4f8d-93e1-4f23e238121b'; v = '18ab9c3a-b6be-4995-9438-289c34eee294' }
    direction           = @{ i = '2114ad3d-157c-47d3-b646-60fcf50949c7'; v = '8b45e13b-952d-4164-bbac-37f4e97b7985' }
    enabled             = @{ i = '4e150e1a-6a10-49b2-a20c-911bf44ea767'; v = '7562f243-f281-4f6f-b7e6-ecdb76dc1f1b' }
    action_type         = @{ i = '0565cfd1-21c2-4965-b87f-6bde2b8d2cbd'; v = '419773d8-bffe-4d6f-a91f-286871963f5c' }
    profiles            = @{ i = '7dc9b243-cdd2-4359-b5f5-0c48edb8fd34'; v = '75330111-26c5-43e4-931b-f9f880a5eb43' }
    protocol            = @{ i = 'b8f45398-674f-40c3-ab18-e002aa8e589b'; v = '27d0d86c-d87d-473b-a41c-eef503d8baec' }
    localportranges     = @{ i = 'b57dc83e-5bf3-439a-b923-4c3e49ac9e2d'; v = 'baa6f4e5-85d3-4060-b9c0-67997509fb10' }
    remoteportranges    = @{ i = 'de5d058e-ab1d-4772-81f5-32b6a35b4587'; v = '01952dc3-6aa8-4302-ba67-c13894457b69' }
    localaddressranges  = @{ i = '8b5de251-c683-4440-91d6-3b679b0aa5aa'; v = '02296167-047a-4c14-9f53-f103cb5f699d' }
    remoteaddressranges = @{ i = 'bf9855fc-f2c0-4241-94cf-94cf823f1c1c'; v = '4dc9acc7-b58e-499d-a2f5-2fe2dcfdd1f3' }
    app_filepath        = @{ i = 'dd825fa0-961b-4fcc-a6b3-4d2dc0419d4e'; v = '8c94fefa-67e5-40b5-8d97-6fca4f0c1e98' }
    app_servicename     = @{ i = '1bd709fe-1cd4-4cc4-9a6f-4cb7f104da66'; v = 'c77294ec-795e-43dc-9af6-775b3b2f911d' }
    # icmptypesandcodes is a setting definition of the template but has no setting template:
    # it never carries template references.
}
#endregion

#region Helpers ------------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

function Get-RuleValue {
    # Reads an optional property of a rule object from ConvertFrom-Json
    param($Rule, [string]$Name)
    $prop = $Rule.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function Add-TemplateRefs {
    param($Instance, [string]$Suffix, [string]$ValueProperty, [bool]$WithRefs)
    if (-not $WithRefs -or -not $Tpl.ContainsKey($Suffix)) { return $Instance }
    $Instance.settingInstanceTemplateReference = @{ settingInstanceTemplateId = $Tpl[$Suffix].i }
    $valueRef = @{ settingValueTemplateId = $Tpl[$Suffix].v; useTemplateDefault = $false }
    $value = $Instance[$ValueProperty]
    if ($value -is [array]) { $value[0].settingValueTemplateReference = $valueRef }
    else { $value.settingValueTemplateReference = $valueRef }
    $Instance
}

function New-SimpleString {
    param([string]$Suffix, [string]$Value, [bool]$WithRefs)
    $inst = [ordered]@{
        '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
        settingDefinitionId = "${DefBase}_$Suffix"
        simpleSettingValue  = [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'
            value         = $Value
        }
    }
    Add-TemplateRefs -Instance $inst -Suffix $Suffix -ValueProperty 'simpleSettingValue' -WithRefs $WithRefs
}

function New-SimpleInt {
    param([string]$Suffix, [int]$Value, [bool]$WithRefs)
    $inst = [ordered]@{
        '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
        settingDefinitionId = "${DefBase}_$Suffix"
        simpleSettingValue  = [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue'
            value         = $Value
        }
    }
    Add-TemplateRefs -Instance $inst -Suffix $Suffix -ValueProperty 'simpleSettingValue' -WithRefs $WithRefs
}

function New-Choice {
    param([string]$Suffix, [string]$Option, [bool]$WithRefs)
    $inst = [ordered]@{
        '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
        settingDefinitionId = "${DefBase}_$Suffix"
        choiceSettingValue  = [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
            value         = "${DefBase}_${Suffix}_$Option"
            children      = @()
        }
    }
    Add-TemplateRefs -Instance $inst -Suffix $Suffix -ValueProperty 'choiceSettingValue' -WithRefs $WithRefs
}

function New-ChoiceCollection {
    param([string]$Suffix, [string[]]$Options, [bool]$WithRefs)
    $values = @(foreach ($o in $Options) {
        [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
            value         = "${DefBase}_${Suffix}_$o"
            children      = @()
        }
    })
    $inst = [ordered]@{
        '@odata.type'                = '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance'
        settingDefinitionId          = "${DefBase}_$Suffix"
        choiceSettingCollectionValue = $values
    }
    Add-TemplateRefs -Instance $inst -Suffix $Suffix -ValueProperty 'choiceSettingCollectionValue' -WithRefs $WithRefs
}

function New-SimpleCollection {
    param([string]$Suffix, [string[]]$Values, [bool]$WithRefs)
    $vals = @(foreach ($v in $Values) {
        [ordered]@{
            '@odata.type' = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'
            value         = $v
        }
    })
    $inst = [ordered]@{
        '@odata.type'                = '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance'
        settingDefinitionId          = "${DefBase}_$Suffix"
        simpleSettingCollectionValue = $vals
    }
    Add-TemplateRefs -Instance $inst -Suffix $Suffix -ValueProperty 'simpleSettingCollectionValue' -WithRefs $WithRefs
}

function Test-Rule {
    # Checks the rule against the Firewall CSP / setting definition limits. Returns error strings.
    param($Rule)
    $errors   = @()
    $name     = Get-RuleValue $Rule 'name'
    $protocol = Get-RuleValue $Rule 'protocol'
    $portRx   = '^\d{1,5}(-\d{1,5})?$'

    if (-not $name) { $errors += 'name is missing' }
    if ((Get-RuleValue $Rule 'direction') -notin 'in', 'out') { $errors += 'direction must be in or out' }
    if ((Get-RuleValue $Rule 'action') -notin 'allow', 'block') { $errors += 'action must be allow or block' }
    $profiles = @(Get-RuleValue $Rule 'profiles')
    if (-not $profiles -or ($profiles | Where-Object { $_ -notin 1, 2, 4 })) { $errors += 'profiles must contain 1, 2 and/or 4' }
    if ($null -ne $protocol -and ($protocol -lt 0 -or $protocol -gt 255)) { $errors += 'protocol must be 0-255' }

    foreach ($field in 'localPortRanges', 'remotePortRanges') {
        $ports = @(Get-RuleValue $Rule $field)
        if (-not $ports) { continue }
        if ($protocol -notin 6, 17) { $errors += "$field requires protocol 6 (TCP) or 17 (UDP)" }
        foreach ($p in $ports) {
            if ("$p" -notmatch $portRx) { $errors += "$field '$p' is not a port or range (keywords like RPC are not supported)"; continue }
            foreach ($n in ("$p" -split '-')) { if ([int]$n -gt 65535) { $errors += "$field '$p' is out of range" } }
        }
    }
    if (@(Get-RuleValue $Rule 'icmpTypesAndCodes') -and $protocol -notin 1, 58) {
        $errors += 'icmpTypesAndCodes requires protocol 1 (ICMPv4) or 58 (ICMPv6)'
    }
    $app = Get-RuleValue $Rule 'appFilePath'
    if ($app -and $app -match '\*') { $errors += 'appFilePath must not contain *' }
    $errors | ForEach-Object { "Rule '$name': $_" }
}

function New-RuleGroupValue {
    param($Rule, [bool]$WithRefs)
    $children = @()
    $children += New-SimpleString -Suffix 'name' -Value $Rule.name -WithRefs $WithRefs
    $description = Get-RuleValue $Rule 'description'
    if ($description) { $children += New-SimpleString -Suffix 'description' -Value $description -WithRefs $WithRefs }

    $enabled = Get-RuleValue $Rule 'enabled'
    $children += New-Choice -Suffix 'enabled'     -Option $(if ($enabled -eq $false) { '0' } else { '1' }) -WithRefs $WithRefs
    $children += New-Choice -Suffix 'direction'   -Option $Rule.direction -WithRefs $WithRefs
    $children += New-Choice -Suffix 'action_type' -Option $(if ($Rule.action -eq 'allow') { '1' } else { '0' }) -WithRefs $WithRefs
    $children += New-ChoiceCollection -Suffix 'profiles' -Options @($Rule.profiles | ForEach-Object { "$_" }) -WithRefs $WithRefs

    $protocol = Get-RuleValue $Rule 'protocol'
    if ($null -ne $protocol) { $children += New-SimpleInt -Suffix 'protocol' -Value $protocol -WithRefs $WithRefs }

    $collections = [ordered]@{
        localPortRanges     = 'localportranges'
        remotePortRanges    = 'remoteportranges'
        localAddressRanges  = 'localaddressranges'
        remoteAddressRanges = 'remoteaddressranges'
        icmpTypesAndCodes   = 'icmptypesandcodes'
    }
    foreach ($key in $collections.Keys) {
        $values = @(Get-RuleValue $Rule $key | Where-Object { $_ })
        if ($values) { $children += New-SimpleCollection -Suffix $collections[$key] -Values $values -WithRefs $WithRefs }
    }

    $appFilePath = Get-RuleValue $Rule 'appFilePath'
    if ($appFilePath) { $children += New-SimpleString -Suffix 'app_filepath' -Value $appFilePath -WithRefs $WithRefs }
    $appServiceName = Get-RuleValue $Rule 'appServiceName'
    if ($appServiceName) { $children += New-SimpleString -Suffix 'app_servicename' -Value $appServiceName -WithRefs $WithRefs }

    $groupValue = [ordered]@{ children = $children }
    if ($WithRefs) {
        $groupValue.settingValueTemplateReference = @{ settingValueTemplateId = $GroupValueTemplateId; useTemplateDefault = $false }
    }
    $groupValue
}

#endregion

#region 1. Read and validate the rule file ---------------------------------------

if (-not (Test-Path $RuleFile)) { throw "Rule file not found: $RuleFile" }
$config = Get-Content -Path $RuleFile -Raw -Encoding UTF8 | ConvertFrom-Json
$rules  = @($config.rules)
if (-not $PolicyName) { $PolicyName = $config.policyName }
if (-not $PolicyName) { throw 'No policy name: set policyName in the rule file or use -PolicyName.' }

# Replace the %MANAGEMENT% token (accepts an array or a comma-separated string, e.g. from -File)
$ManagementAddress = @($ManagementAddress | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($rule in $rules) {
    $remote = @(Get-RuleValue $rule 'remoteAddressRanges')
    if ($remote -contains '%MANAGEMENT%') {
        $rule.remoteAddressRanges = @($remote | ForEach-Object { if ($_ -eq '%MANAGEMENT%') { $ManagementAddress } else { $_ } } | Select-Object -Unique)
    }
}

$problems = @()
if ($rules.Count -eq 0)   { $problems += 'The rule file contains no rules.' }
if ($rules.Count -gt 150) { $problems += "An Intune firewall rules policy supports up to 150 rules (file: $($rules.Count)). Split the file." }
$dupes = $rules | Group-Object { $_.name } | Where-Object Count -gt 1
if ($dupes) { $problems += "Duplicate rule names: $($dupes.Name -join ', ')" }
foreach ($rule in $rules) { $problems += @(Test-Rule -Rule $rule) }
if ($problems) { $problems | ForEach-Object { Write-Warning $_ }; throw "Rule file has $(@($problems).Count) problem(s)." }

#endregion

#region 2. Build the request body -------------------------------------------------

$isFirst = $true
$groupValues = @(foreach ($rule in $rules) {
    New-RuleGroupValue -Rule $rule -WithRefs $isFirst
    $isFirst = $false
})

$body = [ordered]@{
    name              = $PolicyName
    description       = [string]$config.policyDescription
    platforms         = 'windows10'
    technologies      = 'mdm,microsoftSense'
    templateReference = @{ templateId = $TemplateId }
    settings          = @(
        [ordered]@{
            '@odata.type'   = '#microsoft.graph.deviceManagementConfigurationSetting'
            settingInstance = [ordered]@{
                '@odata.type'                    = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                settingDefinitionId              = $DefBase
                settingInstanceTemplateReference = @{ settingInstanceTemplateId = $GroupInstanceTemplateId }
                groupSettingCollectionValue      = $groupValues
            }
        }
    )
}
$json = ConvertTo-Json -InputObject $body -Depth 30

if ($OutputJsonOnly) {
    $json
    return
}

#endregion

#region 3. Sign in ----------------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication

$scopes = @('DeviceManagementConfiguration.ReadWrite.All')
if ($AssignmentGroupName) { $scopes += 'Group.Read.All' }
$connectParams = @{ Scopes = $scopes; NoWelcome = $true }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Write-Step 'Connecting to Microsoft Graph'
Connect-MgGraph @connectParams
$ctx = Get-MgContext
if (-not $ctx -or -not $ctx.TenantId) { throw 'Not connected to Microsoft Graph.' }
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"

# A cached sign-in can silently land in the wrong tenant: confirm before changing anything
if (-not $SkipTenantConfirmation) {
    $answer = Read-Host "Create policy '$PolicyName' with $($rules.Count) rules in tenant $($ctx.TenantId) as $($ctx.Account)? [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Warning 'Aborted. Run Disconnect-MgGraph to sign in with another account, or use -TenantId.'
        return
    }
}

#endregion

#region 4. Create and assign -------------------------------------------------------

$escapedName = $PolicyName.Replace("'", "''")
$existing = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
    -Uri "$GraphBase/deviceManagement/configurationPolicies?`$filter=name eq '$escapedName'&`$select=id,name"
if (@($existing.value).Count -gt 0 -and -not $Force) {
    throw "A policy named '$PolicyName' already exists ($(@($existing.value)[0].id)). Use -PolicyName or -Force."
}

Write-Step "Creating policy '$PolicyName' with $($rules.Count) rules"
$policy = Invoke-MgGraphRequest -Method POST -OutputType PSObject `
    -Uri "$GraphBase/deviceManagement/configurationPolicies" -Body $json -ContentType 'application/json'
Write-Step "Policy created ($($policy.id))"

if ($AssignmentGroupName) {
    $escaped = $AssignmentGroupName.Replace("'", "''")
    $groups  = @((Invoke-MgGraphRequest -Method GET -OutputType PSObject `
        -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escaped'&`$select=id,displayName").value)
    if ($groups.Count -ne 1) { throw "Expected exactly one group named '$AssignmentGroupName', found $($groups.Count). Policy was created unassigned." }

    $assignBody = @{
        assignments = @(
            @{
                target = @{
                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                    groupId       = $groups[0].id
                }
            }
        )
    }
    Invoke-MgGraphRequest -Method POST -Uri "$GraphBase/deviceManagement/configurationPolicies('$($policy.id)')/assign" `
        -Body (ConvertTo-Json -InputObject $assignBody -Depth 10) -ContentType 'application/json' | Out-Null
    Write-Step "Assigned to '$AssignmentGroupName'"
}

Write-Host ''
Write-Host 'Done. Check: Intune admin center -> Endpoint security -> Firewall.' -ForegroundColor Green
[pscustomobject]@{
    PolicyId   = $policy.id
    PolicyName = $PolicyName
    Rules      = $rules.Count
    AssignedTo = $AssignmentGroupName
    TenantId   = $ctx.TenantId
}

#endregion
