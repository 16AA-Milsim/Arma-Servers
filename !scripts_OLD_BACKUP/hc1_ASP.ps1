# Get secrets from file in key-value pairs
$secretsFilePath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.txt"
$secrets = @{}
Get-Content -Path $secretsFilePath | ForEach-Object {
    $key, $value = $_ -split '=', 2
    $secrets[$key] = $value
}
$ParentPath = Split-Path -Path $PSScriptRoot -Parent
$ModpackPath = Join-Path -Path $ParentPath -ChildPath "modpacks\main"
$ProfilesPath = Join-Path -Path $ParentPath -ChildPath "logs_main_hc\hc1"
$ExePath = Join-Path -Path $ParentPath -ChildPath "server_main_hc\arma3server_x64.exe"
$ProfilerPath = Join-Path -Path $ParentPath -ChildPath "servermods\@ArmaScriptProfiler"
$InterceptPath = Join-Path -Path $ParentPath -ChildPath "servermods\@InterceptMinimalDev"

$joinPassword = $secrets["ARMA_CONNECT_PASSWORD"]
$Mods = (Get-ChildItem -Path $ModpackPath -Directory -Filter "*@*"  | Select-Object -expand fullname) -join ';'

$Arguments = "-client -connect=127.0.0.1 -port=2302 -password=$joinPassword -profiles=$ProfilesPath -malloc=mimalloc_v206_LockPages -hugepages -maxMem=16000 -limitFPS=500 -enableHT -mod=$ProfilerPath;$InterceptPath -profilerEnableNetwork -mod=$Mods"

echo "args:" + $Arguments

Start-Process -FilePath "$ExePath" -ArgumentList $Arguments