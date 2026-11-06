@echo off
rem Restarts the host service task (doorman, sleep and wake, transfer agents) so it loads
rem the current host scripts. The worlds keep running. Run it after a pull that changed
rem scripts\gaia-host or scripts\shard-group, or after adding a region to the group.
setlocal
call "%~dp0_env.bat" || exit /b 2
schtasks /Query /TN "%CIV13_TASK%" >nul 2>&1
if errorlevel 1 (
    echo The task "%CIV13_TASK%" is not registered. Run install-host-task.bat from an administrator terminal.
    exit /b 1
)
schtasks /End /TN "%CIV13_TASK%" >nul 2>&1
rem Give the old service a moment to release the doorman port before the new one binds it.
timeout /t 5 /nobreak >nul
schtasks /Run /TN "%CIV13_TASK%" || exit /b 1
echo "%CIV13_TASK%" restarted.
