@echo off
rem migrate-underground.bat REGION - turn a stopped region's save over to the unformed underground level (docs/underground-level.md)
setlocal
if "%~1"=="" (
  echo Usage: migrate-underground.bat REGION   ^(Save and stop it and run update.bat first^)
  exit /b 2
)
call "%~dp0_env.bat" || exit /b 2
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" migrate-underground --region "%~1"
exit /b %ERRORLEVEL%
