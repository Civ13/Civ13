param([Parameter(Mandatory=$true)][string]$ByondBin)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$generated = @('.chemistry_probe.dme', '.chemistry_world.dm', '.chemistry_probe.dmb', '.chemistry_probe.rsc')
foreach ($path in $generated) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot $path)) { throw "Preserve existing $path" }
}
$testRun = Join-Path $env:TEMP ('civ13-chemistry-' + [guid]::NewGuid())
Push-Location -LiteralPath $repoRoot
try {
    # Compile the production sources, replacing only normal world startup.
    # The probe runs real holders/reactions without schedulers or live adapters.
    $world = Get-Content -LiteralPath 'code/world.dm' -Raw
    $world = $world.Replace('/world/New()', '/world/proc/unused_chemistry_startup()')
    # The renamed startup is never called and no longer has a parent New().
    $startupOffset = $world.IndexOf('/world/proc/unused_chemistry_startup()')
    $world = [regex]::new('(?m)^\t\.\.\(\)\r?$').Replace($world, '', 1, $startupOffset)
    [IO.File]::WriteAllText((Join-Path $repoRoot '.chemistry_world.dm'), $world)
    $source = Get-Content -LiteralPath 'civ13.dme' -Raw
    $source = $source.Replace('code\world.dm', '.chemistry_world.dm')
    [IO.File]::WriteAllText((Join-Path $repoRoot '.chemistry_probe.dme'), $source + "`n#include `"tests/chemistry/polyethylene.dm`"`n")
    $build = & (Join-Path $ByondBin 'dm.exe') -max_errors 0 '.chemistry_probe.dme' 2>&1
    $build | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') { throw 'Compilation failed' }
    New-Item -ItemType Directory -Path $testRun | Out-Null
    $build | Set-Content -LiteralPath (Join-Path $testRun 'compile.log')
    Copy-Item -LiteralPath '.chemistry_probe.dmb', '.chemistry_probe.rsc' -Destination $testRun
    Copy-Item -LiteralPath 'config' -Destination $testRun -Recurse
    $testedCommit = git rev-parse HEAD
    Write-Output "Tested commit: $testedCommit"
    Write-Output "Isolated runtime and retained logs: $testRun"
    $runtime = Start-Process -FilePath (Join-Path $ByondBin 'dd.exe') -ArgumentList @((Join-Path $testRun '.chemistry_probe.dmb'), '-invisible', '-safe', '-close', '-params', "tested_commit=$testedCommit", '-log', (Join-Path $testRun 'runtime.log')) -WorkingDirectory $testRun -WindowStyle Hidden -PassThru
    if (!$runtime.WaitForExit(30000)) {
        Stop-Process -Id $runtime.Id
        throw 'Task-owned chemistry probe exceeded 30 seconds'
    }
    $result = Get-Content -LiteralPath (Join-Path $testRun 'chemistry_result.txt') -Raw
    Write-Output $result
    if ($result -notmatch '^PASS:') { throw 'Chemistry probe failed' }
} finally {
    foreach ($path in $generated) {
        $absolute = Join-Path $repoRoot $path
        if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute }
    }
    Pop-Location
}
