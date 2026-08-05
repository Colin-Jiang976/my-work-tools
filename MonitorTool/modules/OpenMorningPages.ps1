function Invoke-OpenMorningPages {
    param ([object]$Config)

    # Morning only
    $CurrentHour = (Get-Date).Hour

    if ($CurrentHour -ge $Config.ShiftSplitHour) {
        Write-Host "[Morning Pages] Skipped." -ForegroundColor DarkGray
        return
    }

    # Check config
    if ($null -eq $Config.MorningPages) {
        Write-Warning "MorningPages not found in config."
        return
    }

    # Open pages
    Write-Host "[Morning Pages] Opening..." -ForegroundColor Cyan

    foreach ($Page in $Config.MorningPages) {
        if (:IsNullOrWhiteSpace($Page.Url)) {
            Write-Warning "Empty URL: $($Page.Name)"
            continue
        }

        try {
            Write-Host "Opening: $($Page.Name)" -ForegroundColor Green
            Start-Process $Page.Url
        }
        catch {
            Write-Warning "Failed to open: $($Page.Name)"
        }
    }
}
