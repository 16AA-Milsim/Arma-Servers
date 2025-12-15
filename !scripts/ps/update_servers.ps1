#requires -RunAsAdministrator

<#
.SYNOPSIS
Updates Arma server install folders via SteamCMD.

.DESCRIPTION
Reads STEAM_USERNAME/STEAM_PASSWORD from environment variables or !scripts/config/secrets.txt.
Prompts for profiling vs stable branch, then runs app_update for each configured server install dir.
#>

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
# Import secrets + error UI helpers.
. (Join-Path $ScriptRoot 'common.ps1')

try {
    # Folder layout:
    # - $ScriptRoot = ...\!scripts\ps
    # - $ScriptsDir = ...\!scripts
    # - $RepoRoot   = ...\ (repo root)
    $ScriptsDir = Split-Path -Path $ScriptRoot -Parent
    $RepoRoot = Split-Path -Path $ScriptsDir -Parent

    # Load Steam credentials (secrets file or environment variables).
    $SecretsPath = Join-Path -Path $ScriptsDir -ChildPath "config\secrets.txt"
    $secrets = Get-SecretsFromFile -SecretsPath $SecretsPath

    $steamUser = Resolve-SecretValue -Key "STEAM_USERNAME" -Secrets $secrets -SecretsPath $SecretsPath -Mandatory
    $steamPassword = Resolve-SecretValue -Key "STEAM_PASSWORD" -Secrets $secrets -SecretsPath $SecretsPath -Mandatory

    # Locate SteamCMD.
    $SteamCmdPath = Join-Path -Path $ScriptsDir -ChildPath "SteamCMD\steamcmd.exe"
    if (-not (Test-Path $SteamCmdPath)) {
        throw "SteamCMD not found at $SteamCmdPath"
    }

    # Install directories to update.
    $ServerPaths = [ordered]@{
        Main       = Join-Path -Path $RepoRoot -ChildPath "server_main"
        Training   = Join-Path -Path $RepoRoot -ChildPath "server_training"
        MainHC     = Join-Path -Path $RepoRoot -ChildPath "server_main_hc"
        Testing    = Join-Path -Path $RepoRoot -ChildPath "server_testing"
        Special    = Join-Path -Path $RepoRoot -ChildPath "server_special"
        LsrTesting = Join-Path -Path $RepoRoot -ChildPath "server_lsr_testing"
    }

    $branchChoice = Read-Host "Use profiling branch? (y/n) Enter for default (y)"
    $AppId = if ($branchChoice -eq "n") { "233780" } else { "233780 -beta profiling" }

    # Update each server folder.
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
