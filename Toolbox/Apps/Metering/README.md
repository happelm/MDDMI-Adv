# Software metering with Defender for Endpoint (draft)

Intune has no software metering like Configuration Manager. This course uses one method: Microsoft Defender for Endpoint (MDE) records every process start in the advanced hunting table `DeviceProcessEvents`. A KQL query counts launches of the apps you pay for.

**Prerequisite:** devices onboarded to Defender for Endpoint. Microsoft 365 E5 includes Defender for Endpoint Plan 2.

| File | Purpose |
|---|---|
| `AdvancedHunting.kql` | Queries for the Defender portal: per app, per device, top apps (discovery). |
| `Get-AppUsageFromDefender.ps1` | Runs the query through Graph (`POST /security/runHuntingQuery`, scope `ThreatHunting.Read.All`) for the apps in `LicensedApps.json` and exports a CSV with launches, devices, users and licenses not used. `-PerDevice` for one row per device and app. |
| `LicensedApps.json` | Licensed apps: executable name and number of licenses. |

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1
PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -Days 14 -PerDevice
PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -ShowQuery
```

## What it measures and what not

- Launches, not minutes of use: there is no process end event.
- 30 days: advanced hunting keeps 30 days of Defender data. For longer periods export the result regularly, or stream the table to Microsoft Sentinel.
- Only onboarded devices. Devices without MDE are invisible – an app with 0 launches may still be used there.
- No user names by default: users are counted (`dcount`). `-IncludeUserNames` adds them to the per-device export – clear this with data protection and, where it applies, the works council first.

## Sources

- [runHuntingQuery (Graph v1.0)](https://learn.microsoft.com/graph/api/security-security-runhuntingquery?view=graph-rest-1.0)
- [DeviceProcessEvents](https://learn.microsoft.com/defender-xdr/advanced-hunting-deviceprocessevents-table)
- [Advanced hunting quotas: 30 days, 100,000 rows, 10 minutes](https://learn.microsoft.com/defender-xdr/advanced-hunting-overview#quotas-and-usage-parameters)
- [Microsoft 365 E5 includes Defender for Endpoint Plan 2](https://learn.microsoft.com/defender-endpoint/discover-local-ai-agents#licensing)
- [Defender for Endpoint data retention](https://learn.microsoft.com/defender-endpoint/data-storage-privacy#data-retention)
