---
title: 'Lab 1.2 – Rename policies safely'
lab:
    title: 'Lab 1.2 – Rename policies safely'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.2 – Rename policies safely

**Estimated time:** 30 minutes

**Goal:** Bring your policies to a naming standard with a dry run, a real run and an undo.

1. Intune admin center → Devices → Configuration → Create → New policy: create two settings catalog policies for Windows, `etcX-Test A` and `etcX-Test B`. A policy needs at least one setting: add category **Start** → **Hide Recently Added Apps** = **Enabled**. Don't assign them – the lab only renames them.
2. Open Windows PowerShell in `C:\Toolbox\Naming` (from Lab 0.1, source: [Toolbox/Graph/Naming](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Naming)).
3. Dry run – nothing is changed:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Rename-IntunePolicies.ps1 -OldPrefix 'etcX-' -NewPrefix 'etcX-WIN-' -ObjectType ConfigurationPolicies -WhatIf
   ```

4. Run the same command without `-WhatIf`. Open the CSV log the script writes.
5. Undo the rename with the log:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Rename-IntunePolicies.ps1 -UndoCsv <path to the CSV log>
   ```

6. Intune admin center → Tenant administration → Audit logs: find both renames.

### Checkpoint

- [ ] Dry run lists only your two policies
- [ ] Policies renamed in the admin center
- [ ] Undo restored the original names
- [ ] Audit log shows the changes with your account

**Note:** Always rename by your own prefix. A rename without a prefix filter would touch every object your role can edit in the shared tenant.
