---
title: 'Lab 2.2 – Audit apps with App Control for Business'
lab:
    title: 'Lab 2.2 – Audit apps with App Control for Business'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.2 – Audit apps with App Control for Business

**Estimated time:** 30 minutes

**Goal:** Run App Control for Business in audit mode on CL3 and tell apps from the managed installer apart from apps you started yourself.

**Why:** Audit mode blocks nothing but logs every file that an enforced policy would block. That log is your list of rules to add before you enforce.

Before Day 1, the trainer set the Intune Management Extension as managed installer for the course device groups. Your clients got that policy when they enrolled in Lab 0.1, so every app Intune installed after that – like your 7-Zip from Lab 1.3 – carries the managed installer tag. The setup is described in the [managed installer demo](../Demos/managed-installer.html).

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
   (CiTool -lp -json | ConvertFrom-Json).Policies |
       Where-Object FriendlyName -like '*AppControl*' |
       Select-Object PolicyID, FriendlyName, IsEnforced
   ```

   Use `-json`: when the text output of CiTool goes into a pipe, CiTool waits for **Enter** and seems to hang.

   Your policy shows with its own policy ID and your policy name as `FriendlyName`. Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → **Operational** shows the same name in event 3099 ("Refreshed and activated Code Integrity policy"). The log file behind it is `C:\Windows\System32\winevt\Logs\Microsoft-Windows-CodeIntegrity%4Operational.evtx`. The same events in PowerShell:

   ```powershell
   Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -MaxEvents 200 |
       Where-Object Id -eq 3099 | Select-Object -First 5 TimeCreated, Message | Format-List
   ```

4. Download a portable tool that Intune did not install: [Process Explorer](https://download.sysinternals.com/files/ProcessExplorer.zip) from Sysinternals ([Learn page](https://learn.microsoft.com/sysinternals/downloads/process-explorer)). Save it to `Downloads`, extract it and start `procexp64.exe`.
5. Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → **Operational**: find event **3076** for the tool from step 4.
6. Start 7-Zip from Lab 1.3. Look for its events in the same log and check the managed installer tag on the file:

   ```powershell
   fsutil file queryEA "C:\Program Files\7-Zip\7zFM.exe"
   ```

   Look for `Ea-Name: $KERNEL.SMARTLOCKER.ORIGINCLAIM` and the first data row `0000:`. Count its values from the left:

   <pre><code>0000:  01 00 00 00 <span style="color:#d1242f;font-weight:bold">00</span> 00 00 00  <span style="color:#d1242f;font-weight:bold">00</span> 00 00 00 01 00 00 00</code></pre>

   | Value | Here | Meaning |
   |---|---|---|
   | <span style="color:#d1242f;font-weight:bold">5th</span> | `00` | Origin is the managed installer (`01` would be the Intelligent Security Graph) |
   | <span style="color:#d1242f;font-weight:bold">9th</span> | `00` | The managed installer wrote the file itself (`02` = written later by the installed app, not trusted through the managed installer) |

7. Counter-test: run the same check on the tool you downloaded yourself in step 4 (adjust the path to where you extracted it):

   ```powershell
   fsutil file queryEA "$env:USERPROFILE\Downloads\ProcessExplorer\procexp64.exe"
   ```

   There is no `$KERNEL.SMARTLOCKER.ORIGINCLAIM` entry: no managed installer wrote this file, so nothing vouches for it – that is why it has a 3076 event and 7-Zip doesn't. To list both side by side:

   ```powershell
   Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -MaxEvents 500 |
       Where-Object { $_.Id -eq 3076 -and $_.Message -match 'procexp|7z' } |
       Select-Object -First 10 TimeCreated, Message | Format-List
   ```

   Only Process Explorer shows up.

### Checkpoint

- [ ] Policy `etcX-AppControl Audit` shows **Succeeded** for CL3
- [ ] Event 3076 for the downloaded tool – it would be blocked in enforce mode
- [ ] 7-Zip carries the managed installer tag and has no 3076 event
- [ ] Process Explorer has no managed installer tag (counter-test)

**Note:** Never switch this policy to enforce in the course tenant. If you remove an App Control policy, it stays active on the device until the next restart.

**Note:** The managed installer tags only apps that Intune installs after the managed installer policy reached the device. Apps installed earlier need their own rules, for example a supplemental policy built with the App Control Wizard from the 3076 events.

<!-- Sources: Learn – Manage approved apps for Windows devices with App Control for Business policy and Managed Installers (built-in controls, Audit only, device scope, built-in controls policy); Learn – Automatically allow apps deployed by a managed installer (fsutil, events 3090-3092); Learn – Understanding App Control events (3076); checked 2026-11-02. -->
<!-- Trainer prep (before Day 1, before Lab 0.1): see Instructions/Demos/managed-installer.md. -->
<!-- CiTool: text output into a pipe waits for Enter (Learn OSConfig article: "select the Enter key twice"); -json + ConvertFrom-Json per Learn CiTool reference, checked 2026-11-21. -->
<!-- 2026-11-24: renumbered 2.6 -> 2.2 (Michael); added full log path, Get-WinEvent lines and counter-test step 7 (untested). -->
<!-- Tested by Michael 2026-11-21: works; CiTool lists the policy with its own GUID and the Intune policy name as FriendlyName (event 3099). -->
