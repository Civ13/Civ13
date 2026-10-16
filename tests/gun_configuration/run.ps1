param([Parameter(Mandatory=$true)][string]$ByondBin, [ValidateRange(1,180)][int]$TimeoutSeconds = 90, [switch]$NegativeControl, [ValidateSet('install','remove','service','premature')][string]$FeedbackNegativeControl)
$ErrorActionPreference = 'Stop'
if ($NegativeControl -and $FeedbackNegativeControl) { throw 'Select one negative control at a time' }
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$prefix = '.gun_configuration_probe'
$generated = @('.dme','_world.dm','_globals.dm','.dmb','.rsc','_assembly.dm','_chat.dm') | ForEach-Object { Join-Path $repo ($prefix + $_) }
foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { throw "Preserve existing probe file: $path" } }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('civ13-gun_configuration-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$process = $null
try {
    $world = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/world.dm')).Replace("`r`n", "`n")
    $start = $world.IndexOf('/world/New()')
    $parent = $world.IndexOf("`n`t..()", $start)
    if ($start -lt 0 -or $parent -lt 0) { throw 'World startup isolation marker changed' }
    $world = $world.Remove($parent, 6).Replace('/world/New()', '/world/proc/unused_gun_configuration_startup()')
    $world = $world.Replace("/datum/global_init/New()`n", "/datum/global_init/New()`n`treturn`n")
    [IO.File]::WriteAllText($generated[1], $world)
    $globals = (Get-Content -Raw -LiteralPath (Join-Path $repo 'code/controllers/mc/globals.dm')).Replace("`r`n", "`n")
    $marker = "/datum/controller/global_vars/New()`n"
    if (!$globals.Contains($marker)) { throw 'Global isolation marker changed' }
    [IO.File]::WriteAllText($generated[2], $globals.Replace($marker, $marker + "`treturn`n"))
    $source = Get-Content -Raw -LiteralPath (Join-Path $repo 'civ13.dme')
    $source = $source.Replace('code\world.dm', $prefix + '_world.dm').Replace('code\controllers\mc\globals.dm', $prefix + '_globals.dm')
    $source = [regex]::Replace($source, '(?m)^#include ".*\.dmm"\s*$', '')
    # Capture the outgoing chat sink, retaining production action dispatch and messages.
    $chat = Get-Content -Raw -LiteralPath (Join-Path $repo 'code/modules/chat/chat.dm')
    if (!$chat.Contains('/proc/to_chat_wrapper(')) { throw 'Chat capture marker changed' }
    [IO.File]::WriteAllText($generated[6], $chat.Replace('/proc/to_chat_wrapper(', '/proc/configuration_unused_chat_wrapper('))
    $source = $source.Replace('code\modules\chat\chat.dm', $prefix + '_chat.dm')
    if ($NegativeControl -or $FeedbackNegativeControl) {
        $assembly = Get-Content -Raw -LiteralPath (Join-Path $repo 'code/modules/1713/gunsmithing/gun_configuration.dm')
        if ($NegativeControl) {
        $marker = ' || P.loc != H || H.get_active_hand() != P || !configuration_tools(P,H) || !configuration_compatible(P))'
        if (!$assembly.Contains($marker)) { throw 'Negative-control marker changed' }
        $assembly = $assembly.Replace($marker,')')
        } else {
            $patterns = @{
                install = '(?m)^\s*if \(!spawn_part\) to_chat\(H, SPAN_NOTICE\("You attach .*\r?\n'
                remove = '(?m)^\s*to_chat\(H, SPAN_NOTICE\("You remove .*\r?\n'
                service = '(?m)^\s*(?:if \(B\)|else) to_chat\(H, SPAN_NOTICE\("You finish (?:repairing|cleaning) .*\r?\n'
            }
            if ($FeedbackNegativeControl -eq 'premature') {
                $marker = "		var/complete = wait_for_configuration(H, 15)"
                if (!$assembly.Contains($marker)) { throw 'Premature feedback marker changed' }
                $assembly = $assembly.Replace($marker, "`t`t" + 'to_chat(H, SPAN_NOTICE("You attach [P.name] to [name]."))' + "`n" + $marker)
            } else {
                $pattern = $patterns[$FeedbackNegativeControl]
                if (![regex]::IsMatch($assembly,$pattern)) { throw 'Feedback negative-control marker changed' }
                $assembly = [regex]::Replace($assembly,$pattern,"`n")
            }
        }
        [IO.File]::WriteAllText($generated[5],$assembly)
        $source = $source.Replace('code\modules\1713\gunsmithing\gun_configuration.dm',$prefix + '_assembly.dm')
    }
    [IO.File]::WriteAllText($generated[0], $source + "`n#include `"tests/gun_configuration/probe.dm`"`n#include `"tests/gun_configuration/feedback.dm`"`n")
    $compiler = if ($IsWindows) { 'dm.exe' } else { 'DreamMaker' }
    $daemon = if ($IsWindows) { 'dd.exe' } else { 'DreamDaemon' }
    $compileLog = Join-Path $temp 'compile.log'
    $compileError = Join-Path $temp 'compile-stderr.log'
    $launchCompiler = @{FilePath=(Join-Path $ByondBin $compiler);ArgumentList=@('-max_errors','0',('"' + $generated[0] + '"'));WorkingDirectory=$repo;PassThru=$true;RedirectStandardOutput=$compileLog;RedirectStandardError=$compileError}
    if ($IsWindows) { $launchCompiler.WindowStyle = 'Hidden' }
    $process = Start-Process @launchCompiler
    if (!$process.WaitForExit(120000)) { throw 'Gun configuration compilation timed out' }
    $build = (Get-Content -Raw -LiteralPath $compileLog) + (Get-Content -Raw -LiteralPath $compileError)
    $build -split "`n" | Select-Object -Last 5
    if ($process.ExitCode -ne 0 -or $build -notmatch '0 errors, 0 warnings' -or $build -notmatch '516.1681') { throw 'Pinned gun_configuration probe compilation failed' }
    Copy-Item -LiteralPath $generated[3],$generated[4] -Destination $temp
    New-Item -ItemType Directory -Path (Join-Path $temp 'config') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'config/names') -Destination (Join-Path $temp 'config') -Recurse
    Copy-Item -LiteralPath (Join-Path $repo 'config/crafting') -Destination (Join-Path $temp 'config') -Recurse
    $commit = git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Git revision failed' }
    $dirty = git -C $repo status --porcelain -- code config tests/gun_configuration civ13.dme
    if ($LASTEXITCODE -ne 0) { throw 'Git status failed' }
    @{commit=$commit;dirty=[bool]$dirty;byond='516.1681';scope='production gun configuration/maintenance/serializer with startup and selected wait/inventory adapters';os=[Environment]::OSVersion.ToString()} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'metadata.json')
    $launch = @{FilePath=(Join-Path $ByondBin $daemon);ArgumentList=@(('"' + (Join-Path $temp ($prefix + '.dmb')) + '"'),'0','-invisible','-safe','-log','startup.log');WorkingDirectory=$temp;PassThru=$true}
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (!$process.WaitForExit(100)) {
        $process.Refresh()
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds -or $process.WorkingSet64 -gt 512MB -or $process.TotalProcessorTime.TotalSeconds -gt 40) { throw 'Gun configuration probe resource limit exceeded' }
    }
    Write-Output "Daemon exit: $($process.ExitCode)"
    if (!(Test-Path -LiteralPath (Join-Path $temp 'gun_configuration-result.txt'))) {
        Get-Content -LiteralPath (Join-Path $temp 'startup.log')
        throw 'Gun configuration probe did not produce a completion report'
    }
    $result = Get-Content -Raw -LiteralPath (Join-Path $temp 'gun_configuration-result.txt')
    Write-Output $result
    $runtimeLog = Get-Content -Raw -LiteralPath (Join-Path $temp 'startup.log')
    if ($runtimeLog -match 'GUN_CONFIGURATION RUNTIME|runtime error:' -or $process.ExitCode -ne 0) { throw 'Gun configuration runtime error' }
    if ($NegativeControl) {
        if ($result -notmatch '^FAIL: post-wait dropped part remains uninstalled') { throw 'Negative control was not detected by the intended regression' }
        Write-Output 'PASS: unsafe post-wait ownership negative control detected'
        return
    }
    if ($FeedbackNegativeControl) {
        $expected = switch ($FeedbackNegativeControl) {
            install { 'rail install emits one actor message' }
            remove { 'optic removal emits one actor message' }
            service { 'cleaning emits one actor message' }
            premature { 'cancelled installation emits no success' }
        }
        if (!$result.StartsWith('FAIL: ' + $expected)) { throw 'Feedback negative control missed its intended regression' }
        Write-Output "PASS: $FeedbackNegativeControl feedback negative control detected"
        return
    }
    if ($runtimeLog -match 'GUN_CONFIGURATION RUNTIME|runtime error:' -or $process.ExitCode -ne 0 -or $result -notmatch '^PASS:') { throw 'Gun configuration runtime regression failed' }
} finally {
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
    foreach ($path in $generated) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    Write-Output "Isolated gun_configuration evidence: $temp"
}

