param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateRange(1024,65535)][int]$Port = 16994
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = (git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Cannot identify evidence commit' }
$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Use a clean committed checkout for evidence' }
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } finally { $listener.Stop() }
$nonce = [guid]::NewGuid().ToString('N')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-evidence-' + 'battery' + '-' + $nonce)
New-Item -ItemType Directory -Path $run | Out-Null
$environment = Join-Path $repo ('.battery-evidence-' + $nonce + '.dme')
$base = Get-Content -LiteralPath (Join-Path $repo 'civ13.dme') -Raw
foreach ($adapter in @(@('code/modules/webhooks/webhooks.dm','/proc/webhook_send(method, data)'), @('code/modules/admin/ToRban.dm','/proc/ToRban_update()'))) {
    $body = Get-Content -LiteralPath (Join-Path $repo $adapter[0]) -Raw
    $body = $body.Replace($adapter[1], $adapter[1] + "`n`treturn")
    $path = Join-Path $run ([IO.Path]::GetFileName($adapter[0]))
    [IO.File]::WriteAllText($path,$body)
    $base = $base.Replace($adapter[0].Replace('/','\'),$path.Replace('\','/'))
}
$basePath = Join-Path $repo ('.battery-base-' + $nonce + '.dme')
[IO.File]::WriteAllText($basePath,$base)
$lines = @(('#define BATTERY_EVIDENCE_TOKEN "{0}"' -f $nonce),('#define BATTERY_EVIDENCE_COMMIT "{0}"' -f $commit),('#include "{0}"' -f $basePath.Replace('\','/')),'#include "tests/batteries/gameplay.dm"')
[IO.File]::WriteAllText($environment, ($lines -join [Environment]::NewLine))
Copy-Item -LiteralPath $environment -Destination (Join-Path $run 'validation-environment.dme.txt')
try {
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $environment 2>&1
    $build | Set-Content -LiteralPath (Join-Path $run 'build.log')
    $build | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($build -join [Environment]::NewLine) -notmatch '0 errors, 0 warnings') { throw 'Evidence build failed' }
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($environment,'dmb')) -Destination (Join-Path $run 'civ13.dmb')
    Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($environment,'rsc')) -Destination (Join-Path $run 'civ13.rsc')
}
finally { foreach ($path in @($environment,$basePath,[IO.Path]::ChangeExtension($environment,'dmb'),[IO.Path]::ChangeExtension($environment,'rsc'))) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } } }
Copy-Item -LiteralPath (Join-Path $repo 'config'),(Join-Path $repo 'UI') -Destination $run -Recurse
New-Item -ItemType Directory -Path (Join-Path $run 'SQL') | Out-Null
'valzargaming;Debug Host;65535|||' | Set-Content -LiteralPath (Join-Path $run 'SQL/admins.txt')
$configPath = Join-Path $run 'config/config.txt'
$config = Get-Content -LiteralPath $configPath -Raw
$config = [regex]::Replace($config,'(?m)^(HUB|GUEST_BAN|USE_JOB_WHITELIST)\s*\r?$','#$1')
$config = [regex]::Replace($config,'(?m)^HUB_BANNER_URL[^\r\n]*','#HUB_BANNER_URL')
$config = $config.Replace('SERVER_NAME Civilization 13',"SERVER_NAME Civ13 LOCAL 'battery' evidence $($commit.Substring(0,7))")
[IO.File]::WriteAllText($configPath, $config)
$started = (Get-Date).ToUniversalTime().ToString('o')
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $run 'civ13.dmb'),"$Port",'-invisible','-trusted','-logself') -WorkingDirectory $run -WindowStyle Hidden -PassThru
$metadata = [ordered]@{commit=$commit;scenario='battery';run=$run;port=$Port;nonce=$nonce;pid=$daemon.Id;started_utc=$started;binary_sha256=(Get-FileHash (Join-Path $run 'civ13.dmb')).Hash;scope='isolated-game with opt-in local test adapter'}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'session.json')
$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    if ($daemon.HasExited) { throw "Evidence daemon exited: $run" }
    $probe = [Net.Sockets.TcpClient]::new()
    try { $probe.Connect('127.0.0.1', $Port); $ready = $true } catch {} finally { $probe.Dispose() }
    if ($ready) { break }
    Start-Sleep -Milliseconds 500
}
if (!$ready) { Stop-Process -Id $daemon.Id; throw "Evidence daemon did not listen: $run" }
Write-Output "SESSION_JSON=$(Join-Path $run 'session.json')"
Write-Output "Connect a fresh Dream Seeker to byond://127.0.0.1:$Port; adapter nonce is in session.json."

