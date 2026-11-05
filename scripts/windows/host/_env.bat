@echo off
rem Shared by every script here: loads settings.bat and finds the repository.
for %%I in ("%~dp0..\..\..") do set "CIV13_REPO=%%~fI"
if not exist "%~dp0settings.bat" (
    echo Copy settings.example.bat to settings.bat in %~dp0 and edit it first.
    exit /b 2
)
call "%~dp0settings.bat"
if not defined CIV13_PYTHON set "CIV13_PYTHON=py -3"
set "CIV13_SHARD=%CIV13_REPO%\scripts\shard-group\shard_group.py"
set "CIV13_HOST=%CIV13_REPO%\scripts\gaia-host\gaia_host.py"
if not exist "%CIV13_GROUP%" (
    echo The group config was not found: %CIV13_GROUP%
    echo Copy group.example.json there and edit it, or fix CIV13_GROUP in settings.bat.
    exit /b 2
)
exit /b 0
