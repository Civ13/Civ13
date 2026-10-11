param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [ValidateRange(1,3600)][int]$TimeoutSeconds = 360)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$probeSource = Join-Path $repoRoot '.world_save_probe.dme'
if (Test-Path -LiteralPath $probeSource) { throw 'Existing probe source must be preserved' }
Push-Location -LiteralPath $repoRoot
try {
    $source = Get-Content -LiteralPath 'civ13.dme' -Raw
    [IO.File]::WriteAllText($probeSource, $source + "`n#include `"tests/world_save/full_game_probe.dm`"`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 $probeSource 2>&1
    $build | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') {
        throw 'Full-game probe compilation failed'
    }
    $testRun = Join-Path $env:TEMP ('civ13-world-save-game-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $testRun | Out-Null
    Copy-Item -LiteralPath '.world_save_probe.dmb' -Destination $testRun
    Copy-Item -LiteralPath '.world_save_probe.rsc' -Destination $testRun
    # Public checkout defaults and name/crafting assets, no live server files.
    Copy-Item -LiteralPath 'config' -Destination $testRun -Recurse
    $testedCommit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot identify tested commit' }
    $parameters = "tested_commit=$testedCommit" + $(if ($Visual) { '&visual=1' } else { '' })
    Write-Output "Isolated full-game runtime: $testRun"
    Push-Location -LiteralPath $testRun
    try {
        if ($Visual) {
            & (Join-Path $ByondBin 'dd.exe') '.world_save_probe.dmb' -invisible -safe -params $parameters -log 'startup.log'
            if ($LASTEXITCODE -ne 0) { throw 'Full-game daemon failed' }
        } else {
            $daemon = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @('.world_save_probe.dmb','-invisible','-safe','-params',$parameters,'-log','startup.log') -WorkingDirectory $testRun -WindowStyle Hidden -PassThru
            try {
                if (-not $daemon.WaitForExit($TimeoutSeconds * 1000)) {
                    Stop-Process -Id $daemon.Id
                    $daemon.WaitForExit()
                    throw "Full-game probe timed out after $TimeoutSeconds seconds; logs retained at $testRun"
                }
                if ($daemon.ExitCode -ne 0) { throw 'Full-game daemon failed' }
            } finally {
                if (-not $daemon.HasExited) { Stop-Process -Id $daemon.Id; $daemon.WaitForExit() }
                $daemon.Dispose()
            }
        }
    } finally { Pop-Location }
    $result = Get-Content -LiteralPath (Join-Path $testRun 'full_game_result.txt') -Raw
    Write-Output $result
    if ($result -notmatch '^PASS:') { throw 'Full-game probe failed' }
} finally {
    Remove-Item -LiteralPath $probeSource
    Pop-Location
}
