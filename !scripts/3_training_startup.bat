@echo off
setlocal

rem Self-elevate if not admin (needed for creating symlinks, huge pages, etc.)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

rem Starts the TRAINING Arma dedicated server (event-driven modset).
rem Edit EVENT/MODSET if you want to start a different preset/modset folder.
set "EVENT=01 - 16AA MAIN"
set "MODSET=modpacks\server-training"

rem Ports are validated; startup fails if the required UDP port range is in use.
echo Training server requires UDP ports 2402-2406 free (base port 2402).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action start-server -EventName "%EVENT%" -ModsetPath "%MODSET%" -Port 2402 -ExePath "server_training\arma3serverprofiling_x64.exe" -ConfigPath "configs\training.cfg" -ProfilesPath "logs_training" -NetworkConfigPath "configs\network.cfg" -ServerModsPath "servermods\@OCAP" -Label "training server (-port=2402)"
set "EXITCODE=%errorlevel%"
if not "%EXITCODE%"=="0" (
    echo.
    echo Startup failed (exit code %EXITCODE%). See output above.
    pause
)
exit /b %EXITCODE%
