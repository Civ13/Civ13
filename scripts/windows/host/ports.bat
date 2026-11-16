@echo off
rem ports.bat - list every port of the group, who holds it, which to forward on the router, and any clash (changes nothing)
call "%~dp0_group.bat" ports
exit /b %ERRORLEVEL%
