# Labfiles

| File | Lab | Purpose |
|---|---|---|
| `Deploy-RemoteHelpUnattendedApps.ps1` | Trainer prep | Creates the Win32 apps Azure Virtual Desktop Agent and Agent Bootloader (prerequisites for Remote Help unattended control on Windows) in the tenant of the signed-in admin, with the dependency Bootloader → Agent and an optional Required assignment (`-AssignmentGroupName`). Run: `PowerShell.exe -ExecutionPolicy Bypass -File .\Deploy-RemoteHelpUnattendedApps.ps1` |

