@echo off
setlocal

rem Define the event name and modset used by the PS1 (required)
set "EVENT=03 - 16AA XMAS"
set "MODSET=modpacks\server-main"

rem Self-elevate if not admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

if "%EVENT%"=="" (
    echo EVENT environment variable not set. Please set EVENT before running this launcher.
    exit /b 1
)
if "%MODSET%"=="" (
    echo MODSET environment variable not set. Please set MODSET before running this launcher.
    exit /b 1
)

rem Run the Arma startup script
set SCRIPT=%~dp0main.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -EventName "%EVENT%" -ModsetPath "%MODSET%"
