---
title: 'Day 2 notes – Security, least privilege, support'
---

# Day 2 notes – Security, least privilege, support

> Summary of what was covered on Day 2, with sources – not a transcript. Recommendations marked "trainer recommendation" are field experience, not Microsoft documentation. Links marked "community" point to non-Microsoft sources.

## Key takeaways

- One setting, one owner: security settings belong in endpoint security policies. The same setting in two policies with different values is a conflict and may not apply at all.
- ASR: the three standard protection rules can go to Block right away, all other rules Audit first.
- App Control for Business: audit first, then enforce. The managed installer (IME) trusts only apps it installs **after** the policy arrived. A removed policy stays active until restart.
- Firewall rules are data – keep them in a file, not in clicks.
- Windows LAPS: one password per device, rotated after use. Reading the password is its own permission – in Graph and in Intune.
- EPM: strong rules (hash, or certificate plus attributes), a safe default response, no broad child process rights.
- Cloud PKI replaces CA, NDES and connector for SCEP. Three CAs per tenant – plan the hierarchy first.
- Remote Help: helpers need RBAC, elevation is its own permission, unattended control is its own permission. Every session is audited.

## 6. Endpoint security and App Control

### Which policy type owns a setting?

| Type | What it is for |
|---|---|
| Endpoint security policy | Focused security settings per workload. "Not configured" by default – only what you set is sent |
| Security baseline | Microsoft-recommended starting point with non-default values. Don't manage the same setting elsewhere |
| Settings catalog | Everything else. Same CSPs as endpoint security – overlaps create conflicts |
| Templates (Endpoint protection) | Legacy only – plan the move |
| Compliance policy | Evaluates the resulting state |

- All configuration policy types have equal priority. Different values for the same setting are a conflict – resolve it by hand. Exceptions that merge: **ASR rules** (superset across ASR policy, endpoint protection profile and Defender baseline) and **antivirus exclusions**.
- Policy types: account protection (incl. Windows LAPS and local user group membership), antivirus, App Control for Business, attack surface reduction, disk encryption (BitLocker, Personal Data Encryption, FileVault), EDR, firewall. EPM has its own node.
- Recommended order for Windows: security baseline → fill gaps with the settings catalog → ADMX for legacy needs → check with compliance.

### Disk encryption

- Use Endpoint security → Disk encryption → BitLocker. The settings catalog alone lacks the TPM startup authentication controls needed for reliable silent enablement.
- Personal Data Encryption encrypts files and releases the keys at Windows Hello sign-in – an addition to BitLocker, not a replacement.
- Rotating recovery keys needs Remote tasks → **Rotate BitLockerKeys**. Status: Devices → Monitor → Encryption report.

### Attack surface reduction

- **ASR rules** modes: Not configured, Off, Audit, Warn, Block. Microsoft recommends the three standard protection rules in Block (vulnerable signed drivers, credential stealing from LSASS, persistence through WMI event subscription); everything else Audit first. `Off` is an explicit value and can conflict, `Not configured` can't.
- Exclusions: global ASR exclusions or per-rule exclusions. Not every rule honors Defender Antivirus exclusions.
- **Device control:** only devices that create a drive letter count as removable media. Intune doesn't honor rule order – exclude explicitly.
- **Exploit protection:** build the XML on a reference device and test every app – per-app mitigations break apps.
- **Network protection** moved to the Antivirus profile. Application Guard is removed in Windows 11 24H2.
- ASR, network protection and controlled folder access need Defender Antivirus in **active mode**. With a third-party antivirus (passive mode) the policies arrive but have no effect. Check: `Get-MpComputerStatus | Select-Object AMRunningMode`.
- Client check: `Get-MpPreference` (rule IDs and actions: 0 Off, 1 Block, 2 Audit, 6 Warn); Windows Defender Operational log events 1121 block, 1122 audit, 1129 warn override.

### App Control for Business

- Use App Control where you can; AppLocker gets security fixes only, but still fits for user- or group-specific rules on shared devices.
- Building blocks: **base policy with built-in controls** (trust Windows components and Store apps, trust managed installers), **base policy as XML**, **supplemental policy** (always XML, same groups as the base).
- **Managed installer:** an AppLocker rule for the IME tags every app it installs after the policy arrived. Device scope only. Remove empty AppLocker rule collections first – they would be enforced with only a dummy rule.
- Client checks: CodeIntegrity Operational log – **3076** audit (would be blocked), **3077** blocked, 3090–3092 managed installer or ISG origin; `CiTool -lp -json`; `fsutil file queryEA` shows the managed installer tag.
- Rollout: audit on a pilot, collect 3076 events, build supplemental rules (App Control Wizard), enforce by group. To remove: deploy an allow-all version first, then delete – a deleted policy stays active until reboot.

### Antivirus, account protection, firewall

- Tamper protection is in the Windows Security experience profile and needs Defender for Endpoint onboarding. Antivirus exclusions merge; for other conflicts the most secure value wins, then the last modified.
- **Local user group membership:** only one policy per device – a second one is a conflict and neither applies. **Add (Replace)** removes every member not in the policy; use **Add (Update)**.
- **Firewall rules:** up to 150 rules per profile, applied all-or-nothing since Windows 11 21H2. `Toolbox\Security\Firewall\New-IntuneFirewallRulePolicy.ps1` builds the policy from a JSON rule file and checks the limits; `-OutputJsonOnly` shows the request body without sign-in. Client check: `Get-NetFirewallRule -PolicyStore ActiveStore`.
- Rules scoped to the **Domain** profile don't apply on Entra joined devices – Windows never activates that profile there.

### Defender for Endpoint and Mobile Threat Defense

- Defender for Endpoint or an MTD partner reports a risk level; Intune compliance uses it; Conditional Access blocks access.
- Plan 1: next-generation protection, ASR, device control, firewall, network protection, application control. Plan 2 adds EDR, automatic investigation, vulnerability management.
- Onboarding with Intune: connect the Defender connector in both portals, then Endpoint security → EDR → **Deploy preconfigured policy** ("Auto from connector" can take up to 15 minutes to appear).
- **Security settings management** brings antivirus, ASR, EDR and firewall policies to devices that have Defender but no Intune enrollment – the way to reach Windows Server from Intune.
- **Security tasks:** Defender vulnerability management creates a task, Intune admins accept and complete it.

Sources: Learn – Manage endpoint security in Microsoft Intune · Manage device security with endpoint security policies · Use security baselines to configure Windows devices · Disk encryption policy for endpoint security · Attack surface reduction rules overview · Use Microsoft Intune policy to manage rules for attack surface reduction · Device control in Microsoft Defender for Endpoint · App Control for Business and AppLocker overview · Manage approved apps for Windows devices with App Control for Business policy and Managed Installers · Understanding App Control events · Antivirus policy for endpoint security · Account protection policy for endpoint security · Policy CSP LocalUsersAndGroups · Firewall policy for endpoint security · Mobile Threat Defense integration with Intune · Configure Microsoft Defender for Endpoint with Intune · Microsoft Defender service description

## 7. Least privilege: LAPS and EPM

### Windows LAPS

- Policy: Endpoint security → Account protection → Windows LAPS, backup to Microsoft Entra ID. The tenant needs **Enable Microsoft Entra LAPS** = Yes in the Entra device settings.
- **Automatic account management** (Windows 11 24H2 and later): LAPS creates and manages its own account – no built-in Administrator needed.
- **Passphrases** (Windows 11 24H2 and later): 3–10 words from a word list – easier to read out on the phone than random characters.
- **Post-authentication actions** after the password was used: reset password, reset and sign out (default), reset and reboot, reset/sign out/terminate processes. Delay 0–24 hours.
- Don't assign two LAPS policies to one device and don't assign LAPS to user groups.
- Read with PowerShell: `Get-LapsAADPassword -DeviceIds <id> -IncludePasswords -AsPlainText`. `DeviceLocalCredential.ReadBasic.All` shows only backup and expiry time, `DeviceLocalCredential.Read.All` the password. The same split exists in Intune RBAC.
- Client: `Invoke-LapsPolicyProcessing`; LAPS log events 10022 policy, 10029 backup to Entra ID, 10041 sign-in detected.

### Endpoint Privilege Management

- Three policy types: **elevation settings** (turns EPM on, installs the agent, default response for files without a rule), **elevation rules** (one rule per file), **elevation system settings** (new: standard users change network settings via the Company Portal).

| Elevation type | When |
|---|---|
| Automatic | Few, trusted, business-critical files |
| User confirmed | Apps IT trusts users to elevate (optionally with justification or Windows authentication) |
| Elevate as current user | Installers and tools that need the user profile |
| Support approved | Rare and risky operations – IT approves, then 24 hours to elevate |
| Deny | Known-bad files and high-risk tools |

- Rule strength: file hash is strongest but changes with every version; certificate plus product or internal name is a strong pair; file name alone can be renamed – never on its own. Always set a file path users can't write to.
- Collisions: deny wins; user-targeted before device-targeted; hash rules first.
- Safe default response: **Require support approval** or **Deny**, not user confirmation.
- "Allow all child processes to run elevated" skips rule evaluation for children, even deny rules – avoid it for shells and script engines.
- Approving requests needs the permission **Endpoint Privilege Management Elevation Requests**. Intune doesn't notify admins about new requests or users about denied ones.
- `EpmTools` on the client: `Get-Policies`, `Get-ElevationRules`, `Get-FileAttributes` (attributes and certificate chain for a rule).
- The elevation report is processed once every 24 hours; the Elevation requests tab is live.

Sources: Learn – Windows LAPS policy settings · Manage Windows LAPS with Microsoft Intune · Windows LAPS passwords and passphrases · Get-LapsAADPassword · Plan and prepare for Endpoint Privilege Management deployment · Creating elevation rules with Endpoint Privilege Management · Support approved file elevations · Monitor your Endpoint Privilege Management policies

## 8. Certificates: PKI refresher and Cloud PKI

- **Refresher:** a certificate is a passport issued by a CA; the CRL lists revoked certificates; trust is anchored at the root CA in Trusted Root Certification Authorities; issuing CAs sign users and devices.
- **SCEP:** the device creates its key and requests the certificate (classic: through NDES and the certificate connector). **PKCS:** the connector creates the key and the certificate is delivered as PFX. **Imported PKCS:** the same certificate on several devices of a user, for example S/MIME.
- The trusted certificate profile must reach the **same target type** as the SCEP profile – SCEP to devices with the trusted profile to users only fails. The SCEP profile's "Root certificate" points to the **root CA** profile.

### Microsoft Cloud PKI

| | Cloud PKI root CA | Bring your own CA |
|---|---|---|
| Root of trust | Root CA in Intune | Your existing private CA (for example ADCS) signs the issuing CA |
| On-premises | Nothing | The existing CA only signs the CSR |

- Both replace NDES and the connector for SCEP; Cloud PKI issues only to Intune-managed devices (Windows, Android, iOS/iPadOS, macOS).
- Up to **3 CAs per tenant** – root, issuing and BYOCA CAs all count.
- RSA 2048, 3072 or 4096; keys in a managed HSM. CRL valid 7 days, refreshed every 3.5 days.
- Keys in the TPM are limited to 2048 bit; 4096 works on Windows only with the Software KSP. With a 1-year validity and 20 % renewal threshold the device renews about 73 days before expiry.

Sources: Learn – Use certificates for authentication in Microsoft Intune · Use SCEP certificate profiles · Configure and use PKCS certificates · Overview of Microsoft Cloud PKI · Microsoft Cloud PKI deployment models · Microsoft Cloud PKI fundamentals

## 9. Remote Help

- Both sides sign in with Microsoft Entra ID; RBAC decides who may help whom; noncompliant devices show a warning; every session is audited (Tenant administration → Remote Help → Monitor). Included in Microsoft 365 E3 since July 2026.
- Permissions: View screen, Take full control, **Elevation** (answer UAC prompts), **Windows unattended control remote sign-in**, plus Offer remote assistance and Remote Assistance Connector – Read. Help Desk Operator lacks unattended control – use a custom role.
- **Elevation:** without it the helper sees a black screen at the UAC prompt (secure desktop). The sharer is signed out automatically only when the **sharer** ends the session after elevation – as helper, close elevated windows before you leave.
- **Unattended (Windows):** corporate, enrolled, Entra or hybrid joined devices with the Azure Virtual Desktop agent and bootloader; one unattended session per device; the signed-in user can deny within 30 seconds.
- Lab observations (trainer, 2026-11-21) that differ from Learn: unattended worked on the Hyper-V course VMs with Remote Desktop off, and sign-in worked only with the local LAPS account `.\etcXAdmin`.
- `Toolbox\Apps\RemoteHelp\Deploy-RemoteHelpUnattendedApps.ps1` packages AVD agent and bootloader with the dependency bootloader → agent – the same upload flow as the Win32 pipeline.
- Remote Help from the Enterprise App Catalog with automatic update: Required to device groups only, no rollback, no rings.

Sources: Learn – Planning for Remote Help with Microsoft Intune · Deploying Remote Help with Microsoft Intune · Using Remote Help with Microsoft Intune
