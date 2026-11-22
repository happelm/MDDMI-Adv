---
title: 'Lab 3.5 – Enroll and check a Linux desktop'
lab:
    title: 'Lab 3.5 – Enroll and check a Linux desktop'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.5 – Enroll and check a Linux desktop

**Estimated time:** 45 minutes

**Goal:** Enroll the Red Hat Enterprise Linux 9 VM, make it compliant with built-in password rules and add a custom compliance rule from a shell script.

### Prepare the VM

1. Sign in to the Linux VM in your pod and open **Terminal**. Every pod has the same VM with the same default host name, so all VMs show up in Intune under the same device name. Give your VM its own name first:

   ```bash
   sudo hostnamectl set-hostname etcX-rhel
   hostnamectl
   ```

   Replace `X` with your number. `hostnamectl` shows the new **Static hostname**.
2. Register the VM with Red Hat so that `dnf` can install packages. The trainer gives you the user name and password of the course Red Hat account:

   ```bash
   sudo subscription-manager register --username=<Red Hat user>
   ```

   Enter the password when asked.
3. Add the Microsoft repository and install the Microsoft Intune app:

   ```bash
   sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
   sudo dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/microsoft-rhel9.0-prod
   sudo dnf install intune-portal -y
   ```

4. Add the Microsoft Edge repository and install Edge:

   ```bash
   sudo sh -c 'echo -e "[microsoft-edge]\nname=Microsoft Edge\nbaseurl=https://packages.microsoft.com/yumrepos/edge\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/microsoft-edge.repo'
   sudo dnf install microsoft-edge-stable -y
   ```

5. Set the local password rules that your compliance policy will require – at least 10 characters, no character class rules:

   ```bash
   cat <<'EOF2' | sudo tee /etc/security/pwquality.conf.d/10-intune.conf
   minlen = 10
   dcredit = 0
   ucredit = 0
   lcredit = 0
   ocredit = 0
   EOF2
   ```

6. Restart the VM.

### Enroll and check compliance

1. Open the **Microsoft Intune** app and sign in with your `etcX` account. Follow the enrollment screens.
2. Open **Microsoft Edge**, select the profile icon → **Sign in to sync data** and pick your `etcX` account. Turn on sync. Then open <https://myapplications.microsoft.com> – no password prompt: the Microsoft Identity Broker that came with the Intune app signs Edge in with the account you enrolled with.
3. Work in the admin center on CL3. Both files are already in `C:\Toolbox\Compliance` from Lab 0.1:
   - `etcX-LinuxDiscovery.sh`: the admin center has no file upload for Linux scripts. Open the file in Notepad and copy the content – you paste it in step 4.
   - `etcX-LinuxRules.json`: rename it to your number, for example `etc7-LinuxRules.json`. You upload this file in step 5.
4. Endpoint security → Device compliance → Scripts → Add → **Linux**: script `etcX-LinuxDiscovery`, paste the content of `etcX-LinuxDiscovery.sh`.
5. Devices → Compliance → Create policy → **Linux** → Settings catalog: policy `etcX-Linux` with these settings:
   - **Allowed Distributions:** Red Hat Enterprise Linux, minimum version 9.0
   - **Password Policy:** Minimum Length **10**
   - **Custom Compliance:** **Require Custom Compliance** = **True**, discovery script `etcX-LinuxDiscovery`, rules file: upload your renamed `etcX-LinuxRules.json`

   Assign it to `studentXusers`.
6. In the Intune app on the VM, select **Refresh** and read the compliance result.
7. On the VM, stop the firewall with `sudo systemctl stop firewalld`, refresh again and read the message from the rules file. Start it again with `sudo systemctl start firewalld`.

### Checkpoint

- [ ] Linux VM listed as `etcX-rhel` in Intune admin center → Devices → Linux
- [ ] Compliance result for built-in and custom settings in the admin center
- [ ] Edge signed in and syncing with your `etcX` account, Microsoft 365 sites open without a password prompt
- [ ] Stopped firewall shows your remediation text in the Intune app
- [ ] You can explain why a broker update changes the device ID

**Note:** Supported: Ubuntu Desktop 24.04 and 26.04 LTS, Red Hat Enterprise Linux 9 and 10, with GNOME. Linux devices enrolled in Intune are corporate devices. When the Microsoft Identity Broker updates to 2.0.2 or later, Intune re-enrolls the device with new Intune and Entra device IDs – check assignments and groups that use device IDs.

**Note:** Linux discovery scripts run in the user's context. They can't read values that need root.

<!-- Sources: Learn – Get the Microsoft Intune app for Linux; Enroll Linux device in Intune; Device compliance settings for Linux; Custom compliance discovery scripts; Custom compliance JSON files; checked 2026-11-02. Install commands from Michael's tested Install.txt. -->
<!-- Every participant has the same RHEL VM in the pod and registers it with the trainer's Red Hat account (Michael 2026-11-02). Credentials never go into this repo. -->
<!-- Steps 4-6 (Michael 2026-11-22): Linux script content is pasted (no upload); the rules JSON is uploaded as a file, so it is renamed first. -->
<!-- Edge sign-in step added 2026-11-22 (Michael): Learn Enroll Linux device (sign in to Edge after enrollment), What is Microsoft single sign-on for Linux (SSO for Edge via broker). -->
<!-- Host name step added 2026-11-22: Michael saw all pod VMs enrolled as localhost in Intune (lab observation). Tested: device shows the new name. -->
<!-- Tested by Michael 2026-11-22: lab runs as written (hostname, Edge SSO/sync, pasted script, uploaded rules JSON, firewall test). -->
