param([Parameter(Mandatory=$true)][string]$ByondBin, [string]$Revision, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
function Read-Production([string]$Path) {
    if ($Revision) {
        $result = (git -C $repo show ($Revision + ':' + $Path)) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Cannot read $Revision : $Path" }
        return $result
    }
    return (Get-Content -LiteralPath (Join-Path $repo $Path) -Raw).Replace("`r`n", "`n")
}
function Read-Proc([string]$Source, [string]$Path) {
    $match = [regex]::Match($Source, '(?m)^' + [regex]::Escape($Path) + '\([^\n]*\)[^\n]*\n[\s\S]*?(?=^/obj/|^/turf/|\z)')
    if (!$match.Success) { throw "Missing production proc $Path" }
    return $match.Value.TrimEnd()
}
$farming = Read-Production 'code/game/objects/farming.dm'
$wild = Read-Production 'code/game/objects/structures/wild.dm'
$seedEnd = $farming.IndexOf('/obj/structure/farming/plant' + "`n")
if ($seedEnd -lt 0) { throw 'Missing seed catalog boundary' }
$seeds = $farming.Substring(0,$seedEnd)
$globals = $wild.Substring(0,$wild.IndexOf('/obj/structure/wild' + "`n"))
$procs = @(
    (Read-Proc $wild '/obj/structure/wild/proc/generate_seed_list'),
    (Read-Proc $wild '/obj/structure/wild/proc/pick_seed_by_biome'),
    (Read-Proc $wild '/obj/structure/wild/proc/pickseed'),
    (Read-Proc $farming '/obj/structure/farming/plant/proc/water_proc'),
    (Read-Proc $farming '/obj/structure/farming/plant/proc/set_dead')
)
# Observe the production dispatch argument without changing filtering or selection.
$production = ($procs -join "`n`n").Replace('/proc/pick_seed_by_biome(var/biome = "")' + "`n", '/proc/pick_seed_by_biome(var/biome = "")' + "`n`tglobal.selected_biome = biome`n")
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-outdoor-crops-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'icons/farming') -Force | Out-Null
$process = $null
try {
    [IO.File]::WriteAllText((Join-Path $temp 'production.dm'), $globals + "`n" + $seeds + "`n" + $production)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    Copy-Item -LiteralPath (Join-Path $repo 'icons/farming/seeds.dmi') -Destination (Join-Path $temp 'icons/farming/seeds.dmi')
    Copy-Item -LiteralPath (Join-Path $repo 'code/__defines/maps.dm') -Destination (Join-Path $temp 'maps.dm')
    $includes = @('#include "maps.dm"','#include "fixture.dm"','#include "production.dm"')
    if ($Baseline) { $includes = @('#define BASELINE') + $includes }
    Set-Content -LiteralPath (Join-Path $temp 'probe.dme') -Value $includes
    $compilerName = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemonName = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    $compile = & (Join-Path $ByondBin $compilerName) (Join-Path $temp 'probe.dme') 2>&1
    $compile | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($compile -join "`n") -notmatch '(?m)^DM compiler version 516\.1681\r?$' -or ($compile -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Fixture compilation failed' }
    $processOptions = @{}; if ($IsWindows) { $processOptions.WindowStyle = 'Hidden' }
    $process = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @((Join-Path $temp 'probe.dmb'), '-invisible', '-safe', '-log', 'runtime.log') -WorkingDirectory $temp -PassThru @processOptions
    if (!$process.WaitForExit(15000)) { throw 'Outdoor crop fixture exceeded 15 seconds' }
    $log = Get-Content -LiteralPath (Join-Path $temp 'runtime.log') -Raw
    $log | Write-Output
    if ($process.ExitCode -ne 0 -or $log -match 'runtime error:|FAIL ' -or $log -notmatch 'PASS outdoor crops') { throw 'Outdoor crop regression failed' }
} finally {
    if ($process -and !$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    Remove-Item -LiteralPath $temp -Recurse -Force
}
