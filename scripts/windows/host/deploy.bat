@echo off
rem deploy.bat [REGION ...] - update the source checkout, build the update beside the running regions
rem (staging), and only once every build is ready hand each running region over to it: the new build
rem boots beside the old world, the old world saves (holding play only on the level being saved),
rem the new one loads that save
rem while the old one still runs, then players move across with a reconnect of a few seconds. A
rem region that is asleep, cold or stopped is left alone; the host service installs the staged build
rem when it wakes or starts. A failed build or a failed handover never stops a world: the old build
rem keeps running and the players keep playing.
rem With no REGION it does every region of the group; with one or more (for example "deploy.bat gaia"
rem for just the mainland) only those. Each step waits for the one before it, and the script stops at
rem the first failure. A handover needs the machine to hold both worlds for a few minutes (the new
rem Gaia peaks near 2 GB while it loads), so the regions take turns.
rem
rem Exit codes: 0 done, 1 a step failed, 2 settings missing. "deploy.bat continue" is accepted for the
rem launcher and waits for handovers already under way.
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
echo [1/5] Updating the source checkout %CIV13_REPO% (local edits are kept)...
git -C "%CIV13_REPO%" pull --ff-only --autostash || goto :failed

echo [2/5] Building the update beside %WHICH% while the worlds keep running...
rem One region compiles at a time, at low priority. A region whose build is already current says so.
call :each stage
%WAIT% --until staged || goto :failed

echo [3/5] Handing %WHICH% over to the new build (running regions only; the host service updates the rest when they wake)...
rem A region that is asleep, stopped or already on the build refuses; the wait below decides.
call :each handover
:wait_stop
if defined RESUME echo [3/5] Waiting for %WHICH% to finish their handover...
%WAIT% --until handed-over --timeout 3600 || goto :failed

echo [4/5] Restarting the host service...
call "%CIV13_HOST_DIR%restart-host.bat" || goto :failed

echo [5/5] Done.
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

:failed
echo Deploy stopped at the step above. No world was stopped: a region whose handover failed keeps
echo running on its old build. Run status.bat to see each region, fix the cause, then run deploy.bat
echo again (the staged builds are kept).
exit /b 1
