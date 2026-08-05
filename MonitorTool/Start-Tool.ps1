# Get paths
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$ConfigFilePath = "$PSScriptRoot/config.json"
$LoaderModulePath = "$PSScriptRoot/modules/ConfigLoader.ps1"
$LogModulePath = "$PSScriptRoot/modules/OpenTodayLogs.ps1"
$PageModulePath = "$PSScriptRoot/modules/OpenMorningPages.ps1"

# Load modules
if (Test-Path $LoaderModulePath) {
    . $LoaderModulePath
}

if (Test-Path $LogModulePath) {
    . $LogModulePath
}

if (Test-Path $PageModulePath) {
    . $PageModulePath
}

# Run tools
$ConfigData = Get-ToolConfig -ConfigPath $ConfigFilePath

if ($null -ne $ConfigData) {
    Invoke-OpenTodayLogs -Config $ConfigData
    Invoke-OpenMorningPages -Config $ConfigData
}

Start-Sleep -Seconds 3