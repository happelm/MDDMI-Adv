# Labfiles

| File | Lab | Purpose |
|---|---|---|
| `Deploy-RemoteHelpUnattendedApps.ps1` | Trainer prep | Creates the Win32 apps Azure Virtual Desktop Agent and Agent Bootloader (prerequisites for Remote Help unattended control on Windows) in the tenant of the signed-in admin, with the dependency Bootloader → Agent and an optional Required assignment (`-AssignmentGroupName`). Run: `PowerShell.exe -ExecutionPolicy Bypass -File .\Deploy-RemoteHelpUnattendedApps.ps1` |
| `Firewall/New-IntuneFirewallRulePolicy.ps1`, `Firewall/DomainProfileRules.json` | Scripting (draft) | Creates an endpoint security **Windows Firewall Rules** policy from a JSON rule file via Graph. `DomainProfileRules.json`: inbound management exceptions for hybrid joined devices in the domain profile, modeled on the built-in rule groups usually enabled by GPO. Preview the request body with `-OutputJsonOnly`. Run: `PowerShell.exe -ExecutionPolicy Bypass -File .\New-IntuneFirewallRulePolicy.ps1 -ManagementAddress LocalSubnet` |
| `Firewall/RuleCatalog.json` | Scripting (draft) | Rule groups and validation patterns for the [Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Tools/firewall-rule-builder.html). Same rule format as `DomainProfileRules.json`. |

