---
title: 'Lab 1.4 – Add an app from the Enterprise App Catalog'
lab:
    title: 'Lab 1.4 – Add an app from the Enterprise App Catalog'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.4 – Add an app from the Enterprise App Catalog

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a catalog app without packaging and compare it with your pipeline app.

1. Intune admin center → Apps → All apps → Create → **Enterprise App Catalog app**.
2. Search the catalog and pick an app. When you select the app and its package, you also decide whether Intune keeps it up to date automatically – read the option and leave it **on**. Name the app `etcX-<app>`.
3. Review the prefilled install and uninstall commands, detection rules and requirements – change nothing.
4. Assign it **Required** to `studentXdevices`. Auto-update works only with a **Required** assignment – an **Available** assignment keeps the manual update path with supersedence.
5. Sync CL3 and compare the install status with your 7-Zip app from Lab 1.3.

### Checkpoint

- [ ] Catalog app installed on CL3
- [ ] You can name two settings the catalog prefilled
- [ ] You can say when auto-update is not an option

**Note:** Auto-update has no rollback, no rings and can't be a blocking app in the Enrollment Status Page.

<!-- VERIFY: Enterprise App Management license in the course tenant -->
<!-- VERIFY: Lab-Administrator can create catalog apps -->
<!-- Trainer finding 2026-11-21: in the admin center the auto-update choice is made when selecting the app, not in the assignment. Learn (Add an Enterprise App Catalog app, Step 6) still describes it at the Required assignment. VERIFY exact label. -->
