# Builds the launcher voice apps (issue #5122) against an external Discord
# Social SDK directory, then packs them for testers. Not run in CI: the SDK is
# a vendor download and is never committed.
#
#   .\Build-VoiceProto.ps1 -SdkRoot D:\GitHub\discord-social-sdk-1.10.19337
#
# Output in build\voice, with the SDK runtime beside them:
# - civ13-voice.exe: Phase 3 region voice, started by the launcher.
# - civ13-voice-proto.exe: the Phase 2 two-player prototype.
# build\civ13-voice.zip holds the same files. Unzip it so the launcher has
# voice\civ13-voice.exe beside Civ13.exe.
param([Parameter(Mandatory = $true)][string]$SdkRoot)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
$include = Join-Path $SdkRoot 'include'
$lib = Join-Path $SdkRoot 'lib/release/discord_partner_sdk.lib'
$bin = Join-Path $SdkRoot 'bin/release'
foreach ($required in @((Join-Path $include 'discordpp.h'), $lib, (Join-Path $bin 'discord_partner_sdk.dll'))) {
    if (!(Test-Path -LiteralPath $required)) { throw "Discord Social SDK file missing: $required" }
}
$out = Join-Path $root 'build/voice'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Installed MSVC discovery tool unavailable; no installation attempted.' }
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$installation) { throw 'Installed x64 MSVC tools unavailable; no installation attempted.' }
$dev = Join-Path $installation 'Common7/Tools/VsDevCmd.bat'
foreach ($value in @($root, $out, $dev, $include, $lib)) {
    if ($value -match '["%\r\n]') { throw 'Unsupported command path character.' }
}
# The SDK header is compiled as an external include with its own warnings
# silenced. Warnings in the prototype print but do not stop a test build.
$flags = '/nologo /std:c++20 /EHsc /W4 /MT /external:W0'
$commands = @(
    '@echo off',
    "call `"$dev`" -no_logo -arch=x64 -host_arch=x64 >nul",
    'if errorlevel 1 exit /b 1',
    "cl $flags /external:I`"$include`" /I`"$root/voice`" /Fo:`"$out/`" /Fe:`"$out/civ13-voice-proto.exe`" `"$root/voice/voice_proto.cpp`" `"$lib`" user32.lib",
    'if errorlevel 1 exit /b 1',
    "cl $flags /external:I`"$include`" /I`"$root/voice`" /Fo:`"$out/`" /Fe:`"$out/civ13-voice.exe`" `"$root/voice/voice_client.cpp`" `"$lib`" ws2_32.lib winhttp.lib bcrypt.lib",
    'if errorlevel 1 exit /b 1',
    'exit /b 0'
)
$batch = Join-Path $out 'compile.cmd'
Set-Content -LiteralPath $batch -Value $commands -Encoding ascii
$log = Join-Path $root 'build/voice-compile.log'
& $env:ComSpec /d /s /c "`"$batch`" > `"$log`" 2>&1"
$code = $LASTEXITCODE
Get-Content -LiteralPath $log
if ($code -ne 0) { throw "Voice compile failed with exit $code." }
Copy-Item -Path (Join-Path $bin '*') -Destination $out -Force
$notices = Join-Path $SdkRoot 'License-Notices.txt'
if (Test-Path -LiteralPath $notices) { Copy-Item -LiteralPath $notices -Destination $out -Force }
Remove-Item -Path (Join-Path $out '*.obj'), $batch -ErrorAction SilentlyContinue
$zip = Join-Path $root 'build/civ13-voice.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
Write-Output "Built $(Join-Path $out 'civ13-voice.exe') and $(Join-Path $out 'civ13-voice-proto.exe')"
Write-Output "Packed $zip; unzip it into a folder named voice beside Civ13.exe"
