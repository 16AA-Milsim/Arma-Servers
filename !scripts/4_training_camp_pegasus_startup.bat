@echo off
setlocal

rem Starts the TRAINING server in "Camp Pegasus" mode.
rem Also auto-selects the latest matching mission file and updates the mission template in the cfg.
rem Edit EVENT/MODSET if you want to start a different preset/modset folder.
set "EVENT=01 - 16AA MAIN"
set "MODSET=modpacks\server-training"

rem Ports are validated; startup fails if the required UDP port range is in use.
echo Training (Camp Pegasus) requires UDP ports 2402-2406 free (base port 2402).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps\script_launcher.ps1" -Action start-server -EventName "%EVENT%" -ModsetPath "%MODSET%" -Port 2402 -ExePath "server_training\arma3serverprofiling_x64.exe" -ConfigPath "configs\training_camp_pegasus.cfg" -ProfilesPath "logs_training" -NetworkConfigPath "configs\network.cfg" -ServerModsPath "servermods\@OCAP" -MissionsPath "server_training\mpmissions" -MissionPattern "[16AA]Universal_Training_Grounds_V*.cfb_moosehead.pbo" -AutoInit -Label "training camp pegasus (-port=2402)"
exit /b %errorlevel%
