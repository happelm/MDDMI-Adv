---
title: 'Lab 3.3 – Enroll and check a Linux desktop'
lab:
    title: 'Lab 3.3 – Enroll and check a Linux desktop'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.3 – Enroll and check a Linux desktop

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Enroll an Ubuntu VM, make it compliant and add a custom compliance rule.

1. On the Linux VM, install Microsoft Edge and the Microsoft Intune app (Learn: Get the Microsoft Intune app for Linux).
2. Open the Intune app and enroll with your `etcX` account.
3. Intune admin center → Devices → Compliance → Create policy → **Linux** → Settings catalog: policy `etcX-Linux` with a minimum OS version and password rules, assigned to `studentXusers`.
4. Endpoint security → Device compliance → Scripts → Add → Linux: upload the discovery script from the lab guide appendix. Add **Custom Compliance** to `etcX-Linux` with the script and the JSON rules file.
5. Check compliance in the Intune app on the VM and in the admin center.

### Checkpoint

- [ ] Linux VM listed in Intune
- [ ] Compliance result for built-in and custom settings
- [ ] You can explain why a broker update changes the device ID

**Note:** Supported: Ubuntu 24.04 and 26.04 LTS, RHEL 9 and 10 with GNOME. When the Microsoft Identity Broker updates to 2.0.2 or later, Intune re-enrolls the device with new device IDs.

<!-- VERIFY: Linux VM in the pod and its version -->
<!-- VERIFY: discovery script + JSON sample for the appendix (not written yet) -->
<!-- VERIFY: custom compliance scripts need the Default scope tag -->
