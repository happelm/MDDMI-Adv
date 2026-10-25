# SSO prompt: auto-accept on managed devices

Remediation pair for the Windows SSO prompt ("Continue to sign in?") that users in the European Economic Area see after signing in to Windows.

| File | Role |
|---|---|
| `Detect-AutoAcceptSsoPermission.ps1` | Detection script. Exit 0 if `AutoAcceptSsoPermission` = 1, otherwise exit 1. |
| `Remediate-AutoAcceptSsoPermission.ps1` | Remediation script. Writes the value and verifies it. |

- Registry value: `HKLM\SOFTWARE\Policies\Microsoft\Windows\AAD`, `AutoAcceptSsoPermission` (DWORD) = 1.
- Requires Windows 11 24H2 or 25H2 with the July 2026 security update (KB5101650) or later.
- Applies only to managed devices with Microsoft Entra ID accounts. Prompts for personal Microsoft accounts stay.
- Intune settings: run as system (logged-on credentials = No), 64-bit PowerShell = Yes.
- At the time of writing there is no Settings Catalog setting for this value, so a Remediation is the Intune route.

Source: [Admin control for SSO prompts in Windows](https://learn.microsoft.com/entra/identity/devices/sso-admin-control).

> **Note:** The text on that page names `...\Policies\Microsoft\Windows\AAD`, the registry screenshot on the same page shows `...\Policies\Microsoft\AAD`. The scripts follow the text.
