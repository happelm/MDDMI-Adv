# Win32 app pipeline

`New-IntuneWin32AppFromFolder.ps1` turns an app folder into a Win32 app in Intune: package with IntuneWinAppUtil.exe, create the app via Graph, upload the content, set detection, return codes and requirements, and optionally assign it. All settings come from `app.json` in the app folder.

## Folder layout on CL1

```text
C:\Software\
  7-Zip\
    app.json
    Source\7z2501-x64.msi
  FirefoxESR\
    app.json
    Source\                      PSADT v4 package (Invoke-AppDeployToolkit.exe, Files\, SupportFiles\, ...)
  Intune\                        output, written by the script (one subfolder per app)
```

Copy a sample folder from `Samples\` to `C:\Software`, put the installer (or the PSADT package) into `Source\`, adjust `app.json`.

## Run

```powershell
# Package and show the request body, no changes in Intune
.\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly

# Create one app
.\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip

# All folders below C:\Software that contain an app.json, assigned as required to a group
.\New-IntuneWin32AppFromFolder.ps1 -All -AssignmentGroupName "All Windows 11 Devices"
```

An app with the same display name and version that already exists is skipped (`-Force` creates it again). Supersedence and dependencies are not set.

## app.json

| Key | Required | Meaning |
|---|---|---|
| `displayName`, `publisher` | yes | Shown in Intune and Company Portal. |
| `setupFile` | yes | File in `Source\` that IntuneWinAppUtil uses as setup file (`-s`). |
| `description`, `developer` | no | Default for description: display name. |
| `version` | no | Display version. Default for an MSI: ProductVersion. |
| `sourceFolder` | no | Default `Source`. |
| `installCommand`, `uninstallCommand` | for non-MSI | Default for an MSI: `msiexec /i "<setupFile>" /qn`, `msiexec /x "{ProductCode}" /qn`. |
| `installContext` | no | `system` (default) or `user`. |
| `restartBehavior` | no | `basedOnReturnCode` (default), `allow`, `suppress`, `force`. |
| `maxRunTimeInMinutes` | no | Default 60. |
| `architecture` | no | `x64` (default), `x86`, `none` (= any). |
| `minimumWindowsRelease` | no | Default `1607`. Graph example format: `Windows11_23H2`. |
| `allowAvailableUninstall` | no | Uninstall button in Company Portal for available assignments. |
| `returnCodes` | no | Added to the Intune defaults (0, 1707, 3010, 1641, 1618), e.g. `{ "code": 1602, "type": "retry" }`. Types: `success`, `softReboot`, `hardReboot`, `retry`, `failed`. |
| `detection` | yes | One or more rules (AND), see below. |
| `assignment` | no | `{ "group": "<name>", "intent": "required", "notifications": "showAll" }`. `-AssignmentGroupName` overrides the group. |

Detection rules:

| `type` | Keys | Notes |
|---|---|---|
| `msi` | `msiFile` (only if the setup file is not an MSI), `versionOperator` | Product code from the setup MSI, or from an MSI inside the package (e.g. `Files\app.msi` of a PSADT package). |
| `file` | `path`, `name`, `check32BitOn64System`, `operation`, `operator`, `value` | `operation`: `exists` (default), `doesNotExist`, `version`, `modifiedDate`, `createdDate`, `sizeInMB`. |
| `registry` | `keyPath`, `valueName`, `check32BitOn64System`, `operation`, `operator`, `value` | `operation`: `exists` (default), `doesNotExist`, `string`, `integer`, `version`. |
| `script` | `file`, `runAs32Bit`, `enforceSignatureCheck` | PowerShell file in the app folder. Only rule allowed when used. |

Rule properties follow the Graph beta types [win32LobAppFileSystemRule](https://learn.microsoft.com/graph/api/resources/intune-apps-win32lobappfilesystemrule?view=graph-rest-beta), [win32LobAppRegistryRule](https://learn.microsoft.com/graph/api/resources/intune-apps-win32lobappregistryrule?view=graph-rest-beta) and [win32LobAppPowerShellScriptRule](https://learn.microsoft.com/graph/api/resources/intune-apps-win32lobapppowershellscriptrule?view=graph-rest-beta).

## PSADT packages

A PSADT package is a normal source folder for the pipeline. `setupFile` is `Invoke-AppDeployToolkit.exe`, the commands are `Invoke-AppDeployToolkit.exe -DeploymentType Install` / `Uninstall`, and detection comes from `app.json` (PSADT does not provide one). See `Samples\FirefoxESR`, the Firefox ESR package built in the SCMI course (Lab 10.1): detection on `policies.json`, return code 1602 as retry (user deferred).
