@echo off
rem Civ13 Edge chat translator (tools\edge-translator\README.md).
rem Listens on 127.0.0.1:55581 only. Close this window to stop it.
cd /d "%~dp0"
if not exist node_modules\playwright-core call npm ci --ignore-scripts
:run
node edge_translator.js %*
rem Restart after Edge or the service stops; close this window to stop for good.
timeout /t 10 /nobreak >nul
goto run
