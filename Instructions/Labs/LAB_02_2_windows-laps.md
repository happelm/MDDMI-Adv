---
title: 'Lab 2.2 – Windows LAPS'
lab:
    title: 'Lab 2.2 – Windows LAPS'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.2 – Windows LAPS

**Estimated time:** 40 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Let Windows LAPS create and manage its own local administrator account on CL3, read the password in the portal and with Graph, sign in with it, and watch what happens after the sign-in.

**Why:** The same local administrator password on every device is one of the easiest ways to move laterally in a network. On cloud-native devices the built-in Administrator is disabled, so classic LAPS has nothing to manage. Since Windows 11 24H2, **automatic account management** creates and manages the account for you. CL3 runs 26H2.

## Part A – Policy

1. Intune admin center → Endpoint security → Account protection → Create Policy → Windows → **Local admin password solution (Windows LAPS)**: policy `etcX-LAPS`, assigned to `studentXdevices`.

   | Setting | Value |
   |---|---|
   | Backup Directory | **Backup the password to Azure AD only** (Microsoft Entra ID) |
   | Password Age Days | `7` |
   | Administrator Account Name | leave empty |
   | Password Complexity | **Large letters + small letters + numbers + special characters** |
   | Password Length | `16` |
   | Post Authentication Actions | **Reset the password and logoff the managed account** |
   | Post Authentication Reset Delay | `1` (hours) |
   | Automatic Account Management Enabled | **The target account will be automatically managed** |
   | Automatic Account Management Target | **Manage a new custom administrator account** |
   | Automatic Account Management Name Or Prefix | `etcXAdmin` |
   | Automatic Account Management Enable Account | **The target account will be enabled** |
   | Automatic Account Management Randomize Name | **The name of the target account will not use a random numeric suffix** |

   With an empty **Administrator Account Name** and automatic account management on, LAPS creates `etcXAdmin`, adds it to the local Administrators group and manages it. `7` days is the minimum password age when the backup goes to Entra ID.

## Part B – Watch the client

2. Sync CL3. Then process the LAPS policy right away instead of waiting for the hourly cycle, in an elevated PowerShell:

   ```powershell
   Invoke-LapsPolicyProcessing
   Get-LocalUser etcXAdmin | Select-Object Name, Enabled, PasswordLastSet
   net localgroup Administrators
   ```

3. Event Viewer → Applications and Services Logs → Microsoft → Windows → **LAPS** → **Operational**, or:

   ```powershell
   Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -MaxEvents 30 |
       Select-Object TimeCreated, Id, Message | Format-Table -Wrap
   ```

   | Event ID | Meaning |
   |---|---|
   | 10003 | Policy processing started |
   | 10022 | Current policy: backup directory, account name, age, complexity, length, post-authentication actions |
   | 10029 | New password stored in Microsoft Entra ID |
   | 10020 | Local account updated with the new password |
   | 10004 | Policy processing succeeded (10005 = failed, with error code) |

## Part C – Read the password

4. Intune admin center → Devices → Windows → CL3-yourname → **Local admin password** → **Show local administrator password**. Note account name, password, last rotation and next rotation.
5. Read it with Graph, like in Lab 1.1. On CL3, get the Entra device ID first:

   ```powershell
   $deviceId = ((dsregcmd /status | Select-String -Pattern '^\s*DeviceId\s*:' | Select-Object -First 1).Line -split ':')[1].Trim()
   $deviceId
   ```

   Then sign in with your `etcX` account and read the credential:

   ```powershell
   Connect-MgGraph -Scopes Device.Read.All, DeviceLocalCredential.Read.All -NoWelcome
   $uri = "https://graph.microsoft.com/v1.0/directory/deviceLocalCredentials/$deviceId`?`$select=credentials"
   $info = Invoke-MgGraphRequest -Method GET -Uri $uri
   $info.credentials | Select-Object accountName, backupDateTime, @{n='password';e={ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.passwordBase64)) }}
   ```

   The response holds the current password and the history. `passwordBase64` is the password as Base64.
6. Short way with the LAPS module that ships with Windows (it uses the Graph PowerShell modules underneath):

   ```powershell
   Get-LapsAADPassword -DeviceIds $deviceId -IncludePasswords -AsPlainText
   ```

## Part D – Use the account and watch the post-authentication action

7. Sign out of CL3. Sign in as **Other user** with `.\etcXAdmin` and the password from step 4. Open an elevated PowerShell: no UAC credential prompt, you are a local administrator.
8. Still signed in as `etcXAdmin`, check the log:

   ```powershell
   Get-WinEvent -LogName 'Microsoft-Windows-LAPS/Operational' -MaxEvents 10 | Select-Object TimeCreated, Id, Message | Format-Table -Wrap
   ```

   Event **10041**: LAPS detected the sign-in of the managed account and scheduled the post-authentication action, with the deadline in the event text. When the reset delay (1 hour in your policy) has passed, you see **10042** (grace period expired) and **10044** (password reset and actions done), and the account is signed out.
9. Sign out and sign in again as `etcX`. Intune admin center → CL3-yourname → **Rotate local admin password**. Sync CL3, then read the password again (step 4 or 5).
10. At the end of the day, look at the password once more: the post-authentication action has rotated it a second time.

### Checkpoint

- [ ] Local account `etcXAdmin` exists on CL3, is enabled and is a member of Administrators
- [ ] Events 10022 and 10029 in the LAPS log, 10041 after the sign-in as `etcXAdmin`
- [ ] Same password in Intune and in your Graph output
- [ ] Sign-in as `.\etcXAdmin` works
- [ ] New password after **Rotate local admin password**

**Note:** Reading the password is its own permission. With `DeviceLocalCredential.ReadBasic.All` you see backup and rotation time, not the password. In Entra ID, a role with `microsoft.directory/deviceLocalCredentials/password/read` is needed, for example Cloud Device Administrator.

**Note:** Don't assign two LAPS policies to the same device and don't assign LAPS to user groups. LAPS manages exactly one account per device, and conflicting policies stop the backup.

**Why post-authentication actions:** A LAPS password that was used is a known password. The reset after the delay makes sure it is valid only for one support case.

<!-- Sources: Learn – Configure policy settings for Windows LAPS (AutomaticAccountManagement* defaults, 24H2+, PostAuthenticationActions 3 = reset + logoff, delay hours); Microsoft Intune support for Windows LAPS; Deploy Windows LAPS policy with Microsoft Intune (one policy per device, device groups); Tutorial cloud-native endpoints (built-in admin disabled, LAPS creates accounts only with automatic account management); Use Windows LAPS event logs (10003/10004/10005, 10022, 10029, 10020, 10041/10042/10044); Get-LapsAADPassword (Graph library, permissions, -DeviceIds name or ID); deviceLocalCredentialInfo resource type (id = Entra deviceId); checked 2026-11-20. -->
<!-- VERIFY: exact UI labels of the automatic account management settings and the Backup Directory value in the 2611 UI -->
<!-- VERIFY: passwordBase64 encoding – UTF8 vs Unicode; Graph docs sample decodes to plain text with UTF8 -->
<!-- VERIFY: Entra LAPS enabled in the course tenant; AU-scoped Cloud Device Administrator can read passwords of CL3; admin consent for DeviceLocalCredential.Read.All on Microsoft Graph Command Line Tools -->
<!-- VERIFY: Get-LapsAADPassword works with only Microsoft.Graph.Authentication installed (Lab 1.1) -->
<!-- VERIFY: Lab-Administrator role has Remote tasks – Rotate local admin password -->
