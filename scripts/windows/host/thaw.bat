@echo off
rem thaw.bat [REGION] - wake a sleeping region now
call "%~dp0_group.bat" thaw %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
