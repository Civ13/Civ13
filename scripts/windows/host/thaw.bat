@echo off
rem thaw.bat [REGION] - wake a sleeping region now; a cold one starts from its save
call "%~dp0_group.bat" thaw %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
