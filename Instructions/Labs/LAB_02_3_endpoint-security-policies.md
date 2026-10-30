---
title: 'Lab 2.3 – Endpoint security policies'
lab:
    title: 'Lab 2.3 – Endpoint security policies'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.3 – Endpoint security policies

**Estimated time:** 45 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Create the core endpoint security policies for your client in one block – and check them on CL3 at the end.

Create all policies in Intune admin center → Endpoint security, platform **Windows**, assigned to `studentXdevices`. Don't check the client in between.

1. Antivirus → Microsoft Defender Antivirus: policy `etcX-AV` with real-time protection, cloud-delivered protection and an exclusion for `C:\Source`.
2. Disk encryption → BitLocker: policy `etcX-BitLocker` – require device encryption, encrypt the OS drive silently, back up the recovery key to Microsoft Entra ID.
3. Attack surface reduction → Attack Surface Reduction Rules: policy `etcX-ASR Audit` with **Block all Office applications from creating child processes** and **Block credential stealing from the Windows local security authority subsystem**, both in **Audit** mode.
4. Account protection → Local user group membership: policy `etcX-Local Admins` that adds your user group `studentXusers` to the local group **Administrators** with action **Add (Update)**.
5. Firewall rules with the script from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) (folder `Firewall`). First the request body only, then the policy:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\New-IntuneFirewallRulePolicy.ps1 -OutputJsonOnly
   ```

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\New-IntuneFirewallRulePolicy.ps1 -PolicyName "etcX-Firewall Rules" -ManagementAddress LocalSubnet -AssignmentGroupName studentXdevices
   ```

6. Sync CL3 and check each policy:

   ```powershell
   Get-MpPreference | Select-Object DisableRealtimeMonitoring, ExclusionPath, AttackSurfaceReductionRules_Ids, AttackSurfaceReductionRules_Actions
   manage-bde -status C:
   net localgroup Administrators
   Get-NetFirewallRule -PolicyStore ActiveStore | Select-Object DisplayName, Direction, Action
   ```

### Checkpoint

- [ ] All policies show **Succeeded** for CL3
- [ ] `ExclusionPath` contains `C:\Source`, two ASR rules in audit mode
- [ ] OS drive encrypted, recovery key visible in the device view
- [ ] Firewall rules from your policy in the active store

**Note:** **Add (Replace)** in local user group membership removes every member that is not in the policy – including accounts you still need. Use **Add (Update)**.

**Why:** Configuration profiles and endpoint security policies can set the same setting – that is a conflict. Keep security settings in one place.

<!-- VERIFY: vTPM on CL3 for silent BitLocker -->
<!-- VERIFY: ASR audit value 2 in Get-MpPreference -->
<!-- VERIFY: MDM firewall rules in ActiveStore -->
<!-- VERIFY: adapted from MDDMI Lab 3.3 (own tenants) – shared tenant not tested -->
