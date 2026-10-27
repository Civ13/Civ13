param(
    [Parameter(Mandatory)][string]$ByondBin,
    [string]$SourceRef
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('civ13-power-' + [guid]::NewGuid())
$runtime = $null
$processOptions = @{}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $processOptions.WindowStyle = 'Hidden' }
$compilerName = if ($processOptions.Count) { 'dm.exe' } else { 'DreamMaker' }
$runtimeName = if ($processOptions.Count) { 'dd.exe' } else { 'DreamDaemon' }
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    if ($SourceRef) {
        $source = (& git -C $repo show "${SourceRef}:code/modules/1713/machinery/cables.dm") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read original cable source.' }
        $fixture = Get-Content -LiteralPath (Join-Path $repo 'tests/power/reproduction.dm') -Raw
    } else {
        $source = Get-Content -LiteralPath (Join-Path $repo 'code/modules/1713/machinery/cables.dm') -Raw
        $fixture = Get-Content -LiteralPath (Join-Path $repo 'tests/power/fixture.dm') -Raw
        $engineSource = Get-Content -LiteralPath (Join-Path $repo 'code/modules/1713/machinery/engines/engines.dm') -Raw
        $engineDestroy = $engineSource.Substring($engineSource.IndexOf('/obj/structure/engine/proc/disconnect_cables()'))
        $objSource = Get-Content -LiteralPath (Join-Path $repo 'code/game/objects/objs.dm') -Raw
        $destroyStart = $objSource.IndexOf('/obj/Destroy()')
        $objDestroy = $objSource.Substring($destroyStart, $objSource.IndexOf('/obj/Topic(', $destroyStart) - $destroyStart)
        $processStart = $engineSource.IndexOf('/obj/structure/engine/proc/process_power_output()')
        $engineProcess = $engineSource.Substring($processStart, $engineSource.IndexOf('/obj/structure/engine/proc/process_current_weight()', $processStart) - $processStart)
        foreach ($consumerSpec in @(
            @('code/modules/1713/radio.dm', '/obj/structure/radio/proc/check_power()', '/obj/structure/radio/attack_hand('),
            @('code/modules/1713/modern_items.dm', '/obj/structure/lamp/proc/check_power()', '/obj/structure/lamp/bullet_act(')
        )) {
            $consumerSource = Get-Content -LiteralPath (Join-Path $repo $consumerSpec[0]) -Raw
            $consumerStart = $consumerSource.IndexOf($consumerSpec[1])
            $consumerEnd = $consumerSource.IndexOf($consumerSpec[2], $consumerStart)
            $fixture += "`n" + $consumerSource.Substring($consumerStart, $consumerEnd - $consumerStart)
        }
        $cableDestroyStart = $source.IndexOf('/obj/structure/cable/Destroy()')
        $cableDestroy = $source.Substring($cableDestroyStart, $source.IndexOf('///////////////////////////////////', $cableDestroyStart) - $cableDestroyStart)
        $fixture += "`n" + $cableDestroy
        $fixture += "`n" + $engineProcess + "`n" + $engineDestroy + "`n" + $objDestroy
    }
    $start = $source.IndexOf('/obj/structure/cable/proc/get_connections()')
    if ($start -lt 0) { throw 'Production network section not found.' }
    $environment = Join-Path $temporary 'probe.dme'
    Set-Content -LiteralPath $environment -Value ($fixture + "`n" + $source.Substring($start))
    $compiler = Start-Process -FilePath (Join-Path $ByondBin $compilerName) -ArgumentList @($environment) -Wait -PassThru -RedirectStandardOutput (Join-Path $temporary 'compile.log') @processOptions
    $compileLog = Get-Content -LiteralPath (Join-Path $temporary 'compile.log') -Raw
    Write-Output $compileLog
    if ($compiler.ExitCode -ne 0 -or $compileLog -notmatch '0 errors, 0 warnings') { throw 'Probe compilation failed.' }
    $runtime = Start-Process -FilePath (Join-Path $ByondBin $runtimeName) -ArgumentList @('probe.dmb', '0', '-invisible', '-close', '-trusted', '-log', 'runtime.log') -WorkingDirectory $temporary -PassThru @processOptions
    if (!$runtime.WaitForExit(30000)) {
        Stop-Process -Id $runtime.Id
        $runtime.WaitForExit()
        $timeoutLog = Join-Path $temporary 'runtime.log'
        if (Test-Path -LiteralPath $timeoutLog) { Get-Content -LiteralPath $timeoutLog }
        throw 'Probe timed out.'
    }
    $log = Get-Content -LiteralPath (Join-Path $temporary 'runtime.log') -Raw
    Write-Output $log
    if ($log -notmatch 'POWER_PROBE failures=0' -or $log -match 'runtime error') { throw 'Power regression probe failed.' }
} finally {
    if ($runtime -and !$runtime.HasExited) { Stop-Process -Id $runtime.Id; $runtime.WaitForExit() }
    $resolved = [IO.Path]::GetFullPath($temporary)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid temporary path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
