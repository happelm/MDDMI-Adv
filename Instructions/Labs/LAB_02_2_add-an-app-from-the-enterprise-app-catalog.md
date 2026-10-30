---
title: 'Lab 2.2 – Add an app from the Enterprise App Catalog'
lab:
    title: 'Lab 2.2 – Add an app from the Enterprise App Catalog'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.2 – Add an app from the Enterprise App Catalog

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a catalog app without packaging and compare it with your pipeline app.

1. Intune admin center → Apps → All apps → Create → **Enterprise App Catalog app**.
2. Search the catalog and pick an app. Name it `etcX-<app>`.
3. Review the prefilled install and uninstall commands, detection rules and requirements – change nothing.
4. Assign it **Required** to `studentXdevices`. Look at the auto-update option of the Required assignment.
5. Sync CL3 and compare the install status with your 7-Zip app from Lab 2.1.

### Checkpoint

- [ ] Catalog app installed on CL3
- [ ] You can name two settings the catalog prefilled
- [ ] You can say when auto-update is not an option

**Note:** Auto-update has no rollback, no rings and can't be a blocking app in the Enrollment Status Page.

<!-- VERIFY: Enterprise App Management license in the course tenant -->
<!-- VERIFY: Lab-Administrator can create catalog apps -->
