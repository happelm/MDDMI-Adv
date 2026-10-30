---
title: 'Lab 3.4 – Deploy a Universal Print printer'
lab:
    title: 'Lab 3.4 – Deploy a Universal Print printer'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.4 – Deploy a Universal Print printer

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Install a shared Universal Print printer for your user without a print server.

1. Get the **Cloud Device ID**, **Printer Shared ID** and **Printer Shared Name** of the course printer from the trainer.
2. Intune admin center → Devices → Configuration → Create → Windows 10 and later → Settings catalog: policy `etcX-Printer`, settings picker → **Printer Provisioning**:

   | Setting | Value |
   |---|---|
   | Action | **Install** |
   | Cloud Device ID | from step 1 |
   | Printer Shared ID | from step 1 |
   | Printer Shared Name | from step 1 |

3. Assign the policy to `studentXusers`.
4. Sign in to CL3 with your `etcX` account, sync, open Settings → Bluetooth & devices → Printers & scanners.
5. Print a test page.

### Checkpoint

- [ ] Printer listed on CL3
- [ ] Test page printed or visible as job in Universal Print
- [ ] You can explain why shared PCs are a problem for this policy

<!-- VERIFY: course printer registered and shared in Universal Print -->
<!-- VERIFY: who hands out the printer IDs -->
