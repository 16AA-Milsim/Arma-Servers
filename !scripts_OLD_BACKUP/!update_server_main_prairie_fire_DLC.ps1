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
$A3serverBRANCH = "233780 -beta creatordlc"
$MainServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_main"
$TrainingServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server_training"
$ProfilingExecutable = "arma3serverprofiling_x64.exe"

# Run the SteamCMD command to update the main server to the Prairie Fire DLC branch
Write-Host "Updating Arma 3 Main Server to Prairie Fire DLC branch..."
& "$STEAMPATH" +force_install_dir $MainServerPath +login $STEAMLOGIN +"app_update $A3serverBRANCH validate" +quit

if ($LASTEXITCODE -eq 0) {
    Write-Host "Main server updated to Prairie Fire DLC branch successfully!"
    
    # Check if the profiling executable exists in the main server directory
    $MainServerExePath = Join-Path -Path $MainServerPath -ChildPath $ProfilingExecutable
    if (-not (Test-Path $MainServerExePath)) {
        # If not found, copy the profiling executable from the training server
        Write-Host "Profiling executable not found in main server, copying from training server..."
        $TrainingServerExePath = Join-Path -Path $TrainingServerPath -ChildPath $ProfilingExecutable
        
        if (Test-Path $TrainingServerExePath) {
            Copy-Item -Path $TrainingServerExePath -Destination $MainServerExePath -Force
            Write-Host "Profiling executable successfully copied from training server to main server."
        } else {
            Write-Host "Profiling executable not found in training server. Please ensure it exists." -ForegroundColor Red
        }
    } else {
        Write-Host "Profiling executable already exists in main server."
    }

} else {
    Write-Host "Failed to update the main server. Please check SteamCMD output for details." -ForegroundColor Red
}

# Wait for user input before exiting
Write-Host "Press any key to continue..."
$x = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# Exit the script
exit
