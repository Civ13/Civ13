@echo off
rem status.bat [REGION] - each region's state (awake, asleep, cold, stopped) and last action
setlocal
call "%~dp0_env.bat" || exit /b 2
set "REGION_ARG="
if not "%~1"=="" set "REGION_ARG=--region %~1"
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" status %REGION_ARG% | %CIV13_PYTHON% -m json.tool
