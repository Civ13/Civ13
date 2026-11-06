@echo off
rem unlock.bat [REGION] [force] - delete the stale BYOND lock files (*.lk) a forced stop or crash left in
rem a region's map_saves, then check the save again.
rem Safe by default: a region that is running, asleep or mid-action, or whose save is broken for any
rem other reason, is refused and left alone. "force" deletes the files anyway and lists what it skipped.
rem Only *.lk files are touched. Run status.bat first; start.bat afterwards.
setlocal
call "%~dp0_env.bat" || exit /b 2
set "REGION_ARG="
set "FORCE_ARG="
:arguments
if "%~1"=="" goto :run
if /i "%~1"=="force" (
    set "FORCE_ARG=--force"
) else (
    set "REGION_ARG=--region %~1"
)
shift
goto :arguments
:run
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" unlock %REGION_ARG% %FORCE_ARG%
exit /b %ERRORLEVEL%
