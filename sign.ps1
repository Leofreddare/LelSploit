$exe = Join-Path $PSScriptRoot "LelSploit.exe"

if (-not (Test-Path $exe)) {
    Write-Error "LelSploit.exe was not found in $PSScriptRoot"
    exit 1
}

$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=LelSploit" `
    -CertStoreLocation "Cert:\CurrentUser\My"

Set-AuthenticodeSignature `
    -FilePath $exe `
    -Certificate $cert `
    -HashAlgorithm SHA256

Write-Host "Signed LelSploit.exe as LelSploit."