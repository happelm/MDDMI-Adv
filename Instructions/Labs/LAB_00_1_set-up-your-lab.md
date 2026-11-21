---
title: 'Lab 0.1 – Set up your lab'
lab:
    title: 'Lab 0.1 – Set up your lab'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 0.1 – Set up your lab

**Estimated time:** 25 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Bring CL3 and CL4 into the training tenant and into your device group, named so that everybody can find them, and sign in with Windows Hello.

1. Get your user `etcX` and your number X from the trainer.
2. Start CL3. OOBE begins: select your region and keyboard layout, skip the second keyboard layout.
3. The network connects automatically. If Windows checks for updates, wait until it is done.
4. When OOBE asks for the device name, enter `CL3-yourname` and select **Next**. The client restarts.
5. Select **Set up for work or school** and sign in with `etcX` – this joins the client to Microsoft Entra ID. Complete MFA.
6. Choose any privacy settings.
7. Set up Windows Hello with a PIN when Windows asks for it.

   > **Wait with the enhanced session until your PIN is set up:** Hyper-V may show a window with a **screen resolution slider** (enhanced session). Close it for now and don't select **Connect** yet – Connect switches the console to an RDP connection, and the Windows Hello PIN setup fails over RDP. Once the PIN works, you can use the enhanced session (for example for copy and paste). If you already connected: View → **Enhanced Session** (clear the checkmark), then set up the PIN again.

8. Repeat steps 2–7 on CL4 with the device name `CL4-yourname`.
9. Entra admin center → Groups → `studentXdevices` → Members: add `CL3-yourname` and `CL4-yourname`.
10. From now on, every object you create in the tenant starts with `etcX-`.
11. On CL3, get all scripts and lab files of this course in one go. Open Windows PowerShell and run:

    ```powershell
    $zip = "$env:TEMP\MDDMI-Adv.zip"
    Invoke-WebRequest https://github.com/happelm/MDDMI-Adv/archive/refs/heads/main.zip -OutFile $zip -UseBasicParsing
    Expand-Archive $zip "$env:TEMP\MDDMI-Adv" -Force
    New-Item C:\Toolbox -ItemType Directory -Force | Out-Null
    Get-ChildItem "$env:TEMP\MDDMI-Adv\MDDMI-Adv-main\Toolbox" -Directory -Exclude Builders |
        Get-ChildItem -Directory | Copy-Item -Destination C:\Toolbox -Recurse -Force
    Get-ChildItem C:\Toolbox -Recurse -File | Unblock-File
    Get-ChildItem C:\Toolbox
    ```

    Every folder of the [Toolbox](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox) lands directly under `C:\Toolbox`, for example `C:\Toolbox\Assignments` or `C:\Toolbox\Win32Pipeline`. The labs use these paths. The builders are web pages and stay online.

### Checkpoint

- [ ] `dsregcmd /status` on CL3 and CL4: `AzureAdJoined : YES`
- [ ] Both devices listed in Intune admin center → Devices → Windows
- [ ] Both devices are members of `studentXdevices`
- [ ] Sign-in with your Windows Hello PIN works on CL3 and CL4
- [ ] `C:\Toolbox` on CL3 contains the script folders, for example `Assignments` and `Win32Pipeline`

**If a device is joined but not in Intune:** MDM auto-enrollment did not run. Download `Autoenroll.ps1` from [Toolbox/Identity/Enrollment](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Identity/Enrollment) and run it in an elevated PowerShell on that client. The script writes the Intune enrollment URLs to `HKLM\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\<tenant ID>` and starts the enrollment with `deviceenroller.exe /c /AutoEnrollMDM` – the device enrolls as corporate device. Check the checkpoint again after a few minutes.

**Note:** A computer name has at most 15 characters – shorten `yourname` if needed. Your roles only reach devices whose name matches the lab naming pattern, so keep the `CL3-` / `CL4-` prefix.

**Note:** The user who joins a device to Microsoft Entra ID becomes a local administrator on it. Other users of the tenant sign in as standard users – Lab 2.3 (Endpoint Privilege Management) uses this.

**Why:** Every assignment in the following labs targets `studentXdevices` or `studentXusers`. A device that is not in your group gets nothing.

<!-- Same setup as MDDMI-TS Lab 0.1. -->

<!-- VERIFY: OOBE screen order on 26H2 Pro (region, keyboard, network/updates, device name + restart, work or school, privacy, Hello) – order reworked 2026-11-21 per trainer. Enhanced session warning: trainer finding 2026-11-21. -->
