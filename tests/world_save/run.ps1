param(
    [Parameter(Mandatory=$true)][string]$ByondBin,
    [switch]$Large
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$compiler = Join-Path $ByondBin 'dm.exe'
$daemon = Join-Path $ByondBin 'dd.exe'
Push-Location -LiteralPath $repoRoot
try {
    $build = & $compiler -max_errors 0 'tests/world_save/roundtrip.dme' 2>&1
    $build | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings') {
        throw 'Regression world compilation failed'
    }
    $testRun = Join-Path $env:TEMP ('civ13-world-save-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $testRun | Out-Null
    Copy-Item -LiteralPath 'tests/world_save/roundtrip.dmb' -Destination $testRun
    Copy-Item -LiteralPath 'tests/world_save/roundtrip.rsc' -Destination $testRun
    Push-Location -LiteralPath $testRun
    try {
        $daemonArgs = @('roundtrip.dmb', '-invisible', '-safe', '-log', 'runtime.log')
        if ($Large) { $daemonArgs += @('-params', 'large=1') }
        & $daemon @daemonArgs
        if ($LASTEXITCODE -ne 0) { throw 'Regression daemon failed' }
    } finally { Pop-Location }
    Get-Content -LiteralPath (Join-Path $testRun 'runtime.log')
    if ((Get-Content -LiteralPath (Join-Path $testRun 'result.txt') -Raw).Trim() -ne 'PASS') {
        throw 'Regression world failed'
    }
    Write-Output "Evidence retained at $testRun"
} finally {
    Pop-Location
}
