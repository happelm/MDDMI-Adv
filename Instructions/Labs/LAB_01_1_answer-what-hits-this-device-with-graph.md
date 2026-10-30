---
title: 'Lab 1.1 – Answer "what hits this device?" with Graph'
lab:
    title: 'Lab 1.1 – Answer "what hits this device?" with Graph'
    module: 'Day 1 – Automate, connect, govern'
---

# Lab 1.1 – Answer "what hits this device?" with Graph

**Estimated time:** 45 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Use two read-only scripts to see every Intune object that reaches a group, a device or a user – and the objects that reach nobody.

1. On CL3, open PowerShell and install the Graph module for your account if it is missing:

   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
   ```

2. Copy the folder `Assignments` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) to `C:\Labfiles` on CL3.
3. Group view – sign in with your `etcX` account when asked and confirm the tenant:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName studentXdevices -ExportCsv
   ```

4. Device view for your client – compare it with the group view:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntunePolicyAssignmentsByGroup.ps1 -DeviceName CL3-yourname -ExportCsv
   ```

5. Objects that apply to nobody:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Find-UnassignedIntuneObjects.ps1 -ExportCsv
   ```

   Open the CSV in Excel and filter the name column on `etcX-`.
6. Pick one result and confirm it in the Intune admin center.

### Checkpoint

- [ ] Group view lists the objects assigned to `studentXdevices`
- [ ] Device view also lists All devices assignments and every group CL3 is a member of
- [ ] At least one of your objects shows as unassigned or exclude-only
- [ ] You can name the Graph scopes the scripts asked for

**Note:** The group view follows group nesting; the device and user views resolve transitive membership. The shared tenant has many objects – expect long lists.

**Why:** The admin center answers "which groups does this policy target?". Support asks the opposite: "what hits this device?".

<!-- VERIFY: admin consent for the delegated scopes of the Assignments scripts in the course tenant -->
