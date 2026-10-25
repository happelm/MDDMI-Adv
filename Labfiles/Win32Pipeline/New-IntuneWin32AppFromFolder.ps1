#Requires -Version 5.1
<#
.SYNOPSIS
    Win32 app pipeline: packages an app folder with IntuneWinAppUtil.exe and creates the Win32 app in
    Intune from the settings in the folder's app.json (upload, detection, requirements, return codes,
    optional assignment).

.DESCRIPTION
    Folder layout (one folder per app, default root C:\Software):

        C:\Software\<App>\app.json        settings of the Win32 app (see Samples\ and README.md)
        C:\Software\<App>\Source\         content to package: an MSI, an EXE with wrapper, or a PSADT package
        C:\Software\<App>\Detect.ps1      optional detection script (detection type "script")
        C:\Software\Intune\<App>\         output: .intunewin (written by this script)

    Steps per app:
      1. Read and validate app.json.
      2. Package Source\ with IntuneWinAppUtil.exe (downloaded from GitHub if not provided).
      3. Read Detection.xml from the package (encryption info, MSI product code if the setup file is an MSI).
      4. Create the win32LobApp via Microsoft Graph (beta), upload the encrypted content to Azure Storage,
         commit it and set committedContentVersion.
      5. Optionally assign the app (app.json "assignment" or -AssignmentGroupName).

    PSADT packages need no special handling: Source\ is the PSADT folder, setupFile is
    Invoke-AppDeployToolkit.exe, install/uninstall commands and detection come from app.json.
    Detection type "msi" with "msiFile" reads the product code from an MSI inside the package
    (e.g. Files\app.msi of a PSADT package).

    An app with the same display name and version that already exists in Intune is skipped unless -Force is set.
    Supersedence and dependencies are not set by this script.

.PARAMETER Path
    One or more app folders (each with app.json).

.PARAMETER Root
    Process every subfolder of this folder that contains an app.json. Default for -All: C:\Software.

.PARAMETER All
    Process all app folders below -Root.

.PARAMETER OutputRoot
    Output folder for the .intunewin files. Default: <Root>\Intune (C:\Software\Intune).

.PARAMETER PackageOnly
    Package and validate only, show the Graph request body, no sign-in and no changes in Intune.

.PARAMETER AssignmentGroupName
    Overrides the group of app.json "assignment" (intent from app.json, default required).

.PARAMETER IntuneWinAppUtilPath
    Path to an existing IntuneWinAppUtil.exe. If omitted, it is downloaded from
    github.com/microsoft/Microsoft-Win32-Content-Prep-Tool.

.PARAMETER Force
    Create the app even if an app with the same display name and version exists.

.PARAMETER TenantId
    Optional. Without it the tenant comes from the interactive sign-in.

.PARAMETER SkipTenantConfirmation
    Do not ask to confirm the connected tenant.

.EXAMPLE
    .\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip -PackageOnly
    Packages 7-Zip and shows what would be created. Nothing is changed in Intune.

.EXAMPLE
    .\New-IntuneWin32AppFromFolder.ps1 -Path C:\Software\7-Zip, C:\Software\FirefoxESR

.EXAMPLE
    .\New-IntuneWin32AppFromFolder.ps1 -All -AssignmentGroupName "All Windows 11 Devices"

.NOTES
    Version : 1.0 (2026-10-25)
    Requires: Windows PowerShell 5.1 or PowerShell 7 on Windows, Microsoft.Graph.Authentication
    Scopes  : DeviceManagementApps.ReadWrite.All, Group.Read.All (only for an assignment)
    Graph   : https://learn.microsoft.com/graph/api/resources/intune-apps-win32lobapp?view=graph-rest-beta
    Upload code shared with RemoteHelp\Deploy-RemoteHelpUnattendedApps.ps1.
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
    [string[]]$Path,

    [Parameter(Mandatory = $true, ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(ParameterSetName = 'All')]
    [string]$Root = 'C:\Software',

    [string]$OutputRoot,
    [switch]$PackageOnly,
    [string]$AssignmentGroupName,
    [string]$IntuneWinAppUtilPath,
    [switch]$Force,
    [string]$TenantId,
    [switch]$SkipTenantConfirmation
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$GraphBase = 'https://graph.microsoft.com/beta'

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
    param([string]$WorkFolder)
    if ($IntuneWinAppUtilPath) {
        if (-not (Test-Path $IntuneWinAppUtilPath)) { throw "IntuneWinAppUtil.exe not found: $IntuneWinAppUtilPath" }
        return (Resolve-Path $IntuneWinAppUtilPath).Path
    }
    $exe = Join-Path $WorkFolder 'IntuneWinAppUtil.exe'
    if (-not (Test-Path $exe)) {
        Write-Step 'Downloading IntuneWinAppUtil.exe (Microsoft-Win32-Content-Prep-Tool)'
        New-Item -Path $WorkFolder -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe' -OutFile $exe -UseBasicParsing
        Unblock-File -Path $exe
    }
    $sig = Get-AuthenticodeSignature -FilePath $exe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw "IntuneWinAppUtil.exe signature check failed ($($sig.Status))"
    }
    $exe
}

function Get-MsiProperty {
    # Reads properties from an MSI database (Windows Installer COM)
    param([Parameter(Mandatory)][string]$MsiPath, [string[]]$Names = @('ProductCode', 'ProductVersion', 'UpgradeCode', 'ProductName', 'Manufacturer'))
    $installer = New-Object -ComObject WindowsInstaller.Installer
    $db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($MsiPath, 0))
    $result = @{}
    foreach ($n in $Names) {
        $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT Value FROM Property WHERE Property = '$n'"))
        [void]$view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        if ($rec) { $result[$n] = $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, 1) }
        [void]$view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
    }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($db)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
    $result
}

function Read-AppDefinition {
    param([Parameter(Mandatory)][string]$Folder)
    $jsonPath = Join-Path $Folder 'app.json'
    if (-not (Test-Path $jsonPath)) { throw "app.json not found in $Folder" }
    $def = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json

    $problems = @()
    foreach ($req in 'displayName', 'publisher', 'setupFile') {
        if (-not $def.$req) { $problems += "'$req' is missing" }
    }
    $sourceFolder = if ($def.sourceFolder) { $def.sourceFolder } else { 'Source' }
    $source = Join-Path $Folder $sourceFolder
    if (-not (Test-Path $source -PathType Container)) { $problems += "source folder '$source' not found" }
    elseif ($def.setupFile -and -not (Test-Path (Join-Path $source $def.setupFile))) { $problems += "setup file '$($def.setupFile)' not found in $source" }

    $isMsi = ([IO.Path]::GetExtension([string]$def.setupFile) -eq '.msi')
    if (-not $isMsi -and -not $def.installCommand) { $problems += "'installCommand' is required when the setup file is not an MSI" }
    if (-not $isMsi -and -not $def.uninstallCommand) { $problems += "'uninstallCommand' is required when the setup file is not an MSI" }

    $detection = @($def.detection)
    if ($detection.Count -eq 0 -or $null -eq $detection[0]) { $problems += "'detection' needs at least one rule" }
    foreach ($d in $detection) {
        if (-not $d) { continue }
        switch ($d.type) {
            'msi'      { if (-not $isMsi -and -not $d.msiFile) { $problems += "detection 'msi' needs 'msiFile' when the setup file is not an MSI" }
                         if ($d.msiFile -and -not (Test-Path (Join-Path $source $d.msiFile))) { $problems += "msiFile '$($d.msiFile)' not found in $source" } }
            'file'     { if (-not $d.path -or -not $d.name) { $problems += "detection 'file' needs 'path' and 'name'" } }
            'registry' { if (-not $d.keyPath) { $problems += "detection 'registry' needs 'keyPath'" } }
            'script'   { if (-not $d.file -or -not (Test-Path (Join-Path $Folder $d.file))) { $problems += "detection script '$($d.file)' not found in $Folder" } }
            default    { $problems += "unknown detection type '$($d.type)' (msi, file, registry, script)" }
        }
    }
    if (@($detection | Where-Object { $_.type -eq 'script' }).Count -gt 0 -and $detection.Count -gt 1) {
        $problems += 'a script detection cannot be combined with other detection rules'
    }
    if ($problems.Count -gt 0) { throw "app.json in $Folder is invalid:`n - " + ($problems -join "`n - ") }

    [pscustomobject]@{ Folder = $Folder; Name = Split-Path $Folder -Leaf; Source = $source; IsMsi = $isMsi; Def = $def }
}

function New-IntuneWinPackage {
    param([Parameter(Mandatory)]$App, [Parameter(Mandatory)][string]$Tool, [Parameter(Mandatory)][string]$OutFolder)
    $out     = Join-Path $OutFolder $App.Name
    $extract = Join-Path $env:TEMP ("intunewin_{0}" -f ([guid]::NewGuid().ToString('N')))
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }
    New-Item $out -ItemType Directory -Force | Out-Null

    Write-Step "Packaging $($App.Name) ($($App.Def.setupFile))"
    $argList = @('-c', "`"$($App.Source)`"", '-s', "`"$($App.Def.setupFile)`"", '-o', "`"$out`"", '-q')
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

    [pscustomobject]@{ IntuneWinFile = $intunewin; EncryptedFile = $encrypted; ExtractFolder = $extract; Info = $detection.ApplicationInfo }
}

function Get-MsiData {
    # MSI product code etc.: from Detection.xml if the setup file is an MSI, else from "msiFile" in the package
    param($App, $Pkg)
    if ($App.IsMsi -and $Pkg.Info.MsiInfo) {
        $m = $Pkg.Info.MsiInfo
        return @{ ProductCode = [string]$m.MsiProductCode; ProductVersion = [string]$m.MsiProductVersion; UpgradeCode = [string]$m.MsiUpgradeCode
                  Publisher = [string]$m.MsiPublisher; ExecutionContext = [string]$m.MsiExecutionContext; RequiresReboot = ([string]$m.MsiRequiresReboot -eq 'true') }
    }
    $msiRule = @($App.Def.detection) | Where-Object { $_.type -eq 'msi' -and $_.msiFile } | Select-Object -First 1
    if ($msiRule) {
        $p = Get-MsiProperty -MsiPath (Join-Path $App.Source $msiRule.msiFile)
        return @{ ProductCode = $p.ProductCode; ProductVersion = $p.ProductVersion; UpgradeCode = $p.UpgradeCode; Publisher = $p.Manufacturer; ExecutionContext = $null; RequiresReboot = $false }
    }
    return $null
}

function New-DetectionRules {
    param($App, $Msi)
    foreach ($d in @($App.Def.detection)) {
        switch ($d.type) {
            'msi' {
                [ordered]@{
                    '@odata.type'          = '#microsoft.graph.win32LobAppProductCodeRule'
                    ruleType               = 'detection'
                    productCode            = $Msi.ProductCode
                    productVersionOperator = if ($d.versionOperator) { $d.versionOperator } else { 'notConfigured' }
                    productVersion         = if ($d.versionOperator) { $Msi.ProductVersion } else { $null }
                }
            }
            'file' {
                [ordered]@{
                    '@odata.type'        = '#microsoft.graph.win32LobAppFileSystemRule'
                    ruleType             = 'detection'
                    path                 = $d.path
                    fileOrFolderName     = $d.name
                    check32BitOn64System = [bool]$d.check32BitOn64System
                    operationType        = if ($d.operation) { $d.operation } else { 'exists' }
                    operator             = if ($d.operator) { $d.operator } else { 'notConfigured' }
                    comparisonValue      = $d.value
                }
            }
            'registry' {
                [ordered]@{
                    '@odata.type'        = '#microsoft.graph.win32LobAppRegistryRule'
                    ruleType             = 'detection'
                    keyPath              = $d.keyPath
                    valueName            = $d.valueName
                    check32BitOn64System = [bool]$d.check32BitOn64System
                    operationType        = if ($d.operation) { $d.operation } else { 'exists' }
                    operator             = if ($d.operator) { $d.operator } else { 'notConfigured' }
                    comparisonValue      = $d.value
                }
            }
            'script' {
                $content = [IO.File]::ReadAllBytes((Join-Path $App.Folder $d.file))
                [ordered]@{
                    '@odata.type'         = '#microsoft.graph.win32LobAppPowerShellScriptRule'
                    ruleType              = 'detection'
                    enforceSignatureCheck = [bool]$d.enforceSignatureCheck
                    runAs32Bit            = [bool]$d.runAs32Bit
                    scriptContent         = [Convert]::ToBase64String($content)
                    operationType         = 'notConfigured'
                    operator              = 'notConfigured'
                    comparisonValue       = $null
                }
            }
        }
    }
}

function New-AppBody {
    param($App, $Pkg, $Msi)
    $def = $App.Def
    $setup = [string]$Pkg.Info.SetupFile

    $install   = if ($def.installCommand) { $def.installCommand } else { "msiexec /i `"$setup`" /qn" }
    $uninstall = if ($def.uninstallCommand) { $def.uninstallCommand } else { "msiexec /x `"$($Msi.ProductCode)`" /qn" }
    $version   = if ($def.version) { [string]$def.version } elseif ($Msi) { $Msi.ProductVersion } else { $null }

    # Intune defaults for new Win32 apps, then the codes from app.json (same code from app.json wins)
    $codes = [ordered]@{ '0' = 'success'; '1707' = 'success'; '3010' = 'softReboot'; '1641' = 'hardReboot'; '1618' = 'retry' }
    foreach ($rc in @($def.returnCodes)) { if ($rc) { $codes["$($rc.code)"] = $rc.type } }
    $returnCodes = foreach ($k in $codes.Keys) {
        [ordered]@{ '@odata.type' = '#microsoft.graph.win32LobAppReturnCode'; returnCode = [int]$k; type = $codes[$k] }
    }

    $body = [ordered]@{
        '@odata.type'                  = '#microsoft.graph.win32LobApp'
        displayName                    = [string]$def.displayName
        description                    = if ($def.description) { [string]$def.description } else { [string]$def.displayName }
        publisher                      = [string]$def.publisher
        notes                          = 'Created by New-IntuneWin32AppFromFolder.ps1'
        displayVersion                 = $version
        fileName                       = $Pkg.IntuneWinFile.Name
        setupFilePath                  = $setup
        installCommandLine             = $install
        uninstallCommandLine           = $uninstall
        applicableArchitectures        = if ($def.architecture) { [string]$def.architecture } else { 'x64' }
        minimumSupportedWindowsRelease = if ($def.minimumWindowsRelease) { [string]$def.minimumWindowsRelease } else { '1607' }
        allowAvailableUninstall        = [bool]$def.allowAvailableUninstall
        installExperience              = [ordered]@{
            '@odata.type'         = '#microsoft.graph.win32LobAppInstallExperience'
            runAsAccount          = if ($def.installContext) { [string]$def.installContext } else { 'system' }
            deviceRestartBehavior = if ($def.restartBehavior) { [string]$def.restartBehavior } else { 'basedOnReturnCode' }
            maxRunTimeInMinutes   = if ($def.maxRunTimeInMinutes) { [int]$def.maxRunTimeInMinutes } else { 60 }
        }
        returnCodes                    = @($returnCodes)
        rules                          = @(New-DetectionRules -App $App -Msi $Msi)
    }
    if ($def.developer) { $body.developer = [string]$def.developer }
    if ($App.IsMsi -and $Msi) {
        $packageType = switch ($Msi.ExecutionContext) { 'User' { 'perUser' } 'Any' { 'dualPurpose' } default { 'perMachine' } }
        $body.msiInformation = @{
            productCode    = $Msi.ProductCode
            productVersion = $Msi.ProductVersion
            upgradeCode    = $Msi.UpgradeCode
            requiresReboot = $Msi.RequiresReboot
            packageType    = $packageType
            productName    = [string]$def.displayName
            publisher      = $Msi.Publisher
        }
    }
    $body
}

function Wait-ContentFileState {
    param([Parameter(Mandatory)][string]$FileUri, [Parameter(Mandatory)][string]$SuccessState, [int]$TimeoutSeconds = 300)
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
    param([Parameter(Mandatory)][string]$SasUri, [Parameter(Mandatory)][string]$FilePath)
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
    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>' + (($blockIds | ForEach-Object { "<Latest>$_</Latest>" }) -join '') + '</BlockList>'
    Invoke-RestMethod -Uri "$SasUri&comp=blocklist" -Method Put -Body $xml -ContentType 'application/xml' | Out-Null
}

function Publish-Win32App {
    param([Parameter(Mandatory)]$Pkg, [Parameter(Mandatory)]$Body)
    $info = $Pkg.Info

    Write-Step "Creating Win32 app '$($Body.displayName)' $($Body.displayVersion)"
    $app    = Invoke-Graph -Method POST -Uri "$GraphBase/deviceAppManagement/mobileApps" -Body $Body
    $appUri = "$GraphBase/deviceAppManagement/mobileApps/$($app.id)"

    $cv    = Invoke-Graph -Method POST -Uri "$appUri/microsoft.graph.win32LobApp/contentVersions" -Body @{}
    $cvUri = "$appUri/microsoft.graph.win32LobApp/contentVersions/$($cv.id)"

    $fileBody = [ordered]@{
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

    Invoke-Graph -Method PATCH -Uri $appUri -Body ([ordered]@{ '@odata.type' = '#microsoft.graph.win32LobApp'; committedContentVersion = [string]$cv.id }) | Out-Null
    Write-Step "Published '$($Body.displayName)' ($($app.id))"
    $app.id
}

function Set-AppAssignment {
    param([Parameter(Mandatory)][string]$AppId, [Parameter(Mandatory)][string]$GroupName, [string]$Intent = 'required', [string]$Notifications = 'showAll')
    $escaped = $GroupName.Replace("'", "''")
    $groups  = @(Get-GraphCollection -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$([uri]::EscapeDataString($escaped))'&`$select=id,displayName")
    if ($groups.Count -ne 1) { throw "Expected exactly one group named '$GroupName', found $($groups.Count)" }
    Write-Step "Assigning as $Intent to '$GroupName'"
    Invoke-Graph -Method POST -Uri "$GraphBase/deviceAppManagement/mobileApps/$AppId/assign" -Body @{
        mobileAppAssignments = @(
            [ordered]@{
                '@odata.type' = '#microsoft.graph.mobileAppAssignment'
                intent        = $Intent
                target        = [ordered]@{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $groups[0].id }
                settings      = [ordered]@{
                    '@odata.type'                = '#microsoft.graph.win32LobAppAssignmentSettings'
                    notifications                = $Notifications
                    deliveryOptimizationPriority = 'notConfigured'
                    installTimeSettings          = $null
                    restartSettings              = $null
                }
            }
        )
    } | Out-Null
}

#endregion

#region Main ---------------------------------------------------------------------

# 1. App folders
if ($All) {
    if (-not (Test-Path $Root)) { throw "Root folder not found: $Root" }
    $folders = @(Get-ChildItem -Path $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'app.json') } | ForEach-Object { $_.FullName })
    if ($folders.Count -eq 0) { throw "No subfolder of $Root contains an app.json." }
    $baseRoot = $Root
}
else {
    $folders = @($Path | ForEach-Object { (Resolve-Path $_).Path })
    $baseRoot = Split-Path $folders[0] -Parent
}
if (-not $OutputRoot) { $OutputRoot = Join-Path $baseRoot 'Intune' }

$apps = @($folders | ForEach-Object { Read-AppDefinition -Folder $_ })
Write-Step "App folders: $(($apps | ForEach-Object { $_.Name }) -join ', ')"

# 2. Package (no sign-in needed yet)
$tool = Get-IntuneWinAppUtil -WorkFolder (Join-Path $OutputRoot '_tools')
$work = foreach ($a in $apps) {
    $pkg  = New-IntuneWinPackage -App $a -Tool $tool -OutFolder $OutputRoot
    $msi  = Get-MsiData -App $a -Pkg $pkg
    if (@($a.Def.detection | Where-Object { $_.type -eq 'msi' }).Count -gt 0 -and -not $msi.ProductCode) {
        throw "$($a.Name): detection 'msi' but no MSI product code found."
    }
    [pscustomobject]@{ App = $a; Pkg = $pkg; Body = (New-AppBody -App $a -Pkg $pkg -Msi $msi) }
}

if ($PackageOnly) {
    foreach ($w in $work) {
        Write-Host ''
        Write-Host "=== $($w.App.Name): $($w.Pkg.IntuneWinFile.FullName)" -ForegroundColor Green
        $w.Body | ConvertTo-Json -Depth 10 | Write-Host
        Remove-Item $w.Pkg.ExtractFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ''
    Write-Host 'PackageOnly: nothing was changed in Intune.' -ForegroundColor Yellow
    return
}

# 3. Sign in
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Step 'Installing Microsoft.Graph.Authentication (CurrentUser)'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
$needGroups = $AssignmentGroupName -or @($apps | Where-Object { $_.Def.assignment -and $_.Def.assignment.group }).Count -gt 0
$scopes = @('DeviceManagementApps.ReadWrite.All')
if ($needGroups) { $scopes += 'Group.Read.All' }
$connectParams = @{ Scopes = $scopes; NoWelcome = $true }
if ($TenantId) { $connectParams.TenantId = $TenantId }
Connect-MgGraph @connectParams
$ctx = Get-MgContext
if (-not $ctx -or -not $ctx.TenantId) { throw 'Not connected to Microsoft Graph.' }
Write-Step "Signed in as $($ctx.Account) - tenant $($ctx.TenantId)"
if (-not $SkipTenantConfirmation) {
    $answer = Read-Host "Create $($apps.Count) app(s) in tenant $($ctx.TenantId) as $($ctx.Account)? [y/N]"
    if ($answer -notmatch '^(y|yes)$') { Write-Warning 'Aborted.'; return }
}

# 4. Upload and assign
$existingApps = @(Get-GraphCollection -Uri "$GraphBase/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')&`$select=id,displayName,displayVersion")
$results = foreach ($w in $work) {
    $name = $w.Body.displayName; $ver = $w.Body.displayVersion
    $dupe = $existingApps | Where-Object { $_.displayName -eq $name -and "$($_.displayVersion)" -eq "$ver" } | Select-Object -First 1
    try {
        if ($dupe -and -not $Force) {
            Write-Warning "'$name' $ver already exists ($($dupe.id)) - skipped. Use -Force to create it again."
            [pscustomobject]@{ App = $w.App.Name; DisplayName = $name; Version = $ver; AppId = $dupe.id; Result = 'Skipped (exists)'; AssignedTo = $null }
            continue
        }
        $id = Publish-Win32App -Pkg $w.Pkg -Body $w.Body

        $group  = if ($AssignmentGroupName) { $AssignmentGroupName } elseif ($w.App.Def.assignment) { [string]$w.App.Def.assignment.group } else { $null }
        if ($group) {
            $intent = if ($w.App.Def.assignment.intent) { [string]$w.App.Def.assignment.intent } else { 'required' }
            $notif  = if ($w.App.Def.assignment.notifications) { [string]$w.App.Def.assignment.notifications } else { 'showAll' }
            Set-AppAssignment -AppId $id -GroupName $group -Intent $intent -Notifications $notif
        }
        [pscustomobject]@{ App = $w.App.Name; DisplayName = $name; Version = $ver; AppId = $id; Result = 'Created'; AssignedTo = $group }
    }
    catch {
        Write-Warning "$($w.App.Name): $($_.Exception.Message)"
        [pscustomobject]@{ App = $w.App.Name; DisplayName = $name; Version = $ver; AppId = $null; Result = "Failed: $($_.Exception.Message)"; AssignedTo = $null }
    }
    finally {
        Remove-Item $w.Pkg.ExtractFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
$results | Format-Table App, DisplayName, Version, Result, AssignedTo -AutoSize | Out-Host
$results

#endregion
