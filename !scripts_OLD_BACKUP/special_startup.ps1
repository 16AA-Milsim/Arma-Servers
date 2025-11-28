#Generic
$ParentPath = Split-Path -Path $PSScriptRoot -Parent
$ModpackPath = Join-Path -Path $ParentPath -ChildPath "modpacks\main"
$NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
$OcapPath = Join-Path -Path $ParentPath -ChildPath "servermods\@OCAP"
$ProfilerPath = Join-Path -Path $ParentPath -ChildPath "servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $ParentPath -ChildPath "servermods\@InterceptMinimalDev"
#Specific
$ModpackPath = Join-Path -Path $ParentPath -ChildPath "modpacks\special"
$Port = 2302
$ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_special"
$ConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\special.cfg"
$ExePath = Join-Path -Path $ParentPath -ChildPath "server_special\arma3serverprofiling_x64.exe"

$Mods = (Get-ChildItem -Path $ModpackPath -Directory -Filter "*@*"  | Select-Object -expand fullname) -join ';'

$Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -servermod=$OcapPath -mod=$Mods"

echo "args:" + $Arguments

Start-Process -FilePath "$ExePath"  -ArgumentList $Arguments