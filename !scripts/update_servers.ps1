#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $ScriptRoot 'common.ps1')

try {
    $SecretsPath = Join-Path -Path $ScriptRoot -ChildPath "secrets.txt"
    $secrets = Load-SecretsFile -SecretsPath $SecretsPath

    $steamUser = Resolve-SecretValue -Key "STEAM_USERNAME" -Secrets $secrets -SecretsPath $SecretsPath -Mandatory
    $steamPassword = Resolve-SecretValue -Key "STEAM_PASSWORD" -Secrets $secrets -SecretsPath $SecretsPath -Mandatory

    $SteamCmdPath = Join-Path -Path $ScriptRoot -ChildPath "SteamCMD\steamcmd.exe"
    if (-not (Test-Path $SteamCmdPath)) {
        throw "SteamCMD not found at $SteamCmdPath"
    }

    $ParentPath = Split-Path -Path $ScriptRoot -Parent
    $ServerPaths = [ordered]@{
        Main       = Join-Path -Path $ParentPath -ChildPath "server_main"
        Training   = Join-Path -Path $ParentPath -ChildPath "server_training"
        MainHC     = Join-Path -Path $ParentPath -ChildPath "server_main_hc"
        Testing    = Join-Path -Path $ParentPath -ChildPath "server_testing"
        Special    = Join-Path -Path $ParentPath -ChildPath "server_special"
        LsrTesting = Join-Path -Path $ParentPath -ChildPath "server_lsr_testing"
    }

    $branchChoice = Read-Host "Use profiling branch? (y/n) Enter for default (y)"
    $AppId = if ($branchChoice -eq "n") { "233780" } else { "233780 -beta profiling" }

    foreach ($entry in $ServerPaths.GetEnumerator()) {
        Write-Host "Updating $($entry.Key) server at $($entry.Value) with app_update $AppId" -ForegroundColor Cyan
        & "$SteamCmdPath" +force_install_dir $entry.Value +login $steamUser $steamPassword +"app_update $AppId" validate +quit
        if ($LASTEXITCODE -ne 0) {
            throw "SteamCMD update failed for $($entry.Key) (exit code $LASTEXITCODE)."
        }
    }
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
