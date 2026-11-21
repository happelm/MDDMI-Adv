---
title: 'Lab 1.3 – Build a Win32 app with the pipeline'
lab:
    title: 'Lab 1.3 – Build a Win32 app with the pipeline'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.3 – Build a Win32 app with the pipeline

**Estimated time:** 40 minutes

**Goal:** Turn an app folder into a Win32 app in Intune with one script call.

1. On CL3, copy `C:\Toolbox\Win32Pipeline\Samples\7-Zip` (from Lab 0.1, source: [Toolbox/Apps/Win32Pipeline](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Apps/Win32Pipeline)) to `C:\Software\7-Zip`.
2. Download the current 7-Zip MSI (x64) from <https://www.7-zip.org> into `C:\Software\7-Zip\Source`. Set `setupFile` in `app.json` to the file name, for example `7z2606-x64.msi`. 7-Zip releases new versions often, so your version may differ – that is fine.
3. In `app.json`, set `displayName` to `etcX-7-Zip <version> (x64)` with the version you downloaded, for example `etcX-7-Zip 26.06 (x64)`.
4. Package only and read the request body:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly
   ```

5. Create the app and assign it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -AssignmentGroupName studentXdevices -ScopeTagName Lab-Students
   ```

6. Sync CL3 and watch the installation.

### Checkpoint

- [ ] App `etcX-7-Zip <version> (x64)` exists with MSI detection
- [ ] Assigned **Required** to `studentXdevices`
- [ ] 7-Zip installed on CL3

**Note:** The script downloads IntuneWinAppUtil.exe if it is missing. An app with the same name and version is skipped; `-Force` creates it again. The version in Intune comes from the MSI (`ProductVersion`, for example `26.06.00.0`), the name is your text from `app.json`.

