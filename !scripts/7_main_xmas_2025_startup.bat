@echo off
setlocal

rem Starts the MAIN server using the XMAS event preset.
rem Edit EVENT/MODSET if you want to start a different preset/modset folder.
set "EVENT=03 - 16AA XMAS"
set "MODSET=modpacks\server-main"

rem Ports are validated; startup fails if the required UDP port range is in use.
echo Main server requires UDP ports 2302-2306 free (base port 2302).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action start-server -EventName "%EVENT%" -ModsetPath "%MODSET%" -Port 2302 -ExePath "server_main\arma3serverprofiling_x64.exe" -ConfigPath "configs\main.cfg" -ProfilesPath "logs_main" -NetworkConfigPath "configs\network.cfg" -ServerModsPath "servermods\@OCAP" -Label "main server (-port=2302)"
exit /b %errorlevel%
