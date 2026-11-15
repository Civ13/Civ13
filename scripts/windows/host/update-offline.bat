@echo off
rem update-offline.bat [REGION] - pull the source checkout, then update every region that is NOT
rem running to the latest master, so it is ready when it starts. Running regions are left alone.
rem Stopped regions build one at a time and install it; asleep ones install it while they sleep.
rem Run status.bat and look at "stage" for progress.
setlocal
call "%~dp0_env.bat" || exit /b 2
echo Updating the source checkout %CIV13_REPO% (local edits are kept)...
git -C "%CIV13_REPO%" pull --ff-only --autostash || exit /b 1
call "%~dp0_group.bat" update-offline %1
set "CODE=%ERRORLEVEL%"
echo Building in the background. Running regions were left alone.
exit /b %CODE%
