---
title: 'Lab 0.1 – Set up your lab'
lab:
    title: 'Lab 0.1 – Set up your lab'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 0.1 – Set up your lab

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Bring CL3 and CL4 into the training tenant and into your device group, named so that everybody can find them, and sign in with Windows Hello.

1. The trainer gives you your user `etcX` and your number X.
2. CL3 and CL4 start at OOBE. When OOBE asks for the device name, enter `CL3-yourname` and `CL4-yourname`. Choose any privacy settings.
3. Sign in with `etcX` as work or school account – this joins the client to Microsoft Entra ID. Complete MFA and set up Windows Hello with a PIN when Windows asks for it.
4. Entra admin center → Groups → `studentXdevices` → Members: add `CL3-yourname` and `CL4-yourname`.
5. From now on, every object you create in the tenant starts with `etcX-`.

### Checkpoint

- [ ] `dsregcmd /status` on CL3 and CL4: `AzureAdJoined : YES`
- [ ] Both devices listed in Intune admin center → Devices → Windows
- [ ] Both devices are members of `studentXdevices`
- [ ] Sign-in with your Windows Hello PIN works on CL3 and CL4

**If a device is joined but not in Intune:** MDM auto-enrollment did not run. Download `Enrollment/Autoenroll.ps1` from the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles) and run it in an elevated PowerShell on that client. The script writes the Intune enrollment URLs to `HKLM\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\<tenant ID>` and starts the enrollment with `deviceenroller.exe /c /AutoEnrollMDM` – the device enrolls as corporate device. Check the checkpoint again after a few minutes.

**Note:** A computer name has at most 15 characters – shorten `yourname` if needed. Your roles only reach devices whose name matches the lab naming pattern, so keep the `CL3-` / `CL4-` prefix.

**Note:** The user who joins a device to Microsoft Entra ID becomes a local administrator on it. Other users of the tenant sign in as standard users – Lab 2.3 (Endpoint Privilege Management) uses this.

**Why:** Every assignment in the following labs targets `studentXdevices` or `studentXusers`. A device that is not in your group gets nothing.

<!-- Same setup as MDDMI-TS Lab 0.1 (validated there). VERIFY: run once in the MDDMI-Adv class. -->
