@echo off
setlocal

rem Define the event name and modset used by the PS1 (required)
set "EVENT=01 - 16AA MAIN"
set "MODSET=modpacks\server-testing"

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
set SCRIPT=%~dp0testing.ps1

echo Testing server requires UDP ports 2442-2446 free (base port 2442).
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -EventName "%EVENT%" -ModsetPath "%MODSET%"
if errorlevel 1 (
    echo.
    echo Startup failed. See the error output above.
    pause
    exit /b 1
)
