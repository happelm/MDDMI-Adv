---
title: 'Lab 3.4 – Universal Print with the print connector (trainer demo)'
lab:
    title: 'Lab 3.4 – Universal Print with the print connector (trainer demo)'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.4 – Universal Print with the print connector (trainer demo)

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Follow a printer from SRV1 to a Windows client – print connector, Universal Print share, Intune policy – and explain each link in the chain.

**Why a demo:** Universal Print needs a license for every user who prints or manages printing. The course accounts don't have one, so the trainer runs the steps and you follow along.

The trainer shows:

1. SRV1: the printer `HP Universal Printing PCL 6 (v7.1.0)` is installed locally and shared.
2. SRV1: install the Universal Print connector, sign in and register the printer in the connector app.
3. Azure portal → Universal Print → Printers: the registered printer, then **Share** it and give users access.
4. Universal Print → Printers → the printer, then Printer shares → the share: **Printer ID** (Cloud Device ID), **Share ID** and **Share name**.
5. Intune admin center → Devices → Manage devices → Configuration → Create → New policy → Windows 10 and later → Settings catalog, settings picker → **Printer Provisioning**:

   | Setting | Value |
   |---|---|
   | Action | **Install** |
   | Cloud Device ID | Printer ID from step 4 |
   | Printer Shared ID | Share ID from step 4 |
   | Printer Shared Name | Share name from step 4 |

6. The policy is assigned to a user group, the client syncs and the printer shows up in Settings → Bluetooth & devices → Printers & scanners with a cloud icon.
7. A test page, then the job in Universal Print → the printer → Jobs.

Write down your answers while you watch.

### Checkpoint

- [ ] You can name where the three values of the Intune policy come from
- [ ] You can explain why the printer has to be installed locally on the connector host and not as a share from a print server
- [ ] You can explain what happens if the policy is assigned to a group that has no access to the printer share
- [ ] You can name the license a user needs to print with Universal Print

**Note:** The connector lists only printers installed locally on the connector host. Printers connected from a print server share (`\\server\printer`) and printers on a `PORTPROMPT:` port are skipped.

**Note:** If you assign the policy to a group that can't access the printer, Intune grants that group the permission. If the printer is removed, unshared or its permissions are removed in Universal Print, the policy fails to install the printer.

**Note:** Universal Print counts print jobs in one pool per tenant – each eligible license adds jobs. Access is checked per user: a user without a Universal Print license can't print, even if the pool has jobs left.

Sources: [Create a Universal Print policy in Intune](https://learn.microsoft.com/intune/device-configuration/settings-catalog/configure-universal-print) · [Register printers with the connector](https://learn.microsoft.com/universal-print/fundamentals/universal-print-connector-printer-registration) · [Universal Print troubleshooting](https://learn.microsoft.com/universal-print/fundamentals/universal-print-troubleshooting-support-howto#configuring-and-registering-printers) · [Get access to Universal Print](https://learn.microsoft.com/universal-print/get-access-to-universal-print)

<!-- VERIFY: portal labels in steps 3-4 (Printer ID / Share ID / Share name) against the current Universal Print portal -->
