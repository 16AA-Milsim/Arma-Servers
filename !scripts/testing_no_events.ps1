#requires -RunAsAdministrator

param(
    [string]$ModsetPath
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. (Join-Path $ScriptRoot 'common.ps1')

try {
    $ParentPath = Split-Path -Path $ScriptRoot -Parent
    if (-not $ParentPath) {
        throw "Could not resolve ParentPath from script root ($ScriptRoot)."
    }

    $ModsetPath = Resolve-ModsetPath -ModsetPath $ModsetPath -ParentPath $ParentPath

    # Clear only symlinks, leave real folders/files
    Clear-ModsetSymlinks -ModsetPath $ModsetPath

    $NetworkConfigPath = Join-Path -Path $ParentPath -ChildPath "configs\network.cfg"
    $ProfilesPath      = Join-Path -Path $ParentPath -ChildPath "logs_testing"
    $ConfigPath        = Join-Path -Path $ParentPath -ChildPath "configs\testing.cfg"
    $ExePath           = Join-Path -Path $ParentPath -ChildPath "server_testing\arma3serverprofiling_x64.exe"
    $Port              = 2442

    $Mods = Get-ModsetArgument -ModsetPath $ModsetPath
    Write-Host ("Mods to load (post-clear): {0}" -f (($Mods -split ';').Count)) -ForegroundColor DarkGray
    $Arguments = "-config=$ConfigPath -cfg=$NetworkConfigPath -profiles=$ProfilesPath -port=$Port -name=16aa -filePatching -hugepages -maxMem=16000 -malloc=mimalloc_v206_LockPages -enableHT -bandwidthAlg=2 -limitFPS=1000 -loadMissionToMemory -mod=$Mods"

    Start-ArmaServer -ExePath $ExePath -Arguments $Arguments
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
