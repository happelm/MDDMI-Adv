# Demo – Publish the Power BI report and refresh it daily (Module 11)

**Duration:** 10 minutes

The trainer takes the compliance trend report from Lab 3.2 out of Power BI Desktop and into the Power BI service: published to a workspace, refreshed once a day without anyone opening Power BI Desktop, and shared with colleagues. You watch on the projector – it needs a Power BI license and a workspace, which is more than the lab needs.

**Needs:** the report from Lab 3.2 saved as `.pbix`, a Power BI Pro license for the publisher (included in Microsoft 365 E5) and for every viewer, unless the workspace runs on a Premium or Fabric capacity.

## 1. Publish

1. Power BI Desktop → Home → **Publish**. Sign in if asked, choose a workspace (for example **My workspace**) → **Select**.

   **Share** in Power BI Desktop is something else: it saves the `.pbix` file to OneDrive and shares the file. Scheduled refresh only exists for reports that were **published**.

2. Open the link in the success message, or browse to `app.powerbi.com` → **Workspaces** → your workspace. The workspace now holds two items with the name of your file: a **Report** (the visuals) and a **Semantic model** (the data and the connection to the Data Warehouse).

## 2. Refresh daily

The refresh belongs to the semantic model, not to the report.

1. At the **Semantic model** → **⋯** (More options) → **Settings**.
2. **Data source credentials** → **Edit credentials**: authentication method **OAuth2**, privacy level **Organizational** → **Sign in**.
3. **Refresh** → **Configure a refresh schedule** **On**, frequency **Daily**, check the time zone, **Add another time** → **Apply**.
4. At the semantic model, select **Refresh now** to test it.

One time slot per day is enough: the Data Warehouse itself is refreshed daily. Power BI Pro allows up to 8 scheduled refreshes per day, Premium per user and Premium/Fabric capacities up to 48. After two months without any view of the report, the service pauses the schedule.

## 3. Share

| Way | How | Good for |
|---|---|---|
| Share the report | Open the report → **Share** → people or groups → **Send**. They find it under **Shared with me**. | A few colleagues |
| Workspace role | Create a workspace (My workspace takes no members) → **Manage access** → a group with the role **Viewer**, publish the report there | A team |
| App | Publish an app from the workspace to a group | Many readers |

**Don't use Publish to web:** it creates a public link that anyone can open without signing in.

## 4. The point to remember

The refresh runs with the **publisher's** credentials. Every viewer sees all devices the publisher can see – regardless of their own Intune role and scope tags. Intune RBAC stops at the Data Warehouse; once the data is in the Power BI service, only Power BI decides who sees what (separate reports per audience, or row-level security in Power BI).

<!-- Sources: Learn – Configure scheduled refresh; Data refresh in Power BI; Create an Intune report from the OData feed with Power BI; checked 2026-11-22. -->
<!-- Tested 2026-11-22 (Michael): Publish, OAuth2 credentials and scheduled refresh in app.powerbi.com work. Sharing and workspace roles not shown yet. -->
