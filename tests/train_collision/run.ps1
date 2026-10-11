param([string]$ByondBin = 'C:/Program Files (x86)/BYOND/bin', [int]$TimeoutSeconds = 15)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $repo -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-train-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'code/modules/1713/trains.dm')
    $start = $source.IndexOf('/obj/structure/trains' + "`n")
    if ($start -lt 0) { $start = $source.IndexOf('/obj/structure/trains' + "`r`n") }
    $end = $source.IndexOf('/obj/structure/trains/storage')
    $slice = $source.Substring($start, $end-$start) -replace "icon = 'icons/obj/vehicles/trains.dmi'", 'icon = null'
    $slice = $slice -replace "'sound/[^']+'", 'null'
    Set-Content -LiteralPath (Join-Path $temp 'production.dm') -Value $slice
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixture.dm') -Destination $temp
    Set-Content -LiteralPath (Join-Path $temp 'probe.dme') -Value '#include "fixture.dm"','#include "production.dm"'
    & (Join-Path $ByondBin 'dm.exe') (Join-Path $temp 'probe.dme') 2>&1 | Tee-Object -Variable compile
    if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed' }
    $out = Join-Path $temp 'stdout.log'
    $err = Join-Path $temp 'stderr.log'
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temp 'probe.dmb'), '-invisible', '-trusted', '-log', (Join-Path $temp 'runtime.log')) -WorkingDirectory $temp -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    if (!$process.WaitForExit($TimeoutSeconds*1000)) { Stop-Process -Id $process.Id; $process.WaitForExit(); Get-Content (Join-Path $temp 'runtime.log') | Select-Object -First 50; throw 'Probe timed out' }
    Get-Content -LiteralPath $out,$err,(Join-Path $temp 'runtime.log')
    Write-Output "Process exit: $($process.ExitCode)"
} finally {
    Write-Output "Probe artifacts: $temp"
}



