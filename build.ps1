[CmdletBinding()]
param(
    [Alias('Python')]
    # Change this path if Python is installed somewhere else.
    [string]$PythonExecutable = 'C:\Users\leo\AppData\Local\Programs\Python\Python313\python.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:OS -ne 'Windows_NT') { throw 'The portable release must be built on 64-bit Windows.' }

$projectRoot = $PSScriptRoot
$apiDirectory = Join-Path $projectRoot 'api'
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('LelSploit-build-' + [guid]::NewGuid().ToString('N'))
$portableOutput = Join-Path $projectRoot 'LelSploit_portable.exe'
if (-not (Test-Path -LiteralPath $PythonExecutable -PathType Leaf)) {
    throw "Python was not found at '$PythonExecutable'. Please change the Python directory in build.ps1: edit the `$PythonExecutable path at the top of the script to point to your python.exe."
}

Push-Location $projectRoot
try {
    & $PythonExecutable -c "import os,struct,sys; sys.exit(0 if os.name == 'nt' and struct.calcsize('P') == 8 and sys.version_info >= (3,11) else 1)"
    if ($LASTEXITCODE -ne 0) { throw 'Use Python 3.11 or newer, 64-bit, on Windows.' }
    & $PythonExecutable -c 'import nuitka, PyQt6.Qsci, cryptography, certifi, zstandard'
    if ($LASTEXITCODE -ne 0) { throw "Missing dependencies. Open PowerShell and run: & `"$PythonExecutable`" -m pip install -r `"$(Join-Path $projectRoot 'requirements.txt')`"" }

    foreach ($relative in @('main.pyw', 'icon.ico', 'api\__init__.py', 'api\lelsploit_api.py')) {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relative) -PathType Leaf)) { throw "Missing project file: $relative" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'icons') -PathType Container)) { throw 'Missing icons folder. Keep your existing application assets.' }

    $nativeNames = @('libls.dll', 'libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'xxhash.dll', 'zstd.dll', 'd3d9.dll', 'D3DX9_43.dll')
    # Resolve all input files before moving any old-layout files.
    $nativeFiles = @()
    foreach ($name in $nativeNames) {
        $source = $null
        foreach ($directory in @($apiDirectory, $projectRoot, (Join-Path $projectRoot 'dlls'), (Join-Path $projectRoot 'bin'))) {
            $candidate = Join-Path $directory $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $source = $candidate; break }
        }
        if (-not $source) { throw "Missing native DLL: api\$name. Supply your existing x64 DLL; this build does not download DLLs." }
        $nativeFiles += [pscustomobject]@{ Source = $source; Target = (Join-Path $apiDirectory $name) }
    }
    New-Item -ItemType Directory -Path $apiDirectory -Force | Out-Null
    foreach ($native in $nativeFiles) {
        if ([IO.Path]::GetFullPath($native.Source) -ne [IO.Path]::GetFullPath($native.Target)) {
            Write-Host "Moving $([IO.Path]::GetFileName($native.Source)) into api..."
            Move-Item -LiteralPath $native.Source -Destination $native.Target
        }
    }
    # Reuse the same PE/x64 checks as the application before packaging.
    & $PythonExecutable -c 'from api.lelsploit_api import REQUIRED_FILES, RUNTIME_DIR, _validate_x64_dll; [_validate_x64_dll(RUNTIME_DIR / name) for name in REQUIRED_FILES]'
    if ($LASTEXITCODE -ne 0) { throw 'Native DLL validation failed. Supply valid Windows x64 DLLs.' }

    $versionMatch = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectRoot 'main.pyw') -Raw), 'APP_VERSION\s*=\s*["'']([0-9]+\.[0-9]+\.[0-9]+)["'']')
    if (-not $versionMatch.Success) { throw 'main.pyw must declare APP_VERSION as MAJOR.MINOR.PATCH.' }
    $applicationVersion = $versionMatch.Groups[1].Value
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    $payloadPath = Join-Path $temporaryDirectory 'lelsploit_dll_payload.zip'
    Compress-Archive -LiteralPath @($nativeFiles | ForEach-Object { $_.Target }) -DestinationPath $payloadPath -Force

    $nuitkaArguments = @(
        '-m', 'nuitka', 'main.pyw',
        '--mode=onefile',
        '--msvc=latest',
        '--enable-plugin=pyqt6',
        '--windows-console-mode=disable',
        '--output-filename=LelSploit_portable.exe',
        "--output-dir=$temporaryDirectory",
        '--windows-icon-from-ico=icon.ico',
        '--product-name=LelSploit',
        '--file-description=LelSploit',
        "--product-version=$applicationVersion",
        "--file-version=$applicationVersion.0",
        '--include-package=api',
        '--include-module=lelsploit_deobfuscate',
        '--include-module=lelsploit_source_tools',
        "--include-data-files=$payloadPath=api/lelsploit_dll_payload.zip",
        '--include-data-files=icon.ico=icon.ico',
        '--include-data-dir=icons=icons',
        '--remove-output'
    )
    foreach ($optionalFile in @('ui_config.json', 'API-Dump.json')) {
        if (Test-Path -LiteralPath (Join-Path $projectRoot $optionalFile) -PathType Leaf) { $nuitkaArguments += "--include-data-files=$optionalFile=$optionalFile" }
    }
    if (Test-Path -LiteralPath (Join-Path $projectRoot 'images') -PathType Container) { $nuitkaArguments += '--include-data-dir=images=images' }

    Write-Host "Building LelSploit_portable.exe (v$applicationVersion)..."
    & $PythonExecutable @nuitkaArguments
    if ($LASTEXITCODE -ne 0) { throw "Nuitka build failed with exit code $LASTEXITCODE" }
    $compiledExecutable = Join-Path $temporaryDirectory 'LelSploit_portable.exe'
    if (-not (Test-Path -LiteralPath $compiledExecutable -PathType Leaf)) { throw 'Nuitka finished without producing LelSploit_portable.exe.' }
    Copy-Item -LiteralPath $compiledExecutable -Destination $portableOutput -Force
    Write-Host "Built $portableOutput"
} finally {
    Pop-Location
    if (Test-Path -LiteralPath $temporaryDirectory) { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue }
}
