# Custom reports

Two ways to build your own Intune reports:

| | A: Graph `exportJobs` (script) | B: Data Warehouse OData feed (Excel) |
|---|---|---|
| Data | The reports of the admin center, current state | Daily snapshot, star schema |
| History | Only reports built for it (e.g. `DeviceComplianceTrend`) | Fact tables about 30 days, device history 60 days |
| Tool | PowerShell, can run unattended | Excel or Power BI, no code |
| Permission | Graph scope + Intune role for the data | Intune role permission **Intune data warehouse** |
| Typical use | Detailed exports, input for other scripts | Trends, pivot tables, management view |

Microsoft Graph cannot be used as a data source in Power Query, which is why the Excel route goes through the Data Warehouse ([Learn](https://learn.microsoft.com/power-query/connectors/odata-feed)).

## A: Export-IntuneReport.ps1

Runs an export job (`POST deviceManagement/reports/exportJobs`), waits until it is completed, downloads the ZIP and saves a CSV that Excel opens with columns (delimiter = list separator of the current culture, UTF-8 with BOM).

```powershell
.\Export-IntuneReport.ps1 -ListPresets
.\Export-IntuneReport.ps1 -Preset Devices
.\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <Remediation ID>
.\Export-IntuneReport.ps1 -Preset AppInstallStatusByDevice -ApplicationId <App ID>
.\Export-IntuneReport.ps1 -ReportName DeviceCompliance -Select DeviceName,ComplianceState,UPN
```

Presets (`ReportPresets.json`, columns from the [Learn list](https://learn.microsoft.com/intune/device-management/reports/ref-graph-available-reports)):

| Preset | reportName | Needs |
|---|---|---|
| Devices | Devices | |
| DeviceCompliance | DeviceCompliance | |
| DeviceComplianceTrend | DeviceComplianceTrend | |
| DevicesWithoutCompliancePolicy | DevicesWithoutCompliancePolicy | |
| AppInstallStatus | AppInstallStatusAggregate | |
| AppInstallStatusByDevice | DeviceInstallStatusByApp | `-ApplicationId` |
| RemediationResults | DeviceRunStatesByProactiveRemediation | `-PolicyId` |
| FeatureUpdateDeviceState | FeatureUpdateDeviceState | `-PolicyId` |

Notes:
- Always select the columns. Microsoft recommends not to automate on a report's default columns.
- `-LocalizationType ReplaceLocalizableValues` (default here) returns readable values. `Devices` and `DevicesWithInventory` ignore it.
- Throttling: 8 export requests per user per minute, 100 per tenant per minute.
- Source: [Export Intune reports using Graph APIs](https://learn.microsoft.com/intune/device-management/reports/export-graph-apis).

## B: Data Warehouse in Excel

1. Intune admin center > **Reports** > **Intune Data warehouse** > **Data warehouse**: copy the OData feed URL.
2. Excel > **Data** > **Get Data** > **From Other Sources** > **From OData Feed**, paste the URL, sign in with **Organizational account**, select tables in the Navigator and load them.
3. Or use a prepared query: **Get Data** > **From Other Sources** > **Blank Query** > **Advanced Editor**, paste one of the files below, replace `FeedUrl`, **Done**, **Close & Load**.

| File | Result |
|---|---|
| `DataWarehouse/ComplianceTrend.pq` | Devices per compliance state per day, last 30 days (line chart) |
| `DataWarehouse/Devices.pq` | Current devices with ownership and compliance state (pivot by OS, ownership, compliance) |

Notes:
- Data is refreshed once a day. Co-managed workloads managed by Configuration Manager are not in the Data Warehouse.
- `maxHistoryDays` limits the history of tables with a `dateKey`.
- The Power BI connector v1 is being retired; the OData feed is the recommended way.
- Sources: [Connect to the Data Warehouse](https://learn.microsoft.com/intune/developer/data-warehouse/connect-power-bi), [API endpoint](https://learn.microsoft.com/intune/developer/data-warehouse/ref-api-endpoints), [Collections](https://learn.microsoft.com/intune/developer/data-warehouse/ref-collections).
