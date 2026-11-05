@echo off
rem Copies live Gaia's local-only files (config.txt with the webhook key, host.txt,
rem the Kestrel DLL and its settings) from this checkout into the Gaia overlay, which
rem update.bat lays over the region after every checkout. Run it before git pull.
setlocal
call "%~dp0_env.bat" || exit /b 2
if not exist "%CIV13_OVERLAY%\config" mkdir "%CIV13_OVERLAY%\config" || exit /b 1
for %%F in (config\config.txt config\host.txt config\kestrel-jit.json kestrel_gaia_pathscore_v1.dll) do (
    if exist "%CIV13_REPO%\%%F" (
        copy /y "%CIV13_REPO%\%%F" "%CIV13_OVERLAY%\%%F" >nul || exit /b 1
        echo copied %%F
    ) else (
        echo skipped %%F ^(not present^)
    )
)
echo Overlay ready in %CIV13_OVERLAY%
