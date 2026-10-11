param([Parameter(Mandatory=$true)][string]$ByondBin)
$ErrorActionPreference = 'Stop'
$repo = (Split-Path $PSScriptRoot -Parent).Replace('\', '/')
$fixture = Get-Content -LiteralPath (Join-Path $repo 'tests/memory/observer-counts.dm') -Raw
$fixture = $fixture.Replace('../../code/', "$repo/code/")
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('civ13-observer-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDir | Out-Null
$dm = Join-Path $testDir 'observer_counts.dm'
[IO.File]::WriteAllText($dm, $fixture)
$compile = & (Join-Path $ByondBin 'dm.exe') $dm 2>&1
$compile | Write-Output
if ($LASTEXITCODE -ne 0 -or ($compile -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Observer fixture compilation failed' }
$daemon = Start-Process -FilePath (Join-Path $ByondBin 'dreamdaemon.exe') -ArgumentList @((Join-Path $testDir 'observer_counts.dmb'), '-invisible', '-trusted', '-logself', '-close') -WindowStyle Hidden -PassThru
if (!$daemon.WaitForExit(60000)) { $daemon.Kill(); throw "Observer fixture exceeded 60 seconds. Evidence: $testDir" }
$logPath = Join-Path $testDir 'observer_counts.log'
if (!(Test-Path -LiteralPath $logPath)) { throw "Daemon exit=$($daemon.ExitCode); missing log. Evidence: $testDir" }
$log = Get-Content -LiteralPath $logPath -Raw
$log | Write-Output
Write-Output "Evidence: $testDir"
if ($log -notmatch 'PASS observer bookkeeping' -or $log -match 'FAIL|runtime error') { throw 'Observer regression failed' }
