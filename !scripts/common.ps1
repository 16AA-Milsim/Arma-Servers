# Shared helpers for Arma server startup scripts.

$ErrorActionPreference = "Stop"

$CommonPaths = @{
    LibraryA3SPath = "F:\16AA\Arma-Servers\modpacks\library\.a3s"
    EventsJsonPath = "F:\16AA\Arma-Servers\a3s.events.json\events.json"
    ModLibraryPath = "F:\16AA\Arma-Servers\modpacks\library"
    ParserRoot     = "F:\16AA\zOther\a3s_to_json"
}

function Get-ParserPython {
    param(
        [Parameter(Mandatory)]
        [string]$ParserRoot
    )

    $python = Join-Path -Path $ParserRoot -ChildPath ".venv\Scripts\python.exe"
    if (Test-Path $python) {
        return $python
    }

    return "python"
}

function Invoke-EventParser {
    param(
        [Parameter(Mandatory)] [string]$ParserRoot,
        [Parameter(Mandatory)] [string]$ParserScript,
        [Parameter(Mandatory)] [string]$LibraryA3SPath,
        [Parameter(Mandatory)] [string]$EventsJsonPath,
        [Parameter(Mandatory)] [string]$PythonExe
    )

    $eventsDir = Split-Path -Path $EventsJsonPath -Parent
    if (-not (Test-Path $eventsDir)) {
        New-Item -ItemType Directory -Path $eventsDir | Out-Null
    }

    Write-Host "Running a3s_to_json to extract events..." -ForegroundColor Cyan
    Push-Location $ParserRoot
    try {
        Write-Host "Parser command: $PythonExe $ParserScript $LibraryA3SPath $EventsJsonPath --events" -ForegroundColor DarkGray
        & $PythonExe $ParserScript $LibraryA3SPath $EventsJsonPath --events
    }
    finally {
        Pop-Location
    }
}

function Get-EventDefinition {
    param(
        [Parameter(Mandatory)] [string]$EventsJsonPath,
        [Parameter(Mandatory)] [string]$EventName
    )

    Write-Host "Loading events JSON..." -ForegroundColor Cyan
    $eventsJson = Get-Content $EventsJsonPath -Raw | ConvertFrom-Json
    $event = $eventsJson.events.EVENTS.PSObject.Properties.Value |
        Where-Object { $_.name -eq $EventName } |
        Select-Object -First 1

    if (-not $event) {
        throw "Event '$EventName' not found in $EventsJsonPath"
    }

    $mods = @($event.mods)
    if (-not $mods -or $mods.Count -eq 0) {
        throw "Event '$EventName' contains no mods."
    }

    Write-Host "Selected event: '$($event.name)' with $($mods.Count) mods" -ForegroundColor Yellow
    Write-Host "Mods list:" -ForegroundColor DarkGray
    $mods | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }

    return [PSCustomObject]@{
        Event = $event
        Mods  = $mods
    }
}

function Resolve-ModsetPath {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath,
        [Parameter(Mandatory)] [string]$ParentPath
    )

    if (-not $ParentPath) {
        throw "Could not resolve ParentPath."
    }

    if (-not [IO.Path]::IsPathRooted($ModsetPath)) {
        $ModsetPath = Join-Path -Path $ParentPath -ChildPath $ModsetPath
    }
    if ([string]::IsNullOrWhiteSpace($ModsetPath) -or ($ModsetPath -notlike "*modpacks*")) {
        throw "ModsetPath resolved to an unsafe path: '$ModsetPath'"
    }

    return $ModsetPath
}

function Clear-ModsetSymlinks {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath
    )

    if (-not (Test-Path $ModsetPath)) {
        Write-Host "Modset path does not exist, nothing to clear: $ModsetPath" -ForegroundColor Yellow
        return
    }

    Write-Host "Clearing symlinks in $ModsetPath (leaving normal folders/files untouched)..." -ForegroundColor Cyan
    Get-ChildItem -Path $ModsetPath -Force | ForEach-Object {
        $isLink = $_.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isLink) {
            Write-Host "Removing symlink: $($_.FullName)" -ForegroundColor DarkGray
            Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
        } else {
            Write-Host "Leaving non-symlink: $($_.FullName)" -ForegroundColor DarkGray
        }
    }
}

function Normalize-ModList {
    param(
        [Parameter(Mandatory)] $Mods
    )

    $flat = New-Object System.Collections.Generic.List[string]

    function Add-ModRecursive {
        param($item)

        if ($null -eq $item) { return }

        # Strings are the terminal case
        if ($item -is [string]) {
            $flat.Add($item)
            return
        }

        # Enumerables (arrays/lists) need to be flattened
        if ($item -is [System.Collections.IEnumerable]) {
            foreach ($child in $item) {
                Add-ModRecursive $child
            }
            return
        }

        # Fallback to ToString()
        $flat.Add($item.ToString())
    }

    Add-ModRecursive $Mods
    return $flat
}

function Rebuild-ModsetLinks {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath,
        [Parameter(Mandatory)] [string[]]$Mods,
        [Parameter(Mandatory)] [string]$ModLibraryPath,
        [string]$EventName
    )

    $context = if ($EventName) { " for event '$EventName'" } else { "" }
    Write-Host "Rebuilding modset symlinks$context..." -ForegroundColor Cyan

    if (-not (Test-Path $ModsetPath)) {
        New-Item -ItemType Directory -Path $ModsetPath | Out-Null
    }

    Get-ChildItem -Path $ModsetPath -Force | ForEach-Object {
        $isLink = $_.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isLink) {
            Write-Host "Removing existing symlink: $($_.FullName)" -ForegroundColor DarkGray
            Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
        } else {
            Write-Host "Leaving non-symlink in place: $($_.FullName)" -ForegroundColor DarkGray
        }
    }

    $FlatMods = Normalize-ModList -Mods $Mods
    Write-Host ("Mods to link ({0}):" -f $FlatMods.Count) -ForegroundColor DarkGray
    $FlatMods | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }

    foreach ($mod in $FlatMods) {
        $normalized = $mod.ToString()
        try {
            $src = Join-Path -Path $ModLibraryPath -ChildPath $normalized -ErrorAction Stop
            $dest = Join-Path -Path $ModsetPath -ChildPath $normalized -ErrorAction Stop
        } catch {
            $detail = "Join-Path failed for mod '$mod' (type: $($mod.GetType().FullName)) with ModLibraryPath='$ModLibraryPath' ModsetPath='$ModsetPath'"
            throw "$detail. $_"
        }
        if (-not (Test-Path $src)) {
            Write-Warning "Source mod not found: $src"
            continue
        }
        if (Test-Path $dest) {
            $isLink = (Get-Item $dest -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint
            if (-not $isLink) {
                Write-Warning "Destination exists and is not a symlink, skipping: $dest"
                continue
            }
        }
        Write-Host "Linking $dest -> $src" -ForegroundColor DarkGray
        New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
    }
}

function Get-ModsetArgument {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath
    )

    return (Get-ChildItem -Path $ModsetPath -Directory -Filter "*@*" | Select-Object -ExpandProperty FullName) -join ';'
}

function Start-ArmaServer {
    param(
        [Parameter(Mandatory)] [string]$ExePath,
        [Parameter(Mandatory)] [string]$Arguments
    )

    Write-Host "Starting server with arguments:" -ForegroundColor Green
    Write-Host $Arguments

    Start-Process -FilePath "$ExePath" -ArgumentList $Arguments
}

function Get-UdpPortUsage {
    param(
        [Parameter(Mandatory)] [int[]]$Ports
    )

    $results = New-Object System.Collections.Generic.List[object]
    $uniquePorts = @($Ports | Sort-Object -Unique)

    $hasNetCmdlet = $null -ne (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
    if (-not $hasNetCmdlet) {
        $netstat = & netstat -ano -p udp 2>$null
        foreach ($line in $netstat) {
            $m = [regex]::Match($line, '^\s*UDP\s+(\S+):(\d+)\s+\*\:\*\s+(\d+)\s*$')
            if (-not $m.Success) { continue }

            $port = [int]$m.Groups[2].Value
            if ($uniquePorts -notcontains $port) { continue }

            $pid = [int]$m.Groups[3].Value
            $processName = $null
            try {
                $processName = (Get-Process -Id $pid -ErrorAction Stop).ProcessName
            }
            catch {
                $processName = "<unknown>"
            }

            $results.Add([PSCustomObject]@{
                Port          = $port
                LocalAddress  = $m.Groups[1].Value
                OwningProcess = $pid
                ProcessName   = $processName
            })
        }

        return $results
    }

    foreach ($port in $uniquePorts) {
        try {
            $endpoints = Get-NetUDPEndpoint -LocalPort $port -ErrorAction Stop
        }
        catch {
            continue
        }

        foreach ($ep in $endpoints) {
            $processName = $null
            try {
                $processName = (Get-Process -Id $ep.OwningProcess -ErrorAction Stop).ProcessName
            }
            catch {
                $processName = "<unknown>"
            }

            $results.Add([PSCustomObject]@{
                Port          = $port
                LocalAddress  = $ep.LocalAddress
                OwningProcess = $ep.OwningProcess
                ProcessName   = $processName
            })
        }
    }

    return $results
}

function Assert-UdpPortsFree {
    param(
        [Parameter(Mandatory)] [int[]]$Ports,
        [string]$Label
    )

    $usage = Get-UdpPortUsage -Ports $Ports
    if (-not $usage -or $usage.Count -eq 0) {
        return
    }

    $title = if ($Label) { "Port check failed ($Label)" } else { "Port check failed" }
    $usedPorts = ($usage | Sort-Object Port | Select-Object -ExpandProperty Port -Unique) -join ", "

    $details = $usage |
        Sort-Object Port, OwningProcess |
        ForEach-Object { " - UDP $($_.LocalAddress):$($_.Port) (PID $($_.OwningProcess): $($_.ProcessName))" }

    throw ($title + ": required UDP port(s) are already in use: $usedPorts`r`n" + ($details -join "`r`n"))
}

function Assert-ArmaServerPortsFree {
    param(
        [Parameter(Mandatory)] [int]$BasePort,
        [string]$Label
    )

    # Arma 3 dedicated server uses the game port plus several adjacent UDP ports
    # (Steam query/communication + BattlEye). When any are occupied, Arma will
    # silently shift the base port to a higher free range.
    $portsToCheck = @($BasePort, ($BasePort + 1), ($BasePort + 2), ($BasePort + 3), ($BasePort + 4))
    Assert-UdpPortsFree -Ports $portsToCheck -Label $Label
}

function Show-ErrorAndExit {
    param(
        [Parameter(Mandatory)] [string]$Message
    )

    $hint = @(
        "",
        "Troubleshooting:",
        " - Check Task Manager for stuck Arma processes and close them (e.g. arma3server_x64.exe / arma3serverprofiling_x64.exe).",
        " - If this is a port error, make sure the required UDP port range is free before starting."
    ) -join "`r`n"

    $fullMessage = $Message + $hint

    Write-Error $fullMessage

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.MessageBox]::Show($fullMessage, "Arma Startup Error", 'OK', 'Error') | Out-Null
    } catch {
        # If WinForms is unavailable, just rely on console error output.
    }

    exit 1
}

function Select-LatestMission {
    param(
        [Parameter(Mandatory)] [string]$MissionsPath,
        [Parameter(Mandatory)] [string]$MissionPattern
    )

    $missionFile = Get-ChildItem -Path $MissionsPath -Filter $MissionPattern -ErrorAction SilentlyContinue |
        Sort-Object { [int]([regex]::Match($_.Name, 'V(\d+)').Groups[1].Value) } -Descending |
        Select-Object -First 1

    if (-not $missionFile) {
        throw "No mission matching pattern '$MissionPattern' found in $MissionsPath"
    }

    return [PSCustomObject]@{
        File      = $missionFile
        Path      = $missionFile.FullName
        Template  = [IO.Path]::GetFileNameWithoutExtension($missionFile.Name)
    }
}

function Update-CfgTemplate {
    param(
        [Parameter(Mandatory)] [string]$ConfigPath,
        [Parameter(Mandatory)] [string]$MissionTemplate
    )

    $cfgLines = Get-Content $ConfigPath
    $cfgLines = $cfgLines | ForEach-Object {
        if ($_ -match '^\s*template\s*=') {
            "        template    = ""$MissionTemplate"";"
        } else {
            $_
        }
    }

    Set-Content -Path $ConfigPath -Value ($cfgLines -join "`r`n")
}

function Load-SecretsFile {
    param(
        [Parameter(Mandatory)] [string]$SecretsPath
    )

    $secrets = @{}
    if (-not (Test-Path $SecretsPath)) {
        return $secrets
    }

    foreach ($line in Get-Content -Path $SecretsPath) {
        if (-not $line -or $line -match '^\s*#') { continue }
        $pair = $line -split '=', 2
        if ($pair.Count -eq 2) {
            $key = $pair[0].Trim()
            $value = $pair[1].Trim()
            if ($key) {
                $secrets[$key] = $value
            }
        }
    }

    return $secrets
}

function Resolve-SecretValue {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [Parameter()][hashtable]$Secrets,
        [Parameter()][string]$SecretsPath,
        [switch]$Mandatory
    )

    $envValue = [Environment]::GetEnvironmentVariable($Key)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) {
        return $envValue
    }

    if ($Secrets -and $Secrets.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Secrets[$Key])) {
        return $Secrets[$Key]
    }

    if ($Mandatory) {
        $locationHint = if ($SecretsPath) { $SecretsPath } else { "<path to secrets.txt>" }
        throw "Secret '$Key' not provided. Set environment variable $Key or add it to $locationHint (see secrets.txt.sample)."
    }

    return $null
}

function Get-ArmaPasswordFromConfig {
    param(
        [Parameter(Mandatory)] [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        return $null
    }

    foreach ($line in Get-Content -Path $ConfigPath) {
        $match = [regex]::Match($line, '^\s*password\s*=\s*\"([^\"]+)\"')
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return $null
}

function Resolve-ConnectPassword {
    param(
        [Parameter(Mandatory)] [string]$ParentPath,
        [hashtable]$Secrets,
        [string]$SecretsPath
    )

    $Candidates = @(
        Join-Path -Path $ParentPath -ChildPath "configs\passwords.hpp" -ErrorAction Stop
        Join-Path -Path $ParentPath -ChildPath "configs\passwords_main.hpp" -ErrorAction Stop
        Join-Path -Path $ParentPath -ChildPath "configs\passwords_testing.hpp" -ErrorAction Stop
        Join-Path -Path $ParentPath -ChildPath "configs\passwords_training.hpp" -ErrorAction Stop
    )

    foreach ($cfg in $Candidates) {
        $pw = Get-ArmaPasswordFromConfig -ConfigPath $cfg
        if ($pw) {
            Write-Host "Using join password from $cfg" -ForegroundColor DarkGray
            return $pw
        }
    }

    # Fallback to secrets/env
    return Resolve-SecretValue -Key "ARMA_CONNECT_PASSWORD" -Secrets $Secrets -SecretsPath $SecretsPath -Mandatory
}
