@echo off
rem force-stop.bat [REGION] - end a hung region at once WITHOUT saving; the next start loads its last completed save
call "%~dp0_group.bat" kill %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
