---
title: 'Lab 1.6 – Wrap an app with PSADT and ship it with the pipeline'
lab:
    title: 'Lab 1.6 – Wrap an app with PSADT and ship it with the pipeline'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.6 – Wrap an app with PSADT and ship it with the pipeline

**Estimated time:** 35 minutes

**Goal:** Build a PSAppDeployToolkit (PSADT) v4 package for Firefox ESR – close the app, install the MSI, copy a policy file – and send it through the same pipeline as your 7-Zip app in Lab 1.3.

**Why:** An MSI alone can't ask the user to close the app, copy a configuration file or clean up a shortcut. PSADT gives every package the same structure, the same log and the same user dialogs. For the pipeline it is just another source folder.

Work on CL3. Steps 1–9 run in a normal Windows PowerShell; the local test in step 10 needs one **as administrator**.

### Build the package

1. Install the toolkit module:

   ```powershell
   Install-Module PSAppDeployToolkit -Scope CurrentUser -Force
   ```

2. On CL3, copy `C:\Toolbox\Win32Pipeline\Samples\FirefoxESR` (from Lab 0.1, source: [Toolbox/Apps/Win32Pipeline](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Apps/Win32Pipeline)) to `C:\Software\FirefoxESR`. The folder contains `app.json` and `policies.json`. Then create the PSADT template as the `Source` folder of the app:

   ```powershell
   New-ADTTemplate -Destination C:\Software\FirefoxESR -Name Source
   ```

3. Download the Firefox ESR installer for **Windows 64-bit** as **MSI** from Mozilla's download page (`https://www.mozilla.org/firefox/all/` → Firefox Extended Support Release). Save it as `C:\Software\FirefoxESR\Source\Files\FirefoxESR.msi`. Right-click the MSI → Properties → Details: note the version.

4. Move `policies.json` into the package:

   ```powershell
   Move-Item C:\Software\FirefoxESR\policies.json C:\Software\FirefoxESR\Source\SupportFiles
   ```

5. Open `C:\Software\FirefoxESR\Source\Invoke-AppDeployToolkit.ps1` in the PowerShell ISE or VS Code. **Variables** – in the `$adtSession` block at the top, set these lines (use the major version from step 3 for `AppVersion`):

   ```powershell
   AppVendor = 'Mozilla'
   AppName = 'Firefox ESR'
   AppVersion = '140'
   AppArch = 'x64'
   AppProcessesToClose = @(@{ Name = 'firefox'; Description = 'Mozilla Firefox' })
   ```

   `AppName` must not stay empty: with an empty `AppName` and a single MSI in `Files` the toolkit switches to Zero-Config MSI and installs the MSI on its own.

6. **Pre-Install** – nothing to write. The template already calls `Show-ADTInstallationWelcome` with `AppProcessesToClose`: the user is asked to close Firefox and can defer.

7. **Install** – in `Install-ADTDeployment`, under `## <Perform Installation tasks here>`, add the MSI. The file name is enough, the toolkit looks in `Files`; silent switches, MSI log and exit code 3010 come from the toolkit:

   ```powershell
   Start-ADTMsiProcess -Action Install -FilePath 'FirefoxESR.msi'
   ```

8. **Post-Install** – under `## <Perform Post-Installation tasks here>`, copy the policy file and remove the desktop shortcut. Then delete the `Show-ADTInstallationPrompt` block at the end of the function: a required deployment should not end with a message box.

   ```powershell
   Copy-ADTFile -Path "$($adtSession.DirSupportFiles)\policies.json" -Destination "$envProgramFiles\Mozilla Firefox\distribution"
   Remove-ADTFile -Path "$envCommonDesktop\Firefox.lnk"
   ```

9. **Uninstall** – in `Uninstall-ADTDeployment`, under `## <Perform Uninstallation tasks here>`:

   ```powershell
   $helper = "$envProgramFiles\Mozilla Firefox\uninstall\helper.exe"
   if (Test-Path -LiteralPath $helper) { Start-ADTProcess -FilePath $helper -ArgumentList '/S' }
   Remove-ADTFolder -Path "$envProgramFiles\Mozilla Firefox"
   ```

   Save the file.

### Test locally, then ship

10. Test before Intune sees the package. Open Windows PowerShell **as administrator** (right-click → Run as administrator) – without admin rights the toolkit installs nothing and writes no log to `C:\Windows\Logs\Software`. Install:

    ```powershell
    C:\Software\FirefoxESR\Source\Invoke-AppDeployToolkit.exe -DeploymentType Install
    ```

    Firefox starts with the course page as home page, and `about:policies` lists the three policies. Read the toolkit log and the MSI log in `C:\Windows\Logs\Software`. Leave Firefox open and run the install command again: the toolkit asks you to close Firefox – the same dialog a user sees when Intune installs while Firefox runs. Close Firefox in the dialog. Then remove Firefox again, so that you can watch Intune install it:

    ```powershell
    C:\Software\FirefoxESR\Source\Invoke-AppDeployToolkit.exe -DeploymentType Uninstall
    ```

11. Open `C:\Software\FirefoxESR\app.json`: set `displayName` to `etcX-Firefox ESR` and `version` to the version from step 3. Look at what the file already sets for a PSADT package – setup file, install and uninstall command, return code `1602`, detection on `policies.json`. Then package only and read the request body:

    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\FirefoxESR -PackageOnly
    ```

12. Create the app and assign it:

    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -File C:\Toolbox\Win32Pipeline\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\FirefoxESR -AssignmentGroupName studentXdevices -ScopeTagName Lab-Students
    ```

13. Sync CL3 and watch the installation. When the app shows **Installed**, open Firefox and check `about:policies`.

### Checkpoint

- [ ] Local install and uninstall on CL3 worked, toolkit log in `C:\Windows\Logs\Software`
- [ ] App `etcX-Firefox ESR` exists with detection on `policies.json` and return code 1602 = Retry
- [ ] Firefox ESR installed by Intune, `about:policies` shows the policies
- [ ] You can explain why the app needs `AppName` and its own detection rule

**Why 1602 = Retry:** 1602 means the user deferred. With Retry, Intune tries again three times, five minutes apart. Without the mapping the install counts as failed and the next attempt comes much later.

**Note:** Typical errors: `policies.json` in `Files` instead of `SupportFiles`, detection on the wrong path, v3 function names copied from internet examples (v4 functions all contain `-ADT`). Check a name with `Get-Command <name> -Module PSAppDeployToolkit`.

**Note:** The same package as in the SCMI course (Lab 10.1) – there it replaces a ConfigMgr wrapper, here it runs through the pipeline.

<!-- Source: SCMI Lab 10.1 (tested), Win32Pipeline README (PSADT packages). -->
