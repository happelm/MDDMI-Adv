---
title: 'Lab 3.2 – Export reports with Graph and Power BI'
lab:
    title: 'Lab 3.2 – Export reports with Graph and Power BI'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.2 – Export reports with Graph and Power BI

**Estimated time:** 40 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Export Intune reports with Graph – including the remediation results from Lab 3.1 – and answer a compliance question with the Data Warehouse in Power BI Desktop.

1. In Windows PowerShell in `C:\Toolbox\Reports` (from Lab 0.1, source: [Toolbox/Graph/Reports](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Reports)), list the presets:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -ListPresets
   ```

   A preset is a ready-made request from `ReportPresets.json`: the exact `reportName`, a fixed column list and, where the report needs one, a filter with a placeholder for `-PolicyId` or `-ApplicationId`. The script also exports any other report from the Learn list with `-ReportName` and `-Select`.

   Export the compliance state and the results of your remediation from Lab 3.1. For the remediation ID open Devices → Scripts and remediations → Remediations → `etcX-Registry` (the remediation, not the compliance policy): the browser address bar contains `/id/<GUID>/` – copy the GUID after `id/`.

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -Command "& .\Export-IntuneReport.ps1 -Preset DeviceCompliance -PassThru | Out-GridView -Wait"
   PowerShell.exe -ExecutionPolicy Bypass -Command "& .\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <remediation ID> -PassThru | Out-GridView -Wait"
   ```

   `-PassThru` hands the rows to the grid (no Excel on CL3); the CSV files are saved in `.\ReportExports` as well. Close the grid to get the prompt back. Type `CL3-` or your name in the **Filter** box: compliance state **Compliant**, remediation **Issue fixed** with pre- and post-detection output. If the remediation grid is still empty, the per-device data hasn't arrived yet – run that export again at the end of the lab.

2. Install status of your 7-Zip app from Lab 1.3 (app ID from the browser address bar):

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -Command "& .\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <app ID> -PassThru | Out-GridView -Wait"
   ```

3. Install Power BI Desktop on CL3, in an elevated PowerShell:

   ```powershell
   winget install --id Microsoft.PowerBI --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

4. Intune admin center → Reports → Intune Data warehouse → **Data warehouse**: copy the OData feed URL.
5. Power BI Desktop → Home → Get data → **Blank query** → Advanced Editor: paste `C:\Toolbox\Reports\DataWarehouse\ComplianceTrend.pq`, set `FeedUrl` to the feed URL without `?api-version=...`, **Done**. Sign in with **Organizational account** (your `etcX`), then **Close & Apply**.
6. Report view: add a **Line chart** with `Date` on the X-axis and `compliant` and `nonCompliant` as values. Compare: which question does each tool answer best?

### Checkpoint

- [ ] Three exports in `.\ReportExports`: compliance, remediation results, app install status
- [ ] Compliance trend line chart in Power BI Desktop
- [ ] You can name one question per tool

**Note:** Graph can't be a Power Query data source – that is why Power BI uses the Data Warehouse OData feed. The same `.pq` files also work in Excel (Data → Get Data → From Other Sources → Blank Query).

<!-- VERIFY: "Intune data warehouse" and report permissions in the Lab roles -->
<!-- VERIFY: winget ID Microsoft.PowerBI installs Power BI Desktop on CL3; menu labels Get data / Blank query / Close & Apply and the Organizational account prompt in the current Power BI Desktop -->
<!-- 2026-11-22: dashboard part moved to Lab 3.1 Prove; remediation export moved here from Lab 3.1. -->
