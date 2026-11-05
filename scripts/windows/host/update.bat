@echo off
rem update.bat [REGION] - fetch, check out and compile (regions must be stopped)
call "%~dp0_group.bat" update %1
set "CODE=%ERRORLEVEL%"
echo Compiling in the background. Run status.bat until the phase is "compiled", then start.bat.
exit /b %CODE%
