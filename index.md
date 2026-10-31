---
title: MDDMI-Adv Lab Instructions
permalink: index.html
---

# MDDMI-Adv – Modern Device Management with Microsoft Intune, Advanced

Lab instructions for the MDDMI-Adv workshop, the second part of the MDDMI course series. Use the copy button on every code block.

## Labs

### Day 1 – Automate, connect, govern

| Lab | Title | Time |
|---|---|---|
| 1.1 | [Answer "what hits this device?" with Graph](Instructions/Labs/LAB_01_1_answer-what-hits-this-device-with-graph.html) (draft) | 45 min |
| 1.2 | [Rename policies safely](Instructions/Labs/LAB_01_2_rename-policies-safely.html) (draft) | 30 min |
| 1.3 | [Remove the Windows SSO prompt](Instructions/Labs/LAB_01_3_remove-the-windows-sso-prompt.html) (draft) | 30 min |

### Day 2 – Apps, security, support

| Lab | Title | Time |
|---|---|---|
| 2.1 | [Build a Win32 app with the pipeline](Instructions/Labs/LAB_02_1_build-a-win32-app-with-the-pipeline.html) (draft) | 40 min |
| 2.2 | [Add an app from the Enterprise App Catalog](Instructions/Labs/LAB_02_2_add-an-app-from-the-enterprise-app-catalog.html) (draft) | 20 min |
| 2.3 | [Endpoint security policies](Instructions/Labs/LAB_02_3_endpoint-security-policies.html) (draft) | 45 min |
| 2.4 | [Windows LAPS](Instructions/Labs/LAB_02_4_windows-laps.html) (draft) | 25 min |
| 2.5 | [Endpoint Privilege Management](Instructions/Labs/LAB_02_5_endpoint-privilege-management.html) (draft) | 30 min |
| 2.6 | [Certificates from Cloud PKI](Instructions/Labs/LAB_02_6_certificates-from-cloud-pki.html) (draft) | 25 min |
| 2.7 | [Help your partner with Remote Help](Instructions/Labs/LAB_02_7_help-your-partner-with-remote-help.html) (draft) | 20 min |

### Day 3 – Insights, automation, platforms

| Lab | Title | Time |
|---|---|---|
| 3.1 | [Write your own remediation](Instructions/Labs/LAB_03_1_write-your-own-remediation.html) (draft) | 30 min |
| 3.2 | [Export reports with Graph and Excel](Instructions/Labs/LAB_03_2_export-reports-with-graph-and-excel.html) (draft) | 35 min |
| 3.3 | [Enroll and check a Linux desktop](Instructions/Labs/LAB_03_3_enroll-and-check-a-linux-desktop.html) (draft) | 30 min |
| 3.4 | [Deploy a Universal Print printer](Instructions/Labs/LAB_03_4_deploy-a-universal-print-printer.html) (draft) | 20 min |
| 3.5 | [Find licensed apps nobody uses](Instructions/Labs/LAB_03_5_find-licensed-apps-nobody-uses.html) (draft, optional) | 30 min, if time permits |

### Builders

[Firewall rule builder](Tools/firewall-rule-builder.html) (draft) – pick firewall rule groups and add custom rules; builds the rule file for `New-IntuneFirewallRulePolicy.ps1`.

### Appendix

[Appendix](Instructions/Appendix.html)

## About this guide

> **Draft:** This lab guide is new. Every lab is marked as draft until it has been tested in this course.

Each lab lists its goal, the steps at task level (not every click) and a checkpoint you confirm before moving on.

- **Steps** say what to do and where. Menu paths use → between levels.
- **Checkpoint** items are the definition of done. If one fails, tell the trainer before you continue.
- **Notes** explain what to expect and where it typically goes wrong.

### Your lab pod

Every participant works in the shared course tenant with their own account and groups. Your number X comes from the trainer.

| Item | Value |
|---|---|
| Account | `etcX` in the course tenant (the trainer gives you the domain) |
| Groups | `studentXusers`, `studentXdevices` – assign everything to these groups, never to All users or All devices |
| Clients | CL3, CL4 (`CLx-yourname`), Microsoft Entra joined and enrolled in Intune |
| Servers | DC1, SRV1 – shared by the class, lab files on `\\dc1\labfiles` |
| Object names | Every object you create starts with `etcX-` |

You can read everything in the tenant, but change only objects for your own groups. Conditional Access, assignment filters and tenant settings are shown by the trainer.

### Tools

- Microsoft 365 admin center: admin.microsoft.com · Intune admin center: intune.microsoft.com · Entra admin center: entra.microsoft.com
- Lab files: [Labfiles folder in this repository](https://github.com/happelm/MDDMI-Adv/tree/main/Labfiles)
