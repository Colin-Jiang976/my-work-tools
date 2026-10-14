# Get paths
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$ConfigFilePath = "$PSScriptRoot/config.json"
$SecretsFolderPath = "$PSScriptRoot/secrets"
$LoaderModulePath = "$PSScriptRoot/modules/ConfigLoader.ps1"
$LogModulePath = "$PSScriptRoot/modules/OpenTodayLogs.ps1"
$SecretStoreModulePath = "$PSScriptRoot/modules/SecretStore.ps1"
$FirstRunSetupModulePath = "$PSScriptRoot/modules/FirstRunSetup.ps1"
$PasswordBookModulePath = "$PSScriptRoot/modules/PasswordBook.ps1"
$PageModulePath = "$PSScriptRoot/modules/OpenMorningPages.ps1"

# Load modules
if (Test-Path $LoaderModulePath) {
    . $LoaderModulePath
}

if (Test-Path $LogModulePath) {
    . $LogModulePath
}

if (Test-Path $SecretStoreModulePath) {
    . $SecretStoreModulePath
}

if (Test-Path $FirstRunSetupModulePath) {
    . $FirstRunSetupModulePath
}

if (Test-Path $PasswordBookModulePath) {
    . $PasswordBookModulePath
}

if (Test-Path $PageModulePath) {
    . $PageModulePath
}

# Run tools
$ConfigData = Get-ToolConfig -ConfigPath $ConfigFilePath

if ($null -ne $ConfigData) {
    # First run on this PC: ask for the server IP once, then remember it.
    if (Get-Command Repair-ServerConfig -ErrorAction SilentlyContinue) {
        $ConfigData = Repair-ServerConfig -Config $ConfigData -ConfigPath $ConfigFilePath
    }

    Invoke-OpenTodayLogs -Config $ConfigData
    Invoke-OpenMorningPages -Config $ConfigData -SecretsFolder $SecretsFolderPath
}

Start-Sleep -Seconds 3
