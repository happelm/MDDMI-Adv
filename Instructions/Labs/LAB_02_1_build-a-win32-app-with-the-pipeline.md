---
title: 'Lab 2.1 – Build a Win32 app with the pipeline'
lab:
    title: 'Lab 2.1 – Build a Win32 app with the pipeline'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.1 – Build a Win32 app with the pipeline

**Estimated time:** 40 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Turn an app folder into a Win32 app in Intune with one script call.

1. Copy `Win32Pipeline` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) to `C:\Labfiles` and `Samples\7-Zip` to `C:\Software\7-Zip` on CL3.
2. Download the 7-Zip MSI (x64) from <https://www.7-zip.org> into `C:\Software\7-Zip\Source`. Set `setupFile` in `app.json` to the file name.
3. In `app.json`, set `displayName` to `etcX-7-Zip (x64)`.
4. Package only and read the request body:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Labfiles\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly
   ```

5. Create the app and assign it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Labfiles\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -AssignmentGroupName studentXdevices
   ```

6. Sync CL3 and watch the installation.

### Checkpoint

- [ ] App `etcX-7-Zip (x64)` exists with MSI detection
- [ ] Assigned **Required** to `studentXdevices`
- [ ] 7-Zip installed on CL3

**Note:** The script downloads IntuneWinAppUtil.exe if it is missing. An app with the same name and version is skipped; `-Force` creates it again.

<!-- VERIFY: Win32Pipeline README names CL1 – align with CL3 -->
<!-- VERIFY: internet access from CL3 for the downloads -->
<!-- VERIFY: DeviceManagementApps.ReadWrite.All consent and app rights of the Lab-Administrator role -->
