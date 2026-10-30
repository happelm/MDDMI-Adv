---
title: 'Lab 1.3 – Remove the Windows SSO prompt'
lab:
    title: 'Lab 1.3 – Remove the Windows SSO prompt'
    module: 'Day 1 – Automate, connect, govern'
---

# Lab 1.3 – Remove the Windows SSO prompt

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a remediation that accepts the Windows single sign-on consent on your devices.

1. Open `Remediations\SsoPrompt` in the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) and read both scripts and the README.
2. Intune admin center → Devices → Scripts and remediations → Remediations → Create:

   | Setting | Value |
   |---|---|
   | Name | `etcX-SsoPrompt` |
   | Detection script | `Detect-AutoAcceptSsoPermission.ps1` |
   | Remediation script | `Remediate-AutoAcceptSsoPermission.ps1` |
   | Run this script using the logged-on credentials | **No** |
   | Run script in 64-bit PowerShell | **Yes** |

3. Assign it to `studentXdevices` with an hourly schedule.
4. Devices → CL3-yourname → **Run remediation** → `etcX-SsoPrompt`.
5. On CL3, check the value:

   ```powershell
   Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD' -Name AutoAcceptSsoPermission
   ```

6. Check the device status of the remediation.

### Checkpoint

- [ ] `AutoAcceptSsoPermission` = 1 on CL3
- [ ] Device status shows **Without issues** or **Issue fixed**
- [ ] You can explain why a remediation fits better than a one-time platform script

<!-- VERIFY: "Run remediation" permission in Lab-Administrator for Students -->
