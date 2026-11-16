<#
.SYNOPSIS
    Remediation script: sets AutoAcceptSsoPermission = 1 so that the Windows SSO prompt
    ("Continue to sign in?") is accepted automatically on managed devices.

.NOTES
    Registry : HKLM\SOFTWARE\Policies\Microsoft\Windows\AAD
    Value    : AutoAcceptSsoPermission (DWORD) = 1
    Requires : Windows 11 24H2 or 25H2 with the July 2026 security update (KB5101650) or later.
               On older builds the value is written but has no effect.
    Intune   : Run this script using the logged-on credentials = No, Run script in 64-bit PowerShell = Yes
    Source   : https://learn.microsoft.com/entra/identity/devices/sso-admin-control
#>

$RegPath   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD'
$ValueName = 'AutoAcceptSsoPermission'
$Value     = 1

try {
    if (-not (Test-Path -Path $RegPath)) {
        New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name $ValueName -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null

    # Verify the write
    $current = Get-ItemPropertyValue -Path $RegPath -Name $ValueName -ErrorAction Stop
    if ($current -eq $Value) {
        Write-Output "Success: $ValueName = $current"
        exit 0
    }

    Write-Output "Error: unexpected value after write ($current)"
    exit 1
}
catch {
    Write-Output "Error setting ${ValueName}: $($_.Exception.Message)"
    exit 1
}
