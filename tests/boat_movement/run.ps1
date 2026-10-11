param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateRange(1,60)][int]$TimeoutSeconds = 15,
    [string]$Revision,
    [switch]$Baseline,
    [switch]$Unchecked
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-boat-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
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
        $end = $content.IndexOf($last, $start)
        if ($start -lt 0 -or $end -le $start) { throw 'Production source boundaries not found' }
        return $content.Substring($start, $end-$start)
    }
    $axis = Read-Source 'code/modules/1713/machinery/modular_vehicles/axis.dm'
    $ship = Read-Source 'code/modules/1713/machinery/modular_vehicles/ships/axis.dm'
    $config = Read-Source 'code/modules/1713/machinery/modular_vehicles/_config.dm'
    $slices = @(
        (Slice $axis '/obj/structure/vehicleparts/axis/proc/do_move()' '/obj/structure/vehicleparts/axis/proc/add_transporting()'),
        (Slice $axis '/obj/structure/vehicleparts/axis/proc/check_matrix()' '/obj/effect/pseudovehicle' ),
        (Slice $ship '/obj/structure/vehicleparts/axis/ship/add_transporting()' '//basically, a matrix'),
        $config.Substring($config.IndexOf('var/global/list/rotation_matrixes1'))
    )
    # check_corners references pseudovehicle before its definition: use the next top-level declaration.
    $start = $axis.IndexOf('/obj/structure/vehicleparts/axis/proc/check_matrix()')
    $end = $axis.IndexOf("`n/obj/effect/pseudovehicle`n", $start)
    $slices[1] = $axis.Substring($start, $end-$start)
    Set-Content -LiteralPath (Join-Path $temp 'production.dm') -Value ($slices -join "`n")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    $includes = @('#include "fixture.dm"','#include "production.dm"')
    if ($Baseline) { $includes = @('#define BASELINE') + $includes }
    if ($Unchecked) { $includes = @('#define UNCHECKED') + $includes }
    Set-Content -LiteralPath (Join-Path $temp 'probe.dme') -Value $includes
    & (Join-Path $ByondBin 'dm.exe') (Join-Path $temp 'probe.dme') 2>&1 | Tee-Object -FilePath (Join-Path $temp 'compile.log')
    if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed' }
    $log = Join-Path $temp 'runtime.log'
    $security = if ($Unchecked) { '-trusted' } else { '-safe' }
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temp 'probe.dmb'), '-invisible', $security, '-log', $log) -WorkingDirectory $temp -WindowStyle Hidden -PassThru
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
    $runtime | Write-Output
    Write-Output "Process exit: $($process.ExitCode); limit: $limit; PID: $($process.Id)"
    if ($Baseline -and $Unchecked) {
        Write-Output 'Unchecked baseline: inspect exit code, limit and log; no assumed failure classification.'
    } elseif ($Baseline) {
        if ($runtime -notmatch 'FAIL object outside deck stays put' -or $runtime -notmatch 'PASS rectangular quarter turn') { throw 'Expected baseline boat failure not reproduced' }
        Write-Output 'Confirmed baseline moves an object outside the deck.'
    } elseif ($limit -or $process.ExitCode -ne 0 -or $runtime -match 'runtime error:|FAIL ' -or $runtime -notmatch 'RESULT failures=0') {
        throw 'Boat regression probe failed'
    }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    Write-Output "Probe artifacts: $temp"
}



