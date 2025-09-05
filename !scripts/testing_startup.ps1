# Generic
$ParentPath = Split-Path -Path $PSScriptRoot -Parent
$NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
$OcapPath = Join-Path -Path $ParentPath -ChildPath "servermods\@OCAP"
$ProfilerPath = Join-Path -Path $ParentPath -ChildPath "servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $ParentPath -ChildPath "servermods\@InterceptMinimalDev"

# Specific
$Port = 2442
$ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_testing"
$ConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\testing.cfg"
$ExePath = Join-Path -Path $ParentPath -ChildPath "server_testing\arma3serverprofiling_x64.exe"

# Mods setup
$MainModsPath = "F:\16AA\Arma-Servers\modpacks\main"
$TestModsPath = "F:\16AA\Arma-Servers\modpacks\testing"

# List of mods to exclude
$ExcludedMods = @(
    # "@SomeOtherMod",
    "@Zulu_Headless_Client_ZHC_","@Advanced_Combat_Medicine"
)

# Collect and filter mods from both directories
$Mods = @(Get-ChildItem -Path $TestModsPath, $MainModsPath -Directory -Filter "*@*") |
    Where-Object { $ExcludedMods -notcontains $_.Name } |
    Select-Object -ExpandProperty FullName -Unique

$ModsJoined = $Mods -join ';'

$Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -servermod=$OcapPath -mod=$ModsJoined"

echo "args:" + $Arguments

Start-Process -FilePath "$ExePath" -ArgumentList $Arguments
