#requires -RunAsAdministrator

param(
    [Parameter(Mandatory)] [string]$ModsetPath
)

$ErrorActionPreference = "Stop"

try {
    $ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $ParentPath = Split-Path -Path $ScriptRoot -Parent

    if (-not [IO.Path]::IsPathRooted($ModsetPath)) {
        $ModsetPath = Join-Path -Path $ParentPath -ChildPath $ModsetPath
    }

    if ([string]::IsNullOrWhiteSpace($ModsetPath) -or ($ModsetPath -notlike "*modpacks*")) {
        throw "ModsetPath resolved to an unsafe path: '$ModsetPath'"
    }

    if (-not (Test-Path $ModsetPath)) {
        Write-Host "Modset path does not exist, nothing to clear: $ModsetPath" -ForegroundColor Yellow
        exit 0
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
catch {
    Write-Error $_.Exception.Message
    exit 1
}
