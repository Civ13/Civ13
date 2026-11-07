@echo off
rem config-migrate.bat - turn each overlay's whole config\config.txt into config\config.local.txt (only its own lines)
call "%~dp0_group.bat" config-migrate
set "CODE=%ERRORLEVEL%"
exit /b %CODE%
