param([Parameter(Mandatory=$true)][string]$ByondBin)
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
    $process = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $run 'probe.dmb'),'-invisible','-safe','-params',"tested_commit=$commit",'-log','startup.log') -WorkingDirectory $run -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(120000)) { throw 'Full-game probe timed out' }
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
