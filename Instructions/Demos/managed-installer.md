# Demo – Intune Management Extension as managed installer (Module 6)

> **Draft:** This demo hasn't been run in the course tenant yet. If a step behaves differently, the trainer updates this page.

**Duration:** 10 minutes

The trainer shows the managed installer policy that was set up before Day 1 and what it does on a client. Lab 2.6 builds on it: App Control for Business trusts apps that carry the managed installer tag. The policy is set up by the trainer only, because it needs the Intune Administrator role and has to reach your clients before Intune installs anything on them.

**Why before Day 1:** The managed installer tags only apps that Intune installs **after** the policy reached the device. Your clients enroll in Lab 0.1 and get 7-Zip in Lab 1.3 – if the policy arrives later, 7-Zip carries no tag and shows up in Lab 2.6 like any app you started yourself.

## 1. Set up (trainer, before Day 1)

1. Intune admin center → Endpoint security → App Control for Business → **Managed installer** tab → **Create**.
2. Basics: name `MDDMI-Adv Managed installer`, short description.
3. Settings:

   | Setting | Value |
   |---|---|
   | Enable Intune Managed Extension as Managed Installer | **Enabled** (default) |

4. Scope tags: optional.
5. Assignments: include the course device groups (`studentXdevices` of every participant). Managed installer policies apply in device scope only – a group with users in it works, but only its devices get the policy.
6. Review + create → **Create**. The new policy can take up to 10 minutes to show up in the list; select **Refresh**.

## 2. Show it in Module 6

1. **Admin center:** Endpoint security → App Control for Business → Managed installer → the policy from section 1 → Properties: one setting, device groups as assignment.
2. **CL3**, elevated PowerShell – the AppLocker services that do the tagging run:

   ```powershell
   sc.exe query appidsvc
   sc.exe query applockerfltr
   ```

   Both show `STATE : 4 RUNNING`.

3. The managed installer rule collection is on disk – there is at least one `.AppLocker` file each for EXE, DLL and MANAGEDINSTALLER:

   ```powershell
   Get-ChildItem "$env:windir\System32\AppLocker"
   ```

4. 7-Zip from Lab 1.3 carries the tag:

   ```powershell
   fsutil file queryEA "C:\Program Files\7-Zip\7zFM.exe"
   ```

   Look for `$KERNEL.SMARTLOCKER.ORIGINCLAIM`. In the first data row (`0000:`), `00` at the start of the second group of four means managed installer origin (`01` would be the Intelligent Security Graph), and `00` at the start of the third group means the file was written directly by the managed installer.

**What to watch:**

- The managed installer only tags. An App Control for Business policy uses the tag only when **Trust apps from managed installers** is selected – that is what you build in Lab 2.6.
- Apps installed before the policy reached the device have no tag. To give an app the tag, Intune has to install it again after the policy arrived (uninstall it locally and sync).
- Files that an installed app writes later (updates, plug-ins) get the "child of child" value `02` in the third group and are **not** trusted through the managed installer.
- The tag counts only on the Windows volume. Apps installed on another drive need their own App Control rules.
- Since 2025-08-18, managed installer policies can target groups. A tenant that had the old tenant-wide setting got it converted into a policy for all devices.

## 3. Reset after the course

Leave the policy in place for the next course run. Check before the next Day 1 that its assignment still covers the course device groups.

**Sources:** Learn – Manage approved apps for Windows devices with App Control for Business policy and Managed Installers for Microsoft Intune; Learn – Managed installer and ISG technical reference and troubleshooting guide; checked 2026-11-21.
