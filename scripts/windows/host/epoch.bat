@echo off
rem epoch.bat EPOCH - advance the mainland and every awake region to EPOCH (a name such as 2026, or 0-9) without a restart
setlocal
if "%~1"=="" (
  echo Usage: epoch.bat EPOCH   ^(for example: epoch.bat 2026^)
  exit /b 2
)
call "%~dp0_env.bat" || exit /b 2
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" epoch --epoch "%~1"
exit /b %ERRORLEVEL%
