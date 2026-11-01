#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [string]$LogRoot,
    [datetime]$Now = (Get-Date),
    [switch]$Preview,
    [switch]$SkipPages
)
$ErrorActionPreference = 'Stop'
try {
    foreach ($name in 'ConfigLoader','LogIO','OpenTodayLogs','SecretStore',
                         'FirstRunSetup','PasswordBook','OpenMorningPages') {
        $module = Join-Path $PSScriptRoot "modules/$name.ps1"
        if (-not (Test-Path -LiteralPath $module -PathType Leaf)) {
            throw "Required module missing: $module"
        }
        . $module
    }
    $config = Get-ToolConfig -ConfigPath $ConfigPath
    # Preview never prompts for setup, modifies config or touches the clipboard.
    if (-not $Preview -and [string]::IsNullOrWhiteSpace($LogRoot)) {
        $config = Repair-ServerConfig -Config $config -ConfigPath $ConfigPath
        if ([string]::IsNullOrWhiteSpace($config.ServerIP) -or $config.ServerIP -eq '<YOUR_SERVER_IP>') {
            throw 'Server not configured. Use -LogRoot for a local demonstration.'
        }
    }
    Invoke-OpenTodayLogs -Config $config -Now $Now -LogRoot $LogRoot -Preview:$Preview
    if (-not $Preview -and -not $SkipPages) {
        Invoke-OpenMorningPages -Config $config -Now $Now -SecretsFolder (Join-Path $PSScriptRoot 'secrets')
    }
}
catch { Write-Error $_ -ErrorAction Continue; exit 1 }
