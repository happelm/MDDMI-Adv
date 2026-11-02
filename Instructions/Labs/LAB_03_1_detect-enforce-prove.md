---
title: 'Lab 3.1 – Detect, enforce, prove'
lab:
    title: 'Lab 3.1 – Detect, enforce, prove'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.1 – Detect, enforce, prove

**Estimated time:** 45 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Make CL3 noncompliant with a custom compliance rule, fix it with your own remediation and prove both with exported reports.

**Why:** Compliance reports a state and feeds Conditional Access – it changes nothing on the device. A remediation changes the device – but no Conditional Access policy reads its result. Many settings need both.

Your setting: registry key `HKLM:\SOFTWARE\etcX\Lab`, value `Enforced` = `1` (DWORD). It does not exist yet on CL3.

### Detect

1. Open the [Custom compliance builder](../../Tools/compliance-builder.html). Name prefix `etcX-Custom`. Remove the sample checks and add **Registry value**:

   | Setting | Value |
   |---|---|
   | Key path | `HKLM:\SOFTWARE\etcX\Lab` |
   | Value name | `Enforced` |
   | Setting name | `LabEnforced` |
   | Data type | **Int64** |
   | Operator | **IsEquals** |
   | Compliant value | `1` |
   | Remediation title | `Lab setting missing. Value discovered: {ActualValue}.` |

   Download both files to `C:\Labfiles\Compliance` on CL3.
2. Copy `Test-CustomCompliance.ps1` from `Compliance` in the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) to the same folder. Test in an elevated Windows PowerShell:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Test-CustomCompliance.ps1 -ScriptPath .\etcX-Custom-Discovery.ps1 -RulesPath .\etcX-Custom-Rules.json
   ```

   `LabEnforced` shows `-1` (the fallback) and **Not compliant**.
3. Intune admin center → Endpoint security → Device compliance → Scripts → Add → **Windows 10 and later**: script `etcX-Custom-Discovery`, paste the script, logged-on credentials **No**, 64-bit host **Yes**.
4. Devices → Compliance → Create policy → **Windows 10 and later**: policy `etcX-Custom Compliance`, Custom Compliance **Require**, select `etcX-Custom-Discovery`, upload `etcX-Custom-Rules.json`. Assign it to `studentXdevices`.
5. On CL3: Company Portal → Devices → CL3-yourname → **Check status**. Wait until CL3 is **Not compliant** and Company Portal shows your remediation title.

### Enforce

6. Write `Detect-etcX.ps1`: read the value, `Write-Output` one line, `exit 0` when it is `1`, `exit 1` when not. Write `Remediate-etcX.ps1`: create the key, set the value, `Write-Output` one line.
7. Test both on CL3 in an elevated PowerShell: detection returns 1, remediation fixes, detection returns 0. Then delete the key again:

   ```powershell
   Remove-Item -Path 'HKLM:\SOFTWARE\etcX' -Recurse
   ```

8. Devices → Scripts and remediations → Remediations → Create: `etcX-Registry` with your two scripts, logged-on credentials **No**, 64-bit **Yes**. Assign it to `studentXdevices`.
9. Devices → CL3-yourname → **Run remediation** → `etcX-Registry`.
10. Company Portal → **Check status** again. CL3 turns **Compliant**.

### Prove

11. Copy `Reports` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) and export both sides (remediation ID from the browser address bar):

    ```powershell
    PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset RemediationResults -PolicyId <remediation ID>
    PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntuneReport.ps1 -Preset DeviceCompliance
    ```

12. Find CL3 in both CSV files: remediation **Issue fixed** with pre- and post-detection output, compliance state **Compliant**.

### Checkpoint

- [ ] Local test showed **Not compliant** for `LabEnforced` before the fix
- [ ] CL3 was **Not compliant** with your remediation title in Company Portal
- [ ] Remediation status **Issue fixed** for CL3
- [ ] CL3 **Compliant** again, both CSV exports contain CL3
- [ ] You can explain which of the two a Conditional Access policy can use

**Note:** One discovery script belongs to exactly one compliance policy. Discovery scripts don't support scope tags – creating them needs the Default scope tag.

**Note:** Remediation output is limited to 2,048 characters. No reboots, passwords or personal data in remediation scripts.

<!-- Sources: Learn – Custom compliance discovery scripts (System context default, 32-bit default, Default scope tag, one script per policy); Custom compliance JSON files; checked 2026-11-02. -->
<!-- VERIFY: Lab roles – Default scope tag for discovery scripts, "Run remediation" permission -->
<!-- VERIFY: Remediations license for the etcX users -->
<!-- VERIFY: Company Portal "Check status" label and how fast custom compliance re-evaluates -->
<!-- VERIFY: DeviceCompliance export column names for the compliance state -->
