param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or $env:GITHUB_RUN_ATTEMPT -ne '1') {
    throw 'hosted_run_binding_required'
}
$binding = [ordered]@{}
foreach ($name in @('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_REF')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if (-not $value) { throw 'missing_run_binding' }
    $binding[$name] = $value
}
if ($binding.GITHUB_SHA -notmatch '^[0-9a-f]{40}$' -or $binding.GITHUB_RUN_ID -notmatch '^[0-9]+$' -or
    $binding.GITHUB_JOB -notmatch '^[A-Za-z0-9_-]{1,100}$') { throw 'bad_run_binding' }
$base = Join-Path $Root 'official-directx'
$rows = @(
    @{ name='directx_Jun2010_redist.exe'; path=(Join-Path $base 'directx_Jun2010_redist.exe'); sha='053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b'; signer='2485A7AFA98E178CB8F30C9838346B514AEA4769' },
    @{ name='DXSETUP.exe'; path=(Join-Path $base 'extracted/DXSETUP.exe'); sha='8f47d7121ef6532ad9ad9901e44e237f5c30448b752028c58a9d19521414e40d'; signer='93859EBF98AFDEB488CCFA263899640E81BC49F1' },
    @{ name='DSETUP.dll'; path=(Join-Path $base 'extracted/DSETUP.dll'); sha='2a61679eeedabf7d0d0ac14e5447486575622d6b7cfa56f136c1576ff96da21f'; signer='93859EBF98AFDEB488CCFA263899640E81BC49F1' },
    @{ name='dsetup32.dll'; path=(Join-Path $base 'extracted/dsetup32.dll'); sha='fb0e534f9b0926e518f1c2980640dfd29f14217cdfa37cf3a0c13349127ed9a8'; signer='93859EBF98AFDEB488CCFA263899640E81BC49F1' }
)
$hashes = [ordered]@{}
foreach ($row in $rows) {
    $item = Get-Item -LiteralPath $row.path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'non_plain_package_file' }
    $hash = (Get-FileHash -LiteralPath $row.path -Algorithm SHA256).Hash.ToLowerInvariant()
    $signature = Get-AuthenticodeSignature -LiteralPath $row.path
    if ($hash -ne $row.sha -or $signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.Thumbprint -ne $row.signer) { throw 'signature_or_hash_mismatch' }
    $hashes[$row.name] = $hash
}
$receipt = [ordered]@{ binding=$binding; sha256=$hashes; all_signatures_valid=$true } | ConvertTo-Json -Depth 4 -Compress
$out = Join-Path $base 'signature-receipt.json'
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($receipt)
if ($bytes.Length -gt 16384) { throw 'receipt_too_large' }
$stream = [IO.File]::Open($out, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
