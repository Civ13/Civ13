@echo off
rem Runs one shard_group.py action: _group.bat ACTION [REGION]
setlocal
call "%~dp0_env.bat" || exit /b 2
set "REGION_ARG="
if not "%~2"=="" set "REGION_ARG=--region %~2"
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" %~1 %REGION_ARG%
exit /b %ERRORLEVEL%
