[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot 'LelSploit_portable.exe'),
    [string]$CertificateThumbprint,
    [string]$TimestampServer
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'Authenticode signing requires Windows.' }
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Signing input was not found: $Path. Build it first." }
$targetPath = (Resolve-Path -LiteralPath $Path).ProviderPath
if ([IO.Path]::GetExtension($targetPath) -notin @('.exe', '.msi')) { throw 'Choose an EXE or MSI file to sign.' }

$certificate = $null
if ($CertificateThumbprint) {
    $CertificateThumbprint = $CertificateThumbprint.Replace(' ', '')
    $certificate = Get-Item -LiteralPath "Cert:\CurrentUser\My\$CertificateThumbprint"
} else {
    $certificate = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert |
        Where-Object { $_.Subject -eq 'CN=LelSploit' -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date).AddDays(1) -and $_.NotBefore -le (Get-Date) } |
        Sort-Object NotAfter -Descending | Select-Object -First 1
    if (-not $certificate) {
        $certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=LelSploit' -CertStoreLocation 'Cert:\CurrentUser\My' -HashAlgorithm SHA256
    }
}
if (-not $certificate.HasPrivateKey -or $certificate.NotAfter -le (Get-Date) -or $certificate.NotBefore -gt (Get-Date)) { throw 'The certificate needs a usable private key and must be currently valid.' }

$signingParameters = @{ FilePath = $targetPath; Certificate = $certificate; HashAlgorithm = 'SHA256'; ErrorAction = 'Stop' }
if ($TimestampServer) { $signingParameters.TimestampServer = $TimestampServer }
$signature = Set-AuthenticodeSignature @signingParameters
if (-not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) { throw "No matching signature was written: $($signature.StatusMessage)" }
if ($signature.Status -notin @('Valid', 'NotTrusted')) { throw "Signature verification failed: $($signature.Status) - $($signature.StatusMessage)" }
Write-Host "Signed $([IO.Path]::GetFileName($targetPath)) as LelSploit. Status: $($signature.Status)."
if ($signature.Status -eq 'NotTrusted') { Write-Host 'The signature is present, but the certificate is not trusted by this computer. Self-signed certificates do not establish public publisher trust.' }
