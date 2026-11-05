@echo off
rem Copies the stopped standalone Gaia (this checkout's map_saves, SQL and runtime data)
rem into the Gaia region. The originals stay where they are as a rollback.
setlocal
call "%~dp0_env.bat" || exit /b 2
%CIV13_PYTHON% -I -B "%CIV13_SHARD%" --config "%CIV13_GROUP%" adopt --region %CIV13_MAINLAND% --from "%CIV13_REPO%"
exit /b %ERRORLEVEL%
