# Labfiles

All scripts sign in interactively and use the tenant of the signed-in admin. Scripts that change the tenant ask for confirmation and support `-WhatIf` where noted. Status **draft**: not yet used in a lab.

Run a script with `PowerShell.exe -ExecutionPolicy Bypass -File .\<script>.ps1 <parameters>`.

## Enrollment

| File | Purpose | Example |
|---|---|---|
| `Enrollment/Autoenroll.ps1` | Lab 0.1 fallback when MDM auto-enrollment did not run after the Entra join: sets the Intune enrollment URLs and enrolls the device as corporate device. Run elevated on the client. | `PowerShell.exe -ExecutionPolicy Bypass -File .\Autoenroll.ps1` |

## Compliance (draft)

| File | Purpose | Example |
|---|---|---|
| `Compliance/Test-CustomCompliance.ps1` | Runs a Windows custom compliance discovery script locally, checks that it returns one JSON line with every setting of the rules file, and evaluates each rule (approximation of the Intune evaluation). Lab 3.1. Use with the [Custom compliance builder](https://happelm.github.io/MDDMI-Adv/Tools/compliance-builder.html). | `.\Test-CustomCompliance.ps1 -ScriptPath .\etcX-Custom-Discovery.ps1 -RulesPath .\etcX-Custom-Rules.json` |

## Linux compliance (draft)

| File | Purpose | Example |
|---|---|---|
| `LinuxCompliance/etcX-LinuxDiscovery.sh` | Lab 3.3 custom compliance discovery script for RHEL: reports whether `firewalld` is running and the installed Microsoft Edge version as JSON. Runs in the user's context. | `bash ./etcX-LinuxDiscovery.sh` |
| `LinuxCompliance/etcX-LinuxRules.json` | Rules file for the script: firewall must run, Edge 102.0 or later, with remediation text for the Intune app. | |

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

## Win32 app pipeline (draft)

| File | Purpose | Example |
|---|---|---|
| `Win32Pipeline/New-IntuneWin32AppFromFolder.ps1` | Packages an app folder (`C:\Software\<App>` with `app.json` and `Source\`) and creates the Win32 app in Intune: upload, detection, return codes, optional assignment. Works with MSI, EXE and PSADT packages. `-PackageOnly` shows the request body without changes. See the folder README. | `.\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly` |
| `Win32Pipeline/Samples/` | `app.json` samples: 7-Zip (MSI) and Firefox ESR (PSADT v4, as in the SCMI course). | |

## Custom reports (draft)

| File | Purpose | Example |
|---|---|---|
| `Reports/Export-IntuneReport.ps1` | Exports an Intune report via Graph `exportJobs` (preset or any reportName) and saves a CSV that Excel opens with columns. | `.\Export-IntuneReport.ps1 -Preset Devices` |
| `Reports/Get-IntuneDashboard.ps1` | Reads managed devices (and the discovered versions of one app) via Graph and writes one HTML dashboard with charts (Chart.js). Lab 3.2, optional part. | `.\Get-IntuneDashboard.ps1 -App '7-Zip'` |
| `Reports/ReportPresets.json` | Presets: devices, compliance, compliance trend, devices without compliance policy, app install status, Remediation results, feature update state. | |
| `Reports/DataWarehouse/*.pq` | Power Query queries for Excel on the Intune Data Warehouse OData feed: compliance trend (30 days), device list for pivots. See `Reports/README.md`. | |

## Software metering (draft)

| File | Purpose | Example |
|---|---|---|
| `Metering/Get-AppUsageFromDefender.ps1` | Counts launches of the apps in `LicensedApps.json` with a Defender advanced hunting query through Graph and compares users with licenses. Needs Defender for Endpoint. Read-only. | `.\Get-AppUsageFromDefender.ps1 -Days 14` |
| `Metering/LicensedApps.json` | Licensed apps (executable name, number of licenses). | |
| `Metering/AdvancedHunting.kql` | The same queries for the Defender portal, plus a top-apps discovery query. | |

See `Metering/README.md`.
