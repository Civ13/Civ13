param([Parameter(Mandatory=$true)][string]$ByondBin, [ValidateRange(1,180)][int]$TimeoutSeconds = 90)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$prefix = '.car_workshop_probe'
$generated = @('.dme','_world.dm','_globals.dm','.dmb','.rsc') | ForEach-Object { Join-Path $repo ($prefix + $_) }
foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { throw "Preserve existing probe file: $path" } }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-cars-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$process = $null
try {
    $world = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/world.dm')).Replace("`r`n", "`n")
    $start = $world.IndexOf('/world/New()')
    $parent = $world.IndexOf("`n`t..()", $start)
    if ($start -lt 0 -or $parent -lt 0) { throw 'World startup isolation marker changed' }
    $world = $world.Remove($parent, 6).Replace('/world/New()', '/world/proc/unused_car_startup()')
    $world = $world.Replace("/datum/global_init/New()`n", "/datum/global_init/New()`n`treturn`n")
    [IO.File]::WriteAllText($generated[1], $world)
    $globals = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/controllers/mc/globals.dm')).Replace("`r`n", "`n")
    $marker = "/datum/controller/global_vars/New()`n"
    if (!$globals.Contains($marker)) { throw 'Global isolation marker changed' }
    [IO.File]::WriteAllText($generated[2], $globals.Replace($marker, $marker + "`treturn`n"))
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    $source = $source.Replace('code\world.dm', $prefix + '_world.dm').Replace('code\controllers\mc\globals.dm', $prefix + '_globals.dm')
    $source = [regex]::Replace($source, '(?m)^#include ".*\.dmm"\s*$', '')
    [IO.File]::WriteAllText($generated[0], $source + "`n#include `"tests/car_workshop/probe.dm`"`n")
    $compiler = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemon = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    $build = & (Join-Path $ByondBin $compiler) -max_errors 0 $generated[0] 2>&1
    $exitCode = $LASTEXITCODE
    $build | Set-Content -LiteralPath (Join-Path $temp 'compile.log')
    $build | Select-Object -Last 5
    if ($exitCode -ne 0 -or ($build -join "`n") -notmatch '0 errors, 0 warnings' -or ($build -join "`n") -notmatch '516.1681') { throw 'Pinned car probe compilation failed' }
    Copy-Item -LiteralPath $generated[3],$generated[4] -Destination $temp
    $commit = git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Git revision failed' }
    $dirty = git -C $repo status --porcelain -- code config tests/car_workshop civ13.dme
    if ($LASTEXITCODE -ne 0) { throw 'Git status failed' }
    @{commit=$commit;dirty=[bool]$dirty;byond='516.1681';scope='production construction/vehicle/serializer with startup and actor wait adapters';os=[Environment]::OSVersion.ToString()} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'metadata.json')
    $launch = @{FilePath=(Join-Path $ByondBin $daemon);ArgumentList=@(('"' + (Join-Path $temp ($prefix + '.dmb')) + '"'),'-invisible','-safe','-log','startup.log');WorkingDirectory=$temp;PassThru=$true}
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 512MB -or $process.TotalProcessorTime.TotalSeconds -gt 40) { throw 'Car probe resource limit exceeded' }
    }
    $result = Get-Content -Raw -LiteralPath (Join-Path $temp 'car-result.txt')
    Write-Output $result
    if ($process.ExitCode -ne 0 -or $result -notmatch '^PASS:') { throw 'Car runtime regression failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    Write-Output "Isolated car evidence: $temp"
}
