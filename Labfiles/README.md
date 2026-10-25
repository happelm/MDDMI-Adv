# Labfiles

All scripts sign in interactively and use the tenant of the signed-in admin. Scripts that change the tenant ask for confirmation and support `-WhatIf` where noted. Status **draft**: not yet used in a lab.

Run a script with `PowerShell.exe -ExecutionPolicy Bypass -File .\<script>.ps1 <parameters>`.

## Remote Help (trainer prep)

| File | Purpose | Example |
|---|---|---|
| `RemoteHelp/Deploy-RemoteHelpUnattendedApps.ps1` | Creates the Win32 apps Azure Virtual Desktop Agent and Agent Bootloader (prerequisites for Remote Help unattended control on Windows), with the dependency Bootloader → Agent and an optional Required assignment. | `.\Deploy-RemoteHelpUnattendedApps.ps1 -AssignmentGroupName "<group>"` |

## Firewall (draft)

| File | Purpose | Example |
|---|---|---|
| `Firewall/New-IntuneFirewallRulePolicy.ps1` | Creates an endpoint security **Windows Firewall Rules** policy from a JSON rule file. Preview the request body with `-OutputJsonOnly`. | `.\New-IntuneFirewallRulePolicy.ps1 -ManagementAddress LocalSubnet` |
| `Firewall/DomainProfileRules.json` | Inbound management exceptions for hybrid joined devices in the domain profile, modeled on the built-in rule groups usually enabled by GPO. Default rule file of the script. | |
| `Firewall/RuleCatalog.json` | Rule groups and validation patterns for the [Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Tools/firewall-rule-builder.html). Same rule format as `DomainProfileRules.json`. | |

## Assignments (draft, read-only)

| File | Purpose | Example |
|---|---|---|
| `Assignments/Get-IntunePolicyAssignmentsByGroup.ps1` | Reverse lookup. Group view: every Intune object that includes or excludes a group, directly, through parent groups or policy sets. Device or user view (`-DeviceName`, `-UserPrincipalName`): everything that targets the device or user through any of its groups (assigned and dynamic) and All devices / All users. | `.\Get-IntunePolicyAssignmentsByGroup.ps1 -DeviceName "CL5" -ExportCsv` |
| `Assignments/Find-UnassignedIntuneObjects.ps1` | Lists Intune objects that apply to nobody: no assignment, exclusions only, or only deleted groups. Also flags assignments to deleted groups and shows scope tags. | `.\Find-UnassignedIntuneObjects.ps1 -ExportCsv` |

## Naming (draft)

| File | Purpose | Example |
|---|---|---|
| `Naming/Rename-IntunePolicies.ps1` | Bulk rename of Intune objects by prefix (`-OldPrefix`/`-NewPrefix`) or regex (`-Find`/`-Replace`), filtered by `-ObjectType`. `-WhatIf`, CSV log, undo with `-UndoCsv`. | `.\Rename-IntunePolicies.ps1 -OldPrefix '[Pilot] ' -NewPrefix '[Prod] ' -WhatIf` |

## Remediations (draft)

| File | Purpose | Example |
|---|---|---|
| `Remediations/SsoPrompt/` | Detection and remediation script that set `AutoAcceptSsoPermission` = 1 so the Windows SSO prompt ("Continue to sign in?") is accepted on managed devices. See the folder README. | Upload as a Remediation |

## Hybrid join (draft)

| File | Purpose | Example |
|---|---|---|
| `HybridJoin/Set-HybridJoinSCP.ps1` | Creates or updates the service connection point for Microsoft Entra hybrid join in the current forest (needed with Entra Cloud Sync device sync). Shows the current values first, protects an SCP of another tenant (`-Force`), supports `-WhatIf`. Without `-TenantId`/`-Domain` it reads both from Graph. Run as Enterprise Admin. | `.\Set-HybridJoinSCP.ps1 -WhatIf` |
