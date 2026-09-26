$ErrorActionPreference = 'Stop'

$python = 'C:\Users\leo\AppData\Local\Programs\Python\Python313\python.exe'

$payload = Join-Path $env:TEMP (
    'lelsploit_dll_payload_' + [guid]::NewGuid().ToString('N') + '.zip'
)

$dlls = @(
    '.\libls.dll'
    '.\libcrypto-3-x64.dll'
    '.\libssl-3-x64.dll'
    '.\xxhash.dll'
    '.\zstd.dll'
    '.\d3d9.dll'
    '.\D3DX9_43.dll'
)

try {
    Write-Host 'Creating temporary DLL payload...'

    Compress-Archive `
        -Path $dlls `
        -DestinationPath $payload `
        -Force

    Write-Host 'Building LelSploit.exe...'

    & $python -m nuitka main.pyw `
        --mode=onefile `
        --msvc=latest `
        --enable-plugin=pyqt6 `
        --windows-console-mode=disable `
        --output-filename=LelSploit.exe `
        --windows-icon-from-ico=icon.ico `
        "--include-data-files=$payload=lelsploit_dll_payload.zip" `
        --include-data-files=icon.ico=icon.ico `
        --include-data-files=ui_config.json=ui_config.json `
        --include-data-dir=icons=icons `
        --remove-output

    if ($LASTEXITCODE -ne 0) {
        throw "Nuitka build failed with exit code $LASTEXITCODE"
    }

    Write-Host 'Built LelSploit.exe successfully.'
}
finally {
    if (Test-Path -LiteralPath $payload) {
        Remove-Item -LiteralPath $payload -Force -ErrorAction SilentlyContinue
    }
}