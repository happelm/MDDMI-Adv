---
title: 'Lab 2.4 – Windows LAPS'
lab:
    title: 'Lab 2.4 – Windows LAPS'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.4 – Windows LAPS

**Estimated time:** 25 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Let Windows LAPS manage the local administrator password of CL3 and read it from the portal and from PowerShell.

1. Intune admin center → Endpoint security → Account protection → Create policy → Windows → **Local admin password solution (Windows LAPS)**: policy `etcX-LAPS`, backup directory **Backup the password to Microsoft Entra ID only**, password age `7` days, assigned to `studentXdevices`.
2. Sync CL3, then open Event Viewer → Applications and Services Logs → Microsoft → Windows → LAPS → Operational.
3. Intune admin center → Devices → CL3-yourname → **Local admin password**: show the password.
4. Read it with PowerShell:

   ```powershell
   Connect-MgGraph -Scopes Device.Read.All, DeviceLocalCredential.Read.All -NoWelcome
   Get-LapsAADPassword -DeviceIds CL3-yourname -IncludePasswords -AsPlainText
   ```

5. Devices → CL3-yourname → **Rotate local admin password**. Read the password again.

### Checkpoint

- [ ] Password visible in Intune and in PowerShell
- [ ] Different password after the rotation
- [ ] You know which permission reads the password

**Note:** Reading the password is its own permission. With `DeviceLocalCredential.ReadBasic.All` you see backup and expiry time, not the password.

**Why:** The same local administrator password on every device is one of the easiest ways to move laterally in a network.

<!-- VERIFY: Entra LAPS enabled in the course tenant -->
<!-- VERIFY: Lab roles may read the password and rotate -->
<!-- VERIFY: built-in Administrator disabled on OOBE-joined devices – automatic account management (24H2+) or a named account? -->
