# MDDMI-Adv – Modern Device Management with Microsoft Intune, Advanced

Lab instructions for the MDDMI-Adv workshop, the second part of the MDDMI course series.

- **Read online:** <https://happelm.github.io/MDDMI-Adv/>

## Labs

### Day 1 – Automate, package, connect, govern

| Lab | Title | Time |
|---|---|---|
| 0.1 | [Set up your lab](Instructions/Labs/LAB_00_1_set-up-your-lab.md) | 25 min |
| 1.1 | [Answer "what hits this device?" with Graph](Instructions/Labs/LAB_01_1_answer-what-hits-this-device-with-graph.md) | 60 min |
| 1.2 | [Rename policies safely](Instructions/Labs/LAB_01_2_rename-policies-safely.md) | 30 min |
| 1.3 | [Build a Win32 app with the pipeline](Instructions/Labs/LAB_01_3_build-a-win32-app-with-the-pipeline.md) | 40 min |
| 1.4 | [Add an app from the Enterprise App Catalog](Instructions/Labs/LAB_01_4_add-an-app-from-the-enterprise-app-catalog.md) | 20 min |
| 1.5 | [Package a setup.exe with the pipeline](Instructions/Labs/LAB_01_5_package-a-setup-exe-with-the-pipeline.md) | 30 min |
| 1.6 | [Wrap an app with PSADT and ship it with the pipeline](Instructions/Labs/LAB_01_6_wrap-an-app-with-psadt-and-ship-it-with-the-pipeline.md) | 35 min |

### Day 2 – Security, least privilege, support

| Lab | Title | Time |
|---|---|---|
| 2.1 | [Endpoint security policies](Instructions/Labs/LAB_02_1_endpoint-security-policies.md) | 50 min |
| 2.2 | [Audit apps with App Control for Business](Instructions/Labs/LAB_02_2_audit-apps-with-app-control-for-business.md) | 30 min |
| 2.3 | [Windows LAPS](Instructions/Labs/LAB_02_3_windows-laps.md) | 40 min |
| 2.4 | [Endpoint Privilege Management](Instructions/Labs/LAB_02_4_endpoint-privilege-management.md) | 55 min |
| 2.5 | [Certificates from Cloud PKI](Instructions/Labs/LAB_02_5_certificates-from-cloud-pki.md) | 30 min |
| 2.6 | [Support CL3 from CL4 with Remote Help](Instructions/Labs/LAB_02_6_support-cl3-from-cl4-with-remote-help.md) | 45 min |

### Day 3 – Insights, automation, platforms

| Lab | Title | Time |
|---|---|---|
| 3.1 | [Detect, enforce, prove](Instructions/Labs/LAB_03_1_detect-enforce-prove.md) | 45 min |
| 3.2 | [Export reports with Graph and Power BI](Instructions/Labs/LAB_03_2_export-reports-with-graph-and-excel.md) | 55 min |
| 3.3 | [Find unused licenses and stale devices](Instructions/Labs/LAB_03_3_find-unused-licenses-and-stale-devices.md) | 45 min |
| 3.4 | [Query devices with Advanced Analytics](Instructions/Labs/LAB_03_4_query-devices-with-advanced-analytics.md) | 35 min |
| 3.5 | [Enroll and check a Linux desktop](Instructions/Labs/LAB_03_5_enroll-and-check-a-linux-desktop.md) | 45 min |

### Review questions

Understanding questions with hidden answers – for the start of the next day and for after the course.

[Day 1 review](Instructions/Review/day-1-review.md) – for the morning of Day 2

[Day 2 review](Instructions/Review/day-2-review.md) – for the morning of Day 3

[Day 3 review](Instructions/Review/day-3-review.md) – for the end of the course and later

### Day notes

Summary of each day with sources – the slide content in reading form.

| Day | Notes |
|---|---|
| 1 | [Automate, package, connect, govern](Instructions/Notes/DAY_01_notes.md) |
| 2 | [Security, least privilege, support](Instructions/Notes/DAY_02_notes.md) |
| 3 | [Insights, automation, platforms](Instructions/Notes/DAY_03_notes.md) |

### Demos

[Overview](Instructions/Demos/README.md) – trainer demos, what they show and what they need

[Multi Admin Approval for a script change](Instructions/Demos/multi-admin-approval.md) – Module 5, an access policy for scripts in the admin center and from Microsoft Graph

[Alerts for Intune changes with Azure Monitor](Instructions/Demos/intune-alerts.md) – Module 5, Intune audit events as email alerts with Log Analytics and the Intune alert builder, plus a daily connector and token check

[Intune Management Extension as managed installer](Instructions/Demos/managed-installer.md) – Module 6, the managed installer policy behind Lab 2.2 and the tag it puts on apps

[Publish the Power BI report and refresh it daily](Instructions/Demos/publish-power-bi-report.md) – Module 11, the Lab 3.2 report in the Power BI service: scheduled refresh, sharing, and what viewers can see

[Shape Data Warehouse data with Power Query in Excel](Instructions/Demos/power-query-data-warehouse.md) – Module 11, the Lab 3.2 data as a Power Query script in Excel with joins, readable columns and Refresh All

[Universal Print with the print connector](Instructions/Demos/universal-print.md) – Module 14, a printer from SRV1 through the print connector to a Windows client with an Intune policy

[Renew the Microsoft Tunnel TLS certificate automatically](Instructions/Demos/tunnel-tls-renewal.md) – Module 15, a Let's Encrypt certificate for the Tunnel Gateway via Azure DNS and the VM's managed identity (draft)

### Toolbox

All scripts, lab files and builders are in the [Toolbox](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox), sorted by area: Builders, Graph, Apps, Security, Identity. Lab 0.1 copies all script folders to `C:\Toolbox` on CL3; the labs link to their source folder.

[Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/firewall-rule-builder.html) – pick firewall rule groups and add custom rules; builds the rule file for `New-IntuneFirewallRulePolicy.ps1`.

[Custom compliance builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/compliance-builder.html) – pick checks for Windows devices; builds the discovery script and the JSON rules file for a custom compliance policy.

[Dashboard builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/dashboard-builder.html) – pick tiles, charts and tables; builds a read-only PowerShell script that reads Intune data from Microsoft Graph and writes one HTML dashboard.

[Remediation builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/remediation-builder.html) – pick checks for Windows devices; builds the detection and remediation script pair for a remediation script package.

[Intune alert builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/intune-alert-builder.html) – pick Intune events that support should hear about; builds the KQL queries and an ARM template with email alerts in Azure Monitor (trainer demo, needs an Azure subscription).

## About this guide

Each lab lists its goal, the steps at task level (not every click) and a checkpoint you confirm before moving on.

- **Steps** say what to do and where. Menu paths use → between levels.
- **Checkpoint** items are the definition of done. If one fails, tell the trainer before you continue.
- **Notes** explain what to expect and where it typically goes wrong.

### Your lab pod

Every participant works in the shared course tenant with their own account and groups. Your number X comes from the trainer.

| Item | Value |
|---|---|
| Account | `etcX` in the course tenant (the trainer gives you the domain) |
| Groups | `studentXusers`, `studentXdevices` – assign everything to these groups, never to All users or All devices |
| Clients | CL3, CL4 (`CLx-yourname`), Microsoft Entra joined and enrolled in Intune |
| Where you work | On **CL3**, signed in as `etcX`: Intune admin center, PowerShell and the Toolbox in `C:\Toolbox` (Lab 0.1). CL4 is the second client, for example the helper in Lab 2.6. |
| Servers | DC1, SRV1 – shared by the class |
| Object names | Every object you create starts with `etcX-` |

You can read everything in the tenant, but change only objects for your own groups. Conditional Access, assignment filters and tenant settings are shown by the trainer.

### Portals and files

- Microsoft 365 admin center: admin.microsoft.com · Intune admin center: intune.microsoft.com · Entra admin center: entra.microsoft.com
- Lab files and scripts: [Toolbox folder in this repository](Toolbox)

## Known issues and feedback

Known issues, workarounds and corrections are tracked in the [Issues](https://github.com/happelm/MDDMI-Adv/issues) tab. If something in a lab does not work as described, check the open issues first, then open a new one with the lab number and the step.

## Contributing

Trainers and participants may fork this repository. Pull requests are welcome and are merged after review.

(c) Enterprise Training Center
