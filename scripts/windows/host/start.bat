@echo off
rem start.bat [REGION] - start every region, or one
call "%~dp0_group.bat" start %1
set "CODE=%ERRORLEVEL%"
echo Starting in the background. Run status.bat to follow it.
exit /b %CODE%
