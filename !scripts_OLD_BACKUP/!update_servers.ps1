# Get secrets from file in key-value pairs
$secretsFilePath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.txt"
$secrets = @{}
Get-Content -Path $secretsFilePath | ForEach-Object {
    # Split each line into key and value
    $key, $value = $_ -split '=', 2
    # Store the key-value pair in the hashtable
    $secrets[$key] = $value
}

# Define the variables
$STEAMLOGIN = $secrets["STEAM_USERNAME"], $secrets["STEAM_PASSWORD"]
$STEAMPATH = Join-Path -Path $PSScriptRoot -ChildPath "SteamCMD\steamcmd.exe"
$A3serverBRANCH = "233780"
$A3serverBRANCH_PROF = "233780 -beta profiling"
# get path of server_main folder
$MainServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_main"
$TrainingServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_training"
$MainHCServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_main_hc"
$TestServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_testing"
$SpecialServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_special"
$LSRTestingServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_lsr_testing"


$UsePROF = Read-Host "Use profiling branch? (y/n) Enter for default (y)"
if ($UsePROF -eq "y" -or $UsePROF -eq "") {
    $A3serverBRANCH = $A3serverBRANCH_PROF
}

# Run the steamcmd commands
& "$STEAMPATH" +force_install_dir $MainServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit
& "$STEAMPATH" +force_install_dir $TrainingServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit
& "$STEAMPATH" +force_install_dir $MainHCServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit
& "$STEAMPATH" +force_install_dir $TestServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit
& "$STEAMPATH" +force_install_dir $SpecialServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit
& "$STEAMPATH" +force_install_dir $LSRTestingServerPath +login $STEAMLOGIN  +"app_update $A3serverBRANCH" validate +quit

# Exit the script
exit