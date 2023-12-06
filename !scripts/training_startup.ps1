#Generic
$ModpackPath = Join-Path -Path $PSScriptRoot -ChildPath "..\modpacks\main"
$NetworkConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\configs\network.cfg"
$OcapPath = Join-Path -Path $PSScriptRoot -ChildPath "..\servermods\@OCAP"
$ProfilerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\servermods\@InterceptMinimalDev"
#Specific
$Port = 2402
$ProfilesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\logs_training"
$ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\configs\training.cfg"
$ExePath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_training\arma3serverprofiling_x64.exe"

$Mods = (Get-ChildItem -Path $ModpackPath -Directory -Filter "*@*"  | Select-Object -expand fullname) -join ';'

$Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -servermod=$OcapPath -mod=$Mods"

echo "args:" + $Arguments

Start-Process -FilePath "$ExePath"  -ArgumentList $Arguments