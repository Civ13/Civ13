@echo off
rem Registers the host service (sleep, wake, cold start, doorman on 1713) as a scheduled
rem task that starts at your logon, then starts it now. Run as the user who runs the worlds.
setlocal
call "%~dp0_env.bat" || exit /b 2
set "PYW="
for /f "delims=" %%P in ('%CIV13_PYTHON% -c "import os, sys; print(os.path.join(os.path.dirname(sys.executable), 'pythonw.exe'))"') do set "PYW=%%P"
if not exist "%PYW%" (
    echo Could not find pythonw.exe next to %CIV13_PYTHON%.
    exit /b 1
)
schtasks /Create /F /TN "%CIV13_TASK%" /SC ONLOGON /RU "%USERNAME%" /IT /RL LIMITED /TR "\"%PYW%\" -I -B \"%CIV13_HOST%\" --group \"%CIV13_GROUP%\" serve" || exit /b 1
schtasks /Run /TN "%CIV13_TASK%" || exit /b 1
echo "%CIV13_TASK%" is registered and running.
