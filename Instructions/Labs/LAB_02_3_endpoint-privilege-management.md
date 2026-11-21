---
title: 'Lab 2.3 – Endpoint Privilege Management'
lab:
    title: 'Lab 2.3 – Endpoint Privilege Management'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.3 – Endpoint Privilege Management

**Estimated time:** 55 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Let a standard user install Notepad++ with a file hash rule, change network settings, and approve a support request for a file without a rule yourself – without giving anyone local admin rights.

**Why:** Least privilege with exceptions per file instead of local admin rights for everyone. Everything that has no rule goes through a support approval, and every elevation is reported.

**Who is who in this lab:** `etcX` joined CL3 and is a local administrator there. A standard user is any other course user, so you sign in to CL3 with `etcY` – the account the trainer gives you, or the user of another participant number. As admin you work in the Intune admin center as `etcX`, on CL4 or on your own computer.

## Part A – Prepare the file

1. On CL3, signed in as `etcX`: download the current **Notepad++ 64-bit installer** from the official site (notepad-plus-plus.org → Downloads) and save it to `C:\Users\Public\Downloads`. This folder is readable for every user of the device, so `etcY` finds the file later.
2. Remove the download mark (Mark of the Web), then get the file hash and keep it for the rule:

   ```powershell
   Get-ChildItem C:\Users\Public\Downloads\npp.*.Installer.x64.exe | Unblock-File
   Get-ChildItem C:\Users\Public\Downloads\npp.*.Installer.x64.exe | Get-FileHash -Algorithm SHA256 | Format-List Path, Hash
   ```

   `Unblock-File` removes the `Zone.Identifier` stream that Windows adds to downloaded files. The hash stays the same – the stream isn't part of the file content.

## Part B – Policies

3. Intune admin center → Endpoint security → Endpoint Privilege Management → **Policies** → Create Policy → Windows → **Windows elevation settings policy**: policy `etcX-EPM Settings`, assigned to `studentXdevices`.

   | Setting | Value |
   |---|---|
   | Endpoint Privilege Management | **Enabled** |
   | Send elevation data for reporting | **Yes** |
   | Reporting scope | **Diagnostic data and all endpoint elevations** |
   | Default elevation response | **Require support approval** |

4. Create Policy → Windows → **Windows elevation rules policy**: policy `etcX-EPM Rules`, assigned to `studentXdevices`, with one rule:

   | Setting | Value |
   |---|---|
   | Rule name | `Notepad++ installer` |
   | Elevation type | **User confirmed** |
   | Validation | **Business justification** |
   | Child process behavior | **Require rule to elevate** |
   | File name | the exact file name, for example `npp.8.8.8.Installer.x64.exe` |
   | File path | `C:\Users\Public\Downloads` |
   | Signature source | **Not configured** |
   | File hash | the SHA256 hash from step 2 |

   **Why not allow all child processes:** With **Allow all child processes to run elevated**, every process the installer starts runs elevated and EPM skips rule evaluation for it – even deny rules. The Notepad++ installer offers to start Notepad++ at the end; that Notepad++ would run as administrator, and its **Open** dialog can start other programs with the same rights. **Require rule to elevate** lets a child process elevate only with its own rule.

5. Create Policy → Windows → **Elevation system settings policy**: policy `etcX-EPM System Settings`, assigned to `studentXdevices`, with one rule:

   | Setting | Value |
   |---|---|
   | Rule name | `Network settings` |
   | System setting | **Network settings** |
   | Elevation type | **User confirmed** |
   | Validation | **Business justification** |

   This policy lets a standard user change IPv4, IPv6 and DNS server values of the network adapters – for example a static IP address at a site without DHCP – without any other admin rights. It works only together with the elevation settings policy from step 3.

6. Sync CL3 and wait until all three policies show **Succeeded**. The EPM agent is installed only after the settings policy arrived. Check on CL3, as `etcX` in an elevated PowerShell:

   ```powershell
   Get-ChildItem 'C:\Program Files\Microsoft EPM Agent'
   Import-Module 'C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll'
   Get-Policies -PolicyType ElevationRules
   ```

   Your rule with file name and hash must be in the output.

## Part C – Elevate as a standard user

7. Sign out of CL3 and sign in as `etcY`. Check that you are a standard user:

   ```powershell
   whoami /groups | Select-String 'S-1-5-32-544'
   ```

   No output means not a member of Administrators.
8. Open `C:\Users\Public\Downloads`, right-click the Notepad++ installer → **Run with elevated access**, enter a business justification, and install. No UAC credential prompt appears. Leave **Run Notepad++** checked on the last page: Notepad++ doesn't start. It is a child process of the elevated installer and has no rule of its own – that is **Require rule to elevate** at work.
9. Right-click `C:\Windows\regedit.exe` → **Run with elevated access**. There is no rule for it, so the default response applies: enter a reason and send the support request. Stay signed in as `etcY`.
10. While the request waits: Company Portal → **Help & support** → **System settings** tile → **Edit settings**. In **Endpoint Privilege Management - Network Settings**, select the adapter → **Edit** next to IPv4 → **Manual**. The fields already hold the current values from DHCP – leave them as they are, select **Save**, and enter a business justification. Check with `ipconfig /all`: same address, but DHCP is now off. Change it back to **Automatic (DHCP)** the same way.

    Keeping the DHCP values keeps CL3 online – you see the elevation without breaking the lab network.

## Part D – Approve the request yourself

11. As `etcX` in the Intune admin center (CL4 or your computer): Endpoint security → Endpoint Privilege Management → **Elevation requests**. Open the request from CL3 and read file, publisher, device, user and justification. Select **Approve**, enter a reason, and confirm with **Yes**.
12. Back on CL3 as `etcY`: wait for the toast notification that the request was approved. It needs a device sync and can take a few minutes. Then right-click `regedit.exe` → **Run with elevated access** again. Registry Editor opens elevated.

    The approval is valid for this user, this file and this device for 24 hours from the moment you approved it. It can't be revoked before that.

## Part E – Reports

13. Endpoint Privilege Management → **Reports** → **Elevation report**: find the Notepad++ elevation and the network settings changes with the justifications of `etcY`. In the **Elevation requests** tab, the regedit request shows **Approved** with your name and the expiry time.

### Checkpoint

- [ ] `Get-Policies` on CL3 lists your Notepad++ rule
- [ ] Notepad++ installed by `etcY` without admin rights
- [ ] IPv4 settings changed by `etcY` in the Company Portal and set back to DHCP
- [ ] regedit request approved by you and run elevated by `etcY`
- [ ] The elevations in the elevation report (or noted for tomorrow, see the note)

**Note:** The elevation report is processed once every 24 hours. If your elevations are not in the report yet, check again tomorrow morning. The **Elevation requests** tab is live.

**Note:** Approving requests is its own Intune permission: **Endpoint Privilege Management Elevation Requests** (view and modify). Policy authoring does not include it.

**Why a hash rule:** File name and path alone are weak – any user can rename a file. The hash proves it is exactly the file you checked. The trade-off: every new Notepad++ version needs a new hash. In production you combine the publisher certificate with product name and internal name instead.

<!-- Sources: Learn – Managing elevation settings with EPM (Send elevation data for reporting, Reporting scope, Default elevation response); Creating elevation rules with EPM (hash required only for automatic, child process behavior, file name/path weak); Support approved file elevations for EPM (Elevation requests tab, 24 h from approval, toast, no revoke, RBAC Elevation Requests); EPM reports (24 h processing); checked 2026-11-20; Creating elevation rules (Allow child processes: rule evaluation skipped incl. deny rules; tutorial uses Require rule to elevate); Manage system settings with EPM (Elevation system settings policy, Network settings, User confirmed, Company Portal Help & support → System settings), checked 2026-11-21. -->
<!-- VERIFY: network settings changes appear in the elevation report (Learn: justification visible in reporting) -->
<!-- VERIFY: Get-Policies -PolicyType ElevationRules output on the current agent -->
<!-- VERIFY: regedit.exe offers "Run with elevated access" for a standard user (autoElevate manifest) -->
<!-- VERIFY: etcY can sign in to CL3 interactively (no sign-in restriction policy in the lab) -->
