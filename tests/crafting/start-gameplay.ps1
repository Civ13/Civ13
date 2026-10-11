param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [ValidateRange(1024,65535)][int]$Port = 16998
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = (git -C $repo rev-parse HEAD).Trim()
if (git -C $repo status --porcelain) { throw 'Use a clean committed checkout for evidence' }
if (Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue) { throw 'Requested local evidence port is occupied' }
$nonce = [guid]::NewGuid().ToString('N')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-evidence-' + 'crafting' + '-' + $nonce)
New-Item -ItemType Directory -Path $run | Out-Null
$environment = Join-Path $repo ('.crafting-evidence-' + $nonce + '.dme')
$base = Get-Content -LiteralPath (Join-Path $repo 'civ13.dme') -Raw
foreach ($adapter in @(@('code/modules/webhooks/webhooks.dm','/proc/webhook_send(method, data)'), @('code/modules/admin/ToRban.dm','/proc/ToRban_update()'), @('code/processes/python.dm','/process/python/proc/execute(var/command, var/list/py_args = list())'))) {
    $body = Get-Content -LiteralPath (Join-Path $repo $adapter[0]) -Raw
    if ([regex]::Matches($body,[regex]::Escape($adapter[1])).Count -ne 1) { throw 'External adapter signature changed' }
    $body = $body.Replace($adapter[1], $adapter[1] + "`n`treturn")
    $path = Join-Path $run ([IO.Path]::GetFileName($adapter[0]))
    [IO.File]::WriteAllText($path,$body)
    $base = $base.Replace($adapter[0].Replace('/','\'),$path.Replace('\','/'))
}
# Inject only dialog selections in the isolated anvil copy. No recipe logic is rewritten.
$anvilRelative = 'code/game/objects/structures/blacksmithing/blacksmithing.dm'
$anvilBody = Get-Content -LiteralPath (Join-Path $repo $anvilRelative) -Raw
if (!$anvilBody.Contains('WWinput(')) { throw 'Anvil prompt wiring changed' }
$anvilBody = $anvilBody.Replace('WWinput(', 'crafting_evidence_prompt(')
$anvilPath = Join-Path $run 'blacksmithing.dm'
[IO.File]::WriteAllText($anvilPath,$anvilBody)
$includeNeedle = $anvilRelative.Replace('/','\')
if ([regex]::Matches($base,[regex]::Escape($includeNeedle)).Count -ne 1) { throw 'Anvil include wiring changed' }
$base = $base.Replace($includeNeedle,$anvilPath.Replace('\','/'))
$basePath = Join-Path $repo ('.crafting-base-' + $nonce + '.dme')
[IO.File]::WriteAllText($basePath,$base)
$lines = @(('#define CRAFTING_EVIDENCE_TOKEN "{0}"' -f $nonce),('#define CRAFTING_EVIDENCE_COMMIT "{0}"' -f $commit),('#include "{0}"' -f $basePath.Replace('\','/')),'#include "tests/crafting/gameplay.dm"')
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
$config = $config.Replace('SERVER_NAME Civilization 13',"SERVER_NAME Civ13 LOCAL 'crafting' evidence $($commit.Substring(0,7))")
[IO.File]::WriteAllText($configPath, $config)
$started = (Get-Date).ToUniversalTime().ToString('o')
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $run 'civ13.dmb'),"$Port",'-invisible','-trusted','-logself') -WorkingDirectory $run -WindowStyle Hidden -PassThru
$metadata = [ordered]@{commit=$commit;scenario='crafting';run=$run;port=$Port;nonce=$nonce;pid=$daemon.Id;started_utc=$started;binary_sha256=(Get-FileHash (Join-Path $run 'civ13.dmb')).Hash;scope='isolated-game with opt-in local test adapter'}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'session.json')
Write-Output "SESSION_JSON=$(Join-Path $run 'session.json')"
Write-Output "Connect a fresh Dream Seeker to byond://127.0.0.1:$Port; adapter nonce is in session.json."

