[CmdletBinding()]
param(
    [string]$InstallerSource,
    [string]$PackageVersion,
    [string[]]$WixArguments = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'Build the Windows MSI on Windows.' }
$projectRoot = $PSScriptRoot
$portableExecutable = Join-Path $projectRoot 'LelSploit_portable.exe'
$outputPath = Join-Path $projectRoot 'LelSploit_installer.msi'
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('LelSploit-msi-' + [guid]::NewGuid().ToString('N'))
$preparedSource = $null
if (-not (Test-Path -LiteralPath $portableExecutable -PathType Leaf)) { throw 'LelSploit_portable.exe was not found. Run build.ps1 first.' }
$wixCommand = Get-Command wix.exe -ErrorAction SilentlyContinue
if (-not $wixCommand) { $wixCommand = Get-Command wix -ErrorAction SilentlyContinue }
if (-not $wixCommand) { throw 'WiX Toolset 4 or newer was not found on PATH.' }

if (-not $InstallerSource) {
    $InstallerSource = Join-Path $projectRoot 'installer.wxs'
    if (-not (Test-Path -LiteralPath $InstallerSource -PathType Leaf)) { $InstallerSource = Join-Path $projectRoot 'installer-template.wxs' }
}
$InstallerSource = (Resolve-Path -LiteralPath $InstallerSource).ProviderPath
if (-not $PackageVersion) {
    $versionMatch = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectRoot 'main.pyw') -Raw), 'APP_VERSION\s*=\s*["'']([0-9]+\.[0-9]+\.[0-9]+)["'']')
    if (-not $versionMatch.Success) { throw 'Could not read APP_VERSION from main.pyw. Pass -PackageVersion MAJOR.MINOR.PATCH.' }
    $PackageVersion = $versionMatch.Groups[1].Value
}
if ($PackageVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'The MSI version must be MAJOR.MINOR.PATCH.' }
$versionParts = $PackageVersion.Split('.') | ForEach-Object { [int]$_ }
if ($versionParts[0] -gt 255 -or $versionParts[1] -gt 255 -or $versionParts[2] -gt 65535) { throw 'MSI version limits are 255.255.65535.' }

Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.XmlResolver = $null
    $document.Load($InstallerSource)
    if ($document.DocumentElement.NamespaceURI -ne 'http://wixtoolset.org/schemas/v4/wxs') { throw 'The installer must use WiX 4+ authoring (schemas/v4/wxs). Convert a WiX 3 definition before building.' }
    # Preserve the existing UpgradeCode, component IDs, shortcuts, and metadata.
    # Only redirect old executable input paths in this temporary build copy.
    foreach ($file in $document.SelectNodes('//*[local-name()="File" and @Source]')) {
        $originalSource = $file.GetAttribute('Source')
        $leaf = [IO.Path]::GetFileName($originalSource.Replace('/', '\'))
        if ($leaf -in @('LelSploit.exe', 'LelSploit_portable.exe')) {
            $file.SetAttribute('Source', $portableExecutable)
            if (-not $file.HasAttribute('Name')) { $file.SetAttribute('Name', $leaf) }
        }
    }
    $package = $document.SelectSingleNode('/*[local-name()="Wix"]/*[local-name()="Package"]')
    if ($null -eq $package) { throw 'No Package element was found in the installer definition.' }
    $package.SetAttribute('Version', $PackageVersion)
    # Keep include paths and $(sys.SOURCEFILEDIR) relative to the original.
    $preparedSource = Join-Path (Split-Path -Parent $InstallerSource) ('lelsploit-installer-' + [guid]::NewGuid().ToString('N') + '.wxs')
    $document.Save($preparedSource)
    $temporaryOutput = Join-Path $temporaryDirectory 'LelSploit_installer.msi'
    $wixParameters = @('build', '-arch', 'x64', $preparedSource,
        '-d', "PortableExe=$portableExecutable", '-d', "ProductVersion=$PackageVersion",
        '-d', "AppIcon=$(Join-Path $projectRoot 'icon.ico')",
        '-bindpath', $projectRoot, '-bindpath', (Split-Path -Parent $InstallerSource),
        '-i', $projectRoot, '-i', (Split-Path -Parent $InstallerSource),
        '-intermediateFolder', (Join-Path $temporaryDirectory 'obj'), '-o', $temporaryOutput)
    $wixParameters += $WixArguments
    Write-Host "Building LelSploit_installer.msi from $([IO.Path]::GetFileName($InstallerSource))..."
    & $wixCommand.Source @wixParameters
    if ($LASTEXITCODE -ne 0) { throw "WiX build failed with exit code $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath $temporaryOutput -PathType Leaf)) { throw 'WiX finished without producing the MSI.' }
    Copy-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
    Write-Host "Built $outputPath"
} finally {
    Pop-Location
    if ($preparedSource -and (Test-Path -LiteralPath $preparedSource)) { Remove-Item -LiteralPath $preparedSource -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $temporaryDirectory) { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue }
}
