@echo off
rem config-apply.bat [REGION] - write the overlays and config.local.txt into the regions without a compile; worlds use them from their next restart
call "%~dp0_group.bat" config-apply %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
