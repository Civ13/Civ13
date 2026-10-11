param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [ValidateRange(1024,65535)][int]$Port=18339, [ValidateRange(60,900)][int]$TimeoutSeconds=600)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$nonce = [guid]::NewGuid().ToString('N')
$source = Join-Path $repo ('.gun-area-' + $nonce + '.dme')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-gun-area-' + $nonce)
$owned = $null
New-Item -ItemType Directory -Path $run | Out-Null
try {
    [IO.File]::WriteAllText($source, '#include "civ13.dme"' + "`n" + '#include "tests/gun_configuration/test_area.dm"' + "`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $source 2>&1
    $build | Set-Content -LiteralPath (Join-Path $run 'build.log')
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '516.1681' -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Pinned test-area compilation failed' }
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source,'dmb')) -Destination (Join-Path $run 'area.dmb')
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source,'rsc')) -Destination (Join-Path $run 'area.rsc')
    Copy-Item -LiteralPath (Join-Path $repo 'config'),(Join-Path $repo 'UI') -Destination $run -Recurse
    New-Item -ItemType Directory -Path (Join-Path $run 'SQL') | Out-Null
    $configPath = Join-Path $run 'config/config.txt'
    $config = Get-Content -Raw -LiteralPath $configPath
    $config = [regex]::Replace($config,'(?m)^(HUB|GUEST_BAN|USE_JOB_WHITELIST)\s*\r?$','#$1')
    $config = [regex]::Replace($config,'(?m)^HUB_BANNER_URL[^\r\n]*','#HUB_BANNER_URL')
    [IO.File]::WriteAllText($configPath,$config)
    $commit = (& git -C $repo rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify tested commit' }
    $parameters = 'tested_commit=' + $commit
    if ($Visual) { $parameters += '&visual=1' }
    $owned = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @('area.dmb',"$Port",'-invisible','-safe','-params',$parameters,'-log','startup.log') -WorkingDirectory $run -WindowStyle Hidden -PassThru
    Write-Output "RUN_DIRECTORY=$run; OWNED_PID=$($owned.Id); LOCAL_CONNECT=byond://127.0.0.1:$Port"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$owned.WaitForExit(200)) {
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            if ($Visual -and (Test-Path -LiteralPath (Join-Path $run 'test-area-ready.json'))) { break }
            throw 'Test-area startup timed out'
        }
    }
    if (!(Test-Path -LiteralPath (Join-Path $run 'test-area-ready.json'))) { throw "Area did not become ready; inspect $run" }
    Get-Content -LiteralPath (Join-Path $run 'test-area-ready.json')
} finally {
    if ($owned -and !$owned.HasExited) { Stop-Process -Id $owned.Id; $owned.WaitForExit() }
    foreach ($path in @($source,[IO.Path]::ChangeExtension($source,'dmb'),[IO.Path]::ChangeExtension($source,'rsc'))) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    Write-Output "Retained disposable evidence: $run"
}
