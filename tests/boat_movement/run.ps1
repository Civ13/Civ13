param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateRange(1,60)][int]$TimeoutSeconds = 15,
    [string]$Revision,
    [switch]$Baseline
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-boat-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
$sourceRef = if ($Revision) { $Revision } else { 'HEAD' }
$tested = git -C $repo rev-parse $sourceRef
$dirty = if (!$Revision) { [bool](git -C $repo status --porcelain -- code/game/objects/effects/autoassembler.dm code/modules/1713/machinery/modular_vehicles tests/boat_movement) } else { $false }
Write-Output "Working source dirty: $dirty"
Write-Output "Boat source revision: $tested; OS: $([Environment]::OSVersion); fixture: 40x40x1 water world"
$process = $null
try {
    function Read-Source([string]$path) {
        if ($Revision) {
            $content = (git -C $repo show ($Revision + ':' + $path)) -join "`n"
            if ($LASTEXITCODE -ne 0) { throw 'Cannot read source revision' }
        } else { $content = Get-Content -Raw -LiteralPath (Join-Path $repo $path) }
        return $content.Replace("`r`n", "`n")
    }
    function Slice([string]$content, [string]$first, [string]$last) {
        $start = $content.IndexOf($first)
        if ($start -lt 0) { throw 'Production source start not found' }
        $end = $content.IndexOf($last, $start)
        if ($start -lt 0 -or $end -le $start) { throw 'Production source boundaries not found' }
        return $content.Substring($start, $end-$start)
    }
    $axis = Read-Source 'code/modules/1713/machinery/modular_vehicles/axis.dm'
    $ship = Read-Source 'code/modules/1713/machinery/modular_vehicles/ships/axis.dm'
    $assembler = Read-Source 'code/game/objects/effects/autoassembler.dm'
    $wheel = Read-Source 'code/modules/1713/machinery/modular_vehicles/ships/wheels.dm'
    $config = Read-Source 'code/modules/1713/machinery/modular_vehicles/_config.dm'
    $slices = @(
        (Slice $axis '/obj/structure/vehicleparts/axis/proc/do_move()' '/obj/structure/vehicleparts/axis/MouseDrop('),
        (Slice $axis '/obj/structure/vehicleparts/axis/proc/check_matrix()' ("`n/obj/effect/pseudovehicle`n")),
        (Slice $ship '/obj/structure/vehicleparts/axis/ship/add_transporting(' '//basically, a matrix'),
        $config.Substring($config.IndexOf('var/global/list/rotation_matrixes1')),
        (Slice $axis '/obj/structure/vehicleparts/axis/MouseDrop(' '//basically, a matrix'),
        (Slice $wheel '/obj/structure/vehicleparts/shipwheel/proc/turndir(' '/obj/structure/vehicleparts/shipwheel/attack_hand('),
        ($assembler -replace "'icons/[^']+'", 'null'),
        (Slice $ship '/obj/structure/vehicleparts/axis/ship/movementloop()' '/obj/structure/vehicleparts/axis/ship/check_engine()')
    )
    Set-Content -LiteralPath (Join-Path $temp 'production.dm') -Value (($slices -join "`n") -replace "'sound/[^']+'", 'null')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    $includes = @('#include "fixture.dm"','#include "production.dm"')
    if ($Baseline) { $includes = @('#define BASELINE') + $includes }
    Set-Content -LiteralPath (Join-Path $temp 'probe.dme') -Value $includes
    $compiler = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemon = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    & (Join-Path $ByondBin $compiler) (Join-Path $temp 'probe.dme') 2>&1 | Tee-Object -FilePath (Join-Path $temp 'compile.log')
    if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed' }
    $log = Join-Path $temp 'runtime.log'
    $security = '-trusted'
    $launch = @{
        FilePath = Join-Path $ByondBin $daemon
        ArgumentList = @(('"' + (Join-Path $temp 'probe.dmb') + '"'), '-invisible', $security, '-log', 'runtime.log')
        WorkingDirectory = $temp
        PassThru = $true
    }
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $limit = $null
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) { $limit = 'wall timeout'; break }
        if ($process.WorkingSet64 -gt 256MB) { $limit = '256 MiB working set'; break }
        if ($process.TotalProcessorTime.TotalSeconds -gt 5) { $limit = '5 CPU seconds'; break }
    }
    if ($limit) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    $runtime = Get-Content -Raw -LiteralPath $log
    ($runtime -split "`n" | Where-Object { $_ -match '^(FAIL|RESULT)|runtime error:|^CRUSH' }) | Write-Output
    Write-Output ("Assertions passed: " + ([regex]::Matches($runtime, '(?m)^PASS ')).Count)
    Write-Output "Process exit: $($process.ExitCode); limit: $limit; PID: $($process.Id)"
    if ($Baseline) {
        if ($limit -or $process.ExitCode -ne 0 -or $runtime -match 'runtime error:' -or $runtime -notmatch 'RESULT failures=') { throw 'Baseline did not complete cleanly' }
        if ($runtime -notmatch 'FAIL object outside deck stays put' -or $runtime -notmatch 'PASS rectangular quarter turn') { throw 'Expected baseline boat failure not reproduced' }
        Write-Output 'Confirmed baseline moves an object outside the deck.'
    } elseif ($limit -or $process.ExitCode -ne 0 -or $runtime -match 'runtime error:|FAIL ' -or $runtime -notmatch 'RESULT failures=0') {
        throw 'Boat regression probe failed'
    }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    Write-Output "Probe artifacts: $temp"
}
