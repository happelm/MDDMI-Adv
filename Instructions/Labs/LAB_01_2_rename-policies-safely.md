---
title: 'Lab 1.2 – Rename policies safely'
lab:
    title: 'Lab 1.2 – Rename policies safely'
    module: 'Day 1 – Automate, connect, govern'
---

# Lab 1.2 – Rename policies safely

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Bring your policies to a naming standard with a dry run, a real run and an undo.

1. Intune admin center → Devices → Configuration → Create → New policy: create two empty settings catalog policies for Windows, `etcX-Test A` and `etcX-Test B`.
2. Copy the folder `Naming` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) to `C:\Labfiles`.
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

<!-- VERIFY: PATCH with the Lab-Administrator role in the shared tenant (script v1.0 not yet run there) -->
