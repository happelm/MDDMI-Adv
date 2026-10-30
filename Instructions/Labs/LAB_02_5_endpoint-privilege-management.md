---
title: 'Lab 2.5 – Endpoint Privilege Management'
lab:
    title: 'Lab 2.5 – Endpoint Privilege Management'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.5 – Endpoint Privilege Management

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Let a standard user run a specific installer and a specific admin command elevated – without local admin rights.

1. Intune admin center → Endpoint security → Endpoint Privilege Management → Create policy → Windows → **Windows elevation settings policy**: policy `etcX-EPM Settings` with EPM **Enabled** and default elevation response **Require support approval**, assigned to `studentXdevices`.
2. Create policy → **Windows elevation rules policy**: policy `etcX-EPM Rules` with two rules, elevation type **User confirmed** with business justification:
   - the Notepad++ installer (file name plus file hash or certificate)
   - `sc.exe` with file path `C:\Windows\System32`
3. On CL3, import the EpmTools module and check what the client received:

   ```powershell
   Import-Module 'C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll'
   Get-Policies -PolicyType ElevationRules
   ```

4. Sign in to CL3 as a standard user. Right-click the Notepad++ installer → **Run with elevated access** and enter a reason.
5. Right-click a file without a rule → **Run with elevated access**: the request waits for support approval.
6. Endpoint Privilege Management → **Elevation requests** and **Reports**: find your requests and elevations.

### Checkpoint

- [ ] Notepad++ installed by a standard user
- [ ] File without a rule waits for support approval
- [ ] Elevations listed in the EPM report

**Why:** Least privilege with exceptions per file instead of local admin rights for everyone.

<!-- VERIFY: EPM license in the course tenant -->
<!-- VERIFY: standard user on CL3 (first OOBE user is local admin) -->
<!-- VERIFY: sc.exe elevation behavior -->
<!-- VERIFY: adapted from MDDMI Lab 3.3 (EPM) -->
