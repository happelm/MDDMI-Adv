---
title: 'Lab 3.5 – Find licensed apps nobody uses'
lab:
    title: 'Lab 3.5 – Find licensed apps nobody uses'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.5 – Find licensed apps nobody uses

**Estimated time:** 30 minutes, if time permits (optional)

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Count launches of licensed apps with Defender for Endpoint advanced hunting, first in the portal, then with a script.

**Why:** Intune has no software metering. Defender for Endpoint records every process start, so a KQL query shows which licensed apps are started, on how many devices and by how many users.

1. On CL3, start Notepad a few times and close it again. Do the same on CL4.
2. Microsoft Defender portal → Hunting → **Advanced hunting**. Paste query 1 from `AdvancedHunting.kql` in the `Metering` folder of the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) and run it. Then run query 2 and find your devices.
3. Copy the `Metering` folder to CL3. Open `LicensedApps.json` and set `licenses` for Notepad to `10`.
4. Show the query the script will run, then run it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -ShowQuery
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-AppUsageFromDefender.ps1 -Days 1
   ```

5. Open the CSV in Excel. Run the script again with `-PerDevice` and compare.

### Checkpoint

- [ ] Query 1 shows `notepad.exe` with at least two devices
- [ ] `DefenderAppUsage_*.csv` with one row per app in `LicensedApps.json` and a value in **LicensesNotUsed** for Notepad
- [ ] You can explain why the default output counts users but shows no user names

**Note:** New events can take a while to show up in advanced hunting. If Notepad doesn't appear yet, continue and run the query again later.

**Note:** The query counts launches, not minutes of use, and sees only devices onboarded to Defender for Endpoint. Advanced hunting keeps 30 days of data.

<!-- VERIFY: CL3/CL4 onboarded to MDE in the course tenant -->
<!-- VERIFY: Lab roles can open advanced hunting in the Defender portal -->
<!-- VERIFY: Graph consent for ThreatHunting.Read.All for participants -->
<!-- VERIFY: delay until process events appear in advanced hunting -->
