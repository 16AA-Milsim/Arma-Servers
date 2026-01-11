<#
.SYNOPSIS
Shared helpers for Arma server startup scripts.

.DESCRIPTION
Contains reusable functions for:
- Updating/parsing event mod lists (events.json)
- Building/clearing modset symlinks (with hash caching)
- Starting processes and validating UDP ports
- Secrets lookup and user-friendly error UI/pause behavior
#>

$ErrorActionPreference = "Stop"

# Canonical paths used by the event parser + mod library.
$script:CommonPaths = @{
    LibraryA3SPath = "F:\16AA\Arma-Servers\modpacks\library\.a3s"
    EventsJsonPath = "F:\16AA\Arma-Servers\a3s.events.json\events.json"
    ModLibraryPath = "F:\16AA\Arma-Servers\modpacks\library"
    ParserRoot     = "F:\16AA\zOther\a3s_to_json"
}

function Get-CommonPaths {
    # Exposes CommonPaths to dot-sourced scripts without triggering "assigned but never used" warnings.
    return $script:CommonPaths
}

$EventParserMutexName = "Global\16AA-Arma-Servers-EventsJson"

if ($null -eq $global:ArmaStartupHadWarnings) {
    $global:ArmaStartupHadWarnings = $false
}

# Marks a non-fatal warning that should keep the console open for review.
function Write-StartupWarning {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $global:ArmaStartupHadWarnings = $true
    Write-Warning $Message
}

# Pauses in ConsoleHost so a script doesn't close before the message is read.
function Wait-StartupExitKeypress {
    param(
        [string]$Prompt = "Press any key to close..."
    )

    try {
        Write-Host ""
        Write-Host $Prompt -ForegroundColor Yellow

        if ($Host -and $Host.UI -and $Host.UI.RawUI) {
            [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }

        try {
            [void][Console]::ReadKey($true)
            return
        } catch { }

        [void](Read-Host)
    } catch { }
}

# Runs a scriptblock under a named Windows mutex (used to serialize event parsing).
function Invoke-WithMutex {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock
    )

    $mutex = New-Object System.Threading.Mutex($false, $Name)
    $lockTaken = $false
    try {
        $lockTaken = $mutex.WaitOne(0)
        if (-not $lockTaken) {
            Write-Host "Another startup is updating events.json; waiting for lock..." -ForegroundColor Yellow
            $lockTaken = $mutex.WaitOne()
        }

        & $ScriptBlock
    }
    finally {
        if ($lockTaken) {
            try { $mutex.ReleaseMutex() } catch { }
        }
        $mutex.Dispose()
    }
}

# Prefers a local venv python.exe if present, otherwise falls back to "python" on PATH.
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

# Executes the Python parser to extract/update events.json.
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

# Updates events.json (serialized by mutex) and returns the selected event definition.
function Update-EventsAndGetDefinition {
    param(
        [Parameter(Mandatory)] [string]$ParserRoot,
        [Parameter(Mandatory)] [string]$ParserScript,
        [Parameter(Mandatory)] [string]$LibraryA3SPath,
        [Parameter(Mandatory)] [string]$EventsJsonPath,
        [Parameter(Mandatory)] [string]$PythonExe,
        [Parameter(Mandatory)] [string]$EventName
    )

    return Invoke-WithMutex -Name $EventParserMutexName -ScriptBlock {
        Invoke-EventParser -ParserRoot $ParserRoot -ParserScript $ParserScript -LibraryA3SPath $LibraryA3SPath -EventsJsonPath $EventsJsonPath -PythonExe $PythonExe
        Get-EventDefinition -EventsJsonPath $EventsJsonPath -EventName $EventName
    }
}

# Loads events.json and returns the matching event + mod list.
function Get-EventDefinition {
    param(
        [Parameter(Mandatory)] [string]$EventsJsonPath,
        [Parameter(Mandatory)] [string]$EventName
    )

    Write-Host "Loading events JSON..." -ForegroundColor Cyan
    $eventsJson = Get-Content $EventsJsonPath -Raw | ConvertFrom-Json
    $eventDefinition = $eventsJson.events.EVENTS.PSObject.Properties.Value |
        Where-Object { $_.name -eq $EventName } |
        Select-Object -First 1

    if (-not $eventDefinition) {
        throw "Event '$EventName' not found in $EventsJsonPath"
    }

    $mods = @($eventDefinition.mods)
    if (-not $mods -or $mods.Count -eq 0) {
        throw "Event '$EventName' contains no mods."
    }

    Write-Host "Selected event: '$($eventDefinition.name)' with $($mods.Count) mods" -ForegroundColor Yellow
    Write-Host "Mods list:" -ForegroundColor DarkGray
    $mods | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }

    return [PSCustomObject]@{
        Event = $eventDefinition
        Mods  = $mods
    }
}

# Resolves and validates a modset path (ensures it stays under the modpacks directory).
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

# Removes only symlinks inside the modset folder (leaves real files/folders untouched).
function Clear-ModsetSymlinks {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath
    )

    if (-not (Test-Path $ModsetPath)) {
        Write-Host "Modset path does not exist, nothing to clear: $ModsetPath" -ForegroundColor Yellow
        return
    }

    Write-Host "Clearing symlinks in $ModsetPath (leaving normal folders/files untouched)..." -ForegroundColor Cyan
    Remove-SymlinkChildren -Path $ModsetPath -RemovePrefix "Removing symlink:" -KeepPrefix "Leaving non-symlink:"
}

# Helper used by Clear-ModsetSymlinks/Update-ModsetSymlinks to delete only symlink children.
function Remove-SymlinkChildren {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$RemovePrefix,
        [Parameter(Mandatory)] [string]$KeepPrefix
    )

    Get-ChildItem -Path $Path -Force | ForEach-Object {
        $isLink = $_.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isLink) {
            Write-Host "$RemovePrefix $($_.FullName)" -ForegroundColor DarkGray
            Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
        } else {
            Write-Host "$KeepPrefix $($_.FullName)" -ForegroundColor DarkGray
        }
    }
}

# Flattens a nested mod list into a simple string list.
function ConvertTo-FlatModList {
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

# Computes a stable SHA-256 hash for a mod list (used by the modset cache).
function Get-ModListHash {
    param(
        [Parameter(Mandatory)]
        [string[]]$Mods
    )

    $normalized = @($Mods | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
    $payload = ($normalized -join "`n")

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

# Returns the cache file path stored within a modset directory.
function Get-ModsetCachePath {
    param(
        [Parameter(Mandatory)]
        [string]$ModsetPath
    )

    return (Join-Path -Path $ModsetPath -ChildPath ".modset.cache.json")
}

# Reads the modset cache JSON; returns null on missing/invalid cache.
function Read-ModsetCache {
    param(
        [Parameter(Mandatory)]
        [string]$ModsetPath
    )

    $cachePath = Get-ModsetCachePath -ModsetPath $ModsetPath
    if (-not (Test-Path $cachePath)) {
        return $null
    }

    try {
        return (Get-Content -Raw -Path $cachePath | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

# Writes the modset cache JSON (hash + metadata).
function Write-ModsetCache {
    param(
        [Parameter(Mandatory)]
        [string]$ModsetPath,

        [Parameter(Mandatory)]
        [string]$Hash,

        [Parameter(Mandatory)]
        [string[]]$RequestedMods,

        [string]$EventName,

        [string[]]$MissingMods
    )

    $cachePath = Get-ModsetCachePath -ModsetPath $ModsetPath
    $payload = [PSCustomObject]@{
        version       = 1
        updatedUtc    = [DateTime]::UtcNow.ToString("o")
        hash          = $Hash
        event         = $EventName
        requestedMods = @($RequestedMods)
        missingMods   = @($MissingMods)
    }

    $json = $payload | ConvertTo-Json -Depth 4
    Set-Content -Path $cachePath -Value $json -Encoding UTF8
}

# Verifies the current symlink set matches the expected mod list (for cache hits).
function Test-ModsetLinksMatch {
    param(
        [Parameter(Mandatory)]
        [string]$ModsetPath,

        [Parameter(Mandatory)]
        [string[]]$ExpectedMods,

        [Parameter(Mandatory)]
        [string]$ModLibraryPath
    )

    if (-not (Test-Path $ModsetPath)) {
        return $false
    }

    $expectedExisting = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $ExpectedMods) {
        $src = Join-Path -Path $ModLibraryPath -ChildPath $m
        if (Test-Path $src) {
            [void]$expectedExisting.Add($m)
        }
    }

    foreach ($m in $expectedExisting) {
        $dest = Join-Path -Path $ModsetPath -ChildPath $m
        if (-not (Test-Path $dest)) {
            return $false
        }
        $item = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue
        if (-not $item) {
            return $false
        }
        $isLink = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
        if (-not $isLink) {
            return $false
        }
    }

    $existingSymlinkDirs = Get-ChildItem -Path $ModsetPath -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } |
        Select-Object -ExpandProperty Name

    foreach ($name in $existingSymlinkDirs) {
        if (-not $expectedExisting.Contains($name)) {
            return $false
        }
    }

    return $true
}

# Builds the modset folder by symlinking mods from the library (skips work if cache matches).
function Update-ModsetSymlinks {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath,
        [Parameter(Mandatory)] [string[]]$Mods,
        [Parameter(Mandatory)] [string]$ModLibraryPath,
        [string]$EventName
    )

    $context = if ($EventName) { " for event '$EventName'" } else { "" }
    Write-Host "Ensuring modset symlinks are up to date$context..." -ForegroundColor Cyan

    if (-not (Test-Path $ModsetPath)) {
        New-Item -ItemType Directory -Path $ModsetPath | Out-Null
    }

    $FlatMods = ConvertTo-FlatModList -Mods $Mods
    Write-Host ("Requested mod list ({0}):" -f $FlatMods.Count) -ForegroundColor DarkGray
    $FlatMods | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }

    $hash = Get-ModListHash -Mods $FlatMods
    $cache = Read-ModsetCache -ModsetPath $ModsetPath

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($m in $FlatMods) {
        $src = Join-Path -Path $ModLibraryPath -ChildPath $m
        if (-not (Test-Path $src)) {
            $missing.Add($m)
        }
    }
    if ($missing.Count -gt 0) {
        Write-StartupWarning ("Missing mod folders in library ({0}): {1}" -f $missing.Count, (($missing | Sort-Object -Unique) -join ", "))
    }

    $cacheHit = $cache -and $cache.hash -and ($cache.hash -eq $hash)
    if ($cacheHit -and (Test-ModsetLinksMatch -ModsetPath $ModsetPath -ExpectedMods $FlatMods -ModLibraryPath $ModLibraryPath)) {
        Write-Host ("Modset is already up to date (hash {0}); symlinks match; skipping relink." -f $hash) -ForegroundColor Cyan
        return
    }

    Write-Host "Relinking modset symlinks..." -ForegroundColor Cyan
    Remove-SymlinkChildren -Path $ModsetPath -RemovePrefix "Removing existing symlink:" -KeepPrefix "Leaving non-symlink in place:"

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
            Write-StartupWarning "Source mod not found: $src"
            continue
        }
        if (Test-Path $dest) {
            $isLink = (Get-Item $dest -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint
            if (-not $isLink) {
                Write-StartupWarning "Destination exists and is not a symlink, skipping: $dest"
                continue
            }
        }
        Write-Host "Linking $dest -> $src" -ForegroundColor DarkGray
        New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
    }

    Write-ModsetCache -ModsetPath $ModsetPath -Hash $hash -RequestedMods $FlatMods -EventName $EventName -MissingMods @($missing)
}

# Builds the Arma -mod= argument from directories present in the modset folder.
function Get-ModsetArgument {
    param(
        [Parameter(Mandatory)] [string]$ModsetPath
    )

    return (Get-ChildItem -Path $ModsetPath -Directory -Filter "*@*" | Select-Object -ExpandProperty FullName) -join ';'
}

# Starts an Arma-related process with a prebuilt argument string.
function Start-ArmaServer {
    param(
        [Parameter(Mandatory)] [string]$ExePath,
        [Parameter(Mandatory)] [string]$Arguments
    )

    Write-Host "Starting server with arguments:" -ForegroundColor Green
    Write-Host $Arguments

    $workingDirectory = Split-Path -Path $ExePath -Parent

    # Attach the Arma process to the current console so its output is visible when launched from a .bat (even via double-click).
    $process = Start-Process -FilePath $ExePath -ArgumentList $Arguments -WorkingDirectory $workingDirectory -NoNewWindow -PassThru

    # If Arma exits immediately with a non-zero code, keep the console open so the error/output can be read.
    Start-Sleep -Milliseconds 400
    if ($process -and $process.HasExited -and $process.ExitCode -ne 0) {
        Show-ErrorAndExit ("Process exited immediately (code {0})." -f $process.ExitCode)
    }
}

# Returns UDP port usage information (Get-NetUDPEndpoint when available, otherwise netstat).
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

            $processId = [int]$m.Groups[3].Value
            $processName = $null
            try {
                $processName = (Get-Process -Id $processId -ErrorAction Stop).ProcessName
            }
            catch {
                $processName = "<unknown>"
            }

            $results.Add([PSCustomObject]@{
                Port          = $port
                LocalAddress  = $m.Groups[1].Value
                OwningProcess = $processId
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

# Throws if any of the provided UDP ports are in use.
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

# Throws if the Arma base port range is in use (base + adjacent ports).
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

# Shows a user-friendly error (console + optional messagebox) and exits non-zero.
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

    # Use non-terminating error output so we can always show UI/pause even under $ErrorActionPreference='Stop'.
    Write-Error $fullMessage -ErrorAction Continue

    $shown = $false
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.MessageBox]::Show($fullMessage, "Arma Startup Error", 'OK', 'Error') | Out-Null
        $shown = $true
    } catch { }

    if (-not $shown) {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
            [System.Windows.MessageBox]::Show($fullMessage, "Arma Startup Error", 'OK', 'Error') | Out-Null
            $shown = $true
        } catch { }
    }

    if (-not $shown) {
        try {
            # Fallback: works even when WinForms/WPF assemblies aren't available.
            $wsh = New-Object -ComObject WScript.Shell
            # 0 = wait indefinitely, 0x10 = critical icon
            [void]$wsh.Popup($fullMessage, 0, "Arma Startup Error", 0x10)
            $shown = $true
        } catch { }
    }

    # Prefer a tidy popup-only flow; only fall back to console pause when we cannot show UI.
    if (-not $shown) {
        Wait-StartupExitKeypress
    }
    exit 1
}

# Selects the highest mission version matching a pattern (expects V<number> in filename).
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

# Updates the "template" entry in a server cfg to match the chosen mission.
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

# Loads key=value secrets from a text file (ignores blank lines and comments).
function Get-SecretsFromFile {
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

# Resolves a secret from env var first, then from config\secrets.txt, optionally requiring it.
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
        $locationHint = if ($SecretsPath) { $SecretsPath } else { "<path to config\\secrets.txt>" }
        throw "Secret '$Key' not provided. Set environment variable $Key or add it to $locationHint (see config\\secrets.txt.sample)."
    }

    return $null
}

# Reads "password = \"...\"" from an Arma config file (returns null if missing).
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

# Resolves the join password from passwords*.hpp or from ARMA_CONNECT_PASSWORD.
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
