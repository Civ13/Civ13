@echo off
rem Registers the host service (sleep, wake, cold start, doorman on 1713) as a scheduled
rem task that starts at your logon, then starts it now. Run as administrator, signed in as the user who runs the worlds.
setlocal
call "%~dp0_env.bat" || exit /b 2
rem Windows only lets an administrator register a logon-triggered task.
net session >nul 2>&1
if errorlevel 1 (
    echo Run this from an administrator terminal: right-click PowerShell, "Run as administrator".
    echo The task still runs as %USERNAME% with normal rights.
    exit /b 1
)
set "PYW="
for /f "delims=" %%P in ('%CIV13_PYTHON% -c "import os, sys; print(os.path.join(os.path.dirname(sys.executable), 'pythonw.exe'))"') do set "PYW=%%P"
if not exist "%PYW%" (
    echo Could not find pythonw.exe next to %CIV13_PYTHON%.
    exit /b 1
)
schtasks /Create /F /TN "%CIV13_TASK%" /SC ONLOGON /RU "%USERNAME%" /IT /RL LIMITED /TR "\"%PYW%\" -I -B \"%CIV13_HOST%\" --group \"%CIV13_GROUP%\" serve" || exit /b 1
schtasks /Run /TN "%CIV13_TASK%" || exit /b 1
echo "%CIV13_TASK%" is registered and running.
