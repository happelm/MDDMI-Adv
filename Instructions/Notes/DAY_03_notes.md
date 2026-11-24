---
title: 'Day 3 notes – Insights, automation, platforms'
---

# Day 3 notes – Insights, automation, platforms

> Summary of what was covered on Day 3, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. Links marked "community" point to non-Microsoft sources.

## Key takeaways

- Endpoint analytics shows trends; Advanced Analytics adds live device queries, the device timeline and anomalies.
- Remediation contract: one output line plus the exit code. Exit 1 starts the remediation.
- Custom compliance tells Conditional Access, a remediation fixes the device – many settings need both.
- One question, the right tool: admin report, Graph export, Graph resources, Data Warehouse or Log Analytics.
- Intune has no software metering – Defender advanced hunting counts app launches.
- Unattended scripts = managed identity plus least privilege. Multi Admin Approval also applies to app-only calls.
- macOS target picture: ADE plus Platform SSO with Secure Enclave. Linux in Intune is compliance-centric.
- Before a customer drops the domain join, walk through the checklist in Module 16.

## 10. Endpoint analytics and Remediations

### Endpoint analytics

- Reports: startup performance, application reliability, work from anywhere. The score is the weighted average of the three. Path: Reports → Endpoint analytics.
- Onboarding with a data collection policy from Intune. Data arrives up to 24 hours after a restart; startup data needs at least one restart. Co-managed devices are configured through Intune, no workload switch needed.
- Fewer than 5 devices = insufficient data. Baselines (for example All organizations, median) put your score in context.
- **Model performance** shows boot and sign-in times per manufacturer and model – is the problem limited to certain models?
- **Startup processes** lists processes that keep the CPU above 50 % after the desktop rendered, only if they affect at least 10 devices in the tenant.

### What Advanced Analytics adds

| Scope | What you get |
|---|---|
| Reports | Resource performance (CPU, RAM), battery health, anomalies with device correlation groups, device scopes based on scope tags |
| Single device | Device timeline (replaces the Application reliability tab), device query with near real-time data, battery and resource views |
| Fleet | Device query for multiple devices (needs a properties catalog policy), entities such as Battery, Bios Info, Tpm, Windows Qfe; CSV export |

- Included in Microsoft 365 E3 since July 2026 (Module 1). Enabled automatically when licensed – up to 48 hours after licenses or a trial start.
- The device timeline uses the admin's time zone; most events appear within 24 hours.

Sources: Learn – Endpoint analytics overview · Configure endpoint analytics · Startup performance in endpoint analytics · Advanced Analytics overview · Device timeline report · Device query for multiple devices · Advanced Analytics FAQs

### Remediations you write yourself

- A package = detection script plus optional remediation script. The remediation runs only after **exit 1**. Up to 200 packages per tenant.
- Script rules: UTF-8 (no BOM when the signature check is on), output up to 2,048 characters, no reboots, no secrets, no personal data.
- Schedule once, hourly or daily, or **Run remediation** on demand per device (Remote tasks permission "Run remediation"). Runs as System or the signed-in user, 32- or 64-bit.
- Licensing: Windows Enterprise E3/E5, Education A3/A5 or VDA per user.
- The pattern:
  - **Detection** reads the value: `Write-Output "OK …"` and `exit 0` when it is right, otherwise write the current state and `exit 1`.
  - **Remediation** sets the value and writes what it did.
  - Pre- and post-remediation detection output appear as report columns. Empty output with exit 0 means "issue not found".
- Graph: results with `Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <id>`; on demand with `initiateOnDemandProactiveRemediation`. The [remediation builder](../../Toolbox/Builders/remediation-builder.html) writes both scripts.

### Custom compliance

1. **Discovery script** – Windows PowerShell on Windows, Bash on Linux. The last line returns one line of JSON (`return $hash | ConvertTo-Json -Compress`); the keys are the setting names the rules refer to. Created under Endpoint security → Device compliance → Scripts – discovery scripts don't support scope tags and need the **Default** scope tag.
2. **Rules file (JSON)** – per setting `SettingName`, `DataType` (Boolean, Int64, Double, String, DateTime, Version), `Operator` (IsEquals, NotEquals, GreaterThan, GreaterEquals, LessThan, LessEquals), `Operand`, plus `MoreInfoUrl` and `RemediationStrings`. `en_US` is required, `{ActualValue}` shows the discovered value. Up to 100 rules and 100 KB.
3. **Evaluation** – one discovery script belongs to exactly one policy. The IME runs it every eight hours and when the user selects **Check status** in Company Portal. Windows compliance policies also offer the setting *Custom compliance evaluation frequency* (rolling out). The result counts like a built-in setting, so Conditional Access uses it.

- Output longer than 2,048 characters is cut off – the JSON becomes invalid and evaluation fails with error **65009**.
- Field observation (trainer): assign custom compliance to device groups – with a user group assignment, evaluation happened only while that user was signed in.
- Tools: the [custom compliance builder](../../Toolbox/Builders/compliance-builder.html) writes script and JSON; `Test-CustomCompliance.ps1` checks both on a client before you upload them (Lab 3.1).

| | Custom compliance | Remediation |
|---|---|---|
| Job | Discover values and compare them with rules | Detect a problem and fix it |
| Files | Discovery script + JSON rules, one script per policy | Detection script + optional remediation script |
| Changes the device | No | Yes, after exit 1 |
| Conditional Access | Part of the compliance state | No |
| User sees | Remediation text from the JSON in Company Portal | – |
| Runs as | System (default) or signed-in user, 32-bit host unless set to 64-bit | System or signed-in user, 32- or 64-bit |

- Lab 3.1 uses both for the same setting. Prove it with the remediation overview in the portal – per-device remediation results in Graph lag behind the overview by hours (tested 2026-11-22).

Sources: Learn – Remediations · Remediations – prerequisites · Run a remediation script on demand · Custom compliance settings · Custom compliance discovery scripts · Custom compliance JSON files · Create a compliance policy

## 11. Reporting and automation

### Five ways to get Intune data

| Source | What you get | Use it for |
|---|---|---|
| Admin center reports | Current state, operational and organizational reports; few trend reports | Daily work |
| Graph exportJobs | Admin center reports as CSV; history only in reports built for it (for example DeviceComplianceTrend) | Detailed exports, input for scripts |
| Graph resources | Policies, apps, devices, assignments; no history | Automation, configuration inventory |
| Data Warehouse (OData) | Daily snapshot in a star schema; fact tables about 30 days, device history 60 days | Trends in Excel and Power BI without code |
| Log Analytics | Audit, operational, devices, compliance; retention of the workspace | Change audit, alerts, workbooks |

- Graph can't be a Power Query data source – Excel goes through the Data Warehouse. The Data Warehouse needs the Intune role permission **Intune data warehouse**.
- The Data Warehouse Power BI connector v1 is retired – Power BI Desktop and Excel read the OData feed (feed URL under Reports → Intune Data warehouse).

### Export reports with Graph

- `Export-IntuneReport.ps1` wraps the exportJobs flow: `POST /beta/deviceManagement/reports/exportJobs` with `reportName`, `select`, `format`, `localizationType` → poll until completed → download and unzip.
- `-ListPresets` shows the presets (Devices, DeviceCompliance, DeviceComplianceTrend, AppInstallStatus(ByDevice), RemediationResults, FeatureUpdateDeviceState); `-ReportName` with `-Select` exports any supported report.
- **Always select the columns** – Microsoft recommends not to automate on the default columns. Throttling: 8 export requests per user per minute, 100 per tenant per minute.
- `Get-IntuneDashboard.ps1` writes one HTML page with charts; the [dashboard builder](../../Toolbox/Builders/dashboard-builder.html) generates the presets.

### Data Warehouse in Power BI and Excel

- Lab 3.2: in the Navigator tick `dates` and `compliancePolicyStatusDeviceActivities`; Power BI links them via `dateKey`. Power BI Desktop needs 8192 MB RAM on CL3.
- **Publish** creates a report and a semantic model; scheduled refresh exists only for published reports. Refresh credentials OAuth2, privacy level Organizational, one daily slot (the Data Warehouse refreshes once a day).
- The refresh runs with the **publisher's credentials** – every viewer sees all devices the publisher can see. Intune RBAC and scope tags stop at the Data Warehouse.
- Sharing: the report for a few colleagues, a workspace role for a team, an app for many readers. Don't use Publish to web – it creates a public link.
- Licensing: Power BI Pro for the publisher and every viewer, unless the workspace runs on a Premium or Fabric capacity.
- **Power Query in Excel:** `Devices.pq` (Toolbox/Graph/Reports/DataWarehouse) loads the tables, joins them and renames columns in one query. The query is text – it runs unchanged in Power BI Desktop and can live in a repository.

Sources: Learn – Export Intune reports using Graph APIs · Connect to the Data Warehouse with Power BI · Intune Data Warehouse data model · Power Query M formula language · Demos: [Publish the Power BI report](../Demos/publish-power-bi-report.html), [Power Query in Excel](../Demos/power-query-data-warehouse.html)

### Unused licenses and stale devices

- Intune has no software metering. Defender for Endpoint records every process start, so advanced hunting (KQL) shows which licensed apps start, on how many devices and for how many users.
- The query counts **launches, not minutes of use**, sees only devices onboarded to Defender for Endpoint, and advanced hunting keeps 30 days.
- Advanced hunting for a custom role (lab finding 2026-11-22): activate the Endpoint workload in Defender unified RBAC and select **execute query actions** in the role.
- `Compare-IntuneEntraDevices.ps1` only reads: Matched, Intune only, Entra only, Stale – every row is a cleanup decision.

### Device query

| | Single device | Multiple devices |
|---|---|---|
| Data | Live from the device (Windows push notification) – device must be online | Collected inventory from a properties catalog policy |
| Entities | Includes registry, files, services, processes, events | Inventory entities only |
| Limits | 15 queries per minute | 10 per minute, 1,000 per month, up to 50,000 rows |

- Strings in single quotes. `WindowsEvent` needs the log name in quotes: `WindowsEvent('Application', 1d)` – the Learn sample without quotes failed in the lab (2026-11-22).

Sources: Learn – Device query · Device query for multiple devices · Intune data platform schema

### Log Analytics and KQL

| Log category → table | Latency | Content |
|---|---|---|
| AuditLogs → `IntuneAuditLogs` | Near real time | Who changed what – portal and Graph |
| OperationalLogs → `IntuneOperationalLogs` | Near real time | Enrollment and compliance operations |
| DeviceComplianceOrg → `IntuneDeviceComplianceOrg` | Every 24 h, up to 48 h delay | Compliance history |
| IntuneDevices → `IntuneDevices` | Every 24 h, up to 48 h delay | Inventory snapshots, stale devices |

- Setup: Reports → Diagnostics settings; needs an Azure subscription. Enable it at least two days before you need the data.
- Learn documents the columns (for example `ActivityType`, `ActorType`), not the content of the `Properties` field. The parsing in the change audit workbook comes from community workbooks – check it in your workspace. Splitting people from apps by `@` in the actor is a heuristic; `ActorType` is the documented field.
- Your scripts show up too: delegated runs with your UPN, app-only runs with the app name.

Sources: Learn – Send Intune log data to Azure Monitor · Azure Monitor tables for Intune · Intune change tracking workbook, Niklas Tinner (community)

### Scripts that run without you

1. **Azure Automation runbook** – PowerShell runbook on a schedule with `Microsoft.Graph.Authentication`; output to storage, mail or Teams.
2. **Managed identity** – `Connect-MgGraph -Identity`: no secret, no certificate to rotate. Graph app roles can't be granted in the app registration UI – assign them by script with `New-MgServicePrincipalAppRoleAssignment`. The identity appears under Enterprise applications → Managed Identities, not under App registrations.
3. **Least privilege** – read scopes for reports, write scopes only for the job that needs them. Multi Admin Approval also applies to app-only calls – app-only writes to protected objects are rejected unless planned for (Module 5).

- Example: the connector check (Part B of the [Intune alert builder](../../Toolbox/Builders/intune-alert-builder.html)) runs as a daily runbook with a managed identity.

Sources: Learn – Connect-MgGraph · Use Multi Admin Approval with the Microsoft Graph API

## 12. macOS

- Enrollment paths: BYOD with Company Portal, ADE through Apple Business, direct enrollment with Apple Configurator. Intune supports **macOS 15 and later**. The legacy Setup Assistant authentication for ADE is retired – use Setup Assistant with modern authentication.
- **Configure:** settings catalog for most payloads, declarative device management (DDM) for software updates (macOS 14 and later; Enforce Latest or a target version), endpoint security for FileVault, firewall, antivirus and EDR.
- **Apps:** PKG and DMG (up to 8 GB, installed by the agent), pre- and post-install scripts for unmanaged PKG; Microsoft 365 Apps and Edge as built-in app types. Apps the agent installed stay on the Mac after Retire.
- **Scripts:** shell scripts through the Intune management agent (macOS 12 and later, no proxy, max. 60 minutes, run in parallel); custom attributes echo a String, Integer or Date (ISO-8601), output up to 20 KB. The agent is installed with the first script or custom attribute.

### Platform SSO

- Policy: settings catalog → Authentication → Extensible Single Sign On, extension identifier `com.microsoft.CompanyPortalMac.ssoextension`, team identifier `UBF8T346G9`. Company Portal deploys the Enterprise SSO plug-in – an outdated Company Portal breaks Platform SSO.
- One SSO policy per group. With user affinity assign to **user groups** – device groups or filters aren't supported and can break Conditional Access. Users must be allowed to join devices to Entra ID.
- The user sees **Registration Required** in the Notification Center, signs in with MFA; the Mac becomes Entra joined. Check with `app-sso platform -s`.
- Changing the authentication method or shared device keys makes devices register again.

| Method | Properties | macOS |
|---|---|---|
| Secure Enclave (recommended) | Passwordless, phishing resistant, usable as passkey | 13 and later |
| Smart card | Passwordless, phishing resistant | 14 and later |
| Password | Local password synced with Entra ID | 13 and later |

- The local password stays – FileVault uses it after a restart. For a mixed fleet configure *Authentication Method* (macOS 14+) and *Authentication Method (Deprecated)* (macOS 13) in one profile.
- With ADE, registration can happen in Setup Assistant (`EnableRegistrationDuringSetup`). New users: register with a Temporary Access Pass.

### Apple Business federation and securing the Mac

- **Federation** links Apple Business with Entra ID: users sign in to Apple services with their work account as Managed Apple Account. Plan it before you create Managed Apple Accounts by hand. Account-driven user enrollment and Shared iPad need Managed Apple Accounts.
- **FileVault:** Endpoint security → Disk encryption. The recovery key is escrowed in Intune and can rotate every 1–12 months; users get it in the Company Portal website. Macs encrypted before: Store recovery key or `fdesetup changerecovery -personal`.
- **macOS LAPS:** local account configuration in the ADE enrollment policy – random 15-character password, rotated every six months, **only new ADE enrollments**. View and rotate permissions are in no built-in role – create a custom role.
- **Defender for Endpoint:** profiles first (system extensions, network filter – only one per Mac, Full Disk Access), then the app, then the onboarding profile. The Defender machine risk compliance setting isn't offered for macOS – use compliance from FileVault, firewall and OS version.

Sources: Learn – Deployment guide: Enroll macOS devices · Use shell scripts on macOS devices · Add a macOS DMG app · Configure Platform SSO for macOS devices · Set up account driven Apple User Enrollment · Disk encryption policy for endpoint security · macOS ADE local account configuration with LAPS · Deploy Microsoft Defender for Endpoint on macOS with Intune · Apple Business User Guide – federated authentication (Apple)

## 13. Linux

- Supported: **Ubuntu 24.04 LTS and 26.04 LTS, RHEL 9 and RHEL 10**, GNOME desktop, Microsoft Edge and the Microsoft Intune app. Older material with Ubuntu 20.04/22.04 or RHEL 8 is out of date.
- Linux management is **compliance-centric**: it protects access to Microsoft 365 web apps in Edge, it is not full configuration management. Compliance from the settings catalog, custom compliance with a POSIX script and JSON, custom configuration with Bash scripts.
- **Identity Broker 2.0.2 and later re-enrolls devices** with new Intune and Entra device IDs when they update from the Java broker. Check device-based groups, filters and assignments.
- Lab 3.5 findings (2026-11-22): rename the host first – Intune shows the host name as device name, and cloned VMs all have the same one. The admin center has no file upload for Linux scripts – paste the content. Linux discovery scripts run in the user's context.

Sources: Learn – Deployment guide: Manage Linux devices · Enroll Linux device in Intune · Device compliance settings for Linux · Custom compliance settings · What is Microsoft single sign-on for Linux

## 14. Universal Print

- No print servers, no drivers to distribute (the Universal Print driver is part of Windows), print from anywhere without VPN, secure release with PIN or QR code. Universal Print ready printers register directly, other printers through the **connector**; the **share** defines who can print and which name they see.
- Intune: settings catalog → **Printer Provisioning** – action Install, Cloud Device ID, Printer Shared ID, Shared Name; assign to users. Intune grants missing share permissions to the target group.
- On the device the Universal Print CSP runs `UPPrinterInstaller.exe`. Uninstall isn't in the portal yet – users remove printers themselves. The PrintProvisioning tool and `printers.csv` are deprecated.
- Shared devices outside Azure Virtual Desktop aren't officially supported (Conditional Access and MFA failures, delayed installs).
- The connector lists only printers installed locally on the connector host – printers from a print server share or on a `PORTPROMPT:` port are skipped.
- Licensing: print jobs are pooled per tenant, but access is checked per user – a user without a Universal Print license can't print.

Sources: Learn – What is Universal Print? · Create a Universal Print policy in Microsoft Intune · Universal Print printer provisioning · Register printers with the Universal Print connector · Demo: [Universal Print](../Demos/universal-print.html)

## 15. Microsoft Tunnel and ChromeOS

| | Microsoft Tunnel | Tunnel for MAM |
|---|---|---|
| Devices | Enrolled iOS/iPadOS and Android | Unenrolled devices with app protection |
| License | Intune Plan 1 + Azure subscription | Plan 2 or Suite |
| Client | Defender for Endpoint app | Edge and apps with the MAM SDK |

- Server: RHEL 9.x/10.x with Podman or Ubuntu 24.04/26.04 with Docker, a trusted TLS certificate; Tunnel and Global Secure Access not on the same device. Containers `mstunnel-server` (443 inbound) and `mstunnel-agent` (443 outbound).
- The supported server versions are a table on Learn – check it before every project; run the readiness tool before the installation.
- TLS certificate renewal with ACME: see the demo [Renew the Tunnel TLS certificate](../Demos/tunnel-tls-renewal.html).
- **ChromeOS** with the Chrome Enterprise connector (Tenant administration → Connectors and tokens, one connection per tenant): inventory as `Chrome-<serial>`, device actions (deprovision, lost mode, restart, wipe), ownership always Corporate. Enrollment and policies stay in Google Admin, compliance shows *Not evaluated*. **Deleting the connection removes all ChromeOS devices** from Intune and Entra ID.

Sources: Learn – Prerequisites for the Microsoft Tunnel · Command-line reference for Microsoft Tunnel Gateway · Configure Chrome Enterprise connector · View ChromeOS device information in Intune

## 16. From hybrid to Entra joined

| Works on hybrid joined because of the domain | On Entra joined |
|---|---|
| Group Policy | No GPO processing – everything from MDM; Group Policy analytics shows MDM equivalents |
| Firewall domain profile (DC reachable over LDAP) | No domain to detect – NetworkListManager CSP with an internal HTTPS endpoint (`AllowedTlsAuthenticationEndpoints`, `ConfiguredTlsAuthenticationNetworkName`) |
| Root CA distributed by the domain | Trusted certificate profiles for root and issuing CA |
| Certificate autoenrollment by GPO | SCEP or PKCS profiles, or Cloud PKI (Lab 2.5) |
| Computer account authentication (RADIUS, Wi-Fi, apps) | Device certificates from Intune or user authentication |
| Kerberos SSO | Still works with line of sight to a DC and users synced from AD; Windows Hello needs cloud Kerberos trust |
| Restricted Groups for local admins | Account protection (local users and groups), Entra joined device local administrator role, Windows LAPS |
| LAPS password and BitLocker key in AD | Backed up to Entra ID |
| Printers from a print server GPO | Universal Print with Printer Provisioning (Module 14) |
| GPO drive maps, logon scripts | Script that registers a scheduled task at logon and on network change |

- Drive mappings example: `Toolbox/Identity/DriveMapping/MapNetworkDrives.ps1` – maps drives by AD group membership via LDAP (needs line of sight to a DC). Community: Tbone Granheden, ideas from Nicola Suter.

**Checklist before you drop the domain join**

1. Group Policy: which settings have no MDM equivalent?
2. Firewall: which rules sit on the domain profile? NetworkListManager endpoint planned?
3. Certificates: root and issuing CA as trusted certificate profiles; autoenrollment replaced.
4. Computer account: 802.1X, Wi-Fi, SQL or apps that authenticate the computer object.
5. On-premises access: line of sight to a DC, users synced from AD, cloud Kerberos trust.
6. Printers, drive mappings, logon scripts.
7. Provisioning: Windows Autopilot instead of images.

Sources: Learn – Plan your Microsoft Entra join implementation · How SSO to on-premises resources works on Microsoft Entra joined devices · Policy CSP – NetworkListManager · Configure trusted certificate profiles · Windows LAPS with Intune · Tutorial: cloud-native Windows endpoints
