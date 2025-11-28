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

    if (-not [IO.Path]::IsPathRooted($ModsetPath)) {
        $ModsetPath = Join-Path -Path $ParentPath -ChildPath $ModsetPath
    }
    if ([string]::IsNullOrWhiteSpace($ModsetPath) -or ($ModsetPath -notlike "*modpacks*")) {
        throw "ModsetPath resolved to an unsafe path: '$ModsetPath'"
    }

    $ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_main_hc\hc2"
    $ExePath      = Join-Path -Path $ParentPath -ChildPath "server_main_hc\arma3server_x64.exe"
    $Port         = 2302

    $SecretsPath = Join-Path -Path $ScriptRoot -ChildPath "secrets.txt"
    $secrets = Load-SecretsFile -SecretsPath $SecretsPath
    $JoinPassword = Resolve-ConnectPassword -ParentPath $ParentPath -Secrets $secrets -SecretsPath $SecretsPath

    $ParserScript = Join-Path -Path $CommonPaths.ParserRoot -ChildPath "Parser.py"
    $PythonExe    = Get-ParserPython -ParserRoot $CommonPaths.ParserRoot

    Invoke-EventParser -ParserRoot $CommonPaths.ParserRoot -ParserScript $ParserScript -LibraryA3SPath $CommonPaths.LibraryA3SPath -EventsJsonPath $CommonPaths.EventsJsonPath -PythonExe $PythonExe

    $eventInfo = Get-EventDefinition -EventsJsonPath $CommonPaths.EventsJsonPath -EventName $EventName
    Rebuild-ModsetLinks -ModsetPath $ModsetPath -Mods $eventInfo.Mods -ModLibraryPath $CommonPaths.ModLibraryPath -EventName $EventName

    $Mods = Get-ModsetArgument -ModsetPath $ModsetPath

    $Arguments = "-client -connect=127.0.0.1 -port=$Port -password=$JoinPassword -profiles=$ProfilesPath -malloc=mimalloc_v206_LockPages -hugepages -maxMem=16000 -limitFPS=500 -enableHT -mod=$Mods"

    Start-ArmaServer -ExePath $ExePath -Arguments $Arguments
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
