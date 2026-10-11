param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual)
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
    $parameters = if ($Visual) { 'visual=1' } else { '' }
    Write-Output "Isolated full-game runtime: $testRun"
    & (Join-Path $ByondBin 'dd.exe') (Join-Path $testRun '.world_save_probe.dmb') -invisible -safe -params $parameters -log (Join-Path $testRun 'startup.log')
    $result = Get-Content -LiteralPath (Join-Path $testRun 'full_game_result.txt') -Raw
    Write-Output $result
    if ($result -notmatch '^PASS:') { throw 'Full-game probe failed' }
} finally {
    Remove-Item -LiteralPath $probeSource
    Pop-Location
}
