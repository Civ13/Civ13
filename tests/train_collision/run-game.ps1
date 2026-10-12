param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [ValidateRange(1,900)][int]$TimeoutSeconds = 90)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot determine tested commit' }
$dirtyStatus = @(git -C $repo status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine checkout dirty state' }
$sourcePath = Join-Path $repo '.train_game_probe.dme'
if (Test-Path -LiteralPath $sourcePath) { throw 'Existing probe file must be preserved' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-train-game-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
$process = $null
@{ head_sha = $commit; working_tree_dirty = ($dirtyStatus.Count -gt 0); byond = '516.1681'; visual = [bool]$Visual } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'metadata.json')
git -C $repo diff HEAD | Set-Content -LiteralPath (Join-Path $temp 'tested.patch')
if ($LASTEXITCODE -ne 0) { throw 'Cannot preserve tested diff' }
@('code/controllers/mc/globals.dm', 'tests/train_collision/game_probe.dm', 'tests/train_collision/run-game.ps1') | ForEach-Object { $path = $_; @{ path = $path; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $path)).Hash.ToLowerInvariant() } } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'source-hashes.json')
try {
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    [IO.File]::WriteAllText($sourcePath, $source + "`n#include `"tests/train_collision/game_probe.dm`"`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $sourcePath 2>&1
    $build | Tee-Object -FilePath (Join-Path $temp 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch 'DM compiler version 516.1681' -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Full-game probe compilation failed' }
    foreach ($extension in @('dmb','rsc')) { Copy-Item -LiteralPath (Join-Path $repo ('.train_game_probe.' + $extension)) -Destination $temp }
    Copy-Item -LiteralPath (Join-Path $repo 'config') -Destination $temp -Recurse
    $parameters = 'tested_commit=' + $commit
    if ($Visual) { $parameters += '&visual=1' }
    $process = Start-Process -RedirectStandardOutput (Join-Path $temp 'daemon-output.log') -RedirectStandardError (Join-Path $temp 'daemon-error.log') -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temp '.train_game_probe.dmb'), '-invisible', '-close', '-safe', '-params', $parameters, '-log', 'startup.log') -WorkingDirectory $temp -WindowStyle Hidden -PassThru
    Write-Output "Local game PID: $($process.Id); runtime: $temp"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 768MB -or $process.TotalProcessorTime.TotalSeconds -gt 45) {
            Stop-Process -Id $process.Id; $process.WaitForExit(); throw 'Full-game probe exceeded resource limit'
        }
    }
    $diagnosticPattern = '(?im)^\s*(BUG:|runtime error|## ERROR:|RUNTIME[: ])|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null'
    $diagnostics = @(Get-ChildItem -LiteralPath $temp -File -Recurse | Where-Object { $_.Name -match '\.(log|txt)$' -and $_.Name -ne 'compile.log' } | Select-String -Pattern $diagnosticPattern)
    if ($diagnostics.Count) { $diagnostics | Select-Object -First 10 | ForEach-Object { Write-Output $_ }; throw 'Native engine/runtime diagnostics invalidate full-game acceptance' }
    $result = Get-Content -Raw -LiteralPath (Join-Path $temp 'train-result.txt')
    Write-Output $result
    Get-Content -LiteralPath (Join-Path $temp 'train-result.json')
    if ($process.ExitCode -ne 0 -or $result -notmatch '^RESULT failures=0') { throw 'Full-game probe failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    Remove-Item -LiteralPath $sourcePath -ErrorAction SilentlyContinue
    Write-Output "Full-game artifacts: $temp"
}
