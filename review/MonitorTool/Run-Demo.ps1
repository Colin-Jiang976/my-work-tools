#Requires -Version 5.1
[CmdletBinding()]
param([switch]$OpenFiles)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'demo/New-DemoLogs.ps1')
$options = @{
    ConfigPath = Join-Path $PSScriptRoot 'demo/config.demo.json'
    LogRoot = Join-Path $PSScriptRoot 'demo/logs'
    Now = [datetime]'2026-10-19T09:00:00'
    SkipPages = $true
    Preview = -not $OpenFiles
}
& (Join-Path $PSScriptRoot 'Start-Tool.ps1') @options
