#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys the Remote Help unattended control prerequisites for Windows to Intune:
    Azure Virtual Desktop Agent + Azure Virtual Desktop Agent Bootloader as Win32 apps.

.DESCRIPTION
    1. Downloads both MSIs from the Microsoft fwlinks referenced in the Remote Help docs
       and verifies their Authenticode signature (Microsoft Corporation).
    2. Packages each MSI with IntuneWinAppUtil.exe (downloaded from GitHub if not provided).
    3. Creates a win32LobApp per package via Microsoft Graph (beta), uploads the encrypted
       content to the Intune Azure Storage SAS URI (block upload), commits the file and
       sets committedContentVersion.
       - Install:   msiexec /i "<msi>" /qn
       - Uninstall: msiexec /x "{ProductCode}" /qn
       - Detection: MSI product code
       - Requirement: x64, Windows 10 1607
    4. Sets the dependency Bootloader -> Agent (dependencyType autoInstall).
    5. Optionally assigns both apps as Required to a device group.

    Existing apps with the same display name are reused (no re-upload) unless -Force is set.

    Docs: https://learn.microsoft.com/intune/remote-help/deploy  (Unattended support)

.PARAMETER TenantId
    Optional. Tenant ID or verified domain to sign in to. If omitted, the tenant comes
    from the account you sign in with interactively (its home tenant).

.PARAMETER AssignmentGroupName
    Display name of a device group. If set, both apps are assigned as Required to it.
    NOTE: /assign replaces all existing assignments of the two apps.

.PARAMETER WorkingDirectory
    Folder for downloads, packages and extraction. Default: .\work next to the script.

.PARAMETER IntuneWinAppUtilPath
    Path to an existing IntuneWinAppUtil.exe. If omitted, it is downloaded from
    github.com/microsoft/Microsoft-Win32-Content-Prep-Tool.

.PARAMETER Force
    Create new apps even if apps with the same display name already exist.

.PARAMETER SkipTenantConfirmation
    Do not ask for confirmation after sign-in. By default the script shows the tenant ID
    and account it is connected to and waits for "y" before it changes anything.

.EXAMPLE
    .\Deploy-RemoteHelpUnattendedApps.ps1

.EXAMPLE
    .\Deploy-RemoteHelpUnattendedApps.ps1 -AssignmentGroupName 'SG-Dev-RemoteHelp-Unattended'

.NOTES
    Requires module Microsoft.Graph.Authentication (installed for CurrentUser if missing).
    Interactive sign-in, delegated scopes:
      DeviceManagementApps.ReadWrite.All
      Group.Read.All (only with -AssignmentGroupName)
    Signed-in account needs an Intune role that allows creating/assigning apps
    (e.g. Intune Administrator / Application Manager).
#>
[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$AssignmentGroupName,
    [string]$WorkingDirectory,
    [string]$IntuneWinAppUtilPath,
    [switch]$Force,
    [switch]$SkipTenantConfirmation
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # Invoke-WebRequest is very slow in WinPS 5.1 with progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not $WorkingDirectory) { $WorkingDirectory = Join-Path $PSScriptRoot 'work' }
New-Item -Path $WorkingDirectory -ItemType Directory -Force | Out-Null

$GraphBase = 'https://graph.microsoft.com/beta'

# Order matters: Agent first, Bootloader depends on it
$Packages = @(
    [pscustomobject]@{
        Key         = 'Agent'
        Url         = 'https://go.microsoft.com/fwlink/?linkid=2310011'
        MsiName     = 'Microsoft.RDInfra.RDAgent.Installer-x64.msi'
        Description = 'Azure Virtual Desktop Agent. Prerequisite for Intune Remote Help unattended control (remote sign-in) on Windows. The agent self-updates; registration token stays INVALID_TOKEN by design.'
    }
    [pscustomobject]@{
        Key         = 'Bootloader'
        Url         = 'https://go.microsoft.com/fwlink/?linkid=2311028'
        MsiName     = 'Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi'
        Description = 'Azure Virtual Desktop Agent Bootloader. Prerequisite for Intune Remote Help unattended control (remote sign-in) on Windows. Depends on the Azure Virtual Desktop Agent app.'
    }
)

#region Helpers ------------------------------------------------------------------

function Write-Step {
    param([string]$Message)
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Cyan
}

function Invoke-Graph {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        $Body
    )
    $params = @{ Method = $Method; Uri = $Uri; OutputType = 'PSObject' }
    if ($null -ne $Body) {
        $params.Body        = ConvertTo-Json -InputObject $Body -Depth 10
        $params.ContentType = 'application/json'
    }
    Invoke-MgGraphRequest @params
}

function Get-GraphCollection {
    param([Parameter(Mandatory)][string]$Uri)
    $items = @()
    $next  = $Uri
    while ($next) {
        $resp  = Invoke-Graph -Method GET -Uri $next
        $items += @($resp.value)
        $next  = $resp.'@odata.nextLink'
    }
    $items
}

function Get-IntuneWinAppUtil {
    if ($IntuneWinAppUtilPath) {
        if (-not (Test-Path $IntuneWinAppUtilPath)) { throw "IntuneWinAppUtil.exe not found: $IntuneWinAppUtilPath" }
        return (Resolve-Path $IntuneWinAppUtilPath).Path
    }
    $exe = Join-Path $WorkingDirectory 'IntuneWinAppUtil.exe'
    if (-not (Test-Path $exe)) {
        Write-Step 'Downloading IntuneWinAppUtil.exe (Microsoft-Win32-Content-Prep-Tool)'
        Invoke-WebRequest -Uri 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe' -OutFile $exe -UseBasicParsing
        Unblock-File -Path $exe
    }
    $sig = Get-AuthenticodeSignature -FilePath $exe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw "IntuneWinAppUtil.exe signature check failed ($($sig.Status))"
    }
    $exe
}

function New-IntuneWinPackage {
    param(
        [Parameter(Mandatory)]$Package,
        [Parameter(Mandatory)][string]$Tool
    )
    $root    = Join-Path $WorkingDirectory $Package.Key
    $src     = Join-Path $root 'source'
    $out     = Join-Path $root 'output'
    $extract = Join-Path $root 'extract'
    foreach ($dir in $src, $out, $extract) {
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    }
    foreach ($dir in $src, $out) { New-Item $dir -ItemType Directory -Force | Out-Null }

    $msi = Join-Path $src $Package.MsiName
    Write-Step "Downloading $($Package.Key) MSI"
    Invoke-WebRequest -Uri $Package.Url -OutFile $msi -UseBasicParsing
    Unblock-File -Path $msi

    $sig = Get-AuthenticodeSignature -FilePath $msi
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw "Signature check failed for $msi ($($sig.Status), $($sig.SignerCertificate.Subject))"
    }

    Write-Step "Packaging $($Package.MsiName)"
    $argList = @('-c', "`"$src`"", '-s', "`"$msi`"", '-o', "`"$out`"", '-q')
    $proc = Start-Process -FilePath $Tool -ArgumentList $argList -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw "IntuneWinAppUtil.exe failed with exit code $($proc.ExitCode)" }

    $intunewin = Get-ChildItem -Path $out -Filter '*.intunewin' | Select-Object -First 1
    if (-not $intunewin) { throw "No .intunewin produced in $out" }

    # .intunewin is a zip: Metadata\Detection.xml + Contents\IntunePackage.intunewin (encrypted)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($intunewin.FullName, $extract)

    [xml]$detection = Get-Content -Path (Join-Path $extract 'IntuneWinPackage\Metadata\Detection.xml') -Raw
    $encrypted = Join-Path $extract ("IntuneWinPackage\Contents\" + $detection.ApplicationInfo.FileName)
    if (-not (Test-Path $encrypted)) { throw "Encrypted content not found: $encrypted" }

    [pscustomobject]@{
        Package       = $Package
        IntuneWinFile = $intunewin
        EncryptedFile = $encrypted
        Info          = $detection.ApplicationInfo
    }
}

function Wait-ContentFileState {
    param(
        [Parameter(Mandatory)][string]$FileUri,
        [Parameter(Mandatory)][string]$SuccessState,
        [int]$TimeoutSeconds = 300
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $file = Invoke-Graph -Method GET -Uri $FileUri
        if ($file.uploadState -eq $SuccessState) { return $file }
        if ($file.uploadState -match 'Failed|TimedOut') { throw "Content file upload state: $($file.uploadState)" }
        Start-Sleep -Seconds 3
    }
    throw "Timeout waiting for upload state '$SuccessState' (last: $($file.uploadState))"
}

function Send-AzureBlob {
    param(
        [Parameter(Mandatory)][string]$SasUri,
        [Parameter(Mandatory)][string]$FilePath
    )
    $chunkSize = 6MB
    $blockIds  = New-Object System.Collections.Generic.List[string]
    $stream    = [IO.File]::OpenRead($FilePath)
    try {
        $buffer = New-Object byte[] $chunkSize
        $index  = 0
        while (($read = $stream.Read($buffer, 0, $chunkSize)) -gt 0) {
            $chunk = New-Object byte[] $read
            [Array]::Copy($buffer, $chunk, $read)
            $blockId = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($index.ToString('0000')))
            $uri = "$SasUri&comp=block&blockid=$([uri]::EscapeDataString($blockId))"
            Invoke-RestMethod -Uri $uri -Method Put -Body $chunk -ContentType 'application/octet-stream' -Headers @{ 'x-ms-blob-type' = 'BlockBlob' } | Out-Null
            $blockIds.Add($blockId)
            $index++
        }
    }
    finally { $stream.Dispose() }

    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>' +
           (($blockIds | ForEach-Object { "<Latest>$_</Latest>" }) -join '') +
           '</BlockList>'
    Invoke-RestMethod -Uri "$SasUri&comp=blocklist" -Method Put -Body $xml -ContentType 'application/xml' | Out-Null
}

function Publish-Win32App {
    param([Parameter(Mandatory)]$Pkg)

    $info        = $Pkg.Info
    $msi         = $info.MsiInfo
    $displayName = [string]$info.Name
    $productCode = [string]$msi.MsiProductCode

    $existing = Get-GraphCollection -Uri "$GraphBase/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')&`$select=id,displayName" |
                Where-Object { $_.displayName -eq $displayName }
    if ($existing -and -not $Force) {
        $id = @($existing)[0].id
        Write-Warning "App '$displayName' already exists ($id) - reusing it. Use -Force to create a new one."
        return $id
    }

    $packageType = switch ([string]$msi.MsiExecutionContext) {
        'User'  { 'perUser' }
        'Any'   { 'dualPurpose' }
        default { 'perMachine' }
    }

    $body = @{
        '@odata.type'                  = '#microsoft.graph.win32LobApp'
        displayName                    = $displayName
        description                    = $Pkg.Package.Description
        publisher                      = 'Microsoft'
        developer                      = 'Microsoft'
        notes                          = 'Created by Deploy-RemoteHelpUnattendedApps.ps1'
        displayVersion                 = [string]$msi.MsiProductVersion
        fileName                       = $Pkg.IntuneWinFile.Name
        setupFilePath                  = [string]$info.SetupFile
        installCommandLine             = "msiexec /i `"$($info.SetupFile)`" /qn"
        uninstallCommandLine           = "msiexec /x `"$productCode`" /qn"
        applicableArchitectures        = 'x64'
        minimumSupportedWindowsRelease = '1607'
        allowAvailableUninstall        = $false
        installExperience              = @{
            '@odata.type'         = '#microsoft.graph.win32LobAppInstallExperience'
            runAsAccount          = 'system'
            deviceRestartBehavior = 'suppress'
            maxRunTimeInMinutes   = 60
        }
        returnCodes                    = @(
            @{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = 0;    type = 'success' }
            @{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = 1707; type = 'success' }
            @{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = 3010; type = 'softReboot' }
            @{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = 1641; type = 'hardReboot' }
            @{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = 1618; type = 'retry' }
        )
        rules                          = @(
            @{
                '@odata.type'          = '#microsoft.graph.win32LobAppProductCodeRule'
                ruleType               = 'detection'
                productCode            = $productCode
                productVersionOperator = 'notConfigured'
                productVersion         = $null
            }
        )
        msiInformation                 = @{
            productCode    = $productCode
            productVersion = [string]$msi.MsiProductVersion
            upgradeCode    = [string]$msi.MsiUpgradeCode
            requiresReboot = ([string]$msi.MsiRequiresReboot -eq 'true')
            packageType    = $packageType
            productName    = $displayName
            publisher      = [string]$msi.MsiPublisher
        }
    }

    Write-Step "Creating Win32 app '$displayName' ($($msi.MsiProductVersion))"
    $app    = Invoke-Graph -Method POST -Uri "$GraphBase/deviceAppManagement/mobileApps" -Body $body
    $appUri = "$GraphBase/deviceAppManagement/mobileApps/$($app.id)"

    $cv    = Invoke-Graph -Method POST -Uri "$appUri/microsoft.graph.win32LobApp/contentVersions" -Body @{}
    $cvUri = "$appUri/microsoft.graph.win32LobApp/contentVersions/$($cv.id)"

    $fileBody = @{
        '@odata.type' = '#microsoft.graph.mobileAppContentFile'
        name          = [string]$info.FileName
        size          = [int64]$info.UnencryptedContentSize
        sizeEncrypted = [int64](Get-Item $Pkg.EncryptedFile).Length
        manifest      = $null
        isDependency  = $false
    }
    $file    = Invoke-Graph -Method POST -Uri "$cvUri/files" -Body $fileBody
    $fileUri = "$cvUri/files/$($file.id)"
    $file    = Wait-ContentFileState -FileUri $fileUri -SuccessState 'azureStorageUriRequestSuccess'

    Write-Step "Uploading content ($([math]::Round($fileBody.sizeEncrypted / 1MB, 1)) MB)"
    Send-AzureBlob -SasUri $file.azureStorageUri -FilePath $Pkg.EncryptedFile

    $enc = $info.EncryptionInfo
    $commitBody = @{
        fileEncryptionInfo = @{
            encryptionKey        = [string]$enc.EncryptionKey
            macKey               = [string]$enc.MacKey
            initializationVector = [string]$enc.InitializationVector
            mac                  = [string]$enc.Mac
            profileIdentifier    = 'ProfileVersion1'
            fileDigest           = [string]$enc.FileDigest
            fileDigestAlgorithm  = [string]$enc.FileDigestAlgorithm
        }
    }
    Write-Step 'Committing content file'
    Invoke-Graph -Method POST -Uri "$fileUri/commit" -Body $commitBody | Out-Null
    Wait-ContentFileState -FileUri $fileUri -SuccessState 'commitFileSuccess' | Out-Null

    Invoke-Graph -Method PATCH -Uri $appUri -Body @{
        '@odata.type'           = '#microsoft.graph.win32LobApp'
        committedContentVersion = [string]$cv.id
    } | Out-Null

    Write-Step "App '$displayName' published ($($app.id))"
    $app.id
}

#endregion

#region Main ---------------------------------------------------------------------

# 1. Package (no sign-in needed yet)
$tool  = Get-IntuneWinAppUtil
$built = foreach ($p in $Packages) { New-IntuneWinPackage -Package $p -Tool $tool }

# 2. Sign in
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication

$scopes = @('DeviceManagementApps.ReadWrite.All')
if ($AssignmentGroupName) { $scopes += 'Group.Read.All' }
$connectParams = @{ Scopes = $scopes; NoWelcome = $true }
if ($TenantId) {
    $connectParams.TenantId = $TenantId
    Write-Step "Connecting to Microsoft Graph (tenant $TenantId)"
}
else {
    Write-Step 'Connecting to Microsoft Graph (tenant from your sign-in)'
}
Connect-MgGraph @connectParams
$ctx = Get-MgContext
if (-not $ctx -or -not $ctx.TenantId) { throw 'Not connected to Microsoft Graph.' }
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"

# A cached sign-in can silently land in the wrong tenant: confirm before changing anything
if (-not $SkipTenantConfirmation) {
    $answer = Read-Host "Create the apps in tenant $($ctx.TenantId) as $($ctx.Account)? [y/N]"
    if ($answer -notmatch '^(y|yes)$') {
        Write-Warning 'Aborted. Run Disconnect-MgGraph to sign in with another account, or use -TenantId.'
        return
    }
}

# 3. Upload
$appIds = @{}
foreach ($b in $built) { $appIds[$b.Package.Key] = Publish-Win32App -Pkg $b }

# 4. Dependency Bootloader -> Agent (auto install)
Write-Step 'Setting dependency Bootloader -> Agent (autoInstall)'
Invoke-Graph -Method POST -Uri "$GraphBase/deviceAppManagement/mobileApps/$($appIds.Bootloader)/updateRelationships" -Body @{
    relationships = @(
        @{
            '@odata.type'  = '#microsoft.graph.mobileAppDependency'
            targetId       = $appIds.Agent
            dependencyType = 'autoInstall'
        }
    )
} | Out-Null

# 5. Optional assignment
if ($AssignmentGroupName) {
    $escaped = $AssignmentGroupName.Replace("'", "''")
    $groups  = @(Get-GraphCollection -Uri "$GraphBase/groups?`$filter=displayName eq '$escaped'&`$select=id,displayName")
    if ($groups.Count -ne 1) { throw "Expected exactly one group named '$AssignmentGroupName', found $($groups.Count)" }
    $groupId = $groups[0].id

    foreach ($key in 'Agent', 'Bootloader') {
        Write-Step "Assigning $key as Required to '$AssignmentGroupName'"
        Invoke-Graph -Method POST -Uri "$GraphBase/deviceAppManagement/mobileApps/$($appIds[$key])/assign" -Body @{
            mobileAppAssignments = @(
                @{
                    '@odata.type' = '#microsoft.graph.mobileAppAssignment'
                    intent        = 'required'
                    target        = @{
                        '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                        groupId       = $groupId
                    }
                    settings      = @{
                        '@odata.type'                = '#microsoft.graph.win32LobAppAssignmentSettings'
                        notifications                = 'hideAll'
                        deliveryOptimizationPriority = 'notConfigured'
                        installTimeSettings          = $null
                        restartSettings              = $null
                    }
                }
            )
        } | Out-Null
    }
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
[pscustomobject]@{
    AgentAppId      = $appIds.Agent
    BootloaderAppId = $appIds.Bootloader
    AssignedTo      = $AssignmentGroupName
    TenantId        = $ctx.TenantId
}

#endregion
