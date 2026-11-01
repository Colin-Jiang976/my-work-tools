# modules/FirstRunSetup.ps1
# One-time, per-PC setup: if the server IP is still the placeholder value,
# ask for it once (console prompt) and save it back into config.json.
# Every run after that skips this step, since the placeholder is gone.

function Repair-ServerConfig {
    param(
        [Parameter(Mandatory)][object]$Config,
        [Parameter(Mandatory)][string]$ConfigPath
    )

    $placeholder = "<YOUR_SERVER_IP>"

    if ($Config.ServerIP -ne $placeholder -and -not [string]::IsNullOrWhiteSpace($Config.ServerIP)) {
        return $Config
    }

    Write-Host ""
    $ip = Read-Host "First-time setup: enter this PC's server IP"

    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Warning "Server IP not set. Some features may not work until this is configured."
        return $Config
    }

    $Config.ServerIP = $ip
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
    Write-Host "Saved." -ForegroundColor Green

    return $Config
}
