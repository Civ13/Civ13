@echo off
rem set-port.bat REGION PORT [apply] - move REGION's world to game port PORT. Without "apply" it only prints the
rem plan (and any clash) and changes nothing. With it, the world is saved and stopped, moved and started again.
rem Follow it with ports.bat: "change" shows the phase (done, or failed with the reason).
setlocal
if "%~2"=="" (
  echo Usage: set-port.bat REGION PORT [apply]   ^(for example: set-port.bat moon 1721 apply^)
  exit /b 2
)
call "%~dp0_env.bat" || exit /b 2
set "APPLY="
if /i "%~3"=="apply" set "APPLY=--apply"
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" set-port --region "%~1" --port "%~2" %APPLY%
exit /b %ERRORLEVEL%
