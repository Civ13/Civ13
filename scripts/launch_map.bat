@echo off
REM launch_map.bat — Swap the map in civ13.dme, compile, and run on DreamSeeker.
REM Usage: scripts\launch_map.bat <map>
REM
REM Resolution order:
REM   1. If MAP_<UPPER> is defined in code\__defines\maps.dm, use that map ID.
REM   2. Otherwise find <arg>.dmm (case-insensitive) under maps\.

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: %~nx0 ^<map^>
    echo   e.g. %~nx0 nomads
    echo        %~nx0 SUBCOM13
    exit /b 1
)

set "ARG=%~1"
REM Convert to uppercase
call :upper ARG "%ARG%"

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."
set "DME=%REPO_DIR%\civ13.dme"
set "MAPS_DM=%REPO_DIR%\code\__defines\maps.dm"

REM --- resolve map .dmm path ---
set "MAP_PATH="

REM Step 1: check for MAP_<UPPER> define (exact match)
findstr /R /C:"#define MAP_%UPPER% " "%MAPS_DM%" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2 delims==" %%A in ('findstr /C:"#define MAP_%UPPER%" "%MAPS_DM%"') do (
        set "RAW=%%A"
        REM Strip quotes and whitespace
        for %%B in (!RAW!) do set "MAP_ID=%%~B"
    )
    echo Found #define MAP_%UPPER% "!MAP_ID!"
    call :find_dmm "!MAP_ID!"
    if defined MAP_PATH goto :found
)

REM Step 2: direct filename match
call :find_dmm "%ARG%"
if defined MAP_PATH goto :found

REM Step 3: case-insensitive search
for /r "%REPO_DIR%\maps" %%F in (%ARG%.dmm) do (
    set "MAP_PATH=%%F"
    goto :found
)

echo ERROR: Could not find a .dmm for '%ARG%'.
echo Searched: MAP_%UPPER% define, %ARG%.dmm under maps\
exit /b 1

:found
REM Convert to relative path
set "MAP_REL=!MAP_PATH:%REPO_DIR%\=!"
echo Map file: !MAP_REL!

REM --- rewrite civ13.dme: replace any existing .dmm include ---
echo Updating DME...
set "TMPDME=%TEMP%\civ13_launch.dme"
set "MAP_INCLUDE=#include "!MAP_REL!""

REM Copy DME, skip lines containing .dmm, insert new map before END_INCLUDE
set "FOUND_END=0"
set "TMPDME=%TEMP%\civ13_launch.dme"
(
    for /f "usebackq delims=" %%L in ("%DME%") do (
        echo %%L | findstr /C:".dmm" >nul 2>&1
        if errorlevel 1 (
            echo %%L | findstr /C:"// END_INCLUDE" >nul 2>&1
            if not errorlevel 1 (
                echo %MAP_INCLUDE%
                set "FOUND_END=1"
            )
            echo %%L
        )
    )
) > "%TMPDME%"

REM If no END_INCLUDE found, append at end
if !FOUND_END!==0 (
    echo.>> "%TMPDME%"
    echo %MAP_INCLUDE%>> "%TMPDME%"
)

copy /y "%TMPDME%" "%DME%" >nul
del "%TMPDME%" 2>nul
echo DME updated: %MAP_INCLUDE%

REM --- compile ---
echo Compiling...
where DreamMaker >nul 2>&1
if not errorlevel 1 (
    DreamMaker "%DME%"
) else (
    where dm >nul 2>&1
    if not errorlevel 1 (
        dm "%DME%"
    ) else (
        echo ERROR: Neither DreamMaker nor dm found in PATH.
        echo Install BYOND or add DreamMaker to PATH.
        exit /b 1
    )
)

set "DMB=%DME:.dme=.dmb%"
if not exist "%DMB%" (
    echo ERROR: Compilation failed — .dmb not found.
    exit /b 1
)

echo Compilation successful.

REM --- run on DreamSeeker ---
echo Launching DreamSeeker...
where DreamSeeker >nul 2>&1
if not errorlevel 1 (
    start "" DreamSeeker "%DMB%"
) else (
    where byond >nul 2>&1
    if not errorlevel 1 (
        start "" byond "%DMB%"
    ) else (
        echo WARNING: DreamSeeker not found in PATH.
        echo Open %DMB% manually in BYOND.
    )
)

goto :eof

REM --- subroutines ---

:upper
REM Converts string to uppercase
setlocal enabledelayedexpansion
set "STR=%~2"
for %%C in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set "STR=!STR:%%C=%%C!"
)
REM Also handle lowercase → uppercase
for %%C in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    set "UPPER=%%C"
    set "STR=!STR:%%C=!UPPER:~0,1!"
)
endlocal & set "%~1=%STR%"
goto :eof

:find_dmm
REM Find a .dmm file by name under maps\
setlocal
set "FNAME=%~1"
for /r "%REPO_DIR%\maps" %%F in (%FNAME%.dmm) do (
    endlocal & set "MAP_PATH=%%F"
    goto :eof
)
endlocal & set "MAP_PATH="
goto :eof
