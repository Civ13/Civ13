param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [switch]$AutoScene, [switch]$ExerciseCapture, [ValidateRange(1024,65535)][int]$Port=18328, [ValidateRange(60,900)][int]$TimeoutSeconds=120)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$nonce = [guid]::NewGuid().ToString('N')
$environment = Join-Path $repo ('.conveyor-probe-' + $nonce + '.dme')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-conveyor-game-' + $nonce)
New-Item -ItemType Directory -Path $run | Out-Null
$process = $null
try {
    [IO.File]::WriteAllText($environment, '#include "civ13.dme"' + "`n" + '#include "tests/conveyor/full_game_probe.dm"' + "`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $environment 2>&1
    $build | Set-Content -LiteralPath (Join-Path $run 'build.log')
    $build | Write-Output
    if ($LASTEXITCODE -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Full-game probe compilation failed' }
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($environment,'dmb')) -Destination (Join-Path $run 'probe.dmb')
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($environment,'rsc')) -Destination (Join-Path $run 'probe.rsc')
    Copy-Item -LiteralPath (Join-Path $repo 'config'),(Join-Path $repo 'UI') -Destination $run -Recurse
    New-Item -ItemType Directory -Path (Join-Path $run 'SQL') | Out-Null
    $configPath = Join-Path $run 'config/config.txt'
    $config = Get-Content -LiteralPath $configPath -Raw
    $config = [regex]::Replace($config,'(?m)^(HUB|GUEST_BAN|USE_JOB_WHITELIST)\s*\r?$','#$1')
    $config = [regex]::Replace($config,'(?m)^HUB_BANNER_URL[^\r\n]*','#HUB_BANNER_URL')
    [IO.File]::WriteAllText($configPath,$config)
    $commit = (& git -C $repo rev-parse HEAD).Trim()
    if ($LASTEXITCODE -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot determine tested commit' }
    $parameters = 'tested_commit=' + $commit
    if ($AutoScene -and !$Visual) { throw 'AutoScene requires Visual' }
    if ($Visual) { $parameters += '&visual=1' }
    if ($AutoScene) { $parameters += '&auto_scene=1' }
    if ($ExerciseCapture) { $parameters += '&exercise_capture=1' }
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $run 'probe.dmb'),"$Port",'-invisible','-trusted','-params',$parameters,'-log','startup.log') -WorkingDirectory $run -WindowStyle Hidden -PassThru
    Write-Output "RUN_DIRECTORY=$run; PID=$($process.Id); connect=byond://127.0.0.1:$Port"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(200)) {
        $process.Refresh()
        if ($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            if ($Visual -and (Test-Path -LiteralPath (Join-Path $run 'game_result.txt'))) { Stop-Process -Id $process.Id; $process.WaitForExit(); break }
            throw 'Full-game probe timed out'
        }
    }
    $result = Get-Content -LiteralPath (Join-Path $run 'game_result.txt') -Raw
    Write-Output "RUN_DIRECTORY=$run"
    Write-Output $result
    if ($result -notmatch '^PASS:') { throw 'Full-game assertions failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    foreach ($path in @($environment,[IO.Path]::ChangeExtension($environment,'dmb'),[IO.Path]::ChangeExtension($environment,'rsc'))) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
}
