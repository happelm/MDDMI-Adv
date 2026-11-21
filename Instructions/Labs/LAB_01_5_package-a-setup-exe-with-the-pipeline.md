---
title: 'Lab 1.5 – Package a setup.exe with the pipeline'
lab:
    title: 'Lab 1.5 – Package a setup.exe with the pipeline'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.5 – Package a setup.exe with the pipeline

**Estimated time:** 30 minutes

**Goal:** Send a setup.exe through the same pipeline as your 7-Zip MSI in Lab 1.3 – with your own install and uninstall commands and your own detection rule.

**Why:** For an MSI the script reads product code and version itself and builds the commands and the detection. A setup.exe gives it nothing: you have to know the silent switches, the uninstall command and how to detect the installed app. That is the normal case for most vendor installers.

1. On CL3, copy `C:\Toolbox\Win32Pipeline\Samples\VLC` (from Lab 0.1, source: [Toolbox/Apps/Win32Pipeline](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Apps/Win32Pipeline)) to `C:\Software\VLC`.
2. Download the current VLC 64-bit installer for Windows (`.exe`, not `.msi`) from <https://www.videolan.org> into `C:\Software\VLC\Source`. VLC releases new versions now and then, so your version may differ from the sample – that is fine.
3. Open `C:\Software\VLC\app.json` and set your values. The version is in the file name, for example `vlc-3.0.21-win64.exe` → `3.0.21`:

   | Key | Value |
   |---|---|
   | `displayName` | `etcX-VLC media player <version> (x64)` |
   | `version` | your version |
   | `setupFile` | the file name of your installer |
   | `installCommand` | `<file name> /L=1033 /S` |
   | `uninstallCommand` | leave as it is: `"C:\Program Files\VideoLAN\VLC\uninstall.exe" /S` |
   | detection `value` | your version |

4. Package only and read the request body. Compare it with the 7-Zip body from Lab 1.3: no `msiInformation`, your commands, and a `win32LobAppFileSystemRule` instead of a product code rule:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\VLC -PackageOnly
   ```

5. Create the app and assign it:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\VLC -AssignmentGroupName studentXdevices -ScopeTagName Lab-Students
   ```

6. Sync CL3 and wait until VLC is installed. Check the file the detection rule looks at:

   ```powershell
   (Get-Item 'C:\Program Files\VideoLAN\VLC\vlc.exe').VersionInfo.FileVersion
   ```

7. Intune admin center → Apps → Windows → `etcX-VLC media player …` → Properties: find your commands and the detection rule as Intune shows them.

### Checkpoint

- [ ] Request body with your commands and a file version detection rule
- [ ] App `etcX-VLC media player <version> (x64)` exists, assigned **Required** to `studentXdevices`, scope tag Lab-Students
- [ ] VLC installed on CL3, file version of `vlc.exe` at least your detection value

**Why the full uninstall path:** The Intune Management Extension runs as a 32-bit process. `%ProgramFiles%` can resolve to `C:\Program Files (x86)` there, and the uninstall would not find the 64-bit app.

**Why greater than or equal:** VLC can update itself. With **Equals** a newer version would count as "not installed", and Intune would install the old version again.

**Note:** Silent switches depend on the installer technology, not on the app. Typical: NSIS `/S`, Inno Setup `/VERYSILENT /NORESTART`, InstallShield `/s /v"/qn"`. Check the vendor documentation or run `setup.exe /?` first. For an EXE that wraps an MSI, extract the MSI and use the MSI instead.
