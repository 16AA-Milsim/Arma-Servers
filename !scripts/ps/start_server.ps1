#requires -RunAsAdministrator
<#
.SYNOPSIS
Starts an Arma 3 dedicated server instance.

.DESCRIPTION
This script is parameter-driven: the .bat launcher provides all server-specific paths and settings
(exe/config/profiles/port/servermods/etc). It optionally rebuilds the modset symlinks based on the
selected event (from the .a3s / events.json pipeline), with a hash-cache to skip relinking when unchanged.
#>

param(
    [string]$EventName,
    [Parameter(Mandatory)]
    [string]$ModsetPath,

    [switch]$SkipEvents,

    [Parameter(Mandatory)]
    [int]$Port,

    [Parameter(Mandatory)]
    [string]$ExePath,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter(Mandatory)]
    [string]$ProfilesPath,

    [string]$NetworkConfigPath = "configs\network.cfg",

    [string]$ServerModsPath,

    [string]$ServerName = "16aa",

    [string]$Label,

    [string]$MissionsPath,

    [string]$MissionPattern,

    [switch]$AutoInit,

    [string]$ExtraArgs
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
# Import shared helpers (event parsing, modset linking, port checks, secrets, UI/pause).
. (Join-Path $ScriptRoot 'common.ps1')
$CommonPaths = Get-CommonPaths

function Resolve-RelativePath {
    # Resolves a path relative to the repo root (ParentPath) unless already absolute.
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path is empty."
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path -Path $BasePath -ChildPath $Path)
}

try {
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

    # Resolve any relative input paths against the repo root.
    $ExePath = Resolve-RelativePath -Path $ExePath -BasePath $RepoRoot
    $ConfigPath = Resolve-RelativePath -Path $ConfigPath -BasePath $RepoRoot
    $ProfilesPath = Resolve-RelativePath -Path $ProfilesPath -BasePath $RepoRoot
    $NetworkConfigPath = Resolve-RelativePath -Path $NetworkConfigPath -BasePath $RepoRoot
    if ($ServerModsPath) {
        $ServerModsPath = Resolve-RelativePath -Path $ServerModsPath -BasePath $RepoRoot
    }

    if ($SkipEvents) {
        # Skip event parsing and start with whatever mod folders are currently in the modset.
        Clear-ModsetSymlinks -ModsetPath $ModsetPath
    } else {
        # Parse event definition and rebuild modset symlinks to match it.
        if ([string]::IsNullOrWhiteSpace($EventName)) {
            throw "EventName not provided. Ensure the BAT launcher sets and passes EVENT (or use -SkipEvents)."
        }

        $ParserScript = Join-Path -Path $CommonPaths.ParserRoot -ChildPath "Parser.py"
        $PythonExe = Get-ParserPython -ParserRoot $CommonPaths.ParserRoot

        $eventInfo = Update-EventsAndGetDefinition -ParserRoot $CommonPaths.ParserRoot -ParserScript $ParserScript -LibraryA3SPath $CommonPaths.LibraryA3SPath -EventsJsonPath $CommonPaths.EventsJsonPath -PythonExe $PythonExe -EventName $EventName
        Update-ModsetSymlinks -ModsetPath $ModsetPath -Mods $eventInfo.Mods -ModLibraryPath $CommonPaths.ModLibraryPath -EventName $EventName
    }

    # Convert the modset folder contents into an Arma -mod= argument.
    $Mods = Get-ModsetArgument -ModsetPath $ModsetPath

    # Build the dedicated server command line.
    $baseArgs = @(
        "-config=$ConfigPath",
        "-cfg=$NetworkConfigPath",
        "-profiles=$ProfilesPath",
        "-port=$Port",
        "-name=$ServerName",
        "-filePatching",
        "-hugepages",
        "-maxMem=16000",
        "-malloc=mimalloc_v206_LockPages",
        "-enableHT",
        "-bandwidthAlg=2",
        "-limitFPS=1000",
        "-loadMissionToMemory"
    )

    if ($ServerModsPath) {
        # Server-only mods (e.g. @OCAP) loaded via -servermod.
        $baseArgs += "-servermod=$ServerModsPath"
    }

    if ($MissionsPath -or $MissionPattern) {
        # Optional: auto-select latest mission file and update the cfg template before starting.
        if ([string]::IsNullOrWhiteSpace($MissionsPath) -or [string]::IsNullOrWhiteSpace($MissionPattern)) {
            throw "MissionsPath and MissionPattern must be provided together."
        }

        $resolvedMissionsPath = Resolve-RelativePath -Path $MissionsPath -BasePath $RepoRoot
        $mission = Select-LatestMission -MissionsPath $resolvedMissionsPath -MissionPattern $MissionPattern
        Update-CfgTemplate -ConfigPath $ConfigPath -MissionTemplate $mission.Template

        if ($AutoInit) {
            # Auto-start the mission after launch.
            $baseArgs += "-autoInit"
        }
        $baseArgs += "-mission=""$($mission.Path)"""
    }

    $baseArgs += "-mod=$Mods"
    if (-not [string]::IsNullOrWhiteSpace($ExtraArgs)) {
        $baseArgs += $ExtraArgs
    }
    $Arguments = $baseArgs -join ' '

    if ([string]::IsNullOrWhiteSpace($Label)) {
        # Friendly label used in port-check error messages.
        $Label = "arma server (-port=$Port)"
    }

    # Fail fast if the required UDP ports are already occupied.
    Assert-ArmaServerPortsFree -BasePort $Port -Label $Label
    # Launch the server (non-blocking; the server continues running after the script exits).
    Start-ArmaServer -ExePath $ExePath -Arguments $Arguments
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
