@echo off
rem freeze.bat [REGION] - put an empty, saved region to sleep now
call "%~dp0_group.bat" freeze %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
