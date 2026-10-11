param([Parameter(Mandatory)][string]$ByondBin)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-battery-' + [guid]::NewGuid())
$runtime = $null
$processOptions = @{}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $processOptions.WindowStyle = 'Hidden' }
$compilerName = if ($processOptions.Count) { 'dm.exe' } else { 'DreamMaker' }
$runtimeName = if ($processOptions.Count) { 'dd.exe' } else { 'DreamDaemon' }
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $source = Get-Content -LiteralPath (Join-Path $repo 'code\modules\1713\machinery\batteries.dm') -Raw
    $start = $source.IndexOf('// BATTERY CONTRACTS:')
    $end = $source.Length
    if ($start -lt 0 -or $end -lt 0) { throw 'Production network section not found.' }
    $fixture = Get-Content -LiteralPath (Join-Path $repo 'tests\batteries\fixture.dm') -Raw
    $environment = Join-Path $temporary 'probe.dme'
    $cable = Get-Content -LiteralPath (Join-Path $repo 'code/modules/1713/machinery/cables.dm') -Raw
    $cable = $cable.Substring($cable.IndexOf('/obj/structure/cable/proc/get_connections()'))
    Set-Content -LiteralPath $environment -Value ($fixture + "`n" + $source.Substring($start, $end - $start) + "`n" + $cable)
    $compiler = Start-Process -FilePath (Join-Path $ByondBin $compilerName) -ArgumentList @($environment) -Wait -PassThru @processOptions -RedirectStandardOutput (Join-Path $temporary 'compile.log')
    Get-Content -LiteralPath (Join-Path $temporary 'compile.log')
    if ($compiler.ExitCode -ne 0) { throw 'Probe compilation failed.' }
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $runtimeName) -ArgumentList @((Join-Path $temporary 'probe.dmb'), '-invisible', '-trusted', '-logself') -WorkingDirectory $temporary @processOptions -PassThru
    if (!$runtime.WaitForExit(30000)) { Stop-Process -Id $runtime.Id; throw 'Probe timed out.' }
    $log = Get-Content -LiteralPath (Join-Path $temporary 'probe.log') -Raw
    Write-Output $log
    if ($log -notmatch 'BATTERY_PROBE failures=0' -or $log -match 'runtime error') { throw 'Battery regression probe failed.' }
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id }
    $resolved = [IO.Path]::GetFullPath($temporary)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}




