@echo off
rem restart.bat [REGION] - save, stop and start again
call "%~dp0_group.bat" restart %1
set "CODE=%ERRORLEVEL%"
echo Restarting in the background. Run status.bat to follow it.
exit /b %CODE%
