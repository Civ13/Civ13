param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [int]$Width = 50,
    [int]$Height = 50,
    [int]$Cycles = 20
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Get-Content -LiteralPath (Join-Path $repo 'code/game/turfs/flooring/flooring_premade.dm') -Raw
function Read-Proc([string]$name) {
    $pattern = '(?m)^' + [regex]::Escape($name) + '\(\)[\s\S]*?(?=^/|\z)'
    $match = [regex]::Match($source, $pattern)
    if (!$match.Success) { throw "Missing production proc: $name" }
    return $match.Value.TrimEnd()
}
# Execute production bodies; only shorten the 20-minute wait and count accepted wakes.
$recovery = Read-Proc '/turf/floor/dirt/proc/soil_nutrition_recover'
$recovery = $recovery.Replace('rand(12000,12010)', '5')
$recovery = $recovery.Replace('if(soil_nutrition < max_soil_nutrition)', "global.recoveries++`n`t`tif(soil_nutrition < max_soil_nutrition)")
$procs = @(
    (Read-Proc '/turf/floor/grass/New'),
    (Read-Proc '/turf/floor/grass/Del'),
    (Read-Proc '/turf/floor/dirt/New'),
    (Read-Proc '/turf/floor/dirt/Del'),
    $recovery
) -join "`n`n"
$harness = @"
var/list/grass_turf_list = list()
/datum/soil_recovery_token
var/global/recoveries = 0
/turf/floor/dirt
    var/datum/soil_recovery_token/soil_recovery_token
    var/soil_nutrition = 0
    var/max_soil_nutrition = 150
/obj/structure/farming/plant
/turf/floor/dirt/winter
/turf/floor/grass
    var/grass_registry_index = 0
/turf/floor/grass/jungle
$procs
/world
    maxx = $Width
    maxy = $Height
    fps = 10
/world/New()
    sleep(10)
    world.log << "BASELINE tiles=[world.maxx * world.maxy]"
    for (var/cycle = 1 to $Cycles)
        for (var/turf/T in world)
            new /turf/floor/grass(T)
        if (grass_turf_list.len != world.maxx * world.maxy)
            world.log << "FAIL grass count cycle=[cycle] count=[grass_turf_list.len]"
            del(world)
        for (var/turf/T in world)
            new /turf/floor/grass/jungle(T)
        if (grass_turf_list.len != world.maxx * world.maxy)
            world.log << "FAIL grass subtype count=[grass_turf_list.len]"
            del(world)
        for (var/turf/T in world)
            new /turf/floor/dirt(T)
            new /turf/floor/dirt/winter(T)
        if (grass_turf_list.len)
            world.log << "FAIL non-grass registry count=[grass_turf_list.len]"
            del(world)
        sleep(1)
    // Wait for obsolete chains to wake and stop, then count one recovery wave.
    var/turf/floor/dirt/planted = locate(1,1,1)
    new /obj/structure/farming/plant(planted)
    planted.soil_nutrition = 0
    sleep(6)
    var/before = recoveries
    sleep(5)
    if (recoveries - before != world.maxx * world.maxy)
        world.log << "FAIL duplicate recovery chains delta=[recoveries-before] expected=[world.maxx*world.maxy]"
        del(world)
    var/turf/floor/dirt/D = locate(2,1,1)
    if (D.soil_nutrition <= 0 || D.soil_nutrition > D.max_soil_nutrition)
        world.log << "FAIL soil recovery nutrition=[D.soil_nutrition]"
        del(world)
    if (planted.soil_nutrition != 0)
        world.log << "FAIL planted soil recovered"
        del(world)
    world.log << "POST cycles=$Cycles registry=[grass_turf_list.len] recovery_wave=[recoveries-before]"
    sleep(10)
    world.log << "PASS season memory regression"
    del(world)
"@
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('civ13-season-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDir | Out-Null
$dm = Join-Path $testDir 'season_memory.dm'
[IO.File]::WriteAllText($dm, $harness)
$compile = & (Join-Path $ByondBin 'dm.exe') $dm 2>&1
$compile | Write-Output
if ($LASTEXITCODE -ne 0 -or ($compile -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Harness compilation failed' }
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $testDir 'season_memory.dmb'), '-invisible', '-trusted', '-logself', '-close') -WindowStyle Hidden -PassThru
$samples = @()
$deadline = (Get-Date).AddSeconds(120)
while (!$daemon.HasExited) {
    if ((Get-Date) -gt $deadline) { $daemon.Kill(); throw 'Offline harness exceeded 120 seconds' }
    $daemon.Refresh()
    if (!$daemon.HasExited) { $samples += [pscustomobject]@{Time=(Get-Date).ToString('o');PrivateBytes=$daemon.PrivateMemorySize64;WorkingSet=$daemon.WorkingSet64} }
    Start-Sleep -Milliseconds 100
}
$logPath = Join-Path $testDir 'season_memory.log'
if (!(Test-Path -LiteralPath $logPath)) { throw "DreamDaemon exited with code $($daemon.ExitCode) without a log. Evidence: $testDir" }
$log = Get-Content -LiteralPath $logPath -Raw
$log | Write-Output
$samples | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $testDir 'memory.csv')
Write-Output "Evidence: $testDir"
if ($samples.Count) { Write-Output "Synthetic private bytes: first=$($samples[0].PrivateBytes) peak=$(($samples | Measure-Object PrivateBytes -Maximum).Maximum) last=$($samples[-1].PrivateBytes)" }
if ($log -notmatch 'PASS season memory regression' -or $log -match 'FAIL|runtime error') { throw 'Offline regression failed' }
