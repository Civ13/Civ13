param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [ValidateRange(1,900)][int]$TimeoutSeconds = 90)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot determine tested commit' }
$sourcePath = Join-Path $repo '.train_game_probe.dme'
if (Test-Path -LiteralPath $sourcePath) { throw 'Existing probe file must be preserved' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-train-game-' + [guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
$process = $null
try {
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    [IO.File]::WriteAllText($sourcePath, $source + "`n#include `"tests/train_collision/game_probe.dm`"`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $sourcePath 2>&1
    $build | Tee-Object -FilePath (Join-Path $temp 'compile.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Full-game probe compilation failed' }
    foreach ($extension in @('dmb','rsc')) { Copy-Item -LiteralPath (Join-Path $repo ('.train_game_probe.' + $extension)) -Destination $temp }
    Copy-Item -LiteralPath (Join-Path $repo 'config') -Destination $temp -Recurse
    $parameters = 'tested_commit=' + $commit
    if ($Visual) { $parameters += '&visual=1' }
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $temp '.train_game_probe.dmb'), '-invisible', '-safe', '-params', $parameters, '-log', (Join-Path $temp 'startup.log')) -WorkingDirectory $temp -WindowStyle Hidden -PassThru
    Write-Output "Local game PID: $($process.Id); runtime: $temp"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 768MB -or $process.TotalProcessorTime.TotalSeconds -gt 45) {
            Stop-Process -Id $process.Id; $process.WaitForExit(); throw 'Full-game probe exceeded resource limit'
        }
    }
    $result = Get-Content -Raw -LiteralPath (Join-Path $temp 'train-result.txt')
    Write-Output $result
    Get-Content -LiteralPath (Join-Path $temp 'train-result.json')
    if ($process.ExitCode -ne 0 -or $result -notmatch '^RESULT failures=0') { throw 'Full-game probe failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    Remove-Item -LiteralPath $sourcePath -ErrorAction SilentlyContinue
    Write-Output "Full-game artifacts: $temp"
}
