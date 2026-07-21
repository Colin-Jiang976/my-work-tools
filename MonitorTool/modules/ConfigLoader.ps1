function Get-ToolConfig {
    param ([string]$ConfigPath)
    
    if (Test-Path $ConfigPath) {
        # Read JSON and convert to PowerShell Object
        $JsonRaw = Get-Content -Raw -Path $ConfigPath -Encoding UTF8
        return $JsonRaw | ConvertFrom-Json
    } else {
        Write-Error "Configuration not found at: $ConfigPath"
        return $null
    }
}