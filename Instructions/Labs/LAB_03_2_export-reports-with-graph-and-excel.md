---
title: 'Lab 3.2 – Export reports with Graph and Excel'
lab:
    title: 'Lab 3.2 – Export reports with Graph and Excel'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.2 – Export reports with Graph and Excel

**Estimated time:** 35 minutes (+ 15 minutes optional dashboard)

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Answer the same compliance question with a Graph export and with the Data Warehouse in Excel – and, optionally, as charts on a single HTML page.

1. With the `Reports` folder from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles), list the presets and export compliance:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -ListPresets
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset DeviceCompliance
   ```

   Open the CSV in Excel and filter on your devices.
2. Install status of your 7-Zip app from Lab 1.3 (app ID from the browser address bar):

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <app ID>
   ```

3. Intune admin center → Reports → Intune Data warehouse → **Data warehouse**: copy the OData feed URL.
4. Excel → Data → Get Data → From Other Sources → **Blank Query** → Advanced Editor: paste `DataWarehouse\ComplianceTrend.pq`, replace `FeedUrl`, **Done**, sign in with **Organizational account**, **Close & Load**.
5. Build a line chart from the result. Compare: which question does each tool answer best?

### Optional: dashboard from Graph data

Graph returns JSON, not charts. A short script runs the device query, counts the results and hands them to a chart library in the browser – compliance, operating systems, check-in age, Windows versions and the versions of one app. No server, no Power BI: one HTML file you can mail or open again later.

6. Open `Reports\Get-IntuneDashboard.ps1` and read it:
   - Which Graph call delivers the device data, and which properties does it ask for?
   - Where are the devices counted per chart?
   - How does the data get into the HTML page?
7. Run it in PowerShell (not elevated), sign in with `etcX` when asked:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntuneDashboard.ps1 -App '7-Zip' -OutFile 'C:\Temp\etcX-Dashboard.html'
   ```

8. The dashboard opens in the browser. Hover over the bars and the doughnut: the tooltips show the exact numbers.
9. Compare with your compliance CSV from step 1 and with the Intune admin center (Devices → **All devices**). Do the numbers match?

### Checkpoint

- [ ] Two CSV files in your output folder
- [ ] Compliance trend chart in Excel
- [ ] You can name one question per tool
- [ ] Optional: dashboard opens with tiles, four charts and the list of non-compliant devices

**Note:** Graph can't be a Power Query data source – that is why Excel uses the Data Warehouse OData feed.

**Note:** The dashboard loads the chart library Chart.js from `cdn.jsdelivr.net`. Without internet access the tiles and the table still show, the charts stay empty. Your Intune role decides which devices you see, so your dashboard and the trainer's may differ.

<!-- VERIFY: "Intune data warehouse" and report permissions in the Lab roles -->
<!-- VERIFY: Excel on CL3 -->
<!-- VERIFY: Graph consent for DeviceManagementManagedDevices.Read.All for etcX; 7-Zip shows up in discovered apps after Lab 1.3 -->
