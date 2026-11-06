@echo off
rem enrol.bat REGION - enrol a set-up region with the running transfer agents and coordinator
if "%~1"=="" (
  echo usage: enrol.bat REGION
  exit /b 2
)
call "%~dp0_group.bat" enrol %1
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
