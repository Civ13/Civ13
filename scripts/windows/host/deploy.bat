@echo off
rem deploy.bat [continue] [REGION ...] - update the source checkout, build the update beside the
rem running regions (staging), and only once every build is ready save and stop the regions, install
rem the builds, start them again and restart the host service. A failed build stops it before anyone
rem is kicked.
rem With no REGION it does every region of the group; with one or more (for example "deploy.bat gaia"
rem for just the mainland) only those stop, and the others keep running. Each step waits for the one
rem before it, and the script stops at the first failure, leaving the worlds as that step left them
rem (a failed save or compile never starts an old or half-saved world). The worlds stay up while
rem the update builds; the downtime is the save (Gaia's takes up to ten minutes), install and load.
rem
rem Exit codes: 0 done, 1 a step failed, 2 settings missing, 3 a region did not save and is still
rem running (the regions that did save stay stopped). After 3, either force-stop the regions that did
rem not save (force-stop.bat REGION, losing what they did since their last completed save) and run
rem "deploy.bat continue" with the same regions to carry on from the save step (the builds stay
rem staged), or start the stopped regions again with start.bat. The launcher asks which and does it.
setlocal
rem cmd reads a running .bat from disk line by line, and step 1 pulls this very file. Run from a copy
rem so the pull cannot change the lines still to come; the copy finds the other scripts here.
if defined CIV13_DEPLOY_COPY goto :copied
set "CIV13_HOST_DIR=%~dp0"
set "CIV13_DEPLOY_COPY=%TEMP%\civ13-deploy.bat"
copy /y "%~f0" "%CIV13_DEPLOY_COPY%" >nul || exit /b 2
"%CIV13_DEPLOY_COPY%" %*

:copied
call "%CIV13_HOST_DIR%_env.bat" || exit /b 2
set "RESUME="
set "REGIONS="
set "WAIT_REGIONS="
:arguments
if "%~1"=="" goto :arguments_done
if /i "%~1"=="continue" goto :resume_argument
set "REGIONS=%REGIONS% %~1"
set "WAIT_REGIONS=%WAIT_REGIONS% --region %~1"
shift
goto :arguments
:resume_argument
set "RESUME=1"
shift
goto :arguments
:arguments_done
set "WHICH=every region"
if defined REGIONS set "WHICH=region%REGIONS%"
set "WAIT=%CIV13_PYTHON% -I -B "%CIV13_HOST_DIR%wait_group.py" --config "%CIV13_GROUP%"%WAIT_REGIONS%"
if defined RESUME goto :wait_stop

rem Pulling first means a pull that cannot fast-forward stops the deploy before anyone is kicked.
rem The regions run from their own worktrees, so the running worlds do not notice the pull.
echo [1/7] Updating the source checkout %CIV13_REPO% (local edits are kept)...
git -C "%CIV13_REPO%" pull --ff-only --autostash || goto :failed

echo [2/7] Building the update beside %WHICH% while the worlds keep running...
rem One region compiles at a time, at low priority. A region whose build is already current says so.
call :each stage
%WAIT% --until staged || goto :failed

echo [3/7] Saving and stopping %WHICH%...
rem A region that is already stopped refuses the stop; the wait below decides.
call :each stop
:wait_stop
if defined RESUME echo [3/7] Waiting for %WHICH% to finish saving and stop...
%WAIT% --until stopped || goto :unsaved

echo [4/7] Installing the staged builds in %WHICH% (anything not staged compiles now)...
call :each update || goto :failed
%WAIT% --until compiled || goto :failed

echo [5/7] Starting %WHICH%...
call :each start
%WAIT% --until awake --timeout 900 || goto :failed

echo [6/7] Restarting the host service...
call "%CIV13_HOST_DIR%restart-host.bat" || goto :failed

echo [7/7] Done.
call "%CIV13_HOST_DIR%status.bat"
exit /b 0

:each
rem :each ACTION - one shard_group.py action for the chosen regions, or for the whole group.
if not defined REGIONS (
    call "%CIV13_HOST_DIR%_group.bat" %1
    exit /b
)
set "EACH_FAILED="
for %%R in (%REGIONS%) do call "%CIV13_HOST_DIR%_group.bat" %1 %%R || set "EACH_FAILED=1"
if defined EACH_FAILED exit /b 1
exit /b 0

:unsaved
echo A region did not save, so it is still running and nothing was updated. The regions that saved
echo stay stopped. Either force-stop the ones that did not save (force-stop.bat REGION; they go back
echo to their last completed save) and run "deploy.bat continue%REGIONS%", or start the others again
echo with start.bat.
exit /b 3

:failed
echo Deploy stopped at the step above. Run status.bat to see each region, fix the cause, then
echo continue by hand from that step (stop.bat, update.bat, start.bat, restart-host.bat).
exit /b 1
