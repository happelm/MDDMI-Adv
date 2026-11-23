# Demo – Alerts for Intune changes with Azure Monitor (Module 5)

**Duration:** 25 minutes (Part A 15, Part B 10)

The trainer shows two kinds of alerts built with the [Intune alert builder](../../Toolbox/Builders/intune-alert-builder.html). **Part A:** Intune audit events become email alerts – the Intune audit log goes to a Log Analytics workspace, and log search alert rules check it every few minutes. **Part B:** a daily check of connectors and tokens (Apple, Managed Google Play, Mobile Threat Defense, Windows Autopilot) mails the ones that expire or stop syncing. You follow along on the projector. It needs an Azure subscription, so in the course only the trainer runs it.

**Why:** Multi Admin Approval stops a change before it happens, but it covers only some object types and nobody hears about the changes that pass. An alert tells support and security within minutes that a device was wiped, a script changed or a role assignment moved – no matter who did it.

## Part A – Alerts on Intune changes

### A1. Prepare (trainer, before the module)

1. Azure portal → **Log Analytics workspaces** → Create, in a resource group of your subscription, same region as the alert rules later (for example West Europe).
2. Intune admin center → Reports → **Diagnostic settings** → Add diagnostic setting: name `Intune to Log Analytics`, **AuditLogs**, **Send to Log Analytics workspace** → the new workspace → Save.
3. Make one change in Intune (for example change the description of a test policy), wait up to 30 minutes, then run the check query from step 1 of the builder in the workspace → **Logs**. Compare the `OperationName` values with the activity names in the builder.
4. In the builder, enter the workspace resource ID (workspace → **JSON View**), the region and your trainer mailbox. Keep the five default events, download `intune-alerts.json` and deploy it (portal **Deploy a custom template**, or the PowerShell lines from the builder).

### A2. Show it

1. Open the builder on the projector: the events, why each one matters for support, the threshold (one wipe is a leaver, five in an hour are a problem).
2. Workspace → Logs: run the **test query** from the builder. The rows show who changed what in the last 7 days.
3. Azure portal → Monitor → **Alerts** → **Alert rules**: the rules from the template, each with its query, frequency and the action group with the mail address.
4. Trigger one event: Intune admin center → Devices → a lab device → **Run remediation** with any remediation.
5. After the next evaluation and the ingestion delay the mail arrives (subject `Intune alert: Remediation run on demand`). Monitor → **Alerts** shows the fired alert with the query result.

## Part B – Connector and token check

**Why:** An expired Apple MDM push certificate or ADE token is not in the audit log – nobody changed anything. Intune shows the state under Tenant administration → **Connector status**, but only to someone who opens it. With an expired push certificate Intune can no longer reach Apple devices, and a certificate that has to be created anew instead of renewed means re-enrolling them. A daily check turns the status page into a mail.

### B1. Prepare (trainer, before the module)

1. In the builder, Part B (step 6): it uses the workspace, region, mail address and name prefix from step 2. Download `intune-connector-check.json`.
2. Run the PowerShell block from the builder, part by part:
   - **Step 1 (Az):** deploy the template. It creates the custom table `IntuneConnectorStatus_CL`, a data collection rule, an Automation account with system-assigned managed identity, the runbook `Send-IntuneConnectorStatus.ps1`, a daily schedule, the role **Monitoring Metrics Publisher** on the data collection rule, an action group and one alert rule.
   - **Step 2 (new PowerShell window, Microsoft Graph):** grant the managed identity the Graph application permissions `DeviceManagementServiceConfig.Read.All` and `DeviceManagementConfiguration.Read.All`. ARM can't grant Graph permissions. Use a separate window: Az and Microsoft.Graph modules in one session fail with `MissingMethodException`.
   - **Step 3 (back in the Az window):** start the runbook once.
3. Automation account → **Jobs** → the job → **Output**: one row per connector with status and reason. Then run the **latest status** query from the builder in the workspace → Logs.

### B2. Show it

1. Intune admin center → Tenant administration → **Connector status**: the connectors and their expiry and sync dates.
2. The runbook output or the latest status query: the same connectors, rated with the same thresholds:

   | Status | When |
   |---|---|
   | **Unhealthy** | expired, or last sync 3 or more days ago |
   | **Warning** | expires within 30 days, or last sync more than 1 day ago |
   | **Healthy** | everything else |

   Intune itself warns 7 days before expiry; the runbook warns after 30 days so there is time to renew (`-ExpiryWarningDays`).
3. Monitor → **Alert rules** → `<prefix>-connectors`: the query looks for rows that are not **Healthy**, split by connector, name, status and reason – so every connector gets its own mail with the reason in it.
4. If a connector is in Warning, show the mail (for example an Apple token that expires within 30 days).
5. Automation account → **Schedules**: the daily run. Mail address and alert settings can be changed later in the action group and the alert rule – no redeploy needed.

**Note:** The runbook reads Graph beta endpoints. Connectors that are not set up in the tenant are skipped. Mobile Threat Defense returns only a partner ID; the runbook shows Microsoft Defender for Endpoint by name.

## Clean up

Delete the resource group, or at least the alert rules and the diagnostic setting – the workspace and every alert rule cost money. For Part B also the Automation account; its managed identity and Graph permissions go with it.

### What you take away

- The Intune audit log reaches Azure Monitor right after the change; Learn gives about 30 minutes until it shows in the workspace. An alert is not real time.
- Alert rules filter on `OperationName`. Check the names in your own tenant first – Learn doesn't document the values.
- Without an Azure subscription: Microsoft Graph `auditEvents` gives the same events, for example read by a scheduled script.
- Prevention (Multi Admin Approval), change alerts (Part A) and health alerts (Part B) answer three different questions: may this change happen, who changed what, and what is about to break without anybody changing anything.

**Note:** The builder's activity names come from the Intune audit log of the course tenant (Graph `auditEvents`, November 2026). Names marked *pattern* follow the same naming but were not seen there.

Sources: [Send Intune log data to Azure Storage, Event Hubs, or Log Analytics](https://learn.microsoft.com/intune/governance/integrate-azure-monitor) · [IntuneAuditLogs table](https://learn.microsoft.com/azure/azure-monitor/reference/tables/intuneauditlogs) · [Resource Manager templates for log search alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/resource-manager-alerts-log) · [Use audit logs to track and monitor events in Intune](https://learn.microsoft.com/intune/governance/monitor-audit-logs) · [Logs Ingestion API in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview) · [Using a system-assigned managed identity for an Azure Automation account](https://learn.microsoft.com/azure/automation/enable-managed-identity-for-automation)

<!-- Built 2026-11-23 on Michael's request (course day 1). Tested by Michael 2026-11-23: check/test queries, ARM deploy, one mail per event after the ingestion_time() fix (5e44348). Part B (connector check) tested by Michael 2026-11-23: runbook, schedule, mails per connector. -->
