---
title: 'Lab 1.4 – Add an app from the Enterprise App Catalog'
lab:
    title: 'Lab 1.4 – Add an app from the Enterprise App Catalog'
    module: 'Day 1 – Automate, package, connect, govern'
---

# Lab 1.4 – Add an app from the Enterprise App Catalog

**Estimated time:** 20 minutes

**Goal:** Deploy a catalog app without packaging and compare it with your pipeline app.

1. Intune admin center → Apps → All apps → Create → **Enterprise App Catalog app**.
2. Search the catalog and pick an app. Go through **Select app** and **Configuration**. On **Updates** → Update method, read both options and select **Automatically update**:

   | Option | What it means |
   |---|---|
   | **Automatically update** | The app follows the latest version in the catalog. Custom settings, including install and uninstall scripts, are reset and blocked. |
   | **Update with supersedence** | Custom settings stay possible, but every new version is a new app with guided supersedence. |

   The choice is one-time for this app – a different choice means a new app. Name the app `etcX-<app>`.
3. Go through the app wizard (subtitle **Windows auto-update catalog app**). **Program** shows only install behavior and device restart behavior – no install or uninstall command. **Requirements** and **Detection rules** are greyed out: the catalog manages them. Compare with your 7-Zip app from Lab 1.3, where you set all of them yourself.
4. Assign it **Required** to `studentXdevices`. With **Automatically update**, the assignment offers only **Required** – **Available for enrolled devices** is not there.
5. Sync CL3 and compare the install status with your 7-Zip app from Lab 1.3.

### Checkpoint

- [ ] Catalog app installed on CL3
- [ ] You can name the wizard steps that **Automatically update** locks
- [ ] You can name what **Automatically update** blocks and which assignment type it allows

**Note:** Auto-update has no rollback, no rings and can't be a blocking app in the Enrollment Status Page.

<!-- Trainer finding 2026-11-21 (screenshot): Updates tab → Update method (Automatically update / Update with supersedence, one-time choice); Automatically update offers only Required; Program shows only install and restart behavior, Requirements and Detection rules greyed out. Learn (Add an Enterprise App Catalog app, Step 6) still places auto-update in the Required assignment. -->
