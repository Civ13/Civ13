@echo off
rem Runs the host service in this window (Ctrl+C stops it; the worlds keep running).
rem Use install-host-task.bat to run it at logon instead.
setlocal
call "%~dp0_env.bat" || exit /b 2
%CIV13_PYTHON% -I -B "%CIV13_HOST%" --group "%CIV13_GROUP%" serve
