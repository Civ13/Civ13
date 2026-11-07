@echo off
rem force-unlock.bat [REGION] - remove BYOND lock files even if the region looks running; only for a world whose process is gone
call "%~dp0_group.bat" force-unlock %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
