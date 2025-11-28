@echo off
setlocal

rem Self-elevate if not admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set SCRIPT=%~dp0update_servers.ps1
echo Running server updates via %SCRIPT%
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
