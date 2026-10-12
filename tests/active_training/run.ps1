param([Parameter(Mandatory)][string]$ByondBin, [switch]$NegativeControl)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$prefix = '.active_training_' + [guid]::NewGuid().ToString('N')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-training-game-' + [guid]::NewGuid())
$runtime = $null
$options = @{}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $options.WindowStyle = 'Hidden' }
$compilerName = if ($options.Count) { 'dm.exe' } else { 'DreamMaker' }
$daemonName = if ($options.Count) { 'dd.exe' } else { 'DreamDaemon' }
New-Item -ItemType Directory -Path $temporary | Out-Null
Push-Location -LiteralPath $repo
try {
    $commit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Source revision unavailable' }
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
    $build = & (Join-Path $ByondBin $compilerName) -max_errors 0 ($prefix + '.dme') 2>&1
    $build | Tee-Object -FilePath (Join-Path $temporary 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings' -or ($build -join "`n") -notmatch '516\.1681') { throw 'Pinned full-source fixture compile failed' }
    foreach ($extension in @('.dmb','.rsc')) { Copy-Item -LiteralPath ($prefix + $extension) -Destination (Join-Path $temporary ('probe' + $extension)) }
    Copy-Item -LiteralPath 'config' -Destination $temporary -Recurse
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-safe', '-params', "tested_commit=$commit", '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @options
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
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    foreach ($extension in @('.dme','_world.dm','_globals.dm','_training.dm','.dmb','.rsc')) {
        $target = Join-Path $repo ($prefix + $extension)
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    $resolved = [IO.Path]::GetFullPath($temporary)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary fixture path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    Pop-Location
}
