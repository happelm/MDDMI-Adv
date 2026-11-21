---
title: 'Lab 2.1 – Endpoint security policies'
lab:
    title: 'Lab 2.1 – Endpoint security policies'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.1 – Endpoint security policies

**Estimated time:** 50 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Create the core endpoint security policies for CL3 in one block, check the BitLocker state the device already has, and verify every policy on the client with expected values.

**Why:** Endpoint security policies are the single place for security settings. A setting that is configured in two places is a conflict, and a conflict means the setting is not applied.

Create all policies in Intune admin center → Endpoint security, platform **Windows**, assigned to `studentXdevices`. Create all of them first, then check the client once in Part C.

## Part A – Create the policies

1. **Antivirus** → Create Policy → Windows → **Microsoft Defender Antivirus**: policy `etcX-AV`.

   | Setting | Value |
   |---|---|
   | Allow Realtime Monitoring | **Allowed** |
   | Allow Behavior Monitoring | **Allowed** |
   | Allow Cloud Protection | **Allowed** |
   | Cloud Block Level | **High** |
   | Submit Samples Consent | **Send safe samples automatically** |
   | Excluded Paths | `C:\Source` |

2. **Attack surface reduction** → Create Policy → Windows → **Attack Surface Reduction Rules**: policy `etcX-ASR Audit`.

   | Setting | Value |
   |---|---|
   | Block all Office applications from creating child processes | **Audit** |
   | Block credential stealing from the Windows local security authority subsystem | **Audit** |

   Leave every other rule **Not configured**.

3. **Account protection** → Create Policy → Windows → **Local user group membership**: policy `etcX-Local Admins`.

   | Setting | Value |
   |---|---|
   | Local group | **Administrators** |
   | Group and user action | **Add (Update)** |
   | User selection type | **Users/Groups** |
   | Selected users | `studentXusers` |

4. On CL3, open PowerShell in `C:\Toolbox\Firewall` (from Lab 0.1, source: [Toolbox/Security/Firewall](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Security/Firewall)) and look at the request body first. Nothing is created and you don't sign in:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\New-IntuneFirewallRulePolicy.ps1 -OutputJsonOnly
   ```

   The rule file `DomainProfileRules.json` holds 13 inbound management rules (ping, SMB, RDP, WinRM, WMI, remote event log, services, scheduled tasks, firewall). Each rule has `%MANAGEMENT%` as remote address. `-ManagementAddress` replaces that placeholder: an IP, a subnet like `10.0.0.0/24`, a range, or a keyword like `LocalSubnet` (the default). In production you put the subnet of your admin jump hosts there.

5. Create the policy and assign it in one go. Sign in with your `etcX` account and confirm tenant and account when the script asks:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\New-IntuneFirewallRulePolicy.ps1 -PolicyName "etcX-Firewall Rules" -ManagementAddress LocalSubnet -AssignmentGroupName studentXdevices
   ```

   **Alternative:** the [Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Toolbox/Builders/firewall-rule-builder.html) builds your own rule file from rule groups in the browser. Pass it with `-RuleFile`.

## Part B – BitLocker: check what is already there

CL3 encrypts its OS drive automatically (Windows device encryption on Entra join), so you don't deploy a BitLocker policy in this lab. A policy deployed afterwards would not change the encryption method of a drive that is already encrypted.

6. On CL3, in an elevated PowerShell:

   ```powershell
   manage-bde -status C:
   Get-BitLockerVolume -MountPoint C: | Select-Object MountPoint, VolumeStatus, EncryptionMethod, EncryptionPercentage, ProtectionStatus, KeyProtector
   ```

7. Intune admin center → Devices → Windows → CL3-yourname → **Recovery keys**: the key ID shown here must match the ID of the `RecoveryPassword` protector on the client.
8. Devices → Monitor → **Encryption report**: find CL3 and open it. Read **Encryption readiness** and **Encryption status**.

## Part C – Check everything on CL3

9. Sync CL3 (Settings → Accounts → Access work or school → Info → **Sync**) and wait until all four policies show **Succeeded** under Endpoint security → the policy → Device and user check-in status.
10. Antivirus and ASR:

    ```powershell
    Get-MpPreference | Select-Object DisableRealtimeMonitoring, DisableBehaviorMonitoring, MAPSReporting, CloudBlockLevel, SubmitSamplesConsent, ExclusionPath
    Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids
    Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Actions
    ```

    | Property | Expected |
    |---|---|
    | `DisableRealtimeMonitoring` | `False` |
    | `DisableBehaviorMonitoring` | `False` |
    | `CloudBlockLevel` | `2` (High) |
    | `ExclusionPath` | `C:\Source` |
    | `AttackSurfaceReductionRules_Ids` | `d4f940ab-401b-4efc-aadc-ad5f3c50688a` (Office child processes) and `9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2` (LSASS) |
    | `AttackSurfaceReductionRules_Actions` | `2` for both (2 = Audit, 1 = Block, 6 = Warn) |

11. Local administrators:

    ```powershell
    net localgroup Administrators
    ```

    Expected: the existing members plus an entry for `studentXusers` (shown as SID).
12. Your firewall rules, filtered to the rules from the policy:

    ```powershell
    Get-NetFirewallRule -PolicyStore ActiveStore |
        Where-Object DisplayName -in (Get-Content C:\Toolbox\Firewall\DomainProfileRules.json | ConvertFrom-Json).rules.name |
        Select-Object DisplayName, Direction, Action, Profile, Enabled
    ```

    Expected: 13 rules, direction **Inbound**, action **Allow**, profile **Domain**.

## Part D – Optional: build a conflict and find it

13. Devices → Configuration → Create → Windows 10 and later → **Settings catalog**: profile `etcX-Conflict`, category **Defender** → **Cloud Block Level** = **High Plus**, assigned to `studentXdevices`.
14. Sync CL3. Look at `etcX-AV` and `etcX-Conflict` → device status: both report **Conflict** for this setting. Check `Get-MpPreference | Select-Object CloudBlockLevel` on CL3 and note which value the client actually has.
15. Delete `etcX-Conflict` and sync again.

### Checkpoint

- [ ] `etcX-AV`, `etcX-ASR Audit`, `etcX-Local Admins` and `etcX-Firewall Rules` show **Succeeded** for CL3
- [ ] `ExclusionPath` is `C:\Source`, `CloudBlockLevel` is `2`, both ASR rules have action `2`
- [ ] OS drive **Fully Encrypted**, protection **On**, recovery key ID in Intune matches the client
- [ ] `studentXusers` is a member of the local Administrators group
- [ ] 13 rules of `etcX-Firewall Rules` in the active store
- [ ] Optional: you saw the conflict in the policy status and removed it

**Note:** **Add (Replace)** in local user group membership removes every member that is not in the policy, including accounts you still need, for example the LAPS account from Lab 2.2. Use **Add (Update)**.

**Note:** The firewall rules apply to the **Domain** profile only. CL3 is Entra joined and not a domain member, so Windows never uses the Domain profile there: the rules arrive and show in the store but don't open any port on CL3. The rule file is built for hybrid joined devices, where the Domain profile is active in the company network.

**Why audit first:** ASR rules in **Block** break line-of-business apps that do exactly what the rule blocks. Run them in **Audit**, read the events (Event Viewer → Microsoft → Windows → Windows Defender → Operational, event ID 1122 for audit) or the ASR report, then switch rule by rule to **Block**.

<!-- Sources: Learn – Settings for Microsoft Defender Antivirus policy in Microsoft Intune for Windows devices (Cloud block level High/High plus); Attack surface reduction rules reference (GUIDs, 0 off / 1 block / 2 audit / 6 warn, event 1121 block / 1122 audit); Manage local groups with Intune account protection policy (Add (Update) / Add (Replace)); checked 2026-11-20. -->
<!-- VERIFY: exact display names in the AV profile (Allow Realtime Monitoring etc.) on the 2611 UI -->
<!-- VERIFY: CloudBlockLevel value 2 in Get-MpPreference with tamper protection on (Learn: changes don't apply when tamper protection is enabled) -->
<!-- VERIFY: MDM firewall rules visible in ActiveStore with their DisplayName -->
<!-- VERIFY: which value wins on the client in the conflict step (expected: neither change is applied, previous value stays) -->
<!-- VERIFY: CL3 auto encryption is XTS-AES 128 used space only, recovery key escrowed to Entra -->
