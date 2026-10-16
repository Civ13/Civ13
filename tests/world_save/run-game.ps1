param([Parameter(Mandatory=$true)][string]$ByondBin, [switch]$Visual, [switch]$PlayerIdentity, [switch]$IdentityNegativeControl, [ValidateRange(1,3600)][int]$TimeoutSeconds = 360)
$ErrorActionPreference = 'Stop'
if ($IdentityNegativeControl -and -not $PlayerIdentity) { throw 'Identity negative control requires -PlayerIdentity' }
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$probeSource = Join-Path $repoRoot '.world_save_probe.dme'
$identitySource = Join-Path $repoRoot '.world_save_identity_nomads.dm'
if (Test-Path -LiteralPath $probeSource) { throw 'Existing probe source must be preserved' }
if (Test-Path -LiteralPath $identitySource) { throw 'Existing identity source must be preserved' }
Push-Location -LiteralPath $repoRoot
try {
    $source = Get-Content -LiteralPath 'civ13.dme' -Raw
    if ($PlayerIdentity) {
        $mapInclude = '#include "maps\nomads\nomads.dmm"'
        if (($source.Split($mapInclude, [StringSplitOptions]::None).Count - 1) -ne 1) { throw 'Identity probe needs one default Nomads map include' }
        $source = $source.Replace($mapInclude, '#include "maps\nomads\nomads_gaia.dmm"')
    }
    if ($IdentityNegativeControl) {
        $nomads = (Get-Content -LiteralPath 'code/game/mob/living/carbon/human/nomads_spawn.dm' -Raw).Replace("`r`n", "`n")
        $guard = "`tif(persistence_restored)`n`t`treturn`n"
        if (($nomads.Split($guard, [StringSplitOptions]::None).Count - 1) -ne 1) { throw 'Identity guard mutation target changed' }
        [IO.File]::WriteAllText($identitySource, $nomads.Replace($guard, ''))
        $include = 'code\game\mob\living\carbon\human\nomads_spawn.dm'
        if (-not $source.Contains($include)) { throw 'Nomads include missing' }
        $source = $source.Replace($include, '.world_save_identity_nomads.dm')
    }
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
    if ($PlayerIdentity) { $parameters += '&player_identity=1' }
    [ordered]@{
        tested_commit = $testedCommit
        player_identity = [bool]$PlayerIdentity
        identity_negative_control = [bool]$IdentityNegativeControl
        map_source = $(if ($PlayerIdentity) { 'maps/nomads/nomads_gaia.dmm' } else { 'maps/nomads/nomads.dmm' })
        dmb_sha256 = (Get-FileHash -LiteralPath (Join-Path $testRun '.world_save_probe.dmb') -Algorithm SHA256).Hash.ToLowerInvariant()
        rsc_sha256 = (Get-FileHash -LiteralPath (Join-Path $testRun '.world_save_probe.rsc') -Algorithm SHA256).Hash.ToLowerInvariant()
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRun 'launch-inputs.json') -Encoding UTF8
    Write-Output "Isolated full-game runtime: $testRun"
    Push-Location -LiteralPath $testRun
    try {
        if ($Visual) {
            & (Join-Path $ByondBin 'dd.exe') '.world_save_probe.dmb' -invisible -safe -params $parameters -log 'startup.log'
            if ($LASTEXITCODE -ne 0) { throw 'Full-game daemon failed' }
        } else {
            $runtimeWatch = [Diagnostics.Stopwatch]::StartNew()
            $daemon = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @('.world_save_probe.dmb','-invisible','-safe','-params',$parameters,'-log','startup.log') -WorkingDirectory $testRun -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testRun 'daemon-stdout.log') -RedirectStandardError (Join-Path $testRun 'daemon-stderr.log')
            $timedOut = $false
            try {
                if (-not $daemon.WaitForExit($TimeoutSeconds * 1000)) {
                    $timedOut = $true
                    Stop-Process -Id $daemon.Id
                    $daemon.WaitForExit()
                    throw "Full-game probe timed out after $TimeoutSeconds seconds; logs retained at $testRun"
                }
                if ($daemon.ExitCode -ne 0) { throw "Full-game daemon failed with exit $($daemon.ExitCode); logs retained at $testRun" }
            } finally {
                if (-not $daemon.HasExited) { Stop-Process -Id $daemon.Id; $daemon.WaitForExit() }
                $runtimeWatch.Stop()
                [ordered]@{ pid = $daemon.Id; exit_code = $daemon.ExitCode; timed_out = $timedOut; elapsed_seconds = $runtimeWatch.Elapsed.TotalSeconds } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRun 'daemon-exit.json') -Encoding UTF8
                $daemon.Dispose()
            }
        }
    } finally { Pop-Location }
    $result = Get-Content -LiteralPath (Join-Path $testRun 'full_game_result.txt') -Raw
    Write-Output $result
    if ($IdentityNegativeControl) {
        $failure = (Get-Content -LiteralPath (Join-Path $testRun 'full_game_failure.txt') -Raw).Trim()
        if ($result -notmatch '^FAIL:' -or $failure -ne 'Deferred spawn overwrote saved identity') { throw 'Wrong identity negative-control failure' }
        Write-Output 'PASS: identity negative control caught deferred name overwrite'
    } elseif ($result -notmatch '^PASS:') { throw 'Full-game probe failed' }
} finally {
    Remove-Item -LiteralPath $probeSource
    if ($IdentityNegativeControl -and (Test-Path -LiteralPath $identitySource)) { Remove-Item -LiteralPath $identitySource }
    Pop-Location
}
