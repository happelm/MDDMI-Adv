---
title: 'Lab 1.1 – Answer "what hits this device?" with Graph'
lab:
    title: 'Lab 1.1 – Answer "what hits this device?" with Graph'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.1 – Answer "what hits this device?" with Graph

**Estimated time:** 60 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Follow one request from the Intune admin center through Graph Explorer into PowerShell – then use two read-only scripts to see every Intune object that reaches a group, a device or a user, and the objects that reach nobody.

### Part A – Warm-up: from the admin center to PowerShell (15 minutes)

1. On CL3, open the Intune admin center → Devices → Windows. Press **F12** → **Network**, type `graph.microsoft.com` in the filter box and reload the page with **F5**. Select one request whose URL starts with `https://graph.microsoft.com/beta/deviceManagement/` and look at **Headers** (request URL, method) and **Response**. Every blade works this way – most of them call `/beta`.

2. Open Graph Explorer (`https://aka.ms/ge`) and sign in with your `etcX` account. Method **GET**, version **v1.0**. Clear the URL box and paste – replace `CL3-yourname`:

   ```text
   https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=deviceName eq 'CL3-yourname'&$select=id,deviceName,osVersion,complianceState,lastSyncDateTime
   ```

   Run it once more without the `&$select=...` part and compare the size of the response.

3. Open the **Modify permissions** tab: which permission does this request need? Then open **Code snippets** → **PowerShell**: Graph Explorer shows the same request as a command of the full Graph SDK.

4. On CL3, open PowerShell and install the Graph module for your account if it is missing. This one small module is all the scripts in this course need:

   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
   ```

5. Send the same request from PowerShell with `Invoke-MgGraphRequest` – replace `CL3-yourname`. The backtick in front of `$filter` and `$select` stops PowerShell from reading them as variables:

   ```powershell
   Connect-MgGraph -Scopes DeviceManagementManagedDevices.Read.All -NoWelcome
   $r = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq 'CL3-yourname'&`$select=id,deviceName,osVersion,complianceState,lastSyncDateTime"
   $r.value | Select-Object deviceName, osVersion, complianceState, lastSyncDateTime
   ```

### Part B – What hits this device?

6. Copy the folder [Toolbox/Graph/Assignments](https://github.com/happelm/MDDMI-Adv/tree/main/Toolbox/Graph/Assignments) to `C:\Toolbox\Assignments` on CL3.
7. Group view – sign in with your `etcX` account when asked and confirm the tenant:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName studentXdevices -ExportCsv
   ```

8. Device view for your client – compare it with the group view:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntunePolicyAssignmentsByGroup.ps1 -DeviceName CL3-yourname -ExportCsv
   ```

9. Objects that apply to nobody:

   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File .\Find-UnassignedIntuneObjects.ps1 -ExportCsv
   ```

   Open the CSV in Excel and filter the name column on `etcX-`.
10. Pick one result and confirm it in the Intune admin center.

### Checkpoint

- [ ] Same device data in Graph Explorer and in PowerShell
- [ ] You can name the permission Graph Explorer listed for the request
- [ ] Group view lists the objects assigned to `studentXdevices`
- [ ] Device view also lists All devices assignments and every group CL3 is a member of
- [ ] At least one of your objects shows as unassigned or exclude-only
- [ ] You can name the Graph scopes the scripts asked for

**Note:** The group view follows group nesting; the device and user views resolve transitive membership. The shared tenant has many objects – expect long lists.

**Why Part A:** The admin center, Graph Explorer and the scripts all send the same requests. What you find with F12 you can try in Graph Explorer and then put into a script – that is how the Toolbox scripts were built.

**Why:** The admin center answers "which groups does this policy target?". Support asks the opposite: "what hits this device?".

<!-- VERIFY: admin consent for the delegated scopes of the Assignments scripts in the course tenant -->
