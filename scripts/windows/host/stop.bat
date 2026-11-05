@echo off
rem stop.bat [REGION] - save and stop every region, or one
call "%~dp0_group.bat" stop %1
set "CODE=%ERRORLEVEL%"
echo Saving and stopping in the background (Gaia's save can take 10 minutes). Run status.bat to follow it.
exit /b %CODE%
