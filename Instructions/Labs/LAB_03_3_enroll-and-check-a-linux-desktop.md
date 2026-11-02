---
title: 'Lab 3.3 – Enroll and check a Linux desktop'
lab:
    title: 'Lab 3.3 – Enroll and check a Linux desktop'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.3 – Enroll and check a Linux desktop

**Estimated time:** 45 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Enroll the Red Hat Enterprise Linux 9 VM, make it compliant with built-in password rules and add a custom compliance rule from a shell script.

### Prepare the VM

1. Sign in to the Linux VM and open **Terminal**. The VM is already registered with Red Hat, so `dnf` can install packages.
2. Add the Microsoft repository and install the Microsoft Intune app:

   ```bash
   sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
   sudo dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/microsoft-rhel9.0-prod
   sudo dnf install intune-portal -y
   ```

3. Add the Microsoft Edge repository and install Edge:

   ```bash
   sudo sh -c 'echo -e "[microsoft-edge]\nname=Microsoft Edge\nbaseurl=https://packages.microsoft.com/yumrepos/edge\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/microsoft-edge.repo'
   sudo dnf install microsoft-edge-stable -y
   ```

4. Set the local password rules that your compliance policy will require – at least 10 characters, no character class rules:

   ```bash
   cat <<'EOF2' | sudo tee /etc/security/pwquality.conf.d/10-intune.conf
   minlen = 10
   dcredit = 0
   ucredit = 0
   lcredit = 0
   ocredit = 0
   EOF2
   ```

5. Restart the VM.

### Enroll and check compliance

1. Open the **Microsoft Intune** app and sign in with your `etcX` account. Follow the enrollment screens.
2. Intune admin center → Devices → Compliance → Create policy → **Linux** → Settings catalog: policy `etcX-Linux`.
   - **Allowed Distributions:** Red Hat Enterprise Linux, minimum version 9.0
   - **Password Policy:** Minimum Length **10**

   Assign it to `studentXusers`.
3. Copy `etcX-LinuxDiscovery.sh` and `etcX-LinuxRules.json` from `LinuxCompliance` in the [Labfiles](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles). Rename both to your number.
4. Endpoint security → Device compliance → Scripts → Add → **Linux**: upload `etcX-LinuxDiscovery.sh` as script `etcX-LinuxDiscovery`.
5. Open `etcX-Linux` → Properties → Compliance settings → Add settings → **Custom Compliance**: **Require Custom Compliance** = **True**, discovery script `etcX-LinuxDiscovery`, rules file `etcX-LinuxRules.json`.
6. In the Intune app on the VM, select **Refresh** and read the compliance result.
7. On the VM, stop the firewall with `sudo systemctl stop firewalld`, refresh again and read the message from the rules file. Start it again with `sudo systemctl start firewalld`.

### Checkpoint

- [ ] Linux VM listed in Intune admin center → Devices → Linux
- [ ] Compliance result for built-in and custom settings in the admin center
- [ ] Stopped firewall shows your remediation text in the Intune app
- [ ] You can explain why a broker update changes the device ID

**Note:** Supported: Ubuntu Desktop 24.04 and 26.04 LTS, Red Hat Enterprise Linux 9 and 10, with GNOME. Linux devices enrolled in Intune are corporate devices. When the Microsoft Identity Broker updates to 2.0.2 or later, Intune re-enrolls the device with new Intune and Entra device IDs – check assignments and groups that use device IDs.

**Note:** Linux discovery scripts run in the user's context. They can't read values that need root.

<!-- Sources: Learn – Get the Microsoft Intune app for Linux; Enroll Linux device in Intune; Device compliance settings for Linux; Custom compliance discovery scripts; Custom compliance JSON files; checked 2026-11-02. Install commands from Michael's tested Install.txt. -->
<!-- VERIFY: RHEL subscription registration done by the trainer before class (credentials stay with the trainer) -->
<!-- VERIFY: one Linux VM per participant? -->
<!-- VERIFY: Intune password compliance reads the pwquality config (inferred from Michael's Install.txt) -->
<!-- VERIFY: Allowed Distributions value label for RHEL in the settings catalog -->
<!-- VERIFY: custom compliance scripts need the Default scope tag -->
<!-- VERIFY: "Refresh" label in the Intune app for Linux -->
