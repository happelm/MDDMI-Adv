---
title: 'Lab 3.3 – Find unused licenses and stale devices'
lab:
    title: 'Lab 3.3 – Find unused licenses and stale devices'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.3 – Find unused licenses and stale devices

**Estimated time:** 45 minutes

**Goal:** Count launches of licensed apps with Defender for Endpoint advanced hunting, first in the portal, then with a script. Then compare the Intune and Entra ID device lists and find devices that are only in one of them or haven't been seen for a while.

**Why:** Intune has no software metering. Defender for Endpoint records every process start, so a KQL query shows which licensed apps are started, on how many devices and by how many users. Intune and Entra ID keep separate device objects, and no admin center view joins them – stale or orphaned objects show up only when you compare both lists.

## Part A – Licensed apps nobody uses

1. On CL3, start Notepad a few times and close it again. Do the same on CL4.
2. Microsoft Defender portal → Hunting → **Advanced hunting**. Paste query 1 and run it. It counts launches, devices and users per licensed app:

   ```text
   let Watchlist = dynamic(["visio.exe", "winproj.exe", "msaccess.exe", "acrobat.exe", "notepad++.exe", "notepad.exe"]);
   DeviceProcessEvents
   | where Timestamp > ago(30d)
   | extend App = tolower(FileName)
   | where App in (Watchlist)
   | where tolower(InitiatingProcessFileName) != App   // a program that starts copies of itself counts once
   | summarize Launches = count(), Devices = dcount(DeviceId), Users = dcount(AccountObjectId), LastLaunch = max(Timestamp) by App
   | order by Launches desc
   ```

   Clear the query box, paste query 2 and run it. Find your devices:

   ```text
   let Watchlist = dynamic(["visio.exe", "winproj.exe", "msaccess.exe", "acrobat.exe", "notepad++.exe", "notepad.exe"]);
   DeviceProcessEvents
   | where Timestamp > ago(30d)
   | extend App = tolower(FileName)
   | where App in (Watchlist)
   | where tolower(InitiatingProcessFileName) != App
   | summarize Launches = count(), LastLaunch = max(Timestamp) by DeviceName, App
   | order by App asc, LastLaunch desc
   ```

   Both queries, plus a discovery query for the top apps, are also in `AdvancedHunting.kql` in [Toolbox/Apps/Metering](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Apps/Metering).
3. On CL3, open `C:\Toolbox\Metering\LicensedApps.json` and set `licenses` for Notepad to `10`.
4. Open Windows PowerShell in `C:\Toolbox\Metering`. Show the query the script will run, then run it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -ShowQuery
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -Days 1
   ```

5. Open the newest CSV in a grid. Run the script again with `-PerDevice` and compare:

   ```powershell
   $csv = Get-ChildItem .\AppUsage\*.csv | Sort-Object LastWriteTime | Select-Object -Last 1
   Import-Csv -Path $csv.FullName -Delimiter (Get-Culture).TextInfo.ListSeparator | Out-GridView
   ```

## Part B – Devices in Intune and Entra ID

6. In Windows PowerShell in `C:\Toolbox\Devices`, read the help, then compare both device lists. The script only reads (GET) and writes a CSV to the current folder:

   ```powershell
   Get-Help .\Compare-IntuneEntraDevices.ps1 -Full
   PowerShell.exe -ExecutionPolicy Bypass -File .\Compare-IntuneEntraDevices.ps1 -StaleDays 30
   ```

   The summary shows how many devices are **Matched**, **Intune only**, **Entra only, MDM** and **Entra only**, and how many carry each flag.

7. Open the result in a grid and filter it:

   ```powershell
   Import-Csv -Path .\IntuneEntraDeviceComparison.csv -Delimiter ';' | Out-GridView
   ```

   Find your CL3 and CL4 (status and flags), then pick one device that is not **Matched** or carries the flag **Stale** and explain why it is listed.


### Checkpoint

- [ ] Query 1 shows `notepad.exe` with at least two devices
- [ ] `DefenderAppUsage_*.csv` with one row per app in `LicensedApps.json` and a value in **LicensesNotUsed** for Notepad
- [ ] You can explain why the default output counts users but shows no user names
- [ ] `C:\Toolbox\Devices\IntuneEntraDeviceComparison.csv` with your CL3 and CL4 as **Matched**
- [ ] You can explain one device that is not **Matched** or is flagged **Stale**

**Note:** New events can take a while to show up in advanced hunting. If Notepad doesn't appear yet, continue and run the query again later.

**Note:** The query counts launches, not minutes of use, and sees only devices onboarded to Defender for Endpoint. Advanced hunting keeps 30 days of data.

<!-- Tested by Michael 2026-11-22 (Part B): Compare-IntuneEntraDevices.ps1 runs with a participant account. -->
<!-- Tested 2026-11-22 (Part A): devices onboarded to MDE; participants need a Defender unified RBAC role (Endpoint workload active, 'execute query actions' selected) for advanced hunting; Graph consent for ThreatHunting.Read.All works; Notepad launches showed up within minutes. -->
