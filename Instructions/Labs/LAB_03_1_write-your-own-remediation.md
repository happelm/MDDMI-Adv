---
title: 'Lab 3.1 – Write your own remediation'
lab:
    title: 'Lab 3.1 – Write your own remediation'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.1 – Write your own remediation

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Detect and fix a setting of your choice and read the result with a script.

1. Pick a registry value to enforce, for example `HKLM:\SOFTWARE\etcX\Lab` value `Enforced` = `1` (DWORD).
2. Write `Detect-etcX.ps1`: read the value, `Write-Output` one line, `exit 0` when correct, `exit 1` when not.
3. Write `Remediate-etcX.ps1`: create the key, set the value, `Write-Output` one line.
4. Test both scripts on CL3 in an elevated PowerShell: detection returns 1, remediation fixes, detection returns 0.
5. Delete the value again. Create the remediation `etcX-Registry` (64-bit, system context), assign it to `studentXdevices`.
6. Devices → CL3-yourname → **Run remediation** → `etcX-Registry`.
7. Copy `Reports` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) and export the results (remediation ID from the browser address bar):

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <remediation ID>
   ```

### Checkpoint

- [ ] Device status **Issue fixed** for CL3
- [ ] Pre- and post-remediation detection output in the device status
- [ ] CSV export contains your device

**Note:** Output is limited to 2,048 characters. No reboots, passwords or personal data in remediation scripts.

<!-- VERIFY: "Run remediation" permission in the Lab roles -->
<!-- VERIFY: Remediations license for the etcX users -->
