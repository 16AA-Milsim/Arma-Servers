@echo off
setlocal

rem Self-elevate if not admin (needed for writing server folders, SteamCMD, etc.)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

rem Runs SteamCMD updates for all configured server installs.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action update-servers
set "EXITCODE=%errorlevel%"
if not "%EXITCODE%"=="0" (
    echo.
    echo Update failed (exit code %EXITCODE%). See output above.
    pause
)
exit /b %EXITCODE%
