---
title: 'Day 1 notes – Automate, package, connect, govern'
---

# Day 1 notes – Automate, package, connect, govern

> Summary of what was covered on Day 1, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. Links marked "community" point to non-Microsoft sources.

## Key takeaways

- Since July 2026, Microsoft 365 E3 includes Intune Plan 2, Remote Help and Advanced Analytics; E5 and E7 add Endpoint Privilege Management, Cloud PKI and Enterprise App Management. Check Tenant administration → **Intune add-ons** before you plan a project.
- The admin center is a Microsoft Graph client. F12 → Network shows every request, and every request can be scripted.
- **Delegated** sign-in respects Intune RBAC and scope tags. **App-only** does not – an app with a ReadWrite permission can change every object in the tenant.
- A safe script pages through `@odata.nextLink`, waits on HTTP 429, supports `-WhatIf` and logs every write.
- `app.json` plus one script turns an MSI, a setup.exe and a PSADT package into a Win32 app – repeatable and documented.
- The Enterprise App Catalog saves the packaging. Automatic update is Required only, with no rings and no rollback.
- winget is a tool for admins, not an update service for a fleet: the winget CLI isn't supported in SYSTEM context.
- Cloud Sync covers most hybrid customers, including device sync. The SCP decides the tenant – script it and check it.
- Multi Admin Approval **prevents** changes to protected object types; alerts on the audit log **report** every change.

## 0. Kickoff and lab orientation

- The tenant is shared by the whole class. Your prefix `etcX-` and your groups `studentXusers` / `studentXdevices` keep your work apart – never assign to All users or All devices.
- Your rights: Entra administrative units for your groups and the lab devices; in Intune **Lab-Reader for Students** (read everything) and **Lab-Administrator for Students** (create and assign with scope tag Lab-Students). Conditional Access, assignment filters and tenant settings are trainer demos.
- The Graph scripts run delegated with your account – Intune RBAC limits them exactly like the portal.
- How we run scripts: read the help first (`Get-Help .\script.ps1 -Full`, scopes under `.NOTES`), dry run with `-WhatIf`, own objects only, keep the CSV log – it is your undo and your evidence.
- PowerShell 7 is recommended; Windows PowerShell 5.1 works for all Toolbox scripts. The only module you need is `Microsoft.Graph.Authentication`.
- Lab 0.1: don't select **Connect** in the Hyper-V enhanced session window before the Windows Hello PIN works – the PIN setup fails over RDP. Afterwards the enhanced session is fine.
- The user who joins a device becomes a local administrator on it; every other user is a standard user.

## 1. Advanced capabilities in 2026

| Capability | Standalone add-on | Plan 2 | Suite | Included since July 2026 in |
|---|---|---|---|---|
| Remote Help | ✓ | | ✓ | E3, E5, E7 |
| Advanced Analytics | ✓ | | ✓ | E3, E5, E7 |
| Endpoint Privilege Management | ✓ | | ✓ | E5, E7 |
| Enterprise App Management | ✓ | | ✓ | E5, E7 |
| Microsoft Cloud PKI | ✓ | | ✓ | E5, E7 |
| Tunnel for Mobile Application Management | | ✓ | ✓ | E3, E5, E7 (Plan 2) |

- Plan 2 and the Suite are additive to Plan 1; the Suite includes Plan 2. Learn now calls these "advanced capabilities (formerly Microsoft Intune Suite)".
- Other plans keep the Suite or single add-ons as separate subscriptions. No change for Education and frontline plans at this time.
- The rollout is gradual: eligible tenants are provisioned automatically, with a Message center notice 30 days before.
- Check in the tenant: Intune admin center → Tenant administration → **Intune add-ons** (Active, or available for trial or purchase).

Sources: Learn – Microsoft Intune planning guide – determine costs and licensing · Use Microsoft Intune Suite add-on capabilities · What's new in Microsoft Intune – week of June 29, 2026

## 2. Microsoft Graph for Intune admins

### Three ways in

1. **Admin center:** every blade calls `graph.microsoft.com`, most Intune blades use `/beta`. F12 → Network → filter on `graph` shows the request.
2. **Graph Explorer:** try a request with your own account, see the required permissions and sample code. Press **Enter** after pasting a new URL – **Run query** keeps sending the first one.
3. **Graph PowerShell SDK:** `Connect-MgGraph` signs in, `Invoke-MgGraphRequest` sends any request. Use `-OutputType PSObject`, otherwise you get hashtables that `Format-Table` doesn't show well.

### Who signs in?

| Sign-in | Permissions | Use for |
|---|---|---|
| Delegated (`Connect-MgGraph -Scopes …`) | Scopes combined with your Intune role and scope tags | Tools you run by hand – all labs in this course |
| App-only with certificate | Application permissions, tenant-wide | Scheduled jobs on a server you control |
| App-only with secret | Same | Avoid – secrets leak and expire |
| Managed identity (`Connect-MgGraph -Identity`) | App roles assigned to the identity | Azure Automation, Azure Functions – no secret at all |

App-only ignores Intune RBAC and scope tags. Multi Admin Approval still applies to app-only calls (Module 5).

### The script pattern

- Least-privilege scopes: Read before ReadWrite.
- Show the tenant and ask before writing.
- Paging: follow `@odata.nextLink` – never trust the first page.
- `ShouldProcess` gives `-WhatIf` and `-Confirm` for free.
- Throttling: HTTP 429 with `Retry-After`. The SDK retries on its own; inside JSON batches you retry yourself.
- `beta` changes without notice – pin what you depend on.

Intune limits (examples, per 20 seconds, tenant / app): devices and scripts 400 / 200 writes and 4,000 / 2,000 requests; RBAC, enrollment and resource access profiles 200 / 100 writes and 2,000 / 1,000 requests. Report export jobs: 8 per user per minute, 100 per tenant per minute.

- A Graph POST doesn't add your scope tag the way the admin center does – set `roleScopeTagIds` yourself (the pipeline does it with `-ScopeTagName`).
- Export jobs need a ReadWrite scope although they only read – documented in the Graph reference.
- Windows client blocks scripts by default, including the Graph SDK module files: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Sources: Learn – Use Microsoft Graph PowerShell authentication commands · Use app-only authentication with the Microsoft Graph PowerShell SDK · Microsoft Graph throttling guidance · Microsoft Graph service-specific throttling limits (Intune) · Paging Microsoft Graph data in your app

## 3. The app factory

### Three ways to ship a Win32 app

| Way | Who packages | Updates | Fits when |
|---|---|---|---|
| Portal: IntuneWinAppUtil + upload | You | New app + supersedence by hand | A few apps, rare changes |
| Script pipeline (Graph) | You, once per app folder | New version = new folder, same script | Many apps, repeatable, documented in `app.json` |
| Enterprise App Catalog | Microsoft | Guided supersedence or automatic update | App is in the catalog and EAM is licensed |
| winget / Winget-AutoUpdate (community) | Community manifests | Scheduled winget runs on the client | Admin tool to find and test packages |

### What the pipeline does in Graph

1. **Package:** `IntuneWinAppUtil.exe`, then read the encryption info from the `.intunewin`.
2. **Create:** POST `/deviceAppManagement/mobileApps` (`win32LobApp`) with detection, requirements and return codes from `app.json`.
3. **Upload:** content version, file entry, upload in blocks to the Azure Storage SAS URI, commit with the encryption info.
4. **Finish:** set `committedContentVersion`, optionally assign.

The upload has to wait for the SAS URI and the commit state – that is where most home-made scripts fail.

- **MSI:** the script reads product code and version, builds the commands and an MSI detection rule.
- **setup.exe:** nothing to read – you supply the silent switches (NSIS `/S`, Inno Setup `/VERYSILENT /NORESTART`, InstallShield `/s /v"/qn"`), the uninstall command and a detection rule. Write the uninstall path in full: the IME is a 32-bit process, `%ProgramFiles%` can resolve to `Program Files (x86)`. Detect a self-updating app with **greater than or equal**, not equals.
- **PSADT v4:** closes the app with a deferral option, installs the MSI, copies configuration files, writes its log to `C:\Windows\Logs\Software`. Map return code **1602 to Retry** (user deferred). Detect the last thing the package does (here `policies.json`), not only the MSI. v4 functions all contain `-ADT`. Test locally in an **elevated** Windows PowerShell – without admin rights the toolkit installs nothing and writes no log.

### Enterprise App Catalog

- Prepackaged Win32 apps hosted by Microsoft, installed by the IME – not by winget.
- Update method is chosen once per app on the **Updates** tab: **Automatically update** or **Update with supersedence**. Most updates arrive within 24 hours (service level objective).
- Automatic update: Required only, Program/Requirements/Detection locked, no rollback, no rings, no deployment plans.
- Since October 2026 automatic-update apps can be blocking apps in the Enrollment Status Page.
- Scope tags and assignments are not copied when you supersede.

### winget – where support ends

- `winget list` shows every app in Add/Remove Programs and matches it to a package. "Source: winget" means "a matching package exists", not "installed by winget".
- User, admin and SYSTEM each have their own tracking database – same device, different results.
- The winget CLI is **not supported in SYSTEM context**. Supported there: the PowerShell module `Microsoft.WinGet.Client`. Intune runs Win32 apps, scripts and remediations as SYSTEM.
- Trainer recommendation: use winget to find and test packages; deploy and update with the catalog or your pipeline. If you automate winget anyway: allowlist only, one update mechanism per app, test in SYSTEM context.

Sources: Learn – Win32 app management · Microsoft Intune Enterprise Application Management (FAQ, auto-update) · Windows Autopilot: What's new · Debugging and troubleshooting issues with the WinGet tool · Lab guide – Toolbox\Apps\Win32Pipeline README · PSAppDeployToolkit documentation (community)

## 4. Hybrid identity, advanced

| Scenario | Cloud Sync | Connect Sync |
|---|---|---|
| New hybrid customer, hybrid join (device sync), Exchange hybrid | ✓ | ✓ |
| Disconnected forests (mergers), high availability with several agents | ✓ | – |
| More than 250,000 objects, attribute-based filtering | – | ✓ |

- Cloud Sync runs lightweight agents on-premises; engine, database and configuration live in Microsoft Entra ID.
- **Device sync:** provisioning agent 1.1.1107 or later, job `AD2AADDeviceSync` (off by default), test with provision on demand. Deleted devices: restore in Entra or change the AD object.
- **SCP:** one per forest, keywords `azureADName` and `azureADId`; creating it needs Enterprise Admins. `Toolbox\Identity\HybridJoin\Set-HybridJoinSCP.ps1` shows the current keywords, refuses a foreign tenant without `-Force` and supports `-WhatIf`. The Learn script replaces existing keywords without asking.

Sources: Learn – Hybrid scenarios – supported sync scenarios · What is Microsoft Entra Cloud Sync? · Configure device sync with Microsoft Entra Cloud Sync

## 5. Change governance

### Deployment plans and deployments (preview)

- A **deployment plan** is a reusable template with rings, groups, filters, excludes and deferral between rings – no payload.
- A **deployment** delivers one payload (settings catalog, endpoint security policy, Win32 or catalog app – Required only) with a plan or one-time rings; pause, resume, cancel; at least one hour between rings.
- Ring groups are added cumulatively to the payload's Required assignments. The payload stays the source of truth – direct assignment changes win. Payload, rings, schedule and groups can't be changed after creation.

### Multi Admin Approval

- Protects apps, compliance and settings catalog policies, scripts, device actions (wipe, retire, delete), roles, access policies and device categories.
- Flow: request with business justification → a second admin from the approver group approves → requestor selects **Complete**. The access policy itself needs approval too.
- Applies to delegated and app-only Graph calls; the approval code goes in `x-msft-approval-code`. GET is never blocked.
- Approver group: security group with direct members, assigned to an Intune role. Nobody approves their own request. Intune sends no notifications; requests expire after 3 days.
- Be careful with the **Role** access policy – it can lock the RBAC changes MAA itself needs.
- Lab finding 2026-11-23: the Scripts access policy also protects remediations, but only a few minutes after Complete.

### Alerts on Intune changes

- Every change lands in the Intune audit log (Graph `auditEvents`). Diagnostic settings send it to Log Analytics (table `IntuneAuditLogs`) – it arrives within about 30 minutes, so alerts are not real time.
- The [Intune alert builder](../../Toolbox/Builders/intune-alert-builder.html) builds the KQL and the ARM template: **Part A** alerts on audit events (one mail per event), **Part B** checks connectors and tokens once a day.

Sources: Learn – Deployment plans and deployments in Microsoft Intune · Use access policies to require multi admin approval · Use Multi Admin Approval with the Microsoft Graph API · Send Intune log data to Azure Storage, Event Hubs, or Log Analytics · Demos: [Multi Admin Approval](../Demos/multi-admin-approval.html), [Alerts for Intune changes](../Demos/intune-alerts.html)
