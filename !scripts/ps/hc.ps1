#requires -RunAsAdministrator

<#
.SYNOPSIS
Starts a local Arma headless client (HC1/HC2).

.DESCRIPTION
Connects to the local main server (127.0.0.1:2302) using the same modset as the server.
Reads the join password from configs/passwords*.hpp or ARMA_CONNECT_PASSWORD/config\secrets.txt via common.ps1.
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet(1, 2)]
    [int]$Index,

    [string]$ModsetPath
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
# Import shared helpers (path safety, secrets, process start, UI/pause).
. (Join-Path $ScriptRoot 'common.ps1')

try {
    if ([string]::IsNullOrWhiteSpace($ModsetPath)) {
        throw "ModsetPath not provided. Ensure the BAT launcher sets and passes MODSET."
    }

    # Folder layout:
    # - $ScriptRoot = ...\!scripts\ps
    # - $ScriptsDir = ...\!scripts
    # - $RepoRoot   = ...\ (repo root)
    $ScriptsDir = Split-Path -Path $ScriptRoot -Parent
    $RepoRoot = Split-Path -Path $ScriptsDir -Parent
    if (-not $RepoRoot) {
        throw "Could not resolve repo root from script root ($ScriptRoot)."
    }

    # Normalize/validate modset path (and ensure it resolves under modpacks).
    $ModsetPath = Resolve-ModsetPath -ModsetPath $ModsetPath -ParentPath $RepoRoot

    # HC profile folder is unique per index.
    $ProfilesPath = Join-Path -Path $RepoRoot -ChildPath ("logs_main_hc\hc{0}" -f $Index)
    $ExePath = Join-Path -Path $RepoRoot -ChildPath "server_main_hc\arma3server_x64.exe"
    $Port = 2302

    # Resolve the join password (config file preferred; env/secrets fallback).
    $SecretsPath = Join-Path -Path $ScriptsDir -ChildPath "config\secrets.txt"
    $secrets = Get-SecretsFromFile -SecretsPath $SecretsPath
    $JoinPassword = Resolve-ConnectPassword -ParentPath $RepoRoot -Secrets $secrets -SecretsPath $SecretsPath

    # Require the modset to already exist (main server usually builds the symlinks first).
    if (-not (Test-Path $ModsetPath)) {
        throw "ModsetPath does not exist: $ModsetPath. Start the main server first to build symlinks."
    }

    # Convert the modset folder contents into an Arma -mod= argument.
    $Mods = Get-ModsetArgument -ModsetPath $ModsetPath

    # Build and launch the HC command line.
    $Arguments = "-client -connect=127.0.0.1 -port=$Port -password=$JoinPassword -profiles=$ProfilesPath -malloc=mimalloc_v206_LockPages -hugepages -maxMem=16000 -limitFPS=500 -enableHT -mod=$Mods"
    Start-ArmaServer -ExePath $ExePath -Arguments $Arguments
}
catch {
    # Extra diagnostics help when Arma exits immediately or PowerShell throws during start.
    Write-Host ("ERROR DETAILS (hc{0}):" -f $Index) -ForegroundColor Red
    Write-Host ($_ | Out-String)
    if ($_.InvocationInfo) { Write-Host "Invocation:" $_.InvocationInfo.PositionMessage }
    if ($_.ScriptStackTrace) { Write-Host "Script stack:" $_.ScriptStackTrace }
    Show-ErrorAndExit $_.Exception.Message
}
