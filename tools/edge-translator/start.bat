@echo off
rem Civ13 Edge chat translator (tools\edge-translator\README.md).
rem Listens on 127.0.0.1:55581 only. Close this window to stop it.
cd /d "%~dp0"
if not exist node_modules\playwright-core call npm ci --ignore-scripts
node edge_translator.js %*
