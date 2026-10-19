param([Parameter(Mandatory)][string]$ByondBin, [switch]$NegativeControl,
    [switch]$ClickFeedback, [switch]$OriginalSilence, [string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
if ($OriginalSilence -and !$ClickFeedback) { throw 'OriginalSilence requires ClickFeedback.' }
if ($ClickFeedback -and $NegativeControl) { throw 'ClickFeedback uses its separate OriginalSilence control.' }
if ($ClickFeedback -and !$EvidenceDirectory) { throw 'ClickFeedback requires a fresh external EvidenceDirectory.' }
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$prefix = if ($ClickFeedback) { '.active_training_click' } else { '.active_training_' + [guid]::NewGuid().ToString('N') }
$extensions = @('.dme','_world.dm','_globals.dm','_training.dm','.dmb','.rsc')
if ($ClickFeedback) {
    $extensions += '_fixture.dm'
    foreach ($extension in $extensions) {
        if (Test-Path -LiteralPath (Join-Path $repo ($prefix + $extension))) { throw 'Preserve existing ClickFeedback source/binary files.' }
    }
    $evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
    $sourceRoot = [IO.Path]::GetFullPath($repo).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($evidence.StartsWith($sourceRoot, [StringComparison]::OrdinalIgnoreCase) -or $evidence.TrimEnd([IO.Path]::DirectorySeparatorChar) -eq $sourceRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Evidence must stay outside the source checkout.' }
    if ((Test-Path -LiteralPath $evidence) -and (Get-ChildItem -LiteralPath $evidence -Force | Select-Object -First 1)) { throw 'Preserve existing evidence; use an empty directory.' }
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-training-game-' + [guid]::NewGuid())
$runtime = $null
$options = @{}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $options.WindowStyle = 'Hidden' }
$compilerName = if ($options.Count) { 'dm.exe' } else { 'DreamMaker' }
$daemonName = if ($options.Count) { 'dd.exe' } else { 'DreamDaemon' }
if ($ClickFeedback) {
    $pythonCommand = if ($options.Count) { (Get-Command py).Source } else { '/usr/bin/python3' }
    [string[]]$pythonArguments = if ($options.Count) { @('-3','-B') } else { @('-B') }
}

# Used only by the explicit ClickFeedback path. The old accelerated mode below
# retains its existing invocation and result contract.
function Invoke-ClickProcess($Executable, $Arguments, $Directory, $Phase, $DeadlineSeconds) {
    $native = $null
    $timedOut = $false
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $native = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $Directory -PassThru @options -RedirectStandardOutput (Join-Path $temporary "$Phase-stdout.log") -RedirectStandardError (Join-Path $temporary "$Phase-stderr.log")
        if (!$native.WaitForExit($DeadlineSeconds * 1000)) {
            $timedOut = $true
            $native.Kill()
            if (!$native.WaitForExit(10000)) { throw 'Owned fixture process did not exit after termination.' }
        }
        return $native.ExitCode
    } finally {
        if ($native -and !$native.HasExited) {
            $native.Kill()
            if (!$native.WaitForExit(10000)) { throw 'Owned fixture process survived cleanup.' }
        }
        $watch.Stop()
        $code = if ($native -and $native.HasExited) { $native.ExitCode } else { $null }
        @{returncode=$code;timed_out=$timedOut;wall_seconds=$watch.Elapsed.TotalSeconds;deadline_seconds=$DeadlineSeconds} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temporary "$Phase-status.json") -Encoding utf8
        if ($native) { $native.Dispose() }
    }
}
New-Item -ItemType Directory -Path $temporary | Out-Null
Push-Location -LiteralPath $repo
try {
    $commit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Source revision unavailable' }
    if ($ClickFeedback) {
        $prepareArguments = @('tests/active_training/prepare_click.py','--output',(Join-Path $temporary 'prepared'))
        if ($OriginalSilence) { $prepareArguments += '--original-silence' }
        & $pythonCommand @pythonArguments @prepareArguments
        if ($LASTEXITCODE -ne 0) { throw 'ClickFeedback source preparation failed.' }
        $metadata = Get-Content -LiteralPath (Join-Path $temporary 'prepared/metadata.json') -Raw | ConvertFrom-Json
        Copy-Item -LiteralPath (Join-Path $temporary 'prepared/metadata.json') -Destination (Join-Path $temporary 'metadata.json')
        foreach ($entry in $metadata.inputs_sha256.PSObject.Properties) {
            if ((Get-FileHash -LiteralPath (Join-Path $repo $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) { throw 'Prepared input changed before materialization.' }
        }
        foreach ($entry in $metadata.generated_sha256.PSObject.Properties) {
            if ($entry.Name -notin ($extensions | ForEach-Object { $prefix + $_ })) { throw 'Unexpected generated source name.' }
            $overlay = Join-Path $temporary ('prepared/overlay/' + $entry.Name)
            if ((Get-FileHash -LiteralPath $overlay -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) { throw 'Prepared source hash changed.' }
            Copy-Item -LiteralPath $overlay -Destination (Join-Path $repo $entry.Name)
        }
    } else {
    $world = Get-Content -LiteralPath 'code/world.dm' -Raw
    $world = $world.Replace('/world/New()', '/world/proc/unused_active_training_startup()')
    $offset = $world.IndexOf('/world/proc/unused_active_training_startup()')
    $world = [regex]::new('(?m)^\t\.\.\(\)\r?$').Replace($world, '', 1, $offset)
    $world = $world.Replace('/datum/global_init/New()', "/datum/global_init/New()`n`treturn")
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_world.dm')), $world)
    $globals = Get-Content -LiteralPath 'code/controllers/mc/globals.dm' -Raw
    $globals = $globals.Replace('/datum/controller/global_vars/New()', "/datum/controller/global_vars/New()`n`tGLOB = src`n`treturn")
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_globals.dm')), $globals)
    $trainingSource = Get-Content -LiteralPath 'code/modules/1713/active_training.dm' -Raw
    $trainingSource = $trainingSource.Replace('return world.time', 'return training_fixture_time')
    if ($NegativeControl) {
        $guard = 'if (!success || !eligible(H) || H.loc != start || !anchored || !isturf(loc) || exercise_time() >= expiry)'
        if (!$trainingSource.Contains($guard)) { throw 'Negative-control guard unavailable' }
        $trainingSource = $trainingSource.Replace($guard, 'if (!success || !start)')
    }
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_training.dm')), $trainingSource)
    $source = Get-Content -LiteralPath 'civ13.dme' -Raw
    $source = $source.Replace('code\world.dm', $prefix + '_world.dm').Replace('code\controllers\mc\globals.dm', $prefix + '_globals.dm')
    $source = $source.Replace('code\modules\1713\active_training.dm', $prefix + '_training.dm')
    $source = [regex]::Replace($source, '(?m)^#include ".*\.dmm"\s*$', '')
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '.dme')), $source + "`n#include `"tests/active_training/game.dm`"`n")
    }
    if ($ClickFeedback) {
        $compileExit = Invoke-ClickProcess (Join-Path $ByondBin $compilerName) @('-max_errors','0',($prefix + '.dme')) $repo 'compile' 180
        $build = (Get-Content -LiteralPath (Join-Path $temporary 'compile-stdout.log') -Raw) + (Get-Content -LiteralPath (Join-Path $temporary 'compile-stderr.log') -Raw)
        $build | Set-Content -LiteralPath (Join-Path $temporary 'compile.log') -Encoding utf8
        Write-Output $build
        $compileStatus = Get-Content -LiteralPath (Join-Path $temporary 'compile-status.json') -Raw | ConvertFrom-Json
        if ($compileExit -ne 0 -or $compileStatus.timed_out -or $compileStatus.wall_seconds -ge 180 -or $build -notmatch '\bDM compiler version 516\.1681\b' -or $build -notmatch '(?<!\d)0 errors, 0 warnings\b') { throw 'ClickFeedback pinned warning-free compilation failed.' }
    } else {
    $build = & (Join-Path $ByondBin $compilerName) -max_errors 0 ($prefix + '.dme') 2>&1
    $build | Tee-Object -FilePath (Join-Path $temporary 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings' -or ($build -join "`n") -notmatch '516\.1681') { throw 'Pinned full-source fixture compile failed' }
    }
    foreach ($extension in @('.dmb','.rsc')) { Copy-Item -LiteralPath ($prefix + $extension) -Destination (Join-Path $temporary ('probe' + $extension)) }
    Copy-Item -LiteralPath 'config' -Destination $temporary -Recurse
    if ($ClickFeedback) {
        $runtimeExit = Invoke-ClickProcess (Join-Path $ByondBin $daemonName) @('probe.dmb','0','-invisible','-close','-trusted','-params',"tested_commit=$commit",'-log','runtime.log') $temporary 'runtime' 100
        $verifyArguments = @('tests/active_training/verify_click.py','--evidence',$temporary,'--expected-commit',$commit)
        if ($OriginalSilence) { $verifyArguments += '--original-silence' }
        & $pythonCommand @pythonArguments @verifyArguments
        if ($LASTEXITCODE -ne 0) { throw 'ClickFeedback exact causal result verification failed.' }
    } else {
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-trusted', '-params', "tested_commit=$commit", '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @options
    if (!$runtime.WaitForExit(60000)) { throw 'Unique active training fixture timed out' }
    $log = Get-Content -LiteralPath (Join-Path $temporary 'runtime.log') -Raw
    Write-Output $log
    $result = Get-Content -LiteralPath (Join-Path $temporary 'result.json') -Raw | ConvertFrom-Json
    $result | ConvertTo-Json -Compress
    if ($runtime.ExitCode -ne 0 -or $result.commit -ne $commit -or $result.byond_build -ne 1681 -or $log -match 'runtime error|Bad ref') { throw 'Native exercise diagnostics invalid' }
    if ($NegativeControl) {
        if ($result.failures -lt 1 -or $log -notmatch 'FAIL: move rejects XP and releases claim' -or $log -notmatch 'FAIL: death rejects XP and releases claim') { throw 'Missing post-wait authorization was not detected' }
        Write-Output 'PASS negative control: omitted post-wait guards detected'
    } elseif ($result.failures -ne 0 -or $log -match 'FAIL:') { throw 'Native exercise/save contracts failed' }
    }
} finally {
    try {
    if ($ClickFeedback) {
        foreach ($name in @('metadata.json','compile.log','compile-stdout.log','compile-stderr.log','compile-status.json','runtime.log','runtime-stdout.log','runtime-stderr.log','runtime-status.json','result.json','verification.json')) {
            $sourceEvidence = Join-Path $temporary $name
            if (Test-Path -LiteralPath $sourceEvidence -PathType Leaf) { Copy-Item -LiteralPath $sourceEvidence -Destination (Join-Path $evidence $name) }
        }
    }
    } finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    foreach ($extension in $extensions) {
        $target = Join-Path $repo ($prefix + $extension)
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    $resolved = [IO.Path]::GetFullPath($temporary)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary fixture path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    Pop-Location
    }
}
