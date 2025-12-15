@echo off
setlocal

rem Self-elevate if not admin (needed for creating symlinks, huge pages, etc.)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

rem Starts the MAIN Arma dedicated server + two local headless clients (HC1/HC2).
rem Edit EVENT/MODSET if you want to start a different preset/modset folder.
set "EVENT=01 - 16AA MAIN"
set "MODSET=modpacks\server-main"

echo Starting main server...
rem Ports are validated; startup fails if the required UDP port range is in use.
echo Main server requires UDP ports 2302-2306 free (base port 2302).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action start-server -EventName "%EVENT%" -ModsetPath "%MODSET%" -Port 2302 -ExePath "server_main\arma3serverprofiling_x64.exe" -ConfigPath "configs\main.cfg" -ProfilesPath "logs_main" -NetworkConfigPath "configs\network.cfg" -ServerModsPath "servermods\@OCAP" -Label "main server (-port=2302)"
if errorlevel 1 goto :fail
rem Give the server a moment to bind ports and write initial files.
timeout /t 2 /nobreak >nul

echo Starting headless client 1...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action hc -Index 1 -ModsetPath "%MODSET%"
if errorlevel 1 goto :fail
rem Stagger client starts to avoid a burst of load.
timeout /t 5 /nobreak >nul

echo Starting headless client 2...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action hc -Index 2 -ModsetPath "%MODSET%"
set "EXITCODE=%errorlevel%"
if not "%EXITCODE%"=="0" goto :fail_with_code
exit /b 0

:fail
set "EXITCODE=%errorlevel%"

:fail_with_code
echo.
echo Startup failed (exit code %EXITCODE%). See output above.
pause
exit /b %EXITCODE%
