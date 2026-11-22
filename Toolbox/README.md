# Toolbox

Everything you use in the labs and can take home afterwards: PowerShell scripts, sample files and browser-based builders, sorted by area. The labs link to the folder they need.

| Folder | What is in it |
|---|---|
| [Builders](Builders) | Web pages that generate a script or rule file for you – no sign-in, nothing leaves your browser |
| [Graph](Graph) | Read and change Intune with Microsoft Graph: assignments, naming, documentation, devices, reports |
| [Apps](Apps) | Win32 app pipeline, software metering, Remote Help prerequisites |
| [Security](Security) | Firewall rules as code, custom compliance (Windows and Linux) |
| [Identity](Identity) | Enrollment fallback, hybrid join SCP, Windows SSO prompt remediation |

All scripts sign in interactively and use the tenant of the signed-in admin. Scripts that change the tenant ask for confirmation and support `-WhatIf` where noted. Status **draft**: not yet used in a lab.

## Run a script

1. Download the folder or the script (open it on GitHub, **Download raw file**) to `C:\Toolbox\<folder>`, for example `C:\Toolbox\Assignments`.
2. Open Windows PowerShell (not elevated unless noted) in that folder. The scripts install the module `Microsoft.Graph.Authentication` for your account if it is missing.
3. Run the script and sign in with an admin account of your tenant. The first run asks for consent to the permissions.

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\<script>.ps1 <parameters>
```

Every script has help with all parameters: `Get-Help .\<script>.ps1 -Full`. CSV files use the delimiter `;` and UTF-8, so Excel with German regional settings opens them directly.

## Builders

| Page | Purpose |
|---|---|
| [Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/firewall-rule-builder.html) (draft) | Pick firewall rule groups and add custom rules; builds the rule file for `Security/Firewall/New-IntuneFirewallRulePolicy.ps1`. Lab 2.1. |
| [Custom compliance builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/compliance-builder.html) (draft) | Pick checks for Windows devices; builds the discovery script and the JSON rules file for a custom compliance policy. Lab 3.1. |
| [Dashboard builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/dashboard-builder.html) (draft) | Pick tiles, charts and tables; builds a read-only PowerShell script that reads Intune data from Graph and writes one HTML dashboard. Lab 3.2 (Dashboard part). |
| [Remediation builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/remediation-builder.html) (draft) | Pick checks for Windows devices (registry, services, scheduled tasks, optional features, files); builds the detection and remediation script pair and recommends the package settings. Lab 3.1. |

## Graph

| File | Lab | Purpose | Example |
|---|---|---|---|
| `Assignments/Get-IntunePolicyAssignmentsByGroup.ps1` | 1.1 | Reverse lookup, read-only. Group view: every Intune object that includes or excludes a group – policies, apps, scripts, enrollment profiles – directly, through parent groups or policy sets. Device or user view (`-DeviceName`, `-UserPrincipalName`): everything that targets the device or user through any of its groups and All devices / All users. | `.\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName 'All Windows 11 Devices' -IncludeAllUsersAllDevices -ExportCsv -OutputFolder 'C:\Temp'` |
| `Assignments/Find-UnassignedIntuneObjects.ps1` | 1.1 | Read-only. Intune objects that apply to nobody: no assignment, exclusions only, or only deleted groups. Also flags assignments to deleted groups and shows scope tags. | `.\Find-UnassignedIntuneObjects.ps1 -ExportCsv` |
| `Naming/Rename-IntunePolicies.ps1` | 1.2 | Bulk rename of Intune objects by prefix (`-OldPrefix`/`-NewPrefix`) or regex (`-Find`/`-Replace`), filtered by `-ObjectType`. `-WhatIf`, CSV log, undo with `-UndoCsv`. | `.\Rename-IntunePolicies.ps1 -OldPrefix '[Pilot] ' -NewPrefix '[Prod] ' -WhatIf` |
| `Documentation/Export-IntunePolicyDocumentation.ps1` | – | Read-only. Every settings catalog policy with its configured settings and assignments as HTML and CSV in `C:\Temp\IntuneDocumentation`. The portal has no export. | `.\Export-IntunePolicyDocumentation.ps1` |
| `Devices/Compare-IntuneEntraDevices.ps1` | 3.3 | Read-only. Joins the Intune and Entra ID device lists: devices only in one of them, stale, disabled, different compliance state. CSV in `C:\Temp`. | `.\Compare-IntuneEntraDevices.ps1 -StaleDays 90` |
| `Reports/Export-IntuneReport.ps1` | 3.1, 3.2 | Exports an Intune report via Graph `exportJobs` (preset or any reportName) and saves a CSV that Excel opens with columns. | `.\Export-IntuneReport.ps1 -Preset Devices` |
| `Reports/ReportPresets.json` | 3.1, 3.2 | Presets: devices, compliance, compliance trend, devices without compliance policy, app install status, Remediation results, feature update state. | |
| `Reports/Get-IntuneDashboard.ps1` | 3.2 | Reads managed devices (and the discovered versions of one app) and writes one HTML dashboard with charts (Chart.js). | `.\Get-IntuneDashboard.ps1 -App '7-Zip'` |
| `Reports/DataWarehouse/*.pq` | 3.2 | Power Query queries for Excel on the Intune Data Warehouse OData feed: compliance trend (30 days), device list for pivots. See `Reports/README.md`. | |

## Apps

| File | Lab | Purpose | Example |
|---|---|---|---|
| `Win32Pipeline/New-IntuneWin32AppFromFolder.ps1` | 1.3, 1.5, 1.6 | Packages an app folder (`C:\Software\<App>` with `app.json` and `Source\`) and creates the Win32 app in Intune: upload, detection, return codes, optional assignment. Works with MSI, EXE and PSADT packages. `-PackageOnly` shows the request body without changes. See the folder README. | `.\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly` |
| `Win32Pipeline/Samples/` | 1.3, 1.5, 1.6 | `app.json` samples: 7-Zip (MSI, Lab 1.3), VLC (setup.exe, Lab 1.5) and Firefox ESR (PSADT v4 with `policies.json`, Lab 1.6). | |
| `Metering/Get-AppUsageFromDefender.ps1` | 3.3 | Counts launches of the apps in `LicensedApps.json` with a Defender advanced hunting query through Graph and compares users with licenses. Needs Defender for Endpoint. Read-only. See `Metering/README.md`. | `.\Get-AppUsageFromDefender.ps1 -Days 14` |
| `Metering/LicensedApps.json` | 3.3 | Licensed apps (executable name, number of licenses). | |
| `Metering/AdvancedHunting.kql` | 3.3 | The same queries for the Defender portal, plus a top-apps discovery query. | |
| `RemoteHelp/Deploy-RemoteHelpUnattendedApps.ps1` | trainer prep, read in 2.5 | Creates the Win32 apps Azure Virtual Desktop Agent and Agent Bootloader (prerequisites for Remote Help unattended control on Windows), with the dependency Bootloader → Agent and an optional Required assignment. | `.\Deploy-RemoteHelpUnattendedApps.ps1 -AssignmentGroupName "<group>"` |

## Security

| File | Lab | Purpose | Example |
|---|---|---|---|
| `Firewall/New-IntuneFirewallRulePolicy.ps1` | 2.1 | Creates an endpoint security **Windows Firewall Rules** policy from a JSON rule file. Preview the request body with `-OutputJsonOnly`. | `.\New-IntuneFirewallRulePolicy.ps1 -ManagementAddress LocalSubnet` |
| `Firewall/DomainProfileRules.json` | 2.1 | Inbound management exceptions for hybrid joined devices in the domain profile, modeled on the built-in rule groups usually enabled by GPO. Default rule file of the script. | |
| `Firewall/RuleCatalog.json` | 2.1 | Rule groups and validation patterns for the Firewall rule builder. Same rule format as `DomainProfileRules.json`. | |
| `Compliance/Test-CustomCompliance.ps1` | 3.1 | Runs a Windows custom compliance discovery script locally, checks that it returns one JSON line with every setting of the rules file, and evaluates each rule (approximation of the Intune evaluation). Use with the Custom compliance builder. | `.\Test-CustomCompliance.ps1 -ScriptPath .\etcX-Custom-Discovery.ps1 -RulesPath .\etcX-Custom-Rules.json` |
| `Compliance/etcX-LinuxDiscovery.sh` | 3.4 | Custom compliance discovery script for RHEL: reports whether `firewalld` is running and the installed Microsoft Edge version as JSON. Runs in the user's context. | `bash ./etcX-LinuxDiscovery.sh` |
| `Compliance/etcX-LinuxRules.json` | 3.4 | Rules file for the Linux script: firewall must run, Edge 102.0 or later, with remediation text for the Intune app. | |

## Identity

| File | Lab | Purpose | Example |
|---|---|---|---|
| `Enrollment/Autoenroll.ps1` | 0.1 | Fallback when MDM auto-enrollment did not run after the Entra join: sets the Intune enrollment URLs and enrolls the device as corporate device. Run elevated on the client. | `PowerShell.exe -ExecutionPolicy Bypass -File .\Autoenroll.ps1` |
| `HybridJoin/Set-HybridJoinSCP.ps1` | – | Creates or updates the service connection point for Microsoft Entra hybrid join in the current forest (needed with Entra Cloud Sync device sync). Shows the current values first, protects an SCP of another tenant (`-Force`), supports `-WhatIf`. Without `-TenantId`/`-Domain` it reads both from Graph. Run as Enterprise Admin. | `.\Set-HybridJoinSCP.ps1 -WhatIf` |
| `SsoPrompt/` | – | Detection and remediation script that set `AutoAcceptSsoPermission` = 1 so the Windows SSO prompt ("Continue to sign in?") is accepted on managed devices. See the folder README. | Upload as a Remediation |

## Written with AI – checked by a human

The Graph scripts in this Toolbox were written with an AI assistant and then checked: every Graph URL against the Microsoft Graph reference and against a real tenant, read scopes only, paging over `@odata.nextLink`. Do the same before you trust a script that an AI writes for you:

- [ ] Only `GET` requests – search the script for `POST`, `PATCH`, `PUT`, `DELETE`, `Remove-`, `Set-`, `New-`.
- [ ] Only `Read` scopes in `Connect-MgGraph`, none ending in `ReadWrite`.
- [ ] Every Graph URL exists: `Find-MgGraphCommand -Uri '<url>' -Method GET` or the Graph reference on Microsoft Learn – `v1.0` or `beta`, property names in `$select` and `$filter`.
- [ ] Paging: the script follows `@odata.nextLink` (or uses `-All`). Without it, it silently stops after the first page.
- [ ] Result checked against the portal for at least one device, policy or group.

**Note:** The scripts run with your permissions. Your Intune role and scope tags decide what Graph returns.
