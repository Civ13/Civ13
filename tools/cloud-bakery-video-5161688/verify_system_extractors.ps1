param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or $env:GITHUB_RUN_ATTEMPT -ne '1') {
    throw 'hosted_run_binding_required'
}
$binding = [ordered]@{}
foreach ($name in @('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_REF')) {
    $binding[$name] = [Environment]::GetEnvironmentVariable($name)
    if (-not $binding[$name]) { throw 'missing_run_binding' }
}
$result = [ordered]@{ status='FAILED'; binding=$binding; files=[ordered]@{}; failure=$null }
$out = Join-Path $Root 'system-extractors.json'
try {
    foreach ($name in @('tar.exe','expand.exe')) {
        $path = Join-Path (Join-Path $env:SystemRoot 'System32') $name
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 33554432) {
            throw 'unsafe_system_extractor'
        }
        $signature = Get-AuthenticodeSignature -LiteralPath $path
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '^CN=Microsoft Windows,') {
            throw 'system_extractor_signature_invalid'
        }
        $result.files[$name] = [ordered]@{ sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();
                                          bytes=$item.Length; version=$item.VersionInfo.FileVersion;
                                          signature='Valid'; signer='Microsoft Windows' }
    }
    $result.status = 'PASSED'
} catch {
    $message = $_.Exception.Message
    $result.failure = if ($message -match '^[a-z_]{1,80}$') { $message } else { $_.Exception.GetType().Name }
    throw
} finally {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($result | ConvertTo-Json -Depth 5 -Compress))
    if ($bytes.Length -gt 16384) { throw 'system_extractor_receipt_oversize' }
    $stream = [IO.File]::Open($out, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
