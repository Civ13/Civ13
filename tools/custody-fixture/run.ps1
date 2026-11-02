$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Join-Path ([IO.Path]::GetFullPath($env:RUNNER_TEMP)) 'civ13-custody'
. (Join-Path $root 'runtime-checks.ps1')
. (Join-Path $root 'evidence-copy.ps1')
$runtimeFile=Join-Path $root 'runtime.json'
if ((Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash.ToLowerInvariant() -cne $env:CUSTODY_RUNTIME_SHA256) { throw 'runtime_manifest_changed' }
$runtime=Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
$build=Get-Content -LiteralPath (Join-Path $root 'build.json') -Raw | ConvertFrom-Json
if ($build.runtime_manifest_sha256 -cne $env:CUSTODY_RUNTIME_SHA256 -or $runtime.image_os -cne $env:ImageOS -or $runtime.image_version -cne $env:ImageVersion -or $runtime.run_id -cne $env:GITHUB_RUN_ID -or $runtime.run_attempt -cne $env:GITHUB_RUN_ATTEMPT -or $runtime.commit -cne $env:GITHUB_SHA) { throw 'runtime_binding_changed' }
$expectedPaths=@('C:\hostedtoolcache\windows\Python\3.12.10\x64\python.exe','C:\hostedtoolcache\windows\Python\3.12.10\x64\python312.dll','C:\hostedtoolcache\windows\Python\3.12.10\x64\python3.dll','C:\Program Files\dotnet\dotnet.exe')
if (@($runtime.files).Count -ne 4) { throw 'runtime_file_count' }
for($i=0;$i -lt 4;$i++) {
    if ($runtime.files[$i].path -cne $expectedPaths[$i] -or $runtime.files[$i].publisher -cne $(if($i -eq 3){'dotnet'}else{'python'})) { throw 'runtime_file_binding' }
    Assert-RuntimeMatches $runtime.files[$i]
}
Push-Location $root
try {
    $sdk=@(& $runtime.dotnet --version)
    if ($LASTEXITCODE -ne 0 -or $sdk.Count -ne 1 -or $sdk[0] -cne '8.0.427' -or $sdk[0] -cne $runtime.dotnet_sdk) { throw 'dotnet_sdk_mismatch' }
} finally { Pop-Location }
foreach($record in $runtime.files) { Assert-RuntimeMatches $record }
$outer=Join-Path $root 'outer\bin\Release\net8.0\Outer.dll'
$inner=Join-Path $root 'watchdog\bin\Release\net8.0\CustodyWatchdog.dll'
$manifest=Join-Path $root 'snapshot\manifest.json'
foreach($entry in @(@($outer,$build.outer_sha256),@($inner,$build.inner_sha256),@($manifest,$build.snapshot_manifest_sha256))) {
    if ((Get-FileHash -LiteralPath $entry[0] -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry[1]) { throw 'built_source_changed' }
}
$runs=Join-Path $root 'runs'
New-Item -ItemType Directory -Path $runs -ErrorAction Stop | Out-Null
$scratch=Join-Path $runs ('run-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$runtime.dotnet;$start.WorkingDirectory=$scratch;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
$start.Environment.Clear()
foreach($pair in @(@('SystemRoot',$env:SystemRoot),@('WINDIR',$env:WINDIR),@('PATH',[IO.Path]::GetDirectoryName($runtime.dotnet)),@('RUNNER_TEMP',$env:RUNNER_TEMP),@('TEMP',$scratch),@('TMP',$scratch),@('DOTNET_CLI_HOME',$root),@('DOTNET_NOLOGO','1'),@('DOTNET_CLI_TELEMETRY_OPTOUT','1'),@('DOTNET_SKIP_FIRST_TIME_EXPERIENCE','1'))) { $start.Environment[$pair[0]]=$pair[1] }
foreach($arg in @($outer,$scratch,$inner,$build.inner_sha256,$build.snapshot_manifest_sha256,$env:CUSTODY_RUNTIME_SHA256)) { $start.ArgumentList.Add([string]$arg) }
$proc=[Diagnostics.Process]::new();$proc.StartInfo=$start
$state='not_started';$started=$false;$reaped=$false;$exitCode=$null;$copyFailures=[Collections.Generic.List[string]]::new();$copied=[Collections.Generic.List[string]]::new()
try {
    $state='outer_start_unknown'
    if (-not $proc.Start()) { throw 'outer_start_unknown' }
    $started=$true;$state='running'
    $retainedHandle=$proc.Handle
    if ($retainedHandle -eq [IntPtr]::Zero) { throw 'outer_handle_unavailable' }
    if (-not $proc.WaitForExit(75000)) {
        $state='timeout_cleanup_inconclusive'
        try { $proc.Kill(); $reaped=$proc.WaitForExit(10000) } catch { $reaped=$false }
        throw 'outer_timeout_cleanup_inconclusive'
    }
    $reaped=$true;$exitCode=$proc.ExitCode
    foreach($name in @('outer-result.json','watchdog-result.json','coordinator-result.json')) {
        $p=Join-Path $scratch $name
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw 'required_receipt_missing' }
        if ((Get-Item -LiteralPath $p).Length -gt 16384) { throw 'receipt_oversized' }
    }
    $receipt=Get-Content -LiteralPath (Join-Path $scratch 'outer-result.json') -Raw | ConvertFrom-Json
    if ($exitCode -ne 0 -or $receipt.result -ne 0 -or -not $receipt.query -or $receipt.active -ne 0 -or $receipt.forced -or $receipt.timeout -or $receipt.cleanup_uncertain) { throw 'outer_receipt_not_pass' }
    $state='passed'
} catch {
    if ($state -ne 'timeout_cleanup_inconclusive' -and $state -ne 'outer_start_unknown') { if ($started -and -not $reaped) { $state='process_custody_uncertain' } else { $state='failed' } }
    throw
} finally {
    try {
        $evidence=Join-Path $root 'evidence'
        foreach($name in @('outer-result.json','watchdog-result.json','coordinator-result.json')) {
            $p=Join-Path $scratch $name
            try {
                $limit=if($name -eq 'coordinator-result.json'){16384}else{4096}
                if (Copy-BoundedEvidence $p (Join-Path $evidence $name) $limit) { $copied.Add($name) }
                elseif ($state -eq 'passed') { $copyFailures.Add($name) }
            } catch { $copyFailures.Add($name) }
        }
        $successBeforeCopy=($state -eq 'passed')
        if($successBeforeCopy -and $copyFailures.Count -gt 0){$state='evidence_incomplete'}
        $status=[ordered]@{schema=1;state=$state;started=$started;outer_reaped=$reaped;outer_exit=$exitCode;copied=$copied.ToArray();copy_failures=$copyFailures.ToArray();possibly_partial=($state -ne 'passed')}
        try {
            $bytes=[Text.Encoding]::UTF8.GetBytes(($status | ConvertTo-Json -Compress))
            if($bytes.Length -gt 4096){throw 'runner_status_oversized'}
            [IO.File]::WriteAllBytes((Join-Path $evidence 'runner-status.json'),$bytes)
        } catch { $copyFailures.Add('runner-status.json') }
        if($successBeforeCopy -and $copyFailures.Count -gt 0){throw 'evidence_preservation_failed'}
    } finally { $proc.Dispose() }
}
