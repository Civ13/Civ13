@echo off
rem force-restart.bat [REGION] - force-stop (no save) if running, then start from the last completed save
call "%~dp0_group.bat" force-restart %1
set "CODE=%ERRORLEVEL%"
echo Starting in the background. Run status.bat to follow it.
exit /b %CODE%
