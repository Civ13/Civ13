param([Parameter(Mandatory=$true)][string]$ByondBin, [string]$Revision, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($Revision) {
    $source = (git -C $repo show ($Revision + ':code/game/objects/farming.dm')) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read production revision' }
} else { $source = Get-Content -LiteralPath (Join-Path $repo 'code/game/objects/farming.dm') -Raw }
$source = $source.Replace("`r`n", "`n")
$names = @('readyHarvest','growth','stageGrowth','soil_nutrition_proc','set_dead','water_proc')
# Historical revisions predate the shared stage boundary; retain baseline support.
if ($source -match '(?m)^/obj/structure/farming/plant/proc/advance_stage_if_allowed\(') {
    $names += 'advance_stage_if_allowed'
}
$procs = foreach ($name in $names) {
    $match = [regex]::Match($source, '(?m)^/obj/structure/farming/plant/proc/' + $name + '\([^\n]*\)[^\n]*\n[\s\S]*?(?=^/obj/|\z)')
    if (!$match.Success) { throw "Missing production proc $name" }
    $match.Value.TrimEnd()
}
# Accelerate only the 600-tick wait; count actual entries into the production growth body.
$production = ($procs -join "`n`n").Replace('spawn(600)', 'spawn(2)').Replace('/proc/growth()' + "`n", '/proc/growth()' + "`n`tglobal.growth_calls++`n")
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-plants-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$process = $null
try {
    [IO.File]::WriteAllText((Join-Path $temp 'production.dm'), $production)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    $includes = @('#include "fixture.dm"','#include "production.dm"')
    if ($Baseline) { $includes = @('#define BASELINE') + $includes }
    Set-Content -LiteralPath (Join-Path $temp 'probe.dme') -Value $includes
    $compilerName = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemonName = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    $compile = & (Join-Path $ByondBin $compilerName) (Join-Path $temp 'probe.dme') 2>&1
    $compile | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($compile -join "`n") -notmatch '(?m)^DM compiler version 516\.1681\r?$' -or ($compile -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Fixture compilation failed' }
    $processOptions = @{}; if ($IsWindows) { $processOptions.WindowStyle = 'Hidden' }
    $process = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @((Join-Path $temp 'probe.dmb'), '-invisible', '-trusted', '-log', 'runtime.log') -WorkingDirectory $temp -PassThru @processOptions
    if (!$process.WaitForExit(15000)) { throw 'Plant fixture exceeded 15 seconds' }
    $log = Get-Content -LiteralPath (Join-Path $temp 'runtime.log') -Raw
    $log | Write-Output
    if ($process.ExitCode -ne 0 -or $log -match 'runtime error:|FAIL ' -or $log -notmatch 'PASS plant lifecycle') { throw 'Plant lifecycle regression failed' }
} finally {
    if ($process -and !$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    # Only this run's uniquely named temporary directory is removed.
    Remove-Item -LiteralPath $temp -Recurse -Force
}
