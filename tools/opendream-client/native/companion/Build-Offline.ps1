param([string]$SdkInclude = '')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Installed MSVC discovery tool unavailable; no installation attempted.' }
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$installation) { throw 'Installed x64 MSVC tools unavailable; no installation attempted.' }
$dev = Join-Path $installation 'Common7/Tools/VsDevCmd.bat'
if (!(Test-Path -LiteralPath $dev)) { throw 'Installed MSVC environment unavailable.' }
foreach ($value in @($root, $build, $dev, $SdkInclude)) {
    if ($value -match '["%\r\n]') { throw 'Unsupported command path character.' }
}
$commands = @('@echo off', "call `"$dev`" -no_logo -arch=x64 -host_arch=x64 >nul", 'if errorlevel 1 exit /b 1')
$flags = '/nologo /std:c++20 /EHsc /W4 /WX /MT'
$commands += "cl $flags /Fe:`"$build/peer-tests.exe`" `"$root/peer.cpp`" `"$root/tests/peer_tests.cpp`""
$commands += 'if errorlevel 1 exit /b 1'
if ($SdkInclude) {
    $SdkInclude = (Resolve-Path -LiteralPath $SdkInclude).Path
    if (!(Test-Path -LiteralPath (Join-Path $SdkInclude 'cdiscord.h'))) { throw 'Explicit official cdiscord.h directory required.' }
    # DISCORD_API is intentionally empty: every used SDK symbol is provided by
    # original fake functions, not an import library, DLL, installer or service.
    $commands += "cl $flags /DDISCORD_API= /I`"$SdkInclude`" /Fe:`"$build/sdk-tests.exe`" `"$root/peer.cpp`" `"$root/discord_backend.cpp`" `"$root/tests/sdk_tests.cpp`""
    $commands += 'if errorlevel 1 exit /b 1'
    Write-Output ('External header SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $SdkInclude 'cdiscord.h') -Algorithm SHA256).Hash)
}
$commands += 'exit /b 0'
$batch = Join-Path $build 'compile.cmd'
Set-Content -LiteralPath $batch -Value $commands -Encoding ascii
function Invoke-Bounded([string]$executable, [string]$arguments, [string]$name) {
    $stdout = Join-Path $build "$name.log"
    $stderr = Join-Path $build "$name.stderr.log"
    $options = @{FilePath=$executable; WorkingDirectory=$build; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=$stdout; RedirectStandardError=$stderr}
    if ($arguments) { $options.ArgumentList=$arguments }
    $process = Start-Process @options
    if (!$process.WaitForExit(45000)) { $process.Kill(); [void]$process.WaitForExit(5000); throw "Owned offline $name process exceeded 45 seconds." }
    $process.WaitForExit()
    Get-Content -LiteralPath $stdout
    Get-Content -LiteralPath $stderr
    if ($process.ExitCode -ne 0) { throw "Offline $name failed with exit $($process.ExitCode)." }
}
Invoke-Bounded $env:ComSpec ('/d /s /c ""' + $batch + '""') 'compile'
Invoke-Bounded (Join-Path $build 'peer-tests.exe') '' 'peer-tests'
if ($SdkInclude) { Invoke-Bounded (Join-Path $build 'sdk-tests.exe') '' 'sdk-tests' }
