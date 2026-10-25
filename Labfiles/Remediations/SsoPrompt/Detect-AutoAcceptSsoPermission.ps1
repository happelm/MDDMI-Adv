<#
.SYNOPSIS
    Remediation detection script: checks whether the Windows SSO prompt ("Continue to sign in?")
    is accepted automatically by policy.

.DESCRIPTION
    In the European Economic Area, Windows asks users whether their Windows sign-in may be used
    to sign in to other Microsoft apps and services. On managed devices the prompt can be
    accepted automatically with the registry value AutoAcceptSsoPermission = 1.

    Exit 0 = compliant, exit 1 = remediation needed.

.NOTES
    Registry : HKLM\SOFTWARE\Policies\Microsoft\Windows\AAD
    Value    : AutoAcceptSsoPermission (DWORD) = 1
    Requires : Windows 11 24H2 or 25H2 with the July 2026 security update (KB5101650) or later
    Intune   : Run this script using the logged-on credentials = No, Run script in 64-bit PowerShell = Yes
    Source   : https://learn.microsoft.com/entra/identity/devices/sso-admin-control
#>

$RegPath   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AAD'
$ValueName = 'AutoAcceptSsoPermission'
$Expected  = 1

try {
    $current = Get-ItemPropertyValue -Path $RegPath -Name $ValueName -ErrorAction Stop
    if ($current -eq $Expected) {
        Write-Output "Compliant: $ValueName = $current"
        exit 0
    }
    Write-Output "Not compliant: $ValueName = $current (expected: $Expected)"
    exit 1
}
catch {
    Write-Output "Not compliant: $ValueName not found under $RegPath"
    exit 1
}
