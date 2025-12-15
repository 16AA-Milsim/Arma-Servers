@echo off
setlocal

rem Runs SteamCMD updates for all configured server installs.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action update-servers
exit /b %errorlevel%
