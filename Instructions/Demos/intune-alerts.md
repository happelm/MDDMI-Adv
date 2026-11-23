# Demo – Alerts for Intune changes with Azure Monitor (Module 5)

**Duration:** 15 minutes

The trainer shows how Intune audit events become email alerts: the Intune audit log goes to a Log Analytics workspace, and log search alert rules check it every few minutes. The rules come from the [Intune alert builder](../../Toolbox/Builders/intune-alert-builder.html). You follow along on the projector. It needs an Azure subscription, so in the course only the trainer runs it.

**Why:** Multi Admin Approval stops a change before it happens, but it covers only some object types and nobody hears about the changes that pass. An alert tells support and security within minutes that a device was wiped, a script changed or a role assignment moved – no matter who did it.

## 1. Prepare (trainer, before the module)

1. Azure portal → **Log Analytics workspaces** → Create, in a resource group of your subscription, same region as the alert rules later (for example West Europe).
2. Intune admin center → Reports → **Diagnostic settings** → Add diagnostic setting: name `Intune to Log Analytics`, **AuditLogs**, **Send to Log Analytics workspace** → the new workspace → Save.
3. Make one change in Intune (for example change the description of a test policy), wait up to 30 minutes, then run the check query from step 1 of the builder in the workspace → **Logs**. Compare the `OperationName` values with the activity names in the builder.
4. In the builder, enter the workspace resource ID (workspace → **JSON View**), the region and your trainer mailbox. Keep the five default events, download `intune-alerts.json` and deploy it (portal **Deploy a custom template**, or the PowerShell lines from the builder).

## 2. Show it

1. Open the builder on the projector: the events, why each one matters for support, the threshold (one wipe is a leaver, five in an hour are a problem).
2. Workspace → Logs: run the **test query** from the builder. The rows show who changed what in the last 7 days.
3. Azure portal → Monitor → **Alerts** → **Alert rules**: the rules from the template, each with its query, frequency and the action group with the mail address.
4. Trigger one event: Intune admin center → Devices → a lab device → **Run remediation** with any remediation.
5. After the next evaluation and the ingestion delay the mail arrives (subject `Intune alert: Remediation run on demand`). Monitor → **Alerts** shows the fired alert with the query result.

## 3. Clean up

Delete the resource group, or at least the alert rules and the diagnostic setting – the workspace and every alert rule cost money.

### What you take away

- The Intune audit log reaches Azure Monitor right after the change; Learn gives about 30 minutes until it shows in the workspace. An alert is not real time.
- Alert rules filter on `OperationName`. Check the names in your own tenant first – Learn doesn't document the values.
- Without an Azure subscription: Microsoft Graph `auditEvents` gives the same events, for example read by a scheduled script.

**Note:** The builder's activity names come from the Intune audit log of the course tenant (Graph `auditEvents`, November 2026). Names marked *pattern* follow the same naming but were not seen there.

Sources: [Send Intune log data to Azure Storage, Event Hubs, or Log Analytics](https://learn.microsoft.com/intune/governance/integrate-azure-monitor) · [IntuneAuditLogs table](https://learn.microsoft.com/azure/azure-monitor/reference/tables/intuneauditlogs) · [Resource Manager templates for log search alerts](https://learn.microsoft.com/azure/azure-monitor/alerts/resource-manager-alerts-log) · [Use audit logs to track and monitor events in Intune](https://learn.microsoft.com/intune/governance/monitor-audit-logs)

<!-- Built 2026-11-23 on Michael's request (course day 1). Tested by Michael 2026-11-23: check/test queries, ARM deploy, one mail per event after the ingestion_time() fix (5e44348). -->
