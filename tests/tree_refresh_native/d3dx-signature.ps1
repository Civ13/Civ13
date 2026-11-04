# Metadata-only WinTrust query. Never imports, registers or loads the target DLL.
param([Parameter(Mandatory=$true)][string]$LiteralFile)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
function CertificateFacts($Certificate) {
    if ($null -eq $Certificate) { return $null }
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = $hasher.ComputeHash($Certificate.RawData) }
    finally { $hasher.Dispose() }
    return @{
        subject = $Certificate.Subject
        issuer = $Certificate.Issuer
        simple_name = $Certificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        certificate_sha256 = ([System.BitConverter]::ToString($digest)).Replace('-','').ToLowerInvariant()
        not_before_utc = $Certificate.NotBefore.ToUniversalTime().ToString('o')
        not_after_utc = $Certificate.NotAfter.ToUniversalTime().ToString('o')
    }
}
# Existing OS validation only. No signing, trust-store or revocation-policy edits.
$signature = Get-AuthenticodeSignature -LiteralPath $LiteralFile
@{
    status = $signature.Status.ToString()
    signature_type = $signature.SignatureType.ToString()
    is_os_binary = $signature.IsOSBinary
    signer = CertificateFacts $signature.SignerCertificate
    timestamp = CertificateFacts $signature.TimeStamperCertificate
} | ConvertTo-Json -Depth 5 -Compress
