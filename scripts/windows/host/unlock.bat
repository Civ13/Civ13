@echo off
rem unlock.bat [REGION] - check each stopped region's save for stale BYOND lock files (*.lk) and remove them
call "%~dp0_group.bat" unlock %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
