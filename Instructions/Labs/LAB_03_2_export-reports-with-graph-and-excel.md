---
title: 'Lab 3.2 – Export reports with Graph and Power BI'
lab:
    title: 'Lab 3.2 – Export reports with Graph and Power BI'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.2 – Export reports with Graph and Power BI

**Estimated time:** 55 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Answer the same compliance question with a Graph export and with the Data Warehouse in Power BI Desktop – and as charts on a single HTML page.

1. In Windows PowerShell in `C:\Toolbox\Reports` (from Lab 0.1, source: [Toolbox/Graph/Reports](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Reports)), list the presets and export compliance:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -ListPresets
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset DeviceCompliance
   ```

   A preset is a ready-made request from `ReportPresets.json`: the exact `reportName`, a fixed column list and, where needed, a filter with a placeholder for `-PolicyId` or `-ApplicationId`. Any other report from the Learn list works with `-ReportName` and `-Select`.

   Open the newest CSV in Excel, or in a grid and type `CL3-` or your name in the **Filter** box:

   ```powershell
   $csv = Get-ChildItem .\ReportExports\*.csv | Sort-Object LastWriteTime | Select-Object -Last 1
   Import-Csv -Path $csv.FullName -Delimiter (Get-Culture).TextInfo.ListSeparator | Out-GridView
   ```

2. Results of your remediation from Lab 3.1. Get the ID of the **remediation** `etcX-Registry` (not of the compliance policy): Devices → Scripts and remediations → Remediations → select `etcX-Registry`. The browser address bar now contains `/id/<GUID>/` – copy the GUID after `id/`.

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <remediation ID>
   ```

   Open the result in Excel – the script prints the path after `Excel :`, or:

   ```powershell
   Get-ChildItem .\ReportExports\RemediationResults_*.csv | Where-Object Name -notlike '*_raw.csv' | Sort-Object LastWriteTime | Select-Object -Last 1 | Invoke-Item
   ```

   CL3 shows **Issue fixed** with pre- and post-detection output. If the file is empty, the per-device data hasn't arrived yet (see Lab 3.1) – run the export again at the end of the lab.

3. Install status of your 7-Zip app from Lab 1.3. For the app ID open Apps → Windows → your 7-Zip app: the GUID after `appId/` in the browser address bar.

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <app ID>
   ```

4. Install Power BI Desktop on CL3, in an elevated PowerShell:

   ```powershell
   winget install --id Microsoft.PowerBI --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

5. Intune admin center → Reports → Intune Data warehouse → **Data warehouse**: copy the OData feed URL.
6. Power BI Desktop → Home → Get data → **Blank query** → Advanced Editor: paste `C:\Toolbox\Reports\DataWarehouse\ComplianceTrend.pq`, set `FeedUrl` to the feed URL without `?api-version=...`, **Done**. Sign in with **Organizational account** (your `etcX`), then **Close & Apply**.
7. Report view: add a **Line chart** with `Date` on the X-axis and `compliant` and `nonCompliant` as values. Compare: which question does each tool answer best?

### Dashboard from Graph data

Graph returns JSON, not charts. A short script runs the device query, counts the results and hands them to a chart library in the browser – compliance, operating systems, check-in age, Windows versions and the versions of one app. No server, no Power BI: one HTML file you can mail or open again later.

8. Open `Reports\Get-IntuneDashboard.ps1` and read it:
   - Which Graph call delivers the device data, and which properties does it ask for?
   - Where are the devices counted per chart?
   - How does the data get into the HTML page?
9. Run it in PowerShell (not elevated), sign in with `etcX` when asked:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntuneDashboard.ps1 -App '7-Zip' -OutFile 'C:\Temp\etcX-Dashboard.html'
   ```

10. The dashboard opens in the browser. Hover over the bars and the doughnut: the tooltips show the exact numbers.
11. Compare with your compliance CSV from step 1 and with the Intune admin center (Devices → **All devices**). Do the numbers match?

### Checkpoint

- [ ] Three CSV files in `.\ReportExports`: compliance, remediation results, app install status
- [ ] Compliance trend line chart in Power BI Desktop
- [ ] You can name one question per tool
- [ ] Dashboard opens with tiles, four charts and the list of non-compliant devices

**Note:** Graph can't be a Power Query data source – that is why Power BI uses the Data Warehouse OData feed. The same `.pq` files also work in Excel (Data → Get Data → From Other Sources → Blank Query).

**Note:** The dashboard loads the chart library Chart.js from `cdn.jsdelivr.net`. Without internet access the tiles and the table still show, the charts stay empty. Your Intune role decides which devices you see, so your dashboard and the trainer's may differ.

<!-- VERIFY: "Intune data warehouse" and report permissions in the Lab roles -->
<!-- VERIFY: winget ID Microsoft.PowerBI installs Power BI Desktop on CL3; menu labels Get data / Blank query / Close & Apply and the Organizational account prompt in the current Power BI Desktop -->
<!-- VERIFY: Graph consent for DeviceManagementManagedDevices.Read.All for etcX; 7-Zip shows up in discovered apps after Lab 1.3 -->
