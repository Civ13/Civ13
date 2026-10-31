param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or $env:GITHUB_RUN_ATTEMPT -ne '1' -or
    $env:GITHUB_REF -ne 'refs/heads/ci/cloud-bakery225-control-5161688-20261031-r1') {
    throw 'hosted_run_binding_required'
}
$binding = [ordered]@{}
foreach ($name in @('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_REF')) {
    $binding[$name] = [Environment]::GetEnvironmentVariable($name)
    if (-not $binding[$name]) { throw 'missing_run_binding' }
}
if ($binding.GITHUB_SHA -notmatch '^[0-9a-f]{40}$' -or $binding.GITHUB_RUN_ID -notmatch '^[1-9][0-9]*$' -or
    $binding.GITHUB_JOB -ne 'bakery') { throw 'bad_run_binding' }
$base = Join-Path $Root 'official-nuget/selected'
$rows = @(
    @{name='d3dx9_43.dll'; bytes=2001304; sha='2fea401698db2764ec5943de6634bf0eb5dbe191a963b1ef3620a027730b83e9'},
    @{name='d3dcompiler_43.dll'; bytes=2109336; sha='aaca0bac2e1e94966f4546b6234333f9cdc1a4599024e30cd20aef4c1fd1b4f1'}
)
$result = [ordered]@{status='FAILED';binding=$binding;files=[ordered]@{};failure=$null}
$out = Join-Path $Root 'nuget-signature-receipt.json'
try {
    foreach ($row in $rows) {
        $result['checking'] = $row.name
        $path = Join-Path $base $row.name
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $item.Length -ne $row.bytes) { throw 'unsafe_nuget_binary' }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $sig = Get-AuthenticodeSignature -LiteralPath $path
        if ($hash -ne $row.sha -or $sig.Status -ne 'Valid' -or
            $sig.SignerCertificate.Thumbprint -ne '2485A7AFA98E178CB8F30C9838346B514AEA4769') {
            throw 'nuget_signature_or_hash_mismatch'
        }
        $result.files[$row.name] = [ordered]@{bytes=$item.Length;sha256=$hash;signature='Valid';signer_thumbprint=$sig.SignerCertificate.Thumbprint}
    }
    $result.status = 'PASSED'
} catch {
    $message=$_.Exception.Message
    $result.failure=if ($message -match '^[a-z_]{1,80}$') { $message } else { $_.Exception.GetType().Name }
    throw
} finally {
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result | ConvertTo-Json -Depth 5 -Compress))
    if ($bytes.Length -gt 16384) { throw 'nuget_signature_receipt_oversize' }
    $stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
