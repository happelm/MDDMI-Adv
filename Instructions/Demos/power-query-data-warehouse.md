# Demo – Shape Data Warehouse data with Power Query in Excel (Module 11)

**Duration:** 15 minutes


In Lab 3.2 you loaded Data Warehouse tables through the OData feed dialog and built the chart by hand. The trainer now shows the same data as a Power Query script: one query that loads the tables, joins them, keeps the columns you need and gives them readable names. You paste it once, and **Refresh All** brings the current data the next time.

**Needs:** Excel (Microsoft 365 Apps) on the trainer device, an account with read access to the Intune Data Warehouse, the two query files from [Toolbox/Graph/Reports/DataWarehouse](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Reports/DataWarehouse).

| File | Returns |
|---|---|
| `Devices.pq` | Current devices (deleted ones filtered out) with ownership and compliance state as text instead of keys – ready for a pivot table |
| `ComplianceTrend.pq` | Compliance state per day for the last 30 days – the same data as the line chart in Lab 3.2 |

## 1. Paste the query

1. Intune admin center → Reports → **Data warehouse**: copy the OData feed URL. Remove `?api-version=v1.0` at the end – the query adds it.
2. Excel → blank workbook → Data → Get Data → From Other Sources → **Blank Query**. The Power Query editor opens.
3. Home → **Advanced Editor**. Replace the content with `Devices.pq`, paste the feed URL into the `FeedUrl` line → **Done**.
4. Sign in with **Organizational account** when Excel asks for credentials → **Connect**.

## 2. Read the steps

5. On the right, **Applied Steps** lists every line of the `let` block: `Source`, `Devices`, `Owners`, `Compliance`, `Active`, `WithOwner`, `WithState`, `Result`. Select a step to see the table at that point:
   - `Active` – the filter on `isDeleted`, the same filter you set by hand in the Lab 3.2 pivot.
   - `WithOwner`, `WithState` – the joins on `ownerTypeKey` and `complianceStateKey`, so the table shows names instead of numbers.
   - `Result` – only the columns a report needs.
6. Home → **Close & Load**. The result lands as a table on a new sheet.

## 3. Use and refresh

7. Insert → **PivotChart**: **Ownership** to Axis, **Compliance** to Legend, **deviceName** to Values (Count). One chart answers "how many corporate devices are noncompliant?".
8. Change a device in Intune (for example its ownership) and wait for the next Data Warehouse refresh. Data → **Refresh All** updates the table and the chart – no new import.
9. Optional: add `ComplianceTrend.pq` as a second blank query and build a line chart on **Date**.

## The point to remember

The query is a text file. It can live in a repository, be reviewed like a script and run unchanged in Power BI Desktop (Get data → Blank query → Advanced Editor). The OData dialog in Lab 3.2 is quicker for a one-off look; the query is the better choice for a workbook that someone refreshes every week.

**Note:** The Data Warehouse refreshes once a day, so a change in Intune shows up after the next refresh, not right away.

**Note:** The `Source` line is the same `OData.Feed(..., [Implementation="2.0", Query=[#"api-version"="v1.0"]])` call Microsoft documents for moving old reports off the retired Intune Data Warehouse connector v1; `?maxHistoryDays=30` limits the history.

Sources: [Connect to the Data Warehouse with Power BI](https://learn.microsoft.com/intune/developer/data-warehouse/connect-power-bi) · [Intune Data Warehouse data model](https://learn.microsoft.com/intune/developer/data-warehouse/ref-data-model) · [Power Query M formula language](https://learn.microsoft.com/powerquery-m/)

<!-- Tested by Michael 2026-11-22: Devices.pq and ComplianceTrend.pq run against the course tenant, demo runs as written. -->
<!-- Sources checked 2026-11-22: Learn Connect to the Data Warehouse with Power BI (OData.Feed with Implementation 2.0, api-version v1.0, maxHistoryDays; endpoint without api-version), Use the Intune Data Warehouse (refreshed on a daily cadence). -->
