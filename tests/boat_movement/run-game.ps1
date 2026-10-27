param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [switch]$TankOnly, [ValidateRange(1,900)][int]$TimeoutSeconds = 120, [string]$ArtifactDirectory)
$ErrorActionPreference = 'Stop'
if ($Visual -and !$IsWindows) { throw 'Visual mode uses a Windows Dream Seeker client' }
if ($Visual -and $TankOnly) { throw 'TankOnly is for diagnostic batch checks, not a visual world' }
$compiler = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
$daemon = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sourcePath = Join-Path $repo '.boat_game_probe.dme'
if (Test-Path -LiteralPath $sourcePath) { throw 'Existing probe source must be preserved' }
$artifactRoot = if ($ArtifactDirectory) { [IO.Path]::GetFullPath($ArtifactDirectory) } else { [IO.Path]::GetTempPath() }
$temp = Join-Path $artifactRoot ('civ13-boat-game-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
$process = $null
$commit = git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source revision' }
$dirty = [bool](git -C $repo status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source state' }
@{commit=$commit;dirty=$dirty;visual=[bool]$Visual;tank_only=[bool]$TankOnly;timeout_seconds=$TimeoutSeconds;os=[Environment]::OSVersion.ToString()} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'source-metadata.json')
function Write-ProbeDiagnostics {
    foreach ($name in @('boat-result.json','boat-result.txt','boat-drift.txt')) {
        $path = Join-Path $temp $name
        if (Test-Path -LiteralPath $path) {
            Write-Output "Probe diagnostic: $name"
            Get-Content -LiteralPath $path -Tail 100
        }
    }
    $files = @(Get-ChildItem -LiteralPath $temp -File -Recurse | Where-Object { $_.Extension -in @('.log','.txt') -and $_.Name -ne 'compile.log' })
    $errors = @($files | Select-String -Pattern 'runtime error:|BOAT FAIL:|BOAT EXCEPTION:|\bBad ref\b|\bBad loc\b|^\s*BUG:|##\s*ERROR:|Cannot read null|Cannot execute null')
    $errors | Select-Object -Last 100 | ForEach-Object { Write-Output "Probe diagnostic: $($_.Path):$($_.LineNumber): $($_.Line)" }
}
function Assert-NativeLogs {
    $files = @(Get-ChildItem -LiteralPath $temp -File -Recurse | Where-Object { $_.Name -match '\.(log|txt)$' -and $_.Name -ne 'compile.log' })
    $errors = @($files | Select-String -Pattern 'runtime error:|BOAT FAIL:|BOAT EXCEPTION:|\bBad ref\b|\bBad loc\b|^\s*BUG:|##\s*ERROR:|Cannot read null|Cannot execute null')
    if ($errors.Count) { throw ('Native log errors: ' + ($errors.Line -join '; ')) }
}
try {
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    [IO.File]::WriteAllText($sourcePath,$source + "`n#include `"tests/boat_movement/game_probe.dm`"`n")
    $build = & (Join-Path $ByondBin $compiler) -max_errors 0 $sourcePath 2>&1
    $build | Tee-Object -FilePath (Join-Path $temp 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Full-game probe compilation failed' }
    foreach ($extension in @('dmb','rsc')) { Copy-Item -LiteralPath (Join-Path $repo ('.boat_game_probe.' + $extension)) -Destination $temp }
    Remove-Item -LiteralPath $sourcePath -Force
    # Copy only versioned sample configuration into isolated storage; never local secrets/saves.
    foreach ($path in (git -C $repo ls-files config)) {
        $target = Join-Path $temp $path
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $path) -Destination $target
        if ([IO.Path]::GetExtension($target) -eq '.txt') {
            $lines = Get-Content -LiteralPath $target | Where-Object { $_ -notmatch '^\s*(ToRban|webhook_can_fire)\b' }
            Set-Content -LiteralPath $target -Value $lines
        }
    }
    Write-Output "Full-game source: $commit; working source dirty: $dirty"
    $parameters = 'tested_commit=' + $commit
    if ($Visual) { $parameters += '&visual=1' }
    if ($TankOnly) { $parameters += '&tank_only=1' }
    $launch = @{
        FilePath = Join-Path $ByondBin $daemon
        ArgumentList = @(('"' + (Join-Path $temp '.boat_game_probe.dmb') + '"'), '-invisible', '-trusted', '-params', $parameters, '-log', 'startup.log')
        WorkingDirectory = $temp
        PassThru = $true
        RedirectStandardOutput = Join-Path $temp 'daemon-output.log'
        RedirectStandardError = Join-Path $temp 'daemon-error.log'
    }
    if (!$Visual) { $launch.ArgumentList += '-close' }
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds).ToString('o')
    Write-Output "LOCAL boat daemon PID: $($process.Id); runtime: $temp; expires UTC: $deadline"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $announced = $false
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 768MB -or $process.TotalProcessorTime.TotalSeconds -gt 45) {
            Stop-Process -Id $process.Id; $process.WaitForExit(); throw 'Full-game probe exceeded resource limit'
        }
        $resultPath = Join-Path $temp 'boat-result.json'
        if (!$announced -and (Test-Path -LiteralPath $resultPath)) {
            $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
            if ($Visual -and $result.phase -notlike 'READY:*' -and !$result.failures) { continue }
            if ($result.failures) {
                Write-ProbeDiagnostics
                throw ('Full-game assertion failures: ' + $result.failures + '; labels: ' + ($result.failure_labels -join '; '))
            }
            $errors = @(Get-ChildItem -LiteralPath (Join-Path $temp 'data/logs/runtime') -File -ErrorAction SilentlyContinue | Select-String -Pattern 'runtime error:|BOAT FAIL:|BOAT EXCEPTION:')
            if ($errors.Count) { throw ('Runtime log errors: ' + ($errors.Line -join '; ')) }
            if (!$Visual) { Write-Output 'Full-game assertions completed; no visual world requested'; $announced = $true; continue }
            $portMatch = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $temp 'startup.log')), 'World opened on network port (\d+)')
            if (!$portMatch.Success) { throw 'Daemon port not found in startup log' }
            $port = $portMatch.Groups[1].Value
            $session = @{commit=$commit; daemon_pid=$process.Id; port=[int]$port; runtime=$temp; expires_utc=$deadline; client_executable=(Join-Path $ByondBin 'dreamseeker.exe'); client_url=('byond://127.0.0.1:'+$port)}
            $session | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'session.json')
            Write-Output ('READY session: ' + ($session | ConvertTo-Json -Compress))
            $announced = $true
        }
    }
    Assert-NativeLogs
    $resultText = Get-Content -Raw -LiteralPath (Join-Path $temp 'boat-result.txt')
    Write-Output $resultText
    if ($process.ExitCode -ne 0 -or $resultText -notmatch '^RESULT failures=0') { throw 'Full-game probe failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    # A timeout, native diagnostic or early assertion failure must retain its evidence.
    try { Write-ProbeDiagnostics } catch { Write-Warning "Could not read probe diagnostics: $_" }
    if (Test-Path -LiteralPath $sourcePath) { Remove-Item -LiteralPath $sourcePath -Force }
    Write-Output "Full-game artifacts: $temp"
}
