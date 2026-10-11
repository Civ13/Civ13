param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateRange(1,60)][int]$TimeoutSeconds = 15,
    [string]$Revision,
    [switch]$Baseline,
    [switch]$Unchecked
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-train-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
$process = $null
try {
    if ($Revision) {
        $source = (git -C $repo show ($Revision + ':code/modules/1713/trains.dm')) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read source revision' }
    } else { $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'code/modules/1713/trains.dm') }
    $source = $source.Replace("`r`n", "`n")
    $start = $source.IndexOf('/obj/structure/trains' + "`n")
    $end = $source.IndexOf('/obj/structure/trains/storage')
    if ($start -lt 0 -or $end -le $start) { throw 'Train source boundaries not found' }
    $slice = $source.Substring($start, $end-$start) -replace "icon = 'icons/obj/vehicles/trains.dmi'", 'icon = null'
    $slice = $slice -replace "'sound/[^']+'", 'null'
    Set-Content -LiteralPath (Join-Path $temp 'production.dm') -Value $slice
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    $includes = @('#define DEBUG','#include "fixture.dm"','#include "production.dm"')
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
    Write-Output "Process exit: $($process.ExitCode); limit: $limit; PID: $($process.Id); CPU seconds: $($process.TotalProcessorTime.TotalSeconds); peak bytes: $($process.PeakWorkingSet64)"
    if ($Baseline -and $Unchecked) {
        Write-Output 'Unchecked baseline: inspect exit code, limit and log; no assumed failure classification.'
    } elseif ($Baseline) {
        if ($runtime -notmatch 'Maximum recursion level reached' -or $runtime -notmatch 'START cyclic connection Move') { throw 'Expected baseline recursion not reproduced' }
        Write-Output 'Confirmed baseline maximum-recursion runtime; this does not prove a native crash.'
    } elseif ($limit -or $process.ExitCode -ne 0 -or $runtime -match 'runtime error:|FAIL ' -or $runtime -notmatch 'RESULT failures=0') {
        throw 'Train regression probe failed'
    }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    Write-Output "Probe artifacts: $temp"
}
