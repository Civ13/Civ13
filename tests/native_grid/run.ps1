param([Parameter(Mandatory)][string]$ByondBin, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-native-grid-' + [guid]::NewGuid())
$runtime = $null
$options = @{}
$compilerName = 'DreamMaker'
$daemonName = 'DreamDaemon'
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $options.WindowStyle = 'Hidden'
    $compilerName = 'dm.exe'
    $daemonName = 'dd.exe'
}
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    if ($Baseline) {
        $source = (& git -C $repo show 'aa675de6dbade0f3740c516dc4b5945c5c9a43c7:code/modules/1713/machinery/cables.dm') -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Pinned baseline unavailable' }
    } else {
        $source = Get-Content -LiteralPath (Join-Path $repo 'code/modules/1713/machinery/cables.dm') -Raw
    }
    $start = $source.IndexOf('/obj/structure/cable/proc/get_connections()')
    if ($start -lt 0) { throw 'Production graph boundary missing' }
    $source = $source.Substring($start)
    # Count real calls and queue iterations in the generated copy only.
    $header = [regex]::Matches($source, '(?m)^/obj/structure/cable/proc/rebuild_supply\([^\r\n]*\)')
    if ($header.Count -ne 1) { throw 'Production traversal signature changed' }
    $source = $source.Replace($header[0].Value, $header[0].Value + "`n`tgrid_probe_calls++")
    $loop = if ($Baseline) { "`twhile (pending.len)" } else { "`twhile (index <= pending.len)" }
    if (!$source.Contains($loop)) { throw 'Production queue boundary changed' }
    $source = $source.Replace($loop, $loop + "`n`t`tgrid_probe_steps++")
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'probe.dm') -Raw
    $define = if ($Baseline) { '' } else { "#define GRID_CURRENT`n" }
    [IO.File]::WriteAllText((Join-Path $temporary 'probe.dme'), $define + $fixture + "`n" + $source)
    $compiler = Start-Process -FilePath (Join-Path $ByondBin $compilerName) -ArgumentList @('probe.dme') -WorkingDirectory $temporary -Wait -PassThru -RedirectStandardOutput (Join-Path $temporary 'compile.log') @options
    $compile = Get-Content -LiteralPath (Join-Path $temporary 'compile.log') -Raw
    Write-Output $compile
    if ($compiler.ExitCode -ne 0 -or $compile -notmatch '516\.1681' -or $compile -notmatch '0 errors, 0 warnings') { throw 'Pinned compilation failed' }
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $daemonName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-safe', '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @options
    if (!$runtime.WaitForExit(60000)) { throw 'Unique graph fixture timed out' }
    $log = Get-Content -LiteralPath (Join-Path $temporary 'runtime.log') -Raw
    Write-Output $log
    if ($runtime.ExitCode -ne 0 -or $log -notmatch 'GRID_METRICS .*failures=0' -or $log -match 'runtime error|Bad ref|FAIL ') { throw 'Production graph comparison failed' }
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    $resolved = [IO.Path]::GetFullPath($temporary)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
