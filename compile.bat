@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Compile the current map and options in civ13.dme. Never launch the game.
if not "%~1"=="" goto :usage
set "CIV13_ROOT=%~dp0"
if not exist "%CIV13_ROOT%civ13.dme" (
    echo ERROR: civ13.dme is missing beside this script. 1>&2
    exit /b 1
)

rem BYOND_BIN is an optional directory containing the Windows console compiler.
set "CIV13_COMPILER="
if defined BYOND_BIN (
    set "CIV13_COMPILER=%BYOND_BIN%\dm.exe"
    goto :check_compiler
)
for %%C in (dm.exe) do set "CIV13_COMPILER=%%~$PATH:C"
if defined CIV13_COMPILER goto :check_compiler
if exist "%ProgramFiles(x86)%\BYOND\bin\dm.exe" (
    set "CIV13_COMPILER=%ProgramFiles(x86)%\BYOND\bin\dm.exe"
    goto :check_compiler
)
if exist "%ProgramFiles%\BYOND\bin\dm.exe" set "CIV13_COMPILER=%ProgramFiles%\BYOND\bin\dm.exe"

:check_compiler
if not exist "%CIV13_COMPILER%" (
    echo ERROR: BYOND console compiler dm.exe was not found. 1>&2
    echo Install the version in tools\byond\version.json or set BYOND_BIN to its bin directory. 1>&2
    exit /b 1
)
rem Pass paths through the environment so spaces and shell metacharacters are safe.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -Command "try { $pin = (Get-Content -LiteralPath (Join-Path $env:CIV13_ROOT 'tools\byond\version.json') -Raw | ConvertFrom-Json).version; if ($pin -notmatch '^\d+\.\d+$') { throw 'Invalid BYOND version manifest.' }; $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($env:CIV13_COMPILER); $actual = '{0}.{1}' -f $v.FileBuildPart, $v.FilePrivatePart; if ($actual -ne $pin) { throw ('Expected BYOND {0}, found {1}. Set BYOND_BIN to the matching bin directory.' -f $pin, $actual) }; Write-Host ('Using BYOND {0}: {1}' -f $actual, $env:CIV13_COMPILER) } catch { Write-Error $_; exit 1 }"
if errorlevel 1 exit /b 1

pushd "%CIV13_ROOT%"
if errorlevel 1 exit /b 1
"%CIV13_COMPILER%" -max_errors 0 civ13.dme
set "CIV13_RESULT=%ERRORLEVEL%"
popd
if not "%CIV13_RESULT%"=="0" (
    echo ERROR: Compilation failed with exit code %CIV13_RESULT%. 1>&2
    exit /b %CIV13_RESULT%
)
echo Compilation completed: civ13.dmb and civ13.rsc in "%CIV13_ROOT%"
exit /b 0

:usage
echo Usage: compile.bat
echo Optionally set BYOND_BIN to the directory containing the pinned dm.exe.
exit /b 2
