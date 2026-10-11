param([Parameter(Mandatory)][string]$ByondBin)
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
    [IO.File]::WriteAllText((Join-Path $repo ($prefix + '.dme')), $source + "`n#include `"tests/resource_extraction/probe.dm`"`n")
    $build = & (Join-Path $ByondBin $compilerName) -max_errors 0 ($prefix + '.dme') 2>&1
    $build | Tee-Object -FilePath (Join-Path $temporary 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings' -or ($build -join "`n") -notmatch '516\.1681') { throw 'Pinned probe compile failed' }
    foreach ($extension in @('.dmb','.rsc')) { Copy-Item -LiteralPath ($prefix + $extension) -Destination (Join-Path $temporary ('probe' + $extension)) }
    Copy-Item -LiteralPath 'config' -Destination $temporary -Recurse
    [IO.File]::WriteAllText((Join-Path $temporary 'source-state.txt'), "commit=$commit`ndirty=$dirty")
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-safe', '-params', "tested_commit=$commit", '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @options
    if (!$runtime.WaitForExit(30000)) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit(); throw 'Task-owned probe timed out' }
    $result = Get-Content -LiteralPath (Join-Path $temporary 'result.json') -Raw | ConvertFrom-Json
    $runtimeLog = Get-Content -LiteralPath (Join-Path $temporary 'runtime.log') -Raw
    Write-Output $runtimeLog
    $result | ConvertTo-Json -Compress
    if ($runtime.ExitCode -ne 0 -or $result.failures -ne 0 -or $result.runtime_error -or $runtimeLog -match 'runtime error' -or $result.commit -ne $commit -or $result.byond_build -ne 1681) { throw 'Production-path extraction probe failed' }
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    foreach ($extension in @('.dme','_world.dm','_globals.dm','.dmb','.rsc')) {
        $target = Join-Path $repo ($prefix + $extension)
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    Pop-Location
    Write-Output "Retained isolated evidence: $temporary"
}
