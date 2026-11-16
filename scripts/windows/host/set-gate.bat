@echo off
rem set-gate.bat REGION [apply] - make REGION the front door: the world on the public port that players and the
rem Discord Play button join and the bot watches. Without "apply" it only prints the plan and changes nothing.
rem With it, the two worlds are saved and stopped, swap ports, and are started again, the new front door first.
rem Follow it with ports.bat: "change" shows the phase (done, or failed with the reason).
setlocal
if "%~1"=="" (
  echo Usage: set-gate.bat REGION [apply]   ^(for example: set-gate.bat gaia apply^)
  exit /b 2
)
call "%~dp0_env.bat" || exit /b 2
set "APPLY="
if /i "%~2"=="apply" set "APPLY=--apply"
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" set-gate --region "%~1" %APPLY%
exit /b %ERRORLEVEL%
