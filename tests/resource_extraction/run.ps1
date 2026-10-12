param(
    [switch]$DiggingBaseline,
    [Parameter(Mandatory)][string]$ByondBin,
    [ValidateSet('tests/resource_extraction/probe.dm','tests/petroleum_lifecycle/probe.dm','tests/hydraulic_fracturing/probe.dm','tests/automated_sifting/probe.dm','tests/mining_yields/probe.dm','tests/resource_extraction/digging_probe.dm')]
    [string]$Probe = 'tests/resource_extraction/probe.dm'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$prefix = '.resource_probe_' + [guid]::NewGuid().ToString('N')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-resource-' + [guid]::NewGuid())
$runtime = $null
$options = @{}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $options.WindowStyle = 'Hidden' }
$compilerName = if ($options.Count) { 'dm.exe' } else { 'DreamMaker' }
$daemonName = if ($options.Count) { 'dd.exe' } else { 'DreamDaemon' }
New-Item -ItemType Directory -Path $temporary | Out-Null
Push-Location -LiteralPath $repo
try {
    $commit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source revision' }
    $dirty = git status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine dirty source state' }
    $world = Get-Content -LiteralPath 'code/world.dm' -Raw
    $world = $world.Replace('/world/New()', '/world/proc/unused_resource_startup()')
    $offset = $world.IndexOf('/world/proc/unused_resource_startup()')
    $world = [regex]::new('(?m)^\t\.\.\(\)\r?$').Replace($world, '', 1, $offset)
    $world = $world.Replace('/datum/global_init/New()', "/datum/global_init/New()`n`treturn")
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_world.dm')), $world)
    $globals = Get-Content -LiteralPath 'code/controllers/mc/globals.dm' -Raw
    $globals = $globals.Replace('/datum/controller/global_vars/New()', "/datum/controller/global_vars/New()`n`tGLOB = src`n`treturn")
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_globals.dm')), $globals)
    $source = Get-Content -LiteralPath 'civ13.dme' -Raw
    $source = $source.Replace('code\world.dm', $prefix + '_world.dm').Replace('code\controllers\mc\globals.dm', $prefix + '_globals.dm')
    $source = [regex]::Replace($source, '(?m)^#include ".*\.dmm"\s*$', '')
    if ($Probe -eq 'tests/resource_extraction/digging_probe.dm') {
        # Adapt only action waits; execute the complete production attackby body.
        $digging = Get-Content -LiteralPath 'code/game/turfs/floor_attackby.dm' -Raw
        if ($DiggingBaseline) {
            $digging = (git show 'aa675de6dbade0f3740c516dc4b5945c5c9a43c7:code/game/turfs/floor_attackby.dm') -join "`n"
            if ($LASTEXITCODE -ne 0) { throw 'Immutable digging baseline unavailable' }
        }
        $digging = $digging.Replace('do_after(', 'digging_probe_wait(')
        [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_mining.dm')), $digging)
        $source = $source.Replace('code\game\turfs\floor_attackby.dm', $prefix + '_mining.dm')
    }
    if ($Probe -eq 'tests/mining_yields/probe.dm') {
        # Only deterministic RNG calls in the production mining body are adapted.
        $mining = Get-Content -LiteralPath 'code/game/turfs/floor_attackby.dm' -Raw
        $begin = $mining.IndexOf('/turf/proc/mining_proc(')
        $end = $mining.IndexOf('/turf/floor/dirt/underground/attack_hand(', $begin)
        if ($begin -lt 0 -or $end -le $begin) { throw 'Mining adapter boundaries missing' }
        $body = $mining.Substring($begin, $end - $begin)
        $body = [regex]::Replace($body, '\bprob\(', 'yield_prob(')
        $body = [regex]::Replace($body, '\brand\(', 'yield_rand(')
        $body = $body.Replace('pick(1,2,3,4)', 'yield_pick()')
        $mining = $mining.Substring(0, $begin) + $body + $mining.Substring($end)
        [IO.File]::WriteAllText((Join-Path $repo ($prefix + '_mining.dm')), $mining)
        $source = $source.Replace('code\game\turfs\floor_attackby.dm', $prefix + '_mining.dm')
    }
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '.dme')), $source + "`n#include `"$Probe`"`n")
    $build = & (Join-Path $ByondBin $compilerName) -max_errors 0 ($prefix + '.dme') 2>&1
    $build | Tee-Object -FilePath (Join-Path $temporary 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings' -or ($build -join "`n") -notmatch '516\.1681') { throw 'Pinned probe compile failed' }
    foreach ($extension in @('.dmb','.rsc')) { Copy-Item -LiteralPath ($prefix + $extension) -Destination (Join-Path $temporary ('probe' + $extension)) }
    Copy-Item -LiteralPath 'config' -Destination $temporary -Recurse
    [IO.File]::WriteAllText((Join-Path $temporary 'source-state.txt'), "commit=$commit`ndirty=$dirty`ndigging_baseline=$DiggingBaseline")
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-safe', '-params', "tested_commit=$commit", '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @options
    if (!$runtime.WaitForExit(30000)) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit(); throw 'Task-owned probe timed out' }
    $result = Get-Content -LiteralPath (Join-Path $temporary 'result.json') -Raw | ConvertFrom-Json
    $runtimeLog = Get-Content -LiteralPath (Join-Path $temporary 'runtime.log') -Raw
    Write-Output $runtimeLog
    $result | ConvertTo-Json -Compress
    $failuresUnexpected = if ($DiggingBaseline) { $result.failures -eq 0 } else { $result.failures -ne 0 }
    if ($DiggingBaseline -and $Probe -ne 'tests/resource_extraction/digging_probe.dm') { throw 'Baseline is only supported for digging probe' }
    if ($runtime.ExitCode -ne 0 -or $failuresUnexpected -or $result.runtime_error -or $runtimeLog -match 'runtime error' -or $result.commit -ne $commit -or $result.byond_build -ne 1681) { throw 'Production-path extraction probe failed' }
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    foreach ($extension in @('.dme','_world.dm','_globals.dm','_mining.dm','.dmb','.rsc')) {
        $target = Join-Path $repo ($prefix + $extension)
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    Pop-Location
    Write-Output "Retained isolated evidence: $temporary"
}
