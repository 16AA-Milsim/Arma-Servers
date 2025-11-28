@echo off
setlocal

rem Clear symlinks in the testing modset without touching real folders/files, then start empty
set "MODSET=modpacks\server-testing"

rem Self-elevate if not admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

if "%MODSET%"=="" (
    echo MODSET environment variable not set. Please set MODSET before running this launcher.
    exit /b 1
)

set SCRIPT=%~dp0testing_no_events.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -ModsetPath "%MODSET%"
