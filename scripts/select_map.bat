@echo off
REM select_map.bat -€” Interactive map selector. Lists folders, then maps,
REM then calls launch_map.bat with the chosen map.
REM Usage: scripts\select_map.bat

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."
set "MAPS_DIR=%REPO_DIR%\maps"

:header
cls
echo ==========================================
echo            CIV13 MAP SELECTOR
echo ==========================================
echo.

REM --- Step 1: Select era/folder ---
echo Select an era:
echo.

set "FOLDER_COUNT=0"
set "FOLDER_LIST="

for /d %%D in ("%MAPS_DIR%\*") do (
    set "FOLDER_NAME=%%~nxD"
    REM Skip non-gameplay folders
    if /i not "!FOLDER_NAME!"=="WIP" (
        if /i not "!FOLDER_NAME!"=="zones" (
            if /i not "!FOLDER_NAME!"=="special" (
                if /i not "!FOLDER_NAME!"=="campaign_archive" (
                    set /a "FOLDER_COUNT+=1"
                    set "FOLDER_!FOLDER_COUNT!=%%D"
                    REM Count .dmm files
                    set "DMC=0"
                    for %%F in ("%%D\*.dmm") do set /a "DMC+=1"
                    REM Also count one level down
                    for /d %%S in ("%%D\*") do (
                        for %%F in ("%%S\*.dmm") do set /a "DMC+=1"
                    )
                    if !DMC! GTR 0 (
                        echo   !FOLDER_COUNT!^) !FOLDER_NAME!                           ^(!DMC! maps^)
                    ) else (
                        set /a "FOLDER_COUNT-=1"
                    )
                )
            )
        )
    )
)

REM Add WIP folder if it has maps
if exist "%MAPS_DIR%\WIP" (
    set /a "FOLDER_COUNT+=1"
    set "FOLDER_!FOLDER_COUNT!=%MAPS_DIR%\WIP"
    set "DMC=0"
    for %%F in ("%MAPS_DIR%\WIP\*.dmm") do set /a "DMC+=1"
    echo   !FOLDER_COUNT!^) WIP                              ^(!DMC! maps^)
)

echo.
set /p "FOLDER_CHOICE=  Select folder [1-%FOLDER_COUNT%]: "

REM Validate
if !FOLDER_CHOICE! LSS 1 goto :bad_folder
if !FOLDER_CHOICE! GTR %FOLDER_COUNT% goto :bad_folder

set "SELECTED_FOLDER=!FOLDER_%FOLDER_CHOICE%!"

REM --- Step 2: Select map from folder ---
:select_map
cls
echo ==========================================
echo            CIV13 MAP SELECTOR
echo ==========================================
echo.
echo Folder: %SELECTED_FOLDER%
echo.
echo Select a map:
echo.

set "MAP_COUNT=0"

REM List .dmm files directly in the folder
for %%F in ("%SELECTED_FOLDER%\*.dmm") do (
    set /a "MAP_COUNT+=1"
    set "MAP_!MAP_COUNT!=%%~nF"
    set "MAP_DISPLAY_!MAP_COUNT!=%%~nF"
    echo   !MAP_COUNT!^) %%~nF
)

REM Also check one level down (subdirectories)
for /d %%S in ("%SELECTED_FOLDER%\*") do (
    set "SUB_NAME=%%~nxS"
    for %%F in ("%%S\*.dmm") do (
        set /a "MAP_COUNT+=1"
        set "MAP_!MAP_COUNT!=%%~nF"
        set "MAP_DISPLAY_!MAP_COUNT!=!SUB_NAME!\%%~nF"
        echo   !MAP_COUNT!^) !SUB_NAME!\%%~nF
    )
)

if !MAP_COUNT! EQU 0 (
    echo   No .dmm files found.
    pause
    goto :header
)

echo.
set /p "MAP_CHOICE=  Select map [1-%MAP_COUNT%]: "

REM Validate
if !MAP_CHOICE! LSS 1 goto :bad_map
if !MAP_CHOICE! GTR %MAP_COUNT% goto :bad_map

set "SELECTED_MAP=!MAP_%MAP_CHOICE%!"

REM --- Step 3: Confirm and launch ---
cls
echo ==========================================
echo            CIV13 MAP SELECTOR
echo ==========================================
echo.
echo Map: !MAP_DISPLAY_%MAP_CHOICE%!
echo ID:  %SELECTED_MAP%
echo.
echo Launching...
echo.

call "%SCRIPT_DIR%launch_map.bat" "%SELECTED_MAP%"
goto :eof

:bad_folder
echo Invalid selection.
pause
goto :header

:bad_map
echo Invalid selection.
pause
goto :select_map
