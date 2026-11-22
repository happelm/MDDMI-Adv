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

### Before you start

1. Power BI Desktop needs more memory than CL3 has by default. On the lab host: Hyper-V Manager → CL3 → **Settings** → **Memory** → RAM **8192** MB → **OK** (works while CL3 is running).

   Then start the Power BI Desktop installation right away – it takes a while, so continue with the next steps in a second PowerShell window meanwhile. In an elevated PowerShell on CL3:

   ```powershell
   winget install --id Microsoft.PowerBI --exact --source winget --accept-package-agreements --accept-source-agreements
   ```

### Graph

2. In Windows PowerShell in `C:\Toolbox\Reports` (from Lab 0.1, source: [Toolbox/Graph/Reports](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Reports)), list the presets and export compliance:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -ListPresets
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset DeviceCompliance
   ```

   A preset is a ready-made request from `ReportPresets.json`: the exact `reportName`, a fixed column list and, where needed, a filter with a placeholder for `-PolicyId` or `-ApplicationId`. Any other report from the Learn list works with `-ReportName` and `-Select`.

   Open the newest CSV in a grid and type `CL3-` or your name in the **Filter** box:

   ```powershell
   $csv = Get-ChildItem .\ReportExports\*.csv | Sort-Object LastWriteTime | Select-Object -Last 1
   Import-Csv -Path $csv.FullName -Delimiter (Get-Culture).TextInfo.ListSeparator | Out-GridView
   ```

3. Install status of your 7-Zip app from Lab 1.3. For the app ID open Apps → Windows → your 7-Zip app: the GUID after `appId/` in the browser address bar.

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <app ID>
   ```

### Power BI

4. Intune admin center → Reports → Intune Data warehouse → **Data warehouse**: copy the OData feed URL (it ends with `?api-version=v1.0`).
5. Power BI Desktop → Home → Get data → **OData feed** → **Basic**, paste the URL → **OK**. Sign in with **Organizational account** (your `etcX`) → **Connect**.
6. The **Navigator** lists all Data Warehouse tables. Tick two of them:
   - `compliancePolicyStatusDeviceActivities` – one row per day with the number of devices per compliance state (`compliant`, `nonCompliant`, `inGracePeriod` …)
   - `dates` – the calendar: `dateKey` plus the real date `fullDate`

   Select **Load**. Power BI loads the data; this takes a moment.

   **Orientation:** Power BI Desktop has three views, switched with the small icons in the **narrow bar on the far left** (easy to overlook): **Report view** (top icon, the canvas for charts), **Table view** (the data as rows) and **Model view** (tables and their relationships). On the **right** are the panes **Visualizations** (chart types and the fields of the selected chart) and **Data** (your tables and their columns).

7. Select **Model view** in the bar on the left. You see both tables as boxes. A line between them means Power BI has linked them via `dateKey` – the activity table only holds a `dateKey`, the real date comes from `dates`. If there is no line: Home → **Manage relationships** → **Autodetect** → **Close**.
8. Build the chart:
   1. Select **Report view** in the bar on the left (top icon). You get an empty canvas.
   2. In the **Visualizations** pane on the right, select the icon **Line chart**. An empty chart frame appears on the canvas and stays selected. Drag its corner to make it bigger.
   3. Below the chart icons the Visualizations pane now shows the boxes **X-axis**, **Y-axis**, **Legend** and more.
   4. In the **Data** pane on the far right, expand `dates` and drag `fullDate` into the box **X-axis**.
   5. Expand `compliancePolicyStatusDeviceActivities` and drag `compliant` and then `nonCompliant` into the box **Y-axis**. Power BI shows them as *Sum of compliant* and *Sum of nonCompliant* – one line each.
   6. If the X-axis shows only years or quarters: in the box **X-axis**, select the small arrow next to `fullDate` and choose **fullDate** instead of **Date Hierarchy**. Now every day is a point on the line.
   7. Hover over the line: the tooltip shows the date and the number of devices.

### Excel

9. Open both new CSV files from `C:\Toolbox\Reports\ReportExports` in Excel (not the `_raw.csv` files). Filter the compliance export for CL3 and sort the app export by install state.
10. The Data Warehouse works in Excel too – here as a PivotChart: how many devices per operating system?
    1. Open a new blank workbook. Data → Get Data → From Other Sources → **From OData Feed**, paste the same URL as in step 4 → **OK**. Sign in with **Organizational account** (your `etcX`) → **Connect**.
    2. The **Navigator** opens, just like in Power BI. Select the table `devices` → **Load**. Excel puts the devices into a new sheet as a table – one row per device, with columns such as `deviceName`, `operatingSystem`, `model` and `isDeleted`.
    3. Click any cell inside the table. Insert → **PivotChart** → **OK** (the table is already selected, the chart goes to a new sheet).
    4. On the right the pane **PivotChart Fields** opens with all columns of the table. Drag `operatingSystem` into the box **Axis (Categories)** and `deviceName` into the box **Values**. Excel shows *Count of deviceName* – a column per operating system.
    5. Devices removed from Intune stay in the Data Warehouse with `isDeleted` = TRUE. Drag `isDeleted` into the box **Filters**, then select the filter button on the chart (top left) and choose **FALSE**.
    6. Compare with the Intune admin center (Devices → **All devices**): does the number of Windows devices match?

### Dashboard

Graph returns JSON, not charts. A short script runs the device query, counts the results and hands them to a chart library in the browser – compliance, operating systems, check-in age, Windows versions and the versions of one app. No server, no Power BI: one HTML file you can mail or open again later.

11. Open `Reports\Get-IntuneDashboard.ps1` and read it:
    - Which Graph call delivers the device data, and which properties does it ask for?
    - Where are the devices counted per chart?
    - How does the data get into the HTML page?
12. Run it in PowerShell (not elevated), sign in with `etcX` when asked:

    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntuneDashboard.ps1 -App '7-Zip' -OutFile 'C:\Temp\etcX-Dashboard.html'
    ```

13. The dashboard opens in the browser. Hover over the bars and the doughnut: the tooltips show the exact numbers.
14. Compare with your compliance export from step 2 and with the Intune admin center (Devices → **All devices**). Do the numbers match? Which question does each tool – Graph export, Power BI, Excel, dashboard – answer best?

### Checkpoint

- [ ] Two CSV files in your output folder
- [ ] Compliance trend line chart in Power BI Desktop
- [ ] Both CSV files open in Excel, PivotChart with devices per operating system
- [ ] You can name one question per tool
- [ ] Dashboard opens with tiles, four charts and the list of non-compliant devices

**Note:** Graph can't be a Power Query data source – that is why Power BI uses the Data Warehouse OData feed.

**Note:** The dashboard loads the chart library Chart.js from `cdn.jsdelivr.net`. Without internet access the tiles and the table still show, the charts stay empty. Your Intune role decides which devices you see, so your dashboard and the trainer's may differ.

<!-- VERIFY: "Intune data warehouse" and report permissions in the Lab roles -->
<!-- Michael 2026-11-22: CL3 needs 8192 MB RAM for Power BI Desktop; change works live. -->
<!-- 2026-11-22 (Michael): Data Warehouse via the OData feed dialog instead of the .pq files (Learn: Create an Intune report from the OData feed with Power BI). The .pq files stay in Toolbox/Graph/Reports/DataWarehouse for advanced use. -->
<!-- VERIFY: Power BI/Excel menu labels (OData feed, Basic, Manage relationships > Autodetect, Date Hierarchy, From OData Feed) in the current versions on CL3; relationship autodetect between compliancePolicyStatusDeviceActivities and dates -->
<!-- VERIFY: winget ID Microsoft.PowerBI installs Power BI Desktop on CL3 -->
<!-- VERIFY: Graph consent for DeviceManagementManagedDevices.Read.All for etcX; 7-Zip shows up in discovered apps after Lab 1.3 -->
