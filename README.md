# MDDMI-Adv – Modern Device Management with Microsoft Intune, Advanced

Lab instructions for the MDDMI-Adv workshop, the second part of the MDDMI course series.

- **Read online:** <https://happelm.github.io/MDDMI-Adv/>

## Labs

### Day 1 – Automate, connect, govern

| Lab | Title | Time |
|---|---|---|
| 1.1 | [Answer "what hits this device?" with Graph](Instructions/Labs/LAB_01_1_answer-what-hits-this-device-with-graph.md) (draft) | 45 min |
| 1.2 | [Rename policies safely](Instructions/Labs/LAB_01_2_rename-policies-safely.md) (draft) | 30 min |
| 1.3 | [Remove the Windows SSO prompt](Instructions/Labs/LAB_01_3_remove-the-windows-sso-prompt.md) (draft) | 30 min |

### Day 2 – Apps, security, support

| Lab | Title | Time |
|---|---|---|
| 2.1 | [Build a Win32 app with the pipeline](Instructions/Labs/LAB_02_1_build-a-win32-app-with-the-pipeline.md) (draft) | 40 min |
| 2.2 | [Add an app from the Enterprise App Catalog](Instructions/Labs/LAB_02_2_add-an-app-from-the-enterprise-app-catalog.md) (draft) | 20 min |
| 2.3 | [Endpoint security policies](Instructions/Labs/LAB_02_3_endpoint-security-policies.md) (draft) | 45 min |
| 2.4 | [Windows LAPS](Instructions/Labs/LAB_02_4_windows-laps.md) (draft) | 25 min |
| 2.5 | [Endpoint Privilege Management](Instructions/Labs/LAB_02_5_endpoint-privilege-management.md) (draft) | 30 min |
| 2.6 | [Certificates from Cloud PKI](Instructions/Labs/LAB_02_6_certificates-from-cloud-pki.md) (draft) | 25 min |
| 2.7 | [Help your partner with Remote Help](Instructions/Labs/LAB_02_7_help-your-partner-with-remote-help.md) (draft) | 20 min |

### Day 3 – Insights, automation, platforms

| Lab | Title | Time |
|---|---|---|
| 3.1 | [Write your own remediation](Instructions/Labs/LAB_03_1_write-your-own-remediation.md) (draft) | 30 min |
| 3.2 | [Export reports with Graph and Excel](Instructions/Labs/LAB_03_2_export-reports-with-graph-and-excel.md) (draft) | 35 min |
| 3.3 | [Enroll and check a Linux desktop](Instructions/Labs/LAB_03_3_enroll-and-check-a-linux-desktop.md) (draft) | 30 min |
| 3.4 | [Deploy a Universal Print printer](Instructions/Labs/LAB_03_4_deploy-a-universal-print-printer.md) (draft) | 20 min |

### Builders

[Firewall rule builder](https://happelm.github.io/MDDMI-Adv/Tools/firewall-rule-builder.html) (draft) – pick firewall rule groups and add custom rules; builds the rule file for `New-IntuneFirewallRulePolicy.ps1`.

### Appendix

[Appendix](Instructions/Appendix.md)

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
- Lab files: [Labfiles folder in this repository](Labfiles)

## Known issues and feedback

Known issues, workarounds and corrections are tracked in the [Issues](https://github.com/happelm/MDDMI-Adv/issues) tab. If something in a lab does not work as described, check the open issues first, then open a new one with the lab number and the step.

## Contributing

Trainers and participants may fork this repository. Pull requests are welcome and are merged after review.

(c) Enterprise Training Center
