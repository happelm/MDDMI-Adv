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

1. Open the [Custom compliance builder](../../Toolbox/Builders/compliance-builder.html){:target="_blank" rel="noopener"}. Name prefix `etcX-Custom`. Remove the sample checks and add **Registry value**:

   | Setting | Value |
   |---|---|
   | Key path | `HKLM:\SOFTWARE\etcX\Lab` |
   | Value name | `Enforced` |
   | Setting name | `LabEnforced` |
   | Data type | **Int64** |
   | Operator | **IsEquals** |
   | Compliant value | `1` |
   | Remediation title | `Lab setting missing. Value discovered: {ActualValue}.` |

   Download both files to `C:\Toolbox\Compliance` on CL3.
2. `Test-CustomCompliance.ps1` is already in this folder (from Lab 0.1, source: [Toolbox/Security/Compliance](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Security/Compliance)). Open an elevated Windows PowerShell in `C:\Toolbox\Compliance` and test:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Test-CustomCompliance.ps1 -ScriptPath .\etcX-Custom-Discovery.ps1 -RulesPath .\etcX-Custom-Rules.json
   ```

   `LabEnforced` shows `-1` (the fallback) and **Not compliant**.
3. Intune admin center → Endpoint security → Device compliance → Scripts → Add → **Windows 10 and later**: script `etcX-Custom-Discovery`, paste the script, logged-on credentials **No**, 64-bit host **Yes**.
4. Devices → Compliance → Create policy → **Windows 10 and later**: policy `etcX-Custom Compliance`, Custom Compliance **Require**, select `etcX-Custom-Discovery`, upload `etcX-Custom-Rules.json`. Assign it to `studentXdevices`.
5. On CL3: Company Portal → Devices → CL3-yourname → **Check status**. Wait until CL3 is **Not compliant** and Company Portal shows your remediation title.

### Enforce

6. Open the [Remediation builder](../../Toolbox/Builders/remediation-builder.html){:target="_blank" rel="noopener"}. Name `etcX-Registry`. Add the check **Registry value must be set**:

   | Setting | Value |
   |---|---|
   | Key path | `HKLM:\SOFTWARE\etcX\Lab` |
   | Value name | `Enforced` |
   | Type | **DWord** |
   | Value | `1` |

   **Why DWord here and Int64 in Detect?** Both mean the same number. The registry stores the value as a 32-bit integer (DWord), so the remediation has to write that registry type. Custom compliance rules know only one integer data type, `Int64` (the others are Boolean, Double, String, DateTime and Version). The discovery script reads the DWord and returns it as a number, and a 32-bit value fits into Int64 without loss.

   Read both scripts: the detection script writes one output line and ends with `exit 1` when the value is wrong, the remediation script creates the key and sets the value. Download both to `C:\Toolbox\Compliance` on CL3.
7. Test both on CL3 in an elevated Windows PowerShell in `C:\Toolbox\Compliance`. `$LASTEXITCODE` shows the exit code of the last script:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Detect-etcX-Registry.ps1; $LASTEXITCODE
   PowerShell.exe -ExecutionPolicy Bypass -File .\Remediate-etcX-Registry.ps1
   PowerShell.exe -ExecutionPolicy Bypass -File .\Detect-etcX-Registry.ps1; $LASTEXITCODE
   ```

   Expected: `1`, then the fix, then `0`. Delete the key again so Intune has something to fix:

   ```powershell
   Remove-Item -Path 'HKLM:\SOFTWARE\etcX' -Recurse
   ```

8. Devices → Scripts and remediations → Remediations → Create: `etcX-Registry`, detection script `Detect-etcX-Registry.ps1`, remediation script `Remediate-etcX-Registry.ps1`, logged-on credentials **No**, 64-bit **Yes**. Assign it to `studentXdevices`.
9. Devices → CL3-yourname → **Run remediation** → `etcX-Registry`.
10. Company Portal → **Check status** again. CL3 turns **Compliant**.

### Prove

11. Open Windows PowerShell in `C:\Toolbox\Reports` (from Lab 0.1, source: [Toolbox/Graph/Reports](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Reports)) and export both sides (remediation ID from the browser address bar):

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
<!-- VERIFY: file names from the remediation builder (Detect-/Remediate-etcX-Registry.ps1) and exit codes in the local test -->
