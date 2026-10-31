# Software metering (draft)

Intune has no software metering like Configuration Manager. Three sources come close:

| Source | What you get | Needs | Limits |
|---|---|---|---|
| Endpoint analytics – Application reliability (`Get-AppUsageFromEndpointAnalytics.ps1`) | Per app, whole tenant, last 14 days: active devices and usage minutes (engagement time) | Endpoint analytics with data collection | No per-device or per-user view. An app is listed only with more than 5 active devices or more than 2% of enrolled devices, whichever is larger. |
| Remediation sampler (`Remediation/Detect-AppUsageSampler.ps1` + `Get-AppUsageFromRemediation.ps1`) | Per device, last 30 days: in how many hourly checks a watched app was running, last seen | Remediations licensing (Windows Enterprise E3/E5 or equivalent) | Samples, not minutes: an app opened and closed between two checks is not seen. Output max 2,048 characters. |
| Defender XDR advanced hunting (`AdvancedHunting.kql`) | Every process start with device, user and product version | Microsoft Defender for Endpoint | Launches, not minutes (no process end event). |

## Remediation sampler – setup

1. Edit `$Watchlist` in `Detect-AppUsageSampler.ps1` (process names without `.exe`).
2. Intune admin center → Devices → Scripts and remediations → Remediations → **Create**:

   | Setting | Value |
   |---|---|
   | Detection script | `Detect-AppUsageSampler.ps1` |
   | Remediation script | none |
   | Run this script using the logged-on credentials | No |
   | Enforce script signature check | No |
   | Run script in 64-bit PowerShell | Yes |
   | Schedule | Hourly, every 1 hour |

3. Collect the results:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromRemediation.ps1 -RemediationName '<name>'
   ```

The sampler keeps its counts in `C:\ProgramData\MDDMI-Adv\AppUsage\state.json`. Delete the file to start over.

## Sources

- [Application reliability report](https://learn.microsoft.com/intune/endpoint-analytics/app-reliability)
- [userExperienceAnalyticsAppHealthApplicationPerformance (Graph v1.0)](https://learn.microsoft.com/graph/api/resources/intune-devices-userexperienceanalyticsapphealthapplicationperformance?view=graph-rest-1.0)
- [deviceHealthScriptDeviceState (Graph beta)](https://learn.microsoft.com/graph/api/resources/intune-devices-devicehealthscriptdevicestate?view=graph-rest-beta)
- [Device query: `Process` table is single-device and current state only](https://learn.microsoft.com/intune/advanced-analytics/ref-data-platform-schema)
- [DeviceProcessEvents](https://learn.microsoft.com/defender-xdr/advanced-hunting-deviceprocessevents-table)
