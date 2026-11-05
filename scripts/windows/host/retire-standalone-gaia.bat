@echo off
rem Stops the old setup: ends and disables the old doorman and Gaia scheduled tasks,
rem then asks standalone Gaia to save and stop (it is thawed first if it was asleep).
setlocal
call "%~dp0_env.bat" || exit /b 2
schtasks /End /TN "%CIV13_OLD_DOORMAN_TASK%" >nul 2>&1
schtasks /Change /TN "%CIV13_OLD_DOORMAN_TASK%" /DISABLE && echo Disabled "%CIV13_OLD_DOORMAN_TASK%"
schtasks /Change /TN "%CIV13_OLD_GAIA_TASK%" /DISABLE && echo Disabled "%CIV13_OLD_GAIA_TASK%"
if not exist "%CIV13_OLD_CONFIG%" (
    echo Old config not found: %CIV13_OLD_CONFIG%. Stop Gaia by hand if it is running.
    exit /b 0
)
%CIV13_PYTHON% -I -B "%CIV13_HOST%" --config "%CIV13_OLD_CONFIG%" stop
if errorlevel 1 (
    echo Standalone Gaia was not stopped by this script; if it said "not running", it is already off.
    exit /b 0
)
echo Saving and stopping standalone Gaia in the background. Follow it with:
echo   %CIV13_PYTHON% "%CIV13_HOST%" --config "%CIV13_OLD_CONFIG%" status
echo and wait until "phase" is "stopped" before adopt-gaia.bat.
