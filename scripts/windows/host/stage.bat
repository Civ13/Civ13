@echo off
rem stage.bat [REGION] - pull the source checkout, then build the update beside the running
rem regions. The host service installs it in each region the next time that region is empty and
rem saved, or asleep, so nobody is kicked. Run status.bat and look at "stage" for progress.
setlocal
call "%~dp0_env.bat" || exit /b 2
echo Updating the source checkout %CIV13_REPO% (local edits are kept)...
git -C "%CIV13_REPO%" pull --ff-only --autostash || exit /b 1
call "%~dp0_group.bat" stage %1
set "CODE=%ERRORLEVEL%"
echo Building in the background. Each region installs the build when it is empty.
exit /b %CODE%
