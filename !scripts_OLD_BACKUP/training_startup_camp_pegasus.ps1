#Generic
$ParentPath = Split-Path -Path $PSScriptRoot -Parent
$ModpackPath = Join-Path -Path $ParentPath -ChildPath "modpacks\main"
$NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
$OcapPath = Join-Path -Path $ParentPath -ChildPath "servermods\@OCAP"
$ProfilerPath = Join-Path -Path $ParentPath -ChildPath "servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $ParentPath -ChildPath "servermods\@InterceptMinimalDev"

#Specific
$Port = 2402
$ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_training"
$ConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\training_camp_pegasus.cfg"
$MpMissionsPath = Join-Path -Path $ParentPath -ChildPath "server_training\mpmissions"
$ExePath = Join-Path -Path $ParentPath -ChildPath "server_training\arma3serverprofiling_x64.exe"

# Find the latest version of the mission
$LatestMissionFile = Get-ChildItem -Path $MpMissionsPath -Filter "[16AA]Universal_Training_Grounds_V*.cfb_moosehead.pbo" |
    Sort-Object {
        # Debug: show what name it's parsing
        Write-Host "Parsing: $($_.BaseName)"
        
        if ($_.BaseName -match '_V(\d+)\.cfb') {
            $version = [int]$matches[1]
            Write-Host " → Extracted version: $version"
            return $version
        } else {
            Write-Host " → No match, returning 0"
            return 0
        }
    } -Descending |
    Select-Object -First 1

if ($LatestMissionFile) {
    $LatestMissionName = $LatestMissionFile.BaseName
    Write-Host "Latest mission version identified: $LatestMissionName"
    
    # Update the training.cfg file with the latest mission
    $Content = Get-Content $ConfigPath
    $NewContent = $Content -replace '(template\s*=\s*").+(")', "`$1$LatestMissionName`$2"
    $NewContent | Set-Content $ConfigPath
    
    Write-Host "training.cfg updated successfully."
} else {
    Write-Host "No matching mission file found."
}

$Mods = (Get-ChildItem -Path $ModpackPath -Directory -Filter "*@*"  | Select-Object -expand fullname) -join ';'

$Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -autoInit -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -servermod=$OcapPath -mod=$Mods"

echo "args:" + $Arguments

Start-Process -FilePath "$ExePath"  -ArgumentList $Arguments