# 1. Locate root folder (using standard forward slashes for subpaths)
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFilePath = "$PSScriptRoot/config.json"
$LoaderModulePath = "$PSScriptRoot/modules/ConfigLoader.ps1"
$LogModulePath = "$PSScriptRoot/modules/OpenTodayLogs.ps1"

# 2. Import modules
if (Test-Path $LoaderModulePath) { . $LoaderModulePath }
if (Test-Path $LogModulePath) { . $LogModulePath }

# 3. Process

    $ConfigData = Get-ToolConfig -ConfigPath $ConfigFilePath
    if ($null -ne $ConfigData) {
        Invoke-OpenTodayLogs -Config $ConfigData
    }

Start-Sleep -Seconds 3