<#
.SYNOPSIS
Entry point for all Arma scripts (UAC elevation + action dispatch).

.DESCRIPTION
Called by the .bat launchers. Re-launches itself as Administrator, then dispatches to:
- start_server.ps1 for dedicated servers
- hc.ps1 for headless clients
- update_servers.ps1 for SteamCMD updates

Also pauses on errors and on non-fatal warnings (flagged via common.ps1).
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("start-server", "hc", "update-servers")]
    [string]$Action,

    [ValidateSet(1, 2)]
    [int]$Index,

    [string]$EventName,
    [string]$ModsetPath,

    [switch]$SkipEvents,

    [int]$Port,

    [string]$ExePath,

    [string]$ConfigPath,

    [string]$ProfilesPath,

    [string]$NetworkConfigPath,

    [string]$ServerModsPath,

    [string]$ServerName,

    [string]$Label,

    [string]$MissionsPath,

    [string]$MissionPattern,

    [switch]$AutoInit,

    [string]$ExtraArgs
)

$ErrorActionPreference = "Stop"

function Wait-ExitKeypress {
    param(
        [string]$Prompt = "Press any key to close..."
    )

    try {
        if ($Host -and $Host.Name -eq "ConsoleHost" -and $Host.UI -and $Host.UI.RawUI) {
            Write-Host ""
            Write-Host $Prompt -ForegroundColor Yellow
            [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } catch { }
}

function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# UAC elevation: re-run this script as Administrator with the same arguments.
if (-not (Test-IsAdmin)) {
    try {
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $PSCommandPath,
            "-Action", $Action
        )

        if ($PSBoundParameters.ContainsKey("Index")) {
            $argList += @("-Index", $Index)
        }
        if ($PSBoundParameters.ContainsKey("EventName")) {
            $argList += @("-EventName", $EventName)
        }
        if ($PSBoundParameters.ContainsKey("ModsetPath")) {
            $argList += @("-ModsetPath", $ModsetPath)
        }
        if ($SkipEvents) {
            $argList += "-SkipEvents"
        }
        foreach ($k in @("Port", "ExePath", "ConfigPath", "ProfilesPath", "NetworkConfigPath", "ServerModsPath", "ServerName", "Label", "MissionsPath", "MissionPattern", "ExtraArgs")) {
            if ($PSBoundParameters.ContainsKey($k)) {
                $argList += @("-$k", (Get-Variable -Name $k -ValueOnly))
            }
        }
        if ($AutoInit) {
            $argList += "-AutoInit"
        }

        $p = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru
        exit $p.ExitCode
    }
    catch {
        Write-Error $_.Exception.Message
        Wait-ExitKeypress -Prompt "Unable to start elevated process. Press any key to close..."
        exit 1
    }
}

$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

try {
    # Reset the warning flag for this run (common.ps1 sets this when a warning should pause before exit).
    $global:ArmaStartupHadWarnings = $false
    $exitCode = 0

    switch ($Action) {
        "start-server" {
            # Dedicated server startup is fully parameter-driven; the BAT provides all server-specific values.
            if ([string]::IsNullOrWhiteSpace($ModsetPath)) { throw "ModsetPath is required for Action=start-server." }
            if (-not $SkipEvents -and [string]::IsNullOrWhiteSpace($EventName)) { throw "EventName is required for Action=start-server unless -SkipEvents is set." }
            if (-not $PSBoundParameters.ContainsKey("Port")) { throw "Port is required for Action=start-server." }
            if ([string]::IsNullOrWhiteSpace($ExePath)) { throw "ExePath is required for Action=start-server." }
            if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw "ConfigPath is required for Action=start-server." }
            if ([string]::IsNullOrWhiteSpace($ProfilesPath)) { throw "ProfilesPath is required for Action=start-server." }

            $startArgs = @{
                EventName     = $EventName
                ModsetPath    = $ModsetPath
                SkipEvents    = $SkipEvents
                Port          = $Port
                ExePath       = $ExePath
                ConfigPath    = $ConfigPath
                ProfilesPath  = $ProfilesPath
            }

            foreach ($k in @("NetworkConfigPath", "ServerModsPath", "ServerName", "Label", "MissionsPath", "MissionPattern", "ExtraArgs")) {
                if ($PSBoundParameters.ContainsKey($k)) {
                    $startArgs[$k] = (Get-Variable -Name $k -ValueOnly)
                }
            }
            if ($AutoInit) {
                $startArgs["AutoInit"] = $true
            }

            & (Join-Path $ScriptRoot "start_server.ps1") @startArgs
            $exitCode = $LASTEXITCODE
            break
        }
        "hc" {
            # Local headless client (connects to the main server on localhost).
            if (-not $PSBoundParameters.ContainsKey("Index")) { throw "Index is required for Action=hc." }
            if ([string]::IsNullOrWhiteSpace($ModsetPath)) { throw "ModsetPath is required for Action=hc." }

            & (Join-Path $ScriptRoot "hc.ps1") -Index $Index -ModsetPath $ModsetPath
            $exitCode = $LASTEXITCODE
            break
        }
        "update-servers" {
            # SteamCMD update for all server install folders.
            & (Join-Path $ScriptRoot "update_servers.ps1")
            $exitCode = $LASTEXITCODE
            break
        }
    }

    # If warnings were emitted via Write-StartupWarning, pause so the console doesn't immediately close.
    if ($global:ArmaStartupHadWarnings) {
        Wait-ExitKeypress -Prompt "Warnings were reported. Press any key to close..."
    }

    exit $exitCode
}
catch {
    Write-Error $_.Exception.Message
    Wait-ExitKeypress
    exit 1
}
