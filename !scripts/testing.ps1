#requires -RunAsAdministrator

param(
    [string]$EventName,
    [string]$ModsetPath
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $ScriptRoot 'common.ps1')

try {
    if ([string]::IsNullOrWhiteSpace($EventName)) {
        throw "EventName not provided. Ensure the launcher BAT sets and passes EVENT."
    }

    if ([string]::IsNullOrWhiteSpace($ModsetPath)) {
        throw "ModsetPath not provided. Ensure the launcher BAT sets and passes MODSET."
    }

    $ParentPath = Split-Path -Path $ScriptRoot -Parent
    if (-not $ParentPath) {
        throw "Could not resolve ParentPath from script root ($ScriptRoot)."
    }

    $ModsetPath = Resolve-ModsetPath -ModsetPath $ModsetPath -ParentPath $ParentPath

    $NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
    $ProfilesPath      = Join-Path -Path $ParentPath -ChildPath "logs_testing"
    $ConfigPath        = Join-Path -Path $ParentPath -ChildPath "configs\testing.cfg"
    $ExePath           = Join-Path -Path $ParentPath -ChildPath "server_testing\arma3serverprofiling_x64.exe"
    $Port              = 2442

    $ParserScript = Join-Path -Path $CommonPaths.ParserRoot -ChildPath "Parser.py"
    $PythonExe    = Get-ParserPython -ParserRoot $CommonPaths.ParserRoot

    Invoke-EventParser -ParserRoot $CommonPaths.ParserRoot -ParserScript $ParserScript -LibraryA3SPath $CommonPaths.LibraryA3SPath -EventsJsonPath $CommonPaths.EventsJsonPath -PythonExe $PythonExe

    $eventInfo = Get-EventDefinition -EventsJsonPath $CommonPaths.EventsJsonPath -EventName $EventName
    Rebuild-ModsetLinks -ModsetPath $ModsetPath -Mods $eventInfo.Mods -ModLibraryPath $CommonPaths.ModLibraryPath -EventName $EventName

    $Mods = Get-ModsetArgument -ModsetPath $ModsetPath
    $Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -mod=$Mods"

    Start-ArmaServer -ExePath $ExePath -Arguments $Arguments
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
