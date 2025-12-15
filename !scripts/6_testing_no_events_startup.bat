@echo off
setlocal

rem Self-elevate if not admin (needed for creating symlinks, huge pages, etc.)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

rem Starts the TESTING server without event parsing (uses whatever is already in the modset folder).
rem This will clear only symlinks inside MODSET (leaves real files/folders untouched).
set "MODSET=modpacks\server-testing"

rem Ports are validated; startup fails if the required UDP port range is in use.
echo Testing server (no events) requires UDP ports 2442-2446 free (base port 2442).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action start-server -ModsetPath "%MODSET%" -SkipEvents -Port 2442 -ExePath "server_testing\arma3serverprofiling_x64.exe" -ConfigPath "configs\testing.cfg" -ProfilesPath "logs_testing" -NetworkConfigPath "configs\network.cfg" -Label "testing server (no events) (-port=2442)"
set "EXITCODE=%errorlevel%"
if not "%EXITCODE%"=="0" (
    echo.
    echo Startup failed (exit code %EXITCODE%). See output above.
    pause
)
exit /b %EXITCODE%
