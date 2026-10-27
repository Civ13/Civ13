param([Parameter(Mandatory=$true)][string]$ByondBin, [ValidateRange(1,180)][int]$TimeoutSeconds = 90, [switch]$NegativeControl, [switch]$ForgeMergeControl)
$ErrorActionPreference = 'Stop'
if ($NegativeControl -and $ForgeMergeControl) { throw 'Choose one negative control' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$prefix = '.blackpowder_probe'
$generated = @('.dme','_world.dm','_globals.dm','.dmb','.rsc','_assembly.dm') | ForEach-Object { Join-Path $repo ($prefix + $_) }
foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { throw "Preserve existing probe file: $path" } }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-blackpowder-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$process = $null
try {
    $world = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/world.dm')).Replace("`r`n", "`n")
    $start = $world.IndexOf('/world/New()')
    $parent = $world.IndexOf("`n`t..()", $start)
    if ($start -lt 0 -or $parent -lt 0) { throw 'World startup isolation marker changed' }
    $world = $world.Remove($parent, 6).Replace('/world/New()', '/world/proc/unused_blackpowder_startup()')
    $world = $world.Replace("/datum/global_init/New()`n", "/datum/global_init/New()`n`treturn`n")
    [IO.File]::WriteAllText($generated[1], $world)
    $globals = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/controllers/mc/globals.dm')).Replace("`r`n", "`n")
    $marker = "/datum/controller/global_vars/New()`n"
    if (!$globals.Contains($marker)) { throw 'Global isolation marker changed' }
    [IO.File]::WriteAllText($generated[2], $globals.Replace($marker, $marker + "`treturn`n"))
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    $source = $source.Replace('code\world.dm', $prefix + '_world.dm').Replace('code\controllers\mc\globals.dm', $prefix + '_globals.dm')
    $source = [regex]::Replace($source, '(?m)^#include ".*\.dmm"\s*$', '')
    if ($NegativeControl) {
        $assembly = Get-Content -Raw -LiteralPath (Join-Path $repo 'code/modules/1713/gunsmithing/blackpowder_assembly.dm')
        $marker = 'barrel_attached != expected_stage || !compatible_part(P))'
        if (!$assembly.Contains($marker)) { throw 'Negative-control marker changed' }
        [IO.File]::WriteAllText($generated[5],$assembly.Replace($marker,'barrel_attached != expected_stage)'))
        $source = $source.Replace('code\modules\1713\gunsmithing\blackpowder_assembly.dm',$prefix + '_assembly.dm')
    }
    if ($ForgeMergeControl) { $source = "#define FORGE_MERGE_CONTROL`n" + $source }
    [IO.File]::WriteAllText($generated[0], $source + "`n#include `"tests/blackpowder/probe.dm`"`n")
    $compiler = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemon = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    $compileLog = Join-Path $temp 'compile.log'
    $compileError = Join-Path $temp 'compile-stderr.log'
    $launchCompiler = @{FilePath=(Join-Path $ByondBin $compiler);ArgumentList=@('-max_errors','0',('"' + $generated[0] + '"'));WorkingDirectory=$repo;PassThru=$true;RedirectStandardOutput=$compileLog;RedirectStandardError=$compileError}
    if ($IsWindows) { $launchCompiler.WindowStyle = 'Hidden' }
    $process = Start-Process @launchCompiler
    if (!$process.WaitForExit(120000)) { throw 'Blackpowder compilation timed out' }
    $build = (Get-Content -Raw -LiteralPath $compileLog) + (Get-Content -Raw -LiteralPath $compileError)
    $build -split "`n" | Select-Object -Last 5
    if ($process.ExitCode -ne 0 -or $build -notmatch '0 errors, 0 warnings' -or $build -notmatch '516.1681') { throw 'Pinned blackpowder probe compilation failed' }
    Copy-Item -LiteralPath $generated[3],$generated[4] -Destination $temp
    New-Item -ItemType Directory -Path (Join-Path $temp 'config') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'config/crafting') -Destination (Join-Path $temp 'config') -Recurse
    $commit = git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Git revision failed' }
    $dirty = git -C $repo status --porcelain -- code config tests/blackpowder civ13.dme
    if ($LASTEXITCODE -ne 0) { throw 'Git status failed' }
    @{commit=$commit;dirty=[bool]$dirty;byond='516.1681';scope='production assembly/menus/research/serializer with startup and selected wait/inventory adapters';os=[Environment]::OSVersion.ToString()} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'metadata.json')
    $launch = @{FilePath=(Join-Path $ByondBin $daemon);ArgumentList=@(('"' + (Join-Path $temp ($prefix + '.dmb')) + '"'),'0','-invisible','-trusted','-log','startup.log');WorkingDirectory=$temp;PassThru=$true}
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 512MB -or $process.TotalProcessorTime.TotalSeconds -gt 40) { throw 'Blackpowder probe resource limit exceeded' }
    }
    Write-Output "Daemon exit: $($process.ExitCode)"
    if (!(Test-Path -LiteralPath (Join-Path $temp 'blackpowder-result.txt'))) {
        Get-Content -LiteralPath (Join-Path $temp 'startup.log')
        throw 'Blackpowder probe did not produce a completion report'
    }
    $result = Get-Content -Raw -LiteralPath (Join-Path $temp 'blackpowder-result.txt')
    Write-Output $result
    $runtimeLog = Get-Content -Raw -LiteralPath (Join-Path $temp 'startup.log')
    if ($runtimeLog -match '(?i)BLACKPOWDER RUNTIME|runtime error:|bad ref|BUG:|##ERROR:|RUNTIME:|infinite loop|segmentation|assertion failed|fatal error' -or $process.ExitCode -ne 0) { throw 'Unexpected blackpowder engine diagnostic' }
    if ($ForgeMergeControl) {
        if ($runtimeLog -match 'BLACKPOWDER RUNTIME|runtime error:' -or $process.ExitCode -ne 0 -or $result -notmatch '^FAIL: fresh forge material is live at ') { throw 'Forge merge setup control was not detected' }
        Write-Output 'PASS: auto-merged forge input control detected'
        return
    }
    if ($NegativeControl) {
        if ($result -notmatch '^FAIL: post-wait missing flint rejects final assembly') { throw 'Negative control was not detected by the intended regression' }
        Write-Output 'PASS: unsafe post-wait compatibility negative control detected'
        return
    }
    if ($runtimeLog -match 'BLACKPOWDER RUNTIME|runtime error:' -or $process.ExitCode -ne 0 -or $result -notmatch '^PASS:') { throw 'Blackpowder runtime regression failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    Write-Output "Isolated blackpowder evidence: $temp"
}
