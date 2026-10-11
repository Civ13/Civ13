param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [Parameter(Mandatory=$true)][ValidateSet('water','observer','season')][string]$Scenario,
    [ValidateRange(1024,65535)][int]$Port = 16992
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'gameplay-evidence-common.ps1')
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$commit = Get-EvidenceCheckoutCommit -Repository $repo
$nonce = [guid]::NewGuid().ToString('N')
$run = Join-Path ([IO.Path]::GetTempPath()) ('civ13-evidence-' + $Scenario + '-' + $nonce)
New-Item -ItemType Directory -Path $run | Out-Null
$environment = Join-Path $repo ('.memory-evidence-' + $nonce + '.dme')
$lines = @(('#define MEMORY_EVIDENCE_TOKEN "{0}"' -f $nonce),('#define MEMORY_EVIDENCE_COMMIT "{0}"' -f $commit),('#define MEMORY_EVIDENCE_{0}' -f $Scenario.ToUpper()),'#include "civ13.dme"')
if ($Scenario -ne 'season') { $lines += '#include "tests/memory/' + $Scenario + '-gameplay.dm"' }
$lines += '#include "tests/memory/gameplay-topic.dm"'
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
finally { Remove-EvidenceBuildOutputs -Environment $environment -Repository $repo }
Copy-Item -LiteralPath (Join-Path $repo 'config'),(Join-Path $repo 'UI') -Destination $run -Recurse
New-Item -ItemType Directory -Path (Join-Path $run 'SQL') | Out-Null
'valzargaming;Debug Host;65535|||' | Set-Content -LiteralPath (Join-Path $run 'SQL/admins.txt')
$configPath = Join-Path $run 'config/config.txt'
$config = Get-Content -LiteralPath $configPath -Raw
$config = [regex]::Replace($config,'(?m)^(HUB|GUEST_BAN|USE_JOB_WHITELIST)\s*\r?$','#$1')
$config = [regex]::Replace($config,'(?m)^HUB_BANNER_URL[^\r\n]*','#HUB_BANNER_URL')
$config = $config.Replace('SERVER_NAME Civilization 13',"SERVER_NAME Civ13 LOCAL $Scenario evidence $($commit.Substring(0,7))")
[IO.File]::WriteAllText($configPath, $config)
$started = (Get-Date).ToUniversalTime().ToString('o')
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $run 'civ13.dmb'),"$Port",'-invisible','-trusted','-logself') -WorkingDirectory $run -WindowStyle Hidden -PassThru
$metadata = [ordered]@{commit=$commit;scenario=$Scenario;run=$run;port=$Port;nonce=$nonce;pid=$daemon.Id;started_utc=$started;binary_sha256=(Get-FileHash (Join-Path $run 'civ13.dmb')).Hash;scope='isolated-game with opt-in local test adapter'}
$pendingSession = Join-Path $run 'pending-session.json'
$metadata | ConvertTo-Json | Set-Content -LiteralPath $pendingSession
try {
    $statusQuery = { & (Join-Path $PSScriptRoot 'query-gameplay-evidence.ps1') -SessionJson $pendingSession -ByondBin $ByondBin -Action status -PassThru }
    $ready = Wait-EvidenceServerReady -Process $daemon -StatusQuery $statusQuery -ExpectedCommit $commit
    Move-Item -LiteralPath $pendingSession -Destination (Join-Path $run 'session.json')
}
catch {
    $daemon.Refresh()
    if (!$daemon.HasExited) { $daemon.Kill(); $null = $daemon.WaitForExit(5000) }
    throw
}
Write-Output "SESSION_JSON=$(Join-Path $run 'session.json')"
Write-Output "Connect a fresh Dream Seeker to byond://127.0.0.1:$Port; adapter nonce is in session.json."
