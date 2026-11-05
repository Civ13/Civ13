@echo off
rem Copy this file to settings.bat (git-ignored) in the same folder and edit it.
rem Every script in this folder reads settings.bat first.

rem How to run Python 3 (never the bare "python" Store alias).
set "CIV13_PYTHON=py -3"

rem The region group config (copy group.example.json outside the repository).
set "CIV13_GROUP=D:\Civ13Regions\earth.json"

rem The region that is Gaia (the group's mainland).
set "CIV13_MAINLAND=gaia"

rem Where the Gaia region's overlay lives (must match its "overlay" in the group config).
set "CIV13_OVERLAY=D:\Civ13Regions\overlay\gaia"

rem The scheduled task that runs the host service at logon.
set "CIV13_TASK=Civ13 Host"

rem The old standalone Gaia setup, retired by retire-standalone-gaia.bat.
set "CIV13_OLD_CONFIG=D:\Civ13-host\gaia-host.json"
set "CIV13_OLD_DOORMAN_TASK=Civ13 Gaia Doorman"
set "CIV13_OLD_GAIA_TASK=Civ13 Gaia On-Demand"
