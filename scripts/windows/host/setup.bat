@echo off
rem setup.bat [REGION] - create or refresh the region worktrees and their config
call "%~dp0_group.bat" setup %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
