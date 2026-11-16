# Toolbox

Three read-only PowerShell scripts for questions the Intune admin center answers badly or not at all. They are a bonus to the course: no lab depends on them. Use them in your lab tenant during the course and in your own tenant afterwards.

| Script | Question it answers | Why not in the portal |
|---|---|---|
| [`Export-IntunePolicyDocumentation.ps1`](Export-IntunePolicyDocumentation.ps1) | What exactly is configured in my settings catalog policies, and to whom are they assigned? | The portal shows settings on screen only, one policy at a time. There is no export. |
| [`Compare-IntuneEntraDevices.ps1`](Compare-IntuneEntraDevices.ps1) | Which devices exist only in Intune or only in Entra ID, which are stale, disabled or report a different compliance state? | Intune and Entra ID show two separate device lists. Nothing joins them. |
| [`Get-IntunePolicyAssignmentsByGroup.ps1`](Get-IntunePolicyAssignmentsByGroup.ps1) | What does this group, device or user get from Intune – policies, apps, scripts, enrollment profiles, including nested groups and excludes? | The portal shows assignments per object, not per group. |

Every Graph request in these scripts is GET. Nothing is changed in the tenant.

## Run a script

1. Download the script (open it on GitHub, **Download raw file**) to a folder, for example `C:\Toolbox`.
2. Open Windows PowerShell (not elevated) in that folder. The scripts install the module `Microsoft.Graph.Authentication` for your account if it is missing.
3. Run the script and sign in with an admin account of your tenant. The first run asks for consent to the read permissions.

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Export-IntunePolicyDocumentation.ps1
```

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Compare-IntuneEntraDevices.ps1 -StaleDays 90
```

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File .\Get-IntunePolicyAssignmentsByGroup.ps1 -GroupName 'All Windows 11 Devices' -IncludeAllUsersAllDevices -ExportCsv -OutputFolder 'C:\Temp'
```

Every script has help with all parameters: `Get-Help .\<script>.ps1 -Full`.

| Script | Output | Graph permissions (delegated) |
|---|---|---|
| `Export-IntunePolicyDocumentation.ps1` | `C:\Temp\IntuneDocumentation\IntunePolicyDocumentation.html` and `.csv` | `DeviceManagementConfiguration.Read.All`, `Group.Read.All` |
| `Compare-IntuneEntraDevices.ps1` | Summary in the console, `C:\Temp\IntuneEntraDeviceComparison.csv` | `DeviceManagementManagedDevices.Read.All`, `Device.Read.All` |
| `Get-IntunePolicyAssignmentsByGroup.ps1` | Table in the console, CSV in `C:\Temp` with `-ExportCsv -OutputFolder 'C:\Temp'` | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All`, `DeviceManagementServiceConfig.Read.All`, `DeviceManagementRBAC.Read.All`, `GroupMember.Read.All` |

CSV files use the delimiter `;` and UTF-8, so Excel with German regional settings opens them directly.

## Written with AI – checked by a human

These scripts were written with an AI assistant and then checked: every Graph URL against the Microsoft Graph reference and against a real tenant, read scopes only, paging over `@odata.nextLink`. Do the same before you trust a script that an AI writes for you:

- [ ] Only `GET` requests – search the script for `POST`, `PATCH`, `PUT`, `DELETE`, `Remove-`, `Set-`, `New-`.
- [ ] Only `Read` scopes in `Connect-MgGraph`, none ending in `ReadWrite`.
- [ ] Every Graph URL exists: `Find-MgGraphCommand -Uri '<url>' -Method GET` or the Graph reference on Microsoft Learn – `v1.0` or `beta`, property names in `$select` and `$filter`.
- [ ] Paging: the script follows `@odata.nextLink` (or uses `-All`). Without it, it silently stops after the first page.
- [ ] Result checked against the portal for at least one device, policy or group.

**Note:** `Get-IntunePolicyAssignmentsByGroup.ps1` is the same script that the labs use from [`Labfiles/Assignments`](../Labfiles/Assignments). The copy here is for use after the course.

**Note:** The scripts run with your permissions. Your Intune role and scope tags decide what Graph returns.
