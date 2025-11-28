@echo off
setlocal

rem Shared event/modset for main server and headless clients
set "EVENT=01 - 16AA MAIN"
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

set SCRIPT_MAIN=%~dp0main.ps1
set SCRIPT_HC1=%~dp0hc1.ps1
set SCRIPT_HC2=%~dp0hc2.ps1

echo Starting main server...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_MAIN%" -EventName "%EVENT%" -ModsetPath "%MODSET%"
timeout /t 2 /nobreak >nul

echo Starting headless client 1...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_HC1%" -EventName "%EVENT%" -ModsetPath "%MODSET%"
timeout /t 5 /nobreak >nul

echo Starting headless client 2...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_HC2%" -EventName "%EVENT%" -ModsetPath "%MODSET%"
