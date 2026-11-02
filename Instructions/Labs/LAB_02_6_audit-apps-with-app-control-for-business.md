---
title: 'Lab 2.6 – Audit apps with App Control for Business'
lab:
    title: 'Lab 2.6 – Audit apps with App Control for Business'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.6 – Audit apps with App Control for Business

**Estimated time:** 30 minutes, if time permits

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Run App Control for Business in audit mode on CL3 and tell apps from the managed installer apart from apps you started yourself.

**Why:** Audit mode blocks nothing but logs every file that an enforced policy would block. That log is your list of rules to add before you enforce.

The trainer has already set the Intune Management Extension as managed installer for the course devices. Apps that Intune installed since then – like your 7-Zip from Lab 1.3 – carry the managed installer tag.

1. On CL3, check the managed installer rule in an elevated PowerShell:

   ```powershell
   Get-AppLockerPolicy -Effective -Xml | Select-String ManagedInstaller
   ```

2. Intune admin center → Endpoint security → App Control for Business → **App Control for Business** tab → **Create Policy**: policy `etcX-AppControl Audit`.

   | Setting | Value |
   |---|---|
   | Configuration settings format | **Built-in controls** |
   | Enable trust of Windows components and store apps | **Audit only** |
   | Select additional options for trusting apps | **Trust apps from managed installers** |

   Assign it to `studentXdevices`. App Control policies apply only in device scope.
3. Sync CL3. Check the active policies:

   ```powershell
   CiTool --list-policies | Select-String -Context 0,3 "63D1178A"
   ```

4. Download a portable tool that Intune did not install – for example Process Explorer from Sysinternals – to `Downloads`, extract it and start it.
5. Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → **Operational**: find event **3076** for the tool from step 4.
6. Start 7-Zip from Lab 1.3. Look for its events in the same log and check the managed installer tag on the file:

   ```powershell
   fsutil file queryEA "C:\Program Files\7-Zip\7zFM.exe"
   ```

### Checkpoint

- [ ] Policy `etcX-AppControl Audit` shows **Succeeded** for CL3
- [ ] Event 3076 for the downloaded tool – it would be blocked in enforce mode
- [ ] 7-Zip carries the managed installer tag and has no 3076 event

**Note:** Never switch this policy to enforce in the course tenant. If you remove an App Control policy, it stays active on the device until the next restart.

**Note:** The managed installer tags only apps that Intune installs after the managed installer policy reached the device. Apps installed earlier need their own rules, for example a supplemental policy built with the App Control Wizard from the 3076 events.

<!-- Sources: Learn – Manage approved apps for Windows devices with App Control for Business policy and Managed Installers (built-in controls, Audit only, device scope, PolicyID 63D1178A for Windows components + managed installers); Learn – Automatically allow apps deployed by a managed installer (fsutil, events 3090-3092); Learn – Understanding App Control events (3076); checked 2026-11-02. -->
<!-- VERIFY: trainer prep – managed installer policy for the student device groups before Day 1 (Lab 1.3) -->
<!-- VERIFY: Lab-Administrator for Students has the App Control for Business permission -->
<!-- VERIFY: CiTool output format on CL3 and whether the policy is active without restart -->
<!-- VERIFY: event for 7-Zip in audit mode (3091 origin audited?) and fsutil output naming -->
<!-- VERIFY: 7zFM.exe path from the Win32 pipeline sample -->
