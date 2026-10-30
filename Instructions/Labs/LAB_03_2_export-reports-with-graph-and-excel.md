---
title: 'Lab 3.2 – Export reports with Graph and Excel'
lab:
    title: 'Lab 3.2 – Export reports with Graph and Excel'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.2 – Export reports with Graph and Excel

**Estimated time:** 35 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Answer the same compliance question with a Graph export and with the Data Warehouse in Excel.

1. With the `Reports` folder from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles), list the presets and export compliance:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -ListPresets
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset DeviceCompliance
   ```

   Open the CSV in Excel and filter on your devices.
2. Install status of your 7-Zip app from Lab 2.1 (app ID from the browser address bar):

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <app ID>
   ```

3. Intune admin center → Reports → Intune Data warehouse → **Data warehouse**: copy the OData feed URL.
4. Excel → Data → Get Data → From Other Sources → **Blank Query** → Advanced Editor: paste `DataWarehouse\ComplianceTrend.pq`, replace `FeedUrl`, **Done**, sign in with **Organizational account**, **Close & Load**.
5. Build a line chart from the result. Compare: which question does each tool answer best?

### Checkpoint

- [ ] Two CSV files in your output folder
- [ ] Compliance trend chart in Excel
- [ ] You can name one question per tool

**Note:** Graph can't be a Power Query data source – that is why Excel uses the Data Warehouse OData feed.

<!-- VERIFY: "Intune data warehouse" and report permissions in the Lab roles -->
<!-- VERIFY: Excel on CL3 -->
