# Demos – overview

Trainer demos in the shared course tenant. You follow along on the projector; each page lists the steps so you can read them again after the course. Tenant-wide settings are changed by the trainer only.

| Demo | Module | Shows | Needs |
|---|---|---|---|
| [Multi Admin Approval for a script change](multi-admin-approval.md) | 5 – Change governance | An access policy for scripts holds a change until a second admin approves it – in the admin center and from PowerShell with Microsoft Graph | Two trainer accounts, approver group with an Intune role assignment |
| [Alerts for Intune changes with Azure Monitor](intune-alerts.md) | 5 – Change governance | Part A: Intune audit events as email alerts (audit log to Log Analytics, alert rules from the Intune alert builder). Part B: daily connector and token check with an Automation runbook | Azure subscription (trainer), Log Analytics workspace, Intune diagnostic setting; Part B: Graph application permissions for the Automation account's managed identity |
| [Intune Management Extension as managed installer](managed-installer.md) | 6 – Endpoint security | The managed installer policy set up before Day 1 and the tag it puts on apps Intune installs; basis for Lab 2.6 | Intune Administrator, policy assigned to the course device groups before Lab 0.1 |
| [Publish the Power BI report and refresh it daily](publish-power-bi-report.md) | 11 – Reporting | The Lab 3.2 report in the Power BI service: published, refreshed daily, shared – and why viewers see what the publisher sees | Report from Lab 3.2, Power BI Pro for publisher and viewers |
| [Shape Data Warehouse data with Power Query in Excel](power-query-data-warehouse.md) | 11 – Reporting | The Lab 3.2 Data Warehouse data as a Power Query script in Excel: joins, readable columns, Refresh All | Excel, Data Warehouse read access, `Devices.pq` and `ComplianceTrend.pq` from the Toolbox |
| [Universal Print with the print connector](universal-print.md) | 14 – Universal Print | A printer from SRV1 through the print connector and a Universal Print share to a Windows client, deployed with a settings catalog policy | Universal Print license for the trainer, print connector on SRV1 |
| [Renew the Microsoft Tunnel TLS certificate automatically](tunnel-tls-renewal.md) | 15 – Microsoft Tunnel | A Let's Encrypt certificate for the Tunnel Gateway: DNS challenge in Azure DNS with the VM's managed identity, import and restart by acme.sh, check in the admin center (draft) | Tunnel server VM in Azure, public Azure DNS zone, root on the server |
