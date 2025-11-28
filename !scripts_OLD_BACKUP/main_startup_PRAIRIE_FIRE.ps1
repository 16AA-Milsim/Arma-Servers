# Paths
$ParentPath = Split-Path -Path $PSScriptRoot -Parent
$ModpackPath = Join-Path -Path $ParentPath -ChildPath "modpacks\main"
$SpecialRequiredPath = Join-Path -Path $ParentPath -ChildPath "modpacks\special_required"
$NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
$OcapPath = Join-Path -Path $ParentPath -ChildPath "servermods\@OCAP"
$ProfilerPath = Join-Path -Path $ParentPath -ChildPath "servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $ParentPath -ChildPath "servermods\@InterceptMinimalDev"
# Specific configurations
$Port = 2302
$ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_main"
$ConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\main.cfg"
$ExePath = Join-Path -Path $ParentPath -ChildPath "server_main\arma3serverprofiling_x64.exe"

# Get the mod paths from main and special_required folders
$ModsMain = (Get-ChildItem -Path $ModpackPath -Directory -Filter "*@*" | Select-Object -ExpandProperty FullName) -join ';'
$ModsSpecial = (Get-ChildItem -Path $SpecialRequiredPath -Directory -Filter "*@*" | Select-Object -ExpandProperty FullName) -join ';'

# Combine the mods from both folders
$Mods = $ModsMain + ';' + $ModsSpecial + ";vn"

# Build the arguments string
$Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -servermod=$OcapPath -mod=$Mods"

# Echo the arguments to the console
echo "args:" + $Arguments

# Try starting the process and capture any error messages
$ErrorOccurred = $false
try {
    Start-Process -FilePath "$ExePath" -ArgumentList $Arguments -ErrorAction Stop
} catch {
    # Output any error that occurred
    Write-Host "An error occurred while starting the process:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $ErrorOccurred = $true
}

# Wait for user input if an error occurred
if ($ErrorOccurred) {
    Write-Host "Press any key to continue..."
    $x = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
