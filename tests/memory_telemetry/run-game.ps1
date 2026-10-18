param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [Parameter(Mandatory=$true)][string]$EvidenceDir,
    [ValidateRange(45,90)][int]$TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows) { throw 'This launcher verifies Windows native BYOND only' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot determine tested commit' }
$dirtyStatus = @(git -C $repo status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine dirty state' }
$evidence = [IO.Path]::GetFullPath($EvidenceDir)
if (Test-Path -LiteralPath $evidence) {
    if (@(Get-ChildItem -LiteralPath $evidence -Force).Count) { throw 'Evidence directory must be empty or absent' }
} else { New-Item -ItemType Directory -Path $evidence | Out-Null }
$prefix = '.memory_telemetry_game_' + [guid]::NewGuid().ToString('N')
$generated = @('dme','dmb','rsc') | ForEach-Object { Join-Path $repo ($prefix + '.' + $_) }
foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { throw 'Preserve existing generated source' } }
$process = $null
$osRows = [Collections.Generic.List[object]]::new()
$alignment = $null
$previousPoll = 0.0
$timer = [Diagnostics.Stopwatch]::new()
try {
    $patchLines = @(git -C $repo diff HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot preserve tested diff' }
    [IO.File]::WriteAllText((Join-Path $evidence 'tested.patch'), ($patchLines -join "`n"))
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    [IO.File]::WriteAllText($generated[0], $source + "`n#include `"tests/memory_telemetry/game_probe.dm`"`n")
    Copy-Item -LiteralPath (Join-Path $repo 'tests/memory_telemetry/game_probe.dm') -Destination (Join-Path $evidence 'game_probe.dm')
    Copy-Item -LiteralPath (Join-Path $repo 'code/_helpers/memory_lifetime_telemetry.dm') -Destination (Join-Path $evidence 'memory_lifetime_telemetry.dm')
    Copy-Item -LiteralPath $generated[0] -Destination (Join-Path $evidence 'generated.dme')
    # Hash the complete recursively included source/map/interface graph.
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($generated[0])
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $hashes = [Collections.Generic.List[object]]::new()
    while ($pending.Count) {
        $path = $pending.Dequeue()
        if (!$seen.Add($path)) { continue }
        $relative = [IO.Path]::GetRelativePath($repo, $path)
        $hashes.Add(@{path=$relative;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()})
        if ([IO.Path]::GetExtension($path) -in @('.dm','.dme')) {
            $includeText = [regex]::Replace([IO.File]::ReadAllText($path), '(?s)/\*.*?\*/', '')
            foreach ($match in [regex]::Matches($includeText, '(?m)^\s*#include\s+"([^"]+)"')) {
                $child = [IO.Path]::GetFullPath((Join-Path (Split-Path $path -Parent) $match.Groups[1].Value))
                if (!(Test-Path -LiteralPath $child)) { throw "Missing included source: $child" }
                $pending.Enqueue($child)
            }
        }
    }
    foreach ($path in @('tests/memory_telemetry/run-game.ps1','code/_helpers/memory_lifetime_telemetry.dm')) {
        $hashes.Add(@{path=$path;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $path)).Hash.ToLowerInvariant()})
    }
    $hashes | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'source-hashes.json')
    @{head_sha=$commit;working_tree_dirty=($dirtyStatus.Count -gt 0);checkout_status=$dirtyStatus;byond='516.1681';scope='normal full-game Nomads startup; finite ephemera exercise; Windows owned-process memory';os=[Environment]::OSVersion.ToString()} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'metadata.json')
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $generated[0] 2>&1
    $build | Tee-Object -FilePath (Join-Path $evidence 'compile.log') | Select-Object -Last 5
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch 'DM compiler version 516.1681' -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Pinned full-game telemetry compilation failed' }
    Copy-Item -LiteralPath $generated[1],$generated[2] -Destination $evidence
    # Copy only versioned public configuration, excluding ignored local secrets/state.
    $configFiles = @(git -C $repo ls-files -- config)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory public configuration' }
    foreach ($relative in $configFiles) {
        $destination = Join-Path $evidence $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $destination
    }
    $launch = @{FilePath=(Join-Path $ByondBin 'dd.exe');ArgumentList=@(('"' + (Join-Path $evidence ($prefix + '.dmb')) + '"'),'-invisible','-close','-trusted','-params',('tested_commit=' + $commit),'-log','startup.log');WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=(Join-Path $evidence 'daemon-output.log');RedirectStandardError=(Join-Path $evidence 'daemon-error.log')}
    $timer.Start()
    $process = Start-Process @launch
    Write-Output "Owned telemetry PID: $($process.Id); evidence: $evidence"
    while (!$process.WaitForExit(250)) {
        $process.Refresh()
        $now = $timer.Elapsed.TotalSeconds
        if ($osRows.Count -ge 600 -or $now -gt $TimeoutSeconds -or $process.PrivateMemorySize64 -gt 1GB -or $process.TotalProcessorTime.TotalSeconds -gt 45) { throw 'Finite full-game telemetry resource limit exceeded' }
        $osRows.Add(@{stopwatch_elapsed_seconds=$now;private_memory_bytes=$process.PrivateMemorySize64;working_set_bytes=$process.WorkingSet64})
        if (!$alignment -and (Test-Path -LiteralPath (Join-Path $evidence 'telemetry-ready.json'))) {
            $ready = Get-Content -Raw -LiteralPath (Join-Path $evidence 'telemetry-ready.json') | ConvertFrom-Json
            $alignment = @{native_start=$ready;os_observed_lower_seconds=$previousPoll;os_observed_upper_seconds=$now;os_offset_midpoint_seconds=($previousPoll + $now)/2;uncertainty_seconds=($now-$previousPoll)/2;method='Native file existence bracketed by owned-process polling; file/write/start scheduling adds unquantified small delay'}
        }
        $previousPoll = $now
    }
    $timer.Stop()
    $diagnosticPattern = '(?im)^\s*(BUG:|runtime error|##\s*ERROR:|RUNTIME[: ])|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|infinite loop|segmentation|fatal error'
    $diagnostics = @(Get-ChildItem -LiteralPath $evidence -File -Recurse | Where-Object { $_.Name -match '\.(log|txt)$' -and $_.Name -ne 'compile.log' } | Select-String -Pattern $diagnosticPattern)
    if ($diagnostics.Count) { $diagnostics | Select-Object -First 8 | Write-Output; throw 'Native diagnostics invalidate telemetry evidence' }
    $sentinel = Get-Content -Raw -LiteralPath (Join-Path $evidence 'telemetry-result.txt')
    if ($sentinel -notmatch '^PASS:') { throw "Native telemetry probe failed: $sentinel" }
    $result = Get-Content -Raw -LiteralPath (Join-Path $evidence 'telemetry-result.json') | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or !$result.passed -or $sentinel -notmatch '^PASS:' -or !$alignment -or $result.tested_commit -ne $commit -or $result.port -ne 0 -or $result.native_rows.Count -ne 40 -or $result.created_effects -gt 600 -or $result.peak_owned_effects -gt 40 -or $osRows.Count -gt 600) { throw 'Native full-game telemetry contract failed' }
    $firstNative = $result.native_rows[0]
    $lastNative = $result.native_rows[-1]
    $enqueueRate = ($result.native_rows.gc_enqueue_per_second | Measure-Object -Maximum).Maximum
    $drainRate = ($result.native_rows.gc_drain_per_second | Measure-Object -Maximum).Maximum
    if ($lastNative.gc_enqueued -le $firstNative.gc_enqueued -or $lastNative.gc_drained -le $firstNative.gc_drained -or $enqueueRate -le 0 -or $drainRate -le 0) { throw 'Bounded native trace did not demonstrate positive enqueue and queue-drain deltas/rates' }
    foreach ($row in $osRows) { $row.native_elapsed_seconds_estimate = $row.stopwatch_elapsed_seconds - $alignment.os_offset_midpoint_seconds }
    Write-Output "PASS: $($result.native_rows.Count) native rows; $($osRows.Count) OS rows; $($result.created_effects) effect constructions; peak $($result.peak_owned_effects) owned effects"
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    $osRows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'os-memory.json')
    @{os_clock='System.Diagnostics.Stopwatch seconds since launch request, monotonic';native_clock='world.timeofday observed deciseconds modulo midnight; world.time recorded separately';poll_interval_target_seconds=0.25;max_os_rows=600;alignment=$alignment;elapsed_seconds=$timer.Elapsed.TotalSeconds;pid=if($process){$process.Id}else{$null};scope='Observed Windows memory and awake scheduling intervals only; not a production soak or OOM remediation proof'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'alignment.json')
    foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    Write-Output "Telemetry artifacts retained: $evidence"
}
