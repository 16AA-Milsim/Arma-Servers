$ParentPath = $PSScriptRoot
$MainPath = Join-Path -Path $ParentPath -ChildPath "main_startup.ps1"
$TrainingPath = Join-Path -Path $ParentPath -ChildPath "training_startup_camp_pegasus.ps1"
$TestingPath = Join-Path -Path $ParentPath -ChildPath "testing_startup.ps1"
$Hc1Path = Join-Path -Path $ParentPath -ChildPath "hc1.ps1"
$Hc2Path = Join-Path -Path $ParentPath -ChildPath "hc2.ps1"

powershell -executionpolicy bypass -File $MainPath
Start-Sleep -Seconds 2
powershell -executionpolicy bypass -File $TrainingPath
Start-Sleep -Seconds 2
powershell -executionpolicy bypass -File $TestingPath
Start-Sleep -Seconds 2
powershell -executionpolicy bypass -File $Hc1Path
Start-Sleep -Seconds 2
powershell -executionpolicy bypass -File $Hc2Path