param([string]$ByondBin = 'C:\Program Files (x86)\BYOND\bin')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-battery-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $source = Get-Content -LiteralPath (Join-Path $repo 'code\modules\1713\machinery\batteries.dm') -Raw
    $start = $source.IndexOf('// BATTERY CONTRACTS:')
    $end = $source.Length
    if ($start -lt 0 -or $end -lt 0) { throw 'Production network section not found.' }
    $fixture = Get-Content -LiteralPath (Join-Path $repo 'tests\batteries\fixture.dm') -Raw
    $environment = Join-Path $temporary 'probe.dme'
    Set-Content -LiteralPath $environment -Value ($fixture + "`n" + $source.Substring($start, $end - $start))
    $compiler = Start-Process -FilePath (Join-Path $ByondBin 'dm.exe') -ArgumentList @($environment) -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $temporary 'compile.log')
    Get-Content -LiteralPath (Join-Path $temporary 'compile.log')
    if ($compiler.ExitCode -ne 0) { throw 'Probe compilation failed.' }
    $runtime = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temporary 'probe.dmb'), '-invisible', '-trusted', '-logself') -WorkingDirectory $temporary -WindowStyle Hidden -PassThru
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




