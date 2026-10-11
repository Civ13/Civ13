param([Parameter(Mandatory=$true)][string]$ByondBin)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Get-Content -LiteralPath (Join-Path $repo 'code/game/turfs/floor_types.dm') -Raw
function Read-Proc([string]$name) {
    $match = [regex]::Match($source, '(?m)^' + [regex]::Escape($name) + '\(\)[\s\S]*?(?=^/|\z)')
    if (!$match.Success) { return '' }
    return $match.Value.TrimEnd()
}
$procs = (Read-Proc '/turf/floor/beach/water/New') + "`n" + (Read-Proc '/turf/floor/beach/water/Del')
$harness = @"
var/list/water_turf_list = list()
/turf/floor/beach/water
    var/water_registry_index = 0
/turf/floor/beach/water/deep
/turf/floor/beach/drywater
$procs
/world
    maxx = 50
    maxy = 50
/world/New()
    for (var/cycle = 1 to 20)
        for (var/turf/T in world)
            new /turf/floor/beach/water(T)
            new /turf/floor/beach/water/deep(T)
        if (water_turf_list.len != 2500)
            world.log << "FAIL water count cycle=[cycle] count=[water_turf_list.len] expected=2500"
            del(world)
            return
        // Remove interleaved entries to exercise swapped indexes, not only tail removal.
        for (var/turf/T in world)
            if (T.x % 2)
                new /turf/floor/beach/drywater(T)
        if (water_turf_list.len != 1250)
            world.log << "FAIL partial removal count=[water_turf_list.len]"
            del(world)
            return
        for (var/i = 1 to water_turf_list.len)
            var/turf/floor/beach/water/W = water_turf_list[i]
            if (!istype(W) || W.water_registry_index != i)
                world.log << "FAIL wrong registry type/index at [i]"
                del(world)
                return
        for (var/turf/T in world)
            new /turf/floor/beach/drywater(T)
        if (water_turf_list.len)
            world.log << "FAIL dry registry count=[water_turf_list.len]"
            del(world)
            return
    world.log << "PASS water registry: 20 cycles, subtype replacement and interleaved removal"
    del(world)
    return
"@
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('civ13-water-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDir | Out-Null
$dm = Join-Path $testDir 'water_memory.dm'
[IO.File]::WriteAllText($dm, $harness)
$compile = & (Join-Path $ByondBin 'dm.exe') $dm 2>&1
$compile | Write-Output
if ($LASTEXITCODE -ne 0 -or ($compile -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Harness compilation failed' }
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $testDir 'water_memory.dmb'), '-invisible', '-trusted', '-logself', '-close') -WindowStyle Hidden -PassThru
if (!$daemon.WaitForExit(60000)) { $daemon.Kill(); throw "Offline harness exceeded 60 seconds. Evidence: $testDir" }
$logPath = Join-Path $testDir 'water_memory.log'
if (!(Test-Path -LiteralPath $logPath)) { throw "Daemon exit=$($daemon.ExitCode); missing log. Evidence: $testDir" }
$log = Get-Content -LiteralPath $logPath -Raw
$log | Write-Output
Write-Output "Evidence: $testDir"
if ($log -notmatch 'PASS water registry' -or $log -match 'FAIL|runtime error') { throw 'Water regression failed' }
