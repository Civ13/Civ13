@echo off
rem deploy.bat - save and stop every region, update the source checkout and the regions to the
rem group's revision, compile, start them again and restart the host service. Each step waits
rem for the one before it, and the script stops at the first failure, leaving the worlds as
rem that step left them (a failed save or compile never starts an old or half-saved world).
rem Gaia's save takes up to ten minutes and its compile a few more.
setlocal
call "%~dp0_env.bat" || exit /b 2
set "WAIT=%CIV13_PYTHON% -I -B "%~dp0wait_group.py" --config "%CIV13_GROUP%""

echo [1/6] Saving and stopping every region...
rem A region that is already stopped refuses the stop; the wait below decides.
call "%~dp0_group.bat" stop
%WAIT% --until stopped || goto :failed

echo [2/6] Updating the source checkout %CIV13_REPO% (local edits are kept)...
git -C "%CIV13_REPO%" pull --ff-only --autostash || goto :failed

echo [3/6] Checking out and compiling every region...
call "%~dp0_group.bat" update || goto :failed
%WAIT% --until compiled || goto :failed

echo [4/6] Starting every region...
call "%~dp0_group.bat" start
%WAIT% --until awake --timeout 900 || goto :failed

echo [5/6] Restarting the host service...
call "%~dp0restart-host.bat" || goto :failed

echo [6/6] Done.
call "%~dp0status.bat"
exit /b 0

:failed
echo Deploy stopped at the step above. Run status.bat to see each region, fix the cause, then
echo continue by hand from that step (stop.bat, update.bat, start.bat, restart-host.bat).
exit /b 1
