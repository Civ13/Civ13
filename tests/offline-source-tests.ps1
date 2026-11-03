param([Parameter(Mandatory=$true)][string] $FixtureRoot)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if (-not (Test-Path -LiteralPath $FixtureRoot -PathType Container)) { throw 'fixture_root_missing' }
$item=Get-Item -LiteralPath $FixtureRoot
if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or @(Get-ChildItem -LiteralPath $FixtureRoot -Force).Count -ne 0) { throw 'fixture_root_invalid' }
$tool=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\custody-fixture'
. (Join-Path $tool 'runtime-checks.ps1')
. (Join-Path $tool 'evidence-copy.ps1')
$good=Get-PublisherIdentity ([Security.Cryptography.X509Certificates.X500DistinguishedName]::new('CN=.NET,O=Microsoft Corporation,C=US'))
Assert-PublisherIdentity $good 'dotnet'
$good=Get-PublisherIdentity ([Security.Cryptography.X509Certificates.X500DistinguishedName]::new('CN=Python Software Foundation,O=Python Software Foundation,C=US'))
Assert-PublisherIdentity $good 'python'
foreach($dn in @('CN=Microsoft impostor,O=Example Ltd,C=US','CN=.NET,O=Evil Microsoft Corporation,C=US','CN=.NET,CN=.NET,O=Microsoft Corporation,C=US')) {
    $rejected=$false
    try{$v=Get-PublisherIdentity ([Security.Cryptography.X509Certificates.X500DistinguishedName]::new($dn));Assert-PublisherIdentity $v 'dotnet'}catch{$rejected=$true}
    if(-not $rejected){throw 'publisher_negative_control_failed'}
}
$src=Join-Path $FixtureRoot 'source.bin';$dst=Join-Path $FixtureRoot 'copy.bin';$big=Join-Path $FixtureRoot 'oversized.bin';$reject=Join-Path $FixtureRoot 'rejected.bin'
[IO.File]::WriteAllBytes($src,[byte[]](0,1,2,255))
if (-not (Copy-BoundedEvidence $src $dst 4)) { throw 'exact_copy_missing' }
if (([Convert]::ToHexString([IO.File]::ReadAllBytes($dst))) -cne '000102FF') { throw 'copy_mismatch' }
if (Copy-BoundedEvidence (Join-Path $FixtureRoot 'missing.bin') $reject 4) { throw 'missing_not_false' }
[IO.File]::WriteAllBytes($big,[byte[]]::new(4097))
$rejected=$false;try{[void](Copy-BoundedEvidence $big $reject 4096)}catch{$rejected=$true}
if (-not $rejected -or (Test-Path -LiteralPath $reject)) { throw 'oversized_not_refused' }
$rejected=$false;try{[void](Copy-BoundedEvidence $src $dst 4)}catch{$rejected=$true}
if (-not $rejected -or ([Convert]::ToHexString([IO.File]::ReadAllBytes($dst))) -cne '000102FF') { throw 'overwrite_not_refused' }
Write-Output 'Publisher identity: 2 positive, 3 spoof/duplicate negatives passed. Bounded evidence: 4 cases passed.'

# Check actual checkout bytes, including a CRLF negative control, without native processes.
$snapshot=Join-Path $tool 'snapshot'
$manifest=Get-Content -LiteralPath (Join-Path $snapshot 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
if ($manifest.schema -ne 1 -or $manifest.files.Count -ne 10) { throw 'snapshot_manifest_invalid' }
foreach($entry in $manifest.files.GetEnumerator()) {
    if ($entry.Key -cnotmatch '^[A-Za-z0-9_./-]{1,160}$' -or $entry.Key.Contains('..') -or $entry.Value -cnotmatch '^[0-9a-f]{64}$') { throw 'snapshot_manifest_entry_invalid' }
    $member=Join-Path $snapshot $entry.Key
    if (-not (Test-Path -LiteralPath $member -PathType Leaf) -or (Get-Item -LiteralPath $member).Length -gt 1048576) { throw 'snapshot_member_unavailable' }
    if ((Get-FileHash -LiteralPath $member -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.Value) { throw ('snapshot_checkout_hash_mismatch:'+$entry.Key) }
}
$coordinator=[IO.File]::ReadAllBytes((Join-Path $snapshot 'coordinator.py'))
$text=[Text.Encoding]::UTF8.GetString($coordinator)
if ($text.Contains("`r`n") -or -not $text.Contains("`n")) { throw 'snapshot_coordinator_not_lf' }
$crlf=[Text.Encoding]::UTF8.GetBytes($text.Replace("`n","`r`n"))
$negative=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($crlf)).ToLowerInvariant()
if ($crlf.Length -ne 11158 -or $negative -cne '91ab6eaa550ecd7d621c2af8487ed6c7b6cb5fc1cabc08671073a8e41bf17a57' -or $negative -ceq $manifest.files['coordinator.py']) { throw 'snapshot_crlf_negative_failed' }
Write-Output 'Snapshot checkout: 10 raw-byte hashes and CRLF negative control passed.'
