---
title: 'Lab 3.5 – Find licensed apps nobody uses'
lab:
    title: 'Lab 3.5 – Find licensed apps nobody uses'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.5 – Find licensed apps nobody uses

**Estimated time:** 30 minutes, if time permits (optional)

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Measure app usage with two methods – Endpoint analytics for the whole tenant and your own remediation per device – and decide which licenses you could save.

**Why:** Intune has no software metering. Endpoint analytics knows usage but only for the whole tenant; a small remediation gives you a per-device view.

### Part 1 – Endpoint analytics

1. Copy the `Metering` folder from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) to CL3.
2. Open `LicensedApps.json`. Add one app you know runs on the course devices (for example `msedge.exe`) and one that doesn't.
3. Run the script and open both CSV files in Excel:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromEndpointAnalytics.ps1
   ```

4. Compare with Intune admin center → Reports → Endpoint analytics → Application reliability → **App performance**.

### Part 2 – Remediation sampler

1. Open `Remediation\Detect-AppUsageSampler.ps1`. Set `$Watchlist` to two apps, for example `@('notepad', 'mspaint')`.
2. Run it once on CL3 in an elevated PowerShell with Notepad open. The output shows `notepad=1@<today>`.
3. Create the remediation `etcX App usage sampler`:

   | Setting | Value |
   |---|---|
   | Detection script | `Detect-AppUsageSampler.ps1` |
   | Remediation script | none |
   | Run this script using the logged-on credentials | No |
   | Run script in 64-bit PowerShell | Yes |
   | Assignment | `studentXdevices`, schedule **Hourly** |

4. Sign in to CL3 as `etcX`, open Notepad. Devices → CL3-yourname → **Run remediation** → `etcX App usage sampler`.
5. When the device status shows a result, collect it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromRemediation.ps1 -RemediationName 'etcX App usage sampler'
   ```

### Checkpoint

- [ ] `LicensedAppUsage_*.csv` with one row per app in `LicensedApps.json`
- [ ] `RemediationAppUsage_*.csv` with a row for CL3-yourname and a count for Notepad
- [ ] You can explain why "NotInReport" is not proof that nobody uses an app

**Note:** Endpoint analytics lists an app only when it ran on more than 5 devices or more than 2% of enrolled devices, whichever is larger. In the course tenant most apps stay below that – that is part of the lesson.

**Note:** The sampler counts hourly checks where the app was running, not minutes. For launches per user, Defender for Endpoint advanced hunting is the better source (trainer demo, `AdvancedHunting.kql`).

<!-- VERIFY: Endpoint analytics data in the course tenant (enabled, enough devices) -->
<!-- VERIFY: Lab roles allow Run remediation (Remote tasks permission) and reading deviceRunStates -->
<!-- VERIFY: Graph consent for DeviceManagementManagedDevices.Read.All / DeviceManagementConfiguration.Read.All for participants -->
