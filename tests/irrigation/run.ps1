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
$source = Read-Production 'code/modules/1713/trench.dm'
$procs = @(
    (Read-Proc $source '/turf/floor/proc/irrigate'),
    (Read-Proc $source '/turf/floor/check_relatives'),
    (Read-Proc $source '/turf/floor/proc/expand_flood')
)
$production = $procs -join "`n`n"
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-irrigation-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'icons/turf') -Force | Out-Null
$process = $null
try {
    [IO.File]::WriteAllText((Join-Path $temp 'production.dm'), $production)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    Copy-Item -LiteralPath (Join-Path $repo 'icons/turf/trench.dmi') -Destination (Join-Path $temp 'icons/turf/trench.dmi')
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
    $process = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @((Join-Path $temp 'probe.dmb'), '-invisible', '-trusted', '-log', 'runtime.log') -WorkingDirectory $temp -PassThru @processOptions
    if (!$process.WaitForExit(15000)) { throw 'Irrigation fixture exceeded 15 seconds' }
    $log = Get-Content -LiteralPath (Join-Path $temp 'runtime.log') -Raw
    $log | Write-Output
    if ($process.ExitCode -ne 0 -or $log -match 'runtime error:|FAIL ' -or $log -notmatch 'PASS irrigation') { throw 'Irrigation regression failed' }
} finally {
    if ($process -and !$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    Remove-Item -LiteralPath $temp -Recurse -Force
}

